# DEVIL'S ADVOCATE — "subscribe GameplayGrid + WaterSystem to region_rebuilt"

Read from code, 2026-07-19. Worktree `agent-a7ee3ee11e668f7ba`.

---

## OBJECTION 0 (FATAL): `GameplayGrid.update_region()` DOES NOT UPDATE ELEVATION OR SLOPE

This kills the proposal as written. `gameplay_grid.gd:485-515`:

```
func update_region(center: Vector3, radius_meters: float) -> void:
    ...
    var density: float = _density_at(terrain_type[idx], world_x, world_z)
    vegetation_density[idx] = density
    if density < 0.1:   terrain_type[idx] = CLEAR ; is_passable[idx] = 1
    elif density < 0.3: terrain_type[idx] = GRASSLAND
    ... # else keep current type
    grid_updated.emit(...)
```

`elevation[]` (`:64`) and `slope[]` (`:65`) are **never written**. They are written exactly once,
in `build_from_terrain()` (`:128`, `:132`), from `heightmap_storage.sample_world` /
`get_normal_world`. `_determine_terrain_type()` (`:274`) — the function that turns
`slope > 0.7` into CLIFF and `height < 2.0` into WATER — is **never re-run** by `update_region`.

Consequences, all of which the proposed fix leaves standing:

1. **The R=215 firebase flatten does not update one byte of grid elevation.** Grid cell size is
   `1280/256 = 5.0 m`, so the flatten covers `g_radius = ceil(215/5) = 43` → a **87x87 = 7,569-cell**
   block whose `elevation[]` still describes the hill that was bulldozed. `has_line_of_sight()`
   (`:434-478`) reads `get_elevation()` for both endpoints and every step. **Every AI LOS decision in
   and around the firebase is computed against terrain that no longer exists.**
2. **Slope is stale too**, and `SitePlanner.find_site` / `plan_firebase_main_center` score sites on
   `_grid.get_slope()` (`site_planner.gd:78`, `:523`). Re-running site planning after any flatten
   would score against ghost relief.
3. **A CLIFF cell can never be un-cliffed.** `update_region`'s ladder has no `else` branch for
   density >= 0.7 ("else keep current type", `:513`), and CLIFF/WATER/HEAVY_JUNGLE are all in that
   bucket. Flatten a ridge under the wire and its cells stay `CLIFF` → `is_passable = 0`,
   `MOVEMENT_COSTS = 99.0`, `COVER_VALUES = 0.9`, and `has_line_of_sight` blocks on them (`:460`).
   **A bulldozed cliff inside the firebase remains an impassable LOS-blocking wall to the AI.**
   `update_region` also cannot *set* impassable — it only ever writes `is_passable = 1`.

So: wiring `update_region` to `region_rebuilt` produces a *plausible-looking* connection that fixes
vegetation bookkeeping and **does not fix the height desync the whole exercise is named after**. That
is the worst possible outcome under the FOSSIL LAW — not a dead system, a *live lie*: a subscriber
that appears to be the height-reseat channel and isn't.

**REQUIRED for the fix to mean anything:** `update_region` must re-sample `elevation`/`slope` from
the heightmap and re-run `_determine_terrain_type` for the region. That is a change to the semantics
of `update_region`, not a wiring change — and it will alter the *existing* `clear_and_flatten` call
path's behaviour, which is not currently in scope.

---

## 1. ORDERING TRAP — subscribers do exist in time, but they fire at the WRONG MOMENT

### The real call order

```
game_world.gd:110   await terrain_manager.generate_terrain()   -> terrain_ready
game_world.gd:129   _on_terrain_ready()
game_world.gd:141-144   water_system.initialize() / generate_water_bodies()
game_world.gd:150-155   gameplay_grid = new(...) ; build_from_terrain()
game_world.gd:166-168   GroundClutter.new() ; clutter.setup(self)
                          -> ground_clutter.gd:121 connects region_rebuilt
game_world.gd:172-173   is_world_ready = true ; world_ready.emit()
--- later frame ---
game_flow.gd:262    while not world.is_world_ready: ...
mission_generator.gd:546  build_patrol_world()
mission_generator.gd:554    planner.place_firebase_main()
site_planner.gd:553           _terrain.modify_terrain(center, 215.0, ...)   << THE FLATTEN
site_planner.gd:556-557       clear_and_flatten() x5 (FSB_CLEAR_DISCS)
mission_generator.gd:563-565  DamageSystem.apply_damage() x4-8 (first_sign craters)
mission_generator.gd:596-606  NavBaker.queue_sites()
```

**Verdict on the stated worry: the ordering is FINE for existence.** Grid (`:155`) and water (`:144`)
are constructed inside `_on_terrain_ready`, and the firebase flatten happens in `build_patrol_world`,
which `game_flow.gd:262` gates behind `is_world_ready`. A connection made at `_on_terrain_ready` is
live before any world-build `modify_terrain` fires. Good.

**But the sub-frame ordering is the actual trap, and it is vicious.**

`site_planner.clear_and_flatten` (`:110-116`):

```
110  func clear_and_flatten(center, radius):
111      var zone_id := ClearingSystem.create_zone(center, radius)
112      ClearingSystem.set_zone_stage(zone_id, CLEARED)
113/114  _veg.clear_area(...)
115/116  if _grid: _grid.update_region(center, radius)
```

And `clearing_system.gd:122-131`:

```
122  func set_zone_stage(zone_id, stage):
127      zone.stage = stage
130      _apply_stage_changes(zone)      -> :173 terrain_manager.modify_terrain(...) -> region_rebuilt EMITS HERE
131      _update_vegetation_map(zone)    <- THE CLEARING MASK IS WRITTEN *AFTER* THE EMIT
```

**`region_rebuilt` is emitted BEFORE `_update_vegetation_map` writes the clearing mask.** A
synchronous grid subscriber calling `update_region` on that emit runs `_density_at`
(`gameplay_grid.gd:176-182`), which reads `clearing_system.get_vegetation_density` — **the
still-uncleared mask**. It would recompute the pad as full jungle, then `clear_and_flatten:116`
would immediately recompute it correctly. Net: wasted work, and if the direct call at `:116` were
ever deleted, **the firebase pads and every village footprint would silently stop being cleared in
the AI grid** — dense jungle cover and 2.2x movement cost stamped across a bulldozed parade ground.

`GroundClutter` already learned this the hard way; the comment at `ground_clutter.gd:173-176` states
it verbatim ("`clear_and_flatten` updates the gameplay grid AFTER `modify_terrain` — so re-scattering
synchronously would … read stale water/veg state"). Any new subscriber must be deferred/coalesced
the same way (`ground_clutter.gd:177-198`).

**Second-order ordering hazard nobody has named:** if the grid also uses `call_deferred` coalescing,
the deferred-call queue is FIFO by registration. `GroundClutter._accept` (`:202-209`) reads
`world.gameplay_grid`. The clutter flush **must** run after the grid flush, and the only thing that
guarantees that is *which node connected to `region_rebuilt` first*. Grid connects at
`game_world.gd:~155`, clutter at `:168`, so today it works — **by line ordering in a function, with
nothing asserting it.** That is a fossil-in-waiting: reorder those two lines in a future refactor and
grass re-scatters against a stale grid with no error anywhere.

---

## 2. DOUBLE-WORK / FOSSIL RISK — and a HARD BLOCKER

### Is `site_planner.gd:116` a fossil after the fix?

**No. It is the only correctly-timed call, and deleting it is a regression.** Per §1, the
`region_rebuilt` emit from `set_zone_stage` happens one line *before* the clearing mask exists. The
direct `_grid.update_region()` at `:116` runs after both `_update_vegetation_map` and
`_veg.clear_area`. The two calls are **not** the same call at two places — they are the same call at
two *different world states*, and only the later one is correct.

Also note the radii differ in practice: `modify_terrain` passes the affected rect derived from
`heightmap.modify_region(cell_center, ceil(radius/cell_size))` (`terrain_manager.gd:297-305`), while
`:116` passes `(center, radius)` directly. Similar, not identical.

### So is there double work?

Yes, and it is asymmetric per call site:

| Call site | modify_terrain fires? | grid work if subscribed | direct call at :116? |
|---|---|---|---|
| `place_firebase_main:553` (R=215) | yes | 7,569 cells | **no** — the R=215 flatten never touches the grid today |
| `clear_and_flatten:112` (via `set_zone_stage`) | yes (R=58-60) | ~625 cells | yes → **duplicate** |
| `DamageSystem:138` (crater R=20m) | yes | 81 cells | no |

Note the top row: **`place_firebase_main`'s R=215 flatten is the one that has NO grid update at all
today** — that is the real gap. The `clear_and_flatten` discs already update the grid. So the
proposal's value is concentrated entirely in the one call that `update_region` (per Objection 0)
cannot fix anyway.

### HARD BLOCKER — RAISED LOUDLY

> **If any council member concludes the fix requires deleting or moving
> `site_planner.gd:116` (`_grid.update_region(center, radius)`), THAT IS A BLOCKER.**
> `site_planner.gd` is owned by another agent this session and MUST NOT be edited from here.
> My finding is that `:116` should **NOT** be deleted (it is not a fossil — see above), so the
> fossil-law obligation does not bite. But if the Arbiter decides the duplicate must go, this work
> **cannot ship from this worktree** and must be sequenced behind the other agent's change.
>
> A second, softer blocker in the same file: the deeper correct fix is to move `region_rebuilt.emit`
> in `clearing_system.gd:130-131` to *after* `_update_vegetation_map` — that is `clearing_system.gd`,
> not `site_planner.gd`, so it is reachable. But it changes the emit contract for the *existing*
> `GroundClutter` subscriber and must be probed.

---

## 3. PERF — the water subscription is a combat-hitch generator. Reject it as specified.

Measured constants: `WorldConfig.MAP_SIZE = 1280`, `CELL_SIZE = 4.0` →
`HeightmapStorage.size = ceil(1280/4) = 320`, chunk-aligned to **320**. So
`water_map_size = 320` → **102,400 cells**.

`WaterSystem.generate_water_bodies()` (`water_system.gd:78-115`) is a **whole-map** operation with
**no region parameter**:

- `clear()` (`:85` → `:409`) — `queue_free()`s the `CombinedWater` MeshInstance3D, wipes
  `water_bodies`, `water_by_chunk`, `water_map.fill(0)`, resets `_next_id = 0`, drops `_hydrology`.
- `HydrologyMap.generate(_heightmap)` at `downsample = maxi(1, round(320/450)) = **1**`
  (`:119-123`) — i.e. **full-resolution 320x320 flood-fill + flow accumulation, no downsampling at
  all** on this map size. This is the single most expensive routine in world build.
- `extract_static_bodies` + `_create_static_body` per body, each running `_cells_to_polygon`
  (`:210-218`, PondDetector polygon trace + simplify).
- `_build_combined_water_mesh` (`:231-269`) — rebuilds every quad for every static body
  (`_append_static_quads` does a `_cell_distance_to_edge` search up to 20 cells **per cell**,
  `:341-347`) plus every river ribbon; allocates a fresh ArrayMesh + ShaderMaterial.
- `_build_water_map_from_hydrology` (`:388-406`) — 102,400-iteration loop.

**A LARGE_EXPLOSION crater is `radius_cells = 5` × `cell_size 4.0` = a 20 m radius disc, ~314 m².
The map is 1,638,400 m². The proposal recomputes 100% of the hydrology for 0.02% of the map, per
grenade.** `DamageSystem.MAX_DEFORMS_PER_MISSION = 40` (`damage_system.gd:69`) caps it at 40 full
map hydrology regenerations per mission — every one of them a synchronous main-thread stall, and the
ones that matter happen *during a firefight*, which is Pillar 1 territory.

Additional water-specific damage:

- **Non-locality.** Hydrology is a global flood/drainage model. A crater in one corner can shift
  pool surfaces and river traces **map-wide** — water visibly jumping in places the player never
  touched. That is worse than the stale water it fixes.
- **A one-frame double mesh.** `clear()` calls `queue_free()` (end-of-frame) while
  `_build_combined_water_mesh` adds the new mesh immediately — for one frame two coincident
  transparent water surfaces exist. At 40 craters, that flicker is visible.
- **ID invalidation.** `_next_id = 0` on every regen; anything holding a `WaterBodyData` id or
  reference across a crater is dangling. `water_by_chunk` consumers
  (`gameplay_grid.get_water_flow`, `get_water_at`) go through the dictionary so they survive, but
  the reset is a footgun for anything that caches.
- **Every crater becomes a pond.** LARGE_EXPLOSION digs `depth_m = 8.0`. A fresh hydrology pass over
  a fresh 8 m depression will classify it as standing water. That may be *desirable* — but it
  **collides directly with `mission_generator.gd:566-567`, which already deliberately calls
  `_spawn_crater_water()` for 40% of first-sign craters.** Ship the subscription and that hand-rolled
  system becomes a genuine ADR-023 fossil/double-source. That is a real fossil obligation created
  *by* this fix.
- **World build cost.** `build_patrol_world` fires ~1 (FSB) + ~5 (clear discs, via `set_zone_stage`)
  + 2-4 per village clear + 4-8 crater `modify_terrain` calls ≈ **12-20 emits in one synchronous
  stretch** (the figure `ground_clutter.gd:173` already records). Naive water resubscription = 12-20
  full hydrology passes at load. Even coalesced to one deferred flush, it is one extra full water
  regen per build — and it must be sequenced against `generate_wetness_texture` (`:531-578`, a
  4-pass 102,400-pixel `Image.get_pixel`/`set_pixel` distance field ≈ 3.7 M pixel ops), which
  `game_world.gd:145-147` only ever runs once and which nothing in the proposal re-runs. **Ship the
  water resubscription without also re-running the wetness texture and the terrain's shore-blend
  shader goes stale relative to the water it is blending to — a NEW desync created by the fix.**

**Grid perf, by contrast, is cheap and fine:** FSB flatten 7,569 cells, clear disc ~625, crater 81 —
each cell doing one `_density_at` (an `Image.get_pixel` on a 512² map). Sub-millisecond for craters.
The grid subscription is affordable; the water one is not.

**Counter-proposal (name the sacrifice):** water gets *no* subscription in this wave. Accept that
craters do not create ponds and do not drain them, i.e. **the water map stays a build-time truth**.
Sacrificed: a crater dug into a creek bank still reads as dry land to `is_water`. Cheap, correct,
and honest. If water must respond, it needs a genuine `regenerate_region(Rect2)` — which does not
exist and is a real piece of work, not a wiring change.

---

## 4. REENTRANCY

**No recursion today.** Nothing in `GameplayGrid`, `WaterSystem`, or `GroundClutter` calls
`modify_terrain`. `WaterSystem` is read-only against the heightmap.

**But there is no guard, and the surface is wide.** `terrain_manager.modify_terrain` (`:296-305`)
mutates the heightmap, rebuilds chunks (`_rebuild_chunks_in_region` → `_rebuild_chunk_immediate` →
`vegetation_manager.generate_for_chunk`), *then* emits. A subscriber that synchronously called
`modify_terrain` — a plausible near-future feature: "water erodes a channel after a crater", "clutter
flattens a shelf" — would recurse with **no depth counter, no in-flight flag, and no cycle
detection**, and each level does a full chunk rebuild. `DamageSystem` has a
`MAX_DEFORMS_PER_MISSION` cap but that is a *mission* counter, not a reentrancy guard, and
`ClearingSystem._apply_stage_changes` has none at all.

**Recommendation:** add an `_emitting_region_rebuilt` bool in `terrain_manager.modify_terrain` that
`push_error`s (or queues) on reentry. Cheap, and it converts a future silent stack overflow into a
loud failure. Independent of whether this proposal ships.

**Signal storm is real without coalescing.** 12-20 synchronous emits per world build, up to 40 more
per mission. Any subscriber that does non-trivial work MUST use the
`_dirty` + `call_deferred` pattern from `ground_clutter.gd:177-198`, not raw synchronous handling.

---

## 5. THE "5TH DIVERGENT INSTANCE" FRAMING IS INCOMPLETE — there are at least NINE

Grepped `get_height_at|sample_world|elevation\[|get_normal_world` across `scripts/`, `terrain/`.
Build-time height bakers that are **not** subscribed to `region_rebuilt`:

| # | Consumer | Where it bakes | Stale after… |
|---|---|---|---|
| 1 | `GameplayGrid.elevation[]` / `slope[]` | `gameplay_grid.gd:128,132` (once) | any flatten/crater — **and `update_region` will NOT fix it (Objection 0)** |
| 2 | `WaterSystem.water_map` / bodies / mesh | `water_system.gd:78` (once) | any flatten/crater |
| 3 | **`NavBaker` terrain mesh** | `nav_baker.gd:226-229` — 4 `get_height_at` per quad, baked into the navmesh; queued at `mission_generator.gd:606`, i.e. **after** the build craters but never again | **every in-play crater.** AI pathing over a hole that isn't in the navmesh. This is arguably worse than the grid: an 8 m-deep crater is a nav-invisible pit. |
| 4 | **Vegetation placement cache** | `terrain_manager.gd:76-87` `_rebuild_chunk_immediate` deliberately **preserves** `vegetation_manager._chunk_placements` and re-materialises from cache (comment at `:325-328`). Y values in that cache are pre-crater. | every crater — trees around a crater keep their old Y and float/sink |
| 5 | `TopoMap` height texture | `topo_map.gd:42` — `MAP_PIXELS²` `get_height_at`, baked once | any flatten — the player's map shows the pre-firebase hill |
| 6 | Placed structures | `site_planner.gd:182-183` `place_structure` | a later `modify_terrain` overlapping an earlier structure. `build_patrol_world` fires craters at `:563` **after** villages are stamped at `:556-562` — a first-sign crater within 20 m of a hut floats it. |
| 7 | Placed props / animals | `site_planner.gd:332-333` `place_prop` | same |
| 8 | Civilians / chickens / bench / patrols | `mission_generator.gd:593, 637, 649`, `_seat` at `:587` | same — all seated before or between crater passes |
| 9 | `PunjiTrap` | `site_planner.gd:247` → `punji_trap.gd:23-24` | same |

Mitigated already: `TerrainWatchdog` (`terrain_watchdog.gd:51-57`) re-seats *CharacterBody3D* nodes
in `enemies`/`allies`/`civilians` every 2 s — so #8's living NPCs self-heal within two seconds.
Static props (#6, #7, #9), the navmesh (#3), the veg cache (#4) and the topo map (#5) have **no**
recovery path whatsoever.

**So: the "5 instances" framing undersells the problem by roughly half, and it omits the one with
the worst gameplay consequence (NavBaker).** Subscribing 2 of 9 consumers and declaring the wire-is-
law channel "closed" would be exactly the kind of map-lie ADR-023 exists to prevent.

---

## VERDICT / WHAT IS SACRIFICED

Everything has a price. Naming them:

- **Ship the grid subscription as specified** → you sacrifice honesty: you get a wire that looks like
  the height-reseat channel and reseats no heights. Cost: a future agent trusts it.
- **Fix `update_region` to re-sample elevation/slope/type** → you sacrifice determinism review: the
  existing `clear_and_flatten` path's behaviour changes (CLIFF cells can now un-cliff, `is_passable`
  can now be *cleared*), which touches site planning, AI LOS, and pathing all at once. Needs a probe.
- **Ship the water subscription** → you sacrifice in-combat frame time (a full-res 320² hydrology
  pass + full water mesh rebuild per grenade, up to 40/mission), map-wide water stability, and you
  create a new fossil (`_spawn_crater_water`) plus a new desync (wetness texture / shore blend).
- **Skip water entirely** → you sacrifice crater-pond fidelity and creek-bank accuracy. Cheapest,
  most honest option. Recommended.
- **Skip NavBaker** → you sacrifice AI pathing over in-play craters, which is a Pillar 1 problem and
  is *currently unnamed in the plan*.
