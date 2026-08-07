# Hardware Scout — owned, licence-clean capture routes (verified 2026-08-07)

## Route 1 — Multi-camera optical triangulation (WINNER)
2–4 cameras → 2D pose per view → triangulate = **measured** depth, not inferred.
- Licences ALL verified permissive: Pose2Sim **BSD-3**, aniposelib **BSD-2**, OpenCV **Apache-2.0**,
  MediaPipe/RTMPose **Apache-2.0** (rtmlib checkpoint mirror is Apache/MIT/BSD).
- FreeMoCap is AGPL-3 but **output data is unconditionally clean** — GNU's own FAQ: program output
  is covered only when the program copies itself into it (https://www.gnu.org/licenses/gpl-faq.en.html).
  AGPL bites only if we distribute a modified FreeMoCap.
- Accuracy, peer-reviewed (Pose2Sim, Sensors 2022): **3.0–4.1° mean joint-angle error** vs
  marker-based reference — optical-suit territory. 3–4 cams is the sweet spot for occlusion
  (a rifle across the chest blinds any single view).
- Sync WITHOUT genlock: Pose2Sim cross-correlates keypoint speed across views; clap/slate or LED
  flash as fallback. ±8ms at 60fps is fine for human motion.
- Cost: **$0–250** (owns phone + webcam; 1–2 more used phones/webcams + tripods optional).
- Session burden: calibrate once (checkerboard), mark tripod spots on the floor, ~5 min/session.
  **TRAP: a nudged tripod silently garbages extrinsics — re-check when anything looks off.**

## Route 3 — Markers (ArUco/AprilTag/colour blobs)
- OpenCV ArUco is Apache-2.0, built in. Full-BODY marker mocap is why AI pose won — flat tags die
  when rotated away or under ~30px; colour blobs are a lighting yak-shave.
- **Where markers are GOLD: the WEAPON PROP.** 2–3 ArUco tags on the rifle = drift-free 6-DoF prop
  pose per frame — the thing MediaPipe cannot see at all. ~50 lines on top of Route 1's rig. Paper cost.

## Route 2 — IMU suits
SlimeVR is genuinely open (MIT sw / Apache hw), native **BVH export**, ~$200 DIY / $279–600 bought.
No fingers, yaw drift, no absolute position — hands never land on the rifle without cleanup.
**A later complement for prone/crawl/outdoor takes, not the answer for weapon work.**
Mocopi/Rebocap/Haritora = proprietary SDK surfaces; against the brief.

## Route 4 — Depth cameras: DEAD
Azure Kinect hardware killed 2023, Sensor SDK archived 2024, Body Tracking SDK was NEVER open
(proprietary MS binary; headers had no licence grant). Orbbec Femto body tracking = a wrapper
around that same dead MS stack. RealSense lives but sells depth, not a skeleton solver. **Skip.**

## Route 5 — Fingers
Gloves: StretchSense $795–6,995, Rokoko $695, all proprietary. DIY flex gloves are toys.
**Industry answer: grip poses are a small authored set per weapon (grip/trigger/mag/charging
handle), blended — hands are keyed, not captured.** $0, licence-proof, matches Lane A doctrine.

## Ranked
1. Multi-cam triangulation of the existing pipeline + ArUco on the prop ($0–250, all permissive)
2. Hand-key fingers from reference (the standard, not a compromise)
3. SlimeVR later for camera-blind captures
4. FreeMoCap as a turnkey trial only; 5. depth cams never; 6. commercial IMU/gloves never.

## Traps
- Checkpoint licence ≠ repo badge (the SMPL trap in a new hat) — verify per-weight, esp.
  Halpe/COCO-WholeBody finger models which can ride non-commercial datasets.
- AGPL: data always clean; shipping a modified tool is not.
- IMU hands don't land on props; more trackers don't fix it.
- "Azure Kinect compatible body tracking" anywhere in marketing = the corpse with a EULA.
