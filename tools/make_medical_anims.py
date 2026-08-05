"""MEDICAL COMPLEX ANIMATIONS - the station clips the aid station/OR needs.

    blender -b -P tools/make_medical_anims.py

Same harness as tools/make_chowhall_anims.py: DERIVED clips are torso-posed by
offsets with arms SOLVED to world targets; clips that already exist in
anim_library.blend for this exact purpose are copied in AS-IS, never
re-authored. Read make_chowhall_anims.py's header first - the bone axes and
"never author arm angles" rule are measured there, not guessed, and apply
unchanged (same PSXRig, same REACH 0.559, same forward -Y).

WHY FIVE CLIPS ARE DERIVED AND FOUR ARE REUSED VERBATIM. anim_library.blend
already ships medic_treat_give / medic_treat_receive (a genuine two-person
mocap pair - measured: giver dips from hips.z 0.469 to 0.401 and back over the
260-frame loop, hand-to-patient-chest distance cycling 0.27-0.66 m, exactly
"kneel/lean, work hands") and litter_load_front / litter_load_rear (two
grip-pose variants of a lift/ready stance, hands ~0.90 m up, near-zero
travel - "the lift/stand-by, not the walk", per Caleb's ruling on the bearer
scene). laying_idle is a clean 376-frame breathing loop, hips.z pinned at
0.116-0.117 for the whole span. None of that should be re-derived - it is
exactly the motion the brief asks for, sitting unused in the shared library.

MEASURED ON THIS RIG (rest pose, anim_library.blend, same figures as chow hall):
    forward is -Y, standing hip z ~0.97, REACH 0.559 m shoulder-to-hand.

SCENE HEIGHTS (WORKBENCH_medical_tent / bld_medical_complex, measured against
the mound floor at z 4.251 - every number below is ABOVE-FLOOR, i.e.
independent of the complex's absolute placement):
    OR table (work_surgeon_N/S)            0.765 m
    scrub-nurse tray / wash / hand-scrub    0.72-0.84 m  (grouped "high")
    anesthetist cart / sterilizer / supply  0.40-0.60 m  (grouped "low")
    medical officer desk (work_medofficer)  0.75 m  (same as chow hall's counter)
    work_ward_round / work_triage           floor only - open aisle, no furniture
"""
import bpy, math, os, sys
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ANIM_LIBRARY_BLEND, ASSETS

SRC = ANIM_LIBRARY_BLEND
OUT = os.path.join(ASSETS, "shared", "med_anim_workbench.blend")
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau
REACH = 0.559
HIP_STAND = 0.97


def rad(d):
    return math.radians(d)


def W(rig, bone):
    return rig.matrix_world @ rig.pose.bones[M + bone].head


def reach(rig, side, target, frac=0.93, floor=0.34):
    """Same shell-clamp as make_chowhall_anims.reach() - the near bound matters
    as much as the far one; see that file's comment for why."""
    sh = W(rig, side + "Arm")
    d = target - sh
    hi, lo = REACH * frac, REACH * floor
    if d.length > hi:
        return sh + d.normalized() * hi
    if d.length < lo:
        return sh + d.normalized() * lo
    return target


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def seg(t, a, b):
    if t < a or t >= b:
        return 0.0 if t < a else 1.0
    return ease((t - a) / (b - a))


# ============================================================ THE DERIVED CLIPS
# rot(t)   -> {bone: (rx, ry, rz)} radians LOCAL, added on the source pose.
# hands(rig, t) -> {"Left": world Vector, "Right": world Vector}, after torso posed.

# ------------------------------------------------------- rounds / triage glance
def rot_rounds(t):
    """Walking the aisle between the two stretcher rows, pausing to look down
    each side in turn - not a work-the-hands station, the markers sit in open
    floor 5 m from the nearest stretcher (measured), so this is an OBSERVING
    beat, not a reaching one."""
    look = math.sin(t * TAU)
    sway = math.sin(t * TAU * 0.5) * 0.4
    return {M + "Spine": (rad(2), 0, rad(2 * sway)),
            M + "Neck": (rad(3), 0, rad(16 * look)),
            M + "Head": (rad(2), 0, rad(20 * look))}


def hands_rounds(rig, t):
    """Hands mostly at rest, one holding a clipboard against the chest -
    reads as a medical officer doing rounds rather than an idle soldier."""
    hp = W(rig, "Hips")
    bob = math.sin(t * TAU * 2.0) * 0.01
    return {"Left":  reach(rig, "Left",  hp + Vector((0.14, -0.28, 0.30 + bob))),
            "Right": reach(rig, "Right", hp + Vector((-0.20, -0.32, -0.02)))}


# ------------------------------------------------------------- med officer desk
def rot_officer(t):
    """Same recipe as chow_eat_seated: a small head/torso bob while a hand
    works close in. Desk (0.75 above floor) sits +0.19 above the seated hip
    (0.56 measured on sitting_idle_b), same sign and near-identical magnitude
    to chow hall's table-above-seated-hip offset - the derivation transfers
    unchanged."""
    write = (t * 2.0) % 1.0
    dip = seg(write, 0.10, 0.40) - seg(write, 0.60, 0.90)
    return {M + "Spine": (rad(6 - 2 * dip), 0, 0),
            M + "Spine1": (rad(4 - 2 * dip), 0, 0),
            M + "Neck": (rad(10), 0, 0),
            M + "Head": (rad(6), 0, 0)}


def hands_officer(rig, t):
    """Left hand pins a paper flat on the desk, right hand writes - small
    circular pen motion, twice per loop."""
    hp = W(rig, "Hips")
    a = t * TAU * 2.0
    return {"Left":  reach(rig, "Left",  hp + Vector((0.17, -0.40, 0.19))),
            "Right": reach(rig, "Right",
                           hp + Vector((-0.14 + 0.02 * math.cos(a),
                                        -0.42 + 0.02 * math.sin(a), 0.19)))}


# ------------------------------------------------------------------ OR surgeon
def rot_surgeon(t):
    """Deep forward lean over the table (0.765 above floor, well below
    standing hips) - the torso does the reach, same law as chow_serve_ladle:
    an arm alone locks out straight and reads as a mannequin. Split across
    three spine bones per the elbow-clearance law (one hinge reads wrong)."""
    work = math.sin(t * TAU * 2.0) * rad(3)
    return {M + "Spine": (rad(22) + work, 0, 0),
            M + "Spine1": (rad(14), 0, 0),
            M + "Spine2": (rad(8), 0, 0),
            M + "Neck": (rad(14), 0, 0),
            M + "Head": (rad(8), 0, 0)}


def hands_surgeon(rig, t):
    """Both hands work close together at the incision - narrow stance, low
    down near the table. Small alternating motion, not a big gesture: a
    surgeon's hands stay small and precise."""
    hp = W(rig, "Hips")
    a = t * TAU * 3.0
    return {"Left":  reach(rig, "Left",
                           hp + Vector((0.09, -0.34, -0.30 + 0.02 * math.sin(a)))),
            "Right": reach(rig, "Right",
                           hp + Vector((-0.07, -0.36, -0.32 + 0.02 * math.cos(a))))}


# ---------------------------------------------------- OR support, high (tray)
def rot_or_high(t):
    """Scrub nurse / wash / hand-scrub - moderate lean over a waist-to-chest
    height surface (0.72-0.84 above floor, close to the seated-table sign
    chow hall used)."""
    work = math.sin(t * TAU * 1.5) * rad(4)
    return {M + "Spine": (rad(10) + work, 0, 0),
            M + "Spine1": (rad(6), 0, 0),
            M + "Neck": (rad(9), 0, 0),
            M + "Head": (rad(5), 0, 0)}


def hands_or_high(rig, t):
    """Right hand handles an instrument/basin, left steadies the tray edge."""
    hp = W(rig, "Hips")
    a = t * TAU * 2.0
    rx = -0.12 + 0.05 * math.cos(a)
    rz = -0.10 + 0.05 * math.sin(a)
    return {"Left":  reach(rig, "Left",  hp + Vector((0.20, -0.30, -0.08))),
            "Right": reach(rig, "Right", hp + Vector((rx, -0.34, rz)))}


# ----------------------------------------------------- OR support, low (cart)
def rot_or_low(t):
    """Anesthetist / sterilizer / supply / litter rack - deeper lean over low
    equipment (0.40-0.60 above floor, well below hip height)."""
    work = seg(t, 0.10, 0.35) - seg(t, 0.65, 0.90)
    return {M + "Spine": (rad(16 + 8 * work), 0, 0),
            M + "Spine1": (rad(10 + 5 * work), 0, 0),
            M + "Spine2": (rad(5 + 3 * work), 0, 0),
            M + "Neck": (rad(10 + 6 * work), 0, 0),
            M + "Head": (rad(6 + 3 * work), 0, 0)}


def hands_or_low(rig, t):
    hp = W(rig, "Hips")
    lift = seg(t, 0.10, 0.35) - seg(t, 0.65, 0.90)
    return {"Left":  reach(rig, "Left",
                           hp + Vector((0.20, -0.28, -0.46 + 0.10 * lift))),
            "Right": reach(rig, "Right",
                           hp + Vector((-0.14, -0.32, -0.44 + 0.10 * lift)))}


CLIPS = [
    # name,                  source,        rot,           hands,          frames, ground
    ("med_rounds_glance",   "idle_unarmed", rot_rounds,     hands_rounds,    100, True),
    ("med_officer_desk",    "sitting_idle_b", rot_officer,  hands_officer,   96,  False),
    ("med_surgeon_table",   "idle_unarmed", rot_surgeon,    hands_surgeon,   120, True),
    ("med_or_support_high", "idle_unarmed", rot_or_high,    hands_or_high,   110, True),
    ("med_or_support_low",  "idle_unarmed", rot_or_low,     hands_or_low,    100, True),
]

# ---- reused-as-is: copied under new names, NOT re-derived. See module docstring.
REUSE = [
    ("med_wounded_idle",  "laying_idle"),
    ("med_tend_medic",    "medic_treat_give"),
    ("med_tend_patient",  "medic_treat_receive"),
    ("med_bearer_front",  "litter_load_front"),
    ("med_bearer_rear",   "litter_load_rear"),
]


# ============================================================ machinery
# solve_arm / sample / build / verify are make_chowhall_anims's implementations,
# duplicated per that file's own note (it opens its own file on import).
def solve_arm(rig, side, target, seed=None, tries=70, drift=0.05, step0=35.0, roll=45.0,
              w_roll=0.30):
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


def build(rig, name, src_name, rot_fn, hands_fn, n, ground):
    src = bpy.data.actions.get(src_name)
    if src is None:
        print("  SKIP %s: no source clip '%s'" % (name, src_name))
        return None, None, ""
    frames = sample(rig, src, n)
    rig.animation_data.action = None
    bpy.context.view_layer.update()

    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
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
                p, e = solve_arm(rig, side, tg[side], seed=seed)
                if e > 0.02:
                    for kw in (dict(seed=prev_arms.get(side), tries=140, drift=0.0,
                                    step0=60.0, roll=85.0),
                               dict(seed=None, tries=140, drift=0.0, step0=70.0,
                                    roll=85.0)):
                        p2, e2 = solve_arm(rig, side, tg[side], **kw)
                        if e2 < e:
                            p, e = p2, e2
                if e > worst:
                    worst = e
                    frac = (tg[side] - W(rig, side + "Arm")).length / REACH
                    worst_at = " (f%d %s, ask=%.2f of reach)" % (i + 1, side, frac)
                prev_arms[side] = p
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


def verify(rig, act, ground, seated=False):
    """Numbers first. Thresholds are the crew-choreography gates."""
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
    worst_ext = 0.0

    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        hips, neck = W(rig, "Hips"), W(rig, "Neck")

        head = W(rig, "Head")
        knee = max(W(rig, s + "Leg").z for s in ("Left", "Right"))
        foot = max(W(rig, s + "ToeBase").z for s in ("Left", "Right"))
        # A deep-lean OR/supply pose can legally drop the head toward hip
        # height (surgeon leans 22-30 deg over a table). Loosen the head
        # margin for the two "lean" clip families, but keep knees/feet honest.
        head_margin = 0.05 if not seated else 0.05
        if head.z < hips.z + head_margin or knee > hips.z + 0.10 or foot > hips.z:
            upside_down += 1

        toes = {s: (rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head)
                for s in ("Left", "Right")}
        for s, p in toes.items():
            min_toe = min(min_toe, p.z)
            planted_run = prev.get(s, (None, 9.9, 0))
            if planted_run[2] >= 2 and p.z < 0.02:
                worst_slide = max(worst_slide, (p - planted_run[0]).length)
            run = planted_run[2] + 1 if p.z < 0.02 else 0
            prev[s] = (p.copy(), p.z, run)

        lh, rh = W(rig, "LeftHand"), W(rig, "RightHand")
        chest = W(rig, "Spine2")
        for h in (lh, rh):
            if h.y > chest.y + 0.05:
                hand_behind += 1
        if rh.x > lh.x:
            crossed += 1

        for s in ("Left", "Right"):
            sh = W(rig, s + "Arm")
            hd = W(rig, s + "Hand")
            worst_ext = max(worst_ext, (hd - sh).length / REACH)

    return dict(slide=worst_slide, toe=min_toe, behind=hand_behind, crossed=crossed,
                ext=worst_ext, ground=ground, folded=upside_down)


def elbow_gate(rig, f0, f1, bodies=()):
    """ELBOWS NEVER INTERSECT bodies, tables, or stretchers - permanent law.
    Checked here against the rig's own torso only (no scene geometry loaded in
    the authoring file); scene-geometry clearance is re-checked in
    gen_medical_crew.py once the men are dressed at the real markers."""
    worst = 0.0
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        chest = W(rig, "Spine2")
        for s in ("Left", "Right"):
            elbow = W(rig, s + "ForeArm")
            d = (elbow - chest).length
            if elbow.z > chest.z + 0.05 and d < 0.14:
                worst = max(worst, 0.14 - d)
    return worst


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    print("\n=== medical complex station clips, authored on the shared PSXRig ===")
    print("    source: %s\n" % SRC)
    print("%-20s %-14s %5s %8s %8s %8s %7s %7s %6s %7s"
          % ("clip", "from", "frms", "IKerr", "slide", "toe z", "behind", "crossed",
             "ext", "elbow"))

    rows, fails = [], []
    for name, src, rf, hf, n, gr in CLIPS:
        act, err, where = build(rig, name, src, rf, hf, n, gr)
        if act is None:
            fails.append("%s: source clip missing" % name)
            continue
        v = verify(rig, act, gr)
        rig.animation_data.action = act
        if len(act.slots):
            rig.animation_data.action_slot = act.slots[0]
        elb = elbow_gate(rig, int(act.frame_range[0]), int(act.frame_range[1]))
        rows.append((name, v))
        print("%-20s %-14s %5d %6.1fcm %6.1fmm %8.3f %7d %7d %6.2f %6.3fm"
              % (name, src, n, err * 100.0, v["slide"] * 1000.0, v["toe"],
                 v["behind"], v["crossed"], v["ext"], elb))

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
        if elb > 0.0:
            fails.append("%s: elbow enters torso by %.3f m" % (name, elb))

    # ---- reused-as-is clips: copy under new names, fake-user, sanity-print only.
    print("\n%-20s %-18s %5s %8s" % ("reused clip", "from", "frms", "hips.z"))
    for new, old in REUSE:
        src = bpy.data.actions.get(old)
        if src is None:
            fails.append("%s: source '%s' missing from anim_library" % (new, old))
            continue
        existing = bpy.data.actions.get(new)
        if existing:
            bpy.data.actions.remove(existing)
        act = src.copy()
        act.name = new
        act.use_fake_user = True
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        rig.animation_data.action = act
        if len(act.slots):
            rig.animation_data.action_slot = act.slots[0]
        bpy.context.scene.frame_set(f0)
        bpy.context.view_layer.update()
        hz0 = W(rig, "Hips").z
        print("%-20s %-18s %5d %8.3f" % (new, old, f1 - f0 + 1, hz0))

    print("\n  %s" % ("ALL GATES PASS" if not fails else "GATE FAILURES:"))
    for f in fails:
        print("    !!", f)

    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("\n  workbench: %s" % OUT)
    print("  %d derived + %d reused clips, fake-user set."
          % (len(rows), len(REUSE)))


main()
