# TECHNICAL DIRECTOR — THE 10-STEP PLAN

**Convened:** 2026-07-13 · **Engine:** Godot 4.7 stable · Forward+ (by default, never chosen) · **Jolt** (`project.godot:287`)
**Charge:** sequence the decree. Not re-litigate it. Every step independently shippable, independently verifiable.

**SKILLS LOADED (as ordered):** `godot_4.7_features.md` · `godot_standards.md` ·
GodotPrompter `godot-optimization` (frame budget, `Performance` monitors, draw calls) ·
`physics-system` (Jolt, shape cost table, **"NEVER scale a collision shape"**, Cylinder3D is Jolt-only) ·
`procedural-generation` (**"AVOID global `randf()`/`randi()`"**).

---

## THE LAW OF THIS PLAN

1. **No step depends on a later one.** Verified below, step by step.
2. **Every step names a PROBE.** ADR-015: *"mitigated" / "likely fixed" never closes anything.* Where a probe
   does not exist, **the step builds the probe FIRST and the probe goes RED.** A probe that is green the day
   it lands is a probe that scans nothing — **that is the exact `test_fossils.gd SCAN_DIRS` bug, and it cost
   this project 11 dead functions.**
3. **Steps 1–6 add ZERO frame cost and are therefore GATE-EXEMPT.** The decree says *"nothing ships before
   Phase 0."* It means **nothing that ADDS COST.** A hash that replaces a per-frame `randf()` *removes*
   cost. A deleted classifier *removes* cost. A test file costs nothing. **Steps 8, 9, 10 are the ones the
   gate binds, and they are behind it.**
4. **Steps 1–6, 8, 9 run HEADLESS.** The Summoner can stay in Blender through all of them.
   **Step 7 needs the machine — with Blender CLOSED.** A GPU-contended frame time is another lying number,
   and this project has enough.

---

## THE TABLE

| # | STEP | 4.7 / JOLT FEATURE | PROOF | SIZE | HEADLESS? |
|---|---|---|---|---|---|
| 1 | Fossil probe learns to see `terrain/` | *(harness — no engine feature, and I will not invent one)* | `test_fossils` prints a count with `terrain/` in it; canary dead func → suite RED | **30 min** | ✅ |
| 2 | Manifest-path ratchet + fix the dead `tree_ref` paths | `ResourceLoader.exists()` · **4.7 "import a 3D scene directly as a Mesh"** · **4.7 `JSON.stringify` `{}` compaction** | `test_manifest_paths` RED → fix → **PASS** | **1 hr** | ✅ |
| 3 | Build the RNG probe + capture the golden worldgen hash | **`RandomNumberGenerator`** (proc-gen skill §1) · `PackedByteArray` hashing | `test_rng_discipline` **must go RED** naming 7 sites; `test_worldgen_hash` writes the golden | **2 hrs** | ✅ |
| 4 | **CLOSE THE P0 GATE (`5i8a`)** — kill every runtime draw | **4.7 typed-return override inheritance** (compile-error gotcha on deletion) · pure `hash()` | `test_rng_discipline` **PASS** **AND** `test_worldgen_hash` **UNCHANGED** (proves it is a no-op) | **1–2 hrs** | ✅ |
| 5 | Comment purge reaches `terrain/` + comment ratchet | *(none — the COMMENT DISCIPLINE law, now a P0 defect class)* | `test_comment_debt` — shrink-only register, same shape as fossils | **1–2 hrs** | ✅ |
| 6 | Build the A/B perf harness | **`Performance.get_monitor()`** (draw calls, primitives, physics time, active bodies, VRAM) | The harness prints `scale=` and `method=` **in every summary line** | **2–3 hrs** | ✅ *(authoring)* |
| 7 | **RUN IT. SET THE GATING NUMBER.** (`mhfv`) | **`rendering_method`** (Forward+ vs Mobile: 4.5 FP16 + 4.6 debanding) · **4.7 nearest-neighbour 3D scaling filter** · **4.6 D3D12-vs-Vulkan** · **4.5 Shader Baker** | A number, at `scale=1.0`, with a **per-layer attribution table**, **committed to canon** | **½ day** | ❌ **HIS EYES. BLENDER CLOSED.** |
| 8 | **ONE CLASSIFIER.** `VegetationManager._determine_terrain_type()` dies | **4.7 `packed_prop[i] = x` no longer fires the setter** · `FastNoiseLite` (migrate, don't lose) | `test_one_classifier`: **0 disagreements** over 10,000 positions; fossil register **shrinks** | **A day** | ✅ |
| 9 | **THE PADDY BECOMES A SITE.** | **4.7 packed-array setter change** (the heightmap write — the #1 silent-no-op risk) · **4.6 SSR overhaul** (the moon on the water) | `test_paddy_field`: 6 assertions, incl. **a paddy EXISTS** (it never has) and **the riparian belt does not eat it** | **A day** *(could be two — named)* | ✅ *(+1 screenshot)* |
| 10 | **TRUNK COLLIDERS.** (`2v3t`) Destruction stays deferred. | **Jolt `StaticCompoundShape` + internal BVH** · `PhysicsServer3D.body_create/body_add_shape/`**`body_set_shape_disabled`** · **`CylinderShape3D` is reliable ON JOLT ONLY** · **NEVER scale a shape** → 16 quantized RIDs | `test_trunk_collision`: **a ray from 40 m HITS the trunk** — *the pillar, as one assertion* — plus an RID census and a zero-leak check | **A day** *(1–2)* | ✅ *(probe)* ❌ *(feel)* |

---

## STEP 1 — THE FOSSIL PROBE LEARNS TO SEE `terrain/`

**WHAT.** `tests/test_fossils.gd:6` — `const SCAN_DIRS := ["res://scripts"]`. **The entire `terrain/` tree has
never been scanned.** That is the Arbiter's own probe, and it is *why* the terrain fossils survived — and why
stale terrain comments produced **two false P0s**. Widen to `["res://scripts", "res://terrain"]`.
(`REF_DIRS` already includes `res://terrain` — only the DECLARATION scan is blind. One line.)

Then **one sanctioned `--write-baseline`.** This is the **only legitimate use of that flag in the project's
life**: it is a *first count* of a tree never counted, not a silence of a failure. The register **will jump**
before it shrinks. That is not a regression; it is the first honest number from that half of the codebase.

**PROOF.**
```
powershell -File run_all_tests.ps1 -Filter fossils
```
→ prints `scanned N files` with `terrain/` files in it and a NEW, larger `fossils now:` count.
**Then the canary:** add `func _fossil_canary() -> void: pass` to `terrain/core/gameplay_grid.gd`, re-run →
**suite must go RED** with `+ terrain/core/gameplay_grid.gd:N func _fossil_canary`. Delete it → green.
**A probe you have not watched fail is not a probe.**

**4.7 FEATURE.** None. This is harness work and I will not decorate it.

**RISK.** The register jumps and it *looks* like a regression on the scoreboard.
**EARLY WARNING:** the first person who proposes a *second* `--write-baseline` to make a number look better.
That is the one forbidden move (CLAUDE.md), and the temptation arrives exactly here.

**WHY FIRST.** Every step below deletes something. **This is the instrument that proves the deletion happened
and that nothing new died in its place.** It must exist before the first corpse.

---

## STEP 2 — THE DEAD PATHS, AND THE RATCHET THAT MAKES THEM IMPOSSIBLE

**WHAT.** `patches.json`'s `tree_ref` points at `res://assets/models/vegetation/*.glb`. **That directory does
not exist** (deleted by the restructure `615ddd0`). The files live at `res://assets/world/vegetation/`. **This
is in SHIPPED DATA, not just the generator.** Wire the trees today and all 44 load as `null`, silently.

**Build the probe first.** `tests/test_manifest_paths.gd` (new): walk every `.json` / `.tres` under `data/`,
`assets/`, `terrain/`; extract every string matching `res://`; assert `ResourceLoader.exists()`.
**ZERO TOLERANCE — no baseline, unlike fossils.** A fossil can be grandfathered because the game runs with
it; **a dead resource path is never legitimate.** Reuse `test_fossils.gd`'s `_collect()` recursive walk —
**do not write a third file-walker** (ADR-023 in miniature).

It goes **RED on `tree_ref` immediately.** Then:
1. Fix `tools/make_jungle_patches.py:978-980` → `assets/world/vegetation/`.
2. **REGENERATE `patches.json`.** Do not hand-patch generated data and leave the generator wrong — the next
   regen resurrects the corpse.
3. **THE BOOT GUARD:** in `JunglePatchLayer._load_patches()`, run every declared `res://` string through
   `ResourceLoader.exists()`. Any miss → `push_error` **naming the key and the path** and **disable the
   layer**. A data-driven path that is wrong must **never** be a silent no-op. That is precisely how 44 trees
   became invisible.

**PROOF.** `run_all_tests.ps1 -Filter manifest_paths` → **RED before, PASS after.** The probe is the receipt.

**4.7 FEATURES.**
- `ResourceLoader.exists()` — the guard.
- **"Import a 3D scene file directly as a single Mesh" (4.7).** Set the import type of `felled_trunk.glb`,
  `tree_stump.glb`, `felled_tree.glb` to **Mesh** *now*, while the paths are being touched.
  `JunglePatchLayer._load_patch_mesh()` currently does `load() → instantiate() → recursive _first_mesh() →
  queue_free()` **46 times at boot.** Do not let the next MultiMesh repeat that dance.
- **`JSON.stringify` writes `{}` compactly even with indent (4.7 gotcha).** The regenerated `patches.json`
  must be diffed with that in mind — **only the three paths may change.** Anything else in the diff is a bug
  in the regen.

**RISK.** The regen churns fields nobody meant to touch.
**EARLY WARNING:** a `git diff` on `patches.json` that is longer than three lines.

---

## STEP 3 — BUILD THE TWO PROBES THAT MAKE STEP 4 PROVABLE

**These are instruments. They ship RED. That is the point.**

### 3a · `tests/test_rng_discipline.gd` (new)
Static-scan `res://scripts` + `res://terrain` for bare `randf(`, `randi(`, `randf_range(`, `randi_range(`,
`randomize(`, `.pick_random(`, `.shuffle(` **with no `rng.` / `_rng.` receiver.** Strip comments first —
**reuse `test_fossils.gd::_strip_comments()`**, which already learned that *a comment is not a caller.*

**THE LAW IT ENFORCES** (Godot Specialist, and it should become an ADR):
> The global RNG stream is reserved for **GENERATION** and **EVENT** draws. Any **per-frame, per-query, or
> per-effect** draw MUST use a dedicated seed-derived `RandomNumberGenerator` or a pure hash. **A runtime draw
> on the global stream is a defect, because it moves the stream under everything ADR-010 promised.**

**It MUST go RED**, naming: `gameplay_grid.gd:291`, `:478`, `terrain_manager.gd:167`, `terrain_engine.gd:215`,
`damage_system.gd:254`, `:262-265`, `poisson_sampler.gd:36,37,45,53,54`.
**If it comes back green on day one, the regex is broken.** Watch it fail.

### 3b · `tests/test_worldgen_hash.gd` (new) — **THE ADR-010 GATE, FINALLY MECHANICAL**
Boot `game_world.tscn` headless at 3 fixed seeds. Hash `GameplayGrid.terrain_type` +
`vegetation_density` + `WaterSystem.water_map` as `PackedByteArray`s. Commit the goldens.

**And the assertion nobody has ever written:** build the grid twice **in the same process**, the second time
with **N dummy per-frame AI think-cycles interleaved.** *Same hash.* That is ADR-010 §16 — *"same seed, same
world, same EVENTS"* — expressed as a test instead of a promise. **Today it would fail, because the stream
position is a function of framerate.**

**PROOF.** Both probes land and both are RED/captured. **The step's deliverable IS the red.**

**4.7 FEATURE.** `RandomNumberGenerator` per proc-gen skill §1 (*"AVOID global `randf()`/`randi()` — not
reproducible"*). `PackedByteArray` hashing per `godot_standards.md` Performance Mandates.

**RISK.** The RNG regex over-matches `rng.randf()` and floods the output.
**EARLY WARNING:** more than ~10 hits. The list is known and it is 7 sites; a bigger number means the scan is
lying, and a lying probe is worse than no probe.

---

## STEP 4 — CLOSE THE P0 GATE (`5i8a`). **THE STRONGEST STEP IN THIS PLAN.**

**WHAT.**

1. **DELETE `GameplayGrid.has_line_of_sight()` (`:448-489`) WHOLE.** It has **ZERO callers** — every LOS call
   in the game goes to `CombatManager.has_line_of_sight`. It is **a dead function holding a live determinism
   violation**: the `randf()` at `:478`, a per-frame, AI-driven draw on the seeded global stream. ADR-023 says
   a superseded system does not get fixed, **it gets buried.** Deleting it kills the strobe AND the stream
   poison in one move, and removes a per-frame draw from the hot path.
2. **DELETE the unreachable paddy branches** — `:283` (`h < 5.0`) and `:290-291` (`h < 50.0` + `randf()`).
   **These are provably a no-op: 0 of 65,536 cells, measured, on a map whose floor is 87.9 m.** `:290-291`
   becomes `return TerrainType.GRASSLAND`. **This is the safest deletion in the project and it pre-clears the
   ground for Step 9.**
3. **`terrain/systems/damage_system.gd`** — its own `RandomNumberGenerator`, seeded from `world_seed`. Decal
   yaw is cosmetic, **but it draws from the SHARED stream, and explosions are player-driven and frame-timed.**
   Second contamination source. Same treatment.
4. **`terrain/core/terrain_manager.gd:167`** — `noise.seed = randi()`: seed from `world_seed`.
   **`terrain/core/terrain_engine.gd:215`** — verify `game_world.gd` always passes the mission seed; a bare
   `generate()` makes the AO a lottery.
5. **DELETE `terrain/vegetation/poisson_sampler.gd`** — 3/3 functions dead; its only reference is an unused
   `preload` const in `terrain_lab.gd:8`. **A loaded gun on the table.** Delete both.

**PROOF — AND IT IS A DOUBLE LOCK:**
- **`test_rng_discipline` → PASS.** Every runtime draw is gone.
- **`test_worldgen_hash` → UNCHANGED, all 3 seeds.** *This is the load-bearing assertion:* it proves the
  deletions in (2) are a **behavioural no-op**, exactly as measured. If the hash moves, the branches were
  **not** unreachable and everything in the decree's §1 is wrong. **The step proves its own premise.**
- The interleaved-think-cycles assertion in `test_worldgen_hash` **now passes**, for the first time.
- `test_fossils` → **register SHRINKS** (`has_line_of_sight`, `poisson_sampler`'s three).

**4.7 FEATURE.** **Typed-return override inheritance (4.7 gotcha).** In 4.7, an override of a method with a
typed return *inherits* the return type, and an override without an explicit `return` is now a **compile
error**. Before deleting `has_line_of_sight() -> bool`, grep for overrides — deleting a base method whose
override the parser was reconciling is how a "safe" deletion becomes a 4.7 parse failure. Replacement is a
**pure `hash()`**, not a roll: zero draws, and the jungle stops flickering.

**RISK.** Something calls `has_line_of_sight()` through a `has_method()` string or a `call()` and the grep
misses it.
**EARLY WARNING:** `run_all_tests.ps1` throws `Invalid call. Nonexistent function` — the harness catches
`ERROR:` on stderr **by design** (`run_all_tests.ps1:40-44`). It will not slip past.

---

## STEP 5 — THE COMMENT PURGE REACHES `terrain/`

**WHAT.** The decree upgraded COMMENT DISCIPLINE **from hygiene to a P0 defect class**, because a stale
comment in this repo has now produced **two false P0s and one bogus build order.** The purge never reached
`terrain/`. Kill, at minimum:
- `jungle_patch_layer.gd:10-11` and `:83` — the dead single-dict water format. **These generated a phantom P0
  in the council that ordered this plan.** Line 11 also asserts *"one source of truth for water"* — **there
  are six.** It states, on its face, the exact property the codebase does not have.
- `jungle_patch_layer.gd:315-319` — *"a whole chunk of rice paddy costs ONE extra draw call."* **Measured:
  178.** Delete the claim (Step 9 may make it true; until then it is a lie).
- Sweep `terrain/` for tombstones: `## used to…`, `## was a…`, `## this file used to hardcode…`.

**PROOF.** `tests/test_comment_debt.gd` (new): count comment lines per file under `scripts/` + `terrain/`
against `tests/comment_baseline.json`. **FAIL if any file's count INCREASES.** Same ratchet as the fossil
register — **shrink-only**, and for the same reason: *a law in Markdown is just the next fossil.*

**4.7 FEATURE.** None. Do not decorate this one either.

**RISK.** A count-based ratchet pressures people to delete **load-bearing** comments — the units contract, the
"do not reorder these two lines and here is the physical reason" invariant. **Those are the ONLY comments the
law permits and they must survive.**
**EARLY WARNING:** a diff where the deleted comment names a **unit** (`metres`, `Hz`, `0-1`) or an **ordering
constraint**. That is not debt; that is the one kind of comment worth having.

---

## STEP 6 — BUILD THE PERF HARNESS (authoring is headless; running is not)

**WHAT.** `tests/perf_probe.gd` exists and is nearly useless for this: it boots the world, samples FPS, and
gates on 30. **It does not say what resolution it measured at, and it does not isolate the jungle.** Every FPS
number this project has ever quoted was taken through it, at **`scaling_3d/scale = 0.77` → 59.3% of native
pixels**, and **no document says so.**

Rebuild it as a **gating A/B harness**:
- **Every summary line self-describes or it is void:**
  `PERF SUMMARY: avg=… min=… scale=1.00 method=forward_plus driver=vulkan draw_calls=… tris=…`
- **Layer toggles** via `OS.get_cmdline_user_args()`: `--no-patches`, `--no-billboards`, `--no-water`,
  `--terrain-only`. **This is the number nobody has: what FRACTION of the frame is the jungle?**
- **`Performance.get_monitor()` dump** (godot-optimization skill §1, Monitors table):
  `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` · `RENDER_TOTAL_PRIMITIVES_IN_FRAME` · `TIME_PROCESS` ·
  `TIME_PHYSICS_PROCESS` · `PHYSICS_3D_ACTIVE_OBJECTS` · `RENDER_VIDEO_MEM_USED`.
  **`TIME_PHYSICS_PROCESS` is the one that prices Step 10 before it is written.**
- **It must stand in `patch_tangle`** (the worst tile: 4 trees, ~21k tris) **with ~30 enemies moving**, or it
  is not measuring the game — it is measuring an empty field.

**PROOF.** The harness runs and prints a per-layer table. **The step's deliverable is the instrument, not the
number** — the number is Step 7.

**4.7 FEATURE.** `Performance.get_monitor()` — the monitor set above.
Frame budget, stated (godot-optimization §1): **30 FPS = 33.3 ms. 60 FPS = 16.6 ms.** No system may own the
majority of it.

**RISK.** The toggles change the scene in a way that changes *more* than the layer (e.g. disabling patches
also drops the water buckets), and the attribution table lies.
**EARLY WARNING:** the layer deltas do not sum to the total. If `terrain-only + patches + billboards + water`
≠ `full`, the harness is wrong and **must not be trusted for the gate.**

---

## STEP 7 — **RUN IT. SET THE GATING NUMBER.** (bead `mhfv`) 🔴 **NEEDS HIS MACHINE**

**WHAT.** Every number this project owns is void until this runs.

1. **SET `rendering/renderer/rendering_method` EXPLICITLY.** It is **not in `project.godot` at all** — the
   project has been silently Forward+ for its entire life. **Nobody chose it.** On an Intel UHD, Forward+ pays
   for clustered-light and GI machinery a PSX game does not use. **A/B it against Mobile** — 4.5's explicit
   FP16 pipeline and 4.6's debanding-on-Mobile removed the last visual objections. Mobile loses volumetric
   fog / SSR / SDFGI; a jungle wants distance fog anyway, **which is cheaper.**
2. **SET `scaling_3d/scale = 1.0`. RE-MEASURE.** State the scale in the number, forever.
3. **THE FSR TRAP.** `scaling_3d/mode = 1` is **FSR 1.0 — it SPENDS GPU time to upscale.** Godot **4.7's
   nearest-neighbour 3D scaling filter** is **cheaper AND more PSX**. A/B it. If a low `scale` is needed after
   all, take it with **nearest**, not FSR — the aesthetic *improves*.
4. **A/B THE DRIVER.** 4.6 made **D3D12** the default for *new* Windows projects; this one predates that and
   is on Vulkan. **Intel UHD Vulkan drivers are historically weak.** `rendering/rendering_device/driver`.
   This is free money and it is one line.
5. **A/B THE LAYERS** (Step 6's toggles). Attribute the frame.
6. **`Shader Baker` (4.5) in the release preset.** Kills first-use material hitches (measured 20× load-time
   wins). Not a frame-rate fix — a *hitch* fix — and the jungle instantiates materials at runtime.
7. **FREE, ALREADY BANKED, DO NOT "OPTIMIZE" AGAIN:** 4.7 *unique environment buffers per render pass* and 4.6
   *octahedral probe maps* are automatic. And **`IN_SHADOW_PASS` buys this project ZERO** — every patch bucket
   already sets `SHADOW_CASTING_SETTING_OFF` (`jungle_patch_layer.gd:412`, `:434`). **The jungle casts no
   shadows. There is no shadow pass to skip.**
8. **NEVER, on an Intel UHD:** `AreaLight3D` (the engine's most expensive light) · Vulkan raytracing
   (experimental).

**PROOF.** A **NUMBER**, at `scale=1.0`, with a **per-layer attribution table**, **written into canon** (ADR /
charter). *"It feels better"* does not close this. **The gate is a number or it is not a gate.**

**SIZE.** ½ day.

**RISK.** It comes back **12–16 FPS at native**, and Step 10's trunk colliders do not ship as specced.
**That is not a failure of this step — that is this step working.**
**EARLY WARNING — AND IT IS THE ONE TO WATCH:** if `--no-patches --no-billboards` FPS ≈ full-scene FPS, **the
jungle is not the bottleneck** and this project has been blaming the wrong system for weeks. Then the answer
is upstream (terrain mesh, water's 178 draw calls/chunk, the renderer itself) and **the whole cost model in
the decree is wrong.**

> 🔴 **RUN THIS WITH BLENDER CLOSED.** A frame time measured while a DCC app holds the GPU is **another lying
> number.** This project's entire perf history is lying numbers. Do not add one.

---

## STEP 8 — **ONE CLASSIFIER.** `VegetationManager._determine_terrain_type()` DIES.

*(Gated on Step 7 — but note it REMOVES a classifier, so it is cost-negative.)*

**WHAT.** There are **two independent terrain classifiers** at two resolutions with two RNG streams:
`GameplayGrid._determine_terrain_type()` (5 m cells — decides the **wade, the drag, the sight cap, the
leeches**) and `VegetationManager._determine_terrain_type()` (8 m bundles — decides **what you SEE**, because
`JunglePatchLayer` stamps the art from it). `TERRAIN_WORKFLOW.md §6` claims *"you cannot desync them."*
**The Level Designer proved that FALSE.** They agree today **only because both are empty** — the bug is hiding
the bug.

- **`GameplayGrid` becomes the sole classifier.** `VegetationManager` **samples the grid it is handed.**
- **MIGRATE, DO NOT LOSE:** VegMgr's `FastNoiseLite` patch coherence and water-proximity terms are **better
  than what GameplayGrid has.** This is a **merge**, then a deletion.
- **DELETE:** `VegetationManager._determine_terrain_type()` (`:294-326`) · `TerrainManager.near_water_mask` +
  `is_near_water()` (a third water mask whose only caller is the classifier being deleted).
- **RE-ORDER BOOT:** the grid must be built **before** chunks materialise. Today it is the reverse.

**PROOF.**
- **`tests/test_one_classifier.gd` (new):** sample 10,000 world positions; assert `VegetationManager`'s terrain
  type **equals** `GameplayGrid`'s. **0 disagreements.** Today this probe cannot even be written — there are
  two answers. After this step there is one, and the probe is trivially true *and permanently enforced.*
- `test_fossils` → register **SHRINKS** by `_determine_terrain_type` (veg), `near_water_mask`, `is_near_water`.
- `test_worldgen_hash` → **re-blessed ONCE**, in this commit, **named in the decree.** A golden that changes
  without a decree naming it is a golden nobody can trust.
- `tests/test_world_boot.tscn` + `tools/probe_jungle_patches.gd` → still green (the art still stamps).

**4.7 FEATURE.** **`packed_prop[i] = x` NO LONGER FIRES THE PROPERTY SETTER (4.7 gotcha).** The 4.7 brief
names this exact codebase: *"audit terrain/heightmap code that writes `packed_prop[i] = x` expecting a setter
to rebuild meshes."* Re-ordering boot and re-plumbing who writes the grid is **precisely where this bites** —
code that relied on a per-element write triggering a rebuild **silently breaks.** Reassign the whole array or
call the rebuild explicitly. Also `FastNoiseLite` (the coherence term being migrated).

**RISK.** **The boot sequence.** *"Boot sequences are where the bodies get buried."* (Lead Programmer.)
**EARLY WARNING:** chunks materialise with the **wrong art** (patch density classes flip), or `is_world_ready`
fires before the grid exists. `probe_jungle_patches` prints the class histogram — **compare it before and
after. It should barely move.** If the histogram lurches, the merge lost the noise.

---

## STEP 9 — **THE PADDY BECOMES A SITE, NOT A CELL TYPE.** (the Summoner's actual ask)

**WHAT.** **There are ZERO rice paddies. Not one, on any map, ever** — 0 of 65,536 cells. And even with the
elevation gate fixed, `_apply_riparian_belt()` converts any cell within 22 m of water whose density is under
0.55 into jungle. **Paddy density is 0.2.** The belt skips CLIFF and WATER — **not PADDY.** *A paddy could
only survive where it could never be irrigated.* **A perfect inversion of reality, and nobody wrote it on
purpose.**

**THE RULING: `WaterSystem` is the ONE oracle — READ to site the paddy, WRITTEN by the paddy.**

A seeded **field pass**, after `WaterSystem`, **before chunk meshing**:
1. **SITE (read the water).** Flood-fill contiguous **3–12 tile** polygons on slope < ~4°, near the **real D8
   network in `water_map`** (not `near_water_mask` — that is blind to every pond, lake and swamp), **below an
   elevation PERCENTILE of this map's own range — never an absolute metre value again.** That is what kills
   the 87.9 m bug **at the root.** Seeded from the province seed.
2. **STAMP (write the water).** **Terrace AND FLATTEN the heightmap** — reuse `ClearingSystem`'s
   `terrain_manager.modify_terrain`; **do not write a second deformer** (ADR-023). **RAISE THE BUNDS INTO THE
   HEIGHTMAP (+0.35–0.45 m), DROP THE PANS (−0.25–0.35 m).** Then **write water back into `water_map`** as
   `Type.PADDY`, depth **0.25–0.40 m**.
3. **THE BELT EXEMPTS THE PADDY.** One condition. **This is the single most likely way this ships broken.**
4. **`get_water_type() != PADDY`** at the seven `is_water()`-as-*"do not place here"* sites
   (`mission_generator:186`, `site_planner` ×5, `survive_waves:110`) or objective placement starves.

**BUNDS IN THE HEIGHTMAP, NOT IN COLLIDERS.** Collision, prone cover, navmesh, and the water's basin **all come
free, at ZERO draw calls and ZERO colliders** — and the paddy becomes a **decision** (dry bund: fast, quiet,
**silhouetted** · pan: 55% speed, ×2.2 noise, prone-able) instead of a **punishment**. **Pillar 3.**

**PROOF — `tests/test_paddy_field.gd` (new). Six assertions, at 3 seeds:**
1. **A PADDY EXISTS.** `count > 0`, within a sane band. *It has been 0 forever, and the boot log said so on
   every run since it shipped, and nobody read it.*
2. **IT IS WET.** Every paddy cell: `water_system.get_water_depth() ∈ [0.25, 0.40]`. **This is the Summoner's
   whole complaint, as one assertion** — the wade fires, the leeches bite, the ×2.2 noise wake exists.
3. **IT IS A FIELD, NOT A DITHER.** Every field's flood-fill size ≥ 3 tiles, contiguous.
   *(Today: 76% of paddy tiles would render as the treeline edge tile, and `patch_paddy_quad` on ~5%.)*
4. **THE GROUND DOES NOT PUNCH THROUGH.** Max ground-height variance within a pan **< 0.05 m.** The pan sits
   **5.5 cm** above ground — **5.5 cm over a 12 m tile is 0.26° of slope**, and tiles place on up to **26°.**
   *This is arithmetic, not a risk.* **Flattened, not merely terraced.**
5. **THE BELT DOES NOT EAT IT.** Zero paddy cells converted by `_apply_riparian_belt()`. **The trap, as a
   test.**
6. **OBJECTIVES STILL PLACE.** Placement success rate unchanged at the same seeds.

Plus: `test_worldgen_hash` re-blessed (deliberately, decree-named). Plus **one screenshot** — *does it read as
a rice paddy?* **That one needs his eyes.**

**4.7 FEATURES.**
- **`packed_prop[i] = x` no longer fires the setter (4.7).** **This step writes the HEIGHTMAP.** If the bund
  write relies on a per-element setter to trigger a mesh rebuild, **the bunds are ghosts and the step ships as
  a silent no-op** — the exact bug we set out to fix, with extra steps. **Name it, then test it (assertion 4).**
- **SSR overhaul (4.6)** — *"higher quality at REDUCED GPU cost."* A paddy under open sky is the **one place in
  this game SSR could earn its keep**: at night a flooded paddy is **a mirror with the moon lying flat on it,
  and you a silhouette walking across the moon.** Pillar 2, and it is the picture on the box. **Measure it
  with Step 6's harness; it is opt-in and it is the first honest reason to turn it on.**
- **Paddy water must NOT share `water_swamp.gdshader`** — that material is authored as *stagnant muck*
  (`muck_intensity 0.4`), correct for a creek under canopy and **exactly wrong for a sheet of sky lying on the
  ground.**

**SIZE.** **A day — and it is the one step that could eat two.** I am naming that now rather than discovering
it at 6 pm.

**RISK.** **Generation order.** The pass must run **after `WaterSystem` and BEFORE chunk meshing / collider
cooking.** Run it late and **the bunds are ghosts you walk through.**
**EARLY WARNING:** walk into a bund and pass through it. **Assertion 4 catches the visual half; add an
ordering assert** (`paddy_pass_done` before `cook_colliders`) for the collision half.
**SACRIFICE, NAMED (the decree binds me):** **he gets FEWER paddies.** Rare, deliberate, real ones with quads.
**Some missions will have none.** That is the cost of a paddy being a *site* and not a coin flip — and it is
what a province actually looks like.

---

## STEP 10 — **TRUNK COLLIDERS.** (bead `2v3t`) **The tree you dive behind stops the bullet.**

**WHAT.** ~**16,000 standing trees** in a 1280 m AO (**not 44** — 44 is what he *authored*; the map stamps them
~365× each). All 25 chunks stay resident for the whole mission (**ADR-013**) — **there is no "only the near
chunks pay."**

**THE ARCHITECTURE — `PhysicsServer3D`-DIRECT CHUNK COMPOUNDS. ZERO SCENE-TREE NODES.**

| Approach | Nodes | Verdict |
|---|---|---|
| `StaticBody3D` per tree | **32,000** | **~50–65 MB of node overhead + a 0.5–0.8 s load stall.** *The scene tree dies, not the physics.* |
| One body per chunk, a `CollisionShape3D` child per tree | **16,000** | Halves it. Still 16,000 nodes holding a radius and a transform. |
| **`PhysicsServer3D` direct** | **ZERO** | **25 body RIDs · 16 shared shape RIDs · 16k shape entries.** |

- **25 static body RIDs** — `body_create()`, `BODY_MODE_STATIC`, layer 1 (`world`), mask 0.
- **16 SHARED, QUANTIZED `CylinderShape3D` RIDs.** Measured `r` **0.259–0.427 m**, bole `h` **5.84–9.61 m** →
  **4×4 radius/height buckets.** Max radial error **±2.5 cm on a 30 cm trunk.**
  **QUANTIZE — NEVER SCALE.** `physics-system` §1, the critical rule: *"NEVER scale collision shapes — scaled
  shapes produce incorrect collision results."*
- **`body_add_shape(body, shape, xform)`** per tree — pure **translate + yaw**, no scale, ever.
- **~646 shapes per body.** **Jolt compiles that into a `StaticCompoundShape` with an internal BVH.** A bullet
  ray = **one broadphase hit (25 AABBs) + one ~O(log 646) descent.** Cheaper than a 16,000-body broadphase by
  a lot. **On GodotPhysics this bet LOSES. On Jolt it WINS.**
- **Fell = `body_set_shape_disabled()`. NEVER `body_remove_shape()`** — removal **reindexes** and invalidates
  all 16,000 stored indices in one call. **This is the whole reason the architecture holds together.**
- **Registry: parallel `PackedInt32Array` / `PackedFloat32Array`** (~640 KB). **NOT** Dictionary-of-Dictionary
  (**8 MB** + a hash lookup per query). `godot_standards.md`, Performance Mandates.
- **`free_rid()` EVERY body and shape in `_exit_tree()`** — RIDs are invisible to the scene tree. No group, no
  `queue_free()`, **and no `Object Count` monitor tick when you leak one.** **MissionScope registration is
  mandatory (ADR-010 §19).** *A static without a MissionScope entry is a defect.*
- **NavBaker:** `nav_baker.gd:241` scans `get_tree().get_nodes_in_group("nav_blockers")`. RIDs are not in
  groups. **Feed it an AABB query into `TreeRegistry` instead of a 16,000-node group scan.** Ten lines, and
  **strictly faster than what the plan proposed.**

**🔴 DESTRUCTION IS DEFERRED.** No bitmask. No shader edit. No fall. It was **CUT 24 hours ago** by the 07-12
council (blocked by `vtiz`, still OPEN), and re-thawing it now is the **fifth** feature to jump the queue.
> *"Standing trunks alone deliver Pillar 3's promise for zero vertex cost. Destruction is the luxury; cover is
> the pillar."* **Ship the pillar.**

**PROOF — `tests/test_trunk_collision.gd` (new, headless):**
1. **THE PILLAR, AS ONE ASSERTION.** Boot a chunk. Take a known trunk's world position and radius from the
   registry. Fire `PhysicsDirectSpaceState3D.intersect_ray()` from **40 m** at its centre, mask = layer 1.
   **ASSERT IT HITS, at the trunk's surface, ±the quantization error.** *That is the bead. That is the pillar.
   That is `2v3t` closed, mechanically.*
2. **RID CENSUS.** Exactly **25** bodies; **≤16** shapes; `body_get_shape_count(chunk)` **==** the registry's
   tree count for that chunk.
3. **THE REINDEX TRAP, AS A TEST.** `body_set_shape_disabled(idx, true)` → the ray from (1) now **MISSES**,
   **AND every other stored shape index still resolves to the same tree.** *This is the assertion that makes
   `body_remove_shape()` impossible to reintroduce by accident.*
4. **ZERO LEAK.** Extend `tests/test_mission_scope.tscn`: RID count before mission **==** after teardown.
   **Miss one `free_rid()` and you leak 25 bodies per mission, invisibly, forever.**
5. **THE PRICE, RE-MEASURED.** Re-run Step 7's harness. **`TIME_PHYSICS_PROCESS`, before and after.**

**4.7 / JOLT FEATURES (this step is 100% Jolt-dependent):**
- **Jolt is the non-experimental default (4.6)** and this project is on it (`project.godot:287`).
  **`CylinderShape3D` is listed reliable ON JOLT ONLY** (physics-system §5: *"Cylinder3D — Jolt only, unstable
  on GodotPhysics"*). **The entire architecture is legal only because of that line.**
- **Jolt's separate static quadtree + `StaticCompoundShape` with an internal BVH.**
- `PhysicsServer3D.body_create()` / `body_set_mode()` / `body_add_shape()` / **`body_set_shape_disabled()`**.
- **Physics interpolation is ON** (`project.godot:288`). Static RID bodies never move → nothing to interpolate,
  no `reset_physics_interpolation()` needed. **Confirmed, not assumed.**

**RISK — AND IT IS THE REAL ONE, AND THE PLAN THAT PRECEDED THIS ONE NEVER NAMED IT:**
> **`CharacterBody3D.move_and_slide()` now sweeps a capsule against a 646-shape compound EVERY PHYSICS TICK.**
> **The jungle had ZERO collision before this.** The player **and ~30 enemies** each pay a narrowphase descent
> per tick they did not pay yesterday. And `enemy_base._move_toward()` only uses the navmesh **inside
> NavBaker's site islands — across ~95% of the AO, enemies AND the player's own squad bee-line on
> `move_and_slide()`.**

**EARLY WARNING:** `TIME_PHYSICS_PROCESS` jumps in the Step 7 harness · the squad starts **grinding** into
trunks in open jungle · a "bullet went through the tree" report (mitigation: **build the `ImmediateMesh` debug
draw of the chunk compound FIRST, not after the first bug report** — 16,000 colliders you cannot click in the
remote inspector).
**SACRIFICE:** **the jungle can no longer be walked through.** He will bump into trees he used to ghost
through. **It is correct** — *cover that does not collide is cover that lies, and in an E&E run that lie is a
death* — **but he will feel it in the first thirty seconds, and he should hear it from us first.**

---

## THE LANDMINES — CARRIED FORWARD, NOT LOST

*(All five are already defused inside the steps above. Restated so no future session steps on one.)*

1. **`DESTRUCTIBLE_JUNGLE_PLAN §C2` IS OFF BY ONE.** The plan says `COLOR.b = (slot+1)/24`, slots 0..23.
   **The SHIPPED DATA is `slot/24.0`, slot 1-BASED (1..5).** Implement the plan literally and **you fell the
   NEIGHBOURING tree.** *(Deferred with destruction — but **fix the plan document now, while it is free**, or
   it detonates the day the thaw is granted.)*
2. **TWO MULTIMESHES PER BUCKET** (near + `_far`, `jungle_patch_layer.gd:303` / `:311`). Flip the bit on one
   and **the tree vanishes up close and still stands at 60 m.** *(Deferred with destruction.)*
3. **`test_fossils.gd` NEVER SCANS `terrain/`.** → **STEP 1.**
4. **The pan sits 5.5 cm above ground, on slopes up to 26°.** → **STEP 9, assertion 4.**
5. **`get_cover()` IS A FOSSIL** — declared, read by nothing. The paddy's `cover = 0.1` **does nothing.**
   Concealment comes entirely from `vegetation_density`. → triage in **STEP 1**'s widened register: **wire it
   or bury it. Do not leave a lie in the map that reads as load-bearing.**

---

## THE SCHEDULE, HONESTLY

| While he is in Blender (**headless, today**) | Needs the machine / his eyes |
|---|---|
| **1** fossil probe sees `terrain/` · **2** dead paths + ratchet · **3** the two probes go RED · **4** **the P0 gate closes** · **5** comment purge · **6** perf harness authored | **7** **RUN THE PERF GATE — Blender CLOSED** |
| **8** one classifier · **9** the paddy field pass · **10** trunk colliders *(all three gated on 7)* | **9** one screenshot: *does it read as a paddy?* · **10** the movement-feel regression |

**Steps 1–6 are ~8 hours of headless work that require nothing from him and close a P0 GATE bead (`5i8a`) on
the way.** They are the correct thing to do **right now, while he poses in Blender.**

**Step 7 is the hinge.** Steps 8–10 are priced against a number that does not exist yet, and **I will not
pretend otherwise.**

---

*The Council advises. The Summoner decides.*
