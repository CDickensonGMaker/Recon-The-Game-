# Devil's Advocate — Worldbuild Unification, Phase 1

Scope reminder: structure + determinism + residency only. NOT density/look, NOT the arena, NOT AI
tiering. I read the code, not the plan. Below: what breaks, ranked, and what is sacrificed.

Map fact that governs everything: `WorldConfig.MAP_SIZE = 1280.0` (world_config.gd:9), so the item-1
residency guard (`map_size <= 2000`) DOES fire — streaming is skipped, all 25 chunks (1280/256=5x5)
load once and stay resident. The residency premise is valid at the *terrain* level. The clutter
problem below is NOT about the map; it is about GroundClutter's own architecture.

---

## RISK 1 (BIGGEST) — "Make GroundClutter resident" is a REWRITE mislabeled as a deletion. As worded it destroys near-field clutter.

`_scatter()` (ground_clutter.gd:122-155) is the ONLY code that places any instance, and its ONLY
caller is `_process()` (line 119). `setup()` (71-102) builds the MultiMeshes with `instance_count`
set but NEVER assigns a single transform.

- Delete lines 108-155 (both `_process` AND `_scatter`, exactly the briefing's range) and nothing
  ever calls a scatter. Every grass/rock/log/mushroom instance keeps its default transform =
  `Transform3D.IDENTITY` at world origin (0,0,0). Result: a stacked clump of all ~408 billboards at
  the map corner, and BARE GROUND everywhere the player actually is. Hard visual break.
- Even if paired with an unstated "call `_scatter(spawn)` once in setup", GroundClutter is
  architecturally a **45 m near-player follow** (`RADIUS = 45.0`, line 10). Scattered once at
  insertion it covers a 45 m disc on a 1280 m map — a grass island at the LZ, bare ground for the
  rest of the mission. The player leaves it in seconds.
- Genuine residency for clutter means re-architecting it to scatter per-chunk across all 25 resident
  chunks (the way JunglePatchLayer keys off `chunk_coord`). That is real work, NOT in item 2's scope.

This directly violates the phase's own "NOT changing look" guard. Item 2 as written cannot be shipped
literally; it needs a design decision (per-chunk resident scatter) that the briefing does not carry.

Ordering, for when a resident scatter IS added: SAFE. `clutter.setup(self)` runs in
`_on_terrain_ready` (game_world.gd:174-176), after `is_ready=true` and after the player spawns
(step 5, :166-170). `terrain_manager.get_height_at` and `world.player` are both valid. No ordering
break — but only relevant once placement is actually restored.

## RISK 2 — Fossil-probe BUILD BREAK (ADR-023). Deleting 108-155 orphans three symbols.

`_last_center` (:31), `_poll` (:105) and `RESCATTER_DIST` (:11) are referenced ONLY inside the code
being removed (`_last_center`: 116/118; `_poll`: 111/112/114; `RESCATTER_DIST`: 116/124). Remove
108-155 and all three become NEW fossils → `tests/test_fossils.tscn` fails the build (new fossils are
forbidden; regenerating the baseline is the one banned move). They MUST be deleted in the same change.
Also `world.player` is read only in `_process`; a resident clutter no longer needs the player ref
(it still needs `world` for `gameplay_grid`/`terrain_manager`).

Item 4 deletion interacts with the baseline too: `_generate_chunk_vegetation` is grandfathered at
fossil_baseline.json:133 — deleting the function REQUIRES deleting that line (the correct "register
only shrinks" shrink, not a snooze). `_generate_chunk_grass` is NOT in the baseline because it still
has one caller (`_generate_chunk_vegetation:382`); it only becomes dead once its caller dies, so both
must be deleted in ONE change or the probe flags grass as a fresh fossil mid-way.

## RISK 3 — The seed fold has an UNSTATED wiring dependency; forget it and the fold is a silent no-op.

JunglePatchLayer has NO `mission_seed` field today, and VegManager creates `_patch_layer`
(vegetation_manager.gd:105-107) WITHOUT ever passing a seed. Item 3 must ALSO add the field and wire
`_patch_layer.mission_seed = mission_seed` (VegManager already holds `mission_seed` at :26, set from
game_world.gd:92). If that wiring is omitted, `mission_seed` defaults to 0, the fold changes nothing,
and the "identical jungle every mission" bug persists — invisibly. This is the actual bug being
fixed: currently JunglePatch seeds off `hash(chunk) ^ 0x5EED` with NO mission_seed, so today two
DIFFERENT mission seeds already produce the SAME jungle layout. Folding is the fix; the wiring is the
part that can be dropped.

Compliance note (ADR-010 line 15): fold into the DEDICATED `rng.seed`, never call global `seed()`.
Both layers already use local `RandomNumberGenerator.new()`, so this is fine — and it mirrors the
established idiom `hash([chunk_coord, mission_seed])` in VegManager._build_placement_cache:474.

## RISK 4 (LOW/NONE) — The arena is NOT affected. Do not let this block the phase.

- Every headless probe sets `bench_dressing = false` (test_veg_cover.gd:39, test_arena_patrol.gd:58),
  and `_build_jungle()` + `_scatter_ground_plants()` are gated behind `if bench_dressing:`
  (ai_stress_arena.gd:361-364). So NO probe ever builds JunglePatchLayer or ground clutter.
- Arena sight caps / AI concealment come from `_stamp_veg_*` writing directly into `gameplay_grid`
  (arena.gd:429, 813, 868, 876…), which is INDEPENDENT of the patch RNG. Changing the JunglePatch
  seed cannot move a single sight cap, patrol path, or veg_cover assertion.
- The arena builds `JunglePatchLayer.new()` directly and never sets `mission_seed` → stays 0. If the
  fold is XOR (`hash(chunk) ^ 0x5EED ^ mission_seed`), the playable bench jungle is byte-identical
  (`^0`). If instead it's `hash([chunk, mission_seed])`, the bench jungle re-rolls its layout —
  COSMETIC only, no probe, only the bench_dressing=true playable scene. Recommend the XOR form to keep
  the bench pixel-stable; either way nothing breaks.

## RISK 5 (LOW) — TerrainZoning._noise reset is a near-no-op; cross-mission is already clean.

`TerrainZoning._patch_noise(world_seed)` already rebuilds the noise whenever `_noise_seed != world_seed`
(terrain_zoning.gd:59-65). It self-heals on a seed change; on a same-seed re-run reuse is CORRECT. So
resetting `_noise` in MissionScope.reset() is harmless but NOT load-bearing — do it if you like belt-
and-suspenders, but do not claim it fixes a real leak. GroundClutter / JunglePatchLayer / VegManager
are all scene-children of GameWorld and are freed on `_teardown_world()`; they hold NO class statics,
so nothing stale carries across missions. MissionScope needs nothing added for these three systems.

## RISK 6 (LOW) — Determinism/save: the "existing seeds change" cost is COSMETIC-only.

Jungle patches and ground clutter are non-colliding, no-LOS decoration (JunglePatchLayer builds only
MultiMeshInstance3D with material_override and shadows OFF — no StaticBody; GroundClutter is
billboards). Gameplay-relevant world state (terrain type → sight cap, blocks_los, movement) comes from
`TerrainZoning.classify(…, mission_seed)` + gameplay_grid, which this phase does NOT touch. Saves store
seed + carried state and REGENERATE (ADR-007 HARD wheels-down checkpoint; ADR-010 "same seed = same
world/enemies/events, not the same bullet holes") — there is no vegetation snapshot to break. A HARD
checkpoint made before this change and resumed after it reconstructs the same terrain, spawns, and
sight caps; only decorative foliage shifts. No save breaks. The fold actually moves JunglePatch INTO
ADR-010 line 14 compliance ("all world generation derives from the one seed"), closing a real gap.

---

## What is sacrificed (no free lunches)

- **Pixel-stability of already-shipped seeds.** Anyone who screenshotted or memorized a specific seed's
  foliage gets a different-looking (not different-playing) world. Accepted under ADR-010 honest scope.
- **The playable arena bench's jungle layout** may re-roll (cosmetic) unless the fold is XOR-with-0.
- **GroundClutter's near-field polish**, if item 2 ships as a bare deletion, is LOST for the whole
  mission outside a 45 m LZ disc — the opposite of the phase's "don't change the look" intent. The
  honest cost of doing item 2 *right* is a per-chunk clutter rewrite the briefing has not budgeted.

## Single biggest risk

**Item 2.** "Make GroundClutter resident: remove its `_process` re-scatter (108-155)" deletes the only
placement mechanism the class has. Taken literally it clumps all clutter at world origin and strips
near-field grass from the entire 1280 m playfield — and orphans three symbols that fail the fossil
build. It is not a deletion; it is a per-chunk-scatter rewrite, and it must be scoped as one or
deferred out of a phase whose stated rule is "NOT changing density/look."
