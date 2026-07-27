# MEASUREMENT ENGINEER — the windowed batch, the census instrument, and why the old harness lied

**Session:** 2026-07-26 FPS deep dive · **Lens:** build the instrument, not the plan.
**Constraint I am bound by:** he runs windowed benches; I cannot. Everything below is written to be
executed by a human in one sitting, unattended per run, with the exact command line typed once.

**POINTER LAW:** every claim about code state below cites `file:line`. Anything I could not verify is
labelled OPINION or UNVERIFIED and says so.

---

## 0. HEADLINE

1. **The batch is 6 items, ~19 minutes of machine time, ~35 minutes wall clock.** It answers: what the
   baseline is *today*, where the 1,400 draw calls actually live by subsystem, whether the frame is even
   GPU-bound at the spawn pose, and whether the firebase-atlas claim has a ceiling worth the work.
2. **Two of the four levers in the shipped attribution cycle measure NOTHING at seed 47225.**
   `no_campfires` (zero campfires at a DAY seed — `perf_probe.gd:172-174` warns about it) and
   `no_sun_shadow` (ship already runs shadows off — `perf_probe.gd:162-163` warns about it). That is
   **14 of 63 sampled seconds spent measuring nothing, every run, since 2026-07-20.** Re-pointing those
   two phase slots at `no_structures` and `no_characters` is the single highest-value change to the
   instrument and costs ~15 lines.
3. **The patrol world's CPU-vs-GPU split has NEVER been measured.** `tests/perf_probe.gd` reads
   `get_rendering_info` only (`:109-114`) — no `viewport_get_measured_render_time_gpu`. Every CPU/GPU
   claim in the ledger comes from `ai_stress_arena` (`PERF_LEDGER.md:200-201`), a scene the briefing
   itself says escalates while you measure it (`:222-227`). **Eight lines of patch closes the biggest
   hole in the evidence base.**
4. **`--card-dist=` is the only free flag that lands on the only measured lever.**
   `terrain/vegetation/tree_cover_layer.gd:77-80`. Zero code, zero risk, directly shrinks the far-card
   ring that owns ~957–1,017 of the frame's draw calls (`PERF_LEDGER.md:894-899`).
5. **The card bake tool is still NOT in the repo.** Verified: `tools/` contains `bake_family_clip.py`,
   `bake_gun_wood.py`, `bake_pinned_family.py` — all weapon/animation tools. No card, impostor or atlas
   generator. The briefing's question 2.1 is answered **NO**; the atlas blocker at
   `PERF_LEDGER.md:930-939` stands unchanged.

---

## 1. DRIFT FOUND WHILE READING (NO-DRIFT law — corrected on contact)

I am not editing other architects' files mid-council, but these are recorded here so the Arbiter can
correct them in the synthesis. **Every one of them is a pointer that would send the next reader to the
wrong line.**

### 1a. `rendering/renderer/rendering_method` IS MISSING FROM `project.godot` AGAIN

`PERF_LEDGER.md:21-24` says: *"As of 2026-07-20 it is explicitly `forward_plus` in `project.godot:300`
(ADR-026 Amendment A). Note Godot STRIPS this key on editor save when it equals the desktop default —
if it goes missing again, restore it before measuring."*

**It is gone.** The `[rendering]` block of `project.godot` today (lines 302–311) reads:

```
[rendering]
textures/canvas_textures/default_texture_filter=0
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/use_debanding=true
scaling_3d/mode=5
scaling_3d/scale=0.75
scaling_3d/fsr_sharpness=0.3
mesh_lod/lod_change/threshold_pixels=2.0
```

`renderer/rendering_method.mobile` is the **mobile-platform override**, not the desktop key. The desktop
key is absent.

**Behaviourally this changes nothing** — Godot's desktop default IS `forward_plus`, so the game still
runs Forward+. **But it breaks the measurement contract**, in two concrete ways:

- `tests/perf_probe.gd:208-209` prints the renderer by reading
  `ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus (default)")`. With
  the key missing it prints the **fallback string**, not a read value. Every `PERF TABLE` line from now
  on is asserting a renderer it did not actually read.
- `tests/windowed_patrol_perf.gd:48` reads the same setting **with no default** — it will print `<null>`
  or an empty string into the row.

**RECOMMENDATION (Arbiter's call): restore `renderer/rendering_method="forward_plus"` to
`project.godot` BEFORE the batch runs, and update `PERF_LEDGER.md:21-24`'s `:300` pointer to the new
line.** Cost: one line. Without it, every row this batch produces is a number without its renderer,
which `PERF_LEDGER.md:52` says is not a number.

### 1b. Line pointers in the ledger and the briefing have drifted

| Claim | Cited as | Actually at | Source |
|---|---|---|---|
| ship sun `shadow_enabled = false` | `game_world.gd:48` (briefing §1, ledger `:396`, `:631`, `:661-662`) | **`scripts/levels/game_world.gd:52`** | line 48 is `var light := DirectionalLight3D.new()` |
| canopy group key `[species, bucket_x, bucket_z]` | `tree_cover_layer.gd:105` (briefing) / `:94` (ledger `:909`) | **`terrain/vegetation/tree_cover_layer.gd:110`** | read |
| `BUCKET = 64.0` | `:52` (briefing) / `:47` (ledger `:910`) | **`:52`** — briefing correct, ledger stale | read |
| two nodes emitted per group | `:125`/`:128` (briefing) / `:115`/`:118` (ledger `:911`) | **`:132`** (near solid) / **`:135`** (far card) | read |
| `visibility_range` per-NODE / godot#79471 comment | `:47-51` (briefing) / `:43-46` (ledger `:923`) | **`:49-51`** | read |
| `_extract_mesh` takes first mesh only | `:199` (ledger `:908`) | `:88`/`:93` call it; definition further down — **UNVERIFIED, did not read past `:150`** | — |

The `game_world.gd:48` one matters most: it is quoted in **four** separate places including the
retraction banners, and it is the reference the ship-parity guard exists to protect
(`tests/test_ship_parity.gd:8` names `game_world.gd` as `SHIP_FILE`, and reads the property by name
rather than line — so the guard itself is safe; only the prose is wrong).

---

## 2. ASSIGNMENT 1 — INVENTORY OF THE EXISTING HARNESSES

### 2a. The `.bat` launchers at repo root — what each actually launches

Every one of them invokes the **non-console** Godot binary
(`C:\Users\caleb\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`), which means
**stdout is not visible**. That is fine for a play bench, fatal for a measurement bench. The batch below
uses the `_console.exe` sibling that `run_all_tests.ps1:22` uses.

| `.bat` | Launches | Perf relevance |
|---|---|---|
| `night_jungle_bench.bat` | `res://scenes/levels/ai_stress_arena.tscn` | The adversarial night 18v18 arena with `ArenaPerfOverlay` and F1–F6 toggles. **The scene the ledger says is the WRONG one for toggle-diffs** (`PERF_LEDGER.md:222-246`: it escalates while you measure — 6 identical control phases swung 15.7–19.0 fps and 1,013→1,268 calls with nothing changed). Use it for renderer/whole-build A/Bs at a fixed timepoint, never for attribution. |
| `observation_room.bat` | `res://scenes/levels/observation_room.tscn` | AI-vs-AI + structures with the observation instrument (free-fly observer, SimClock). Not a perf harness. |
| `observation_room_routine.bat` | `res://scenes/levels/observation_room_routine.tscn`, `-- --test-save` | Populated AO on a compressed day. **The only `.bat` that already passes `--test-save`** — it is the model the perf batch should copy (see §5c). |
| `patrol_lab.bat` | `res://tools/patrol_lab.tscn` | God's-eye VC patrol lab. Not a perf harness. |
| `support_fire_range.bat` | `res://scenes/levels/support_fire_range.tscn` | Fire-support tiers + destructible trees/forts. Relevant only to the ADR-031 destruction-cost question, not to the resident frame. |
| `gun_range.bat` | `res://scenes/levels/gun_range.tscn` | Armory range. **Malformed file — no line breaks; the `@echo off`, both `rem` lines and the command are on ONE line**, so `@echo offrem THE RANGE...` is a single token. It happens to still launch because cmd treats the whole thing as one command after the mangled echo, but it is broken and should be repaired. Not perf. |
| `sight_lab.bat` | `res://tools/sight_lab.tscn` | Art-vs-AI-sight calibration. Not perf. |
| `grunt_viewer.bat` / `hitzone_editor.bat` / `viewmodel_editor.bat` | character / hitzone / viewmodel benches | Not perf. |

**There is no `.bat` for the patrol-world perf probe.** Every perf run in the ledger since 2026-07-20
was a hand-typed command. That is a friction tax on the one thing we want him to actually do, and a
`fps_bench.bat` is a 3-line file (§5d).

### 2b. `scripts/levels/ps2_perf_probe.gd` — the arena bench, richest CLI surface in the repo

Unattended, self-quitting (`:125`), pins the camera to a fixed pose (`CAM_POS`/`CAM_LOOK`, `:16-17`,
applied `:78-81`), and prints one machine-readable `SUMMARY` line (`:117-119`) carrying
`avg_fps median_fps frame_ms cpu_ms gpu_ms render_cpu_ms calls`.

**It reads the real driver GPU timer** (`viewport_set_measure_render_time` at `:45`,
`viewport_get_measured_render_time_gpu` at `:98`, `..._cpu` at `:99`) — which
`tests/perf_probe.gd` does not. **This is the pattern the patrol probe should copy.**

Its CLI levers (`:8-14`, parsed `:147-187`): `--seconds=` `--warmup=` `--scale=` `--mode=`
`--no-lights` `--no-shadows` `--label=` `--shot=`.

**Scope limit:** it boots `AIStressArena.new()` itself (`:52-58`). Every one of those levers is an
**arena** lever. None of them reach the patrol world.

### 2c. `scripts/levels/arena_perf_overlay.gd` — the live HUD

`ArenaPerfOverlay`, CanvasLayer. Frame graph, spike catcher with event attribution (`:167-173`),
CPU/GPU split with honest fallback when the driver returns no timing (`:144-153` — it **derives** and
says so rather than inventing a number), per-system CPU buckets (`:184-201`), the ray census and the
WA-A2 body-gate census (`:205-232`), and F1–F6 toggles (`:265-294`).

Note `_shadows_on` defaults to `false` at `:83` with the comment naming `game_world.gd:48` — that is the
drift in §1b, and it is the fix the ledger records at `:792-794`.

**Arena-bound:** `setup()` (`:86-93`) is fed the arena's own jungle/clutter/lights/sun nodes. It is not
attachable to the patrol world without being handed equivalents.

### 2d. `tests/perf_probe.gd` — THE patrol-world instrument, and the one the batch drives

Attached by `scripts/main/game_flow.gd:352-358` when `--perf-probe` is on the command line, into the
**live world the player walks** (`:354-358`) — explicitly not a world of its own (`perf_probe.gd:3-6`).

| Property | Where | Value |
|---|---|---|
| warmup | `:18` | 5.0 s |
| phase window | `:19` | 7.0 s |
| settle after toggle | `:20` | 2.5 s → **4.5 s of samples per phase** |
| screenshot fires at | `:24` | 0.25 s (moved from 1.5 s — the fix at `PERF_LEDGER.md:747-750`) |
| screenshot only on | `:97` | phase 0, or every phase under `--shadow-study` |
| vsync / max_fps | `:45-46` | `VSYNC_DISABLED`, `max_fps = 0` |
| ship shadow captured at attach | `:53-58` | `_shipped_shadow`, `_shipped_shadow_dist` |
| phase lists | `:59-68` | `--shadow-study` (5) · `--perf-cycle` (9) · default (1 baseline) |
| counters read | `:109-114` | prims, calls, objs — **no GPU-ms, no CPU-ms** |
| A/B/A bracketing | `:222-233` | each lever scored against the MEAN of its two flanking baselines |
| noise floor printed | `:234-235`, `:250-262` | widest gap between any two baseline windows |
| `INSIDE NOISE` tagging | `:244` | any \|delta\| ≤ spread |
| self-quit | `:246` | `get_tree().quit(0)` — the orphan-process fix (`PERF_LEDGER.md:743-746`) |

**The two dead levers.** At seed 47225 the cycle spends 2 of its 4 lever windows on nothing:
- `no_campfires` — zero campfires at a DAY seed; `:172-174` push_warnings, and the ledger measured
  `+0.0` twice (`:693`, `:825`).
- `no_sun_shadow` — ship already runs shadows off; `:162-163` push_warnings, and the ledger measured
  `-0.2` / `+0.6` / `+1.0`, all inside noise (`:696`, `:826`, `:843`).

The probe is **loud** about both, which is exactly right and is the pattern that caught the seed-47225
problem. But loud-and-useless still burns 14 seconds and, worse, **spends two of the nine phase slots**
that could be measuring the three asset waves that landed since.

### 2e. `tests/test_ship_parity.tscn` / `.gd` — what "ship parity" means mechanically

This is the guard that makes a third shadow retraction structurally hard. Headless, in the suite
(`run_all_tests.ps1:24` globs `test_*.tscn`).

- **SHIP_FILE** = `res://scripts/levels/game_world.gd` (`:8`). The shipped values are *read out of the
  source*, never hardcoded — so the guard cannot drift from the game.
- **PARITY_PROPS** = `["shadow_enabled", "directional_shadow_max_distance"]` (`:23`).
- **Harnesses are DISCOVERED, not listed** (`:15-21`): any `.gd` under `res://tests`, `res://tools` or
  `res://scripts/levels` that contains `get_rendering_info`, `viewport_get_measured_render_time` or
  `get_frames_per_second`. **The 2026-07-17 fix failed because it was instance-shaped — it repaired
  `ai_stress_arena` and left the identical defect in `perf_probe`. Discovery is what covers the harness
  nobody has written yet.**
- **RULE A** (`:54-55`): every write to a parity property in a harness must assign the shipped value,
  assign a captured ship variable, or be **declared** in `tests/parity_baseline.json` with a dated reason.
- **RULE B** (`:56-57`): a harness that deviates at all must **also** read the shipped value somewhere.
  **No register entry can satisfy Rule B.** A study phase cannot be grandfathered into having no
  reference row. This is the rule the historical defect trips hardest — it had exactly one shadow
  assignment, phase-dependent, and never captured ship at all.
- **Self-tested in both directions** (`:32-38`, and the ledger's `:781-786`): 12/12 on every run, four
  sources it must flag (including the defect verbatim) and six it must not. It cannot rot into a probe
  that only ever passes.
- **Ratchet**: `tests/parity_baseline.json`, `count` + `ceiling` audited before the register is read
  (`:68-71` for the write/grandfather paths).

**Direct consequence for this council: any census probe placed under `tests/`, `tools/` or
`scripts/levels/` that reads `get_rendering_info` is AUTOMATICALLY enrolled.** That is an argument for
extending `perf_probe.gd` rather than writing a new file somewhere clever — and an argument against ever
putting a perf probe outside those three roots.

### 2f. Other windowed harnesses that already exist (do not rebuild these)

| File | What it does | Verdict for this batch |
|---|---|---|
| `tests/windowed_patrol_perf.gd` | Real GameFlow entry, seed 47225, **forces `scaling_3d_scale = 1.0` (`:15`, `:31`)**, 8 s warmup + 12 s sample, prints one row with **real GPU-ms** (`:38-42`), self-quits. | **The NATIVE-scale row.** Its 2026-07-18 output is `PERF_LEDGER.md:267-274`. Useful, but a single un-bracketed window — good for one anchor number, not for a delta. |
| `tests/overnight_bench.gd` | Unattended arena bench; drives the real F1–F6 overlay path via injected `InputEventKey` (`:74-81`) rather than reimplementing toggles. `--scale= --mode= --out= --tag= --shot= --allon` (`:55-66`). | Arena only. The ledger's own method-debt note (`:244-246`) says a live firefight is the wrong scene for a toggle-diff. **Do not use for the census.** |
| `tests/probe_perf_decay.gd` | Windowed; samples node count, orphans, objects, chunk count every 4 s for 56 s while stationary — built to catch the monotonic FPS decay described in its header (`:3-8`). Builds a **bare** `game_world` at seed 4242 (`:28-30`). | Bare world, wrong seed — but the **decay question it was built for is still open and nobody has re-run it since the patrol world got heavy.** Flagged as a candidate, not in the batch (see §6, cut line). |
| `tests/veg_lod_lookcheck.gd` | Windowed look-check of the near-solid → far-card LOD transition, 3–80 m lane, screenshot + quit. `--shot=` (`:23-25`). | **This is the LOOK instrument for any `--card-dist` / `BUCKET` change.** Not an FPS bench. Pair it with batch item 3/4. |
| `tests/test_tree_cover_lod.gd` | headless LOD contract test | suite, not batch |
| `tools/diag_veg_cards.gd`, `tools/probe_vegetation.gd` | vegetation diagnostics | not read in depth — UNVERIFIED scope |

### 2g. `run_all_tests.ps1` — understood, NOT run

Headless suite. Godot binary at `:22` is the **`_console.exe`** variant. Globs `tests/test_*.tscn`
(`:24`), so `perf_probe.tscn`, `probe_perf_decay.tscn`, `overnight_bench.tscn`, `veg_lod_lookcheck.tscn`
and `windowed_*` are all **excluded by name** — deliberate, since they are windowed. Passes
`-- --test-save` so the suite cannot wipe the real campaign (`:11-13`). Carries two ratchets:
`$KnownRed` (a red test going green is an XPASS **and breaks the build**) and `$Graduated` (a green test
going red reports REGRESS, and removing a name to quiet the board is named as the forbidden move).
Scans captured output for engine-complaint prefixes rather than trusting exit code (`:4-8`) — the fix
for the R16 navmesh no-op that shipped green.

---

## 3. ASSIGNMENT 2 — EVERY LEVER, SORTED BY WHAT IT COSTS TO *MEASURE*

This is the part that decides how much of the plan is evidence and how much is argument. **A lever that
needs engineering before it can be measured is a bet; a lever behind a flag is a fact you have not
collected yet.**

### (a) TESTABLE TODAY WITH AN EXISTING FLAG — zero code, zero risk

| # | Lever | Flag | `file:line` | Why it matters |
|---|---|---|---|---|
| a1 | **Far-card draw distance** | `--card-dist=N` (default 350) | `terrain/vegetation/tree_cover_layer.gd:77-80` | **THE one free flag that lands on the one measured lever.** Far-card ring = `(buckets in range) × (species per bucket)`; shrinking the range shrinks the bucket count directly. Also a LOOK change — but he can judge the look in the same run with his eyes, which is the gate (`RULE #1`). |
| a2 | **Attribution cycle** | `--perf-probe --perf-cycle` | `scripts/main/game_flow.gd:352-358`; phases `tests/perf_probe.gd:65-66` | A/B/A bracketed, noise floor printed, self-quitting. The batch's spine. |
| a3 | **Shadow price study** | `--perf-probe --shadow-study` | `game_flow.gd:356`; phases `perf_probe.gd:60` | **Settled and CLOSED** — 40/80/uncapped identical within 0.5 (`PERF_LEDGER.md:704-730`). Named so nobody re-runs it. Do not put it in the batch. |
| a4 | **Bench a different seed** | `--perf-seed=N` | `game_flow.gd:202-204` | Weather/time/site layout change with seed. Seed 12 = NIGHT + 4 campfires (`PERF_LEDGER.md:805-807`). |
| a5 | **Bench a different POSE** | `--spawn-at-village` | `game_flow.gd:288-304` | **Badly underused.** *Every* FPS row in the ledger is the fsb_main spawn view into the base interior, and the ledger says so itself (`:524`: *"this pose faces the firebase interior, not a jungle sightline"*). This flag drops the patrol 60 m off a village edge for **zero code**. It is the cheapest way to find out whether the whole ledger is describing an unrepresentative pose. |
| a6 | **Protect the campaign** | `--test-save` | `scripts/autoload/campaign_state.gd:130-131`; redirects saves via `scripts/autoload/save_manager.gd:35-36` | **MANDATORY for this batch, and nobody has been using it.** `game_flow.gd:363` calls `SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE")` at the end of *every* `enter_hub` — **every perf run to date has overwritten his autosave.** It also makes the world deterministic run-to-run: `site_planner.gd:197` skips tunnel mouths the campaign records as collapsed, so a dirty campaign silently changes the geometry you are benching. |
| a7 | **Renderer** | `--rendering-method mobile` | Godot built-in | **CLOSED by decree** (ADR-026 Amendment A, `PERF_LEDGER.md:49-51` of the briefing). Named only so it is not "rediscovered". Not in the batch. |
| a8 | Arena jungle levers | `--fill_chance=` `--view_distance=` | `scripts/levels/ai_stress_arena.gd:471-482` | Arena only. |
| a9 | Arena bench levers | `--scale=` `--mode=` `--no-lights` `--no-shadows` `--seconds=` `--warmup=` `--label=` `--shot=` | `scripts/levels/ps2_perf_probe.gd:8-14, 147-187` | Arena only. |
| a10 | Overnight arena bench | `--scale= --mode= --out= --tag= --shot= --allon` | `tests/overnight_bench.gd:55-66` | Arena only; wrong scene for attribution. |
| a11 | LOD look-check shot | `--shot=` | `tests/veg_lod_lookcheck.gd:23-25` | The LOOK half of any canopy-range change. |

**Free-lever gap, stated plainly: there is NO command-line lever for render scale on the patrol world.**
`ps2_perf_probe.gd:47-50` has `--scale=`/`--mode=` but only for the arena. `tests/perf_probe.gd` parses
no arguments at all. Godot 4.7 has no generic project-setting override on the CLI. So a scale A/B on the
shipped world is either a one-line `project.godot:308` edit + reboot, or the 6-line patch at (b1) —
and (b1) is strictly better because it gets **A/B/A bracketing inside one boot**.

### (b) TESTABLE WITH A <10-LINE TEMPORARY PATCH

Ranked by information-per-line.

| # | Lever / instrument | Patch | Lines | `file:line` anchor |
|---|---|---|---|---|
| **b1** | **GPU-ms + CPU-ms columns in `perf_probe`** | `RenderingServer.viewport_set_measure_render_time(rid, true)` in `_ready()`; accumulate `viewport_get_measured_render_time_gpu` + `Performance.TIME_PROCESS`+`TIME_PHYSICS_PROCESS` alongside the existing counters at `:109-114`; two more columns in the `PERF ROW` format at `:213-217`. | ~8 | pattern already written twice: `ps2_perf_probe.gd:45, 96-99` and `arena_perf_overlay.gd:100, 136-142` | **HIGHEST VALUE PATCH IN THE REPO RIGHT NOW.** Without it every GPU-vs-CPU statement about the shipped world is borrowed from the arena. |
| **b2** | **Render-scale phases** | parse `--perf-scale-ladder`; phase list `["baseline","scale_060","baseline_2","scale_085","baseline_3"]`; in `_apply_toggle`, `get_viewport().scaling_3d_scale = ...` else restore `_shipped_scale` captured at `attach()`. | ~10 | runtime-settable, proven at `ps2_perf_probe.gd:48` | Answers "is the frame fill-bound at all today" **with A/B/A inside one boot**. |
| **b3** | **Re-point the two dead phase slots** | `perf_probe.gd:65-66` → `no_structures` / `no_characters`; two `elif` branches in `_apply_toggle` (`:121-174`); bracket map at `:222-227`. | ~15 | see §5 for the exact node paths | Reclaims 14 wasted seconds/run and produces the census the council was convened for. |
| b4 | **`TreeCoverLayer.BUCKET` 64 → 128** | one const | 1 | `terrain/vegetation/tree_cover_layer.gd:52` | The ~2.5× call cut (`PERF_LEDGER.md:919-925`). **A LOOK change** — but *testing* it is free and his eyes settle it in one screenshot pair. Ranked below look-free levers per RULE #1; included in the batch as an **experiment**, explicitly not a proposal. |
| b5 | **`STRUCTURE_VISIBILITY_END` 230 → 150** | one const | 1 | `scripts/world/site_planner.gd:206-207` | Structures already fade at 230 m with a 25 m margin (`:213-215`). Pulling it in is a LOOK change on the new village/temple/firebase geometry, and it is one line. Untested since three asset waves landed. |
| b6 | **`VEGETATION_DENSITY_MULT` 1.0 → 0.6** | one const | 1 | `scripts/levels/world_config.gd:16` | The ledger says density buys little because prims are not the limiter (`:110-113`). **But that was measured against the retired billboard system.** Under TreeCover, fewer candidates can mean fewer *species per bucket*, which is the CALL multiplier. Worth one phase; my OPINION is it will read inside noise. |
| b7 | **`mesh_lod/lod_change/threshold_pixels` 2.0 → 8.0** | one line, or `Viewport.mesh_lod_threshold` at runtime | 1 | `project.godot:311` | Cheap to test. My OPINION: near-zero effect, because it only bites meshes with import-baked LOD and the canopy is MultiMesh cards. Listed for completeness; **low priority, do not spend a batch slot on it.** |

### (c) NEEDS REAL ENGINEERING BEFORE IT CAN BE MEASURED AT ALL

| Lever | Why it is not measurable today | Cost gate |
|---|---|---|
| **Canopy 27-card ATLAS** | Requires: a card bake pipeline (**does not exist — verified, `tools/` has no card/impostor/atlas generator**), a unit-quad mesh with per-instance UV-rect custom data, a shader that reads it, and each card's aspect re-derived into the instance transform. `PERF_LEDGER.md:930-939`. | A new far-card renderer path. **Its CEILING is measurable today though** — see batch item 1: the `no_canopy_far` phase bounds the entire win at "all far-card calls". |
| **Firebase 9→5 material collapse** | Needs 23 assets re-baked through `tools/gen_firebase.py` (9 fixed slots at `:61-77` per the briefing). | **But its CEILING is also measurable today for free** — batch item 1's `no_structures` phase bounds the total firebase render cost. If the firebase is 60 calls, a 9→5 collapse cannot be "the real performance lever" and `production/firebase_kit_phase1_read.md:261-263` should be corrected. **This is the cheapest possible kill-or-confirm and it costs one phase window.** |
| **DORMANT / AGGREGATE population tiering** (ADR-025) | New system. | Gated on the WB work. |
| **hitzone-sync / `move_and_slide` CPU reduction** | Engineering. | The measured wall is `PERF_LEDGER.md:296-304`; note that row is **headless CPU-only at 65+ units**, which is legitimate (no GPU figure involved) but is the arena's population, not the hub's 13 (`:355-360`). |

**The pattern worth naming for the Arbiter:** for both atlas questions, **the ceiling is free and the
implementation is expensive.** Measure the ceiling first. A subsystem that owns 4% of the frame does not
get an atlas no matter how elegant the atlas is.

---

## 4. ASSIGNMENT 5 — WHAT MADE THE OLD HARNESS LIE, AND THE RULE THAT STOPS A THIRD TIME

### 4a. The mechanism, diagnosed from the ledger

The defect, twice:

1. **`ai_stress_arena.gd:390`** set `sun.shadow_enabled = true` while ship runs `false`. Retired
   2026-07-17 (ADR-026:137-144, recorded `PERF_LEDGER.md:182-196`). The **whole scene** deviated from
   ship, so its −12.17 ms "shadow win" was a cost the bench had added.
2. **`tests/perf_probe.gd:123`** (as committed in `74715b86`) read:

   ```gdscript
   sun.shadow_enabled = phase_name != "no_sun_shadow"
   ```

   Retracted twice over — `PERF_LEDGER.md:393-402` and `:626-635`, corrected at `:653-701`.

**The mechanism is one sentence: the instrument WROTE the property it was measuring, in EVERY phase,
including the baselines.** So the "lever" refunded a cost the probe itself had just added, and every
other lever was scored against a shadowed baseline the game never renders — which additionally
*suppressed* the canopy delta, because the shadow pass re-renders the same jungle geometry
(`:664-666`). The published baseline of 23–25 FPS was not the shipped frame rate; ship parity reads ~34
(`:698`).

### 4b. Why it survived three reproductions — this is the part that matters

`PERF_LEDGER.md:441-443`, in the measurer's own words:

> *"I ran it three times, published the output as 'STANDS — the dominant term' and 'reproduces a third
> time', and treated reproducibility as validity. **Three consistent measurements of an artifact are
> still an artifact.** The A/B/A design was sound and it tightened the noise floor; it could not have
> caught this, because a bracketed baseline that is uniformly wrong is uniformly wrong."*

**A/B/A bracketing measures PRECISION. It cannot measure ACCURACY.** Every protocol in this repo is a
precision protocol. Nothing in the batch design, mine included, catches a uniformly-wrong reference —
so accuracy has to be defended by a *different* mechanism, and that mechanism is a corroborating
counter that the artifact cannot fake.

**It was in fact catchable, and the tell was sitting in the table the whole time.** From the shadow
study at `PERF_LEDGER.md:709-738`: turning the shadow ON *added* 117k–127k primitives and *added*
objects (149,431 → 264,858 prims; 1,934 → 2,107 objs). Meanwhile the retracted rows claimed
`no_sun_shadow` **saved** ~10 FPS while **removing** ~130k primitives from a baseline. A lever that both
adds geometry when enabled and removes geometry when disabled, against a baseline that supposedly had it
disabled, is arithmetically impossible. **The prim column contradicted the fps column for three runs and
nobody read them together.**

### 4c. THE PROTOCOL RULES — baked into the batch below

**R1 — THE INSTRUMENT MUST NOT WRITE, IN A BASELINE PHASE, ANY PROPERTY IT MEASURES.**
Never `prop = phase_name != "lever"`. That expression form **is** the retracted defect. The only legal
shape is: capture the target's own value at `attach()`, apply the deviation in the lever phase only,
restore the captured value in every other phase. `perf_probe.gd:53-58` + `:160-161` already does this for
the shadow. **Every new census toggle must be written the same way**, including the trivially-looking
ones (`visible`). Enforced structurally for the two shadow props by `tests/test_ship_parity.gd:23`
RULE A/B; enforced for the rest **only by discipline**, which is exactly why I am writing it down.

**R2 — EVERY LEVER PRINTS A CENSUS OF WHAT IT HID, AND WARNS LOUDLY WHEN IT HID NOTHING.**
`perf_probe.gd:168-174` is the pattern; it is the check that caught the seed-47225 campfire problem
(`PERF_LEDGER.md:475-488`). A silent no-op row reads as "this system costs nothing", and that reading
survives into a decree. Every new phase gets `hidden=<n>` on its row and a `push_warning` at n=0.

**R3 — NO FPS DELTA IS ACCEPTED UNLESS THE COUNTER DELTAS HAVE THE RIGHT SIGN AND A PLAUSIBLE
MAGNITUDE.** This is the rule the shadow artifact would have failed for three straight runs. Concretely:
hiding a subsystem must *reduce* draw calls and/or primitives, by roughly the count the census says it
hid. An FPS win with a flat or rising call/prim count is **the instrument**, not the world. (The ledger
already applied this reasoning once, correctly, at `:73-75` — "the identical prim/call/object counts
prove it" — and then failed to apply it to the shadow.)

**R4 — THE HARNESS LIVES UNDER `tests/`, `tools/` OR `scripts/levels/`, ALWAYS.**
`tests/test_ship_parity.gd:15-21` discovers harnesses by directory + measurement marker. A probe written
anywhere else is invisible to the guard, and the 2026-07-17 fix failed *precisely* because it was
instance-shaped. **Extending `tests/perf_probe.gd` inherits the guard for free.**

**R5 — SUBSYSTEM TOGGLES USE `.visible`, NEVER `queue_free()` OR `remove_child()`.**
Freeing nodes changes the CPU load, the physics broadphase and the nav graph, so the delta stops being a
render delta and becomes an everything delta — and it is irreversible mid-run, which breaks the A/B/A
return-to-baseline. **Consequence to state on the row: a `.visible` census prices RENDER cost only.**
The `no_characters` phase does NOT price AI CPU, and must never be quoted as if it did.

**R6 — RUN SHORT, FIXED ORDER, AND VERIFY ONE GODOT INSTANCE BEFORE EACH RUN.**
The arena taught that a live scene escalates while you measure it (`:222-227`: six identical control
phases, 15.7–19.0 fps, calls 1,013 → 1,268, nothing changed). The patrol world at the spawn pose is
calmer but it is not frozen — the FieldDirector runs and LazyGroups materialize. Fixed phase order plus
bracketing is the mitigation; a long run is the hazard. And the orphan-process contamination is real
history (`:456-460`, fixed at `:743-746`) — `perf_probe.gd:246` self-quits, but **check the process
count anyway**, both sides, as the ledger records doing at `:807-808`.

**R7 — NO ROW IS WRITTEN TO `PERF_LEDGER.md` WITHOUT ITS SCALE, RENDERER AND SEED.**
(`PERF_LEDGER.md:18-25`.) Given §1a, the renderer is currently **unreadable from ProjectSettings** —
restore the key or the batch's rows violate this on arrival.

---

## 5. ASSIGNMENT 3 — THE BATCH

### 5a. Constants for every run

**Binary (use the CONSOLE build, or you get no stdout):**
```
C:\Users\caleb\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
```
`run_all_tests.ps1:22` uses this one; all ten `.bat` files use the silent one.

**Config recorded on every row:** seed 47225 · `scaling_3d/scale = 0.75` (`project.godot:308`) ·
`scaling_3d/mode = 5` (`:307`) · renderer forward_plus (**restore the key first — §1a**) · windowed
1280×720 · Intel UHD · Godot 4.7.stable · vsync off + `max_fps=0` (`perf_probe.gd:45-46`).

**Pose:** stationary at the `fsb_main` spawn, default view, hands off the mouse. This is the pose every
comparable ledger row used (`:679`, `:698`, `:815`). **Item 6 is the one that deliberately breaks it.**

**Boot is unattended.** `scripts/main/game_flow.gd:24-25` calls `start_default_operation()` directly —
the menu is bypassed, so no clicking. The probe self-quits (`perf_probe.gd:246`).

**Before each run:** confirm zero Godot processes are alive. **After each run:** confirm zero again.

**`--test-save` on EVERY item.** Non-negotiable per R6/a6: without it each run overwrites his autosave
(`game_flow.gd:363`) and a dirty campaign can change the benched geometry (`site_planner.gd:197`).

### 5b. Prerequisite decisions the Arbiter must make BEFORE he starts

| Prereq | Cost | Blocks |
|---|---|---|
| Restore `renderer/rendering_method="forward_plus"` to `project.godot` | 1 line | every row (R7) |
| Land patch **b1** (GPU/CPU-ms columns) | ~8 lines | items 1, 2, 6 |
| Land patch **b3** (re-point the two dead phase slots) | ~15 lines | **item 1 — the census** |
| Land patch **b2** (scale-ladder phases) | ~10 lines | item 2 |

**If the Arbiter declines all patches, items 3, 4, 5 and 6 still run today with zero code** — and item 1
still runs, just in its current shape where two of its four levers measure nothing. I have ordered the
batch so the no-code items are separable.

### 5c. THE BATCH — 6 items

---

#### ITEM 1 — THE CENSUS *(needs b1 + b3)* · run TWICE · ~5 min

**QUESTION:** Where do the frame's ~1,400 draw calls live *today*, by subsystem — canopy far-cards vs
structures (firebase kit + village + temple) vs characters vs water? And is the frame GPU-bound or
CPU-bound at the shipped pose? **This is the council's #1 deliverable and it answers three of the
briefing's four open questions at once.**

**COMMAND** (run it, note the output, then run the identical line a second time):
```powershell
& "C:\Users\caleb\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --path "C:\Users\caleb\RECONgame" -- --perf-probe --perf-cycle --test-save `
  2>&1 | Tee-Object -FilePath "C:\Users\caleb\RECONgame\test_results\fps26_01_census_A.log"
```
(second run: `..._census_B.log`)

**PHASES / ORDERING (A/B/A, fixed):**
`baseline → no_canopy_far → baseline_2 → no_structures → baseline_3 → no_characters → baseline_4 →
no_water → baseline_5`

**DURATION:** 5 s warmup + 9 × 7 s = 68 s of probe, per run. Two runs.

**POSITION:** stationary, spawn, no input.

**RECORD:** the full `PERF ROW` block, the `PERF DRIFT` noise-floor line, every `PERF DELTA` line, and
the `hidden=` census on each phase line. Plus every `push_warning` — **a warning means that row is
void.**

**WHAT CHANGES THE DECISION:**
- `no_structures` returns **< ~150 calls** → the firebase 9→5 material collapse cannot be "the real
  performance lever". `production/firebase_kit_phase1_read.md:261-263` gets **corrected in this
  session**, and the technical-artist's atlas plan loses its top item.
- `no_structures` returns **> ~400 calls** → the 9-slot problem is real, the claim is confirmed, and it
  competes with the canopy atlas for the engineering budget.
- `no_canopy_far` reproduces the historical **+6.3 / +7.8 / +8.0** (`PERF_LEDGER.md:875-877`) with
  ~950–1,050 calls → the canopy diagnosis survives three asset waves and the atlas keeps its ~10×
  ceiling. If it comes back **larger** (more species per bucket after the 40-species impostor wave), the
  atlas gets *more* valuable and the priority order changes.
- **GPU-ms < CPU-ms at the spawn pose** → every GPU lever in the plan (atlas, card-dist, BUCKET, scale)
  is chasing the wrong half, and the CPU section of the synthesis becomes the plan. **This single
  number can invalidate most of the council's GPU work, which is why it is item 1.**
- Two runs disagreeing outside their own printed noise floors → **nothing here is readable**, stop the
  batch and fix the instrument first.

---

#### ITEM 2 — IS THE FRAME FILL-BOUND AT ALL? *(needs b1 + b2)* · ~2 min

**QUESTION:** Does render scale still move the frame? At 0.75 the game already renders 56% of the
pixels. If dropping to 0.60 (36% of pixels) moves FPS by less than the noise floor, the frame is **not
fill-bound** and every pixel-side lever is dead — including the FSR scale dial itself, which is
currently costing sharpness for nothing.

**COMMAND:**
```powershell
& "C:\Users\caleb\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --path "C:\Users\caleb\RECONgame" -- --perf-probe --perf-scale-ladder --test-save `
  2>&1 | Tee-Object -FilePath "C:\Users\caleb\RECONgame\test_results\fps26_02_scale.log"
```

**PHASES:** `baseline(0.75) → scale_060 → baseline_2(0.75) → scale_085 → baseline_3(0.75)`
**DURATION:** 5 s + 5 × 7 s = 40 s. **POSITION:** spawn, stationary.
**RECORD:** fps, GPU-ms, CPU-ms, calls per phase; noise floor; both deltas.

**WHAT CHANGES THE DECISION:**
- 0.60 gains **< noise** → frame is call/CPU-bound. Kills scale as a lever, **and raises the question
  whether 0.75 should go back to 1.00 for free sharpness** — which is a RULE #1 *win*, not a cost.
  My OPINION: this is the highest-upside single result in the batch, because it can hand back image
  quality at zero FPS cost.
- 0.60 gains **> 4 FPS** → genuinely fill-bound; overdraw work (card fill, fog, alpha) moves up the plan.
- 0.85 costs little → he can have a sharper image now.

---

#### ITEM 3 — THE FREE CANOPY LEVER *(zero code)* · A/B/A across three boots · ~4 min

**QUESTION:** How many draw calls does pulling the far-card ring from 350 m to 250 m actually buy, and
**can he see it?** This is the one look-costing lever whose look cost he can judge in the same sitting,
and it is the cheap alternative to the `BUCKET` change.

**COMMANDS — run all three, IN THIS ORDER (A, B, A):**
```powershell
# A
& "...\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\caleb\RECONgame" `
  -- --perf-probe --test-save 2>&1 | Tee-Object "...\test_results\fps26_03a_card350.log"
# B
& "...\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\caleb\RECONgame" `
  -- --perf-probe --card-dist=250 --test-save 2>&1 | Tee-Object "...\test_results\fps26_03b_card250.log"
# A'
& "...\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\caleb\RECONgame" `
  -- --perf-probe --test-save 2>&1 | Tee-Object "...\test_results\fps26_03c_card350.log"
```

**WHY THREE BOOTS AND NOT THREE PHASES:** `view_distance` is consumed at node-construction time — it is
baked into each MultiMesh's `visibility_range` at `tree_cover_layer.gd:135` — so changing it at runtime
would not retro-apply to nodes already built. It **must** be per-boot, which means the bracketing has to
be per-boot too.

**DURATION:** each boot = 5 s warmup + one 7 s baseline window, then self-quit
(`perf_probe.gd:67-68` → single-phase list). ~12 s of probe per boot; boot dominates.
**POSITION:** spawn, stationary.
**RECORD:** fps / calls / prims / GPU-ms from each of the three. **Plus: look at run B's screenshot**
(`res://screenshots/perf_baseline.png`, written at `perf_probe.gd:177-184`) against run A's and say
whether the treeline reads short.

**READING RULE (R-specific):** this is cross-boot bracketing, which is looser than in-run bracketing.
**If the two A runs disagree by more than ~1.5 FPS, B is unreadable — discard it and do not record a
delta.** The ledger's in-run floors were 1.4 / 1.1 / 2.8 (`:875-878`); cross-boot is at least that wide.

**WHAT CHANGES THE DECISION:** a large call drop with **no visible treeline change** makes `--card-dist`
a shipped default and demotes both the `BUCKET` change and the atlas. A large call drop that he can
**see** makes it a RULE #1 loss and it is dead — and that is a *result*, not a failure.

---

#### ITEM 4 — THE `BUCKET` EXPERIMENT *(1-line patch, b4)* · ~3 min

**QUESTION:** Does `BUCKET = 128` deliver the predicted ~2.5× call cut, and does it open a visible
jungle gap? The ledger predicts both (`PERF_LEDGER.md:919-925`) but **has never measured either.**

**PATCH:** `terrain/vegetation/tree_cover_layer.gd:52`, `64.0` → `128.0`. Revert immediately after.

**COMMANDS:** the same single-baseline boot as item 3, patched and unpatched:
```powershell
# (patch applied)
& "...\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\caleb\RECONgame" `
  -- --perf-probe --test-save 2>&1 | Tee-Object "...\test_results\fps26_04_bucket128.log"
```
Bracket it with item 3's two A runs (same config, same session) rather than booting two more times.

**RECORD:** calls, fps, GPU-ms. **And walk 20 m outside the wire and LOOK** — the failure mode is a
±90 m quantisation of the 65 m near/far handoff, which shows up as either double-rendered cards or a
hole in the jungle (the historical invisible-jungle bug, `tree_cover_layer.gd:49-51`).

**WHAT CHANGES THE DECISION:** if the calls fall ~2.5× **and he cannot see it**, this one-line change
beats the entire atlas project and the atlas should not be built. If he *can* see it, RULE #1 kills it
permanently and the ledger records that it was tested, so it stops being re-litigated.
**This is a 3-minute experiment standing in front of a multi-week engineering bet.**

---

#### ITEM 5 — DOES THE NUMBER SURVIVE WALKING? *(zero code)* · ~4 min

**QUESTION:** Every FPS row in this ledger is a stationary camera pointed into the firebase interior, and
the ledger says so itself (`PERF_LEDGER.md:524`). **RULE #1 is that the world must be FUN TO WALK.**
Nobody has ever recorded the frame while walking out the wire into jungle.

**COMMAND:**
```powershell
& "...\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\caleb\RECONgame" `
  -- --test-save 2>&1 | Tee-Object "...\test_results\fps26_05_walk.log"
```
**No probe flag.** `scripts/levels/game_world.gd:476-481` already prints `[PERF] FPS=%.0f` every 2.0 s
(`WorldConfig.LOG_FPS`/`FPS_LOG_INTERVAL`, `scripts/levels/world_config.gd:28-29`) — the instrument is
already in the shipped build and costs nothing.

**PHASE / ROUTE (fixed, so it is repeatable):** stand at spawn 30 s → walk to the wire gate → 60 s
straight out into the treeline → 30 s standing in dense jungle facing *away* from the base → turn and
look back at the firebase from ~150 m for 30 s. **~2.5 minutes, then Esc → quit.**

**RECORD:** the whole `[PERF] FPS=` series with rough timestamps of each leg, and — the point of the
item — **his own verdict in words: where did it feel bad?**

**WHAT CHANGES THE DECISION:** if the jungle sightline is materially worse than the base interior, the
canopy is *underweighted* by every number in the ledger and the atlas moves up. If it is *better*, the
firebase interior is the real hotspot and the structure/material work moves up. **Either way the whole
ranking can flip, for four minutes and zero code.** My OPINION: this is the second-most-valuable item in
the batch and the one most likely to be skipped, because it produces a judgement rather than a table.

---

#### ITEM 6 — A SECOND POSE *(zero code, needs b1/b3 for the census columns)* · ~2.5 min

**QUESTION:** Does the census hold at a village, or is the whole ledger describing one unrepresentative
camera? Villages are where 26 newly-generated enterable buildings live.

**COMMAND:**
```powershell
& "...\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\caleb\RECONgame" `
  -- --perf-probe --perf-cycle --spawn-at-village --test-save `
  2>&1 | Tee-Object "...\test_results\fps26_06_village_census.log"
```
`game_flow.gd:288-304` drops the patrol 60 m off the nearest village edge; it prints `[SPAWN-DEV]` so the
log records that the pose deviated.

**DURATION:** 5 s + 68 s. **POSITION:** wherever the flag put him, stationary, no input.
**RECORD:** the same block as item 1, plus the `[SPAWN-DEV]` line so the pose is on the record.

**WHAT CHANGES THE DECISION:** if `no_structures` dominates here while `no_canopy_far` dominates at the
firebase, then **there is no single "the frame" and the plan needs two budgets, not one.** That is a
finding the council cannot reach any other way.

---

### 5d. Total wall clock, and the cut line

| Item | Machine time | Notes |
|---|---|---|
| 1 — census ×2 | ~4.6 min | 2 × (boot + 73 s) |
| 2 — scale ladder | ~1.8 min | boot + 40 s |
| 3 — card-dist A/B/A | ~3.6 min | 3 × (boot + 12 s) |
| 4 — BUCKET | ~1.2 min + look | reuses item 3's brackets |
| 5 — walk | ~4 min | includes his own play time |
| 6 — village census | ~2.2 min | |
| **Machine total** | **≈ 18 min** | assuming **boot→world-ready ≈ 60 s** |
| + patch/revert, notes, process checks, log naming | ~15 min | |
| **BATCH TOTAL** | **≈ 33–35 min** | |

**THE BOOT TIME IS UNVERIFIED AND IT IS THE ONLY THING THAT CAN BLOW THIS ESTIMATE.**
`tests/windowed_patrol_perf.gd:22` allows up to **180 s** for world-ready. I could not measure it
without running windowed Godot. **Item 1's first run tells him**: if boot exceeds ~2 minutes, the batch
is ~50 min, and the cut line applies.

**CUT LINE, in priority order — if time runs short, do 1, 2, 5 and stop.**
Item 1 is the census the council was convened for. Item 2 can invalidate half the GPU plan in 100
seconds. Item 5 is the only item that tests the thing RULE #1 actually protects. Items 3, 4 and 6 are
refinements on top.

**NOT IN THE BATCH, deliberately** — each with the evidence that kills it:
- **Shadows.** `--shadow-study` is settled: 40 m / 80 m / uncapped identical within a 0.5 noise floor,
  and ship runs them off (`PERF_LEDGER.md:704-730`, `:723-730`). Re-running it is how this gets
  re-litigated a fourth time.
- **Campfires.** `+0.0` at 47225, and unmeasurable even at seed 12 night with all four lit
  (`:846-861`). A CANON win, not a perf win.
- **Clutter.** Inside noise every single time (`:693`, `:825`, `:843`).
- **Renderer.** Closed by decree.
- **`mesh_lod` threshold (b7).** OPINION: near-zero effect on a MultiMesh-card canopy. Not worth a slot.

### 5e. A `.bat`, so the batch is repeatable next time

Every item above is a hand-typed line, and hand-typed lines are how a batch stops happening. Three
lines, matching the existing `.bat` convention (note `observation_room_routine.bat` already passes
`-- --test-save`), would fix that permanently:

```
@echo off
rem FPS CENSUS BENCH - A/B/A attribution of the shipped patrol world. Windowed, self-quitting.
"C:\Users\caleb\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --path "%~dp0" -- --perf-probe --perf-cycle --test-save
```

**Not proposed as a batch item** — it is a convenience, and the Arbiter can decide it. But note it must
use the `_console.exe`, or it produces a bench with no readable output, which is what all ten existing
`.bat` files would do today.

---

## 6. ASSIGNMENT 4 — THE CENSUS INSTRUMENT, SPECIFIED

**RECOMMENDATION: EXTEND `tests/perf_probe.gd`. DO NOT WRITE A NEW PROBE.**

Reasons, each concrete: it already owns A/B/A bracketing (`:222-233`), the printed noise floor
(`:234-235`, `:250-262`), `INSIDE NOISE` tagging (`:244`), ship-config capture at attach (`:53-58`), the
zero-count warning pattern (`:172-174`), self-quit (`:246`), the screenshot-stall fix (`:24`), and
**enrollment in `tests/test_ship_parity.gd`'s harness discovery** (`:15-21`). A new file re-earns all of
that from zero and, per R4, is exactly the "instance-shaped" mistake that let the shadow artifact move
harnesses in 2026-07-17. Extending also satisfies FOSSIL LAW by construction — there is no predecessor
left behind.

### 6a. Exact specification

**File:** `tests/perf_probe.gd` — **modify**, do not create.
**Trigger:** reuse `--perf-cycle` (re-pointing the existing phase list) rather than adding a flag. The
two levers being replaced measure nothing at the shipped seed, so nothing is lost; if a night-seed
campfire run is ever wanted again it is still reachable via `--perf-seed=12` **and would need its own
phase list** — flag that as the one thing the re-point costs.

**New phase list** (`perf_probe.gd:65-66`), same 9 phases, same 68 s:
```gdscript
_phases = ["baseline", "no_canopy_far", "baseline_2", "no_structures",
    "baseline_3", "no_characters", "baseline_4", "no_water", "baseline_5"]
```
**New bracket map** (`:222-227`): `no_canopy_far → [baseline, baseline_2]`,
`no_structures → [baseline_2, baseline_3]`, `no_characters → [baseline_3, baseline_4]`,
`no_water → [baseline_4, baseline_5]`.

**Toggle targets — exact node paths and where they are created:**

| Phase | Target | Where it lives | How to reach it |
|---|---|---|---|
| `no_canopy_far` | **far cards only** | `terrain/vegetation/tree_cover_layer.gd:135` builds the far card with `visibility_range_begin = near_distance` (65.0); `:132` builds the near solid with `begin = 0.0` | `world.vegetation_manager.find_child("TreeCoverLayer", false, false)` (already done at `perf_probe.gd:127`), then iterate its children and hide only those with `visibility_range_begin > 0.0`. **This splits the canopy number into near vs far for the first time** — the ledger asserts the near ring costs ~0 (`PERF_LEDGER.md:917-918`) but that was inferred from a node census, never measured as a delta. |
| `no_structures` | every placed structure + the firebase GLB | `scripts/world/site_planner.gd:162` adds `soft_cover`, `:164` adds `hard_surface` — **every** structure lands in exactly one of the two. `:818-819` places the `fsb_main` root with `set_meta("model_name","fsb_main")` and it is in **neither** group | `get_tree().get_nodes_in_group("hard_surface")` + `"soft_cover"`, **plus** a scan of `world.get_children()` for `get_meta("model_name","") == "fsb_main"`. Missing the fsb_main root is the obvious way to get this phase wrong. |
| `no_characters` | enemies + allies + civilians | `scripts/enemies/enemy_base.gd:252` (`enemies`), `scripts/allies/ally_base.gd:268` (`allies`), `scripts/world/civilian.gd:160` (`civilians`) | three group queries. **`.visible` only** (R5) — never disable processing, so CPU is untouched and the delta is purely render. |
| `no_water` | the combined water mesh | `terrain/water/water_system.gd:62-63` creates `WaterBodies` container; `:276-279` adds one `CombinedWater` MeshInstance3D | `world.water_system.get_node_or_null("WaterBodies")`. **`WaterSystem extends Node`, not Node3D** (`water_system.gd:1`) — hide the *container*, not the system. Expect ~1–2 calls; the value here is **fill**, so this row is only meaningful once b1 lands the GPU-ms column. |
| **terrain — NOT TOGGLED** | — | — | Hiding 25 terrain chunks leaves the player over the void and the frame stops describing anything. **Terrain's share is derived by subtraction** (total − everything toggled). **Say this on the row rather than faking a phase** — the whole point of this exercise is that an instrument must not report a number it did not measure. |

**Sub-attribution without extra phases.** The `no_structures` phase hides everything at once, but each
body carries `set_meta("model_name", ...)` (`site_planner.gd:154`) and the sub-populations are already
grouped: `flammable_structures` = village huts (`:238`), `temple_shrines` = temples (`:932`), and the
firebase-kit assets carry the `fb_` filename prefix (per the kit convention). So the phase line can
print a **static breakdown** — `structures: fb_=N village=N temple=N other=N, fsb_main=1` — which
attributes the *node population* even though only one aggregate *delta* is measured. That is the honest
split: measured delta for the aggregate, counted census for the parts, and the row says which is which.

**Row output (per phase):**
```
PERF ROW no_structures  fps_avg= 41.2 fps_min= 39.0 gpu_ms= 18.4 cpu_ms= 11.2 prims=  118432 calls=  612 objs= 1104 n=152 hidden=387 [fb_=181 village=94 temple=38 other=73 fsb_main=1]
```

**Mandatory guards, per §4c:**
- **R1** — capture each target's own `visible` in `attach()` into a dictionary; restore it in every
  non-lever phase. **Never** `node.visible = phase_name != "no_x"`. That expression *is* the retracted
  defect (`perf_probe.gd:123` as-was; `PERF_LEDGER.md:661`).
- **R2** — `hidden=<n>` on every phase line, and `push_warning` when n == 0, mirroring `:172-174`.
- **R3** — after the run, print one line per lever asserting the call/prim delta agrees in sign with the
  hidden count; flag `*** COUNTER MISMATCH — this row is instrument, not world ***` when it does not.
  **This is the eight lines that would have caught the shadow artifact on its first run.**
- **DO NOT enable per-phase screenshots.** `perf_probe.gd:97` fires only on phase 0 (or shadow-study) and
  that is deliberate: the capture stall depressed the first baseline of every run until `SCREENSHOT_AT`
  moved to 0.25 (`:24`, `PERF_LEDGER.md:747-750`). Adding a shot per phase re-introduces the stall into
  the middle of the run, where there is no clearance before `SETTLE` ends. **Take look-judgment
  screenshots in a separate non-probe pass (item 5).**

### 6b. What it costs to build

| | |
|---|---|
| Files touched | **1** (`tests/perf_probe.gd`) |
| New files | **0** — no new `.tscn`, no new `.gd`, no new probe scene |
| Lines | ~60–80: b1 (~8) + b3 phase list & brackets (~15) + four toggle branches with capture/restore (~30) + census/warning/counter-check printing (~20) |
| New systems | none. Every toggle target already exists, already carries a group or a meta, and is already reachable from `GameWorld` |
| Risk | low — `.visible` only, reversible within the run, self-quitting, auto-enrolled in the ship-parity guard |
| Estimated time | **~1 hour including the guards**, which are the majority of the value |

**Compare the alternative:** a purpose-built census probe re-implements bracketing, the noise floor,
`INSIDE NOISE` tagging, screenshot timing, ship capture and quit — 300+ lines — and it has to earn the
parity guard's trust from scratch. **The extension is 4× cheaper and strictly safer.**

---

## 7. WHAT I COULD NOT DETERMINE, AND WHY

Stated rather than estimated, per the briefing's §3.1.

1. **Boot → world-ready time.** Cannot measure without running windowed Godot. It is the single biggest
   uncertainty in the wall-clock estimate. Item 1 measures it as a side effect.
2. **The current draw-call total.** The last measurement is 1,368–1,481 (`PERF_LEDGER.md:896`) from
   2026-07-20, and **three asset waves have landed since.** I refuse to estimate it. It is batch item 1.
3. **Whether the impostor wave changed species-per-bucket.** The far-card call count is
   `(buckets in range) × (species present per bucket)` (`PERF_LEDGER.md:916-917`). Forty new card
   species could raise the second term. Determinable only from a live census — item 1.
4. **The firebase kit's actual draw-call share.** `production/firebase_kit_phase1_read.md:261-263`
   asserts the 9→5 collapse is "the real performance lever". **UNMEASURED.** Item 1's `no_structures`
   phase bounds it. Until then it must be labelled unproven, per the briefing's explicit instruction.
5. **`tree_cover_layer.gd:199 _extract_mesh` takes the first mesh only** — cited by
   `PERF_LEDGER.md:908`; I read only `:1-150` of that file. UNVERIFIED by me.
6. **`tools/diag_veg_cards.gd` and `tools/probe_vegetation.gd`** — found, not read. There may be
   vegetation-census capability there that duplicates part of §6. **The Arbiter should have someone read
   them before the census patch is written** (FOSSIL LAW: if one of them already does this, extend it or
   delete it, do not build a third).

---

## 8. THE ONE-LINE VERDICT

**Restore the renderer key, land ~33 lines of patch in one existing file, and run six items in about 35
minutes.** Two of those items — the CPU/GPU split at the shipped pose, and the walk-out — can each flip
the council's entire ranking, and neither has ever been measured. And both atlas questions have a
**free ceiling** available today: measure the ceiling before anyone budgets the implementation.
