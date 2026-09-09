# RECONgame Performance Ledger

The single honest record of measured frame rates. Every number here names the render scale it
was measured at (the standing sin — bead `365s` — was quoting scaled numbers as if native).

> ## THERE IS NO NUMERIC FPS GATE. (Summoner, 2026-07-20: *"No numeric gate — my eyes decide."*)
>
> Every "the 30 gate" / "clears the gate" phrase below this banner is **historical shorthand for a
> working target that was never ratified** — read it as a yardstick the measurers chose, never as a
> pass/fail line this project agreed to. Performance is **ongoing tuning discharged by playtest**
> (bead `u4h2`), and no number in this file passes or fails anything. `tests/perf_probe.gd` was
> corrected on 2026-07-20 to report figures and adjudicate nothing — it previously printed a
> hardcoded `FAIL: perf gate missed (baseline avg < 30)`.
>
> The measurement contract below still binds in full: a number without its scale, renderer and seed
> is not a number.

## Measurement contract
- **Always record `rendering/scaling_3d/scale`.** `0.77` = 59.3% of native pixels; a number at 0.77 is
  NOT a native number.
- **Always record the renderer** (`rendering/rendering_method`). ADR-026 Amendment A ratifies
  `forward_plus`. **CORRECTED 2026-07-26: the `project.godot:300` pointer is DEAD — the key is not in
  the file at all.** The `[rendering]` block (`project.godot:302-310`) contains only
  `renderer/rendering_method.mobile="gl_compatibility"` (`:305`); the desktop key has been stripped by
  an editor save, exactly as the failure mode predicted. Forward+ therefore holds **only by being the
  desktop default**. **Verify the renderer AT RUNTIME** (the harness already prints it —
  `tests/windowed_patrol_perf.gd:48`), never by grepping `project.godot`.
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

> ### RETRACTED 2026-07-20 (later) — THE SUN-SHADOW ROWS IN THIS ENTRY ARE THE SAME BENCH ARTIFACT.
> This entry predates the fix and carries the identical defect the entry below it retracts:
> `tests/perf_probe.gd:123` read `sun.shadow_enabled = phase_name != "no_sun_shadow"`, so **every
> baseline here was measured with a shadow the shipped world does not render**
> (`scripts/levels/game_world.gd:48` sets `shadow_enabled = false`). The `+10.9 / +10.5` is the probe
> paying back a cost it had itself added; the `25.1 / 23.7` baselines are not the shipped game's frame
> rate; and the canopy figures are **understated** because canopy geometry was partly hidden inside the
> shadow pass. **Corrected picture: baseline ~34 FPS, canopy +6.3 (the only lever above noise),
> no_sun_shadow −0.2** — see "SHIP-PARITY A/B/A" at the end of this file. Rows left as measured
> (ADR-014). Guarded since 2026-07-20 by `tests/test_ship_parity.tscn`.

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

---

# 2026-07-20 — ADR-026 PART A #1: THE CAMPFIRE LIGHT DIES, AND AN A/B/A THAT RANKS THE CANOPY

> ## ⚠ READ FIRST — EVERY GPU FIGURE IN THIS ENTRY WAS MEASURED ON A BROKEN INSTRUMENT.
> `tests/perf_probe.gd:123` (as committed in `74715b86`, the commit this entry documents) forced
> `sun.shadow_enabled = true` on all eight phases except `no_sun_shadow`, while the shipped world runs
> `false` (`game_world.gd:48`). **Every row below was therefore measured against a baseline the game
> never renders.** See the RETRACTION and the ship-parity re-measure further down this file.
>
> **What is retracted:** this entry's `no_sun_shadow +9.8 / +9.4 / +7.2` — the lever was refunding a
> cost the probe itself added; corrected it is **−0.2, inside noise**. The title's canopy claim is
> **understated, not wrong** (`+2.2` here vs **`+6.3`** at ship parity — a shadowed baseline hides
> canopy cost, because the shadow pass re-renders the same geometry). The ~23–25 FPS baselines are not
> the shipped frame rate; ship parity reads **~34**.
>
> **I own this.** The defect pre-dated my session, but I ran it three times, published the output as
> *"STANDS — the dominant term"* and *"reproduces a third time"*, and treated reproducibility as
> validity. **Three consistent measurements of an artifact are still an artifact.** The A/B/A design
> was sound and it tightened the noise floor; it could not have caught this, because a bracketed
> baseline that is uniformly wrong is uniformly wrong.
>
> **What SURVIVES this retraction unchanged**, because none of it is a GPU figure:
> - **Seed 47225 rolls `time=DAY`, `_add_campfire` is night-gated, so the default world contains ZERO
>   campfires and this change banks 0.0 FPS there.** A scene-graph census, independently reproduced by
>   the ship-parity run (`no_campfires +0.0`).
> - The light census (zero non-exempt real-time light spawners repo-wide) and `test_fake_lights` 18/18.
> - The conclusion that this change **does not bank anything close to ~8.6 FPS.**
>
> **My night-seed campfire before/after (Runs 2 and 3) was NOT covered by the ship-parity re-measure**
> — that run used seed 47225, which has no campfires. **It has now been re-measured at ship parity;
> see "THE CAMPFIRE, RE-MEASURED AT SHIP PARITY" at the end of this file. The conclusion did not
> change — it got stronger.**
>
> **My bug, found by the same fix:** `get_tree().quit(0)` ended up stranded after the `return` in the
> `_spread_of_baselines()` helper I added, so it never ran. **That is why every bench in this entry
> left an orphaned Godot process** that I had to `taskkill` — I treated the symptom three times and
> never diagnosed it.

**The change.** `mission_generator.gd:352` `_add_campfire` spawned a real `OmniLight3D`
(energy 1.8, range 14m) per village fire. **Deleted.** Replaced with the technique `gun_fx` already
uses: two unshaded additive billboards (a 3.2m glow halo + a 0.7x0.9m flame core) whose
`emission_energy_multiplier` carries the original 0.12s flicker beat, particles unchanged. This was
the last non-exempt real-time light spawner in the codebase.

**Light census after this change** (`OmniLight3D.new()` / `SpotLight3D.new()`, repo-wide):
`illum_flare.gd:30` (EXEMPT — `is_lit()` does stealth work) · `tunnel_room.gd:55` (EXEMPT — interior,
player-triggered) · `ai_stress_arena.gd:537` (EXEMPT — the 4 bench campfires `ps2_perf_probe` A/Bs).
**Zero non-exempt dynamic light spawners remain.** Guarded by `tests/test_fake_lights.gd`, now
**18 checks / 0 FAIL** (was 12) — three source assertions on the campfire, two that the exemptions are
not over-deleted, and a negative control on the source scanner itself.

## ⚠ THE MEASUREMENT FINDING THAT MATTERS MOST: SEED 47225 HAS NO CAMPFIRES

`_add_campfire` is called from exactly one place — `mission_generator.gd:643`, gated on
`time_str in ["NIGHT", "DUSK", "DAWN"]`. **Seed 47225 rolls `time=DAY` `weather=MONSOON`**
(`MissionGenerator.conditions_for(47225)`, verified headless — pure CPU logic, no GPU figure involved).

**The probe confirmed it live: `[PERF] phase -> no_campfires (campfires=0)`.** The mandated bench seed
builds a world with **zero campfires in it**, so at seed 47225 this change banks **exactly 0.0 FPS**,
and the `no_campfires` row below measures nothing. The probe now prints the campfire census on every
phase line and `push_warning`s on a zero-count toggle, so a world with nothing to hide can never again
read as "campfires are free".

`TIME_TABLE` (`mission_generator.gd:41`) is 5 DAY of 10 entries, so **half of all seeds have no
campfire at all.** This is a conditional lever, not an always-on one.

### Run 1 — seed 47225, A/B/A, the shipped default

Windowed, **1280x720**, `scaling_3d/scale = 0.75`, renderer **forward_plus**, vsync off, `max_fps=0`,
**Intel UHD Graphics**, Godot 4.7.stable, stationary at the fsb_main spawn. 9 phases, ~7s each after a
2.5s settle. **Every lever is bracketed by its own two baselines** and scored against their mean.

| phase | fps avg | prims | draw calls | objs |
|---|---:|---:|---:|---:|
| baseline | 21.5 | 285,151 | 1,458 | 2,360 |
| no_campfires | 21.8 | 284,245 | 1,452 | 2,346 |
| baseline_2 | 22.1 | 275,359 | 1,428 | 2,319 |
| no_canopy | 24.3 | 275,139 | **457** | 1,368 |
| baseline_3 | 22.2 | 285,545 | 1,524 | 2,493 |
| no_clutter | 22.5 | 286,562 | 1,511 | 2,495 |
| baseline_4 | 22.4 | 284,912 | 1,506 | 2,396 |
| **no_sun_shadow** | **32.0** | **152,488** | 1,314 | 1,965 |
| baseline_5 | 21.9 | 284,387 | 1,498 | 2,479 |

| lever | dFps | dPrims | dCalls | verdict |
|---|---:|---:|---:|---|
| no_campfires | +0.0 | +3,989 | +9 | **MEASURES NOTHING — campfires=0 at this seed** |
| no_canopy | **+2.2** | −5,312 | **−1,018** | **STANDS (first time)** |
| no_clutter | +0.2 | +1,333 | −4 | inside noise |
| **no_sun_shadow** | **+9.8** | **−132,161** | −188 | **STANDS — the dominant term** |

**Baseline spread across the whole run: 0.9 FPS.** That is the honest noise floor, and it is *tighter*
than the 1.4 FPS drift the 2026-07-20 single-baseline run reported — the A/B/A bracketing is why. The
probe now prints this figure itself and tags any delta inside it `INSIDE NOISE`.

**THE CANOPY IS NOW RANKED — the standing gap in this ledger is closed.** The prior run could not rank
it (+4.7 then +2.2, against a 1.4 drift). This run reproduces **+2.2 against a 0.9 floor**, so it is
outside noise and real, and its shape is confirmed: it drops **1,018 of 1,458 draw calls (70%)** while
moving primitives by ~0. **Canopy is call-bound, not primitive-bound, and it is worth ~2 FPS — not the
+4.7 the optimistic pass suggested.** Caveat kept from the prior entry: this pose faces the firebase
interior, not a jungle sightline.

**Sun shadow reproduces a third time** (+10.9 / +10.5 / **+9.8**) and still carries ~46% of all
primitives (132,161 of 285,151). It remains the frame's dominant lever. **No lever was pulled** — all
four are instrument phases; choosing any is the Summoner's call (`mok6` / `4rd4`).

**No pass/fail is claimed.** There is no ratified FPS gate; `perf_probe.gd`'s hardcoded verdict was
removed on 2026-07-20 and was not reintroduced.

### Run 2 — seed 12 (NIGHT, `campfires=4`), the build that SHIPS the fake fire

Seed 47225 cannot see this change, so the campfire was measured where it exists. **Seed 12 rolls
`time=NIGHT` and the probe counted `campfires=4`** — the same four-fire load the original arena bench
measured. Same config otherwise: windowed 1280x720, scale 0.75, forward_plus, Intel UHD, 4.7.stable.

| phase | fps avg | prims | draw calls |
|---|---:|---:|---:|
| baseline | 21.6* | 316,515 | 1,753 |
| no_campfires | 23.6 | 327,738 | 1,839 |
| baseline_2 | 23.8 | 323,386 | 1,803 |
| no_canopy | 26.2 | 308,810 | **560** |
| baseline_3 | 22.8 | 313,381 | 1,745 |
| no_clutter | 23.1 | 322,040 | 1,790 |
| baseline_4 | 22.4 | 325,887 | 1,842 |
| **no_sun_shadow** | **32.1** | **142,623** | 1,407 |
| baseline_5 | 23.0 | 321,511 | 1,843 |

\* `fps_min=8.0` — the screenshot-capture stall. `SCREENSHOT_AT` (1.5s) sits inside `SETTLE` (2.5s) so
the stall frame itself is never sampled, but its recovery frames leak past the settle and depress the
FIRST baseline in every run. **This is why the noise floor here is 2.2 FPS against run 1's 0.9.** The
other four baselines span only 22.4–23.8. Stated rather than corrected — the instrument is unchanged
between runs, so the comparison holds.

| lever | dFps | dCalls | verdict |
|---|---:|---:|---|
| **no_campfires (4 FAKE fires)** | **+0.9** | +60 | **INSIDE NOISE (floor 2.2)** |
| no_canopy | +2.9 | **−1,213** | stands; reproduces run 1's +2.2 |
| no_clutter | +0.5 | −3 | inside noise |
| no_sun_shadow | **+9.4** | −435 | stands; −181,076 prims |

**Hiding all four shipped campfires buys +0.9 FPS, which is inside this run's noise floor.** That is
the intended result: the fake fire is close to free.

### Run 3 — seed 12, the SAME build with the four `OmniLight3D`s temporarily restored

To price the light itself rather than old-build-vs-new-build, the deleted `OmniLight3D` was added back
**alongside** the billboards for one run and removed again immediately. This isolates the light: the
`no_campfires` lever now hides `light + billboards + particles` instead of `billboards + particles`,
and the difference between the two runs' levers is the light's own cost. Both are measured *within*
their own run, so cross-run baseline drift cannot enter the comparison. Same config and seed.

| phase | fps avg | prims | draw calls |
|---|---:|---:|---:|
| baseline | 19.6 (min 4.0*) | 365,099 | 2,173 |
| no_campfires | 21.2 | 367,227 | 2,208 |
| baseline_2 | 19.0 | 370,514 | 2,271 |
| no_canopy | 23.9 | 353,137 | **1,045** |
| baseline_3 | 20.8 | 360,602 | 2,193 |
| no_clutter | 20.9 | 362,886 | 2,194 |
| baseline_4 | 20.3 | 359,127 | 2,157 |
| no_sun_shadow | 28.6 | 154,109 | 1,536 |
| baseline_5 | 22.4 | 370,288 | 2,249 |

| lever | dFps | verdict |
|---|---:|---|
| **no_campfires (4 fires WITH real lights)** | **+1.9** | **INSIDE NOISE (floor 3.4)** |
| no_canopy | +4.1 | stands |
| no_clutter | +0.3 | inside noise |
| no_sun_shadow | +7.2 | stands |

## WHAT THIS CHANGE ACTUALLY BANKS — SAID PLAINLY

| build, seed 12 night, 4 campfires | cost of the whole campfire subsystem | run noise floor |
|---|---:|---:|
| with real `OmniLight3D` (run 3) | +1.9 FPS | 3.4 |
| with the shipped fake fire (run 2) | +0.9 FPS | 2.2 |
| **implied cost of the four LIGHTS alone** | **~1.0 FPS** | — |

**THE ~1.0 FPS FIGURE IS NOT A RESOLVED MEASUREMENT AND MUST NOT BE QUOTED AS ONE.** Both levers it is
derived from fell *inside their own run's noise floor*. The honest statement is: **the four campfire
lights cost less than this instrument can resolve at this pose — bounded above at roughly 2 FPS, and
consistent with ~1.** No estimate is offered beyond that bound.

**Against the "~+8.6 FPS" the bead claims for ADR-026 Part A #1: this change does not bank it, and
neither did the muzzle-flash half.** Three things separate the two figures, all measurable:
1. **The 8.6 came from `ai_stress_arena`** — a night firefight with 4 bench campfires *plus* flares,
   fires and a live 18v18. That is `ps2_perf_probe`'s `BenchLights` root, a deliberately adversarial
   instrument, not the shipped world.
2. **The shipped patrol world has at most 4 campfires and only at night.** Seed 47225 — the default —
   has **zero**, so for the seed the game actually boots into, this change banks **0.0 FPS**.
3. **Muzzle flashes are 45–60ms transients.** `FLASH_SECONDS = 0.06`; a flash light was never resident
   in the frame long enough to carry a sustained FPS delta.

**So the win is real but small, and it is a CANON win before it is a perf win.** ADR-026's cap (<=8
real-time lights, 0 dynamic shadows) is now structurally true in the shipped world rather than
aspirational: there are **zero non-exempt dynamic light spawners left in the codebase**, so no future
scene can quietly reintroduce a per-event light without turning `test_fake_lights` red.

**Where the frame actually is, measured three times today across two seeds:** the sun shadow
(+9.8 / +9.4 / +7.2, ~46% of all primitives) and the canopy (+2.2 / +2.9 / +4.1, ~70% of draw calls).
Campfire lights are not in that league and this ledger should stop implying they are.

> ### RETRACTED 2026-07-20 (same day, later run) — THE SUN-SHADOW FIGURES ABOVE ARE A BENCH ARTIFACT.
> The `+9.8 / +9.4 / +7.2` is **not a saving that exists**, and the canopy figures on this line are
> **understated**. `tests/perf_probe.gd:123` read `sun.shadow_enabled = phase_name != "no_sun_shadow"`,
> which **turned the shadow ON for all eight other phases** — including every baseline. The shipped
> patrol world runs `shadow_enabled = false` (`game_world.gd:48`), so the probe was measuring the cost
> of a shadow it had enabled itself, against a baseline the game never renders.
> **This is the SECOND time this exact artifact was measured and believed** — ADR-026:137-144 retired
> the identical −12.17ms claim on 2026-07-17 when `ai_stress_arena.gd` was the culprit. That wave
> brought the *arena* to ship parity and left `tests/perf_probe.gd` unfixed; the artifact simply moved
> harnesses. Corrected figures in the entry below. Rows above are left as measured.

### Instrument changes made this session (`tests/perf_probe.gd`)
- **A/B/A by construction**: 9 phases, every lever bracketed by its own two baselines and scored
  against their mean, so run drift is halved instead of landing in one delta.
- **The noise floor is now measured and printed** (`PERF DRIFT`, the widest gap between any two
  baselines), and any delta inside it is tagged `INSIDE NOISE` on its own row.
- **Campfire census on every phase line** + a `push_warning` when the lever finds nothing to hide, so a
  zero-campfire world can never read as a free system. This is the check that caught the seed-47225 problem.
- `--perf-seed=N` (`game_flow.gd`) benches a non-default seed. **Measurement override only — the shipped
  default remains 47225.**
- **Known artifact, stated not hidden:** `SCREENSHOT_AT` (1.5s) sits inside `SETTLE` (2.5s), so the
  capture frame is never sampled, but its recovery frames depress the FIRST baseline of every run
  (`fps_min` 14.0 / 8.0 / 4.0). It inflates the reported noise floor and makes it conservative, never
  optimistic. Worth fixing before the next attribution pass.

---

# 2026-07-20 (later) — SHIP-PARITY A/B/A: THE SUN-SHADOW LEVER DOES NOT EXIST, AND THE CAP BUYS NOTHING

Config for every row below: **seed 47225**, `scaling_3d/scale = 0.75`, renderer **forward_plus**,
**Intel UHD Graphics**, Godot 4.7.stable, **windowed** (headless renders nothing), single Godot
instance verified before each run.

## What was wrong with the instrument

`tests/perf_probe.gd:123` forced `sun.shadow_enabled = true` on every phase except `no_sun_shadow`.
The shipped world sets it **false** (`game_world.gd:48`). Three consequences, all measured below:

1. The `no_sun_shadow` "win" was the probe paying back a cost **it had just added**.
2. Every other lever was scored against a **shadowed** baseline the game never renders, which
   **suppressed the canopy delta** (the shadow pass re-renders the same jungle geometry).
3. The published baseline of **23–25 FPS was not the shipped game's frame rate.**

Fixed by capturing the world's own shadow config at `attach()` and reproducing it in every baseline.
The lever now `push_warning`s when it is a no-op, matching the campfire-census pattern that caught the
seed-47225 problem.

## Run 1 — corrected attribution cycle (`-- --perf-probe --perf-cycle`)

`[PERF] ship config: sun shadow_enabled=false max_distance=100.0`

| phase | fps avg | prims | calls | objs |
|-------|--------:|------:|------:|-----:|
| baseline | 34.9 | 157,333 | 1,346 | 2,011 |
| no_campfires | 34.8 | 157,364 | 1,351 | 2,052 |
| baseline_2 | 34.6 | 158,343 | 1,377 | 2,048 |
| no_canopy | **40.4** | 144,963 | 355 | 1,109 |
| baseline_3 | 33.6 | 159,088 | 1,405 | 2,146 |
| no_clutter | 34.3 | 158,510 | 1,378 | 2,054 |
| baseline_4 | 33.4 | 159,891 | 1,411 | 2,080 |
| no_sun_shadow | 33.6 | 160,704 | 1,411 | 2,082 |
| baseline_5 | 34.1 | 156,347 | 1,378 | 2,032 |

**Noise floor this run: 1.4 FPS.**

| lever | dFps | verdict |
|-------|-----:|---------|
| no_campfires | +0.0 | INSIDE NOISE (0 campfires at this seed) |
| **no_canopy** | **+6.3** | **the only lever above noise** |
| no_clutter | +0.8 | INSIDE NOISE |
| **no_sun_shadow** | **−0.2** | **INSIDE NOISE — the lever measures nothing** |

**THE SHIPPED BASELINE IS ~34 FPS, not 23–25.** The old number carried a shadow the game does not ship.
**The canopy delta ROSE from ~+2–4 to +6.3** once the baseline was honest: it had been partly hidden
inside the shadow pass. The canopy is now the *only* measured lever above the noise floor, which is
exactly what ADR-026:145-147 already said ("the remaining GPU bomb is the jungle").

## Run 2 — what the sun shadow would COST if it were ever turned on (`-- --perf-probe --shadow-study`)

This is an atmosphere-price study, **not a saving**. Shadows are off today.

| phase | fps avg | prims | calls | objs |
|-------|--------:|------:|------:|-----:|
| ship (shadows off) | 34.5 | 149,431 | 1,283 | 1,934 |
| shadow_40m | 24.2 | 264,858 | 1,429 | 2,107 |
| shadow_80m | 24.0 | 275,359 | 1,409 | 2,203 |
| shadow_uncapped (100m) | 24.3 | 271,855 | 1,388 | 2,305 |
| ship_2 | 35.0 | 146,740 | 1,277 | 1,930 |

**Noise floor this run: 0.5 FPS.**

| setting | dFps vs ship |
|---------|-------------:|
| shadow_40m | **−10.5** |
| shadow_80m | **−10.8** |
| shadow_uncapped | **−10.4** |

### THE NEAR-FIELD CAP IS NOT A MITIGATION
**40m, 80m and uncapped are identical within a 0.5 FPS noise floor.** Shortening
`directional_shadow_max_distance` concentrates shadow-map resolution nearer; it does **not** meaningfully
reduce the geometry submitted to the shadow pass (+117k to +127k primitives at all three settings).
On this hardware the sun shadow is **binary**: pay ~10.5 FPS (~30% of the frame) or do without.
**ADR-026 Part A #2's "near-field-capped (≤40m)" option is therefore not a cheap middle ground** — the
ADR's other listed option, **OFF, is what ships and is the only affordable one.** ADR-026 A.2 is
already compliant today; no change was needed and none was made to shipped config.

## The draw-distance floor is NOT crossed — verified, not assumed
ADR-026's hard blocker requires player draw distance ≥ AI sight range (`SIGHT_CAP_OPEN = 140m`).
Evidence, from the tables above: enabling/capping the shadow **only ever ADDS** primitives and objects
(149,431 → 264,858 prims; 1,934 → 2,107 objs). Nothing is removed at any cap. A setting that clipped
geometry or foliage would show prims/objs **below** the ship row; none does. `directional_shadow_max_distance`
governs the shadow pass alone and has no effect on mesh visibility or LOD. And in shipped config the sun
casts no shadow at all, so the floor is untouched by construction.

## Instrument fixes this session (`tests/perf_probe.gd`)
- **Ship parity**: baselines reproduce the world's own `shadow_enabled` / `directional_shadow_max_distance`
  instead of forcing shadows on. The no-op case now warns loudly.
- **`get_tree().quit(0)` was DEAD CODE** — stranded after the `return` in `_spread_of_baselines()`, so
  **the probe never exited on its own.** This is the cause of the orphaned Godot processes that
  contaminated earlier benches. Moved to the end of `_finish()`; both runs above exited 0 with
  0 processes left behind.
- **Screenshot artifact fixed**: `SCREENSHOT_AT` moved 1.5s → 0.25s. `Engine.get_frames_per_second()`
  reports frames over the *previous second*, so a capture stall at 1.5s was still depressing the first
  sampled reading at 2.5s. The prior entry flagged this as "worth fixing"; it is fixed. Noise floors of
  1.4 and 0.5 FPS above are with the fix in.
- **`--shadow-study`** phase list added for the atmosphere-price question, with a screenshot per phase.

---

# 2026-07-20 — THE GUARD: `tests/test_ship_parity.tscn`

The ship-parity artifact was measured and believed **twice**, in two harnesses, ten weeks apart:
`ai_stress_arena.gd:390` (retired 2026-07-17, ADR-026:137-144) and then `tests/perf_probe.gd:123`
(retracted above). **Fixing one did not fix the other, and nothing structural prevented a third.**
This probe is that structure. Headless, in the suite (`run_all_tests.ps1` globs `test_*.tscn`).

**What it asserts.** It reads the shipped render config out of `scripts/levels/game_world.gd` rather
than hardcoding it, then holds every perf harness to two rules:

- **RULE A — no undeclared deviation.** Every write to a parity property (`shadow_enabled`,
  `directional_shadow_max_distance`) in a harness must assign the shipped value, assign a captured
  ship variable, or be **declared** in `tests/parity_baseline.json` with a dated reason.
- **RULE B — the reference row must exist.** A harness that deviates at all must *also* read the
  shipped value somewhere. **No register entry can satisfy Rule B** — a study phase cannot be
  grandfathered into having no baseline. This is the rule the historical defect trips hardest: it had
  exactly one shadow assignment, phase-dependent, and never captured ship at all.

**A study is still legal.** `--shadow-study` (40m/80m/uncapped) and the arena's F6 toggle are the four
declared entries in the register. The guard is on the **reference row**, never on the experiment.

**Harnesses are DISCOVERED, not listed** — any `.gd` under `tests/`, `tools/` or `scripts/levels/`
that reads `get_rendering_info` / `viewport_get_measured_render_time` / `get_frames_per_second`.
That is what covers the harness nobody has written yet; the 2026-07-17 fix failed precisely because it
was instance-shaped. Nine are covered today, including four `windowed_*` benches nobody had audited.

**Negative-controlled against the real bug, not a synthetic one.** Restoring
`sun.shadow_enabled = phase_name != "no_sun_shadow"` in `perf_probe.gd` (and removing the ship capture
the fix added) turns the probe **RED on both rules, exit 1**; reverting returns it to green, exit 0.
`perf_probe.gd` was verified byte-identical to its pre-test state afterward. The matcher also
self-tests **12/12 in both directions** on every run — four sources it must flag (including the defect
verbatim) and six it must not — so it cannot rot into a probe that only ever passes.

**Ratchet:** `tests/parity_baseline.json`, same shape as `fossil_baseline.json`. `count` + `ceiling`
are audited before the register is read, so a hand-edit cannot pass quietly. `--write-baseline` can
only remove; new entries require `--grandfather --reason="<why>"`, which appends dated provenance.

Also corrected this session: `arena_perf_overlay.gd`'s `_shadows_on` defaulted to `true` while ship is
`false`. `setup()` overwrites it from the live sun, so it was latent — but with a null sun the overlay
would have reported "F6 sun shadows [ON]" for a world that renders none. Now defaults to ship.

---

# 2026-07-20 (later still) — THE CAMPFIRE, RE-MEASURED AT SHIP PARITY

The campfire before/after in the ADR-026 Part A #1 entry above was measured on the broken probe
(shadow forced ON in every baseline), and the ship-parity re-measure that caught the artifact ran at
**seed 47225, which has zero campfires** — so it could not price this change. Redone here on the
fixed probe, at the only place the lever exists.

**Config (every row):** seed **12** (rolls `time=NIGHT`; probe census `campfires=4` — the same
four-fire load the arena bench used), windowed **1280x720**, `scaling_3d/scale = 0.75`,
renderer **forward_plus**, **Intel UHD Graphics**, Godot 4.7.stable, single Godot instance verified
before and after each run (`ps` count 0 both sides — the `quit(0)` fix holds).
`[PERF] ship config: sun shadow_enabled=false max_distance=100.0` on both runs.

## A — the build that SHIPS (fake fire: additive billboards + particles, no light)

| phase | fps avg | prims | calls |
|---|---:|---:|---:|
| baseline | 32.7 | 137,662 | 1,389 |
| no_campfires | 32.7 | 135,526 | 1,382 |
| baseline_2 | 33.8 | 135,530 | 1,384 |
| no_canopy | **41.3** | 120,122 | **183** |
| baseline_3 | 33.2 | 135,530 | 1,384 |
| no_clutter | 33.6 | 133,960 | 1,355 |
| baseline_4 | 32.7 | 135,562 | 1,384 |
| no_sun_shadow | 33.8 | 135,530 | 1,384 |
| baseline_5 | 33.5 | 135,530 | 1,384 |

**Noise floor 1.1 FPS.** `no_campfires` **−0.5 INSIDE NOISE** · `no_canopy` **+7.8** ·
`no_clutter` +0.6 INSIDE NOISE · `no_sun_shadow` +0.6 INSIDE NOISE (probe warned it measures nothing —
ship config already has the shadow off).

## B — the SAME build with the four `OmniLight3D`s temporarily restored, then removed again

| phase | fps avg | prims | calls |
|---|---:|---:|---:|
| baseline | 31.7 | 150,200 | 1,483 |
| no_campfires | 32.1 | 146,663 | 1,477 |
| baseline_2 | 32.2 | 149,131 | 1,473 |
| no_canopy | **40.4** | 130,247 | **250** |
| baseline_3 | 32.7 | 147,127 | 1,463 |
| no_clutter | 31.3 | 144,341 | 1,434 |
| baseline_4 | 29.9 | 145,499 | 1,469 |
| no_sun_shadow | 31.9 | 146,036 | 1,476 |
| baseline_5 | 31.9 | 145,438 | 1,476 |

**Noise floor 2.8 FPS.** `no_campfires` **+0.2 INSIDE NOISE** · `no_canopy` **+8.0** ·
`no_clutter` −0.0 · `no_sun_shadow` +1.0 INSIDE NOISE.

## THE ANSWER: THIS CHANGE BANKS NO MEASURABLE FPS, AND THAT IS THE FINDING

| | cost of hiding all 4 campfires | run noise floor |
|---|---:|---:|
| shipped fake fire | **−0.5 FPS** | 1.1 |
| with real `OmniLight3D` | **+0.2 FPS** | 2.8 |

**Both levers are inside their own run's noise floor, and they differ by 0.7 FPS — itself inside both
floors.** The honest statement is not "the lights cost ~1 FPS"; it is: **at ship parity the four
campfire `OmniLight3D`s cost less than this instrument can resolve, and deleting them banks nothing
measurable even at a night seed with all four fires lit.** At seed 47225 — the shipped default, which
rolls DAY — there are no campfires at all, so it banks a clean **0.0**.

**This supersedes my earlier "~1.0 FPS implied" figure**, which was derived from two levers measured
against a shadow-inflated baseline. Direction of the error, stated: a heavier baseline compresses FPS
deltas, so that figure was if anything generous. **The real number is "unmeasurable", not "small".**

**Against the bead's "~+8.6 FPS" for ADR-026 Part A #1: none of it is banked here, and none of it was
banked by the muzzle-flash half either.** The 8.6 came from `ai_stress_arena` — a night firefight with
flares, fires and 18v18 — measured with the same shadow artifact now retired twice. Muzzle flashes are
45–60ms transients (`FLASH_SECONDS = 0.06`) and were never resident long enough to move a sustained
average. **ADR-026 Part A #1 is a CANON win, not a perf win, and the bead should stop promising one.**

**What it does buy, and this is worth having:** ADR-026's cap (<=8 real-time lights, 0 dynamic
shadows) is now structurally true rather than aspirational. There are **zero non-exempt real-time
light spawners left in the codebase** (`illum_flare.gd:30`, `tunnel_room.gd:55`,
`ai_stress_arena.gd:537` are the three exempt-by-decree survivors), and `tests/test_fake_lights.gd`
(18 checks, 0 FAIL) turns red if one returns *or* if an exempt one is deleted.

**Canopy is confirmed as the only real lever, now at three seeds/configs:** +6.3 (seed 47225 ship
parity), **+7.8 and +8.0** (seed 12 night, both builds), against noise floors of 1.4 / 1.1 / 2.8. It
drops **~1,200 of ~1,400 draw calls (85%)** while moving primitives ~12%. It is call-bound, and it is
where the frame actually is.

---

## 2026-07-20 — WHERE THE CANOPY'S DRAW CALLS ACTUALLY COME FROM (measured, then STOOD DOWN)

Perf was deprioritised mid-investigation (Summoner: *"don't keep worrying about the fps that'll be
final polish well do in a few weeks"*). **No perf change was shipped and nothing was committed** — the
probes below were run, recorded here, and deleted. This entry exists so the diagnosis survives to the
polish pass. It supersedes nothing; the rows above stand.

Config: seed **47225**, **scale 0.75** (shipped, now `project.godot:308` — NOT native), renderer
**forward_plus** (runtime-verified; the `project.godot:299` pointer is dead — see the measurement
contract correction of 2026-07-26), 1280x720 windowed, Intel UHD, Godot 4.7.stable, single
instance verified. The canopy figure is a measured ON/OFF delta (`TreeCoverLayer.visible`), not an
estimate.

| measurement | value |
|---|---:|
| total draw calls in frame | 1,368 – 1,481 |
| draw calls with canopy hidden | 411 – 464 |
| **draw calls FROM the canopy** | **957 – 1,017** |
| fps at the seeded spawn pose | 30.7 |

### The mechanism, pinned

**MultiMesh is already used correctly and materials are already shared.** The canopy is not defeated
by per-instance materials, and there is no per-plant `MeshInstance3D` anywhere. The call count is
simply the **node count**: one `MultiMeshInstance3D` per group, one draw call each.

- Species meshes carry **1 surface** each (4 palms carry 2) — `tree_cover_layer.gd:323` `_extract_mesh`
  takes the first mesh only. Surfaces are **not** the multiplier.
- `tree_cover_layer.gd:110` keys every group as **`[species, bucket_x, bucket_z]`** with
  `BUCKET = 64.0` (`:52`), and `:132`/`:135` emit **two** nodes per group — a near solid
  (`0..near_distance`) and a far card (`near_distance..view_distance`).

> **Pointer correction, 2026-07-26 (NO DRIFT law).** The four pointers in this section were written
> against the 2026-07-20 file and had all shifted: `:199 → :323`, `:94 → :110`, `:47 → :52`,
> `:115/:118 → :132/:135`. The *mechanism* described is unchanged and re-verified against the live
> file; only the line numbers were stale. Corrected in place.
- Live census: **14,080 MMI nodes** exist (7,040 near / 7,040 far). Of those, **1 near** and
  **~1,670 far** fall inside their own `visibility_range` from the camera; ~957–1,017 survive frustum
  culling and draw.

**So the entire canopy call budget is the FAR-CARD ring, and it equals
`(64m buckets within 350m) × (species present per bucket)` ≈ 94 × ~17.6.** The near ring is correctly
culled and costs ~0 draw calls — it is not a target. Only two factors are available:

1. **Fewer buckets in range.** Calls fall monotonically as `BUCKET` grows (species-per-bucket saturates
   at the 27-species pool), so `BUCKET = 128` is roughly a 2.5× cut. **But this is a LOOK change and
   the comment at `tree_cover_layer.gd:48-51` already names why:** `visibility_range` is evaluated
   per-node against the transformed AABB, so a coarser bucket quantises the 65m near/far handoff by
   ±90m instead of ±45m. That either double-renders cards inside the solid ring or opens a gap in the
   jungle — the ±181m version of this same defect *was* the historical invisible-jungle bug.
2. **Fewer species per bucket** — i.e. collapse the 27 card materials into one atlas so a whole bucket
   is one MultiMesh. This is the real ~10× win (≈94 calls instead of ~1,000) and it is genuinely a
   change to *how* geometry is submitted, not to what is drawn.

### The blocker on the atlas path, and it is an asset-pipeline fact

**The 27 card textures are NOT atlased** — each species has its own PNG and its own
`StandardMaterial3D` (`assets/world/vegetation/cards/bamboo_a_card_bamboo_a.png`, ×27; verified by
probe). Any earlier claim that the cards share an atlas is false. Worse, **the card bake tool is not in
the repo** — `tools/` has no card/impostor generator, only `make_jungle_vegetation.py` (whose only
"card" is the star-fan grass at `:521`). Atlasing therefore means writing the bake pipeline from
scratch, plus a unit-quad mesh with per-instance UV-rect custom data and a shader to read it, plus
re-deriving each card's aspect into the instance transform. That is a new far-card renderer path, not a
batching tweak — which is why it was not attempted under a no-new-systems brief.

**Bottom line for the polish pass: the canopy is call-bound on far-card node count; the cheap lever
(`BUCKET`) is a look change and RULE #1 outranks it; the honest lever is a card atlas and it is real
work, not a one-liner.**

---

## 2026-07-26 — WAR ROOM: whole-game FPS deep dive (NO NEW FPS ROW — nothing was measured)

Summoner reopened the polish pass stood down at `:884`. Six architects in parallel, code not plans.
Full record: `production/war_room/2026-07-26_fps_deep_dive/` (briefing + 6 analyses + synthesis).

> **NO FPS FIGURE WAS PRODUCED BY THIS SESSION.** Agents cannot measure windowed. Every number below
> is a STATIC asset/code count or is quoted from a row above. The rows above stand unchanged; this
> entry adds attribution, corrections and a measurement batch — nothing else.

### The two findings that reframe the whole ledger

1. **`tests/perf_probe.gd` reports NO MILLISECONDS.** It reads three counters (`:110`, `:112`, `:114`)
   and never calls `viewport_set_measure_render_time`. **The CPU-vs-GPU split has never been measured
   at `fsb_main`, ever.** The 44.35ms / 51.94ms pair at `:200-201` is the *night stress arena at native
   scale* — different scene, population and pixel count. **It does not transfer to the hub.**
2. **Every FPS row in this file is a stationary camera inside a cleared firebase.** The census at
   `:912-914` shows **1 near-solid canopy node in range**; `tree_cover_layer.gd:38-40` records **919
   solid candidates** out in the jungle. **No jungle sightline has ever been measured, and RULE #1 is
   about walking.**

**Consequence: fix the ruler before pulling any lever.** Detectability floor is **~3 FPS ~ 2.4ms** at
the 34 FPS baseline (A/B/A floors 1.1 / 1.4 / 2.8, and you cannot know which you drew). Any lever
expected below that is unfalsifiable and must not ship on faith.

### Static census (glTF JSON + code; NOT a frame measurement)

| Subsystem | Static count |
|---|---|
| `fsb_main.glb` (placed once, `site_planner.gd:644`, at the exact 34-FPS pose) | **681 nodes · 202 meshes · 204 surfaces · 94 materials · 9 textures**; 94 → **48 distinct signatures, 46 exact duplicates** |
| Canopy far-cards | **27 species live, not 40** (`vegetation_manager.gd:48-55`); 13 cards on disk never scattered |
| Village / Temple | 26 files · 251 surf · 159 mats (**17 distinct**) / 29 files · 272 surf · 205 mats (**30 distinct**) — palettes duplicated per-GLB |
| US grunt | **COUNT DISPUTED:** 36 nodes/44 calls vs 51-61 MeshInstance3D/71-81 surfaces. **~25 resident** at spawn. Resolve in census phase F3 |
| VC / civilians / water | 3 nodes/13 calls · 1-3 · already one mesh+material (not a target) |

The unattributed **~355-464 non-canopy calls** (`:896-898`) now have two credible owners nobody had
checked: **~25 character bodies** and **`fsb_main.glb`'s 204 surfaces**.

### THE FIREBASE 9-to-5 CLAIM IS FALSE — not merely unmeasured

Four architects killed it independently. **The 23 nine-slot assets do not exist as Godot assets** — the
folder holds `fsb_main.glb` + 4 kit GLBs of **1, 1, 1, 5 surfaces (mean 2.0)**. Unused Blender slots do
not export. The 7 `fb_*` textures are referenced by **nothing**, and none of the 4 kit GLBs loads at
runtime (the source doc concedes this at its own `:268`). Even granting the premise it bounds to
**~0.35-0.7 FPS** — the entire non-canopy frame is 411-464 calls. **`firebase_kit_phase1_read.md:261-263`
is struck.** Material de-duplication is **hygiene, not FPS** (`:98-100`: 77 calls → ~0 FPS).

### THE ATLAS, RE-COSTED AND GATED

Blocker was **mis-scoped**: no atlas packer is needed — **`Texture2DArray` + MultiMesh
`INSTANCE_CUSTOM.x` = layer**. Aspect is readable from `_extract_mesh`'s AABB
(`tree_cover_layer.gd:323`); the shader (`terrain/shaders/vegetation_sway.gdshader`) already has
`ALPHA_SCISSOR_THRESHOLD` and `IN_SHADOW_PASS`. **~2.5 days, ~5.3x not 10x** (~188 calls — two unit
meshes required: trees export crossed 8v/12i, grass/vine single 4v/6i).
**Engine truth: a shared material collapses NOTHING** — Godot never batches 3D draws across
`GeometryInstance3D`; the win is merging the *instance arrays*.
**GATED:** the measured **+8.0 is the WHOLE canopy — calls + card fill + 12% of prims. The atlas
recovers only the call fraction, which has never been measured.** If calls are 25% of it, that is
~1.8 FPS — **below the floor, unprovable.** Batch item 4 (`BUCKET` 64→128, one line) moves calls
**without moving fill** and reads the split directly. **Below floor → atlas dead. Above +4 → build it.**

### NEW LOOK-FREE DEFECTS FOUND (not tradeoffs — bugs)

- **Canteen regex bug, `model_actor.gd:407`:** the pattern anchors on a dot-digit suffix, matching the
  retired `us_grunt_v3` naming; all six shipping grunts use `canteen_l_002`…`_006` (**underscores**).
  **Every grunt renders 5 stacked canteens.** ~-4 calls/body x ~25 bodies. **MEASURED statically.**
- **The WA-A2 hitzone gate LEAKS:** `sync()` runs on two paths and `hitzone_builder.gd:164-166`
  connects an **ungated** closure to `skeleton_updated`; the gate covers only the physics-tick call
  (`enemy_base.gd:463`).
- **`hitzone_builder.gd:225`** writes `hz.global_transform` → **11 `affine_inverse()` per man** where 1
  would do.
- **`hitzone.gd:38` sets `monitoring = true`** but nothing consumes hitzone overlaps — all damage is
  raycast. (Keep `monitorable`; `projectile_base.gd:279` depends on it.)
- **`create_shadow_meshes=true` on 362/362 imports** while shadows are off (`game_world.gd:52`).
- **413/838 textures import LOSSLESS** — 19 copies of one 3600x5700 map, **18 byte-identical**, 78.3 MB
  RGBA8 each; cards alone 121.5 MB. **VRAM compression is also the atlas de-risking test:** it changes
  zero calls and zero prims. FPS moves → bandwidth-bound, atlas over-sold. FPS flat → call-bound proven.

### THE OVERDRAW FINDING (two architects, two routes, same conclusion)

**All 40 canopy cards are `alphaMode:"BLEND"`, `doubleSided:true`, zero MASK** — verified by reading the
glTF JSON of every card GLB. ~1,000 cards with **no depth write, no early-Z, plus CPU sorting**. This
**violates ADR-026:30** ("alpha-scissor jungle") **and :63** (back-face cull). In-repo precedent already
does it right: `ground_clutter.gd:103-105`. **~15 lines.** Same defect in `fsb_main.glb`: **20
alpha-BLEND materials, 19 identical `Sandbags*` on a 64x64 texture**, in the transparent pass, filling
the screen at the exact measured pose. **`doubleSided:true` is on 100% of all assets** — backface
culling off on closed bunkers, crates and soldiers.
**This attacks OVERDRAW, which the atlas cannot touch.** Requires a look-check: hard cutout edges.

### CPU HALF — corrected

**ADR-025 tiering is neither live nor fossil: it is correctly DELETED** (SUPERSEDED at its own line 3;
`scripts/autoload/world_sim.gd` is now **34 lines**, a flat id-to-dict registry). **Budget nothing
against it.** The live population lever is `LazyGroup` (`lazy_group.gd:49-69`, 120m proximity spawn then
`set_physics_process(false)`) plus the civilian 3-tier LOD (`civilian.gd:83, :207`) — which is why hub
start is ~13 live, not 200. **There is no animation LOD anywhere in the project** (largest unmeasured
CPU item). **`physics_interpolation=true` is already ON and unexploited** (`project.godot:300`), making
`physics_ticks_per_second` 60→30 a one-line candidate — **a Summoner feel call, gated on
`ballistics.gd:37`, which derives `dt` from the tick rate.**
**Also NO-DRIFT:** the `ai/anim` bucket contains **zero animation time** — it is behaviour execute
(`enemy_base.gd:521`); and `ai_usec_hitzone` is physics-side only (`ai_stress_arena.gd:346`), so the
render-frame sync is counted **nowhere** — **true hitzone cost is HIGHER than 10.43ms.**

### WHY THE OLD HARNESS LIED, and the rule that prevents a repeat

The instrument **wrote the property it measured in every phase**
(`sun.shadow_enabled = phase_name != "no_sun_shadow"`). **A/B/A measures precision, not accuracy — a
uniformly-wrong baseline is uniformly wrong.** The tell was on screen for three runs: **the primitive
column contradicted the FPS column and nobody read them together.**

> **BINDING ON EVERY FUTURE BENCH: no FPS delta is accepted unless the draw-call/primitive delta has the
> right SIGN and a plausible MAGNITUDE.** Capture-and-restore ship state (never a phase-name
> expression); `hidden=N` census with a zero-warning; `.visible` toggles only, **never `queue_free`**.

### Pointer corrections applied to this file today (NO DRIFT law)

`:21-23` renderer pointer (**key absent from `project.godot` entirely** — only the `.mobile` override
survives at `:305`; Forward+ holds only by being the desktop default — **verify at runtime**) ·
`:909-911` (stale `:94/:47/:115/:118/:199` → **`:110/:52/:132/:135/:323`**) · `:922` (`:43-46` →
**`:48-51`**) · `:889` (scale `:304` → **`:308`**). Outstanding elsewhere: **`ADR-026:121-123` still
calls the refuted +8.6 FPS light win "#1"** (refuted at `:611, :855`) and **`ADR-026:164`'s "80m
foliage"** describes `jungle_patch_layer`, which does not ship (`world_config.gd:21`); the live card
ring is **350m**.

### LANDMINE

**13 card GLBs sit on disk that are never scattered** (40 on disk, 27 live). **Wiring them in raises
canopy draw calls ~48%** — more than `BUCKET=128` would ever save. **The card bake tool is still absent**
(verified across 97 tools; commit `ad25457f` touched zero files in `tools/`) — the 40 cards are
currently **unreproducible in-tree**.

### THE MEASUREMENT BATCH (~18 min machine, ~35 min wall clock; A/B/A, console exe, `--test-save`)

Items 1, 2, 6 need the census patch first; **3, 4, 5 run today with zero code.**

1. **CENSUS** — `-- --perf-probe --perf-cycle --test-save` x2; phases
   `baseline → no_canopy_far → b2 → no_structures → b3 → no_characters → b4 → no_water → b5`. 4.6 min
2. **FILL-BOUND?** scale ladder `0.75/0.60/0.75/0.85/0.75` in one boot. 1.8 min
3. **`-- --card-dist=250`** — A/B/A across **3 boots** (`view_distance` is baked at construction,
   `tree_cover_layer.gd:135`). 3.6 min
4. **ATLAS GATE** — `BUCKET` 64→128, one line (`tree_cover_layer.gd:52`). **Instrument only, never
   shipped.** 1.2 min + eyes
5. **THE WALK** — out the wire into jungle; `[PERF] FPS=` already prints every 2s
   (`game_world.gd:481`). **Zero code.** 4 min
6. **`-- --spawn-at-village`** — second pose. 2.2 min

**Cut line if short: 1, 2, 5.** Free flags found: `--card-dist=N` (`tree_cover_layer.gd:77-80`),
`--perf-seed=N` (`game_flow.gd:202`), `--spawn-at-village` (`:288`),
`--perf-probe/--perf-cycle/--shadow-study` (`:352-358`), `--test-save` (`campaign_state.gd:130`);
arena-only `--fill_chance=/--view_distance=` (`ai_stress_arena.gd:471`) and the eight
`ps2_perf_probe.gd:147-187` flags.

**Prerequisite before ANY bench: restore `renderer/rendering_method="forward_plus"` to `project.godot`.**
`perf_probe.gd:208` now prints a fallback string instead of a read value — **every row measured without
it violates the measurement contract.**

---

## 2026-08-13 — the GPU/CPU instrument EXISTS now; no number has landed yet

`perf_probe` gained real millisecond rows on 2026-08-13 (commit `e2868da2`:
`viewport_set_measure_render_time` wired, `PERF MS` per phase — `perf_probe.gd:47-53,300`).
The 2026-07-26 finding above ("the CPU-vs-GPU split has never been measured") describes the
OLD probe and is CORRECTED as of that commit: the instrument works; **the three poses (THE
WALK · ONE DIG · THE BARRAGE) still have not been taken with it** — that is the Summoner's
run, queued. No row below this line exists yet.

---

## 2026-08-14 — THE CRUCIBLE: first full-load curve, and the doctrine flips on the floor box

`tools/probe_crucible.tscn` (new): five 30s phases — quiet arena → hot 18v18 → +30-man
siege wave + sappers → +napalm/arty/CBU cycling → everything + mortars + second wave.
Every frame sampled; render split via `viewport_set_measure_render_time`. Both runs on
this box (12 cores, **Intel UHD Graphics, Vulkan Forward+** — the named floor), 1280x720,
nothing else running.

**HEADLESS (pure game-thread CPU):** avg ms / 1% / worst —
BASELINE 9.0/21.5/101 · COMBAT 10.1/20.8/291 · WAVE 19.3/41.3/288 ·
FIRES 32.0/61.0/284 · EVERYTHING **43.6/74.5/283** (23fps avg CPU-only).

**REAL RENDERER (frame = CPU+GPU pipeline):** avg / 1% / worst | rCPU / rGPU ms —
BASELINE 47.1/70.5/116 | 2.5/**43.5** · COMBAT 54.0/122.6/260 | 3.6/49.8 ·
WAVE 75.6/186.5/285 | 3.7/67.6 · FIRES 100.3/252.5/275 | 4.8/75.9 ·
EVERYTHING **130.5/262.1/291 | 4.3/94.4** (8fps avg).

**FINDINGS, in rank order:**
1. **The GPU is the wall on the UHD floor.** 43.5ms of GPU at a QUIET night arena —
   21fps before one AI thinks — growing to 94ms under load. The 2026-07 "CPU-bound"
   verdict came from a bench that assumed the frame after graphics cuts; on the floor
   hardware the renderer eats 2-4x the game thread at every phase. Baseline attribution
   (jungle/fog/night lights vs VFX) is the next measurement.
2. **A recurring ~285ms CPU hitch class** — same signature (283-291ms) in every combat
   phase, present even in plain COMBAT with no fires and no craters. One event class;
   suspects: materialize spawn burst, chunk rebuild, breach-bake source assembly.
   Instrumented hunt is next.
3. CPU load curve: the 30-man siege wave alone doubles the game thread (10→19ms);
   fires add 13ms; everything 44ms. The demo runs ~45 siege men + garrison — the demo's
   CPU frame is expected WORSE than the crucible's WAVE phase.
4. `[NAV-FALLBACK]` fired ONCE across the full crucible — the honest navmesh is not
   spamming the designed fallback.

**Gate implication:** a 30fps-avg/20fps-1% gate at the crucible EVERYTHING phase is
currently missed ~4x on the floor box. The gate number goes to the Summoner AFTER the
top-2 fixes land and the three demo poses are taken — a gate set against an unattributed
frame would just be red forever.

### 2026-08-14 03:00 addendum — the spawn-burst class is SYSTEMIC; MarchingCell's site is closed

Fix shipped: MarchingCell spawns drain against an UNCONDITIONAL global budget (2/frame,
frame-keyed static token; no exemptions — the illum path materializes several cells in one
frame and five "exempt first men" re-created the burst). The cell-pop signature
(+2,900-node frames) is gone by construction at that site.

Measured across four crucible runs: the CLASS persists from OTHER sites — WAVE +2,276,
FIRES +4,626-node hitch frames with the cell budget active. Suspects: arena reserve
spawns, and at least one unidentified mass-instantiation path. NEXT INSTRUMENT (plan
step 17 cont.): a caller-tagged spawn counter that prints the spawning call site on any
>100ms frame — no more whack-a-mole without names. The no-node-delta ~285ms class is
ATTRIBUTED-AS-SUSPECT to breach re-bake SOURCE ASSEMBLY (sync main-thread collider walk
in _start_bake during waves with satchels) — needs its own ms split before any fix.

Phase averages improved across runs (EVERYTHING 43.6 -> ~19-21ms over three post-fix
runs) but single-run variance is high and wave timing differs per run — the average
claims wait for a fixed-seed crucible. The leak-column lesson applies to perf: never
celebrate on one reading.

### 2026-08-14 morning — THE DEMO'S OWN NUMBERS, first rows (perf_probe, real renderer)

`--perf-probe` on the shipping demo scene, 1280x720, Intel UHD, render scale 0.75 (the
shipped lever): **baseline 34.5 fps avg / 33.0 min · GPU 24.06ms avg (26.64 max) · CPU
3.67ms (7.81 max) · 1,764 draw calls · 324k prims · 2,597 objects.** The demo's quiet
frame is markedly lighter than the arena bench's (24 vs 41.6ms GPU) - the arena
over-represents jungle density. The siege-study phases (quiet / assault_in /
assault_on_wire) are running as this is written; their rows land next.

### 2026-08-14 — THE SIEGE STUDY rows (the demo's fight, measured)

`--perf-probe --perf-siege`, shipping demo scene, 1280x720 @ 0.75 scale, Intel UHD:
**quiet 31.6 avg / 5 min · GPU 27.1/36.4 · CPU 3.9/33.6** —
**assault_in 22.4 / 6 · GPU 32.3/40.7 · CPU 4.5/12.8** —
**assault_on_wire 21.9 / 7 · GPU 33.2/48.5 · CPU 5.0/13.4** (calls 1814→2073).

Readings: the demo's fight is GPU-led on the floor (6-7x the CPU column) — the crucible
doctrine holds on the shipping scene; CPU worst-frames are 13-34ms, far under the
arena's 285ms class (the spawn budget + smaller demo cells); the 5-7fps minimums are
the hitch tail to hunt with SpawnLedger next time the probe runs.

**GATE PROPOSAL for the Summoner (step 18):** at the shipped 0.75 scale on this box —
**assault_on_wire ≥ 20 fps average, ≥ 10 fps minimum.** Passes TODAY with ~2fps margin;
it is a hold-the-line gate, not an aspiration. An aspirational 30/15 requires the GPU
work (the demo's own veg/dressing splits not yet measured — the arena's numbers do not
transfer directly). His ratification makes either law.

### 2026-08-14 — SPAWNLEDGER ATTRIBUTION RUN (crucible, headless, CPU truth)

Second crucible with the ledger armed (log: session scratchpad
`crucible_spawnledger.log`). Curve reproduces the 8/14 baseline (BASELINE 9.05ms avg /
COMBAT 10.10 / WAVE 25.92 / FIRES 30.31 / EVERYTHING 23.09; worst frames 265-283ms
class, 1 [NAV-FALLBACK] the whole run). The attribution finding is NEGATIVE and it
narrows the hunt: **the big hitch frames (+2,000-4,600 nodes in one frame) report "no
spawns this frame"** — the four ledgered NPC sites (spawn_tracked_enemy, AllyBase,
EnemyBase, Civilian) are NOT the burst class. MarchingCell's 2/frame stagger shows up
exactly as designed (spawn_tracked_enemy x2 on ledgered frames). Remaining suspects, by
phase signature:
- COMBAT +4,135 nodes one frame = the arena's `_hot_start_combat` direct spawn path
  (36 men x ~115 nodes) — bench-only, un-ledgered, and the arena is sterile by ruling;
  instrument only if a demo path shares it.
- WAVE/FIRES +2,000-4,000-node frames with no spawns = **fire-support dispatch
  instantiation** (napalm run airframe + canisters + GunFX procs; arty barrage). This is
  the demo-relevant class — the demo's 5-7fps siege minimums live here. Next lever:
  stagger or pool the fire-support proc instantiation the way MarchingCell was staggered.

### 2026-08-14 EVENING - THE SPAWN-BURST FIX (crucible x4 + demo siege study; supersedes the morning attribution)

**The 8/14 morning negative attribution above was an instrument bug, and its
conclusion was wrong.** SpawnLedger keyed its counts on the PHYSICS frame; a 280ms hitch frame runs
many catch-up physics ticks, each wiping the previous tick's counts, so the burst
frames read "no spawns" on exactly the frames the ledger existed to explain. A second
off-by-one hid the rest: the tracer reports in frame N+1 with a node delta measured
across frame N, but read only frame N+1's bucket. Both fixed
(`scripts/world/spawn_ledger.gd` - process-frame key + two-frame report window), the
re-run named every burst frame: **EnemyBase.spawn_enemy x18-24 and AllyBase.spawn_ally
x22-23 per hitch frame - mass MAN instantiation, not fire-support dispatch.** The
fire-support procs measured small on the same frames (gunfx_explosion x2-3, fire_hazard
x2, fd_shell x3). `_hot_start_combat` was also mis-blamed on 8/14: it spawns nobody
(state flips only); COMBAT's +4k frame was a reinforcement wave.

**Root cause:** MarchingCell's 2/frame token bucket refilled per PHYSICS frame, so a
hitching render frame's catch-up ticks each granted fresh tokens - 15-24 men in one
260ms rendered frame while the budget reported "as designed". A death spiral: the slow
frame buys itself more spawns. And three bulk loops never used the bucket at all
(arena wave/squad/sapper spawns, `FieldDirector._garrison_stand_to` - the demo's own
siege-moment burst, the whole garrison promoted in one frame).

**Fix** (`marching_cell.gd` bucket keyed on `Engine.get_process_frames()`;
`ai_stress_arena.gd` wave/squad/sapper loops + `field_director.gd:_garrison_stand_to`
drip through it; boot-time initial forces stay instant and `_waves_dripping` holds the
attrition trigger while a wave is still arriving - a half-dripped roster read as
casualties and burned reserves into BASELINE on the first attempt):

Crucible headless, same box, before (evening run with ledger armed) -> after:
```
phase        avg ms          1% ms           worst ms        hitch>100ms
BASELINE     9.3  -> 8.8     22   -> 22      92   -> 73      0  -> 0
COMBAT       10.0 -> 9.9     23   -> 24      271  -> 96      3  -> 9
WAVE         18.6 -> 21.9    60   -> 134     263  -> 244     9  -> ~30
FIRES        25.2 -> 30.1    54   -> 183     270  -> 240     2  -> ~15
EVERYTHING   21.9 -> 17.7    36   -> 68      286  -> 161     13 -> ~7
```
The +2,000-4,600-node single-frame class is GONE (biggest node delta after: +650).
The trade is explicit: the one-frame freeze became a run of 100-160ms frames across a
wave's arrival (~30-40ms/man instantiation on this box is the floor - the drip
spreads it, nothing yet removes it). SPAWN_PER_FRAME=1 was measured and REJECTED
(doubles the arrival window: FIRES avg 30->37, hitches 61->107); 2/frame stands.

Demo siege study (`--perf-probe --perf-siege`, shipping scene, 0.75 scale, same box,
vs the morning rows): **quiet 33.9 avg / 9 min (was 31.6/5) - assault_in 27.4 / 5 (was
22.4/6) - assault_on_wire 22.6 / 5 (was 21.9/7)**. Every average improved; the ~5fps
minimums remain and are GPU-led dips (gpu_ms_max 35-41 vs cpu_ms_max 9-10), no longer
CPU spawn bursts. The proposed >=20avg gate now carries ~2.6fps margin on the wire.

**Queued from this run:** per-man instantiation cost (~35ms) is the remaining lever -
pre-pooled ModelActor bodies would kill the drip window entirely (post-demo,
content-first rule). The WAVE/FIRES 1% regression on the ARENA bench is the drip made
visible under a 30-man siege + 26-man waves; the demo never fields that arrival rate.

### 2026-08-31 - THE RAID, MEASURED ALONE FOR THE FIRST TIME (his order: "fix the bombing raid lag")

**The raid had never been benched on its own.** FIRES has always run straight after WAVE in the
crucible, so every raid figure ever banked was measured on top of a siege arrival - the confound
that let the 8/14 morning run blame the airstrike for a burst that was men. `--raid-only` was added
to `tools/probe_crucible.gd` (BASELINE -> FIRES, no combat, no wave) and run first:

```
phase        frames   avg ms    1% ms    worst   hitch>100ms
BASELINE        661    45.42   247.29   260.96      36
FIRES           722    41.57   264.62   296.04      30
```

**The raid phase came in CHEAPER than the quiet one.** The hitch tracer named `EnemyBase.spawn_enemy`
and mid-run `[MODEL] ... +232 clips from shared anim library` loads, not ordnance. So a frame-time
instrument cannot see the raid at all in this arena: the arena fights and loads models on its own,
and that noise is larger than the thing being measured. **A frame-time number from this bench is not
raid attribution, and no future run should be read as one.**

#### The instrument that CAN see it: `tools/probe_raid_cost.tscn`

Times the raid path directly in usec against the arena's live population (18 enemies, 20 allies,
17 props) and real colliders. Headless CPU truth. Before -> after, two runs each:

```
                              BEFORE (2 runs)     AFTER (2 runs)
first burn patch  (cold)      57.132 / 60.662     13.922 / 10.210   ms
first explosion   (cold)      60.948 / 64.299      1.286 /  3.700   ms
  -> first raid pays          ~121.5 ms one frame  ~14.6 ms
CBU dispenser, worst
  single-frame block   avg     4.574 /  4.166      1.160 /  1.182   ms
                       max     8.348 /  8.518      2.107 /  1.865   ms
bomblets born per can           16, frame shape 16  16, shape 4/4/4/4
blast resolution     avg     0.09 - 0.12 ms       unchanged
```

#### WHAT THE SPIKE ACTUALLY WAS - and what it was NOT

1. **~121 ms, once, on the first bomb of a mission.** `GunFX`'s FX texture/material caches are built
   LAZILY on first use of each kind, and `FireHazard` pulls sheets through them that the explosion
   path does not (`sheets/fire_loop_sheet`). A napalm canister hits both, so the FIRST canister of a
   run paid ~121 ms in one frame while every canister after it was free. The file's own header claimed
   "no material/pipeline compile ever happens mid-firefight" - true from the second event onward,
   false for the one that matters. **This is the big one, and it is exactly what "the first strike
   stutters" feels like.** Fixed by `GunFX.warm()` + `FireHazard.warm()` at world build
   (`game_world.gd:56-57`, mirrored into the arena for ship parity at `ai_stress_arena.gd:325-326`).
2. **4.2 ms avg / 8.5 ms max per dispenser**, spent BIRTHING 16 bomblet projectiles in one call
   (`cas_airplane.gd:_open_cluster_at`). Fixed by spreading the births 4 per frame
   (`BOMBLETS_PER_FRAME`). **Nothing was thinned:** the probe counts 16 born before and 16 after, and
   the frame shape moves from `16` to `4/4/4/4`. Each bomblet keeps the fall time computed for its own
   release from the same split point, so the pattern is identical and the strip ripples over ~4 frames
   instead of detonating as one instant. `NAPALM_STAGGER` / `CBU_STAGGER` were NOT touched - those are
   period-correct ripple, not perf dials.
3. **REFUTED BY MEASUREMENT: the blast loop is not a problem.** The standing suspicion was
   `CombatManager.apply_explosion_damage` and its O(bodies x 8 raycasts) `_blast_multiplier`. Measured
   steady state: **0.069 - 0.140 ms per call** at every ordnance's real parameters. 57 detonations in a
   napalm+CBU raid spread over ~1 s of staggered impacts is single-digit milliseconds TOTAL. It was
   named as a root cause earlier in this same session on inspection alone; the probe says no. **Do not
   re-open it without a number.**

#### A CONSERVATIVE INVALIDATION IS RIGHT TO SHIP AND WRONG TO KEEP, 2026-09-09

The vegetation scatter cache shipped with ONE epoch counter for the whole layer, bumped by every
writer of its inputs. That was the correct first version: a stale scatter index when a crater and
a felling touch the same chunk costs a wrong tree in the ground, and a redundant recompute costs
milliseconds. Ship the safe one.

**But keeping it cost the win where the win mattered.** One felled tree invalidated the scatter
of every chunk on the map, and an assault fells trees continuously — `veg.build_scatter` was back
at **80.1 ms inside the 45-man fight**, undoing most of the crater gain at exactly the moment the
frame was tightest. Per-chunk invalidation took the worst to **21.4 ms**.

The sequence is the point, and it is the right way round: **ship the conservative invalidation,
measure it under load, then narrow it with the measurement in hand.** Narrowing first is how you
get a wrong tree; never narrowing is how you get the 80 ms back.

Same shape twice in one night: the roof-miss AUDIT added to `nav_baker` cost 97.9 ms of the
314 ms collider walk it was written to investigate, until it was gated to the first bake. **An
instrument is not free, and it is measured like anything else.**

#### THE BROKEN-INSTRUMENT REGISTER — a bench must check the box TWICE, 2026-09-09

**A CLEAR-BOX CHECK THAT RUNS ONLY AT THE START CANNOT SEE CONTENTION THAT BEGINS MID-RUN.**

A done-condition-5 measurement was taken on a box verified clear. Two Godot processes from
ANOTHER project's audit started four minutes into it, and the run reported a 984 ms worst
script step. That number is contention, not the game, and it was only caught by checking the
process list AFTER the fact - the check at the start had passed honestly.

**Every bench prints the process count at the START and at the END.** A run that ends dirty is
not a measurement, whatever it says. Third time on 2026-09-09 that asking *when* rather than
*how much* changed an answer: this, `nav.collect` (491 ms that turned out to be world build,
not the fight), and the `SpawnLedger` stale-read below.

#### THE BROKEN-INSTRUMENT REGISTER — a NEW class, 2026-09-09

**A TEST WHOSE DISCRIMINATOR IS THE BUG IT IS MEANT TO BE BLIND TO.**

`test_hitzone_rebuild` proves a body swap rebuilds a man's damage regions, and it needs two units
with genuinely different hulls or it proves nothing - it asserts that discriminator is alive
before trusting any result, which is exactly the right instinct. Its pair was
`us_grunt_rifleman` vs `us_pilot_white`.

Those two only differed **because eleven `web_*` suspender clips were being harvested into the
rifleman's hurtbox** - gear `_GEAR_NAME_HINTS` was meant to exclude and missed, because it tests
for `"webbing"` and the meshes are named `web_`. Fix the gear and the pilot and the grunt harvest
the same `us_grunt_joined` body and are identical, so the probe goes red.

**It would have gone quiet the instant anyone got it right, and said nothing about why.** A team
that hit this without the fix in hand would have "repaired" the discriminator and re-buried the
defect. The discriminator is a genuinely different BODY MESH now (`vc_guerilla_joined`).

This is not the stale-read class below. It is: *an instrument calibrated against a defect reads
as broken the moment the defect is cured.* Expect it wherever a probe's control is "these two
things differ" and nobody wrote down WHY they differ.

#### A BROKEN INSTRUMENT FOUND WHILE BUILDING THIS ONE

`SpawnLedger` only clears its counts when `note()` is NEXT called, so a frame in which nothing spawned
still reports the previous frame's numbers. Reading it naively made a 16-bomblet dispenser report **44
births across 11 idle frames**. Guard with `SpawnLedger._frame == Engine.get_process_frames()` before
trusting a count - `probe_raid_cost.gd:_bomblets_this_frame()` is the pattern. This is the same
stale-read class as the 8/14 physics-frame keying bug, in a different disguise.

#### WHAT IS NOT CLAIMED

These are CPU-side resource-construction and instantiation numbers, measured headless. **GPU pipeline
compilation is a separate cost this bench cannot reach**, and the demo's ~5 fps siege minimums remain
GPU-led (8/14 evening entry). **No windowed before/after was taken, and the Summoner has not seen a
raid since the fix.** The crucible `--raid-only` re-run after the fix reported BASELINE 29.12 avg /
10 hitches and FIRES 18.80 / 10 - better on both, but BASELINE (which contains no raid) moved just as
far, so that pair attributes nothing and is recorded as context only.

---

## 2026-09-08 — THE MEASUREMENT WINDOW 2026-08-07..2026-09-08 IS VOID

**Read this before quoting any perf row dated in that window.**

Every row taken between 2026-08-07 and 2026-09-08 that states a render scale states it from
`ProjectSettings.get_setting("rendering/scaling_3d/scale")`. That is the ratified project value
(0.75). **It is not what the frame was drawn at.** `PsxLook` is the sole writer of the viewport's
`scaling_3d_scale` (`scripts/autoload/psx_look.gd:47`) and, with the PSX look off — the shipped
default — it wrote `GameSettings.render_scale`, whose default was **1.0**. The frames were full
resolution. The rows say 0.75.

This is the same disease as the retracted sun-shadow bench artifact three entries up: **an
instrument that reads the document instead of the machine agrees with the document forever.**

- Fixed: `tests/perf_probe.gd` and `tools/probe_config.gd` now read `get_viewport().scaling_3d_scale`
  (probe_config prints live AND project side by side and shouts when they disagree);
  `--print-fps` states the live scale and GPU ms on every row; `tests/test_render_scale.gd` fails the
  build if `GameSettings.DEFAULT_RENDER_SCALE` and `project.godot` ever drift apart again.
- Rows from that window are not deleted. They are **unattributed to a render scale** — treat the scale
  column as unknown, and do not A/B a post-fix number against one.

## 2026-09-08 — the performance wave: BUILT, NOT MEASURED

Shipped this session: the ratified 0.75 render scale actually reaching the viewport; vertex lighting
on the vegetation shader; `specular_disabled, diffuse_lambert` on the terrain shader (it carried no
`render_mode` line at all); per-vertex, specular-free ground clutter; 73 foliage materials converted
from `ALPHA_DEPTH_PRE_PASS` (two passes per leaf, sorted) to `ALPHA_SCISSOR` (one, unsorted); 49
sandbag materials forced opaque. Detail and the refuted single-sided half in ADR-026, wave 2026-09-08.

**NO FPS NUMBER IS CLAIMED, IN EITHER DIRECTION.** GPU milliseconds read zero headless and this box's
discrete GPU is dead (ADR-026 Amendment C), so the author of this change cannot see the win. The
before/after is `perf_before.bat` and `perf_after.bat` — same scene, same seed, the real player camera
under the Summoner's own hands, the walk written into the batch file — and only he can take it.

Headless no-regression evidence, which is all that was earned here:
- `godot --headless --path . --quit-after 300` — zero SCRIPT ERROR.
- `tests/test_render_scale.tscn` — 5/5 PASS; fails as designed under `--perf-before`.
- `tools/probe_material_budget.gd` with and without `--after`: cards 40 depth-prepass -> 40 scissor;
  near-ring plants 33 -> 33 scissor; per-pixel 170 -> 0 and specular 170 -> 0 across the foliage;
  structures opaque 3045 -> 3094 with depth-prepass 137 -> 88. The 286 blended `screen_mesh` surfaces
  (hooch mosquito screening) are untouched on purpose.
- Every `Sandbags*` texture in the tree measured at alpha 255 everywhere, or no alpha channel at all —
  the blend mode was import noise, so forcing opaque cannot change the look.


## 2026-09-08 (later) — Phase 0: the instrument, fixed and PROVEN

`--print-fps` had produced two logs with no measurement in them, twice in one day. Cause, proved by
`_scratch/arg_probe.gd`: `OS.get_cmdline_args()` **stops at the `--` separator** and
`OS.get_cmdline_user_args()` **starts after it**. The launchers wrote the flag before the separator;
`scripts/main/game_flow.gd:747` read it after. FpsPrinter never attached and nothing said so.

- `GameSettings.has_flag()` (`scripts/autoload/game_settings.gd`) reads BOTH arrays. Every launcher
  flag now goes through it, so a flag on the wrong side of `--` can no longer vanish.
- **The watchdog:** `--print-fps` with no `FpsPrinter` in group `fps_printer` after 30 s pushes an
  error and prints `INSTRUMENT FAILED TO ATTACH`. Proved in both directions headless — the row prints
  on `demo_game.tscn`, the error prints on a boot that never enters the hub.
- **Vsync was ON in every prior windowed log** (`Requested V-Sync mode: Enabled` in both). At 24-35 fps
  on a 60 Hz panel that quantises delivery, which is a direct cause of the "sluggish" feel independent
  of throughput. FpsPrinter now forces it OFF whenever it attaches, and it is a player setting.
- **`viewport_get_measured_render_time_cpu` is the RENDER THREAD, not the game thread.** It was
  labelled `cpu_ms` in `tests/perf_probe.gd`, which meant the game thread — where the AI lives — was
  never in a single perf row. Renamed to `render_thread_ms`; `game_ms` (TIME_PROCESS +
  TIME_PHYSICS_PROCESS) added beside it. Rows now carry gpu / render_thread / game.
- FpsPrinter rows also carry a **1% low** (frame pacing, not throughput) and shout if GPU ms reads
  0.00 for 15 s on a windowed run.

**Any perf row dated before this fix is instrument output of unknown validity. Do not A/B against one.**

## 2026-09-08 (later) — Phase 1: VRAM compression applied, NOT YET BENCHED

The de-risking test this ledger designed at :1032 — *"it changes zero calls and zero prims. FPS moves
-> bandwidth-bound. FPS flat -> call-bound proven."* The asset half is now done; the bench needs the
Summoner's hands.

**241 texture imports flipped `compress/mode=0` -> `mode=2`.** Scope rule, deliberately narrower than
the plan's "all of them": under `assets/` or `terrain/`, source >= 256 KB, excluding `assets/ui/`,
`assets/reference/`, `production/` and `screenshots/`. Foliage and terrain (74 of the 241) went to
`high_quality=true` (BC7) — identical 8 bpp to DXT5 but far better on the alpha edges that are the
named look risk. All 241 re-imported with `vram_texture: true`; **zero failed**, including the 47
whose dimensions are not multiples of 4.

Measured, static (VRAM is upload-size for block-compressed data, so these are the pool figures):
- **40 canopy cards: ~243 MB as RGBA8+mips -> 55.6 MB.** The four-triangle quads.
- The whole converted set: ~4,147 MB theoretical RGBA8+mips -> **937 MB** of `.ctex` on disk.

**Two of the plan's numbers were stale, corrected here:**
- Not 939 lossless image imports — **1,654** texture imports carried `compress/mode=0`.
- Not 11 byte-identical copies of the 3600x5700 body atlas — **43**, plus a second 10-copy group of a
  different 3600x5700 image. At 109.4 MB each as RGBA8+mips that is the single largest texture fact in
  this repo, and **compression does not fix it — deduplication does.** Post-compression each copy is
  still ~27 MB and there are still 43 of them. Flagged, not fixed; it is not Phase 1's job.

**No FPS number is claimed.** GPU ms reads zero headless. The bench is two walks by the Summoner with
the now-working instrument. Reversal is `git revert` of the import commit plus one `--import`.

Headless no-regression evidence earned here:
- `--headless --quit-after 400 res://scenes/levels/demo_game.tscn` — no texture load failure, no
  SCRIPT ERROR (only the usual exit-time RID-leak noise).
- `test_art_contract` 72 checks PASS · `test_model_scale` 42 characters PASS · `test_flat_damage` PASS
  · `test_render_scale` PASS · `test_fossils` PASS · `test_ship_parity` PASS.
- `test_viewmodel_contract` FAILS with 12 errors, and it **failed before this work**:
  `assets/player/viewmodels/rpg7_fp.glb` does not exist in the tree at all. Unrelated, pre-existing,
  recorded here so nobody attributes it to the import change.


## 2026-09-08 (night) — THE STALL HUNT: the columns were mislabelled, and the drop is a CRATER

### The instrument, corrected AGAIN — read out of Godot's own source, not inferred

`--print-fps` was printing `process`, `physics` and a summed `game` column. All three were wrong in the
same way, and the error is in Godot's `main.cpp`, not in ours:

    process_max = MAX(process_ticks, process_max);            // every frame
    if (frame > 1000000) {                                    // ONCE PER SECOND
        performance->set_process_time(USEC_TO_SEC(process_max));
        performance->set_physics_process_time(USEC_TO_SEC(physics_process_max));
        process_max = 0; physics_process_max = 0;
    }

**`Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` are MAXIMA OVER A ONE-SECOND BUCKET.** They are
not per-frame values and not averages. That fully resolves the arithmetic that looked impossible — a
43–56 ms `process` beside a 44 fps average was never a contradiction; it was the worst frame of each
second sitting next to the mean of five.

**And the span is not "game thread".** `process_ticks` is timed from before `MainLoop::process` to after
`RenderingServer::draw()`, so it contains `message_queue->flush()`, both navigation servers,
**`RenderingServer::sync()` (which BLOCKS on the render thread)** and **`RenderingServer::draw()`**. A
large `process` can therefore be caused by the renderer. **The earlier read that "the game thread is the
wall" is NOT established by that column** — it is retracted here alongside the draw-call-bound read it
replaced. Two successive conclusions have now come from mislabelled columns.

Fixed in `scripts/dev/fps_printer.gd`: the summed `game` column is **deleted, not renamed** (it added
two maxima that need not come from the same frame, one of which contained the renderer). The remaining
two are labelled `idle_max` / `phys_max` and the row says `1s bucket MAXIMA, not per-frame` in-line.
`nav_max` and Jolt body/pair/island counts added.

Honest per-frame script time now comes from `scripts/dev/stall_ledger.gd` + `scripts/dev/frame_sentinel.gd`:
two sentinels pinned to the front and back of the SceneTree's `process_priority` order bracket every
other node's callbacks, so the span between them IS script time, per frame, in our own clock. Named
`begin()`/`end()` spans attribute a stall to a cause, and the worst step of each window is snapshotted
with its full breakdown.

**The instrument failed silently before it worked, and that is recorded on purpose:** the Node property
is `process_physics_priority`, NOT `physics_process_priority`. The wrong name is a parse error, so
`FrameSentinel` never compiled and two full bench runs reported **"0 steps"** — a confident zero that
reads exactly like a frame which cost nothing. **The standing headless boot check did not catch it**,
because nothing on the boot path loads a dev-only script. `StallLedger.report()` now shouts
`INSTRUMENT FAILED` rather than printing 0.00 ms.

### What is actually in the stalls — measured, `tests/stall_bench.tscn`, headless, seed 47225

Headless is legitimate for this and only this: the work in question is main-thread and physics-thread
CPU. No FPS or GPU claim is made here; that verdict stays the Summoner's walk.

| phase | worst physics script step | worst idle script step | what was in the worst step |
|---|---|---|---|
| QUIET (nothing happening) | 10.4 ms | 35.5 ms | **unattributed** — see open item below |
| SPAWN (30 men, 1/tick) | 12.7 ms | 70.3 ms | unattributed; spawn causes were tiny |
| CRATER (6 large explosions) | **66.6 ms** | **107.2 ms** | crater chain, below |

**THE DROP IS A CRATER.** One large explosion costs ~80–94 ms in a single IDLE frame, and every
millisecond of it is the chunk rebuild:

    terrain.crater 81.6ms -> terrain.chunk_rebuild 81.5ms
        terrain.veg_generate   42.5ms  ( veg.tree_cover_mmi 21.6 + veg.build_scatter 20.9 )
        terrain.collision      20.1ms
        terrain.build_mesh     12.6ms
        terrain.heightmap_edit  0.1ms

A ~5 m crater edits a handful of heightmap cells and then **destroys and reconstructs whole 256 m
chunks** — up to 4 when it straddles a seam. The heightmap edit itself is 0.1 ms. Everything else is
rebuild overhead.

**The physics-side stall is TreeBreakSystem.** Worst physics step in the crater phase, 66.6 ms:
`treebreak.consume 23.9 ms, veg.tree_cover_mmi 19.4 ms, veg.build_scatter 12.5 ms`.
`TreeBreakSystem.apply_blast` runs synchronously on the physics tick and calls `remove_scatter_entries`
per touched chunk, each a full MultiMesh regen, unbounded. `scripts/world/tree_break_system.gd:273-286`
already flagged this as an open perf item and set the precondition *"Measure the assault frame first; if
it is real, batch it."* **It is real, and it is now measured.**

### REFUTED by measurement — do not re-litigate without a number

- **"Spawning a man costs ~35 ms."** Measured over 30 real spawns: `spawn.hitzones` **1.4 ms mean /
  2.1 ms worst per man**, `spawn.anim_library` **0.11 ms per man**. The 100 `add_animation()` calls are
  not a stall. Whatever produced 35 ms was not the steady-state per-man cost.
- **The hitzone `skeleton_updated` gate "leaks".** It does not: `hitzone_builder.gd:170-178` is distance
  gated at 40 m. That lead was stale.
- **"11 `affine_inverse()` per man where 1 would do" at `hitzone_builder.gd:225`.** Not there. The real
  waste was one per VERTEX per region inside the harvest loop — thousands of them, re-deriving a handful
  of constant frames. Hoisted; that is part of the 1.4 ms above.

### Shipped this pass

1. **495 monitoring Area3D killed.** `scripts/combat/hitzone.gd:41` `monitoring` true -> **false**.
   Every man carried 11 `Area3D` with `monitoring = true` and real masks (enemies 8, allies/player 16),
   so Jolt re-queried each against the broadphase every tick while their transforms were also rewritten
   every tick. **Nothing has ever read the result** — verified across the whole tree: no
   `area_entered`/`area_exited`/`body_entered`/`body_exited` is connected to a Hitzone anywhere and no
   caller uses `get_overlapping_*`. Every real consumer is a raycast with `collide_with_areas = true`,
   which finds an area by shape and never consults `monitoring`. `monitorable` deliberately left true so
   the change is one variable wide.
   **Gate: `tools/probe_bullet_damage.tscn` PASSES** — `vc_rifleman hp 70 -> 0`, headshot resolves as a
   headshot through the zone. Damage is unaffected.
2. **Terrain chunk mesh build: SurfaceTool -> packed arrays.** `terrain/core/terrain_chunk.gd:build_mesh`.
   Identical geometry, winding, flat normals and vertex colours; only the machinery changed. The old path
   made 98,304 `add_vertex` + 196,608 `set_normal`/`set_color` boundary crossings per chunk and then paid
   `st.index()` to hash all 98,304 verts hunting duplicates **that cannot exist** — the shading is flat,
   so the two triangles of a quad never share a vertex. Measured, same bench, same seed:
   **`terrain.build_mesh` 185.6 ms -> 61.7 ms total; worst chunk 27.0 ms -> 6.4 ms (4.2x).**
   Whole crater chain **534.5 ms -> 399.0 ms; worst single crater 119.4 ms -> 80.7 ms.**
3. **`affine_inverse()` hoisted out of the hitzone harvest vertex loop** (`hitzone_builder.gd`).
4. **The per-rebuild `[TerrainChunk] mesh built` print is now once per session.** It was a synchronous
   write into the redirected bench log from inside the very stall being measured — the instrument was
   paying part of the cost it reported.

Regression gates, all green after the change: `test_flat_damage` PASS (15 weapons) ·
`test_fossils` PASS (28/28, no new fossils) · `test_tree_cover_lod` PASS · `test_hitzone_rebuild` PASS ·
`test_ship_parity` PASS (4 declared deviations) · `tools/probe_bullet_damage` PASS ·
headless boot `--quit-after 300` clean.

### OPEN, with numbers, needing a decision rather than a keystroke

- **`veg.build_scatter` + `veg.tree_cover_mmi` = 680 ms across the crater phase**, and they appear in
  BOTH the idle stall and the physics stall. Every chunk rebuild and every tree break regenerates every
  MultiMesh for the whole chunk. This is now the largest single slice.
- **`TreeBreakSystem._consume` off the physics tick.** The obvious fix is to coalesce the per-chunk
  regen into the existing idle `_process` drain. **NOT DONE TONIGHT, deliberately.**
  `remove_scatter_entries` re-indexes `_chunk_scatter` and re-registers the break registry, so deferred
  indices go stale if anything else regenerates that chunk in the window — and a crater doing exactly
  that is the common case. Two earlier batched versions were already built and reverted. This needs a
  designed invalidation, not a late-night defer.
- **`terrain.collision` 20 ms worst: `create_trimesh_shape()` over 32,768 triangles per chunk**, plus a
  Jolt static-body swap. The chunk is a regular grid, so `HeightMapShape3D` is both geometrically
  identical and far cheaper to build. It touches ballistics, so it wants a ruling and a probe.
- **The real structural fix is not to rebuild a whole 256 m chunk for a 5 m crater.** Everything above is
  shaving an operation that should not be running at that size.
- **UNEXPLAINED: a 35–70 ms idle script step in the QUIET and SPAWN phases with NO instrumented cause.**
  Present with nothing happening. Not chased this pass. Named here rather than rounded away.
- Summoner observation, logged not chased: **"weird loading chunks happening."**

---

## 2026-09-09 — THE PSX TREATMENT, RULED OFF BY THE SUMMONER

**His verdict, after walking it himself: "well that made it look and perform worse."**
Both halves. This closes a question that had been open since 2026-08-07.

### Why it was open for a month
`psx_look.gd`'s own header gated default-on behind "perf numbers govern default-on
(SHIP_AUDIT_2026-08-07.md S5)". The render-scale instrument began lying on **2026-08-07** —
the same day — and did not stop until 2026-09-08. The number that would have settled this
could not be produced, so the game's own stated art direction shipped switched off for a
month. Nobody re-asked; the gate simply sat.

### The measurement (windowed, seed 47225, vsync off, VRAM-compressed textures, his walk)

| | PSX ON (scale 0.375) | PSX OFF (scale 0.75) |
|---|---|---|
| FPS avg | **22.5 – 32.9** | **20.7 – 44.4** |
| GPU ms | **17.4 – 24.2** | **13.8 – 28.1** |
| render thread ms | **2.25 – 6.13** | **0.86 – 4.74** |
| draw calls | 1,584 – 2,368 | 196 – 1,708 |

### THE FINDING THAT OUTLIVES THE RULING

**A quarter of the pixels did not reduce GPU time.** 480x270 renders 25% of the pixels of
960x540 and measured 17.4–24.2 ms against 13.8–28.1 ms — no better, and worse on average.

**The frame is therefore NOT fill-bound at these resolutions.** That kills the fill-rate
hypothesis outright. The render-scale ladder (48.1 / 33.1 / 22.7 ms at 1.0 / 0.75 / 0.5) was
taken on the DRONE camera and does not describe the player's frame.

Cost is in the treatment itself, not the resolution: a fullscreen dither pass, per-material
conversion, and `PsxLook`'s `SceneTree.node_added` hook running on every node spawned. The
render thread roughly doubled.

### Ruled
- **PSX treatment stays OFF.** His eyes and the numbers agree. Do not re-propose it as a perf
  lever; it is not one. Re-proposing it as an ART change is his call alone.
- `--psx` / `--no-psx` flags stay as instruments. They cost nothing when off and they are how
  this was settled in one walk instead of another month.

### Retracted, again
The approved plan named the frame draw-call bound, then game-thread bound, then fill-bound.
All three came from mislabelled or wrong-camera columns. **Three retractions on this question.**
Nothing about where this frame goes is established except: GPU 14–28 ms is not the wall, and
the drops are crater chunk-rebuild and tree-break on the physics tick (measured, 2026-09-08).

### WHY it looked worse — the mechanism, so nobody re-tries it blind

His report: "the firebase models of buildings were flipping and flooping and changing shape
with that new shader."

That is `ps1_material.gdshader`'s **vertex snap** plus **affine (non-perspective-correct)
texture mapping**. Both artefacts scale with POLYGON SIZE:

- Vertex snap quantises positions to a coarse grid. Across a large triangle the snapped
  corners jump between grid cells as the camera moves, so the surface visibly flexes.
- Affine mapping omits perspective correction, so the texture swims across a large polygon.

On small, densely-tessellated props these read as authentic PS1. On **large flat architecture
they are catastrophic** - and `fsb_main_v3.glb` is a 43 MB kitbash of exactly that: bunker
walls, revetments, hooch panels, 2,455 surfaces. It is the worst-case geometry for this shader
in the entire project.

**If the PSX look is ever revisited as an ART decision (his call alone, never as perf), the
snap must be tessellation-aware or excluded from architecture entirely.** Applying it
uniformly to the whole world is what he saw and rejected.

---

## 2026-09-09 — THE FAR CANOPY IS REAL 3D. It costs frames. His ruling is owed.

Executing the Summoner's art ruling ("no more 2d terrain cards, or 3d plane spliced cards or
whatever. all 3d blender models only in game" · "i do not want the old 2d made 3d terrain art
pieces"), barbwire the single exemption. This is the second half of the near-ground
`GroundClutter` conversion; it is an ART decision, and the numbers below are reported so he
can price it, not to justify it.

**What changed** (`terrain/vegetation/tree_cover_layer.gd`): the 65–350 m impostor-card ring is
deleted. There is now ONE `MultiMeshInstance3D` per (species × 64 m bucket) drawing the real
species GLB from 0 to 350 m. The 65 m boundary — a hard snap that changed a plant's DIMENSION
in one frame — no longer exists.

**Structure, measured** (`tests/test_tree_cover_wired.tscn`, seed 47225, whole AO):

| | canopy child nodes | build |
|---|---|---|
| card ring | 14,418 | 742 ms |
| real meshes | 7,268 | 732 ms |

**Frame, measured** (`tools/bench_canopy.tscn`, seed 47225, 8 fixed yaws from one deep-jungle
stand at 120/120, 6 s sampled per yaw, ship-parity 0.75 render scale, box clear of every other
Godot process):

| | worst frame | worst 1% low | mean fps | draw calls | primitives | gpu |
|---|---|---|---|---|---|---|
| card ring | 42.97 ms | 37.2 fps | 74.3 | 353 | 105,676 | 11.89 ms |
| real meshes | 54.85 ms | 30.1 fps | 60.0 | 412 | 175,077 | 15.54 ms |
| delta | **+11.9 ms** | **−7.1 fps** | −14.3 | **+59 (+17%)** | **+69,401 (+66%)** | **+3.65 ms** |

Every delta clears the ~3 fps / ~2.4 ms detectability floor. **The conversion costs frames.**

Two things the numbers say that are worth more than the totals:

- **Mesh LOD is engaging on MultiMesh.** Primitives rose 66%, not 100×. Every vegetation GLB
  imports with `generate_lods=true` and the renderer is picking down the ladder
  (`tools/probe_far_ring_meshes.gd`: broadleaf_a 752→12 tris, bamboo_a 830→86). Without that
  this change would have been unshippable. `rice_a` and `elephant_grass_b` generated NO ladder
  and draw full detail everywhere; at 84 and 160 tris that is recorded, not fixed.
- **Draw calls went UP while nodes halved.** A card is one surface; a real species GLB carries
  more. The bound is surfaces, not nodes.

**The fill-rate hypothesis stays dead.** It is not resurrected by this row: the cost here is
geometry and surface count, and the 480×270 run already refuted fill.

**Untested lever, named not pulled:** the 350 m ring draws grass tufts, rice and ferns as full
meshes at ranges where they are under a pixel. Shortening the draw radius for the SMALL species
only is a real-mesh answer, not a plane, and would take back most of the primitives — but it
thins the distant jungle floor, so it is a LOOK change and his call.

### The two other pop sources he may be seeing

1. **545 firebase interior props appear in one frame at 40 m.** Counted
   (`tools/probe_interior_pop.gd`): 545 `fb_int_` nodes, 1010 surfaces, 43,941 tris — the
   comment at `site_planner.gd` claimed 178/368/11,936 and was stale by 3×; corrected in the
   same change. `site_planner.gd:1705-1706` sets `visibility_range_end=40` and
   `visibility_range_end_margin=8` but NEVER sets `visibility_range_fade_mode`, so the default
   DISABLED applies and the margin is hysteresis, not a fade. `FADE_SELF` is not the fix — it
   alpha-dithers the props see-through, the ADR-026 opacity bug. Either the range moves out and
   costs calls, or it stays and pops. **Ruling owed.**
2. **`project.godot:331 mesh_lod/lod_change/threshold_pixels=2.0`** (Godot's default is 1.0) is
   now load-bearing for the WHOLE canopy rather than just the 0–65 m band. It swaps a level at
   twice the screen error. Lowering it trades frames for smoothness. **Ruling owed** — not a
   silent tweak.

### Side effect worth its own line: 15 MB of card sheets left the drawn set

The 40 card GLBs carried ~15 MB of PNG sheets (`vine_b_card_vine_b.png` alone is 1.5 MB) — the
largest textures in the vegetation tree by three orders of magnitude against the 1 KB
`*_jungle_palette.png` the real species use. **42 of the 241 entries in
`tools/perf_phase1_set.txt`, the VRAM-compression set, are card textures the game no longer
binds** — that fraction of the compression pass now buys nothing and the set wants re-picking.
The card assets are LEFT ON DISK deliberately: `scripts/dev/fps_printer.gd` used one as its
compression witness, and deleting them mid-A/B would have broken the instrument. The witness is
repointed to the US kit sheet (17 MB, drawn every frame the squad is on screen); retiring the
card assets themselves is a separate, reversible cleanup.

### 2026-09-09 — THE SUMMONER'S VERDICT: "overall the game felt more stable tho"

His words, after walking the demo and playing the 45-man assault. **This is the only instrument
that rules feel** (his own 2026-07-20 law: "No numeric gate — my eyes decide"), and it is the first
positive verdict since the instrument was repaired.

**IT CANNOT BE ATTRIBUTED TO ONE CHANGE.** Too much landed in one night and no clean A/B was ever
taken. Recorded honestly as a whole-session verdict, not as evidence for any single fix. Candidates,
in the order I would bet on them:

1. **VSYNC OFF.** It had been ON in every windowed run this project has ever taken. At 24–35 fps on a
   60 Hz panel vsync does not smooth anything - it forces every frame to a refresh boundary, so the
   rate steps 30 -> 20 -> 30 instead of drifting. That IS "unstable" as a felt quality, and it was
   hiding inside the measurement tool.
2. **The 0.75 render scale actually reaching the viewport** for the first time since 2026-08-07.
3. **495 dead monitoring Area3D turned off** - nothing had ever read a hitzone overlap.
4. **Chunk mesh build off SurfaceTool**: worst chunk 27.0 -> 6.4 ms, worst crater 119.4 -> 80.7 ms.
5. VRAM texture compression: ~4,147 MB -> 937 MB.

**What this does NOT discharge.** The measured stalls are still there: crater chunk-rebuild at
80–94 ms and TreeBreakSystem at 66 ms on the physics tick. "More stable" is not "no drops", and the
1% lows in his own stress walk were still 3.4–3.9 fps on the worst windows. Do not let this verdict
close the stall work.

**Do not regress this.** Any future change that puts vsync back on by default, or lets PsxLook
overwrite the render scale again, is undoing the thing he just felt.

---

## 2026-09-09 (day) — THE CRATER, CUT IN HALF TWICE: the veg cache never hit, and the collision was a trimesh

Instrument: `tests/stall_bench.tscn`, headless, **seed 47225**, CRATER phase (6 LARGE_EXPLOSION digs
12–32 m from the player). Headless is legitimate here and only here — every span below is main-thread
or physics-thread CPU. **No FPS and no GPU claim is made; that verdict is still his walk.**

### 1. The scatter cache built on 2026-09-09 NEVER HIT ONCE, and the instrument had to be built to see it

`veg.build_scatter` was still 402–423 ms across the crater phase after the cache shipped. Splitting the
span into `veg.scatter_hit` / `veg.scatter_miss` (`vegetation_manager.gd`, `_build_scatter`) answered it
in one run: **`veg.scatter_miss x36, veg.scatter_hit x0`.**

Cause, `vegetation_manager.gd` `_dirty_scatter`: it set the chunk's required epoch to
`_scatter_epoch + 1`, while `_build_scatter` stamps the cache it writes with `_scatter_epoch`. **No
rebuild could ever satisfy its own dirty mark.** Every writer already bumps the epoch *before* naming
its chunks, so the requirement is the current epoch, not the next one. One character; the cache the
whole 2026-09-09 night entry is about had been inert since it shipped.

### 2. A shell rebuilt every chunk it touched TWICE

`DamageSystem.apply_damage` called `VegetationManager.clear_area` (immediate re-materialize) **and**
queued a heightmap dig whose chunk rebuild ran the identical work a frame later. 6 shells over
18 chunk rebuilds produced **36** `build_scatter` + **36** `tree_cover_mmi` calls — exactly two per
chunk. `clear_area` now takes `defer_rebuild` and `damage_system.gd` passes it whenever the dig was
actually queued (ceiling/`_cell_is_full`/holes-off still materialize immediately). The surviving pass
is also the CORRECT one: it runs *after* the heightmap edit, so plants re-seat on the new ground.

### 3. A hole is a DELETION, so the cache is PRUNED, not thrown away

`clear_area` now filters the blasted plants out of the cached scatter (`_prune_scatter_cache`) instead
of dirtying the chunk. This is safe for a reason that is checkable rather than plausible:
`_build_scatter` draws every RNG value for a candidate — position, species, basis — **before** it tests
the hole, so removing entries cannot perturb the stream. Felled logs are exempt (they are re-emitted
inside holes on purpose). **Proved, not argued:** `tools/probe_crater_veg.gd` regenerates the same
chunk from scratch after the shell and compares — **2,377 pruned vs 2,377 regenerated, 0 positional or
species mismatches.**

### 4. Terrain collision is a HEIGHTFIELD now (his ruling, 2026-09-09)

`terrain_chunk.create_raycast_collision` built `create_trimesh_shape()` per chunk. **Correction to the
standing figure: that is 8,192 triangles per chunk, not 32,768** — `world_config.gd:11 CELL_SIZE = 4.0`,
so a 256 m chunk is 64×64 cells. The 32,768 in the earlier entry and in the todo assumed 2 m cells.

`HeightMapShape3D` over the same 65×65 samples `build_mesh` already computes (`_height_samples`, filled
in the same loop, so collider and visible mesh cannot describe different ground). Two contracts that are
easy to get wrong: the shape has **no cell size** (one unit per sample → a `(4,1,4)` scale) and it is
**centred** (→ a half-chunk offset).

| measured | trimesh | heightfield |
|---|---|---|
| shape build, one real chunk (`probe_terrain_collision`) | 4.36 / 4.76 / 8.39 ms | **0.09 ms** |
| synthetic 129×129 build (`probe_heightfield_shape`) | — | 0.48 ms |
| `terrain.collision`, crater phase, 18 rebuilds | 175.3 ms (worst 10.3) | **below the 12-cause report floor (<10.8 ms total)** |

**The ballistics evidence, because this is what bullets and boots hit** (`tools/probe_terrain_collision.gd`,
real world, seed 47225, chunk (2,2), the OLD trimesh rebuilt beside the new shape and both fired at):

| | pristine | after a real crater |
|---|---|---|
| downward ground height, 3,000 rays | mean 0.00004 m, **worst 0.00024 m** | mean 0.00004 m, **worst 0.00024 m** |
| grazing bullet lines, 600 rays | worst separation **0.0008 m** | worst separation **0.0015 m** |
| rays hitting one shape and missing the other | 0 | 0 |

Godot/Jolt splits each cell on the **same diagonal** `build_mesh` does — that was the real risk and it
is measured, not assumed. Jolt also accepts the non-uniform `(cell,1,cell)` scale, which was the other
open question. Context, not a regression: the collider and the **bilinear** `get_height_at` oracle
differ by up to 0.207 m (0.408 m cratered) and always have — a triangulated cell is not a bilinear patch.

### The crater phase, three passes, same bench and seed

| | before | + dedupe | + prune | + heightfield |
|---|---:|---:|---:|---:|
| `veg.build_scatter` | 422.9 ms x36 | 212.5 x18 | 72.2 x18 | **59.9 x18** (16 hit / 2 miss) |
| `veg.tree_cover_mmi` | 366.8 x36 | 188.3 x18 | 177.9 x18 | 203.9 x18 |
| `terrain.collision` | ~175 x18 | 175.3 x18 | 175.3 x18 | **off the report** |
| `terrain.crater` total | 722.9 | 752.1 | 567.5 | **453.6** |
| worst idle script step | 175.25 ms | 178.58 | 142.45 | **130.43** |

**Read the two middle columns honestly:** the dedupe deletes ~390 ms of duplicated work but does NOT
move the worst crater frame, because the two rebuilds were always in *different* frames — the shell's
and the dig's. The frame the Summoner feels is moved by the prune and the heightfield.

**Box hygiene, stated because the register demands it:** runs 1–3 were taken with no other Godot
process alive. A foreign Godot process (pid 10060, started 10:51, not the console exe, **not killed**)
was resident for the final row. So the 453.6 / 130.43 column was measured on a DIRTIER box than the
567.5 / 142.45 it is compared against — the improvement is if anything understated, and the call
counts (x36 → x18, 16 hit / 2 miss, collision off the report) are scale-free either way.

### THE BROKEN-INSTRUMENT REGISTER — the ballistics gate passed one run in three

`tools/probe_bullet_damage.tscn` is the probe the 2026-09-08 hitzone-monitoring change was closed on.
Measured today at HEAD, unmodified: **PASS, FAIL, FAIL / and 1 of 4 on a second sample.** It aimed at a
hardcoded `+1.52 m` above the man's origin, and a head is only there in some poses — so the run's
outcome was decided by which idle frame he had settled into. Freezing the AnimationPlayer did NOT fix it
(that only stops the pose drifting *after* the ray). Asking the HEAD region where it actually is did:
**4 runs, 4 passes, with the heightfield collision in the tree.**

A gate that adjudicates one time in three is not evidence in either direction, and it had been quoted as
evidence. Same class as the AUDIT-12 leak flake named in `tree_break_system.gd`.

### Regression gates, all green with both changes in
`test_ship_parity` · `test_flat_damage` · `test_tree_cover_lod` · `test_grid_queries` ·
`test_render_scale` · `test_fossils` 28/28 (it caught an unused accessor I had just added — deleted,
not grandfathered) · `tools/probe_bullet_damage` (repaired, 4/4) · `tools/probe_crater_veg` ·
`tools/probe_terrain_collision` · `tools/probe_heightfield_shape` · headless boot `--quit-after 300`,
**0 SCRIPT ERROR**.
