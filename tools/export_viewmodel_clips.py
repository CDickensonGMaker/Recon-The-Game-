"""Export ONE weapon's FP viewmodel with ALL its clips.

    blender -b fp_arms_rifle.blend -P tools/export_viewmodel_clips.py -- RIG_M14 M14 m14

Exports every object in the gun's RIG_<gun> collection (arms + rig + gun + its moving
parts + markers), one named glTF animation per NLA track.

THE THING THIS EXISTS TO FIX: glTF has no constraints, and Blender's exporter only
samples an object it considers animated - meaning an object carrying TRS fcurves. Our
moving parts carry none: the magazine's entire motion is a CHILD_OF pointed at hand.L
with a keyed influence, and the rifle rides hand.R the same way. The exporter therefore
wrote NO channels for the magazine at all (it stayed welded to the rifle in game - "the
mag never disappears") and only the constant keys for the rifle root.

So we bake first: evaluate every clip frame by frame, record each part's world matrix,
strip the constraints, and write the result back as real location/rotation/scale keys.
glTF then has actual channels to carry.

Two supporting rules:
  * NLA_TRACKS, never ACTIONS - ACTIONS bakes each object's action in isolation, so a
    part gets sampled against an unposed arm and lands hundreds of mm from its hand.
  * No non-uniform scale on anything animated - glTF stores T/R/S separately, so
    non-uniform scale plus inherited rotation is a shear it cannot represent, and the
    decomposition comes out as a tumbling rotation.

Never saves the .blend.
"""
import bpy, sys, os
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(argv) < 3:
    raise SystemExit("argv: <collection> <gun_object_prefix> <out_basename> [--strict] [--root=<gun_root>] [--len=<real_m>]")
COLL, GUN, OUTNAME = argv[0], argv[1], argv[2]
STRICT = '--strict' in argv[3:]
GUN_ROOT = next((a.split('=', 1)[1] for a in argv[3:] if a.startswith('--root=')), None)
REAL_LEN = float(next((a.split('=', 1)[1] for a in argv[3:] if a.startswith('--len=')), '0') or 0)
OUT = rf"C:\Users\caleb\RECONgame\assets\player\viewmodels\{OUTNAME}_fp.glb"
REVIEW_TRACK = "ZZ_REVIEW_ROW"

coll = bpy.data.collections.get(COLL)
if coll is None:
    raise SystemExit(f"collection {COLL} not found")
objs = list(coll.objects)
rig = next((o for o in objs if o.type == 'ARMATURE'), None)
if rig is None:
    raise SystemExit(f"no armature in {COLL}")
print(f"=== {OUTNAME}: {len(objs)} objects from {COLL}, rig {rig.name} ===")

# --- make the collection visible and evaluable -------------------------------
vl = bpy.context.view_layer


def layer_coll(name, layer=None):
    layer = layer or vl.layer_collection
    if layer.collection.name == name:
        return layer
    for ch in layer.children:
        r = layer_coll(name, ch)
        if r:
            return r


lc = layer_coll(COLL)
if lc:
    lc.exclude = False
    lc.hide_viewport = False
for o in objs:
    o.hide_viewport = False
    o.hide_render = False
    o.hide_select = False
bpy.context.view_layer.update()
for o in objs:
    o.hide_set(False)

# --- clip tracks: drop the review row, unmute, clear masking active actions ---
for o in objs:
    ad = o.animation_data
    if not ad:
        continue
    ad.action = None
    for t in list(ad.nla_tracks):
        if t.name == REVIEW_TRACK:
            ad.nla_tracks.remove(t)
    for t in ad.nla_tracks:
        t.mute = False

# Blender 5.0.x exporter bug (glTF-Blender-IO #2681): a stale Manual Frame Range on ANY
# action poisons the sampling range of the whole export. Blend is never saved, so purge all.
for a in bpy.data.actions:
    a.use_frame_range = False

# clip name -> authored length, taken from the RIG's strip (the authority)
clip_len = {}
for t in rig.animation_data.nla_tracks:
    for s in t.strips:
        clip_len[t.name] = max(clip_len.get(t.name, 0), int(round(s.frame_end)))
print("clips:", {k: f"0-{v}" for k, v in sorted(clip_len.items())})

# parts that move but carry no TRS fcurves of their own
parts = [o for o in objs if o.type != 'ARMATURE'
         and (o.constraints or (o.animation_data and o.animation_data.nla_tracks))]
print("parts to bake:", [o.name for o in parts])

# PRE-FLIGHT (--strict, driver-enforced): a gun with no moving parts or missing
# contract markers is a broken rig, not an export candidate. This is the machine
# for the 2026-07-25 M16 break class - fail loud BEFORE writing a GLB.
if STRICT:
    if not parts:
        raise SystemExit(f"STRICT: {COLL} has zero bakeable parts - rig contract broken")
    for src in (f"muzzle_{GUN}", f"sight_front_{GUN}", f"sight_rear_{GUN}"):
        if bpy.data.objects.get(src) is None:
            raise SystemExit(f"STRICT: contract marker {src} missing")
    # SCALE GATE: the model's longest gun-local span must sit near the real weapon's
    # length (loose band - PSX proportions are art, 2x/100x/cm-unit drift is not).
    if GUN_ROOT and REAL_LEN > 0:
        gr = bpy.data.objects.get(GUN_ROOT)
        if gr is None:
            raise SystemExit(f"STRICT: gun root {GUN_ROOT} missing")
        dg = bpy.context.evaluated_depsgraph_get()
        pts = []
        stack = [gr]
        while stack:
            o = stack.pop()
            stack.extend(o.children)
            if o.type == 'MESH':
                ev = o.evaluated_get(dg)
                pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
        if not pts:
            raise SystemExit(f"STRICT: gun root {GUN_ROOT} has no mesh geometry to measure")
        rot = gr.matrix_world.to_3x3()
        span = max(
            max(p.dot(ax) for p in pts) - min(p.dot(ax) for p in pts)
            for ax in (rot.col[i].normalized() for i in range(3)))
        if abs(span - REAL_LEN) / REAL_LEN > 0.15:
            raise SystemExit(f"STRICT: {GUN_ROOT} measures {span:.3f} m vs real "
                             f"{REAL_LEN:.3f} m - scale drift, refusing to export")
        print(f"scale gate: {GUN_ROOT} {span:.3f} m vs real {REAL_LEN:.3f} m OK")

    # Slotted-action contract (Blender 4.4+/5.0): a multi-slot action merges several
    # rigs into one glTF animation, and a strip with no assigned slot exports silent.
    for o in objs:
        if not o.animation_data:
            continue
        for t in o.animation_data.nla_tracks:
            for s in t.strips:
                if s.action is None:
                    raise SystemExit(f"STRICT: {o.name}/{t.name} strip has no action")
                if len(s.action.slots) != 1:
                    raise SystemExit(f"STRICT: action {s.action.name} has "
                                     f"{len(s.action.slots)} slots - one slot per action")
                if s.action_slot is None:
                    raise SystemExit(f"STRICT: {o.name}/{t.name} strip "
                                     f"'{s.action.name}' has no assigned slot")


def depth(o):
    d, p = 0, o.parent
    while p:
        d, p = d + 1, p.parent
    return d


parts.sort(key=depth)          # parents first, so a child's basis is solved against a baked parent


def solo(track):
    for o in objs:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != track)


# --- 1. record every part's world matrix, per clip, with constraints live -----
sc = bpy.context.scene
recorded = {}
drift = {}   # part -> max distance from hand.R across all clips
for clip, end in clip_len.items():
    solo(clip)
    frames = {}
    for f in range(0, end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        frames[f] = {o.name: o.evaluated_get(dg).matrix_world.copy() for o in parts}
        rig_ev = rig.evaluated_get(dg)
        hr = (rig_ev.matrix_world @ rig_ev.pose.bones["hand.R"].matrix).translation
        for name, m in frames[f].items():
            d = (m.translation - hr).length
            if d > drift.get(name, 0.0):
                drift[name] = d
    recorded[clip] = frames
print(f"recorded {sum(len(v) for v in recorded.values())} frames across {len(recorded)} clips")
print("part max distance from hand.R:", {k: round(v, 2) for k, v in drift.items()})

# WRECKAGE CATCHER: a viewmodel part metres from the firing hand is the floor-ruler
# break class (2026-07-25) - the whole M16 constellation baked at +3.1m. Hard limit.
if STRICT:
    for name, d in drift.items():
        if d > 2.5:
            raise SystemExit(f"STRICT: {name} bakes {d:.2f} m from hand.R - rig contract broken, refusing to export")

# --- 2. strip constraints and the old animation off the parts ----------------
for o in parts:
    for c in list(o.constraints):
        o.constraints.remove(c)
    if o.animation_data:
        o.animation_data.action = None
        for t in list(o.animation_data.nla_tracks):
            o.animation_data.nla_tracks.remove(t)
bpy.context.view_layer.update()

# --- 3. write the recorded motion back as real TRS keys ---------------------
for clip, frames in recorded.items():
    acts = {}
    for o in parts:
        a = bpy.data.actions.new(f"{OUTNAME}_{clip}_{o.name}")
        a.use_fake_user = True
        acts[o.name] = a
    for f in sorted(frames):
        sc.frame_set(f)
        for o in parts:                     # parent-first: see the depth sort above
            if o.animation_data is None:
                o.animation_data_create()
            if o.animation_data.action is not acts[o.name]:
                o.animation_data.action = acts[o.name]
            o.matrix_world = frames[f][o.name]
            bpy.context.view_layer.update()
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_quaternion" if o.rotation_mode == 'QUATERNION'
                              else "rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in parts:
        o.animation_data.action = None
        t = o.animation_data.nla_tracks.new()
        t.name = clip
        s = t.strips.new(acts[o.name].name, 0, acts[o.name])
        s.blend_type = 'REPLACE'
        s.extrapolation = 'HOLD'
        t.mute = False
for o in parts:
    for t in o.animation_data.nla_tracks:
        for s in t.strips:
            if s.action_slot is None:
                raise SystemExit(f"baked strip {o.name}/{t.name} lost its action slot")
print("baked parts to explicit TRS keys")

# --- 4. no non-uniform scale on anything animated ----------------------------
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.data.objects:
    o.select_set(False)
fixed = []
for o in objs:
    if o.type != 'MESH':
        continue
    animated = o.animation_data and (o.animation_data.action or o.animation_data.nla_tracks)
    s = o.scale
    if animated and (abs(s[0] - s[1]) > 1e-4 or abs(s[1] - s[2]) > 1e-4):
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.select_set(False)
        fixed.append((o.name, [round(v, 4) for v in s]))
print("non-uniform scale applied on animated parts:", fixed or "none needed")

# --- 5. contract marker names ------------------------------------------------
for src, dst in ((f"muzzle_{GUN}", "MuzzlePoint"),
                 (f"sight_front_{GUN}", "SightFront"),
                 (f"sight_rear_{GUN}", "SightRear")):
    o = bpy.data.objects.get(src)
    if o:
        o.name = dst
    else:
        print(f"   WARNING: {src} missing")

# --- 5b. flatten procedural base colors ---------------------------------------
# glTF cannot carry a node tree (the Wave->ColorRamp wood materials): it writes
# no baseColorFactor at all and the part lands in Godot as placeholder WHITE.
# Resolve a flat color from the ramp driving the socket and bake it into the
# Principled default. Blend is never saved - viewport look untouched.
def _upstream(node, seen):
    if node in seen:
        return
    seen.add(node)
    yield node
    for inp in node.inputs:
        for l in inp.links:
            yield from _upstream(l.from_node, seen)


flattened = []
mats = {slot.material for o in objs if o.type == 'MESH'
        for slot in o.material_slots if slot.material and slot.material.use_nodes}
for mat in mats:
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        continue
    sock = bsdf.inputs['Base Color']
    if not sock.is_linked:
        continue
    chain = list(_upstream(sock.links[0].from_node, set()))
    if any(n.type == 'TEX_IMAGE' for n in chain):
        continue
    ramp = next((n for n in chain if n.type == 'VALTORGB'), None)
    if ramp:
        els = ramp.color_ramp.elements
        col = [sum(e.color[i] for e in els) / len(els) for i in range(3)] + [1.0]
    else:
        col = list(sock.default_value)
    mat.node_tree.links.remove(sock.links[0])
    sock.default_value = col
    flattened.append((mat.name, [round(c, 3) for c in col[:3]]))
print("procedural base colors flattened:", flattened or "none")

# --- 6. export ---------------------------------------------------------------
for o in bpy.data.objects:
    o.select_set(False)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
sc.frame_set(0)

kwargs = dict(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_apply=True, export_yup=True,
    export_animations=True, export_animation_mode='NLA_TRACKS',
    export_bake_animation=True, export_force_sampling=True,
    export_anim_single_armature=True, export_reset_pose_bones=False,
    export_skins=True, export_morph=False, export_optimize_animation_size=False,
    export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_draco_mesh_compression_enable=False)
valid = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
kwargs = {k: v for k, v in kwargs.items() if k in valid}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(**kwargs)
print(f"EXPORTED {OUTNAME}_fp.glb  {os.path.getsize(OUT) / 1024 / 1024:.2f} MB  (blend NOT saved)")
