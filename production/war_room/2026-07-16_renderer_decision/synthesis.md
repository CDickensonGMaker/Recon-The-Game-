# DECREE — Renderer: switch to Mobile (Forward Mobile), native scale 1.0

*Arbiter synthesis, 2026-07-16. Right-sized council: Technical-Director/Godot-Specialist + Devil's
Advocate, independent, no cross-talk. They converged — the strongest signal this process produces.*

## The judgment
**Adopt the Mobile renderer at native `scaling_3d/scale = 1.0`.** Pending the Summoner's sign-off (this
is the `365s` #3 architecture call — his authority, my recommendation).

## Why (measured, not asserted)
- Mobile **40.9 FPS** vs Forward+ **29.2 FPS** at native 1.0, seed 2077, Intel UHD, vsync off. +40%, and
  it clears the 30 gate **at native** — the shipped `0.77` FSR1 upscale crutch is no longer needed (and
  FSR1 is Forward+-only anyway). The A/B image is clean, on-aesthetic, arguably sharper.
- The frame is **fill/pipeline-bound, not geometry-bound** (cutting 100k prims + 77 draw calls moved FPS
  ~0). That is precisely the axis Mobile's lighter pipeline wins on.
- Technical Director audited from code: **nothing Forward+-only is in use** — no SDFGI/SSIL/SSAO/SSR/glow/
  volumetrics; shadows + MSAA already off; all 9 `.gdshader` files pass (only screen-read is a 2D
  canvas_item shader, fully Mobile-supported; water writes depth but never reads DEPTH_TEXTURE). Mobile
  removes nothing the game renders today.

## What is SACRIFICED (no free lunch — named in ink)
1. **Volumetric fog is foreclosed, forever-until-revert.** God-rays through the canopy / morning mist —
   the signature Vietnam image — is a Forward+-only capability. Ships nothing today (game uses
   exponential fog, Mobile-fine), but it is the **named Pillar-2 ceiling** the build-order #6 jungle-feel
   pass will hit. Also foreclosed: SSAO contact-shadow grounding, SDFGI/SSIL bounce light. These are
   *future ceilings*, not current losses.
2. **Mobile caps ~8 omni/spot lights per mesh** with a per-object light loop. The game already spawns
   runtime omnis (illum flares, muzzle flashes, explosions, village fires, tunnel mouths) and **night is
   a real mission state.** A night firefight by a burning ville could cluster past the cap and silently
   drop lights — which can nick **Pillar-1 clarity** (muzzle flash must always telegraph, Fairness Law),
   not just atmosphere. Mitigated (flashes/explosions are count-capped; omni ranges are small, 7–16m) but
   **unverified.**
3. **The evidence is n=1** — one daytime, open-ground, zero-dynamic-light spawn: Mobile's home turf,
   Forward+'s foreign soil. The night-firefight/full-arena scene where Mobile is structurally weakest was
   never benchmarked; the +40% could shrink or (in a light-dense cluster) invert there.
4. **Reversibility decays.** The setting is one line, but every material/shader/lighting look authored
   against Mobile's tonemap accretes an assumption; reverting to Forward+ later means re-validating the
   material library. Cost of reversal is ~zero today and grows weekly.

## The condition (ADR-015 — the decision is not fully verified yet)
The council's converged call is **"switch, but not on n=1."** So:
- **Ship Mobile now** (it clears the gate honestly, the status quo Forward+ is itself under-gate at
  native and only "passed" via the 0.77 hack this bead exists to expose — good riddance).
- **File the adversarial re-measure** as a P1 verification: Mobile vs Forward+ in a night scene with
  illum flare(s) + multiple muzzle flashes + a fire + full arena character count. If Mobile inverts or
  drops telegraphing lights there, that bead reverses this decree. Until then Mobile stands on the
  evidence we have.
- **When the renderer ADR is authored**, record volumetric-fog + SSAO as the explicit Pillar-2 ceiling so
  the jungle-feel council does not rediscover it as a betrayal.

## Not sacrificed (strawmen killed)
- SSAO/SSIL/SDFGI/SSR: used by nothing today — future ceilings, not present losses.
- ADR-024 cinematics: Blender/Eevee **offline** FMV, never touches the runtime renderer. Unaffected.

## Config sub-question — settled
Mobile + **native 1.0** (recommended by both). Reject Mobile+0.77 (plain bilinear mush, no FSR, headroom
not needed). Reject staying Forward+ (worse image AND under the gate).
