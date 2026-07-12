"""CIV_COWER, built from CALEB'S pose. Not from mine.

    blender -b -P tools/make_cower_from_pose.py

He posed it in the workbench and said: "right where i have this at is the perfect
spot for the arms and hat. lock the hat to the head and just have the lower arms
wiggle you dont need to move the shoulders at all. and raise and lower the spine
2-3 cm up and down for a breathing effect."

So that is the whole brief, and everything my solver was doing is deleted:

  * HIS POSE IS THE BASE, held on every frame. No IK, no solving, no re-deriving.
    The IK was the thing that made the arms flail in the first place - it re-solved
    cold every frame and picked a different elbow each time. There is nothing to
    solve here: he already put the arms where they go.
  * THE SHOULDERS DO NOT MOVE. At all. Not a degree.
  * ONLY THE FOREARMS WIGGLE - a couple of degrees, two frequencies so it does not
    read as a metronome. That is the whole arm animation.
  * THE CHEST BREATHES 2-3cm, and it does it by UNCURLING THE SPINE, not by moving
    the hips. Bobbing the hips would lift his feet off the ground. The spine rotation
    is auto-calibrated below: rotate, MEASURE the chest, adjust, until the chest
    actually travels the 2.5cm he asked for. Do not guess the angle - the angle that
    gives 2.5cm of chest depends on how far he is already curled.
  * THE HAT IS HIS. His transform, on the Head bone, rigid. Copied verbatim.
"""
import bpy, math, json, os
from mathutils import Vector, Quaternion, Euler

# Open the WORKBENCH, not the source body: the workbench already holds the other six
# clips and Caleb's hat. Opening civ_farmer_m and saving over the workbench would
# delete his six other clips - and his hat.
SRC = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\civ_anim_workbench.blend"
POSE = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\caleb_cower_pose.json"
OUT = SRC
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau

NAME = "civ_cower"
FRAMES = 72                 # 3s at 24fps - a breath is slow
BREATH_CM = 0.025           # 2.5cm of chest travel, as asked
WIGGLE_DEG = 2.2            # the forearms, and NOTHING else


def rad(d):
    return math.radians(d)


def apply_pose(rig, pose):
    for pb in rig.pose.bones:
        d = pose.get(pb.name)
        if d is None:
            continue
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion(d["q"])
        pb.location = Vector(d["loc"])


def chest_z(rig):
    return (rig.matrix_world @ rig.pose.bones[M + "Spine2"].head).z


def calibrate_breath(rig, pose):
    """How many degrees of spine uncurl is 2.5cm of chest? MEASURE IT.

    It depends entirely on how far he is already curled - a man bent double moves his
    chest a long way per degree, a man standing straight barely moves it at all. So
    binary-search the angle against the actual measured chest height rather than
    picking a number that sounds right."""
    # bound generously: the first search returned EXACTLY 14.00 deg, which is a
    # binary search reporting that it ran out of room, not that it found an
    # answer. It only got 1.5cm of chest out of it.
    lo, hi = 0.0, rad(40.0)
    for _ in range(18):
        mid = (lo + hi) * 0.5
        apply_pose(rig, pose)
        for b, k in ((M + "Spine", 0.45), (M + "Spine1", 0.35), (M + "Spine2", 0.20)):
            pb = rig.pose.bones[b]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((-mid * k, 0, 0), 'XYZ').to_quaternion())
        bpy.context.view_layer.update()
        up = chest_z(rig)
        apply_pose(rig, pose)
        bpy.context.view_layer.update()
        base = chest_z(rig)
        if (up - base) < BREATH_CM:
            lo = mid
        else:
            hi = mid
    return (lo + hi) * 0.5


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'POSE'
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = None
    bpy.context.view_layer.update()          # flush, or the old action clobbers frame 1

    data = json.load(open(POSE))
    pose = data["pose"]
    hatd = data["hat"]

    # HIS HAT, verbatim, rigid on the Head bone
    hat = bpy.data.objects.get("hat_conical_worn")
    if hat is not None:
        hat.parent_bone = hatd["bone"]
        hat.rotation_mode = hatd["rot_mode"]
        hat.location = Vector(hatd["loc"])
        if hatd["rot_mode"] == 'QUATERNION':
            hat.rotation_quaternion = Quaternion(hatd["rot"])
        else:
            hat.rotation_euler = Euler(hatd["rot"], hatd["rot_mode"])
        hat.scale = Vector(hatd["scale"])

    amp = calibrate_breath(rig, pose)
    print("breath: %.2f deg of spine uncurl == %.1f cm of chest travel (measured)"
          % (math.degrees(amp), BREATH_CM * 100))

    old = bpy.data.actions.get(NAME)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(NAME)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    cbag = act.layers.new("base").strips.new(type='KEYFRAME').channelbag(slot, ensure=True)

    chest = []
    for i in range(FRAMES):
        t = i / float(FRAMES)
        apply_pose(rig, pose)

        # BREATHE: uncurl on the inhale, settle on the exhale. Slightly asymmetric -
        # a real breath is a quick draw and a slow let-go.
        br = math.sin(t * TAU)
        br = (br * 0.5 + 0.5) ** 1.35 * 2.0 - 1.0
        for b, k in ((M + "Spine", 0.45), (M + "Spine1", 0.35), (M + "Spine2", 0.20)):
            pb = rig.pose.bones[b]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((-amp * k * (br * 0.5 + 0.5), 0, 0),
                                              'XYZ').to_quaternion())

        # THE FOREARMS, AND NOTHING ELSE. Two frequencies, opposite phase per arm, so
        # it never reads as a metronome and never reads as symmetrical.
        w = rad(WIGGLE_DEG)
        for side, ph in (("Left", 0.0), ("Right", math.pi * 0.6)):
            pb = rig.pose.bones[M + side + "ForeArm"]
            a = (math.sin(t * TAU * 3.0 + ph) * 0.65
                 + math.sin(t * TAU * 5.0 + ph * 1.7) * 0.35)
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((w * a, 0, w * a * 0.4),
                                              'XYZ').to_quaternion())
        bpy.context.view_layer.update()
        chest.append(chest_z(rig))

        f = i + 1
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion
            p = 'pose.bones["%s"].rotation_quaternion' % pb.name
            for idx, v in enumerate((q.w, q.x, q.y, q.z)):
                fc = cbag.fcurves.find(p, index=idx) or cbag.fcurves.new(p, index=idx)
                fc.keyframe_points.insert(f, v, options={'FAST'})
            if pb.name == M + "Hips":
                lp = 'pose.bones["%s"].location' % pb.name
                for idx, v in enumerate(pb.location):
                    fc = cbag.fcurves.find(lp, index=idx) or cbag.fcurves.new(lp, index=idx)
                    fc.keyframe_points.insert(f, v, options={'FAST'})
    for fc in cbag.fcurves:
        fc.update()

    # VERIFY what he actually asked for
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]
    sc = bpy.context.scene
    sh, fa, toe = [], [], []
    prev = None
    worst = 0.0
    for f in range(1, FRAMES + 1):
        sc.frame_set(FRAMES if f != FRAMES else 1)
        sc.frame_set(f)
        bpy.context.view_layer.update()
        q = [rig.pose.bones[M + b].rotation_quaternion.copy()
             for b in ("LeftArm", "RightArm", "LeftForeArm", "RightForeArm")]
        if prev is not None:
            worst = max(worst, max(math.degrees(a.rotation_difference(b).angle)
                                   for a, b in zip(prev, q)))
        prev = q
        sh.append(rig.pose.bones[M + "LeftArm"].rotation_quaternion.copy())
        fa.append(rig.pose.bones[M + "LeftForeArm"].rotation_quaternion.copy())
        toe.append(min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                       for s in ("Left", "Right")))

    sh_move = max(math.degrees(sh[0].rotation_difference(x).angle) for x in sh)
    fa_move = max(math.degrees(fa[0].rotation_difference(x).angle) for x in fa)
    print("\nWHAT HE ASKED FOR, MEASURED:")
    print("   shoulders move   %5.2f deg   (he said: not at all)" % sh_move)
    print("   forearms wiggle  %5.2f deg   (he said: just a wiggle)" % fa_move)
    print("   chest travel     %5.1f cm    (he said: 2-3 cm)"
          % ((max(chest) - min(chest)) * 100.0))
    print("   feet stay on the deck: toe z %.3f..%.3f m" % (min(toe), max(toe)))
    print("   worst arm snap   %5.2f deg/frame (was 196 - that was the flailing)" % worst)

    rig.animation_data.action = None
    sc.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("\nsaved:", OUT)


if __name__ == "__main__":
    main()
