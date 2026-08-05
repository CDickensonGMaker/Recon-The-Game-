# DEVIL'S ADVOCATE — 2026-08-04 FULL AUDIT

Independent sight. No other architect's output read. Every claim carries a pointer or names
the measurement that would settle it. NO CODE was written.

---

## 0. THE HEADLINE: THE DEMO'S CLOCK IS A LIE, AND EVERYTHING DOWNSTREAM OF IT IS WRONG

**The 06:30 start never happens. The demo starts at 17:30, DUSK.**

The chain, each link verified by reading:

1. `demo_game.gd:100` calls `_flow._begin_operation(DEMO_SEED, DEMO_NAME)` **without await**.
2. `_begin_operation` (`game_flow.gd:490-494`) calls `enter_hub()`, a coroutine whose first
   suspension is the `while not world.is_world_ready: await` loop at `game_flow.gd:591-592`.
   Control returns to `demo_game._ready` **the moment the world node is instanced**, minutes
   of build still ahead.
3. `demo_game.gd:103` then runs `SimClock.set_time(1, START_HOUR)` — **mid-build**, not
   "AFTER the build" as its own comment at `demo_game.gd:101-102` claims.
4. The build resumes, and at `game_flow.gd:677-679` `weather.setup(world, plan.weather,
   plan.time)` executes — **after** step 3 — and `mission_weather.gd:51` does
   `SimClock.sim_hour = TIME_ID_START_HOUR[time_id]`.
5. The demo plan's time_id is **`"DUSK"`** (`mission_generator.gd:673`, a fossil of the dead
   7-minute dusk slice that nobody repointed). `TIME_ID_START_HOUR["DUSK"] = 17.5`
   (`mission_weather.gd:40`).

So the player spawns at **17:30 in dusk light**, not 06:30 in dawn light. Now run the decree's
own arithmetic (`sim_clock.gd:45`: sim advances `delta * ratio / 3600` hours) at DAY_RATIO 38
(`demo_game.gd:42`) from 17.5:

| Real time | Sim hour | What happens | Pointer |
|---|---|---|---|
| ~2:22 (142s) | 19:00 | **NIGHT falls** (`sim_clock.gd:62-64`) during the "morning" walk-out | `mission_weather.gd:80-83` |
| ~10:16 (616s) | 24:00 | **MIDNIGHT ROLLOVER** — the exact event the entire rescope exists to avoid: `sim_day` increments (`sim_clock.gd:46-48`), which resets `_rolled_this_night` (`siege_director.gd:171-174`, re-arming a random second siege roll) and re-arms the once-per-day fire-support allotment (`field_director.gd:981`) | |
| ~18:09 (1089s) | 05:00 | **DAWN** — the sun the decree killed comes up anyway, mid-"day" | `sim_clock.gd:58-59` |
| ~21:19 (1279s) | 07:00 | **DAY** — full daylight | |
| 23:00 (1380s) | 08:04 | The "night" seam fires: `[DEMO] night at 1380s`, ratio drops to 20x — **in morning sunshine** | `demo_game.gd:351-355` |
| 24:00 (1440s) | ~08:24 | **"HERE THEY COME" — the night assault opens in broad daylight**, illum flares against a blue sky, `MissionWeather.is_night == false`, night sight caps off | `demo_game.gd:362-364` |
| 30:00 (1800s) | ~10:24 | Gunships circle a mid-morning firebase; the fight the card calls a night held ran at breakfast | |

**Every one of the four lighting events lands on the wrong beat, in the wrong order.** The
walk out to the village happens in darkness (minute 2 to minute 18); the climax happens in
daylight. The three exploits the decree paid the DAWN card to avoid — second siege roll,
allotment re-arm, sun rising during the attack — **all three are armed** by the midnight
crossing at ~10 minutes. The backlog entry ("06:30 start... set_time after the build",
`DEMO_SHIP_BACKLOG.md:570-572`) records the author's intent, not the code's behavior. The
codebase beats the document, and here it beats the document that was written the same day
as the code.

**Fair caveat, stated because the Pointer Law cuts at me too:** this is a reading of
coroutine ordering, not a run. It is exactly the class of claim a measurement must settle —
see NEW MEASUREMENT M-6 in §5. But note the reading requires only two facts: `enter_hub`
awaits before `weather.setup`, and nothing calls `set_time` after `mission_weather.gd:51`
(grep: the only demo-path writer of `sim_hour` after boot is `mission_weather.gd:51`; the
only demo `set_time` is `demo_game.gd:103`).

---

## 1. THE STRANGER TEST — walking the 30 minutes as wired

Assume M-6 fails as read above; where noted, the beat is judged under BOTH clocks (broken
DUSK clock / intended 06:30 clock).

### 1.1 Minute 0-2: the opening
- Spawn on a cot. Air package opens at 3s (`demo_game.gd:129-136`) — genuinely good.
- T+10: "SQUAD MOVING OUT" toast and 8 men walk to the gate (`demo_game.gd:299-307`).
  **The release condition is ALL living members inside 8m of one point simultaneously**
  (`demo_game.gd:309-319`: `arrived < alive` blocks release). Eight avoidance-radius
  CharacterBodies converging on an 8m disc around a gate marker, through compound props —
  if even ONE man rubber-bands outside 8m, the squad stands frozen at the gate in MOVE_TO
  for the full 210s (`GATE_ORDER_MAX_S`, `demo_game.gd:281`) while the stranger walks out
  alone wondering why his squad is statues. M-4 covers arrivals; **it does not cover the
  release-lag distribution**, which is the actual player-facing failure.
- **Trap inside the release:** the timeout sweep resets **any man in MOVE_TO** to FOLLOW
  (`demo_game.gd:321-324`). If the player issues his own squad move order during the first
  3.5 minutes and that order is also `OrderMode.MOVE_TO`, the arc silently cancels the
  player's command at timeout. A stranger reads that as "orders don't work."

### 1.2 Minute 2-5: the walk out
- Under the broken clock: **night falls at 2:22**, the stranger walks to the village in the
  dark with vegetation sight caps. Under the intended clock: DAY snaps on near the gate —
  the decree's best beat, and it works only if M-6 passes.
- First-signs now real (`mission_generator.gd:728-738`), camp real (`:759-772`), village
  real. Good.
- **The ambient cell of §2.5 was never built as ruled.** The wiring note substitutes the
  pre-existing `ambient_patrol_%d` LazyGroups (`mission_generator.gd:805-819`,
  `DEMO_SHIP_BACKLOG.md:582-584`). Three constraints the council attached, none satisfied:
  (1) no >90m road keepout vs `FSB_THREAT_M` 90 (`field_director.gd:968`) — patrol circuit
  legs are free to cross the threat ring, and two men inside it stand the whole 40-man
  garrison to (`field_director.gd:1340-1353`) during the "quiet" opening; (2) the cells are
  **not tagged "hunters"**, so no night arithmetic could ever fold them in; (3) they do not
  satisfy ruling 9 — see 1.4.

### 1.3 Minute 5-20: the day — THE ARC'S QUIET DEATH
- The hunt net is the only reactive system out here, and its pool is **12 men, never
  topped up** (`field_director.gd:106`; grep shows `_hunter_pool` is written exactly twice:
  init and decrement at `:162`). **The decree's §2.9 ruling — top the pool to 6 on each
  outbound gate crossing — was NOT wired.** The 8/4 backlog does not list it as open
  either. A player who fights at minute 6 empties the AO by minute 13 and walks the rest of
  the day in a dead world; a player who stays quiet was never hunted at all (evidence-gated,
  `field_director.gd:127`, `:155-157`). Either way: **minutes ~14-23 have zero authored or
  reactive content** — the beat sheet itself shows nothing between "village in sight ~4:00"
  and the 1380s stand-to except a DUSK light change.
- **The informer is still a coin flip.** §2.6 RULED "force it to 100% in the demo";
  `mission_generator.gd:1010` still reads `if rng.randf() < 0.5 else -1`. The demo's
  central village idea appears on half of all boots. NOT wired, not listed as open.
- **The day feeds the night NOWHERE.** `SIEGE_STRENGTH` is a const 45 (`demo_game.gd:68`);
  no hunters-killed subtraction, no tunnel-mouth −8, no RTO gate line, no breach/no-breach
  differentiation. The decree's own escape clause ("if all three are not built, DO NOT
  BUILD THE LINK", synthesis §2.8) makes this legal — but then the honest statement is:
  **in this demo, nothing the player does before minute 23 changes anything after it.**
  The one-day-arc's entire thesis ("the day is the only thing that turns on...", 
  `demo_game.gd:28-32`) is scenery.

### 1.4 The false-positive / false-negative toast audit
| Toast | False positive | False negative |
|---|---|---|
| "YOU'VE BEEN MADE" (`field_director.gd:131`) | Fixed 8/4 — now evidence-gated (`:127`). Good. | **A player SEEN but silent is never 'made'.** The ledger is fed only by player noise (`field_director.gd:35-37`); visual detection by a walking patrol produces combat with no alarm and no hunters ever. Ruling 9 ("a hunter patrol must be able to hit the player any time outside the wire") remains structurally impossible — the 8/4 wiring did not touch it. |
| "SQUAD MOVING OUT" (`demo_game.gd:306`) | Fires whether or not the squad can path (order issued blind). | — |
| "GUNSHIPS ON STATION - GET YOUR HEADS DOWN" (`demo_game.gd:424`) | **Nothing fires.** No door gun by ruling (`air_traffic.gd:250-257`). A warning toast about incoming friendly fire that never comes. | — |
| "PROBE ON THE WIRE" / "HERE THEY COME" | Under the broken clock: announced in daylight. | If a random `_maybe_open` roll (`siege_director.gd:186-188`, armed once `patrol_count ≥ 1` and night — reachable in-arc) opened a siege first, the probe toast covers a `reinforce(maxi(1, ...))` of as little as **1 man** (`demo_game.gd:397`). |
| "X HAS THE RADIO NOW" (`squad_system.gd:603`) | Reads as pure gain. **It is silently a trade** — see §2.3. | No toast tells the player what he LOST (his medic, his thumper). |

### 1.5 Minute 23-30: the climax and the ending
- Probe 11 at 1395s, assault to 45 at 1440s — wired, `reinforce`/`open_siege` branch logic
  is sound including the broken-probe re-open (`siege_director.gd:200-210`). Credit where due.
- **The break can land early and nothing refills the stage.** `_run_siege` breaks on
  `live/peak` vs `BREAK_BASE_RATIO 0.575` (`siege_director.gd:384-386`, `:30`) — the
  assault breaks at roughly 19-20 dead of 45, against a 40-man garrison + 8-man squad +
  player + SEVEN authored air beats (`demo_game.gd:187-195`). If it breaks at, say, 1600s,
  the demo's last 3+ real minutes are **dead air**: survivors reaped and marched off, while
  `SIEGE_AIR_BEATS` keeps bombing the empty treeline on the wall clock
  (`demo_game.gd:213-218` gates only on `_clock`, never on `siege.active`) — CBU and
  "LAST PASS - EVERYTHING THEY HAVE" on nobody. No measurement covers break-time
  distribution (NEW M-9).
- **The "circling gunships" last image is ~0-5 seconds of circling, then a freeze-frame.**
  Launch at 1800s from `ORBIT_INBOUND_M 330` (`air_traffic.gd:247`); the ship must fly to
  the FAR side of the circle first (`:289`, entry+PI ≈ 460m of flight at ramped Huey speed,
  ~10-12s) before `orbit_in` even completes. The end card lands at +12s
  (`GUNSHIP_HOLD_S`, `demo_game.gd:410`) and `GameManager.pause_game()`
  (`demo_game.gd:445`) freezes the world — `world.process_mode = PAUSABLE`
  (`game_flow.gd:585`) and AirTraffic lives under the world. `ORBIT_SECONDS 75` of circling
  exists for an audience of nobody. His R1 ruling is delivered as a still photograph of two
  Hueys arriving. M-5 (pad launch timing) does NOT cover this — NEW M-8.
- **Fossil text on the death card:** "YOU FELL BEFORE DAWN" (`demo_game.gd:434`) — the dawn
  the decree killed. And "RESTART THE NIGHT" (`demo_game.gd:460`) reloads the whole scene
  (`:474`) — a stranger who dies at minute 29 presses "RESTART THE NIGHT" and gets minute 0.
  Both are one-string lies at the two most emotional moments in the product.
- The KIA-during-hold race IS handled (`demo_game.gd:426-427`). Credit.

---

## 2. THE 8/4 WIRING, ASSUMED WRONG UNTIL PROVEN — findings per item

### 2.1 The 1380s speed seam — WRONG PREMISE, RIGHT MECHANISM
Mechanism is clean: one latch, one direction (`demo_game.gd:350-355`). But under the DUSK
clock it fires at sim 08:04 (see §0), and even under the intended 06:30 clock the comment
"NIGHT snaps on, the garrison stands to" (`demo_game.gd:43`) is drift: NIGHT is a **19:00**
period boundary (`sim_clock.gd:62-64`), which at 38x from 6.5 lands at **1184s ≈ 19:44 of
arc — 196 real seconds BEFORE the seam.** Darkness and "stand-to" are separated by ~3
minutes of unnarrated night. The decree's beat sheet ("~21:00 ... NIGHT snaps on") was
never true in code even before the DUSK bug.

### 2.2 The T+10 gate order — see §1.1. All-must-arrive release + player-order clobber.

### 2.3 The radio MOS reassignment — **THE HEIR'S OLD LIFE IS DELETED**
`_hand_off_radio` (`squad_system.gd:582-603`) picks the **nearest living man** and does
`heir.member["mos"] = "RTO"` (`:601`). His previous MOS is destroyed, and every system that
resolves men by MOS silently loses him:
- **Medic-heir: the player's entire fail-forward dies.** `can_revive()` requires
  `member_by_mos("MEDIC")` (`squad_system.gd:224-226`); revive, restock, resupply, VO all
  route through it (`:236`, `:255`, `:301`, `:316`, `:545`). One RTO death next to Doc —
  and Doc follows close by design — converts ruling R3's Hell-Let-Loose revive into a
  headshot rule for EVERY hit. No toast says so. The next time the player goes down he
  bleeds out reading "X HAS THE RADIO NOW" as his last tutorial.
- Grenadier-heir: thumper and ammo box gone (`:270`, `:459`). Pointman-heir: point scan and
  trap-spot gone (`:420`, `:428`). MG-heir: keeps his 1.6 fire_rate_mult
  (`squad_system.gd:80-81` runs only at spawn) — the RTO now magically fires an M16 at MG
  cadence, and the squad loses its base of fire.
- The fallen RTO's OWN other roles: none (RTO is single-role), so the question in the brief
  has a clean answer — the damage is all on the HEIR's side.
This is r4bk squared: an invisible consequence attached to a positive-sounding toast.
**Cheapest honest fix directions (for the Arbiter, not built here): prefer a rifleman heir,
or make the toast name the trade.** No ordered measurement covers this — NEW M-7.

### 2.4 The ambient-cell / hunter arithmetic — NOT WIRED (see §1.2, §1.3). Three ruled
items missing with no open-items entry: hunter top-up (§2.9), informer 100% (§2.6),
"hunters" tagging (§2.5 constraint 3). Additionally §2.11's ruled ally minimum set:
courage is still a flat `randf()` (`ally_base.gd:295`) so **MOS-weighted courage (item 2)
is unwired**, and grep finds zero concealment term in the cover search (**item 3, "THE
VIETCONG GAP", unwired**). The backlog's "Executes synthesis... including his §8 rulings"
(`DEMO_SHIP_BACKLOG.md:548`) over-claims by at least five ruled items.

### 2.5 `_thaw_held_cells` — MECHANISM READS SOUND, ONE SOFT SPOT
Freeze/thaw pairing is coherent: held = dormant + physics-off (`siege_director.gd:448-479`),
release one at a time under `THAW_HEADROOM 6` with per-cell fit check (`:467-477`). Soft
spot: a cell larger than the available room is skipped **forever** if smaller cells keep
consuming the room first (`:474-475` `continue`) — a 12-man cell can starve behind a stream
of 4-man releases; with `run_strength` counting its paper men, the break ratio still counts
it as alive. Probably self-resolving as men die (room grows), but only M-2 can say.

### 2.6 gun_orbit vs the reaper — THE REAPER IS DODGED, THE PAUSE IS NOT
`orbit_in`/`orbit` are in the settled list (`air_traffic.gd:749-750`) so the 20m arrival
reap (`:755`) is dodged, and `MAX_FLIGHT_SECONDS 240` comfortably holds the ~90s sortie.
Correct. But the fix defends a phase the player never sees — the pause at +12s (§1.5) ends
observation before the orbit's first lap completes. The engineering survived; the
experience did not.

### 2.7 `_bake_gun_only` / corpse cap — not re-verified line-by-line this session; the
backlog's description is plausible and M-3 is the only truth. Flagged: `MAX_WORLD_WEAPONS
24` FIFO means during the 45-man assault, rifles the player is walking toward can vanish
under him as later drops evict them — acceptable, but it is a visible pop the ledger
should expect in M-3 footage.

---

## 3. TIME ARITHMETIC — COMPUTED FROM CONSTANTS (not the backlog)

Under the INTENDED 06:30 start (i.e., if the §0 ordering bug is fixed), at 38x
(`demo_game.gd:39-54`, `sim_clock.gd:45,57-64`, `mission_weather.gd:40`):

| Event | Sim hour | Real arc time | Decree says | Verdict |
|---|---|---|---|---|
| DAY | 7.0 | (0.5h/38)·3600 = **47s** | "~0:55, gate-clear" | Close — but only if the squad+player actually reach the gate in <47s; gate order is issued at T+10 and 8 men need ~30-60s+. Likely DAY snaps while the player is still INSIDE the compound. Cosmetic miss. |
| DUSK | 17.0 | **995s (16:35)** | "~17:00 on the return leg" | Holds. |
| NIGHT | 19.0 | **1184s (19:44)** | "NIGHT snaps on at stand-to (~21:00)" | **False by 196s.** Night light arrives ~3 min before the 1380s seam and probe. |
| Seam (ratio 38→20) | 6.5+14.567=**21.07** | 1380s | "~21:00" | Holds (21:04). |
| Probe | 21.15 | 1395s | after stand-to | Holds. |
| Assault | 21.40 | 1440s | "~23:00 the assault" | **Assault at 21:24 sim, not ~23:00** — decree's beat-sheet label is off, harmless. |
| End | 21.4+2.0=**23.40** | 1800s | before midnight | **Holds — 36 sim minutes of margin.** No rollover, IF the start hour is real. |

So the arithmetic itself was engineered correctly **for a 6.5 start**; the start is what's
broken (§0). One number in the decree was never true (NIGHT-at-stand-to), one label is off
(23:00 assault).

---

## 4. WHAT EVERYONE ASSUMES WITHOUT PROOF — the load-bearing list

| # | Assumption | If false | Covered by |
|---|---|---|---|
| A1 | The demo starts at 06:30 and stays inside one sim day | The entire arc inverts (§0): dark day, daylight assault, midnight re-arms | **NOTHING. NEW M-6** (§5) |
| A2 | Marker dot-suffixes survive Godot import | ~185/198 markers junk; aid station, litter, chow all fiction | M-1 |
| A3 | The freeze latch is defused and assaults can break | Unbreakable siege past the end card | M-2 |
| A4 | An exported build boots and holds ~48 FPS for 30 min with 2.2x air + corpse field + baked world-weapons | Demo unshippable; every FPS claim in the ledger is a 7-min extrapolation | M-3 (the only 30-min run ever ordered) |
| A5 | Compound pathing delivers 8 men to an 8m disc at the gate | 3.5 min of statue squad at the opening (§1.1) | M-4 (arrivals) — **release-lag distribution uncovered; fold into M-4** |
| A6 | A pad-launch path exists and reads at the 0:30 beat | "Birds lifting as he turns the corner" stays fiction | M-5 |
| A7 | Losing the RTO costs only the radio's redundancy | Medic/thumper/point silently deleted; fail-forward dead (§2.3) | **NOTHING. NEW M-7** |
| A8 | The player sees gunships CIRCLING | Last image is a freeze-frame of arrival (§1.5) | **NOTHING. NEW M-8** |
| A9 | The assault lasts until 1800s | Up to ~3 min of dead air + air beats on empty jungle (§1.5) | **NOTHING. NEW M-9** |
| A10 | Ambient patrol circuits stay outside the 90m threat ring | Garrison stands to during the quiet opening; "abandoned base" beat dies | **NOTHING** — fold a `_garrison_stand_to` timestamp into M-6 |
| A11 | The random night siege roll cannot fire inside the arc | A d50 assault lands mid-day-walk under the demo's probe toast | **NOTHING** — armed by `patrol_count ≥ 1` + night (`siege_director.gd:181-188`); log `open_siege` sources in M-6 |
| A12 | The chow hall reads as a warm human beat | It is not in the shipped GLB at all (Jul 26 export, synthesis §2.7); the 21:30 beat is dead air TODAY regardless of M-1 | Blocked on his re-export; M-1 gates |

**Three of the twelve load-bearing assumptions have NO ordered measurement. The single
largest one (A1) is also the single cheapest to measure.**

---

## 5. NEW MEASUREMENTS THIS ADVOCATE ORDERS SPECIFIED

- **M-6 (CLOCK TRUTH — run before all others, minutes of cost):** boot the demo, read the
  boot line (`demo_game.gd:104`) and then log `SimClock.sim_hour`, `sim_day`, and period at:
  player seat, first `patrol_out` flip, 1380s, 1440s, 1800s. Also log every
  `open_siege`/`_maybe_open` and any `_garrison_stand_to` before 1380s. **FAIL if seat-hour
  is not 6.5±0.2, if `sim_day` changes before 1800s, or if the period at 1440s is not
  NIGHT.** Prediction on the record: seat-hour reads ~17.5.
- **M-7 (RADIO TRADE):** kill the RTO with the medic nearest; verify
  `member_by_mos("MEDIC")` and then go down. FAIL if `can_revive()` is false.
- **M-8 (ENDING STOPWATCH):** timestamp `launch("huey","gun_orbit")`, first `orbit` phase
  entry, and `pause_game()`. FAIL if visible orbit time < 20s. (Cheap fix space exists —
  launch earlier or hold the card longer — but that is the Arbiter's call.)
- **M-9 (BREAK CLOCK):** in the M-3 run, log `_break_siege` reason+time. FAIL if the break
  lands more than 60s before END_AT_S on 2 of 3 runs.

---

## 6. THE FULL GAME'S EMPEROR'S CLOTHES — top 3

1. **"The squad is the RPG" (Pillar 4) — the RPG has no actors.** Squad courage is a flat
   `randf()` (`ally_base.gd:295`); MOS is read nowhere in ally AI; allies cannot be wounded,
   only deleted (synthesis §2.11, R9 — asymmetry ACKNOWLEDGED and shipped); MARKSMAN never
   spawns (`squad_roster.gd:64` per synthesis). The stats-and-skills backbone the pitch
   sells (RECON 1982 numbers) currently drives fire-support cooldowns
   (`field_director.gd:489-492`) and little else a player can perceive. The project talks
   about its squad the way the backlog talks about its wiring: the design exists, the
   behavior does not.
2. **"Stealth is an economy" — the economy has one buyer and a 12-coin purse.** The entire
   reactive consequence system outside the wire is a 12-man pool spent 2-4 at a time with
   no refill (`field_director.gd:106,161-162`) and a ledger only the player's NOISE feeds
   (`:35-37`) — visual detection is not evidence, silent kills are not evidence-generating
   events for the faction, and a quiet player experiences an AO with no memory at all.
   ADR-006's "+25 for a contact avoided" is priced against a system that stops existing
   after ~8 minutes of contact. The open-patrol loop's second half is structurally empty,
   demo AND campaign.
3. **"Verified" is a word this project uses for things that have never run.** One export
   has ever existed (briefing:44); the test suite has been red-baselined since 7/27; the
   8/4 rescope is parse-checked only and — measured this audit — silently missing at least
   five ruled items (§2.4) while its backlog entry opens with "Executes... including his §8
   rulings" (`DEMO_SHIP_BACKLOG.md:548`). The medical complex has never once been in the
   running game (synthesis §2.7). The gap between the document-game and the code-game is
   this project's oldest disease (NO MORE DRIFT law), and the rescope, written under that
   law, reproduced it within 24 hours.

---

## 7. VERDICTS

### DEMO
**STRONGEST (survives my attack):**
- The switchboard/save-sandbox discipline (`demo_game.gd:81-95`, `:109-117`) — the demo
  genuinely cannot eat his tour anymore, both holes named and closed.
- The siege probe→assault escalation logic incl. the broken-probe re-open and
  peak-grows-with-strength (`siege_director.gd:192-210`, `:243-249`) — every failure mode
  I hunted was already documented and closed in code.
- The authored air arc + combat-load gate + per-ship ceiling (`demo_game.gd:129-195`,
  `air_traffic.gd:456-480`) — spectacle with a frame-budget conscience.
- The gun_orbit reaper fix itself (`air_traffic.gd:746-755`) — the trap was found before
  it ever ran.

**WEAKEST:**
1. The clock (§0) — one unawaited coroutine + one fossil `"DUSK"` inverts the entire demo.
2. The radio handoff MOS deletion (§2.3) — one death can silently delete the revive system.
3. The unwired rulings sold as wired (§2.4) + the dead-air band at minutes ~14-23 (§1.3).
4. The ending as experienced: freeze-frame arrival, "GET YOUR HEADS DOWN" with no guns,
   "RESTART THE NIGHT" restarting the day (§1.5).

**IMPROVE (value per effort):**
1. Run M-6 TODAY (minutes). Then: fix is one `await` (or set `"time"` in
   `plan_demo_world`) — the highest value-per-line change available to this project.
2. Radio heir: exclude MEDIC (or prefer riflemen) + a trade-naming toast — small.
3. Wire the two one-line ruled items: informer 100% (`mission_generator.gd:1010`), hunter
   top-up at the `_grant_fire_support` seam.
4. Two strings: the death card and the restart button.
5. Hold the end card until the orbit's second lap (or launch the orbit at ~1770s).

### FULL GAME
**STRONGEST:** the enemy side of the ledger — downed/dragged wounded, evidence-led hunting
as a concept, siege break arithmetic, the marker-driven garrison design (IF M-1 passes);
and the project's self-correction machinery (fossil ratchet, pointer law, PERF_LEDGER) which
this audit itself relied on at every step.
**WEAKEST:** Pillar 4's empty actors (§6.1); the one-buyer stealth economy (§6.2); the
verification gap — nothing that matters has run (§6.3).
**IMPROVE:** (1) one full playtest discharges more risk than any ten agent-days — the
bottleneck is and remains HIS run; (2) make visual detection feed the evidence ledger
(one event type) before building any more consequence systems on top of it; (3) MOS-weighted
courage + concealment term — the two smallest changes that make the squad an RPG.

*Law 2, self-applied: this analysis sacrifices depth on `_bake_gun_only`, the chow-hall
schedule internals, and the ally §2.11 item-1 verification (squad_broken feed — partial
wiring exists at `ally_base.gd:98,:1053`; inconclusive without a run) to buy the clock and
radio findings. Those three remain open attack surface.*
