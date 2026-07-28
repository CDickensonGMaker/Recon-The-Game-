# Lane 3 — Indie/solo FPS animation workflows (web research, 2026-07-27)

## How the boomer-shooter cohort ships gun anims
- Dominant retro pipeline is render-3D-to-sprites (CULTIC, Selaco, Prodeus, Duke3D) — NOT our path
  (we're real-time 3D PSX), but the lesson transfers: few frames + snappy timing + muzzle flash carrying
  the impact reads fine. Classic Doom fire anims are ~4-6 frames.
- Cruelty Squad / HROT: deliberately crude art direction makes animation polish irrelevant — the PSX
  aesthetic HIDES contact errors (matches our tri-budgets-are-style law).
- ULTRAKILL: simplicity chosen for at-speed READABILITY, a gameplay feature not nostalgia.

## Procedural motion — ESTABLISHED, and our biggest missing layer
- Split: BAKED = base poses, reloads, equips, idle breaks, finger work. PROCEDURAL = locomotion bob,
  sway, jitter, recoil impulses. Layer procedural ADDITIVELY on top of few authored poses.
  Canonical writeup: https://www.devunallocated.com/projects/project-killhouse/procedural-weapon-animations-condensed
  - sine step cycles (double-time = figure-8 bob); activation blending 1-clamp01(v/threshold)
  - recoil = spring impulses around the GRIP point; scale down during sustained fire
  - jitter = multi-frequency sine = muscle micro-adjustment; idle breathing 12-18 cycles/min
  - ADS: hard-set transform, apply recoil impulses AFTER ADS alignment or the gun sinks off-sight
- Spring/damper is the standard primitive. Godot implementations exist:
  https://github.com/vi4hu/godot-procedural-recoil , https://github.com/AceSpectre/GodotProceduralRecoil
- **The 13-keyframe proof**: David Rosen GDC 2014 "An Indie Approach to Procedural Animation" —
  responsive full-character animation from 13 keyframes + springs/interpolation (Overgrowth, Receiver).
  THE reference for keyframe-poor solo work. https://www.gdcvault.com/play/1020583/

## Workflow efficiency — CONVENTION
- Player sees fire anims thousands of times → SHORT + SNAPPY beats fancy. Cut frame 1 of fire — the
  shot lands the instant the button is hit (CGCookie).
- GUN LEADS, HANDS FOLLOW (constrain off-hand to gun); weapon rotating slightly faster than the view
  reads light and controlled.
- Concrete numbers (MoCap Online FP guide): ADS transition 8-15 frames (25 heavy); head bob 30-60% of
  realistic amplitude; sway yaw > pitch > roll, cut 50-80% in ADS; minimum reload set = tactical+empty.
- DON'T OVERBUILD THE RIG: FP arms rarely contact the world — simple IK on the off-hand only; offload
  repetition to code (Rosen), not rig complexity.

## Robotic vs alive — converging rules
1. Input latency is the #1 sin — same-frame visual response beats realism.
2. Idle is never static — breathing, multi-frequency jitter, idle-break clips.
3. Weight = impulses + settle; springs give free overshoot-and-settle, exactly the overlap hand-keyed
   in/outs lack (this is why frozen-hand clips read dead — see viewmodel_anim_defects §frozen hands).
4. Camera does half the work — Vlambeer "Art of Screenshake": kick, flash, sound sell a gun cheaper
   than animation frames. https://www.youtube.com/watch?v=AJdEqssNZ-U

## PSX-specific
- Simplified hands are a commodity (fingerless gloves standard for tactical); frame contact points LOW
  in the viewport — the grip never has to be perfect if it's near the screen bottom edge; separate
  arms FOV both prevents distortion AND frames out bad contact (ADR-034 lens already gives us this dial).
