# ADR-026 — THE PS2 BUDGET: a graphics-only rendering discipline, uncapped fighters, cheap-per-unit AI

- **Status:** DRAFT — pending Summoner ratification. (Re-frames the whole optimization effort; supersedes nothing until ratified.)
- **Date:** 2026-07-16
- **Deciders:** Summoner (Caleb) by decree; War Room council (technical-director, game-designer/atmosphere, devil's-advocate) advising; Overseer arbitrating.
- **Pillars touched:** 1 (gunplay), 2 (atmosphere), 3 (freedom) — hence a full council.
- **Related:** ADR-001 (PSX renderer of record), ADR-013 (≤2km no-streaming), ADR-015 (verification law), ADR-023 (fossil law).

## Context

Measured baseline (real bench, `night_jungle_bench.bat` + the arena perf overlay): deep night jungle
18v18 = ~19 fps, BOTH-bound — GPU ~50ms (foliage fill) and CPU ~40ms (36 clustered men). Perf is the
top systemic risk (charter §9). The engine is Godot 4.7 Forward+, PSX/PS2 low-poly by ADR-001.

The frame is co-limited: fixing only the GPU stalls at the CPU wall, and vice-versa. This ADR sets a
console-era rendering discipline every system checks against — **and names how big firefights stay
affordable WITHOUT capping the number of soldiers**, because the scale of a Vietnam firefight is a
pillar, not a negotiable.

## Decision

### PART A — THE GRAPHICS BUDGET (rendering only; never limits gameplay scale)

Binding rules. Numbers are the ratification targets; tuning within them is not an ADR change.

1. **Light budget — almost no real-time lights.** Muzzle flashes and explosions are FAKE: a self-lit
   emissive/additive sprite POP (+ particle), NOT a real `OmniLight` per shot. The world is
   vertex-lit / baked, not per-pixel dynamic. **Hard cap: ≤8 simultaneous real-time lights on screen,
   0 shadow-casting dynamic lights.** The night sun's shadow is the one allowed dynamic shadow, and it
   is OFF or near-field-capped (≤40m) over alpha-scissor jungle.
   - **FAIRNESS EXEMPTION (binding, from council):** the flash SPRITE, the tracer, and the report are
     fairness-critical and are **exempt from every light / LOD / flash cap** — cap the bounce LIGHT
     only. Every shot or explosion that can threaten or be seen by the player renders a self-lit
     emissive flash legible at real engagement range through fog/night. The OmniLight may die; the POP
     may not. (The muzzle flash is already 90% fake — `gun_fx.gd` pairs the OmniLight with two self-lit
     additive billboard quads that already carry the telegraph.)
   - The illumination FLARE stays a real light: it does stealth gameplay work (`illum_flare.is_lit()`
     strips night concealment). Do not fake it away.

2. **Draw distance — short, fog-walled; hard LOD snaps (PS2 had no smooth LOD).** Render nothing the
   fog eats. Foliage visibility range ~80m, unit LOD ~70m, hard snaps at 40/70m. Opaque fog ~90m as a
   TARGET — **but see the hard guard-rail below.**
   - **DRAW-DISTANCE FLOOR (HARD BLOCKER, binding):** player draw distance ≥ the AI's effective sight
     range under the same weather/light, and ≥ the longest weapon's effective range. An AI may never
     acquire or fire on a player it cannot render. (`SIGHT_CAP_OPEN = 140m` today; fog and night reduce
     BOTH the AI sight cap and the needed draw distance symmetrically, so a short fog wall is legal only
     while it shortens sight as much as render.) Fog is weather/elevation atmosphere, never a fixed
     render wall below the current sight cap; a fixed cap that hides renderable, shootable enemies is an
     ADR change, not tuning. This protects Pillar 3 (open AO, long recon/sniper sightlines) and the
     Fairness Law.

3. **Vegetation & geometry — Caleb's low-poly models, vertex-lit, hard LOD.** No per-pixel foliage
   fanciness. Single-side (back-face cull) any surface whose back is never seen; keep `cull_disabled`
   only where a single-plane billboard genuinely needs both faces (and prefer double-modeled geometry
   so back-cull is free). Skip wind vertex work in the shadow pass (`IN_SHADOW_PASS`).

4. **Render scale — sub-native + the 4.7 nearest-neighbor 3D filter.** `scaling_3d/scale ≤ 0.75`,
   `scaling_3d/mode=5` (NEAREST) — crisp and PSX-authentic, not blurry. This is the single cheapest,
   most aesthetic-aligned GPU win on a fill-bound frame.

5. **Water & FX — animated texture planes + sprite particles**, not a double-sided transparent river
   sim. One batched water mesh (the `WaterSystem.CombinedWater` path), back-face culled.

### PART B — SCALE IS UNCAPPED; COMPUTE IS BUDGETED (the CPU answer)

**There is NO headcount cap.** Big Vietnam firefights are the goal — target real **30v30 (~60
combatants)**, all existing, visible, and animated; the battle LOOKS full. The ~40ms/36-men CPU cost is
an **AI-efficiency problem**, solved by making AI cheap PER UNIT, not by cutting bodies:

- **ACTIVITY-TIERED AI (a compute budget, not a body limit).** At any moment only a rolling **HOT-SET**
  runs full-cost combat AI (target acquisition, LOS raycasts, precise aiming, cover-seeking, grenade
  logic). Council-sized affordable hot-set ≈ **12 fully-simulated fighters (ceiling 16)** — bounds
  per-frame AI compute regardless of the 60 total. The "outlining" men run CHEAP behaviors
  (move / hold / take-cover / suppressed / reposition / fire-in-general-direction) — the illusion of
  participation without the full per-frame cost.
- **Promote-on-death / disengage.** As a hot fighter dies or disengages, a peripheral unit promotes
  into full combat. Rolling reassignment keeps the fight alive and the cost flat. Owner: the
  `EnemySquad` coordinator (single owner — do not ship two targeting authorities).
- Complements distance-based far-unit LOD; candidate multipliers: round-robin think/raycast stagger,
  AI threading, batched physics — only if 12–16 proves tight, profiled on a REAL mission (the bench's
  40ms is contaminated by bench-only cost: O(18×18) patrol LOS sweep, per-frame debug ImmediateMesh,
  6× telemetry walks).
- **COLD-TIER GUARD-RAIL (binding, ADR-005):** tiering governs render + EXPENSIVE cognition only.
  The witness heartbeat (perception + NoiseBus) and persistent state tick on EVERY tier at EVERY
  distance. `set_physics_process(false)` is never used to shed AI cost — a blind cold unit would void
  the 150m loud-kill witness beacon and invert the stealth economy.
- **Any tier that fires** emits the full telegraph and obeys first-shot-is-a-near-miss; a unit that
  cannot pass the fairness check does not fire on the player.

## The sacrifice (council law — no free lunch)

- Modern lushness / atmosphere ceiling: environmental light-throw dies — muzzle flashes no longer
  splash the shooter's face, explosions no longer dance light on the canopy; the world is baked, not
  dynamically lit. Traded for a stable frame and an authentic PS2 feel.
- The full-scale spectacle is confined to what **fog and dark can sell** — a daylight open-field 60-man
  panorama at 60fps is NOT promised; a fog-walled treeline of unseen guns flashing in the dark is
  (and reads as a bigger war than 36 visible men at 19fps).
- Two-legged risk: the graphics budget alone turns a 19fps both-bound frame into a ~23fps CPU-bound
  one and stalls (measured 2026-07-16). Part A and Part B must land together to reach 30/60.

## Fossil-Law clause (ADR-023)

A fake-flash / plane-water path must DELETE its real-OmniLight / duplicate-mesh predecessor in the same
change — never run beside it (two ways to make a muzzle flash is exactly the fossil the law forbids).
This wave already deleted one such fossil: the duplicate TerrainManager `RiverMesh` visual (superseded
by `WaterSystem.CombinedWater`).

## Status of this wave (2026-07-16, the cheap wins — measured, not projected)

Cheap GPU fixes applied and measured on the bench (probe, consistent fixed wide-jungle view):
**baseline 14.0 fps → 23.1 fps (frame 71ms → 43ms), +65%.** The frame is now CPU-bound at the ~41ms
wall — proving Part B (activity-tiered AI + fake lights) is the next wave. Light cost quantified: real
OmniLights (+their CPUParticles) are worth ~+8.6 fps on this bench — the #1 PS2-budget win, beaded.

## Alternatives considered

- **Cap the fighters (~8-16 active), stage the rest as illusion.** REJECTED by Summoner decree: firefight
  scale is a pillar. Replaced by Part B (uncapped bodies, budgeted compute).
- **Switch Forward+ → Mobile renderer.** Deferred; A/B pending. Mobile drops volumetric fog / SDFGI /
  SSR (a PSX game uses none) but is a larger change than this wave.
