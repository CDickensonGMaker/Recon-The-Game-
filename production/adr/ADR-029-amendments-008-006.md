# DRAFT amendments riding ADR-029 — awaiting Summoner ratification

## Amendment to ADR-008 (the firebase hub)
SUPERSEDED by ADR-029: condition 1 (the TOC briefs you) and condition 2 (the bird flies — boarding
launches the mission) are void; the briefing, offer board, and insertion ride are deleted under
ADR-023. SURVIVES: the firebase as the player's home and persistence anchor (now Caleb's
`fsb_main.glb`), the armorer's bench economy (ADR-018), the autosave on entering the world. The
legacy select→briefing menu wire ADR-008 convicted is deleted with this amendment.

## Amendment to ADR-029 §3 (first-sign band + the wire keep-out) — council 2026-07-18
The four first-sign sectors fan across the gate's OUTWARD half-plane (out_angle ±90°, sectors at
±22.5°/±67.5°), not the world compass rose — the inward "quadrant" is the player's own base, and
at 150–300m from the gate it is physically inside the wire. The 150–300m walking-distance promise
is unchanged where the player actually walks. Binding law shipped with it (probe-asserted in
`test_patrol_world` + `tools/diag_fsb_seat`): **no build-time system may place terrain damage,
sites, patrol anchors, or spawns inside the firebase rect** — craters keep out by their own blast
radius (derived from the LARGE profile, never a bare constant), sites by FSB_SITE_CLEARANCE. The
keep-out is default-on inside `MissionGenerator._passable_near`; opting out is not a parameter
callers can reach for. Root cause record: production/war_room/2026-07-18_fsb_root_cause/.

## Amendment to ADR-006 (the scoring economy)
The ±25 contact grammar, ghost bonus, and team-XP banking are UNCHANGED. The PAYOUT MOMENT moves:
debrief-after-exfil → **patrol AAR at the wire** (re-crossing inward commits the excursion's
ledger). Death pays the same AAR with its consequences (fail forward: wake at the firebase, world
persisted, nothing reloaded). Emergency-exfil penalties are void while helicopters are parked;
the abandoned-patrol case is "walked back in" and simply banks whatever the ledger holds.
