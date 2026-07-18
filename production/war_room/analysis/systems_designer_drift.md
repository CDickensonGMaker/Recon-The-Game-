# SYSTEMS-DESIGNER â€” World-Build Drift Audit (2026-07-17, read-only)

## Verdict: ~14 â†’ 1 canonical path + 3 parallel builders still standing + 2 dormant remnants

The canonical AO build TODAY is ONE ordered, seeded pass:
`game_flow.gd:242-248` (mission) / `:428` (hub) â†’ `MissionGenerator.plan/build/build_hub` on a
`GameWorld` (`scripts/levels/game_world.gd:80-181`): terrain â†’ TerrainZoning (`terrain_manager.gd:156`)
â†’ vegetation (TREE_COVER live, `world_config.gd:21`, `vegetation_manager.gd:133-137`) â†’ water â†’ grid
â†’ clutter (`game_world.gd:176`) â†’ paddies (`mission_generator.gd:124`) â†’ sites â†’ enemies/civilians.
That is ADR-028's decreed shape, real and shipping. There is no node named "WorldBuilder" â€” GameWorld +
MissionGenerator ARE it.

Still standing OFF that path:
1. **ai_stress_arena** â€” fully hand-wired parallel world: TerrainManagerStub/FlatHeightmap/ArenaGrid
   (`ai_stress_arena.gd:11-51`), own JunglePatchLayer, own seed 20260714 (`:136`, `:221`). Phase 3 (qjf0) NOT started.
2. **terrain_lab** â€” lab scene with its own build + unseeded PoissonSampler (`poisson_sampler.gd:36-54`,
   only caller `terrain_lab.gd:7`) + EngineeringSystem/ConstructionMarkers (lab-only).
3. **LocationPlanner** â€” a SECOND settlement doctrine (ring of 8-10 villages + `apply_lifts` terrain
   reshaping, `location_planner.gd:43-45`); only caller is `tests/test_world_alive.gd:64,75`. Competes
   with the canonical PaddyStamper-anchors + SitePlanner.find_site doctrine. Exactly the divergence class ADR-028 bans.

Dormant remnants (mhfv class): TerrainManager streaming machinery gated OFF at `terrain_manager.gd:73`
(map 1280 â‰¤ 2000) but fully present (`:226-308`) with load/unload plumbing still wired
(`game_world.gd:86-87`, `world_config.gd:12-13`). JunglePatchLayer is a one-line fallback flag in the
game (`world_config.gd:21` true â†’ dormant) but LIVE in the arena. RiverMesh: DELETED (5la5 verified â€”
no file in terrain/water/, ADR-026:105 records the deletion).

## Table
| System | Status | Seeded? | Where |
|---|---|---|---|
| GameWorld orchestration | LIVE | mission_seed throughout | CANONICAL |
| TerrainManager + TerrainEngine | LIVE | seeded (`terrain_engine.gd:220-229`); `randi()` only in dormant fallbacks (`terrain_manager.gd:184`, `terrain_engine.gd:217`) | CANONICAL |
| TerrainManager streaming | DORMANT (gate `:73`) | n/a | remnant, delete-able |
| RiverGenerator | LIVE | fixed seed 42 (`river_generator.gd:61`) â€” deterministic via seeded heightmap, does not fold mission_seed | CANONICAL |
| WaterSystem | LIVE | no RNG | CANONICAL |
| VegetationManager + TreeCoverLayer | LIVE | hash([chunk, mission_seed]) (`vegetation_manager.gd:353,382,599`); TreeCover renders VegMgr's placements (`:578`) | CANONICAL |
| JunglePatchLayer | LIVE arena / dormant game flag | seeded in game path (`jungle_patch_layer.gd:201`); arena instance rides arena seed | ARENA + flag |
| GameplayGrid (LOS rng) | LIVE | hash([cell, mission_seed]) (`gameplay_grid.gd:466`) | CANONICAL |
| GroundClutter | LIVE | hash([bucket, layer, mission_seed]) (`ground_clutter.gd:123`) | CANONICAL |
| PaddyStamper | LIVE | mission_seed+1009 (`paddy_stamper.gd:43`) | CANONICAL |
| SitePlanner (all stamp_*) | LIVE | caller rng: plan=seed, build=seed+777 (`mission_generator.gd:341`), hub=seed+4242 (`:900`) | CANONICAL |
| PatrolGenerator | LIVE | caller's seeded rng (`patrol_generator.gd:23`) | CANONICAL |
| MissionGenerator plan/build/build_hub | LIVE | seeded | CANONICAL |
| ConvoySpawner | LIVE | **UNSEEDED** (`convoy_spawner.gd:9`) â€” places vehicles+enemies at runtime | CANONICAL â€” gap |
| InsertionRide AA/scatter | LIVE | **UNSEEDED** global randf (`insertion_ride.gd:162-188`) | CANONICAL â€” gap (transient) |
| WeatherDirector transitions | LIVE | unseeded (`weather_director.gd:18`) â€” weather, not placement | CANONICAL â€” minor |
| DamageSystem decals | LIVE | unseeded (`damage_system.gd:237-248`) â€” cosmetic | acceptable |
| ai_stress_arena hand-wiring | LIVE | own const seed | LAB (parallel world #2) |
| terrain_lab + Poisson/Engineering/Markers | LIVE lab | Poisson unseeded | LAB (parallel world #3) |
| LocationPlanner | test-only | seed+31337 | PARALLEL doctrine, dormant |
| RiverMesh | DELETED | â€” | âœ” |
| ClearingSystem | LIVE autoload | mask, no placement RNG | CANONICAL (the one mask) |

## Phases (beads vs code)
- ghhp Phase 1 (in_progress): deliverables APPEAR SHIPPED â€” residency guard live, clutter resident,
  seeds folded, `tests/probe_worldbuild_phase1.gd` asserts determinism/seed-fold/25-chunk residency/
  clutter (:26-50). Candidate to close.
- 3kgd Phase 2 (in_progress): TreeCover IS live (`world_config.gd:21`); JunglePatch fossil-pair deletion,
  density, relative-elevation paddy gate outstanding.
- qjf0 Phase 3 (open): arena untouched â€” stubs verbatim.
- f9t3 Phase 4 (open). dlox structural probe (open): NOT built.

## dlox probe â€” what exists / what it takes
Nothing in tests/ asserts path-count, arena-on-shared-build, or seed-fold-by-scan. probe_worldbuild_phase1
proves the canonical path is deterministic+resident but is blind to a SECOND path appearing. To make dlox real:
(1) static-scan test in the test_fossils mold: over scripts/world+missions+terrain placement files, every
`RandomNumberGenerator.new()`/global randf must be followed by a seed line folding mission_seed or take a
caller rng â€” whitelist cosmetic files; (2) grep-level assert that `class TerrainManagerStub` is absent from
ai_stress_arena.gd and the scene contains a GameWorld (lands with Phase 3); (3) manifest of allowed placement
entry points (GameWorld._setup_terrain, MissionGenerator.plan/build/build_hub) â€” any new caller of
place_structure/generate_for_chunk/stamp_* outside manifest+tests fails.

## Top 3 consolidations by value
1. **Phase 3 arena wrapper (qjf0)** â€” the arena is the ONLY remaining fully parallel LIVE world; wrapping it
   also deletes JunglePatchLayer's last live consumer, letting Phase 2 finish the one-veg-system decree.
2. **Kill or crown LocationPlanner** â€” second settlement doctrine alive only in test_world_alive; fold its
   terrain-shaping idea into the canonical pass or delete it + its test before someone "uses the wrong one."
3. **Seed ConvoySpawner (+InsertionRide), then land dlox** â€” the one unseeded runtime placer on the canonical
   path; fix it, then make the probe so the count can never grow again. (Lower value: delete dormant
   streaming machinery + load/unload plumbing â€” mhfv.)

Tradeoff named: the structural probe's manifest is a maintenance cost â€” every legitimate new placement
call site must touch the manifest. That friction is the point.
