# WAR ROOM BRIEFING — 2026-07-21 — VC INDIRECT FIRE + THE CLAIM LEDGER

## The matter

The enemy has no indirect fire. Every mortar and artillery path in RECONgame belongs to the
PLAYER. The VC shoot rifles, RPGs and satchels — that is all. Canon claims otherwise
(`production/GAME_GUIDE.md:184`, `:138`), which is how this survived.

Second, entangled defect: suppression is built on both sides and starved of input.
`CombatManager.apply_suppression_in_area` (`scripts/autoload/combat_manager.gd:245-256`) walks
`AgentRegistry.enemies` only — allies and the player cannot be suppressed — and its only callers
are the player's rifle (`weapon_holder.gd:444`) and the Snake Eye (`cas_airplane.gd:188`).
Mortars, artillery, Spectre, CBU and napalm apply zero.

Beads: `8xo3` (the gap), `kfoz` (the suppression defect), `fzxs` (blocked on both), `x4qr`.

## The Summoner's rulings (2026-07-21) — these are SETTLED, do not relitigate

1. **Reach: firebase AND field.** Stand-off barrage on the FSB, and the VC can walk rounds onto a
   static patrol in the open.
2. **Counter: KILL THE TUBE.** No counter-battery verb on the net. The mortar is a real
   emplacement out in the AO you go find and destroy.
3. **Audit: doc sweep first**, then fold into existing beads as one ranked wire-or-cut ledger.

Your job is HOW, and what it costs — not whether.

## Constraints binding every analysis

- **Pillars** (`production/bible/BIBLE.md:62-90`): 1 believable firefights · 2 atmosphere ·
  3 freedom (stealth is an economy, not a gate) · 4 the squad is the RPG and you are IN it ·
  5 fail forward.
- **ADR-011** fire-support ladder — the RTO leash, budgets, danger-close. Today it reads as if
  indirect fire is the player's alone.
- **ADR-006** kills pay zero; scoring pays avoidance.
- **ADR-023 THE FOSSIL LAW** — a replacement is not shipped until its predecessor is DELETED.
  There must be exactly ONE indirect-fire path when this lands, not two.
- **ADR-015** verification law — a decree item closes on a probe, never on a reading.
- **ADR-010** determinism contract.
- **ADR-029** open patrol simulator — no briefing UI, no objective counters, no floating markers.
- **Fairness Law** — nothing may appear from nothing (`field_director.gd:raise_crisis` header).
- **Godot 4.7 only**, strict GDScript typing.

## The proposed shape (attack it)

- **A1** Make `apply_suppression_in_area` faction-blind; call it from every indirect terminal;
  radii from `FirePlan` so they cannot drift from the drawn footprint.
- **A2** Extract `scripts/combat/indirect_fire.gd` (`class_name IndirectFire`) from
  `field_director.gd:590 _fire_shell` + `:567 _run_mortar_mission`, generalising the gun origin
  off the hardcoded `fsb_center`. DELETE the originals.
- **A3** `scripts/enemies/mortar_tube.gd` — a killable emplacement stamped by
  `SitePlanner.stamp_vc_camp` (`scripts/world/site_planner.gd:664`).
- **A4** Two behaviours: FSB barrage riding the existing sapper night roll
  (`SAPPER_CHANCE` tiers); field walk-on gated on observed + static + live tube in range.
- **A5** The spot round IS the warning; reuse the existing incoming-fire wedge
  (`scripts/ui/mission_hud.gd:195`). No second indicator.

## What you must do

1. **READ THE CODE, NEVER THE PLAN.** Three times in one day the codebase has beaten the document
   in this project. Verify every pointer above before you rely on it; if one is wrong, that is a
   finding and it goes at the top of your analysis.
2. Load `~/.claude/architect_knowledge/godot_standards.md`, `godot_4.7_features.md`, and the 1–3
   `~/.claude/architect_knowledge/GodotPrompter/skills/<topic>/` folders matching your domain.
3. Write your FULL analysis to
   `production/war_room/2026-07-21_vc_indirect_fire/analysis/<your_role>.md`.
4. Return **only a short verdict** (≤ 15 lines) — the Arbiter's context must survive.
5. **Name what is sacrificed.** No free lunches. A decision with no named cost is not analysed.

## Open question the Arbiter needs ruled

The ADR-015 mechanical gate `97u3` is held open by `qrg6` (PLAYTEST R4) and blocks feature EPICS.
`8xo3` and `kfoz` both appear in `bd ready` as tasks. `kfoz` is plainly a defect fix (exempt).
Is a whole new enemy weapon system a "feature epic" that should carry a gate link — or is it a
decree item (also exempt) because the Summoner directed it this session? Rule, with reasoning.
