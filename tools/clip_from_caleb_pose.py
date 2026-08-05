"""Turn Caleb's hand-set stances into looping clips.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\clip_from_caleb_pose.py").read())

Caleb posed two men by hand and said of the eating one: *"this animation should be a lot
like the work animation, where the hands just go up and down a bit to simulate movement
of eating."*

BUILD MOTION **ON** THE STANCE, NEVER TOWARD IT. Every frame starts as an exact copy of
his captured pose - all 41 bones, rotation AND location AND scale - and only a small
delta is layered on top. Rebuilding from the stance each frame is what stops the drift
that comes from nudging a pose that is already nudged.

THE LIFT AXIS IS MEASURED, NOT CHOSEN. Probing all six directions on three bones per arm
from HIS stance:
    LeftForeArm  Z  +8 deg -> hand +0.0358 m, lateral drift 0.0064   <- cleanest
    RightForeArm Z  +8 deg -> hand +0.0324 m, lateral drift 0.0165   <- cleanest
    (Shoulder Y lifts more, ~0.039, but drags the hand 0.025 sideways - rejected)
So the bob is authored on ForeArm Z, scaled from the measured per-degree response.
"""
import bpy
import json
import math
from mathutils import Euler, Quaternion, Vector

M = "mixamorig:"
PROD = r"C:\Users\caleb\RECONgame\production"

# measured metres of hand lift per degree, from his stance
LIFT_PER_DEG = {"Left": 0.0358 / 8.0, "Right": 0.0324 / 8.0}


def load(name):
    return json.load(open("%s\\%s" % (PROD, name)))


def stamp(rig, bones):
    """Lay his exact stance onto the rig."""
    for pb in rig.pose.bones:
        b = bones[pb.name]
        pb.rotation_mode = 'QUATERNION'
        if b["mode"] == 'QUATERNION':
            pb.rotation_quaternion = Quaternion(b["quat"])
        else:
            pb.rotation_quaternion = Euler(b["euler"], b["mode"]).to_quaternion()
        pb.location = Vector(b["loc"])
        pb.scale = Vector(b["scale"])


def new_action(name):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    strip = act.layers.new("base").strips.new(type='KEYFRAME')
    return act, slot, strip.channelbag(slot, ensure=True)


def key_all(rig, cbag, f):
    for pb in rig.pose.bones:
        q = pb.rotation_quaternion
        path = 'pose.bones["%s"].rotation_quaternion' % pb.name
        for i, v in enumerate((q.w, q.x, q.y, q.z)):
            fc = cbag.fcurves.find(path, index=i) or cbag.fcurves.new(path, index=i)
            fc.keyframe_points.insert(f, v, options={'FAST'})
        # location on EVERY bone - a clip that keys only the root silently depends on
        # pose state that is not in the file
        lp = 'pose.bones["%s"].location' % pb.name
        for i, v in enumerate(pb.location):
            fc = cbag.fcurves.find(lp, index=i) or cbag.fcurves.new(lp, index=i)
            fc.keyframe_points.insert(f, v, options={'FAST'})


def build_eat(rig, n=120, cycles=3, amp_m=0.030):
    d = load("pose_eat_seated_caleb.json")
    act, slot, cbag = new_action("chow_eat_seated")
    if rig.animation_data is None:
        rig.animation_data_create()
    for i in range(n):
        t = i / float(n)
        stamp(rig, d["bones"])
        # one hand leads the other - both bobbing in lockstep reads mechanical
        for side, phase in (("Right", 0.0), ("Left", 0.42)):
            deg = (amp_m / LIFT_PER_DEG[side]) * math.sin((t * cycles + phase) * math.tau)
            pb = rig.pose.bones[M + side + "ForeArm"]
            pb.rotation_quaternion = pb.rotation_quaternion @ Euler(
                (0.0, 0.0, math.radians(deg)), 'XYZ').to_quaternion()
        # a shallow breath through the chest so the torso is not a statue
        for bone, k in ((M + "Spine", 1.0), (M + "Spine1", 0.7), (M + "Spine2", 0.5)):
            pb = rig.pose.bones[bone]
            pb.rotation_quaternion = pb.rotation_quaternion @ Euler(
                (math.radians(0.9 * k * math.sin(t * math.tau * 2.0)), 0, 0),
                'XYZ').to_quaternion()
        bpy.context.view_layer.update()
        key_all(rig, cbag, i + 1)
    for fc in cbag.fcurves:
        fc.update()
    return act


def build_hold(rig, n=90, amp_m=0.012):
    """The tray-hold: he called it a walking or idle tray-holding pose. Barely moves -
    a slow weight shift and a small tray settle, nothing that breaks his grip."""
    d = load("pose_tray_hold_caleb.json")
    act, slot, cbag = new_action("chow_tray_hold")
    if rig.animation_data is None:
        rig.animation_data_create()
    for i in range(n):
        t = i / float(n)
        stamp(rig, d["bones"])
        s = math.sin(t * math.tau)
        for side in ("Left", "Right"):
            deg = (amp_m / LIFT_PER_DEG[side]) * s
            pb = rig.pose.bones[M + side + "ForeArm"]
            pb.rotation_quaternion = pb.rotation_quaternion @ Euler(
                (0.0, 0.0, math.radians(deg)), 'XYZ').to_quaternion()
        for bone, k in ((M + "Spine", 1.0), (M + "Spine1", 0.6)):
            pb = rig.pose.bones[bone]
            pb.rotation_quaternion = pb.rotation_quaternion @ Euler(
                (0.0, 0.0, math.radians(1.1 * k * s)), 'XYZ').to_quaternion()
        bpy.context.view_layer.update()
        key_all(rig, cbag, i + 1)
    for fc in cbag.fcurves:
        fc.update()
    return act


def report(rig, act, label, tray_z=None):
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    sc = bpy.context.scene
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    lo = [9, 9]; hi = [-9, -9]; drop = -9
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        for j, side in enumerate(("Left", "Right")):
            z = (rig.matrix_world @ rig.pose.bones[M + side + "Hand"].head).z
            lo[j] = min(lo[j], z); hi[j] = max(hi[j], z)
            e = (rig.matrix_world @ rig.pose.bones[M + side + "ForeArm"].head).z
            drop = max(drop, e - z)
    print("  %-18s L %.3f-%.3f (%.0f mm)  R %.3f-%.3f (%.0f mm)  elbow-above-hand %+.3f"
          % (label, lo[0], hi[0], (hi[0]-lo[0])*1000, lo[1], hi[1], (hi[1]-lo[1])*1000, drop))
    if tray_z is not None:
        print("                     tray top %.3f - hands stay %s"
              % (tray_z, "ABOVE it" if min(lo) > tray_z else "!! BELOW IT"))


print("=== clips from Caleb's stances ===")
eat_rig = bpy.data.objects["PSXRig_eater0"]
a1 = build_eat(eat_rig)
report(eat_rig, a1, "chow_eat_seated", tray_z=0.755)

hold_rig = bpy.data.objects["PSXRig_line1"]
a2 = build_hold(hold_rig)
report(hold_rig, a2, "chow_tray_hold")
print("\nboth clips rebuilt from his poses, fake users set")
