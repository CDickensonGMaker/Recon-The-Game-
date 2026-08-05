# TECHNICAL DIRECTOR — Individual Sight

## The finding that reorders everything

I went looking for "which solver should replace MediaPipe." The honest answer to that question
is: WiLoR for hands, NLF or GVHMR for bodies. All three beat MediaPipe by a wide margin on the
exact axes we fail on — WiLoR detects hands in **86.9 %** of in-the-wild frames against
MediaPipe's **66.5 %**, and GVHMR is *gravity-aware and world-grounded*, which is precisely the
class of defect (float, slide, no weight) that costs us hours of "adjusting" per crew clip.

Then I read the licences.

| Model | Licence | Can it ship in RECONgame? |
|---|---|---|
| **MediaPipe** (current) | **Apache 2.0** | **Yes. Explicit commercial grant + patent grant.** |
| WiLoR | CC-BY-**NC**-ND, and depends on **MANO** | **No** |
| HaMeR | depends on **MANO** | **No** |
| GVHMR / TRAM / NLF / SMPLest-X | all built on **SMPL / SMPL-X** | **No** |

The SMPL licence grants use "for the sole purpose of performing non-commercial scientific
research, non-commercial education, or non-commercial artistic projects," and prohibits
"incorporation in a commercial product." MANO is the same licence family, and adds an explicit
prohibition on **military use** — which a Vietnam War game plainly is.

Commercial licences exist (Meshcapade for SMPL; ps-license@tue.mpg.de for MANO). That is a real
option but it is a contract negotiation and an unknown four- or five-figure number, not a
weekend upgrade.

**So the entire academic state of the art is closed to us for shipped animation.** Every
"just use the better model" answer dies here. This is not a reason to despair; it is a reason to
stop shopping for solvers and fix the thing we can actually fix.

## What we can actually fix: stop inferring depth, start measuring it

The depth number is the whole story. 48–51 % of the motion in a weapon take rides an axis the
camera never saw. No solver upgrade fixes that — it's an information problem, not a model
problem. **A second camera does fix it, completely and legally.**

Pose2Sim and FreeMoCap both do exactly this: 2+ ordinary cameras, a printed ChArUco board waved
once, triangulation. Pose2Sim's own published guidance for the two-camera case is **one camera
in front, one at 45° to the side, both at hip level**. Measured joint-angle error across
walking/running/cycling: **3.0°, 4.1°, 4.0°**. Their 2D stage is a pose detector we already own
and already licence cleanly.

He already owns both cameras — the Integrated Webcam and his phone. This costs a printout.

## What I would build, in order

1. **Two-camera triangulation as a second backend behind `take.json`.** The architecture already
   anticipated this ("solvers are pluggable backends"). We keep MediaPipe's Apache-2.0 2D
   landmarks and add a triangulation stage. Nothing downstream changes — the addon, the contact
   solver, the retarget presets all keep working.
2. **A hard triage gate before Blender.** `depth_report.py` exists; it is a report. Promote it
   to a **gate** with thresholds, run automatically at extract time, printing PASS/FAIL. A bad
   take must be caught while he is still standing in front of the camera, not three hours into
   a Blender session.
3. **The contract test.** `rest_delta` was declared in `props.py`, drawn at `ui.py:100`,
   documented, defaulted to True — and consumed by nothing. `feature.preview` was advertised by
   the backend and implemented nowhere. These are not two bugs, they are **one class: the
   toolkit lies about its own capabilities.** A test that walks every declared property and
   every advertised capability and asserts a consumer exists is the highest-ROI test in the repo.
4. **Installed-addon hash gate.** The extension in `AppData\...\extensions\user_default\` is a
   *copy*. It silently ran three days stale and made `psx_fp_arms.json` unloadable — the FPS
   preset did not work in his Blender *at all*, for days, invisibly. `run_tests.ps1` must fail
   loudly when the installed copy differs from `addon/`.

Items 3 and 4 are not glamorous. They are also, measurably, where most of the lost time went.
