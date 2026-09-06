# TECHNICAL DIRECTOR / LEAD PROGRAMMER — analysis
## War Room 2026-09-06 · the RPG-pivot decree, technical items 8/9/10/11
**Scope:** price and constrain. Nothing here is a build order. Every item is POST-DEMO by the
Summoner's own framing; my job is to make the price legible so it stops competing with shipping.

**Binding law enforced throughout:** ADR-013 (≤2km never streams; re-enablement needs its own ADR
with before/after frame times), ADR-028 PROTECTED FOUNDATION (improved in place, never re-fragmented),
ADR-010 (one seed per operation, deterministic placement), the perf-first law, and the verification
law — nothing below is closed by "likely fine".

---

# 0. THE ONE SENTENCE (read this first)

**On the measured floor box the demo's own fight already runs GPU-led at 22.6 fps average / ~5 fps
minimum at 0.75 render scale with ~2.6 fps of margin over the only gate anyone has proposed
(PERF_LEDGER 2026-08-14 evening), and a 2km map adds ~319,000 resident terrain triangles that have
NO level of detail and NO distance culling anywhere in the engine — so 2km is affordable ONLY if
terrain LOD or terrain distance-culling is funded first, and is NOT affordable today.**

That sentence is the whole of item 6 and it outranks items 8–11.

---

# 1. THE 2km CONSTANT — is it really one constant?

## 1a. Yes, mechanically it is one constant. And the ≤2000 guard is inclusive-safe.

`scripts/levels/world_config.gd:9` — `const MAP_SIZE: float = 1280.0` is the single value.
`scripts/levels/game_world.gd:103` pushes it into `terrain_manager.map_size`; `:16` defaults
`GameWorld.map_size` from it. Nothing else authors a map size. Changing that one line changes the
world — ADR-013 already says doing so above 2000m is an ADR-level act, not a tuning tweak.

**The streaming guard, verified:**

- `terrain/core/terrain_manager.gd:26` — `const STREAMING_MIN_MAP_SIZE: float = 2000.0`
- `terrain/core/terrain_manager.gd:71` — `if camera and map_size > STREAMING_MIN_MAP_SIZE:`

The comparison is **strictly greater-than**, so at `map_size == 2000.0` the expression is
`2000.0 > 2000.0` → **false → `_stream_chunks_around_camera()` never runs.** **A map set to exactly
2000 keeps streaming OFF.** ADR-013's "≤ 2km" wording and the code agree; there is no off-by-one here.
This is the good news of the whole item and it is verified, not assumed.

**Residency invariant holds at 2km.** `_load_initial_chunks_async` (`terrain_manager.gd:163-178`)
walks the full `chunks_per_side²` grid up front behind the loading screen; with streaming skipped at
`:71` the only other mutators of `chunks` are `_rebuild_chunk_immediate` (`:75-90`, erase-then-reload,
net zero) and `_unload_chunk` (`:250`), whose only caller is `_unload_distant_chunks` (`:238`), whose
only caller is the streaming path at `:186`. **Chunk count is therefore invariant after
`terrain_ready` at 2km exactly as it is at 1280m.** ADR-013's testable contract survives; the probe
just needs its expected constant changed from 25 to 64.

## 1b. The arithmetic

`chunks_per_side = ceil(map_size / chunk_size)` (`terrain_manager.gd:53`), `chunk_size = 256.0`
(`world_config.gd:10`), `cell_size = 4.0` (`world_config.gd:11`).

| map | chunks/side | chunks | cells/chunk | terrain tris | heightmap cells | heightmap bytes |
|---|---:|---:|---:|---:|---:|---:|
| 512m (demo AO of record for perf rows) | ceil(2.00)=2 | **4** | 64×64 | 32,768 | 128² = 16,384 | 64 KB |
| 1280m (world of record, ADR-013) | ceil(5.00)=5 | **25** | 64×64 | **204,800** | 320² = 102,400 | 400 KB |
| **2000m (the decree)** | ceil(7.8125)=**8** | **64** | 64×64 | **524,288** | 512² = 262,144 | **1.0 MB** |

Working shown:
- cells per chunk side = `chunk_size / cell_size` = 256/4 = **64**; tris per chunk = 64×64×2 = **8,192**
  (matches the ledger's "25 chunks × ~8k tris ≈ 180k", PERF_LEDGER 2026-07-16 t5mo entry).
- 25 × 8,192 = 204,800 → 64 × 8,192 = **524,288**. **Δ = +319,488 triangles, +156%.**
- heightmap side = `ceil(map/cell)` rounded up to a multiple of 64 (`heightmap_storage.gd:22-35`):
  2000/4 = 500 → 512. **512 = 8 × 64 exactly**, so the chunk grid closes onto the heightmap with no
  overhang and no wasted tail — the same clean fit 1280 gets (320 = 5 × 64). **The 2km number is
  arithmetically well-chosen; 1900 or 2100 would not be.** If this ever ships, ship *exactly* 2000.
- vegetation candidates: `TREE_CANDIDATES_PER_CHUNK := 1200` (`vegetation_manager.gd:83`), per chunk,
  so 25 × 1200 = 30,000 → 64 × 1200 = **76,800** candidate evaluations at load. Linear in chunks.
- trimesh collision cooks at load: **25 → 64** `create_trimesh_shape()` calls
  (`terrain_chunk.gd:228`), each over an 8,192-tri mesh.

## 1c. What ACTUALLY scales — and what does not (this is the important half)

**FLAT (does not scale with map size):**
- **GameplayGrid.** `game_world.gd:177` constructs it as `GameplayGridScript.new(map_size, 256)`;
  `gameplay_grid.gd:61-64` derives `cell_size_meters = world_size / grid_size`. The cell *count* is
  pinned at 256² = 65,536 forever. Build cost (`build_from_terrain`, `:97-115`) is therefore constant.
  **But the resolution DEGRADES: 1280/256 = 5.00 m per cell → 2000/256 = 7.81 m per cell, +56% coarser.**
  Every AI cover query, passability test, LOS check and site-footprint validation gets 56% blunter at
  2km. This is a silent quality regression dressed as a free scale-up, and it is the kind of thing
  that shows up as "the AI walks into water" three months later.
- **Nav baking.** `nav_baker.gd` bakes per SITE, gated by `should_bake` (`:111`) against
  `WorldConfig.NAV_SITE_KINDS` (`world_config.gd:40`), never per chunk (`terrain_manager.gd:229-231`
  states this explicitly). Site count is fixed (below), so **nav bake cost is unchanged at 2km.** Good.
- **Site planning.** `find_site` (`site_planner.gd:41-70`) runs a fixed `SITE_ATTEMPTS` loop. And
  critically, the plan places a **fixed** roster: one village per quadrant in a 240–470 m band off the
  firebase gate (`mission_generator.gd:531-560`), camps and temples likewise gate-banded
  (`:581-593`). **Site count and site placement radius do not scale with map size at all.**
- **AI residency / ADR-025 tiers.** Population comes from those fixed sites, so live-unit count at 2km
  is identical to 1280m. ADR-025's own kill-shot (`ADR-025:5-6`) is that WorldSim's
  `CELL_SIZE`/`AO_RADIUS` "can never produce DORMANT on a 1280m map" — a 2km map is, ironically, the
  first map on which the T3 dormant tier would even be reachable. That is an *argument for* 2km, but
  only after the tier work is funded, and it is not funded.

**SCALES LINEARLY WITH AREA (×2.56):** terrain triangles, terrain vertices, trimesh collision cooks,
vegetation candidate scatter, heightmap memory, loading-screen wall time.

**SCALES AND IS THE HIDDEN LANDMINE — hydrology.**
`terrain_manager.gd:369-370`:

```gdscript
# Mirrors WaterSystem._auto_downsample: ~400-cell hydrology grid at any map size.
hydro.downsample = maxi(1, int(round(float(heightmap.size) / 450.0)))
```

**That comment is false for every map between 1280 m and 2700 m.** At `size = 320` (1280m):
320/450 = 0.711 → round = 0 → clamped to **1**. At `size = 512` (2000m): 512/450 = 1.138 → round = **1**.
The divisor does not reach 2 until `size ≥ 675` (a 2700 m map). So the "~400-cell grid at any map
size" invariant is delivered at 1280 m only by accident (320 is already under 400) and at 2000 m it
silently hands the solver a **512² = 262,144-cell grid, 2.56× today's 102,400 and 28% over its own
stated target.** That grid then runs a GDScript priority-flood with a hand-rolled parallel-array
min-heap (`hydrology_map.gd:106, 112-129, 173-190, 266-280, 302-314`) — O(N log N) with an 8-neighbour
inner loop, in interpreted GDScript, on the main thread, inside the loading screen.

**THE ONE THING MOST LIKELY TO BREAK FIRST — two answers, because load and frame are different failures:**

- **At LOAD: the hydrology priority-flood.** 2.56× cells × log-factor ≈ **~2.8× today's solve time**,
  in GDScript, unbudgeted, before a single chunk is built. It is the only genuinely super-linear
  compute in the world build and its own comment claims it is size-invariant, which is exactly the
  kind of false invariant the fossil law exists to kill. **This is unmeasured today — nobody has ever
  timed `_extract_and_carve_rivers`.** A one-line `Time.get_ticks_usec()` bracket around
  `terrain_manager.gd:132` at 1280 vs 2000 is the cheapest probe in this entire document and it must
  run before the constant is touched.
- **In the FRAME: terrain, because terrain has no LOD and no distance culling — none, anywhere.**
  I grepped `terrain/core/terrain_chunk.gd` (239 lines) for `visibility_range`, `lod_bias`,
  `custom_aabb`: **zero hits.** Vegetation is protected — `tree_cover_layer.gd:45` caps cards at a
  350 m ring and `:427-434` sets real `visibility_range_begin/end` per node, so **canopy cost is flat
  with map size, by construction.** Terrain gets none of that. ADR-013 already states "there is no
  terrain LOD in the engine at all — `terrain_chunk.gd` builds one full-res mesh per chunk". Fog
  (`game_world.gd:89`, density 0.0065) hides distant ground but **fog does not cull; it shades.**
  So a ridgeline view at 2 km submits up to **524,288 terrain triangles** into a frame whose entire
  measured primitive count on the shipping demo is **324,000** (PERF_LEDGER 2026-08-14 morning).
  **A hilltop at 2km can more than double the demo's whole-frame geometry with ground the player
  cannot even see through the fog.**

## 1d. Verdict on item 8

**"It is one constant" is TRUE and verified. "Therefore it is cheap" is FALSE.** The constant is
one line; the bill behind it is 2.56× terrain geometry into an engine with no terrain LOD, a ~2.8×
unmeasured GDScript hydrology solve, a 56% coarser AI grid, and — the design half — **zero additional
content**, because the site planner's placement bands are anchored to the firebase gate at 240–470 m
and do not know the map got bigger. **At 2 km, roughly 60% of the world is procedurally-generated
empty jungle that no site, no patrol anchor and no enemy group will ever occupy.**

**The Summoner's persistent-province insight is real and I want it on the record as correct:** paying
the world load once per session instead of once per patrol genuinely buys the load-time budget, and
load time is where 2.56× of this bill lands. That argument answers the hydrology and chunk-cook cost
honestly. **It does not answer the frame cost**, because a resident world is a *drawn* world every
frame, and terrain has no LOD.

---

# 2. ZONES, NOT STREAMING — the "one builder, many places" contract in enforceable terms

## 2a. What exists today

`scripts/missions/mission_generator.gd` holds all three: `plan_patrol_world` (`:499`),
`plan_demo_world` (`:697`), `build_patrol_world` (`:877`). **Note the shape already present and
already correct:** there are TWO planners and ONE builder. `plan_demo_world` produces a different
`p` dictionary — a different seed, a different site roster, a different geography — and then the
*same* `build_patrol_world` materialises it. **That is "one builder, many places", already
implemented, already shipping.** The decree's item 9a is not a new architecture; it is a demand that
the existing shape be made *mandatory*.

The structural probe `tests/test_placement_paths.gd` enforces three rules today:
1. `:12-20` — the six placement entry points (`place_structure(`, `stamp_village(`, `stamp_vc_camp(`,
   `stamp_lz(`, `place_firebase_main(`, `place_prop(`) may be **called** only from `site_planner.gd`
   and `mission_generator.gd`.
2. `:30-37, 70-83` — six named placement files may not draw the global RNG (protects ADR-010).
3. `:85-98` — **exactly one** definition of `func build_patrol_world(`, and it must be in
   `mission_generator.gd` (ADR-028 Amendment A).

**Correction to the briefing:** the probe has **no `KNOWN_EXCEPTIONS` array**. The arena is handled by
`EXCLUDED_BENCHES` (`:26-28`), and the file's own comment (`:21-25`) explains *why* the rename
happened — "an exception still asserts the file is in scope and merely forgiven, which is the drift
this probe exists to stop." ADR-028 Amendment A (`:76-77`) still says "the single `KNOWN_EXCEPTIONS`
entry"; that ADR pointer is **stale** and should be corrected to `EXCLUDED_BENCHES` under the no-drift
law. Small, but this council should not write a new clause citing a symbol that no longer exists.

## 2b. The clause an ADR must say

I recommend the new ADR (call it ADR-037, *Zones, not streaming*) contain these words, because each
is mechanically checkable against the probe as it stands or with one named change:

> **1. An outdoor area of operations is a PLAN, never a scene.** Every outdoor place in the game —
> the home AO, any new AO, any staged assault ground — is produced by a `plan_*_world()` function in
> `scripts/missions/mission_generator.gd` returning the plan dictionary, materialised by the single
> `build_patrol_world()`. A new outdoor place is a new *planner and a seed*, never a new builder and
> never a hand-placed scene. This is ADR-028's foundation improved in place; it is not a parallel path.
>
> **2. There is exactly ONE outdoor world builder.** `build_patrol_world()` is defined once, in
> `mission_generator.gd`. A second definition anywhere fails the build. *(Already enforced:
> `test_placement_paths.gd:85-98`.)*
>
> **3. Placement stays behind the manifest.** The six placement entry points are callable only from
> `site_planner.gd` and `mission_generator.gd`. A hand-wired area that reaches for `place_structure()`
> or `place_prop()` from its own file FAILS. *(Already enforced: `:12-20, 47-68`.)*
>
> **4. INTERIORS are the named, bounded exception.** Tunnels, bunker interiors and hut interiors are
> authored `.tscn` scenes with no procedural terrain, no `TerrainManager`, no `GameplayGrid` and no
> site planning. They are exempt from clause 1 *precisely because* they instantiate none of the
> outdoor machinery. An "interior" that generates terrain is an outdoor AO wearing a costume and
> fails clause 1.
>
> **5. Every plan derives from ONE seed (ADR-010).** A new AO's planner takes an operation seed and
> draws only from a seeded RNG. Bare `randf`/`randi` in a placement file fails. *(Already enforced:
> `:30-37, 70-83` — but the new planner's file must be ADDED to `SEEDED_FILES` or the rule silently
> does not apply to it.)*
>
> **6. Streaming stays dead.** Zones exist so chunk streaming is never written. ADR-013's
> re-enablement bar (per-frame budget + off-main-thread mesh/collision + its own ADR with before/after
> frame times) is unchanged and un-weakened by this record.

## 2c. What the probe needs to change

Three changes, all small, all mechanical:

1. **Nothing** for clauses 2, 3 — those already fail correctly today. A hand-wired bespoke area that
   calls `place_structure()` from its own file already prints
   `FAIL: <path> calls place_structure( - a SECOND placement path (ADR-028)` (`:67`).
2. **`SEEDED_FILES` must gain every new planner file** (`:30-37`). This is the probe's one real hole:
   the seeded-RNG rule is a *whitelist*, so a new placement-owning file that nobody remembers to add
   is simply never checked. **Recommended hardening: invert it.** Apply the global-RNG ban to any file
   under `scripts/world/` or `scripts/missions/` that contains a placement call, rather than to a
   hand-maintained list. That converts a list somebody must remember into a rule that cannot be
   forgotten — the same reasoning that turned `KNOWN_EXCEPTIONS` into `EXCLUDED_BENCHES`.
3. **A new rule is needed for clause 1, and only for clause 1.** The probe today can prove there is
   one *builder*; it cannot prove a new outdoor area *used* it. Cheapest mechanical form: **every
   `plan_*_world(` definition must live in `mission_generator.gd`, and every `GameWorld` instantiation
   outside `game_flow.gd` + the excluded benches fails.** A hand-wired outdoor area has to make a world
   somewhere; forbidding a second `GameWorld` construction site is the choke point. That is ~15 lines
   in the existing `_walk` pass and it is the only new code item 9a needs.

**Cost named:** clause 1 forbids the fastest way to make a memorable place. Every AO in the game will
be procedurally derived, which means no hand-composed landmark, no authored ridge, no set-piece
geography — the price of never fracturing the world build is that the world can never be *composed*.
That is the correct trade under ADR-028 (Catacombs died of the alternative) but it is a real loss and
the level-design lens should be asked whether it can live with it.

---

# 3. BOARD, DON'T SELECT

## 3a. Is it buildable on the existing machinery? Yes — more of it exists than the briefing assumes.

The full ground cycle is real and shipping:
- `AirTraffic.request_replacement_lift(n)` (`scripts/ai/air_traffic.gd:778-782`) → `_dispatch_lz_cycle`
  (`:785`), which spawns the airframe at a random bearing `map_size * 0.55` out (`:806-808`), attaches
  the lift (`:816`) and flies it to a free firebase pad (`:822`).
- `HeliLift` (`scripts/vehicles/heli_lift.gd`) crews the cockpit (`_crew_ship`, `:137`), picks the
  sortie at dispatch (`_choose_mission`, `:166`), loads real men into real seats (`_load_pax` `:248` /
  `_load_replacements` `:408`), drives the cabin doors (`:188-213`), and puts men off on touchdown
  (`_deliver` `:297`, `_on_landed` `:277`).
- Doors shut the whole way in by design (`heli_lift.gd:9-12` — "the Summoner's concealment rule is
  satisfied by the DOORS, not by the dice").
- **And the player-boarding path is written.** `scripts/vehicles/seat_system.gd:170` `BOARD_RANGE = 4.5`,
  `:763-786` is a complete interact→seat→unseat loop for `GameManager.player`, with `enter_seat` /
  `exit_seat` on the player side (`:581`) and a position-only glue that never reparents the player
  (`:14`).

**It is switched off by one exported flag and one comment:**

```gdscript
## OPT-IN. Helicopters are PARKED (ADR-029 foot-only slice); nothing enables
## player_boarding today. The seat contract + test stay for the thaw.
@export var player_boarding: bool = false
```
— `scripts/vehicles/seat_system.gd:173-179`, against `ADR-029:36` ("**Foot only** for the slice.
Helicopters are PARKED (Summoner, 2026-07-17)").

**Verdict: "you board the Huey, you don't select it" is buildable on machinery that is already
written and already tested, and the boarding half is a flag flip plus a crew-chief prompt.** The
architecture the decree asks for is the architecture that exists. This is the cheapest of the four
technical items by a wide margin and the only one I would call low-risk.

## 3b. The actual problem underneath it: the load mask is aspiration, not code

**ADR-017 §4 line 45 claims "The Huey ride remains — and remains the load mask — for windows elsewhere
in the province."** ADR-017's own evidence line (`:118`) cites
`scripts/main/game_flow.gd:242-280 — the mission build path; plan.start_pad gates the Huey ride`.

**That pointer is dead.** I grepped `game_flow.gd` for `start_pad`, `Huey`, `heli` and `insertion`:
**zero hits.** `game_flow.gd:242-280` is now `_dev_gun_run` / `_dev_sapper_run` (`:237`, `:263`).
The insertion ride was cut by ADR-029 and `save_manager.gd:8-9` records the collateral in plain
language: "the wheels-down checkpoint died with ADR-029's insertion cut; never rebuilt".

**So: the ride exists as an ambient sortie; the ride as a LOAD MASK does not exist and never did in
the shipped build.** ADR-017 §4's claim is aspiration and should be marked as such in this council's
record under the truth law.

**The real engineering problem, stated honestly.** A boarding zone-transition is not a seating problem,
it is a *teardown-and-rebuild* problem, and the seam is `GameFlow._teardown_world()`
(`game_flow.gd:407`) plus `MissionScope.reset()` (ADR-010's mandatory static registry). Today
`enter_hub()` (`:589-592`) tears the world down and builds a new one, awaiting through the build. To
make the ride a mask you must:

1. Keep the player alive, seated and rendering **while the old world is freed and the new one
   generates** — and the whole generate path is `await`-based across many frames
   (`terrain_manager.gd:98, 111, 119, 131-136`) with the player's own world as its parent.
2. Decide **where the player node lives during the transit**. `seat_system.gd:14` is emphatic that the
   player is glued position-only and **never reparented** — which is exactly the right call for a seat
   inside one world and exactly the wrong shape for carrying a player across a world teardown.
3. Pay `MissionScope.reset()` at the seam, or not pay it and inherit ADR-010's proven cross-mission
   leak class (stale statics, craters over the wrong heightmap, muted stings).
4. **Or — the cheap and correct answer — don't mask it at all.** Doors shut → cabin interior fills the
   screen → hard cut to the loading screen → doors open on the new pad. STALKER's ten zones have
   loading screens and nobody minds. **The mask is a nice-to-have; the BOARDING is the pillar-serving
   part**, because what kills the briefing/mission-select loop is that the bird is a place with a crew
   chief, not that the load is invisible.

**My recommendation to the Arbiter: ratify "board, don't select" as the interface law and explicitly
DECLINE the seamless load mask.** A loading screen between zones costs nothing, is what the reference
game does, and removing it from scope deletes the single hardest engineering problem in item 9 (a
live player surviving a world teardown) for zero loss to the fiction. Amend ADR-017 §4 to say the ride
is the *fiction of transit*, not a technical load mask, and correct its dead `game_flow.gd:242-280`
pointer while the council is here.

**Cost named:** without the mask, "the province feels like one place" is delivered by *fiction and
continuity of state*, not by continuity of frame. If the Summoner's eye rejects a loading screen
between the pad and the new AO, item 9 stops being cheap and becomes the hardest item on this list.

---

# 4. SAVE ANYWHERE — the honest bill

## 4a. First: the two "still open" defects are CLOSED. Verified against current code.

The briefing asked me to verify two open ship-list defects. **Both were fixed on 2026-08-07 and the
briefing's line numbers describe pre-amendment code:**

- **Atomic writes — CLOSED.** `scripts/autoload/save_manager.gd:100-131` is a full write-and-swap:
  `.tmp` write → `flush()` → `f.get_error()` verify → remove stale `.bak` (Windows rename refuses an
  existing target, `:123`) → rotate current file to `.bak` (`:126`) → `rename_absolute(tmp, path)`
  (`:127`). The briefing's "~:99-107 writes in place" is the old code.
- **Future-version reject — CLOSED.** `save_manager.gd:193-199`: `if file_version >
  SaveData.SCHEMA_VERSION:` prints and **returns null**, with the comment explaining why it refuses
  outright rather than silently rolling back to a `.bak`. Load also falls back to `.bak` on a corrupt
  primary (`:186-192`). The briefing's "~:174-177 only migrates OLDER schemas" is the old code.

ADR-007 already records both amendments as implemented, with the correct pointers. **These are not
outstanding risk and should be struck from the ship list.** Saying so is worth more than a guess:
under save-anywhere both would indeed have been catastrophic, and they are not there.

## 4b. What persists TODAY (the complete list)

`SaveManager.collect()` (`:134-142`) writes exactly four sections:

| section | source | contents |
|---|---|---|
| `campaign` | `CampaignState.to_dict()` (`campaign_state.gd:400-420`) | threat_level, threat_modifiers, reputation, **roster**, missions_played, mission_log, iron_man, player_data, intel_points, **collapsed_tunnels**, **field_marks**, **pencil_marks**, rack_condition, depot_loss, kia_total, ward_wounded, bags_unlifted, pilots_recovered |
| `hub` | `hub_snapshot` (`:30`, maintained by GameFlow) | operation seed + name |
| `meta` | `:138-140` | timestamp, missions_played, playtime |
| `player` | `_collect_player()` (`:145-177`) | position, rotation_y, stamina, hp, health_packs, smoke/claymore/satchel/flare/grenade/ration/repair-kit counts, hunger, primary/secondary weapon **resource paths**, per-slot magazine arrays, weapon_condition |

**That is the entire persisted state of the game.** Note what it is: **the player's pockets, the
campaign's ledgers, and one seed.** ADR-010 is why — the world is a pure function of the operation
seed, so the save does not describe the world, it describes the *inputs* to the world.

`apply()` (`:212-217`) + `apply_pending_player()` (`:223-262`) restore only those, and only after the
hub world exists — the deferred-apply discipline ADR-007 ratified. And note `:233`:
`if p.context == "hub" and p.position != Vector3.ZERO` — **position is restored ONLY in the hub.**
A field position is collected and then thrown away on load. Save-anywhere is not partially built; the
restore path actively refuses field positions.

## 4c. What would have to persist — and why ADR-010 breaks

ADR-010's contract is "same seed = same world, same enemies, same events". That holds **only while
the world is a pure function of the seed.** The moment the player mutates it, the seed no longer
describes what is on screen, and everything below has to be written into the file:

**Workstream S1 — TERRAIN MUTATION.** Every crater and every dig. `TerrainManager.modify_terrain`
(`:289-298`) edits the heightmap in place; `TERRAIN_HOLES_ENABLED` (`world_config.gd:45`) is true and
deforms drain 1/frame (`:46`). A saved world must carry either the full 512²×4 B = **1.0 MB heightmap
delta** or an ordered, replayable list of every modification. Both are new file-format work; the
former alone is ~250× the current save's size class.

**Workstream S2 — DESTRUCTION (ADR-031).** Levelled buildings, felled trees, burned hootches. The
vegetation manager keeps a `_fell_registry` and per-chunk placement caches
(`vegetation_manager.gd:467, 490, 542`) that are rebuilt from seed today. Every destroyed structure
and every felled tree becomes a persisted id.

**Workstream S3 — THE LIVING POPULATION.** Every enemy, ally, civilian and garrison man: identity,
position, hp, wound state, ammunition, squad membership, alert tier, current behaviour, and the
work-point / bunk claims they hold. ADR-025 §Phase 2 already names this as "the highest-risk seam"
and demands a "bit-exact" capture/apply pair (`ADR-025:73-74, 92`) — **and that capture does not
exist yet.** Save-anywhere cannot be built before ADR-025 Phase 2; it *is* ADR-025 Phase 2 plus a
file format.

**Workstream S4 — THE WORLD CLOCK AND ITS SCHEDULES.** Sim time, weather, hour-of-day placement
(`place_for_current_hour`), in-flight air traffic (`_in_flight` roster, `air_traffic.gd:809-816`),
convoys in transit, sieges mid-assault, fires still burning (`FireHazard.active`), ordnance in the
air. Anything with a timer node or an `_ms` stamp is a serialisation question and most of them are
currently `Time.get_ticks_msec()`-relative — **wall-clock relative stamps do not survive a reload at
all** and every one is a defect the moment a save can land mid-mission.

**Workstream S5 — THE FORMAT AND THE SEAM.** JSON via `JSON.stringify(..., "\t")` (`:106`) is fine for
a 4 KB pocket-save and is not fine for a megabyte of heightmap plus a few hundred serialised men.
Binary or compressed sections, a schema version bump, a migration step, and a re-verification of the
atomic swap at the new size. Plus the tier question: `can_manual_save()` (`:88-96`) currently pins
HARD/IRONMAN to the hub — save-anywhere either repeals ADR-007's tier ladder or must be scoped to
REGULAR only, and that is a design ruling this council owes, not an implementation detail.

**Workstream S6 — THE DETERMINISM AMENDMENT.** ADR-010 must be amended to say: *the seed generates the
world's INITIAL state; a save carries the DELTA from that initial state; the seed contract holds only
at t=0.* Without that amendment written first, every workstream above is a silent violation of a
ratified ADR. **S6 is cheap and must come first.**

## 4d. Verdict on item 10

**Six workstreams, of which S3 is a prerequisite that belongs to ADR-025 and has not started, and S1
is a file-format problem that turns a 4 KB save into a megabyte-class one.** This is the largest
single item in the decree by a wide margin — larger than 2km and zones combined. Recording it as
post-demo canon is exactly right; anything more than recording it competes directly with shipping.

**The cheap intermediate that gets 80% of the feel:** extend the existing save to cover the *hub-side*
world (garrison roster, ward, depot, marks — most of which `CampaignState` already carries) and keep
field saves at the wire. That is "save when you get back to base", it costs almost nothing, it is what
HARD and IRONMAN already do (`save_manager.gd:88-96`), and it should be offered to the Summoner as
the alternative before the full bill is priced.

---

# 5. TUNNELS AS DUNGEONS

## 5a. What the tunnel object actually is, today

**It is already more than a mouth. It is a working micro-dungeon, and it is PROCEDURAL.**

- **The mouth.** `SiteLayouts.TUNNEL_MODEL` (`scripts/world/site_layouts.gd:55`) =
  `assets/world/building models/structures/vc_nva/tunnel_entrance_hidden.glb`, placed by the site
  planner in villages (`site_planner.gd:305`) and VC camps (`:2248`), both through `place_structure()`
  — i.e. **already inside the one placement path**, manifest-legal.
- **The interior.** `scripts/world/tunnel_room.gd` — `class_name TunnelRoom`, 92 lines. Header:
  *"Tunnel-rat micro-dungeon (W51): a dark cache chamber 40m under the entrance."* `ROOM_SIZE :=
  Vector3(10, 3, 14)` (`:8`). `get_or_create` (`:15-24`) lazily builds the room 40 m below the mouth
  and caches it on the entrance node via `set_meta("tunnel_room")`. `_build()` (`:27-60`) constructs
  the room **in code, from six `BoxMesh` panels on one `StaticBody3D`** in the `hard_surface` group,
  plus one warm `OmniLight3D` at energy 0.7.
- **It is wired to the player.** `scripts/player/player.gd:600` holds `var _in_tunnel: TunnelRoom`;
  `:912` calls `TunnelRoom.get_or_create(get_tree().current_scene, entrance)`; `:1045` fires the
  loot toast `"TUNNEL CACHE - DOCUMENTS AND AMMO (+2 INTEL)"`; `:1003` removes the mouth from the
  `tunnel_entrances` group when it is satchelled.
- **The loop the decree describes already closes.** `field_mark_verb.gd:22-29` infers the **TUNNEL**
  noun from the `tunnel_entrances` group or an 8 m proximity; `campaign_state.gd:36, 495-503` persists
  `collapsed_tunnels` across sessions; `field_director.gd:1591, 1634` runs the sweep that ends
  `"THAT TUNNEL'S SHUT"`; `enemy_base.gd:1022` lets the AI use mouths. There is even a probe:
  `tests/test_spider_tunnel.gd`.

**Correction to the briefing:** the field-marking vocabulary is **FOUR nouns, not six** —
`field_mark_verb.gd:3` says so explicitly ("FOUR nouns only — the vocabulary is the world's, not a
menu") and `infer()` returns exactly CONTACT, TUNNEL, CAMP, TRAIL (`:22, 24, 30, 44`). TUNNEL is one
of four, which makes it *more* load-bearing than the briefing assumed, not less.

## 5b. Pricing the thaw against "authored scenes, not procedural"

GAME_GUIDE line 319 is unambiguous and I am pricing a thaw, not declaring one: tunnel INTERIORS are
**FROZEN (post-core)** — "a second game: different movement, light, combat — it eats a year. **Tunnel
MOUTHS you mark and satchel are IN SCOPE TODAY.** Going down the hole is the FIRST THAW once the core
is undeniable."

**The awkward fact this council must confront: `TunnelRoom` is a procedurally-generated interior that
already ships, and it contradicts item 9a's "interiors are authored scenes" line as written.** Three
ways out, priced:

1. **Amend 9a to permit it.** Say "interiors are authored scenes **or a single shared procedural
   interior builder**, never a per-place bespoke one" — which is the same one-builder-many-places law
   applied a level down, and `TunnelRoom.get_or_create` already *is* that builder. **Cost: near zero.
   This is my recommendation.** It keeps the law's real intent (no bespoke second path) without
   criminalising working code, and it is consistent with ADR-028's "improved in place, never rebuilt".
2. **Replace `TunnelRoom` with authored `.tscn` interiors.** Cost: art (the interior kit does not
   exist), plus a placement/variant system, plus re-wiring the player's descend/ascend path, plus a
   new probe. **This is the year GAME_GUIDE:319 warns about** and it must not start pre-launch.
3. **A hybrid: authored ROOM MODULES stitched by the existing builder.** `get_or_create` picks from a
   set of authored `.tscn` chambers instead of building boxes; the connection logic stays one builder.
   **Cost: moderate art, small code.** This is the honest middle and the right shape for the thaw when
   it comes.

**Costs named for any thaw, in the order they will hurt:**
- **Combat in a 10×3×14 m box is a different game.** Grenades, the flat damage grammar (ADR-016),
  suppression, AI pathing at those distances, and the fear doctrine were all tuned in open jungle.
  Every one needs re-tuning underground; none of them can be reused unexamined.
- **Light.** `game_world.gd:65` sets `light.shadow_enabled = false` project-wide and ADR-026 allows
  exactly one dynamic shadow (the night sun). A tunnel is a *pistol-light* space — dynamic light is
  its entire atmosphere, and the ADR-026 budget does not currently have room for it.
- **The room is 40 m below the terrain and is currently a `StaticBody3D` in an open world.** It has no
  occlusion relationship to the surface — the surface world keeps rendering above it. Under the
  perf-first law, a proper interior needs the surface world *not drawn*, and that is a visibility
  problem the engine currently does nothing about.
- **Save-anywhere interacts.** A player who saves underground needs the lazily-created room, its
  looted flag (`tunnel_room.gd:11`) and his surface-return position (`:10`) persisted — none of which
  are in `SaveData` today. Items 10 and 11 are coupled.

**Verdict on item 11: the loop the decree describes (find → mark → return kitted → descend) is ~70%
built and shipping.** The thaw is not "build tunnels"; it is "make the room worth going into", which
is content, lighting and combat-tuning work, and GAME_GUIDE:319 is right that it is a year if done
properly. **Record it, price option 1's ADR wording now (it costs a sentence), and thaw nothing.**

---

# 6. THE GATING FPS NUMBER — the measured state, and the verdict

## 6a. What the ledger actually says today

`production/PERF_LEDGER.md` opens with a banner: **"THERE IS NO NUMERIC FPS GATE. (Summoner,
2026-07-20: *'No numeric gate — my eyes decide.'*)"** Every "clears the gate" phrase below it is
historical shorthand for an unratified working target. The charter is correct that this is the #1
systemic risk and it has been unset since July.

**The most recent real rows — shipping demo scene, 1280×720, render scale 0.75, Intel UHD, Forward+,
2026-08-14 evening (post spawn-burst fix):**

| pose | fps avg | fps min | GPU ms avg/max | CPU ms avg/max |
|---|---:|---:|---|---|
| demo baseline (2026-08-14 morning) | **34.5** | 33.0 | 24.06 / 26.64 | 3.67 / 7.81 |
| siege quiet | **33.9** | 9 | 27.1 / 36.4 | 3.9 / 33.6 |
| assault_in | **27.4** | 5 | 32.3 / 40.7 | 4.5 / 12.8 |
| **assault_on_wire** | **22.6** | **5** | **33.2 / 48.5** | **5.0 / 13.4** |

**The gate proposal awaiting ratification (PERF_LEDGER, 2026-08-14, step 18):** *"at the shipped 0.75
scale on this box — **assault_on_wire ≥ 20 fps average, ≥ 10 fps minimum**. Passes TODAY with ~2fps
margin; it is a hold-the-line gate, not an aspiration."* Post-fix the average margin is **~2.6 fps**.

**Note honestly: the demo does not pass its own proposed gate today.** It clears the average
(22.6 ≥ 20) and **misses the minimum (5 < 10)**, and the ledger says those 5 fps dips are **GPU-led**
(`gpu_ms_max` 35–41 vs `cpu_ms_max` 9–10). The frame on the floor box is GPU-bound at every measured
phase — the 2026-08-14 crucible finding ranks it #1: *"The GPU is the wall on the UHD floor."*

## 6b. Is a 2km map affordable against those numbers?

**No — not today, and the reason is one specific missing feature, which makes this a fundable problem
rather than a refusal.**

The reasoning, with the arithmetic from §1:
- The demo's whole frame at its measured baseline is **324,000 primitives / 1,764 draw calls** at
  **24 ms of GPU**, on a box where the fight already spends **33.2 ms** of GPU and dips to 5 fps.
- Canopy does **not** scale with map size — `tree_cover_layer.gd:427-434` gives every vegetation
  MultiMesh a hard 350 m `visibility_range_end`. That protection is real and it is why 2km is even
  arguable.
- **Terrain has no such protection.** `terrain_chunk.gd` contains no `visibility_range`, no LOD, no
  custom AABB, and ADR-013 states the absence as fact. Fog shades distant ground; it does not cull it.
  A 2km world therefore holds **524,288 terrain triangles** resident and frustum-submits as many as
  the view contains — up to **+319,488 over today**, into a 324k-primitive frame with 2.6 fps of
  margin on a GPU-led floor box.
- **A 60% area increase that adds no sites, no enemies and no objectives** (§1c: placement bands are
  gate-anchored at 240–470 m and do not scale) is paid entirely in GPU for entirely in empty ground.

**The condition under which 2km becomes affordable, stated as a fundable gate:** ship **terrain
distance-culling or terrain LOD first** — at minimum a `visibility_range_end` on distant terrain
chunks, at best a real LOD ladder — and **prove it with a before/after GPU-ms measurement at 1280 m**
where it must cost nothing. Then re-measure at 2000 m. **Nothing about the map size may be changed
before that pair of measurements exists** (verification law: "likely fine" closes nothing).

**And the prerequisite to all of it: the Summoner must ratify a number.** The ledger's own
`assault_on_wire ≥ 20 avg / ≥ 10 min` proposal has been sitting "ready for his ratification" since
2026-08-14. **Until a number is law, "is 2km affordable" has no answer, because there is nothing for
it to be unaffordable against.** I recommend this council's single highest-priority ask of the
Summoner be the ratification of that gate — not because 20/10 is the right number, but because an
unratified gate makes every performance argument in this decree unresolvable by construction.

---

# 7. TRADEOFFS — no free lunches

**Item 8 (2km):**
- **Bought:** more ground to patrol; the first map on which ADR-025's DORMANT tier is even reachable
  (`ADR-025:5-6`); a persistent province genuinely amortises the 2.56× load cost over a session.
- **Sacrificed:** +319,488 resident terrain triangles with no LOD and no culling, into an already
  GPU-bound frame · a ~2.8× GDScript hydrology solve on the main thread at load, currently unmeasured
  and mislabelled size-invariant in its own comment (`terrain_manager.gd:369`) · **56% coarser AI
  cover/LOS/passability grid** (5.00 m → 7.81 m cells) with no compensating change, because
  `GameplayGrid` is pinned at 256² · 2.56× loading-screen wall time · **and ~60% of the new world is
  empty**, because the site planner's placement bands never learned the map grew. Bigger, emptier,
  slower, and blinder — unless site scaling and terrain LOD are funded alongside.

**Item 9 (zones):**
- **Bought:** the Catacombs streaming bug class stays impossible by construction; areas are added
  without ever writing a streamer; ADR-028's foundation is enforced rather than merely asserted.
- **Sacrificed:** every outdoor place in the game is procedurally derived forever — no hand-composed
  landmark, no authored ridge, no set-piece geography. Loading screens between zones become permanent
  furniture. And the probe hardening in §2c is real work that produces no player-visible value.

**Item 9b (board, don't select):**
- **Bought:** the mission-select loop cannot re-grow, because there is no menu to grow it in; ADR-029
  stays intact; the machinery already exists (`seat_system.gd:763-786`).
- **Sacrificed:** un-parking helicopters reopens ADR-029:36 ("Foot only for the slice") — that is a
  deliberate scope fence being taken down and it should be taken down knowingly. If the seamless load
  mask is demanded rather than the loading screen, this item goes from the cheapest on the list to the
  hardest: a live player surviving `_teardown_world()` + `MissionScope.reset()`, against a seat system
  whose own header (`seat_system.gd:14`) forbids the reparenting that would make it easy.

**Item 10 (save anywhere):**
- **Bought:** the living world becomes a place the player inhabits rather than visits.
- **Sacrificed:** ADR-010's seed contract, permanently — the seed will describe only t=0 · the save
  goes from ~4 KB of pockets to a megabyte-class world delta · ADR-025 Phase 2's bit-exact
  capture/apply becomes a hard prerequisite · ADR-007's tier ladder must be repealed or scoped ·
  every `Time.get_ticks_msec()`-relative timer in the codebase becomes a reload defect. **Six
  workstreams. This is the largest item in the decree.**

**Item 11 (tunnels):**
- **Bought:** the mark→return→descend loop, which is ~70% built and shipping already
  (`tunnel_room.gd`, `player.gd:600, 912, 1003, 1045`, `campaign_state.gd:495-503`).
- **Sacrificed:** combat, movement, lighting and AI all re-tuned for a 10×3×14 m box · ADR-026's
  one-dynamic-shadow budget confronted by a space whose atmosphere IS its light · the surface world
  keeps rendering 40 m overhead with no occlusion story · coupling to item 10 (nothing about a tunnel
  is in `SaveData`) · and GAME_GUIDE:319's blunt estimate: *it eats a year.*

**The tradeoff across the whole decree:** every one of these four items is a *world* investment, and
the project's measured wall is the *frame*. **Recording them as canon is free and correct. Starting
any of them before a gating FPS number is ratified spends the demo's remaining margin on ground the
player cannot see.**

---

# 8. WHAT I OWE / WHAT IS UNMEASURED (verification law)

Named plainly, because none of these are closed and I will not pretend otherwise:

1. **`_extract_and_carve_rivers` has never been timed** (`terrain_manager.gd:132`). The §1c
   superlinear claim is arithmetic from cell counts, not a measurement. One `Time.get_ticks_usec()`
   bracket at 1280 vs 2000 settles it. **Cheapest, highest-value probe in this document.**
2. **Total world-build wall time has never been split by phase** (hydrology vs chunk mesh vs trimesh
   cook vs vegetation scatter). The 2.56× load claim is derived, not measured.
3. **No terrain-only GPU attribution exists.** The +319,488-triangle frame claim is geometric; the
   ledger has never isolated terrain as a toggle. It should be the next `perf_probe` phase.
4. **The `player_boarding` path has never been exercised in the shipped build** — the flag has been
   false since it was written (`seat_system.gd:173-179`). "It works" is inference from the code and
   the test, not from a run.
5. **ADR pointer corrections owed under the no-drift law:** ADR-028 Amendment A `:76-77` cites
   `KNOWN_EXCEPTIONS`, which no longer exists (it is `EXCLUDED_BENCHES`,
   `test_placement_paths.gd:26`) · ADR-017 `:118` cites `game_flow.gd:242-280` / `plan.start_pad`,
   both of which are gone · ADR-007's `:92-102` / `:165` evidence lines describe pre-amendment code
   (the ADR's own inline note already says so) · `terrain_manager.gd:369`'s "~400-cell hydrology grid
   at any map size" comment is false for every map from 1280 m to 2700 m.
6. **The gating FPS number remains unratified**, and until it is, item 6 has no pass/fail — only a
   measured state and my judgement against it.
