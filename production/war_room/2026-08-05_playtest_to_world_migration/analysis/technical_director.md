# TECHNICAL-DIRECTOR — the perf question, answered honestly

## The rule I am bound by

ADR-031's gate: *"Terrain real-holes and building destruction ship only after the worst single-frame
spike is measured."* ADR-026: the frame is **CPU-bound**. PERF_LEDGER's binding line from 2026-07-26:
the detectability floor is **~3 FPS (~2.4 ms)** and **no jungle sightline has ever been measured, at
all** — every FPS row in that file is a stationary camera inside a cleared firebase.

So on two of the three things Caleb asked about, my honest answer is **budget unknown, measure
first**, and I name the probe. On the third I can price it from structure, and I will.

---

## 1. HP on every world structure — PRICED, and it is cheap

I can answer this one without a bench because the cost is structural, not empirical.

A `Destructible` is a `StaticBody3D` with **no `_process` and no `_physics_process`**
(`destructible.gd`; the drain is a single static call from `DamageSystem._process` at
`terrain/systems/damage_system.gd:199`). Rubble is **one shared MultiMesh across all
destructibles** — one draw call for the whole world's rubble (`destructible.gd:12-16`).

`_adopt_structure` (`site_planner.gd:1595`) **takes the collider the GLB already has** and reparents
its `CollisionShape3D` onto the Destructible. It adds **zero new colliders and zero new meshes**.

The only per-frame-ish cost is the blast bus: `combat_manager.gd:181-188` walks
`AgentRegistry.props` on every explosion doing a `distance_to` and a radius test. That is **O(N) per
blast, not per frame**. A generous AO census — 4 villages × ~12 structures, a VC camp, a temple and
its statues — is **~60–120 props**. One arty barrage of 12 rounds therefore costs on the order of
**1,400 float distance checks**, spread across 12 separate frames. That is noise. It is under the
2.4 ms detectability floor by two orders of magnitude and I will not pretend otherwise.

**Structure leveling is already throttled** — `WorldConfig.STRUCTURE_LEVELS_PER_FRAME = 2`
(`world_config.gd:47`), drained by `Destructible.drain()`. Napalm over a village pops two huts a
frame, not fourteen.

**VERDICT: SHIP IT. The ADR-031 gate is about terrain heightmap holes (main-thread chunk rebuilds),
not about state-swap structures. Structures were gated by association, and the association is
wrong.** The one genuine spike is `NavBaker.breach_at` (`nav_baker.gd:193`) rebaking a nav region —
but it is already debounced (`REBAKE_DEBOUNCE_S`) and one satchel that kills five huts names one
region once.

**What is sacrificed:** permanence. ADR-031 §4 makes destruction permanent inside the firefight
radius, and permanence is a rising per-patrol memory tax — every levelled hut is a hidden mesh, a
disabled collider, and 4 more rubble transforms in the shared array forever. Over a 30-minute demo
that is trivially bounded. Over a long open patrol it is unbounded and there is **no far-field
recycler in code**. Naming it, not solving it here.

---

## 2. Real colliders on felled jungle trees — CHEAPER THAN ANYONE THINKS, and here is why

The instinct is "an open 512 m map, thousands of trees, colliders will kill us." That instinct is
already obsolete: **ADR-033 deleted resident trunk bodies entirely.**

- Chunks store *candidates*, not bodies (`tree_cover_layer.gd:136-150`).
- A **pool of 1,280 `StaticBody3D`** serves a **70 m ring** around the player (`:37, :40`).
- Measured worst 70 m demand: **453 natural, 919 with mission density boosts** — the pool runs
  ~40 % headroom.
- Total physics bodies at a dense centre: **478**, down from 3,715 resident.

And here is the decisive structural fact: **a felled tree REPLACES a standing tree 1:1.** The blast
already removes the standing trunk — `vegetation_manager.clear_area` records the hole (`:423`) and
the chunk rebuild skips holed positions (`:546-548`), so the trunk candidate and its pooled body
vanish. Swapping in a lying-log candidate at the same spot is **net zero new physics bodies.**

The costs are real but small and specific:
1. The pool shares one `CylinderShape3D` per distinct radius (`_shape_for, :374`). A lying log wants
   a **capsule laid along the fall direction** — a second shape family and a per-log rotation, so
   `_place_body` (`:360`) grows an orientation argument. Small refactor, not a rewrite.
2. `FALLEN_MAX = 24` FIFO-frees old logs (`vegetation_manager.gd:482-485`). If a log is cover, a log
   vanishing is cover vanishing under a man's rifle. **24 is a decoration budget, not a cover
   budget**, and it collides with ADR-031 §4 (permanence sacred in the firefight radius).
3. Navmesh: nothing rebakes when a tree falls (`FellableTree` never calls the baker; the arena/range
   add `nav_source` at the call site and nothing re-bakes). A log across a trail would be walked
   through by AI. `Destructible` solved this with `NavBaker.breach_at` — a fallen log needs the
   inverse (an *obstruction*, not a breach), which nav_baker does not currently offer.

**VERDICT: budget known and small for the bodies; UNKNOWN for the nav rebake churn under a
barrage.** Probe named below.

---

## 3. What is genuinely unmeasured, and the probes that would close it

**PROBE A — THE WALK (zero code, ~4 min).** Boot the demo, walk out the wire into the jungle;
`[PERF] FPS=` already prints every 2 s (`game_world.gd:481`). This is the measurement the ledger
says has *never been taken* and RULE #1 is about walking. It must precede every other number here.

**PROBE B — THE BARRAGE SPIKE (the ADR-031 gate, ~5 min).** Stand in the village, call arty
(8–12 rounds, each one a crater + a veg clear + up to 5 fells + N structure levels), watch the
single-frame spike. Same harness, ship config, Intel-UHD floor. This is the number ADR-031 has been
waiting for since 2026-07-25.

**PROBE C — THE LOG RING.** Extend `tests/test_trunk_ring.gd` (which already holds the line at
<5,000 bodies) with a case that fells 40 trees inside the ring and asserts **net-zero body growth**.
Cheap, headless, and it converts my structural argument into a guarded fact.

---

## 4. THE DEMO-SPECIFIC LANDMINE nobody has named

`DamageSystem.MAX_DEFORMS_PER_MISSION = 40` (`damage_system.gd:81`), and **every ground-burst arty
round takes one** (`field_director.gd:842-844`). An arty mission is 8–12 rounds
(`fire_plan.gd ARTY_ROUNDS_MIN/MAX`). **Three to five fire missions exhaust the entire per-mission
crater budget.** `clear_all_damage()` resets it only at mission teardown (`mission_scope.gd:39-40`).

The demo is **30 minutes, one continuous patrol, with a scripted napalm strike, siege air beats and
the night assault**. Late in his 30-minute run, the ground will silently stop cratering, and the
scars and veg-clears will continue — so it will read as *"arty got weaker"* rather than as a cap. It
is exactly the class of silent degradation that will make him distrust tuning he already got right.

This is not a migration. It is a **number that was sized for a mission and is now being asked to
cover a day**, and it will bite during the demo.

---

## 5. Two shared-state leaks out of the arena that are live bugs

Not migrations — the opposite: **playtest values leaking into the game.**

- `ai_stress_arena.gd:304` sets `EnemySquad.tiering_enabled = false` — a **static var**
  (`enemy_squad.gd:46`) — and `_exit_tree` (`:2072-2076`) never restores it. For the rest of that
  process, **ADR-026 Part B activity tiering is off.** This is the single largest CPU lever in the
  project being silently disabled by a test scene.
- `ai_stress_arena.gd:305` sets `GibSystem.gib_lifetime_s = 25.0` against a game default of 12.0
  (`gib_system.gd:13`) — also static, also never restored. Corpses linger twice as long.
- `ai_stress_arena.gd:308` writes `GameSettings.ai_vs_ai_cone_mult`. **Zero effect at defaults**
  (export 1.0, autoload default 1.0 at `game_settings.gd:18`, no `.tscn` override) and there is no
  in-game arena→demo transition — `project.godot:22` boots `demo_game.tscn`. Latent, not live. I
  record it as a hygiene item, not an alarm; the briefing overstated it and I am correcting that.

`demo_game.gd:117` already models the discipline: it clears `GameFlow.demo_mode = false` with the
comment *"never leak demo state into a normal boot."* The arena should do the same for its three.

---

## 6. The arena hook that lives inside shipped combat code

`scripts/combat/bullet_system.gd:172-176` reaches for `get_tree().current_scene` and calls
`get_player_damage_mult()` **if the method exists**. The only provider is
`ai_stress_arena.gd:2031-2032`. A duck-typed test hook, in the bullet path, in shipping code —
ADR-023's fossil law names this exact shape. It costs a `has_method` per bullet and it is a lie in
the map.
