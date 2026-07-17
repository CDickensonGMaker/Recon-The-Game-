# LEAD PROGRAMMER — THE 10-STEP EXECUTION PLAN

**Charge:** dependency order + exact files. The analysis is closed; this is the build order.
**Binding law:** ADR-023 (FOSSIL LAW — the predecessor dies in the same change) and COMMENT DISCIPLINE.

---

## 0 · THE DEPENDENCY GRAPH — AND THE CYCLE NOBODY MEASURED

The Level Designer warned that *"worldgen order becomes brittle."* **It is worse than brittle. The
order the decree requires DOES NOT EXIST TODAY.** Measured boot sequence:

```
terrain_manager.generate_terrain(seed)                     terrain_manager.gd
  :124   terrain_generator.generate(seed)          -> heightmap
  :140   _extract_and_carve_rivers()
  :141   _build_water_proximity_mask()             -> near_water_mask
  :146   _load_initial_chunks_async()              -> MESHES + COLLIDERS COOKED
                                                      VegetationManager._chunk_terrain built
                                                      JunglePatchLayer stamps the art
  :151   _build_river_meshes()
  :155   terrain_ready.emit()
game_world._on_terrain_ready()                             scripts/levels/game_world.gd
  :149   water_system.initialize(...)              <- WATER IS BUILT *AFTER* THE COLLIDERS
  :152   water_system.generate_water_bodies()
  :153   generate_wetness_texture()
  :158   gameplay_grid = GameplayGrid.new()        <- THE GRID IS BUILT *AFTER* THE ART
  :162   gameplay_grid.build_from_terrain()
```

**The paddy pass must READ `WaterSystem` and WRITE the heightmap BEFORE colliders cook.** WaterSystem
runs *after* colliders cook. **That is a cycle, not an ordering preference.**
**And killing VegetationManager's classifier requires `GameplayGrid` to exist before chunks load** —
today it is built two steps later. **Both blockers are the same blocker.**

> ### ⇒ THE BOOT RE-ORDER (STEP 6) IS THE KEYSTONE. Nothing from Phase 2 or 3 can land before it.
> It is also the single change most likely to break the world, so it ships ALONE and PROVES ITSELF
> BIT-IDENTICAL before one line of paddy code is written.

### The hard edges

| Constraint | Why |
|---|---|
| **1 → everything** | Perf baseline must be taken **before** cost is added, or no regression can ever be attributed. `scaling_3d/scale = 0.77` makes every existing number a lie. |
| **2 → 9, 10** | Dead `tree_ref` paths + the off-by-one in the plan doc must die before anyone touches a tree or a shader. |
| **3, 4 → 5** | The terrain/ fossils must be DELETED before the probe is widened, or the grandfathered residue enshrines the debt we are here to kill. |
| **5 → 6…10** | The probe must see `terrain/` **before** new terrain/ code is authored, so every new symbol is born under the law. |
| **6 → 7, 8** | See the cycle above. |
| **7 → 8** | Two classifiers cannot be made to agree about a paddy. Kill the second one, *then* teach the survivor what a paddy is. |
| **8 → 9** | The art stamps from `RICE_PADDY` cells. Until the pass writes them, there are none — **0 of 65,536, measured.** |
| **1 → 10** | Trunk colliders ship only against a gating FPS number. |

---

## STEP 1 · MEASURE. NATIVE RESOLUTION. THE GATE. (bead `mhfv`)

**WHAT.** Set `scaling_3d/scale = 1.0`, confirm `rendering_method`, and profile the jungle at **native
pixels** from three fixed camera stations: open grassland, medium jungle, and standing inside
`patch_tangle` (4 trees, 21k tris). Report FPS · draw calls · primitives, split by system (patch
MultiMeshes / billboards / water / terrain). **Publish the gating number.** Every FPS figure this
project has quoted for weeks is void until this runs.

**FILES.**
- `project.godot:295` — `rendering/scaling_3d/scale` 0.77 → **1.0**; `scaling_3d/mode = 1` (FSR 1.0)
  → evaluate nearest-neighbour (cheaper *and* more PSX).
- **NEW: `tools/probe_jungle_perf.gd` + `.tscn`** — windowed (not headless; GPU timings need a
  swapchain). `Performance.get_monitor(TIME_FPS / RENDER_TOTAL_DRAW_CALLS_IN_FRAME /
  RENDER_TOTAL_PRIMITIVES_IN_FRAME)`, 120-frame average per station.

**WHAT DIES.** Nothing yet. **But name the ledger:** `scripts/levels/world_config.gd`'s FPS-fallback
ladder is read by **nothing** (CLAUDE.md, MISSING FEATURE). This step either wires it or it is
scheduled for the axe. Do not let it survive this plan unexamined.

**PROOF.** `tools/probe_jungle_perf.tscn` prints the table. The number goes into bead `mhfv` and
becomes the pass/fail line for Step 10.

---

## STEP 2 · CLEAN THE MAP: THE COMMENT PURGE, THE DEAD PATHS, THE RATCHET

**WHAT.** Three things that share one cause — **prose the code does not honour.** Two false P0s and
one bogus build order came out of this file tree in two days.

1. **Purge the tombstones in `terrain/`.**
2. **Fix the dead `tree_ref` model paths in the GENERATOR, then re-emit the data.** Never hand-patch
   generated JSON — the generator is the source of truth or the next regen resurrects the corpse.
3. **Add the loud boot guard + the manifest ratchet**, so a dead `res://` path can never again ship
   as a silent no-op.
4. **Correct `DESTRUCTIBLE_JUNGLE_PLAN.md` §C2** — the shipped data is `slot / 24.0`, **1-based**.

**FILES.**
- `tools/make_jungle_patches.py:978-980` — `res://assets/models/vegetation/` →
  `res://assets/world/vegetation/` (`felled_tree.glb`, `felled_trunk.glb`, `tree_stump.glb`;
  confirmed on disk). Re-run the generator → `assets/world/vegetation/patches/patches.json`.
- `terrain/vegetation/jungle_patch_layer.gd` `_load_patches()` — walk **every `res://` string the
  manifest declares** through `ResourceLoader.exists()`. Miss → `push_error` naming key + path, and
  `enabled = false`. **Fail the layer; never spawn nothing quietly.**
- **NEW: `tests/test_manifest_paths.gd` + `.tscn`** — every `res://` string in every `.json`/`.tres`
  resolves. **Zero tolerance, no baseline.** A fossil can be grandfathered; a dead resource path
  never can. Reuse the recursive walk from `tests/test_fossils.gd`'s `REF_DIRS` scan. ~20 lines.
  Register it in `run_all_tests.ps1` (it auto-globs `tests/test_*.tscn` — nothing to edit).
- `production/DESTRUCTIBLE_JUNGLE_PLAN.md` §C2 — fix the doc, **not the data**.

**WHAT DIES (ADR-023 / COMMENT DISCIPLINE).**
- `jungle_patch_layer.gd:10-11` — *"declares its flooded pan … ("water": {level, half, at})"*. **A
  format that never shipped. This sentence generated a phantom P0 in this council.** DELETE.
- `jungle_patch_layer.gd:83` — `## name -> {level: float, half: float, at: [x, y]}`. Same corpse. DELETE.
- `jungle_patch_layer.gd:316-320` — *"a whole chunk of rice paddy costs ONE extra draw call."*
  **Measured: 178.** DELETE the claim now; **Step 9 makes it true.**
- `jungle_patch_layer.gd:11` — *"one source of truth for water."* It loads `water_swamp.gdshader`
  while `WaterSystem` renders `water_static.gdshader`. **Two shaders, two meshes.** DELETE.
- `gameplay_grid.gd:151-153` — *"Four tables must agree or the jungle lies."* After Step 7 there are
  two. Rewrite to the truth or delete.
- The `assets/models/vegetation/*` strings in the regenerated `patches.json`.

**PROOF.** `tests/test_manifest_paths.tscn` (new, green). `tools/probe_jungle_patches.gd` still green.
`grep -rn "assets/models/vegetation" .` → **zero hits.**

---

## STEP 3 · DETERMINISM: KILL THE RUNTIME DRAWS ON THE SEEDED STREAM

**WHAT.** The global RNG **is** seeded (`game_flow.gd:184`). The break is **stream-position
contamination**: per-frame draws move the stream under every generation and event roll ADR-010
promises. **A runtime draw on the global stream is a defect.**

**FILES.**
- `terrain/core/gameplay_grid.gd:448-489` — **`has_line_of_sight()` has ZERO callers** (every LOS call
  goes to `CombatManager.has_line_of_sight`). It holds `randf()` at **`:478`** — a 30%-per-cell block
  roll, re-rolled **every 0.15 s AI think**, at framerate-dependent frequency. **A dead function
  holding a live determinism violation and a LOS strobe light.** → **DELETE THE FUNCTION.** Do not
  hash it, do not fix it. ADR-023: it is a FOSSIL. *(If a future caller needs it, it comes back as a
  pure hash of the cell + `world_seed` salt — zero draws. Not today.)*
- `terrain/vegetation/poisson_sampler.gd` — bare `randf()`/`randi()` at `:36,37,45,53,54`. **3/3
  functions dead.** Sole reference is an unused `preload` const at `terrain/scenes/terrain_lab.gd:8`.
  → **DELETE THE FILE AND THE PRELOAD.** A loaded gun on the table.
- `terrain/systems/damage_system.gd:254, 262-265` — bare `randf()` for decal yaw + scorch scatter,
  **drawing from the shared stream**, on a player-driven, frame-timed path. → dedicated
  `RandomNumberGenerator` seeded from `world_seed`.
- `terrain/core/terrain_manager.gd:167` — `noise.seed = randi()` in `_generate_fallback_terrain()`.
  The heightmap seed drawn from the stream and **stored nowhere.** → seed from the map seed.
- `terrain/core/terrain_engine.gd:215` — `randomize_seed()`. **Verify `game_world.gd` always passes
  the mission seed**; a bare `generate()` makes the AO a lottery.

**WHAT DIES.** `GameplayGrid.has_line_of_sight()` (whole function, `:448-489`) ·
`terrain/vegetation/poisson_sampler.gd` (whole file + `.uid`) · `terrain_lab.gd:8 PoissonSamplerClass`.
*(The two **worldgen** `randf()`s at `gameplay_grid.gd:283-284` and `:290-291` die in **Step 8** —
they die WITH the branch they gate, not before it, or the paddy loses its only spawn path mid-plan.)*

**PROOF.** `tests/test_seed_replay.tscn` green. **New assertion, and it is the real one:**
`grep -rnE "(^|[^.a-zA-Z_])(randf|randi|randfn|randomize)\(" terrain/ scripts/` → every surviving hit
is `rng.`-qualified or a named cosmetic exception. Run the grid build twice in one process → `0 /
65536 cells differ` (it passes today **only because the branch is unreachable** — after Step 8 this
becomes a real test).

---

## STEP 4 · THE TERRAIN FOSSIL SWEEP (triage, then bury)

**WHAT.** Eleven dead water/query functions in `terrain/`. Triage per ADR-023 — **dead ≠ delete.**

**FILES / SYMBOLS.**

| Symbol | File:line | Verdict |
|---|---|---|
| `is_wadeable()` | `gameplay_grid.gd:430` | **UNFINISHED** — never wired to movement. **CUT.** |
| `requires_boat()` | `gameplay_grid.gd:435` | **UNFINISHED** — no boats on the roadmap. **CUT.** |
| `get_water_flow()` | `gameplay_grid.gd:423` | **FOSSIL.** **CUT** (and its `get_flow_at` delegate chain). |
| `get_cover()` | `gameplay_grid.gd:377` | **FOSSIL.** The paddy's famous `cover = 0.1` **does nothing.** **CUT** + `COVER_VALUES`. |
| `get_defense_bonus()` | `gameplay_grid.gd:383` | **FOSSIL.** **CUT** + `DEFENSE_BONUS`. |
| `get_distance_to_water()` | `water_system.gd:567` | **FOSSIL.** **CUT.** |
| `get_flow_at()` | `water_system.gd:481`, `water_body_data.gd:106` | **CUT** once `gameplay_grid.get_water_flow` is gone. |
| `blocks_los()` | `vegetation_manager.gd:735` | **FOSSIL.** Density drives the sight cap. **CUT.** |
| `get_movement_multiplier_at()` | `vegetation_manager.gd:786` | **FOSSIL.** `MOVEMENT_COSTS` drives it. **CUT.** |
| **`get_water_type()`** | `water_system.gd:420` | 🔴 **RESURRECT — LOAD-BEARING.** Step 8 needs it to tell a paddy from a river. **KEEP.** |
| **`get_water_level_at()`** | `water_system.gd:449` | 🔴 **RESURRECT — LOAD-BEARING.** Step 9's pan Y. **KEEP.** |

**WHAT DIES.** The nine CUTs above, **with their tables** (`COVER_VALUES`, `DEFENSE_BONUS`) and every
comment that narrates them.

**PROOF.** `run_all_tests.ps1` fully green (nothing called them — that is the whole claim, and the
suite is how you prove it). `tests/test_grid_queries.tscn` green.

---

## STEP 5 · WIDEN THE FOSSIL PROBE TO `terrain/` — THE ONE SANCTIONED BASELINE WRITE

**WHAT.** `tests/test_fossils.gd:6` — `const SCAN_DIRS := ["res://scripts"]`. **The entire `terrain/`
tree has never been scanned.** That is the Arbiter's own probe, and it is *why* eleven fossils and two
tombstone-generated P0s survived. → `["res://scripts", "res://terrain"]`.

**THE SEQUENCING, AND THE ARBITER MUST NOT GET THIS WRONG:**

> **Widen it HERE — after Steps 3–4 deleted the corpses, before Steps 6–10 write new code.**
>
> - Widen **before** the cleanup → **every commit in this plan is red**, and the pressure to
>   "regenerate the baseline to unblock" becomes irresistible. That is the one forbidden move.
> - Widen **after** the new code → every new terrain/ symbol gets grandfathered at birth. The probe
>   becomes ceremony.
> - Widen **here** → the register **grows once, honestly** (the residue of `terrain/` debt Steps 3–4
>   could not justify killing), and **every symbol Steps 6–10 author is held to the law from line 1.**
>
> **The jump in the count is not a regression. It is the first honest count ever taken of that tree.**
> **One** `--write-baseline` run. Ever. Record the delta in the commit message and in bead `mhfv`'s
> thread so the next council cannot mistake it for backsliding.

**FILES.** `tests/test_fossils.gd:6` · `tests/fossil_baseline.json` (one write).

**WHAT DIES.** The blind spot. **Nothing may be added to `fossil_baseline.json` after this step.**

**PROOF.** `godot --headless --path . res://tests/test_fossils.tscn` → green. Re-run without
`--write-baseline` → still green. Then **add a deliberate dead const to a `terrain/` file and confirm
the build goes RED.** *Prove the probe can see the tree it just learned to look at.*

---

## STEP 6 · 🔑 THE BOOT RE-ORDER — THE KEYSTONE. IT SHIPS ALONE.

**WHAT.** Break the cycle in §0. Water and the grid must exist **before** chunks cook.

**New order inside `TerrainManager.generate_terrain()`:**

```
heightmap -> rivers -> [NEW SIGNAL: heightmap_ready] -> _load_initial_chunks_async() -> terrain_ready
                              |
                              +-- game_world._on_heightmap_ready():
                                    ClearingSystem.set_terrain_manager()
                                    water_system.initialize() + generate_water_bodies()
                                    << STEP 8's PADDY FIELD PASS SLOTS IN HERE >>
                                    gameplay_grid = GameplayGrid.new() ... build_from_terrain()
                                    generate_wetness_texture()
```

**In THIS step the paddy pass does not exist yet.** This is a pure move. **It must be
behaviour-identical.** That is the entire point of isolating it.

**FILES.**
- `terrain/core/terrain_manager.gd` — new `signal heightmap_ready`, emitted at **`:143`** (after
  `_build_water_proximity_mask()`, before `generation_progress.emit("Loading chunks")` at `:144`).
- `scripts/levels/game_world.gd:97` — connect it. **Move `:141-143` (ClearingSystem), `:149-155`
  (water + wetness), `:158-162` (gameplay_grid)** out of `_on_terrain_ready()` and into the new
  `_on_heightmap_ready()`. `_setup_terrain_shader_textures()` stays in `_on_terrain_ready()` — it
  must bake the heightmap **after** Step 8 deforms it.
- `terrain/scenes/terrain_lab.gd:280-318` — **the same sequence, duplicated.** It drifts the moment
  you touch one and not the other. Re-order both, or make the lab call the same path.

**WHAT DIES.** The old call sites in `_on_terrain_ready()` — **moved, not copied.** A second boot path
left standing is exactly the fossil ADR-023 exists to kill.

**PROOF — and it must be BIT-IDENTICAL, not "looks fine":**
- **NEW: `tools/probe_worldgen_order.gd`** — dumps `hash(heightmap.data)`, the 8-bucket
  `GameplayGrid.terrain_type` histogram, `WaterSystem` water-cell count, per-chunk billboard + patch
  instance counts. **Run before the change, save. Run after. Diff must be EMPTY.**
- `tests/test_world_boot.tscn` · `tests/test_seed_replay.tscn` · `tools/probe_vegetation.gd` ·
  `tools/probe_jungle_patches.tscn` — all green, all unchanged output.

---

## STEP 7 · ONE CLASSIFIER. THE SECOND ONE DIES.

**WHAT.** `TERRAIN_WORKFLOW.md §6` claims *"you cannot desync them."* **It is false.**
`JunglePatchLayer.generate_for_chunk()` is fed `VegetationManager._chunk_terrain`, built by
**`VegetationManager._determine_terrain_type()`** — a **second, independent classifier** with its own
RNG, its own noise, and its own water test. `VegetationManager` holds **zero** references to
`GameplayGrid` or `WaterSystem`. **The paddy you would SEE and the paddy you would WADE were never
going to agree.** Today they agree only because both are empty. **The bug is hiding the bug.**

`VegetationManager` **samples the grid it is handed.** It does not classify.

**FILES.**
- `terrain/vegetation/vegetation_manager.gd:294-326` — **`_determine_terrain_type()` DIES WHOLE.**
  **MIGRATE, DO NOT LOSE:** its FastNoiseLite patch coherence (`:309-322`) is *better* than what
  `GameplayGrid` has. It moves into `GameplayGrid._determine_terrain_type()`. **This is a merge, not
  a deletion. Losing the noise is how the jungle turns into elevation stripes.**
- `terrain/vegetation/vegetation_manager.gd:281` — the call site → sample
  `gameplay_grid.get_terrain_type(world_x, world_z)` per bundle.
- `terrain/vegetation/vegetation_manager.gd:92` — `var _terrain_manager: Node` → the grid ref.
  `scripts/levels/game_world.gd:105` — wire `vegetation_manager` to `gameplay_grid` in the new
  `_on_heightmap_ready()` (**Step 6 is what makes this possible**).
- `terrain/core/terrain_manager.gd:41, 471-473, 490, 494-502` — **`near_water_mask` +
  `is_near_water()` DIE.** Their only caller is the classifier being deleted. Superseded by
  `WaterSystem.water_map` (the real D8 network — `near_water_mask` only ever knew the
  gradient-descent rivers and was blind to every pond, lake and swamp).
- `terrain/core/terrain_manager.gd:141` — `_build_water_proximity_mask()` call → **DELETE.**

**WHAT DIES.** `VegetationManager._determine_terrain_type()` (`:294-326`) ·
`TerrainManager.near_water_mask` (`:41`) · `TerrainManager.is_near_water()` (`:494-502`) ·
`TerrainManager._build_water_proximity_mask()` · the `_terrain_manager` back-reference if nothing
else reads it · `gameplay_grid.gd:151-153`'s *"Four tables"* comment (there are now two).

**PROOF — the proof IS the merge:**
- **Extend `tools/probe_vegetation.gd`:** for every bundle in every chunk, assert
  `VegetationManager._chunk_terrain[coord][i] == gameplay_grid.get_terrain_type(bundle_centre)`.
  **Required result: 0 disagreements out of 25,600.** *That single number is the whole step.*
- `tools/probe_riparian.tscn` + `tools/probe_jungle_patches.tscn` green. Terrain-type histogram
  shifts (the noise migrated) — **expected**; record the new baseline in `probe_worldgen_order`.

---

## STEP 8 · THE PADDY FIELD PASS — A SITE, NOT A COIN FLIP

**WHAT.** Runs in the Step-6 hook, **between `generate_water_bodies()` and `build_from_terrain()`.**
`WaterSystem` is **READ** to site the paddy and **WRITTEN** by the paddy. One oracle, one more author
— exactly as `ClearingSystem` already writes into vegetation density.

**THE SUB-ORDER INSIDE THIS STEP IS LOAD-BEARING. Get it wrong and it "works" and is garbage:**

```
8a  SITE      seeded RNG (mission seed). Candidate = slope < ~4 deg
              AND within N m of the real D8 network (water_map)
              AND below an ELEVATION PERCENTILE of THIS map's own range.
              *** NEVER AN ABSOLUTE METRE VALUE AGAIN. ***  (the map's floor is 87.9 m;
              every existing gate is h<5 / h<30 / h<50 -> unreachable, 0/65536, measured)
              Flood-fill CONTIGUOUS polygons, 3-12 tiles. A field, not a dither.

8b  GROUND    FLATTEN + terrace the pan floors, RAISE the bunds, IN THE HEIGHTMAP.
              *** GROUND BEFORE WATER. *** 8d computes depth = surface - terrain by
              sampling the heightmap. Stamp water first and every depth is measured
              against the OLD ground. It will look like it worked.

8c  HYDRO     _hydrology.water_type_full[i] = PADDY
              _hydrology.water_surface_full[i] = pan_floor + ~0.55 m

8d  REPACK    water_system._build_water_map_from_hydrology(_hydrology)   <- ALREADY EXISTS.
              Do not write a second packer. It does the byte math AND makes
              get_water_level_at() work (it reads _hydrology, NOT water_map).

8e  GRID      gameplay_grid.build_from_terrain()  -- now reads the new heightmap AND the
              new water_map.
```

**FILES.**
- **NEW: `terrain/systems/paddy_field_pass.gd`** — the siting + stamp. Seeded `RandomNumberGenerator`,
  never the global stream.
- Heightmap deformation: **reuse `TerrainManager.modify_terrain()` / `heightmap.modify_region()`
  (`terrain_manager.gd:314`)**, which `ClearingSystem` already drives. **Do not write a second
  heightmap deformer.** At worldgen (pre-chunk) write `heightmap.data` directly and skip
  `_rebuild_chunks_in_region()` — there are no chunks yet. *That is the whole reason Step 6 exists.*
- `terrain/water/water_body_data.gd:6-13` — **`PADDY = 7`.** ⚠ The type field is **3 bits**
  (`water_system.gd:428`, `& 0x07`). The enum ends at `COASTAL = 6`. **7 is the ONLY free value.**
- `terrain/core/gameplay_grid.gd:270-297` — `_determine_terrain_type()`:
  - **⚠ `:272-274` returns `WATER` on `is_water()` FIRST.** Once paddies are in `water_map`, **every
    paddy classifies as WATER, not RICE_PADDY.** → check `get_water_type() == PADDY` → `RICE_PADDY`
    **BEFORE** the generic WATER return. **Miss this and the pass produces ZERO paddies — the same
    bug, a new cause, and it will look like the siting failed.**
  - `:283-284` (`h < 5.0`) — **DELETE.** `:290-291` (`h < 50.0` + `randf()`) — **DELETE.**
- `terrain/core/gameplay_grid.gd:213` — the riparian belt. **`if terrain_type[n] == CLIFF or WATER:
  continue` → add `or RICE_PADDY`.** Paddy density is **0.2**; `GALLERY_MIN` is **0.55**; `0.55 > 0.2`
  **always** → `:218-220` overwrites **every paddy within 22 m of water with jungle.** **The single
  most likely way this whole decree ships broken.** *(The BFS seeds only from `WATER` cells, and
  paddies now type as `RICE_PADDY`, so they do not seed the belt — that half is automatic. The
  overwrite is not.)*
- **The `is_water()` = "do not put things here" call sites** — turning n% of the map newly wet
  **shrinks the placeable area and can starve objective placement.** Add `get_water_type() != PADDY`
  at: `scripts/missions/mission_generator.gd:186` · `scripts/missions/objectives/survive_waves.gd:110,
  117` · `scripts/world/site_planner.gd:72, 202, 236` · `scripts/world/ground_clutter.gd:136`.
  **LEAVE ALONE** (they WANT the paddy to be wet): `scripts/player/player.gd:175` (wade sfx, leeches)
  · `scripts/enemies/enemy_base.gd:571` (trail-break) · `scripts/ui/topo_map.gd:58`.

**WHAT DIES (ADR-023).** `gameplay_grid.gd:283-284` (paddy branch A) · `gameplay_grid.gd:290-291`
(paddy branch B + **the second worldgen `randf()`**) · the `_in_rice_paddy`-by-label fallback in
`player.gd:_play_footstep_sound` **only if** `is_water()` now covers it — *verify, then bury* ·
`paddy_terrace_step`'s tile-origin-only quantisation, superseded by the real ground terrace.

**PROOF — extend `tools/probe_riparian.gd` (it already walks the grid):**
1. `RICE_PADDY` cells **> 0** (today: **0 / 65,536**). Fields contiguous, 3–12 tiles, ≥1 per 3 seeds.
2. **Paddy cells eaten by the belt: exactly 0.**
3. `get_water_depth()` inside a pan **> 0**; `get_water_type()` == `PADDY`; `is_passable` == true.
4. **THE FLATTEN PROOF:** max heightmap slope inside any pan **< 0.26°**. *(The pan is a flat sheet
   at `+0.055 m`. Above a quarter of one degree, dirt punches up through the water. This is
   arithmetic, not a risk — and the layer places tiles on ground up to **26°**.)*
5. `tests/test_seed_replay.tscn` green — **same seed, same fields.** *(Determinism is green today
   only by accident: the `randf()` branch is unreachable. The moment the threshold is fixed, ADR-010
   breaks the same day unless the pass is seeded from line one. **The determinism fix and the paddy
   fix are the same commit.**)*
6. `tests/test_generator.tscn` — **objective-placement success rate before vs after.** If it drops,
   the PADDY exemptions in the placers are wrong.

---

## STEP 9 · THE PADDY LOOKS LIKE A PADDY (and costs one draw call)

**WHAT.** The art stamps from `RICE_PADDY` cells, which exist for the first time. Three fixes.

**FILES.**
- `terrain/vegetation/jungle_patch_layer.gd` `_paddy_open_side()` — **the neighbour probe steps one
  BUNDLE (8 m) but tiles are 12 m.** It asks about a point *inside its own tile's skirt*. With
  `p = 0.7`, `P(interior) = 0.7⁴ ≈ 24%` → **≈76% of paddy tiles render as `patch_paddy_edge`, the
  TREELINE tile**, and `patch_paddy_quad` — the tile he is proudest of — lands on **~5%.** → step the
  probe by **`tile_meters`**, not `bundle_m`. **His art is right; the placement is a dither.** With
  Step 8's contiguous fields, `edge` finally lands only on the field's true rim — *doing its authored
  job: the paddy meeting the jungle.*
- `jungle_patch_layer.gd:352` `_build_pan_mesh()` / `:321` `_make_water_bucket()` — pan Y from
  **`water_system.get_water_level_at()`**, not `tile_h + 0.055`. **Water is flat.** One sheet per
  terrace, not a sheet per tile stepping across the field. *(This is why Step 4 keeps
  `get_water_level_at()` alive, and why Step 8c must write `_hydrology.water_surface_full` — that is
  the array this function reads.)*
- **178 → 1.** Merge every pan in a chunk into **one world-space `ArrayMesh`** (pans are flat,
  axis-aligned after the 90° yaw, one material). **`WaterSystem._build_combined_water_mesh()`
  (`water_system.gd:216`) already does exactly this for hydrology water.** Use the pattern. **Do not
  write a third one.** *(Cost, named: a chunk's merged water mesh must be rebuilt whenever the chunk
  re-materialises — e.g. `clear_area()` after a grenade. Today each bucket is independent and cheap
  to drop. One merged mesh is one rebuild. At 25 chunks, loaded once, streaming off (ADR-013), it is
  the right trade — **but it is a trade.**)*

**WHAT DIES.** The `tile_h + 0.055` pan-Y path · the per-(subcell × patch-name) water bucket loop ·
`jungle_patch_layer.gd:316-320`'s *"ONE extra draw call"* comment — **deleted in Step 2, and this step
is what earns the right to say it.**

**PROOF.** `tools/probe_jungle_patches.tscn`, extended: on a solid-paddy chunk, **water draw calls
178 → 1**; `patch_paddy_edge` share **76% → field-perimeter only**; `patch_paddy_quad` **appears**.
Re-run Step 1's `probe_jungle_perf` — **the paddy must be cheaper than it was, not dearer.**

---

## STEP 10 · TRUNK COLLIDERS. THE PILLAR. (bead `2v3t`) — GATED ON STEP 1.

**WHAT.** *"The tree you dive behind does not stop a bullet"* is a **Pillar 3 violation shipping
today.** ~16,000 standing trees in a 1280 m AO (`21×21 tiles/chunk × 25 chunks × 0.78 fill × 2.6
trees/patch` — **all 25 chunks stay resident, ADR-013; there is no near-chunk escape hatch**).

**`PhysicsServer3D`-direct chunk compounds. ZERO scene-tree nodes.**
- **25 static body RIDs** (one per chunk), layer 1 (`world`), mask 0.
- **16 shared, QUANTIZED `CylinderShape3D` RIDs** — 4 radius × 4 height buckets (measured `r`
  0.259–0.427 m, bole `h` 5.84–9.61 m). **NEVER SCALE A SHAPE** (`physics-system` skill §5: scaled
  shapes produce incorrect collision). Quantization error: **±2.5 cm on a 30 cm trunk.**
- `PhysicsServer3D.body_add_shape(body, shape, xform)` per tree — **pure translate + yaw, no scale.**
- **~646 shapes per body** → Jolt (the 4.6+ default, `project.godot:287`) compiles a
  **`StaticCompoundShape` with an internal BVH**: one broadphase hit, O(log n) descent per bullet.
  *On the old GodotPhysics this bet loses. On Jolt it wins.*
- **A `StaticBody3D` per tree = 32,000 nodes ≈ 50–65 MB and a 0.5–0.8 s load stall. The SCENE TREE
  dies, not the physics.**

**DESTRUCTION IS NOT IN THIS STEP.** It was CUT by the 07-12 council (blocked by `vtiz`, still OPEN).
*"Standing trunks alone deliver Pillar 3's promise for zero vertex cost. Destruction is the luxury;
cover is the pillar."*

**FILES.**
- **NEW: `terrain/systems/tree_registry.gd`** — **parallel `PackedInt32Array` / `PackedFloat32Array`
  per chunk** (~640 KB). **As a Dictionary-of-Dictionaries it is 8 MB and a hash lookup per query.**
  Store `slot` **1-BASED, exactly as the data ships** (see traps).
- `terrain/vegetation/jungle_patch_layer.gd` `generate_for_chunk()` — feed the registry the placed
  trees (`at`, `r`, `th`, `slot`) transformed by the tile's `Transform3D`.
- **`_exit_tree()` becomes LOAD-BEARING.** `PhysicsServer3D.free_rid()` every body and shape, or you
  leak 25 bodies + 16 shapes **per mission**, invisibly (no node, no Object Count tick). **ADR-010
  §19: MissionScope registration is mandatory** → `scripts/main/mission_scope.gd`.
- `scripts/world/nav_baker.gd:241` — `get_tree().get_nodes_in_group("nav_blockers")`. **RIDs are not
  in groups.** → **spatial AABB query into `TreeRegistry`.** NavBaker bakes **per-site boxes**, not
  the AO (`nav_baker.gd:80`) — a 60 m box holds ~65 trees. **Ten lines, and strictly faster than the
  16,000-node group scan it replaces.**
- **NEW: a debug draw** that dumps a chunk compound to `ImmediateMesh`. **Build it FIRST, not after
  the first "the bullet went through the tree" report** — 16,000 colliders you cannot click in the
  remote inspector.

**WHAT DIES.** The `nav_blockers` group scan at `nav_baker.gd:241` (**replaced, therefore deleted —
ADR-023**) · any `nav_blockers` group registration that now has no reader.

**PROOF.**
- **NEW: `tools/probe_trunk_collide.gd` + `.tscn`** — ray-cast every registered trunk from 4 azimuths
  at 3 ranges → **100% hit**. Assert **25 bodies**, **≤16 shape RIDs**, **0 new scene-tree nodes**
  (`Performance.OBJECT_NODE_COUNT` delta == 0).
- `tools/probe_brush.tscn` — concealment must still not be cover; **a trunk must now stop the round.**
- **Re-run `tools/probe_jungle_perf.tscn` (Step 1) with 30 enemies moving.** Every
  `move_and_slide()` now sweeps a 646-shape compound **every tick**. **The jungle had ZERO collision
  before.** **This is the real recurring cost and no prior plan named it.**
- `tests/test_mission_scope.tscn` — extend: **after `MissionScope.reset()`, zero live tree RIDs.**
- **THE GATE:** if Step 1's number comes back under the bar, **the colliders ship and destruction does
  not.** That decision is already made. Do not reopen it.

---

## ⚠ THE TRAPS — the plan must not walk into these

1. **SLOT INDEXING IS OFF BY ONE IN THE PLAN DOC.** `DESTRUCTIBLE_JUNGLE_PLAN §C2` says
   `COLOR.b = (slot+1)/24`, slots 0..23. **The shipped data is `slot / 24.0`, slot 1-BASED (1..5)**
   (`make_jungle_flora.py:213`, `make_jungle_patches.py:353`, verified in `patches.json`).
   **THE TRUTH OF RECORD:** `COLOR.b == slot / 24.0, slot ∈ 1..24` · `COLOR.b == 0.0` → **not a tree**
   · bit index = **`slot - 1`**. Implement §C2 literally and **you fell the NEIGHBOURING tree** while
   the collider of the one that visually fell stays live. **Fix the doc (Step 2). Never the data.**
2. **TWO MULTIMESHES PER BUCKET.** `jungle_patch_layer.gd:303` builds **NEAR**, `:311` builds
   **`_far`** — same `local` transform array, **separate `MultiMesh` resources.** Flip the bit on one
   and **the tree vanishes up close and is still standing at 60 m.** `TreeRegistry` holds **both**
   refs and `assert`s their `instance_count` matches. *(The water bucket at `:321` is a third — leave
   it alone.)*
3. **`body_remove_shape()` REINDEXES.** It invalidates **all 16,000 stored shape indices in one
   call.** Fell with **`PhysicsServer3D.body_set_shape_disabled()`** — indices stable forever. **This
   is the reason the architecture holds together.** *(Not exercised until destruction lands — but the
   registry is built now, so the contract is set now.)*
4. **THE PAN SITS 5.5 cm ABOVE GROUND, ON SLOPES TO 26°.** 5.5 cm over a 12 m tile is **0.26° of
   slope.** `paddy_terrace_step` quantises **the tile origin only — the heightmap underneath is never
   touched.** **The ground must be FLATTENED, not merely terraced**, or the first paddy that ever
   spawns is a mud flat with blue triangles poking out of it. **Reuse
   `TerrainManager.modify_terrain()` — do not write a second deformer.**
5. **THE WATER-MAP BYTE ENCODING IS A 3-BIT TYPE + A 0.5 m DEPTH QUANTUM.**
   `water_map[i] = t | (depth_index << 3)`, `depth_index = int(depth * 2.0)` (`water_system.gd:385`).
   **⇒ `PADDY = 7` is the ONLY free type value** (enum ends at `COASTAL = 6`).
   **⇒ THE DECREE'S "0.25–0.40 m" IS NOT REPRESENTABLE.** A surface `+0.45 m` above the pan floor
   packs to `depth_index = 0` → **`get_water_depth()` returns 0.0 and every downstream system sees a
   DRY paddy.** The pan surface must sit **≥ 0.5 m** above the pan floor → depth reads **0.5 m**
   (knee-deep, and safely under `WADE_DEPTH_M = 1.2`, so a paddy is always wadeable and never needs a
   boat). **Bund relief must therefore be ~0.7 m, not 0.4 m.** *Change the number, or change the
   encoding — but do not ship a paddy whose water is 0.0 m deep and think it worked.*
6. **🔴 THE HEIGHTMAP CELL IS 4 m, AND NOBODY IN THIS COUNCIL SAID SO.**
   (`scripts/levels/world_config.gd:9` — `CELL_SIZE = 4.0`. The Level Designer assumed 2 m.)
   A 12 m paddy tile is **THREE heightmap cells across.** `patch_paddy_quad`'s four pans are **2.75 m
   each with cross-bunds between them** — **SUB-CELL. The quad's internal cross-bunds CANNOT be
   written into the heightmap. They are physically inexpressible.**
   **⇒ Bunds go on TILE BOUNDARIES (12 m spacing, one 4 m heightmap cell wide, ~0.7 m relief). The
   quad's internal cross-bunds stay painted art you walk through.**
   The bund-vs-pan route decision — *speed and quiet, bought with your silhouette* — **is real at
   FIELD scale and a lie at QUAD scale.** Anyone who plans prone cover behind a cross-bund is planning
   a bug. **Name it to the Summoner before he finds it in the game.**
7. **`is_water()` IS USED AS "DO NOT PUT THINGS HERE"** at 7 placement sites. Make the paddy wet
   without exempting them and **objective placement starves.** *(This is precisely why Step 4
   resurrects `get_water_type()` instead of burying it.)*
8. **WIDEN THE FOSSIL PROBE AT STEP 5 — NOT BEFORE, NOT AFTER.** Before the cleanup, every commit is
   red and someone regenerates the baseline to unblock. After the new code, every new fossil is
   grandfathered at birth. **See Step 5.**

---

## WHAT THIS PLAN DOES NOT DO

- **It does not put a falling tree on the ground.** Destruction stays cut (blocked by `vtiz`). The
  Summoner gets the *cover* half — which is the pillar — and the foundation destruction needs: live
  paths, a loud guard, a stable slot contract, and a `TreeRegistry` that already holds the truth.
- **It gives him FEWER paddies.** Rare, deliberate, contiguous, actually wet, with `patch_paddy_quad`
  finally showing up. Some missions will have none. **That is the cost of a paddy being a site and not
  a coin flip.**
- **It makes the jungle catchier to move through.** Sixteen thousand 30 cm cylinders in a jungle he
  used to glide through. **Cover that does not collide is cover that lies**, and in an E&E run that
  lie is a death.
