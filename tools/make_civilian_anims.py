"""CIVILIAN ANIMATIONS - work and fear, the two things the library has none of.

    blender -b -P tools/make_civilian_anims.py

Authored on ONE reference body (civ_farmer_m) and written to a workbench blend for
Caleb to scrub and correct. Once he signs them off they get merged into
anim_library.glb, and EVERY civilian - and the VC, who share the same PSXRig - picks
them up for free. That is the whole point of the shared library: author once, and the
skeleton is the contract.

DERIVED, NOT KEYED FROM SCRATCH. Each clip starts from an existing clip and rewrites
only what has to change: panic_run keeps running_unarmed's LEGS (which are good, and
are Caleb's) and rewrites the upper body into a panic. A hand-keyed run built from a
blank timeline would look like a puppet, and the legs are the hardest part.

THE AXES ARE MEASURED, NOT ASSUMED (hard rule: never guess in Blender). A +30 degree
test rotation on each bone's local axis, reading where the tip actually went:

    spine / neck / head    +X = bend FORWARD          +Z = lean to his RIGHT
    arms                   +X = LOWER the arm         (so raising it is -X)
    left arm               +Z = swing FORWARD
    RIGHT arm              +Z = swing BACKWARD        (mirrored! -Z is forward)
    hips / knees           +X = swing the limb FORWARD (so bending a knee is -X)
    every bone             +Y = roll about its own length (the tip does not move)

Every one of those would have been a coin-flip by assumption, and three of them are
the opposite of the naive guess.
"""
import bpy, math, os
from mathutils import Vector, Quaternion, Euler

SRC = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\civ_farmer_m.blend"
OUT = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\civ_anim_workbench.blend"
RIG = "PSXRig"
M = "mixamorig:"

TAU = math.tau


def rad(d):
    return math.radians(d)


# ---------------------------------------------------------------- the clips
# offset(bone) -> (rx, ry, rz) in RADIANS, in the bone's LOCAL frame, as a function
# of phase t (0..1 through the clip). Returned angles are ADDED on top of the source
# clip's pose, so the source's motion survives underneath.
def panic_run(t):
    """Not a soldier's sprint. Arms up and flailing, head snapping back over the
    shoulder to see what is chasing him. The legs are running_unarmed's, untouched."""
    flail = math.sin(t * TAU * 2.0)
    look = math.sin(t * TAU)          # head sweeps back and forth
    return {
        M + "Spine":        (rad(10), 0, 0),                 # thrown forward
        M + "Spine1":       (rad(6), 0, 0),
        M + "LeftArm":      (rad(-95 + 12 * flail), 0, rad(25)),
        M + "RightArm":     (rad(-95 - 12 * flail), 0, rad(-25)),
        M + "LeftForeArm":  (rad(-55 - 15 * flail), 0, 0),
        M + "RightForeArm": (rad(-55 + 15 * flail), 0, 0),
        M + "Neck":         (rad(-5), 0, rad(18 * look)),
        M + "Head":         (rad(-8), 0, rad(30 * look)),    # looking BACK
    }


def cower(t):
    """Curled down, arms clamped over the head. The single most important civilian
    pose in the game: it is what he does when the shooting starts, and it is what the
    player sees before he decides."""
    tremble = math.sin(t * TAU * 6.0) * 0.35 + math.sin(t * TAU * 11.0) * 0.2
    return {
        M + "Spine":        (rad(28), 0, 0),
        M + "Spine1":       (rad(22), 0, 0),
        M + "Spine2":       (rad(16), 0, 0),
        M + "Neck":         (rad(20), 0, 0),
        M + "Head":         (rad(18), 0, 0),                 # tucked
        M + "LeftArm":      (rad(-125 + tremble), 0, rad(38)),
        M + "RightArm":     (rad(-125 + tremble), 0, rad(-38)),
        M + "LeftForeArm":  (rad(-105), 0, 0),               # forearms over the skull
        M + "RightForeArm": (rad(-105), 0, 0),
    }


def hands_up(t):
    """Surrender. Standing, arms up, elbows bent. He is showing you his hands."""
    sway = math.sin(t * TAU) * 2.0
    return {
        M + "Spine":        (rad(-3), 0, 0),
        M + "LeftArm":      (rad(-118), 0, rad(22 + sway)),
        M + "RightArm":     (rad(-118), 0, rad(-22 - sway)),
        M + "LeftForeArm":  (rad(-88), 0, 0),
        M + "RightForeArm": (rad(-88), 0, 0),
        M + "Head":         (rad(-6), 0, 0),                 # chin up, watching you
    }


def squat_idle(t):
    """The villager squat - heels down, backside near the ankles. You see it on every
    doorstep and every dyke in the country, and nobody in a war game ever animates it."""
    breathe = math.sin(t * TAU) * 1.5
    return {
        M + "LeftUpLeg":    (rad(78), 0, rad(14)),           # thighs up and splayed
        M + "RightUpLeg":   (rad(78), 0, rad(-14)),
        M + "LeftLeg":      (rad(-125), 0, 0),               # knees folded HARD
        M + "RightLeg":     (rad(-125), 0, 0),
        M + "LeftFoot":     (rad(38), 0, 0),
        M + "RightFoot":    (rad(38), 0, 0),
        M + "Spine":        (rad(14 + breathe), 0, 0),
        M + "Spine1":       (rad(8), 0, 0),
        M + "LeftArm":      (rad(28), 0, rad(12)),           # forearms on the knees
        M + "RightArm":     (rad(28), 0, rad(-12)),
        M + "LeftForeArm":  (rad(-62), 0, 0),
        M + "RightForeArm": (rad(-62), 0, 0),
    }


def farm_transplant(t):
    """Bent double, planting seedlings into water. The back does the work and the
    arms just dip. This is the pose the whole country was in."""
    dip = math.sin(t * TAU)                    # one plant per cycle
    return {
        M + "Spine":        (rad(46 + 5 * dip), 0, 0),
        M + "Spine1":       (rad(30 + 4 * dip), 0, 0),
        M + "Spine2":       (rad(16), 0, 0),
        M + "Neck":         (rad(10), 0, 0),
        M + "Head":         (rad(8), 0, 0),                  # eyes on the water
        M + "LeftUpLeg":    (rad(12), 0, 0),                 # knees soft
        M + "RightUpLeg":   (rad(12), 0, 0),
        M + "LeftLeg":      (rad(-16), 0, 0),
        M + "RightLeg":     (rad(-16), 0, 0),
        M + "LeftArm":      (rad(52 + 14 * dip), 0, rad(20)),
        M + "RightArm":     (rad(52 - 14 * dip), 0, rad(-20)),
        M + "LeftForeArm":  (rad(-38 - 18 * dip), 0, 0),
        M + "RightForeArm": (rad(-38 + 18 * dip), 0, 0),
    }


def farm_harvest(t):
    """Left hand gathers a fistful of stalks, right hand sweeps the sickle through
    them. One cut per cycle. The sickle is bone-parented to the right hand, so it
    comes along for free - that is what the locker is FOR."""
    sweep = math.sin(t * TAU)
    grab = math.cos(t * TAU)
    return {
        M + "Spine":        (rad(38), 0, rad(-6 * sweep)),
        M + "Spine1":       (rad(24), 0, 0),
        M + "Spine2":       (rad(12), 0, 0),
        M + "Neck":         (rad(12), 0, 0),
        M + "Head":         (rad(10), 0, 0),
        M + "LeftUpLeg":    (rad(10), 0, 0),
        M + "RightUpLeg":   (rad(10), 0, 0),
        M + "LeftLeg":      (rad(-14), 0, 0),
        M + "RightLeg":     (rad(-14), 0, 0),
        M + "LeftArm":      (rad(58 + 8 * grab), 0, rad(26)),
        M + "LeftForeArm":  (rad(-46), 0, 0),
        # the cutting arm: LOWER (+X) and sweep. Right arm's -Z is FORWARD (measured).
        M + "RightArm":     (rad(50), 0, rad(-30 - 30 * sweep)),
        M + "RightForeArm": (rad(-58 + 20 * sweep), 0, 0),
    }


def carry_pole_walk(t):
    """Walking under the don ganh. The pole rides the shoulders; the hands go up to
    steady it, and the whole body has to stay stacked under the load."""
    return {
        M + "Spine":        (rad(4), 0, 0),
        M + "LeftArm":      (rad(-58), 0, rad(6)),           # hands up to the pole
        M + "RightArm":     (rad(-58), 0, rad(-6)),
        M + "LeftForeArm":  (rad(-52), 0, 0),
        M + "RightForeArm": (rad(-52), 0, 0),
        M + "Neck":         (rad(-4), 0, 0),
    }


CLIPS = [
    # name,                source clip,        offset fn,        frames, hips_dz
    ("civ_panic_run",      "running_unarmed",  panic_run,        None,   0.0),
    ("civ_cower",          "idle_crouching",   cower,            48,     -0.10),
    ("civ_hands_up",       "idle_unarmed",     hands_up,         48,     0.0),
    ("civ_squat_idle",     "idle_crouching",   squat_idle,       64,     -0.26),
    ("civ_farm_transplant","idle_unarmed",     farm_transplant,  56,     -0.06),
    ("civ_farm_harvest",   "idle_unarmed",     farm_harvest,     56,     -0.04),
    ("civ_carry_pole_walk","walking_unarmed",  carry_pole_walk,  None,   0.0),
]


def solve_arm(rig, side, target, tries=140):
    """Put the HAND where it needs to be, and let the shoulder and elbow work it out.

    WHY THIS EXISTS: arm angles are expressed in the bone's LOCAL frame, and that
    frame rides the spine. Bend the torso 47 degrees forward and "raise the arm"
    (-X, measured) no longer sends the hand up - it sends it up and BEHIND him. That
    is how the cower came out as a swan dive and the transplant came out with his
    arms pointing backwards. You cannot author arm angles against a moving parent by
    eye; you can only state where the hand goes and solve.

    Coordinate descent on (arm.x, arm.z, forearm.x). Crude, deterministic, and it
    converges in a few dozen evaluations because the arm is a 2-link chain.
    """
    arm = rig.pose.bones[M + side + "Arm"]
    fore = rig.pose.bones[M + side + "ForeArm"]
    hand = rig.pose.bones[M + side + "Hand"]
    for pb in (arm, fore):
        pb.rotation_mode = 'XYZ'

    best = [arm.rotation_euler.x, arm.rotation_euler.z, fore.rotation_euler.x]

    def err(p):
        arm.rotation_euler = Euler((p[0], 0.0, p[1]), 'XYZ')
        fore.rotation_euler = Euler((p[2], 0.0, 0.0), 'XYZ')
        bpy.context.view_layer.update()
        return ((rig.matrix_world @ hand.head) - target).length

    e = err(best)
    step = [rad(50), rad(50), rad(50)]
    for _ in range(tries):
        improved = False
        for i in range(3):
            for s in (+1, -1):
                cand = list(best)
                cand[i] += s * step[i]
                cand[i] = max(-math.pi, min(math.pi, cand[i]))
                ce = err(cand)
                if ce < e - 1e-5:
                    best, e = cand, ce
                    improved = True
        if not improved:
            step = [s * 0.55 for s in step]
            if max(step) < rad(0.4):
                break
    err(best)
    return best, e


def channelbag(action, rig):
    """Blender 5 slotted actions: the F-curves live in a channelbag."""
    if not action.layers:
        return None
    strip = action.layers[0].strips[0]
    slot = action.slots[0] if len(action.slots) else None
    return strip.channelbag(slot) if slot else None


def sample(rig, action, n_frames):
    """Bake the SOURCE clip: read every bone's pose at every frame. Never trust an
    F-curve to exist for a bone you want - sample the evaluated pose instead."""
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    if len(action.slots):
        rig.animation_data.action_slot = action.slots[0]
    rig.data.pose_position = 'POSE'
    f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
    src_n = f1 - f0 + 1
    out = []
    for i in range(n_frames):
        f = f0 + (i % src_n)
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        pose = {}
        for pb in rig.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pose[pb.name] = (pb.rotation_quaternion.copy(), pb.location.copy())
        out.append(pose)
    return out


def build(rig, name, src_name, fn, n_frames, hips_dz):
    src = bpy.data.actions.get(src_name)
    if src is None:
        print("  SKIP %s: no source clip %s" % (name, src_name))
        return None
    if n_frames is None:
        n_frames = int(src.frame_range[1] - src.frame_range[0]) + 1
    frames = sample(rig, src, n_frames)

    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    layer = act.layers.new("base")
    strip = layer.strips.new(type='KEYFRAME')
    cbag = strip.channelbag(slot, ensure=True)

    hips = M + "Hips"
    for i, pose in enumerate(frames):
        t = i / float(n_frames)          # phase, 0..1
        off = fn(t)
        f = i + 1
        for bone, (q, loc) in pose.items():
            q2 = q.copy()
            if bone in off:
                rx, ry, rz = off[bone]
                q2 = q2 @ Euler((rx, ry, rz), 'XYZ').to_quaternion()
            path = 'pose.bones["%s"].rotation_quaternion' % bone
            for idx, val in enumerate((q2.w, q2.x, q2.y, q2.z)):
                fc = cbag.fcurves.find(path, index=idx) or cbag.fcurves.new(path, index=idx)
                fc.keyframe_points.insert(f, val, options={'FAST'})
            if bone == hips:
                lpath = 'pose.bones["%s"].location' % bone
                l = loc.copy()
                # Hips location is in the HIPS' OWN rest frame, not world. Convert the
                # world-space drop we want into that frame or the man leans instead of
                # crouching. (Same trap as fix_laying_breathless.)
                rest = rig.data.bones[hips].matrix_local.to_3x3()
                w2a = rig.matrix_world.to_3x3().inverted()
                l += rest.inverted() @ (w2a @ Vector((0.0, 0.0, hips_dz)))
                for idx, val in enumerate((l.x, l.y, l.z)):
                    fc = cbag.fcurves.find(lpath, index=idx) or cbag.fcurves.new(lpath, index=idx)
                    fc.keyframe_points.insert(f, val, options={'FAST'})
    for fc in cbag.fcurves:
        fc.update()
    return act


def measure(rig, act):
    """VERIFY, do not assert. Read the pose back out of the finished clip in WORLD
    space: how far is he bent, where are his hands, which way is he looking."""
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    mid = (f0 + f1) // 2
    bpy.context.scene.frame_set(mid)
    bpy.context.view_layer.update()

    def w(b):
        return rig.matrix_world @ rig.pose.bones[M + b].head

    hips, neck = w("Hips"), w("Neck")
    spine = (neck - hips)
    pitch = math.degrees(math.atan2(-spine.y, spine.z))       # + = bent forward
    lh, rh = w("LeftHand"), w("RightHand")
    head_dir = (rig.matrix_world.to_3x3()
                @ rig.pose.bones[M + "Head"].matrix.to_3x3() @ Vector((0, 1, 0)))
    yaw = math.degrees(math.atan2(head_dir.x, -head_dir.y))
    return dict(pitch=pitch, hip_z=hips.z, lh_z=lh.z, rh_z=rh.z, yaw=yaw)


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    print("=== civilian clips, authored on civ_farmer_m ===\n")
    print("%-20s %-18s %6s %8s %8s %8s %8s"
          % ("clip", "derived from", "frames", "torso", "hip z", "handL z", "head yaw"))
    made = []
    for name, src, fn, n, dz in CLIPS:
        act = build(rig, name, src, fn, n, dz)
        if act is None:
            continue
        m = measure(rig, act)
        made.append(name)
        print("%-20s %-18s %6d %7.0f%s %8.2f %8.2f %8.0f%s"
              % (name, src, int(act.frame_range[1]), m["pitch"], "d",
                 m["hip_z"], m["lh_z"], m["yaw"], "d"))

    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("\n%d clips -> %s" % (len(made), OUT))
    print("(torso: + = bent forward, 0 = upright.  hip z: standing is ~1.05)")


if __name__ == "__main__":
    main()
