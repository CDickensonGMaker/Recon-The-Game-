# ADR-011: Fire-support ladder: budgets, RTO leash, danger-close protocol
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** — (first written law for this system; previously it existed only in commits e4baf23/f212d37, code comments, and the 2026-07-09 decree item 1)

## Context
Fire support (CAS bombs, napalm, artillery, mortars, Spooky gunship, CBU, resupply) grew across the
long build window as the game's most powerful player verb — and its rules lived nowhere but code.
The 2026-07-09 decree ordered a four-bug fix cluster: the danger-close confirm was unreachable (the
menu closed on the first line, so the second press fell through to weapon keys), a stale pend could
pre-confirm a later call, the Y-mortar and supply-drop shortcut keys bypassed the RTO leash entirely,
and key 6 was double-bound (physical 54 fires both `cbu_strike` and `place_claymore`, project.godot).

Audit #2 (2026-07-10) adversarially re-verified that cluster and found it **genuinely fixed** — the
lead programmer's words: "this is what a closed decree item is supposed to look like." The net stays
open through soft failures and closes only on dispatch (mission_director.gd:225-257); the pend is
kind-bound with a 5s expiry (mission_director.gd:220-222, 248-249); `_radio_check()`
(mission_director.gd:324-331) gates the menu toggle, every `request_fire_support()`
(mission_director.gd:229, including the Y shortcut at :204-205), and `request_supply_drop()`
(mission_director.gd:393); the claymore is guarded by `MissionDirector.any_fire_menu_open`
(mission_director.gd:212, player.gd:620-623). Fix commit e4baf23 matches its message.

One survivor from the prior systems analysis never made the decree and is still true:
`_danger_close_to_squad()` (mission_director.gd:352-360) iterates living squadmates only — the
player's own distance to the impact point is never checked. You can drop a snake-eye on your own
head confirm-free inside DANGER_CLOSE_M (45.0, mission_director.gd:218). This ADR ratifies the
system as built and binds that amendment.

## Decision
Fire support is a squad-mediated, budgeted, confirmed resource. The following are law:

- **The radio is a man.** ALL support verbs — CAS, napalm, arty, mortars, Spooky, CBU, and resupply —
  require a LIVING RTO within `RTO_RADIO_RANGE` (10.0m, mission_director.gd:219). One leash function
  (`_radio_check()`) gates every entry point: menu open, every fire request, and both shortcut keys
  (Y-mortar, supply drop). **No bypass paths.** The e4baf23 fix stands; any new support verb MUST
  route through `_radio_check()` before doing anything else.
- **Budgets are rolled at briefing, per mission type**, injected via the mission plan's
  `fire_support` dict (mission_generator.gd:261-263): patrol `{mortar:1}` (:103), rescue
  `{napalm:1, mortar:1}` (:132), anti-AA `{mortar:1}` (:153), village `{bombs:1, napalm:1, mortar:2}`
  (:236), firebase defense 10 calls total (:248). Budgets decrement on dispatch, never refund.
- **Danger-close protocol (double-press confirm):** if the aim point is within `DANGER_CLOSE_M`
  (45.0m) of any living friendly, the first press raises a pend and a toast; dispatch requires a
  second press of the SAME kind within `DANGER_CLOSE_CONFIRM_S` (5.0s). A stale or different-kind
  pend never pre-confirms. The net stays open through soft failures (no budget, no target, net busy)
  and closes only on dispatch.
- **REQUIRED AMENDMENT (open work):** the danger-close check MUST include the PLAYER's distance to
  the impact point, not only squadmates. `_danger_close_to_squad()` (mission_director.gd:352-360)
  currently checks `squad_system.members` only. Add the player position to the check; the confirm
  protocol already handles the rest.
- **Key-6 context guard stands:** while any fire menu is open, physical key 54 is CBU; claymore
  placement is refused via `any_fire_menu_open` (mission_director.gd:212). One press must never do both.
- **FO/FAC is the RADIOMAN's skill, not the player's:** scatter lerps 1.0→0.45 across 8 levels,
  cooldown `25 − 2×fo` s (floor 10), veteran (fo≥5) mortars fire a 4th round
  (mission_director.gd:263-264, 279, 379-380); calls credit the RTO's `fo_fac` learn-by-doing
  (mission_director.gd:295-298).

## Consequences
**Buys:** the best-guarded input surface in the game (lead programmer) and the best-audited economy
(systems designer). Fire support becomes a Pillar-4 statement — the RTO is a man you protect, whose
skill you feel in the sheaf, whose death silences the sky. Danger-close double-press is "the best
interaction ritual in the game" (UX): you look at your own men and mean it. Written law now protects
the pattern from a future "simplification" pass.

**Costs (named, per council law):** the 10m leash punishes aggressive solo play — lose the RTO or
outrun him and you fight with what you carry; that friction is deliberate (Pillar 4 over convenience).
Per-mission budgets mean patrol players get one mortar mission, period — power fantasy sacrificed for
scarcity. The 5s confirm window adds latency to legitimately urgent danger-close calls; accepted, that
hesitation IS the design. The player-distance amendment will add one more confirm to self-endangering
calls — a speed bump for players who intentionally shell themselves.

**Work created:** implement the player-distance amendment in `_danger_close_to_squad()` (bead to be
filed at THE RECORD; no existing bead covers it — it survived audit #1's analysis without one, which
is how it lived this long). Per the verification law, close it only with a probe.

## Evidence
- mission_director.gd:210-331 — the full net: constants (:217-222), `request_fire_support()`
  (:225-298), `_radio_check()` (:324-331), `request_supply_drop()` gate (:393). Verified this audit.
- mission_director.gd:352-360 — `_danger_close_to_squad()` checks squad members only, never the
  player. Verified 2026-07-10; the amendment target.
- mission_director.gd:204-207 — Y-mortar / 8-supply shortcuts route through the gated requests.
- mission_generator.gd:103, 132, 153, 236, 248, 261-263 — per-mission-type budgets. Verified.
- Commit `e4baf23` ("audit fixes: the council's same-day bug cluster") — the fix; commit `f212d37`
  — the bead recording. Both verified in log.
- War Room: production/war_room/synthesis.md (strength #3: "adversarially verified really fixed"),
  analysis/systems_designer.md DRIFT-9 + ADR candidate #9, analysis/lead_programmer.md A5 + item 12,
  analysis/ux_designer.md strength #3 + record item #10.

## Related
- ADR-004 (per-weapon ADS zoom) — shares the rifle-down/handset-up commitment grammar.
- ADR-008 (walkable firebase hub) — briefing is where budgets are rolled and read (TOC flow).
- ADR-015 (mechanical process laws) — the verification law that this system's fix cluster met and
  that the amendment bead must meet.
- Pillars served: **4 (the squad is the RPG)** — the radio is a man; **1 (outstanding gunplay)** —
  support is scarce, so the rifle stays primary; **5 (fail forward)** — losing the RTO degrades,
  never fail-states.
