# TECHNICAL DIRECTOR / GODOT SPECIALIST — THE ROADS NETWORK

**Session:** 2026-07-20_roads_network · **Charge:** Q1 (where road data lives) + Q5 (minimum system)
**Method:** read the code, not the brief. Every claim below carries a `file:line`.

---

## VERDICT IN ONE PARAGRAPH

**Do NOT add `TerrainType.ROAD`.** The blast radius is 20 code sites and 5 test sites, four of
which fail **silently** through `Dictionary.get()` defaults and two of which are outright
wrong-behaviour. And it has a hard blocker the briefing did not see: adding the road check inside
`GameplayGrid._determine_terrain_type` **fails `test_one_classifier`** on contact
(`tests/test_one_classifier.gd:52-59`), because `VegetationManager._determine_terrain_type`
(`terrain/vegetation/vegetation_manager.gd:276-280`) would not agree. Fixing *that* forces the road
into `TerrainZoning.classify` and therefore into VegetationManager's **parallel enum**
(`vegetation_manager.gd:6-13`), which has only 6 members and no WATER/CLIFF — i.e. the enum change
propagates into exactly the two-classifier divergence bead 6od4 was opened to kill.

**Build instead: `RoadNetwork` — a polyline object shaped exactly like `HydrologyMap.rivers`, whose
gameplay effect enters the grid through the CLEARING MASK that already exists.** Zero enum changes,
zero dict changes, zero shader work, zero new draw calls, and — this is the important part — it
survives `rebuild_rect` *for free through shipped code*, because `_density_at`
(`terrain/core/gameplay_grid.gd:169-175`) re-reads the clearing mask **inside `_seat_cell`**. That
is the persistence property Candidate A was reaching for. It already exists. We do not have to build it.

---

## Q1 — WHERE DOES ROAD DATA LIVE?

### The crux, restated correctly

The briefing frames the crux as "`_seat_cell` is the one writer, so put roads inside it." True but
incomplete. `_seat_cell` (`gameplay_grid.gd:121-142`) writes **two** channels:

- `terrain_type[idx]` ← `_determine_terrain_type(...)` (`:133`) — derived, wiped every re-seat
- `vegetation_density[idx]` ← `_density_at(...)` (`:142`) — derived, **and `_density_at` consults
  an external persistent mask** (`:171-174`)

The second channel is a **re-seat-proof override channel that already exists and already ships.**
`ClearingSystem.vegetation_map` (`terrain/systems/clearing_system.gd:56-57`) is a 512² world-space
raster, starts at `fill(1.0)` (`:75`), is only ever lowered, and is merged as a MINIMUM at
`gameplay_grid.gd:174`. Craters, firebase clearance, and every future re-seat re-read it.

So the honest statement of the crux is: **the grid already has a persistent override lane. It runs
through density, not through terrain_type.** The question is whether roads need terrain_type
*semantics* at all, or whether density + a geometric query is enough. It is enough, and I show that
consumer by consumer below.

### Candidate A — `TerrainType.ROAD` + mask inside `_determine_terrain_type`

#### FULL BLAST RADIUS

Legend: **HARD** = compile/crash · **SILENT** = wrong value, no error · **BEHAVIOUR** = visibly wrong
· **FREE** = existing guard already handles it.

| # | Site | file:line | Effect |
|---|---|---|---|
| 1 | `enum TerrainType` | `terrain/core/gameplay_grid.gd:15-24` | the edit itself; `ROAD = 8` |
| 2 | `MOVEMENT_COSTS` | `terrain/core/gameplay_grid.gd:27-36` | **SILENT** — see #21 |
| 3 | `COVER_VALUES` | `terrain/core/gameplay_grid.gd:39-48` | **SILENT** — see #22 |
| 4 | `_estimate_vegetation` | `terrain/core/gameplay_grid.gd:281-291` | falls to `_: return 0.0` (`:291`). Correct by accident, undocumented |
| 5 | `_determine_terrain_type` | `terrain/core/gameplay_grid.gd:269-278` | the insertion point |
| 6 | **`_apply_riparian_belt`** | `terrain/core/gameplay_grid.gd:215, 222` | **BEHAVIOUR** — skip list is CLIFF/WATER only. Any road within `RIPARIAN_M = 22.0` (`:151`) of a watercourse is **overwritten to LIGHT/MEDIUM/HEAVY_JUNGLE** at `:222`. Rivers are where roads and trails actually go. Must add ROAD to the `:215` skip |
| 7 | `_roof_the_creeks` | `terrain/core/gameplay_grid.gd:241, 254` | reads WATER only — unaffected |
| 8 | **`boost_vegetation`** | `terrain/core/gameplay_grid.gd:488` | **BEHAVIOUR** — skip list is CLEAR/WATER/CLIFF. A road through a hamlet density centre gets thickened to `floor_density`. Must add ROAD |
| 9 | `mark_cleared` | `terrain/core/gameplay_grid.gd:458-472` | writes `CLEAR` over roads. Already ephemeral (next re-seat restores) — accept |
| 10 | `has_line_of_sight` | `terrain/core/gameplay_grid.gd:400-410` | tests CLIFF/HEAVY_JUNGLE only — unaffected |
| 11 | `get_terrain_name` | `terrain/core/gameplay_grid.gd:499-509` | prints `"Unknown"` until amended |
| 12 | `print_stats` | `terrain/core/gameplay_grid.gd:512-524` | iterates `TerrainType.values()` (`:514`) — self-adjusting, **FREE** |
| 13 | **`TerrainZoning`** | `terrain/core/terrain_zoning.gd:8-11, 17-21, 74-85` | **HARD BLOCKER.** The declared ordinal contract lives at `:8-11`. `classify()` is a pure static of `(height, wx, wz, seed)` with **no position→road channel**. Putting roads only in the GameplayGrid wrapper breaks #27 |
| 14 | **`VegetationManager.TerrainType`** | `terrain/vegetation/vegetation_manager.gd:6-13` | **HARD** — parallel enum, 6 members, no WATER/CLIFF. `ROAD = 8` opens a hole at 6,7. The ordinal contract at `terrain_zoning.gd:8-11` must be renegotiated across two files |
| 15 | `TYPE_SPECIES` | `terrain/vegetation/vegetation_manager.gd:48-55` | **FREE** — `.get(ttype, [])` at `:458` → empty pool → `continue` at `:459`. No species on roads, for free |
| 16 | `TYPE_PROPS` | `terrain/vegetation/vegetation_manager.gd:62-69` | `.get(terrain_type, [0.0])` at `:340` safe; **`TYPE_PROPS[ttype]` at `:461` is a hard index** — only unreachable because of the `:459` guard. Fragile, one refactor from a crash |
| 17 | `JunglePatchLayer.TYPE_DENSITY` | `terrain/vegetation/jungle_patch_layer.gd:18-23, 41-47, 221` | **FREE** — `if not TYPE_DENSITY.has(ttype): continue` at `:221`. No canopy patches on roads, for free |
| 18 | `TerrainChunk._get_terrain_color` | `terrain/core/terrain_chunk.gd:198-214` | **BEHAVIOUR** — hardcoded magic ints `1:` and `5:` at `:207-211`, no default case. A road renders base green (`:214`). Invisible until amended |
| 19 | `PaddyStamper.RICE_PADDY` | `scripts/world/paddy_stamper.gd:13` | mirrors ordinal 1 — unaffected |
| 20 | `SitePlanner` | `scripts/world/site_planner.gd:101-102` | rejects WATER/CLIFF only. Roads become legal hut ground — a village stamps **on top of** the road |
| 21 | **`PatrolGenerator._is_walkable`** | `scripts/enemies/patrol_generator.gd:71-75` | **SILENT** — `MOVEMENT_COSTS.get(tt, 99.0)` (`:74`) → an unlisted ROAD is cost **99 = impassable**. VC patrols would refuse to cross their own roads, with no error |
| 22 | **`AmbushPlanner._cover_nearby`** | `scripts/enemies/ambush_planner.gd:84` | **SILENT** — `COVER_VALUES.get(..., 0.0)` → road = zero cover. Benign here, but the same shape as #21 |
| 23 | `AmbushPlanner._los_blocked` | `scripts/enemies/ambush_planner.gd:99-101` | list membership test — unaffected |
| 24 | `Player` footstep + speed | `scripts/player/player.gd:196-199, 841-842` | no road case; `:842` hard-indexes `MOVEMENT_COSTS[RICE_PADDY]` (fine) but roads get no speed benefit |
| 25 | `test_ambush_sites` | `tests/test_ambush_sites.gd:12-19, 34-35, 94, 113` | hand-maintained COVER/OPEN type lists |
| 26 | `test_grid_queries` | `tests/test_grid_queries.gd:45-60` | histogram assertions over produced types |
| 27 | **`test_one_classifier`** | `tests/test_one_classifier.gd:18-19, 52-59, 82-84` | **FAILS ON CONTACT.** `WATER := 6` / `CLIFF := 7` hardcoded at `:18-19`; the exclusion at `:53-54` lets ROAD=8 through; `:58` compares grid vs veg verdict. Grid says 8, veg says 3/4/5 → `disagreements > 0` → **red** |
| 28 | `test_los_determinism` | `tests/test_los_determinism.gd:80` | writes HEAVY_JUNGLE directly — unaffected |
| 29 | `probe_riparian` | `tools/probe_riparian.gd:65` | WATER comparison — unaffected |
| 30 | Fossil probe | `tests/fossil_baseline.json` (`ceiling` 27, `count` 27) | a new enum member unreferenced by any consumer is a **new fossil** → the ratcheting probe **fails the build** (`tests/test_fossils.tscn`) |
| 31 | Serialization | — | **NONE FOUND.** No `*.gd` grep hit serializes `terrain_type`; the grid is rebuilt from seed at `scripts/levels/game_world.gd:153-158`. The save format is safe. Worth stating explicitly so nobody "checks" it later |

**Tally: 20 production sites + 5 test sites. 4 silent failures (#2/#21, #3/#22, #16, #18),
2 behaviour bugs (#6, #8), 2 hard blockers (#13/#14, #27), 1 build-breaker (#30), 4 free.**

#### Ruling on A

**Unacceptable, and not because it is large — because of its shape.** Half the failures are silent
`.get()` defaults that produce a *working game that is quietly wrong*, which is this project's
documented worst failure mode (fossil law, pointer law: "a lie in the map"). And #13→#14→#27 means
the change cannot be contained in `GameplayGrid`; it must be pushed into the ONE classifier and
therefore into a second enum in a second file. **You cannot add a terrain type to one classifier
without adding it to both, and the moment you do, roads are a world-generation concern rather than
a site-connection concern.** That is the second world-gen pass the constraint forbids.

There is also an **ordering problem the briefing missed**, which is fatal to A independently:

`TerrainZoning.configure()` runs at step 2 (`terrain/core/terrain_manager.gd:122`), rivers carve at
step 3 (`:127`), chunk meshes + VegetationManager classification at step 4 (`:212-219`), the grid
builds at step 6 (`game_world.gd:153-158`). **The sites a road connects do not exist until step 7**
(`mission_generator.plan_patrol_world`). A road mask consulted inside `classify()` would therefore
be empty on the first pass and require a full re-classification of every touched chunk afterwards —
including blowing `VegetationManager._chunk_terrain` and `_chunk_placements`, which
`terrain_manager.gd:306-309` explicitly warns causes trees to respawn in their original positions.

### Candidate C — height only, no grid semantics

Rejected on its own terms; see the height ruling below. It also delivers nothing: convoys need
waypoints (data), `ROAD_NEAR_M` needs a distance query (data), the topo sheet needs a polyline
(data). Height is the one thing roads do **not** need.

### RECOMMENDED — Candidate A′: geometry is the authority, the clearing mask is the grid channel

```
RoadNetwork (RefCounted, owned by GameWorld beside `hydrology`)
  roads: Array[Dictionary]   # {points: PackedVector2Array (world XZ), width: float}
                             # deliberately the SAME shape as HydrologyMap.rivers
                             # (terrain/core/hydrology_map.gd:87)
  distance_to_road(p: Vector3) -> float
  nearest_point(p: Vector3) -> Vector3
  route_between(a: Vector3, b: Vector3) -> PackedVector2Array
```

**One object. Four readers. No second classifier.**

| Consumer | How it reads roads | Cost |
|---|---|---|
| `AmbushPlanner` `ROAD_NEAR_M` (`scripts/enemies/ambush_planner.gd:15`) | `RoadNetwork.distance_to_road(site) <= 80.0` — exact, no raster quantisation | ~1 line in `plan()` |
| `Convoy.route` (`scripts/vehicles/convoy.gd:18, 38-42`) | the polyline **is** the waypoint array | 0 |
| Vegetation removal along the corridor | `ClearingSystem` lowers `vegetation_map`; `_density_at` (`gameplay_grid.gd:169-175`) merges it as a minimum **inside `_seat_cell`** | 0 new code |
| Visible road surface | `clearing_texture` (`clearing_system.gd:59`) mixed by alpha in the terrain shader (`terrain/shaders/terrain.gdshader:100-101`) | 0 new draw calls |
| Ground clutter suppression | `_accept` (`scripts/world/ground_clutter.gd:202-209`) already drops jungle-only layers below 0.3 density — which the mask now guarantees | 0 |
| Topo sheet (Q4, ux-designer's call) | draws the polyline | outside my charge |

**Why this survives `rebuild_rect`:** it does not need to. `terrain_type` is allowed to keep saying
GRASSLAND on a road cell — nothing reads terrain_type to answer "is this a road". The two things
that *must* persist (no vegetation, brown ground) persist because the clearing mask is external to
the grid and re-consulted on every `_seat_cell`. Craters on roads Just Work.

**What is sacrificed** (Law 2 — no free lunches):
1. **No movement-cost bonus on roads from the grid.** `MOVEMENT_COSTS` still returns the biome cost.
   If roads should be faster to walk, the player/AI must call `distance_to_road()`. That is one more
   call site, and it is the honest price of not touching the enum. Note the precedent: `player.gd:841`
   *already* special-cases RICE_PADDY by hand, so this is the shipped idiom, not a new one.
2. **`get_terrain_type()` will never say "road".** Any future feature that wants to reason about
   surfaces via terrain_type will have to be told this. Bead it as a known limit, don't discover it.
3. **The road's gameplay footprint is the width of the clearing stamp**, i.e. quantised to the 512²
   mask (2.5 m/px at `MAP_SIZE = 1280.0`, `scripts/levels/world_config.gd:9`). A 6 m trail is ~2 px.
   Fine for de-vegetation; too coarse for a crisp visual edge. Accepted — see Q5.

### DEFECT FOUND EN ROUTE (independent of roads — bead it)

`_apply_riparian_belt` writes `vegetation_density[n] = gallery` at `gameplay_grid.gd:220-221`
**without consulting the clearing mask**, unlike `_density_at` (`:169-175`). It runs *after*
`_seat_cell` in both `build_from_terrain` (`:110-112`) and `rebuild_rect` (`:449`).

**Consequence today, roads or no roads: any cleared ground within `RIPARIAN_M = 22.0 m` of a
watercourse is silently re-vegetated to 0.55–0.95 density on the next re-seat.** That includes the
firebase clearance and every crater near a creek. The AI's `_sight_cap` then reads concealment on
ground the player sees as bare dirt — the exact class of lie `test_one_classifier` exists to prevent,
in the one channel that test does not cover.

Fix: clamp `gallery` by the clearing mask before the `:220` comparison, mirroring `_density_at`.
This is a prerequisite for roads (a road along a river is the most Vietnamese thing in the game) and
a live-bug fix on its own. **Recommend a separate bead, fixed first, with a probe.**

---

## Q5 — THE MINIMUM ROAD SYSTEM

### Geometry, shader mask, or data? — **Data + the existing mask. No new meshes, no new shader.**

We are at **18.8 native FP with jungle at 71% of frame**, and headless reports GPU-ms as 0
(`--headless` gives no honest frame number), so **any proposal whose defence is "it's probably
cheap" must be rejected on principle** — we cannot check it this session. That constraint selects
the design for us: pick the option that is **arithmetically incapable of costing GPU time.**

- **Road meshes (ribbon geometry): REJECT.** New MeshInstance3Ds, new draw calls, new material, a
  seam-with-terrain problem, and a Z-fight problem on a heightmap we do not grade. Unmeasurable cost
  in a session where we cannot measure.
- **A new shader mask / new sampler: REJECT.** `terrain.gdshader:11-14` carries a scar in its own
  comments about exactly this — an unbound sampler returned `(1,1,1,1)` and **painted the terrain
  white on hilltops.** Adding a `road_texture` uniform re-opens that failure mode for a channel we
  already have.
- **The EXISTING `clearing_texture`: ACCEPT.** `clearing_system.gd:59, 77-78, 207-215`; consumed at
  `terrain.gdshader:15, 100-101` as `color = mix(color, clearing.rgb, clearing.a)`. It is already
  bound (`scripts/levels/game_world.gd:125, 399-401, 433-435`), already sized 512², already
  world-space UV'd, already sampled every frame whether we write to it or not. **Painting a road
  into it is free at the pixel level and costs one `Image.set_pixel` loop at build time.**

**Net GPU effect of the recommended road system is NEGATIVE — it makes the game faster.** A road
lowers `vegetation_map`, which lowers `vegetation_density`, which (a) drops jungle-only
`GroundClutter` layers via `_accept` (`ground_clutter.gd:207`) and (b) removes canopy patches via
`TYPE_DENSITY.has()` (`jungle_patch_layer.gd:221`). Roads **delete** instances from the 71% of frame
that is jungle. I will not claim a number — I cannot measure one — but the sign is certain.

### What I would CUT

| Cut | Why |
|---|---|
| **Bridges** | No mesh, no collision, no authoring. Route *around* water: the A* penalty below makes channels expensive but not infinite, so a road fords at the narrowest crossing and the player wades. Vietnam had far more fords than bridges |
| **Road meshes / ribbon geometry** | see above |
| **Height grading (roadbed)** | see the height ruling |
| **Junctions as a solved problem** | Star topology from `p["fsb_center"]` (`scripts/missions/mission_generator.gd:482`) to each site. Braiding (below) makes junctions *emerge*; no intersection code, no T-piece assets |
| **Road-following vegetation clearing as new code** | It is the clearing mask. Already shipped |
| **Road surface footstep audio, tyre tracks, roadside props, mile markers, decals** | Pure polish. Nothing is blocked by their absence. Later, cheaply, once roads are proven |
| **A new terrain type, new enum, new dict entries** | Q1 |

### What is IN (the whole system)

1. `RoadNetwork` (RefCounted, ~150 lines) — storage + `distance_to_road` + A* + smoothing.
2. Routing at **step 7.5**, immediately after `plan_patrol_world` (`scripts/main/game_flow.gd:284`,
   declared "pure positions, no side effects") and before `build_patrol_world` (`:285`), so sites
   stamp with knowledge of the roads rather than the reverse.
3. Corridor stamp into `ClearingSystem` (vegetation_map + clearing_texture), height flattening **0**.
4. One `gameplay_grid.rebuild_rect(corridor)` over the union bounds — **one call, not one per
   segment**, using the same path `game_world.gd:405-429` already runs for craters.
5. Wire `ROAD_NEAR_M` in `ambush_planner.plan()` as a **soft score term, not a hard reject** — see
   the warning below.
6. Wire `Convoy.route` from a road polyline.

### ROUTING — A* over the GameplayGrid cost field. Yes. With three amendments.

Straight polyline + terrain-following is wrong here and will look wrong: a straight line from the
firebase to a village on a `STEEP_MOUNTAINS` preset (`terrain_manager.gd:325-336`) climbs cliffs and
crosses carved channels at right angles. A* is also *nearly free*: the grid is 256² with
`MOVEMENT_COSTS` (`gameplay_grid.gd:27-36`), `is_passable` (`:54`) and `elevation` (`:50`) already
populated, and it runs **once, behind the loading screen.**

**Amendment 1 — road cost ≠ movement cost.** Use a road-specific cost:
`base = MOVEMENT_COSTS[type]`, `+ slope_penalty` from `slope[]` (`:51`) — roads hate grade far more
than infantry do, so weight slope steeply and make anything above ~0.35 effectively closed —
`+ WATER_CROSSING_PENALTY` that is **large but finite** (e.g. 40×). Finite is the design: the road
prefers to go around a channel, and when it must cross, it crosses at the cheapest (narrowest) point,
which is exactly where a ford belongs.

**Amendment 2 — smooth the result.** D8/8-way A* output is jaggy, the same defect
`_smooth_river_path` (`terrain_manager.gd:374-387`) already solves for channels with windowed
averaging. Reuse that treatment; do not invent a second smoother. Then decimate to ~15–25 m waypoint
spacing so `Convoy`'s 2.5 m arrival test (`convoy.gd:59`) is not tripping constantly.

**Amendment 3 — braid, don't branch.** Route firebase→site in decreasing order of distance, and give
already-laid road cells a large cost **discount** (e.g. ×0.2). Later routes then snap onto earlier
ones and peel off near their destination. Junctions emerge from the cost field. This is both how real
trail networks form and how we avoid writing junction code at all.

### HEIGHT — roads must NOT modify the heightmap. Three independent reasons.

1. **Hydrology.** `_carve_riverbed` (`terrain_manager.gd:393-416`) writes the heightmap at step 3,
   *before* chunk meshes, and `WaterSystem` derives its water_map from that same post-carve
   heightmap. `test_height_authority._check_channels` (`tests/test_height_authority.gd:239-259`)
   asserts every channel point returns `water.is_water(...)` true and is currently **10/10 with a
   100% wet channel**. A graded roadbed near a channel *raises* cells inside the carved groove.
   That drains it. That test goes red, and the failure would be attributed to hydrology, not to
   roads — a debugging trap of exactly the kind this project keeps setting for itself.
2. **Cost and thrash.** `modify_terrain` (`terrain_manager.gd:277-286`) rebuilds every overlapping
   chunk (`:290-311`) and emits `region_rebuilt`, which re-seats the grid **and** re-scatters
   `GroundClutter` (`ground_clutter.gd:177-198`). A 1280 m road stamped at 12 m granularity is ~100
   such calls. The firebase's single 215 m flatten disc is already the most expensive stamp in the
   build; this would be that, an order of magnitude over.
3. **It buys nothing.** `Convoy._physics_process` (`convoy.gd:63-70`) writes `lead_pos.x` and
   `lead_pos.z` and **never touches `lead_pos.y`.** A graded roadbed does not help a vehicle that
   does not sample height at all.

**Therefore: roads are SEATED on the terrain.** A* rejects cells above a slope threshold instead of
flattening them — the road goes around the hill, which is both cheaper and more correct.

### LIVE FINDING — convoys will float or sink the moment they are wired

`scripts/vehicles/convoy.gd:67-70` moves the lead vehicle in X and Z only; Y is never assigned after
spawn. Trailing vehicles (`:77-81`) are corrected on a `back` vector with `back.y = 0.0`, so they
inherit the same frozen altitude. On any non-flat ground the convoy drives at its spawn Y — through
hills, above valleys.

This is **not** a roads problem and roads do not fix it. `Convoy` needs a
`TerrainManager.get_height_at()` sample per frame per vehicle (`terrain_manager.gd:269-270`, O(1)
bilinear, no physics). It is ~4 lines. But it means **`ld0y` cannot be closed by delivering roads
alone** — the convoy would still be visibly broken on first contact. File it as a sibling bead and
fix it in the same wave, or the roads wave ships a feature that still does not work.

### WARNING to the systems-designer's Q3 — do not make `ROAD_NEAR_M` a hard gate

`AmbushPlanner.plan()` (`ambush_planner.gd:30-63`) already applies **three** hard rejects — keepout
(`:43`), paddy (`:46`), cover floor (`:50-52`) — over only `CANDIDATES = 16` samples (`:25`). Adding
a fourth hard reject at 80 m against a star-topology road network that has **no reason to pass near
VC camps** (`mission_generator.gd:544-593`) will drive the yield toward zero. Today the planner
returns sites; a naive road gate makes it return `{}`.

Wire `ROAD_NEAR_M` as a **weighted score term** alongside `cover_score` and `los_score` (`:54`), and
if a hard gate is genuinely wanted, first raise `CANDIDATES` and bias sampling toward the road
polyline rather than uniformly around the camp. The planner has a probe
(`tests/test_ambush_sites.gd`) — **prove the yield before and after, headless, and do not ship the
gate if the yield drops.** That is measurable this session; frame time is not.

---

## SUMMARY OF MY RULINGS

| Question | Ruling |
|---|---|
| **Q1 — where does road data live?** | `RoadNetwork` polyline object, shaped like `HydrologyMap.rivers`. **NOT** a `TerrainType` enum member |
| **Blast radius of the enum** | 20 production + 5 test sites; 4 silent, 2 behaviour bugs, 2 hard blockers, 1 build-breaker. **Unacceptable** |
| **How does it survive `rebuild_rect`?** | It does not need to — the clearing mask is external and re-read inside `_seat_cell` (`gameplay_grid.gd:169-175`). Shipped code, no new mechanism |
| **Q5 — geometry, shader, or data?** | **Data + the existing `clearing_texture`.** No meshes, no new sampler, no new draw calls |
| **Perf** | Net **negative** GPU cost (roads delete jungle instances). No number claimed — headless cannot measure GPU-ms, and I will not invent one |
| **Routing** | A* over the grid cost field, with a steep slope penalty, a large-but-finite water penalty, reuse of `_smooth_river_path`'s smoothing, and cost-discount braiding instead of junction code |
| **Height** | **Seat on terrain. Never grade.** Hydrology, cost, and the fact that `Convoy` ignores Y entirely |
| **Cut** | bridges · road meshes · grading · junction code · new terrain type · all surface polish |
| **Blockers found** | (a) `_apply_riparian_belt` bypasses the clearing mask — **live bug, fix first** · (b) `Convoy` never writes Y — **`ld0y` is not closable by roads alone** |
