"""Measure, per clip, how the OBJECT must be oriented to stand the man up and aim him.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\calibrate_clips.py").read())
    -> writes bpy CLIP_CAL = {clip: {"rx": deg, "yaw_off": deg, "travel": Vector}}

TWO THINGS THIS EXISTS TO STOP ME GUESSING.

1. THE CLIPS DISAGREE ON AN UP AXIS. `chow_eat_seated` and the sit/stand transitions are
   Y-up in armature space and need the object at rotation_euler.x = +90 to stand the man
   up; the idle-derived standing clips need x = 0. Keying yaw alone left seated men lying
   on the floor with their hips at z 0.02.

2. FACING MUST BE MEASURED, NOT DERIVED. Caleb: *"you have them all facing away from the
   table... would it help to add directional marker nodes to models orient properly?"* -
   yes, and his `work_*` markers already carry facing on their +X axis. So rather than
   computing which yaw ought to point a man somewhere, we measure the yaw offset between
   the object's rotation and the body's ACTUAL facing, per clip, and then any target
   direction is just `wanted - offset`. Same rule as the gun crews: measure the contact,
   do not assume it.
"""
import bpy
import math
from mathutils import Vector

M = "mixamorig:"


def _probe_rig():
    """Any PSXRig will do - calibration reads the CLIP, not the man. Naming one
    hardcoded rig broke this the moment that man was deleted from the scene."""
    for o in bpy.data.objects:
        if o.type == 'ARMATURE' and M + "Hips" in o.pose.bones:
            return o.name
    raise RuntimeError("no PSXRig-style armature in the file to calibrate against")


PROBE = _probe_rig()


def body_facing(rig):
    """World direction the body actually faces, off the shoulder line."""
    l = rig.matrix_world @ rig.pose.bones[M + "LeftArm"].head
    r = rig.matrix_world @ rig.pose.bones[M + "RightArm"].head
    side = l - r
    f = Vector((side.y, -side.x, 0.0))
    return f.normalized() if f.length > 1e-6 else Vector((0.0, -1.0, 0.0))


def calibrate():
    rig = bpy.data.objects[PROBE]
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()
    keep_act = rig.animation_data.action
    keep_loc = rig.location.copy()
    keep_rot = tuple(rig.rotation_euler)
    keep_mode = rig.rotation_mode

    rig.rotation_mode = 'XYZ'
    rig.location = (0.0, 0.0, 0.0)
    sc = bpy.context.scene
    cal = {}

    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        rig.animation_data.action = act
        if len(act.slots):
            rig.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])

        # (1) which X rotation stands him up? try 0 and +90, keep the taller head.
        best_rx, best_h = 0.0, -9.9
        for rx in (0.0, 90.0):
            rig.rotation_euler = (math.radians(rx), 0.0, 0.0)
            sc.frame_set(f0)
            bpy.context.view_layer.update()
            hips = (rig.matrix_world @ rig.pose.bones[M + "Hips"].head).z
            head = (rig.matrix_world @ rig.pose.bones[M + "Head"].head).z
            if head - hips > best_h:
                best_rx, best_h = rx, head - hips

        # (2) at that X and yaw 0, which way does the body actually point?
        rig.rotation_euler = (math.radians(best_rx), 0.0, 0.0)
        sc.frame_set(f0)
        bpy.context.view_layer.update()
        f = body_facing(rig)
        yaw_off = math.degrees(math.atan2(f.y, f.x))

        # (3) planar root travel, and hip height, at this orientation
        p0 = (rig.matrix_world @ rig.pose.bones[M + "Hips"].head).copy()
        sc.frame_set(f1)
        bpy.context.view_layer.update()
        p1 = (rig.matrix_world @ rig.pose.bones[M + "Hips"].head).copy()
        d = p1 - p0

        cal[act.name] = {"rx": best_rx, "yaw_off": yaw_off,
                         "travel": Vector((d.x, d.y, 0.0)),
                         "hip_z": round(p0.z, 3),
                         "upright": round(best_h, 3)}

    rig.animation_data.action = keep_act
    rig.rotation_mode = keep_mode
    rig.location = keep_loc
    rig.rotation_euler = keep_rot
    sc.frame_set(1)
    bpy.context.view_layer.update()
    return cal


CLIP_CAL = calibrate()
print("%-24s %4s %9s %7s %8s  %s" % ("clip", "rx", "yaw_off", "hip_z", "head-hip", "travel"))
for k in sorted(CLIP_CAL):
    c = CLIP_CAL[k]
    print("%-24s %4.0f %9.1f %7.3f %8.3f  (%6.3f,%6.3f)"
          % (k, c["rx"], c["yaw_off"], c["hip_z"], c["upright"],
             c["travel"].x, c["travel"].y))
