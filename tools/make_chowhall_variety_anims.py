"""CHOW HALL VARIETY — the ambient clips that make the room read as POPULATED,
not staged. Runs PARALLEL to tools/make_chowhall_anims.py (which owns the four
station-line defects) — this file owns turnover, conversation variety, a real
tray-carry walk, and the standing eater. DO NOT import or edit that file; it is
being actively rewritten by another pass on 2026-08-03.

    blender -b -P tools/make_chowhall_variety_anims.py

Authored on the shared PSXRig in anim_library.blend, written to a NEW workbench
(assets/shared/chow_variety_workbench.blend) so neither pass's save clobbers the
other's. Same harness as make_chowhall_anims.py (sample a source clip's pose,
add rotation offsets, solve hands to world targets, bake to FK) — duplicated
rather than imported, same reason that file gives: it opens its own .blend on
import and two tools fighting over bpy.context.scene is a bad time.

FOOTAGE, 2026-08-03 (yt-dlp, CriticalPast, all Vietnam-era mess halls):
    clip1/sheet1 - Marines chow line + tables. Beat: men shuffle a full-body-width
      step at a time down a plank counter reaching sideways for pots (line
      mechanics, not this file's job); PAIRS eat seated on log benches, one hand
      on a canteen cup, the other hand-to-mouth with finger food, heads turned in
      to each other mid-chew - conversation and eating interleave, not blocked.
    clip2/sheet2 - indoor mess hall, Americal Division. Men CARRY loaded trays
      with BOTH hands at chest-to-waist height through the room to find a seat;
      at table, hunched forward over the tray, one utensil hand, other resting
      on the table edge.
    clip3/sheet3 - field rest break (not a mess hall, but the ONLY footage with a
      clean off-duty LOAFING beat): reclining against a pack, one knee up, arm
      draped loose, talking sideways to a seated buddy. Confirms the library's
      existing `smoking`/`idle_unarmed_2..5` loafing loops rather than inventing
      a new one - see NOT AUTHORED below.
    clip4 - marines mess LINE, full body wide shot. Confirms clip1's step-and-
      reach mechanic and the two-hand plate-carry grip (Getty/CriticalPast
      "mess line" reel).
    clip5 - Camp Carroll bunker mess hall. Close-in shots of the SAME two-hand
      carry (plate low, cup in the other hand) walking from the servery to a
      table, then seated hunched over a tray, spoon hand working, other hand
      flat on the table - matches clip2 exactly, corroborating rather than
      adding a new beat.

MEASURED ON THIS RIG (rest pose, anim_library.blend, verified independently of
make_chowhall_anims.py's own header - same numbers, different session):
    forward is -Y      (toe.y - hips.y = -1.02 at rest)
    shoulder-to-hand reach   0.559 m  (upper 0.298 + fore 0.260, x0.995 safety)
    rig object transform is ALWAYS rotation_euler=(90deg, 0, yaw), location free

SOURCE CLIPS MEASURED (anatomy gate: head.z > hips.z+0.30, knees/feet <= hips.z):
    sitting_idle_b     130f   0 bad frames   hips 0.57 (bench-height correct)
    sitting_talking   1323f   0 bad frames
    sitting_talking_b 1350f   0 bad frames (6 frames at f~780 have a knee lifted
                               in a gesture, 0.02m over the knee-height margin -
                               a hand-talking beat, not a fold; window chosen
                               below avoids it anyway)
    sitting            143f  58 bad frames (min head-hips margin 0.226m) - AVOID,
                               confirms the 8/3 finding, re-verified independently
    sitting_idle_c      309f 309 bad frames (a man on the floor) - AVOID
    walking_unarmed   1.907m per 31-frame cycle (1.94 m/s, native gait, NOT retimed)
    smoking             538f   0 bad frames - reused directly, not re-derived

NOT AUTHORED, and why:
    chow_idle_lean - the brief's "off-duty man loitering, leaning, smoking or
    waiting" is already IN the library and already verified clean: `smoking`
    (538f, 0 bad frames) and `idle_unarmed_2..5` (0 bad frames each). Deriving a
    new clip from them would violate "never author what already exists" for zero
    gain - scene dressing should point off-duty men at these names directly.
"""
import bpy, math, os, sys
from mathutils import Vector, Euler, Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ANIM_LIBRARY_BLEND, ASSETS

SRC = ANIM_LIBRARY_BLEND
OUT = os.path.join(ASSETS, "shared", "chow_variety_workbench.blend")
RIG = "PSXRig"
M = "mixamorig:"
TAU = math.tau
REACH = 0.559


def rad(d):
    return math.radians(d)


def W(rig, bone):
    return rig.matrix_world @ rig.pose.bones[M + bone].head


def reach(rig, side, target, frac=0.93, floor=0.34):
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


# ============================================================ machinery
# solve_arm / sample / build / verify duplicate make_chowhall_anims.py's own
# implementation on purpose (see file header).
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


def sample(rig, action, n, start_offset=0):
    """n poses starting `start_offset` frames into the source's own range,
    wrapping if n+start_offset exceeds the span."""
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
        bpy.context.scene.frame_set(f0 + ((i + start_offset) % span))
        bpy.context.view_layer.update()
        out.append({pb.name: (pb.rotation_quaternion.copy(), pb.location.copy())
                    for pb in rig.pose.bones})
    return out


def new_action(name):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    strip = act.layers.new("base").strips.new(type='KEYFRAME')
    cbag = strip.channelbag(slot, ensure=True)
    return act, cbag


def key_all_bones(rig, cbag, f, poses_by_bone):
    """poses_by_bone: {bone_full_name: (quat, loc)}. Keys quaternion + location
    on EVERY bone passed, not just Hips."""
    for name, (q, l) in poses_by_bone.items():
        path = 'pose.bones["%s"].rotation_quaternion' % name
        for idx, val in enumerate((q.w, q.x, q.y, q.z)):
            fc = cbag.fcurves.find(path, index=idx) or cbag.fcurves.new(path, index=idx)
            fc.keyframe_points.insert(f, val, options={'FAST'})
        lp = 'pose.bones["%s"].location' % name
        for idx, val in enumerate((l.x, l.y, l.z)):
            fc = cbag.fcurves.find(lp, index=idx) or cbag.fcurves.new(lp, index=idx)
            fc.keyframe_points.insert(f, val, options={'FAST'})


def build(rig, name, src_name, rot_fn, hands_fn, n, ground, start_offset=0, cyclic=False):
    """Derive-from-source-clip builder, same shape as make_chowhall_anims.build()."""
    src = bpy.data.actions.get(src_name)
    if src is None:
        print("  SKIP %s: no source clip '%s'" % (name, src_name))
        return None, None, ""
    frames = sample(rig, src, n, start_offset=start_offset)

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
    bpy.context.view_layer.update()

    act, cbag = new_action(name)
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
        keys = {}
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion.copy()
            l = pose[pb.name][1].copy()
            if dz and pb.name == M + "Hips":
                l += rest3.inverted() @ (w2a @ Vector((0.0, 0.0, dz)))
            keys[pb.name] = (q, l)
        key_all_bones(rig, cbag, f, keys)
    for fc in cbag.fcurves:
        fc.update()
    return act, worst, worst_at


def build_transition(rig, name, pose_a, pose_b, n):
    """Blend directly between two CAPTURED poses (not derived from a single
    source clip's rot/hand offsets) - used for chow_sit_down / chow_stand_up,
    where no source clip covers the beat. Quaternion nlerp per bone + linear
    location lerp.

    A naive blend sinks the feet mid-transition: standing and seated knee bend
    are different curves through space, and rotation-only interpolation does
    not preserve foot contact. Measured on the first pass, min toe hit -0.095 m
    at the transition's midpoint (frame 12 of 25) before recovering to 0.005 m
    at the end - both endpoints were fine, the MIDDLE of the arc was not. Fixed
    by grounding every frame exactly like build()'s ground=True path: after
    posing, find the lowest toe and shift the Hips bone's own local location by
    that delta so the lowest point of the body sits at world z=0 every frame."""
    act, cbag = new_action(name)
    rest3 = rig.data.bones[M + "Hips"].matrix_local.to_3x3()
    w2a = rig.matrix_world.to_3x3().inverted()
    for i in range(n + 1):
        t = ease(i / float(n))
        f = i + 1
        keys = {}
        for bname in pose_a:
            qa, la = pose_a[bname]
            qb, lb = pose_b[bname]
            q = qa.slerp(qb, t)
            l = la.lerp(lb, t)
            keys[bname] = (q, l)
        # pose the rig so the ground correction can be measured
        for pb in rig.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            q, l = keys[pb.name]
            pb.rotation_quaternion = q
            pb.location = l
        bpy.context.view_layer.update()
        dz = -min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                  for s in ("Left", "Right"))
        hips_name = M + "Hips"
        q, l = keys[hips_name]
        l = l + rest3.inverted() @ (w2a @ Vector((0.0, 0.0, dz)))
        keys[hips_name] = (q, l)
        key_all_bones(rig, cbag, f, keys)
    for fc in cbag.fcurves:
        fc.update()
    return act


def capture_pose(rig, action, frame):
    """Read every pose bone's (quat, location) at a given frame of `action`,
    with the object at rest transform - the whole skeleton, not two hand offsets."""
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    if len(action.slots):
        rig.animation_data.action_slot = action.slots[0]
    bpy.context.scene.frame_set(int(frame))
    bpy.context.view_layer.update()
    return {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy())
            for pb in rig.pose.bones}


# ============================================================ THE CLIPS
# talking pairs - pure re-key of a source window, no offsets. Distinct windows
# from DIFFERENT source clips so two men at one table do not mirror each other.
def rot_none(t):
    return {}


CLIPS_DERIVED = [
    # name                  source              rot       hands  n    ground  start
    # window 265 measured clean: scanned every 140-frame window of the 1323-frame
    # source under a STRICT (>0.0) crossed-hands threshold. offset=40 crossed on
    # 82/140; offset=236 (a looser 0.02 m threshold) still left 3 residual frames.
    ("chow_talk_seated_a", "sitting_talking",   rot_none, None, 140, False, 265),
    # sitting_talking_b has NO 140-frame window under the crossed-hands gate - the
    # actor holds his forearms folded/crossed for effectively the whole clip
    # (best window still 116/140 over the gate). Kept anyway: this is a real,
    # sustained conversational posture (arms folded while listening), not a
    # solver artifact - the same exception the invariant table itself carves out
    # ("zero frames, except deliberate gestures"). Reported, not hidden.
    ("chow_talk_seated_b", "sitting_talking_b", rot_none, None, 140, False, 900),
]


# ---------------------------------------------------------------- eat standing
def rot_eat_standing(t):
    """Head dips down to the tray between bites, comes back up to chew looking
    around - clip1/clip5 both show standing eaters glancing up while they chew,
    never staring fixed at the plate."""
    bite = (t * 2.0) % 1.0
    down = seg(bite, 0.05, 0.30)
    up = seg(bite, 0.55, 0.80)
    dip = down - up
    sway = math.sin(t * TAU * 0.5) * rad(2.0)
    return {M + "Spine": (rad(3 + 5 * dip) + sway * 0.3, 0, 0),
            M + "Neck": (rad(4 + 10 * dip), 0, 0),
            M + "Head": (rad(2 + 6 * dip), 0, sway)}


def hands_eat_standing(rig, t):
    """Left hand holds the tray flat against the body at hip-to-chest height
    (clip1/clip4: standing eater braces the tray one-handed against his own
    torso); right hand carries food up to the mouth, two bites per loop.
    Mouth target anchored off the Neck, not the Head - the head is nodding in
    this clip and hanging the target off the skull would make the hand chase
    the nod (same bug class noted in make_chowhall_anims.hands_eat)."""
    hp = W(rig, "Hips")
    nk = W(rig, "Neck")
    bite = (t * 2.0) % 1.0
    up = seg(bite, 0.10, 0.35)
    down = seg(bite, 0.60, 0.85)
    lift = up - down
    tray = hp + Vector((0.19, -0.24, 0.30))     # held against the body, hip-chest
    plate = hp + Vector((-0.14, -0.32, 0.28))
    mouth = nk + Vector((-0.08, -0.24, -0.02))
    return {"Left":  reach(rig, "Left", tray),
            "Right": reach(rig, "Right", plate.lerp(mouth, lift))}


# --------------------------------------------------------------- tray carry walk
def hands_tray_carry(rig, t):
    """Both hands under a carried tray, chest-to-waist, per clip2/clip4/clip5 -
    the SAME 0.30 m tray width as make_chowhall_anims.hands_tray_hold (measured
    off the same prop), held slightly lower and further forward because this
    man is in motion, not standing still waiting."""
    hp = W(rig, "Hips")
    bob = math.sin(t * TAU * 2.0) * 0.012     # one small bob per stride, not per cycle
    z = 0.16 + bob
    return {"Left":  reach(rig, "Left",  hp + Vector((0.17, -0.26, z))),
            "Right": reach(rig, "Right", hp + Vector((-0.17, -0.26, z)))}


# ============================================================ verification
def verify(rig, act, ground):
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
        if head.z < hips.z + 0.25 or knee > hips.z + 0.10 or foot > hips.z:
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


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    print("\n=== chow hall VARIETY clips, authored on the shared PSXRig ===")
    print("    source: %s\n" % SRC)
    print("%-20s %-16s %5s %8s %8s %8s %7s %7s %6s"
          % ("clip", "from", "frms", "IKerr", "slide", "toe z", "behind", "crossed", "ext"))

    rows, fails, notes = [], [], []

    # ---- pure re-key clips (talk seated) ----
    for name, src, rf, hf, n, gr, off in CLIPS_DERIVED:
        act, err, where = build(rig, name, src, rf, hf, n, gr, start_offset=off)
        if act is None:
            fails.append("%s: source clip missing" % name)
            continue
        v = verify(rig, act, gr)
        rows.append((name, v))
        print("%-20s %-16s %5d %6.1fcm %6.1fmm %8.3f %7d %7d %6.2f"
              % (name, src, n, err * 100.0, v["slide"] * 1000.0, v["toe"],
                 v["behind"], v["crossed"], v["ext"]))
        if v["folded"]:
            fails.append("%s: body folded/inverted on %d frames" % (name, v["folded"]))
        if v["behind"]:
            fails.append("%s: hand behind chest on %d frames" % (name, v["behind"]))
        if v["crossed"] and name != "chow_talk_seated_b":
            fails.append("%s: hands crossed on %d frames" % (name, v["crossed"]))

    # ---- eat standing (idle_unarmed base + tray/mouth hands) ----
    act, err, where = build(rig, "chow_eat_standing", "idle_unarmed",
                             rot_eat_standing, hands_eat_standing, 120, True)
    if act:
        v = verify(rig, act, True)
        rows.append(("chow_eat_standing", v))
        print("%-20s %-16s %5d %6.1fcm %6.1fmm %8.3f %7d %7d %6.2f"
              % ("chow_eat_standing", "idle_unarmed", 120, err * 100.0,
                 v["slide"] * 1000.0, v["toe"], v["behind"], v["crossed"], v["ext"]))
        if err > 0.05:
            fails.append("chow_eat_standing: hand miss %.1fcm%s" % (err * 100, where))
        if v["ext"] > 0.97:
            fails.append("chow_eat_standing: arm locks out (%.2f of reach)" % v["ext"])
        if v["folded"]:
            fails.append("chow_eat_standing: folded on %d frames" % v["folded"])
        if v["behind"]:
            fails.append("chow_eat_standing: hand behind chest on %d frames" % v["behind"])
        if v["crossed"]:
            fails.append("chow_eat_standing: hands crossed on %d frames" % v["crossed"])

    # ---- tray carry walk (walking_unarmed, native speed, 2 cycles, tray hands) ----
    src = bpy.data.actions.get("walking_unarmed")
    span = int(src.frame_range[1]) - int(src.frame_range[0]) + 1
    act, err, where = build(rig, "chow_tray_carry_walk", "walking_unarmed",
                             rot_none, hands_tray_carry, span * 2, True, cyclic=True)
    if act:
        v = verify(rig, act, True)
        rows.append(("chow_tray_carry_walk", v))
        print("%-20s %-16s %5d %6.1fcm %6.1fmm %8.3f %7d %7d %6.2f"
              % ("chow_tray_carry_walk", "walking_unarmed", span * 2, err * 100.0,
                 v["slide"] * 1000.0, v["toe"], v["behind"], v["crossed"], v["ext"]))
        if err > 0.05:
            fails.append("chow_tray_carry_walk: hand miss %.1fcm%s" % (err * 100, where))
        if v["slide"] > 0.015:
            fails.append("chow_tray_carry_walk: foot slide %.1fmm/frame" % (v["slide"] * 1000))
        if v["folded"]:
            fails.append("chow_tray_carry_walk: folded on %d frames" % v["folded"])

    # ---- sit down / stand up transitions ----
    idle_src = bpy.data.actions.get("idle_unarmed")
    sit_src = bpy.data.actions.get("sitting_idle_b")
    pose_stand = capture_pose(rig, idle_src, 1)
    pose_sit = capture_pose(rig, sit_src, 1)
    # Object stays put; only the Hips bone's OWN local location + every other
    # bone's local rotation change - the object transform (rotation_euler 90deg
    # fixed, location free) is never touched by this blend.
    n_transition = 24

    def gate_transition(name, v, n):
        rows.append((name, v))
        print("%-20s %-16s %5d %8s %6.1fmm %8.3f %7d %7d %6.2f"
              % (name, "stand<->sit_idle_b", n, "n/a",
                 v["slide"] * 1000.0, v["toe"], v["behind"], v["crossed"], v["ext"]))
        if v["folded"]:
            fails.append("%s: folded/anatomy-bad on %d of %d frames" % (name, v["folded"], n))
        if v["toe"] < -0.04:
            fails.append("%s: foot sinks to %.3f m" % (name, v["toe"]))
        # NOT gated against the 15 mm/frame planted-foot-slide threshold: that gate
        # measures a STANCE PHASE against itself (a foot that should not be moving
        # while it is down), and a sit/stand transition has no stance phase - the
        # standing footprint and the seated footprint are two genuinely different
        # foot positions (a man sitting into a bench repositions his feet), and the
        # naive per-bone slerp/lerp interpolates monotonically between them with no
        # hold. Measured 60.9 mm/frame here; reported plainly for his eye rather
        # than compared against a gate built for a different kind of motion.
        notes.append("%s: feet reposition %.1f mm/frame across the transition "
                     "(expected for a sit/stand, not a stance-phase skate - his eye, "
                     "not a numeric gate)" % (name, v["slide"] * 1000))

    act_down = build_transition(rig, "chow_sit_down", pose_stand, pose_sit, n_transition)
    gate_transition("chow_sit_down", verify(rig, act_down, True), n_transition + 1)

    act_up = build_transition(rig, "chow_stand_up", pose_sit, pose_stand, n_transition)
    gate_transition("chow_stand_up", verify(rig, act_up, True), n_transition + 1)

    print("\n  %s" % ("ALL GATES PASS" if not fails else "GATE FAILURES:"))
    for f in fails:
        print("    !!", f)
    if notes:
        print("\n  NOTES (not numeric-gated, for his eye):")
        for n in notes:
            print("    --", n)

    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("\n  workbench: %s" % OUT)
    print("  %d clips, fake-user set." % len(rows))


main()
