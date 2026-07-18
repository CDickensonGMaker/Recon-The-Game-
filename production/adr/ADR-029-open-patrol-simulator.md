# ADR-029: The Open Patrol Simulator

**Status: DRAFT — awaiting Summoner ratification (written overnight 2026-07-18 under the
2026-07-17 pivot decree; nothing here self-ratifies).**

## Decree (Summoner, 2026-07-17, near-verbatim)
"Combine what we have working in the AI stress test with the game world. Remove the whole briefing
part of the game. The game itself is an open simulator with no mission tracking that the player
needs to worry about. You form up and leave the base and your squad goes on patrols. Along the way
you find enemy camps, patrols, villages. A logic gate tracks when the player leaves a certain
distance from the firebase — a location spawns that they are pointed toward to patrol around, and
it's the player's path to decide how they get there. Foot only for the slice. Villages and camps
fairly close to the firebase or people get bored." Clarified same session: the world is ALWAYS
living (the gate is a pacing pointer selecting from the living world, never a spawner); the
mission/operations layer is condemned; north star: **"i just wanna leave the camp and go find
problems."**

## Decision
1. **One world, one build.** The firebase and its populated AO are a single deterministic build
   (`MissionGenerator.plan_patrol_world` + `build_patrol_world`) keyed to ONE operation seed
   (ADR-010). There is no hub-vs-mission world split and no offer dict.
2. **Caleb's `fsb_main.glb` IS the firebase.** Placed by its authored markers (SOCKET_A/B = wire
   gate, FACE_OUT = outward normal, GUN_POINT, FOOTPRINT ring, APPROACH lanes). All pacing bands
   measure from the GATE marker — walking distance is the contract. The procedural firebase stamp
   is deleted (ADR-023).
3. **Density bands (from the gate):** first-sign 150–300 m · villages 280–450 m · camps 400–540 m ·
   one location per quadrant · ≥1 village ≤450 m and ≥1 camp ≤500 m always. Probe-asserted
   (`tests/test_patrol_world.tscn`).
4. **No player-facing mission tracking, ever.** The pointer is diegetic only: topo-sheet grease
   circle (ADR-022 language, replaced not completed), compass, repeatable point-man bark, one gate
   toast. Floating objective markers are forbidden.
5. **The wire gate** (FieldDirector): crossing ~120 m walking distance from the gate marker fires
   once per excursion and points the patrol at a living location in the push direction (±45°).
   Re-crossing inward is the commit point: patrol AAR, consequences bank, gate re-arms.
6. **Foot only** for the slice. Helicopters are PARKED (Summoner, 2026-07-17).
7. **MissionDirector survives headless as FieldDirector** — toast bus, fire support, escalation,
   flags, squad wiring. Objective tracking dies. The briefing/offer/select/exfil-bird chain is
   deleted under ADR-023 with a save-schema migration.
8. **Living War hooks are PARKED, not deleted** (result pipeline → patrol AAR; rank clock =
   completed patrols; intel retargets to locations). Flagged UNFINISHED, never FOSSIL.

## Consequences
- ADR-008's TOC-briefing + board-the-bird conditions are superseded (amendment below).
- ADR-006's payout moment moves from the debrief to the patrol AAR at the wire (amendment below).
- ADR-021/022 stand — the patrol IS the intel loop; grease-pencil is canonized as THE pointer.
- The mission-type test fleet dies with the offer flow; the patrol world probe replaces it as the
  canonical end-to-end.
- Save schema bumps: `offers` / `accepted_offer` / `checkpoint_offer` leave `hub_snapshot`;
  CONTINUE restores the patrol world only.

## Q-defaults this ADR encodes (Summoner re-rules any of them cheaply)
Q1 rank clock = completed patrols · Q2 intel retargets to locations · Q3 TOC is scenery ·
Q5 lab scenes stay as instruments (gore_lab, gun_range, benches, editors; terrain_lab deleted).
