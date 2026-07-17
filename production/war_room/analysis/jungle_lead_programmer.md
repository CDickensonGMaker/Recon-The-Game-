# LEAD PROGRAMMER — THE JUNGLE, THE WATER, AND THE PADDY THAT DOES NOT EXIST

**Everything below was RUN, not reasoned.** Godot 4.7.stable, headless, real `game_world.tscn`,
`mission_seed = 20260712`. Two throwaway probes (since deleted) plus the shipped
`tools/probe_jungle_patches.gd`.

---

## WHAT THE WATER PARSE DOES TODAY

**It works. The briefing's BREAK 1 is false.** I ran it.

`jungle_patch_layer.gd:127-131` reads `entry["water"] as Array` and hands the whole list to
`_build_pan_mesh(pans)`, which loops `for pan_v in pans` and reads `half` as `[hx, hy]`.
The N-pan, rectangular-half contract from bead `en75` **is honoured**. Measured:

```
--- _water map: 5 entries ---
patch_paddy        pans=1  verts=49   aabb=(11.60, 0.00, 11.60)
patch_paddy_quad   pans=4  verts=196  aabb=(11.50, 0.00, 11.50)   <- FOUR pans, all built
patch_paddy_fallow pans=1  verts=49   aabb=(11.60, 0.00, 11.60)
patch_paddy_grove  pans=1  verts=49   aabb=(11.60, 0.00, 11.60)
patch_paddy_edge   pans=1  verts=49   aabb=(11.60, 0.00, 6.55)    <- RECTANGULAR, honoured
water material: BUILT
```

`var _water: Dictionary` at line 84 is the **outer** map (`name -> Array[pan]`). It was never the
pan itself. The Arbiter read line 84 and its stale doc-comment and concluded the parse was broken.

**But two comments in that file are lies, and one of them cost this council a phantom P0:**

| Line | The lie |
|---|---|
| `:11` | `## A patch declares its flooded pan in patches.json ("water": {level, half, at})` — the dead single-dict format. Never shipped. |
| `:83` | `## name -> {level: float, half: float, at: [x, y]}` — same dead format. **This is the line that generated the phantom break.** |
| `:315-319` | `## a whole chunk of rice paddy costs ONE extra draw call, not one per tile` — **measured: 178.** |

This is the COMMENT DISCIPLINE law and the FOSSIL LAW proving themselves in one file. A tombstone
comment describing a format that never existed read as load-bearing, survived every grep, and sent an
architect hunting a bug that was already fixed. **The comment was the bug.**

The header's other claim — "rendered here with the terrain's own water shader — one source of truth
for water" — is **also false**, but in a more interesting way. It loads
`terrain/water/water_swamp.gdshader`, while `WaterSystem` renders its `CombinedWater` mesh with
`terrain/water/water_static.gdshader`. Two shaders, two meshes, two systems. There is no source of
truth for water here at all. Which brings us to the real finding.

---

## THE REAL BREAK: THERE ARE ZERO RICE PADDIES IN THE SHIPPED GAME

I booted the real world and counted.

```
GRID   : 256 cells/side @ 5.00m        (GameplayGrid)
VEG    : bundle 8.00m, 25 chunks       (VegetationManager)
WATER  : map 385 @ 4.00m cells         (WaterSystem)

GameplayGrid : RICE_PADDY     0 / 65536 cells (0.0%)  |  WATER 11737 (17.9%)
VegManager   : RICE_PADDY     0 / 25600 bundles (0.0%)   <- THE ART IS STAMPED FROM THIS
```

**Zero. Both deciders. Not one paddy cell in a 1280 m AO.**

The boot log has been saying so the whole time and nobody read it:
`[BillboardVegetation] Generated 1270 tree + 0 rice billboards` — **"0 rice", every chunk, every run.**

### Why — measured, not guessed

```
--- WHY ZERO PADDIES: elevation range 87.9m .. 280.0m ---
  is_water()  -> WATER          : 11737
  slope>0.7   -> CLIFF          : 0
  h<2         -> WATER          : 0
  h<5, flat   -> RICE_PADDY     : 0   <-- paddy branch A
  slope>0.4   -> LIGHT_JUNGLE   : 0
  h<50        -> 30% RICE_PADDY : 0   <-- paddy branch B (the randf one)
  h>=50       -> jungle by band : 53799
```

**The map's lowest point is 87.9 m.** Every paddy branch in the game is gated on an absolute
elevation:

- `gameplay_grid.gd:283` — `if height < 5.0 and slope_val < 0.1` → **unreachable**
- `gameplay_grid.gd:290` — `if height < 50.0` → **unreachable**
- `vegetation_manager.gd:304` — `if height < 30.0 and slope_dot > 0.93` → **unreachable**

The paddy is gated on an elevation band **that does not exist in this world.** Every non-water cell
(53,799 of them) falls through to `h >= 50 -> jungle by band`. The thresholds are absolute metres
written against a heightmap that was later given a floor of 87.9 m, and nobody re-derived them.

### What this makes dead

The Summoner's five authored paddy patches, their bunds, their four-pan cross-bunded quad, the
rectangular edge tile with its treeline, `paddy_terrace_step`, `INTERIOR_PADDIES`, `EDGE_PATCH`,
`_paddy_open_side()`, `_build_pan_mesh()`, `_make_water_bucket()`, the entire `water_swamp` material
path — **all of it is correct, all of it is tested, and none of it has ever run in the game.**
`TYPE_DENSITY[T_RICE_PADDY]` is never selected because no bundle is ever `RICE_PADDY`.

And downstream, in `player.gd`: `_in_rice_paddy` (never true), the ×2.2 wade-noise multiplier
(:542), the `MOVEMENT_COSTS[RICE_PADDY] = 1.8` leg-drag (:708), the paddy footstep sound (:189) —
**dead, all of it, for want of one threshold.**

The art is not "not wired." **The art is wired to a switch that can never close.**

---

## THE SOURCES-OF-TRUTH FOR WATER (ENUMERATED)

Six. There are **six** independent answers to "is there water here," and they do not agree.

| # | Source | Resolution | Who reads it | Knows about paddies? |
|---|---|---|---|---|
| 1 | **`WaterSystem.water_map`** — hydrology: Priority-Flood → D8 flow → creeks/rivers/ponds/lakes/swamps. `is_water` / `get_water_depth` / `get_water_type` / `get_water_level_at` | 385² @ 4 m | `GameplayGrid` delegates to it; `player.gd:175` (wade sfx, leeches); `enemy_base.gd:571` (trail-break); `site_planner`, `mission_generator`, `survive_waves`, `ground_clutter`, `topo_map` | **NO** |
| 2 | **`WaterSystem` `CombinedWater` mesh** (`water_static.gdshader`) — the water you SEE for hydrology | mesh | GPU | **NO** |
| 3 | **`WaterSystem.generate_wetness_texture()`** → `terrain.gdshader` wet-shore tint | 385² | GPU only | **NO** |
| 4 | **`GameplayGrid.terrain_type == WATER / RICE_PADDY`** — its own `_determine_terrain_type` (elevation + slope + **unseeded `randf()`**) | 256² @ 5 m | movement cost, cover, defense, passability, footsteps, noise, AI sight-cap | it *is* the paddy — and it is empty |
| 5 | **`VegetationManager._chunk_terrain`** — a **SECOND, INDEPENDENT** `_determine_terrain_type` (seeded RNG + FastNoiseLite + `near_water_mask`) | 8 m bundles | **JunglePatchLayer stamps the ART from this** | it *is* the paddy — and it is empty |
| 6 | **`TerrainManager.near_water_mask` / `is_near_water()`** — a third water mask, built during terrain gen, consulted by #5 | heightmap res | `vegetation_manager.gd:302` | n/a |
| 7 | **`JunglePatchLayer._water`** — the authored pans, rendered with `water_swamp.gdshader` | per-tile | **NOTHING. Purely visual. No system queries it.** | it *is* the paddy |

**The load-bearing scandal is #4 vs #5.** The paddy you would **SEE** (VegetationManager, 8 m bundles,
seeded RNG, noise, water-proximity) and the paddy you would **WADE** (GameplayGrid, 5 m cells,
elevation heuristic, unseeded `randf()`) are decided by **two different functions, at two different
resolutions, with two different random streams.** They were never going to agree. Today they agree
only because both are empty — the bug is hiding the bug.

And #7 is the punchline: the Summoner's authored water is **rendered and never queried.** Even if a
paddy existed, `WaterSystem.is_water()` inside a visibly flooded pan would return **false** — so the
footstep would be dry, the leeches would never bite, `is_wadeable`/`requires_boat` would say no
water, and the enemy would still track your trail across it. The paddies do not inherit water from
the game. **The Summoner is exactly right, and it is worse than he thinks.**

---

## THE ONE OWNER — MY RULING

### `WaterSystem` owns "is there water here, and how deep."

It is the only candidate. It already has the query surface the whole game reads (`is_water`,
`get_water_depth`, `get_water_type`, `get_water_level_at`), it already owns the wetness texture, and
`GameplayGrid` **already delegates to it** (`gameplay_grid.gd:409-419`). Nothing needs to be
invented. The paddy simply has to become **water in the water map** instead of a label on a grid.

### `GameplayGrid` owns "what kind of ground is this" — and it is the ONLY classifier.

One terrain-type grid. `VegetationManager._determine_terrain_type` dies; VegetationManager **samples**
the grid it is given. That is the fix for #4-vs-#5 and it cannot be fixed any other way — two
classifiers will always drift.

### `JunglePatchLayer` owns the pan GEOMETRY, and it must REPORT it.

`patches.json` is the author's contract. The layer already computes, per placed tile, the exact
world-space pans (tile transform × local pan rect). It must emit them. It must not be the only one
who knows.

### The pipeline — five ordered steps

1. **Hydrology first.** `WaterSystem.generate_water_bodies()` — creeks, rivers, ponds. Unchanged.
2. **Paddy siting** (new, in `GameplayGrid`, **one seeded RNG**, ADR-010): a paddy is *irrigated
   farmland*. Site it where a paddy actually goes — **flat ground (slope < ~4°) within N metres of a
   watercourse, below an elevation PERCENTILE of this map's own range** — never an absolute metre
   value again. This is what kills the 87.9 m bug at the root, and it uses the drainage network the
   terrain already generates.
3. **Flatten the paddy's ground.** *(See "The certainty" below — this is not optional.)*
4. **Stamp.** `JunglePatchLayer` lays paddy tiles on `RICE_PADDY` cells and emits its placed pans
   (world rect + surface level).
5. **Water claims them.** `WaterSystem` rasterises each pan into `water_map` as a new
   `WaterBodyData.Type.PADDY` with `depth = pan_level - terrain_height` (~0.3 m — far under
   `WADE_DEPTH_M = 1.2`, so a paddy is always wadeable and never needs a boat). **Then** build the
   wetness texture. **Then** finalise the grid.

After step 5, wading, footstep audio, leeches, the ×2.2 noise wake, movement drag, `is_wadeable`,
AI trail-breaking, mission/site placement, the topo map, the wet-shore terrain tint **and** the
water shader all agree — **because they all already read `WaterSystem`.** Not one of those call
sites changes. That is the proof the owner is the right one.

### The certainty nobody has hit yet (because no paddy has ever spawned)

The pan is a **flat sheet at `tile_origin.y + 0.055 m`** (`patches.json` `level: 0.055`). The layer
places tiles on ground up to **`max_slope_degrees = 26°`**, and `paddy_terrace_step` quantises the
**tile origin only — the heightmap underneath is never touched.**

5.5 cm of head-room over a 12 m tile is **0.26° of slope.** Above a quarter of one degree, **the
ground punches up through the water sheet.** The first paddy that ever spawns will be a mud flat
with blue triangles poking out of it. This is arithmetic, not a risk.

**So paddy ground must be FLATTENED, not merely terraced.** `ClearingSystem` already owns
heightmap-flattening machinery (`_apply_stage_changes` → `terrain_manager.modify_terrain`). Reuse it
at worldgen — do not write a second one.

---

## WHAT DIES (THE FOSSIL LAW BINDS ME)

Everything below dies **in the same change** that replaces it. ADR-023.

**Worldgen**
1. `GameplayGrid._determine_terrain_type()` paddy branches — `:283` (`h < 5`) and `:290-291`
   (`h < 50` + **`randf()`**). Superseded by the seeded siting pass. **Both unseeded worldgen
   `randf()` calls die with them.**
2. `VegetationManager._determine_terrain_type()` (`:294-326`) — the second classifier. **Dies whole.**
   Its *good* parts (FastNoiseLite patch coherence, water proximity) **migrate into** GameplayGrid's
   one classifier — they are better than what GameplayGrid has. This is a merge, not a deletion; do
   not lose the noise.
3. `TerrainManager.near_water_mask` + `is_near_water()` — a third water mask, whose only caller is
   the classifier being deleted in (2). Superseded by `WaterSystem.water_map`. Verify, then bury.

**Fossils I found while measuring — zero callers, in `terrain/`**
4. `GameplayGrid.has_line_of_sight()` (`:448-489`) — **zero callers.** Every LOS call in the game
   goes to `CombatManager.has_line_of_sight`. It contains the **second unseeded `randf()`**
   (`:478`, a 30 %-per-cell block roll). A dead function holding a live determinism violation.
   **DELETE.**
5. `is_wadeable()`, `requires_boat()`, `get_water_flow()` / `get_flow_at()`, `get_water_level_at()`,
   `get_distance_to_water()`, `get_water_type()` — **all zero callers.** Triage per ADR-023:
   `get_water_type` and `get_water_depth` become **load-bearing** under this design (a paddy must be
   distinguishable from a river — *resurrect*). `is_wadeable` / `requires_boat` are **UNFINISHED** —
   wire to movement or cut. `get_distance_to_water` / `get_flow_at` are **FOSSIL** unless boats are
   on the roadmap. Same for `VegetationManager.get_movement_multiplier_at` / `blocks_los` and
   `GameplayGrid.get_cover` / `get_defense_bonus` — zero callers each.

**Comments (COMMENT DISCIPLINE — and these are not cosmetic)**
6. `jungle_patch_layer.gd:11` and `:83` — the dead single-dict water format. **These generated a
   phantom P0 in this very council.** Delete.
7. `jungle_patch_layer.gd:315-319` — "ONE extra draw call". **Measured 178.** Delete the claim, or
   make it true (see Perf).

**The probe's blind spot — the reason 11 dead functions survived**
8. `tests/test_fossils.gd:6` — `const SCAN_DIRS := ["res://scripts"]`. **The entire `terrain/` tree
   is never scanned.** The fossil probe that exists to catch exactly this has been looking away from
   half the codebase. Widen it to `["res://scripts", "res://terrain"]`. It will grandfather a batch
   on the first run — that is the point. **The register only shrinks.**

---

## THE DEAD PATHS + THE GUARD

**Confirmed dead, by `ResourceLoader.exists()`:**

```
model         res://assets/models/vegetation/felled_tree.glb    exists=FALSE
trunk_model   res://assets/models/vegetation/felled_trunk.glb   exists=FALSE
stump_model   res://assets/models/vegetation/tree_stump.glb     exists=FALSE

res://assets/world/vegetation/felled_tree.glb                   exists=TRUE
res://assets/world/vegetation/felled_trunk.glb                  exists=TRUE
res://assets/world/vegetation/tree_stump.glb                    exists=TRUE
```

**The fix — both halves, or the next regen resurrects the corpse:**
1. `tools/make_jungle_patches.py:978-980` — `assets/models/vegetation/` → `assets/world/vegetation/`.
2. Regenerate `patches.json`. Do **not** hand-patch the JSON and leave the generator wrong — the
   data is generated, so the generator is the source of truth. Fix it there and re-emit.

**THE GUARD (loud, at load):** in `JunglePatchLayer._load_patches()`, walk **every `res://` string the
manifest declares** — `tree_ref.model`, `trunk_model`, `stump_model`, and every future one — through
`ResourceLoader.exists()`. Any miss → `push_error` naming the key and the path, and **fail the
layer** (`enabled = false`) rather than silently spawning nothing. A data-driven path that is wrong
must never be a silent no-op. That is precisely how 44 trees became invisible.

**THE RATCHET (`tests/test_manifest_paths.gd`, new):** walk every data file
(`patches.json` and every other `.json`/`.tres` manifest), extract every string matching `res://`,
assert `ResourceLoader.exists()`. **Zero tolerance — no baseline, unlike fossils.** A fossil can be
grandfathered because the game runs with it; a dead resource path is *never* legitimate. Copy the
recursive file-walk out of `test_fossils.gd`'s `REF_DIRS` scan. **This test would have caught commit
615ddd0 the day it landed**, and it is perhaps twenty lines.

*(The 44 trees themselves are a build, not a fix — outside my charge here. But nothing may be built
on them until the paths are live and the guard is in, or the whole feature ships as a silent no-op
a second time.)*

---

## PERF — PRICING IT (the top systemic risk; 19–25 FPS, at `scaling_3d/scale = 0.77`)

**Measured, a 252 m chunk of solid paddy (441 tiles):** `441 paddy tiles | 178 water buckets |
441 water instances`. The comment promises ONE draw call. **It is 178** — one per
(subcell × patch-name). At 19–25 FPS that is not free.

**Fix, and it makes the comment true:** the pans are flat, axis-aligned after a 90° yaw, and share
one material. Merge every pan in a chunk into **one world-space `ArrayMesh`** → **1 draw call per
chunk**, down from 178. This is exactly what `WaterSystem._build_combined_water_mesh()` already does
for hydrology water (*"Collapsing ~dozens of transparent MeshInstances into a single draw call is the
big win on low-end GPUs"* — `water_system.gd:214`). **The pattern is already in the codebase, in the
system I am naming as owner.** Use it; do not write a third one.

**Bounding the cost:** paddies always fill (`if not is_paddy and rng.randf() > fill_chance` —
paddies skip the fill roll, by design, and correctly: a paddy field is a contiguous mosaic). So
paddy tile count is bounded **only by how many cells the siting pass labels.** Percentile-based
siting near watercourses on flat ground gives a small, controllable share of a 1280 m AO. **The
siting pass must be the throttle** — and, unlike today's `randf()`, it is one you can actually turn.

**Cheap:** stamping pans into `water_map` is O(pans × ~9 cells) once at boot. Paddy exclusion in the
riparian BFS is free (it already walks every cell).

**4.7 idiom, already correct — keep it:** the pans are `MultiMesh` + `visibility_range_begin/end` +
`VISIBILITY_RANGE_FADE_SELF` + `SHADOW_CASTING_SETTING_OFF`. That is the right modern shape.
`IN_SHADOW_PASS` buys nothing here (shadows are already off on the pans) — **spend it on
`vegetation_sway.gdshader` instead**, where 2.06 M triangles of alpha-scissored jungle *do* cast.

---

## THE TRAPS THIS DECREE SETS (name them or step in them)

1. **The riparian belt will eat the paddies.** `_apply_riparian_belt()` grows HEAVY_JUNGLE gallery
   forest 22 m out from **every WATER cell**. Make paddies water, and it will wrap every rice field
   in a wall of heavy jungle — destroying the one thing a paddy is *for*: the open, cover-free
   killing ground. **The belt must skip `Type.PADDY`.** This is the single most likely way this fix
   ships broken.
2. **`is_water()` is used as "do not put things here."** `mission_generator:186`, `site_planner`
   (×5), `survive_waves:110` all reject positions where `is_water()`. Turning ~n % of the map newly
   "water" **shrinks the placeable area** and could starve objective placement. Mitigate with
   `get_water_type() != PADDY` at those call sites — which is precisely why `get_water_type()` gets
   resurrected instead of buried. **Measure objective-placement success rate after.**
3. **A village belongs *next to* paddies.** Once paddies exist, `site_planner` should *want* them
   nearby, not flee them. Out of scope here; flag it for the game designer.
4. **Determinism is currently green *by accident*.** I re-ran the grid build: `0 / 65536 cells
   differ`. It is bit-identical **only because the `randf()` branch is unreachable.** The moment you
   fix the threshold, ADR-010 breaks the same day — unless the siting pass is seeded from the start.
   **The determinism fix and the paddy fix are the same commit. They cannot be separated.**

---

## SACRIFICES

- **`VegetationManager` loses its independence.** It must be handed the grid, which means
  **worldgen must be re-ordered** so the terrain grid is built *before* chunks materialise. Today it
  is the reverse (chunks load, *then* `WaterSystem`, *then* `GameplayGrid`). This is the real cost of
  the decree: a boot-sequence change, and boot sequences are where the bodies get buried.
- **Paddy ground gets flattened**, so the Summoner's terraced-hillside paddy is a *stepped* field of
  flat pans, not a smoothly draped one. That is what a real terraced paddy is — but it is a
  constraint on his art, and he should hear it from us before he finds it in the game.
- **The 178→1 draw-call merge costs a rebuild** of a chunk's water mesh whenever a chunk
  re-materialises (e.g. `clear_area()` after a grenade). Today each bucket is independent and cheap
  to drop. One merged mesh is one rebuild. At 25 chunks, loaded once, streaming off (ADR-013), this
  is the right trade — **but it is a trade.**
- **Widening the fossil probe to `terrain/` will grandfather a batch of new debt** and make the
  register jump before it shrinks. That will look like a regression on the scoreboard. It is not.
  It is the first honest count we have ever taken of that tree.
- **None of this puts a tree on the ground.** The 44 destructibles remain unbuilt. This decree buys
  the *foundation* they need (live paths, a loud guard, a single water owner) and **spends a session
  doing it.** If the Summoner wants a falling tree this week, he will not get one from me first —
  he will get a paddy that is finally wet, and a build that fails loudly the next time an asset moves.
