# ADR-029 — AMENDMENT C: The Patrol Contract (route as input, ground covered as grade)

**Status:** ACCEPTED 2026-07-25 by the Summoner (Caleb's word, morning rulings).
**Amends:** ADR-029 (The Open Patrol Simulator), §4 "No player-facing mission tracking, ever."
**Also amends:** ADR-006 (scoring economy — ground-covered joins the wire-AAR grade).
**Pillars:** 3 (Freedom — the plan is a suggestion, never a rail), 4 (the squad is the RPG).
**War room:** `production/war_room/2026-07-24_patrol_contract/synthesis.md` (4-architect council).

---

## Decision

An EVOLUTION of the existing FieldDirector loop — not a new system (it already held ~85% of the machinery).

1. **The route is INPUT to the ONE existing selector.** Before the wire the player may draw their own
   ~5-point route on the tactical map (grease-pencil intent, ADR-022). That route REPLACES push-direction as
   the input to `_pick_patrol_location` (`field_director.gd`); push-direction is the no-route fallback
   (walking is a 1-point route). ONE selector — never a second picker, never a spawner on the drawn line, no
   manager node (ADR-023). A live crisis always outranks the route.
2. **Command tasks in the field, anchored to the route.** As the player reaches each mark, command re-tasks
   the sweep onto the LIVING feature nearest the next mark (`_advance_route_tasking`, over the net — off the
   net, no word). Command names FEATURES or ORDINALS ("the village", "your 3rd mark"), never a briefing pin.
3. **Ground-covered is a silent patrol-quality GRADE, not a gate.** Distinct 25m sectors actually walked,
   accumulated on `MissionState`, banked and shown ONLY at the wire AAR (debrief). RTB is always legal.
4. **The four §4 clauses (binding, probed by `tests/test_patrol_contract`):** (1) waypoints never check off;
   (2) ground-covered never reaches the in-field HUD; (3) command names features/ordinals, never objective
   pins; (4) the route feeds only the one selector, never the scorer/tasking-authority.
5. **Deferred, gated (spec-ready, not built):** the OP-hold setpiece runs on REAL time, never compressed
   SimClock (gates its build); Level-2 forgiving squad orders (area/direction, aim-and-press, confirm via
   bark + order-line + roster) are enabled only once the AI provably obeys in a playtest.

## Consequences (the sacrifice — no free lunch)
A loud AO's crises can override every waypoint and make the drawn line cosmetic; planning-minded players
will feel the route is "just a suggestion." That is the correct side of Pillar 3 (freedom over authored plan).

## Build state
**Phase 1 spine SHIPPED (local commit `173f5eb5`, unpushed):** route-as-input + `_advance_route_tasking` +
silent ground-covered + the four §4 probes. `debrief.gd` shows "GROUND COVERED: N SECTORS" (reported, not
scored). The route pencil UI is Phase 2 (its pixel-glyph rendering rides with ADR-030 to final polish).

## Related
ADR-022 (+ Amendment A — the intel verb, the map's other player layer) · ADR-006 · ADR-029 Amendment B
(world verb legal, objective counter not) · ADR-010 (ground-covered deterministic from the walked path).
