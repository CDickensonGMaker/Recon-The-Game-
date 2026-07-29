# WAR ROOM — THE SIEGE (firebase night assault, v2)

**Convened** 2026-07-28 · **Summoner's decree, verbatim:**

> The night raid can happen any night. It can happen up to three nights in a row. It will be a d50
> roll of enemies. With 2d6 of them being sappers. It should feel like a real fight for death or
> life. A Siege. The enemy will mortar the position with ranging rounds as the attack kinda starts
> and then get more accurate over time. How does the player stop the attack? I would say holding off
> long enough that over 40 to 50 percent of the attack is killed by them. But that also implies that
> the attack is focused on one direction overall so there isn't lost enemy NPCs the player cannot
> find.

## THIS IS A RULING, NOT A PROPOSAL

Every numbered item below is DECIDED. No architect may re-litigate whether the siege should exist,
whether 50 is too many, or whether the player should instead be told to leave. Name the cost of
delivering it — do not propose delivering something smaller.

1. **Any night.** The once-per-operation latch is dead.
2. **Up to 3 consecutive nights.** Night 4 in a row cannot fire.
3. **Attacker count = d50** (1–50), rolled per assault.
4. **Sappers = 2d6** (2–12) of that count.
5. **Enemy mortars walk on.** Ranging rounds when the attack opens, tightening over time.
6. **Break condition = the player killing 40–50% of the assault.** Survivors withdraw.
7. **One overall axis of attack** — so no survivor is a needle in 500 m of jungle.
8. **It must feel like death-or-life.** A siege, not a raid.

## THE CODE OF RECORD (read it, never the plan)

- `scripts/missions/field_director.gd:766-1146` — the whole current attack: `SAPPER_*` consts,
  `_maybe_launch_sappers:1099`, `launch_sapper_assault:1115`, `_poll_firebase_threat:1026`,
  `_garrison_stand_to:1066`, `on_firebase_breach:1085`.
- `scripts/enemies/sapper_charge.gd` — the satchel behaviour (250/70/14 m, `spare_garrison=false`).
- `scripts/allies/garrison_defender.gd` — Civilian → AllyBase 1:1 promotion, MG emplacement manning.
- `scripts/missions/field_director.gd:586-730` — the FRIENDLY fire-mission path (`_run_mortar_mission`,
  `_fire_shell`, `_mortar_impact`) and `scripts/gameplay/fire_plan.gd`. **There is no enemy indirect
  fire system in this repo.** Whether the enemy mortar reuses this path or gets its own is a finding.
- `scripts/enemies/enemy_base.gd:1207-1221` — per-man RETREAT scoring. **There is no formation-level
  morale/break.** `numbers_mult`, `char_self_preservation`, `d_retreats_when_hurt`.
- `scripts/enemies/camp_director.gd`, `scripts/enemies/enemy_squad.gd` — existing group brains.
- `production/PERF_LEDGER.md`, `production/adr/ADR-025-lod-tier-simulation.md`,
  `ADR-026-ps2-graphics-budget.md` — the frame budget you are about to spend.
- `production/adr/ADR-031-destruction-doctrine.md` — mortars landing in a built firebase.
- `tests/test_firebase_defense.gd`, `tests/test_sapper_assault.gd` — what currently guards this.

## KNOWN DEFECTS IN THE CURRENT SYSTEM (measured 2026-07-28)

- `_poll_firebase_threat:1027` returns early when `not patrol_out` — **the crisis and the radio call
  never fire while the player is sitting inside his own wire.** The siege happens TO him at home;
  this gate is fatal to the decree.
- `_sapper_launched` never resets → one assault per operation, ever.
- The 4-man `firebase_assault` element gets `AlertTier.ALERT` + `last_known_target_pos` and **no
  objective**. Nobody has verified these men actually close on the wire rather than stall at 300 m.
- `_garrison_stood_to` is a once-per-op latch; three nights of siege needs the garrison to stand to,
  stand down, and stand to again — and to have taken casualties in between.

## THE LAWS THAT BIND THIS COUNCIL

- **FOSSIL LAW (ADR-023):** the v2 siege REPLACES `SAPPER_*` / `_sapper_launched` /
  `launch_sapper_assault`. The old constants and the old latch are DELETED in the same change.
  Do not propose a parallel siege system beside the raid.
- **POINTER LAW:** every assertion about code state cites `file:line` or names the probe.
- **DIVERGENT-SYSTEMS BLINDSPOT:** this project already carries ~14 parallel live world-build paths.
  A second enemy-spawn authority is the failure mode we are most prone to. Say plainly which
  existing authority owns the siege.
- **COMMENT DISCIPLINE:** no tombstones, no changelogs in headers.
- **PILLARS:** believable firefights · atmosphere · freedom · the squad is the RPG and you are IN it
  (you do not position individual men) · fail forward.

## THE QUESTIONS EACH ARCHITECT MUST ANSWER

1. What is the *shape* of a d50/2d6 siege in seconds — opening, ranging, assault, breach, break?
2. Where does the 40–50% break threshold live, who counts it, and what does "withdraw" mean
   mechanically so no man is ever lost in the jungle?
3. How is the single axis enforced against terrain, the wire, and the MG emplacements — and does
   one axis make the fight a shooting gallery?
4. What does 50 full-AI bodies + garrison + squad + mortar impacts do to the frame budget, and what
   is the honest mitigation *within* Forward+ (ADR-025 LOD tiers, EnemySquad hot-set)?
5. What breaks the three-night run — persistence, garrison casualties, depot loss, save/load?

## OUTPUT CONTRACT

Write your full analysis to `production/war_room/2026-07-28_firebase_siege/analysis/<your_role>.md`.
Return to the Arbiter **only a short verdict**: your top 3 findings and your single biggest
disagreement with the decree's implied design, each with a `file:line` pointer. Keep the return
under 400 words — the Arbiter's context is the scarce resource.
