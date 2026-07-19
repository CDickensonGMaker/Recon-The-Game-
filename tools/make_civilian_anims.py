"""CIVILIAN ANIMATIONS - work and fear, the two things the shared library has none of.

    blender -b -P tools/make_civilian_anims.py

Authored on ONE reference body (civ_farmer_m) and written to a workbench blend for
Caleb to scrub and correct. Once he signs them off they get merged into
anim_library.glb, and EVERY civilian - and the VC, who share the same PSXRig - picks
them up for free. That is the point of the shared library: author once, and the
skeleton is the contract.

DERIVED, NOT KEYED FROM SCRATCH. Each clip starts from an existing clip and rewrites
only what must change: civ_panic_run keeps running_unarmed's LEGS (which are good,
and are Caleb's) and rewrites the upper body into a panic. A run hand-keyed from a
blank timeline looks like a puppet, and the legs are the hardest part of a run.

------------------------------------------------------------------------------
HARD RULE: NEVER GUESS IN BLENDER. Two things here are measured, not assumed:

1. THE BONE AXES. A +30 degree test rotation on each bone's local axis, reading
   where the tip actually went:
       spine / neck / head   +X = bend FORWARD        +Z = lean to his RIGHT
       arms                  +X = LOWER the arm       (so raising it is -X)
       LEFT arm              +Z = swing FORWARD
       RIGHT arm             +Z = swing BACKWARD      (mirrored - -Z is forward)
       hips / knees          +X = swing the limb FORWARD (so a knee bends on -X)
       every bone            +Y = roll about its own length; the tip does not move
   Three of those are the opposite of the naive guess.

2. THE ARMS ARE SOLVED, NOT POSED. Arm angles live in the bone's LOCAL frame, and
   that frame rides the spine. Bend the torso 47 degrees and "raise the arm" no
   longer sends the hand up - it sends it up and BEHIND him. My first pass authored
   arm ANGLES and the cower came out as a swan dive and the transplant came out with
   his arms pointing backwards. So the clips now state WHERE THE HAND GOES, in world
   space, against the already-posed torso, and a solver works out the shoulder and
   elbow. You cannot author an arm against a moving parent by eye.

3. THE FEET ARE GROUNDED BY MEASUREMENT. For the static clips the hips drop is not
   hand-tuned - the toes are measured after posing and the hips are dropped by
   exactly enough to put the lowest one on the deck.
------------------------------------------------------------------------------
"""
import bpy, math, os, sys
from mathutils import Vector, Quaternion, Euler, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import CIV_DIR, GEAR_ARMORY

SRC = os.path.join(CIV_DIR, "civ_farmer_m.blend")
OUT = os.path.join(CIV_DIR, "civ_anim_workbench.blend")
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau


def rad(d):
    return math.radians(d)


def W(rig, bone):
    return rig.matrix_world @ rig.pose.bones[M + bone].head


# MEASURED on this rig: upper arm 0.298 + forearm 0.260 = 0.559 m, shoulder to
# hand. A target past that is not a pose, it is a wish - the solver reports a
# 60cm miss and the arm locks out straight, pointing at nothing. That is exactly
# what "hands in the water" was: unreachable, so the arm just aimed at it.
REACH = 0.559


def reach(rig, side, target, frac=0.93):
    """Pull a target back onto the sphere the hand can actually get to."""
    sh = W(rig, side + "Arm")
    d = target - sh
    lim = REACH * frac
    return sh + d.normalized() * lim if d.length > lim else target


# ============================================================ THE CLIPS
# rot(t)   -> {bone: (rx, ry, rz)} radians, LOCAL frame, ADDED on top of the source.
#             Spine, neck, head and legs only. NEVER arms - see the header.
# hands(rig, t) -> {"Left": world Vector, "Right": world Vector}. Evaluated AFTER the
#             torso is posed, so it can hang targets off the head, the hips, the knee.

def rot_panic(t):
    look = math.sin(t * TAU)
    return {M + "Spine": (rad(12), 0, 0),
            M + "Spine1": (rad(7), 0, 0),
            M + "Neck": (rad(-6), 0, rad(20 * look)),
            M + "Head": (rad(-10), 0, rad(34 * look))}       # snapping a look back


def hands_panic(rig, t):
    """Hands up by his head as he runs. ANCHOR TO THE NECK, not the head - his head
    is WHIPPING BACK AND FORTH in this clip (that is the point of it), and a target
    hung off a whipping head whips too, which drags the arms after it. The neck is
    the stable thing to hang off. Measured: 35.8 deg/frame of arm snap before, and
    the target was doing it, not the solver."""
    flail = math.sin(t * TAU * 2.0)
    nk = W(rig, "Neck")
    return {"Left":  reach(rig, "Left",
                           nk + Vector((0.26, -0.10, 0.22 + 0.06 * flail))),
            "Right": reach(rig, "Right",
                           nk + Vector((-0.26, -0.10, 0.22 - 0.06 * flail)))}


def rot_cower(t):
    """A cower is not a POSE, it is a man flinching.

    v1 was a static curl with a 1-degree jitter on it - a statue with a tic. What a
    man under fire actually does is CYCLE: he tightens (shoulders to his ears, head
    deeper, spine curls harder), holds it, then eases off a fraction because he
    cannot hold that hard forever - and then something lands and he tightens again.
    That cycle is the whole read. It is also what tells the player he is ALIVE and
    not a prop, which is the entire reason the player has to decide about him.

    Two rhythms on top of each other:
      * FLINCH   ~2.5s, the big tighten-and-ease. This is the animation.
      * TREMBLE  fast, small, never still. This is what says he is terrified.

    HEAD: v1 tucked the skull to 122 degrees - past face-down - which threw the hat
    round the back of his skull and made it look like it had come off. He tucks his
    chin, he does not fold his neck in half. Measured back to ~95.
    """
    flinch = (math.sin(t * TAU - math.pi / 2.0) * 0.5 + 0.5) ** 2.2   # sharp in, slow out
    tremble = (math.sin(t * TAU * 9.0) * rad(0.9)
               + math.sin(t * TAU * 14.0) * rad(0.5))
    return {M + "Spine": (rad(20 + 7 * flinch) + tremble, 0, rad(2 * flinch)),
            M + "Spine1": (rad(15 + 5 * flinch), 0, 0),
            M + "Spine2": (rad(10 + 4 * flinch), 0, 0),
            # A LIGHT chin tuck. v1 folded the neck to 122 deg - past face-down - and
            # the hat went round the front of his skull. Measured back to ~60.
            M + "Neck": (rad(5 + 4 * flinch), 0, 0),
            M + "Head": (rad(4 + 3 * flinch), 0, 0),
            # the crouch does the work: he gets SMALL, he does not fold in half
            M + "LeftUpLeg": (rad(30 + 12 * flinch), 0, rad(5)),
            M + "RightUpLeg": (rad(30 + 12 * flinch), 0, rad(-5)),
            M + "LeftLeg": (rad(-48 - 16 * flinch), 0, 0),
            M + "RightLeg": (rad(-48 - 16 * flinch), 0, 0),
            M + "LeftFoot": (rad(18 + 6 * flinch), 0, 0),
            M + "RightFoot": (rad(18 + 6 * flinch), 0, 0),
            M + "LeftShoulder": (rad(-9 * flinch), 0, 0),
            M + "RightShoulder": (rad(-9 * flinch), 0, 0)}


def hands_cower(rig, t):
    """Forearms clamped over the crown, pressing HARDER on the flinch.

    ANCHOR TO THE NECK, NOT THE HEAD-TOP. HeadTop_End rides the skull, and a cowering
    man's skull is TUCKED - so HeadTop_End swings forward past his face, and "just
    above the head-top" becomes "out in front of his nose". That is exactly what it
    did: his arms came out in a stiff-arm instead of clamping down. The NECK does not
    tilt with the skull, so it is the only stable thing to hang a target off.

    A man protecting his head puts his hands on the crown in WORLD space - on top of
    whatever the skull is currently doing - so the target is straight up off the neck."""
    flinch = (math.sin(t * TAU - math.pi / 2.0) * 0.5 + 0.5) ** 2.2
    tr = math.sin(t * TAU * 11.0) * 0.010
    nk = W(rig, "Neck")
    up = 0.17 - 0.04 * flinch          # hands press DOWN onto the crown as he tightens
    fwd = 0.03 + 0.03 * flinch
    return {"Left":  reach(rig, "Left",
                           nk + Vector((0.13, fwd, up + tr))),
            "Right": reach(rig, "Right",
                           nk + Vector((-0.13, fwd, up - tr)))}


def rot_hands_up(t):
    return {M + "Spine": (rad(-2), 0, 0),
            M + "Head": (rad(-8), 0, 0)}                      # chin up, watching you


def hands_hands_up(rig, t):
    sway = math.sin(t * TAU) * 0.012
    ls, rs = W(rig, "LeftArm"), W(rig, "RightArm")
    return {"Left":  reach(rig, "Left",  ls + Vector((0.14 + sway, -0.14, 0.40))),
            "Right": reach(rig, "Right", rs + Vector((-0.14 - sway, -0.14, 0.40)))}


def rot_squat(t):
    br = math.sin(t * TAU) * rad(1.5)
    # a real squat: thigh comes up to horizontal, knee folds hard, ankle lets the
    # heel stay down. Derived from `idle` (STRAIGHT legs) - deriving it from
    # idle_crouching stacked a second bend on an already-bent knee and folded him in
    # half on the floor.
    # MEASURED, not eyeballed: at 96/-138 his hips sat at 0.20 m - that is not a
    # squat, that is sitting on his heels in a ball. A man squatting on a dyke rides
    # about 0.35 m. Backed the fold off until the measurement said so.
    return {M + "LeftUpLeg": (rad(82), 0, rad(15)),
            M + "RightUpLeg": (rad(82), 0, rad(-15)),
            M + "LeftLeg": (rad(-112), 0, 0),
            M + "RightLeg": (rad(-112), 0, 0),
            M + "LeftFoot": (rad(32), 0, 0),
            M + "RightFoot": (rad(32), 0, 0),
            M + "Spine": (rad(16) + br, 0, 0),
            M + "Spine1": (rad(9), 0, 0)}


def hands_squat(rig, t):
    lk, rk = W(rig, "LeftLeg"), W(rig, "RightLeg")            # the knees
    return {"Left":  reach(rig, "Left",  lk + Vector((0.03, -0.03, 0.03))),
            "Right": reach(rig, "Right", rk + Vector((-0.03, -0.03, 0.03)))}


def rot_transplant(t):
    dip = math.sin(t * TAU)
    # A transplanting back is near HORIZONTAL - about 90 degrees of total spine
    # bend - with soft knees. Anything less and the hands physically cannot get
    # to the water, which is what the 60cm IK miss was telling me.
    return {M + "Spine": (rad(40 + 4 * dip), 0, 0),
            M + "Spine1": (rad(34 + 3 * dip), 0, 0),
            M + "Spine2": (rad(20), 0, 0),
            # MEASURED: with the spine at ~94deg the skull came out at 99-106deg
            # from vertical - bent PAST face-down. He has to LIFT his head to look
            # at the water, and that is also what stops the hat tipping off his
            # face. Neck and head lift hard against the spine.
            M + "Neck": (rad(-30), 0, 0),
            M + "Head": (rad(-26), 0, 0),
            M + "LeftUpLeg": (rad(26), 0, 0),
            M + "RightUpLeg": (rad(26), 0, 0),
            M + "LeftLeg": (rad(-36), 0, 0),
            M + "RightLeg": (rad(-36), 0, 0)}


def hands_transplant(rig, t):
    dip = math.sin(t * TAU)
    out = {}
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        sh = W(rig, side + "Arm")
        d = Vector((sx * 0.22, -0.30, -0.92 + 0.18 * dip * sx)).normalized()
        out[side] = sh + d * (REACH * 0.94)     # the arm HANGS to the water
    return out


def rot_harvest(t):
    sweep = math.sin(t * TAU)
    return {M + "Spine": (rad(34), 0, rad(-7 * sweep)),
            M + "Spine1": (rad(28), 0, 0),
            M + "Spine2": (rad(16), 0, 0),
            M + "Neck": (rad(-26), 0, 0),
            M + "Head": (rad(-24), 0, 0),
            M + "LeftUpLeg": (rad(22), 0, 0),
            M + "RightUpLeg": (rad(22), 0, 0),
            M + "LeftLeg": (rad(-32), 0, 0),
            M + "RightLeg": (rad(-32), 0, 0)}


def hands_harvest(rig, t):
    sweep = math.sin(t * TAU)
    shl, shr = W(rig, "LeftArm"), W(rig, "RightArm")
    # left fist holds the standing stalks steady, low and forward
    dl = Vector((0.30, -0.55, -0.78)).normalized()
    # right hand sweeps the sickle THROUGH them, right to left
    dr = Vector((-0.62 + 1.15 * (sweep * 0.5 + 0.5), -0.52, -0.62)).normalized()
    return {"Left":  shl + dl * (REACH * 0.92),
            "Right": shr + dr * (REACH * 0.90)}


def rot_pole(t):
    return {M + "Spine": (rad(5), 0, 0),
            M + "Neck": (rad(-4), 0, 0)}


def hands_pole(rig, t):
    s2 = W(rig, "Spine2")
    return {"Left":  reach(rig, "Left",  s2 + Vector((0.36, 0.02, 0.19))),
            "Right": reach(rig, "Right", s2 + Vector((-0.36, 0.02, 0.19)))}


CLIPS = [
    # name,               source,            rot,            hands,           frames, ground
    ("civ_panic_run",     "running_unarmed", rot_panic,      hands_panic,     None,  False),
    ("civ_cower",         "idle",            rot_cower,      hands_cower,     60,    True),
    ("civ_hands_up",      "idle_unarmed",    rot_hands_up,   hands_hands_up,  48,    True),
    ("civ_squat_idle",    "idle",            rot_squat,      hands_squat,     64,    True),
    ("civ_farm_transplant", "idle",          rot_transplant, hands_transplant, 56,   True),
    ("civ_farm_harvest",  "idle",            rot_harvest,    hands_harvest,   56,    True),
    ("civ_carry_pole_walk", "walking_unarmed", rot_pole,     hands_pole,      None,  False),
]


# ============================================================ machinery
def solve_arm(rig, side, target, seed=None, tries=70):
    """Put the HAND where it needs to be; let the shoulder and elbow work it out.

    THIS USED TO MAKE THE ARMS FLAIL. Solved cold on every frame, coordinate descent
    lands in a DIFFERENT local minimum from one frame to the next, and the arm snaps
    between them. Measured on the old clips: adjacent frames jumping 196, 307, 312
    degrees. Caleb: "you have the arms going all over the place."

    Three things fix it, and they are all about the arm having MORE FREEDOM THAN THE
    HAND NEEDS - a 2-link arm reaching a point has one whole redundant degree of
    freedom, and that DOF is the elbow swinging round the shoulder-to-hand axis:

      1. SEED FROM THE PREVIOUS FRAME. The solve starts where the last one ended, so
         it stays in the same basin instead of hopping to a new one.
      2. PENALISE SHOULDER ROLL. arm.y is the redundant DOF - it moves the ELBOW and
         does almost nothing to the hand. Left free, the elbow windmills. Caleb:
         "the elbows dont need to move all over the place."
      3. PENALISE MOVING AT ALL. A small cost on drifting from the seed, so of two
         equally good solutions it takes the one nearest where the arm already was.

    The hand still lands on target - these costs are ~1cm-scale next to the distance
    term. They only pick BETWEEN solutions that all hit it.
    """
    arm = rig.pose.bones[M + side + "Arm"]
    fore = rig.pose.bones[M + side + "ForeArm"]
    hand = rig.pose.bones[M + side + "Hand"]
    for pb in (arm, fore):
        pb.rotation_mode = 'XYZ'

    # [shoulder pitch, shoulder yaw, ELBOW, shoulder roll]
    LO = [rad(-175), rad(-150), rad(-150), rad(-45)]
    HI = [rad(175), rad(150), rad(150), rad(45)]     # roll clamped HARD: no windmill
    best = list(seed) if seed is not None else [0.0, 0.0, 0.0, 0.0]
    best = [max(LO[i], min(HI[i], best[i])) for i in range(4)]
    ref = list(best)

    W_ROLL = 0.30        # metres of "error" per radian of shoulder roll
    W_DRIFT = 0.05       # ... and per radian of moving away from last frame

    def err(p):
        arm.rotation_euler = Euler((p[0], p[3], p[1]), 'XYZ')
        fore.rotation_euler = Euler((p[2], 0.0, 0.0), 'XYZ')
        bpy.context.view_layer.update()
        d = ((rig.matrix_world @ hand.head) - target).length
        d += W_ROLL * abs(p[3])
        if seed is not None:
            d += W_DRIFT * sum(abs(p[i] - ref[i]) for i in range(4))
        return d

    e = err(best)
    step = [rad(35)] * 4
    for _ in range(tries):
        moved = False
        for i in range(4):
            for sg in (+1, -1):
                cand = list(best)
                cand[i] = max(LO[i], min(HI[i], cand[i] + sg * step[i]))
                ce = err(cand)
                if ce < e - 1e-5:
                    best, e = cand, ce
                    moved = True
        if not moved:
            step = [x * 0.55 for x in step]
            if max(step) < rad(0.3):
                break
    # report the TRUE hand miss, not the penalised score
    arm.rotation_euler = Euler((best[0], best[3], best[1]), 'XYZ')
    fore.rotation_euler = Euler((best[2], 0.0, 0.0), 'XYZ')
    bpy.context.view_layer.update()
    miss = ((rig.matrix_world @ hand.head) - target).length
    return best, miss


def sample(rig, action, n):
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    if len(action.slots):
        rig.animation_data.action_slot = action.slots[0]
    rig.data.pose_position = 'POSE'
    f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
    span = f1 - f0 + 1
    out = []
    for i in range(n):
        bpy.context.scene.frame_set(f0 + (i % span))
        bpy.context.view_layer.update()
        out.append({pb.name: (pb.rotation_quaternion.copy(), pb.location.copy())
                    for pb in rig.pose.bones})
    return out


def build(rig, name, src_name, rot_fn, hands_fn, n, ground):
    src = bpy.data.actions.get(src_name)
    if src is None:
        print("  SKIP %s: no source clip '%s'" % (name, src_name))
        return None, None
    if n is None:
        n = int(src.frame_range[1] - src.frame_range[0]) + 1
    frames = sample(rig, src, n)
    rig.animation_data.action = None
    # FLUSH IT. Clearing the action is not enough: the depsgraph has not processed
    # the removal yet, so the FIRST view_layer.update() inside the loop still has the
    # source clip driving and it overwrites the pose we just hand-set. The result was
    # frame 1 of every clip silently keying the UNPOSED source - a standing man at the
    # head of a cower, a transplant, a squat. Measured: at i=0 the spine went
    # +0.046 -> +0.303 (offset applied) -> +0.046 (clobbered). At i=1 it held.
    bpy.context.view_layer.update()

    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    strip = act.layers.new("base").strips.new(type='KEYFRAME')
    cbag = strip.channelbag(slot, ensure=True)

    prev_arms = {}          # last frame's solve, per side - the seed
    hips_b = rig.data.bones[M + "Hips"]
    rest3 = hips_b.matrix_local.to_3x3()
    w2a = rig.matrix_world.to_3x3().inverted()
    worst_err = 0.0

    for i, pose in enumerate(frames):
        t = i / float(n)
        off = rot_fn(t)

        # 1. lay down the source pose, then the torso/leg offsets
        for pb in rig.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            q, loc = pose[pb.name]
            pb.rotation_quaternion = q
            pb.location = loc
        for bone, (rx, ry, rz) in off.items():
            pb = rig.pose.bones[bone]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((rx, ry, rz), 'XYZ').to_quaternion())
        bpy.context.view_layer.update()

        # 2. NOW solve the arms, against the torso as it actually stands
        arms = {}
        if hands_fn is not None:
            tg = hands_fn(rig, t)
            for side in ("Left", "Right"):
                p, e = solve_arm(rig, side, tg[side], seed=prev_arms.get(side))
                worst_err = max(worst_err, e)
                arms[side] = p
                prev_arms[side] = p
                # PUT THE BONES BACK INTO QUATERNION MODE AND BAKE THE SOLVE IN.
                # solve_arm works in euler, and a pose bone in EULER mode IGNORES
                # its quaternion channels entirely - so every quaternion key I
                # wrote for the four arm bones was dead on arrival and the arms
                # were never animated at all. They just sat in whatever leftover
                # euler the solver last tried. Caleb saw it instantly: hands at
                # hip height, right hand behind his back.
                a = rig.pose.bones[M + side + "Arm"]
                fb = rig.pose.bones[M + side + "ForeArm"]
                qa = Euler((p[0], p[3], p[1]), 'XYZ').to_quaternion()
                qf = Euler((p[2], 0.0, 0.0), 'XYZ').to_quaternion()
                a.rotation_mode = 'QUATERNION'
                a.rotation_quaternion = qa
                fb.rotation_mode = 'QUATERNION'
                fb.rotation_quaternion = qf
            bpy.context.view_layer.update()

        # 3. feet on the deck, by measurement, not by hand-tuned hip drops
        dz = 0.0
        if ground:
            toe = min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                      for s in ("Left", "Right"))
            dz = -toe

        # 4. key it
        f = i + 1
        for pb in rig.pose.bones:
            nm = pb.name
            # every bone is back in QUATERNION mode now, arms included, so there
            # is no special case: read the pose and key it.
            q = pb.rotation_quaternion.copy()
            path = 'pose.bones["%s"].rotation_quaternion' % nm
            for idx, val in enumerate((q.w, q.x, q.y, q.z)):
                fc = cbag.fcurves.find(path, index=idx) or cbag.fcurves.new(path, index=idx)
                fc.keyframe_points.insert(f, val, options={'FAST'})
            if nm == M + "Hips":
                l = pose[nm][1].copy()
                if dz:
                    l += rest3.inverted() @ (w2a @ Vector((0.0, 0.0, dz)))
                lp = 'pose.bones["%s"].location' % nm
                for idx, val in enumerate((l.x, l.y, l.z)):
                    fc = cbag.fcurves.find(lp, index=idx) or cbag.fcurves.new(lp, index=idx)
                    fc.keyframe_points.insert(f, val, options={'FAST'})
    for fc in cbag.fcurves:
        fc.update()
    return act, worst_err


def measure(rig, act):
    """Verify by reading the finished clip back in WORLD space."""
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    mid = (f0 + f1) // 2
    # step OFF the frame first: frame_set() to the frame the scene is already on
    # is a no-op, the depsgraph never re-evaluates, and this read the PREVIOUS
    # clip's pose. The reported table was lying.
    bpy.context.scene.frame_set(f1 if mid != f1 else f0)
    bpy.context.scene.frame_set(mid)
    bpy.context.view_layer.update()
    hips, neck = W(rig, "Hips"), W(rig, "Neck")
    sp = neck - hips
    pitch = math.degrees(math.atan2(-sp.y, sp.z))
    toe = min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
              for s in ("Left", "Right"))
    return dict(pitch=pitch, hip=hips.z, toe=toe,
                lh=W(rig, "LeftHand").z, rh=W(rig, "RightHand").z)


# was locker/gear_library.blend — gone; the armory is its racked successor.
# Read-only append; prop names inside UNVERIFIED (Blender not run).
LOCKER = GEAR_ARMORY
BENCH_PROPS = {"rice_sickle": "RightHand", "carry_pole": "Spine2",
               "rice_basket_back": "Spine2", "rice_bundle": "LeftHand"}


def add_bench_props(rig):
    """Hang every prop on the reference body, HIDDEN.

    Caleb has to judge civ_farm_harvest against an actual sickle and
    civ_carry_pole_walk against an actual pole - a hand closing on thin air tells
    you nothing about whether the grip is right. Unhide the one you are working on."""
    n = 0
    for name, bone in BENCH_PROPS.items():
        before = set(bpy.data.objects)
        with bpy.data.libraries.load(LOCKER, link=False) as (src, dst):
            dst.objects = [o for o in src.objects if o == name]
        for o in dst.objects:
            if o is None:
                continue
            bpy.context.scene.collection.objects.link(o)
            o.parent = rig
            o.parent_type = 'BONE'
            o.parent_bone = M + bone
            o.matrix_parent_inverse = Matrix.Identity(4)
            bpy.context.view_layer.update()
            o.matrix_world = Matrix.Identity(4)   # locker verts are world/rest space
            bpy.context.view_layer.update()
            o.hide_set(True)
            o.hide_render = True
            n += 1
    return n


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    print("=== civilian clips, authored on civ_farmer_m ===\n")
    print("%-21s %-16s %5s %7s %6s %6s %6s %7s"
          % ("clip", "from", "frms", "torso", "hip z", "toe z", "handL", "IK err"))
    made = []
    for name, src, rf, hf, n, gr in CLIPS:
        act, err = build(rig, name, src, rf, hf, n, gr)
        if act is None:
            continue
        m = measure(rig, act)
        made.append(name)
        print("%-21s %-16s %5d %6.0fd %6.2f %6.3f %6.2f %6.1fcm"
              % (name, src, int(act.frame_range[1]), m["pitch"], m["hip"], m["toe"],
                 m["lh"], err * 100.0))
    np = add_bench_props(rig)
    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("(%d props hung on the bench body, hidden - unhide the one you are judging)" % np)
    print("\n%d clips -> %s" % (len(made), OUT))
    print("torso: + = bent forward.  toe z should be ~0.00 on the grounded clips.")
    print("IK err = how far the solver missed the hand target by.")


if __name__ == "__main__":
    main()
