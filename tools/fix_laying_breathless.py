"""Drop `laying_breathless` onto the floor. RECONgame-bv4q task 4.

Every death_* clip lands the body on the ground; laying_breathless (the downed /
bleeding-out pose) was authored ~1.07m ABOVE it. The runtime ground-clamps the
pose so it is not a visible bug today - but the clamp is a patch over bad source
data, and any new consumer of the clip inherits the float. Fix the source and
the clamp becomes a no-op (that is explicitly safe: see production/VC_FIX_LIST.md).

The clip is root-driven, so the whole pose is lowered by offsetting the Hips
location F-curves. The offset is computed in the Hips' own rest space, because
that is the space `pose_bone.location` lives in - offsetting world Z directly
would skew the pose on any rig whose Hips rest orientation is not axis-aligned.

    blender -b <file.blend> -P tools/fix_laying_breathless.py
"""
import bpy
from mathutils import Vector

CLIP = "laying_breathless"
RIG = "PSXRig"
HIPS = "mixamorig:Hips"
TARGET_LOWEST_Z = 0.0        # soles on the deck, like the death clips


def channelbag(action, rig):
    """Blender 5 slotted actions: the F-curves live in a channelbag."""
    if not action.layers:
        return None
    strip = action.layers[0].strips[0]
    slot = None
    if rig.animation_data and rig.animation_data.action == action:
        slot = rig.animation_data.action_slot
    if slot is None and len(action.slots):
        slot = action.slots[0]
    return strip.channelbag(slot) if slot else None


def sample_lowest(rig, action):
    """Lowest bone head over the whole clip, in world Z."""
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    if len(action.slots):
        rig.animation_data.action_slot = action.slots[0]
    rig.data.pose_position = 'POSE'
    f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
    lo = 1e9
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        for pb in rig.pose.bones:
            lo = min(lo, (rig.matrix_world @ pb.head).z)
    return lo


def main():
    rig = bpy.data.objects.get(RIG)
    act = bpy.data.actions.get(CLIP)
    if rig is None or act is None:
        print("SKIP: no %s / no %s in %s" % (RIG, CLIP, bpy.data.filepath))
        return

    before = sample_lowest(rig, act)
    drop = TARGET_LOWEST_Z - before          # world-space Z we must move (negative)
    if abs(drop) < 0.01:
        print("%s already on the floor (lowest z=%.3f) - nothing to do" % (CLIP, before))
        return

    # world Z -> Hips rest space (that is the space pose_bone.location uses)
    rest = rig.data.bones[HIPS].matrix_local.to_3x3()
    world_to_arm = rig.matrix_world.to_3x3().inverted()
    local_delta = rest.inverted() @ (world_to_arm @ Vector((0.0, 0.0, drop)))

    cbag = channelbag(act, rig)
    if cbag is None:
        print("FAIL: no channelbag on %s" % CLIP)
        return
    path = 'pose.bones["%s"].location' % HIPS
    moved = 0
    for i in range(3):
        fc = cbag.fcurves.find(path, index=i)
        if fc is None:
            continue
        for kp in fc.keyframe_points:
            kp.co.y += local_delta[i]
            kp.handle_left.y += local_delta[i]
            kp.handle_right.y += local_delta[i]
        fc.update()
        moved += 1
    if moved == 0:
        print("FAIL: %s has no Hips location curves to offset" % CLIP)
        return

    after = sample_lowest(rig, act)
    print("%s: lowest bone z %.3f -> %.3f m (dropped %.3f, %d curves)"
          % (CLIP, before, after, drop, moved))
    if abs(after - TARGET_LOWEST_Z) > 0.02:
        print("  WARNING: still off the floor by %.3fm" % (after - TARGET_LOWEST_Z))
        return

    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_mainfile()
    print("saved:", bpy.data.filepath)


if __name__ == "__main__":
    main()
