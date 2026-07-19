# Systems Architect — RECONgame-15ow / RECONgame-t5ne (terrain data desync)

Read from code, not from the beads. All citations are worktree-relative.

---

## a) One root cause or two?

**One wiring gap, two repairs.**

`TerrainManager.region_rebuilt` (`terrain/core/terrain_manager.gd:17`, emitted at `:303`) is the
declared "one terrain-change channel" — its own docstring at `:13-16` says *"Anything that baked
heights at build time re-seats on this."* Exactly one consumer honours that contract:
`scripts/world/ground_clutter.gd:121`.

Both stale systems bake heights at build time:
- `GameplayGrid` bakes `elevation`/`slope`/`terrain_type`/`is_passable` in `build_from_terrain()`
  (`terrain/core/gameplay_grid.gd:111-149`), run once at `scripts/levels/game_world.gd:155`.
- `WaterSystem` bakes the combined mesh + `water_map` in `generate_water_bodies()`
  (`terrain/water/water_system.gd:78-116`), run once at `scripts/levels/game_world.gd:144`.

Both then get invalidated by the *same* emitters: `site_planner.gd:553` (FSB plateau, R=215) and
`damage_system.gd:138` (every crater). So the **cause** is one: nobody subscribes.

They are **not** one fix, because the two consumers sit in different cost classes by ~3 orders of
magnitude (see (d)) and require different update granularity. The grid can re-seat per-rect,
synchronously, always. Water cannot — its model is *global* (priority-flood + flow accumulation over
the whole map, `terrain/water/hydrology_map.gd:107-124`), so there is no such thing as a regional
water update. Any fix that treats them identically will either leave the grid stale or hitch the game
on every grenade.

There is a third, quieter victim of the same gap: the **wetness texture** is generated and pushed to
the terrain shader at `game_world.gd:145-147` and is never regenerated. It is downstream of
`water_map` and must be re-pushed whenever water is rebuilt.

---

## b) Does `update_region()` actually recompute elevation/slope/passability?

**No. It touches vegetation only, and it is misnamed.**

`terrain/core/gameplay_grid.gd:485-515`:

- `:494-499` iterates the cell box and computes `world_x`/`world_z`.
- `:500` is a bare `if true:` — a stub guard, dead syntax.
- `:501-502` recomputes `vegetation_density[idx]` via `_density_at()`.
- `:504-513` **downgrades** `terrain_type` by density bands, and at `:506` sets
  `is_passable[idx] = 1` — but ONLY on the `density < 0.1` branch. Passability is never
  *recomputed*, only force-cleared for bare cells.
- `elevation[]` is **never written**. `slope[]` is **never written**.

Consequences after the FSB plateau at `site_planner.gd:553`:
- `get_elevation()` (`:324`) returns pre-flatten terrain across the whole R=215 ring.
- `get_slope()` (`:336`) returns pre-flatten slope — the plateau reads as sloped hillside.
- `has_line_of_sight()` (`:434-478`) raycasts against `get_elevation_at()` — LOS in and around the
  firebase is computed against a hill that no longer exists.
- `get_movement_cost()` (`:352-359`) applies a slope penalty from stale slope.
- `_determine_terrain_type()`'s `CLIFF` verdict (`:279-280`, `slope > 0.7`) and its
  `height < 2.0 → WATER` verdict (`:282`) are never revisited, so a flattened cliff stays
  impassable and a filled low spot stays water.
- `site_planner._score_site` reads `_grid.get_slope()` at `:523` — site scoring for *later* sites
  reads pre-FSB slope.

Note the ordering trap in `clear_and_flatten` (`scripts/world/site_planner.gd:110-116`): it calls
`_grid.update_region()` *after* the clearing zone, and `ClearingSystem` itself calls
`modify_terrain` (`terrain/systems/clearing_system.gd:173`) — so the grid update runs after the
height change but still refuses to read heights. The call is in the right place; the function is
simply the wrong function. The FSB's own `modify_terrain(center, 215.0, …)` at `:553` gets no grid
update of any kind — only the five 58–60m `FSB_CLEAR_DISCS` (`:472-476`, applied at `:556-557`) get
even the vegetation-only pass.

**Rect2 vs center+radius:** `update_region(center: Vector3, radius_meters: float)` (`:485`) cannot
take a `Rect2`. It converts to a cell box at `:486-492` and — despite the name "region" — the box is
a **square**, not a disc (contrast `mark_cleared` `:527-528` and `boost_vegetation` `:546-547`,
which both do a radial reject). Feeding it a `region_rebuilt` `Rect2` would require
`center = rect.get_center()`, `radius = max(size.x, size.y) * 0.5` — which for a non-square rect
under-covers the long axis. `game_world.gd:361-368` already does exactly this lossy conversion for
the clearing path, complete with a hardcoded `/ 512.0` magic divisor that is unrelated to the grid's
own 256 resolution. A rect-native entry point is required, not a wrapper.

---

## c) `water_system.gd` — what must be re-seated, and is a full regen safe?

Three pieces of baked state, and they are **not** independent:

1. **`water_map`** (`:35`, built at `:388-406`) — the O(1) `is_water`/`get_water_type`/
   `get_water_depth`/`get_distance_to_water` grid (`:424-459`, `:582-605`). Encodes depth from
   `hydro.water_surface_full[i] - terrain` at `:399-400`, i.e. it is **height-derived** and goes
   wrong the instant the heightmap moves.
2. **The combined mesh** (`_build_combined_water_mesh`, `:231-269`) — static quad Y comes from
   `b["surface"]` (`:297`) and vertex-colour depth from `_heightmap.get_cell()` (`:293-294`); river
   strip Y is `_heightmap.sample_world()` (`:320`). Both bake heights. After a 215m plateau raises
   the ground, any water surface inside it renders *below* the new terrain — invisible water that
   `is_water()` still reports as wet.
3. **The wetness texture** — `generate_wetness_texture()` (`:531-578`) reads `water_map` and is
   pushed to the terrain shader once at `game_world.gd:145-147`. It is not owned by WaterSystem
   after creation, so a water rebuild that does not re-push it leaves the shader painting shorelines
   on dry plateau.

Plus a fourth, external: `GameplayGrid`'s `WATER` cells come from `water_system.is_water()` at
`gameplay_grid.gd:276-278` and its passability from `get_water_depth()` at `:139`. **A water rebuild
therefore obligates a grid rebuild.** Ordering in any flush must be water → grid, never the reverse.

**Is a full `generate_water_bodies()` re-run safe/idempotent?**

State-wise, essentially yes. `clear()` (`:409-417`) resets `water_bodies`, `water_by_chunk`,
`water_map`, `_next_id` (so no ID drift across runs) and `_hydrology`. `_build_water_map_from_hydrology`
opens with `water_map.fill(0)` (`:389`). A fresh `HydrologyMapClass` is constructed each call (`:88`),
so no hydrology state carries over. No leak of dictionaries or ids.

Two real defects, both node-lifetime:

- **Same-frame double mesh.** `clear()` calls `child.queue_free()` (`:410-411`), which is deferred to
  end-of-frame, but `_build_combined_water_mesh` adds the new `CombinedWater` at `:266-269`
  synchronously in the same call. For the remainder of that frame **two transparent water meshes
  overlap** — visible z-fighting/double-blend on the exact surface the PSX water shader is most
  sensitive on. Correct fix is `free()`/`remove_child()`-then-free in `clear()`, not `queue_free`.
- **`water_generated` re-emits** (`:115`) and `water_body_added` re-emits per body (`:384`). Any
  future subscriber that appends rather than replaces will double up. Nothing subscribes today —
  which by the FOSSIL LAW is itself worth noting: `water_generated` is currently a signal with zero
  listeners.

The `_water_container` is created in `_ready()` (`:55-58`) and reused, so repeated regen does not
accumulate containers.

---

## d) Cost per emission — concrete cell counts

Constants: `map_size = 3000m`, `cell_size = 2.0` → `heightmap.size = 1501` (`terrain_manager.gd:19-21`,
`:59`). Gameplay grid is 256 cells/side over `map_size`, so `cell_size_meters ≈ 11.72m`
(`gameplay_grid.gd:75-78`, constructed at `game_world.gd:150`). WaterSystem inherits
`water_map_size = 1501`, `water_map_cell_size = 2.0` (`water_system.gd:65-67`).

**Emission 1 — FSB plateau, `site_planner.gd:553`, R = 215m**
- Heightmap cells written: radius 108 cells → **217 × 217 = 47,089** cells (`modify_region`).
- Chunks rebuilt: 215m radius at 256m chunks → up to **4 × 4 = 16** chunk mesh rebuilds
  (`_rebuild_chunks_in_region`, `:309-329`).
- Gameplay-grid cells in the box: `g_radius = ceil(215 / 11.72) = 19` → **39 × 39 = 1,521** cells.
  A *full* per-cell rebuild (sample_world + get_normal_world + classify + water query) on 1,521 cells
  is roughly 2.3% of `build_from_terrain`'s 65,536-cell pass. If that full build is the ~200–400ms
  class it prints at `:148-149`, this is **single-digit milliseconds**. Trivially affordable
  synchronously. There is exactly **one** such emission per mission.

**Emission 2 — crater, `damage_system.gd:138`, r ≈ 5–10m**
- Heightmap cells: radius 3–5 → **49 to 121** cells.
- Chunks rebuilt: 1–4.
- Gameplay-grid cells: `g_radius = 1` → **3 × 3 = 9** cells. Sub-millisecond.
- Frequency: every explosion, capped by `MAX_DEFORMS_PER_MISSION` (`damage_system.gd:136`), and
  they arrive in **bursts** (a fire mission, an RPG exchange).

**Water regen cost, per call, regardless of the emitter's radius:**
- `_build_downsampled_elevation` (`hydrology_map.gd:127-155`): reads all **2,253,001** heightmap
  cells. `_auto_downsample` (`water_system.gd:119-123`) gives `round(1501/450) = 3`, so the hydrology
  grid is **501 × 501 = 251,001** cells.
- `_priority_flood` (`:157-194`): GDScript binary heap over 251,001 cells → ~**4.5M** heap ops.
- flow directions + accumulation + classification + river extraction: several more 251k passes.
- `_upsample_outputs` (`:530-554`): **2,253,001** writes.
- `_build_water_map_from_hydrology` (`water_system.gd:388-406`): a **2,253,001-iteration GDScript
  loop** with a `get_cell` per iteration.
- Mesh rebuild: 4 verts per water cell across every body plus every river strip.

That is a **hundreds-of-milliseconds to multi-second** operation, entirely on the main thread. It is
already the single most expensive step of world build.

**And the wetness texture is worse than the water regen.** `generate_wetness_texture(16.0)`
(`water_system.gd:531-578`, called at `game_world.gd:145`): `fade_cells = ceil(16 / 2) = 8`, and the
loop at `:546-572` is 8 distance passes × 2,253,001 pixels × up to 9 `Image.get_pixel` neighbour
reads = up to **~162 million per-pixel GDScript Image calls**. Multi-second, guaranteed.

**Verdict on (d):** synchronous full-consumer rebuild on every `region_rebuilt` is **not viable**.
A single grenade would trigger a multi-second freeze. Per-crater water regen is not "expensive" — it
is a hard hitch measured in seconds, on a pillar-1 (gunplay) frame.

But debouncing alone does not save it either: five craters in a firefight debounced into one flush is
still one multi-second freeze. **Water regen must be gated by cause, not merely deferred.**

The honest physical argument for the gate: hydrology is a *global* flow model. A 5m crater does not
meaningfully redirect a watershed — and even if it pooled, `hydrology_map` at downsample 3 works on
6m hydrology cells and would barely resolve it. A 215m plateau genuinely can dam or erase a creek.
So:

- **FSB plateau / any structural flatten (R ≥ ~50m): water MUST rebuild.** Once, at build time,
  behind the loading screen — where a second is free.
- **Craters: water must NOT rebuild.** The desync is real but bounded and, at 6m hydrology
  resolution, largely below the model's own precision. Accept it; that is the tradeoff, named.
- **Gameplay grid: rebuilds on EVERY emission, synchronously.** 9 cells for a crater, 1,521 for the
  FSB. It is cheap enough that deferral buys nothing but a window of staleness.

---

## e) The ONE fix shape

**A single dirty-rect coalescer in `game_world.gd` that subscribes `region_rebuilt` once, with a
rect-native grid rebuild and a radius-gated water rebuild.** Mirror the pattern
`ground_clutter.gd:173-187` already proves works here.

### 1. `terrain/core/gameplay_grid.gd` — extract the per-cell build, add a rect entry point

Extract the body of `build_from_terrain()`'s inner loop (`:121-143`) into:

```gdscript
func _build_cell(gx: int, gz: int) -> void
```

— which writes `elevation`, `slope`, `terrain_type`, `is_passable` and `vegetation_density` for one
cell from the heightmap. `build_from_terrain()` (`:119-143`) then calls it in its double loop, so
there is exactly one definition of "what a cell means".

Add:

```gdscript
func rebuild_rect(world_rect: Rect2) -> void
```

— clamps the rect to grid bounds, calls `_build_cell()` per cell, then emits
`grid_updated.emit(Rect2i(...))`. It must NOT re-run `_apply_riparian_belt()` /
`_roof_the_creeks()` (`:184-271`) — those are global BFS passes and re-running them per crater
re-costs the whole grid; accept that gallery-forest density is not re-derived on a local edit, or
re-run them only on the structural (water-rebuilding) flush.

**DELETE `update_region()` (`:485-515`)** per ADR-023. Its two callers become `rebuild_rect`:
- `site_planner.clear_and_flatten:116` → `_grid.rebuild_rect(Rect2(center.x - r, center.z - r, r*2, r*2))`
- `game_world._on_vegetation_updated:368` → same, and this also kills the `/ 512.0` magic divisor at
  `:363-367`. (`tools/probe_riparian.gd:181` also calls it and must be updated.)
Leaving `update_region` beside `rebuild_rect` is precisely the two-things-that-look-like-one-thing
the FOSSIL LAW forbids.

### 2. `terrain/water/water_system.gd` — make regen node-safe

In `clear()` (`:409-411`), replace `child.queue_free()` with `remove_child(child)` +
`child.queue_free()` so no two `CombinedWater` meshes ever coexist in a frame.

Add:

```gdscript
func rebuild_from_terrain() -> ImageTexture
```

— calls `generate_water_bodies()` then returns `generate_wetness_texture(16.0)`, so the caller
cannot forget to re-push the shader texture. No other change; the existing regen is otherwise
idempotent.

### 3. `scripts/levels/game_world.gd` — the coalescer (the actual fix)

```gdscript
const WATER_REBUILD_MIN_RADIUS: float = 50.0   # below this, hydrology cannot resolve the change

var _dirty_rects: Array[Rect2] = []
var _water_dirty: bool = false
var _terrain_flush_pending: bool = false

func _on_terrain_region_rebuilt(world_rect: Rect2) -> void:
    _dirty_rects.append(world_rect)
    if maxf(world_rect.size.x, world_rect.size.y) * 0.5 >= WATER_REBUILD_MIN_RADIUS:
        _water_dirty = true
    if not _terrain_flush_pending:
        _terrain_flush_pending = true
        _flush_terrain_dirty.call_deferred()

func _flush_terrain_dirty() -> void:
    _terrain_flush_pending = false
    if _water_dirty:
        _water_dirty = false
        var tex: ImageTexture = water_system.rebuild_from_terrain()
        if tex:
            TerrainChunkScript.set_shader_texture("wetness_texture", tex)
    for r in _dirty_rects:
        gameplay_grid.rebuild_rect(r)
    _dirty_rects.clear()
```

Connect once in `_on_terrain_ready()`, immediately after the grid is built
(`game_world.gd:155`):

```gdscript
terrain_manager.region_rebuilt.connect(_on_terrain_region_rebuilt)
```

Water-before-grid inside the flush is **load-bearing**: `gameplay_grid._determine_terrain_type`
(`:276-278`) and `build_from_terrain` (`:139`) both query `water_system`, so the grid must be the
last thing rebuilt.

`ground_clutter._on_region_rebuilt` (`:177`) also defers to next frame; both flushes land in the same
deferred batch, and clutter's `_accept()` will now read a grid that has actually been re-seated —
which is what its own comment at `:173-176` says it wanted and was not getting.

### What this sacrifices (no free lunch)

- **Craters never update water.** A shell hole that should hold water will not. Bounded, sub-model-
  resolution, and the alternative is a multi-second freeze mid-firefight.
- **Riparian/roof density is not re-derived on local edits** unless the structural flush runs. Local
  gallery-forest density drifts slightly from truth around craters.
- **The FSB build now pays one water regen + one wetness bake** — a second or two, behind the loading
  screen. Acceptable there; would not be acceptable anywhere else.
- **One frame of staleness** on every crater, because the flush is deferred. AI thinks at 6–7 Hz; a
  single frame is inside the noise.

### The probe this needs

A headless test that: builds a world, places the FSB, and asserts that
`gameplay_grid.get_elevation()` and `get_slope()` at the plateau centre and at r=100m match
`terrain_manager.get_height_at()` / `get_normal_at()` within tolerance. Today that assertion fails.
Without it, this desync grows back the moment someone adds a new terrain-editing caller — which is
exactly how it got here.
