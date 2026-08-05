# THE DEBATE — 2026-08-05

## 1. Where the Arbiter's own briefing was WRONG (recorded first — the Pointer Law cuts both ways)

The Arbiter walked into this council carrying eleven measured claims. Four were wrong and three were
incomplete. Recorded before anything else.

| Arbiter's claim | Truth | Pointer |
|---|---|---|
| Firebase parapet = "80 HP segments" | **140 HP × 80 segments.** 80 is the COUNT | `firebase_v3_destructibles.json`; `site_planner.gd:1490, :1515` |
| "SiegeDirector reads a destroyed member as a breach" | **False.** `_measure_perimeter` reads the group for POSITIONS only, to build a per-bearing wall radius. It never calls `is_destroyed()`. Its own header says so | `siege_director.gd:559, :554-588, :63-67` |
| "Destructible buildings outside the parapet are test-scene only" | **False.** `_wire_structure_destructibles` / `_adopt_structure` put firebase bunkers (260), MG bunkers (260), sleeping bunkers (260), towers (180) and sandbag stacks (90) on the blast bus in the SHIPPED world | `site_planner.gd:1542, :1552-1558, :1561, :1595` |
| "FellableTree is placed solely at `ai_stress_arena.gd:564`" | Arena line is **:577**; and it is also placed by `support_fire_range.gd:236, :946, :958`, `probe_fire_parity.gd:71`, `test_support_fire_bench.gd:73`. Two benches, not one | as listed |
| "Every other `Destructible.new()` runs through `spawn_fort`" | Three paths, not one: `spawn_fort`, `spawn_lifted`, `_adopt_structure`. Two unlisted callers: `sapper_room.gd:204`, `probe_fire_parity.gd:74` | as listed |
| "`support_fire_range.gd` is clean — one const, `SP_OPEN`" | **16 top-level consts** | `support_fire_range.gd:16, 20, 21, 35, 45, 46, 51, 246, 284, 322, 572, 573, 663, 664, 665, 854, 970` |
| The `GameSettings.ai_vs_ai_cone_mult` leak means "same build, two behaviours" | Mechanism real, **effect zero at defaults**: export 1.0, autoload default 1.0 (`game_settings.gd:18`), no `.tscn` override, and there is no in-game arena→demo transition (`project.godot:22` boots `demo_game.tscn`). The leaks that DO fire at defaults are two others | `ai_stress_arena.gd:304, :305, :308` |
| Stale tombstone at `site_planner.gd:1479-1489` | Correct in substance; the stale part is **:1479-1484 only**. `:1486-1489` still accurately describes live code | `site_planner.gd` |

**Three times in one day the codebase beat the document. This makes it eight.**

## 2. The convergence — three architects, three doors, one conclusion

The systems-designer (from the build path), the world-architect (from the vegetation pipeline) and
the game-designer (from the fantasy) arrived independently at the same sentence:

> **The firebase can be blown apart. The world you patrol into cannot. And blowing up the jungle
> currently deletes cover and hands back nothing.**

That convergence is the strongest signal this process produces, and it reorders the whole ask.
Caleb named "destructible trees and buildings" as one item. It is two, with different costs,
different risks, and only one of them changes how a firefight plays.

## 3. Where they disagreed

**Technical-director vs devil's-advocate — is the felled-log collider a lift or a rewrite?**

- TD: net-zero physics bodies, because a felled log replaces a standing trunk 1:1 inside the same
  ADR-033 pool. The count argument is airtight.
- DA: the count is not the cost. `TreeCoverLayer` has no concept of a candidate that survives
  `_build_scatter`'s holed-position skip — and that skip is *the same mechanism* that deletes the
  standing tree. Plus a rotated capsule in a pool built for shared cylinders, plus a per-candidate
  fall direction persisted through chunk rebuilds.

**Arbiter's resolution: the DA is right about classification and the TD is right about budget.** It
is a **small rewrite of the candidate model with a known-small runtime cost.** Both halves go in the
decree; calling it a lift is how it lands half-done.

**Technical-director vs devil's-advocate — does building HP need the ADR-031 perf gate?**

- TD: no. The gate names *terrain heightmap holes* (main-thread chunk rebuilds). A `Destructible` is
  a `StaticBody3D` with no per-instance process, adopting an existing collider, sharing one rubble
  MultiMesh, throttled at 2 levels/frame. ~60–120 props, O(N) per blast, orders of magnitude under
  the 2.4 ms detectability floor.
- DA: agreed on cost, but objects that it buys no verb and has no consequence layer.

**Arbiter's resolution: TD carries the perf question, DA carries the scope question.** Structure HP
is cheap and may ship; it may NOT be sold to the Summoner as a danger item, and it is not "done"
when the hut falls over.

**Game-designer vs devil's-advocate — priority.**

- GD: if one thing ships, the fallen tree becomes cover. It is the only item that changes what a
  firefight *is*.
- DA: the thing most likely to ruin his next playtest is `MAX_DEFORMS_PER_MISSION = 40` against a
  30-minute continuous demo — he will call four fire missions, the ground will stop cratering, and
  he will conclude his own tuning regressed.

**Arbiter's resolution: both, in that order — the phantom first.** A one-line cap fix costs nothing
and protects every judgement he makes for the rest of the demo. Then the tree.

## 4. Unanimous refusals

Every architect independently refused the same four:

1. The arena's `SPOT_RANGE` / `SPOT_CONE_DOT` / `SPOT_GAIN` — a second perception authority
   (ADR-023), and a workaround for the arena's own spawn choice, not a missing system.
2. The bench's unlimited fire-support stock (all 9s) and `_cas_cooldown = 0.0` — these delete the
   fire-support economy, which is the only thing that makes a fire mission a decision (ADR-011).
3. The arena's `SIEGE_STRENGTH` survival-wave figure — a stress number, not a design number; the
   demo's 45 is already ruled and 55 arms a known softlock (2026-08-03 council).
4. Every instrument dial — `mirror_mode`, `MIRROR_HP`, `player_damage_multiplier`,
   `ai_hp_multiplier`, `rng_seed`, `force_gib`, `hot_start`, `debug_readouts`. ADR-029 Q5: labs stay
   labs.

## 5. The drift found on the way (NO-DRIFT law — corrected or logged in the same pass)

1. `site_planner.gd:1479-1484` — a pre-fix problem statement standing above its own fix. Claims the
   manifest is "READ BY NOTHING" (read 20 lines below at `:1497`), that "nothing in the shipped world
   ever called `Destructible.new()`" (the next function does, `:1513`), and that the firebase "was
   incapable of taking a mark" (parapet + bunkers + towers + stacks are all on the bus).
2. `site_planner.gd:1491-1492` and `:1536-1537` — assert SiegeDirector reads a destroyed member as a
   breach. It does not (`siege_director.gd:63-67, :554-588`). The breach IS handled — generically, by
   `destructible.gd:92-94` → `NavBaker.breach_at` — just not by SiegeDirector.
3. `ai_stress_arena.gd:1954-1955` — claims core perception exempts all allies until COMBAT.
   `enemy_base.gd:1066-1079` was narrowed to exempt only the player's own squad.
4. `DEMO_SHIP_BACKLOG.md` 2026-08-05 — "Applies to main world AND benches (group-based)" for
   `JunglePatchLayer.blast_clear`. The group is **empty in the shipped world**
   (`vegetation_manager.gd:114-123` is either/or; `WorldConfig.USE_TREE_COVER = true`). The effect is
   nonetheless achieved by a different path (`clear_area` at 12/20/60 m). Mechanism claim is false,
   outcome claim is true.
5. `site_planner.gd:140 _is_soft_cover()` — the old filename-hint heuristic, dead in the placement
   path (`:176` uses `CollisionTable.is_soft()`). Fossil candidate.
6. `bullet_system.gd:172-176` — a duck-typed `get_player_damage_mult()` hook in shipping bullet code
   whose only provider is `ai_stress_arena.gd:2031-2032`.
7. Three unreconciled sandbag HP tables: 140 / 90 (`fire_support_bench.gd:48-55`), 90
   (`site_planner.gd:1552-1558`), 110 (`support_fire_range.gd:988`).
