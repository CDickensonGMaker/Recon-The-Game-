# BRIEFING — A Mocap Rig That Is Truly Ours

**2026-08-07 · Summoner's query:** *"look at our motioncapture setup and how we could basically
make our true own motioncapture without having any of these licensing issues we keep running into."*

## Standing constraints (from prior councils — not re-litigated here)
- **The licence wall is VERIFIED (8/5):** every SOTA solver (WiLoR, HaMeR, GVHMR, TRAM, NLF,
  SMPLest-X) is SMPL/MANO-licensed — non-commercial AND anti-military. RECONgame is a commercial
  Vietnam War title: blocked twice over. See `2026-08-05_mocap_pipeline_deep_dive/synthesis.md`.
- MediaPipe (Apache 2.0) is the only solver that is legally ours today.
- The 8/5 decree proposed Lane A (weapon: video = metronome) / Lane B (body: measure depth
  with a second camera) — **its four rulings are still awaiting the Summoner.**
- mocap-toolkit architecture: solvers are pluggable backends, `take.json` is the only contract.
- Hardware on hand: phone camera, integrated webcam, Quadro P620 (CPU-only inference).

## The question for this council
What does an END-TO-END mocap stack that Caleb OWNS look like — every component either
Apache/MIT/BSD-licensed or written by us — and which route gives the best animation quality
per dollar and per session-minute for a solo dev capturing weapon handling and soldier motion?

## Architects summoned (parallel, no cross-talk)
1. **Solver scout** — verify which 2026 pose models have commercially-clean WEIGHTS (not just code).
2. **Hardware scout** — multi-camera optical, IMU suits, marker-based DIY, depth cams, gloves:
   cost / burden / quality / licence, verified with sources.
3. **Toolkit surveyor** — where a new backend plugs into mocap-toolkit; what a triangulation
   backend minimally needs; effort estimate.
