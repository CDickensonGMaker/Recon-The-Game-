# ADR-039: Zones, not streaming — one builder, many places; and you BOARD the bird, you never select it

**Date:** 2026-09-06 · **Status:** ACCEPTED as canon; **POST-DEMO — BUILD NOTHING** (Summoner decree,
THE RPG PIVOT, under his own scope wall *"but the demo scope is still the overall goal"*) ·
**Amends:** ADR-013 (adds the map-size gate below), ADR-017 (§4's load-mask claim corrected — see §5),
ADR-028 (Amendment A's one-path law extended from *one world* to *many places, one builder*) ·
**Depends on:** ADR-010 (one seed), ADR-013 (≤2km never streams), ADR-028 (the protected foundation) ·
**War Room:** `production/war_room/2026-09-06_rpg_pivot/`

---

## Context

The Summoner named the shape of a bigger game and, in the same breath, the way to get it without
writing the feature that killed a previous project:

> STALKER is about ten zones with loading screens, not one seamless map. So separate areas — Huey
> assaults, operations, staged areas off the main world — are the way to feel larger. **And it means
> chunk streaming never has to be written.**

That is exactly right, and it is the reason this ADR exists. ADR-013 killed chunk streaming by policy
after diagnosing it as *"the exact synchronous-world-streaming bug class that killed the Catacombs
project."* ADR-028 then unified fourteen divergent world systems into one deterministic build path and
declared it a **PROTECTED FOUNDATION**: improved in place, never rebuilt, never re-fragmented, never
given a parallel path.

**Zones are how the game grows without touching either law.** But a zone is also the most natural place
in the world to hand-wire a bespoke scene — and a hand-wired scene *is* the fracture ADR-028 exists to
prevent. So the permission and the constraint are recorded together, here, before anything is built.

## Decision

### 1 · ONE BUILDER, MANY PLACES (six clauses, mechanically checkable)

> **1. An outdoor area of operations is a PLAN, never a scene.** Every outdoor place in the game — the
> home AO, any new AO, any staged assault ground — is produced by a `plan_*_world()` function in
> `scripts/missions/mission_generator.gd` returning the plan dictionary, materialised by the single
> `build_patrol_world()`. **A new outdoor place is a new planner and a seed, never a new builder and
> never a hand-placed scene.** This is ADR-028's foundation improved in place; it is not a parallel path.
>
> **2. There is exactly ONE outdoor world builder.** `build_patrol_world()` is defined once, in
> `mission_generator.gd`. A second definition anywhere fails the build.
> *(Already enforced: `tests/test_placement_paths.gd:85-98`.)*
>
> **3. Placement stays behind the manifest.** The placement entry points are callable only from
> `site_planner.gd` and `mission_generator.gd`. A hand-wired area that reaches for `place_structure()`
> or `place_prop()` from its own file FAILS. *(Already enforced: `test_placement_paths.gd:12-20, 47-68`.)*
>
> **4. INTERIORS are the named, bounded exception.** Tunnels, bunker interiors and hut interiors are
> built with **no procedural terrain, no `TerrainManager`, no `GameplayGrid` and no site planning**.
> They are exempt from clause 1 *precisely because* they instantiate none of the outdoor machinery.
> **An "interior" that generates terrain is an outdoor AO wearing a costume and fails clause 1.**
>
> **4a. An interior may be authored OR generated — but by ONE shared interior builder, never per-place.**
> *(Corrected in council from an earlier "authored `.tscn` only" wording, which the code already
> contradicts: `scripts/world/tunnel_room.gd` `TunnelRoom` is a wired, procedural 10×3×14m cache room
> shipping today. Clause 1's real principle is **one builder**, not *procedural versus authored* — and
> that principle applies inside as well as out. A second interior generator is the same fracture as a
> second world builder.)*
>
> **5. Every plan derives from ONE seed (ADR-010).** A new AO's planner takes an operation seed and
> draws only from a seeded RNG. Bare `randf`/`randi` in a placement file fails.
>
> **6. Streaming stays dead.** Zones exist so that chunk streaming is never written. ADR-013's
> re-enablement bar — per-frame time budget, mesh and collision cook off the main thread, and its own
> ADR carrying before/after frame times — is unchanged and un-weakened by this record.

**A hand-wired bespoke outdoor area is FORBIDDEN and must fail the structural probe.**

### 2 · WHAT THE PROBE STILL CANNOT CATCH (recorded so it is not mistaken for enforcement)

Clauses 2, 3 and 5 fail correctly today. **Clause 1 is not enforced at all**, and clause 5 has a hole:

- **Clause 5's rule is a whitelist.** `SEEDED_FILES` (`tests/test_placement_paths.gd:30-37`) is
  hand-maintained, so a new placement-owning file that nobody remembers to add **is simply never
  checked**. Hardening, when this is built: invert it — apply the global-RNG ban to any file under
  `scripts/world/` or `scripts/missions/` that contains a placement call. That turns a list somebody
  must remember into a rule that cannot be forgotten.
- **Clause 1 needs one new rule (~15 lines).** The probe can prove there is one *builder*; it cannot
  prove a new outdoor area *used* it. Cheapest mechanical form: **every `plan_*_world(` definition must
  live in `mission_generator.gd`, and every `GameWorld` instantiation outside `game_flow.gd` and the
  excluded benches fails.** A hand-wired outdoor area must construct a world somewhere; forbidding a
  second construction site is the choke point.

**Neither is built. Neither may be claimed as enforced until it is** (truth law, ADR-015).

### 3 · THE COST OF CLAUSE 1, NAMED

Clause 1 forbids the fastest way to make a memorable place. **Every outdoor AO in the game will be
procedurally derived** — no hand-composed landmark, no authored ridge, no set-piece geography. The price
of never fracturing the world build is that the world can never be *composed*. This is the correct trade
(Catacombs died of the alternative), but it is a real loss, and it collides with the vignette-place
ambition of the same decree. **The reconciliation is ADR-020 §1-§2 and, in full, ADR-041:** a memorable
place is made by what is *stamped and dressed* on procedural ground, and by the authored interiors of
clause 4 — not by hand-sculpting the ground itself.

> **CITATION CORRECTED 2026-09-06 (ADR-041 §9, no-more-drift).** This paragraph originally read *"the
> reconciliation is §4 of ADR-020."* **ADR-020 §4 is the Ambience Law** — how often ambient events fire
> at the firebase — and contains nothing about stamping or dressing places. The licence for authored
> ground is ADR-020 **§1-§2** (the rail/guarantee distinction; the first patrol is *"AUTHORED-DENSE"*).
> The argument was sound; the pointer was wrong. **ADR-041 now carries the mechanism in full**: the
> scene is a plan, not a prefab — the GROUND can never be composed, but a PLACE can.

### 4 · YOU BOARD THE BIRD, YOU NEVER SELECT IT

> **The Huey is a place on the pad with a crew chief. It is not a mission menu.**

Zone travel is a **diegetic act performed in the world**: you walk to the pad, you board, the doors
shut, you ride, you step off somewhere else. There is **no destination list, no map-select, no
ACCEPT/DECLINE, and no screen** at any point.

This clause exists for one reason and it is not flavour: **it is the load-bearing guard that keeps
ADR-029 intact.** ADR-029 deleted the briefing screen, the offer board and mission select in July.
A zone system is the single most likely way for all three to grow back — a list of places to go *is*
an offer board. Boarding cannot become selecting.

**The ground cycle already exists** and more of it than expected: a Huey lands on the firebase pad, men
board real seats, doors shut for the ride, and they step off at the far end
(`scripts/vehicles/heli_lift.gd`, `AirTraffic.request_replacement_lift`, `seat_system.gd`).

**And the PLAYER half is already built and switched off.** `seat_system.gd:763-786` is a complete player
board/unseat loop, gated behind one export — `player_boarding: bool = false` (`:173-179`) — left off
because ADR-029's slice is foot-only and helicopters are PARKED. **Boarding is therefore nearly free;
the expensive half is the zone transition behind it (§5), not the act.** The seat contract and its test
stay in place for the thaw.

### 5 · TRUTH-LAW CORRECTION TO ADR-017 §4

**ADR-017 §4 claims "the Huey ride remains — and remains the load mask — for windows elsewhere in the
province." That claim is aspiration, and its own evidence pointer is dead.** ADR-017's evidence cites
`game_flow.gd:242-280` as "the mission build path; `plan.start_pad` gates the Huey ride"; that span is
now `_dev_gun_run` / `_dev_sapper_run`, and `game_flow.gd` contains **zero** hits for `start_pad`,
`Huey`, `heli` or `insertion`. The insertion ride was cut by ADR-029, and `save_manager.gd:8-9` records
the collateral in plain language: *"the wheels-down checkpoint died with ADR-029's insertion cut; never
rebuilt."*

**So: the ride exists as an ambient sortie. The ride as a LOAD MASK does not exist and never did in the
shipped build.** The real engineering problem is not seating — it is **teardown-and-rebuild**, seamed at
`GameFlow._teardown_world()` (`game_flow.gd:407`) plus `MissionScope.reset()` (ADR-010's mandatory
static registry). Anyone who builds this must start there, not at the helicopter.

### 6 · THE MAP-SIZE GATE (item 8 — 2km per side)

The Summoner asked for 2km per side, correctly noting it sits inside ADR-013's existing "≤2km loads
whole, never streams" policy and is therefore one constant. **Both halves of that were measured:**

- **"It is one constant" is TRUE** — `world_config.gd`'s `MAP_SIZE`, and ADR-013's guard is
  inclusive-safe, so streaming stays off at exactly 2000.
- **"Therefore it is cheap" is FALSE.** 2km is **2.56× the terrain geometry** of the 1280m world of
  record — up to **+319,488 resident terrain triangles** — into a frame that already measures
  **324,000 primitives / 1,764 draw calls** and spends **33.2 ms of GPU** during the assault on a floor
  box with **~2.6 fps of margin**, GPU-led at every measured phase.
- **Canopy is protected; terrain is not.** Vegetation MultiMeshes carry a hard 350m
  `visibility_range_end` (`tree_cover_layer.gd:427-434`), which is why 2km is arguable at all.
  `terrain_chunk.gd` has **no `visibility_range`, no LOD, no custom AABB**. Fog shades distant ground;
  it does not cull it.
- **And it adds no content.** The site planner's placement bands are anchored to the firebase gate at
  240–470m and **do not know the map got bigger**. At 2km, roughly **60% of the world is procedurally
  generated empty jungle** that no site, no patrol anchor and no enemy group will ever occupy. A 60%
  area increase paid entirely in GPU, entirely for empty ground.
- **The Summoner's persistent-province insight is correct and is recorded as correct:** paying the world
  load once per session rather than once per patrol genuinely buys the *load-time* budget, which is
  where 2.56× of this bill lands. **It does not answer the frame cost**, because a resident world is a
  drawn world every frame.

> **THE GATE (binding).** The map size may not be raised above 1280m until BOTH hold:
> **(1)** terrain distance-culling or terrain LOD ships, proven by a **before/after GPU-ms measurement
> at 1280m where it must cost nothing**, then re-measured at 2000m; and **(2)** the placement bands
> scale with map size, so that new ground carries new content.
> **A map-size change without that pair of measurements is forbidden** (verification law: "likely fine"
> closes nothing).

### 7 · SAVE ANYWHERE (item 10) — POST-DEMO, and the largest item in the decree

Recorded in full at **ADR-007 Amendment A**. Summary of the ruling: it is **six workstreams**, larger
than 2km and zones combined, and it breaks ADR-010's central economy — saves are small *because the
world regenerates from a seed*, and that assumption dies the moment the world has been mutated
(destruction, the dead, moved AI, burned villages). **The cheap intermediate that gets most of the feel
— extend the save to the hub-side world and keep field saves at the wire — must be offered to the
Summoner before the full bill is ever priced.**

### 8 · TUNNELS AS DUNGEONS (item 11) — the thaw is NAMED, not granted

`GAME_GUIDE` §6 freezes tunnel **interiors** as post-core and already names them *"the FIRST THAW once
the core is undeniable"*; tunnel **mouths** you mark and satchel are in scope today. This ADR does not
thaw anything. It records the shape so the thaw, when it comes, is built correctly:

- **A tunnel is an interior under clauses 4/4a** — no terrain, no grid, no site planning — and the
  **interior builder already exists and is ~70% of the way there**: `scripts/world/tunnel_room.gd`
  `TunnelRoom` is a wired, procedural 10×3×14m cache room shipping today. The thaw extends that one
  builder; it does not start a new one.
- **The loop is already half-built in the field-marking vocabulary:** find a hole on patrol → mark it
  (`TUNNEL` is one of the **four** player-markable nouns — CONTACT · TRAIL · TUNNEL · CAMP,
  `scripts/player/field_mark_verb.gd`; **not six** — correct that on contact) → come back kitted → go
  down. The `[F] GO DOWN THE HOLE` verb, the ladder point, the cache chamber and the satchel-the-mouth
  alternative all exist today (`player.gd` `field_interact_prompt`).

### 9 · THREE MORE STALE CLAIMS CORRECTED ON CONTACT (NO MORE DRIFT)

1. **`terrain_manager.gd:369-370`'s hydrology comment is false.** It claims a "~400-cell grid at any map
   size", but `downsample = max(1, round(size/450))` rounds to **1** at heightmap size 512, handing the
   GDScript priority-flood a full 512² = 262,144-cell grid. The comment is false for **every map from
   1280m to 2700m**, i.e. for the shipping world of record. This is the item most likely to break the
   *load* at 2km (the frame breaks on terrain, §6).
2. **ADR-028 Amendment A's `KNOWN_EXCEPTIONS` citation is stale.** The structural probe's constant was
   deliberately renamed to `EXCLUDED_BENCHES` (`tests/test_placement_paths.gd:26`). The law is unchanged;
   the pointer was.
3. **Both save defects on the ship list are CLOSED, not open.** Atomic write-and-swap is live
   (`save_manager.gd:100-131` — tmp → flush → verify → `.bak` rotate → rename) and future-version reject
   returns null (`:193-199`). `GAME_GUIDE` §8.1 item 2 still lists them as bleeding; **strike both.**

## FROZEN FILES (the scope wall's enforcement surface)

**Nothing in this ADR is authorised. These paths are FROZEN against it until the Summoner thaws them by
explicit decree.** A change to any of them justified by "zones", "the bigger map", "board the bird" or
"tunnels as dungeons" is a scope-wall breach, regardless of how small it is.

- `scripts/levels/world_config.gd` — `MAP_SIZE` and its neighbours (the 2km constant)
- `terrain/core/terrain_manager.gd`, `terrain/core/terrain_chunk.gd` — streaming, LOD, hydrology
- `scripts/missions/mission_generator.gd` — any new `plan_*_world()` function
- `scripts/vehicles/seat_system.gd` — `player_boarding` stays `false`
- `scripts/world/tunnel_room.gd` — no second interior generator, and no extension of this one
- `scripts/main/game_flow.gd` — `_teardown_world()` and the zone-transition seam

**AND THE LEAK MECHANISM THAT IS FORBIDDEN BY NAME:** a *parked-but-built* constant in the
`FieldDirector.SLEEP_POST_LAUNCH` style — code shipped behind a flag "so it is ready" — is **not
permitted for any item in this ADR.** That pattern has already proven to be exactly how post-launch work
gets built during launch scope, and the sleep loop is the precedent that proves it.

## Consequences

**Bought.** The game can grow to many places without ever writing chunk streaming — the Catacombs bug
class is dodged by construction rather than by discipline. ADR-028's protected foundation extends
cleanly from "one world" to "many places, one builder". The briefing screen cannot grow back through the
travel system, because travel is an act and not a list. And the 2km question gets a *fundable answer*
instead of a refusal: it is gated on one specific missing feature.

**Sacrificed — no free lunches.**

- **The world can never be composed** (§3). No authored ridge, no hand-built landmark. Every place is
  procedural ground plus stamped dressing, forever.
- **Loading screens between zones.** The seamless-world fantasy is explicitly given up; this is the
  STALKER trade the Summoner asked for by name, and some players read a load screen as a smaller game.
- **Boarding is slower than selecting**, every single time, deliberately. A player in a hurry will feel
  the walk to the pad as friction. That friction *is* the guard.
- **Zones multiply content debt.** Ten places want ten times the dressing, and the art budget is already
  the binding constraint.
- **2km is deferred behind a feature nobody has started** (terrain LOD), which means the bigger map is
  further away than "one constant" made it sound. That is the honest position and it is better known now.

## Evidence

- Summoner decree 2026-09-06; council record `production/war_room/2026-09-06_rpg_pivot/`, technical
  analysis in `analysis/technical_director.md` (all numbers below independently measured this session).
- `tests/test_placement_paths.gd:12-20, 30-37, 47-68, 85-98` — the structural probe as it stands.
- `terrain/core/terrain_chunk.gd` — no `visibility_range`, no LOD, no custom AABB (verified).
- `scripts/world/tree_cover_layer.gd:427-434` — 350m `visibility_range_end` on vegetation (verified).
- `production/PERF_LEDGER.md` 2026-08-14 — demo baseline 34.5 fps / GPU 24.06 ms; `assault_on_wire`
  22.6 fps avg, 5 fps min, GPU 33.2/48.5 ms; the unratified gate proposal.
- `scripts/main/game_flow.gd` — zero hits for `start_pad` / `Huey` / `heli` / `insertion`; `:407`
  `_teardown_world()` (verified).
- `scripts/autoload/save_manager.gd:8-9` — "the wheels-down checkpoint died with ADR-029's insertion
  cut; never rebuilt" (verified).
- `scripts/player/field_mark_verb.gd` — four nouns: CONTACT · TUNNEL · CAMP · TRAIL (verified).

## Related

- **ADR-013** — streaming policy, un-weakened; this ADR adds the map-size gate above it.
- **ADR-028** — the protected foundation; clause 1 is its extension, not its exception.
- **ADR-029** — the loop that §4 exists to protect.
- **ADR-017** — §4's load-mask claim corrected in §5 above.
- **ADR-007 Amendment A** — save anywhere, priced.
- **Pillars served:** 3 (Freedom — more world, no rails), 2 (Atmosphere — places worth going),
  and via the streaming that never gets written, 1 (gunplay on a stable frame).
