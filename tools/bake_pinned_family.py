# bake_pinned_family.py - weapon-family clips with a GRIP-LOCKED support hand
# (bead 6opb, Caleb: "lock the gun in the model's hands so it moves organically
# and won't drift the arm").
#
# The right arm (gun arm) gets Caleb's captured hold as constant FK deltas -
# its motion IS the clip. The LEFT arm is solved per frame by a temporary IK
# pin: the left wrist chases a grip point that rides the right hand (= rides
# the gun), so the support hand stays welded to the weapon through sway, runs
# and strafes - no more elbow drift. The IK solve is visually baked into
# plain FK keys and the constraint removed: the exported clip is ordinary.
#
# Spec JSON: right_deltas {bone: quat}, grip_matrix (left hand in right-hand
# space), elbow_hint, clips [{base, new}].
# Run: blender -b anim_library.blend -P tools/bake_pinned_family.py -- spec.json
import bpy
import json
import sys
from mathutils import Quaternion, Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:]
with open(argv[0], encoding='utf-8-sig') as f:
    spec = json.load(f)

CONST_DELTAS = {b: Quaternion(q).normalized() for b, q in spec["right_deltas"].items()}
GRIP = Matrix([Vector(r) for r in spec["grip_matrix"]])
PAIRS = spec["clips"]

rig = None
for ob in bpy.data.objects:
    if ob.type == 'ARMATURE':
        rig = ob
        break
bpy.context.view_layer.objects.active = rig

LEFT_CHAIN = ["mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand"]


def channelbag(act):
    slot = act.slots[0]
    for layer in act.layers:
        for strip in layer.strips:
            return strip.channelbag(slot)
    return None


def apply_const_deltas(act):
    cb = channelbag(act)
    for bone, d in CONST_DELTAS.items():
        path = 'pose.bones["%s"].rotation_quaternion' % bone
        fcs = sorted([fc for fc in cb.fcurves if fc.data_path == path], key=lambda f: f.array_index)
        if len(fcs) != 4:
            continue
        prev = None
        for i in range(len(fcs[0].keyframe_points)):
            q = Quaternion((fcs[0].keyframe_points[i].co[1], fcs[1].keyframe_points[i].co[1],
                            fcs[2].keyframe_points[i].co[1], fcs[3].keyframe_points[i].co[1]))
            qn = (d @ q).normalized()
            if prev is not None and prev.dot(qn) < 0.0:
                qn = -qn
            prev = qn
            for ci, fc in enumerate(fcs):
                fc.keyframe_points[i].co[1] = qn[ci]
        for fc in fcs:
            fc.update()


def write_channel(act, bone, quats_by_frame):
    """Overwrite a bone's rotation keys with solved values (aligned baked keys)."""
    cb = channelbag(act)
    path = 'pose.bones["%s"].rotation_quaternion' % bone
    fcs = sorted([fc for fc in cb.fcurves if fc.data_path == path], key=lambda f: f.array_index)
    if len(fcs) != 4:
        print("  WARN %s has %d channels - skipped" % (bone, len(fcs)))
        return
    prev = None
    for i, kp in enumerate(fcs[0].keyframe_points):
        f = int(round(kp.co[0]))
        q = quats_by_frame.get(f)
        if q is None:
            continue
        qn = Quaternion(q).normalized()
        if prev is not None and prev.dot(qn) < 0.0:
            qn = -qn
        prev = qn
        for ci, fc in enumerate(fcs):
            fc.keyframe_points[i].co[1] = qn[ci]
    for fc in fcs:
        fc.update()


# temp IK rig: unparented empty, repositioned per frame in world space
grip_empty = bpy.data.objects.new("GripTarget_tmp", None)
bpy.context.scene.collection.objects.link(grip_empty)
lf = rig.pose.bones["mixamorig:LeftForeArm"]
ik = lf.constraints.new('IK')
ik.target = grip_empty
ik.chain_count = 2  # forearm + upper arm; shoulder stays FK (constant delta)
ik.use_tail = True

rh = rig.pose.bones["mixamorig:RightHand"]
lh = rig.pose.bones["mixamorig:LeftHand"]

for pair in PAIRS:
    base_act = bpy.data.actions.get(pair["base"])
    if base_act is None:
        print("SKIP %s" % pair["base"])
        continue
    old = bpy.data.actions.get(pair["new"])
    if old is not None:
        bpy.data.actions.remove(old)
    act = base_act.copy()
    act.name = pair["new"]
    act.use_fake_user = True
    apply_const_deltas(act)

    # assign + solve the left arm per frame against the riding grip point
    rig.animation_data.action = act
    if hasattr(rig.animation_data, "action_slot") and act.slots:
        rig.animation_data.action_slot = act.slots[0]
    fr = act.frame_range
    solved = {b: {} for b in LEFT_CHAIN}
    for f in range(int(fr[0]), int(fr[1]) + 1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        # grip point rides the (delta-corrected) right hand = the gun
        grip_pose = rh.matrix @ GRIP
        grip_empty.matrix_world = rig.matrix_world @ grip_pose
        bpy.context.view_layer.update()
        for bname in ["mixamorig:LeftArm", "mixamorig:LeftForeArm"]:
            pb = rig.pose.bones[bname]
            loc = rig.convert_space(pose_bone=pb, matrix=pb.matrix, from_space='POSE', to_space='LOCAL')
            solved[bname][f] = list(loc.to_quaternion().normalized())
        # hand follows the grip orientation exactly (knuckles stay wrapped)
        lh_local = rig.convert_space(pose_bone=lh, matrix=grip_pose, from_space='POSE', to_space='LOCAL')
        solved["mixamorig:LeftHand"][f] = list(lh_local.to_quaternion().normalized())

    for bname in LEFT_CHAIN:
        write_channel(act, bname, solved[bname])
    print("PINNED CLIP '%s' <- '%s' (%d frames, left arm IK-locked to grip)" % (pair["new"], pair["base"], int(fr[1]) - int(fr[0]) + 1))

# cleanup: constraint + empty out, library stays ordinary FK
lf.constraints.remove(ik)
bpy.data.objects.remove(grip_empty, do_unlink=True)
bpy.ops.wm.save_mainfile()
print("library master SAVED (%d pinned clips)" % len(PAIRS))
