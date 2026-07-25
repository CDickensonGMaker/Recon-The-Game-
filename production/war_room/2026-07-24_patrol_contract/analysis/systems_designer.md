# SYSTEMS-DESIGNER — The Patrol Contract (2026-07-24)

Lens: HOW the new layer bolts onto the LIVE FieldDirector / topo_map / SquadSystem
without birthing a parallel system (ADR-023) and without spawning-on-route
(ADR-029 §4, world-foundation-locked). I judged the CODE, not the plan.

**Headline finding: FieldDirector ALREADY contains ~85% of the machinery the vision
needs.** `patrol_locations` (the living-feature list), `_pick_patrol_location`
(proximity selection), `raise_crisis` (retarget-on-the-spot + push_front override),
`_visited_locations` (dedup ledger), `MissionState` (per-excursion accumulator that
already resets at the wire), and the `_order_all`/`_aim_ground_point` order path all
exist. The whole build is an EXTENSION of these, not a new subsystem. The moment
anyone proposes a `RouteManager`/`TaskingSystem`/`GroundCoveredTracker` node, a fossil
is being born.

---

## 1. ROUTE-ANCHORED TASKING — minimal change to `_pick_patrol_location:1030`

Today the selector (`field_director.gd:1030-1069`) runs three tiers:
1. crisis-first scan (`:1033-1040`, keyed on `trigger_state`, skips `_visited_locations`),
2. push-direction: `pdir = player - gate`, take nearest LIVING `patrol_locations`
   entry with `dot ≥ 0.707` (`:1042-1055`),
3. fallbacks: nearest-anywhere, then ring-wrap (`:1056-1066`).

**The route only replaces TIER 2.** Add to FieldDirector:

```gdscript
var patrol_route: Array[Vector3] = []   # ordered ~5 grease-pencil points (world XZ)
var _route_idx: int = 0
```

In tier 2, when `patrol_route` is non-empty, compute
`var wp: Vector3 = patrol_route[_route_idx]` and score candidates by
`pos.distance_to(wp)` ascending (skip `_visited_locations`) instead of the gate-dot.
It **never spawns on `wp`** — it picks the nearest ALREADY-LIVING feature in
`patrol_locations` to the waypoint (design call #1 honored: persistent world, route is
a proximity anchor). Empty route → the existing push-direction path is the fallback,
so foot-freedom and the headless probe path are untouched.

**The real structural gap is not the heuristic — it is CADENCE.**
`_pick_patrol_location` is called EXACTLY ONCE per excursion, at the wire crossing
(`_poll_wire_gate:810`). One location per walk-out. A 5-point route implies RE-TASKING
as each waypoint is reached. That retarget mechanism already exists: `raise_crisis:886`
does precisely "retarget the sweep on the spot, re-bark, append to `_visited_locations`"
(`:895-902`). So the bolt-on is:

```gdscript
# polled at the existing 0.5s _gate_poll cadence (:152), NOT per-frame
func _advance_route_tasking() -> void:
    if patrol_route.is_empty() or not patrol_out or _route_idx >= patrol_route.size():
        return
    var wp := patrol_route[_route_idx]
    if Vector2(world.player.global_position.x - wp.x,
               world.player.global_position.z - wp.z).length() < ROUTE_WAYPOINT_M:
        _route_idx += 1
        var picked := _pick_patrol_location()   # re-run, now anchored to next wp
        # re-bark using rebark_patrol() — one toast, point-man VO, grease circle moves
```

**Interaction audit — does the existing structure absorb this?**
- **`raise_crisis:886` push_front + override:** clean, and CORRECT per design call #3.
  A crisis unshifts to the front of `patrol_locations` and the crisis-first tier
  (`:1033`) outranks BOTH route and push-direction. So "command pulls you off your
  line" is already the intended precedence — the route governs only the *default*
  selection, command always wins. No conflict; the route makes push_front *more*
  meaningful, not less.
- **`_visited_locations`:** stays the single dedup ledger, unchanged. It is appended by
  crisis-pick (`:1039`), route/push-pick (`:1068`), and raise_crisis (`:897`), and
  cleared on ring-exhaustion (`:1065`). A route queue reads through it identically.
- **Verdict:** ABSORBS CLEANLY. No refactor. Two additions (`patrol_route`/`_route_idx`
  fields + `_advance_route_tasking` on the existing poll) and one branch inside
  `_pick_patrol_location` tier 2. Route storage should live in the ADR-022 PLAYER
  grease-pencil layer (topo_map draws it; FieldDirector reads it) — NOT a new store.

**Named sacrifice:** the "route freedom vs tasking coherence" tension is real — because
crisis correctly outranks the route, a loud AO can override every waypoint and the drawn
line becomes cosmetic. Guard: crises are net-gated and rate-limited; on a quiet patrol
the route drives, which is most patrols.

---

## 2. GROUND-COVERED accumulator

**Where it lives: `MissionState` (`mission_state.gd`).** It is already "mission
accumulators + the ADR-006 contact ledger," already holds `Dictionary` ledgers
(`_detected_groups`, `_known_groups`), and is already reset per-excursion at the wire
(`_bank_patrol:1088`). Adding a swept-cell set there is idiomatic and gets the
per-patrol reset for free. Do **not** put it on FieldDirector (survives across
excursions → would leak, ADR-010 static-leak class).

```gdscript
# on MissionState
var _swept_cells: Dictionary = {}        # cell-key -> true
const SWEEP_CELL_M: float = 25.0
func mark_swept(p: Vector3) -> void:
    _swept_cells[Vector2i(int(p.x / SWEEP_CELL_M), int(p.z / SWEEP_CELL_M))] = true
func swept_cell_count() -> int:
    return _swept_cells.size()
```

**Sampling the ACTUAL walked path cheaply (design calls #2/#3 — accrues where they
walk, not the drawn line):** quantize the player's position to a coarse grid and set the
cell flag on the EXISTING 0.5s `_gate_poll` cadence (`field_director.gd:152`). No new
timer, no per-frame cost, ~2 Hz. Grid-cell visitation (a `Dictionary` set) is O(1) per
sample and bounded by AO cell count. "Features checked" is a cheap superset: when a cell
is first entered, test proximity to `patrol_locations` and flag a separate
`_features_checked` count — still off the poll, still no per-frame work.

**Feed to the wire without per-frame cost:** in `_bank_patrol:1075`, immediately after
`state.build_result(true, "PATROL")`, inject:

```gdscript
result["ground_covered"] = state.swept_cell_count()
result["features_checked"] = state.features_checked()
```

Then extend `DebriefScreen.compute_score` (`debrief.gd:32`) — the ONE pure scoring
authority — with `score += GROUND_COVERED_PER_CELL * int(r.get("ground_covered", 0))`.
This matches how `shots`/`hits` are already stapled onto the result at `:1076-1077` and
how ADR-006 pays at the wire. It is debrief-only — never an on-screen progress bar
(honors ADR-029 §4 and the briefing's guard).

**Determinism (ADR-010):** SAFE. Position-sampling uses NO RNG and never feeds
generation, so it is outside the one-seed contract by construction. It is
timing-dependent per-frame data — exactly the class ADR-010 explicitly carves out
("same world/enemies/events, NOT same bullet holes," `game_flow.gd:103-106`). As long
as ground-covered never seeds or gates spawning, it cannot break determinism. The only
rule to keep: it is a GRADE, never a gate (design call #2) — RTB stays legal, unwalked
waypoints simply don't accrue.

---

## 3. OP-HOLD setpiece — hold area X for N mikes, no scripted wave

**Substrate reuse (the boundary):**
- **SimClock** (`sim_clock.gd`) owns the countdown. `schedule_event(day, end_hour,
  &"op_hold_end", {...})` fires the resolve, or simpler: store `op_hold_end_hour` and
  compare `SimClock.sim_hour` on the existing poll. `real_to_sim_ratio = 60` means
  "10 mikes" ≈ 10 real seconds of sim-hour — tune the ratio or hold in real seconds; a
  dedicated real-time countdown is cleaner and avoids coupling pacing to day-length.
- **Pressure detection = REUSE `_poll_firebase_threat:907` verbatim in shape.** That
  function already answers "are ≥N enemies within R of a watched center" (`FSB_THREAT_M`
  ring count, `:910-917`). Generalize it to a watched center = the OP point. NEW code is
  only the parameterization; the ring-poll logic is done.
- **Threat generation = REUSE `_process_escalation:87` / the hunter pool.** During a
  hold, nudge `_hunter_timer` down and bias the hunter spawn ring (`:103`) toward the OP
  center so ambient pressure RISES organically instead of a scripted assault. This is the
  same emergent pattern the sapper decree used (silent drive + reuse the hunter pattern
  for the loud element, `:1013-1025`).
- **Combat posture (crouch-to-hold / suppression) needs ZERO change** — it is emergent
  from being in contact while `OrderMode.HOLD` (`ally_base.gd:721`, `_settle`). The OP is
  just a HOLD order with a clock and a nearby-threat bias.

**Reuse vs new-code boundary:**
- REUSE: SimClock countdown, `_poll_firebase_threat` ring logic, `_process_escalation`
  hunter cadence, combat posture, `raise_crisis`/`DynamicMissionFactory.emit_location`
  (`:927-931`) to nominate a nearby LIVING camp's patrol to drift in.
- NEW (small): an `OpHold` struct on FieldDirector `{center, radius, end_time}`, the
  countdown compare, the "bias hunters toward center" tweak, and the OP-STATE HUD element
  reading `op_hold_remaining()`.
- **FORBIDDEN:** an `op_spawn_wave()` that instantiates a scripted assault. That guts
  ADR-029 and Pillar 3. Pressure must draw from the living world + the finite hunter pool.

**Named sacrifice (the honest tension):** the hunter pool only arms AFTER first detection
(`_escalation_active`, `:79-84`) and is finite (12, `:74`). A stealthy player who reaches
the OP undetected gets SILENCE — the boredom failure. Mitigation without a rail: during a
hold, allow a low-rate ambient probe via `DynamicMissionFactory.emit_location` nominating
the nearest living camp — reuses the existing crisis channel, spawns nothing new. Accept
that a clean patrol can hold 10 quiet mikes; that is freedom, and it is fine.

---

## 4. LEVEL-2 SQUAD ORDERS — 2–3 area/direction orders

**What exists:** `SquadSystem._unhandled_input` (`squad_system.gd:147-160`) already binds
FOLLOW / HOLD / MOVE_TO (`squad_follow`/`squad_hold`/`squad_move`) + weapons-free toggle,
each routed through `_order_all` (`:173`) or `_set_weapons_free` (`:163`). `squad_move`
already IS aim-and-press: `_aim_ground_point()` (`:181`) raymarches the crosshair to the
ground and issues `MOVE_TO`. `AllyBase.OrderMode` is `{FOLLOW, HOLD, MOVE_TO}`
(`ally_base.gd:155`), executed at `:678-727`.

**The bolt-on:** the vision's three forgiving orders map almost 1:1 to what exists:
- **MOVE UP** = `squad_move` (aim a point, `MOVE_TO`) — DONE.
- **HOLD** = `squad_hold` (`HOLD`) — DONE.
- **EYES-ON / SUPPRESS A DIRECTION** = the ONE genuinely new order. It must BIAS, not
  command (Pillar 4 — the men hold their own intent). Implement as a lightweight facing/
  target-bias field on AllyBase (e.g. `suppress_dir: Vector3`) that nudges target
  selection toward that bearing, set from `_aim_ground_point()` + weapons-free. It is an
  area/direction hint over the AI's existing intent, so the AI ALWAYS looks like it
  obeyed (the briefing's core fear addressed by design, not by reliability).

**Confirmation trifecta ALREADY EXISTS** in `_order_all`/`_set_weapons_free`:
- **bark** → `VOManager.play_squad(...)` (`:169`),
- **order-line** → `director.toast.emit(toast_text)` (`:177`) — this is the compass
  order-line surface,
- **roster change** → `squad_changed.emit()` (`:170`, `:178`).
The new direction order just calls the same three. No new feedback plumbing.

**Fossil risk — does this duplicate the fire-menu input path?** There are TWO distinct
aim-and-press implementations today, and they MUST stay distinct:
- `FieldDirector._cas_ground_target()` (`field_director.gd:688`, 5000 m raymarch,
  RTO-net-gated, LMB-commit) — the fire-mission verb.
- `SquadSystem._aim_ground_point()` (`squad_system.gd:181`, 40-step, direct keypress,
  NO RTO gate) — the squad-order verb.
They SHARE the "report verb" grammar CONCEPTUALLY but are mechanically separate for a
real reason: fire missions ride the RTO leash (`_radio_check`, `field_director.gd:512`);
squad orders do not. **Merging them into one radio menu would break the RTO leash and IS
the fossil trap.** Correct move: EXTEND `SquadSystem._unhandled_input` with 1–2 more
actions reusing `_aim_ground_point` + `_order_all`. That is an extension of the existing
order path, not a duplication of the fire path. Keep the two aim primitives separate; do
NOT let the new order add a THIRD.

---

## 5. Biggest architectural risk / where a parallel system is born

**Risk A (the big one) — a new node.** Every capability the vision asks for already lives
inside FieldDirector: proximity selection (`_pick_patrol_location`), retarget-on-the-spot
(`raise_crisis`), per-excursion accumulator (`MissionState`), dedup ledger
(`_visited_locations`), feedback (`rebark_patrol` + topo grease circle). A
`RouteManager` / `TaskingSystem` / `GroundCoveredTracker` node would DUPLICATE all of it
and read as load-bearing — the exact ADR-023 fossil failure mode. **Rule: the entire
build is fields + methods added to FieldDirector, MissionState, SquadSystem, and topo_map.
No new manager node.**

**Risk B — ADR-029 §4 resurrection.** A drawn route + `_route_idx` + ground-covered can
quietly re-grow the condemned mission-tracking / briefing loop. Guard (from the briefing,
enforce it): waypoints NEVER check off (the grease circle at `topo_map.gd:138-144` already
"never checks off, never updates" by design — the route must inherit that discipline);
ground-covered is debrief-only, never an on-screen bar; `_route_idx` is internal pacing
state, never surfaced.

**Risk C — a third aim-and-press path.** Two exist and are correctly separate. A new
direction-order or OP-designation UI that adds a third crosshair-to-ground implementation
is a mechanical fossil. Reuse `_aim_ground_point` for squad orders; reuse
`_cas_ground_target` for anything net-gated.

**Risk D — ground-covered on the wrong owner.** If it lands on FieldDirector instead of
MissionState it becomes a cross-excursion static leak (ADR-010). It MUST live on
MissionState, which already resets at the wire.

---

## Cleanest bolt-on path (summary)
1. `patrol_route`/`_route_idx` fields on FieldDirector; route replaces ONLY push-direction
   tier 2 of `_pick_patrol_location`; `_advance_route_tasking` (a stripped `raise_crisis`)
   re-tasks per waypoint on the existing 0.5s poll. Route stored in the ADR-022 player
   grease-pencil layer.
2. `_swept_cells` on MissionState, sampled on the 0.5s poll, banked into the result at
   `_bank_patrol:1075`, scored in `compute_score:32`. No RNG, ADR-010-clean, debrief-only.
3. OP-HOLD = SimClock countdown + generalized `_poll_firebase_threat` ring + hunter-cadence
   bias + `OrderMode.HOLD`; NO wave spawner.
4. Level-2 orders = extend `SquadSystem._unhandled_input` (reuse `_aim_ground_point` +
   `_order_all`); one new BIAS field for the direction order; confirm trifecta already
   fires. Keep the two aim-and-press paths separate.
5. No new manager node. Ever.
