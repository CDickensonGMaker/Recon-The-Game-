# DEVIL'S ADVOCATE — what the converged proposal stands on, and what the evidence does not show (2026-09-13, night)

Lens: break the Arbiter's reading and the four verdicts; name what each choice sacrifices; find what the
evidence does NOT show. Every claim carries a `file:line` read tonight at `5ddf69be` or names the probe.
No game file edited. One headless probe run (`--stress=assault`, 230 s wall cap, §9); everything else is
constants, call sites and the ledger.

---

## 0 · THE ONE THING EVERYONE MISSED: the stopwatch is not what ends the assault. The BREAK is.

All four architects, and the discussion, treat `MAX_DURATION_S = 480` (`siege_director.gd:77`, `:684-686`)
as the wall that makes "a 15-minute defence impossible today" and its lift to a demo-set 900 as the door
to "~14 minutes of fighting". **The ledger measured the paced night AFTER the five 9/11 stall fixes, and
it does not run to the stopwatch:**

> *"Paced night now breaks at t+139 s / 22 down; flood at t+71 s / 23 down."*
> — `production/PERF_LEDGER.md:3481`; same figure in `war_room/2026-09-11_siege_waves/synthesis.md:19`

Headless, garrison only, no player, no squad. `EnemySquad.break_state(live, run_peak, courage, 0.575)`
(`siege_director.gd:692`, `enemy_squad.gd:118-122`) fires at 42.5% of PEAK killed — **19 of 45** — and the
36-man garrison reaches that in **~2.3 minutes** from the reinforce. With the player and eight squad rifles
added it is faster, not slower. The 480 s "dawn" branch (`:684`) has been reached by the shipping assault
exactly never since 9/11; before 9/11 it was reached only by the five stalls that are now fixed.

**So:**
- Today's demo assault is ~2-3 minutes, not the 7 the discussion says it is (`discussion.md:8-11`).
- Lifting the cap to 900 s **changes nothing** about how long the fight lasts. It changes only how long a
  STALLED night runs before "FIRST LIGHT" ends it — from 8 minutes to 15.
- The converged clock (night 1667, assault 1800, break at ~1940-1980, gunships ~2000 s = **~33 min**) does
  not reach 45 minutes. It reaches 45 only if the fight genuinely lasts 14 minutes, which the break rule
  forbids at 45 men.
- A 14-minute fight at 45 men needs the garrison's kill rate cut ~6x (19 kills over 840 s ≈ 1.4/min vs the
  measured ~9.5/min) — which is exactly "men standing at the ring not closing", the stall class the 9/11
  synthesis says the flat cap had been hiding (`synthesis.md:62-64`: *"the flat-cap break was the only
  reason five old AI stalls never showed"*). **The 15-minute assault and the 9/11 fix are in tension, and
  nobody priced it.**
- The handoff itself hedges the number: *"A strong defense can finish somewhat early... The target is a
  reliably paced encounter, not a forced minimum duration at any cost"* (`DEMO_40MIN_HANDOFF_2026-09-13.md`
  §0A). The council took a hedge as a constant.

**What the evidence does NOT show:** any measurement of the assault's length with a player on the wire; any
measurement of a night at `NIGHT_RATIO 12`; any measurement of a `WAVE_RAMP_S` other than 180. Every siege
number in the ledger is 480 s / 20x / 180 s. The council is retuning three coupled constants off zero rows.

**The cheapest first move nobody listed:** read `PERF_LEDGER.md:3481` and the `[DEMO] the raid ended at
%.0fs (%s)` line (`demo_game.gd:673-676`) from one `--stress=assault` run BEFORE touching the cap. Zero
code. It decides whether the clock work is aimed at the right constant. (§9 below is that run.)

---

## 1 · THE CLOCK — 27x day / 12x night / 900 s cap

### 1.1 The arithmetic is right; the comment it was read against is drift

`sim_clock.gd:70-77` is the ONLY period authority: DAWN 5-7, DAY 7-17, DUSK 17-19, NIGHT 19+. At 27x from
06:30: DAY snaps at **67 s**, midday 12:00 at **733 s**, DUSK at **1400 s (23:20)**, NIGHT at **1667 s
(27:47)** — SD/TD's numbers hold.

But `demo_game.gd:35-36` says *"lighting is a four-state table that only changes on a period boundary
(`mission_weather.gd:40` holds {5.5, 10.0, 17.5, 21.0})"*. Those are `TIME_ID_START_HOUR`
(`mission_weather.gd:43`) — the BOOT hour per time_id — not boundaries. **The writer built a DAY_RATIO 24
proposal on that drift** (`writer.md` §3: "DAY snaps at sim 10.0 ≈ min 9"). DAY snaps at 07:00 whatever the
ratio. A drift comment in the file the council is editing misled one of four architects; correct it in the
same change (NO MORE DRIFT), and `:59` ("360 s of it") with it.

### 1.2 What 27x costs that nobody named

- **The garrison's day is 40% slower in real seconds.** A sim hour is 133 s (was 95 s). The mess sittings,
  the 12:00 chow walk (`civilian_schedules.gd:113-115, :148`), the 19:00-20:00 sentry handover
  (`:118-120`) — every camp-life event the player might watch happens 29% less often per real minute. The
  SD names "dead air unless the two tasks land"; the TD names "per-sim-hour bookings thin". Neither says the
  base itself reads slower. On a 4-minute opening (sim 06:30-08:18) the player sees ONE schedule transition
  (the cook 08:00, `:170`) instead of the two he sees at 38x. Camp life is the demo's atmosphere pillar and
  the clock just diluted it.
- **12x night = a 2.5-minute assault ending at sim ~20:00**, "FIRST LIGHT - THEY'VE MELTED AWAY"
  (`field_director.gd:1927`) never toasts because the break toasts instead — fine — but if the stalls DO
  recur under any re-pacing, "FIRST LIGHT" at 22:24 is the toast, and it is a lie about the sky (same lie as
  today's 21:12; not new, still false).
- **Air beats:** `SIEGE_AIR_BEATS` run 25→300 s after `siege_at` (`demo_game.gd:395-403`). With a ~150 s
  fight, beats 5-7 (205, 255, 300 s) fire on an EMPTY field after the break — "LAST PASS - EVERYTHING THEY
  HAVE" over men who already ran. That is true TODAY at t+139 too. Re-spacing them across 900 s (GD)
  makes it worse: at 130 s spacing the sky is quieter per minute than today's, and the escalation order
  (standoff → guns → heavy) lands after the fight.
- **`--stress` follows** (`_arc_hour_at` / `_stress_boot_hour`, `:247-256`): seat = 19:17 NIGHT at the
  SD/TD numbers. Derived, safe. But a 900 s cap means a stress run that reaches "dawn" is 15.5 minutes —
  every 3-minute headless gate in this council's own rules cannot see the end of a stalled stress night.
- **Midnight:** backstop 3000 s → 23:27 at 12x. Never crossed. But the backstop is now unreachable by
  design: the break ends the night at ~1980 s and `siege_ended` → `_on_raid_ended` → `_ending`. The
  `END_BACKSTOP_S` edit is ceremonial.
- **`test_demo_arc.gd:32-41`** re-pinned — agreed, cheap. But note `:26-31`: the test's own header says the
  numbers are law "until he re-decrees them"; he re-decreed a LENGTH (45), not these numbers. The council
  is deriving them.

### 1.3 What is sacrificed by the clock alone
A 40%-slower firebase; three retimed air beats that already fire late; a stress run nobody can gate; a
rewritten arc test that pins numbers nobody measured; `demo_game.gd:35-36, :49-50, :59, :64-73`,
`sleep_station.gd:68` corrected. **Bought:** a visible dusk on the walk home (real: 1400-1667 s = 4.4 min
of DUSK light) — the one thing the clock change genuinely buys, and it is bought at 27x or 30x alike.

---

## 2 · THE 15-MINUTE ASSAULT — an assault that ENDS, or men trickling at the wire?

- **ADR-035 §1** ends a siege three ways: break (42.5% killed), wiped, or the 480 s stopwatch "before dawn".
  **ADR-036** is BLOCKED (`ADR-036:3-5`) — there is no objective to capture and no failure branch, so "a
  weak defense can lose" (handoff §0A) has no code. The assault ends on the break or the clock. Period.
- **The 9/11 measurement** (`synthesis.md:19, :32-49`; `PERF_LEDGER.md:3475-3481`): paced night ran to dawn
  with 14-31 men ALIVE and the kill count flat for four minutes; five defects fixed; **now breaks at
  139 s.** The ramp `WAVE_CAP_START 8 → 50 over 180 s` (`siege_director.gd:66-68`) tops out AFTER the break
  — at 139 s the cap is ~40, so ~5 cells are still held at the ring when the assault breaks
  (`wave_cap()` `:759-763`). The "whole force has still come by the time the ramp tops out"
  (`:44-46`) is false in the measured night.
- **A longer cap re-opens nothing by itself** — the stalls are fixed in `_reaim_stalled` (`:944-993`),
  `SapperCharge._withdraw`, the stuck watchdog. But a longer cap plus a SLOWER ramp (the only way to fill
  15 minutes at 45 men) is 15 minutes of men held at the 190-235 m ring (`demo_game.gd:636-638`), outside
  the garrison's 56 m night sight, waiting for a cap slot. That is the stall by design. The GD's "two
  reinforce steps 11→30→45" un-breaks once (peak grows with strength, `:355-360`) and buys perhaps one
  more 2-minute fight — not fourteen.
- **The handoff's phase table** (2-3 + 4-5 + 3-4 + 3-4 min) requires "finite remaining reserves commit"
  — i.e. MORE men over time. `test_demo_arc.gd:36` pins 45; ADR-035 §1 rolls a d50 once per run. The
  only path to more men is `open_siege` again after a break (nights_run 2, 3 — `siege_director.gd:296-305`,
  `MAX_RUN_NIGHTS 3`), which fires `_on_siege_ended` → `_garrison_stand_down()` (`field_director.gd:1936`)
  between waves — the garrison reverts to civilians mid-night and re-promotes, laundering names (F10) three
  times. Nobody proposed it; I name it only so the Arbiter knows the honest price of "phases".

**Sacrificed if the cap is lifted anyway:** a combat const becomes a var on both branches for a fight that
never reaches it; and the one guarantee the demo has today — that a stalled night ends in 8 minutes —
becomes 15.

---

## 3 · HEARTS & MINDS — felt, or invisible?

### 3.1 The paddy: the schedule already empties it, so the reading is indistinguishable
Farmers REST 11:00-12:00, WALK_HOME 12:00-13:00, WORK 13:00-17:00 (`civilian_schedules.gd:35-40`). At 27x
that is real **600-867 s empty, 867-1400 s full.** The GD's outing opens at 660 s; the TD's at 720 s. **A
player who passes the paddy on his way OUT to the crash (min 10-14) sees it empty in BOTH states.** The
consumer only reads on a pass between 14:27 and 23:20 real, and only to a player who ALSO saw it full
before 10:00 real (sim 06:30-11:00). The writer says "the route is the readout" — but there is no route:
the squad FOLLOWs the player after the gate order (`demo_game.gd:576-579`), `_patrol_anchors` route the
friendly element, not him, and the crash lands 220 m ahead of wherever the plane was
(`pilot_recovery.gd:76`, `_passable_near` on an UNSEEDED rng `:45`) — anywhere on the slice. Pillar 3 says he
walks where he likes. **The second look at the paddy is an assumption about player behaviour with no
mechanism behind it.** How often does a player look at a paddy twice? The evidence does not show; the
2026-09-07 demo audit found nobody has walked the arc with an instrument.

### 3.2 The withheld warning is worth ~15 seconds
GD's C-E: withhold "MOVEMENT ON THE WIRE - STAND TO" until men are inside 90 m. But:
- `_on_siege_began` (`field_director.gd:1876-1889`) calls `_garrison_stand_to()` BEFORE the toast. Withholding
  the toast withholds text; the garrison still promotes at the probe's open.
- Withhold the stand-to too, and `_poll_firebase_threat` (`:1735-1749`) stands them to at 2 men inside 90 m
  (`FSB_THREAT_MEN 2`, `:1180`) — and `garrison_alarm` (`:1871-1876`) stands them to on the first audible
  ENEMY GUNSHOT/EXPLOSION within 120 m of centre (`civilian.gd:452-458`). The enemy mortar's impact emits
  team-1 EXPLOSION noise (`siege_director.gd:1223`); first volley at 12-20 s (`:109-110`). **The maximum
  withholding is one mortar timer.** Not felt.
- The SD's version (warm → a toast 73 s early) IS felt, but see 3.4: warm is nearly unreachable.
- **Does it punish a player who never went near the ville?** No — under every model a player who was
  never seen and never fired is `quiet`/`open` and gets today's behaviour. But the writer's `open` default
  gives the EARLY warning to a player who skipped the village entirely (informer never answered = open,
  `writer.md` §1b); the SD's `warm` requires being within 40 m clean (P3'). **Two architects, opposite
  defaults for the same player; the discussion merged them as if they agreed.**

### 3.3 Fire discipline fires on the player's own defence (false positive)
`civilian._on_noise` (`civilian.gd:459-465`) tests type and 60 m — **not team, not whether an enemy was in
the ville.** `EvidenceLedger.on_noise` (`evidence_ledger.gd:56-62`) filters team 0 = player side, nothing
else. The informer's four responders spawn 90-140 m from where he saw you (`field_director.gd:807-816`) and
sweep his last-seen spot — **the game sends enemies INTO the village and then records the player's return
fire as `fire/village/<hash>`.** So the one built H&M edge (the informer) produces the false positive for
the first new producer. `_call_for_aid` (`:470-485`) already has this shape — shooting starts, the village
becomes a crisis — and the crisis is a REWARD (relief, P4). The same shots are P3 (cold) and P4 (warm).
ADR-038 §4 says fire discipline near a ville IS allegiance; ADR-019 §3 says burning it must genuinely pay.
Neither says returning fire at men the game sent is arson. A producer that cannot tell the difference is a
morality meter with a wrong answer — the PS2 thing ADR-019 rejects by name.

### 3.4 The informer: the ruling becomes a binary the player cannot see
- The demo ALWAYS seeds one (`mission_generator.gd:1297-1301`). He must SEE you at 15 m + LOS
  (`civilian.gd:531-535`); 25 s later he is gone (`:539-548`).
- **Shooting him inside the 25 s is a noncombatant death**: `_record_noncombatant_death` (`:1116-1124`)
  exempts only `is_garrison` and men out of the `civilians` group; `_transform_to_vc` (`:1163-1166`) drops
  him from the group only AFTER he has talked. The code's own comment says so: *"A revealed informer is a
  combatant now"* — revealed = already gone. So the writer's producer #1 ("the player saw the runner and
  stopped him (any means)") is the SD/GD's P2 `civ_killed` → cold. **Same act, opposite sign in two
  analyses.**
- Therefore `warm` = walk within 40 m of the centre and never be in one man's 15 m LOS, on a free path, for
  the whole visit, with no way to know which man. That is a stealth check against an unmarked target, and
  ADR-038 §2 says the world must be readable. The village's demo-day outcome is decided by one villager's
  schedule crossing the player's path — a coin flip by another name, which is what the 2026-08-03 ruling
  ("a coin flip on the demo's central idea is a dice roll on the shop window") removed.

### 3.5 Determinism — every Time/randf on the paths the producers and consumers touch
| where | draw | on which path |
|---|---|---|
| `field_director.gd:803` | `hash(from_pos) ^ int(Time.get_ticks_msec())` | P1 informer response — the SD found it; the fix is one line |
| `civilian.gd:467` | global `randf()` FLEE/COWER | P3 fire-near-ville noise branch (the producer fires regardless; the villager's reaction rolls) |
| `civilian.gd:1082` | global `randf()` | P2 — a wounded civilian's reaction |
| `field_director.gd:176, :206-212` | `randf_range` ×4, `randi_range` | the hunter-cadence consumer inherits an unseeded timer, count, bearing and offset |
| `pilot_recovery.gd:45, :76, :99, :175` | unseeded `_rng` — crash site, wreck yaw, pilot face | P3 pilot; the crash SITE decides the escort's length (§3.1) |
| `zpu_gun.gd:230` | `_rng.randf() >= KILL_CHANCE` | the shoot-down itself (GD's guarantee bypasses it) |
| `field_director.gd:1907` | `randf_range(2,5)` siren delay | C-E cosmetic |
| `siege_director.gd:205, :321, :330, :547-560` | `_rng` seeded from centre | assault — deterministic, fine |
| `Time.get_ticks_msec()` at `field_director.gd:20, :24, :37, :171, :189`, `friendly_patrol_group.gd:123` | wall-clock TTLs | relative; fine under the honest scope |
The demo declares ambient RNG honest (`demo_game.gd:9-11`). But a LEDGER consumed by a schedule and by the
assault's warning is not ambient; ADR-010 says anything that "persists, saves, scores, or affects
generation" draws from the seed. The hunter-cadence consumer is out of bounds as proposed.

---

## 4 · THE EARNED COMPANION — a garrison man in the squad

- **Does `SquadSystem` accept a ninth?** `_stand_up_member` (`squad_system.gd:110-141`) appends with no cap;
  `SQUAD_SIZE 8` is applied only in `setup` (`:71`). Yes, mechanically.
- **Does the roster save him?** Only if his dict is appended to `CampaignState.roster`. If it IS (TD's
  adopt): `SquadRoster.vacancies()` = `SQUAD_SIZE − living` (`squad_roster.gd:206-211`) → 8 − 9 = 0, and when
  a REAL squad man dies it is 8 − 8 = 0: **no replacement bird for a genuine KIA while the ninth man lives.**
  His 2026-08-28 ruling ("smallest squad you get handed back is 4 more", `field_director.gd:2143-2145`)
  silently stops. If it is NOT appended: his death enters `squad_kia` (`squad_system.gd:815-819`) and is
  read at the wire and on the butcher's bill (`field_director.gd:2165-2179`) as a squad man — which he is
  not, by the handoff's own "do not equate everybody fighting beside the player with everybody joining".
- **Stand-to:** `_garrison_stand_to` iterates `firebase_garrison` Civilians (`field_director.gd:1817-1830`);
  a squad AllyBase is untouched. He FOLLOWs — he is "at your position" by default, not by choice. The
  chosen branch is today's behaviour. **The REFUSED branch is the broken one:** the SD's "GarrisonDefender
  .promote takes him home" cannot — `promote` takes a Civilian (`garrison_defender.gd:26`). The only
  AllyBase → Civilian door is `stand_down` (`:119-165`), which reads `garrison_occupation` (default
  **"cook"**), `garrison_home` (default ZERO → home = where he stood), and respawns a `GARRISON_MEN` body.
  A man stood up through `_stand_up_member` has none of those metas. **The man who refuses you becomes a
  cook standing at the wire, and at stand-to `promote` regenerates his `member` from `_seeded_rng(stand)`
  (`:72`) — a new name.** The writer's "the nameplate tells you who did not come" shows a stranger. This
  is F10 (`handoff` §4 F10) exactly, and the proposal walks into it on the branch that is supposed to be
  the consequence.
- **Does his absence break a post?** Points are dealt without replacement (`mission_generator.gd:1305`);
  the census printed *35 posts planned, 36 men placed* (§9 log `:266`). One empty post all day is invisible
  in 36 and the census asserts no count. Not a break — but the "one man per work point" ruling now has a
  work point with no man, on purpose, and nothing marks it.

**Sacrificed:** the replacement loop OR the butcher's bill (pick one); a ninth near-tier body (+1/8 of the
allies' 9.5% siege share, `PERF_LEDGER.md:3579`); and the RPG premise is shown by a man whose refusal the
code cannot represent without a new door.

---

## 5 · ADR-038 §2a — the writer's lines, audited against the law myself

The law (`ADR-038:96-104`): SUBJECT yes; QUANTITY, RATE, DIRECTION OF CHANGE no; and *"a line that lets the
player score his last patrol has rebuilt the meter."* The ADR's own §2 worked sample (`:56-62`) is legal by
definition and the writer's four `shut` lines are that sample nearly verbatim — "gone quiet", "since you
went through", "Saigon prices now" are all in `:56-62`. Those pass by precedent.

**The one that names direction, and it is not in the sample:**
> `HQ: S2 SAYS THE VILLE'S STILL TALKING TO THE ARVN. KEEP IT THAT WAY.`

"STILL" asserts the direction of change (held); "KEEP IT THAT WAY" tells the player his last patrol scored
positive and instructs him to repeat it. That is the meter with a face. Cut "KEEP IT THAT WAY" and it passes.
Runner-up: `LIFER (shut): ... NOW THEY KNOW WHICH SIDE WE'RE ON` — "now" is a direction, but the sample's
"they finally figured out" is the same claim, so precedent covers it.

**The second finding is worse than the line:** three architects wrote three different guards. The writer's
regex (`writer.md` §1c) has no SINCE/NOW/NOBODY; the GD's (`game_designer.md` §3) includes `since you`,
which would FAIL the ADR's own legal example (`:99`); the SD's (`systems_designer.md` §2.7) has `again|since
last`. One law, three tests, and one of them red-lines canon. The test must quote `ADR-038:99-103`'s
illegal list literally and nothing more, or it will be argued with every line.

---

## 6 · THE TRUTH LAW AND THE STORE PAGE — what may be claimed after this ships

ADR-038 §5: *"no doc, comment or store page may call it a readout."* GAME_GUIDE §8 (`:26`): *"the ADR-029
open-patrol identity ships as ROADMAP. The store page says so."* After the converged proposal ships, with
one village, one day, one ledger:
- **May be claimed:** "one village on one day"; "the men you walk out with notice what you did"; "a village
  that remembers the morning" — subject only, and only once the paddy consumer is verified by HIS playthrough
  (ADR-015 — never by a probe).
- **May NOT be claimed:** "Hearts and Minds system"; "dynamic reputation"; "the world reacts to your
  choices"; "villages turn against you"; "earn your squad" (one man, one binary, and the refusal branch is
  a cook — §4); "15-minute siege" (§0); "your actions change the war" (ADR-019 §3's rate-of-recruitment does
  not exist and a set has no rate — the GD says so, `game_designer.md` §4).
- **The trap:** the moment `HmLedger` exists, ADR-038 §5's sentence "there is no province value to read" is
  false and the truth law LETS a doc call the factions a readout. One village ≠ a province (ADR-017). The
  honest sentence after this ships is "there is one village value for one day, and four canned men read it".

---

## 7 · THE CHEAPEST FIRST MOVE, AND THE CHANGE THAT WASTES THE MOST IF WRONG

**Cheapest, unlisted:** measure what ends the night today (`--stress=assault`, read the `[DEMO] the raid ended`
line, `demo_game.gd:673-676`) and read `PERF_LEDGER.md:3481`. Zero code. If it says `broken` at ~180 s —
and the ledger says it will — the cap edit is aimed at the wrong constant and the 45-minute clock is
derived from a fight that lasts 2.5 minutes. Second cheapest, also unlisted: fix `demo_game.gd:35-36` (the
`mission_weather.gd:40` drift) before anyone else derives a ratio from it.

**Most wasteful if wrong:** the clock re-pin (27/12, PROBE 1740, SIEGE 1800, backstop 3000, `test_demo_arc`
rewritten, seven air beats retimed, `_stress_boot_hour` moved, five comments corrected) built on a
14-minute assault the break rule ends at ~2.5. Get it wrong and every number is re-derived a third time
(38x was the second), the arc test is rewritten twice, and the measured siege rows in the ledger stop being
comparable — for a demo that ends at minute 33.

---

## 8 · WHAT SURVIVES

- **Owner and shape** (TD/SD): a `RefCounted` ledger of deeds with stable ids, `consumed` as the whole
  idempotency, NOT `DynamicMissionFactory._seen`, NOT `MissionState` (the bank replaces it, `:2136`). Sound.
- **The informer Time-seed fix** (`field_director.gd:803`). One line, overdue.
- **The reserve stocked at the WARNING beat** (TD §5) — a measured win (`PERF_LEDGER.md:3521-3536`), and it
  needs no ledger.
- **A visible dusk on the walk home** — any ratio ≤ 30 buys it.
- **One consumer, wordless, on a schedule** (the paddy) — sound in shape, but its felt-ness is unproven
  (§3.1) and its producer has a false positive (§3.3). Ship it with `civ_killed` as the ONLY cold producer
  and leave fire discipline for a village that has an enemy-in-ville test.
- **The pilot at the ward door on HOLD** (GD C-A) — built chain, one listener, no roster, no ninth man. The
  cheapest ally consumer in the council and it walks around §4 entirely. Its cost is the unmeasured escort
  length (§3.1) and a guarantee that must also suppress the DOOR (`ambient_encounters.gd` exclusivity) or
  silently fail — the GD priced that.

**Does not survive as written:** the 900 s cap as the door to 15 minutes (§0); the withheld warning (§3.2);
the informer's fate as the village producer (§3.4); the garrison man's refusal branch (§4); the HQ-open
line (§5); three guards (§5).

---

## 9 · THE PROBE — `--stress=assault`, headless, `--test-save`, 230 s wall cap (2026-09-13)

Log: `scratchpad/stress_assault.log`. Boot: seed 29072026, seated 20:10 NIGHT, probe at 20 s, 45-man
reinforce at 45 s (`:509-510, :1146, :1730-1731`). Garrison stood to 36 + 4 late (`:1480, :1681`). Reserve
34 of 34 pre-built (`:1729`). At 60 s the wave cap held six cells at the ring at cap 12 (`:2071-2076`) — the
ramp doing what it was built to do.

**Result — the wall cap cut the run before `[DEMO] the raid ended`, at about arc 200 s (~155 s into the
assault; the +150 s air beat had fired, `:2333`).** What the log shows up to the cut:
- cap 26 at ~75 s in, cells released from the ring (`:2263-2265`);
- press wave 13 (~104 s in): `siege_assault_3` rushing, **7 of 11** men crossing (`:2286`);
- press wave 17 (~136 s in): `siege_assault_1` rushing, **1 of 11** men crossing (`:2323`);
- `_reaim_stalled` firing on single men from ~140 s in (`:2326-2339`) — the post-break shape the 9/11
  synthesis describes, not a 480 s wall.

**The run did not reach the stopwatch and was not going to.** A rushing squad down to one man at 136 s is
an assault at the edge of the 42.5% break; the ledger's *"breaks at t+139 s / 22 down"* (`PERF_LEDGER.md:3481`)
is consistent with this run and stands as the measurement of record. I did not see the break line and do not
claim its second. A run with a 300 s wall cap, serially, would print it; the 3-minute rule forbade it tonight.
