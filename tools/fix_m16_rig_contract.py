"""Restore the M16 rig contract in fp_arms_rifle.blend (2026-07-25 break).

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/fix_m16_rig_contract.py

THE BREAK (measured, see memory recon-m16-rig-break-2026-07-25): the 36->4 mesh join
created M16A1_gun but the old root's rig state died with it - no CHILD_OF->hand.R, no
parent links, and the fittings (sights/muzzle/grips/magazine) were left on the floor
ruler at world X~2.6-3.4. The floor constellation is EXACTLY the old gun's local marker
set offset by O=(3.112, 0, 0.055) - verified to sub-mm against the last-good GLB on six
fittings before this script was written.

THE RESTORE (mirrors the measured healthy AK47_root pattern):
  1. apply the gun's non-uniform scale (1.014, 1.467, 1.001) - glTF shear poison -
     while it still has no children and no keys, so appearance is preserved
  2. CHILD_OF "hold_R" -> ArmsRig_M16A1/hand.R on the gun, influence 1.0, set-inverse
     at the neutral pose (the M16 never leaves the right hand in any clip)
  3. re-seat the floor fittings as children of the gun at their old gun-local offsets
  4. parent the charge-handle rail under the gun keeping world (Caleb authored the new
     chandle clips against its current placement - do not move it)
  5. re-set the magazine's "hand_handoff" CHILD_OF inverse at the reload grab frame
     (first frame its influence curve reaches 1), so the carry lands in the palm
  6. verify by measurement; SAVE ONLY ON PASS. Never writes .blend1 backups.
"""
import bpy, sys, json
from mathutils import Matrix, Vector

FLOOR_ORIGIN = Vector((3.112, 0.0, 0.055))   # old gun frame on the floor ruler (measured)
FLOOR_ITEMS = ["sight_rear_M16A1", "sight_front_M16A1", "muzzle_M16A1",
               "grip_L_M16A1", "grip_R_M16A1", "M16A1_magazine.030"]

fails = []


def fail(msg):
    fails.append(msg)
    print("FIX-FAIL:", msg)


def ob(name):
    o = bpy.data.objects.get(name)
    if o is None:
        fail(f"object {name} missing")
    return o


gun = ob("M16A1_gun")
rig = ob("ArmsRig_M16A1")
mag = ob("M16A1_magazine.030")
rail = ob("M16A1_ch_rail")
if fails:
    sys.exit(1)

if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

coll = bpy.data.collections["RIG_M16A1"]
objs = list(coll.objects)

# neutral state: every track muted, frame 0
saved_mute = {}
for o in objs:
    if o.animation_data:
        for t in o.animation_data.nla_tracks:
            saved_mute[(o.name, t.name)] = t.mute
            t.mute = True
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()

# --- 1. bake the gun's non-uniform scale into the mesh (it has no children/keys yet)
if gun.parent is not None or gun.constraints or (gun.animation_data and gun.animation_data.nla_tracks):
    fail("M16A1_gun is not the bare joined object this fix was measured against")
    sys.exit(1)
pre_world = gun.matrix_world.copy()
if gun.data.users > 1:
    gun.data = gun.data.copy()
for o in bpy.data.objects:
    o.select_set(False)
gun.select_set(True)
bpy.context.view_layer.objects.active = gun
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
if (gun.matrix_world.translation - pre_world.translation).length > 1e-4:
    fail("scale apply moved the gun")

# --- 2. CHILD_OF hold_R at the neutral pose
con = gun.constraints.new('CHILD_OF')
con.name = "hold_R"
con.target = rig
con.subtarget = "hand.R"
con.influence = 1.0
before = gun.matrix_world.translation.copy()
with bpy.context.temp_override(object=gun, active_object=gun, constraint=con):
    bpy.ops.constraint.childof_set_inverse(constraint=con.name, owner='OBJECT')
bpy.context.view_layer.update()
drift = (gun.matrix_world.translation - before).length
if drift > 0.002:
    fail(f"set_inverse drifted the gun {drift:.4f} m")

# --- 3+4. fittings onto the gun
gun_world = gun.matrix_world.copy()
for name in FLOOR_ITEMS:
    o = ob(name)
    local = Matrix.Translation(-FLOOR_ORIGIN) @ o.matrix_world
    o.parent = gun
    o.parent_type = 'OBJECT'
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.matrix_basis = local
rail_local = gun_world.inverted() @ rail.matrix_world
rail.parent = gun
rail.parent_type = 'OBJECT'
rail.matrix_parent_inverse = Matrix.Identity(4)
rail.matrix_basis = rail_local
bpy.context.view_layer.update()

sr, sf = ob("sight_rear_M16A1"), ob("sight_front_M16A1")
radius = (sr.matrix_world.translation - sf.matrix_world.translation).length
if abs(radius - 0.596) > 0.02:
    fail(f"sight radius off after reattach: {radius:.4f} (want ~0.596)")
for name in FLOOR_ITEMS + ["M16A1_ch_rail"]:
    d = (bpy.data.objects[name].matrix_world.translation - gun.matrix_world.translation).length
    if d > 1.2:
        fail(f"{name} is {d:.2f} m from the gun after reattach")

# --- 5. magazine hand_handoff inverse at the reload grab frame
handoff = bpy.data.actions.get("m16_mag_handoff")
grab_frame = None
if handoff is None:
    fail("m16_mag_handoff action missing")
else:
    for layer in handoff.layers:
        for strip in layer.strips:
            for slot in handoff.slots:
                try:
                    cb = strip.channelbag(slot)
                except Exception:
                    cb = None
                if cb is None:
                    continue
                for fc in cb.fcurves:
                    if fc.data_path.endswith('influence'):
                        hit = [kp.co.x for kp in fc.keyframe_points if kp.co.y >= 0.99]
                        if hit:
                            grab_frame = int(round(min(hit)))
if grab_frame is None:
    fail("no influence>=0.99 key in m16_mag_handoff - cannot find the grab frame")
else:
    # armature plays the reload; the mag itself stays muted at its well rest
    for o in objs:
        if o is mag or not o.animation_data:
            continue
        for t in o.animation_data.nla_tracks:
            t.mute = (t.name != "reload")
    bpy.context.scene.frame_set(grab_frame)
    bpy.context.view_layer.update()
    mcon = mag.constraints.get("hand_handoff")
    if mcon is None:
        fail("mag constraint hand_handoff missing")
    else:
        well = mag.matrix_world.translation.copy()
        with bpy.context.temp_override(object=mag, active_object=mag, constraint=mcon):
            bpy.ops.constraint.childof_set_inverse(constraint=mcon.name, owner='OBJECT')
        bpy.context.view_layer.update()
        d = (mag.matrix_world.translation - well).length
        if d > 0.02:
            fail(f"mag set_inverse drifted it {d:.4f} m at the grab frame")

# restore every track to live
for o in objs:
    if o.animation_data:
        for t in o.animation_data.nla_tracks:
            t.mute = False
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()

# --- 6. verification trace across the clips
report = {}
tracks = {t.name: max(int(round(s.frame_end)) for s in t.strips)
          for t in rig.animation_data.nla_tracks if t.strips}
for clip, end in tracks.items():
    for o in objs:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != clip)
    rows = {}
    for f in sorted({0, max(1, end // 2), end}):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        rig_ev = rig.evaluated_get(dg)
        hr = (rig_ev.matrix_world @ rig_ev.pose.bones["hand.R"].matrix).translation
        gw = gun.evaluated_get(dg).matrix_world.translation
        mw = mag.evaluated_get(dg).matrix_world.translation
        rows[f] = {"gun_to_handR": round((gw - hr).length, 4),
                   "mag_to_gun": round((mw - gw).length, 4),
                   "gun_w": [round(v, 3) for v in gw]}
    report[clip] = rows
    dists = [r["gun_to_handR"] for r in rows.values()]
    if max(dists) - min(dists) > 0.005:
        fail(f"{clip}: gun does not ride hand.R rigidly (spread {max(dists) - min(dists):.4f} m)")
    for f, r in rows.items():
        if r["mag_to_gun"] > 1.0:
            fail(f"{clip} f{f}: magazine {r['mag_to_gun']:.2f} m from the gun")

for o in objs:
    if o.animation_data:
        for t in o.animation_data.nla_tracks:
            t.mute = False
bpy.context.scene.frame_set(0)

print("FIX_TRACE " + json.dumps(report))
if fails:
    print(f"FIX RESULT: FAIL ({len(fails)}) - NOT SAVED")
    sys.exit(1)

bpy.context.preferences.filepaths.save_version = 0   # no .blend1 (no-backup law)
bpy.ops.wm.save_mainfile()
print("FIX RESULT: PASS - saved", bpy.data.filepath)
