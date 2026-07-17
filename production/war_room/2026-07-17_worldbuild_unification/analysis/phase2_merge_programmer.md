# Phase 2 — Vegetation Merge: Lead-Programmer / Systems Analysis

Author: lead-programmer lens. Read from CODE, not the plan. Files at HEAD as read
2026-07-17.

## Ground truth (what the code actually does today)

- `VegetationManager` (`terrain/vegetation/vegetation_manager.gd`) is the streamed,
  per-chunk owner. `terrain_manager._load_chunk()` (`terrain/core/terrain_manager.gd:261`)
  calls `vegetation_manager.generate_for_chunk(coord, heightmap, chunk_size)` during the
  resident load, then reads back `_chunk_terrain[coord]` + `_bundles_per_chunk`
  (`:262-264`) to color rice paddies in the mesh. So VM owns the ONE terrain grid and
  everyone downstream reads it. That stays.
- `VM.generate_for_chunk` (`:249`) does three things: builds `_chunk_terrain` via
  `_determine_terrain_type` → `TerrainZoning.classify` (`:294-298`), builds the placement
  cache once (`_build_placement_cache`, `:302`), then `_rematerialize` (`:290`).
- `_rematerialize` (`:532`) is the ONE branch point:
  - if `_patch_layer.enabled` → `JunglePatchLayer.generate_for_chunk(...)` (the live canopy
    today; `use_jungle_patches=true` default, `:33`)
  - else → `_materialize_vegetation` (the SUPPRESSED lone-tree path)
  - ALWAYS → `_materialize_grass` (`:541`)
- `_materialize_grass` (`:430`) builds a per-chunk grass MMI. **GroundClutter also builds
  grass** (grass_tuft/herb layers, `scripts/world/ground_clutter.gd:25-34`), resident, in
  `game_world._on_terrain_ready` (`:174-176`). Grass is materialized TWICE right now — a
  live redundancy, not just a fossil.
- `TreeCoverLayer` (`terrain/vegetation/tree_cover_layer.gd`) is built but wired to
  NOTHING. Its own header (`:11`) says the switchover is look-check-gated.
- Asset check: every individual species GLB exists under
  `assets/world/vegetation/` (broadleaf_a/b/c, banana_a/b, bamboo_a/b/c, jungle_palm_a1..b3,
  fallen_log_a/b, felled_tree, felled_trunk, tree_stump, plus concealment fern/bush/vine/
  liana/moss/grass_tuft/elephant_grass/tall_grass/rice/palm_sapling) AND every one has a
  matching `_card.glb` in `cards/`. So `TreeCoverLayer.load_species()` can load the whole
  cast today; the mechanism is not blocked on missing assets — only on the broadleaf
  models rendering as dark pyramids.

## Q1 — Cleanest ONE-veg-system structure

VegetationManager STAYS the single owner. It already holds the grid; nothing else should.
Per chunk it derives a per-species SCATTER from `_chunk_terrain` + density and feeds folded
sub-layers.

Key realization: **TreeCoverLayer already handles cover AND mid-story concealment in one
call.** `generate_for_chunk` (`tree_cover_layer.gd:62`) builds near-solid + far-card per
species and only gates the trunk collider on `COVER_TRUNK` membership (`:82`). So fern/bush
(NOT in COVER_TRUNK) go through the SAME layer as broadleaf/bamboo and simply get no
collider. There is no need for a second instancing layer for mid-story concealment — one
TreeCoverLayer covers canopy + shrub.

Ground-level concealment (grass tufts, rocks, flowers) already lives resident in
GroundClutter, which is ADR-013 (resident) + ADR-010 (deterministic) and decoupled from
streaming. That is a legitimately different lifecycle (scattered once behind the loading
screen, not per streamed chunk) and should NOT be folded into per-chunk VM — doing so is a
regression. It stays a sibling.

So "one system" = one OWNER (VM) driving one streamed INSTANCER (TreeCoverLayer) for
canopy+shrub, with GroundClutter as the resident ground sibling. Concrete call graph:

```
terrain_manager._load_chunk(coord)                         # terrain_manager.gd:261
  └─ VegetationManager.generate_for_chunk(coord, hm, size) # veg_manager.gd:249
        ├─ build _chunk_terrain via TerrainZoning.classify # unchanged (:257-284)
        ├─ scatter := _build_scatter(coord, hm, size)      # NEW (replaces _build_placement_cache)
        │     • roll TREE_CANDIDATES rng (seed hash([coord,mission_seed]))  # ADR-010
        │     • per accepted candidate: pick species name from TYPE_SPECIES[ttype]
        │       weighted pool; accept prob = TYPE_PROPS[ttype][0] (tree_chance)
        │     • emit {name, xf(pos=height, jitter/tilt/scale)}
        └─ _tree_cover.generate_for_chunk(coord, scatter)  # tree_cover_layer.gd:62
              • near-solid MMI per species (0..near)
              • far-card MMI per species w/ card (near..view)
              • trunk StaticBody per COVER_TRUNK instance

game_world._on_terrain_ready()                             # game_world.gd:137
  └─ GroundClutter.setup(self)   # resident ground concealment — UNCHANGED sibling (:174)
```

`_tree_cover` is a child of VM created in `VM._ready` (guarded by the render-path flag,
see Q4); `load_species()` is called once there with the union of every name in
TYPE_SPECIES and COVER_TRUNK. `clear_chunk_visuals`/`clear_chunk_full`/`clear_all` (and the
`clear_area` explosion re-materialize, `:490`) forward to `_tree_cover.clear_chunk(coord)`
exactly where they forward to `_patch_layer` today. Frustum culling (`:131`) drives
`_tree_cover` per-chunk the same way it drives `_patch_layer` (`:138-145`) — actually
TreeCoverLayer's `visibility_range` LOD makes coarse per-chunk culling optional.

## Q2 — Fossil-law: keep / delete each

| Element | Verdict | When |
|---|---|---|
| `JunglePatchLayer` (whole file + `use_jungle_patches` `:33`, `_patch_layer` `:35`, patch branch in `_rematerialize` `:533-538`, patch cull `:138-145`) | **DELETE** — superseded as canopy by TreeCoverLayer | DEFERRED behind look-check (Q4). It is LIVE today, so keeping it this phase creates no new fossil. |
| `_materialize_vegetation` (`:369`) + tree half of `_build_placement_cache` (`:308-335`) + `_meshes`/`_fallback_mesh`/`_create_procedural_tree` (`:668`)/`_load_first_mesh`/`use_external_models` | **DELETE** — lone-tree path, already SUPPRESSED (dead when patches on = shipping default). Replaced by TreeCoverLayer scatter. | With the flag flip (Q4). Rebuild `_build_placement_cache`→`_build_scatter` (species-aware). |
| `_materialize_grass` (`:430`) + grass half of `_build_placement_cache` (`:337-363`) + `_grass_mesh`/`_create_procedural_grass` (`:761`) + `GRASS_ACCEPT` (`:71`) + `_chunk_grass` + grass distance-cull (`:155-167`) | **DELETE** — pure fossil/redundancy: GroundClutter already owns ground grass; VM grass is a SECOND copy drawn on top. | **THIS PHASE** — headless-safe (grass still shows from GroundClutter; canopy look untouched). |
| `GroundClutter` | **KEEP** — resident ground concealment, different lifecycle, ADR-013/010 compliant. Folding into per-chunk VM is a regression. | — |
| `TreeCoverLayer` | **KEEP + WIRE LIVE** — this is the merge target. | This phase (behind flag). |
| `_chunk_terrain` grid + `TYPE_PROPS` + `blocks_los`/`get_terrain_type_at`/`get_movement_multiplier_at`/`clear_area` | **KEEP** — the grid is the shared source of truth read by terrain_manager, DamageSystem, ClearingSystem. | — |

Note: deleting VM grass this phase does NOT strand callers — `gore_lab`/`ai_stress_arena`
use `GroundClutter.make_sway_material` (static, `ground_clutter.gd:41`), not VM grass.

## Q3 — Where the per-species selection comes from

TreeCoverLayer takes `{name, xf}` but has NO opinion on which species goes where — it only
classifies cover-vs-concealment via `COVER_TRUNK` (`tree_cover_layer.gd:19`). The
terrain-type → species map is the analog of `JunglePatchLayer.TYPE_DENSITY`
(`jungle_patch_layer.gd:41`), but at INDIVIDUAL-species granularity, and **it does not
exist yet — it must be built.**

Where it lives: with the other per-terrain-type placement policy that is ALREADY in
VegetationManager — `TYPE_PROPS` (`:43`) and the now-deleted `GRASS_ACCEPT` (`:71`) prove
that per-type placement tables are VM's job. Add a `const TYPE_SPECIES` there:

```
TerrainType.GRASSLAND     -> weighted [banana_a, palm_sapling_a, bush_a, tall_grass_a,...]
TerrainType.LIGHT_JUNGLE  -> [broadleaf_a, banana_a, jungle_palm_a1, bush_b, fern_a, ...]
TerrainType.MEDIUM_JUNGLE -> [broadleaf_b, bamboo_a, jungle_palm_b1, fern_b, vine_a, ...]
TerrainType.HEAVY_JUNGLE  -> [broadleaf_c, bamboo_c, fallen_log_a, liana_a, ...]
```

Density (how MANY) is already solved: reuse `TYPE_PROPS[ttype][0]` (tree_chance) as the
per-candidate accept probability exactly as `_materialize_vegetation` does today
(`:385-389`). So the ONLY missing datum is species SELECTION, not density. Keep COVER_TRUNK
as the single authority on which of those names is a cover-giver (collider) — VM never
decides collision, it only names species; TreeCoverLayer decides the collider by
membership. One source of truth per concern: pools in VM, cover-class in TreeCoverLayer.

Determinism (ADR-010): the species pick MUST draw from the same per-chunk RNG seeded
`hash([coord, mission_seed])` that `_build_placement_cache` uses (`:310`), so two boots with
one seed produce a byte-identical canopy.

## Q4 — Sequencing risk & safe staging

The risk is real and specific: a full switchover in ONE headless run means (a) the
near-solid look is unverifiable headless, and (b) the broadleaf GLBs render as dark
pyramids. TreeCoverLayer keeps each GLB's OWN materials (`_extract_mesh` `:149`, unlike
JunglePatch which rebinds a palette atlas), so a broken broadleaf ships broken with NO
JunglePatch fallback and NO eyes to catch it. That violates "fail forward" and burns the
one canopy we have.

Recommended staging — lands the MECHANISM + real fossil-law progress THIS phase without
betting the look:

1. **Render-path flag on VM.** `enum CanopySource { JUNGLE_PATCH, TREE_COVER }`,
   `@export var canopy_source := CanopySource.JUNGLE_PATCH` (default = unchanged look).
   `_rematerialize` (`:532`) branches on it. This is a config flag, not a fossil, because
   both branches are reachable and the probe exercises the TREE_COVER one.
2. **Wire TreeCoverLayer live behind the flag.** Create `_tree_cover` in `_ready`, add
   `TYPE_SPECIES` + `_build_scatter`, route the TREE_COVER branch to it, forward all the
   clear/cull hooks. TreeCoverLayer stops being unwired.
3. **Exercise it in the headless probe.** The Phase-2 probe sets `canopy_source =
   TREE_COVER`, generates a chunk, and asserts `_tree_cover.collider_count() > 0` and a
   non-empty near MMI. THIS is what makes wiring genuinely LIVE (not "built ahead of its
   wiring" = a fresh fossil) — the fossil-law progress is real and machine-guarded.
4. **Delete the headless-safe fossils NOW** (Q2 row 3): the whole VM grass duplication.
   Verifiable headless (grass still present via GroundClutter; canopy untouched). Real
   fossil-law shrinkage this phase.
5. **DEFER to a look-check change** (Caleb's eyes + fixed broadleaf models): flip default
   to TREE_COVER, then in the SAME change delete JunglePatchLayer + the lone-tree
   `_materialize_vegetation`/tree-cache/procedural-tree (Q2 rows 1–2). Flip-and-bury is one
   small, reviewable step — the fossil law says bury in the same change as the replacement
   goes live, and "goes live" = the default flips.

Do NOT half-populate (ship bamboo/palm/deadfall as cover but skip broadleaf) — a canopy
with holes where the broadleaf should be reads as broken and muddies the look-check. Gate
the whole flip on one look-check.

One perf flag to name (devil's-advocate hand-off): TreeCoverLayer spawns one StaticBody3D
PER cover instance (`:82-85`). In HEAVY_JUNGLE that is potentially hundreds of physics
nodes per chunk — the mechanism is correct for Pillar 3 (hide behind a trunk) but the
node/broadphase cost is unmeasured and must ride the same look-check bench (ps2_perf_probe),
not just the visual pass.
```

