# ADR-006: Mission scoring economy: avoidance pays, kills do not
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends the debrief scoring spec implied by `debrief.gd` (NS21); enacts the scoring rule already ratified in RECON_ADAPTATION.md §1 and promised in DESIGN.md §2 DEBRIEF but never implemented.

## Context

The design canon has said the same thing since Phase 3: RECON_ADAPTATION.md:15 adopts the 1982 RECON
RPG XP rule — "**+25 per contact successfully avoided, −25 per contact detected**, minus every point
of St the team lost (KIA = ×2)" — as the mission debrief score, and DESIGN.md's DEBRIEF section repeats
it ("+avoided/−detected contacts, −St lost"). Stealth-as-economy is the mechanical expression of
Pillar 3 (Freedom: any route viable, stealth optional but rewarded).

The code never implemented it. `compute_score()` (scripts/ui/screens/debrief.gd:21-31) pays
`objectives×100 + kills×10 − damage_taken + 50 speed bonus − 50 emergency exfil + 75 ghost bonus`.
There is no contact tracking anywhere: MissionState counts kills and damage only, and a grep for
"avoided" across scripts/ returns zero hits (verified 2026-07-10). Because game_flow.gd:219 banks the
score 1:1 into `CampaignState.team_xp` (floored at 0), the XP economy — the squad-RPG progression
engine — literally trains loud play: eight kills out-earn any avoidance behavior, which pays nothing.
Audit #2 scored Pillar 3 at 2.9, down from 3.4, and named this drift the audit's headline wound
(synthesis.md, wound #1: "STEALTH ECONOMY VOID").

Two adjacent defects compound it. First, VILLAGE_RAID hard-requires a body count: the "CLEAR THE
VILLAGE" objective is `required: true` with `fraction: 0.8` of 6-10 defenders
(scripts/missions/mission_generator.gd:233) — a mandatory kill quota inside a game whose third pillar
is "stealth optional." Second, the debrief UI displays "THE PILOT DIDN'T MAKE IT: -100" when
`pow_lost` is true (debrief.gd:68-69), but `compute_score()` never reads `pow_lost` — the penalty is
shown to the player and silently not applied, a small instance of the audit's broader truth-drift
finding (comments and UI claiming behavior the code does not have).

## Decision

Debrief scoring adopts the ratified RECON rule. Specifically:

- **+25 per contact successfully avoided; −25 per contact detected.** This replaces `kills × 10`,
  which is deleted from `compute_score()`. Definitions: an enemy group that reaches COMBAT awareness
  of the player counts as *detected*; a group left alive and cold (never reaching COMBAT) behind a
  completed route counts as *avoided*. MissionState must track both counters.
- **Kills pay zero score.** Kills remain displayed on the AAR as information, not income.
- **Score continues to bank 1:1 into team XP** via game_flow.gd (floor at 0 unchanged).
- **Unchanged components:** objective credit (×100), −St lost (damage_taken subtraction), speed
  bonus (+50), emergency exfil (−50), ghost/ROE bonus (+75).
- **VILLAGE_RAID's 80% clear objective becomes optional/bonus** (`required: false` at
  mission_generator.gd:233, or equivalent). Destroying the cache/APC remains the required objective.
- **The POW −100 penalty is implemented in `compute_score()` or the debrief line is removed.** The
  UI may not display a scoring term the function does not apply (Truth Law, ADR-015).
- **Loud play stays viable** (Pillar 3: any route completes the mission); it stops being the optimal
  XP strategy. No mechanic may *gate* on stealth — the economy prices it, nothing forbids the gun.
- Closure requires a headless probe per the Verification Law: a scripted detected-contact run and an
  avoided-contact run producing the expected ±25 deltas.

## Consequences

**Buys:** Pillar 3's economy finally exists in code, not just in two design docs. The XP engine stops
teaching against the game's own thesis. Re-activates the payoff side of already-shipped stealth
systems (ghost bonus, silent movement, threat cooling) that currently feed a dead ledger. UI/score
truth restored on the POW line.

**Costs (named, per council law):** Loud runs earn less XP — players who enjoyed kill-farming
progression lose their best farm; squad leveling pacing shifts and may need retuning once real
avoided/detected counts come in. VILLAGE_RAID loses guaranteed-combat identity; a pure-stealth raid
is now legal, which some will read as anticlimax. New contact-classification code is a fresh bug
surface (when exactly is a group "avoided"? edge cases at exfil), and it depends on the witnessed-
contact beacon fix (o18o) being real — scoring detection while the beacon still fires on silent kills
would punish ghosts for ghosting.

**Work created:** the Stealth Restoration Bundle (synthesis build-order item 1): MissionState
contact counters + `compute_score()` rewrite + mission_generator VILLAGE_RAID change + POW penalty
resolution + headless scoring probe. Tracked with bead o18o (beacon) plus the new scoring bead the
decree orders created; `tests/test_xp_spend.gd:17` calls `compute_score()` and must be updated.

## Evidence

- RECON_ADAPTATION.md:15 — ratified +25/−25 avoidance scoring rule (verified).
- scripts/ui/screens/debrief.gd:21-31 — `compute_score()` pays kills×10 (line 23), no contact terms (verified).
- scripts/ui/screens/debrief.gd:68-69 — POW −100 displayed; absent from compute_score() (verified).
- scripts/main/game_flow.gd:219 — `CampaignState.team_xp += maxi(0, DebriefScreen.compute_score(result))` (verified).
- scripts/missions/mission_generator.gd:233 — VILLAGE_RAID kill objective `required: true, fraction: 0.8` (verified).
- Grep "avoided" in scripts/ — zero hits (verified 2026-07-10).
- production/war_room/synthesis.md — Decree, wound #1 and build-order item 1; analysis/game_designer.md §A3; analysis/systems_designer.md (scoring drift section).

## Related

- **Pillars served:** Pillar 3 (Freedom) primarily; Pillar 4 (squad-RPG XP integrity) secondarily.
- **ADR-015** (process laws): Truth Law governs the POW display/apply mismatch; Verification Law governs closure.
- Companion decision in the same bundle: the detection beacon / witnessed-contact rule (bead o18o) — this ADR's detected-contact counter is meaningless until the beacon stops firing on unwitnessed silent kills.
- Beads: o18o (beacon fix); new scoring bead per the decree; ida9 (Playtest R3, the session gate).
