"""Re-seat the M14's stranded fittings onto the gun (2026-07-26 strict-gate catch).

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/fix_m14_fittings.py

The M14 was staged into the arms rig but its loose fittings (op-rod x3, contract
markers x3, grips x2) were left parentless at the armory rack position, with the
op-rod animation keyed in rack-world space. In every exported GLB they sat ~5.8 m
from the hands: no op-rod on screen, MuzzlePoint ~3 m off the barrel.

Reference measured in assets/us/characters/weapons_us.blend (probe_m14_armory.py):
gun origin (2.9533, -0.9499, -0.0054), identity rot/scale; chandle seats relative
to it match the stranded basis positions to the millimetre, which proves the
fittings never moved. Fix: parent each fitting to M14_gun with identity parent
inverse, basis = (rack basis - rack origin); shift every location fcurve on the
op-rod actions by the same delta. Saves ONLY if the post-fix measurement passes.
"""
import bpy
from mathutils import Matrix, Vector

RACK_O = Vector((2.9533, -0.9499, -0.0054))
ARMORY_SEATS = {  # gun-local, measured in weapons_us.blend
    "M14_chandle": Vector((-0.2758, 0.0124, 0.0354)),
    "M14_chandle.001": Vector((0.1387, 0.0189, 0.0554)),
    "M14_chandle.002": Vector((0.0589, 0.0181, 0.0479)),
}
ANIMATED = ["M14_chandle", "M14_chandle.001", "M14_chandle.002"]
STATIC = ["muzzle_M14", "sight_front_M14", "sight_rear_M14", "grip_R_M14", "grip_L_M14"]

coll = bpy.data.collections["RIG_M14"]
objs = list(coll.objects)
rig = next(o for o in objs if o.type == 'ARMATURE')
gun = bpy.data.objects.get("M14_gun")
if gun is None:
    raise SystemExit("M14_gun not found")

lc = None


def find_layer(layer):
    global lc
    if layer.collection.name == "RIG_M14":
        lc = layer
    for ch in layer.children:
        find_layer(ch)


find_layer(bpy.context.view_layer.layer_collection)
if lc:
    lc.exclude = False
    lc.hide_viewport = False
for o in objs:
    o.hide_viewport = False
bpy.context.view_layer.update()

# --- pre-flight: prove the rack hypothesis before touching anything -----------
for name, seat in ARMORY_SEATS.items():
    o = bpy.data.objects[name]
    if o.parent is not None or o.constraints:
        raise SystemExit(f"{name}: expected parentless/unconstrained, found "
                         f"parent={o.parent} constraints={list(o.constraints)}")
    d = (Vector(o.location) - RACK_O - seat).length
    if d > 0.002:
        raise SystemExit(f"{name}: basis {tuple(o.location)} is {d * 1000:.1f} mm off the "
                         f"rack-origin hypothesis - measure again, do not guess")
for name in STATIC:
    o = bpy.data.objects.get(name)
    if o is None:
        raise SystemExit(f"{name} missing")
    if o.parent is not None:
        raise SystemExit(f"{name}: already parented to {o.parent.name}")
    if o.animation_data and (o.animation_data.action or o.animation_data.nla_tracks):
        raise SystemExit(f"{name}: has animation - static reparent would break it")
    local = Vector(o.location) - RACK_O
    if max(abs(v) for v in local) > 1.0:
        raise SystemExit(f"{name}: rack-local {tuple(round(v, 3) for v in local)} not on the gun")
print("pre-flight: all 8 fittings match the rack hypothesis")

# --- reparent, rebase basis --------------------------------------------------
for name in ANIMATED + STATIC:
    o = bpy.data.objects[name]
    o.parent = gun
    o.parent_type = 'OBJECT'
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.location = Vector(o.location) - RACK_O

# --- shift every location fcurve on the op-rod actions by -RACK_O -------------
done = set()
shifted = 0
for name in ANIMATED:
    o = bpy.data.objects[name]
    if not o.animation_data:
        continue
    for t in o.animation_data.nla_tracks:
        for s in t.strips:
            if s.action is None or s.action_slot is None:
                continue
            key = (s.action.name, s.action_slot.identifier)
            if key in done:
                continue
            done.add(key)
            for layer in s.action.layers:
                for strip in layer.strips:
                    cb = strip.channelbag(s.action_slot)
                    if cb is None:
                        continue
                    for fc in cb.fcurves:
                        if fc.data_path != "location":
                            continue
                        delta = -RACK_O[fc.array_index]
                        for kp in fc.keyframe_points:
                            kp.co[1] += delta
                            kp.handle_left[1] += delta
                            kp.handle_right[1] += delta
                        fc.update()
                        shifted += 1
print(f"rebased {shifted} location fcurves across {len(done)} actions")

# --- verify by measurement (the export bake's own criterion) ------------------
for a in bpy.data.actions:
    a.use_frame_range = False
clip_len = {}
for t in rig.animation_data.nla_tracks:
    if t.name == "ZZ_REVIEW_ROW":
        continue
    for s in t.strips:
        clip_len[t.name] = max(clip_len.get(t.name, 0), int(round(s.frame_end)))


def solo(track):
    for o in objs:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != track)


sc = bpy.context.scene
worst_overall = 0.0
fail = False
for clip, end in sorted(clip_len.items()):
    solo(clip)
    worst = {}
    for f in range(0, end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        rig_ev = rig.evaluated_get(dg)
        hr = (rig_ev.matrix_world @ rig_ev.pose.bones["hand.R"].matrix).translation
        for name in ANIMATED + STATIC:
            o = bpy.data.objects[name]
            d = (o.evaluated_get(dg).matrix_world.translation - hr).length
            if d > worst.get(name, 0.0):
                worst[name] = d
    for name, d in worst.items():
        worst_overall = max(worst_overall, d)
        if d > 1.0:
            print(f"FAIL {clip}: {name} still {d:.2f} m from hand.R")
            fail = True
    print(f"{clip}: worst fitting distance {max(worst.values()):.3f} m")

# op-rod must still stroke in charge_handle - measured in GUN space, the only
# frame where the stroke is axis-aligned now that the gun rides the hand
solo("charge_handle")
locs = []
for f in range(0, clip_len["charge_handle"] + 1):
    sc.frame_set(f)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    gun_inv = gun.evaluated_get(dg).matrix_world.inverted()
    locs.append(gun_inv @ bpy.data.objects["M14_chandle"].evaluated_get(dg).matrix_world.translation)
stroke = max((max(p[i] for p in locs) - min(p[i] for p in locs)) for i in range(3)) * 1000
print(f"charge_handle op-rod stroke (gun space): {stroke:.1f} mm")
if not (10.0 < stroke < 60.0):
    print("FAIL: stroke outside the 34 mm-class band - rebase damaged the animation")
    fail = True

if fail:
    raise SystemExit("verification FAILED - blend NOT saved")
bpy.ops.wm.save_mainfile()
print(f"SAVED: all fittings ride the gun (worst {worst_overall:.3f} m from hand.R)")
