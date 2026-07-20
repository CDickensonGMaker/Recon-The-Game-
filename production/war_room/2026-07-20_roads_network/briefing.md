# BRIEFING — THE ROADS NETWORK

**Summoned:** 2026-07-20 · **Arbiter:** Overseer · **Branch:** audit-fixes

## The query
The Summoner has RULED: build the roads network. This reverses his earlier "no new systems,
just wiring." He made the call explicitly, so it stands. The council's job is HOW, not WHETHER
— except where a pillar is at stake, in which case say so plainly.

## What roads unblock
- `scripts/vehicles/convoy.gd` is live but routeless. Its header already says
  "PARKED BY DECISION, NOT BY NEGLECT ... until a road network exists (bead ld0y)".
  `resume`, `route_finished`, `waypoint_reached` are dead symbols today.
- `scripts/enemies/ambush_planner.gd:15` `ROAD_NEAR_M = 80.0` — **declared and NEVER READ**.
  The header documents "road/trail within 80m" as a requirement; `plan()` never enforces it.
  This is a live truth-law violation.
- `DynamicMissionFactory._on_convoy_ambushed` (`dynamic_mission_factory.gd:52`) is the one
  wired dynamic-event producer in the game and can never fire.
- Rule #1: the world must be FUN to walk and FEEL like Vietnam.

## THE CONSTRAINT THAT OUTRANKS THE FEATURE
The unified game world is PROTECTED FOUNDATION. ADR-028 / the populated-AO build is to be
IMPROVED and REFINED, never rebuilt, replaced, or re-fragmented. This project's single worst
recurring failure is parallel world-build systems — there were ~14 at one point and it caused
months of phantom bugs. **Roads must be ONE authority integrated into the existing build, not a
second world-gen pass that disagrees with the first.**

## VERIFIED FACTS (reconnaissance, this session — trust these over memory)

**World build order** (`scripts/main/game_flow.gd` — note: `scripts/main/`, NOT `scripts/autoload/`):
1. `terrain_manager.generate_terrain(seed)` — heightmap
2. `TerrainZoning.configure(heightmap)` (`terrain_manager.gd:123`)
3. **rivers carve into the heightmap BEFORE chunk meshes** (`terrain_manager.gd:126`, impl `:351-370`)
4. chunk meshes + collision
5. `water_system.generate_water_bodies(hydrology)` — reuses the SAME hydrology solve
   (`game_world.gd:144-150`)
6. **`GameplayGrid.build_from_terrain()`** (`game_world.gd:153-158`)
7. `MissionGenerator.plan_patrol_world()` (`game_flow.gd:284`) — pure positions, no side effects
8. `MissionGenerator.build_patrol_world()` (`game_flow.gd:285`) — stamping
9. NavBaker `queue_sites` (`mission_generator.gd:649-659`)

**Sites a road would connect** — canonical stores:
- `p["fsb_center"]` (`mission_generator.gd:482`), `p["gate_pos"]` (`:483`)
- `p["village_centers"]` (`:528`) — 4 villages, one per quadrant
- `p["camp_centers"]` (`:542`) — 3 VC camps
- `built["sites"]` (`:667`) has centers AND radii
- Persistent: `FieldDirector.patrol_locations` (`field_director.gd:519-527`)

**Height:** ONE authority `TerrainConfig.WORLD_HEIGHT_MAX = 350.0`. Sample via
`TerrainManager.get_height_at()` (`terrain_manager.gd:269`). Modify via
`TerrainManager.modify_terrain(center, radius, modifier)` (`:277-286`) — modifier takes/returns
NORMALIZED 0-1 height, and emits `region_rebuilt`, which auto-re-seats GameplayGrid
(`game_world.gd:405-429`) and re-scatters GroundClutter.

**THE CRUX — the hard architectural problem:**
`GameplayGrid._seat_cell` (`gameplay_grid.gd:121`) is THE ONE WRITER of terrain_type. It derives
every cell from `_determine_terrain_type(h, slope, wx, wz)` (`:269`). `rebuild_rect` (`:429`)
re-runs it on every terrain edit. **There is no `TerrainType.ROAD` and no per-cell override
channel that survives a re-seat.** A road painted directly into `terrain_type[]` (the way
`mark_cleared` at `:458` does) WOULD BE SILENTLY ERASED by the next crater in that rect.

**Rivers:** `HydrologyMap.rivers` (`hydrology_map.gd:87`) = Array of
`{points: PackedVector2Array (world XZ), widths: PackedFloat32Array}`. Channels have NO water
surface written — `WaterSystem.get_water_level_at()` returns `-INF` inside a channel.
`test_height_authority` is 10/10 with a 100% wet channel and MUST stay there.

**Precedent for ground-painting:** there is NO decal system and NO ground-mesh painting.
`paddy_stamper.gd` is a READER, not a writer — it flood-fills cells `TerrainZoning` already
classified as RICE_PADDY and scatters collisionless prop MeshInstance3Ds. `ground_clutter.gd`
is the only real ground instancer (MultiMesh per 32m subcell, 42m visibility range).
`clearing_system` drives a low-res mask blended into the terrain shader — the only existing
shader-space ground painting.

**Perf reality:** 18.8 native FP / jungle = 71% of frame. Headless reports GPU-ms as 0, so no
honest frame number is obtainable without a windowed bench, and the Summoner is at his desk
doing art — windowed runs are FORBIDDEN this session.

## THE QUESTIONS BEFORE THE COUNCIL

**Q1 (technical-director / godot-specialist): Where does road data LIVE?**
Given `_seat_cell` is the one writer and `rebuild_rect` re-derives everything — how do roads
persist? Candidate A: add `TerrainType.ROAD` to the enum and have `_determine_terrain_type`
consult a road mask owned by one RoadNetwork object (survives re-seat for free, because it is
INSIDE the one writer). Candidate B: a separate overlay every consumer must remember to query
(fragments authority). Candidate C: roads modify height only, no grid semantics. Name the
blast radius of adding an enum member: `MOVEMENT_COSTS`, `COVER_VALUES`, `_estimate_vegetation`,
every `match` on TerrainType, VegetationManager's parallel classifier.

**Q2 (game-designer): PILLAR 3 — is a road network a RAIL?**
"Freedom — no rails ever." A road literally is a path the designer drew. Does a road corridor
funnel the player, or does it give the player a legible choice (fast+exposed vs slow+concealed)?
Where is the line?

**Q3 (systems-designer): does the ambush economy IMPROVE?**
ADR-021's intel loop is PATROL TO LEARN THE GROUND → USE THE GROUND TO KILL THEM, and its
ambush substrate is the VC PATROL CIRCUIT, not a road. Bead ld0y explicitly offers "retarget
ROAD_NEAR_M at PatrolGenerator circuits — arguably the truer Vietnam ambush" as an alternative.
Is a road the right ambush substrate, or is enforcing ROAD_NEAR_M against a road network
solving the constant rather than the design? Note the ambush is planned around VC CAMPS
(`mission_generator.gd:544-593`) — if roads don't pass near camps, ROAD_NEAR_M rejects everything
and we've made the planner WORSE (it currently returns sites; a naive road gate returns none).

**Q4 (ux-designer): r4bk law — a feature without a visible HUD affordance does not exist.**
ADR-022 grease-pencil law: the game marks what you SAW; the player marks what he THINKS.
OBSERVED decays. Does a road appear on the topo sheet from mission start (a road is a permanent
terrain feature a real map WOULD print) or only once walked? Getting this wrong turns the map
into a quest log.

**Q5 (all): SCOPE.** What is the MINIMUM road system that unblocks convoys + ROAD_NEAR_M
without becoming a second world-gen pass? Name what you would CUT. Bridges over rivers?
Road-following vegetation clearing? Road meshes at all vs shader mask? Junctions?

**Q6 (devil's-advocate): what breaks?**
Specifically: hydrology (rivers were JUST fixed to 100% wet channel), the firebase 215m flatten
disc, `test_height_authority` 10/10, navmesh bake, the fossil register, and frame time we
CANNOT MEASURE this session.

## THE LAWS
1. No decree may violate a Pillar. 2. Tradeoffs must be named. 3. The Summoner holds final
authority. 4. All deliberations archived. 5. Actionable items enter the graph.

**If some part of this shouldn't be built the way the Summoner framed it, SAY SO.** He would
rather hear that than get a bad system built obediently.
