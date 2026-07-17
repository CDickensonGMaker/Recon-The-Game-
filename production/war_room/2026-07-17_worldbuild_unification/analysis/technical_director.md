# Technical Director — Worldbuild Unification Phase 1

Read of record (code, not plan), 2026-07-17. All line refs verified against source this session.

## Q1 — Residency guard correctness & explosion safety

**Correct and sufficient for the streaming invariant.** `_process` (terrain_manager.gd:59-66):

```
if not is_ready: return
_process_rebuild_queue()
if camera:
    _stream_chunks_around_camera()
```

Gate the stream call only: `if camera and map_size > 2000.0:`. After `terrain_ready`,
`_load_initial_chunks_async` (194-211) has already added all 25 chunks. `_stream_chunks_around_camera`
(214) is the ONLY caller of `_load_chunks_around` (222) and `_unload_distant_chunks` (271) — the only two
functions that change the *set* of chunk coords. Skip it and `chunks.size()` is frozen at 25 across any
traverse. That is exactly ADR-013's observable contract (ADR line 43-45). Sufficient; nothing else adds or
removes chunks per frame.

**Does NOT break explosions.** The rebuild path is independent of streaming:
- `_process_rebuild_queue()` (63) is called UNCONDITIONALLY — leave it ungated. The 8ms deferred queue
  (`REBUILD_BUDGET_MS`, 43) keeps working.
- `modify_terrain` (316) → `_rebuild_chunks_in_region` (326) → `_rebuild_chunk_immediate` (89), and the
  queued path via `queue_chunk_rebuild` (84), all funnel to `_rebuild_chunk_immediate`. That function
  erases ONE coord (101) and immediately re-adds the SAME coord via `_load_chunk` (104) — net chunk-set
  delta is zero. The invariant `chunks.size() == 25` holds *through* an explosion. Craters and cleared
  vegetation still rebuild. No regression.

Caveat: put the guard on the stream call specifically. Do NOT gate `_process_rebuild_queue`, or explosions
stop repainting terrain.

Guard value is right: game_world.gd:83 sets `terrain_manager.map_size = map_size` (=WorldConfig.MAP_SIZE
1280) BEFORE `_process` ever runs, overriding the 3000 export default (14). At runtime map_size=1280 ≤ 2000
→ streaming off. A bare TerrainManager left at default 3000 streams — that IS the intended >2km case.

## Q2 — Remaining determinism holes

The two Phase-1 targets are real and correctly identified:
- JunglePatchLayer: `jungle_patch_layer.gd:198` `rng.seed = hash(chunk_coord) ^ 0x5EED` — NOT seeded from
  mission_seed. Two boots, same seed, same chunk → identical (fine), but the seed carries no mission
  identity, so it cannot be re-derived per-op and is a lie by ADR-010's "one seed per op" letter.
- GroundClutter: `ground_clutter.gd:124` `rng.seed = hash(Vector2i(center.x/RESCATTER, center.z/RESCATTER))`
  — same problem; scatter is a pure function of camera cell but not of mission_seed.

**Other un-seeded world-placement RNGs still leaking (grep of terrain/ + scripts/world):**

1. **FOSSILS — vegetation_manager.gd `_generate_chunk_vegetation` (309: `hash(chunk_coord)+1000`) and
   `_generate_chunk_grass` (400: `hash(chunk_coord)+5000`).** These are the OLD placement path. The live
   path is `generate_for_chunk` (248) → `_build_placement_cache` (466, already
   `hash([chunk_coord, mission_seed])`) → `_rematerialize` (696) → `_materialize_vegetation`/`_grass`.
   Nothing calls `_generate_chunk_vegetation`/`_generate_chunk_grass`. They are dead (ADR-023 FOSSIL LAW):
   **delete them, do not seed them.** Seeding a corpse just hides it better. Confirm zero callers before cut.
2. **terrain_manager.gd:172** `noise.seed = randi()` in `_generate_fallback_terrain` — a true global-RNG
   non-determinism hole, but only on the no-TerrainEngine fallback branch (142). Shipping has the autoload,
   so latent, not live. Fix opportunistically: `noise.seed = seed_value` — but out of Phase-1 scope.
3. **scripts/world planners are already clean:** location_planner.gd:45 (`mission_seed+31337`),
   paddy_stamper.gd:43 (`mission_seed+1009`), site_planner.gd (rng passed in by caller),
   enemy_mortar_team.gd:18 (seeded by caller). gameplay_grid.gd:466 and terrain_zoning.gd:54 both already
   use `hash([pos, mission_seed])`. No generation leak here.
4. **Behavioral/cosmetic global randf — honest-scope carve-out, LEAVE:** civilian.gd:116/379 (flee/wander
   reactions), mission_weather.gd:64/130 (squall timers), damage_system.gd:237-248 (decal jitter). ADR-010
   line 16 explicitly excludes per-frame/reaction draws. NOTE one grey-area: **weather_director.gd:18/40**
   `rng` is a fresh unseeded RNG and weather TYPE affects the world (fog/wildlife) — arguably generation.
   Flag for a later pass; not Phase 1 (not a placement RNG).

**Is `hash([chunk_coord, mission_seed])` a sound fold to copy? Yes.** It is the proven pattern already used
in three live places (`_build_placement_cache` 474/503, gameplay_grid 466, terrain_zoning 54). Array-hash
folds both operands, is order-independent, and yields a pure function of (position, seed) per ADR-010.
Apply it verbatim:
- JunglePatchLayer:198 → `rng.seed = hash([chunk_coord, mission_seed])` (requires plumbing mission_seed
  into JunglePatchLayer — it currently has none; pass it from VegetationManager, which owns mission_seed
  at vegetation_manager.gd:26 and news the layer at 105).
- GroundClutter:124 → `rng.seed = hash([Vector2i(int(center.x/RESCATTER_DIST), int(center.z/RESCATTER_DIST)), mission_seed])`
  (GroundClutter has `world: GameWorld`; read `world.mission_seed`, game_world.gd:16).

Do not use `+ 0x5EED` / bare `hash(cell)` — folding by XOR/offset with a constant does not inject mission
identity.

## Q3 — TerrainZoning._noise static

`static var _noise` + `static var _noise_seed` (terrain_zoning.gd:33-34), rebuilt in `_patch_noise` (58-65)
only when `_noise == null or _noise_seed != world_seed`.

**Is it a real cross-mission leak?** By the letter of ADR-010 line 19 — YES, it is a defect: an unregistered
class static that carries state across `_teardown_world()`. By runtime *behavior* — it is self-healing, not a
live bug: mission N+1 with a different seed trips `_noise_seed != world_seed` and rebuilds; with the same seed
it correctly reuses identical noise. So determinism is not actually violated today. Be honest about that in the
decree — the fix is law-hygiene (and frees a persistent FastNoiseLite), not a bug patch. But ADR-010 is
explicit that "a static without a MissionScope entry is a defect," and this is precisely the leak class the
registry exists to close. Register it.

**Can MissionScope (RefCounted static) null another class's static? Yes.** `class_name TerrainZoning` is
globally resolvable; GDScript permits writing a `static var` via `ClassName.var = ...` from any scope.
MissionScope already both pokes fields directly (`EnemyBase._cover_claims.clear()`, mission_scope.gd:35) and
calls reset methods (`GunFX.reset_session()`, 36). Nulling `_noise` alone is sufficient — the guard checks
`_noise == null` FIRST (59), forcing a rebuild next `classify()` regardless of seed.

**Exact line to add**, in `MissionScope.reset()` after line 41 (`GruntRandomizer.reset_bench()`):

```gdscript
	TerrainZoning._noise = null   ## static FastNoiseLite outlives teardown; forces rebuild next classify (ADR-010)
```

Preferred (encapsulated, matches the method-call idiom): add to terrain_zoning.gd
`static func reset() -> void:` that sets `_noise = null` and `_noise_seed = 0`, and call `TerrainZoning.reset()`
from MissionScope. Either satisfies the law; the direct null is the minimal one-liner requested.

## Q4 — ADR-013 subtlety: also force unload_distance >= chunks_per_side?

**No. Skipping the call is enough — do not also touch unload_distance.** ADR-013 line 42-43 offers the two as
*alternatives* ("skip the call in `_process` OR set `unload_distance >= chunks_per_side`"), not a conjunction.
If `_stream_chunks_around_camera` never runs, `_unload_distant_chunks` (271, the only reader of
`unload_distance`) is never reached, so its threshold is dead input — bumping it would be redundant and would
muddy which mechanism is load-bearing. Pick ONE (the skip), and leave WorldConfig.UNLOAD_DISTANCE=3 as-is.
For the record: if streaming were ever re-enabled WITHOUT this guard, `unload_distance=3 < chunks_per_side=5`
would unload the map corners — but that is the re-enablement ADR's problem (ADR-013 lines 49-53), not Phase 1's.

## Verdict
Phase 1 is sound and low-risk. Ship the stream-call guard (not a queue guard), copy the proven
`hash([coord, mission_seed])` fold into JunglePatch + GroundClutter (plumbing mission_seed into both), and
register `TerrainZoning._noise = null` in MissionScope. Two riders the council should not skip: **delete the
dead `_generate_chunk_vegetation`/`_generate_chunk_grass` fossils** rather than seed them (ADR-023), and log
`terrain_manager.gd:172` + `weather_director` as known out-of-scope determinism debt.
