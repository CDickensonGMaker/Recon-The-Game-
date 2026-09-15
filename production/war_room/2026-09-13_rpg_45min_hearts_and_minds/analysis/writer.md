# WRITER / NARRATIVE DIRECTOR — what the player HEARS and SEES (2026-09-13, night)

Lens: Hearts & Minds and the earned companion, FELT inside 45 minutes, with no meter, no menu, no
plot. Every claim below carries a pointer or a date. Nothing here was run; no game file was edited.

## 0 · The channel the words ride (verified)

- `FieldDirector.toast` (`scripts/missions/field_director.gd:7`) → `MissionHUD.show_toast`
  (`scripts/ui/mission_hud.gd:394-402`): 17 px amber label, centre-top, **3.5 s + 1 s fade**. Every
  line is pushed to `FieldLog` first (`scripts/ui/field_log.gd:22-42`, 240-line ring, identical lines
  inside 20 s collapse) — so a line missed in a firefight is still in the journal.
- **House style is `SPEAKER: LINE`, all caps**: `"%s: CONTACT!"` (`scripts/squad/squad_system.gd:786`),
  `"%s: HOLD UP - MOVEMENT AHEAD"` (`:625`), `"SIX: ..."` (`field_director.gd:1699,1703`), `"S2 INTEL:"`
  (`:1490`). The four voices need no new convention.
- **VO is additive, never required** (`scripts/autoload/vo_manager.gd:9`). The asset wall: `john`/`ryan`
  hold 24 squad clips (`assets/audio/vo/john/`, all combat barks), `joe` holds 14 radio clips. **No clip
  exists for any line in this file, and none may be planned for** — every H&M line ships as text.
- ADR-030 is PROPOSED/DEFERRED (`production/adr/ADR-030-hud-buffer-doctrine.md:3-5`); it is the period
  look, not the channel. The briefing's pointer to it is harmless but not load-bearing.

## 1 · The felt readouts, per audience

### 1a · THE VILLAGE — wordless (ADR-038 §2: "the instant somebody narrates the empty paddy, the meter is back")

The code already owns the states; nothing needs a new animation. Two world states, `open` (default)
and `shut`:

| # | The reading | `open` (code today) | `shut` (the edit) | Pointer |
|---|---|---|---|---|
| 1 | **The paddy at midday** | farmers WORK 06:30-11:00 and 13:00-17:00 | farmers stay on `walk_home`/`rest` all afternoon — the paddy is empty when you walk back past it at 15:00 sim | `scripts/ai/civilian_schedules.gd:31-48` (`action_for` is static and pure — one `shut` branch) |
| 2 | **The old man on his bench** | elder TALK 09-11 / 12-14, SIT 14-17 at his working point | elder holds `sleep` (indoors) from the flag on | `civilian_schedules.gd:81-98`. **There is no well** — see §6 |
| 3 | **The crouch** | villagers `WANDER` on their schedule | every villager within `COWER_M` of the player drops to `COWER` (`crouching` clip) when the squad enters | `scripts/world/civilian.gd:17` (`CivState`), `:611-614` (`crouching`); the mechanism is `_force_cower` `scripts/world/ambient_encounters.gd:341-353`, keyed today on the harass group — re-key on the player |
| 4 | **The children** | `civ_kid`, `civ_kid_b` exist and draw an adult occupation | `open`: kids `walk_group` behind the squad to the ville edge (the *Platoon* image); `shut`: kids `GONE` indoors | `civilian.gd:299` (models), `:619` (`walk_group`), `:1296` (`_group_walk_apply`). **Retargeting the group walk onto the player is NEW** — price it; cut it first |
| 5 | **Who looks up** | nothing — no civilian look-at exists (checked `civilian.gd` `_animate` `:593-690`) | not built | Do not promise it |

The trail wire: ADR-020's guarantee (`ADR-020-authored-threshold.md:52-53`), but **I did not verify a
tripwire prop or placer exists in this pass** — the point man's `HOLD UP - MOVEMENT AHEAD`
(`squad_system.gd:625`) is the only existing "the trail is wrong" channel. Treat as unpriced.

**The reading needs a SECOND LOOK.** The two-quests circuit is gate → village → camp → home
(`DEMO_TWO_QUESTS_PLAN_2026-09-06.md`, per briefing). A paddy can only read as *empty* to a man who saw
it full. **The route must pass the ville twice**: out at ~08:00 sim (paddy full, elder on his bench,
kids at the edge), back at ~15:00 (full or empty, bench or no bench). Gate → ville → camp → **ville** →
home. The route is the readout. This is the cheapest content in the council and I believe it is the
thing the Arbiter's read missed.

### 1b · THE ENEMY — what an ambush or a quiet night SAYS

- **Day, `shut`:** the informer path, built. He must SEE you (`civilian.gd:531-534`, ADR-005), 25 s later
  `"THAT VILLAGER TALKED - THEY KNOW YOU'RE HERE"` (`:544`) and hunters come from the FAR side, ALERT
  but unwitnessed (`field_director.gd:789-816`). The line is legal under §2a — a subject and a fact,
  no quantity, no direction. *Keep it.*
- **Day, `open`:** nothing. The quiet trail is the reading and ADR-038 accepts that a player who never
  talks to anyone gets no readout. Do not add a "the trail is clean" line — that is the meter.
- **Night — the demo ALWAYS probes** (`scripts/levels/demo_game.gd:59-60`, PROBE_AT_S/SIEGE_AT_S). So
  "what a quiet night says" is not available to the demo. **The enemy's readout at night is the WARNING
  QUALITY** (the handoff's own payoff row, `DEMO_40MIN_HANDOFF_2026-09-13.md:233`):
  - `open`: one line at dusk, before PROBE_AT_S: **`SIX: THE VILLE SENT A KID UP THE ROAD. SOMETHING'S MOVING TONIGHT.`** (12 words)
  - `shut`: no line. The first thing you hear is the sentry: `"MOVEMENT ON THE WIRE - STAND TO"`
    (`field_director.gd:1888`) — already built, already legal.

### 1c · THE ALLIES

**The reluctant partner — two lines.** Speaker: MCCLEARY (see §2). Both unprompted, both once.

| Beat | Line | Words | Where it fires |
|---|---|---|---|
| Refuses | `MCCLEARY: THIS IS AS FAR AS I GO. THE VILLE'S YOURS.` | 11 | the tree line before the ville, first walk-out; he HOLDs there (`garrison_defender.gd:74` `set_order(HOLD, post)`) |
| Chooses | `MCCLEARY: SAVE ME A SPOT ON THE WIRE. I'M WALKING OUT WITH YOU.` | 13 | the gate, SECOND walk-out, only if the producer fired; he switches to `FOLLOW` (`ally_base.gd OrderMode`, used at `squad_system.gd:281`) |

**The garrison man at stand-to — one line.** Speaker: CHAMPS. The player is addressed by rank, never a
number (ADR-032: `CampaignState.title()`, `campaign_state.gd:62-95`; at reputation 0 he is PVT, and a
lieutenant calling a replacement "PRIVATE" is period-true).

- **`CHAMPS: %s - TAKE THE GATE SIDE. WE KNOW WHERE YOU'LL BE.`** with `%s` = `CampaignState.title()` (11
  words). Fires once, at `_on_siege_began` probe branch (`field_director.gd:1884-1889`) after the
  sentry's shout. Champs' rank is his open call (`production/HANDOFF_2026-09-13.md:72`) — **no rank word
  in Champs' own tag** until he rules.

**The four voices, unprompted, one per faction per world state** (ADR-038 §2, §2a). Trigger: the player
passes within ~6 m of that camp's hooch row (the billets exist: `FSB_GARRISON_POSTS` /
`FSB_GARRISON_QUARTERS`, `site_planner.gd:938-962` per ADR-038 §5) AND the village flag is set AND the
line has not fired this sim day. **Never at the wire crossing** — a line that lands as you bank the
patrol is a score (`_bank_patrol`, `field_director.gd:1797`). Fire it the *next* time you walk the row.

| Voice | `open` — the ville still talks | `shut` — the ville shut its doors |
|---|---|---|
| **HQ** | `HQ: S2 SAYS THE VILLE'S STILL TALKING TO THE ARVN. KEEP IT THAT WAY.` (13) | `HQ: S2 SAYS THE VILLE'S GONE QUIET ON US. NOBODY'S REPORTING. FIX IT.` (12) |
| **TRUE BELIEVERS** | `LIFER: THEY SMILE AT YOU IN THAT VILLE. THEY SMILED AT CHARLIE LAST WEEK TOO.` (14) | `LIFER: THEY SHUT THEIR DOORS ON YOU. GOOD. NOW THEY KNOW WHICH SIDE WE'RE ON.` (14) |
| **DRAFTEES** | `KID: SOME KIDS FOLLOWED YOU OUT OF THE VILLE. NOBODY'S FOLLOWED ME ANYWHERE.` (12) | `KID: THE VILLE WON'T TALK TO ANYBODY SINCE YOU WENT THROUGH. NOT US, NOT THE ARVN.` (15) |
| **BLACK MARKET** | `DEALER: MY GUY FROM THE VILLE CAME UP THE ROAD TODAY. YOU WANT FISH, I GOT FISH.` (16) | `DEALER: MY GUY FROM THE VILLE DIDN'T COME UP THE ROAD. YOU DID THAT. SAIGON PRICES NOW.` (16) |

Speaker tags `HQ` / `LIFER` / `KID` / `DEALER` are placeholders for `SquadRoster.call_name()` of the
billet's seeded man (`garrison_defender.gd:72,163-166` — a garrison man's name is seeded from his stand
position, so **the same man has the same name every stand-to for free**, ADR-010). Nobody says
"allegiance", "hearts", "minds", or "the villagers' opinion" (craft rule 1). HQ's is the least true
reading (rule 2): in `open` he takes credit, in `shut` he blames.

**The §2a grep guard** (run over the line table and over `FieldLog.entries()` in the probe, §5):

```
sed -E 's/\bS2\b//g' <lines> | grep -nE '[0-9]|\bMORE\b|\bLESS\b|\bBETTER\b|\bWORSE\b|\bHALF\b|\bMOST\b|\bEVERY TIME\b|\bAGAIN\b|\bBACK AROUND\b|\bCOMING (A)?ROUND\b|\bTURN(ING|ED)\b|\bTHAN BEFORE\b|\bALLEGIANCE\b|\bHEARTS\b|\bMINDS\b'
```

**RUN, 2026-09-13, over the 13 lines in this file:** 2 hits, both the token `S2` in the HQ lines. `S2`
is the intelligence section's name, already in the game's vocabulary (`"S2 INTEL:"`,
`field_director.gd:1490`), not a quantity — exempted by the `sed` above, deliberately and only that
token. Zero hits otherwise; longest line 16 words. `%s` is a rank word, never a digit — `TITLES` are
`PVT/PFC/SP4/SGT/SSG` (`campaign_state.gd:62`); note `SP4` would trip the digit test if a rank ever
lands inside a faction line, so the rank slot lives only in Champs' line, which is not a faction line.
The nameplate reads `member.name` (`scripts/ui/squad_nameplate.gd:68-69`), so a seeded garrison man's
name is on his chest as well as in his tag. **The `(%d LEFT)` fire-support toasts**
(`field_director.gd:594-629`) are ammunition counts, not faction lines; scope the guard to the H&M
table and the four-voice emits, not the whole log.

## 2 · The earned companion — who, what he sees, what changes

**Who: Sgt. McCLEARY.** Not a squad member — the demo keeps its eight (ADR-044 §0,
`war_room/2026-09-09_progression_spine/ADR-044-the-progression-spine.md`), and a companion who takes a
roster slot would be the full game's ladder smuggled into the demo. He is a **garrison NCO**
(`GarrisonDefender`, `squad_member = false`, `garrison_defender.gd:68`) detailed to walk the new
man to the ville and back. Bulky, forearms, cigar, bandana (Caleb verbatim,
`war_room/talking_heads_2026-09-11.md:96-98`). Gus stays in the squad — he is the ear teacher (`:124-127`)
and the ear is the atrocity producer; giving Gus the trust arc would tangle two ledgers in one face.
Champs is the officer's acknowledgement (§1c) and nothing more — a Black lieutenant whose only line is
about the wire passes ADR-038 §3's five-minute test (nobody in this file speaks about race).

**The face exists on disk, NOT in the game.** `cow_mccleary.glb`, `cow_mccleary_helmet.glb`,
`cow_champs.glb` are on disk (`production/HANDOFF_2026-09-13.md:25-27`); `grep -rn cow_ scripts` = **0
hits**, and `ModelActor.model_path()` (`scripts/visuals/model_actor.gd:9-21`, the ONLY sanctioned
`unit_id` → path resolution) carries no cast id. Wiring two `unit_id`s is the asset gate for this
beat. If it slips, McCleary ships as a `GARRISON_MEN` body under his name (`civilian.gd:313`,
`call_name`, `squad_roster.gd:283-291`) — legal, felt less.

**What he sees.** One producer, witnessed by him (ADR-005: participation, not telepathy — the
handoff's own rule, `DEMO_40MIN_HANDOFF_2026-09-13.md:129`). Pick ONE of, in order of cheapness:
1. **The informer never got his 25 s** — the player saw the runner and stopped him (any means) before
   `_inform_clock > 25.0` (`civilian.gd:539-546`). Occurrence id: `_informer_answered` is already a
   once-per-op latch (`field_director.gd:790-792`); its *complement* — informer seeded
   (`mission_generator.gd:1297-1301`, always in demo) and never answered by wire-return — is the
   `open` fact.
2. **The ville freed** — `villagers_freed` already banks (`ambient_encounters.gd:325-328`) with the line
   `THE VILLE'S CLEAR - THEY WON'T FORGET WHO CAME` (legal under §2a: a promise of subject, no quantity).
3. Fire discipline near the ville — `NoiseBus` gunshots inside ~60 m of `village_center` with no enemy
   in the ville. NEW (the listener exists, `civilian.gd:442`; the tally does not).

**What changes — behaviour, never dialogue.**
- First walk-out: he HOLDs at the tree line (§1c line 1). He does not enter the ville. You go in
  without him.
- Second walk-out, producer fired: he crosses the gate behind you unasked (`FOLLOW`), line 2.
  Producer not fired: he is on his post; he says nothing; the gate is yours alone.
- Stand-to: `defense_zone` (`garrison_defender.gd:75-76`) is **the player's position**, not his marker
  post. He is the man beside you on the wire. If the producer never fired he holds his marker and you
  find him there — the nameplate (`squad_nameplate.gd`, per `garrison_defender.gd:69-71`) tells you who
  did not come.
- Ending: the end card already exists (`demo_game.gd` `_ending`, `:683-712`). One true line, no more:
  `MCCLEARY STOOD THE GATE SIDE WITH YOU.` or `MCCLEARY HELD HIS POST.` — a fact, not a score.

## 3 · The 45-minute day as CONTENT — priced in lines and world states

The dead air is the walk (briefing: 1184 s to dusk, 340-500 s of circuit). It dies only if the ville is
a place you SEE TWICE and the second walk-out has a reason to exist. My clock, as a writer's need (the
systems lens owns the number): night must fall at **~31 min**, not ~20 — at 38x the ville's afternoon is
gone before the player walks back past it. **DAY_RATIO ≈ 24** puts 06:30→19:00 at ~1875 s; DAY snaps at
sim 10.0 (`mission_weather.gd:40` `TIME_ID_START_HOUR`) ≈ min 9, as he reaches the ville; DUSK at 17.5 ≈
min 27.5 on the walk home. `tests/test_demo_arc.gd:34-40` pins PROBE 1395 / SIEGE 1440 / NIGHT_RATIO 20
/ START 6.5 as constants — it must be **re-pinned on purpose**, not left green by accident.

| Min | Block | Existing system | New content (min) | Player who ignores the task |
|---|---|---|---|---|
| 0-4 | Bunk → gate. McCleary detailed to you | `SQUAD MOVING OUT` at T+10 (`demo_game.gd:546`); garrison schedule | 0 lines; McCleary stands at the gate (a `GarrisonDefender` on a HOLD) | Walks the base; the four hooch rows are silent (no state yet) |
| 4-13 | First walk: the ville, OUT | route + `rebark_patrol` (`field_director.gd:1585-1595`); informer (`civilian.gd:531-546`); harass (`ambient_encounters.gd:294-339`); elder/kids on schedule | McCleary line 1 at the tree line; kids `walk_group` (cut first) | Skips the ville → informer never sees him → `open` by default; he earned nothing and McCleary stays home |
| 13-17 | Wire, in. Bank. | `_poll_wire_gate` / `_bank_patrol` (`:1465-1515, 1797`) | 0 lines at the wire (law: never score at the crossing) | Same |
| 17-19 | The hooch row | billets (`site_planner.gd:938-962`) | **1 of 4 faction lines**, unprompted, on walk-past | Never walks the row → no readout (ADR-038 accepted) |
| 19-30 | Second walk-out: camp / crash / friendly element, via the ville AGAIN | `ambient_encounters` patrol/contact (`:364-470`); camp; `SIX WANTS US SWEEPING` | McCleary line 2 at the gate (or silence); **village state visible on the second pass**: paddy, bench, crouch | He stays inside: the garrison day runs; dusk comes; no second look, no McCleary |
| 30-33 | Dusk return | `_bank_patrol`; DUSK snap | `SIX` dusk warning (`open` only) | — |
| 33-45 | Stand-to → probe → assault → gunships | `_on_siege_began` (`:1876-1894`), `SIEGE_STRENGTH`, `_ending` (`demo_game.gd:683`) | Champs' line; McCleary's post = you; 1 end-card fact | The assault comes regardless (one authority, `SiegeDirector`) |

**Price of the whole thing in words: 12 new lines** (2 McCleary + 1 Champs + 8 faction + 1 SIX dusk),
none over 16 words, all text, no VO. **World states: 7** (paddy, bench, crouch, kids [cut-first],
warning present/absent, McCleary tree-line HOLD/FOLLOW, McCleary stand-to post). **Faces: 2 `unit_id`s
to wire** (the gate). One end-card fact. That is all the content Hearts & Minds needs to be felt in
45 minutes; anything past it is the meter growing a face.

## 4 · What is sacrificed (Law 2)

- **No voice.** Every H&M line is amber text for 4.5 s. The four voices ADR-038 imagined as *men at the
  wire* are four captions until someone records lines — and the asset wall says nobody may plan on it.
- **One state per run.** A player who spares the ville sees `open` only; he never sees the empty paddy.
  The demo is one day; the before/after is `open` vs `shut` across TWO players' runs, and inside one run
  it is only the paddy-full-then-still-full. Accepted — it is the honest size.
- **Kids following the patrol** goes first if the group-walk retarget costs an hour; the crouch carries
  the reading alone.
- **McCleary's face** may ship as a generic grunt under his name if the two `unit_id`s slip.
- **The squad's own point man loses character** to McCleary in the demo; Gus's ear beat stays post-demo
  with the corpse wave (`HANDOFF_2026-09-13.md:59-61`).
- **The four voices are still "four men with canned opinions"** until the flag exists; the moment it
  does, the truth law lets a doc call the *flag* a value and the lines a readout — and not before.

## 5 · Answers to the briefing's list

- **45-minute table:** §3. **H&M model (my lane):** one village flag `open|shut` per site plan entry,
  set by producers (§2 list — informer answered, `villagers_freed`, `record_noncombatant_death`
  `field_director.gd:120`, `on_atrocity_witnessed` `civilian.gd:1147`), consumed by §1a states, §1b
  warning, §1c McCleary + four voices. The trust "variable" is the one `bool` on McCleary
  (`came_out`), witnessed. **Build first:** producer = the informer never answered (already latched,
  zero new bookkeeping); consumer per audience = paddy empty at midday (village), the dusk `SIX` warning
  present/absent (enemy), McCleary's stand-to post (ally). Why: each is one branch on code that runs
  today, and each is a thing a man SEES, not reads.
- **Felt/read guard:** the regex in §1c, run over the line table in-repo and over `FieldLog.entries()`
  in the probe; plus the placement law — no faction line at the wire crossing.
- **Sacrificed:** §4. **Riskiest edit:** re-keying `_force_cower` onto the player. `COWER` has exactly
  one exit, `_release_cowed` (`ambient_encounters.gd:355-360`); a village flagged `shut` at 08:00 could
  hold every villager in the crouch until dusk, and a frozen ville reads as a bug, not a reading. The
  schedule override (§1a #1-2) is the safe version of the same reading — do that one first, and give the
  crouch a proximity release, never a timer.
- **Cheapest probe:** the existing `test_demo_arc.gd` plays nothing — it asserts constants (`:26-40`).
  The proof is a headless day at 38x with `--village-state=open|shut`, printing every `FieldDirector.toast`
  with its `FieldLog.stamp_now()` (`field_log.gd:46-48`) and its producer id, then the §1c regex over the
  dump. The census must stay green — stand-to is already excluded from it (`field_director.gd:1806-1811`).
- **Where the briefing is wrong (the code wins):** §6.

## 6 · Where the briefing is wrong

1. **Four paths do not exist where cited.** `civilian_schedules.gd` is `scripts/ai/`;
   `garrison_defender.gd` is `scripts/allies/`; `ambient_encounters.gd` is `scripts/world/`;
   `friendly_patrol_group.gd` is `scripts/missions/`.
2. **There is no well.** No `well` action, marker or prop (`civilian_schedules.gd:8-19` lists every
   action). "Whether the elder is at the well" must read "whether the old man is on his bench" — his
   `SIT`/`TALK` working point (`:81-98`).
3. **"No value to read" is slightly wrong.** Two write-side crumbs exist: `state.flags["villagers_freed"]`
   (`ambient_encounters.gd:325-327`) and `CampaignState.reported_marks` `INFORMER` (`field_director.gd:795-797`,
   committed at mission end). Neither is read by a village. The missing half is the READ, and the read
   needs the second pass (§1a).
4. **`on_informer_escaped` is at `:789-816`**, not 786-800; the informer seed comment is `:1297-1301`.
5. **"Use a face that exists":** none of the CoW faces resolves in-game (`grep cow_ scripts` = 0;
   `model_actor.gd:9-21`). On disk ≠ in the game.
6. **The demo always probes** (`demo_game.gd:59`), so "what a quiet night says" is unavailable; the
   enemy's night readout is the warning before the probe, not the probe's absence.
7. **The "kids" the briefing wants to look up** cannot — no civilian look-at exists (§1a #5).
