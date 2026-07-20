# RECONgame Performance Ledger

The single honest record of measured frame rates. Every number here names the render scale it
was measured at (the standing sin — bead `365s` — was quoting scaled numbers as if native).

## Measurement contract
- **Always record `rendering/scaling_3d/scale`.** `0.77` = 59.3% of native pixels; a number at 0.77 is
  NOT a native number.
- **Always record the renderer** (`rendering/rendering_method`). As of 2026-07-20 it is explicitly
  `forward_plus` in `project.godot:300` (ADR-026 Amendment A). Note Godot STRIPS this key on editor
  save when it equals the desktop default — if it goes missing again, restore it before measuring.
- **Always record the seed.** Terrain relief, site layout and therefore frame cost change with it.
  The shipped default is **47225** (`game_flow.gd:190`); older entries at 2077 do not describe it.
- Harness (as of 2026-07-20): launch the game normally with `-- --perf-probe [--perf-cycle]`.
  `GameFlow.enter_hub` attaches `tests/perf_probe.tscn` to the live patrol world. Windowed ONLY —
  headless instantiates `RendererDummy` and every figure it reports is fiction.

## Entries

### 2026-07-16 — first HONEST native profile (Track A1 / bead 365s)
- **Native FPS ≈ 27** (steady 24–29 range), main-game jungle.
- Config: `scaling_3d/scale = 1.0` (temporarily set for the measurement, then **restored to 0.77** —
  native was measured, not shipped), renderer **Forward+** (default, unset), seed 2077.
- Hardware: **Intel UHD Graphics**, Vulkan 1.3, Godot 4.7.stable.
- Scene load: 25 terrain chunks (5×5, 1280m map), ~13,000+ tree + rice billboards map-wide, 46 water
  bodies, GameplayGrid 256×256. Consistent with the bead's ~350k alpha-tested overdraw estimate.
- **Surprise vs the bead's prediction:** `365s` predicted native would be **12–16 FPS**. It is **~27** —
  roughly **2× better** than the pessimistic estimate. Still below the 30 FPS gate, but not the disaster
  the void numbers implied. The FPS=1 sample in the log is a one-frame screenshot-capture stall
  (measurement artifact), not a real dip.
- For reference: the old "40–41 on 4.7" figure was at 0.77 (59% pixels); a like-for-like 0.77 re-measure
  was not run this pass.

### 2026-07-16 — Phase 0 per-system attribution (bead t5mo)
Harness: `perf_probe.gd` extended to sample `RenderingServer.get_rendering_info` and to cycle each
foliage system off one window at a time (`perf_probe_cycle.tscn`). Stationary camera at the AO-center
spawn, seed 2077, **scale 1.0**, renderer Forward+ (default). Numbers are per-frame averages over each
~4.5s window.

| phase | fps avg | prims | draw calls | objects |
|-------|--------:|------:|-----------:|--------:|
| baseline (all on) | 24.4* | 301,886 | 164 | 251 |
| billboards OFF | **32.5** | 181,666 | 56 | 143 |
| jungle patches OFF | 29.8 | 301,886 | 164 | 251 |
| grass OFF | 29.6 | 301,886 | 164 | 251 |

\* baseline avg is dragged down by the one-frame screenshot-capture stall (fps_min 7.0). The
patches-OFF / grass-OFF windows render byte-identical frames to baseline and read ~29.6 — that is the
true stationary native baseline (consistent with the earlier 24–29 range).

> **SUPERSEDED 2026-07-20 by the seed-47225 patrol-world run at the end of this ledger.** Kept as
> history (ADR-014). This entry was produced by an instrument that toggled `BillboardVegetation` — a
> system since retired — inside a bare `game_world` at seed 2077 that had no firebase and no sites.
> The headline below is measured against a world nobody plays. **Sun shadow, which this run never
> toggled, is the larger lever.**

**The finding — billboards are the whole story, and it is measured now, not estimated:**
- Disabling **`BillboardVegetation`** removes **120,220 primitives (40% of the frame)**, **108 of the
  164 draw calls (66%)**, 108 objects, and gains **+8.2 FPS → 32.5, which clears the 30 gate on its own.**
- Disabling **jungle patches** and **grass** changes primitives / draw calls / objects by **ZERO** at
  this pose. Their toggles fire; they simply have nothing in range to hide (patches render <128m, grass
  <60m, and the AO-center spawn sits on open ground). Their apparent "+5 FPS" is the *absence* of the
  screenshot stall, not a real saving — the identical prim/call/object counts prove it.
- **Correction to the plan / bead:** the plan ranked patches the #2 GPU driver. At the measured spawn
  pose they are not a driver at all; **billboards are ~the entire controllable foliage cost.** Patch
  cost would rise if the camera stood inside a dense patch field, but billboards are the always-on
  80–600m far-field fill and the unambiguous primary target. Phase 1 targets billboards only; patches
  are left untouched (also protects Pillar 2 atmosphere + LOS).
- Total-frame context: ~302k prims with terrain (25 chunks × ~8k tris ≈ 180k) as the other big block —
  terrain is not a cut target. The old "~350k overdraw" estimate was in the right order of magnitude but
  wrongly attributed; the real attributable-and-cuttable block is the 120k billboard prims.

### 2026-07-16 — Phase 1/2/3 (bead t5mo). Measurement note: vsync + the real bottleneck
**Vsync was quantising every prior number.** `project.godot` has no vsync key (defaults ON) + fullscreen;
on a 60Hz panel that pins the GPU to 30/60 half-steps, so 24–29 "native" was partly a vsync artifact.
`perf_probe.gd` now forces `VSYNC_DISABLED` + `max_fps=0` for a true-throughput read. All numbers below
are vsync-off, scale=1.0, seed 2077, stationary AO-center spawn (open hillside — see caveat).

**The bottleneck is fill/pipeline, NOT geometry (measured, decisive):**
| change | prims | draw calls | fps (Forward+) |
|--------|------:|-----------:|---------------:|
| Forward+ baseline | 301,886 | 164 | ~29.2 |
| billboards single-sided (CULL_BACK) | 301,886* | 164 | ~29.2 |
| + billboard range 600→350m | 202,386 | 87 | ~28.9 |

\* `TOTAL_PRIMITIVES_IN_FRAME` counts submitted tris — back-face culling saves fill, not primitive count.
Cutting **99,500 prims (33%) and 77 draw calls moved FPS by ~0.** Geometry/draw-call count is not the
jungle's limiter at this pose; full-screen terrain/water fragment shading + the render pipeline is.

**Phase 1 kept (both free / near-free, no measured FPS cost but reduce worst-case fill):**
- Billboards **single-sided** (`CULL_DISABLED`→`CULL_BACK`; the mesh authors both faces so both sides
  still draw — half the fill, identical silhouette).
- Billboard **range 600→350m** (fog at 0.004 already hides >75% of a 350m card; zero visible cutoff).
- **Reverted** the density pull (candidates 3000, unchanged) — it cost Pillar-2 atmosphere for zero
  measured FPS. Alpha-hash (Change 2) **skipped** — its early-Z benefit is nil when the frame isn't
  geometry-bound, and it adds shimmer for no gain.

**Phase 2 — FPS ladder wired (discharges the world_config MISSING-FEATURE fossil, 97→95):**
`VEGETATION_DENSITY_MULT` now scales billboard+grass+tree candidate counts; `BILLBOARD_DISTANCE_MULT`
scales billboard draw range. Manual quality dial (edit const + reboot). NOTE: because geometry isn't the
limiter, this dial buys little FPS — it's a fossil-discharge + memory/CPU-gen lever, not the FPS fix.

**Phase 3 — RENDERER A/B (the real win):**
| renderer | fps (native, scale 1.0) | clears 30 gate? |
|----------|------------------------:|:---------------:|
| Forward+ (default) | ~29.2 | NO |
| **Mobile (Forward Mobile)** | **40.9** | **YES (+40%, at native)** |
Nothing Forward+-only is used (no SDFGI/SSIL/SSAO/glow/volumetrics/SSR; shadows+MSAA already off). Mobile
clears the gate at NATIVE resolution — the shipped 0.77 FSR upscale becomes unnecessary (FSR1 is
Forward+-only anyway). Visual A/B: clean, on-aesthetic, arguably sharper. **Recommendation pending a
right-sized War Room + Summoner sign-off (renderer is a 365s architecture call).**

## Still owed (does NOT close 365s)
1. **Per-system attribution** — the probe gives a whole-frame number; it does not yet split billboards
   vs terrain vs water vs characters into a per-ms budget. That attribution is the next step before any
   optimization bet.
2. **Set a gating FPS number** — the decree in `365s` step 4. Deferred to the Summoner: native-27 is the
   honest floor to gate against.
3. **`rendering_method` decision** — pick and commit a renderer (Forward+ vs Mobile vs Compatibility on
   an Intel UHD target) deliberately, not by default.

---

# 2026-07-16/17 OVERNIGHT — THE FIRST PER-SYSTEM ATTRIBUTION (365s Phase 0)

**Method.** `tests/overnight_bench.tscn` (new, unattended): boots `ai_stress_arena.tscn`, warms up 9s,
then drives the SAME F1–F6 toggles a human would press (injected `InputEventKey` — the real overlay
code path, not a reimplementation), 1.5s settle + 4.0s averaged sample per configuration. GPU-ms is
`RenderingServer.viewport_get_measured_render_time_gpu` (the real driver figure). Renderer selected
via the `--rendering-method` CLI override — **`project.godot` was never edited**. Render scale pinned
at runtime and recorded on EVERY row.

**Hardware/scene:** Intel UHD · Godot 4.7.stable · `ai_stress_arena` = NIGHT firefight, dense jungle,
3D trees, flares/fires, 18v18 patrol→contact. **This is the adversarial scene (5kr3), not `game_world`.**

## THE HEADLINE — `all_systems_on` (no toggle applied; the trustworthy rows)

| renderer | render scale | fps | GPU ms | CPU ms | draw calls | primitives |
|---|---|---:|---:|---:|---:|---:|
| Forward+ | **1.00 native** | **18.8** | 51.94 | 44.35 | 911 | 806,793 |
| Forward+ | **0.75 / mode5 (shipped)** | 22.3 | 43.18 | 41.24 | 910 | 806,611 |
| Mobile | **1.00 native** | **25.5** | 36.89 | 37.98 | 527 | 807,370 |
| Mobile | **0.75 / mode5 (shipped)** | **29.9** | 31.24 | 34.28 | 526 | 806,125 |

**NOTHING CLEARS THE 30 FPS GATE IN THE NIGHT ARENA.** Best case — Mobile at the shipped 0.75/mode5 —
is **29.9 fps**. At native, the best any renderer manages is **25.5**.

**This corrects a live claim in this ledger.** The Phase-3 entry above says *"Mobile … 40.9 fps …
clears the gate at NATIVE"*. That was measured in `game_world` — **daytime, open ground, zero dynamic
lights: Mobile's best case.** In the adversarial night arena Mobile at native is **25.5**, not 40.9.
The +40% direction survives (**+36%**: 25.5 vs 18.8 at native); **the "clears the gate" conclusion does
not.** This is exactly the n=1 problem `5kr3` was filed to catch.

**Mobile roughly HALVES draw calls** (527 vs 911) at identical primitive counts.

## PER-SYSTEM ATTRIBUTION — Forward+ @ native 1.00 (deltas vs 51.94ms GPU / 18.8 fps)

| toggle OFF | fps | GPU ms | ΔGPU | primitives | Δprims |
|---|---:|---:|---:|---:|---:|
| **jungle patches (F1)** | 24.1 | 39.68 | **−12.26** | 234,355 | **−572,438** |
| **sun shadows (F6)** | 23.4 | 39.77 | **−12.17** | 687,601 | −119,192 |
| lights (F3) | 20.3 | 46.93 | −5.01 | 817,998 | +11,205 |
| characters (F4) | 19.9 | 48.61 | −3.33 | 697,559 | −109,234 |
| grass/clutter (F2) | 18.2 | 50.56 | −1.38 | 769,054 | −37,739 |

**1. The jungle is the bomb, and it is now MEASURED, not asserted.** −12.26ms GPU and
**−572,438 primitives — 71% of the frame's geometry** — from one toggle. 365s predicted "~350,000
alpha-tested triangles of overdraw" on reasoning alone; the real figure is larger.

**2. SUN SHADOWS COST AS MUCH AS THE ENTIRE JUNGLE (−12.17ms, 23% of the GPU frame), AND THE ARENA
BENCH IS HARDER THAN THE SHIPPED GAME.** `ai_stress_arena.gd:390` reads `sun.shadow_enabled = true`;
`game_world.gd:48` reads `light.shadow_enabled = false`. **The scene we judge FPS by carries a 12ms
shadow the shipped world does not.**

**⚠ Wave-2 correction — this is NOT a leftover and must NOT be "fixed".** ADR-026 (draft) line 29
states: *"0 shadow-casting dynamic lights. **The night sun's shadow is the one allowed dynamic
shadow**."* The arena is doing exactly what the draft sanctions. My first pass called this "the
cheapest measured win, needs no art, no LOD, no renderer decision" — **that framing was wrong**; it
implied a mistake where there is a decision. Untouched.

**What is a real question, and is the Summoner's:** `game_world` (no sun shadow) and the arena (sun
shadow) disagree, so **the 18.8/25.5 numbers are a worst case that the shipped night world may or may
not pay.** Whether the shipped game gets ADR-026's "one allowed dynamic shadow" decides whether ~12ms
belongs in the gate. That is an ADR-026 ratification question (`mok6`), not a bug.

**3. Grass/clutter is ~free (−1.38ms).** Any density pull there buys nothing and costs Pillar 2.

**4. The frame is NOT lopsidedly GPU-bound.** CPU 44.35ms vs GPU 51.94ms at native. Prior notes call
this "GPU fill-bound"; it is close to balanced, so a pure fill fix cannot get past ~19→23 fps alone.

## ⚠ CORRECTION (same night, Wave 2) — THE ATTRIBUTION ABOVE IS CONTAMINATED. READ THIS FIRST.

The first pass blamed the Mobile anomalies on "a re-batch storm / too-short settle" and called the
Forward+ deltas "the attribution of record". **Both claims were wrong. A control experiment killed them.**

**The control.** Six **identical** `all_systems_on` phases, **no toggle ever pressed**, Forward+ @ 1.00:

| phase | fps | GPU ms | CPU ms | draw calls | primitives |
|---|---:|---:|---:|---:|---:|
| control_t0 | 17.9 | 54.04 | 45.94 | 1,013 | 829,798 |
| control_t1 | 18.5 | 50.74 | 58.04 | 968 | 813,867 |
| control_t2 | 19.0 | 49.93 | 66.09 | 1,007 | 817,770 |
| control_t3 | **15.7** | 49.60 | 68.76 | **1,243** | 843,247 |
| control_t4 | 19.0 | 50.38 | 36.58 | 1,219 | 845,029 |
| control_t5 | 16.8 | 50.19 | 66.49 | **1,268** | 848,371 |

**Nothing was changed between those six rows.** fps swings **15.7–19.0 (±10%)**, draw calls climb
**1,013 → 1,268 (+25%)**, CPU swings **36.6–68.8 (±47%)**.

**`ai_stress_arena` IS A LIVE 18v18 FIREFIGHT. IT ESCALATES WHILE YOU MEASURE IT.** Reinforcement
waves spawn, corpses and gibs accumulate, flares drift. A sequential toggle-diff therefore conflates
*the toggle* with *the clock*. That, not a settle time, is why `mobile lights_OFF` read **16.3 fps
(and 21.5 at a 5s settle) — worse than its own all-on baseline — while draw calls ROSE 627→864.**
Toggling a light off cannot add 237 draw calls. The arena did.

**What survives, measured against a ±3.3 fps / ±255-call / ±4.4ms-GPU noise floor:**

| finding | ΔGPU | verdict |
|---|---:|---|
| **jungle patches** | **−12.26ms, −572,438 prims** | **STANDS** — the primitive delta is ~4× the drift band and 71% of all geometry. Not noise. |
| **sun shadows** | **−12.17ms** | **STANDS** — ~3× the GPU noise band, and it was measured at the *most* contaminated (latest) phase, where drift makes frames *slower*. If anything it is **understated**. |
| lights | −5.01ms | **WITHDRAWN — inside the noise.** |
| characters | −3.33ms | **WITHDRAWN — inside the noise.** |
| grass/clutter | −1.38ms | **WITHDRAWN — inside the noise.** The "grass is free" claim is not established. |

**The renderer A/B STANDS.** All four `all_systems_on` rows are phase 1 (t≈9s post-warmup, no toggle),
so they are measured at the same point on the escalation curve. Control t0 (17.9) vs the A/B's Forward+
row (18.8) is ~1 fps of run-to-run spread; the Mobile gap is **+36%**, far outside it. **Nothing
clears 30** is likewise safe — the entire drift band sits below 30.

**Method debt this creates:** a live firefight is the right scene for a *renderer* A/B (identical
timepoint, two builds) and the **wrong** scene for a *toggle-diff*. Per-system attribution needs a
frozen arena (`hot_start=false`, no reinforcement waves, corpses disabled) or an A/B/A design that
re-measures the baseline between every toggle. Until then, only the two large findings above are real.

## STILL OWED

1. **The gating FPS number is the Summoner's to set** (365s step 4). Measured floor is now honest:
   **18.8 native / 22.3 shipped (Forward+), 25.5 native / 29.9 shipped (Mobile)** — night arena.
2. **`rendering_method` stays `forward_plus`** — unchanged tonight. Evidence is above; the call is his.
3. **Pillar-1 light-telegraph check under Mobile's ~8-omni cap NOT DONE** (5kr3's other half). An FPS
   number does not answer it, and a dropped muzzle flash is a Fairness-Law breach, not an atmosphere bug.

---

# 2026-07-18 OVERNIGHT — NO NEW FPS ROW, BY DESIGN

Task 45 asked for a native Forward+ datapoint in the populated patrol world. The overnight
stop-lines forbade windowed runs (Summoner asleep at the machine) and a headless dummy renderer
cannot measure GPU frames. **No number was recorded that night rather than a fake one.** The world DID get
heavier tonight (fsb_main = 678 meshes/1,116 bodies + 4 villages + 3 camps resident) and lighter
(billboard PNGs gone, procedural firebase gone, offer-flow scenes gone). First honest row = the
Summoner's morning walk-out with the F3 overlay, or the next sanctioned windowed bench.

**Morning row (2026-07-18, sanctioned single windowed run, closed immediately):**
`tests/windowed_patrol_perf.tscn` - real GameFlow entry, populated patrol world, op seed 47225,
NATIVE 1.00, Forward+, Intel UHD, player standing at the fsb_main spawn (default view), 8s warmup +
12s average: **28.8 fps | 217 draws | 116,094 prims**. CAVEATS, said out loud: this is the SPAWN
VIEW into the base interior, not a jungle sightline, not a firefight, weather/time = whatever seed
47225 rolls; gpu_ms unavailable (measured-render-time flag not enabled in this scene). It does NOT
generalize to the night-arena rows above and is not the gate number - it is the patrol world's
first honest datapoint.

---

# 2026-07-18 — W0 HEADLESS CPU BASELINE (AI consolidation decree, first counter row)

**Harness:** `tests/test_arena_perf.tscn` headless (hot_start, 3+3 squads x6 + one forced wave/side,
**65-67 live units** at sample end - deliberately OVER the shipped load), 4s warmup + 12s sample, on
the uncommitted W0 tree atop `e84bec82`. Headless = AI/physics/logic only. **GPU-ms / windowed fps /
draw calls: needs-windowed - the Summoner runs that batch.** Two runs, numbers stable across both.

| metric | run 1 | run 2 |
|---|---:|---:|
| headless avg fps | 2.2 | 2.3 |
| physics frames in 12s window | 720 (8-step saturated) | 720 |
| rays/s total (perc / wit / los-other / cover / bullet) | 152 (21/0/89/35/8) | 161 (18/0/102/29/12) |
| rays per physics frame | 2.53 | 2.68 |
| ai ms/physics-frame: think | 1.28 | 1.20 |
| ai ms/physics-frame: move_and_slide | 9.06 | 8.78 |
| ai ms/physics-frame: hitzone sync | 10.43 | 9.87 |
| ai ms/physics-frame: anim/execute remainder | 19.04 | 17.63 |
| ai ms/physics-frame: SUM | **39.8** | **37.5** |

**THE ATTRIBUTION THE DECREE DEMANDED (DA sec.2), now measured, not argued:** at 65+ live units the
AI physics wall is ~38-40 ms per physics tick, and **perception rays + think are ~6% of it**
(rays ~2.6/frame level-wide - microseconds; think 1.2 ms). The wall is the BODY:
hitzone sync (~10 ms) + move_and_slide (~9 ms) + the execute/anim remainder (~18 ms). Wave A's
milliseconds live in **A2 (body gate)**; A1 is architecture + the A4 platform, exactly as the
devil's advocate predicted from the raycast math. Counters live at: `CombatManager.rays_*` /
`CombatManager.ai_usec_*`, overlay ray line + physics-bucket section in `arena_perf_overlay.gd`,
1 Hz feed in `ai_stress_arena._report_ai_buckets`.

Inherited errors visible in arena runs (NOT W0's, present at HEAD): `damage_system.gd:107` reads
`terrain_manager.heightmap.height_scale` - the arena's TerrainManagerStub has no heightmap, so
RPG/grenade craters error headless (crater-retune commit `e84bec82` fallout). Main-scene headless
boot: 0 SCRIPT ERROR.

---

# 2026-07-18 — WA-A2 BODY GATE (headless before/after, same harness as the W0 row)

**Change:** sim-side body gate in `enemy_base` + `ally_base` `_physics_process`. BODY
(gravity, `move_and_slide`, `HitzoneBuilder.sync`, `_update_sprite`) runs only when
`_body_gate_open()`: perceivable (CombatManager.perceivable: player-camera dist ≤150m AND
(≤20m near-bubble OR camera-forward dot >0), no rays, headless-valid) OR |velocity|>eps OR
COMBAT state OR alert_tier>RELAXED (enemy) / target held (ally) OR downed OR cover-exit
window OR de-phased 300ms heartbeat. BRAIN never gates: think accumulator/_think, hearing,
suppression decay, gut-bleed, downed bleed-out, fire/damage-decay clocks all tick before the
gate branch (DA TRAP 2). Census counters `CombatManager.bodies_run/bodies_gated` + overlay
`bodies/f` line + bench print.

**Harness:** `tests/test_arena_perf.tscn` headless, same recipe as the W0 row, uncommitted
WA-A2 tree atop `021bb928` (before = same tree with the 5 gate files stashed, same night,
same machine state). Live-unit count at sample end varies per run (the arena escalates);
per-unit column is the honest comparator.

| run | live | think | move | hitzone | anim | SUM ms/pf | ms/unit | gated % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| BEFORE A | 65 | 0.428 | 3.096 | 3.977 | 7.529 | 15.030 | 0.231 | - |
| BEFORE B | 62 | 0.414 | 3.001 | 3.692 | 7.036 | 14.143 | 0.228 | - |
| AFTER 1 | 69 | 0.440 | 3.182 | 4.137 | 7.259 | 15.018 | 0.218 | 0% |
| AFTER 2 | 71 | 0.454 | 3.230 | 4.285 | 7.211 | 15.180 | 0.214 | 0% |

**Reading, said honestly:** in THIS bench the gate never closes - hot_start puts every unit
in COMBAT tier (gate open by contract) and `spawn_player=false` means no observer, which the
oracle treats as stay-hot. So the row proves the gate costs nothing when everyone is
legitimately hot (per-unit 0.229 -> 0.216 ms, a wash inside noise) and 0% gated is the
CORRECT census for a firefight. The gate's payoff class - stationary RELAXED unperceivable
men (far camps, garrison idlers) - does not exist in this scene; the number that will show
it is the patrol long-walk bench (WB gates on it) and the windowed night-arena batch
(Summoner-run, overlay now carries the `bodies/f run/gated` line). `test_body_gate` proves
the gate CLOSES and the brain keeps ticking: 200m unit gated, still thinks at LOD rate,
still hears, downed + cover-exit units never gated.

Note vs the W0 row above: the W0 tree measured 38-40 ms SUM at 65-67 live; tonight's HEAD
measures ~14-15 ms at 62-71 live BEFORE the gate. The delta belongs to what landed between
the W0 tree and HEAD plus machine state, not to A2 - the A2 claim is only the before/after
pair in this table.

### WA-A2 payoff, measured where the payoff class LIVES (Overseer, 2026-07-18)

`tools/diag_body_gate_payoff.tscn` — real patrol world, seed 47225, player present,
20 samples after settle:

| population | gated share | note |
|---|---|---|
| 13 live (5 enemies, 8 allies) | **9.4%** | hub start, LazyGroups not yet materialized |

**Said plainly: A2's payoff today is small, and the reason is population, not mechanism.**
The gate closes exactly on the class it was built for (stationary RELAXED men the player
cannot perceive), and at hub start that class is one enemy in ten. It grows with the
resident population — the far camps and garrisons that WB's DORMANT/AGGREGATE tiers exist
to hold — so A2 is banked as the CORRECTNESS prerequisite (brain always ticks; body follows
perceivability) and WB is where the milliseconds are. No claim beyond the measurement.

---

### 2026-07-20 — FIRST run of `tests/perf_probe.gd` against the REAL patrol world (bead `s7wo`)

**This is the first time this probe has ever executed.** Its previous form named two symbols that
never existed (`BillboardVegetation`, `world.billboard_vegetation`) and built its own bare
`game_world` at seed 2077 — terrain with no firebase, no sites, no LazyGroups. Every attribution row
above it in this ledger describes a world nobody plays.

- Harness: `--perf-probe --perf-cycle` on the normal boot; `GameFlow.enter_hub` attaches the probe to
  the live world (`scripts/main/game_flow.gd`), so the probe and the player share ONE world build.
- **Seed 47225** (`DEFAULT_OPERATION_SEED`), spawn `984,719`, `[SPAWN-TRUTH] delta=-0.00`.
- Window **1280x720**, `scaling_3d/scale = 0.75`, renderer **forward_plus** (key restored to
  `project.godot` this session), vsync off, `max_fps=0`.
- Hardware: Intel UHD Graphics, Godot 4.7.stable. Stationary at the firebase spawn.
- Two full passes, ~7s per phase after a 2.5s settle.

| phase | run 1 fps | run 2 fps | run 1 dFps | run 2 dFps | prims (run 1) | calls (run 1) |
|---|---:|---:|---:|---:|---:|---:|
| baseline | 25.1 | 23.7 | — | — | 270,084 | 1,407 |
| no_canopy | 29.8 | 25.9 | +4.7 | +2.2 | 254,655 | 364 |
| no_clutter | 26.7 | 25.5 | +1.6 | +1.8 | 266,843 | 1,354 |
| **no_sun_shadow** | **36.0** | **34.2** | **+10.9** | **+10.5** | **144,454** | 1,251 |

**The finding — the sun shadow is the frame, and the old headline was wrong.**
- **Sun shadow is the dominant lever and the only one that reproduces tightly** (+10.9 / +10.5 FPS).
  It carries **~126-129k primitives, 46% of every primitive in the frame.** Nothing else is close.
- **Canopy does not reproduce** (+4.7 vs +2.2) and cannot be ranked from these two passes — but it
  owns **~70% of the draw calls** (1,407 -> 364). Its cost is call-bound, not primitive-bound.
- **Ground clutter is small and honest** (+1.6 / +1.8).
- Baseline drifted **25.1 -> 23.7 between runs (1.4 FPS)** on identical config. Any future single-pass
  A/B on this hardware is inside the noise floor. A/B/A or nothing.

**No lever was pulled.** The default is unchanged; `no_sun_shadow` is an instrument phase only.
Choosing it is ADR-026 / `mok6` / `4rd4` work and belongs to the Summoner.

**No pass/fail is claimed.** The probe prints `FAIL: perf gate missed (baseline avg 25.1 < 30)`
against a **30 FPS constant hardcoded at `tests/perf_probe.gd:170`**. That constant is not a ratified
gate — no gating FPS number exists. Read the rows, ignore the verdict line.

**NOT measured: the LazyGroup A/B/A (`l9kh`).** LazyGroup spawning has no toggle, and building one
would be a change to `mission_generator`, not a measurement. Reported unmeasured rather than estimated.
