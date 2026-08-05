# GAME-DESIGNER ANALYSIS — 2026-08-04 FULL AUDIT — DEMO READINESS

**Dimension:** the 30-minute arc AS WIRED vs the ten rulings; first 5 minutes; last 30 seconds;
all death paths. Independent sight; no other architect's output read.
**Standing:** NOTHING from the 8/4 wiring has ever run. Every "WIRED" below means parse-checked
code read this session, not verified behavior. Where a claim needs a run, the measurement is named.

---

## 1. THE TEN RULINGS vs THE CODE

| Ruling | Status | Pointer |
|---|---|---|
| R1 gunships circle, player survives, one flag | **WIRED, but the image may not survive its own timing — §3** | `demo_game.gd:62` (`ENDING_PLAYER_SURVIVES`), `:412-428`; `air_traffic.gd:262-344` (`gun_orbit`) |
| R2 headshot ends the demo | **WIRED** | `health_system.gd:203-208` (`force_death`, bypasses revive); chain verified §5.1 |
| R3 HLL revive: full HP, paid in bandages | **WIRED** | `health_system.gd:276-282` (full HP); `squad_system.gd:292-297` (bandage spent), `:10` (6 bandages), `:235-244` (box restock) |
| R4 radio is an object | **WIRED, with a landmine — §4** | `squad_system.gd:566-567`, `:582-603` (`_hand_off_radio`, MOS reassignment, full quality) |
| R5 dual pad | Code half done (dedupe `air_traffic.gd:59`, `_firebase_lzs`); the second pad is HIS export bench, per the ruling itself | — |
| R6 rostered cooks, role look | Half wired, blocked on the GLB re-export + M-1 (backlog §2026-08-04). Wardrobe swap unverified in code this session — I found no `mess_cook` wardrobe application; **probe:** grep the dresser for the chow occupations before claiming the "cook look" exists | backlog `DEMO_SHIP_BACKLOG.md:609-618` |
| R7 fill the hall / three sittings | Three sittings chosen by the Arbiter (backlog `:613`); **his sittings-vs-ceiling ruling is STILL OPEN** (synthesis §8 tail). Blocked on export + M-1 either way | — |
| R8 marker names locked | Done by him mid-council (synthesis R8) | — |
| R9 wounded squadmates CUT | **COMPLIANT** — allies still go HP≤0 → dead, no downed state found (`ally_base.gd` has no downed/dragged path; courage/goal code unchanged) | `ally_base.gd:295`, `:765-806` |
| R10 three bombing runs, all the same | **WIRED** | `field_director.gd:1273-1282` (`{"bombs": 3, ...}` in demo_mode); napalm spectacle billed to nobody: `demo_game.gd:162-195` scripted beats |

**No §8 ruling is CONTRADICTED by code.** Two are endangered by second-order wiring (§3, §4).

---

## 2. THE FIRST 5 MINUTES, AS WIRED (5-minute rule is LAW)

Trace from spawn at 06:30, DAY_RATIO 38x (`demo_game.gd:39-42`). All times real. UNRUN — this
trace is code-reading, and M-3/M-4 plus a fresh-eyes playtest are what verify it.

- **0:00** — spawn on the cot. **The light is the DUSK preset, not DAWN**: `plan_demo_world`
  still declares `"time": "DUSK"` (`mission_generator.gd:673`), `MissionWeather.setup` applies it
  and sets sim 17.5 (`mission_weather.gd:51-52`), and the demo's `SimClock.set_time(1, 6.5)`
  (`demo_game.gd:103`) does **not** emit `time_period_changed` (`sim_clock.gd:103-107`), so no
  re-light happens. Saved only by luck: the DAWN and DUSK presets are near-identical oranges
  (`mission_weather.gd:22-23`). The decree's "spawn in dawn light" is not what is wired.
- **0:03** — a 6-9 Huey pack crosses low (`demo_game.gd:130`, `AIR_OPENING`).
- **0:10** — "SQUAD MOVING OUT": T+10 `MOVE_TO` on `patrol_gate_pos`, release on arrival or
  210s clock, `N/M arrived` print = M-4 (`demo_game.gd:276-328`).
- **0:14** — Huey `lz_cycle` onto the (single) pad. **0:26** F4s. **0:35** napalm on the horizon
  plus toast (`demo_game.gd:162`, `:203-206`).
- **~0:47** — **DAY snaps on.** The real period table is `sim_clock.gd:57-64` (DAY begins at
  7.0, NOT the weather table's 10.0): (7.0−6.5)×3600/38 = **47.4s**. The decree's opening beat
  — day snapping on as he clears the gate — holds, and by the right table.
- **0:48 / 1:10 / 1:35** — Huey, Skyraider, Chinook lz (`demo_game.gd:133-135`).
- **~1:00-2:00** — wire crossing at 120m (`field_director.gd:965`, `:1219-1233`): fire support
  granted — "3 bombing runs, nothing else" print, RTO horn toast.
- **1:20-4:00** — first-signs now real: 2-3 craters at 150-300m on the outbound bearing
  (`mission_generator.gd:728-738`). Village at 185m with 3-4 defenders (`:744-745`), temple 170m
  opposite, camp ~300m (`:759-771`), 2-3 ambient walking patrols (`:805-819`).

**THE HOOK RISK: minutes 2-5 have no authored contact.** Everything guaranteed in the window is
AIR. The village defenders are 185m off-axis and `lazy: false` but stationary; the ambient
patrols are random circuits with 140m activation (`mission_generator.gd:816`) — the council's
ruled "ambient cell crosses your front at ~2:45" (§2.5) was answered by the backlog with
"circuits already ship, do not build a second system" (`DEMO_SHIP_BACKLOG.md:582-584`), but a
random circuit is not an authored crossing. A stranger who doesn't fire may walk a quiet, pretty
3 minutes. Whether that quiet reads as ATMOSPHERE (Pillar 2) or as EMPTY is exactly the kind of
question only his fresh-eyes playtest answers — **measurement: on 5 boots, log time-to-first
ground contact and whether any patrol crosses within 60m of the outbound path in minutes 1-5.**
- Also unenforced: the council's >90m road constraint (§2.5 constraint 1). Patrol anchors are
  lerped gate→village positions with ±120m wander (`mission_generator.gd:808-810`);
  `_poll_firebase_threat` stands the whole garrison to at 2 men near the wire
  (`field_director.gd:969`, `:1340-1350`). **Measurement: min circuit-anchor distance from
  fsb_center on the demo seed; watch for a 07:05 stand-to.**

**The informer is still a coin flip — and on a fixed seed it is a WEIGHTED die already cast.**
§2.6 RULED "force it to 100% in the demo." Code: `rng.randf() < 0.5`
(`mission_generator.gd:1010`), rng seeded from the op seed (`:777-778` chain). With
`DEMO_SEED = 29072026` fixed (`demo_game.gd:15`), the flip is DETERMINISTIC: the demo village
either ALWAYS has an informer or NEVER does, and nobody knows which. **Measurement (minutes):
boot once, print `informer_idx` for the demo seed.** If it's −1, the village-as-the-enemy's-eyes
idea has never been in the demo at all.

---

## 3. THE LAST 30 SECONDS — R1's image is ~2 seconds long

The wiring is faithful and the reaper trap was correctly defused (`air_traffic.gd:746-750`,
orbit phases in the `settled` list). But walk the clock:

1. `_ending()` fires at 1800s, launches the pair, toasts, then waits `GUNSHIP_HOLD_S = 12.0`
   and pauses the world under the card (`demo_game.gd:410-428`, `:445`).
2. Each ship spawns at `ORBIT_INBOUND_M 330` and flies to the FAR side of the 130m circle —
   entry and first waypoint are colinear through the centre (`air_traffic.gd:288-301`), so the
   inbound leg is ~460m at the Huey's 50 m/s (`helicopter.gd:12`) ≈ **9.2s plus the speed ramp**.
3. The card lands at +12s. **The player gets one crossing over the wire at 45m — good — and
   roughly 2-3 seconds of actual circling before the world freezes.** The ruled last image,
   "circling gunships," is in practice a flypast and a freeze-frame; `ORBIT_SECONDS 75` never
   plays. (The pause freezing the flight mid-orbit behind the card is deliberate and fine — the
   problem is how little orbit exists before it.)
4. **And the pair is not guaranteed to exist.** `_dispatch_gun_orbit` returns at
   `MAX_IN_FLIGHT 14` per ship (`air_traffic.gd:272-275`), and the demo's own 42s cadence has
   been feeding 6-9-ship packs all night (`demo_game.gd:138-142`). Nothing reserves slots for
   the demo's one non-negotiable image. **Measurement: print `_in_flight.size()` at END_AT_S
   across 5 runs.**
5. **Quiet-finale risk:** the assault breaks at ~42.5% killed (`siege_director.gd:27-30`,
   `:384-386`) — 45 men, break at ~19 dead, with a 40-man garrison plus the player plus seven
   authored air beats firing into it. If it breaks at minute 26, the gunships arrive over a
   battlefield that went quiet minutes ago. Unmeasured; M-3 covers it if someone watches the
   break time.

End card itself: correct and complete — title by the one flag, the eight named men KIA/HELD,
RESTART/QUIT, war frozen, mouse freed (`demo_game.gd:441-469`). Death-during-hold handled
(`:426-427`).

---

## 4. DEATH PATHS — what the stranger sees

The chain is verified end to end in code: `force_death()` → `GameManager.on_player_death`
(`health_system.gd:267-271`, `game_manager.gd:50-52`) → `player_died` →
`FieldDirector._on_player_died` → `fail_mission("KIA")` → `mission_failed`
(`field_director.gd:29-30`, `:187-202`) → `_on_demo_death` → card "YOU FELL BEFORE DAWN"
(`demo_game.gd:340-345`, `:431-434`). The HUD's own death screen stays out of the way
(`hud.gd:326-331`, `managed_by_flow`). ONE screen for every terminal, all paths:

- **Headshot, any minute** (R2): instant card. Note the synthesis's mitigation ("a retry is a
  different AO") is HALF-true: the seed is fixed (`demo_game.gd:15`), layout identical, only
  ambient RNG varies (`:9-11`). A stranger who eats a round at minute 22 replays the same map.
- **Normal down**: "MAN DOWN! DOC IS MOVING TO YOU (n bandages left)", 30s window
  (`health_system.gd:252`), body hits shave the window rather than kill (`:210-218`), 5s channel
  minus skill, full-HP revive with VO (`squad_system.gd:313-343`). This is the best-built loop
  in the demo.
- **Bandage exhaustion**: `can_revive()` false → `force_death` → card. Doc restocks from a box
  within 6m first (`squad_system.gd:224-244`) — legible economy, correct.
- **Medic dead or out of reach**: "DOC DIDN'T MAKE IT TO YOU." → card (`squad_system.gd:318-324`).
- **RTO death**: handset passes to the NEAREST living man at full quality with a toast; squad
  wipe → "THE RADIO IS GONE - NOBODY LEFT TO CARRY IT" (`squad_system.gd:582-603`). R4 exactly.

**THE LANDMINE — the radio can eat the medic.** `_hand_off_radio` picks the nearest living man
with **no MOS exclusion** (`squad_system.gd:588-597`) and overwrites his MOS
(`:601` — `heir.member["mos"] = "RTO"`). If Doc is nearest — and Doc RUNS TOWARD casualties, so
at the moment the RTO drops in a firefight he plausibly is — then `member_by_mos("MEDIC")`
returns null forever: `can_revive()` fails (`:224-226`), a mid-channel revive aborts as "DOC
DIDN'T MAKE IT TO YOU" (`:316-324`), and **R3's entire fail-forward system silently dies for
the rest of the run.** The next down is the end card, and the stranger will never know why. The
same overwrite deletes the thumper if the GRENADIER inherits (`:459`) or sustained fire if the
MG does. R4's cost was supposed to be paid on squad DEATH, not on a lottery at the first RTO
casualty. **This is the single worst interaction wired on 8/4, and it is invisible until it
fires.**

---

## 5. DECREE ITEMS RULED-AND-NOT-WIRED (not §8, not superseded, absent from the 8/4 backlog)

1. **Hunter pool top-up** (§2.9 RULED: top to 6 per outbound crossing at the fire-support seam).
   Pool is still a one-shot 12 (`field_director.gd:106`, `:161-162`); the seam has no top-up
   (`:1219-1234`). ~7.7 minutes of hunt pressure, then the AO is empty for the rest of a
   30-minute day — the arc-break the council itself named.
2. **Informer not forced** (§2.6) — see §2; one deterministic flip nobody has read.
3. **Ally minimum set, all four items** (§2.11 "RULED FOR THE DEMO"): courage is still flat
   `randf()` (`ally_base.gd:295`); the shared-scorer Context still carries no
   squad_broken/force_ratio (`:781-801`); no concealment term; thumper still automatic
   (`squad_system.gd:457-479`). The Vietcong bar the council priced at ~35 lines total is
   untouched.
4. **§2.8 day-feeds-night**: not built — **compliant**, by the decree's own "if all three are
   not built, DO NOT BUILD THE LINK" clause. Flat 45 stands (`demo_game.gd:68`).

## 6. TWO CLOCK TRUTHS THE ARC'S OWN COMMENTS GET WRONG

The real period table is `sim_clock.gd:57-64` — DAWN 5-7, DAY 7-17, DUSK 17-19, NIGHT ≥19 —
not the weather-table hours the demo's comments and the synthesis cite (`demo_game.gd:34-38`).
At 38x from 06:30: DAY at ~47s (good — the opening beat survives), DUSK at ~995s (16:35 real),
**NIGHT at ~1184s (19:44 real) — 196 seconds BEFORE the demo's declared night seam at
`DAY_END_S 1380`** (`demo_game.gd:43`). Stand-to, darkness sight caps and the garrison's night
posture all start ~3.3 real minutes earlier than the arc says; the ratio drop and the beat-sheet
narration are late to their own night. Not a break — but the pacing doc everyone will tune
against is wrong by a fifth of the day.

Worse: **at NIGHT the siege rolls its own dice.** The SiegeDirector is attached at world build
(`field_director.gd:1104`), so `_maybe_open` runs all day and rolls once at 19:00 sim
(`siege_director.gd:168-188`): LOW threat = **5% chance a RANDOM d50 siege opens ~3.5 minutes
before the scripted probe** — with the DEFAULT 300-500m ring on a 512m map
(`siege_director.gd:20-21`), i.e., cells off the map, the exact geometry bug the demo's override
only fixes at 1395s (`demo_game.gd:376-387`). One demo boot in twenty fights a malformed
unscripted night. The demo's phase logic then merely reinforces it (`:391-399`), so the authored
11-probe/45-assault shape is swamped.

## 7. STRONGEST (demo lens)

1. **One terminal screen for every death, verified chain** — headshot, bleed-out, no-doc, squad
   wipe all land on the same card with named men (§4, §5.1 pointers). No path dumps a stranger
   into a debrief, a death screen, or a hang.
2. **The revive economy** (R3) — window, pressure, channel, bandage count spoken aloud, box
   restock. Complete and legible (`squad_system.gd:222-348`).
3. **The switchboard boot** — save sandboxing both directions, ratio restored on exit, one
   world-build path, everything printed at boot (`demo_game.gd:76-117`). This is how a demo
   scene should be built.
4. **The authored sky** — opening six beats plus seven escalating siege air beats through the
   safety-checked `authored_strike` (`demo_game.gd:129-195`). The climax's spectacle is real
   and budgeted.

## 8. WEAKEST (demo lens)

1. **The ending as experienced**: ~2-3s of orbit before the freeze, and the pair can be cut to
   0 by its own ceiling (§3). The one image he ruled the demo ends on is the least-protected
   thing in it.
2. **The radio-eats-the-medic landmine** (§4) — one bullet can silently delete fail-forward.
3. **Minutes 2-5 are unauthored** — the hook is 100% air; ground contact is probabilistic, the
   hunter pool is finite and untopped, the informer flip is uninspected (§2, §5).
4. **The clock truths** (§6) — night arrives 3.3 min early and 1-in-20 boots roll a malformed
   pre-emptive siege.
5. **Zero runs.** Every line above is reading. The 5-minute rule, the break timing, the pad
   count, the marker suffix — all of it is discharged only by M-1..M-5 plus the runs named here.

## 9. IMPROVE — ranked by value-per-effort

| # | Item | Cost | Value | Sacrifice (Law 2) |
|---|---|---|---|---|
| 1 | **Exclude MEDIC (at minimum) from radio-heir selection**; prefer RIFLEMAN, walk outward | ~0.5h | Protects R3 from R4; the demo's whole fail-forward | The "nearest man grabs it" fiction bends — a rifleman may teleport past a closer Doc. Honest trade. |
| 2 | **Boot-once probe run**: print informer_idx, gate arrivals, `_in_flight` at 1800, night-seam times, first-contact time | ~1h of watching | Discharges four unknowns in this analysis for free | An hour of his or an agent-driven run; nothing else. |
| 3 | **Guarantee the ending**: GUNSHIP_HOLD_S → ~30s, spawn the pair at ~ORBIT_RADIUS+50m, and let `gun_orbit` bypass (or reserve 2 slots under) the ceiling | ~1h | The ruled last image actually plays; R1 lands | +18s where a bored stranger might click through; 2 frames of ceiling honesty spent on the finale. Bypassing the cap is a scoped exception to the "binding on EVERY caller" rule — document it. |
| 4 | **Demo-gate `_maybe_open`** (skip the random roll in demo_mode) | ~0.5h | Kills the 5% malformed-siege boot | The AO stops being able to surprise the demo — correct for a shop window, named here so the full game keeps the dice. |
| 5 | **`"time": "DUSK"` → `"DAWN"`** in plan_demo_world | ~5 min | The decree's dawn spawn becomes true, not lucky | None. |
| 6 | **Force the informer in demo** (§2.6 as ruled) | ~15 min | The village's central idea exists every run | Determinism honesty: one more thing seed-fixed rather than rolled. |
| 7 | **Hunter pool top-up** per §2.9 at the `:1221` seam | ~1h | Pressure survives past minute 8 | ADR-035's finite pool, demo-scoped exception — already priced and accepted by the decree. |
| 8 | **Ally item 1** (pass squad_broken/force_ratio into Context) — the council's ~2-liner | ~0.5h | Squad break is real at the climax | Will read as a bug ("my men left") to a first-timer; council already named this. |
| 9 | Fix the demo arc comments to cite `sim_clock.gd:57-64` and the true seam times | ~15 min | Stops the next tuner aiming at the wrong night | None — this is the NO-DRIFT law applied to the arc's own narration. |

Items 3, 4, 6, 7 are wiring against RULED decree text, not new design. Item 1 is a defect fix.
Nothing above adds a system.

**What I am deliberately NOT recommending** (Law 2, scope): ally items 2-4 (§2.11) — good, ruled,
and cut-rankable below everything above because the demo's squad reads acceptably without them
at night; the §2.8 link — its three-surface precondition is honest and unmet; any chow-hall code
before M-1 and his export.
