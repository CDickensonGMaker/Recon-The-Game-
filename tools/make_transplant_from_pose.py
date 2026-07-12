"""CIV_FARM_TRANSPLANT, built from CALEB'S pose. Third clip on the pose-first rule.

    blender -b -P tools/make_transplant_from_pose.py

His brief: "we can just keep this pose here as the start and just have the arms go up
and down at this angle. i cant really get the model to go down more and from afar itll
read like they are working."

He is right, and it is the correct call: the arm REACH is 0.559 m, measured, so his
hands physically cannot get to the mud from a standing crouch - the rig will not do it
no matter how hard you drag. And at the range the player actually sees a paddy, the
SILHOUETTE is the read. A working rhythm sells it; an anatomically perfect bend that
nobody can see does not.

So: HIS POSE, HELD, and the arms dip. That is the whole clip.

  * both arms dip and lift, OUT OF PHASE - one goes down as the other comes up, which
    is what a man planting seedlings actually does (one hand holds the bunch, the other
    pushes them in) and it reads as WORK instead of as calisthenics.
  * the dip is calibrated by MEASUREMENT, not by eye: binary-search the shoulder angle
    until the hand actually travels the distance we want. How many degrees is 18cm of
    hand depends entirely on where his arm already is.
  * the forearm counter-rotates a little so the hand does not scoop.
  * a small spine bob rides along, because a man does not plant with a rigid back.
  * NO IK. The solver is what made the arms flail.
"""
import bpy, math, json, os
from mathutils import Vector, Quaternion, Euler

WB = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\civ_anim_workbench.blend"
POSE = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\caleb_transplant_pose.json"
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau

NAME = "civ_farm_transplant"
FRAMES = 40                 # ~1.7s: one plant per hand per cycle
DIP_M = 0.18                # how far the hand travels, vertically. MEASURED, not guessed.
FORE_FRAC = 0.45            # forearm counter-rotation, as a fraction of the shoulder
SPINE_DEG = 3.5


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


def hand_z(rig, side):
    return (rig.matrix_world @ rig.pose.bones[M + side + "Hand"].head).z


def lift_axis(rig, pose, side):
    """FIND the shoulder axis that actually lifts the hand. Do not assume one.

    I assumed +X (it LOWERS an arm, measured on the rest pose) - and on Caleb's posed
    right arm, +X swings the hand SIDEWAYS, not down. The calibration ran all the way
    to its 70-degree ceiling and still only bought 8cm of travel, against 21cm on the
    left. Same rotation, same rig, completely different result, because the two arms
    are posed differently.

    The axis a bone's rotation moves the hand along depends on WHERE THE ARM ALREADY
    IS. So measure it: nudge each of the three axes a degree, read how far the hand
    moved VERTICALLY, and take the gradient. That vector IS the "dip" axis for this
    arm in this pose."""
    a = rig.pose.bones[M + side + "Arm"]
    grad = []
    d = rad(2.0)
    for ax in range(3):
        apply_pose(rig, pose)
        bpy.context.view_layer.update()
        z0 = hand_z(rig, side)
        e = [0.0, 0.0, 0.0]
        e[ax] = d
        a.rotation_quaternion = (a.rotation_quaternion
                                 @ Euler(e, 'XYZ').to_quaternion())
        bpy.context.view_layer.update()
        grad.append(hand_z(rig, side) - z0)
    apply_pose(rig, pose)
    bpy.context.view_layer.update()
    v = Vector(grad)
    if v.length < 1e-6:
        return Vector((1.0, 0.0, 0.0))
    return v.normalized()          # points the way that LOWERS the hand


def dip(rig, side, axis, ang):
    """Rotate the shoulder about its measured lift axis; counter-rotate the forearm on
    the same axis so the hand keeps its attitude instead of scooping."""
    a = rig.pose.bones[M + side + "Arm"]
    f = rig.pose.bones[M + side + "ForeArm"]
    a.rotation_quaternion = (a.rotation_quaternion
                             @ Quaternion(axis, ang))
    f.rotation_quaternion = (f.rotation_quaternion
                             @ Quaternion(axis, -ang * FORE_FRAC))


def calibrate_dip(rig, pose, side, axis):
    """How many degrees along that axis is 18cm of hand? MEASURE IT. A search that
    returns exactly its bound has run out of room - it has not found an answer."""
    lo, hi = 0.0, rad(80.0)
    apply_pose(rig, pose)
    bpy.context.view_layer.update()
    base = hand_z(rig, side)
    for _ in range(22):
        mid = (lo + hi) * 0.5
        apply_pose(rig, pose)
        dip(rig, side, axis, mid)
        bpy.context.view_layer.update()
        if abs(hand_z(rig, side) - base) < DIP_M:
            lo = mid
        else:
            hi = mid
    apply_pose(rig, pose)
    bpy.context.view_layer.update()
    return (lo + hi) * 0.5


def main():
    bpy.ops.wm.open_mainfile(filepath=WB)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'POSE'
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = None
    bpy.context.view_layer.update()      # flush, or the old action clobbers frame 1

    data = json.load(open(POSE))
    pose = data["pose"]
    hatd = data["hat"]

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

    ax = {s: lift_axis(rig, pose, s) for s in ("Left", "Right")}
    amp = {s: calibrate_dip(rig, pose, s, ax[s]) for s in ("Left", "Right")}
    for s in ("Left", "Right"):
        print("%-5s lift axis (%+.2f,%+.2f,%+.2f)  %5.1f deg == %.0f cm of hand"
              % (s, ax[s].x, ax[s].y, ax[s].z, math.degrees(amp[s]), DIP_M * 100))

    old = bpy.data.actions.get(NAME)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(NAME)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    cbag = act.layers.new("base").strips.new(type='KEYFRAME').channelbag(slot, ensure=True)

    lz, rz = [], []
    for i in range(FRAMES):
        t = i / float(FRAMES)
        apply_pose(rig, pose)

        # OUT OF PHASE: one hand goes down as the other comes up. That is what planting
        # looks like - one hand feeds, the other pushes - and it reads as WORK rather
        # than as a man doing star jumps.
        # The dip is SHARP going down (a jab into the mud) and slower coming up.
        for side, ph in (("Left", 0.0), ("Right", math.pi)):
            u = (math.sin(t * TAU + ph) * 0.5 + 0.5)     # 0..1
            u = u ** 1.5                                  # quick down, lazy up
            dip(rig, side, ax[side], amp[side] * u)

        # a plant is not done with a rigid back
        bob = math.sin(t * TAU * 2.0)
        for b, k in ((M + "Spine", 0.5), (M + "Spine1", 0.3)):
            pb = rig.pose.bones[b]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((rad(SPINE_DEG) * k * bob, 0, 0),
                                              'XYZ').to_quaternion())
        bpy.context.view_layer.update()
        lz.append(hand_z(rig, "Left"))
        rz.append(hand_z(rig, "Right"))

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

    # ---- verify
    sc = bpy.context.scene
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]
    prev, worst, toe = None, 0.0, []
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
        toe.append(min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                       for s in ("Left", "Right")))
    print("\nMEASURED:")
    print("   left hand travels   %5.0f cm" % ((max(lz) - min(lz)) * 100))
    print("   right hand travels  %5.0f cm" % ((max(rz) - min(rz)) * 100))
    qa, qb = FRAMES // 4, (3 * FRAMES) // 4
    print("   out of phase?  quarter: L=%.2f R=%.2f   3/4: L=%.2f R=%.2f  -> %s"
          % (lz[qa], rz[qa], lz[qb], rz[qb],
             "YES, they oppose" if (lz[qa] - rz[qa]) * (lz[qb] - rz[qb]) < 0
             else "NO - they move together"))
    print("   feet planted        toe z %.3f..%.3f" % (min(toe), max(toe)))
    print("   worst arm snap      %5.2f deg/frame" % worst)

    rig.animation_data.action = None
    sc.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=WB)
    print("\nsaved:", os.path.basename(WB))


if __name__ == "__main__":
    main()
