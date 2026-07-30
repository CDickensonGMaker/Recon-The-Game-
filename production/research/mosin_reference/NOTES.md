# Mosin Nagant viewmodel reference kit

*As of 2026-07-29. Source: YouTube 4l7oNeL2rfg, "Mosin Nagant in FPS games" compilation,
1080p60. Cut into per-game takes with 6 fps frame sheets (1 tile ≈ 10 frames @60).*

**This footage is a DEAD mocap source — measured, not assumed.** 1,041 frames probed
through the mocap-toolkit MediaPipe models: hands detected in 1% of frames, both hands in
0%, every pose hit a phantom (no body in frame). Stylized gloved game hands at viewmodel
FOV do not read as hands to the detector. Use these sheets as beats/staging reference for
hand-keying only.

## Takes

| file | game | worth stealing |
|---|---|---|
| `bf1.mp4` | Battlefield 1 | bolt-cycle snap, gloved hand poses, single-round top-up |
| `tarkov.mp4` | Tarkov | sky-tilt inspection framing, deliberate weighty pacing |
| `enlisted.mp4` | Enlisted | **best full stripper-clip reload** — clean phases, honest thumb press |
| `cod_vanguard.mp4` | COD Vanguard | bare hands (scoped variant — note scoped Mosins load singles, no clip) |
| `scum.mp4` | S.C.U.M | camo sleeve reads, muzzle-high carry sway |

## Enlisted stripper-clip reload — phase beats (from the 6 fps sheets)

| phase | ≈ duration @60fps | notes |
|---|---|---|
| bolt up + back (eject) | ~30–40 f | gun rolls left toward camera as the right hand works the bolt |
| right hand drops for clip | ~20 f | gun holds the rolled pose, muzzle rises slightly |
| clip presented + seated in guide | ~30 f | clip enters from lower-right, distinct "seek then seat" beat |
| thumb press (rounds strip in) | ~40–50 f | the signature beat — wrist arches, one hard shove, not five taps |
| clip flick away | ~15 f | fast toss right, empty clip visibly tumbles |
| bolt forward + down | ~30 f | gun rolls back to center as bolt closes |
| settle to idle | ~20 f | overshoot and recover, sway resumes |

Whole reload ≈ 3.2 s. Every studio rolls the rifle left ~30–45° during the cycle so the
action stays on-screen — that roll is the shot; keep it.

## Filming spec for a real mocap take (mocap-toolkit `fps_arms`)

The profile hard-requires the BODY model: hips, both shoulders, elbows, wrists visible or
the take fails (`profiles/fps_arms.json` — `fail_if_missing: wrist_l, wrist_r`,
min detection 0.8). So:

- **Frame hips-to-head**, whole take. Not a hands-only close-up.
- **3/4 angle from the shooter's RIGHT** so the bolt hand stays camera-side; dominant
  motion lateral (monocular depth is the weak axis).
- **Bare hands** — gloves cost detection (measured today: gloved segments = 0%).
- **Thin prop** (dowel/broomstick) occludes less than a real rifle profile; shoot a take
  with each if possible. 60 fps, even light, plain background.
- 3–5 clean reps per take; hold a neutral pose a beat at the start.
- Expect to hand-key over the top: forearm roll/pronation (unobservable from points),
  finger contact detail, and the snap of the extremes. Mocap supplies arcs and timing.
