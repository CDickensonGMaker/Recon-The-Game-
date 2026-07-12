"""CIV_HANDS_UP, built from CALEB'S pose. Same rule as the cower: hold his pose, add
only the motion he named.

    blender -b -P tools/make_handsup_from_pose.py

His brief: "the animation should be them putting their hands up and shaking their
heads."

That is TWO clips, because it is two different things:

    civ_hands_up_raise   ONE-SHOT. Hands come up from a neutral stand. ~0.7s.
                         Built by interpolating from `idle_unarmed` into HIS pose -
                         so the start is Caleb's own idle and the end is Caleb's own
                         hands-up, and nothing in between is invented.
    civ_hands_up         LOOP. His pose, HELD, plus:
                           * the head shaking NO - the whole point of the clip. He is
                             not just surrendering, he is TALKING to you: I am not VC,
                             do not shoot. That negation is what tells the player this
                             one is communicating and not reaching for something.
                           * the chest breathing
                           * the hands trembling a little. A man holding his hands up
                             under a rifle is not statue-still and he is not waving.

NO IK. The solver is what made the arms flail - it re-solved cold every frame and
picked a different elbow each time. Caleb posed the arms; there is nothing to solve.
The SHOULDERS DO NOT MOVE.

HEAD-SHAKE AXIS, MEASURED - and my first table was MISLEADING. Rotating each axis
30 deg and watching where the FACE points:
    +X -> face pitches 30 deg   = a NOD ("yes")
    +Y -> face yaws   30 deg   = a SHAKE ("no")   <- this one
    +Z -> face does not turn   = a TILT (ear to shoulder)
The old table called +Y "roll, the tip does not move" - true, because the tip is
ALONG the bone. But the FACE yaws a full 30 deg. Watch the face, not the tip.
"""
import bpy, math, json, os
from mathutils import Vector, Quaternion, Euler

WB = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\civ_anim_workbench.blend"
POSE = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\caleb_handsup_pose.json"
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau

LOOP_NAME = "civ_hands_up"
RAISE_NAME = "civ_hands_up_raise"
LOOP_FRAMES = 84            # 3.5s - a head shake needs room to be a shake, not a tic
RAISE_FRAMES = 17           # ~0.7s. Fast: he is being aimed at.

SHAKE_DEG = 11.0            # head yaw, each way
BREATH_DEG = 4.0            # a standing chest barely rises - see calibrate note
TREMBLE_DEG = 1.4


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


def sample_action(rig, name):
    """Grab frame 1 of an existing clip as a plain pose dict."""
    act = bpy.data.actions.get(name)
    if act is None:
        return None
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    sc = bpy.context.scene
    f0 = int(act.frame_range[0])
    sc.frame_set(int(act.frame_range[1]))
    sc.frame_set(f0)
    bpy.context.view_layer.update()
    out = {pb.name: dict(q=list(pb.rotation_quaternion), loc=list(pb.location))
           for pb in rig.pose.bones}
    rig.animation_data.action = None
    bpy.context.view_layer.update()      # flush, or it clobbers the next frame we set
    return out


def chest_z(rig):
    return (rig.matrix_world @ rig.pose.bones[M + "Spine2"].head).z


def calibrate_breath(rig, pose):
    """NO SEARCH THIS TIME - and that is the finding.

    On the COWER he is folded double, so uncurling the spine lifts the chest a long
    way per degree and a 2.5cm target was easy. On HANDS_UP he is STANDING UPRIGHT,
    and rotating an already-straight spine swings the chest sideways rather than up:
    the search ran all the way to its 40-degree ceiling and still only bought 1.5cm.
    40 degrees of spine would visibly arch him backwards - a broken pose, to buy a
    centimetre nobody would see.

    So the mechanism is wrong for a standing man, and the honest thing is a small
    fixed lift. The head shake is what this clip is; the breath is texture."""
    return rad(BREATH_DEG)


def new_action(name):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    cbag = act.layers.new("base").strips.new(type='KEYFRAME').channelbag(slot, ensure=True)
    return act, cbag


def key_all(rig, cbag, f):
    for pb in rig.pose.bones:
        q = pb.rotation_quaternion
        p = 'pose.bones["%s"].rotation_quaternion' % pb.name
        for i, v in enumerate((q.w, q.x, q.y, q.z)):
            fc = cbag.fcurves.find(p, index=i) or cbag.fcurves.new(p, index=i)
            fc.keyframe_points.insert(f, v, options={'FAST'})
        if pb.name == M + "Hips":
            lp = 'pose.bones["%s"].location' % pb.name
            for i, v in enumerate(pb.location):
                fc = cbag.fcurves.find(lp, index=i) or cbag.fcurves.new(lp, index=i)
                fc.keyframe_points.insert(f, v, options={'FAST'})


def main():
    bpy.ops.wm.open_mainfile(filepath=WB)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'POSE'
    if rig.animation_data is None:
        rig.animation_data_create()

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

    stand = sample_action(rig, "idle_unarmed")
    rig.animation_data.action = None
    bpy.context.view_layer.update()

    amp = calibrate_breath(rig, pose)
    print("breath: %.1f deg of spine lift (fixed - see calibrate_breath)"
          % math.degrees(amp))

    # ---------------------------------------------------------------- the LOOP
    act, cbag = new_action(LOOP_NAME)
    chest = []
    for i in range(LOOP_FRAMES):
        t = i / float(LOOP_FRAMES)
        apply_pose(rig, pose)

        # HEAD SHAKING NO. Two beats per loop, and it DECAYS - a man does not shake his
        # head at a constant amplitude forever; he says no hard, then keeps saying it
        # smaller. +Z turns him to his RIGHT (measured on this rig).
        env = 0.55 + 0.45 * math.cos(t * TAU)          # strongest at the top of the loop
        shake = math.sin(t * TAU * 4.0) * env
        # Y, not Z. Z is a head TILT (ear to shoulder). Y is the yaw - the 'no'.
        for b, k in ((M + "Neck", 0.40), (M + "Head", 0.60)):
            pb = rig.pose.bones[b]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((0, rad(SHAKE_DEG) * shake * k, 0),
                                              'XYZ').to_quaternion())

        # BREATHE - the chest, by lifting the spine. Not the hips: moving the hips
        # lifts his feet off the ground.
        br = (math.sin(t * TAU * 0.75) * 0.5 + 0.5)
        for b, k in ((M + "Spine", 0.45), (M + "Spine1", 0.35), (M + "Spine2", 0.20)):
            pb = rig.pose.bones[b]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((-amp * k * br, 0, 0), 'XYZ').to_quaternion())

        # THE HANDS TREMBLE. Forearms only. The SHOULDERS DO NOT MOVE.
        w = rad(TREMBLE_DEG)
        for side, ph in (("Left", 0.0), ("Right", math.pi * 0.55)):
            pb = rig.pose.bones[M + side + "ForeArm"]
            a = (math.sin(t * TAU * 6.0 + ph) * 0.6
                 + math.sin(t * TAU * 9.0 + ph * 1.6) * 0.4)
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((w * a, 0, w * a * 0.5), 'XYZ').to_quaternion())
        bpy.context.view_layer.update()
        chest.append(chest_z(rig))
        key_all(rig, cbag, i + 1)
    for fc in cbag.fcurves:
        fc.update()

    # ------------------------------------------------------------- the RAISE
    # Interpolate from HIS idle into HIS hands-up. Ease out hard: the hands snap up,
    # then settle. Nothing in between is invented - both ends are his.
    ract, rbag = new_action(RAISE_NAME)
    for i in range(RAISE_FRAMES):
        u = i / float(RAISE_FRAMES - 1)
        e = 1.0 - (1.0 - u) ** 2.6                    # fast out of the gate, settles
        for pb in rig.pose.bones:
            a = stand.get(pb.name) if stand else None
            b = pose.get(pb.name)
            if b is None:
                continue
            qb = Quaternion(b["q"])
            lb = Vector(b["loc"])
            if a is None:
                qa, la = qb, lb
            else:
                qa, la = Quaternion(a["q"]), Vector(a["loc"])
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = qa.slerp(qb, e)
            pb.location = la.lerp(lb, e)
        bpy.context.view_layer.update()
        key_all(rig, rbag, i + 1)
    for fc in rbag.fcurves:
        fc.update()

    # ---------------------------------------------------------------- verify
    sc = bpy.context.scene
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]
    sh, yaw, toe = [], [], []
    prev, worst = None, 0.0
    for f in range(1, LOOP_FRAMES + 1):
        sc.frame_set(LOOP_FRAMES if f != LOOP_FRAMES else 1)
        sc.frame_set(f)
        bpy.context.view_layer.update()
        q = [rig.pose.bones[M + b].rotation_quaternion.copy()
             for b in ("LeftArm", "RightArm", "LeftForeArm", "RightForeArm")]
        if prev is not None:
            worst = max(worst, max(math.degrees(a.rotation_difference(b).angle)
                                   for a, b in zip(prev, q)))
        prev = q
        sh.append(rig.pose.bones[M + "LeftArm"].rotation_quaternion.copy())
        # Measure where his FACE points, not an axis. The old metric tracked the head's
        # local Z, which is INVARIANT under a rotation about Z - so it reported a 3.8deg
        # shake on an 11deg one. A metric that cannot see the thing it measures.
        m = rig.matrix_world @ rig.pose.bones[M + "Head"].matrix
        d = (m @ Vector((0, 0, -0.1))) - (m @ Vector((0, 0, 0)))
        d.normalize()
        yaw.append(math.degrees(math.atan2(d.x, -d.y)))
        toe.append(min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                       for s in ("Left", "Right")))
    print("\nMEASURED:")
    print("   shoulders move   %5.2f deg   (asked: not at all)"
          % max(math.degrees(sh[0].rotation_difference(x).angle) for x in sh))
    print("   head shake       %5.1f deg peak-to-peak" % (max(yaw) - min(yaw)))
    print("   chest travel     %5.1f cm" % ((max(chest) - min(chest)) * 100))
    print("   feet planted     toe z %.3f..%.3f" % (min(toe), max(toe)))
    print("   worst arm snap   %5.2f deg/frame" % worst)
    print("   raise            %d frames (%.2fs)" % (RAISE_FRAMES, RAISE_FRAMES / 24.0))

    rig.animation_data.action = None
    sc.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=WB)
    print("\nsaved:", os.path.basename(WB))


if __name__ == "__main__":
    main()
