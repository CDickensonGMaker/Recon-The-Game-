# ADR-025 — LOD-tier world simulation (awake/asleep × node/data)

**Status:** DRAFT pending Summoner ratification
**Filed:** 2026-07-16 by recon-overseer (wave 2 of the eager-growing-turtle plan)
**GATE:** design-only ADR + a next-session implementation bead; no build this turn. Implementation is
GATE-aware and convenes a War Room before code (it touches enemy AI + the Ambience Law).

## Context

The Living-World design doc wants a 4-tier level-of-detail simulation so the world can be bigger than the
player's immediate view without paying 60 Hz physics/anim for every off-screen entity. Two facts constrain
how that lands here:

1. **ADR-013: maps are ≤2km and never stream.** There is no "far map to page in" — the whole AO is
   already resident. So LOD here is not terrain streaming; it is *entity simulation cost*, and the small
   map is what makes aggressive sleeping safe (a unit that sleeps at 500m is far past the 45–140m sight
   cap, so there is no perceptible pop-in).
2. **Three overlapping LOD notions already exist, and they are a Fossil-Law hazard (ADR-023).** Today:
   - enemy `_update_think_lod` (a think-rate distance LOD, live) — `scripts/enemies/enemy_base.gd`
   - a separate, fully-wired civilian `lod_tier` — `scripts/world/civilian.gd`
   - the zero-caller `set_lod_live`/`set_lod_abstract` stubs, and the fossil `MAX_THINK_TIME`
     (baselined at `tests/fossil_baseline.json:28`)
   - a **fully-built but entirely unwired off-AO region system** in `scripts/autoload/world_sim.gd`:
     `update_player`, `materialize_near`, `dematerialize_far` all have **zero callers** (verified by grep,
     wave 2). WorldSim is the intended T3 data tier — built ahead of its wiring.
   - a **seeded abstract clock that never ticks:** `SimClock.advance()` (`scripts/autoload/sim_clock.gd:43`)
     has **zero callers**, though eight systems already subscribe to its signals. The clock everyone
     listens to is never wound.

   Three names for one idea is exactly the lie ADR-023 forbids: an agent cannot tell which LOD authority
   is load-bearing. Unifying them is prerequisite, not cleanup-later.

## Decision

Model LOD as **two orthogonal axes** — *awake/asleep* (is the unit simulating?) and *node/data* (does a
scene node exist?) — collapsed into a single `set_tier(t)` authority. Extend **`WorldSim`** as the
scheduler (NOT a new autoload — a parallel MissionScope lifecycle is its own fossil risk).

| Tier | Band | State | Mechanism |
|------|------|-------|-----------|
| T0 | 0–100m | live node, full physics/anim, think 0.15s | `set_tier` + think interval |
| T1 | 100–500m | live node, physics on, think ~0.45s, reduced anim | `set_tier` |
| T2 | 500m–AO edge | node **asleep** (physics off, invisible), still allocated | `set_tier` → statistical |
| T3 | beyond AO | **no node** — pure `WorldSim` data (route/dest/ETA) | `materialize_near`/`dematerialize_far` |

**Phased so each phase is independently testable (ADR-015):**

- **Phase 0 — Fossil-Law unification FIRST.** Collapse `_update_think_lod`, civilian `lod_tier`, and the
  `set_lod_live/abstract` stubs into ONE `set_tier(t)` on `EnemyBase` + `Civilian`; **delete** the other
  three notions and `MAX_THINK_TIME` in the same change (discharges the stubs in place). Gate: `test_fossils`
  green afterward.
- **Phase 1 — T0/T1/T2 node culling** (first visible win): `WorldSim._tick_node_lod`, round-robin over
  units, time-sliced to a ~1ms budget (reuse the `terrain_manager` `REBUILD_BUDGET_MS` template),
  hysteresis + min-dwell to prevent boundary thrash (learn from the existing cover-thrash fix). Wires the
  `set_lod_live/abstract` callers.
- **Phase 2 — T3 ↔ node materialize loop:** wire `WorldSim.update_player` + budgeted `materialize_near`/
  `dematerialize_far`. `_capture_state`/`_apply_state` must preserve position, hp, **squad_id + membership**,
  morale, objective/ETA, patrol index — a demoted→re-promoted unit must not reset. Convoys/aircraft register
  with WorldSim when spawned off-AO (their lifecycle signals `Convoy.waypoint_reached`/`route_finished` feed
  this).
- **Phase 3 — T2 statistical resolution:** seeded and **SimClock-driven** — wiring `SimClock.advance()` into
  the WorldSim tick fixes the current real-`delta` determinism defect and winds the clock eight systems
  already wait on. Sorted-id order; off-screen collisions resolve by force ratio. **Ambience Law:**
  resolution never touches the player or player-assets directly — the instant an outcome could cost the
  player, it has already become an *offer* surfaced through `DynamicMissionFactory`, never a silent loss.

## Consequences

**Buys:** the world can carry many more off-AO entities (convoys, patrols, ambient war) at bookkeeping cost;
one honest LOD authority replaces three ambiguous ones (ADR-023 discharged, not deferred); the seeded
SimClock finally ticks, making off-screen sim deterministic per ADR-010 (one seed per operation).

**Costs (named — no free lunches):**
- **A demote/promote round-trip is a lossy save/load every time a unit crosses 500m.** Any state
  `_capture_state` forgets silently resets on return — this is the highest-risk seam and needs a bit-exact
  round-trip probe before it can be trusted.
- **Statistical resolution is coarser than lived combat.** An off-screen fight resolved by force ratio will
  sometimes disagree with what the player would have seen had he been there. Accepted: the Ambience Law
  turns any player-relevant outcome into an offer, so the coarseness never *costs* the player, only the
  fiction's fidelity.
- **Phase 0 deletes working code** (three LOD paths that each function today). The Fossil Law demands it,
  but it is real churn on live enemy/civilian AI and must ship behind the perf-truth pass (bead 365s) so a
  regression is measurable.
- **Perf risk cuts both ways:** the scheduler itself costs frame time; the ~1ms budget + round-robin is the
  guard, but native is already ~27 FPS (PERF_LEDGER, 2026-07-16) — the LOD tick must *save* more than it
  spends or it is a net loss.

## Evidence
- `scripts/autoload/world_sim.gd` — T3 region system: `update_player` (:70), `materialize_near` (:86),
  `dematerialize_far` (:99), `_advance_abstract_cells` (:111); all three public LOD fns **zero-caller** (grep,
  wave 2). Header (:1–11) already describes the live/abstract cell design.
- `scripts/autoload/sim_clock.gd` — `advance()` (:43) **zero-caller**; signals `hour_advanced`/`day_advanced`/
  `time_period_changed`/`sim_event` (:11–14) consumed by 8 systems (air_traffic, ambient_war,
  civilian_schedules, camp_director, convoy_spawner, mission_generator, civilian, weather_director).
- `scripts/vehicles/convoy.gd:8-10` — `waypoint_reached`/`route_finished` zero-caller; `ambushed` is LIVE
  (3 callers: `dynamic_mission_factory.gd`, `mission_generator.gd`).
- `tests/fossil_baseline.json:28` — `MAX_THINK_TIME` grandfathered; Phase 0 deletes it.
- `production/PERF_LEDGER.md` (2026-07-16) — native ~27 FPS; the perf floor the LOD tick must beat.

## Fossil triage of record (the 18 wave-1 RED symbols)
Direct grep, wave 2. Do NOT regenerate `fossil_baseline.json` (ADR-023 forbidden move). Resolution vehicle:
- **LOD-destined — wired by the phases above, do not cut:** `WorldSim.update_player/materialize_near/`
  `dematerialize_far` (Phase 2) · `SimClock.advance` + its four signals (Phase 3 driver) ·
  `Convoy.waypoint_reached`/`route_finished` (Phase 2 convoy registration, or cut if WorldSim needs neither).
- **NOT LOD — belong to other threads, need their own cut/wire decision:** `AmbushPlanner` dead consts →
  the ADR-021/022 ambush intel loop (LW-10); `PaddyStamper` dead consts → the village/paddy generation
  thread. Both classes ARE instantiated by `mission_generator.gd` and use most of their consts internally;
  the flagged ones are tuning declared ahead of use.
- **False alarm — actually live:** `Convoy.ambushed` (3 callers) is NOT a fossil.

## Related
- **Pillars served:** 2 (atmosphere — a living world beyond the tree line); 3 (freedom — off-AO events
  become offers, never rails); 4 (the squad persists across the LOD boundary).
- **ADRs:** ADR-013 (≤2km never-stream — the constraint that makes sleeping safe) · ADR-010 (one seed per
  operation — SimClock determinism) · ADR-023 (Fossil Law — Phase 0 unification) · ADR-015 (verification —
  each phase ships with a probe) · the Ambience Law (Phase 3 safety).
- **Beads:** the LOD-sim implementation bead (this session) carries the phase breakdown as its work plan.
- **Critical files:** `scripts/autoload/world_sim.gd`, `scripts/autoload/sim_clock.gd`,
  `scripts/enemies/enemy_base.gd`, `scripts/world/civilian.gd`,
  `scripts/missions/dynamic_mission_factory.gd`, `scripts/missions/mission_generator.gd`.
