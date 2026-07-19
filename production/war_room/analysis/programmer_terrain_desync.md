# LEAD PROGRAMMER — Probe spec: terrain/state desync (GameplayGrid + WaterSystem)

Read from code, not plan. Files read: `terrain/core/gameplay_grid.gd`,
`terrain/water/water_system.gd`, `terrain/core/terrain_manager.gd`,
`terrain/core/heightmap_storage.gd`, `scripts/levels/game_world.gd`,
`scripts/world/site_planner.gd`, `scripts/world/ground_clutter.gd`,
`terrain/systems/damage_system.gd`, `terrain/systems/clearing_system.gd`,
`tests/test_site_stamp.gd`, `tests/test_patrol_world.gd`, `tools/probe_riparian.gd`,
`run_all_tests.ps1`.

---

## 1. The bug, confirmed in source (not inferred)

### 1a. GameplayGrid elevation is write-once

`gameplay_grid.gd:111 build_from_terrain()` walks every cell and does
`elevation[idx] = heightmap_storage.sample_world(world_x, world_z)` (line 127),
`slope[idx]` from `get_normal_world` (line 130). That is the **only** write to
`elevation` and `slope` in the entire file — verified: no other assignment to
`elevation[` or `slope[` exists.

`update_region()` (line 485) is the runtime re-bake path, and it is called by
`SitePlanner.clear_and_flatten()` (site_planner.gd:117). Read what it actually
recomputes:

```gdscript
if true:
    var density: float = _density_at(terrain_type[idx], world_x, world_z)
    vegetation_density[idx] = density
    ... reclassify terrain_type from density ...
```

**Vegetation only.** It never re-reads the heightmap. `elevation` and `slope` are
frozen at the values sampled *before* any flatten or crater. `mark_cleared()` and
`boost_vegetation()` likewise touch only type/density/passability.

So every consumer of `get_elevation()`, `get_elevation_at()`,
`get_elevation_advantage()` and `has_line_of_sight()` (which builds its ray from
`get_elevation` + `get_elevation_at`, lines 438–457) is reading pre-flatten
terrain forever.

### 1b. The edit that does the damage

`site_planner.gd:553` — `place_firebase_main()`:

```gdscript
_terrain.modify_terrain(center, FSB_FLATTEN_RADIUS,
    func(h: float, f: float) -> float:
        return lerpf(h, seat_norm, clampf(f / FSB_PLATEAU_FALLOFF, 0.0, 1.0)))
```

`FSB_FLATTEN_RADIUS = 215.0` (line 464), `FSB_PLATEAU_FALLOFF = 0.107` (line 469).
`heightmap_storage.modify_region()` computes `falloff = 1.0 - smoothstep(0, radius, dist)`,
so `f >= 0.107` ⇒ `dist <= ~0.796 * 215 ≈ 171 m`. **Inside 171 m of the firebase
centre the terrain is set to exactly `seat_norm`** — a mathematically flat plateau.
`seat_y` is the mean of a 7×7 sample lattice over the ±82 m footprint (lines 541–548).

`TerrainManager.modify_terrain()` (line 296) rebuilds chunks and emits
`region_rebuilt(world_rect)` (line 303). The heightmap now says "flat plateau".
The gameplay grid still says "original hillside".

### 1c. WaterSystem bakes twice, against the same pre-flatten heightmap

`game_world.gd:144` calls `water_system.generate_water_bodies()` **before** the
grid is built (line 155) and long before any site stamp. Two frozen artefacts:

* `_build_water_map_from_hydrology()` (water_system.gd:388) writes
  `water_map[i] = t | (depth_index << 3)` where
  `depth = max(0, hydro.water_surface_full[i] - heightmap.get_cell(x,z)*height_scale)`.
  Type and depth are both baked against pre-edit ground.
* `_hydrology` is retained and `get_water_level_at()` (line 464) returns
  `_hydrology.water_surface_full[idx]` — a surface height that was solved on the
  old terrain.

There is **no** listener on `region_rebuilt` in `water_system.gd` (grep: zero
hits for `region_rebuilt` in `terrain/water/`), and no `clear()`/regen path
wired to terrain edits.

Consequence: raise the ground 8 m under a creek with the FSB plateau and
`is_water()` still returns `true` on the parade ground, `get_water_depth()`
still returns the old index, and `get_water_level_at()` returns a surface
*below* the ground it supposedly covers.

### 1d. Only one subscriber exists

`ground_clutter.gd:121` — `world.terrain_manager.region_rebuilt.connect(_on_region_rebuilt)`.
That is the sole connection in the codebase. The signal's own docstring
(terrain_manager.gd:14–16) states the contract that is being violated:
*"Anything that baked heights at build time re-seats on this — the wire-is-law
lesson: one terrain-change channel, every height consumer listens or floats."*

---

## 2. The probe

**Name:** `tests/test_terrain_desync.gd` + `tests/test_terrain_desync.tscn`
**Registration:** none required. `run_all_tests.ps1:23` does
`Get-ChildItem "$root\tests" -Filter "test_*.tscn"` — a `test_*.tscn` in `tests/`
is auto-discovered. Do **not** put it in `tools/` (not scanned) and do **not**
name it `probe_*` (not scanned).

### 2.1 Harness pattern to copy — `tests/test_site_stamp.gd`

`test_site_stamp.gd` is the right ancestor, not `test_patrol_world.gd`.
`test_patrol_world` boots the full `GameFlow` + `CampaignState` + autosave and
has to clean up a save file; we need none of that and it triples runtime.

```gdscript
extends Node

const SEED_STEEP: int = 43   # 43 % 100 = 43 -> AO_EMPTY branch, 43 % 5 = 3 -> 2 + (43%2) = 3
                             # = STEEP_MOUNTAINS, relief 300 m. Maximum honest divergence.

var _failures: int = 0

func _ready() -> void:
    _run()

func _fail(msg: String) -> void:
    print("FAIL: ", msg)          # print(), NEVER push_error() — see §4.6
    _failures += 1

func _run() -> void:
    var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
    var world: GameWorld = world_scene.instantiate() as GameWorld
    world.mission_seed = SEED_STEEP
    world.spawn_player_on_ready = false
    add_child(world)
    var elapsed: float = 0.0
    while not world.is_world_ready and elapsed < 180.0:
        await get_tree().create_timer(0.5).timeout
        elapsed += 0.5
    if not world.is_world_ready:
        _fail("world timeout")
        _finish(world)
        return
    ...
```

Termination copies `test_patrol_world.gd:172-179`: print a single `PASS:` or
`FAIL:` line, then `get_tree().quit(_failures)`. The suite judges on exit code
**and** scans stdout/stderr for `ERROR:` (run_all_tests.ps1:44–48).

### 2.2 Phase A — synthetic edit (deterministic, preset-independent)

The real firebase flatten's magnitude depends on the AO's natural relief, which
makes a fixed numeric threshold fragile. So the probe's **primary, hard**
assertion uses an edit it authors itself, with a known-exact expected delta.

```gdscript
const LIFT_M: float = 20.0
const LIFT_R: float = 60.0     # > 5 grid cells across, so cell centres land inside

var tm: TerrainManager = world.terrain_manager
var grid: GameplayGrid = world.gameplay_grid          # strict-typed local, see §4.1
var hs: float = tm.heightmap.height_scale
var centre := Vector3(world.map_size * 0.5, 0.0, world.map_size * 0.5)
var lift_norm: float = LIFT_M / hs

tm.modify_terrain(centre, LIFT_R,
    func(h: float, f: float) -> float:
        return clampf(h + lift_norm * (1.0 if f >= 0.5 else 0.0), 0.0, 1.0))

await get_tree().process_frame
await get_tree().process_frame     # deferred re-seats land here — see §4.3
```

The step modifier (`f >= 0.5` ⇒ `dist <= ~0.5*R`) creates a **flat-topped mesa of
exactly +20.0 m** over a ~30 m-radius core. Every grid cell whose centre falls in
that core must have moved by exactly 20.0 m. No relief assumptions, no seed
luck.

### 2.3 Phase B — the real firebase flatten (organic, reported + soft-asserted)

```gdscript
var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
                               world.vegetation_manager, world)
var rng := RandomNumberGenerator.new()
rng.seed = SEED_STEEP
var fsb_centre: Vector3 = planner.find_site(rng, 90.0)
# record pre-edit truth for the negative-control magnitude report
var pre: PackedFloat32Array = _snapshot_core(grid, fsb_centre, 171.0)
var site: Dictionary = planner.place_firebase_main(fsb_centre)
await get_tree().process_frame
await get_tree().process_frame
```

Same assertions as Phase A, run over the plateau core (`dist <= 171 m`).

### 2.4 THE ASSERTIONS — state matches terrain

**Sample set:** not "N random points". Iterate **grid cell indices** whose *cell
centre* lies inside the edited disk, and query at the cell centre:

```gdscript
var cs: float = grid.cell_size_meters                        # 12.0
var g0: Vector2i = grid.world_to_grid(centre - Vector3(r, 0, r))
var g1: Vector2i = grid.world_to_grid(centre + Vector3(r, 0, r))
for gz in range(g0.y, g1.y + 1):
    for gx in range(g0.x, g1.x + 1):
        var p := Vector3((float(gx) + 0.5) * cs, 0.0, (float(gz) + 0.5) * cs)
        if Vector2(p.x - centre.x, p.z - centre.z).length() > core_r:
            continue
        ...
```

A ~171 m core at 12 m cells is ~640 cells; a 30 m core is ~20. Both are free.
**Assert on every one, report the worst** — that is the difference between a
probe and a coin flip.

#### A1 — elevation (HARD, exact)

```gdscript
var grid_h: float = grid.get_elevation(p)            # GameplayGrid.get_elevation
var real_h: float = tm.get_height_at(p)              # TerrainManager.get_height_at
if absf(grid_h - real_h) > ELEV_TOL:
    _fail("cell %d,%d: grid says %.2fm, terrain says %.2fm (%.2fm stale)"
          % [gx, gz, grid_h, real_h, absf(grid_h - real_h)])
```

`ELEV_TOL = 0.05` metres. Justification in §3.

#### A2 — slope (HARD)

`slope[]` is baked in the same loop and is just as stale; a flattened plateau
that the grid still reads as a 30° hillside breaks `get_movement_cost()`
(gameplay_grid.gd:352) and `SitePlanner._site_ok()`'s `MAX_SLOPE` gate
(site_planner.gd:104).

```gdscript
var grid_s: float = grid.get_slope(p)
var real_s: float = 1.0 - tm.get_normal_at(p).y     # identical formula to line 131
if absf(grid_s - real_s) > SLOPE_TOL:                # SLOPE_TOL = 0.02 (unitless)
```

#### A3 — water cannot sit below its own floor (HARD, terrain-independent)

This is the strongest water assertion available because it needs no memory of
the old state — it is a physical invariant.

```gdscript
var ws: WaterSystem = world.water_system
if ws.is_water(p.x, p.z):
    var level: float = ws.get_water_level_at(p.x, p.z)   # -INF if no water
    var ground: float = tm.get_height_at(p)
    if level != -INF and ground - level > WATER_TOL:
        _fail("water at %.0f,%.0f claims surface %.2fm but ground is now %.2fm — "
              % [p.x, p.z, level, ground] + "%.2fm of water underground" % (ground - level))
```

`WATER_TOL = 0.30` m (§3).

#### A4 — reported depth matches actual depth (HARD)

```gdscript
if ws.is_water(p.x, p.z):
    var reported: float = ws.get_water_depth(p.x, p.z)          # 0.5 m quantised
    var actual: float = maxf(0.0, ws.get_water_level_at(p.x, p.z) - tm.get_height_at(p))
    if absf(reported - actual) > DEPTH_TOL:
```

`DEPTH_TOL = 0.60` m — one 0.5 m quantisation step (water_system.gd:459
`depth_index * 0.5`) plus 0.1 m float slack. Note the clamp at
`depth_index <= 31` (line 401) caps reported depth at 15.5 m; skip cells whose
`actual > 15.0` rather than fail on a documented saturation.

**Water sampling runs at the water map's own 2 m resolution**, not the 12 m grid
— `water_map_cell_size = heightmap.cell_size = 2.0` (water_system.gd:66). Walk
2 m steps across the edited disk for A3/A4. There is no coarse-cell excuse to
grant here.

#### A5 — the two systems agree on what water is (HARD)

`GameplayGrid.is_water()` (line 395) delegates to `water_system.is_water()`, but
`get_terrain_type()` returns the byte baked at build time from
`_determine_terrain_type()` (line 274). Those can and will disagree after an edit.

```gdscript
var typed_water: bool = grid.get_terrain_type(p) == GameplayGrid.TerrainType.WATER
if typed_water != ws.is_water(p.x, p.z):
    _fail("cell %d,%d: grid type says water=%s, water system says water=%s"
          % [gx, gz, str(typed_water), str(ws.is_water(p.x, p.z))])
```

#### A6 — passability follows the wade rule (HARD)

`build_from_terrain():137-140` sets `is_passable = 0` for WATER cells deeper than
`WADE_DEPTH_M = 1.2`. Re-assert it post-edit:

```gdscript
var deep: bool = grid.get_water_depth(p) > GameplayGrid.WADE_DEPTH_M
var expect_passable: bool = not (deep or grid.get_terrain_type(p) == GameplayGrid.TerrainType.CLIFF)
if grid.is_position_passable(p) != expect_passable:
```

#### A7 — signal-contract guard (cheap, catches silent unwiring)

Not a substitute for A1–A6 — an *addition*, so a future refactor that quietly
drops the connection fails loudly instead of decaying into a stale-state bug
again:

```gdscript
if tm.region_rebuilt.get_connections().size() < 3:
    _fail("region_rebuilt has %d listeners (want >=3: clutter, grid, water)"
          % tm.region_rebuilt.get_connections().size())
```

### 2.5 What the probe deliberately does NOT assert

* **Crater-sized edits against the 12 m grid.** `DamageSystem` craters are
  `radius * cell_size` metres; the profiles top out at `depth_m: 8.0` and the
  typical blast radius is well under 12 m. A crater smaller than one grid cell
  *cannot* be represented in `GameplayGrid` and it is not a bug that it isn't —
  the grid is a 12 m tactical abstraction. Asserting otherwise would produce a
  probe that fails forever and gets baselined away. **Craters are asserted
  against WaterSystem only (A3/A4), whose 2 m map does resolve them.** State this
  in the probe's header comment so the next agent does not "fix" it.
* **That a function was called.** No `has_method`, no call-counting, no spies.
  Every assertion above compares a stored answer to a freshly computed one.

---

## 3. Tolerances and why the 12 m / 2 m geometry justifies them

The naive reading is: "grid cells are 12 m, heightmap cells are 2 m, therefore
the grid can be wrong by up to half a cell of terrain relief — call it several
metres." **That reasoning is wrong here, and accepting it would neuter the probe.**

`build_from_terrain():124-127` samples the heightmap at the **cell centre**:

```gdscript
var world_x: float = (gx + 0.5) * cell_size_meters
var h: float = heightmap_storage.sample_world(world_x, world_z)
```

`TerrainManager.get_height_at()` (line 288) is `heightmap.sample_world(x, z)` —
**the identical function**. If the probe also queries at the cell centre, both
sides evaluate `sample_world` at the *same coordinates against the same array*.
The 12 m/2 m ratio contributes **zero** error, because the probe never asks the
grid about a point it did not bake.

Residual error sources, all tiny:
* `elevation` is `PackedFloat32Array`; `sample_world` returns a `float` (f64
  in GDScript). One f32 round-trip at a ~300 m magnitude is ~2e-5 m.
* Bilinear interpolation is deterministic and identical on both sides.

**`ELEV_TOL = 0.05 m`** is therefore ~3 orders of magnitude above the real noise
floor and ~2 orders below the smallest interesting divergence. It is not a
"generous" tolerance; it is a rounding allowance.

**Where the 12 m coarseness *is* real:** if a caller queries `get_elevation()` at
an arbitrary point rather than a cell centre, the honest error bound is
`slope × half-diagonal = slope × 8.49 m`. On a 30° slope that is ~4.9 m. That is
a legitimate property of a 12 m grid, **not** a desync, and it is precisely why
the probe samples at cell centres — it isolates the bug from the abstraction.
Worth one line in the probe header so nobody later "loosens the tolerance
because the cells are 12 m".

**`SLOPE_TOL = 0.02`** (unitless, `1 - normal.y`): `get_normal_world` is called
with identical arguments on both sides; the tolerance covers f32 storage only.
0.02 corresponds to about 11° — far coarser than the noise, far finer than a
flatten.

**`WATER_TOL = 0.30 m`**: `water_map`, `_hydrology.water_surface_full` and the
heightmap are all on the **same 2 m lattice** — index `i` is the same cell in all
three (`water_map_size = heightmap.size`, line 65). So there is no resampling
error at all. The 0.30 m covers `RIVER_RECESS = 0.1` (water_system.gd:225) and
the difference between `get_cell()` (nearest-cell, used at bake) and
`sample_world()` (bilinear, used by `get_height_at`), which on 2 m cells over
Vietnam-scale relief is sub-decimetre.

**`DEPTH_TOL = 0.60 m`**: one full quantisation step (0.5 m) plus slack. Not
negotiable downward — the encoding genuinely loses that much.

---

## 4. Negative control — what the probe prints when the fix is reverted

The probe is worthless unless we know its failure magnitude in advance. Both
phases are computed, not guessed.

### 4.1 Phase A (synthetic +20 m mesa) — exact

Revert the fix (grid stops listening to `region_rebuilt`) and every cell centre
inside the ~30 m core reports:

> **|grid_h − real_h| = 20.00 m ± 0.05**

Exactly the authored lift, because the modifier is a step function and the grid
simply never moved. Zero dependence on seed, preset, or relief. **This is the
number the probe should print and the number a reviewer should check.** If a
reverted build shows anything other than ~20 m, the probe itself is broken.

### 4.2 Phase B (real R=215 firebase flatten) — bounded, seed-dependent

Divergence at a core cell is `|h_original(cell) − seat_y|`, where `seat_y` is the
7×7 footprint mean over ±82 m and the plateau extends to 171 m. So the probe is
measuring the **natural relief of a 342 m-diameter disk** on that AO.

Per-preset relief budgets are declared in `terrain_manager.gd:359-375`
(`_preset_height_scale`), and the fBm terrain's relief over a 342 m window is
roughly `relief × (342/3000)^H` with H ≈ 0.8, i.e. ~16 % of full-map relief:

| Preset (relief) | expected core relief | expected **max** divergence | typical median |
|---|---|---|---|
| COASTAL_HILLS (25 m) | ~4 m | ~2 m | ~0.7 m |
| RIVER_VALLEY (40 m) | ~6 m | ~3 m | ~1.2 m |
| ROLLING_HILLS (90 m) | ~14 m | **~7 m** | ~2.5 m |
| PLATEAU (160 m) | ~26 m | ~13 m | ~4 m |
| STEEP_MOUNTAINS (300 m) | ~48 m | **~24 m** | ~8 m |

Hence `SEED_STEEP = 43` in §2.1: `43 % 100 = 43` ⇒ empty branch; `43 % 5 = 3` ⇒
not PLATEAU; `2 + (43 % 2) = 3` ⇒ **STEEP_MOUNTAINS**. Verify this arithmetic
against `_derive_ao_preset()` when writing the probe rather than trusting this
table, and print the resolved preset.

**Assert only `> ELEV_TOL` on Phase B; print the measured max.** Do not hard-code
"expect ≥ 7 m" — that couples the probe to noise generation and it will be
baselined away the first time it flakes. The claim to make in the ADR is:
*Phase A pins the magnitude exactly; Phase B proves the real production edit
exhibits the same class of failure at 2–24 m depending on AO.*

### 4.3 Water negative control

For A3, flatten a firebase over a creek and a "water" cell whose surface was at
the old creek bed reports:

> **ground − level = seat_y − creek_bed**, i.e. the full plateau lift, typically
> **2–20 m of water sitting underground** on STEEP_MOUNTAINS.

For A4, `get_water_depth()` returns the *old* index while `actual` has gone to
0 (or negative, clamped to 0): expected divergence equals the pre-edit depth,
**1.0 m for a creek, 2.5 m for a river** (water_system.gd:143), up to the 15.5 m
saturation for a lake.

The clean, seed-proof water negative control is again the synthetic mesa: pick
any cell where `ws.is_water()` is true, lift the terrain 20 m under it, and A3
must report **≈ 20 m** of underground water.

---

## 5. Strict-typing and Godot 4.7 pitfalls in headless world boot

1. **`GameplayGrid extends RefCounted`, not Node** (gameplay_grid.gd:1). Assign
   it to an explicitly typed local (`var grid: GameplayGrid = world.gameplay_grid`)
   — `world.gameplay_grid` is an untyped `var` in `game_world.gd`, so `:=` infers
   `Variant` and every subsequent method call is an unchecked dynamic dispatch
   that strict mode will flag. Same for `var tm: TerrainManager`, `var ws: WaterSystem`.
   Do **not** hold the grid past `world.queue_free()` — RefCounted will keep a
   freed world's heightmap alive and skew a second phase.

2. **`heightmap` is a bare `RefCounted`** (terrain_manager.gd:34), not a typed
   class. `tm.heightmap.height_scale` is a Variant lookup; wrap it:
   `var hs: float = float(tm.heightmap.height_scale)`. Likewise
   `modifier.call(...)` returns Variant — never `:=` its result.

3. **Signal timing is the trap that will make this probe lie.**
   `TerrainManager.modify_terrain()` emits `region_rebuilt` **synchronously**
   (line 303), but the existing subscriber re-seats via `call_deferred`
   (ground_clutter.gd:186-188) and its own comment (lines 173–176) explains why:
   `clear_and_flatten` updates the gameplay grid *after* `modify_terrain`, and the
   firebase stamp fires 12–18 `modify_terrain` calls in one synchronous stretch.
   Any correct fix will almost certainly coalesce the same way. **The probe must
   `await get_tree().process_frame` at least twice after the last edit before
   asserting** — once for the deferred flush to run, once for anything it queues.
   Asserting immediately after `modify_terrain()` returns will produce a
   *false FAIL* on a correct fix, which is worse than the bug.

4. **Do not await `region_rebuilt` itself.** With a synchronous emit inside a
   synchronous call chain, `await tm.region_rebuilt` from the probe's coroutine
   can miss the emission entirely and hang until the 420 s suite timeout
   (run_all_tests.ps1:16). Poll frames; do not await the signal.

5. **Physics frames are not needed — say so and keep it that way.** Every
   assertion above reads the heightmap and the two lookup arrays. Nothing
   raycasts. Adding a `ray_cast` against terrain collision would require
   `await get_tree().physics_frame` *after* `_rebuild_chunk_immediate()` has
   re-run `create_raycast_collision()` (terrain_manager.gd:240), and headless
   Godot's physics server is a documented source of flake here. Resist it.

6. **`_rebuild_chunk_immediate()` `queue_free()`s chunks** (terrain_manager.gd:84).
   Never cache a `TerrainChunk` reference across an edit —
   `run_all_tests.ps1:46` treats `"previously freed"` as a hard FAIL.

7. **Never call `push_error`/`push_warning` from the probe.** The harness scans
   for the literal `"ERROR:"` (run_all_tests.ps1:44, matched with ordinal
   `.Contains()`), and `push_error` emits exactly that — a probe that reported its
   own failures via `push_error` would fail even when green, and a probe that
   used `push_warning` for a *real* failure would pass silently. Use `print()`,
   exactly as `test_patrol_world.gd` and `test_site_stamp.gd` do, and exit via
   `get_tree().quit(_failures)`.

8. **`spawn_player_on_ready = false`** (as in `test_site_stamp.gd:35`). The
   player boot pulls in audio, HUD and camera-dependent vegetation and adds
   seconds plus leak chatter to a probe that needs none of it.

9. **No `--test-save` dependency.** Instantiating `game_world.tscn` directly
   avoids `CampaignState`/`SaveManager` entirely, so the probe cannot corrupt a
   campaign the way the suite's header warns about. Don't reach for `GameFlow`.

10. **`world.map_size`** — use it for the synthetic-edit centre rather than
    hard-coding 3072/3000. `TerrainManager.map_size` (3000.0) and
    `GameplayGrid.world_size` (3072.0 default, but constructed with
    `terrain_manager.map_size` at game_world.gd:150) are *different numbers* in
    the defaults. Deriving both from `world.map_size` avoids sampling a cell
    that exists in one system and not the other.

11. **Budget.** Two world boots (Phase A and Phase B can share one) at
    STEEP_MOUNTAINS, ~640 + ~20 cell assertions and a 2 m water walk over the
    edited disks. Well inside the 420 s box; keep it to **one** world instance
    and run both phases against it, ordering Phase A (synthetic) first so a
    failure there indicts the wiring before the more expensive firebase stamp.

---

## 6. Verdict

The desync is real and mechanical: `GameplayGrid.elevation`/`slope` have exactly
one writer (`build_from_terrain`), `update_region` recomputes vegetation only,
and `WaterSystem` retains a hydrology solved against the pre-edit heightmap while
subscribing to nothing. `region_rebuilt` exists, carries the right payload, and
has one listener out of the three it needs.

The probe must sample **at grid cell centres** so that the 12 m/2 m ratio
contributes zero error, which buys a 0.05 m tolerance instead of a meaningless
multi-metre one — and it must author its own +20 m edit so the negative control
is an exact, seed-independent 20.00 m rather than a relief-dependent guess.
