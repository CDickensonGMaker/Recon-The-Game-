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
  desktop default**. **Verify the renderer AT RUNTIME**, never by grepping `project.godot`.
  **CORRECTED 2026-09-09: the harness this line sent you to was not doing that.**
  `windowed_patrol_perf.gd` printed `ProjectSettings.get_setting("rendering/renderer/rendering_method")`
  — the very setting the paragraph above says is stripped and untrustworthy. It agreed with reality by
  luck, because `forward_plus` is also the default. Both it and `--print-fps` now print
  `RenderingServer.get_current_rendering_method()` + `get_current_rendering_driver_name()`, which is
  what the process actually booted (`tests/windowed_patrol_perf.gd:54-55`,
  `scripts/dev/fps_printer.gd`).
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

---

## 2026-09-09 (night) — THE FIREBASE BAKE IS REAL 3D TOO. The last cards in the world are gone.

The third and final half of the Summoner's art ruling ("no more 2d terrain cards, or 3d plane
spliced cards or whatever. all 3d blender models only in game"), barbwire the one exemption
(`bwire_card` untouched, as decreed). The two runtime halves shipped this morning; this is the
ART BAKE — ~350 plants baked into `fsb_main_v3.glb` around the treeline ring, which no runtime
code reaches.

**Discharged:** `tools/probe_firebase_cards.gd` reported `14 flat (card-like), 5 volumetric` in
the morning and now reports **`0 flat (card-like), 19 volumetric`**.

### What was re-exported, and how the plants found their places

`scatter_veg()` fuses every instance of a species into ONE merged mesh, so the per-instance
transforms are not stored anywhere in the blend. They are still recoverable EXACTLY, because
`bmesh.from_mesh()` appends: instance *i* occupies the vertex block `[i*V, (i+1)*V)` where `V`
is the source card's vertex count. A Umeyama fit per block returns translation, rotation and
uniform scale.

**Max fit residual across all 349 instances in all 14 groups: 0.0000 m.** That is the whole
reason this is a swap and not a re-scatter — the real model stands on the card's exact
transform. `tools/refit_firebase_veg.py` refuses to plant if any block exceeds 1 mm, and
refuses outright if a merged mesh is no longer N copies in vertex order.

**349 instances**, against the "~360 cards" every prior note guessed. Counted now, per species:
bush_a 20 · bush_b 21 · bush_c 32 · fern_a 25 · fern_b 27 · fern_c 22 · elephant_grass_a 43 ·
tall_grass_a 40 · grass_tuft_b 41 · jungle_palm_a1 19 · a2 15 · b1 18 · b3 9 · palm_sapling_a 17.

**No species was invented or substituted.** All 14 real GLBs already existed under the identical
stem, each imported as a single mesh part (audited on load; the export raises rather than
substitute). Card and model bounding boxes agree in width and height to the centimetre — the
card was rendered FROM the model, so scale parity is inherent, not assumed.

**It is an export step, not a blend edit** — the same shape as the `-colonly` twins:
generated inside `export_firebase()`, exported, undone. The artist's blend still holds the
cards and is never saved. Reverting the ruling is reverting `tools/refit_firebase_veg.py`.

### THE PRICE. Measured, reported as the cost of his ruling, not argued against it.

Instrument: `tools/bench_firebase_veg.tscn`, 8 fixed yaws from the compound centre at eye
height, 6 s sampled per yaw, **ship-parity 0.75 render scale asked of the VIEWPORT** (it read
`0.750` at 1280x720, printed in every run), Forward+, vsync off. It loads the GLB, one sun and
a fixed camera — NOT `build_patrol_world` — because the firebase bake is a baked asset that
does not vary with the operation seed, and a live garrison between two runs would be noise in
an A/B whose whole subject is one asset's geometry. **The cost below is therefore the FULL cost
of the change, not the fraction that survives into a frame that also holds jungle and men.**

**TWO RUNS PER STATE, because one pair cannot tell a result from noise:**

| | cards run 1 | cards run 2 | real run 1 | real run 2 | resolved? |
|---|---|---|---|---|---|
| `fb_veg_` triangles | 28,646 | 28,646 | 93,024 | 93,024 | **+64,378** |
| `fb_veg_` surfaces | 19 | 19 | 23 | 23 | **+4** |
| primitives in frame | 167,220 | 167,220 | 231,800 | 231,800 | **+64,580 (+38.6%)** |
| draw calls | 603 | 603 | 597 | 597 | **−6 — it did not rise** |
| gpu ms | 7.50 | 7.58 | 7.86 | 7.90 | **+0.34 ms** |
| mean fps | 105.8 | 104.8 | 100.6 | 101.6 | **−4.2 fps (−4.0%)** |
| worst frame ms | 14.55 | 15.80 | 16.69 | 15.41 | **NO — ranges overlap** |
| worst 1% low fps | 73.7 | 69.1 | 67.8 | 72.7 | **NO — ranges overlap** |

**The transferable number is +0.39 ms of frame time** (105.30 -> 101.10 fps is 9.497 -> 9.891 ms),
of which +0.34 ms is GPU. At the demo's 24–35 fps (28–42 ms) that is about **1% of the frame**, and it is well under the ~2.4 ms detectability floor the canopy
conversion was measured against. The canopy conversion cost +11.9 ms; this one costs +0.34 ms.

**AND THE INSTRUMENT CAUGHT ITSELF.** The first pair alone said "worst 1% low 73.7 -> 67.8, −5.9
fps" — a headline. The second CARDS run, with nothing changed at all, moved the same figure
73.7 -> 69.1. **The pacing spread on an unchanged build is 1.25 ms / 4.6 fps, which swallows the
delta.** Worst-frame and 1%-low are recorded above and deliberately NOT reported as a result.
A single A/B pair on this bench cannot resolve pacing; mean fps, gpu ms, draw calls and
primitives are deterministic or near-deterministic and can.

**Draw calls did not rise, and that is the interesting row.** The canopy conversion's bound was
surfaces (+17% calls). Here surfaces rose by 4 and calls fell by 6 — the merged-per-species bake
means 349 plants are still 19 nodes, and Godot's mesh LOD (the GLB imports with
`generate_lods=true`) is picking down the ladder on them.

### The destructible / ballistic contract: measured before AND after, not reasoned about

The naming contract is what makes a mesh shootable and destructible, and a miss ships
INVULNERABLE and BULLETPROOF with no error (ADR-042). Object names, object count and collision
class are all unchanged by design — the 14 groups keep their exact `fb_veg_<stem>` names and all
14 sit in `COL_NONE`, so they emit no collider, before and after. Booted headless both ways
(`res://scenes/levels/test_range.tscn`, which runs the real `plan_demo_world` ->
`build_patrol_world`):

| `[FSB]` line | cards | real models |
|---|---|---|
| ballistic tags | 1254 soft / 1182 hard | 1254 soft / **1181** hard |
| box hulls replaced | 86 | 86 |
| concave forced double-sided | 1985 | **1984** |
| parapet | 81 segs, 1 stray adopted, 0 hidden | identical |
| parapet radii | 49.4–96.0 m | identical |
| structures on the blast bus | 11 bunker, 9 sandbag_stack, 4 tower, 4 bunker_mg | identical |

**The two −1s are one node, and it is a FIX, not a regression.** A control export with the plant
swap disabled — everything else identical — pinned it: the only node that left is
`us_fb_ammo_crate_stack-colonly_P2_3339-colonly`, *a collider built for a collider*. That is
FAILURE MODE 9 in the destructible-export contract, and `make_collision`'s "CONTAINS, not
endswith" fix (2026-09-09, earlier the same day) correctly stops emitting it. The visible-mesh
half of that defect is still there and still needs the object renamed in the source blend.

### A STANDING CLAIM RETIRED: the firebase export is no longer byte-for-byte reproducible

`tools/reexport_firebase_v3.py` asserted, with an md5, that open -> export -> shrink rebuilds
the shipped GLB byte for byte (`6ce1bfbf35bcd9f7b9b090a23d705083`). **It was true for about
twelve hours.** The control export above — cards, no plant swap, today's code — comes out at
`e72085a36f935857815aecbf8102434d`, 43,484,240 bytes against 43,485,624, differing by that one
collider-of-a-collider node. The claim is corrected in place at its source. The pipeline is
still deterministic; it reproduces ITSELF, not a file exported by older code. **Do not quote a
stored md5 for this asset — re-derive it.**

### Bytes

Shipped card GLB 43,485,624 -> real-model GLB **44,647,644 (+1.11 MB)**. 14 card sheets left the
GLB (2.88 MB of PNG) and 2 palm textures entered; materials 155 -> 159, embedded images 42 -> 30.
Geometry growth outweighed the texture saving.

### Named, not pulled — three follow-ups, none of them a ruling

1. **14 orphaned card sheets, 2.88 MB**, still sit beside the GLB as extracted sidecars
   (`fsb_main_v3_bush_a.png` and 13 others). Nothing in the GLB references them any more and
   none of them is in `tools/perf_phase1_set.txt`. A reversible cleanup, deliberately not done
   in the same change as the export — and NOT the `assets/world/vegetation/cards/` originals,
   which stay on disk as `scripts/dev/fps_printer.gd`'s compression witness required.
2. **The merged bake is one AABB per species spanning a ~273 x 210 m ring**, so a group can
   never be frustum-culled and its LOD is picked on the whole ring's screen size. It cost
   nothing measurable at 93k tris. If the firebase bake ever grows again, bucketing each species
   spatially — the same answer `tree_cover_layer` uses at runtime — is the lever, and it does
   not touch any name the destructible contract reads.
3. `VEG_GROUPS` in `tools/gen_firebase_v3.py` now names the real models, so a fresh
   `redress()` bakes real plants from the start. Its `_load_mesh` still takes part one of a
   multi-part GLB silently; all 14 species are single-part today, so it is not a live defect.

### Gates
`tools/probe_firebase_cards.gd` **0 card-like** · both `[FSB]` boots green and diffed above ·
headless boot `--quit-after 300`, **0 SCRIPT ERROR** · `tools/refit_firebase_veg.py` dry run,
**14/14 groups, max residual 0.0000 m**.

---

## 2026-09-09 (night) — THE 545 INTERIOR PROPS ARE FOLDED. And the bench that priced it was refused.

His ruling on the whole row was "ok do it all". This is the interior-prop half.

### What the props actually are — the standing plan was wrong twice

`site_planner.gd` carried a note saying the fix was "folding each prop TYPE into one MultiMesh
(1010 surfaces -> ~11)". Measured instead of assumed (`tools/probe_interior_fold.gd`, new):

- **545 `fb_int_` nodes share 69 DISTINCT meshes, not ~11.** The compound ships eleven identical
  hooch sets, so nearly every prop is one of 69 things.
- **1,010 surfaces of baked copies carry only 5,471 triangles of unique geometry**, against
  43,941 triangles of copies — an 8x duplication.

### What shipped

`scripts/world/interior_prop_fold.gd` (new). One MultiMesh per distinct mesh, and **the baked
nodes are removed in the same call** — detached from the tree and freed, not hidden. That is not
optional: leaving them draws every prop twice, which is the trap the old note warned about.
Measured on a real world boot: **`545 prop(s) -> 69 MultiMesh(es), 1010 surface(s) -> 132`**.

**The range is measured now, not guessed.** 40 m for everything was chosen when every prop cost
its own draw call. Each type is now shown out to the distance at which it covers two rendered
rows — the same screen error `mesh_lod/lod_change/threshold_pixels` already accepts, reused
deliberately and **without touching that setting, which is his open ruling.** A helmet earns
15 m, a cot 230 m. Floor 40 m (never nearer than it shipped), ceiling 230 m
(`STRUCTURE_VISIBILITY_END` — a prop may never outlive the building around it).

**The staggered arrival is kept and widened.** It was 545 thresholds over 6 m, deterministic in
each prop's name (ADR-010). It is now 69 measured per-type thresholds spread over ~150 m, with
the name-derived jitter retained per type, and every one of them lands while the prop covers two
pixels or less. Banding types further was measured and rejected: with 69 types, 4 bands costs 528
draw calls and 6 costs 792 against 132 for one — it quadruples the bill to stagger an arrival
that is already invisible.

**FADE_SELF stayed refused.** It alpha-dithers a prop see-through — the ADR-026 opacity bug.

### THE FOLD DOES NOT PAY FOR ITSELF. It pays for the range move.

This is the counterintuitive result and it is the reason the row is worth reading. Draw calls and
primitives, four lanes, deterministic (identical across repeat runs):

| lane | interior surfaces | draw calls | primitives |
|---|---|---|---|
| A — baked + 40 m (what shipped this morning) | 1,010 | **476** | 223,851 |
| C — folded + 40 m (the fold, isolated) | 132 | **526** | 240,649 |
| B — folded + measured 40-230 m (**shipped**) | 132 | **543** | 241,993 |
| D — baked + measured 40-230 m | 1,010 | **586** | 230,728 |

- **Folding at the same 40 m range COSTS +50 draw calls** (A->C). A MultiMesh gives up per-node
  frustum culling: 545 nodes cull one at a time, 69 MultiMeshes each span all eleven hooches and
  draw whole. Surfaces are not the bill when the surfaces were being culled.
- **The range move costs +110 calls on baked nodes (A->D) and only +17 on folded ones (C->B).**
  That is what the fold buys, and it is the whole justification for it.
- **Net against today: +67 calls (+14%) and +18,142 primitives (+8.1%)**, for a pop that is gone.
- **If the 40 m range is ever restored, the fold must be restored with it or it is a straight loss.**

### THE BENCH WAS REFUSED, AND HE IS RIGHT

His words on `tools/bench_firebase_veg.tscn`: **"cuz its just terrain with no action so its not
really gauging anything."**

It is the same bug class as ADR-026's founding "+65%" drone shot — a camera and a scene no player
ever occupies. **No fps or gpu-ms figure from it is reported here, for this row or any other.**
The table above is draw calls, primitives and surfaces: structural counts that do not depend on
what else is happening, taken at a fixed camera. What the change FEELS like is **UNMEASURED**.

It also explains the pacing noise recorded earlier tonight: with nothing happening in the scene,
there were no events for a 1% low to be about, which is why two identical runs moved it 4.6 fps.

**Required before this bench is quoted again:** re-point it to the firebase during the actual
assault — men fighting, craters, tree breaks live, a player-height camera walking the ground the
player walks, seeded and repeatable. If a loaded bench still cannot resolve the difference, the
honest answer is "not measurable under load", not a clean number from an empty base.

### HIS EYES DECIDE THE DISTANCE — press F9

A headless session cannot judge draw distance, so it is not shipped as a silent guess.
**F9 cycles the interior-prop draw distance** in the running game — MEASURED (2 px, the default)
-> NEAR (about the retired 40 m) -> FAR (1.5x measured) — and prints what it selected each press.
`scripts/world/interior_prop_dial.gd`. The boot log names the key:
`[FSB] interior prop draw distance: press F9 to cycle (MEASURED (2 px, the default))`.

### A THIRD BROKEN INSTRUMENT, caught in the act

`RenderingServer.viewport_get_measured_render_time_gpu` returned a mean of **4,434,311,963 ms**
for one whole run — the timestamp counter handing back junk. Averaged in silently it destroys the
column without failing anything. The bench now rejects any sample outside 0-1000 ms and prints how
many it threw away. Nothing that bench measures can legitimately take a second of GPU time.

### The destructible contract: diffed, and it did not move

The fold creates `fb_int_mm_*` MultiMeshInstance3D nodes and frees the baked MeshInstance3D ones.
Nothing the contract reads is involved: ballistics reads **collider** names, the navmesh reads
`CollisionShape3D`, and both are untouched `StaticBody3D` siblings in the flat GLB — a footlocker
is still solid, still shootable, still in the nav bake. Booted headless (`test_range.tscn`):

`1254 soft / 1181 hard` · `parapet 81 segs, 1 stray adopted, 0 hidden` · `radii 49.4-96.0 m` ·
`11 bunker, 9 sandbag_stack, 4 tower, 4 bunker_mg` · `86 box hulls replaced` · `1984 concave` —
**every row identical to the pre-fold boot.**

**And the ordering trap that would have killed the radios.** `_stamp_hooch_radios` reads the
eleven `fb_int_radio` MESH positions to place the voices, and the fold removes those meshes. The
fold is called AFTER it for that reason, with the reason written at the call site. Verified:
`[FSB] radios: 11 hooch set(s) given a voice`.

### Gates
Headless boot `--quit-after 300`, **0 SCRIPT ERROR** · `test_fossils` **28/28 PASS, no new
fossils** (the retired `INTERIOR_CULL_M/_MARGIN_M/_SPREAD_M` constants were deleted with the
system they served, per ADR-023) · contract diff above.

---

## 2026-09-09 (night) — THE WHITE BOX IN THE MORTAR PIT: the premise was wrong, and the fix is BLOCKED on a permission prompt

His ruling authorised renaming `us_fb_ammo_crate_stack-colonly_P2` in the canon blend, on the
understanding that it was a visible prop whose name had a misplaced suffix.

**IT IS NOT A PROP. It is a collision proxy, and the rename as prescribed would have shipped a
duplicate solid crate.** Measured read-only in the blend before anything was touched:

| | the offender | its visible twin |
|---|---|---|
| name | `us_fb_ammo_crate_stack-colonly_P2` | `us_fb_ammo_crate_stack_P2` |
| verts / tris | 24 / 12 | 96 / 48 |
| UV layers | **none** | `UVMap` |
| materials | **0** | 1, on image `fb_crate.002` |
| world location | −49.0983, −1.93674, 1.56025 | **identical, distance 0.0000** |

24 verts, 12 tris, no UVs, no material, sitting on its twin's exact AABB: a box hull. **The
prescribed destination name `us_fb_ammo_crate_stack_P2` was already taken by that twin** — and
Blender does not refuse a name collision, it appends `.001`, which `make_collision` then strips
with `base = o.name.split(".")[0]`. The untextured box would have shipped visible AND collected a
fresh box collider. Strictly worse than today.

**What it actually is:** a collider that escaped the strip. `clear_collision()` matches
`endswith("-colonly")` or `"-colonly." in name`, and a MIDDLE suffix matches neither — the same
character-position assumption that defeats Godot's importer and `make_collision`. Three call
sites, one wrong assumption. It ships today as a Godot-default **white** box, 0.94 x 0.41 x 0.99 m,
z-fighting the textured crate in the P2 mortar pit — **a candidate for the demo audit's "white
surfaces on the walked path"**. Its twin is already correctly collided by the generated
`us_fb_ammo_crate_stack_P2_3338-colonly`.

**The corrected fix, non-destructive:** rename it to `us_fb_ammo_crate_stack_P2-colonly` — suffix
at the END. `clear_collision()` then finally matches it and removes it from the session before
export, so it ships *nothing at all*, while the object stays in his blend (the pipeline never
saves that file). No geometry is deleted from his art source. The mesh datablock goes to
`fb_ammo_crate_stack_002-colonly` — underscore, not `.002`, because `split(".")[0]` would
otherwise destroy the marker one level down and recreate this exact bug class.

### BLOCKED — and it needs him, not another attempt

**The write to `firebase_v3.2.blend` was denied by the permission classifier three times.** The
blend is untouched: mtime `2026-09-06 16:32:14`, size `50,534,041`, verified after every attempt.
No backups, no `.blend1`, nothing written to that directory.

A relayed instruction is not consent, and a denial is not something to route around. **This lands
when Caleb approves the prompt or adds a permission rule for `blender.exe`, and not before.**

Script, ready to run unchanged, now preserved in the repo rather than the session scratchpad:
`tools/rename_fb_ammo_crate_colonly.py`. It asserts both destination names are free before
assigning, captures a full identity signature and a 14-field inventory and aborts if either
drifts, asserts the new name satisfies both exporter predicates, and saves with `compress=True`
(the file is zstd, and `save_mainfile` does not inherit compression in background mode).

**Blend baseline for whoever completes it** — all of it must be unchanged afterwards:
3,365 objects (2,416 mesh), 565,702 tris, 651,966 verts, 629 mesh datablocks, 281 materials,
65 images, 24 collections.

**Expected side effects when it does land, so the contract diff is not misread:** GLB nodes
5,811 -> 5,810 · generated collider indices shift down by one after that object's slot, because
`make_collision` names them `{base}_{i:03d}-colonly` off `enumerate(sc.objects)` and the orphan
currently consumes a slot even though it is skipped. Prefixes and families are unaffected, so
ADR-042 tagging and `firebase_ballistics_baseline.json` (which keys on family names and counts,
not node names) are safe — but a raw node-name diff will light up, and that is expected, not a
regression.

**A machine worth adding with it:** assert at export that no exported GLB node contains
`-colonly` anywhere but at the end of its name. One set comparison over `nodes[].name`. It would
have caught this in August.

~~**The GLB was NOT re-exported for this row**~~ **LANDED 2026-09-09 (night, second pass).**
He approved the write; the rename ran in background Blender and the firebase was re-exported.

| | before | after |
|---|---|---|
| blend | 50,534,041 B, `us_fb_ammo_crate_stack-colonly_P2` | 50,533,163 B, `us_fb_ammo_crate_stack_P2-colonly` (mesh `fb_ammo_crate_stack_002-colonly`) |
| GLB md5 | `e47eba8dd1cca16962c5c05a9f32be06` | `6461852eff7c0c9e6dbb885b296767c7` |
| GLB bytes | 44,647,644 | 44,646,444 |
| nodes | 5,811 | 5,810 |
| `-colonly` nodes | 2,308 (2,307 terminal, **1 stray**) | 2,307 (**all terminal, 0 stray**) |
| visible material-less meshes | **1** | **0** |

**The blend baseline held exactly** - 3,365 objects / 2,416 mesh / 565,702 tris / 651,966 verts /
629 meshes / 281 materials / 65 images / 24 collections, before, after, and again after reopening
the saved file. zstd compression preserved; no `.blend1` written (`save_version = 0` set for the
run, because `--factory-startup` restores the stock value of 1).

**Contract diff, both directions.** One node removed (`us_fb_ammo_crate_stack-colonly_P2`), zero
added. The other 17 raw name differences are the predicted collider index shift and are all
**exactly -1**, all inside the P2 mortar pit (`us_mortar_*_P2`, `us_MC_round_slide_P2`), because
`make_collision` numbers off `enumerate(sc.objects)` and the stray no longer consumes a slot.
Every prefix family is unchanged except `us_fb_ammo_crate_stack` 5 -> 4: parapet 162, bunkers
16/8/6, towers 8, sandbag stacks 18, hootches 836, `fb_veg_` 24. COL_NONE membership identical
both directions - 0 colliders on a COL_NONE family, and the 12 passable families keep their exact
counts (door_ 84, mud 24, scorch 22, the rest unchanged).

**THE MACHINE, so this cannot ship a third time** (it shipped in the 2026-08-12, 09-06 and 09-09
exports): `gen_firebase_v3.assert_colonly_terminal()` raises before the exporter runs;
`reexport_firebase_v3.audit_colonly()` re-reads the SHIPPED BYTES afterwards and raises on any
stray; `tests/test_fsb_colonly_contract.tscn` asserts it against the imported Godot scene -
**2,435 collider bodies, 2,130 visible meshes, 0 stray, 0 white**. The pre-flight was selftested
against the exact historical name and trips on it.

**The white box is gone, and it was the only one in this GLB.** A material-less-primitive audit of
the shipped file finds 1,753 such meshes, every one of them a `-colonly` collider (invisible in
Godot) and **zero visible ones**. That closes the firebase's contribution to the demo audit's
"white surfaces on the walked path"; it does not speak for the terrain or the village models.

---

## 2026-09-09 (afternoon) — THE PARTIAL CHUNK UPDATE, and two look dials handed to his hands

His ruling on the whole open row was "ok do it all". Rows 3 and 6 went to the firebase agent; rows
2, 4 and 5 are below. **Rows 2 and 4 end UNMEASURED for frames, on purpose — see the last section.**

### Row 5 — a 5 m hole no longer rebuilds a 256 m chunk

`terrain_manager.modify_terrain` destroyed the TerrainChunk, re-derived every quad, re-emitted every
vertex, built a new Jolt body and rebuilt the whole canopy — for an edit that moves a handful of
samples. The exact size of that edit, for the LARGE_EXPLOSION the bench and the siege both fire
(`damage_system.gd:43-46` radius_cells 5, `world_config.gd:11` CELL_SIZE 4.0 → 20 m):

| per shell, per chunk | before | after |
|---|---:|---:|
| height samples re-derived | 4,225 | **121** (2.9%) |
| quads re-derived | 4,096 | **144** (3.5%) |
| vertices re-emitted | 24,576 | 864 written, whole array re-submitted once |
| chunk node + Jolt static body | destroyed and rebuilt | **untouched** |
| collision shape | trimesh rebuilt | `map_data` re-assigned |

The patch cache (the three fan-out arrays, ~1.2 MB a chunk) is armed by the FIRST shell on a chunk,
not held for all 25 — ground nothing hits pays nothing.

**Equivalence, which is the only thing that matters here** (`tools/probe_chunk_patch.gd`: two shells,
then force the full rebuild the patch replaced and compare):

| | patched vs fully rebuilt |
|---|---|
| vertices | **0 of 24,576 differ** |
| collision samples | **0 of 4,225 differ**, worst 0.000000 m |
| downward rays | **0 of 2,000 differ**, worst 0.000000 m |
| canopy | 338 MultiMesh nodes, **0 of 2,132 instances differ** |

Both fast paths carry their own control in the probe, so "the two agree" can never mean "the fast
path never ran".

### Row 5, the half that was BUILT, MEASURED AND REMOVED — the canopy cannot be re-seated

An in-place canopy re-seat was written for the same reason: a height edit moves plants in Y without
changing which plants there are. **It never fired once in the crater bench, and the reason is a
design fact, not a bug:** the same blast that digs the hole FELLS TREES. `TreeBreakSystem` drops
those entries, so the plant list HAS changed, which is exactly the case an in-place re-seat must
refuse. Removed rather than left in as an unexercised path (ADR-023).

**It was nearly kept on a false green.** The first control counted a `StallLedger` span — and a span
counts ATTEMPTS. Every attempt was failing (`generate_for_chunk` cleared the chunk's visuals before
the re-seat could reach them), and the probe read PASS. A success counter said 0. **A span is not a
success count**, and this is the third instrument this week that answered a question it was not
being asked.

### Row 2 — the ground-cover ring, and what the census says its ceiling is

Grass, rice and ferns now stop at **150 m** while the canopy still draws to 350
(`tree_cover_layer.gd` SMALL_RING_M / SMALL_PREFIXES). The number is not taste: it sits just outside
the AI's open-ground sight cap (SIGHT_CAP_OPEN 140 m), so every metre of ground anyone can see or
shoot you across still has its cover drawn.

**The census first, because it bounds what this lever can possibly buy**
(`tools/probe_ground_cover_census.gd`, seed 47225, whole AO):

| class | instances | share | full-detail tris | share |
|---|---:|---:|---:|---:|
| ground cover (grass, rice, fern) | 8,544 | 17.2% | 674,357 | **7.7%** |
| canopy (trees, bamboo, palm, bush, vine) | 41,151 | 82.8% | 8,114,169 | 92.3% |

**So the ceiling on this lever is 7.7% of drawn triangles, and only the part beyond 150 m.** Anyone
expecting a large number from it should stop here.

**Two findings from the same census that are worth more than the lever:**
- **`bush_a/b/c` are 10,938 instances of the canopy class**, and a bush is waist-high concealment,
  not canopy. On the same sight-cap argument they are the next candidate for the short ring — and a
  bigger one. **His call, because it changes how thick the mid-distance jungle reads.**
- **NO RICE IS EVER PLANTED.** `vegetation_manager.gd:63` sets `TYPE_PROPS[RICE_PADDY] = [0.00, 0, 0]`,
  so the rice-paddy classification plants nothing at all; `rice_a`/`rice_b` are absent from the census.
  Which also makes `rice_a`'s missing LOD ladder cost exactly zero.

**The missing LOD ladders are an ART fact, not a setting.** `rice_a` and `elephant_grass_b` carry
`meshes/generate_lods=true` and import settings **byte-identical** to `rice_b` and
`elephant_grass_a`, which DO generate ladders (`diff` of the two `.import` files differs only in the
cache path). The importer declines on those two meshes' topology. Nothing in the import pipeline can
fix it; the source mesh can. Recorded, not churned.

### Rows 2 and 4 — UNMEASURED FOR FRAMES, and why that is the honest answer

The bench that would have decided them is `tools/bench_canopy.tscn`: eight fixed yaws on quiet
terrain. **His verdict on it: "cuz its just terrain with no action so its not really gauging
anything."** He is right, and it is the same bug class as ADR-026's founding "+65%" — a camera and a
scene no player occupies. Every frame he has complained about came from the 45-man assault.

Two runs were taken before that ruling landed and they are recorded for their GEOMETRY only, because
a foreign Godot process was resident throughout and the timing is void:

| 8 yaws, seed 47225, scale 0.75 | draw calls | primitives |
|---|---:|---:|
| ground cover to 350 m (before) | 414 | 176,237 |
| ground cover to 150 m (after) | **378 (−8.7%)** | **164,394 (−6.7%)** |

Those two counters reproduce the 2026-09-09 morning canopy row (412 calls / 175,077 prims) to within
1% while fps and gpu ms read 2× worse — **which is itself the useful result: on a contended box the
geometry counters are trustworthy and the timing counters are not.**

**`mesh_lod/lod_change/threshold_pixels` STAYS AT 2.0 and is recorded as unmeasured.** GPU ms reads
zero headless, no windowed run may be taken while he is at the machine, and guessing it would be the
fourth retracted perf conclusion on this question.

### What replaced the bench: two dials in his hands

His own law is that his eyes decide, so both open questions are now switches he can flip mid-walk
(`tree_cover_layer.gd`, F9/F10 unbound anywhere else in the project). Each prints to the console AND
toasts on the HUD, and the game names both keys ~4 s after the world builds:

- **F9** — ground-cover draw distance: 150 m (shipped) → 100 → 250 → same as the trees (350).
- **F10** — mesh LOD sharpness: 2.0 px (shipped) → 1.0 (smoother, costs frames) → 4.0 (coarser, cheaper).

### Gates, all green headless with everything above in
`test_ship_parity` · `test_flat_damage` · `test_tree_cover_lod` · `test_grid_queries` ·
`test_render_scale` · `test_fossils` · `test_trunk_ring` · `test_veg_density` ·
`test_tree_cover_wired` · `probe_chunk_patch` · `probe_crater_veg` · `probe_terrain_collision` ·
`probe_bullet_damage` · headless boot **0 SCRIPT ERROR** · `demo_game.tscn` headless boot
**0 SCRIPT ERROR**.

### 2026-09-09 (night) — THE SUMMONER'S SECOND VERDICT: "yeah that felt smoother"

His words after walking the build launched for him tonight. This is the second consecutive positive
verdict from the only instrument that rules feel (his 2026-07-20 law: "No numeric gate — my eyes
decide"), following "overall the game felt more stable tho" the same morning.

**WHAT IT COVERS.** The build he walked carried, in one launch: the partial chunk update (a 5 m hole
re-derives 2.9% of a chunk's ground samples instead of rebuilding 256 m, and the chunk node, mesh
instance and Jolt body are never destroyed), the `HeightMapShape3D` terrain collider (shape build
4.4–8.4 ms -> 0.09 ms, `terrain.collision` off the report), the scatter-cache epoch fix and crater
double-rebuild dedupe (crater phase 723 -> 454 ms, worst idle script step 175 -> 130 ms), the
ground-cover ring at 150 m, and the 545 interior props folded to 69 MultiMeshes.

**WHAT IT DOES NOT DISCHARGE — the same caution as this morning's verdict, and for the same reason.**
It CANNOT be attributed to any one change: too much landed in one build and no clean A/B was ever
taken. It is recorded as a whole-build verdict, not as evidence for any single fix. In particular it
is NOT a measurement of the canopy real-mesh cost, the LOD threshold, or the interior-prop fold — all
three remain UNMEASURED, and the fold is a known +67 draw calls that buys the removal of the pop.

**IT WAS ALMOST CERTAINLY TAKEN ON THE SHIPPED DEFAULTS** (ground cover 150 m, LOD threshold 2.0,
interior props MEASURED) unless he pressed F9/F10/F11 during the walk. He has not yet said which
settings he prefers, so no dial is closed by this verdict.

**Still true from this morning and unchanged:** the measured stalls are not all gone, and no frame
number from a quiet-terrain bench may be quoted. His own ruling stands — *"its just terrain with no
action so its not really gauging anything"* — so the re-pointed bench, running inside the live
45-man assault from a player-height camera, is still owed before any fps figure is published again.

---

## 2026-09-09 (night, wave 2) — THE AMBIENT NAPALM STUTTER, ATTRIBUTED AND CUT

**His report, mid-session, straight after "the rest felt smoother":** *"when the ambient napalm hits
tho it still stutters really bad."*

### It was in HIS OWN LOG, and the log named the frame

`AppData/Roaming/Godot/app_userdata/RECONgame/logs/recon.log`, his live session, line 761 onward:

```
[DEMO] air beat: NAPALM at 256,466 (210m out on bearing 90 deg)
[PERF] FPS=36 -> 35 -> 13 -> 1 -> 25 -> 38
```

**FPS=1.** Beside it, **145 `[TreeCover]` print lines** in the same window. That log rotates out after
8 runs; a copy is preserved at
`AppData/Local/Temp/claude/.../scratchpad/caleb_live_session_napalm_2026-09-09.log`.

### The instrument: `tests/probe_napalm_stall.tscn` (new)

Fires the **real** thing — `FieldDirector.authored_strike(..., Ordnance.NAPALM, ...)`, a real F-4
flying a real pass and pickling `FirePlan.NAPALM_DROPS` (9) real canisters — at the demo's own 210 m
ambient standoff, **after 24 real enemies are on the ground through the real spawn path**. It is not a
quiet bench; his ruling on `bench_canopy` (*"its just terrain with no action so its not really gauging
anything"*) is respected. Every number is a StallLedger per-frame span; no Performance bucket-max is
quoted as a per-frame cost, and no fps or GPU figure is published from it.

### WHAT THE NAPALM FRAME WAS ACTUALLY SPENT ON

**Not the trees. Not the VFX. Not the AI. The terrain crater.**

| span (StallLedger, per frame) | before | after |
|---|---:|---:|
| **worst idle script step** | **125.43 ms** | **54.86 ms** |
| `terrain.crater` (x1) | **122.2 ms** | **13.5 ms** |
| `terrain.chunk_rebuild` (x1) | 121.1 ms | 12.5 ms |
| `terrain.veg_generate` | 96.1 ms over x4, one frame | 82.5 ms over x4, one per frame |
| `terrain.patch_mesh` | *never ran* | 9.1 ms |
| worst physics script step | 22.69 ms | 22.32 ms |
| `[TreeCover]` print lines per strike | **439** | **5** |

> **CORRECTED 2026-09-09, when `StallLedger` learned to subtract nesting.** Every figure in that
> table is INCLUSIVE, and `terrain.crater` **calls** `terrain.chunk_rebuild` — the nesting is visible
> at `:1588` of this file (`terrain.crater 81.6ms -> terrain.chunk_rebuild 81.5ms`). Laid out as a
> flat table the two rows read as siblings and invite a reader to add them: 122.2 + 121.1 = 243 ms
> inside a 125.43 ms step, which is impossible.
>
> **The crater's OWN work was 122.2 − 121.1 = 1.1 ms.** The heading above — *"Not the trees. Not the
> VFX. Not the AI. The terrain crater."* — is right that the crater CALL was the frame, and wrong
> about where the time went inside it. **`terrain.chunk_rebuild` was 121.1 of the 122.2 ms**, and the
> fix that worked was a chunk-rebuild fix. The distinction matters for the next person deciding what
> to optimise: there is nothing left to win inside `crater` itself.
>
> The instrument now prints `name excl(incl)/worst xN` so this cannot be misread again.

**The root cause, named:** `DamageType.NAPALM` is `radius_cells: 22` (`terrain/systems/damage_system.gd:57`),
and at the demo's 4 m cell that is an **88 m radius heightmap edit — 176 m across, which always spans
four 256 m chunks**. `_rebuild_chunks_in_region` rebuilt **all four in one idle frame**, and because
`_patch_armed` was populated lazily *by the first shell*, none of the four was armed, so all four took
the full `_rebuild_chunk_immediate` path. **The partial-update fast path shipped this morning never
engaged for a napalm at all** — `terrain.patch_mesh` does not appear anywhere in the before column.
The lazy arming was written for artillery, which clusters; **air support never gets a second shell on
the same ground to pay it off.**

### Fixes, all measured

1. **Every chunk is armed for the patch at load** (`terrain/core/terrain_manager.gd`, `_load_chunk`).
   Costs RAM, not time — `build_mesh` already builds these arrays; arming only stops them being
   dropped. **~1.0 MB per 256 m chunk: 4 MB on the demo's 512 m map, ~67 MB at ADR-013's 2 km ceiling.
   If that ceiling is ever built this line needs a chunk-count condition — HIS CALL.**
2. **The crater's per-chunk vegetation re-derive is deferred, one chunk per frame**
   (`terrain_manager._queue_veg_regen` / `_drain_veg_regen`). The heightmap edit, the mesh patch and
   the `HeightMapShape3D` collision all still happen **immediately** — outcome intact; only which
   grass is *drawn* lags, for at most three frames, on chunks 88 m wide.
3. **`load_species` is asked once per species, not once per felled trunk**
   (`scripts/world/tree_break_system.gd`, `_ensure_parts_loaded`). 710 trunks felled produced **1
   call**. That is the 439 -> 5 print collapse. The dedupe lives in the CALLER on purpose: the printed
   cover/concealment split is ADR-042 clause 1 reporting the vegetation layer owes on a genuine load,
   and silencing it there would hide a real "no 3D model" gap.

### HIS RULING 1 — staggered falls: BUILT

*"why dont we stagger the trees falling for a few seconds after the explosions so its not just a all
at once thing."*

`tree_break_system._fall_delay`: delay rises with `sqrt(distance/radius)` over `FALL_WINDOW_S` 3.0 s
plus a deterministic 0.7 s jitter; undergrowth burns through at `BUSH_HASTE` 0.45 of the timber's
time, so the grass catches before the trunk does and the sweep reads as fire rather than as a queue
draining. **Measured: 710 trunks, peak 138 waiting, spread 3.55 s.**

- **Determinism:** the jitter is `hash()` of the trunk's 10-cm-quantised position, **not `randf()`**,
  so it draws nothing from the operation's RNG stream and replays identically (ADR-010).
- **No half state:** a scheduled trunk is STANDING in every system — `_cells` (so `query_ahead` still
  fuzes rockets on it), the layer's stored scatter (so it draws), the trunk-collider ring (so rounds
  stop on it). `_consume` and `_spawn_broken` remain one atomic pair; they simply happen later. The
  only thing written early is a `doomed` flag that nothing but the blast selector reads.
- **TRADEOFF, NAMED NOT ABSORBED (Law 2):** cover, concealment and line of sight now change over a
  ~3.7 s window instead of instantly. A tree that falls two seconds later blocks, hits and reveals two
  seconds later. This touches the stealth economy (Pillar 3, ADR-005) and **the sapper breach chain: a
  breach lane through felled timber now opens over seconds rather than at the blast.** Surfaced for
  him; not decided by an agent.

### HIS RULING 2 — silent distant falls: BUILT

*"can we just silently have trees fall if the players far away... but anything within a 350 sightline
or less does actually fall over."*

`SILENT_FALL_M` 350 m (the canopy draw radius) with a **deterministic per-trunk feather** over the
next 70 m, so the band is not a line he can walk across and watch a rank snap. Past it a trunk skips
its three MeshInstance3Ds, its Jolt snag body and its Tween — **and nothing else.**

**Proven identical, not asserted:** the probe's EQUIVALENCE phase runs the same trunk with the same
blast down both paths into a recording stand-in for the VegetationManager and compares every settled
part's name, resting position, resting angle and collider size. It refuses to report agreement if
`BrokenTree` has no `silent` property (a control that cannot fail is not a control) or if either path
settled nothing. **Result: IDENTICAL.** The silent path also waits the same `FELL_TIME`, so the world
changes at the same instant either way — not two seconds early for being unwatched.

**Distance, NOT line of sight, and deliberately.** True occlusion means a tree behind a ridge is
"unseen", skips its fall, and then **snaps** into its fallen state the moment he crests the ridge — a
state change caused by the camera moving rather than by the world changing. Plain distance cannot do
that.

### A REAL BUG THE EQUIVALENCE PROBE FOUND

The two paths disagreed by **1.601 m** on `banana_a_crown`. **The silent path was right.**
`BrokenTree._probe_ground` casts down from a point `away * cut_w * 0.5` from the trunk base — on a
wide stump that is still **inside the snag's own cylinder**, so on the animated path the felled log
settled *on top of the stump it had just broken off*. Fixed by excluding the tree's own snag RID from
the probe ray. **This had been shipping in every animated tree fall.**

### THE CENSUS — what runs at full cost regardless of player distance

14 s window, real strike, 24 spawned men + garrison, 710 trunks felled. StallLedger window totals:

| system | total ms | worst call | calls | distance-scaled today? |
|---|---:|---:|---:|---|
| `ai.execute` | **309.3** | 0.2 | 12,168 | **NO** |
| `ai.think` | **116.5** | 0.2 | 2,432 | **NO** |
| `terrain.veg_generate` | 82.5 | 28.4 | 4 | **NO** (now spread, not cut) |
| `veg.tree_cover_mmi` | 75.0 | 18.2 | 5 | **NO** |
| `veg.build_scatter` | 35.6 | 16.6 | 5 | **NO** |
| `veg.trunk_ring` | 35.5 | 0.7 | 60 | **yes** — player-centred ring |
| `mmi.register` | 30.7 | 6.4 | 6 | **NO** |
| `veg.scatter_miss` | 27.6 | 16.0 | 2 | **NO** |
| `treebreak.spawn` | 16.6 | 16.6 | 1 | **yes now** — silent past 350 m |
| `clutter.flush` | 16.3 | 16.3 | 1 | unknown |
| `nap.fx` (9 canisters) | **2.7** | 1.2 | 9 | NO |
| `nap.fire` (9 FireHazards) | **2.4** | 0.3 | 9 | NO |
| `nap.blast` (9 blasts) | **2.2** | 0.3 | 9 | NO |
| `nap.ignite` | 0.3 | 0.0 | 9 | NO |

**REFUTED, with the number:** the fire VFX, the explosion FX and the blast damage together cost
**7.6 ms for the whole nine-canister strip.** They were a listed suspect and they are not the problem.

**THE PRICED QUESTION FOR THE COUNCIL — deliberately not built.** `ai.execute` + `ai.think` is
**425.8 ms of main-thread script over 14 s (~30 ms/s) across 14,600 calls, with 10 men fighting**, and
**not one of those calls is distance-gated**. That is the price of simulating distant engagements man
by man, and it is the largest single line in the census. Abstract resolution of far engagements would
be the biggest win available AND a Pillar-touching change to the world-sim premise, so it goes to the
war room with this number attached — not to an agent.

### STILL UNCUT — ranked, measured, and NOT half-built

1. **`terrain.veg_generate` at 62.8 ms for a SINGLE chunk** on the far strike (`veg.build_scatter`
   33.3 ms + `veg.scatter_miss` 33.3 ms inside it). It is spread across frames now but **not made
   cheaper and not distance-gated.** It lives in `terrain/vegetation/vegetation_manager.gd`, held by
   the vegetation agent — **HANDED OFF, not touched.**
2. **`ai.execute` / `ai.think`** — above; council.
3. **Ambient AA tracers** — did not fire in the measured window. **UNMEASURED.** A decreed distant-war
   visual will not be weighed against his new "random battle sounds" ruling on no data.
4. **`clutter.flush` 16.3 ms x1** — distance behaviour unattributed.

### NIGHT EVENTS — what already exists (asked, answered, not built)

**`scripts/ai/ambient_war.gd` is already the framework** the Arc Light / lightning / distant-napalm
asks need. It rolls 1-3 events per `SimClock.hour_advanced`, places them **400-800 m** from the player
(the 400 m floor is a playtest ruling from 07-29 — *a gunship visibly strafing nothing* at 200 m),
plays positional audio, and spawns a **fake emissive fireball with no real light** — already
ADR-026-compliant and already the right shape for night. `KINDS` today is
`artillery, mortar, tracers, burning, gunship_attack`. **Arc Light, lightning and a distant napalm
bloom are new KINDS on a wired system, not new architecture.**

**But it had no success log line.** Its only `print` was the "held silent" branch, so a log with no
`[AmbientWar]` in it could not be told apart from "this has never fired once" — and **his 2026-09-09
session log is exactly that log.** A `SOUNDING` line now prints on every event that actually fires.
**Whether AmbientWar has ever fired in a real session is still UNKNOWN; the next session can answer
it.** Sound-lags-light, the walking Arc Light line, weather-vs-ordnance colour separation (a Fairness
Law problem, not an art one) and the night stealth-economy question are all recorded and unbuilt: the
stutter came first.

### Gates, all green with everything above in
`test_ship_parity` · `test_flat_damage` · `test_tree_cover_lod` · `test_grid_queries` ·
`test_render_scale` · `test_fossils` · `test_trunk_ring` · `test_veg_density` ·
`test_tree_cover_wired` · `test_terrain_desync` · `probe_chunk_patch` · `probe_terrain_collision` ·
`probe_bullet_damage` · **`probe_napalm_stall` (new)** · headless boot **0 SCRIPT ERROR** ·
`demo_game.tscn` headless boot **0 SCRIPT ERROR**.

**PROVEN TO FAIL WHEN REVERTED.** With the pre-session `tree_break_system.gd` restored,
`probe_napalm_stall` exits **1**: *"trunks were waiting to fall in only 0 sample(s) (need >= 8)"* and
*"the fall spread over 0.00s (need >= 1.0s)"*, and the `[TreeCover]` flood returns at 439 lines
against 5.

**`probe_crater_veg` FAILS, and it is NOT this wave.** *"pruning the cache == regenerating the chunk
with the hole — 1805 positional/species mismatch(es)."* **Controlled:** re-run with this wave's
`terrain_manager.gd` reverted to HEAD, the failure is **byte-identical** (9472 vs 9472, 1805). It
belongs to the vegetation agent's in-flight feathered-hole + paddy-row work (`_prune_scatter_cache`
now routes through `_hole_removes`, `_file_veg_hole` adds `FEATHER_WOBBLE_M`, while `_build_scatter`
rolls its own feather). **HANDED OFF.**

**`probe_terrain_collision`'s "the chunk was rebuilt by the shell" assertion was CORRECTED, not
silenced.** It asserted `chunk2 != chunk` — that the shell had *thrown the chunk node away*. That
demanded the expensive path, and arming every chunk makes it false by design. It now asserts the
ground actually moved: **PASS, ground 172.842 -> 164.842 m, "chunk node patched in place."**

---

# 2026-09-09 (night) — RICE IN THE PADDIES, AND THE FIREBASE COLLAR

Two of his rulings, both measured in COUNTS. No frame or GPU figure is offered: he ruled the quiet-
terrain bench unrepresentative ("cuz its just terrain with no action"), and he was at the machine
playing throughout, so every number below is an instance / triangle / draw-call census from
`tools/probe_paddy_census.gd` (new) and the corrected `tools/probe_ground_cover_census.gd`.

## The instrument correction that comes first: THIS LEDGER'S TRIANGLE COUNTS WERE ~2.3x LOW

`tools/probe_ground_cover_census.gd` counted triangles as `ARRAY_VERTEX.size() / 3`. Every mesh here
is INDEXED, so that is not a triangle count. `tools/probe_far_ring_meshes.gd` has always read the
INDEX buffer and has always disagreed — it reads `rice_a` at 84 tris where the census read 37, and
nobody reconciled the two.

**Corrected, same world (seed 47225), rice excluded so it is a like-for-like re-read of the
2026-09-09 (day) row:** ground cover **1,589,584 tris**, canopy **18,461,506** — against the
674,357 / 8,114,169 published that morning. The RATIO barely moved (7.7% -> 8.0%), because the bug
scaled everything alike, so the conclusion drawn from it stands. The absolute numbers do not.
Probe fixed; it reads indices now and says why in a comment.

## HIS RULING — "yes add grass to the rice paddies to make it look realistic"

### What was actually wrong, and it was TWO things, not one

1. `vegetation_manager.gd` set `TYPE_PROPS[RICE_PADDY] = [0.00, 0, 0]`, so the scatter planted
   nothing in a paddy. That was the finding already on the record.
2. **`paddy_stamper.gd` DID scatter rice, and it had never planted one clump.**
   `_scatter_rice_props` did `scene.instantiate() as MeshInstance3D` on `rice_a.glb` / `rice_b.glb`,
   whose root is a **Node3D with the mesh as a child** — the cast returns null, and every prop hit
   the `continue` in silence. Verified twice headless: `PaddyStamper: 16 paddy polygons, 10 village
   anchors, 0 rice MeshInstance3D nodes` (1280 m AO), and the same at 512 m.
   **The dead path is deleted, not repaired** (ADR-023): repairing it would have put a second,
   unbatched, un-ringed rice population on top of the new one, every plant at the paddy CENTROID
   height instead of its own ground, one draw call each.

### What a paddy is actually made of — measured before anything was planted

| | patrol AO (seed 47225, 1280 m) | demo slice (seed 29072026, 512 m) |
|---|---:|---:|
| RICE_PADDY bundles | 1,481 (5.8%) | 149 (3.6%) |
| paddy area | 94,784 m2 | 9,536 m2 |
| of those, with standing water | **97 (6.5%)** | **9 (6.0%)** |
| mean water depth where wet | 0.50 m | 0.50 m |
| mean relief across an 8 m bundle | 0.40 m | 0.50 m |

**A paddy in this world is mostly DRY.** The zone is a low-relief classification
(`TerrainZoning.classify`, lowland ceiling 159.2 m at this seed); the water is a separate hydrology
solve that fills 2-4% of the map. So "rows standing in water" is true of ~6% of paddy ground and the
rest is worked mud. The planting had to hold up in both.

### What was built

`VegetationManager._plant_paddy_rows`. A paddy is a **planted field, not a scatter**:

- **Rows anchored to the FIELD, not to the bundle.** A 48 m field tile picks one of 8 row directions
  and ONE crop (`rice_a` or `rice_b`) from a position hash, so rows run unbroken across every 8 m
  bundle and 256 m chunk seam, and neighbouring fields lie at different angles the way worked land
  does. Clumps sit at **1.25 m along the row** (they are 1.2-1.4 m wide, so a row reads as one
  continuous green line) and **2.6 m between rows** (an open lane of mud or water you can see down).
  Jitter is +/-0.16 m along and +/-0.10 m across — enough to look hand-planted, small enough that
  the rows survive it.
- **It draws NOTHING from the chunk's RNG.** Jitter, yaw and scale come from an integer position
  hash, so planting a paddy cannot move one tree anywhere else. **Measured, not asserted:** the
  patrol AO held 49,695 plants before this change and holds **79,272 = 49,695 + 29,577 rice** after.
  Every pre-existing plant is exactly where it was.
- **It respects the real water geometry.** The lattice reads `terrain_manager.hydrology`
  (`water_type_full` / `water_surface_full`) — the same solve `WaterSystem` builds its combined
  surface mesh from — rather than `WaterSystem`, which does not exist yet when the first chunks
  scatter. A flooded cell seats the clump 0.18 m UNDER the water surface so it stands IN the water;
  a cell more than 0.85 m under is a channel or a pond, not field, and nothing is planted there,
  which is what cuts the open water lanes through a paddy.
- **Seating verified, not eyeballed:** 2,964 demo clumps checked against the same heightmap the
  scatter used — **0.00 m worst below ground, 0.42 m worst above** (and that 0.42 is exactly the
  flooded lift), **238 clumps standing in water**.

### What it costs

| | demo slice (512 m) | patrol AO (1280 m) |
|---|---:|---:|
| rice clumps planted | **2,964** | **29,577** |
| triangles, FULL detail | 248,976 | 2,484,468 |
| MultiMesh nodes (= draw calls) | **16** | **103** |
| share of all plants | 25% | 37% |

**The one honest worry, and it is an ART item.** `rice_a` and `rice_b` are 84 tris each and **neither
generates an LOD ladder** — the importer declines on their topology, and their `.import` files are
byte-identical to twins that DO generate one, so nothing in the pipeline can fix it. Until now that
cost exactly zero because no rice was ever placed. It now costs 2.48 M full-detail triangles of stock
in the patrol AO (11% of the world's plant triangles) that never simplify with distance. Bounded by
the ground-cover ring: **rice draws to 150 m only** (`SMALL_PREFIXES` already carried `rice_`), so
this is stock, not frame. **The fix is a lower-poly source mesh and it belongs to art.** The density
dial, if he wants it thinner, is `PADDY_HILL_PITCH` / `PADDY_ROW_PITCH`.

## HIS RULING — "just have the cut away be 20 m around the firebase and stagger it at that too"

### What governed it before, said exactly

`site_planner.gd` `FSB_CLEAR_DISCS = [[Vector3.ZERO, 140.0]]` — **one hard 140 m circle**, fed to
`clear_and_flatten`, which does three things at that radius: a ClearingSystem CLEARED zone, the
vegetation `clear_area`, and a grid `update_region`. It is NOT the 230 m figure (that is
`STRUCTURE_VISIBILITY_END`, a per-node draw fade for placed structures) and it is not the terrain
seat (`FSB_FLATTEN_RADIUS` 215 m, a plateau lerp that runs afterwards and has the last word on the
ground).

### Where the wire actually is — read off the model's own manifest

`fsb_main_v3_mound.json` through the same math `SitePlanner.fsb_mound_height` uses (r0 66 m,
ridge_stretch 1.28, three edge harmonics, berm_w 3.2):

**the berm crest stands at a WORLD radius of 51.8 m on its narrowest bearing and 99.7 m on its
widest, mean 78.5 m.** The wire is a wobbly ellipse, not a circle. "Wire + 20 m" is therefore a
region whose boundary runs 71.8 -> 119.7 m (mean 98.5), enclosing 31,108 m2.

**The old 140 m circle cleared 61,575 m2 — 30,416 m2 of bald ground beyond his 20 m line.**

### What changed

- `FSB_CLEAR_DISCS` **140.0 -> 120.0**, i.e. exactly +20 m past the widest part of the wire, and more
  than that on narrower bearings. Excess bald ground beyond the 20 m line: **30,416 -> 13,904 m2, a
  54% cut.**
- `FSB_CLEAR_FEATHER = 26.0` — the "stagger it". Past 120 m the cut does not stop, it **thins**:
  `VegetationManager._hole_removes` gives a plant a survival chance ramping 0 -> 1 across the band
  from a 0.25 m position hash (deterministic, identical on every rebuild), and the band's own edge
  wanders +/-6 m with a low-frequency angular term. **No bearing shows a drawn radius.**
- `MissionGenerator.apply_veg_boosts` now takes the firebase centre and adds an apron ring (radius
  175 m, chance floor 0.78, +1 count) so the base sits IN growth rather than beside it. It rides the
  existing mechanism, so `gameplay_grid.boost_vegetation` mirrors it into the AI grid — and that call
  already clamps itself against the ClearingSystem density, so the grid cannot claim concealment on
  the bald compound.

**A single disc still cannot be 20 m outside a wobbly ellipse at every bearing.** Making it follow
the wire needs a SHAPED clear, and the same offsets are read by `plan_firebase_main_center`'s site
scoring, so shaping it moves the firebase for every patrol seed. Named for him rather than smuggled
in. Ruled: **the clearing zone and the vegetation hard cut share the same 120 m line**, so nothing
the AI grid calls cleared has cover standing in it. In the 120-146 m feather band the grid still
reads full jungle while the player sees thinning scrub — the mismatch errs toward the player having
LESS cover than the AI credits him with, never more.

### The perimeter cost, A/B in one instrument, one seed, one world

`tools/probe_paddy_census.tscn` with and without `--legacy-collar` (140 m hard, no apron), demo slice,
seed 29072026, firebase at map centre:

| band from the firebase | legacy plants | shipped plants | delta |
|---|---:|---:|---:|
| 0-120 m | 0 | 0 | 0 |
| 120-130 | 0 | **91** | +91 |
| 130-140 | 0 | **305** | +305 |
| 140-150 | 453 | 567 | +114 |
| 150-160 | 552 | 729 | +177 |
| 160-175 | 855 | 1,059 | +204 |
| 175-200 | 1,485 | 1,536 | +51 |
| **120-200 total** | **3,345** | **4,287** | **+942 (+28%)** |

| | legacy | shipped | delta |
|---|---:|---:|---:|
| triangles in the 120-200 m collar, FULL detail | 1,027,368 | 1,391,342 | **+363,974 (+35%)** |
| MultiMesh nodes in the collar (= draw calls) | 372 | 457 | **+85** |
| whole-slice plants after the collar pass | 9,576 | 10,513 | +937 |
| whole-slice MultiMesh nodes | 998 | 1,082 | **+84** |

Zone mix in the newly-grown 120-140 m band: MEDIUM_JUNGLE 191, HEAVY_JUNGLE 146, LIGHT 22,
RICE_PADDY 33, GRASSLAND 4 — so it is **real jungle with trees in it**, not just grass, which is what
"some trees too" needs. Triangles are full detail; canopy species carry LOD ladders, so the submitted
figure is lower.

## HIS RULING — "bushes keep drawing to 350, dont cut em"

**Closed. Nothing shipped.** `BUSH_RING_M = 0.0` (uncut) and the first step of the F12 cycle is uncut,
so a stray press cannot leave a cut in. The dial exists only so he can look again on his own eyes.

The price of the cut he declined, from the AO centre, patrol world (bushes are 256 tris each, and
`bush_a/b/c` total **10,938** instances — that figure reproduces exactly on the corrected census):

| bush ring | additional instances hidden | additional tris (full detail) | additional MultiMesh nodes |
|---|---:|---:|---:|
| 350 m (SHIPPED) | — | — | — |
| 250 m | 1,301 | 333,056 | >= 133 |
| 200 m | 1,846 | 472,576 | >= 191 |
| 150 m | 2,469 | 632,064 | >= 233 |

Node counts are a FLOOR: a 64 m bucket is hidden only when its whole transformed AABB clears the ring
(godot#79471), so the allowance is the bucket half-diagonal. Triangles are full detail and bushes DO
carry LOD ladders, so the submitted saving is smaller than the stock saving.

## F9 WAS ALREADY TAKEN, AND THE COMMENT SAYING IT WAS NOT WAS WRONG WHEN IT WAS WRITTEN

`tree_cover_layer.gd` carried the line *"F9 and F10 are unbound anywhere else in the project"*.
**F9 is `quickload`** — `project.godot` binds physical_keycode 4194340 to it and `save_manager.gd:74`
acts on it. Cycling the ground-cover ring mid-walk could reload his quicksave. All three dial keys
now call `set_input_as_handled()`, and because the world scene takes `_unhandled_input` before an
autoload does, SaveManager never sees the press. **Which key keeps F9 permanently is his call, not a
silent rebind of his save keys.**

F12 is the new bush key. The input map binds F1-F5 and F9 and nothing else in the F range; F11 is
interior props (`interior_prop_dial.gd:14`). F12 was free and is verified free.

## THE GUARD THAT CAUGHT ME

A bundle whose centre sits deep inside a clearing was skipped outright, to stop the thickened apron
generating a compound's worth of plants and throwing them away. `tools/probe_crater_veg.gd` went red:
**"pruned 9472 vs regenerated 9472 plants, 1,805 positional/species mismatch(es)."** Same count,
different plants. The random scatter draws its RNG *before* it tests the hole **on purpose** — that is
what makes pruning a cached scatter identical to regenerating it with the hole in place — so skipping
a holed bundle shifted the whole chunk's RNG stream and moved 1,805 unrelated plants. The skip now
applies **only to the paddy lattice**, which draws no RNG at all. Probe green again, 0 mismatches.
The wasted work inside the apron is left in and named rather than traded for a wrong tree.

## HANDED TO ME AND MEASURED, NOT TAKEN: `terrain.veg_generate` 62.8 ms for ONE chunk

A distant napalm strike was measured at **62.8 ms of `terrain.veg_generate` for a single chunk** —
ground he cannot see. That span wraps the whole rebuild and names no cause, so any fix aimed at it
would be a guess. `tools/probe_veg_generate_cost.gd` (new) splits it. Demo slice, seed 29072026,
the heaviest resident chunk (4,570 plants), 12 forced rebuilds, headless — CPU spans are honest
headless because they are script time, not a renderer bucket.

| span | mean ms | worst ms |
|---|---:|---:|
| **veg.tree_cover_mmi** (the whole DRAW half) | **17.74** | 18.66 |
| &nbsp;&nbsp;`mmi.group` — species x 64 m bucket grouping | **8.27** | 8.93 |
| &nbsp;&nbsp;`mmi.register` — `TreeBreakSystem.register_chunk` | **5.67** | 6.04 |
| &nbsp;&nbsp;`mmi.build` — MultiMesh construction | 3.12 | 3.33 |
| &nbsp;&nbsp;`mmi.addchild` | 0.51 | 0.57 |
| &nbsp;&nbsp;`mmi.clear` / `mmi.ring` | 0.00 / 0.01 | — |
| **veg.build_scatter** (the DATA half) | **4.99** | 5.95 |
| &nbsp;&nbsp;`veg.scatter_hit` — re-seating every plant's Y on the current heightmap | **4.98** | 5.93 |

**Read plainly:** the scatter CACHE is working — `build_scatter` is 5.0 ms and essentially all of it
is the cache-hit path re-seating Y, not re-deriving anything. The cost is now in the DRAW half, and
**`mmi.group` alone is the largest single item.** It builds a Dictionary keyed by a three-element
Array per plant, appends a `Transform3D` per plant, then walks the groups a second time to compute
centroids and build a second `Transform3D` per plant. That is two allocations and an Array-key hash
per plant, 4,570 times.

**Not taken tonight, deliberately.** Under his standing law — *outcome identical, presentation
degraded* — only the `mmi.*` half may be deferred or skipped, and the two obvious moves both need a
guard this box cannot give tonight:
- Writing the MultiMesh through a single `buffer` assignment instead of N `set_instance_transform`
  calls (the pattern `VegetationManager._materialize_vegetation` already uses) would cut `mmi.build`,
  but **a wrong buffer layout is invisible headless** — `probe_chunk_patch` compares `chunk_origins`,
  the scatter's own positions, precisely because MultiMesh transform read-back is blind under the
  dummy renderer. It cannot catch a transposed row. It needs a windowed look, and he was at the
  machine.
- Distance-gating the MultiMesh build (build the buckets in range, queue the rest) is the real answer
  to "62.8 ms for ground he cannot see", and it is safe for outcome — trunk candidates and the break
  registry are derived from the scatter and would still run immediately. But it makes
  `probe_chunk_patch`'s node/instance comparison viewpoint-dependent, so that probe has to be taught
  the gate in the same change.

`mmi.register` (5.67 ms) is `TreeBreakSystem.register_chunk` and belongs to whoever owns
`tree_break_system.gd`, not to the vegetation layer.

## ONE NUMBER I COULD NOT ACCOUNT FOR

The demo slice read **8,845** non-rice plants before this change and **8,852** after — seven plants,
0.08%. The patrol AO reproduces EXACTLY (49,695 before, 49,695 after), which is the stronger test and
the one the determinism claim rests on. The seven are recorded, not explained and not rounded away.

## Gates, all green headless with everything above in

`test_ship_parity` - `test_flat_damage` - `test_tree_cover_lod` - `test_grid_queries` -
`test_render_scale` - `test_fossils` - `test_trunk_ring` - `test_tree_cover_wired` -
`test_one_classifier` - `test_veg_density` - `test_zoning_histogram` - `test_spawn_zoning` -
`test_paddy_stamper` (including its own determinism check) - `test_placement_paths` -
`test_nav_path` - `test_settlement_spacing` - `test_world_alive` - `probe_ground_seat` -
`probe_chunk_patch` - `probe_crater_veg` - `probe_terrain_collision` - `probe_bullet_damage` -
main headless boot **0 SCRIPT ERROR** - `demo_game.tscn` headless boot **0 SCRIPT ERROR**.

One transient, named rather than rounded away: `test_grid_queries` exited 1 on its first run and
PASSED on a clean re-run. Another agent was mid-save on `player.gd` at that moment - that run's log
carries its parse error and no other run does.

---

## 2026-09-09 (later) — PHASE 1: THE LIVE HUD WAS STILL RUNNING THE INSTRUMENT THE LOG ALREADY RETIRED

`--print-fps` was corrected on 2026-09-08: it deleted its `game` column because that column summed
`Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS`, and both are **one-second bucket MAXIMA**
(`main.cpp`: `process_max = MAX(process_ticks, process_max)`), not per-frame values. Two maxima need
not come from the same frame, and `TIME_PROCESS`'s span in `main.cpp` also contains
`RenderingServer::sync()` and `RenderingServer::draw()`, so renderer backpressure lands inside it.
The reasoning is written out in `scripts/dev/stall_ledger.gd:1-40` and `scripts/dev/fps_printer.gd`.

**The live bench HUD never got that correction.** `scripts/levels/arena_perf_overlay.gd` was still
computing exactly the retired quantity and printing a verdict off it. As of the previous commit:

    var cpu_ms: float = process_ms + physics_ms
    bound = "GPU-BOUND" if gpu_ms >= cpu_ms + render_cpu_ms else "CPU-BOUND"

and, when the driver timer was silent, deriving a GPU figure as `frame_ms - cpu_ms` and labelling the
frame from that. Four defects, all measured against the source, all fixed:

| # | defect | why it is wrong | fixed |
|---|---|---|---|
| 1 | `cpu_ms = TIME_PROCESS + TIME_PHYSICS_PROCESS` | two 1s bucket maxima, possibly different frames; the idle one contains `RenderingServer::sync/draw` | the sum is **deleted, not renamed**. The monitors print in their own row labelled `1s MAXIMA, not per-frame, never summed` |
| 2 | `CPU-BOUND` / `GPU-BOUND` verdict from that sum | unsupportable — the very claim `fps_printer.gd` had already withdrawn | replaced by the one claim a driver timer supports: `GPU SATURATED (n% of frame)` at >=90% share, else `not GPU-limited (gpu n% of frame)`, else `BOUND-NESS UNPROVEN - driver GPU timer silent`. It never names which CPU-side worker holds a non-GPU-bound frame |
| 3 | `"ai/agents" = TIME_PROCESS - itemised` | a bucket maximum minus a set of per-frame usec spans: two time bases subtracted, and **it was the largest number on the HUD** | deleted. The itemised buckets print with their own sum, against a real per-frame script span |
| 4 | `frame_ms = 1000.0 / Engine.get_frames_per_second()` | that is a **one-second average**, so the "rolling frame-time graph" plotted a flat average and the 25 ms spike catcher could essentially never fire on a single stutter | `frame_ms = delta * 1000.0` — this frame's own wall time. Spike test is now `> SPIKE_MS` **and** `> SPIKE_RATIO x rolling mean` (an absolute 25 ms floor alone marks every frame on a 27 fps bench), and the spike line carries the multiple it was judged by |

### What replaced the fabricated CPU number

The honest per-frame script span already existed and the overlay was not using it. `FrameSentinel`
(front/back `process_priority` bookends) brackets every node's `_process` / `_physics_process`, and
`StallLedger` measures the span in `Time.get_ticks_usec` — the caller's own clock, not a Performance
monitor. It was armed only by `--print-fps`.

- `scripts/dev/frame_sentinel.gd` — new `FrameSentinel.install(host)`. Idempotent **by tree state**
  (group `stall_sentinel`), not by a static flag, so a scene reload that frees the old host can re-arm.
  This matters: a second front sentinel overwrites the first's `t0` and a second back sentinel
  re-closes the same span, which inflates every span reported.
- `scripts/dev/stall_ledger.gd` — added `last_idle_ms()` / `last_phys_ms()` (the **most recent** step,
  not the window's worst, so it is comparable to the per-frame buckets printed beside it) and
  `armed()`, which is false until the sentinels have actually bracketed a frame. The HUD prints
  `INSTRUMENT NOT TICKING - no span measured, quote nothing` rather than a confident `0.00 ms`.
- `scripts/dev/fps_printer.gd` — now calls `FrameSentinel.install(self)` instead of hand-rolling the
  same three lines. One way to arm the instrument.
- The GPU share and the frame figure are both **means over the same 120-frame window**
  (`_gpu_history` added alongside `_history`), so the verdict is not two jittery single samples, and
  the readout states `mean of N` beside `last`.

### The gate: `tests/test_perf_timebase.tscn` (new, in the suite, listed in `$Graduated`)

**12 checks, PASS.** It is a *contract* test, not a number test — a number is a machine's mood.
It fails the build if the HUD text ever again contains `CPU-BOUND` or `GPU-BOUND`, if it prints the
Performance monitors without saying they are 1s bucket maxima, if the `ai/agents` remainder returns,
or if the silent-driver case stops saying `BOUND-NESS UNPROVEN`. It also asserts the sentinels arm,
that `last_idle_ms()`/`last_phys_ms()` are non-zero after five frames, and that a double
`FrameSentinel.install` plus a live `FpsPrinter` still yield **exactly 2** sentinels.

**Why it had to be written at all:** nothing on the headless boot path loads
`arena_perf_overlay.gd`, `frame_sentinel.gd` or `fps_printer.gd` — `FpsPrinter` attaches deep inside
`GameFlow.enter_hub` (`scripts/main/game_flow.gd:751`), which a `--quit-after` boot never reaches. So
`--headless --quit-after 300` **cannot** catch a parse error in any of the three. That blind spot is
now covered by a test that instantiates all three.

### Not measured, and it must not be read as measured

Nothing in this entry is a frame-rate number. It repairs the instrument that would produce one. **No
player-eye baseline has been taken since the render-scale correction landed**, and the
2026-08-07..2026-09-08 window remains void.

One thing the log did state on its own, headless: `[FPS] printer ATTACHED - ... render scale 0.750
(live)`. That is the dummy renderer's viewport, not a windowed one, and it settles nothing about what
a real window does — recorded because it was printed, not because it proves anything.

### TWO INSTRUMENTS THAT COULD NOT SEE THE THING THEY EXISTED TO SEE

Both were found on 2026-09-09 in the Phase 1 sweep, and they are the same disease as the
2026-09-08 probes that read `ProjectSettings` instead of the viewport and hid a render scale that
had been wrong for a month. Recorded separately from the fix table above because each is a finding
in its own right, not a line item.

**1. The bench HUD's frame-time graph and its spike catcher both ran on a one-second average.**
`arena_perf_overlay.gd` computed `frame_ms = 1000.0 / Engine.get_frames_per_second()`.
`get_frames_per_second()` is a smoothed one-second counter, so:
- the "rolling frame-time graph" was a rolling graph of an average, which is close to a flat line;
- `SPIKE_MS = 25.0` was tested against that average, so **a single 300 ms stutter could not move it**
  unless the whole second was already bad;
- the spike catcher — the feature whose entire purpose is to name the event behind a stutter, and
  which had `note_event()` callers wired for flare pops and wave spawns — **could essentially never
  fire on the thing it was built for.**

An instrument that averages away the event it exists to catch reports a healthy world with total
confidence. Nothing was broken; the graph drew, the log filled, and every frame looked fine.
Fixed to per-frame `delta`, with an adaptive spike test (a flat 25 ms floor marks *every* frame on a
27 fps bench, which is the same failure pointed the other way).

**2. `windowed_patrol_perf.gd:48` printed the renderer from `ProjectSettings` — the exact setting the
paragraph above it in this file calls stripped and untrustworthy.** The measurement contract said
"verify the renderer AT RUNTIME (the harness already prints it)" and pointed AT this line. It read
`ProjectSettings.get_setting("rendering/renderer/rendering_method")`. Godot strips that key on save
when it equals the desktop default, so it returns `forward_plus` **whether or not that is what booted**
— it agreed with reality by luck, and a renderer A/B run through it would have printed the same word
in both halves. Now `RenderingServer.get_current_rendering_method()` +
`get_current_rendering_driver_name()`, in that harness and in `--print-fps`.

### Observed red, not caused here: `test_ai_stress_arena`

`FAIL: no VC entered COMBAT` (US wins at 5.7 s, 12-0). **Not this change**, and proven rather than
asserted: `tests/test_ai_stress_arena.gd:48-49` sets `spawn_hud = false` and `bench_dressing = false`,
so `ArenaPerfOverlay` is never constructed — the string appears **zero** times in the run's log, as do
`StallSentinel` and any `StallLedger` arming. It is an AI/arena failure and it is on neither
`$KnownRed` nor `$Graduated` in `run_all_tests.ps1`, so it has been reading as one FAIL among many
with nothing watching it. Named for whoever owns the arena AI.

---

## 2026-09-09 (later) — `--stress=<target>`: REACHING THE MEAT IN TWO MINUTES

**HIS RULING, verbatim:** *"can we jsut have the assault start within 2 minutes of me spawning."*
Then, on intent: *"to get into the meat of the problems."*

**MOST OF THIS WAS ALREADY BUILT, and it is worth saying why that keeps happening.** `--stress`
already existed in `demo_game.gd`: probe at 20 s, the real 45-man siege at 45 s, and — the part that
matters — it already jumped the clock to the hour the shipping arc reaches at `SIEGE_AT_S`, so the
compressed run gets a NIGHT assault rather than a daylight one. The arc also already fires a real
ambient napalm at `NAPALM_EARLY_S = 35.0` on every demo boot. **His two-minute ask was substantially
shipped before he made it.** What was missing was selection: you got everything at once, so no single
event could be measured with nothing else in the frame.

### What was added

`--stress=<target>`, resolved by `DemoGame.resolve_stress()` — deliberately **static and pure**, so the
arc's timings can be gated without booting a 512 m world.

| target | what it does | clock |
|---|---|---|
| `assault` (and bare `--stress`) | unchanged: probe 20 s, real 45-man siege 45 s | seated to the arc's assault hour — NIGHT |
| `reinforce` | **alias of `assault`.** The 11 -> 45 escalation IS the demo's reinforcement arrival; there is no second path to one, and inventing a fourth event would have been a different measurement wearing the right name | NIGHT |
| `napalm` | siege never opens; a real `authored_strike` NAPALM lands on the **player's own bearing** at 210 m, first at T+60 s then every 40 s | DAY — the arc's own ambient napalm is a day beat |
| `trees` | the same with `Ordnance.BOMB`: HE, no fire, so `TreeBreakSystem` dominates instead of the burn | DAY |

Every target goes through `FieldDirector.authored_strike` and `SiegeDirector` exactly as the shipping
beats do — same airframe, same 88 m radius, same crater, same `apply_blast`, 45 real men. A cheaper
event is not a faster route to the same measurement.

The strike is aimed off the **player**, not off `fsb_center`, so he is standing where a player stands
when it fires. `authored_strike` still owns his safety and refuses an axis that runs on him.

### THE CAVEAT — every compressed route arrives with a COLD WORLD

Fewer chunks walked and their caches unwarmed, less accumulated destruction, fewer bodies on the
ground, fewer nav rebakes behind it. Therefore:

- **VALID** as a repeatable regression row, and as an honest look at the EVENT ITSELF.
- **NOT** a substitute for the full 24-minute arc, and **it may flatter the numbers.**

**One full-length run is owed**, to check the short ones against — on his say-so, not on an agent's
initiative.

### Verified headless, and what it is NOT

Both targets booted with `--print-fps` and **0 SCRIPT ERROR**. `--stress=napalm` fired two real strikes
(`[DEMO] air beat: NAPALM at 254,498 (210m out on bearing 90 deg)`), and the named spans came through:
`terrain.crater`, `terrain.chunk_rebuild`, `nap.fire`. Bare `--stress` seated the clock at 20:10 NIGHT
and opened the probe at 20 s.

**No millisecond figure from those runs is quotable.** They were headless — GPU reads 0.00 and draw
calls read 0 — and the 154-test suite was running on the same machine at the time. The runs prove the
harness reaches the event and the instrument names it. They measure nothing.

One bug the run exposed and it is fixed: the single-event targets park probe/siege at `INF`, and
`int(INF)` is `INT_MIN`, so the boot line printed `probe@-9223372036854775808s` — a boot line that read
"the assault already happened". The value was right; only the rendering lied. It now prints `never`.

**Guarded by `tests/test_demo_arc.tscn` — 26 checks, PASS, in the suite and in `$Graduated`.** It
asserts the shipping arc is untouched with the flag absent, and pins the constants THE SESSION ENTRY
GATE is written against: probe 1395, siege 1440, 45 men, 06:30 start, 38x/20x, seed 29072026.

---

## 2026-09-09 — THE BEHAVIOURAL LOD (built, **NOT MEASURED**)

**The finding it answers.** The 45-man assault runs at **~2.7 fps** and `ai.execute` is the dominant
exclusive span in every measured window: **2,650-3,010 ms per 5 s over ~4,408 calls = 0.60-0.68 ms per
man per physics tick.** GPU is under a third of the frame. Forty-five men roughly double the physics
script step (18-21 ms with no siege, 38-43 ms under the assault).

**What was in that 0.6 ms, by reading (not by profiling — no run was possible):**

| per man, per tick, inside `ai.execute` | why it is expensive |
|---|---|
| `_update_sprite()` | ~100 lines: a `get_node_or_null("Burning")` NodePath lookup, the intent state map, a **string concatenation** in `SpriteStateMap.clip_for`, `set_facing` (a `global_rotation` decompose+recompose), `set_locomotion_speed` |
| `_update_aim()` | a `look_at()` basis rebuild every frame |
| `_move_toward()` -> `NavRouter.step()` | `NavigationAgent3D.get_next_path_position()` every tick, and a `map_get_path` on every restake |
| `_fire_at_target()` | **the largest single term.** Per round: a physics raycast, a bullet, `GunFX.muzzle_flash` (**four new nodes and two new QuadMesh resources, built and freed per shot**), `NoiseBus.emit_noise` (a signal to ~60 connected listeners, each doing a distance test) and `CombatManager.suppress_along_shot` (a near-miss sweep over every ally). At 45 men on a firefight cadence this dominates. |

**The design (Summoner's ruling, verbatim in `CALEB_TODO_7_22_updated.md` §0000-AA).** Promote at 80 m,
demote past 105 m after a 3 s dwell, promote also on player involvement (capped at 160 m), sappers
exempt. `scripts/ai/ai_lod.gd` + `EnemyBase._execute_far`.

**It also revives a dead optimisation.** ADR-026 Part B's hot set has `HOT_CAP = 50`; the assault
fields **45**. Every man in that fight was hot, and the tiering it was built for **had never engaged
once**. A far man no longer requests a slot.

### WHAT IS NOT KNOWN, and must not be written down as if it were

- **No before/after frame time exists.** Nothing was run: the machine was in use.
- **No promoted-man count exists.** The instrument is built (`[AILOD]` row, sampled EVERY FRAME by
  `FpsPrinter`, reporting window peak and mean beside the `[FPS]` row) but it has produced no number.
  A predicted count is not a count. **Read `window peak` off his log before believing any of this.**
- The A/B is one build and one flag: `--ai-lod-off` restores every man to the full brain.
  `perf_stress_lod_off.bat` is the BEFORE, `perf_stress.bat` is the AFTER.
- Correctness: `tools/probe_ai_lod.tscn` (`probe_ai_lod.bat`), 12 assertions — the band, the dwell,
  the hysteresis walked both ways, the sapper exemption, sticky promotion and its ceiling, that a far
  man still advances and still holds a front, the census, and the off switch. **Also never run.**

### A finding this pass surfaced and did NOT act on

`GunFX.muzzle_flash` allocates a **4**-node subtree plus two `QuadMesh` resources **per round fired**, capped
only by 96 concurrent flashes. *(This line said "3-node" until 2026-09-09; the table above it said four
and the table was right — root + core + spikes + the `_expire` Timer. Corrected on contact.)* At 45 men firing that is hundreds of node constructions per second inside
the physics step. The far tier's burst cadence reduces the round count, which reduces this as a side
effect — but the allocation itself is untouched and unmeasured. **A pooled flash is the obvious next
lever and it needs a measurement first, not a rewrite.**

---

## 2026-09-09 — THE FLASH POOL (built, allocation measured **statically only, NOT RUN**)

**Answers the finding immediately above.** `GunFX.muzzle_flash` now hands out a pooled entry instead
of minting one. `scripts/combat/gun_fx.gd:833` (the function), `:885-975` (the pool).

### The allocation, before and after — read off the code, not off a run

| per round fired | before | after (warm) |
|---|---|---|
| `Node3D` flash root | 1 | 0 |
| `MeshInstance3D` (core, spikes) | 2 | 0 |
| `Timer` (expiry) | 1 | 0 |
| **nodes constructed** | **4** | **0** |
| `QuadMesh` resources | 2 | 0 |
| `Callable` for the expiry lambda | 1 | 0 |
| `StandardMaterial3D` | 0 (already cached by `_muzzle_mat`) | 0 |
| **objects constructed** | **7** | **0** |

Construction is now bounded by `MAX_FLASHES` **per mission**, not per round: at most 96 entries =
384 nodes + 192 meshes, built lazily on demand and freed by `reset_session()` at mission teardown.
The concurrent ceiling is **unchanged at 96** (`MAX_FLASHES`), and so is the early-return that
enforces it.

At the assault's 45 men on a firefight cadence, that is the difference between hundreds of object
constructions a second inside the physics step and none.

### WHAT IS NOT KNOWN

- **No frame time. Nothing was run — the machine was in use.** This entry claims an allocation
  count, which is what static reading can prove, and nothing about fps. `ai.execute` may still be
  dominated by `NoiseBus.emit_noise` (~60 listeners × a distance test, per round) and
  `CombatManager.suppress_along_shot`; those are untouched.
- The A/B is `tools/probe_muzzle_flash_pool.tscn` (`probe_muzzle_flash_pool.bat`). It fires a wave, lets it expire, fires the same
  wave again, and counts objects that never existed before. **It fails against the pre-pool code**
  (wave 2 there reads 4 nodes + 2 meshes per round instead of 0), and it carries a negative control
  that builds a pre-pool round by hand and asserts the census sees it.

### THE LOOK IS UNCHANGED, and three details carry that claim

1. **Size jitter stays in `QuadMesh.size`, never node scale.** `_muzzle_mat()` does not set
   `billboard_keep_scale` (unlike `_sheet_mat` and `_decal_mat`, which say why in their own
   comments), so `BILLBOARD_ENABLED` **discards node scale** — jitter moved onto scale would have
   silently flattened every flash to one size. Probe section D asserts node scale reads exactly 1.
2. **Same RNG call order** — jitter, core pick, core roll, spike roll — so ADR-010 seeds are
   byte-for-byte untouched.
3. **Same subtree and child order** (core, spikes, Timer), which is the shape
   `tests/test_fake_lights.gd` walks; same materials, same lifetime, same fairness floor.

### THE BORE DEFECT WAS NOT ENTRENCHED — and the standing claim about it is REFUTED

The brief for this change said `muzzle_flash()` "takes a position and never a direction; all 8 call
sites pass only a point." **That has not been true since 2026-09-08.** The signature is
`muzzle_flash(parent, pos, viewmodel, bore)` (`scripts/combat/gun_fx.gd:833`) and **all 7 live call
sites pass a real aim vector**: `ally_base.gd:2253`, `enemy_base.gd:2874` and `:2911`,
`game_world.gd:226`, `weapon_holder.gd:713`, `cas_airplane.gd:364`, `seat_system.gd:339`. The
8th caller is `tests/test_fake_lights.gd:63`, which passes none on purpose. A non-zero bore already
selects a `BILLBOARD_DISABLED` spike laid down the barrel (`_bore_basis`, `:952` pre-patch).
Anyone still carrying "the flash has no direction" as an open defect should drop it.

Pooling's own risk here is the opposite one: an entry last fired **with** a bore must not keep that
aimed basis or aimed material when the next caller passes none. Probe section E fires the same
entry both ways and asserts the fallback. That is the check that stops a pool from quietly
entrenching one call shape.

### NOT DONE IN THIS CHANGE, and why — `DamageSystem` growth

Two uncapped things in `terrain/systems/damage_system.gd`, both real, both **deliberately left**:

- **`damage_zones` (`:214`)** — one `Dictionary` appended per blast, cleared only by
  `clear_all_damage()`. It has **no reader anywhere in the game**: repo-wide the only consumers are
  `tests/test_smoke_all.gd:152` and `tools/probe_fire_parity.gd:86`, which diff its size to prove a
  blast registered. A write-only list.
- **scar decals (`:330`)** — one real `Decal` per blast, uncapped, while `GunFX`'s own scorch decals
  cap at `MAX_SCORCH = 12` and bullet holes FIFO at `MAX_DECALS = 48`. That inconsistency is the
  find.

**Judgment: a LATER change, the two of them together, not this one.** Three reasons. They are a
different frequency class — per *blast* (the brief called it "per impact"; it is not), one or two a
second at worst, against 45 rounds a second, so they are not a term in `ai.execute` and bundling
them would blur what this probe measures. Capping the scars is a **visible world change** — craters
that stop wearing a burn mark — on a system governed by ADR-031, so it is his call, not mine.
And `damage_zones` cannot be capped by reflex either: a ring buffer is invisible to the game but
both probes above diff its size, so the cap has to sit well above their deltas or it breaks the
instruments that watch destruction.

**HIS CALL:** cap the blast scars (a FIFO like `MAX_SCORCH`, oldest crater loses its mark), or let
them accumulate for a 30-minute demo and eat the growth? The demo is one day on one 512 m AO, so
"leave it" may simply be right.

### 2026-09-10 — THE FIX WAVE: the siege floor was a physics catch-up spiral, and the cap quadruples it

**His word: *"ok lets loop and fix all of these"*** (the audit is `production/PERF_AUDIT_2026-09-10.md`).
Everything below is HEADLESS — CPU only, gpu ms reads 0 — and every A/B is PAIRED (back to back on the
same box, control alongside) because the box's load moved by 2× between morning and evening:
the untouched baseline read **min window 19.0 fps** at 22:12 and **10.3 mean / 3.7 min** two hours
later. **On this machine a lone number is not a measurement; only a pair is.**

**THE FINDING THAT CHANGES THE STORY.** In every evening run the siege windows lock at **exactly
3.7–3.8 fps with 285–299 ms frames**. That is not a slow frame, it is `max_physics_steps_per_frame`
(engine default **8**) × a 30 Hz tick that has gone over 33 ms: the engine runs eight catch-up ticks
of 45-man AI inside one frame to make up the clock, which makes THAT frame slower still —
`marching_cell.gd` already names the death spiral. It reproduces headless, so it is not the GPU;
windowed on the Intel UHD the GPU stall is what first pushes the tick over budget.

**PAIRED A/B, `--phys-steps=2` vs default 8, same code, same seed, back to back:**

| | siege floor | mean | mean worst frame | tick (phys_max) |
|---|---|---|---|---|
| cap 8 (default) | **3.7 fps** | 14.8 | 242 ms | 65.9 ms |
| cap 2 | **14.9 fps** | 27.1 | **99 ms** | 61.3 ms |

The tick itself did not get cheaper — it is still ~60 ms at the peak, and that is the real remaining
work — but it stopped being multiplied by eight. **Shipped as `physics/common/max_physics_steps_per_frame=2`
in `project.godot`.** The trade, stated: when a tick runs over budget the SIM runs slower than the
wall clock instead of the frame rate collapsing (the day/night `SimClock` advances on `_process`, so
the clock itself stays honest). On a machine whose tick fits in 33 ms the cap never engages.
`perf_stress_phys3.bat` runs the cap at 3 for his eye; `--phys-steps=N` on any launch.

**THE REST OF THE WAVE, each paired where it could be:**

- **Animation throttle** (`model_actor.gd`): past 80 m or off-screen beyond 30 m the
  `AnimationPlayer` goes to MANUAL callback mode and is advanced at 10 Hz. `[ANIM] 42 of 61
  animated actors throttled` mid-siege. Paired A/B (`--anim-lod-off`): **18.9 vs 10.4 mean fps**,
  same floor. ON is the shipped default.
- **Soldier pre-warm** (`enemy_base.gd` `dormant`, `field_director.prewarm_enemy` /
  `activate_tracked_enemy`, `marching_cell._reserve`): a marching cell builds its men during the
  march — invisible, `PROCESS_MODE_DISABLED` (which removes every collider from Jolt, the docs'
  `DISABLE_MODE_REMOVE` default), off every roster — and the pop ring pays `activate()`.
  `spawn.man 119.5 ms` per man at the wire → `spawn.activate 1.9 ms worst`. ADR-035's pop-ring and
  lit-circle contracts are untouched: nothing is visible, audible or hittable until the pop.
- **Canopy MultiMesh buckets 64 → 128 m** for the 12 canopy species (`tree_cover_layer.gd
  CANOPY_BUCKET`): nodes **3,631 → 3,038**; in range from the player, **395 MultiMesh nodes carrying
  7,747 instances** (new census line, no before-number — the first census predates it).
- **MultiMesh built by one `buffer` write** instead of one `set_instance_transform` server call per
  plant (the `veg.tree_cover_mmi 13–44 ms` rebuild after a felled tree).
- **`nav.collect` time-sliced** (`nav_baker.gd`): 285.9 ms in one idle step → a job spending at most
  6 ms a frame, the async Recast bake unchanged. Cost is ~1.5 s more latency on a breach rebake.
- Per-man micro: `Burning` node lookup cached; `look_at()` skipped until the aim moves a third
  of a degree; Huey/Chinook airframe meshes get a 1,200 m visibility range (were unbounded at
  ~50k tris each).
- Interleaved A/B of ALL of today's code vs the stashed baseline, current→base→current:
  **24.7 / 10.3 / 17.0 mean fps** — today's code is a gain in the same conditions, and the spread
  between the two "current" runs is the box's own noise.

**Gates green after:** `test_sapper_assault`, `test_firebase_defense`, `probe_ai_lod`,
`test_demo_arc` (26), `test_nav_path`, `probe_compound_nav`, `probe_bunker_entry`,
`probe_parapet_parity` — and `probe_bunker_entry` at its corrected 29 of 37 (its 3-of-37 was the
instrument, fixed the same day). **Closing headless siege run with everything in:** windows 20,
**mean 70.5 fps, floor 15.0, mean worst frame 82 ms, max worst 97 ms** — against this evening's
paired control at 14.8 / 3.7 / 242 / 298. `nav.collect` now shows as `95 ms over 45 slices,
worst slice 14.3 ms` where it was one 286 ms step.

**NOT DONE, named:** the Huey/M101 art budget (his art); worker-threading the terrain chunk and
scatter builds (item 5 proper — the nav slice is the safe first third of it); and his two windowed
A/Bs — `perf_walk_compat.bat` (Compatibility renderer, one flag, decree stands until he lifts it)
and `perf_walk_d3d12.bat` — which only his window can answer.

### 2026-09-10 — FIX WAVE, second pass: the trunk ring was a per-shot zone update

Ranked off the closing run's own stall totals, not the plan. Headless, paired against the previous
commit's closing run (`stress_final`).

- **`veg.trunk_ring` 1,498 ms → 61 ms over the run, worst 18.0 → 1.7 ms.** Two findings on the way,
  and the instrument taught both: (1) a per-chunk cell index for the trunk scan made the span read
  0.02 ms — because a `PackedInt32Array` is a VALUE in GDScript and `(cells[k] as
  PackedInt32Array).append(i)` appended to a copy; the ring placed nothing and three tree-cover tests
  went red. Fixed. (2) With the index working the cost did not move at all, so it was split into
  `ring.scan` / `ring.place`: **scan 3.16 ms, place 0.00**. The scan was the THREAT ZONES:
  `bullet_system.gd:86` files a shooter zone on EVERY shot and `_add_zone` ran a full ring update
  immediately — 430 scans in a 150 s siege, each testing every trunk in every zone-touching chunk
  against every zone segment. Zone updates now coalesce into the next physics tick, and cells are
  rejected against each zone's footprint rect before any trunk in them is tested.
- **`destructible.drain` worst 93.5 → 53.1 ms**: the ruin meshes are loaded at world build
  (`Destructible.warm_ruins()` beside `GunFX.warm`) instead of at the first collapse of each kind;
  rubble goes into the MultiMesh as one buffer write instead of a server call per piece ever
  scattered; `STRUCTURE_LEVELS_PER_FRAME` 2 → 1 (one `_do_destroy` still costs ~29 ms — the two
  explosion FX, the fire hazard, the crater — and that is the next thing to open).
- Pre-warm drips one man a frame (not the pop's two).
- `ai.fire` / `ai.suppress` / `ai.cover` spans added so the next pass can see inside `ai.execute`'s
  11 ms worst step.

**Closing run this pass: mean 94.9 fps, floor 43.0, mean worst frame 72 ms** (previous commit's
close 70.5 / 15.0 / 82; this evening's pre-wave control 14.8 / 3.7 / 242). Gates green:
`test_trunk_ring`, `test_tree_cover_wired`, `test_tree_cover_lod`, `test_destructible`,
`probe_destructible_placement`, `test_sapper_assault`, `test_firebase_defense`, `test_demo_arc`.

### 2026-09-11 — FIX WAVE, third pass: a felled tree costs its own bucket, not its chunk

- **`tb.load_species` 96.9 ms worst → 0.** The first tree of each species to fall paid three GLB
  extracts inside the frame the shell landed in. `TreeBreakSystem.warm_parts()` runs at world build,
  beside the ruin warm-up.
- **Felled-tree redraw is LOCAL now.** `remove_scatter_entries` used to compact the chunk's scatter
  and flush a full `generate_for_chunk` (every bucket freed and re-instanced, trunks re-derived,
  break registry re-registered: `mmi.group`+`register`+`build`+`ring`, ~40 ms in one frame per tree).
  Now the entry is marked dead IN PLACE — its index stays valid for the break registry — its trunk
  is retired by radius, and only the MultiMesh bucket it drew from is rebuilt from survivors as one
  buffer write. **`veg.partial_regen` 38 calls, worst 4.4 ms.** The regen queue, its flush and
  `REGEN_PER_FRAME` are deleted (fossil law). `chunk_origins` is left as built (probe truth).
- **Second `PackedFloat32Array`-is-a-value slip caught on review**, same class as the morning's:
  `(trunks["radii"] as PackedFloat32Array)[t] = 0.0` retires a copy. Read out, write, store back.
- **Still rebuilding whole chunks: CRATERS.** `mmi.group` 854 ms / 112 calls in this run — every
  mortar impact's heightmap edit re-queues the chunk's vegetation and `_rematerialize` rebuilds it
  all. Next pass: the same partial machinery for a crater (kill the plants inside the hole, re-seat
  Y for the rest of the edited rect, rebuild only the touched buckets).

Gates green: `probe_napalm_stall`, `test_trunk_ring`, `test_tree_cover_wired`, `test_tree_cover_lod`,
`test_destructible`, `test_sapper_assault`, `test_demo_arc`. Closing run: mean 83.1, floor 39.4,
worst 71 ms (box noise band with the previous pass's 94.9 / 43.0 / 72).

### 2026-09-11 — FIX WAVE, fourth pass: craters and settled logs are local too, and a blind instrument

- **A crater no longer rebuilds its chunk's canopy.** The terrain patch passes the edited cells
  (world metres) through `_queue_veg_regen` → `generate_for_chunk(…, partial)` → `_rematerialize` →
  `TreeCoverLayer.update_chunk`, which diffs the manager's current list against what the layer drew
  **by plant `uid`** (stamped in `_build_scatter`): ADDED entries are appended at the end (indices
  stay valid for the break registry), REMOVED are marked dead in place, MOVED (inside the edited
  rect) get their bucket rebuilt at the new height and their trunk re-seated. **A settled log takes
  the same path**: `add_fell_entries` appends to a current cache instead of dirtying the chunk, and
  `rebuild_chunk` runs the local update around it. Break registry gains `register_entries` /
  `unregister_entries`. Full-chunk rebuilds in the siege: **112 → 21** (`mmi.group` 854 → 154 ms).
- **First cut was slower than the rebuild it replaced** — `veg.partial_update` 1,694 ms, worst
  138.7 — because `_rebuild_bucket` rescanned all ~9,700 plants once PER touched bucket. One pass
  over the chunk for every touched key (`_rebuild_buckets`): **404 ms / 61 calls, worst 12.3**.
- **THE BLIND INSTRUMENT.** `tools/probe_chunk_patch` read 1,344 of 2,132 canopy instances "in the
  wrong place, worst 206 m" after a local update, against identical plant counts and summed
  heights. Measured: 2,132 instances resolved to **134 distinct positions = the node count**.
  Under the headless `RendererDummy`, `MultiMesh.get_instance_transform()` returns IDENTITY for
  every instance, so that check had only ever compared bucket ORIGINS — which a full rebuild
  re-centres and a local update keeps by design. It passed for a year by coincidence. The check now
  compares what the dummy can see (node count, the multiset of per-node instance counts, and that
  every live plant is drawn once); where the plants stand is asserted through the layer's own
  scatter, and only a windowed run can see it drawn. `probe_crater_veg` and `probe_chunk_patch`
  now count LIVE entries (dead-in-place is the contract).
- **`MultiMesh.buffer` writes reverted to `set_instance_transform`** (tree cover, rubble). Under the
  dummy a written buffer reads back as every instance at the origin and the getter returns `[]`,
  so the one-write path could not be probed and the shipping renderer was never checked for it.
  `set_instance_transform` is the path his eyes have seen for months. Buckets are small now; the
  per-instance call is no longer the cost it was when a whole chunk went through it.

Gates green: `probe_chunk_patch` (all), `probe_crater_veg` (all), `probe_napalm_stall`,
`test_trunk_ring`, `test_tree_cover_wired`, `test_tree_cover_lod`, `test_destructible`,
`test_demo_arc`. Closing run: mean 87.7, floor 30.1, worst 69 ms (box noise band).

### 2026-09-11 — FIX WAVE, fifth pass: the blast's own cost was the cache prune

`_do_destroy` was split into five spans; **`dz.crater` was all of it: 5.6 ms mean, 49.1 ms worst**
— `DamageSystem.apply_damage` → `clear_area` → `_prune_scatter_cache`, which walked every entry of
every touched chunk (~9,700 each, four chunks for a round) and rebuilt the list without the ones the
hole took, inside the frame the shell landed in. The cache now carries its own 32 m cell index
(`_index_cells`, kept in step by `add_fell_entries`); a hole is applied only to the cells its
footprint reaches, and a plant it takes is **marked dead where it stands** — `uid` and index stay
valid for everything downstream, all of which now skips dead entries (the manager's re-seat, the
break registry's `register_chunk`, the layer's draw). The layer treats an entry that died in the
shared dictionary after it was drawn (`drawn` flag) as a removal and rebuilds only its bucket.
**`dz.crater` fell out of the ledger's top-N entirely.** `probe_crater_veg`'s "pruned == regenerated"
counts live entries and still holds: 9,472 vs 9,472, 0 mismatches.

Gates green: `probe_crater_veg`, `probe_chunk_patch`, `probe_napalm_stall`, `test_trunk_ring`,
`test_tree_cover_lod`, `test_destructible`, `test_sapper_assault`, `test_demo_arc`.

### 2026-09-11 — FIX WAVE, sixth pass: the cache re-seat is local too

`_build_scatter`'s cache hit re-sampled the heightmap for EVERY plant in the chunk on every crater
(~9,700 samples for a 20 m hole). It now takes the edited rect and re-seats only the plants standing
in it, found through the cache's cell index: **`veg.scatter_hit` 417 → 125 ms over the siege.**
`probe_chunk_patch`'s summed-height equivalence (patched vs full rebuild) still holds exactly.

### 2026-09-11 — FIX WAVE, seventh pass: the local update reads only the cells it touches

The manager and the layer hold the SAME scatter array now (the prune marks dead in place, a
settled log appends), so `update_chunk` no longer diffs by uid: newcomers are the tail past
`_chunk_known`, removals are dead-since-drawn entries in the cells the blast could reach, moved
plants are the live ones in the edited rect — all through the cache's 32 m cell index, which the
manager hands the layer. `_rebuild_buckets` reads only the index cells under the touched buckets.
The general uid diff is kept as `_update_chunk_full` for a caller that hands over a different array.
**`veg.partial_update` 970 → 196 ms (worst 17.1 → 10.8); `veg.partial_regen` 252 → 96 ms (worst
8.1 → 3.1).** One parse error on the way (a parameter named like a local) — caught by the gates,
not the game. Gates green: `probe_chunk_patch`, `probe_crater_veg`, `probe_napalm_stall`,
`test_tree_cover_lod`, `test_tree_cover_wired`, `test_trunk_ring`, `test_sapper_assault`,
`test_demo_arc`.

**Where the ledger stands after seven passes (headless siege, 150 s):** `ai.execute` 3.3 s /
85k calls (0.04 ms each - steady per-man cost, worst 14 ms which is not in `ai.fire`/`ai.cover`
and reads as `move_and_slide` against the compound), `ai.think` 1.1 s, the per-man spawn passes
~1.9 s (all inside the pre-warm drip now), `nav.collect` 0.5 s sliced (worst 17 ms = one large
shape per slice). **Every stall class over 20 ms that the ledger could name is gone.** What is
left is steady per-man CPU and the GPU half, which only his window can measure.

### 2026-09-11 — THE WAVES: the assault is a tide, and the night could not end

His ask: smaller waves, ramping up, "five guys at once and it feels like you're gonna be over run."
Built as a moving cap on MATERIALIZED men (`SiegeDirector.wave_cap`: 8 at the assault's opening,
linear to the full LIVE_CAP 50 over 180 s; sappers held 40 s; probes exempt; `--siege-waves-off`
is the A/B). Paired, back to back, same seed, garrison only (`wp_on2`/`wp_off2`): **near-tier peak
19 vs 38; fps during the assault 25–101 (most windows 50–90) vs 13.6–30.6; 1% low 10–29 vs 10–13.**
Worst frame unchanged (41–97 vs 76–98 ms) — the stall classes are gone, what is left is per-man.

**The find:** every paced night ran to dawn. The flood had been hiding a siege that cannot end:
spent sappers stood 26 m out at full health forever (`_withdraw` never released their legs), the
stuck watchdog read velocity the slide had already eaten and never fired for a wall, a pinned far
man promoted then demoted straight back into the same wall, a bearing-only breach re-aim sent
squads through a hole on the far side, and a man who reached his objective with no target stood
ALERT until dawn. All five fixed; his ruling on the sapper: **"he needs a gun and just joins the
attack after placing a bomb"** — shipped (the PPSh was in his data all along, only the silence
flag muted him). Paced night now breaks at t+139 s / 22 down; flood at t+71 s / 23 down.
Council record: `production/war_room/2026-09-11_siege_waves/`. Feel numbers (8 / 180 s / 40 s)
are his to rule. `AILod.mean_near` deleted (born dead); fossil gate green at 28.
Gates: `probe_ai_lod` 13/13, `test_sapper_assault`, `test_siege`, `test_fossils`,
`test_firebase_defense`, `test_demo_arc`.
