# ADR-008: Walkable firebase hub ratified as the campaign spine — with conditions
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends the 2026-07-09 decree's SHRINK ruling ("HQ tent → menu-first version"); amends DESIGN.md §2 mission-loop framing (the loop's front half now lives inside the hub, not a screen stack)

> **POINTER CORRECTION, 2026-07-19 — ruling unchanged.** `DESIGN.md §2` (cited at `:2` and `:19`) is a
> **dead pointer**: `DESIGN.md` has no numbered sections, so the "seven elements" comparison at `:19` has
> no source to compare against. For this ADR's *current* standing, read
> `production/adr/ADR-029-amendments-008-006.md` (**DRAFT, awaiting Summoner ratification**), which
> proposes voiding conditions 1 and 2.

## Context
The 2026-07-09 decree ordered the HQ tent SHRUNK to a menu-first version. Roughly eight hours
later, commit `4573616` ("PHASE B: the firebase-hub loop - operation -> live firebase -> TOC
briefing -> bird") shipped the opposite: a fully *walkable* firebase hub — `enter_hub()`
(game_flow.gd:315+) instantiates the real `game_world.tscn` with terrain, squad, and weather so the
player can walk to the TOC, get a briefing card, and board the Huey at prompts polled by
`HubController` (hub_controller.gd:47, 53). This shipped unratified, while playtest P1s were open,
inverting a standing scope ruling. That process violation is recorded here and answered by the
mechanical gate law (ADR-015), not excused.

The council's audit found the hub itself is the *right shape* for Pillar 2 (atmosphere) and
Pillar 4 (the squad is the RPG) — better than the menu it replaced — but it shipped with the front
half of the approved core loop amputated. First, the RECON 7-element briefing is skipped: the hub
launch path `launch_accepted()` (game_flow.gd:305-312) calls `start_mission(offer)` directly;
`BriefingScreen` (constructed only in `show_briefing`, game_flow.gd:86-92) survives solely on the
legacy menu path. The hub's own briefing card is three lines against DESIGN.md §2's seven elements.

Second, the live Huey insertion is deleted from the campaign path: `if bool(offer.get("from_hub",
false)): plan.erase("start_pad")` (game_flow.gd:166-167) means hub launches spawn wheels-down at
the LZ. This also silently kills the AA-threat economy's only consumer — `InsertionRide`'s W09 AA
rolls scaled by campaign threat (insertion_ride.gd:159-176) — and forfeits the ride-as-load-mask
benefit the council named (the specific "masks world load" header comment cited in debate was not
found verbatim in code; the design rationale stands per game_designer.md §A2). Third, the hub's
front door lies: prompts read "[E]" (hub_controller.gd:47, 53) while the code listens for the
`interact` action (hub_controller.gd:48, 54), bound to F — a new player presses E and concludes
the flagship loop is broken.

Faced with revert-or-ratify, the council judged the hub's pillar value real and the sunk build
sound. Revert would trade a working atmosphere win for process purity. Ratification, conditioned
on restoring what it amputated, keeps both.

## Decision
The walkable firebase hub (operation select → live firebase → TOC → board the bird)
**RETROACTIVELY REPLACES** the decreed menu-first HQ tent as the campaign spine. Ratification is
**conditional**; the conditions are binding and testable:

- **Briefing condition:** the TOC flow MUST present the full RECON 7-element briefing — insertion,
  fire support, enemy intel (with accuracy roll), terrain/weather, objectives, special rules,
  extraction — before any campaign launch. The current skip (`launch_accepted()` never constructs
  `BriefingScreen`, game_flow.gd:305-312) is a defect, not a design. Fix point: the TOC accept
  flow opens the 7-element order before arming "BOARD THE BIRD".
- **Insertion condition:** the live Huey insertion ride returns to the campaign path.
  `plan.erase("start_pad")` (game_flow.gd:166-167) is repealed for hub launches; the AA-threat
  rolls (insertion_ride.gd:159+) must again fire on campaign missions, restoring the AA economy's
  consumer and the ride-covers-load benefit.
- **Prompt/input truth condition:** hub prompts and listened inputs must agree (see ADR-012).
  "[E]" prompts checking the F-bound `interact` action (hub_controller.gd:47-48, 53-54) violate it.
- **Process record:** shipping this unratified while playtest P1s were open was a violation of the
  gate law. It is recorded, and the gate is now mechanical (ADR-015 GATE bead), not markdown.
- **Maintenance tax accepted:** the hub is a permanent third context. Every save-touching or
  world-touching feature must respect `SaveManager.context: "menu"|"hub"|"mission"`
  (save_manager.gd:21), the hub's interaction surface, and its state-restore paths. This cost is
  named and accepted, not deferred.

## Consequences
**Buys:** a lived-in firebase that serves Pillar 2 with zero cutscene budget; the squad physically
present between missions (Pillar 4); one continuous fiction from operation select to wheels-down;
the Huey ride doubling as a diegetic loading screen once restored.

**Costs (named, per council law):** the menu-first cheap path is dead — every future flow feature
pays the walkable-space tax (prompts, save integration, restore, "does this work in hub context?"
branches, forever). Hub boot instantiates a full world for what a menu did in one frame. Ratifying
a fait accompli spends council credibility; the ADR-015 gate is the purchase price. The decree's
cheap partial that WAS ordered (offer `strength` actually read by generation) remains unbuilt —
"ENEMY: HEAVY" on the board is still a lie until that lands.

**Work created:** decree build-order item 5 (hub conditions: 7-element briefing into the TOC flow +
Huey ride restored to the campaign path); prompt/input truth folded into the player-state HUD layer
(fmc8 milestone 0, per ADR-012); hub F5-toast listener gap (no MissionHUD in hub) tracked under the
same HUD layer. All items enter the graph behind the R3 playtest gate (ida9).

## Evidence
- game_flow.gd:305-312 — `launch_accepted()` → `start_mission()` direct; no `BriefingScreen` on the hub path (verified)
- game_flow.gd:86-92 — `BriefingScreen` constructed only in legacy `show_briefing` (verified)
- game_flow.gd:166-167 — `plan.erase("start_pad")` on `from_hub`, deleting the campaign-path insertion ride (verified)
- game_flow.gd:120 — "INSERTING..." static loading screen substituting for the ride (verified)
- insertion_ride.gd:1-3, 159-176 — Huey ride with W09 AA-threat rolls; the economy's sole consumer (verified)
- hub_controller.gd:47-48, 53-54 — "[E]" prompt text vs `interact` (F) input check (verified)
- save_manager.gd:21 — three-state context machine, the maintenance tax (verified per devils_advocate.md §A4)
- Commit `4573616` — "PHASE B: the firebase-hub loop - operation -> live firebase -> TOC briefing -> bird" (verified)
- production/war_room/synthesis.md (2026-07-10 decree); analysis/game_designer.md §A1-A2; analysis/devils_advocate.md §A4; analysis/ux_designer.md Drift 1, 5
- Unverified: the "ride masks world load" *header comment* cited in debate was not located in code; the rationale is sourced from council analysis only

## Related
- **ADR-012** — prompt/input truth (condition 3 of this ratification)
- **ADR-015** — mechanical gate law; the answer to this ADR's process violation
- **ADR-007** — save-tier ladder; the hub is HARD-tier's checkpoint anchor (game_flow.gd:112-114)
- **ADR-009** — hunger parked; hub restore paths carry the dormant fields
- **Beads:** ida9 (R3 gate), fmc8 (HUD layer / prompt truth), decree item 5 (hub conditions)
- **Pillars served:** 2 (Atmosphere), 4 (The squad is the RPG); conditions guard 1 and 3 from erosion by omission
