# ADR-026 — THE PS2 BUDGET: a graphics-only rendering discipline, uncapped fighters, cheap-per-unit AI

- **Status:** RATIFIED 2026-07-20 by the Summoner. Binding. (Re-frames the whole optimization effort.)
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
   - **CLARIFYING NOTE (2026-07-20, measurement only — the rule above is unchanged and the ruling is
     the Summoner's):** on this hardware **the ≤40m cap is not a cheap middle ground; the sun shadow is
     binary.** Measured ship-parity A/B/A, seed 47225, 1280x720, `scaling_3d/scale=0.75`, forward_plus,
     Intel UHD, noise floor **0.5 FPS**: `shadow_40m` **−10.5**, `shadow_80m` **−10.8**,
     `shadow_uncapped` **−10.4** — all three identical within noise (PERF_LEDGER.md, "what the sun
     shadow would COST"). `directional_shadow_max_distance` concentrates shadow-map resolution nearer;
     it does **not** meaningfully reduce the geometry submitted to the shadow pass (+117k–127k
     primitives at every setting). So of the two options this rule permits, **OFF is the only
     affordable one on the target GPU, and OFF is what ships** (`game_world.gd:48`). A reader should
     not infer that capping to 40m buys back most of the cost — it buys ~0.
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
- **Switch Forward+ → Mobile renderer.** REJECTED — see Amendment A.

---

## Amendment A — RATIFIED 2026-07-17: Forward+ is the renderer, full stop

**Summoner decree (2026-07-17):** the renderer is **`forward_plus`**, ratified canon. The Mobile A/B is
**closed and rejected** — do not evaluate, propose, or draft a renderer switch again. The FPS job is to
claw the frame budget back **within Forward+**, never by changing renderer.

- **Already live** (`project.godot:302-305`): `scaling_3d/mode=5` (nearest), `scaling_3d/scale=0.75`.
  MSAA is off (default); `mesh_lod/lod_change/threshold_pixels=2.0`. Part A.4 (sub-native render
  scale) is therefore shipped.
- **`renderer/rendering_method` is NOT and cannot be a committed setting** (verified 2026-07-19).
  Godot strips any value matching the engine default on editor save; an explicit `"forward_plus"`
  line was committed and stripped the same day. Forward+ holds because it IS the desktop default,
  confirmed at runtime: `Vulkan 1.3.215 - Forward+` in a live 4.7 run. Mobile was measured and gave
  no gain, so the renderer stays settled — but it is unguarded, not locked.
- **Sun shadow — the truth (measured 2026-07-17):** the shipped mission world already runs the sun with
  **`shadow_enabled = false`** (`game_world.gd:48`, "perf-first"), which is the **OFF** option Part A.1
  already permits. The −12.17ms "sun-shadow win" from the 2026-07-16 bench was a **bench artifact**: only
  `ai_stress_arena.gd:390` set the sun shadow ON, and unbounded (not the ≤40m Part A.1 allows), so the
  bench was ~12ms harder than anything that ships. **There is no shipped sun-shadow FPS win to claim — it
  is already off.** This wave brings the bench to ship parity (arena sun `shadow_enabled = false`; the F6
  overlay toggle still turns it on to measure the cost). Future bench numbers will read ~12ms faster than
  the 2026-07-16 rows because they now reflect ship.
- **Where the frame actually is:** with the shadow off (ship config), the remaining GPU bomb is the
  **jungle — 71% of frame geometry** (−12.26ms, −572,438 primitives, measured 2026-07-16). That, plus the
  Part B CPU wall, is the whole target. See "Next wave" below.

### Next wave — the Forward+ jungle attack (targets; each ms delta needs the windowed bench)

The jungle is instanced as merged 12m patch meshes via `JunglePatchLayer` (near full-detail + a
structure-only `_far` twin). Levers, ordered by expected win, all inside Forward+:

1. **Foliage `view_distance` 128m → 80m — LANDED 2026-07-17** (`jungle_patch_layer.gd:73`). The A.2
   target; look-verified identical to 128 in night/fog (far foliage invisible anyway) and cuts ~22% of
   primitives. Shipped as low-risk hygiene. FOLIAGE distance only — independent of the unit draw-distance
   floor (units render to the 140m sight cap); fade (80m) stays under the fog wall (~90m).
2. **`fill_chance` 0.78 → 0.6 — REJECTED 2026-07-17.** Fails the Pillar-2 gate: at 0.6 the canopy
   visibly thins (open ground and long sightlines appear where dense bamboo walls stood). No trustworthy
   perf case to justify the atmosphere loss (the frame is CPU-bound; see below). `fill_chance` stays 0.78.
3. **Far-twin simplification / hard-snap tuning** (`near_distance` 46m). PS2 hard LOD; verify the snap
   reads as PS2, not pop.
4. **Part B (activity-tiered AI)** for the CPU half — separate wave (ADR-025 LOD-tier), not a GPU lever.

**These are BLOCKED on a windowed bench** (`night_jungle_bench.bat` + F1–F6 overlay; GPU-ms reads 0
headless). Each lever must be A/B'd (same timepoint) for fps + draw-calls + primitives AND eyeballed for
Pillar 2, per the 2026-07-16 method-debt lesson (a live-firefight toggle-diff conflates the toggle with
the clock).

### Windowed A/B — 2026-07-17 (CONTAMINATED; the finding survives, the fps numbers do not)

Ran the 3-config A/B windowed. **The fps/ms numbers are void — measured with Blender open, GPU/CPU
contended** (THE_PLAN's "Blender CLOSED" rule). Proof of contamination: the `view_distance=80 +
fill_chance=0.6` run reported **GPU 224ms on the LOWEST geometry (382k prims)** — physically impossible;
CPU times ran 3–4× the historical baseline. What DOES survive:
- **Geometry responds correctly** (trustworthy): prims 675k (vd128/fc78) → 526k (vd80) → 382k (vd80/fc60).
- **The frame is CPU-BOUND on AI, not GPU-bound on jungle** (visible in the overlay, robust to
  contention): baseline & vd80 overlays both read **GPU ~32ms** (barely moved despite −22% prims) while
  the **`ai/agents`** bucket — measured **25–192ms** on 2026-07-16, a figure since **RETIRED** as
  attribution-unknown (`production/war_room/2026-07-18_ai_consolidation_plan/synthesis.md:21`) — is the
  wall. **The jungle GPU is NOT what limits the 18v18 arena fps — the AI is.** This confirms **Part B
  (activity-tiered AI) is the real FPS lever**, not the jungle draw cuts.
- **Look-check:** `view_distance=80` is visually identical to 128 (far foliage is invisible at night) —
  look-safe and ADR-026 A.2-aligned. `fill_chance=0.6` **visibly thins the canopy** (a Pillar-2 loss),
  not a free win.

**Not implemented** — no config wins on trustworthy perf, and fill_chance 0.6 fails the Pillar-2 gate.
**Next:** (1) a clean re-run with **Blender closed** + an AI-frozen/reduced arena to isolate jungle GPU;
(2) the FPS effort pivots to **Part B (activity-tiered AI)** — that is where the frame actually is.
