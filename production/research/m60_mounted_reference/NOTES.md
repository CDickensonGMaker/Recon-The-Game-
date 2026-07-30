# Mounted M60 — AI ally animation reference

*As of 2026-07-29. For the mannable/manned MG emplacement (top deferred feature).*

## Sources

| file | what it is | role |
|---|---|---|
| `mounted_jeep_archival.mp4` | 320×240 archival film, gunner on jeep pedestal M60, ~10s | **posture bible** — too small to mocap (artillery-footage class) |
| `bench_fire_recoil.mp4` | modern range clip, belt-fed MG fired off a bench, 1080p25 | recoil shudder timing; MOCAPPED (91% pose / 89% hand) |
| `mounted_posture_sheet.png` | 3 fps frames of the archival gunner | read the stance off it |

## Takes extracted (in `mocap-toolkit\takes\`)

- `m60_recoil_bench.take.json` — 351 frames, upper_body, from the bench clip.
  The burst shudder: torso rocks with the gun, shoulders take the cycle rate.
- `m60_manning_tp.take.json` — 807 frames, upper_body, from Caleb's own 7/29
  session (the M60 segment re-run with the third-person profile).

## The stance (from the archival sheet)

Standing in the bed behind the pedestal, feet braced apart, knees soft. Leaning
INTO the gun — chest toward the receiver, elbows out wide on the spade grips,
head low behind the sights. Traverse comes from the hips, not the arms; the arms
stay locked to the grips and the whole torso swings.

## Honest gap

Caleb's 7/29 M60 segment is a **carry/handling** performance (FP viewmodel work),
not a mounted-gunner performance. The ally needs: idle-manning (scan, small
weight shifts) · fire burst (shudder from the bench take) · traverse left/right
(hip-driven) · optional feed-tray reload. Best source is a dedicated ~30s
performance: stand behind a chair-back "mount", hands on imaginary spade grips
at chest height, run the four beats. Camera side-on to the gun axis, front-lit,
`upper_body` profile, retarget via the `mixamo_psx_crew` preset.
