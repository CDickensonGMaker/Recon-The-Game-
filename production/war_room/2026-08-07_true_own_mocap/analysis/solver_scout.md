# Solver Scout — commercially-usable pose stacks (verified 2026-08-07)

## Candidate verification table

| Name | Task | Code licence | Weights licence (source) | SMPL/MANO-free? | Win/CPU-CUDA | Accuracy vs MediaPipe |
|---|---|---|---|---|---|---|
| **RTMPose (MMPose)** | 2D body / hand / face | Apache-2.0 — https://github.com/open-mmlab/mmpose/blob/main/LICENSE | No separate weights licence; checkpoints on `download.openmmlab.com` fall under repo Apache-2.0 (https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose) | YES — pure keypoint heatmap/SimCC | Excellent: ONNX; RTMPose-m = 75.8 AP COCO at 90+ FPS on i7-11700 **CPU** | Well above MediaPipe Pose for body 2D |
| **RTMW / RTMW-x** | Whole-body 2D (133 kpt: body+feet+face+hands) | Apache-2.0 (same repo) | Same — OpenMMLab-hosted, no separate licence | YES | ONNX; RTMW-l real-time on GPU, usable on CPU at reduced FPS | RTMW-l 70.1 AP COCO-WholeBody @384x288 (arXiv:2407.08634) — above MediaPipe for whole-body incl. hands |
| **RTMW3D / RTMPose3D** | **Direct 3D whole-body keypoints** (no parametric model) | Apache-2.0 (mmpose projects/rtmpose3d) | Same — OpenMMLab checkpoints, no restriction stated | YES — 3D keypoints direct from image; "cocktail14" training mix | ONNX-exportable, CUDA or CPU | RTMW3D-L: 0.678 AP COCO-WholeBody, 0.056 MPJPE on H3WB — includes 3D hand keypoints |
| **ViTPose / ViTPose++** | 2D body | Apache-2.0 — https://github.com/ViTAE-Transformer/ViTPose | HF port `usyd-community/vitpose-plus-base` explicitly tagged **apache-2.0** | YES | HF transformers = trivial Windows/CPU/CUDA | SOTA-class 2D body (80+ AP COCO); no hands in 17-kpt models |
| **DWPose** | Whole-body 2D (133 kpt) | Apache-2.0 — https://github.com/IDEA-Research/DWPose | No separate licence, repo Apache | YES | ONNX, CPU-friendly | 66.5 AP wholebody — above RTMW-m, below RTMW-l/x |
| **MediaPipe** | Whole-body 2.5D | Apache-2.0 | Apache-2.0 | YES | Best-in-class CPU/Windows | Baseline; in-the-wild hand detection ~66.5% (arXiv:2405.03545) |
| **MotionBERT** | 2D→3D lifting (H36M 17-kpt, direct 3D) | Apache-2.0 — https://github.com/Walter0807/MotionBERT | Checkpoints unrestricted | YES for the 3D-pose head. **Avoid the mesh head (SMPL-based)** | PyTorch, offline lifting | SOTA monocular lifting; body only, **no hands** |
| **RTMO** | One-stage multi-person 2D body | Apache-2.0 | Unrestricted | YES | ONNX real-time | Good multi-person body; no hands |
| Sapiens (Meta) | 2D pose/depth/seg | **CC-BY-NC 4.0** (verified LICENSE) | same | — | — | **TRAP — non-commercial. CLOSED.** |
| VideoPose3D | 2D→3D lifting | **CC-BY-NC** | same | — | — | **TRAP. CLOSED.** Use MotionBERT |
| OpenPose | Whole-body 2D | non-commercial / paid FlintBox | same | — | — | **TRAP. CLOSED.** |
| Ultralytics YOLO-pose | 2D body | **AGPL-3.0** (viral) | AGPL | — | — | **TRAP. CLOSED.** |
| YOLO-NAS-Pose | 2D body | Code Apache, **weights Deci non-commercial** (YOLONAS-POSE.md) | restricted | — | — | **TRAP — the code-vs-weights split. CLOSED.** |

## Hand accuracy note
MediaPipe's weak spot is hand *detection* in the wild (~66.5%) — hands are found from body-pose
ROI and drop out constantly. RTMW/RTMW3D solve hands as part of the single 133-kpt top-down solve —
hands are always localized when the person is (RTMPose-Hand 81.5 PCK@0.2 COCO-WholeBody-Hand).
The MANO-free hand landscape is essentially MediaPipe Hands vs the RTMPose/RTMW family.

## Shortlist
1. **RTMW3D** — the headline find: direct 3D whole-body keypoints (body+hands+face), no parametric
   model at any stage, Apache-2.0 code AND weights, ONNX on Windows. The closest thing to a
   licence-clean GVHMR replacement that exists.
2. **RTMW-x/l 2D + MotionBERT lifting** — Apache end to end; RTMW replaces MediaPipe's flaky hands
   with always-on 133-kpt 2D; MotionBERT (pose head only) lifts body to 3D.
3. **ViTPose++ (HF usyd-community, Apache-tagged)** — highest-accuracy 2D body per frame.

Notably, the OpenMMLab family shows NO code-vs-weights licence split anywhere in its docs or hosting.
