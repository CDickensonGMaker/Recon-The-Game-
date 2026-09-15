# DISCUSSION — the 45-minute demo and Hearts & Minds felt by allies, villages and enemies (2026-09-13, night)

Five architects, no cross-talk: `analysis/game_designer.md`, `analysis/systems_designer.md`,
`analysis/writer.md`, `analysis/technical_director.md`, `analysis/devils_advocate.md`.

## Where the Arbiter's briefing was wrong (the code wins)

- **A 15-minute assault is impossible today.** `SiegeDirector.MAX_DURATION_S = 480` counts from the
  PROBE (`siege_director.gd:77, :319, :684-686`; `reinforce()` never resets `_elapsed`), so every demo
  night ends at ~435 s of fighting with a "FIRST LIGHT" toast at ~21:12. There is no 15-minute
  defence to lengthen; there is a 7-minute one to unlock (GD, SD, TD, three doors).
- **The "three launchers" do not exist in demo mode.** The night roll is gated (`siege_director.gd:
  239-241`), sleep is gated (`sleep_station.gd:72`); the clock is the one launcher today (TD).
- **Enemy pressure is producer-live and consumer-dead in the demo.** `threat_level` moves
  (`campaign_state.gd:246-251`, `field_director.gd:1520-1563`) and nothing in the demo reads it
  (`_maybe_open` returns at `:241`; the tier cannot leave MODERATE in one patrol) (SD, GD).
- **The informer's response is Time-seeded** (`field_director.gd:803`) — an ADR-010 break on the one
  built Hearts & Minds edge (SD).
- **The witnessed crash is already BUILT** — `pilot_recovery.gd` (S28), a coin flip today (GD).
- **The circuit passes the village once.** A paddy only reads empty to a man who saw it full; the
  wordless reading needs a second look at the same place (writer). No well exists; no Conquest of
  Worms face is wired (`grep cow_ scripts` = 0) (writer).

## The clock — four proposals, one shape

| | today | GD | SD | TD |
|---|---|---|---|---|
| `DAY_RATIO` | 38 | 30 | 27 | 27 |
| `NIGHT_RATIO` | 20 | 12 | 12 | 12 |
| night falls | 1184 s (19:44) | 1500 s (25:00) | 1667 s (27:47) | 1667 s (27:47) |
| `PROBE_AT_S` | 1395 | 1650 (27:30) | 1740 (29:00) | 1770 (29:30) |
| `SIEGE_AT_S` | 1440 | 1740 (29:00) | 1800 (30:00) | 1830 (30:30) |
| siege cap | 480 const from the probe | demo-set `max_duration_s` 900 | same | same, from the assault |
| backstop | 2700 | 2900 | 3000 | 3000 |
| midnight | — | never (50:00) | never (ends 22:27) | never (raid ends 22:15) |

All four: `NIGHT_RATIO` 12, the cap becomes a demo-set variable at 900 s the way the demo already
sets `ring_min/ring_max`, `test_demo_arc.gd:34-41` re-pinned on purpose, midnight never crossed, the
DUSK lighting state (17:00) visible on the walk home. They differ by three minutes on when night
falls; the writer wants dusk on the walk home (return 21-25) and the GD wants the escort to end at
dusk. The Arbiter takes the SD/TD clock (27x) — it keeps DUSK at 23:20 for a return that starts at
21, and the warning window (§ below) lives in the 1667-1740 gap.

## The 45-minute table — where the four converge

| minutes | block | fills it today | new at minimum |
|---|---|---|---|
| 0-4 | wake on the bunk, the squad's move-out, the first named man | `demo_game._tick_opening`, the gate file (shipped tonight), garrison life (the NPC batch) | one line from the partner (writer) |
| 4-11 | the village, first task | `plan_demo_world` village, schedules, the informer, the temple | the task's ask and its result id (GD: "village quiet"); the paddy FULL on the way in (writer) |
| 11-21 | the main outing: a GUARANTEED Skyraider shoot-down and pilot escort | `pilot_recovery.gd` (built, coin flip today), hunters, the camp | the coin flip becomes a guarantee in demo mode; the escort is the slow verb (GD) |
| 21-25 | the walk home through the village again, at DUSK | the same circuit; `MissionWeather` DUSK at 17:00 sim | the paddy EMPTY or FULL (the first consumer); the partner's line |
| 25-28 | the warning window: stand-to armed | `_garrison_stand_to`, radio traffic | the warning present or withheld (the enemy consumer) |
| 28-30 | the probe on the wire | `PROBE_AT_S`, the sapper probe | — |
| 30-44 | the assault, phased | `SiegeDirector` 45 men, the reinforce, air beats | the cap lifted to 900; phases per the handoff; the earned man at your position |
| 44-45 | the break, the gunships, the end card | `siege_ended`, `ENDING_PLAYER_SURVIVES` | one true consequence line (who came, who stayed home) |

**The dead air, named (GD, writer):** minutes 4-11 and 21-25 are walks; they are filled by the
village being SEEN twice, by the partner walking with you, and by the escort's slowness — not by more
tasks.

## The three variables — owners (TD, SD agree; GD's ledger of deeds is the same thing by another name)

| variable | owner | id | saves | deterministic |
|---|---|---|---|---|
| enemy pressure | `CampaignState.threat_modifiers` — the reason string IS the occurrence id (`campaign_state.gd:226`), zero new fields | `fire/village/<hash>/p<n>`, `informer/<hash>/talked` … | already saved (`:313-315`), sandboxed in the demo | seeded by mission seed + village hash |
| local support (per village) | a small `HmLedger` (RefCounted, `EvidenceLedger`'s shape) held by `CampaignState`, keyed by the village hash `civilian.gd:475-476` already uses; a SET of deeds, never a count | the same ids | with CampaignState | same |
| individual trust (per named ally) | two keys on the roster dict (`ally_base.gd:285` IS the roster record): `trust_deeds` (set) and `companion` (bool) | `outing/day1/<seed>` | with the roster | same |

Not `DynamicMissionFactory._seen` (instance-id keys, world lifetime, records before validating — TD).
**The guard (GD, SD):** no `.size()` or numeric read of a deed set outside the ledger; consumers read
a BAND (`cold / warm`) never a number; `tests/test_hearts_felt.gd` greps the faction lines for
numerals, comparatives and "more/less than before" (ADR-038 §2a) and greps the code for `.size()` on
the ledgers.

## First producer → first consumer per audience — the convergence

| audience | producer (id) | consumer (felt) | who |
|---|---|---|---|
| village | fire discipline near the ville: `fire/village/<hash>/p<n>` from the noise/evidence path (`civilian.gd:459-465`, `EvidenceLedger`'s player-side noise) | the afternoon paddy stays EMPTY and the elder is not on his bench: a `wary`/`shut` branch in `civilian_schedules.gd:31-48` holds farmers on `walk_home`/`rest` — wordless, seen on the walk home | GD, SD, writer (three doors) |
| enemy | the informer's fate: `informer/<hash>/talked` (`civilian.gd:545-549`) | the dusk warning PRESENT or WITHHELD: with a `warm` village the sentry's stand-to shout comes 73 s before the probe (SD) / with a talked informer it is withheld until men are inside 90 m (`field_director.gd:1887-1889`, GD); the writer's line: *"SIX: THE VILLE SENT A KID UP THE ROAD. SOMETHING'S MOVING TONIGHT."* — the demo always probes, so a QUIET night cannot be the readout | GD, SD, writer |
| ally | the outing's result: `outing/day1/<seed>` resolved with the temporary partner present (SD); the pilot recovered `pilot/<seed>/recovered` (GD) | the partner CHOOSES: he stays in `members` and comes to your position at stand-to (McCleary's post is the player's position, not his marker — writer, `garrison_defender.gd:74-76`); else `GarrisonDefender.promote` takes him home; the recovered pilot stands to at the ward door on HOLD (GD) | GD, SD, writer, TD |

## Disagreements

1. **Who is the temporary partner.** SD: a garrison man; GD: the pilot is the visible payoff; writer:
   McCleary (a face exists — but no CoW face is wired). Resolution: the partner is a GARRISON man
   named in the roster (built tonight from existing bodies); McCleary's face is content for the art
   lane; the pilot is a second, separate payoff (he is not a squadmate — handoff §0A).
2. **The assault's length.** All want ~14 minutes of fighting; the cap lifts to a demo-set 900 s; the
   break rule (`EnemySquad.break_state`) ends it, never the stopwatch (SD). TD: re-basing the cap
   together with a widened phase machine is the riskiest edit — do the cap FIRST, phases later.
3. **The devil's advocate's column.** The stopwatch is not what ends the night: the paced assault
   BREAKS at t+139 s with 22 of 45 down under the 42.5% break rule (`siege_director.gd:692`,
   `PERF_LEDGER.md:3481`, and the DA's own `--stress=assault` tonight: ~136 s). Lifting
   `MAX_DURATION_S` to 900 buys nothing; the converged clock ends the demo at ~33 minutes; fifteen
   minutes at 45 men means cutting the kill rate ~6×, which is the 9/11 stall class by design.
   **The assault's length is its own council** (the handoff's D5: finite reserves, arrival cadence,
   phases — not a cap). What survives the attack: the RefCounted ledger of deeds with stable ids held
   by CampaignState (not `_seen`, not `MissionState`); the informer Time-seed fix; the reserve stocked
   at the warning beat; a visible dusk on the walk home; the pilot at the ward door on HOLD (a built
   chain, no ninth man). Its other findings, each binding on the build: the withheld warning is worth
   about one mortar timer (felt, small); fire-discipline as written fires on the player's own return
   fire at the informer's responders (a false positive — the deed must require no hostile in contact
   near the ville); a refused companion goes through `stand_down`'s defaults and comes back as a cook
   with a new name (identity must survive the refusal); HQ's *"KEEP IT THAT WAY"* scores the patrol
   and breaks §2a; three architects wrote three different §2a guards — one guard, one test.
