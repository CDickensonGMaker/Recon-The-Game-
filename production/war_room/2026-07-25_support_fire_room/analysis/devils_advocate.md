# DEVIL'S ADVOCATE — The Support Fire Test Room

**Convened:** 2026-07-25 · Lens: what BREAKS. No free lunches. Every claim carries a pointer.

The request wears a cheap coat. "A test room to verify fire-support effects fire" is a half-day scene.
"...and DESTROY trees, terrain, buildings — if they don't exist, this room is where we add them" is a
multi-week destruction ENGINE. The council is being asked to bless the second under the budget of the
first. Below, concretely, where it breaks.

---

## 1. PERF — destruction is the wrong thing to spend this frame on RIGHT NOW

ADR-026's own status line is the whole argument: the frame is **already both-bound at ~19-23fps deep
night** (`ADR-026:13-17,108`), and **Part B — the activity-tiered AI that fixes the CPU half — is NOT
shipped** (`ADR-026:173,197-199`: "the FPS effort pivots to Part B... that is where the frame actually
is"). We are asked to add cost to a frame whose known fix hasn't landed.

Environmental destruction adds cost to **both** walls, and it lands at the **loudest** moment:

**The worst spike — a napalm run over jungle during a firefight.** Trace it:

- `field_director.gd:424` launches `CASAirplane.Ordnance.NAPALM`. Napalm's crater profile is
  `radius_cells: 15` (`damage_system.gd:46`). `cell_size ≈ 2.0m` (`hydrology_map.gd:81`,
  `water_system.gd:34`) → a **30m-radius / 60m-diameter** deformation disc.
- `DamageSystem.apply_damage()` calls `terrain_manager.modify_terrain()`
  (`damage_system.gd:137`), which runs **synchronously on the main thread**:
  `heightmap.modify_region()` **then** `_rebuild_chunks_in_region()` — it **rebuilds every terrain
  chunk mesh overlapping the disc** (`terrain_manager.gd:281-283`). A 60m disc spans multiple chunks;
  each is a full mesh rebuild that frame.
- It **then** calls `vegetation_manager.clear_area()` (`damage_system.gd:141-147`), which per
  overlapping chunk runs `clear_chunk_visuals()` **and** `_rematerialize()`
  (`vegetation_manager.gd:416-418`) — MultiMesh billboard rebuilds. **This is the exact code path the
  War Room caught as a live shipping bug on 2026-07-12** (one grenade → 256m of authored jungle
  reprocessed into procedural palms). We would be firing it deliberately, at 15-cell radius, mid-fight.
- It **then** builds a scar `Decal` sized `radius * 2.2 ≈ 66m` (`damage_system.gd:231-232`).

All of that is one `apply_damage` call, all synchronous, **on the single frame the napalm lands** —
and it lands **on top of**: burning alpha-cards (added overdraw on a frame ADR-026 says is fill-bound
at ~50ms GPU on foliage), the **AC-47/SpectreGunship** pouring continuous tracer/flash/report (which
are **fairness-exempt and uncapped**, `ADR-026:41-46`), and an 18v18 firefight already sitting **at
the CPU wall** (`ai/agents` measured 25-192ms, `ADR-026:190-192`). The strike is a co-peak: it spikes
the CPU (chunk rebuild + veg rematerialize + future falling-tree transients + collider spawn +
registry bookkeeping) **and** the GPU (rubble props, scar decal, burning cards, fallen-log meshes)
at the precise instant both walls are already loaded. A hitch past the 66ms Quake-3 timestep cap
(CLAUDE.md) is a stutter in the middle of the game's loudest, most fairness-critical moment.

**Verdict on 1:** destruction spends the frame at exactly the wrong time. It is a graphics-and-CPU
luxury layered onto a frame whose baseline fix (Part B) is not even in yet.

---

## 2. SCOPE — the test room is a Trojan horse for the destruction epic, ahead of the R4 gate

Strip the coat off. Verifying **effects fire** is cheap and real. Verifying they **DESTROY** requires,
per `DESTRUCTIBLE_JUNGLE_PLAN.md`, building things that **do not exist**:

- `scripts/world/destructible.gd`, `terrain/vegetation/tree_registry.gd`,
  `scripts/world/falling_tree.gd` — all **"NOT BUILT (designed only)"** (briefing:34; plan Phases 2/2b/4).
- The **explosion→world-object gap**: `CombatManager.apply_explosion_damage()` structurally cannot see
  world objects; a `damage_area()` call must be wired at **five** explosion sites (grenade,
  projectile_base AOE, claymore, cas_airplane, field_director) — plan §Phase 2, briefing:36-39.
- `data/weapons/m79.tres` `projectile_data_path=""` → the **primary player tree-feller fires hitscan
  with no AOE and no crater** (plan Phase 2 "bug found en route"). Fixing it is real projectile work.
- `collision_table.gd` (~120 entries, `collision_table.gd:9-120`) needs a **new material/hp/destroyed/
  debris schema** authored across every structure, plus **retiring the `_SOFT_NAME_HINTS` filename
  footgun** (plan §Phase 4 "FIRST, KILL THE FILENAME FOOTGUN").

That is Phases 1→4 of a **four-phase epic** — trunk colliders, bitmask fell + shader collapse, the
scripted-hinge fall + permanent log cover + nav re-carve, the building state-machine + rubble scatter.
Weeks, not a test room.

And the timing is a direct breach of the standing gate. **PLAYTEST R4 is the session entry gate;
"gated feature work stays parked" until the Summoner verifies it** (CLAUDE.md, THE SESSION ENTRY GATE).
A destruction engine is the most gated feature work imaginable — a brand-new pillar-3 verb ("build
cover by felling a tree," plan §2b) — and R4 is not discharged. Building it now is exactly the move the
gate forbids: it aims weeks of work by guesswork before the core loop is proven playable.

**Named sacrifice if we build it:** the R4 open-patrol loop stays unverified while the team pours weeks
into a benchmark's back half. The "test room" becomes the vehicle for jumping the queue.

---

## 3. FOSSIL / DIVERGENCE — building destruction forks the veg systems the project keeps re-breaking

This is the project's **recurring** bug (memory: divergent-systems blindspot — ~14 parallel live
world-build systems; world-foundation-locked: improve the one world, never re-fragment it). Destruction
threatens to add another fork:

- **`TreeCoverLayer` is a MECHANISM, not wired.** Its own header: *"do NOT wire it live without eyes on
  the new look"* and it is the thing that is **supposed to retire the merged-patch/procedural-billboard
  paths on switchover** (`tree_cover_layer.gd:9-11`, fossil law). It hasn't. It independently defines
  `COVER_TRUNK` radii **and** `felled_tree/felled_trunk/tree_stump` colliders (`:19-27`).
- **`JunglePatchLayer` (merged 12m patch MultiMesh) is what's LIVE** (`ADR-026:161`, plan §0 C1/C2).
  DESTRUCTIBLE_JUNGLE_PLAN Phases 1-2 build trunk colliders and the fell-bitmask **on the merged-patch
  layer** (patches.json `trees[]`, `COLOR.b` slots — plan C1/C2/§Phase 1/§Phase 2).

So the fell/cover verb would be built against the **live merged-patch layer**, while the **unwired
TreeCoverLayer** already claims ownership of `felled_tree` and cover-trunk radii. **Which system owns
the tree you drop?** Both. That is a second fossil-generator planted on top of a switchover that hasn't
happened — precisely the "two things an agent reads as the same thing" the fossil law exists to prevent
(ADR-023). And we would be building from a plan that **openly admits its diagnosis aged out**: its own
banner flags `update_region` no-op as **FALSE NOW**, the `stamp_firebase/stamp_outpost` callers as
**non-existent**, and a stale line number (`DESTRUCTIBLE_JUNGLE_PLAN.md:6-19`). Building destruction on
a half-wired veg switchover, from a partly-stale plan, is how the divergent-systems bug is born again.

---

## 4. DETERMINISM (ADR-010) — destruction promotes non-deterministic impacts into persistent world state

ADR-010's honest scope is explicit: **"same seed = same world/enemies/events, NOT same bullet holes"**;
per-frame draws (spread, hit FX) are non-deterministic **by design** (`ADR-010:16`,
`game_flow.gd:103-106`). Craters and scars live safely inside that carve-out **as long as they are
cosmetic**.

Destruction breaks the carve-out by making impact positions **gameplay state**, and the impacts are
non-deterministic:

- Fire-support scatter draws from the **global RNG**: arty sheaf `randf_range(...)` at
  `field_director.gd:435-436`, mortar spot+sheaf at `:587-593` — uncontrolled per-frame draws.
- Suppressive/hunter placement uses a **time-seeded** RNG:
  `rng.seed = hash(from_pos) ^ int(Time.get_ticks_msec())` (`field_director.gd:496-497`) — explicitly
  wall-clock, run-to-run different.

Under destruction, where a shell lands decides **where a tree falls, where the log-cover ends up,
whether a canopy hole becomes a landable LZ** (`mark_cleared()` rewrites the sight-cap grid; plan
Phase 2/3). The plan's headline verb — "drop a tree across open ground and cross a field you couldn't
before" (plan §2b) — is **persistent, load-bearing cover generated from non-deterministic draws.** Two
runs of the same seed yield a **different walkable/coverable/landable world**. That is no longer a
bullet hole; it is terrain the player plans around.

It gets sharper with the budget cap: `MAX_DEFORMS_PER_MISSION = 40`, and past it `apply_damage`
**skips the terrain dig but still clears veg + scars** (`damage_system.gd:135-147`). So **which 40
craters actually deform terrain depends on arrival order/timing** — non-deterministic which strikes
leave real holes. A player-blown LZ that lands as strike #41 clears foliage but **doesn't dig** — the
bird's honesty check reads a hole that terrain never got. ADR-010 needs an explicit ruling
(cosmetic-only, or seed-derived dedicated RNG for any impact that becomes cover/LZ) **before** any
fell/LZ system ships.

---

## 5. THE ONE THING that must be perf-proven before any destruction ships

**A single napalm run over dense jungle, during a live 18v18 firefight with the AC-47 firing, measured
for the WORST single-frame spike (not average) on ship config (Blender CLOSED, `scale=0.75`,
sun-shadow off), using ONLY the systems that exist today (DamageSystem deform + clear_area + scar).**

If one napalm strike hitches the frame past the 66ms timestep cap in that context — and the
synchronous `modify_terrain` + per-chunk `_rematerialize` path strongly suggests it will — then **no
destruction ships until (a) Part B lands and (b) the deform/rematerialize is made async or
frame-budgeted.** This is provable in the minimum test room with **zero** destruction code written,
because DamageSystem already digs, clears, and scars. Prove the floor before building the tower.

---

## MINIMUM-VIABLE TEST ROOM (no destruction, real value today)

A scene: **PLAYER + one RTO worker + a call menu exposing EVERY fire-support type** (bombs, napalm,
arty, mortar, spectre, CBU) **and every player explosive** (M79, LAW, M26, claymore, satchel). It
verifies the **EFFECTS fire and land correctly** — explosion FX, the DamageSystem crater/scar (already
built), correct ordnance model, the toast/telegraph, danger-close timing, ammo counts, the
`arm/commit_fire_mission` call grammar. Trees and buildings **stay intact under fire, and that is the
honest v1** — it exercises the entire *existing* fire-support roster + FieldDirector + DamageSystem,
and it **doubles as the §5 perf bench**. It also surfaces the two real, cheap, already-known bugs worth
fixing regardless: the **M79 hitscan** (`m79.tres` empty projectile path) and the **filename footgun**
(`_SOFT_NAME_HINTS`). Zero lines of `destructible.gd`, `tree_registry.gd`, or `falling_tree.gd`.

## What is sacrificed by this restraint

The satisfying part — felling trees, cratering the treeline, blowing your own LZ, collapsing a hooch —
is deferred. The player calls a napalm run and the jungle it burns **still stands**. That reads as
incomplete, and it postpones a genuine pillar-3 verb. The trade buys: an R4-gate-legal deliverable, a
frame that isn't gambled before Part B, no second veg-fork, and no ADR-010 breach — and it produces the
one measurement that decides whether the epic is even affordable. Cheap to build, and it makes the
expensive decision on evidence instead of hope.
