# THE DECREE — the 45-minute demo, and Hearts & Minds felt by allies, villages and enemies (2026-09-14)

**Arbiter:** Claude (Fable 5.1), for the Summoner. Council of five: `analysis/game_designer.md`,
`analysis/systems_designer.md`, `analysis/writer.md`, `analysis/technical_director.md`,
`analysis/devils_advocate.md`; debate in `discussion.md`. **Branch: `RPG-build` only** (game state).
The one item in it that is base simulation — the informer response's Time seed — is committed on
`BaseGame-V1` first and fast-forwarded.

## The judgment

His 45 minutes are two different problems, and only one of them is a clock. **The day** is short
today (night falls at 19:44 real) and empty (the two-quests plan measured the dead air); it lengthens
by the clock and fills with things that ARE the RPG: the village seen twice, a guaranteed shoot-down
and a slow escort, a man who walks with you and decides. **The assault** is short today (it breaks at
~139 s, 22 of 45 down) and no cap lengthens it; it is a siege-pacing council of its own (finite
reserves and arrival cadence, the handoff's D5), convened after this ships and measured with the
instrument the DA named first: what ends the night.

Hearts & Minds stops being "no value to read" (ADR-038 §5) the moment a ledger of DEEDS exists —
sets of occurrence ids, never counted — and one consumer per audience reads a band from it. The
factions' four voices stay canned tonight; the world's wordless reading and the warning are the first
readouts, and they are felt, not read.

## The build — stage 1 (this session, one change on `RPG-build`, gated)

1. **The clock.** `demo_game.gd`: `DAY_RATIO` 38 → 27, `NIGHT_RATIO` 20 → 12, `PROBE_AT_S` 1395 →
   1740, `SIEGE_AT_S` 1440 → 1800, `END_BACKSTOP_S` 2700 → 3000. Night falls at 1667 s (27:47); DUSK
   (17:00) is visible from 23:20 on the walk home; the arc ends ~22:27 sim, midnight never crossed;
   `_arc_hour_at` derives the stress boot; `test_demo_arc.gd:34-41` re-pinned on purpose with the
   reason. `MAX_DURATION_S` is NOT touched (DA).
2. **The ledger.** `scripts/world/hm_ledger.gd` (`class_name HmLedger`, RefCounted, `EvidenceLedger`'s
   shape): `deeds: Dictionary` id → `{kind, place, sim_hour}`; `note(id, kind, place)` is idempotent;
   `has(id)`; `band(place) -> StringName` (`&"quiet"` / `&"wary"` / `&"hostile"`) derived from KINDS
   present, never from a count; no method returns a number. Held by `CampaignState.hearts`
   (`campaign_state.gd`), saved alongside `threat_modifiers` (the demo's sandbox applies), keyed by
   the village hash `civilian.gd:481-482` already uses. **Guard:** `tests/test_hearts_felt.gd` —
   pure, no world: (a) the ledger exposes no count (`.size()` on `deeds` outside `hm_ledger.gd` fails
   the grep), (b) every string in `HM_LINES` (the felt lines, one place) matches ADR-038 §2a: no
   numerals, no comparatives of degree, no *more/less than before*, no direction words.
3. **Producers (three, stable ids, idempotent):**
   - `informer/<village>/talked` — `Civilian._transform_to_vc` (`civilian.gd:545`) notes it; the
     response it triggers (`field_director.gd:789-806`) is seeded from `hash(from_pos) ^ mission_seed`,
     never `Time` (ADR-010; this line is base simulation → `BaseGame-V1`).
   - `fire/<village>/p<n>` — the player fires inside `VILLAGE_FIRE_M` (60 m) of a village centre
     while **no hostile is perceived within 80 m of that centre** (the DA's false positive: return
     fire at the informer's responders is not misconduct). `<n>` = the patrol count from
     `CampaignState`, so one patrol notes it once.
   - `civ/<village>/<name>/killed` — `Civilian.take_damage` with the player as attacker, fatal.
4. **Consumers (one per audience, all bands, all felt):**
   - **Village — the world's wordless reading.** `CivilianSchedules.action_for` takes a `wary: bool`
     from the ledger's band (`&"wary"` or `&"hostile"` for that village): farmers hold `walk_home` /
     `rest` after 11:00 instead of the afternoon `work`; the elder sits inside, not on his bench; the
     paddy is empty at midday. Nothing is said. The writer's rule binds: the instant somebody narrates
     the empty paddy, the meter is back.
   - **Enemy — the warning present or withheld.** At the night seam, `FieldDirector` reads the
     ledger: if `informer/<village>/talked` is NOT in it (the informer never saw you, or died), the
     sentry's line lands at 1667 s — *"SIX: THE VILLE SENT A KID UP THE ROAD. SOMETHING'S MOVING
     TONIGHT."* — and `_garrison_stand_to` runs 73 s before the probe; if it IS, no line, and the
     stand-to waits for the probe's own shout. One mortar timer of difference (DA); felt, small,
     honest.
   - **Ally — the pilot at the ward door.** The shoot-down is GUARANTEED in demo mode
     (`pilot_recovery.gd`: the coin flip becomes a demo-mode boolean, one event per day stays); a
     recovered pilot stands to at the aid station door on HOLD at `siege_began`, alive and named in
     the end card. He is not a squadmate (handoff §0A).
5. **The Time seed fix** (`field_director.gd:803`) — base simulation, `BaseGame-V1` first.

## Stage 2 — the earned companion (next session, same branch, its own gate)

A garrison man named at the bunk walks the day with the squad as a TEMPORARY partner (ninth man in
`SquadSystem.members` for the day only); the outing's result `outing/day1/<seed>` — the pilot
recovered, lost, or abandoned — is noted with him present; recovered → `companion = true` on his
roster record and he comes to the player's position at stand-to; else he goes back to his post. His
IDENTITY survives the refusal: `GarrisonDefender.stand_down`'s defaults (a cook with a new name — DA)
are replaced by the F10 snapshot (occupation, name, model, home). The writer's two lines (refuses /
chooses) ride the toast channel, §2a-checked. Built after stage 1's gate and after the N2 A/B, because
it touches placement and the roster together.

## Refused and deferred

- **`MAX_DURATION_S` 480 → 900: refused** (DA). The night ends by the break rule at ~139 s; the cap
  is not the lever. **The 15-minute assault is its own council** (finite reserves, arrival cadence,
  phases; the 9/11 siege-waves work is its baseline; the instrument is a `--stress=assault` run that
  prints what ended the night and when).
- **The four factions' spoken lines: deferred.** They stay canned until the ledger has a second
  producer per village; §2a is enforced by the one guard from day one.
- **HQ's *"KEEP IT THAT WAY"*: cut** (it scores the patrol).
- **The village task at 4-11: deferred** to stage 2 with the partner; the first pass of the village
  is a WALK, on purpose (the paddy must be seen full).

## What is sacrificed (law 2)

- The demo ends at ~33 minutes, not 45, until the assault council lands: the day is 28 minutes of
  RPG; the assault is the ~2.5 minutes it is today, at 30:00 instead of 24:00.
- Camp life runs 40% slower in real seconds at 27x: a sitting that took 24 s takes 34.
- A player who never went near the village gets the same warning as one who kept the informer
  quiet: the enemy consumer rewards conduct, not attention.
- The paddy-empty reading is invisible to a player who does not walk back through the village. The
  route passes it twice by design; a player who cuts across the paddies never sees it, and that is
  freedom, not a bug.
- Three producers, three consumers, one line: the readout is thin on purpose. ADR-038 §5's sentence
  ("no province value to read") becomes false; "the readout exists" may be said only of these three.

## Gates before stage 1 is called done

- `test_demo_arc` green on the new pins; `test_hearts_felt` green; the four NPC tests green.
- A headless day at the demo's ratio (`--npc-census` extended or a new `--hearts-probe`): every deed
  noted with its id exactly once; the paddy empty after a `fire/` deed and full without one; the
  warning line present without `informer/talked` and absent with it; the pilot chain fires once.
- `--stress=assault` 0 errors; the siege still breaks and ends.
- Commit on `RPG-build`; the Time-seed line on `BaseGame-V1` and fast-forwarded; push both.
