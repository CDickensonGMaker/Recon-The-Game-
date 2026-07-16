# Devil's Advocate — veg cover / sight cap wiring

**BIGGEST RISK — coordinate-origin mismatch (silent).** `gameplay_grid.world_to_grid()` (line 324) is
0-origin: `clampi(int(world.x / cell), 0, grid_size-1)`. The arena is CENTER-origin, spanning -100..+100.
Every negative coord (ALL US spawns, the player at -35,35, half the map) clamps to grid column/row 0.
`clampi` swallows it — no error, no warning. Stamp veg "matching foliage" via world coords and sampling
reads the WRONG cell. Sight caps land in the wrong places; the open contact zone could read jungle or the
tree lines read open. **The arena MUST offset coords (or build the grid origin-shifted) before any
stamp/sample, and the probe must assert a KNOWN jungle cell caps and a KNOWN open cell doesn't.** Otherwise
the whole feature is a silent no-op-or-worse.

**Refuted:** #1 group join is SAFE — only enemy_base:290 & player:469 read "game_world", both duck-typed
`if "gameplay_grid" in gw`. SquadSystem/MissionDirector/GroundClutter/topo_map take game_world as a setup
*param* from game_flow, never fetch the group. #3 grid's 30%-per-cell LOS randf is NOT on the perception
path (enemy uses CombatManager physics ray + trunk colliders); only `get_vegetation`/`is_water` are. No
per-frame cost, deterministic (seed 0). #2 concealment fallback (1398) fires only in SEEKING_COVER, not
patrol/MOVE_TO, so it can't stall the patrol→COMBAT transition test_arena_patrol needs.

**Watch:** if stamp blankets veg>0.6, 45m cap could stop US/VC closing to LOS within the 90s probe window
(FAIL b). Keep the center open.

**SACRIFICED:** the arena's tuning baseline. Every prior firefight-length number (cone_mult=1.0, mirror
ratio band) was measured with sight UNCAPPED (grid null → 140m). Wiring a real cap shifts engagement ranges;
the existing telemetry evidence is invalidated until re-baselined.
