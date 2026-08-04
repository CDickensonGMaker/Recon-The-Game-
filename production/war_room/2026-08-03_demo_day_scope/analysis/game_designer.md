# GAME DESIGNER — the 30-minute one-day arc

**Council:** 2026-08-03 demo day rescope · **Lens:** pacing and the player's felt experience.
**Method:** code first. Every claim below carries `file:line`. Where I could not find code, I say so —
that absence is itself a finding.

---

## 0. THE ONE THING THAT REFRAMES EVERY ANSWER

**The player cannot see the clock.** The sun does not track `sim_hour`. `MissionWeather._apply_time`
sets `sun.rotation_degrees.x` to a per-PERIOD constant (`scripts/world/mission_weather.gd:109` immediate,
`:118` eased), and it is called ONLY on a DAWN/DAY/DUSK/NIGHT crossing
(`mission_weather.gd:80-83`), easing over `TIME_EASE_SECONDS = 6.0` (`:41`). The periods are
DAWN 5–7 · DAY 7–17 · DUSK 17–19 · NIGHT 19+ (`scripts/autoload/sim_clock.gd:57-64`).

So across a 0700→1900 day the player sees **exactly two lighting events**: the DAY→DUSK snap at 17:00
and the DUSK→NIGHT snap at 19:00. Between them the sky is a still photograph.

**Consequence for the whole ratio debate:** no ratio makes time feel faster or slower *as time*. The
ratio is felt ONLY as **event density** — how often distant war sounds, how often aircraft cross, how
often villagers change what they are doing, how often camp guards swap posts. That is the real
variable under discussion, and it should be argued in those terms, not in hours-per-minute.

---

## A. THE CLOCK RATIO

### The number

0700 → 1900 is 12 sim hours. Across 23 real minutes (1380 s) that is **31.3x**. One sim hour = 115
real seconds. I recommend **31x, held flat, and NOT accelerated for the night.**

### Why NOT a variable ratio — and the reason is not feel, it is MIDNIGHT

Held at 31x, a 7-minute night runs 19:00 → 22:37. **It never crosses midnight.** Accelerate the night
to the shipped 110x (`scripts/levels/demo_game.gd:42`) and 420 s = 12.8 sim hours: 19:00 → **07:48 the
next day**, crossing midnight AND dawn. `sim_day` increments (`sim_clock.gd:46-48`), and three latches
key off it:

1. **A second siege can roll.** `SiegeDirector._maybe_open` clears `_rolled_this_night` whenever
   `day != _last_sim_day` (`scripts/missions/siege_director.gd:171-174`). It is only reached when the
   siege is NOT active (`:160-163`) — so the moment the first assault breaks, a fresh day plus
   `MissionWeather.is_night` still true (`:175`) re-arms the roll (`:181-188`). The demo's authored
   climax gets a random sequel.
2. **The fire-support allotment re-arms.** `_grant_fire_support` is latched by `_granted_day`
   (`scripts/missions/field_director.gd:1243-1245`), and the comment at `:1240-1242` says in plain
   words why: the wire gate band is 120 m out / 95 m in, "so an unlatched hard assign let a player
   re-arm mid-siege by walking twenty-five metres." After midnight the latch is gone and that exploit
   is live again.
3. **The sun comes up in the middle of the attack.** At 07:48 the period is DAY;
   `MissionWeather.is_night` flips false (`mission_weather.gd:95`) and `SightCap` stops darkening
   sight (`scripts/ai/sight_cap.gd:25`). The demo's own end card says DAWN
   (`demo_game.gd:315-318`) — but the world would have said it first, mid-firefight.

**The player will absolutely feel a variable ratio — as the sun rising during his last stand.** That
is the cheat. Hold one ratio and the whole class of bug does not exist.

### What 31x sacrifices (Law 2)

The sim-driven atmosphere thins by ~3.5x against the shipped demo, because everything ambient is
booked PER SIM HOUR:

| system | booking | at 110x (shipped) | at 31x |
|---|---|---|---|
| `AmbientWar` distant war | 1–3 events per hour (`scripts/ai/ambient_war.gd:62`, hooked to `hour_advanced` at `:44-52`) | ~1.8–5.5 / real min | ~0.5–1.6 / real min |
| `AirTraffic` transits | `TRANSITS_PER_HOUR = 3` (`scripts/ai/air_traffic.gd:62`, seeded `:93-104`) | ~5.5 / real min | ~1.6 / real min |
| pad landings | booked at 07/11/15/19 (`air_traffic.gd:105-108`) | 4 across the day | 4 across the day, ~one per 7.7 real min |
| villagers | activity blocks change on the hour (`scripts/ai/civilian_schedules.gd:25-240`) | a village day in 13 real min | a village day in 46 real min |
| camp guards | roles swap on `hour_advanced` (`scripts/enemies/camp_director.gd:44-47`, `:107-112`) | every 33 s | every 115 s |

Two of those five are gains, not losses. Villagers changing job every 33 s is a speed-run; at 115 s
they read as people. Camp guards likewise. **The two real losses are distant war and the sky.**

**Fix the losses at the source, not with the ratio.** The demo already flies its own sky on the ARC
clock rather than the sim clock — `AIR_OPENING` plus `AIR_CADENCE_S = 42.0`
(`demo_game.gd:105-118`), dispatched through the same `AirTraffic.launch` seam
(`air_traffic.gd:212-216`), with its rationale written at `demo_game.gd:96-101`. So the sky is already
immune to the ratio. **`AmbientWar` is not** — nothing overrides it, so the 31x demo loses ~2/3 of its
distant war. That is a one-knob problem (roll on a demo cadence, or raise the per-hour count for the
demo), and it must be on the build list or the quiet AO is the ratio's fault in the playtest report.

### THE BLOCKER NOBODY HAS NAMED: 0700 does not exist in code

Two authorities set the opening hour and **they disagree**:

- `MissionGenerator` sets it at build: DAWN 6.0 · DAY 10.0 · DUSK 18.0 · NIGHT 22.0
  (`scripts/missions/mission_generator.gd:248-255`).
- `MissionWeather.setup` overwrites it later from `TIME_ID_START_HOUR`: DAWN **5.5** · DAY 10.0 ·
  DUSK **17.5** · NIGHT 21.0 (`scripts/world/mission_weather.gd:40`, applied `:51`).

`MissionWeather` runs after the build (`scripts/main/game_flow.gd:677-679`), so **it wins**. The demo
plan asks for `"time": "DUSK"` (`mission_generator.gd:673`) → 17.5 → and that, not `demo_game.gd`, is
why the shipped demo starts at 17:30. `demo_game.gd` sets only the RATIO (`:76`), never the hour.

A 0700 start therefore requires editing BOTH tables (or deleting one — they are the same decision
written twice, which is the drift the fossil law is about).

**Design note while he is in there:** 07.0 is the first minute of the DAY period
(`sim_clock.gd:60`), so a literal 0700 start opens in flat noon-ish light with no dawn at all.
**Start at 06:30.** He boots in DAWN light — the best-looking light the game owns — and the DAY snap
lands ~3 real minutes in, right as the squad clears the gate. Free drama, zero cost, and the demo
still reads as "first thing in the morning." The clock is a fiction he cannot check; the light is not.

---

## B. THE GATE POINTER

### First, the finding: there is no gate pointer in this codebase

`GAME_GUIDE.md:317` and `production/CALEB_TODO_7_22_updated.md:284` both describe the R4 loop as "out
the wire gate on **one diegetic pointer**." I searched for it and it is not there. The only thing that
speaks about where to go is `rebark_patrol` (`field_director.gd:1278-1287`), and it fires from
`_poll_wire_gate` **only after the player has already crossed 120 m outward**
(`field_director.gd:1207-1222`). It tells you where to sweep once you have left. **Nothing points you
at the gate.** (`GAME_GUIDE.md:317` also cites `field_director.gd:602-614` for the AAR bank; the bank
is `_bank_patrol` at `:1564`. Stale pointer — correct on contact.)

So this is not "pick a form," it is "build the thing the checklist has been assuming for weeks."

### The recommendation: THE POINTER IS A MAN

**At boot, the squad forms up and walks to the gate without you.** Three pieces, all already built:

1. **The order verb exists.** `AllyBase.OrderMode` is `{FOLLOW, HOLD, MOVE_TO, RESCUE}`
   (`scripts/allies/ally_base.gd:160`), `set_order` at `:206`, driven squad-wide by
   `SquadSystem._order_all` (`scripts/squad/squad_system.gd:201-205`). The gate position is already on
   the director as `patrol_gate_pos` (`field_director.gd:991`, set in `setup_patrol` `:1086`).
2. **The arrow already renders.** `MissionHUD._update_markers`
   (`scripts/ui/mission_hud.gd:339-368`) draws a floating call-name + metres over any living squadmate
   more than 20 m away. Its own comment (`:336-338`) rules that objective/exfil markers are DELETED as
   rails while squadmate labels stay, because "never lose your team is a squad affordance, not mission
   tracking." That is precisely the exemption this pointer needs — and it is stripped by HARDCORE
   like every other aid (`:317-321`).
3. **The voice already exists.** The pointman speaks through `VOManager.play_squad` in the existing
   bark path (`field_director.gd:1284-1287`), and radio VO is positional off the RTO's PRC-25
   (`field_director.gd:667-673`).

**So the pointer is: your men stand up, sling their rifles, and walk. You follow soldiers.** No new
UI, no tutorial string, no arrow on the ground, nothing that touches ADR-030's deferred period HUD
(which is a LOOK doctrine — `ADR-030:12-17` — and has nothing to say about this). It cannot read as a
tutorial because it does not address the player at all. It is the single most on-pillar answer
available: Pillar 4 says the squad is the RPG and you are IN it. A demo that opens by making you the
eighth man in a column has stated its entire thesis in fifteen seconds.

**Fire it at 0:10, not 1:00.** The Arbiter's sheet puts the pointer at one minute. Under the
5-minute rule, ten seconds of a stranger standing in a bunk wondering what this game is costs 3% of
the window that decides whether he keeps playing. The men should already be moving as he stands up.

### What it sacrifices

- **A rail, briefly.** For ~60 seconds the squad walks an authored line, and that brushes Pillar 3.
  Pay it explicitly: **the order must expire at the gate.** Outside the wire they revert to FOLLOW and
  he is the one deciding from 1:15 on. If he stops, they wait — they must NOT walk to the village
  without him, or the demo plays itself.
- **It is never enforced.** He can shoot, wander, climb the berm, ignore them. The pointer is offered.
  If he goes the wrong way it costs him time and nothing else.
- **The opening is now hostage to pathing inside the compound.** Eight men snagged on the berm or the
  mound IS the opening beat if it goes wrong. **This must be walked before it ships** — boot the demo,
  issue MOVE_TO gate, and count how many of the eight actually arrive. Not vibes: a count.

### The alternative I reject

One toast ("HEAD OUT THE WIRE"). It is cheap and it works, and it is the only pointer that reads as a
tutorial no matter how it is worded, because a line of text at the top of the screen addressed to
nobody in the fiction is a tutorial by definition. The toast queue (`mission_hud.gd:299-306`) should
carry the things it already carries — command's tasking, the radio, crises — not stage directions.

---

## C-adjacent. THE OPENING BEAT: "birds lifting off when he turns the corner"

**Multi-pad concurrency is already built and nobody has used it.** `_firebase_lzs` walks the
`fsb_main` GLB and builds a `LandingZone` for every node whose name starts with `PSPHelipad` or
`fb_helipad` (`scripts/ai/air_traffic.gd:59`, `:467-507`), each with `capacity = 1` (`:500`), and
`_free_pad` iterates ALL of them and returns the first free one (`:510-515`). Two or three
simultaneous landings are legal today. The only reason it has never happened is scheduling: the sim
books one `lz_cycle` at a time (`:105-108`) and the demo books two, 81 s apart
(`demo_game.gd:106,111`). **Multi-pad is a scheduling change plus per-route jitter, not a new system.**

**But the beat as written cannot happen.** Every `lz_cycle` starts the helicopter **airborne at
0.55 × map_size from the pad** (`air_traffic.gd:536-540`) — ~280 m out on the 512 m demo map — and then
flies in, sits `GROUND_SECONDS = 35.0` (`:53`), and lifts. **There is no code path that starts a
helicopter already on the pad.** So "the player turns the corner and the birds lift off" requires
either (a) launching the cycles well before the player has control so they are down by 0:25 —
measurement needed: real seconds from `launch("huey","lz_cycle")` to skids-down at ~280 m — or (b) a
new authored start-on-pad state. (a) is nearly free and I would take it; the birds should be sitting
with rotors turning while he is still getting off the cot.

---

## THE BEAT SHEET — attacked against the 5-MINUTE RULE

### The fatal flaw in §1 as written

`1:30–4:00 out the wire, something to look at by 200m` gives the demo's decisive window **zero enemy
agency, structurally**. `FieldDirector._check_detection` arms the hunt net only when
`EnemyBase.last_combat_contact_ms > _detect_baseline_ms` (`field_director.gd:113-119`) — i.e. only
after a COMBAT contact — and `_process_escalation` returns immediately while `_escalation_active` is
false (`:124`). **No combat, no hunters, ever.** Nothing can happen on the walk out because nothing is
out there to make it happen. "Something to look at" is set dressing; the 5-minute rule is not asking
for scenery, it is asking for a reason to lean in.

### The fix: make it a DECISION, not a sighting

I support the briefing's §G ambient cell, with one design condition: **it must cross his front, not sit
somewhere.** A cell walking a road (`scripts/world/road_network.gd` exists) that cuts his axis at
~250 m around 2:45 gives him the demo's whole thesis in one moment: *let them pass, or shoot.* And
because shooting is literally what arms the hunt net (`field_director.gd:116`), the demo teaches its
own economy with no tutorial text at all. That is the beat the sheet is missing, and it is the
cheapest one available.

### My sheet (23 min of day)

| real | beat | why |
|---|---|---|
| 0:00–0:20 | wake on the cot (`game_flow.gd:649` spawns seated), squad standing up around you | you are a man in a bunk, not a camera |
| 0:10 | **pointer live** — the squad forms and walks | 5-minute rule: before he can wonder |
| 0:20–1:15 | the compound, the corner, birds on the pads lifting, the gate | his own ask, and the one place spectacle is free |
| 1:15–2:45 | out the wire, the ground opens. Hunt net cold BY DESIGN | the quiet is earned only if it is about to break |
| 2:45–3:30 | **THE CROSSING** — the ambient cell on the road. Let pass, or shoot | the decision the demo is about |
| 3:30–6:00 | the village comes into view, the approach, being seen | |
| 6:00–11:00 | the village: civilians, the cache / tunnel mouth, the ambiguity. If he went loud, first hunters land +70–110 s after contact (`field_director.gd:118`) | |
| 11:00–13:00 | the leg to the camp — **this should be the hottest stretch in the demo** | see D |
| 13:00–19:00 | the camp, the destructible tunnel mouth, fire missions 2 and 3 | |
| 19:00–21:30 | the walk home in falling light. The DUSK snap lands ~19.2 real min at 31x | free drama; do not schedule anything over it |
| 21:30–23:00 | **the one crossing back through the wire**, stand-to | homecoming, not an errand |
| 23:00–30:00 | the attack | |

**One trip through the wire, and it is the last one.** That single change is what buys everything
below.

---

## THE MIDDAY RETURN (chow hall) — RULE: DEAD TIME. It is worse than neutral.

I want to be careful here because this is his newest art and it is good. The verdict is about the
BEAT, not the asset.

**1. Nothing in Godot reads it.** `grep` across all of `scripts/` for `chow`, `WB_chowhall`,
`work_eat`, `food_stop`, `work_serve` returns **zero hits** in any behaviour file (the only `chow`
matches are a comment in `civilian_schedules.gd:113` and an unrelated one in `game_flow.gd:697`). The
markers exist in the blend; nothing in the running game has ever looked for them. Today the chow hall
is a room. Walking two minutes home to see an empty room is the most expensive minute in the build.

**2. The return fires the AAR the demo deliberately excluded.** Crossing back inward runs
`_bank_patrol` (`field_director.gd:1223-1225` → `:1564`), which emits, in a burst: `ROUTE: PLANNED n,
WALKED n` (`:1568`), a possible `FIELD PROMOTION` (`:1573`), and `BACK INSIDE THE WIRE - PATROL 1
LOGGED, N KILLS` (`:1578`). That is a debrief delivered as toasts, in a demo whose switchboard sets
`EXCLUDE_DEBRIEF := true` precisely to avoid it (`demo_game.gd:20`).

**3. It makes the afternoon EASIER — measurably.** `_bank_patrol` replaces `state` with a fresh
`MissionState` and resets `start_time_ms` (`field_director.gd:1584-1587`). `field_mult` reads
`state.elapsed_seconds()` (`:132`). So walking home at midday **resets the field clock to zero**, and
the afternoon's hunt cadence reverts to its slowest setting. The midday return does not merely cost
time; it un-tightens the noose in the exact half of the demo that is supposed to be tightening.

**4. He gets nothing back for it.** The second walk-out re-runs `_grant_fire_support`, which no-ops on
the same sim day (`:1243-1245`). No new steel, no new anything — just a fresh sweep bark.

### The condition under which I would change this ruling

The chow hall becomes a genuine beat if and only if:
- the markers are wired and `build(n=5)` has actually been run, so more than one man eats; **and**
- the return is MOTIVATED by something that happened outside — you are carrying a casualty
  (`scripts/world/litter_team.gd` exists and the medical complex is built), or you are handing S2 a
  captured document (`try_intel_stash`, `field_director.gd:1132-1182`, already emits "CAPTURED
  DOCUMENTS - N POSSIBLE POSITIONS MARKED").

Eating is not a beat. **Coming back with a man on a stretcher is.**

### And the better home for the art

Put the chow hall at **21:30–23:00**, not midday. Men eating in the dark an hour before the wire is
hit is the last supper, and it costs the arc nothing because he is walking through the compound
anyway on his way to stand-to. Same asset, same animations, at the one moment in the demo where
watching soldiers be ordinary means something.

---

## D (brief, because the briefing's premise is FALSIFIED and the council should not act on it)

**§D says `field_mult` makes the second half softer. The code says the opposite.**

`field_mult = clampf(1.0 - (mins - 15.0) * 0.02, 0.6, 1.0)` (`field_director.gd:130-133`) is used at
`:148` as `_hunter_timer = randf_range(100.0, 160.0) * field_mult` — it multiplies the **interval
between waves**. A *smaller* multiplier is a *shorter* wait. At 15 min: 100–160 s. At 30 min:
70–112 s. At the 0.6 floor: 60–96 s. The AO leans **harder**, exactly as its own comment claims
(`:129`). **Do not invert this. It is already correct.**

**The real cause of the soft second half is the POOL.** `_hunter_pool = 12`
(`field_director.gd:106`), spent 2–4 per wave (`:149-150`), and `_process_escalation` returns dead
once it hits zero (`:124`). At a 70–160 s cadence that is 3–6 waves — **the AO is permanently dry
after roughly ten to twelve minutes of contact**, which in this arc is the middle of the village
fight. The last third of the day is quiet not because the math softened but because there is nobody
left to send. If the Arbiter wants a tightening arc, the number to touch is 12, not the decay curve.
(Sacrifice of raising it: "you can bleed the AO dry" is a real and good feature — `:103` — and a pool
large enough to last 20 minutes is a pool the player can never empty, which quietly deletes the
reward for fighting well.)

---

## E. DOES THE DAY'S HUNTING FEED THE NIGHT?

**Yes — one arithmetic beats two scenes. But the briefing's own catch is the whole ruling: an
invisible consequence is no consequence.**

`SIEGE_STRENGTH` is already a single int (`demo_game.gd:48`), and the comment at `:44-47` records why
it is 45 and not 50: `LIVE_CAP` is 50 (`siege_director.gd:36`) and an assault authored at the cap
froze its late cells at the ring on 2026-07-28. So the number is *load-bearing*, not arbitrary.

**Two channels already exist to speak it, and both must be used or the link should not be built:**

1. **At the gate, on the final return** — the RTO's set, positional off the PRC-25
   (`field_director.gd:667-673`). One line: *"S2 says there's fewer of them out there than there were
   this morning."* Diegetic, no HUD, and it lands at the exact moment he crosses in.
2. **On the end card** (`demo_game.gd:331-359`), which already prints every named man as HELD or KIA.
   One line above the roster. **The card is the only place in this demo where a number is allowed to
   be a number** — everywhere else the r4bk law is satisfied by voice.

`_on_siege_ended` also already reports the butcher's bill in his own words — "THEY'RE BREAKING - %d OF
%d DOWN" (`field_director.gd:1450-1455`) — so the night's half of the arithmetic is already spoken.
Only the DAY's half is silent.

### The sacrifice, and it is a real one

**A clean, quiet, skilful day earns a SMALLER climax.** In a marketed demo whose best seven minutes
are the siege, the best player gets the least game. That is backwards, and it is the argument against
the link as a raw subtraction.

**So bound it, and make the FLOOR the important half.** 35 / 45 / 55 as the briefing sketches, with 35
defended as "still unmistakably a mass attack" rather than as "45 minus what he killed." The stealth
player must lose nothing he can SEE. He should get the same wall of men and a different thing to be
proud of at the card: **his own dead**, which the roster already lists (`demo_game.gd:344-349`). Fewer
names greyed out is the reward for a clean day. That reward is already built and it is better than a
smaller siege.

---

## SUMMARY OF SACRIFICES (Law 2, collected)

| recommendation | what is sacrificed |
|---|---|
| 31x flat, night not accelerated | distant-war density drops ~3× (`ambient_war.gd:62` is hour-driven and, unlike the sky, has no arc override); needs a demo cadence knob or the AO reads quiet |
| start 06:30 not 07:00 | his stated hour is not the hour on the clock; the fiction and the code diverge by 30 min (nobody can check, but it is a small lie in the map) |
| the squad is the pointer | ~60 s of soft rail against Pillar 3; the opening becomes hostage to squad pathing inside the compound — must be walked and COUNTED before it ships |
| the crossing at 2:45 | one more live cell during the demo's opening minutes, on the LIVE_CAP question §F is already measuring |
| cut the midday return | his newest art (chow hall) does not appear in the demo unless it moves to the 21:30 slot |
| one wire crossing, at the end | he never sees `_bank_patrol`'s AAR — which is correct for this demo and wrong for the full game; do not let the demo's shape become the game's shape |
| SIEGE_STRENGTH floor at 35 | the link is capped, so a truly exceptional day cannot fully defang the night — the consequence is real but bounded, which is slightly less honest than pure arithmetic |

---

## DECISION QUEUE (plain words, for the Summoner)

1. **The demo currently starts at half past five in the evening, and two different files argue about
   what time it should be.** Neither of them can produce seven in the morning. Do you want six-thirty
   (opens in dawn light, the sun comes up as you reach the gate) or a flat seven o'clock (no dawn at
   all)?
2. **Should the clock run at one speed all the way through?** If the night runs faster than the day,
   the sun comes up in the middle of the attack and the game can hand you a second fire-support
   allotment you did not earn. One speed the whole way avoids both.
3. **Nothing points the player at the gate today — that pointer was never built.** I want your men to
   stand up and walk out without you, and you follow them. No text, no arrow. Yes?
4. **The walk to the village at midday is worth cutting.** Nothing in the running game knows the chow
   hall exists yet, and coming home resets a timer that makes the whole afternoon easier. I would move
   the chow hall to just before the night attack instead — men eating in the dark an hour before the
   wire is hit.
5. **Hunters run out.** There are twelve of them in the whole world, and once they are spent the AO
   never sends anyone again. In a thirty-minute demo you will empty it around the middle. Do you want
   more, knowing that "you can bleed them dry" is a feature you liked?
6. **If a clean day means a smaller night attack, your best players get your smallest ending.** I want
   the attack to never drop below a floor, and to pay a clean day in dead friends you did not have
   instead. Agreed?
