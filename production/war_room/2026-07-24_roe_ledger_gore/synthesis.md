# War Room synthesis — 2026-07-24 — ROE ledger (W5) + head-burst gore (W6)

Arbiter: recon-overseer. Council: systems-designer, game-designer, devil's-advocate (independent, code-first).
Full analyses in `analysis/`.

## W5 — ROE / noncombatant-death ledger (Pillar 5)

**Convergence (three doors, same wall):** the plan's premise — "the ROE/stealth scoring inputs feed a
dead ledger" — is FALSE against code.
- Contact ledger LIVE end-to-end: `register_group` (`field_director.gd:43`) → `report_detected`
  (`mission_state.gd:27`) → scored ±25 (`debrief.gd:33-34`) → banked to team_xp (`field_director.gd:1070`).
- Ghost/ROE bonus LIVE (`debrief.gd:38`). "Silent movement" is a squad SKILL (`skill_catalog.gd:12`),
  never a score input; "threat cooling" is not a score term. ADR-006:67 was drift → corrected.
- The ONLY dead thing: `civilian.gd:_record_noncombatant_death` (empty, called).

**Decree — minimal, in-scope, pillar-safe (count only):**
1. `mission_state.gd`: `civilian_deaths` field + `record_civilian_death()`. DELIBERATELY off
   `_base_result`/`build_result` — devil's-advocate leak: in `flags` it would reach `compute_score`
   and `CampaignState.on_mission_end`, and a later score term under `maxi(0,…)` becomes a hidden
   fail-state (Pillar 5 breach).
2. `field_director.record_noncombatant_death()` routes to `state` (ledger owner).
3. `civilian._record_noncombatant_death` guarded `if not is_in_group("civilians"): return` — fixes a
   real latent MISCOUNT: `_transform_to_vc` drops a revealed informer from "civilians" without GONE,
   so a legit VC-informer kill would otherwise count as a noncombatant death.
4. No scoring, no `build_result`, no AAR toast, no witnessed-LOS (ADR-005 was a mis-cite — it's the
   detection beacon; witness state isn't cheaply reachable).

**Sacrificed (named):** the count is invisible today — an intentional UNFINISHED attach point, not a
fossil: documented reserved-pending-Summoner in code + the ADR-006 correction. Data now flows to the
bank point (`state.civilian_deaths`) so his surfacing decision is a one-line change.

**RESERVED FOR THE SUMMONER (surface as questions, do not decree):** whether ROE surfaces in the
open-patrol AAR and how; whether a noncombatant death ever prices into XP; whether a *witnessed* civ
death should feed ADR-005 escalation (hotter AO — pillar-native fail-forward, but a world-state change);
any hearts-and-minds / karma layer (separate system, Pillar-5 scope-guarded).

## W6 — VC/NVA head-burst gore

**Measurement beat the plan (never guess — measure the assets):** every VC/NVA rig
(`vc_guerilla.glb`, `_rpg`, `_rpd`, `_ppsh`, `_mosin`) ALREADY ships `head_frag_01`..`head_frag_07` —
the identical 7-fragment set the US grunt and civilian rigs carry (`grep -a -o head_frag_*`). The
"VC/NVA rigs have none" premise and the `enemy_base.gd:2218` comment were both drift. **No Blender
work — fabricating duplicate fragments would violate no-crude-boxes and double the meshes.**

**Decree — code only:** harden `enemy_base.gd` head-pop branch so a burst that returns false (no
donors) falls through to the one-piece pop instead of a silent no-op, and only marks HEAD removed when
something happened. Corrected the stale comment. Owner verifies in-game that a heavy VC headshot bursts
(if it does not despite the name contract, the fragments are unskinned/mispositioned — a rig fix, but
that is his in-game finding, not a code gap).
