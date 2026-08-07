# THE DECREE — A Mocap Rig That Is Truly Ours

**2026-08-07 · for the Summoner's review · nothing here has been built**

His query: *"how we could make our true own motioncapture without any of these licensing issues"*,
sharpened mid-council to: *"how do we go around apache or smpl mano and just make our own?"*
and *"if i gave you a compliant video you could read how they are doing things and we could make
our own improved motion capturing programs."*

## THE SHORT ANSWER

**Apache does not need going around — it IS ours.** Apache 2.0 is an irrevocable commercial grant
with a patent grant; the only obligation is a notice in the credits, and it binds the TOOL, never
the output. Every animation that leaves the pipeline is 100% Caleb's. The licences we keep hitting
are all the SMPL/MANO/non-commercial family, and those cannot be gone around: their output IS the
licensed body model.

**And yes, a truly-owned rig exists — it is geometry, not AI.** Licences bind code and weights,
never techniques. Calibration, epipolar geometry, DLT triangulation are published math; writing our
own implementation is a clean-room reimplementation and is how Vicon-class mocap works — no neural
network anywhere required. Measured depth also kills the 48%-inferred-depth tax on every take.

## THE THREE FINDINGS (each verified with sources, see analysis/)

1. **RTMW3D exists and is legally ours** (solver scout): direct 3D whole-body keypoints —
   body + HANDS + face — Apache-2.0 code AND weights, no parametric model anywhere, ONNX on
   Windows. The licence-clean SOTA upgrade the 8/5 council believed did not exist. Fixes
   MediaPipe's worst organ (in-the-wild hand detection ~66.5% → hands always solved with the
   person). Traps confirmed en route: Sapiens CC-BY-NC, VideoPose3D CC-BY-NC, YOLO-NAS-Pose has
   Apache code but restricted WEIGHTS — the code-vs-weights split is real; verify per-checkpoint.
2. **The owned optical stack is proven and near-free** (hardware scout): 2–4 cameras +
   triangulation = 3.0–4.1° joint-angle error peer-reviewed (Pose2Sim, BSD-3), sync by clap or
   keypoint cross-correlation (no genlock), $0–250 total. **ArUco tags on the weapon prop**
   (OpenCV, Apache-2.0) give drift-free 6-DoF prop pose — the thing no pose model can see.
   Fingers stay hand-keyed: that is the industry standard, not a compromise. Depth cameras are a
   corpse with a EULA (MS Body Tracking SDK — never open, now archived; Orbbec wraps it). SlimeVR
   (MIT/Apache, ~$200–279) is a later complement for prone/crawl where cameras are blind.
3. **The toolkit is already shaped for this** (surveyor): backends are pluggable; `input.multi_view`
   is already in the capability vocabulary (`backends/base.py:39`); **a stubbed `rtmw` backend
   already sits in the repo** (`backends/rtmw/__init__.py`, extract unimplemented). A
   `triangulated` backend is ~700–1100 lines, only ~200 of it plumbing; the real work is
   calibration + sync + geometry — all ownable. Schema friction: `Take.camera` holds ONE
   unvalidated dict; two cameras + extrinsics eventually want a `cameras: [...]` MINOR bump.

## THE DECREE — THE OWNED STACK, THREE LAYERS

| Layer | What | Whose |
|---|---|---|
| **Geometry** (the crown) | Our calibration + triangulation + ArUco prop tracking, written by us (OpenCV/aniposelib BSD under it) | **OURS — no model, no weights, no licence** |
| **2D detection** | MediaPipe today; RTMW/RTMW3D when the stub is finished | Apache 2.0 — irrevocably ours to ship |
| **Fingers** | Authored grip-pose set per weapon, video as reference (Lane A doctrine, ratification still pending from 8/5) | Ours by construction |

**The "compliant video" workflow he proposed is ratified into the plan:** study footage teaches
practice (marker placement, camera layout — technique is unlicensable); test footage of HIM is the
pilot input. The pilot needs: checkerboard wave, clap, one take, phone front + webcam 45°.

## WHAT IS SACRIFICED — named, per the Second Law

- **The session loop he likes gets taxed** — second device, calibration, transfer, sync. The 8/5
  kill threshold stands: if the rig costs more than ~10 extra minutes per session, it dies.
- **A nudged tripod produces confidently wrong 3D** — silent-garbage class. Floor marks + a
  calibration check-take are mandatory ritual, or the pipeline lies.
- **Training our own neural net is named and killed**: dataset licences are the same trap one
  level down, plus months of compute to underperform free Apache weights.
- **Pure-marker BODY tracking (zero-AI purism) is named and not recommended**: flat tags die
  off-angle, colour blobs are a lighting yak-shave — it's why AI 2D won. Markers are for the PROP.
- **RTMW3D on a CPU-only box is unmeasured** — offline batch is fine (overnight runs are already
  doctrine) but the pilot must time it before anything depends on it.
- **Demo Day opportunity cost** — EA target 2026-09-06 ships the demo's shape. The 8/5 devil's
  advocate question (32 unwired clips vs any capture work) was never answered and still stands.

## ORDERED NEXT STEPS (proposal)

1. **The $0 pilot** — one two-camera take of Caleb (checkerboard, clap, phone + webcam), ArUco
   tags on the broom-rifle, hand-authored calib, offline triangulation script. Verdict = measured
   depth error vs the monocular take of the same motion. 1–2 days. Kill threshold: >10 min/session.
2. **If the pilot passes: `triangulated` backend** behind `take.json` (~1–2 weeks to trustworthy),
   `cameras: [...]` format bump when it stabilises.
3. **Finish the `rtmw` backend stub** — RTMW 2D feeds the same triangulation and fixes hands;
   RTMW3D benchmarked on CPU as a monocular fallback.
4. *(later, optional)* third/fourth camera ($100–250) for occlusion; SlimeVR for prone/crawl.

## RULINGS SOUGHT

1. **Approve the $0 two-camera + ArUco-prop pilot?** This IS the "make our own" prototype.
2. **Is Apache-2.0 in the 2D stage acceptable "ours"** (recommended), or do you want the zero-AI
   marker-purist body path despite its costs?
3. **Finish the rtmw stub** for better hands?
4. **Scheduling**: does any of this run before Demo Day / EA (9/6), or does it queue post-launch
   with the other capture work? (The 8/5 rulings #1–4 are also still open.)
