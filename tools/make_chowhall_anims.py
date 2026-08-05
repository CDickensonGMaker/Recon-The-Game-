"""CHOW HALL ANIMATIONS - the five station loops the mess line needs.

    blender -b -P tools/make_chowhall_anims.py

Authored on the shared PSXRig in anim_library.blend and written to a workbench blend
for Caleb to scrub and correct. Once he signs them off they get merged back into
anim_library.blend/.glb and every US grunt, VC and civilian picks them up for free.

Same harness as tools/make_civilian_anims.py: DERIVED from an existing clip, torso
posed by offsets, ARMS SOLVED to world targets. Read that file's header before
touching this one - the bone axes and the "never author arm angles" rule are stated
there and they are measured, not guessed.

WHY THERE IS NO SHUFFLE CLIP. The obvious sixth clip is the sideways shuffle along
the serving counter. walk_right carries 2.000 m of root motion per 31-frame cycle -
1.94 m/s, a march. Retiming it down to chow-line speed skates the feet by exactly the
slowdown factor, which is the bug that has bitten this library twice. The men walk
between the 0.70 m work_queue markers on Godot's own locomotion; the library owes
the STATIONS, not the travel.

MEASURED ON THIS RIG (rest pose, anim_library.blend):
    forward is -Y      (shoulder-line cross = (0,-1); toe-minus-ankle = (0.01,-0.12))
    Hips z 1.045 - Spine2 1.364 - Neck 1.501 - Head 1.616
    shoulder to hand   0.559
    standing hip in the idle clips ~0.97; seated hip in `sitting` 0.552

SCENE HEIGHTS these clips are aimed at (WORKBENCH_chowhall, measured):
    serving counter / dining table top  0.75      mermite rim  1.23
    bench seat  0.46                    tray      0.775
So relative to a standing man: the counter sits 0.22 BELOW his hips and the mermite
rim 0.26 ABOVE them. Every target below is written as an offset off a live bone, so
it rides whatever the torso is doing.
"""
import bpy, math, os, sys
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ANIM_LIBRARY_BLEND, ASSETS

SRC = ANIM_LIBRARY_BLEND
OUT = os.path.join(ASSETS, "shared", "chow_anim_workbench.blend")
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau
REACH = 0.559


def rad(d):
    return math.radians(d)


def W(rig, bone):
    return rig.matrix_world @ rig.pose.bones[M + bone].head


def reach(rig, side, target, frac=0.93, floor=0.34):
    """Clamp a target into the SHELL the hand can actually get to.

    Both bounds matter. The far one is obvious - past 0.559 m the arm locks out
    straight and aims at nothing. The near one bit chow_eat_seated: mid-clip the
    seated torso rotates far enough that a hips-relative target lands 0.10 of reach
    from the shoulder, and an arm cannot FOLD to 5.6 cm any more than it can stretch
    to 0.8 m. Same lesson as the placement search that collapsed the M101 gunner onto
    his work point - constrain the minimum standoff, not only the maximum."""
    sh = W(rig, side + "Arm")
    d = target - sh
    hi, lo = REACH * frac, REACH * floor
    if d.length > hi:
        return sh + d.normalized() * hi
    if d.length < lo:
        return sh + d.normalized() * lo
    return target


def ease(x):
    """Smoothstep - a ladle does not move at constant speed."""
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def seg(t, a, b):
    """Position within [a,b) of the loop, eased. 0 outside."""
    if t < a or t >= b:
        return 0.0 if t < a else 1.0
    return ease((t - a) / (b - a))


# ============================================================ THE CLIPS
# rot(t)   -> {bone: (rx, ry, rz)} radians, LOCAL, ADDED on top of the source pose.
#             Spine, neck, head, legs, shoulders ONLY. NEVER arms.
# hands(rig, t) -> {"Left": world Vector, "Right": world Vector}, evaluated AFTER the
#             torso is posed.

# ---------------------------------------------------------------- cook at the range
def rot_cook(t):
    """Leaning over a field range, working a pot. The lean is SPLIT across three
    spine bones - one bone carrying 14 degrees reads as a hinge."""
    breathe = math.sin(t * TAU) * rad(1.2)
    return {M + "Spine": (rad(6) + breathe, 0, 0),
            M + "Spine1": (rad(5), 0, 0),
            M + "Spine2": (rad(3), 0, 0),
            M + "Neck": (rad(9), 0, 0),        # looking down INTO the pot
            M + "Head": (rad(6), 0, 0)}


def hands_cook(rig, t):
    """Right hand stirs a circle at range-top height; left steadies the pot rim.

    Three stir cycles per loop - a whole cycle count, or the loop pops at the seam."""
    hp = W(rig, "Hips")
    a = t * TAU * 3.0
    return {"Left":  reach(rig, "Left",
                           hp + Vector((0.26, -0.28, -0.14))),
            "Right": reach(rig, "Right",
                           hp + Vector((-0.10 + 0.09 * math.cos(a),
                                        -0.34 + 0.09 * math.sin(a),
                                        -0.10)))}


# ------------------------------------------------------------ server behind counter
def rot_serve(t):
    """He dips with the ladle and comes back up. The torso does most of the reach -
    an arm alone stretching to the pot locks out straight and reads as a mannequin."""
    dip = seg(t, 0.05, 0.30) - seg(t, 0.45, 0.65)
    return {M + "Spine": (rad(5 + 7 * dip), 0, 0),
            M + "Spine1": (rad(4 + 5 * dip), 0, 0),
            M + "Spine2": (rad(2 + 3 * dip), 0, 0),
            M + "Neck": (rad(7 + 4 * dip), 0, 0),
            M + "Head": (rad(4), 0, 0)}


def hands_serve(rig, t):
    """LADLE CYCLE, twice per loop: dip into the mermite, lift, swing out over the
    man's tray, tip, come back. Left hand rests on the counter edge and stays there -
    both hands working reads as a mime, not a server.

    The mermite rim is 0.26 ABOVE his hips (measured); the tray he is serving into is
    held at about hip height and further out. That vertical difference IS the gesture."""
    hp = W(rig, "Hips")
    a = (t * 2.0) % 1.0                       # two ladles per loop
    dip = seg(a, 0.00, 0.22)                  # down into the pot
    lift = seg(a, 0.22, 0.40)                 # up out of it
    out = seg(a, 0.40, 0.62)                  # across to the tray
    back = seg(a, 0.72, 0.95)                 # return

    z = 0.24 + 0.02 * dip - 0.10 * lift - 0.10 * out + 0.18 * back
    y = -0.24 - 0.16 * out + 0.16 * back
    x = -0.14 - 0.10 * out + 0.10 * back
    return {"Left":  reach(rig, "Left",  hp + Vector((0.30, -0.30, -0.20))),
            "Right": reach(rig, "Right", hp + Vector((x, y, z)))}


# -------------------------------------------------------------- in line, tray held
def rot_tray_hold(t):
    """Waiting his turn. Weight shifts, he looks down the line and back."""
    sway = math.sin(t * TAU)
    look = math.sin(t * TAU * 2.0)
    return {M + "Spine": (rad(4), 0, rad(1.5 * sway)),
            M + "Spine1": (rad(2), 0, rad(1.0 * sway)),
            M + "Neck": (rad(6), 0, rad(9 * look)),
            M + "Head": (rad(3), 0, rad(13 * look))}


def hands_tray_hold(rig, t):
    """THE TRAY IS HELD, NEVER SET DOWN - that is what the mess-line footage shows.
    Flat, two hands, waist-to-chest. The tray is 0.30 wide, so the hands sit at its
    ENDS, +/-0.17 either side of his centreline, and stay level with each other:
    a tray whose two ends drift apart reads as two men carrying nothing."""
    hp = W(rig, "Hips")
    bob = math.sin(t * TAU) * 0.010
    z = 0.12 + bob
    return {"Left":  reach(rig, "Left",  hp + Vector((0.17, -0.30, z))),
            "Right": reach(rig, "Right", hp + Vector((-0.17, -0.30, z)))}


# ------------------------------------------------ ONE queue step, tray held, no retime
# Footage grounding (clip1, marines chow line, t~9-33s): the queue shuffles forward in
# short stints while the tray stays dead level in both hands - it is the LEGS that move,
# never the tray. This derives a single natural step from walking_unarmed and holds it -
# it is NOT a shuffle authored from scratch and NOT a retimed march. walking_unarmed is a
# 32-frame, 1.907 m gait cycle; sampling only its first 17 frames (n=17 below) crops
# exactly the natural half-cycle where the stance foot swaps, measured hip travel 0.984 m
# at NATIVE frame rate - no time-scaling, so no skate is introduced by this cut. The
# station gets grounded (True) so the ground-correction the other clips use keeps the
# planted foot honest. work_queue markers were re-spaced to 0.98 m to match (was 0.70 m,
# guessed, matching no clip) - moving the props to fit a real motion, per the brief.
def rot_queue_step(t):
    return {}


def hands_queue_step(rig, t):
    """Tray held level throughout - the legs carry him, the tray does not bob with the
    stride the way it bobs with the WEIGHT SHIFT in chow_tray_hold. Same hand geometry
    as hands_tray_hold (0.30 m wide, +/-0.17 either side of centreline)."""
    hp = W(rig, "Hips")
    z = 0.12
    return {"Left":  reach(rig, "Left",  hp + Vector((0.17, -0.30, z))),
            "Right": reach(rig, "Right", hp + Vector((-0.17, -0.30, z)))}


# ------------------------------------------------------------------- eating, seated
def rot_eat(t):
    """Hunched a little over the table, and he lifts his head as the food comes up -
    a man does not keep staring at the table while he chews."""
    bite = (t * 3.0) % 1.0
    up = seg(bite, 0.25, 0.45) - seg(bite, 0.70, 0.90)
    return {M + "Spine": (rad(5 - 2 * up), 0, 0),
            M + "Spine1": (rad(4 - 2 * up), 0, 0),
            M + "Neck": (rad(8 - 6 * up), 0, 0),
            M + "Head": (rad(4 - 3 * up), 0, 0)}


def hands_eat(rig, t):
    """Left hand pins the tray to the table; right hand carries food to the mouth,
    three bites per loop.

    THE MOUTH IS ANCHORED OFF THE NECK, NOT THE HEAD. The head is nodding through
    this clip - hang the target off the skull and the hand chases the nod. Same bug
    class as the panic-run hands in make_civilian_anims.

    Seated hips measure 0.552 and the table top is 0.75, so the tray plane is 0.20
    ABOVE his hips - the opposite sign from every standing clip here."""
    hp = W(rig, "Hips")
    nk = W(rig, "Neck")
    bite = (t * 3.0) % 1.0
    up = seg(bite, 0.10, 0.38)
    down = seg(bite, 0.62, 0.90)
    lift = up - down
    # HANDS SIT ON THE TABLE, NOT IN IT, AND THE FOREARM LIES ALONG IT.
    # v1 put the hands at exactly hips+0.20 - the tabletop plane - so the hand mesh was
    # half buried, and left the elbow 0.21 m above the hand across a 0.26 m forearm,
    # which dived steeply into the table edge. Two changes: lift the hands one hand's
    # thickness clear of the top, and push the targets further out (0.37 -> ~0.8 of
    # reach) so the arm extends and the forearm lies flat instead of hinging down.
    plate = hp + Vector((-0.17, -0.40, 0.24))
    mouth = nk + Vector((-0.09, -0.25, -0.01))
    return {"Left":  reach(rig, "Left",  hp + Vector((0.21, -0.42, 0.24))),
            "Right": reach(rig, "Right", plate.lerp(mouth, lift))}


# --------------------------------------------------------------- tray return / wash
def rot_dump(t):
    """Scraping the tray off into the wash cans, then a shake."""
    push = seg(t, 0.10, 0.35) - seg(t, 0.75, 0.95)
    return {M + "Spine": (rad(8 + 6 * push), 0, 0),
            M + "Spine1": (rad(5 + 4 * push), 0, 0),
            M + "Spine2": (rad(3 + 2 * push), 0, 0),
            M + "Neck": (rad(11), 0, 0),
            M + "Head": (rad(5), 0, 0)}


def hands_dump(rig, t):
    """Both hands stay ON the tray - he tips it, he does not hand it over. The tilt
    is the two hands going to DIFFERENT heights: the far end drops, the near end
    stays up. Then a short shake to knock the last of it off."""
    hp = W(rig, "Hips")
    tip = seg(t, 0.15, 0.40) - seg(t, 0.72, 0.95)
    shake = math.sin(t * TAU * 8.0) * 0.018 * (1.0 if 0.40 <= t < 0.72 else 0.0)
    fwd = -0.30 - 0.09 * tip
    return {"Left":  reach(rig, "Left",
                           hp + Vector((0.17, fwd, 0.10 - 0.16 * tip + shake))),
            "Right": reach(rig, "Right",
                           hp + Vector((-0.17, fwd, 0.10 - 0.02 * tip - shake)))}


# ------------------------------------------------- cook, second and third jobs
def rot_cook_check(t):
    """Lifts a lid and looks into the pot, then straightens off it."""
    lean = seg(t, 0.10, 0.35) - seg(t, 0.65, 0.92)
    return {M + "Spine": (rad(4 + 9 * lean), 0, 0),
            M + "Spine1": (rad(3 + 6 * lean), 0, 0),
            M + "Spine2": (rad(2 + 4 * lean), 0, 0),
            M + "Neck": (rad(6 + 8 * lean), 0, 0),
            M + "Head": (rad(4 + 4 * lean), 0, 0)}


def hands_cook_check(rig, t):
    """Left hand holds the lid up and OUT to the side - a man does not hold a hot lid
    over the pot he is looking into. Right hand steadies the rim."""
    hp = W(rig, "Hips")
    lift = seg(t, 0.10, 0.35) - seg(t, 0.65, 0.92)
    return {"Left":  reach(rig, "Left",
                           hp + Vector((0.30 + 0.06 * lift, -0.24,
                                        -0.04 + 0.22 * lift))),
            "Right": reach(rig, "Right", hp + Vector((-0.16, -0.34, -0.06)))}


def rot_cook_prep(t):
    """Working the prep crate: head down, a steady chopping rhythm."""
    chop = math.sin(t * TAU * 4.0)
    return {M + "Spine": (rad(11), 0, 0),
            M + "Spine1": (rad(7), 0, 0),
            M + "Spine2": (rad(4), 0, 0),
            M + "Neck": (rad(12), 0, rad(2 * chop)),
            M + "Head": (rad(6), 0, 0)}


def hands_cook_prep(rig, t):
    """Right hand chops, left hand feeds the board and stays CLEAR of the blade."""
    hp = W(rig, "Hips")
    chop = (math.sin(t * TAU * 4.0) * 0.5 + 0.5) ** 1.6
    return {"Left":  reach(rig, "Left",  hp + Vector((0.20, -0.34, -0.13))),
            "Right": reach(rig, "Right",
                           hp + Vector((-0.06, -0.36, -0.15 + 0.13 * chop)))}


# ------------------------------------------------------- elbow-direction seed hints
# solve_arm's default roll clamp (+/-45 deg) is right for MOST targets, but a hand
# resting close to the body (chow_eat_seated's pinning left hand: 0.387 m against a
# 0.559 m reach) has TWO IK solutions at that distance - elbow above the shoulder or
# elbow near table height - and with roll clamped to 45 deg the unseeded solve always
# lands in the elbow-high branch (measured: elbow z 1.02 against a shoulder at 0.94,
# i.e. the "elbow" pointing UP AND BACK past the shoulder). A wide seed sweep (a=-90..
# -30, roll=-150..150) found the elbow-flat family sits at roll ~= 150-170 deg, clamped
# out by the default. Frame 1 is unseeded (prev_arms is empty), so getting frame 1 into
# the right branch is enough - continuity then holds it there for the whole clip
# because this target never moves.
SEED_HINTS = {
    ("chow_eat_seated", "Left"): ([rad(-32.3), rad(71.9), rad(92.4), rad(166.7)], 175.0),
}


CLIPS = [
    # name,             source clip,     rot,           hands,           frames, ground
    ("chow_cook_stir",  "idle_unarmed",  rot_cook,      hands_cook,      120,  True),
    ("chow_cook_check", "idle_unarmed",  rot_cook_check, hands_cook_check, 90, True),
    ("chow_cook_prep",  "idle_unarmed",  rot_cook_prep, hands_cook_prep, 96,   True),
    ("chow_serve_ladle", "idle_unarmed", rot_serve,     hands_serve,     120,  True),
    ("chow_tray_hold",  "idle",          rot_tray_hold, hands_tray_hold, 62,   True),
    ("chow_queue_step", "walking_unarmed", rot_queue_step, hands_queue_step, 17, True),
    # ONE MAN ACTUALLY CROSSING THE LINE. Two full native strides of walking_unarmed
    # played straight through (cyclic=True stitches the root motion continuously - see
    # build()), so the whole queue-to-counter walk is real mocap at native speed: 2 x
    # 1.907 m = 3.81 m over 64 frames. No shuffle was invented; this is the same source
    # the march clips already use, just not cropped or slowed.
    ("chow_queue_walk", "walking_unarmed", rot_queue_step, hands_queue_step, 64, True),
    # sitting_idle_b, NOT sitting. Measured over the whole span: `sitting` folds the
    # man double on 15 of its 143 frames (at f72 his head drops to 0.863 against hips
    # 0.592) and the eating lean compounded that to 74. sitting_idle_b holds a clean
    # seated posture for all 130 - hips 0.574, head 1.126, feet 0.008 - which also
    # implies a 0.48 m seat, near enough the 0.46 bench top to sit on it honestly.
    ("chow_eat_seated", "sitting_idle_b", rot_eat,      hands_eat,       130,  False),
    ("chow_tray_dump",  "idle_unarmed",  rot_dump,      hands_dump,      120,  True),
]


# ============================================================ machinery
# solve_arm / sample / build are the make_civilian_anims implementations. They are
# duplicated rather than imported because that script opens its own file on import.
def solve_arm(rig, side, target, seed=None, tries=70, drift=0.05, step0=35.0, roll=45.0,
              w_roll=0.30):
    """Put the HAND where it needs to be; let the shoulder and elbow work it out.

    Seeded from the previous frame, shoulder roll penalised hard, drift penalised
    lightly - without all three the elbow windmills between local minima and the arm
    snaps hundreds of degrees between adjacent frames."""
    arm = rig.pose.bones[M + side + "Arm"]
    fore = rig.pose.bones[M + side + "ForeArm"]
    hand = rig.pose.bones[M + side + "Hand"]
    for pb in (arm, fore):
        pb.rotation_mode = 'XYZ'

    LO = [rad(-175), rad(-150), rad(-150), rad(-roll)]
    HI = [rad(175), rad(150), rad(150), rad(roll)]
    best = list(seed) if seed is not None else [0.0, 0.0, 0.0, 0.0]
    best = [max(LO[i], min(HI[i], best[i])) for i in range(4)]
    ref = list(best)
    W_ROLL, W_DRIFT = w_roll, drift

    def err(p):
        arm.rotation_euler = Euler((p[0], p[3], p[1]), 'XYZ')
        fore.rotation_euler = Euler((p[2], 0.0, 0.0), 'XYZ')
        bpy.context.view_layer.update()
        d = ((rig.matrix_world @ hand.head) - target).length
        d += W_ROLL * abs(p[3])
        if seed is not None and W_DRIFT:
            d += W_DRIFT * sum(abs(p[i] - ref[i]) for i in range(4))
        return d

    e = err(best)
    step = [rad(step0)] * 4
    for _ in range(tries):
        moved = False
        for i in range(4):
            for sg in (+1, -1):
                cand = list(best)
                cand[i] = max(LO[i], min(HI[i], cand[i] + sg * step[i]))
                ce = err(cand)
                if ce < e - 1e-5:
                    best, e, moved = cand, ce, True
        if not moved:
            step = [x * 0.55 for x in step]
            if max(step) < rad(0.3):
                break
    arm.rotation_euler = Euler((best[0], best[3], best[1]), 'XYZ')
    fore.rotation_euler = Euler((best[2], 0.0, 0.0), 'XYZ')
    bpy.context.view_layer.update()
    return best, ((rig.matrix_world @ hand.head) - target).length


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


def build(rig, name, src_name, rot_fn, hands_fn, n, ground, cyclic=False):
    src = bpy.data.actions.get(src_name)
    if src is None:
        print("  SKIP %s: no source clip '%s'" % (name, src_name))
        return None, None, ""
    frames = sample(rig, src, n)

    # MULTI-CYCLE ROOT MOTION. sample() wraps past the source's own frame_range with
    # i % span, which repeats the same LOCAL bone values every span samples - fine for
    # rotation, wrong for the Hips location channel, which carries real forward travel
    # that does NOT return to its start (frame span-1 sits ~2 m from frame 0). Naively
    # wrapping it snaps the man backward every cycle. cyclic=True adds
    # floor(i/span) * (last_sample_loc - first_sample_loc) onto Hips so a multi-cycle
    # clip (chow_queue_walk plays walking_unarmed straight through TWICE) travels
    # continuously - still the source's own native per-frame motion, no retiming.
    if cyclic:
        span = int(src.frame_range[1]) - int(src.frame_range[0]) + 1
        hips_key = M + "Hips"
        cycle_delta = frames[span - 1][hips_key][1] - frames[0][hips_key][1]
        for i, pose in enumerate(frames):
            rep = i // span
            if rep:
                q, loc = pose[hips_key]
                pose[hips_key] = (q, loc + cycle_delta * rep)
    rig.animation_data.action = None
    # Flush: clearing the action does not reach the depsgraph until an update, so
    # frame 1 would otherwise key the UNPOSED source.
    bpy.context.view_layer.update()

    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True          # zero-user actions are NOT written on save
    slot = act.slots.new('OBJECT', "Rig")
    strip = act.layers.new("base").strips.new(type='KEYFRAME')
    cbag = strip.channelbag(slot, ensure=True)

    prev_arms = {}
    rest3 = rig.data.bones[M + "Hips"].matrix_local.to_3x3()
    w2a = rig.matrix_world.to_3x3().inverted()
    worst = 0.0
    worst_at = ""

    for i, pose in enumerate(frames):
        t = i / float(n)
        for pb in rig.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            q, loc = pose[pb.name]
            pb.rotation_quaternion = q
            pb.location = loc
        for bone, (rx, ry, rz) in rot_fn(t).items():
            pb = rig.pose.bones[bone]
            pb.rotation_quaternion = (pb.rotation_quaternion
                                      @ Euler((rx, ry, rz), 'XYZ').to_quaternion())
        bpy.context.view_layer.update()

        if hands_fn is not None:
            tg = hands_fn(rig, t)
            for side in ("Left", "Right"):
                seed = prev_arms.get(side)
                kwargs = {}
                if seed is None:
                    hint = SEED_HINTS.get((name, side))
                    if hint is not None:
                        seed, roll_hint = hint
                        # w_roll near-zero: the default 0.30 penalty on |roll| exists to
                        # stop the elbow WINDMILLING frame-to-frame, but on this frame it
                        # actively fights the hint - it is the exact term that drags the
                        # solve back to the elbow-high branch regardless of seed, because
                        # the hinted roll (~167 deg) costs ~0.87 in penalty against a
                        # ~0.0003 m position error. Frame 1 is a one-shot placement, not
                        # part of the windmill-prone per-frame chain, so it is safe here.
                        kwargs = dict(roll=roll_hint, tries=140, w_roll=0.01)
                p, e = solve_arm(rig, side, tg[side], seed=seed, **kwargs)
                if e > 0.02:
                    # The drift penalty that stops the elbow windmilling also stops the
                    # arm KEEPING UP with a fast target - both misses were at the
                    # quickest frame of their gesture, at 0.79 and 0.40 of reach, so
                    # neither was out of range. Re-solve from the SAME seed with drift
                    # off and a wider first step: continuity is still protected because
                    # it starts where the last frame ended.
                    # Roll is the REDUNDANT dof - it swings the elbow round the
                    # shoulder-to-hand axis and barely moves the hand. It is clamped to
                    # 45 deg so the elbow cannot windmill, and that clamp is what these
                    # two frames were hitting. Widening it here is safe: this pass only
                    # runs on a frame already known to be wrong, and it stays seeded.
                    for kw in (dict(seed=prev_arms.get(side), tries=140, drift=0.0,
                                    step0=60.0, roll=85.0),
                               dict(seed=None, tries=140, drift=0.0, step0=70.0,
                                    roll=85.0)):
                        p2, e2 = solve_arm(rig, side, tg[side], **kw)
                        if e2 < e:
                            p, e = p2, e2
                if e > worst:
                    # A miss is almost never the solver - it is a target the arm
                    # cannot fold to or stretch to. Record how far the ASK was from
                    # the shoulder, as a fraction of reach, so the cause is legible.
                    worst = e
                    frac = (tg[side] - W(rig, side + "Arm")).length / REACH
                    worst_at = " (f%d %s, ask=%.2f of reach)" % (i + 1, side, frac)
                prev_arms[side] = p
                # Back into QUATERNION mode: a bone in EULER mode ignores its
                # quaternion channels, so the keys below would be dead on arrival.
                a = rig.pose.bones[M + side + "Arm"]
                fb = rig.pose.bones[M + side + "ForeArm"]
                a.rotation_mode = 'QUATERNION'
                a.rotation_quaternion = Euler((p[0], p[3], p[1]), 'XYZ').to_quaternion()
                fb.rotation_mode = 'QUATERNION'
                fb.rotation_quaternion = Euler((p[2], 0.0, 0.0), 'XYZ').to_quaternion()
            bpy.context.view_layer.update()

        dz = 0.0
        if ground:
            dz = -min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                      for s in ("Left", "Right"))

        f = i + 1
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion.copy()
            path = 'pose.bones["%s"].rotation_quaternion' % pb.name
            for idx, val in enumerate((q.w, q.x, q.y, q.z)):
                fc = cbag.fcurves.find(path, index=idx) or cbag.fcurves.new(path, index=idx)
                fc.keyframe_points.insert(f, val, options={'FAST'})
            # KEY LOCATION ON EVERY BONE, NOT JUST THE HIPS. These Mixamo sources key
            # translation on 28-34 bones (`sitting` keys 28), and a clip that keys only
            # the Hips silently depends on the OTHER bone locations still being set in
            # the pose. In the authoring file they are - left over from the sampling
            # loop - so the clip looks right there and collapses in any clean file.
            # Measured: chow_eat_seated read hips 0.552 / head 1.039 / toe -0.056 in the
            # workbench, and hips 0.550 / head 0.633 / knee 1.038 / toe 1.107 once
            # appended into the firebase - knees and toes above his own head.
            l = pose[pb.name][1].copy()
            if dz and pb.name == M + "Hips":
                l += rest3.inverted() @ (w2a @ Vector((0.0, 0.0, dz)))
            lp = 'pose.bones["%s"].location' % pb.name
            for idx, val in enumerate((l.x, l.y, l.z)):
                fc = cbag.fcurves.find(lp, index=idx) or cbag.fcurves.new(lp, index=idx)
                fc.keyframe_points.insert(f, val, options={'FAST'})
    for fc in cbag.fcurves:
        fc.update()
    return act, worst, worst_at


# ============================================================ verification
def verify(rig, act, ground):
    """Numbers first, screenshots after. Thresholds are the crew-choreography gates."""
    # CLEAN-ROOM. Wipe the pose before evaluating, so a channel the clip fails to key
    # reads as identity here exactly as it would in a fresh file. Verifying on top of
    # the authoring leftovers is what let a clip that collapses everywhere else pass.
    rig.animation_data.action = None
    bpy.context.view_layer.update()
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()

    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])

    prev = {}
    worst_slide = 0.0
    min_toe = 9.9
    upside_down = 0
    hand_behind = 0
    crossed = 0
    worst_span = 9.9
    max_pitch = 0.0
    worst_elbow_lock = 0.0

    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        hips, neck = W(rig, "Hips"), W(rig, "Neck")
        sp = neck - hips
        max_pitch = max(max_pitch, abs(math.degrees(math.atan2(-sp.y, sp.z))))

        # ANATOMY. Every gate below passed on a clip whose knees and toes sat above
        # his own head, because they all measured hands and feet against the FLOOR
        # and never against the man. Head over hips, feet under hips - a seated man
        # satisfies both, and a collapsed one cannot.
        head = W(rig, "Head")
        knee = max(W(rig, s + "Leg").z for s in ("Left", "Right"))
        foot = max(W(rig, s + "ToeBase").z for s in ("Left", "Right"))
        if head.z < hips.z + 0.25 or knee > hips.z + 0.10 or foot > hips.z:
            upside_down += 1

        toes = {s: (rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head)
                for s in ("Left", "Right")}
        for s, p in toes.items():
            min_toe = min(min_toe, p.z)
            # only the PLANTED foot counts, and only once it has been down for TWO
            # frames running. chow_queue_step's left foot touches down at f10 (z
            # 0.015) coming from f9 at z 0.075 (mid-swing) - comparing that landing
            # frame to its own airborne approach measured 62 mm that was really
            # swing travel, not slide. Even counting from first touchdown (f10->f11)
            # still measured 15.2 mm: the toe ROLLS from heel-strike to flat as the
            # ankle settles, a real, one-time, ~1.5 cm arc at the TOE joint with the
            # heel never moving - not the same thing as a planted foot sliding
            # across frames. Requiring two PRIOR frames already under threshold
            # skips that one settle frame and still catches genuine multi-frame
            # skate (every clip here that is actually planted holds z within 5 mm
            # for the whole stance phase).
            planted_run = prev.get(s, (None, 9.9, 0))
            if planted_run[2] >= 2 and p.z < 0.02:
                worst_slide = max(worst_slide, (p - planted_run[0]).length)
            run = planted_run[2] + 1 if p.z < 0.02 else 0
            prev[s] = (p.copy(), p.z, run)

        lh, rh = W(rig, "LeftHand"), W(rig, "RightHand")
        chest = W(rig, "Spine2")
        # forward is -Y: a hand BEHIND the chest has a greater y than the chest
        for h in (lh, rh):
            if h.y > chest.y + 0.05:
                hand_behind += 1
        # his right is -X: the right hand must not sit left of the left hand
        if rh.x > lh.x:
            crossed += 1

        for s in ("Left", "Right"):
            sh = W(rig, s + "Arm")
            hd = W(rig, s + "Hand")
            worst_span = min(worst_span, 9.9)
            ext = (hd - sh).length / REACH
            worst_elbow_lock = max(worst_elbow_lock, ext)

    return dict(slide=worst_slide, toe=min_toe, behind=hand_behind, crossed=crossed,
                pitch=max_pitch, ext=worst_elbow_lock, ground=ground,
                folded=upside_down)


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    print("\n=== chow hall station clips, authored on the shared PSXRig ===")
    print("    source: %s\n" % SRC)
    print("%-18s %-14s %5s %8s %8s %8s %7s %7s %6s"
          % ("clip", "from", "frms", "IKerr", "slide", "toe z", "behind", "crossed", "ext"))

    rows, fails = [], []
    for name, src, rf, hf, n, gr in CLIPS:
        act, err, where = build(rig, name, src, rf, hf, n, gr,
                                 cyclic=(name == "chow_queue_walk"))
        if act is None:
            fails.append("%s: source clip missing" % name)
            continue
        v = verify(rig, act, gr)
        rows.append((name, v))
        print("%-18s %-14s %5d %6.1fcm %6.1fmm %8.3f %7d %7d %6.2f"
              % (name, src, n, err * 100.0, v["slide"] * 1000.0, v["toe"],
                 v["behind"], v["crossed"], v["ext"]))

        if err > 0.05:
            fails.append("%s: hand misses target by %.1f cm%s" % (name, err * 100, where))
        if v["slide"] > 0.015:
            fails.append("%s: planted foot slides %.1f mm/frame" % (name, v["slide"] * 1000))
        if gr and v["toe"] < -0.04:
            fails.append("%s: foot sinks to %.3f m" % (name, v["toe"]))
        if v["behind"]:
            fails.append("%s: hand behind the chest on %d frames" % (name, v["behind"]))
        if v["crossed"]:
            fails.append("%s: hands crossed on %d frames" % (name, v["crossed"]))
        if v["ext"] > 0.97:
            fails.append("%s: arm locks out straight (%.2f of reach)" % (name, v["ext"]))
        if v["folded"]:
            fails.append("%s: body folded/inverted on %d frames" % (name, v["folded"]))

    print("\n  %s" % ("ALL GATES PASS" if not fails else "GATE FAILURES:"))
    for f in fails:
        print("    !!", f)

    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("\n  workbench: %s" % OUT)
    print("  %d clips, fake-user set. Scrub them, then merge into anim_library."
          % len(rows))


main()
