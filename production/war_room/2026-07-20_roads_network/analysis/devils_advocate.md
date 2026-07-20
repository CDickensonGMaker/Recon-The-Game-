# DEVIL'S ADVOCATE — Q6: WHAT BREAKS?

**Session:** 2026-07-20 roads_network · **Charge:** name what is sacrificed. No free lunches.
**Method:** every claim below is either a `file:line` pointer or a probe I RAN this session (headless
only — no windowed run). Where I could not measure, I say so and I do not estimate.

---

## THE HEADLINE: the probe that is supposed to guard the rivers is HALF DEAD, and it passes anyway

The briefing says `test_height_authority` is 10/10 with a 100% wet channel and MUST stay there. I ran
it. It is 10/10. **And two of those ten checks cannot see a road.**

```
godot --headless --path . res://tests/test_height_authority.tscn
  carved channel points: 2467
  of those, WaterSystem reports water: 2467 (100.0%)
  worst bed-vs-surface gap where both exist: 0.00 m
  === PASS === (10 checks passed, 0 failure(s))
```

`0.00 m` over 2467 points is not a good result. **It is the signature of a check that measured
nothing.**

### Why the gap check (D2) is vacuous

`tests/test_height_authority.gd:262`:
```gdscript
if surf > -INF and surf > 0.0:
    worst_gap = maxf(worst_gap, absf(surf - bed))
```

`surf` comes from `WaterSystem.get_water_level_at()` (`water_system.gd:494-504`), which returns
`_hydrology.water_surface_full[idx]`. And `hydrology_map.gd:340-341` fills `_surface_h` with `0.0` and
then only ever writes it for **LAKE** (`:354`), **SWAMP** (`:362`) and **COASTAL** (`:413`).
`min_lake_depth` is `INF` by decree (`hydrology_map.gd:44-45`) so LAKE never fires. **A river/creek
channel cell keeps surface `0.0`.**

Therefore `surf > 0.0` is false at every carved river point, the body never executes, and
`worst_gap` is still its initialiser. `CHANNEL_TOL_M = 2.5` guards nothing. The probe reports
`water surface within 0.00 m of the carved bed` and calls it `ok`.

### Why the wetness check (D1) is also blind to roads

`WaterSystem.is_water()` (`water_system.gd:454-461`) reads `water_map`, a byte array **baked once**
inside `generate_water_bodies()`. Nothing in `TerrainManager.modify_terrain()`
(`terrain_manager.gd:277-286`) touches it — `region_rebuilt` re-seats `GameplayGrid` and re-scatters
clutter, and that is all. **No terrain edit has ever updated the water map.**

So: grade a road 3 m of fill across a creek. The bed rises above the (nonexistent) surface. `is_water`
still returns `true`, because it is reading a mask computed before the road existed. D1 stays at
100.0%. D2 stays at 0.00. **PASS.**

### Answering the question exactly as asked

- **Which assertion WOULD catch a road damming a river?** *None of them.* Not D1, not D2, not
  A/B/C (those are source-text and height-scale checks and never look at a road).
- **Which would NOT?** All ten.
- **Can a road dam a river?** Yes, and silently. `_carve_riverbed` cuts only `1.8 m`
  (`terrain_manager.gd:394`). A road embankment of two metres erases a channel outright.
- **Can it fill a channel and make it dry?** It can make it *dry in fact and wet in the query* —
  which is worse than dry, because now the AI's water avoidance, `_apply_riparian_belt`, paddy
  rejection and `SitePlanner._footprint_valid` all still believe there is a river in a place the
  player walks across on dry road.

### And this is not hypothetical — the firebase already does it, and got away with it by luck

`site_planner.gd:635` flattens `FSB_FLATTEN_RADIUS = 215.0` m to a single seat height, full plateau
inside ~171 m (`:474-478`). The AO is 1280 m across (measured: `GameplayGrid Initialized 256x256 grid
(5.0m cells)`). That plateau is ~9% of the map, and it is applied at build step 8 — **after** the
rivers were carved at step 3 and **after** `generate_water_bodies` baked the water map at step 5.

Any river passing within 215 m of the firebase is already being partially filled today, with the water
mask unchanged, and no probe can see it. At seed 42 no channel happens to be close enough for anyone to
have noticed. **That is not a passing test, it is an untested seed.**

**A road network is the thing that converts this from a rare seed to a guarantee**, because roads
connect sites, sites are spread across the AO, and connecting them means crossing drainage. Rivers are
the terrain feature roads intersect most.

> **Sacrifice named:** if you build roads without first repairing D1/D2, you will not merely risk
> breaking hydrology — you will break it *with a green suite*, which is how this project lost months
> to fossils in the first place.

---

## THE SECOND HEADLINE: the build is already red, and one of the ten fossils is the road constant

I ran the fossil probe. Before anyone writes a line of road code:

```
godot --headless --path . res://tests/test_fossils.tscn
fossils now: 36   baseline: 26
*** 10 NEW FOSSIL(S) - THE FOSSIL LAW (ADR-023) FORBIDS THIS ***
    + scripts/autoload/world_sim.gd:99   func dematerialize_far
    + scripts/autoload/world_sim.gd:86   func materialize_near
    + scripts/autoload/world_sim.gd:70   func update_player
    + scripts/enemies/ambush_planner.gd:15  const ROAD_NEAR_M
    + scripts/missions/friendly_patrol_group.gd:145  func is_pinned
    + scripts/missions/friendly_patrol_group.gd:149  func living_count
    + scripts/vehicles/convoy.gd:95  func resume
    + scripts/vehicles/convoy.gd:14  signal route_finished (emitted into the void)
    + scripts/vehicles/convoy.gd:12  signal waypoint_reached (emitted into the void)
    + scripts/weapons/weapon_data.gd:101 func get_bore_dir
=== FOSSIL PROBE FAIL ===
```

**Corrections to the briefing and to CLAUDE.md, per the no-drift law:** the baseline is `ceiling 26 /
count 26` (`tests/fossil_baseline.json:3-4`), not 27. CLAUDE.md still says 27. And the four road/convoy
symbols the briefing calls "dead today" are **not grandfathered** — they are live build failures.

### Q6.6 answered mechanically

Read `tests/test_fossils.gd:105-139`:

- **Burying a fossil does NOT fail the build.** A baseline entry that disappears prints
  `*** N FOSSIL(S) BURIED - good. Shrink the register ***` and never touches `_failures` (`:115-120`).
  The suite stays green; you are merely *told* to run `--write-baseline`.
- **Shrinking is safe and one-way.** `_shrink_baseline` (`:363-398`) keeps the intersection of
  register and reality and sets `ceiling = mini(old_ceiling, kept.size())`. It is structurally
  incapable of growth. Ratchet holds.
- **The ratchet fails the build on `count`/`ceiling` desync** (`_audit_register`, `:333-357`) — but
  only if you hand-edit the JSON. Which we are forbidden from doing anyway.
- **What actually fails the build is a NEW fossil** (`:122-131`). And ten already exist.

**So the road work does not risk the register — it is blocked by it.** `ROAD_NEAR_M`,
`convoy.resume`, `waypoint_reached` and `route_finished` are four of the ten reds, and they are
exactly the four symbols roads are meant to bring to life. Wiring them is not a fossil-law risk; it is
**four-tenths of the fix for a suite that is red right now**. The other six (`world_sim.*`,
`friendly_patrol_group.*`, `get_bore_dir`) are somebody else's debt and roads will not touch them.

> **But name the trap:** if roads ship as a *design* that convoys use only "later", `resume` /
> `waypoint_reached` / `route_finished` stay dead, the build stays red, and the next agent's cheapest
> path to green is `--grandfather`. That is the one forbidden move, and we would have created the
> pressure for it.

---

## THE THIRD HEADLINE: the world does not compile headless right now

Same run, before any probe output:

```
SCRIPT ERROR: Parse Error: Identifier "FriendlyPatrolGroup" not declared in the current scope.
   at: GDScript::reload (res://scripts/missions/mission_generator.gd:691)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
   at: .../field_director.gd:0 · equipment_manager.gd:0 · weapon_holder.gd:0 · player.gd:0
ERROR: Failed to load script "res://scripts/player/player.gd" with error "Compilation failed".
```

`scripts/missions/friendly_patrol_group.gd:8` declares `class_name FriendlyPatrolGroup` correctly.
The problem is the cache: `.godot/global_script_class_cache.cfg` (written today 14:49) contains
`LazyGroup` at line 507 and **zero** occurrences of `FriendlyPatrolGroup`. The class was added without
an editor import pass, so every headless run fails to compile `mission_generator` → `field_director` →
`player`.

`run_all_tests.ps1:73` treats `SCRIPT ERROR:` as a failure marker. **Any suite claim made from a
headless run on this tree is suspect until the class cache is regenerated.** `test_height_authority`
survives only because it sets `spawn_player_on_ready = false` and never needs `player.gd`.

> This is a precondition, not a road problem. But it means **"the suite is green" is not currently a
> statement anyone can make**, and the decree should not rest on one.

---

## Q6.2 — THE FIREBASE FLATTEN vs A GRADED ROAD

Order of operations, verified:

| # | Step | Pointer |
|---|------|---------|
| 3 | rivers carve heightmap | `terrain_manager.gd:126` → `_carve_riverbed :393` |
| 5 | `generate_water_bodies` bakes `water_map` | `water_system.gd:86` |
| 6 | `GameplayGrid.build_from_terrain()` | `gameplay_grid.gd:97` |
| 8 | `place_firebase_main` → 215 m flatten | `site_planner.gd:635` |

**The firebase flatten runs LAST, after everything.** It wins every argument, because
`modify_terrain` → `region_rebuilt` → `rebuild_rect` re-derives every grid cell it touched
(`gameplay_grid.gd:429-450`).

Consequences for a road that terminates at the gate:

1. **If the road grades BEFORE the flatten:** the last ~215 m of road is annihilated. Not visually —
   *geometrically*. The flatten lerps `h` toward `seat_norm` with weight `clamp(f/0.107)`, which is
   **1.0** for everything within ~171 m. The road's height edit is overwritten completely, and if the
   road painted anything into `terrain_type[]`, `rebuild_rect` erases that too.
2. **If the road grades AFTER the flatten:** it cuts a groove into a plateau that
   `fsb_main.glb`'s 652 collision bodies are seated on at a fixed `seat_y` (`site_planner.gd:646`).
   The P0 the flatten was built to fix ("a gate and a table" — 26 of 678 meshes poking through ground,
   `:619-621`) comes straight back at the gate, which is the one place the player is guaranteed to
   stand.
3. **Either way there is a discontinuity at the plateau rim** (~171–215 m), where the road's own grade
   meets a 65 m blend shoulder. A vehicle driving that rim is climbing a ramp the road never planned.

**It matters enormously, and neither order is safe.** The only safe answer is that the road **does not
grade inside the flatten disc at all** — it inherits the plateau. The road's height authority must
terminate at `FSB_FLATTEN_RADIUS`, and the segment from rim to gate must be a *painted* road on
already-flat ground, not a graded one. Anything else is two writers arguing over the same cells, which
is the exact failure mode this project has been paying for all year.

---

## Q6.3 — THE ONE-WRITER PROBLEM, and the `mark_cleared` question

**`mark_cleared` is not a live defect. It is a corpse.** `tests/fossil_baseline.json:28` grandfathers
`terrain/core/gameplay_grid.gd|func|mark_cleared` — zero callers, confirmed by the probe run above.
The briefing's premise ("mark_cleared has the SAME bug today") is half right: the *pattern* is there,
but it is unreachable, so it cannot misbehave. **It is a worked example of the bug, preserved in
amber.**

That makes it more useful than a defect: it is proof that this exact mistake has already been made
once here and had to be buried.

Would a road system make it worse? **It would make it real.** Roads are the first system with a
legitimate reason to want a persistent per-cell semantic that is not derivable from `(h, slope, wx,
wz)`. Today `_seat_cell` (`:121-142`) can rebuild any cell from four numbers. A road breaks that
closure. There are exactly two honest outcomes:

- **The road mask lives inside the derivation** (consulted by `_determine_terrain_type`), so
  `rebuild_rect` re-derives it for free and the one-writer property survives; or
- **the road is written into `terrain_type[]`** and the next crater within the rect erases it —
  `mark_cleared`'s bug, resurrected and now reachable.

There is no third option that keeps one writer.

### But Candidate A has a landmine the briefing does not name

Even if the road mask lives inside `_determine_terrain_type`, **`_apply_riparian_belt` overwrites
terrain types AFTER the seat**, and it skips only CLIFF and WATER:

```gdscript
# gameplay_grid.gd:215-222
if terrain_type[n] == TerrainType.CLIFF or terrain_type[n] == TerrainType.WATER:
    continue
...
terrain_type[n] = TerrainType.HEAVY_JUNGLE if gallery >= 0.85 else (...)
```

`RIPARIAN_M = 22.0`. **Every road cell within 22 m of any watercourse gets repainted as jungle** — and
22 m of a watercourse is precisely where a road crosses a river. The bridge/ford is the one place the
road is guaranteed to be erased. It also runs a *second* time on every `rebuild_rect`, dilated
(`:445-450`), so a crater 30 m from a bridge deletes the bridge's road semantics.

`boost_vegetation` (`:479-496`) has the same shape: it skips CLEAR/WATER/CLIFF and would happily grow
concealment on a road.

**Any ROAD member must be added to both skip-lists in the same change, or the road is jungle wherever
it matters most.**

---

## Q6.4 — THE ENUM: what silently misbehaves

I grepped every `TerrainType` site in the repo. Ranked by how quietly each one fails.

### Fails SILENTLY and changes gameplay — the dangerous ones

| Site | Behaviour with an unregistered `ROAD` | Severity |
|---|---|---|
| `patrol_generator.gd:73-75` | `MOVEMENT_COSTS.get(tt, 99.0)` → **99 = impassable**. `WALKABLE_COST_MAX` rejects it. **VC patrols would refuse to cross or walk a road.** | **P0.** The road becomes an invisible wall to the AI while the player walks it freely. Directly contradicts why we are building roads. |
| `gameplay_grid.gd:215-222` riparian belt | Road repainted as jungle within 22 m of water | **P0** (above) |
| `gameplay_grid.gd:488` `boost_vegetation` | Road gains vegetation density → AI concealment on open road | P1 |
| `ambush_planner.gd:84` | `COVER_VALUES.get(tt, 0.0)` → 0.0 | **Benign and correct** — a road *is* zero cover. Lucky, not designed. |
| `gameplay_grid.gd:281-291` `_estimate_vegetation` | `match` has `_: return 0.0` | Benign |
| `gameplay_grid.gd:376-420` LOS | ROAD is neither CLIFF nor HEAVY_JUNGLE → never blocks | Correct |
| `player.gd:196-199, 841-842` | ROAD ≠ GRASSLAND/RICE_PADDY → normal speed, no wade | Correct |
| `site_planner.gd:101-102` | ROAD is neither WATER nor CLIFF → **villages and firebases can be sited on top of roads** | P1, and it is a *world-generation* incoherence, not a bug |
| `terrain_chunk.gd:207-211` | `match` on magic `1`/`5`, no default → falls to base green | **The road is invisible.** A road you cannot see is a rail you cannot read (see Q6.7) |
| `vegetation_manager.gd:340` | `TYPE_PROPS.get(tt, [0.0])`, only `props[0]` read | No crash. But `TYPE_TREES` / `TYPE_PROPS` have no ROAD key → **no trees on roads by accident, which is right for the wrong reason** |
| `gameplay_grid.gd:512-524` `print_stats` | `TerrainType.values()` — self-updating | Fine |

### The classifier guard: `tests/test_one_classifier.gd`

This is bead 6od4's ratchet: it asserts `GameplayGrid._determine_terrain_type` ≡
`VegetationManager._determine_terrain_type` over 10,000 samples (`:52-59`).

**If the road mask goes inside `GameplayGrid._determine_terrain_type` and NOT inside
`VegetationManager`'s, the AI reads ROAD where the player sees MEDIUM_JUNGLE.** That is verbatim the
defect 6od4 exists to prevent: *"the AI conceals against ground the player cannot see."*

**And the guard will not catch it.** `test_one_classifier` builds a synthetic `GameplayGrid` with no
world, no `water_system`, and — crucially — **no road network**. The mask would be empty, both
classifiers would return base zoning, and the probe would print PASS while the shipped game diverged.

> **Corollary that decides Q1:** the road mask cannot live in `GameplayGrid`. It must live in
> **`TerrainZoning.classify()`** (`terrain/core/terrain_zoning.gd`), the one classifier both sides
> already route through, configured once from the same authority that configures `_lowland_ceiling`.
> Anywhere else is a fifteenth parallel world system by construction.

### Serialization

I found **no** persistence of `terrain_type` anywhere — no save hits, no `.tres`, nothing. The grid is
rebuilt from seed every load. Adding a member is therefore save-safe **today**. It also means the
road network must be regenerable from `mission_seed` alone, or ADR-010 determinism breaks and the
same-seed HARD resume (`ADR-007`) returns a different map.

### The sub-cell problem nobody has named

**Grid cells are 5.0 m** (measured at runtime: `[GameplayGrid] Initialized 256x256 grid (5.0m cells)`).
A Vietnam dirt road is 4–6 m wide. **A road is one cell wide, or less.**

So `TerrainType.ROAD` at grid resolution means:
- the road quantises to a 5 m staircase that will not line up with any drawn road;
- a cell is ROAD or it is jungle — there is no "road on the left half";
- the AI's road is off the player's road by up to 2.5 m everywhere, and by a full cell at every bend.

For an ambush check at `ROAD_NEAR_M = 80.0` this is fine (16 cells). For a convoy driving the road,
for `is_walkable`, and for "am I standing on the road" it is a lie of the same species as the one
`test_one_classifier` was built to kill.

---

## Q6.5 — PERF WE CANNOT MEASURE

**Any frame-cost number produced this session is a lie.** Headless reports GPU-ms as 0; windowed runs
are forbidden while the Summoner is at his desk. I did not produce one and no architect should.

**The honest thing to do** is not to estimate — it is to **build the version whose cost is bounded by
construction**, and say plainly that we still have not measured it:

| Road implementation | Added draw calls | Added instances | Measurable-this-session? |
|---|---|---|---|
| Data-only mask + terrain-shader tint | **0** (terrain shader already bound) | 0 | No — but bounded to one extra texture fetch in an already-running fragment shader |
| Road MultiMesh / decal strips | 1+ per chunk-segment | thousands | No, and unbounded |
| Road meshes with collision | 1 per segment + physics bodies | — | No, and unbounded |
| Road nav regions | N bake jobs, async | — | No — and bake time is CPU hitching, not frame cost |

**Worst realistic outcome, and how it is bounded without measuring:** the jungle is 71% of an 18.8 fps
frame. Any road implementation that adds *geometry* competes with the thing that is already the
problem. But a road that **clears vegetation along its length is a perf WIN, not a cost** — fewer
`GroundClutter` MultiMesh instances, fewer `VegetationManager` props, over a corridor that crosses the
whole AO. Nobody has said this out loud and it inverts the whole risk analysis.

**The bound to impose, stated as a rule and not a number:** *this wave adds zero new draw calls and
zero new instanced meshes. If the design needs a road you can see, it is a channel in the existing
terrain shader, exactly as `clearing_system`'s mask already is (`briefing:71-72`) — the only existing
shader-space ground painting, and the precedent.* Then the perf claim is auditable without a
benchmark: `0 new nodes` is a thing you can grep.

Anything richer waits for a windowed bench on a day the Summoner is not doing art. **"We will measure
it later" is how the 71% got there.**

---

## Q6.7 — IS A ROAD A SECOND WORLD-GEN PASS? YES, INHERENTLY. Here is the argument.

**The case for the prosecution.** A world-gen system is anything that decides, per world position,
what is there. There are today at least four such deciders that must agree: `TerrainZoning.classify`
(the one classifier), `HydrologyMap` (where water goes), `SitePlanner` (where structures go), and the
heightmap itself. They agree only because three of them were forcibly merged into the fourth, at real
cost, after ~14 parallel systems caused months of phantom bugs.

A road network decides, per world position: *is there a road here* — and to be useful it must ALSO
decide *is the ground flat here* (grading), *is there jungle here* (clearing), *is there water here*
(crossings), and *can a vehicle be here* (nav). **That is not a consumer of world-gen. That is a
fifth world-gen system, and it overlaps the other four on every axis.**

**Why it "cannot be made to agree":** because a road is the only one of the five whose data is not a
pure function of `(x, z, seed)`. Terrain, zoning and hydrology are all stateless derivations —
`_seat_cell` can rebuild any cell from four numbers, forever. A road is a *decision* — a graph
connecting sites that were themselves chosen by a 300-attempt rejection sampler
(`site_planner.gd:36-86`). It has to be stored. And stored state adjacent to derived state is the
precise shape of every divergence this project has suffered.

**What the divergence looks like in six months** — and I will be specific, because vague warnings get
ignored:

1. Month 1: roads paint into a mask; `_apply_riparian_belt` eats the river crossings; someone adds a
   ROAD skip to the belt.
2. Month 2: `VegetationManager` grows trees on roads because its classifier never learned about them.
   Rather than route through `TerrainZoning`, someone adds a `RoadNetwork.is_road()` call to
   `vegetation_manager._determine_terrain_type` — a second consult of the same mask. Two readers.
3. Month 3: a crater near a road re-seats the cells; roads survive (they are in the derivation) but
   the *graded height* does not, because height edits are not re-derived — `modify_terrain` is
   destructive. The road develops a pothole nobody can explain. Someone adds a "road height cache".
   **Now there are two height authorities**, which is exactly what `test_height_authority` exists to
   forbid, and its check A only greps for the literal `350.0`, so a road height cache sails past it.
4. Month 4: convoys need Y. `convoy.gd:67-70` sets only `.x` and `.z` — **it never writes Y at all**.
   Someone adds terrain sampling to the convoy. Now the convoy samples the heightmap while the road
   samples its cache. Third reader.
5. Month 6: a bug report says "the truck drives through the hill near the second village". Four
   systems each individually correct. Nobody can find it. **This is the divergent-systems blindspot,
   note-for-note.**

### THE ONE DESIGN RULE THAT PREVENTS IT

> **A road may add exactly one new fact to the world: a signed distance to the nearest road
> centreline, owned by `RoadNetwork`, consulted only from inside `TerrainZoning.classify()`. It may
> not write the heightmap, it may not write `terrain_type[]`, and it may not be read by any system
> that does not already read `TerrainZoning`.**

One fact, one owner, one consult site. Everything else — cover, movement cost, vegetation, visuals,
ambush eligibility, convoy routing — falls out of the existing classifier for free, and
`rebuild_rect` re-derives it on every terrain edit at no cost, because it is inside the one writer.

If the road cannot be expressed that way, **it is a second world-gen pass and the answer is no.**

---

## MY VERDICT ON WHAT TO BUILD (asked for plainly, so given plainly)

**Roads as framed — graded terrain, road meshes, bridges, junctions, a connected network — should NOT
be built this wave.** Not because the Summoner is wrong that the game needs roads; because the
framing bundles four systems and three of them are the ones that break hydrology, the firebase and
the one-classifier guard.

**Build the ROAD MASK. Ship nothing else.**

1. `RoadNetwork` — a polyline graph from `p["fsb_center"]`/`gate_pos` → `village_centers` →
   `camp_centers` (`mission_generator.gd:482-483, 528, 542`), seeded from `mission_seed`, computed at
   plan time in `plan_patrol_world()` which the briefing confirms is **pure positions, no side
   effects** (`briefing:38`). Deterministic, ADR-010-safe, save-safe.
2. **One consult site**: `TerrainZoning.classify()` returns `ROAD` inside the corridor. Both
   `GameplayGrid` and `VegetationManager` inherit it — `test_one_classifier` stays honest **and
   actually guards the road**, which it cannot do under any other design.
3. **Zero height edits.** Roads follow the ground. Vietnam dirt tracks did.
4. **Zero new nodes, zero new draw calls.** Visual is a terrain-shader channel or it waits.
5. Register `ROAD` in `MOVEMENT_COSTS` (≈0.85 — faster than clear, that is the whole tactical trade)
   and `COVER_VALUES` (0.0), and add it to the skip-lists in `_apply_riparian_belt:215` and
   `boost_vegetation:488`. **All five in one commit or the road is jungle.**
6. Enforce `ROAD_NEAR_M` in `ambush_planner.plan()` — but see the warning below.

Cut: bridges, junctions, grading, road meshes, road nav regions, convoy wiring, vegetation clearing.
Every one of them is a separate wave with a separate probe.

### The thing that bites if we do only step 6

Q3 in the briefing is right and it deserves an explicit second from this chair. `AmbushPlanner.plan`
searches `SEARCH_RADIUS = 200.0` m around a **VC camp** (`ambush_planner.gd:24, 39-40`). VC camps are
sited by `find_site` with **no road-proximity term at all**. Adding a hard `ROAD_NEAR_M` gate turns a
planner that currently returns a site into one that returns `{}` for any camp whose roads are >280 m
away — and `plan()` already returns `{}` on failure with **no fallback**.

**We would ship "ambushes exist" and deliver "ambushes stopped existing on most seeds," and the only
symptom would be a quieter game.** Nothing asserts that ambushes are produced.

Either (a) roads must be routed to pass near camps — which makes the road network *serve the ambush
system*, an admission that the road is the constant and the design is the variable — or (b) make
`ROAD_NEAR_M` a **score term, not a gate**, and keep the fallback. I recommend (b), and I recommend
a probe that asserts a non-empty ambush plan across ≥8 seeds before the gate is allowed anywhere near
`plan()`.

---

## THE LANDMINES NOBODY NAMED

1. **`convoy.gd:67-70` never writes Y.** The lead's position is advanced in X and Z only; the trail is
   pulled along a flat vector. On any relief the convoy drives at its spawn altitude — flying or
   buried — forever. **Roads do not fix this. Roads expose it**, because roads are the first thing
   that will ever cause a convoy to move. Whoever wires convoys must supply Y, and the moment they do,
   they must decide whether Y comes from the heightmap or from the road — which is landmine #3 in the
   six-month narrative above, arriving on day one.

2. **Convoys are teleported, not driven.** `global_position` is assigned directly — no physics, no
   collision. A convoy will drive through huts, trees, `nav_blockers` and the firebase wire. Also
   `_physics_process` runs every frame per convoy with no LOD gate, while ADR-025's tier sim exists
   and convoys are not in it.

3. **NavBaker bakes site boxes only.** `queue_sites` / `queue_site` (`nav_baker.gd:89-111`) bake AABBs
   around sites; there is no navmesh between them. A road corridor has no navmesh and never will
   unless somebody queues it — and merged road boxes across a 1280 m AO would be a bake job of an
   entirely different magnitude than the site boxes, at `cell_size` matched to the map. **That is
   loading-time hitching, and it is invisible to every perf number we have.**

4. **The water map is never invalidated by terrain edits.** Named above as the reason D1 is blind, but
   it is a defect in its own right and it is not about roads: **every crater, every firebase flatten,
   every future terrain edit leaves `water_map` describing a world that no longer exists.** File it
   whatever roads do.

5. **`test_ambush_sites.gd` writes `grid.terrain_type` directly** (`:94, :113`). It builds uniform
   synthetic grids. Adding an enum member will not break it — but it also means **no ambush test ever
   exercises a real grid**, so the `{}`-returning failure in the warning above cannot be caught by the
   existing suite.

6. **`paddy_stamper.gd:13` hardcodes `const RICE_PADDY: int = 1` with a comment saying it mirrors the
   enum.** That is a second copy of the enum's numbering, by hand, with a tombstone comment vouching
   for it. It survives an append (ROAD would be 8), but it is the exact pattern that broke the height
   constant across eight files. Worth a bead regardless.

---

## WHAT IS SACRIFICED — the honest ledger

| If we build | We give up |
|---|---|
| The road mask only (my recommendation) | Convoys still cannot drive — the four fossils stay red until a second wave. The Summoner asked for a road network and gets a road *classification*. He should be told that in those words. |
| Roads with grading | Hydrology, silently, with a green suite. And the firebase gate, loudly. |
| Roads with meshes | An unmeasurable frame cost against an 18.8 fps budget that is already 71% jungle. |
| `ROAD_NEAR_M` as a hard gate | Ambushes on most seeds, with no error message. |
| Roads outside `TerrainZoning` | The 6od4 guarantee, and it will pass its own probe while doing it. |
| Nothing (defer roads) | `ROAD_NEAR_M` + three convoy symbols stay as build-failing fossils, and the pressure to `--grandfather` them grows every session. **Doing nothing is not free either.** |

---

## BEFORE ANY ROAD CODE IS WRITTEN — preconditions

1. Regenerate `.godot/global_script_class_cache.cfg` (open once in **4.7**). The tree does not compile
   headless.
2. Fix `test_height_authority` D2 — it measures zero points. Either write a channel surface in
   `hydrology_map._classify_cells` or compare the bed against the **carve depth**, not against a
   surface that does not exist. *Do this first, or the roads wave has no hydrology guard at all.*
3. Decide whether `water_map` invalidates on `region_rebuilt`. It never has.
4. Correct `CLAUDE.md`'s fossil counts (27 → 26) and the briefing's "10/10 is a guarantee" claim.
5. Accept that the fossil probe is red *now*, with ten entries, four of them ours.

**Everything in this document is either a pointer or a probe I ran. The two probe runs are
reproducible with the commands quoted above.**
