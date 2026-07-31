"""Generate passive/patrol VARIETY from clips the library already owns.

*** THIS SCRIPT HAS NEVER BEEN RUN. Written 2026-07-30, parked the same hour at the
*** Summoner's word ("i need to verify all the animations were making so i shouldnt
*** go super crazy"). It is a PROPOSAL in executable form, not a shipped tool. Dry-run
*** it and read the seam measurements before trusting a single output.


    blender -b assets/shared/anim_library.blend -P tools/make_ambient_variants.py -- \
        --out art_source/animations/variants_staging.blend [--only splice,phase,retime]

Nothing here invents performance. Every output is a mechanical transform of motion
we already have, which is why it can run headless and be trusted without an eye on
each result:

  SPLICE  upper body of A onto lower body of B. A man walking a patrol while
          scanning is `sentry_scan` over `walk_forward` - two clips we own, one
          new read. The split is at the waist: Spine2 and up comes from the upper
          donor, Hips/legs/Spine/Spine1 stay with the lower, so ROOT MOTION and
          footfalls are never touched. Donors of different length are RESAMPLED by
          evaluating the donor curve at the target's phase, so the cycle still
          lines up with the feet.

  PHASE   the same cycle started at a different point. Five men on one walk clip
          march in lockstep and read as one animation; the same five at 0 / 1/3 /
          2/3 phase read as five men. Cyclic clips only - a phase-shifted one-shot
          is just a broken one-shot.

  RETIME  the same motion, slower or faster, baked as its own clip. A weary shuffle
          and a brisk walk are the same walk. Playback rate alone cannot do this,
          because the engine drives rate from ground speed (`_CLIP_SPEED`).

THE LOOP-SEAM RULE. Phase and retime only stay clean on a clip whose first pose
equals its last. This script MEASURES that seam and refuses any clip over
SEAM_TOL_DEG, printing what it skipped - a phase shift on a clip with a seam moves
the pop into the middle of the cycle, where it is worse than at the ends.
"""
import bpy, sys, os, math, argparse
from mathutils import Quaternion

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--only", default="splice,phase,retime")
ap.add_argument("--dry-run", action="store_true")
args = ap.parse_args(argv)
STAGES = {s.strip() for s in args.only.split(",") if s.strip()}

M = "mixamorig:"
## Waist split. Spine2 and up follow the upper donor; everything else - Hips,
## Spine, Spine1, both legs - stays with the locomotion clip that owns the feet.
UPPER = ("Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm",
         "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand")
## A loop seam wider than this is a pop, and phase/retime would relocate it.
SEAM_TOL_DEG = 12.0

## What to build. (new, upper_donor, lower_donor) - the read is stated so a bad
## one can be cut by name without opening Blender.
SPLICES = [
    ("patrol_scanning",      "sentry_scan",   "walk_forward"),   # walking a line, head up
    ("patrol_nervous",       "nervous_scan",  "walk_forward"),   # green troops, spooked
    ("walk_smoking",         "smoking",       "walk_forward"),   # off-duty crossing camp
    ("stand_scanning_crouch", "sentry_scan",  "idle_crouching"), # crouched overwatch
    ("walk_weary",           "neck_stretch",  "walk_forward"),   # rolling the neck on the move
]
## (new, source, phase_fraction)
PHASES = [
    ("walk_forward_p33", "walk_forward", 1.0 / 3.0),
    ("walk_forward_p66", "walk_forward", 2.0 / 3.0),
    ("run_forward_p50",  "run_forward",  0.5),
    ("walk_crouching_forward_p50", "walk_crouching_forward", 0.5),
]
## (new, source, time_scale) - >1 is SLOWER (more frames for the same motion)
RETIMES = [
    ("walk_trudge", "walk_forward", 1.35),
    ("walk_brisk",  "walk_forward", 0.82),
    ("patrol_scanning_slow", "patrol_scanning", 1.25),  # built from a SPLICE above
]

rig = None
for ob in bpy.data.objects:
    if ob.type == "ARMATURE":
        rig = ob
        break
if rig is None:
    print("[VAR] FATAL: no armature")
    sys.exit(1)


def channelbags(action):
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.append(cb)
    return out


def curves(action):
    out = []
    for cb in channelbags(action):
        out.extend(list(cb.fcurves))
    return out


def bone_of(fc):
    dp = fc.data_path
    if '"' not in dp:
        return ""
    return dp.split('"')[1]


def is_upper(bone_name):
    short = bone_name.replace(M, "")
    return any(short == u or short.startswith(u) for u in UPPER)


def frame_span(action):
    fr = action.frame_range
    return float(fr[0]), float(fr[1])


def seam_degrees(action):
    """Largest per-bone rotation difference between the first and last pose."""
    f0, f1 = frame_span(action)
    worst = 0.0
    per_bone = {}
    for fc in curves(action):
        if ".rotation_quaternion" not in fc.data_path:
            continue
        b = bone_of(fc)
        per_bone.setdefault(b, {})[fc.array_index] = (fc.evaluate(f0), fc.evaluate(f1))
    for b, comps in per_bone.items():
        if len(comps) < 4:
            continue
        q0 = Quaternion([comps[i][0] for i in range(4)])
        q1 = Quaternion([comps[i][1] for i in range(4)])
        if q0.length == 0 or q1.length == 0:
            continue
        q0.normalize(); q1.normalize()
        worst = max(worst, math.degrees(q0.rotation_difference(q1).angle))
    return worst


def new_action(name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new(id_type='OBJECT', name="Object")
    layer = act.layers.new("Layer")
    strip = layer.strips.new(type='KEYFRAME')
    strip.channelbags.new(slot)
    return act, act.layers[0].strips[0].channelbags[0]


def put_curve(cb, data_path, index, samples):
    fc = cb.fcurves.new(data_path, index=index)
    fc.keyframe_points.add(count=len(samples))
    for i, (t, v) in enumerate(samples):
        kp = fc.keyframe_points[i]
        kp.co = (t, v)
        kp.interpolation = 'LINEAR'
    fc.update()
    return fc


def sample_at(action, data_path, index, frame, fallback):
    for fc in curves(action):
        if fc.data_path == data_path and fc.array_index == index:
            return fc.evaluate(frame)
    return fallback


built = []
skipped = []


def do_splice(new_name, upper_name, lower_name):
    up = bpy.data.actions.get(upper_name)
    lo = bpy.data.actions.get(lower_name)
    if up is None or lo is None:
        skipped.append("%s (missing %s)" % (new_name, upper_name if up is None else lower_name))
        return
    if bpy.data.actions.get(new_name) is not None:
        skipped.append("%s (already in library)" % new_name)
        return
    lf0, lf1 = frame_span(lo)
    uf0, uf1 = frame_span(up)
    n = int(round(lf1 - lf0)) + 1
    act, cb = new_action(new_name)
    # Lower half: copied frame for frame - the feet and root motion are the truth.
    for fc in curves(lo):
        b = bone_of(fc)
        if b and is_upper(b):
            continue
        samples = [(lf0 + i, fc.evaluate(lf0 + i)) for i in range(n)]
        put_curve(cb, fc.data_path, fc.array_index, samples)
    # Upper half: the donor's own cycle stretched onto the lower's timeline, so a
    # 195-frame scan rides a 30-frame walk without drifting out of step.
    for fc in curves(up):
        b = bone_of(fc)
        if not b or not is_upper(b):
            continue
        samples = []
        for i in range(n):
            phase = float(i) / float(max(1, n - 1))
            samples.append((lf0 + i, fc.evaluate(uf0 + phase * (uf1 - uf0))))
        put_curve(cb, fc.data_path, fc.array_index, samples)
    built.append("%s = %s(upper) + %s(lower), %d frames" % (new_name, upper_name, lower_name, n))


def do_phase(new_name, src_name, frac):
    src = bpy.data.actions.get(src_name)
    if src is None:
        skipped.append("%s (missing %s)" % (new_name, src_name))
        return
    if bpy.data.actions.get(new_name) is not None:
        skipped.append("%s (already in library)" % new_name)
        return
    seam = seam_degrees(src)
    if seam > SEAM_TOL_DEG:
        skipped.append("%s (seam %.1f deg > %.1f - phase would move the pop inward)"
                       % (new_name, seam, SEAM_TOL_DEG))
        return
    f0, f1 = frame_span(src)
    n = int(round(f1 - f0)) + 1
    shift = frac * (f1 - f0)
    act, cb = new_action(new_name)
    for fc in curves(src):
        samples = []
        for i in range(n):
            t = f0 + math.fmod((i + shift), float(max(1, n - 1)))
            samples.append((f0 + i, fc.evaluate(t)))
        put_curve(cb, fc.data_path, fc.array_index, samples)
    built.append("%s = %s phase %+.0f%% (seam %.1f deg)" % (new_name, src_name, frac * 100.0, seam))


def do_retime(new_name, src_name, scale):
    src = bpy.data.actions.get(src_name)
    if src is None:
        skipped.append("%s (missing %s)" % (new_name, src_name))
        return
    if bpy.data.actions.get(new_name) is not None:
        skipped.append("%s (already in library)" % new_name)
        return
    f0, f1 = frame_span(src)
    n = int(round((f1 - f0) * scale)) + 1
    act, cb = new_action(new_name)
    for fc in curves(src):
        samples = []
        for i in range(n):
            phase = float(i) / float(max(1, n - 1))
            samples.append((f0 + i, fc.evaluate(f0 + phase * (f1 - f0))))
        put_curve(cb, fc.data_path, fc.array_index, samples)
    built.append("%s = %s x%.2f time (%d -> %d frames)"
                 % (new_name, src_name, scale, int(f1 - f0) + 1, n))


if "splice" in STAGES:
    for spec in SPLICES:
        do_splice(*spec)
if "phase" in STAGES:
    for spec in PHASES:
        do_phase(*spec)
if "retime" in STAGES:
    for spec in RETIMES:
        do_retime(*spec)

print("[VAR] built %d:" % len(built))
for b in built:
    print("[VAR]   %s" % b)
if skipped:
    print("[VAR] skipped %d:" % len(skipped))
    for s in skipped:
        print("[VAR]   %s" % s)

if args.dry_run:
    print("[VAR] dry run - nothing written")
else:
    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("[VAR] wrote %s" % out)
print("[VAR] actions: %s" % ",".join(b.split(" =")[0] for b in built))
