# BRIEFING — the 45-minute demo, and Hearts & Minds felt by allies, villages and enemies (2026-09-13, night)

**Branch:** this is RPG game-state work. It commits on **`RPG-build` ONLY** (his ruling 2026-09-13:
"the game states of the difference between just the raw open world simulation and the turning of a
rpg is what we're keeping separate"). Anything in it that improves FPS, performance or combat is
committed on `BaseGame-V1` first and fast-forwarded into `RPG-build` (his ruling, same night: "anything
to improve performance of fps and overall combat etc should be applied to both branches"). The two
branches share ONE checkout; the N2 furniture council (`2026-09-13_n2_furniture_and_climb/`) builds on
`BaseGame-V1` first, then this builds on `RPG-build`. Both are at `5ddf69be` now.

## The Summoner's words tonight (verbatim, in order)

1. *"keep working on improving the recongame project, shaping it more for the rpg style game type inside
   the RPG build tree branch on github as well as deploying more of the Hearts and Minds system to work
   for the allied npcs as well as the villages and enemies etc"*
2. *"and lets really make a 45 minute demo shaped program that i can share on steam eventually when
   were in a working state"*
3. *"but anything to improve performance of fps and overall combat etc should be applied to both branches"*

Word 2 moves the demo's length: GAME_GUIDE §8 says ~30 real minutes (the 2026-09-06 Steam EA target,
"the product is THE DEMO'S SHAPE"); the 2026-09-13 handoff (`production/DEMO_40MIN_HANDOFF_2026-09-13.md`
§0A) proposed ~40 (25 introduction + 15 defence). **The target is now 45.** The shape (one firebase,
one day, dawn on the bunk → the day out → dusk return → stand-to → probe → assault → the player lives)
does not move. Steam is the eventual distribution; nothing in this council designs a store page.

## Canon that binds (read it; do not re-derive it)

- **ADR-019** Hearts & Minds (Accepted): *"the war is the story"*; destruction is TEMPORARY, attrition
  PERMANENT, a finite regional manpower pool; **allegiance is FELT, not read** (§4). Burn the village
  and the locals help the VC and the VC come for you on patrol — his own sentence.
- **ADR-038** The four firebase factions are the READOUT (§2): the world's reading is never a line;
  four voices on the existing toast/subtitle channel, zero new UI; **§2a the imprecision law** — a
  faction line may name the SUBJECT, never the QUANTITY, RATE or DIRECTION of change; at least one
  voice is UNPROMPTED; **§5 the scope wall** — the readout is *not buildable today because there is no
  province value to read*; the demo ships four men with canned opinions and *no doc may call it a
  readout*. **This council's job is to make there BE a value to read, demo-sized, and to say honestly
  what that unlocks.**
- **ADR-032** the player's reputation is hidden, never a number; **ADR-018** rank gates authority, not
  ability; **ADR-017** persistent province + AO window; **ADR-020** the authored threshold (guarantees,
  not rails); **ADR-035/036** the siege and the fall of the firebase; **ADR-044 (DRAFT, in
  `war_room/2026-09-09_progression_spine/`, never filed)**: the main game opens SOLO by Huey, men
  EARNED on trust, the necklace is the character sheet, a rotation clock; **the demo keeps its squad.**
- **The 40-minute handoff §0A** (his approved direction): keep **individual trust**, **Hearts and
  Minds / local support** and **enemy pressure/resources** as three distinct variables; no single global
  score that spawns or despawns enemies; consequences bounded and legible; one assault start/finish
  authority with an occurrence id (quest completion, the clock and the night roll must not launch
  three attacks); a witnessed crash is optional; trust consumes factual events with stable ids,
  idempotent across reload; for the demo, at most two local-support effects and one personal-trust
  transition; a small typed event result (occurrence id, location, persons, witnesses, consequences).
- **The two-quests plan** (`production/DEMO_TWO_QUESTS_PLAN_2026-09-06.md`): the circuit gate → village
  → camp → home is 850-1000 m, 170 s at walk speed, 340-500 s cautious with two fights; **dusk is
  1184 s away; the problem is DEAD AIR, not timing.** At 45 minutes the dead air is worse unless the day
  is filled with things that ARE the RPG.

## What the code has today (pointers; the code wins over any doc)

- `CampaignState.threat_level` 0.1-0.9 with `threat_modifiers` and `effective_threat()` /
  `threat_label()` (`campaign_state.gd:22-26, 207-251`); hidden `reputation` (`:26`, ADR-032).
  Consumers: `SiegeDirector` night-attack chance by label (`siege_director.gd:256, 283`);
  `FieldDirector` (`:1520-1535`, loud patrols raise threat; the label is shown at barracks/main menu).
  This is ENEMY PRESSURE by another name — one variable, campaign-wide, no place attached.
- **The informer** is the one Hearts & Minds mechanism that runs: the demo ALWAYS seeds one
  (`mission_generator.gd:1297-1309`, ruled 2026-08-03); he must SEE you (`civilian.gd:531`, ADR-005),
  25 s later he is gone (`:545 _transform_to_vc`), and `FieldDirector.on_informer_escaped`
  (`field_director.gd:786-800`) brings hunters from the far side. Village → enemy, one edge, built.
- `EvidenceLedger` (`scripts/enemies/evidence_ledger.gd`): hunters converge on evidence leads, never
  on the player's transform. `WorldSim` is a flat entity registry, not a province (`world_sim.gd:1-30`).
  `AgentRegistry` (`agent_registry.gd:12`) anticipates "the hearts-and-minds ledger" walking its roster.
  `civilian.gd:718-722` records the ADR-019 deferral in words.
- The squad: earned nicks and ranks by missions survived (`squad_roster.gd:69, 200-320`), skills
  learned by doing (`skill_catalog.gd:31`). **No trust variable exists on any ally.** Garrison men are
  civilians promoted at stand-to (`garrison_defender.gd`); the player's squad is `SquadSystem.members`.
- The arc: `demo_game.gd` START_HOUR 6.5, DAY_RATIO 38, NIGHT_RATIO 20, night at ~1184 s, PROBE_AT_S
  1395, SIEGE_AT_S 1440, END_BACKSTOP_S 2700, the squad's gate move-out at 10 s. `plan_demo_world`
  stamps one village, one camp, a temple, paddies, roads (`mission_generator.gd:666-775`); hunter teams
  are live after first contact. The village has farmers/elders/fisherman/cook occupations on schedules
  (`civilian_schedules.gd`), work points dealt without replacement, a seedling in the hand at planting.
- Saves: the demo sets `EXCLUDE_SAVES` and sandboxes campaign writes; `SaveData.mission` is an empty
  reserved dict (handoff F14). Nothing here may promise save-anywhere.

## The question, in two halves

**A. The 45-minute arc.** Give the pacing budget in minutes, per block, that reaches ~45 for a normal
player (not a harness), naming for EACH block which EXISTING system fills it and what new content it
needs at minimum. The handoff's table (0-4 arrive / 4-11 first task / 11-21 main outing / 21-25 return
and prepare / 25-40 assault / ending) is the starting shape at 40; it is not sacred. Say what the clock
does (38x day → night at 1184 s does not fit 45 min; what ratio, what START_HOUR, what does the
lighting table at `mission_weather.gd:40` allow), and how the assault is ARMED (the handoff's
world-state transition: OUTING RESOLVED → RETURN → ASSAULT ARMED → WARNING → ATTACK; one authority, one
occurrence id; a poor outing still reaches a defence). Name the dead air and what kills it.

**B. Hearts & Minds felt by allies, villages and enemies — demo-sized.** Propose the smallest model
that makes ADR-038's "no value to read" false:
- the three variables (individual trust per named ally; local support per village; enemy pressure),
  where each LIVES (CampaignState? a new ledger autoload? per-village on the site plan?), how it saves
  in the demo's sandbox, and how it stays deterministic (ADR-010: seeded, never Time);
- 3-5 PRODUCERS with stable occurrence ids: the informer's fate, a civilian killed or spared, fire
  discipline near the ville (ADR-038 §4 says this IS allegiance), a rescue/recovery, a supply or help
  task, a burned hooch, the crash survivor if the crash ships;
- 3-5 CONSUMERS, at least one per audience: **villages** (who talks, who warns, who informs, whether
  the paddy is empty at midday, whether the elder is at the well — the world's wordless reading);
  **enemies** (hunter cadence, warning quality, reserve/cadence of the assault within its budget, the
  night-roll odds — bounded, never popping men in or out); **allies** (the one earned companion — a
  temporary patrol partner who chooses to come; a garrison man who acknowledges you at stand-to; the
  four factions' unprompted lines under the imprecision law);
- what is FELT vs what would be READ, and the grep-enforceable guard that keeps it felt.

## Protected behaviour and laws

Pillars (believable firefights; atmosphere; freedom — stealth is an economy not a gate; **the squad
is the RPG and you are IN it, not above it**; fail forward). No meter, no number, no faction standing
screen (ADR-038 §2). No cheesy written plot (ADR-019 context). One siege authority (`SiegeDirector`).
ADR-010 determinism. The fossil law and comment discipline. The demo playthrough remains his gate. The
truth law: nothing may be called a readout, a system or a feature in a doc until the code does it.
The census (`--npc-census`) and the demo timing tests (`test_demo_arc*` if present — grep `tests/`)
must stay green.

## Questions each architect must answer (in your file, with `file:line`)

- Your 45-minute table, per block: minutes, the existing system that fills it, the new content it
  needs at minimum, and what a player who ignores the task does in that block.
- Your H&M model: variables, owner, producers, consumers, the felt/read guard. Which ONE producer and
  which ONE consumer per audience would you build first, and why that one.
- What is sacrificed (law 2)? Name it.
- The single riskiest edit.
- The cheapest probe that proves the model runs: a headless arc probe that plays the day at 38x and
  prints every consequence with its occurrence id? the census? a new one?
- What in this briefing is wrong (the code wins)?

**Output:** write your full analysis to `production/war_room/2026-09-13_rpg_45min_hearts_and_minds/
analysis/<your_role>.md`. Return to the Arbiter ONLY a verdict of ≤ 200 words: your 45-minute shape
in one line, your first producer/consumer per audience, the riskiest edit, the one thing the Arbiter's
read missed. No cross-talk. Time box: 25 minutes. Read code, never the plan, when they disagree.
