# ADR-022 — AMENDMENT A: The intel verb, and the two player map layers

**Status:** ACCEPTED 2026-07-25 by the Summoner (Caleb's morning rulings).
**Amends:** ADR-022 (The map is the player's memory).
**Pillars:** 2 (Atmosphere), 3 (Freedom — the map is an object with a cost), 4 (the AO you come to know).
**War room:** `production/war_room/2026-07-24_patrol_contract/field_marking_spec.md`.

---

## Decision

The map carries TWO distinct player layers, authored by two distinct inputs:
- **PLAN** = route waypoints (numbered, drawn on the map, no LOS) — the patrol contract (ADR-029 Amdt C).
- **INTEL** = field marks (this amendment): typed grease-pencil notes the player drops while exploring.

1. **One verb, world-inferred noun (the report verb).** Aim at something and press: the symbol is inferred
   from the highest-priority markable thing under the reticle within LOS — enemy → CONTACT (also called over
   the net), a trail → TRAIL, a tunnel mouth → TUNNEL, a structure glassed through binos → CAMP. The
   vocabulary is the world's, not a player menu.
2. **FOUR nouns only: CONTACT · TRAIL · TUNNEL · CAMP.** No "Danger" (danger is everywhere; CONTACT carries
   the warning) and no "Cache" — the game's caches are the TUNNEL loot chamber and the camp `weapons_cache`
   prop, both already reached via a TUNNEL or CAMP mark. A cache icon slots in only if standalone findable
   caches are ever added.
3. **Accuracy: a mark renders as a LARGE GENERAL-AREA CIRCLE, not a point.** "Somewhere in here — come back
   and check later." The circle IS the uncertainty; rough by design (supersedes the earlier point+error-
   offset framing). This is ADR-022's "allowed to be wrong" made literal.
4. **Marking has a COST:** LOS on the thing; ranged marks require binoculars raised; roughly stationary;
   never nagged.
5. **Persistence from the start (ADR-022 canonical end-state).** Marks PERSIST across patrols and build the
   player's AO knowledge over a tour. They are serializable dicts on `MissionState.field_marks`; save/restore
   is built in, not a throwaway patrol-local interim. Marks never auto-update (stale = intended fog).
6. **The four §4 clauses (same family as the route's, probed):** a mark is pure `{kind, area, placed_at}`
   with no completed/objective field; the tasking/selector never reads marks; the scorer/AAR never tallies
   marks by kind ("3 camps found" is banned); no on-screen mark counter, no floating world marker.
7. **Fossil (ADR-023):** the new verb ABSORBS and DELETES the existing binocular floating-`Label3D` marking
   at `player.gd:154-182` (also a §4 floating marker).

## Consequences (the sacrifice)
A large-circle mark can send the player to the wrong corner of the area — that IS the fog-of-war. Persistence
imports a save-schema slice (ADR-017) from day one.

## Build state
GAMEPLAY logic SHIPPED 2026-07-25 (evening session): the report verb on MIDDLE MOUSE
(Summoner ruling 7/25: T or MMB; T is CAS, so MMB)
(`scripts/player/player.gd` `_report_field_mark`), noun inference + area radius
(`scripts/player/field_mark_verb.gd`), the mark store (`scripts/missions/mission_state.gd`
`add_field_mark`), tour persistence (`scripts/autoload/campaign_state.gd` `field_marks`,
seed/bank in `scripts/missions/field_director.gd` `restore_field_marks`/`bank_field_marks`),
map rendering as the general-area circle (`scripts/ui/topo_map.gd` `_draw_overlay`), and the
§4 + fossil probes (`tests/test_field_marks.gd`). The `player.gd` binocular Label3D
auto-mark fossil is DELETED per clause 7. Await Summoner playtest (ADR-015) for feel:
MMB feel, circle size, the four toasts. The pixel-glyph RENDERING of the marks — the
period bitmap look — rides with ADR-030 (HUD buffer doctrine) to final polish; until then
marks render with placeholder chrome (blue pencil circle + kind text).

## Related
ADR-029 Amendment C (the PLAN layer) · ADR-029 Amendment B (world verb legal) · ADR-017 (persistent
province) · ADR-030 (HUD buffer — deferred; the mark glyphs render through it) · ADR-010 (determinism).
