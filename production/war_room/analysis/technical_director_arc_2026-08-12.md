# technical-director — THE DEMO ARC: does it hold together

**Date banner: 2026-08-12.** Read-only audit. No file outside this one was modified, no
suite was run, no `.blend` or GLB was touched.

**Method.** Every claim below carries a `file:line` I read today. Claims are tagged
**VERIFIED** (I read the code), **CLAIMED** (a doc asserts it and I could not close it),
or **NO POINTER** (I looked and could not find one — which is itself the finding).

Scope: `scenes/levels/demo_game.tscn` → `scripts/levels/demo_game.gd`, beat by beat.

---

## 0. Verdict in one paragraph

The arc **holds**. Every one of the seven beats has real wiring, the two published
arithmetic claims in `demo_game.gd`'s own comments (`~1184s`, `~616s → ~22:25`) are
**correct to the second**, `SIEGE_STRENGTH 45` genuinely materialises against
`LIVE_CAP 50`, and the gunship ending is genuinely signal-driven rather than
clock-driven. Three things are wrong, in descending order: the **boot spawn has a
fourth, undiagnosed patch nobody has named** — a terrain-dirty reseat that uses
`surface_y` with a 0.5 m tolerance and will stand the player on a hootch roof mid-siege;
the **"DAY snaps on as you clear the gate" claim is off by roughly the length of the
walk** (day fires at T+47 s, not at gate-clearing); and **two of the four switchboard
flags are wired to a `print` statement and nothing else** — a FOSSIL LAW violation an
audit already caught on 2026-07-30 and which was never fixed.

---

## 1. BOOT SPAWN (defect B4) — root cause

### 1.1 The patches, and which one actually wins

There are **four** pieces of code in this chain, not three. Listed in execution order:

| # | Pointer | What it does |
|---|---|---|
| P0 | `scripts/main/game_flow.gd:601` | `world.spawn_player_on_ready = false` |
| P1 | `scripts/main/game_flow.gd:151-219` `_firebase_bunk()` | picks the spawn point |
| P2 | `scripts/main/game_flow.gd:641-643, 663` | decides `seat_on_surface` |
| P3 | `scripts/levels/game_world.gd:457-466` `spawn_player_at()` | applies it |
| P4 | `scripts/levels/game_world.gd:507-525` `_flush_terrain_dirty()` | **re-seats him later** |
| P5 | `scripts/levels/game_world.gd:573-591` `_physics_process()` | 2 s fall-catcher |

**VERIFIED — the order IS deterministic, and nothing undoes anything at boot.**

- P0 disables the `GameWorld`-internal spawn (`game_world.gd:182-186`), so that path is
  dead in the demo. It is not a competing patch.
- P1 has **two** arms. The authored arm (`game_flow.gd:176-184`) collects every node
  whose name begins `spawn_bunk`, sorts by 2-D distance to `fsb_center`, and returns
  `authored[0]` **used exactly as placed — no raycast, no reseat** (its own comment,
  `:154-161`). The `prop_sleep` arm (`:185-219`) is the fallback.
- The authored arm **always wins in the demo**: `scenes/world/firebase_main.tscn:9-13`
  ships `spawn_bunk_01` at local `(-1.610, 3.982, 32.096)` and `spawn_bunk_02` at
  `(-1.267, 4.068, 43.616)`, and `site_planner.gd:698 FSB_MAIN_PATH` instances that
  scene. So the fallback sweep is **unreached in the shipping demo**.
- P2: `spawn_seated = (bunk == Vector3.ZERO)` → `false`. P3 therefore takes the
  `spawn.y` branch: `y = spawn.y + 1.0` (`game_world.gd:458`).

### 1.2 Does the demo boot path use `surface_y` or `floor_y`?

**VERIFIED: NEITHER.** The player's boot Y is the authored marker Y + 1.0 and nothing
probes it. `floor_y()` is called on the player exactly once in the whole repo —
`game_flow.gd:709` — and only when `had_save` is true (`:705`). The demo sets
`EXCLUDE_SAVES` and calls `CampaignState.reset_campaign()` (`demo_game.gd:100-109`), so
`SaveManager.pending_player` is null and `:709` never runs. `surface_y(spawn)` is
evaluated at `game_flow.gd:674` but **only to print the SPAWN-TRUTH line** — its return
value is not assigned to anything.

### 1.3 THE ROOT CAUSE — an asymmetry, not a conflict

The three patches **do not fight each other**. The defect is that the *winning* arm is
the *only* arm with **no floor validation at all**.

- Fallback arm: probes `p+0.4 → p-5.5` and skips any cot with nothing under it
  (`game_flow.gd:206-217`, `BUNK_FLOOR_REACH_M` at `:148`).
- Authored arm: **no probe** (`game_flow.gd:176-184`).

So if `spawn_bunk_01` sits over one of the hootches that ships a visual with no
`-colonly` twin — `game_flow.gd:192-193` states in its own comment *"fsb_main_v3 ships
8 hootch visuals against 4 `-colonly` bodies"*, and `HANDOFF_CODE_FIXES_2026-08-12.md`
FIX 3 repeats it — the player boots **in mid-air over a hole and falls**. That is the
"under the world" half of B4.

Then P5 catches him: `game_world.gd:583-591` fires every 2 s, computes
`surface_y(player.global_position)`, and if he is more than `RESEAT_DEPTH = 5.0`
(`game_world.gd:37`) below it, teleports him to `ground_y + 1.0`. Under a roof,
`surface_y` returns the **roof** (`game_world.gd:404-423`, probes down from
`SURFACE_PROBE_UP = 18.0` at `:428`, first hit wins). So the fall-catcher puts him
**on top of the hootch**. That is the "on top of the world" half of B4.

> **The two symptoms of B4 are one bug.** Fall through the missing floor → get
> rescued onto the roof above it. Nobody has to reproduce two separate defects.

**I could not close the last link.** Whether `spawn_bunk_01`'s XZ actually sits over a
collider-less hootch is a question about `fsb_main_v3.glb`, which I am forbidden to open
this session. **NO POINTER** — that is the measurement this diagnosis still needs, and
`game_flow.gd:741-747` already ships the instrument: boot with `--roof-probe` and
`tools/probe_roof_spawn.gd` attaches. The `[SPAWN-TRUTH]` line at `game_flow.gd:673-674`
answers it on its own: if `asked spawn.y` and `player landed at y` differ, he fell.

### 1.4 THE UNDIAGNOSED FOURTH PATCH — P4, and it is the worse one

**VERIFIED. `scripts/levels/game_world.gd:522-525`:**

```
if player != null and rect.has_point(...player xz...):
    var seated_y: float = surface_y(player.global_position)
    if absf(player.global_position.y - seated_y) > 0.5:
        player.global_position.y = seated_y + 0.5
```

This is the same bug class as FIX 3 and FIX 0d, in a file that has already been patched
for it twice, and **it was missed because it is not a spawn**. Three properties make it
worse than the boot defect:

1. It uses `surface_y`, so under any roof `seated_y` **is the roof**.
2. Its tolerance is **0.5 m**, not 5.0 m. A player standing on a hootch floor is ~1.9 m
   below a roof measured at 2.88 m (`game_world.gd:436-441`) — five times over the
   trigger.
3. The trigger rect is a **merge**, not the individual region:
   `game_world.gd:493-496` merges every `region_rebuilt` into one bounding `Rect2`
   before the deferred flush. A crater 100 m away and a crater 100 m the other way
   produce a bounding box that contains the player's hootch.

And the demo guarantees the trigger. Terrain deformation emits `region_rebuilt`
(consumed at `game_world.gd:179, 492`), and the assault walks 81 mm mortars onto the
compound (`siege_director.gd:45-53`, `MORTAR_WALK_S 180`, dispersion closing 50 m → 12 m).

> **Prediction, stated so it can be falsified in one playtest:** take cover inside a
> hootch during the assault and the mortars will put the player on the roof.

**Fix:** `floor_y(player.global_position)` at `game_world.gd:523`. `floor_y` falls back
to `surface_y` outdoors (`game_world.gd:451`), so open ground is unaffected. One line.

Note `terrain_watchdog.gd:57` — handoff FIX 0d, marked CLAIMED — is **already fixed**:
`scripts/missions/terrain_watchdog.gd:60` reads `world.floor_y(...)`. Do not re-fix it.

### 1.5 Stale pointer in the handoff

`HANDOFF_CODE_FIXES_2026-08-12.md` FIX 3 lists `scripts/levels/demo_game.gd:262` as a
`surface_y` caller to review. **That line is `func _tick_siege_air(...)`.** The real
call is `demo_game.gd:287`, inside `_strike_at`, seating an **air-strike impact point
210 m out in the jungle** (`NAPALM_RANGE_M`, `:212`). That is open ground and
`surface_y` is the correct call. Nothing to do; correct the pointer.

---

## 2. T+10 s SQUAD MOVES OUT, and the garrison day

### 2.1 The gate order — VERIFIED, fully wired

`demo_game.gd:339-387` `_tick_opening()`, driven from `_physics_process` at `:411`.
`GATE_ORDER_AT_S = 10.0` (`:326`). It reads `d.patrol_gate_pos`, set by
`field_director.gd:1280` from `built.gate_pos`, and issues
`AllyBase.OrderMode.MOVE_TO` to every live squad member (`:353-355`), toasting
`"SQUAD MOVING OUT"`.

Three independent expiries, all real: arrival within `GATE_ORDER_ARRIVE_M = 8.0`
(`:365`), a hard clock `GATE_ORDER_MAX_S = 210.0` (`:367`), and the player himself
crossing the wire (`:372-376`). Release hands every man back to `FOLLOW` (`:380-383`).
**This beat is honest** — it cannot become a rail, and `:386-387` prints the
arrived/alive pair so a pathing failure is visible rather than silent.

### 2.2 The garrison day schedule — the handoff's claim is TRUE but MISLEADING

**The handoff says:** *"No GDScript reads `work_med*`/`work_chow*`/`work_medofficer*`.
A friendly-side director does not exist."*

**Half VERIFIED, half wrong.**

**TRUE as stated.** `grep work_med|work_chow|work_medofficer` over `scripts/` returns
zero hits. `work_pos`/`work_clip` are written only by `scripts/enemies/camp_director.gd:104,
127, 130` (VC camp) and `scripts/enemies/sapper_charge.gd:166`. `enemy_base.gd:1697-1699`
is the only consumer.

**WRONG as a conclusion.** A friendly work-marker consumer exists and is load-bearing:

- `scripts/world/site_planner.gd:1028-1053` `_ensure_fsb_markers()` walks the firebase
  GLB, collects every node named `work_*`, strips the prefix and any `_NN` duplicate
  suffix, and caches `[pos, work_type]` into `_fsb_work_markers` (`:1042-1046`).
- `site_planner.gd:1058-1169` `fsb_garrison_plan()` round-robins those markers by type
  into garrison posts, budgeted by `FSB_GARRISON_MAX_MEN = 40` (`:950`) and
  `FSB_WORK_POST_CAP = 24` (`:960`), mapped to occupations through
  `FSB_WORK_OCCUPATION` (`:871-916`).
- `scripts/missions/mission_generator.gd:1036-1102` `_build_firebase_garrison()` stands
  the men up, seats them with **`floor_y`** (`:1084, 1092, 1096` — correct), and calls
  `man.build_bt()`.

**And the day schedule is real and time-driven. VERIFIED.**
`scripts/world/civilian.gd:933-948` `_bt_tick()` re-picks the man's action whenever
`int(sim_hour)` changes, via `CivilianSchedules.action_for(occupation, hour, name)`
(`:944`). `scripts/ai/civilian_schedules.gd:28` is a genuine per-hour table:
`"sentry"` `:108-113`, `"mess_hall"` `:202-207`, `"medic"` `:219-224`, `"detail"`
`:241-246`, `"off_duty"` `:263-268`.

At `DAY_RATIO 38.0` one sim hour is 94.7 real seconds, so the garrison rolls its
schedule roughly every 95 s and gets **~13 rolls** across the day leg. The evening meal
(`civilian_schedules.gd:207`, supper `19.5 + 0.4×sitting`) lands after the night seam
but before the probe — **verified below at §4**.

**What genuinely does not exist:**

1. **No `hour_advanced` consumer on the friendly side.** The three subscribers are
   `scripts/ai/ambient_war.gd:47`, `scripts/enemies/camp_director.gd:46` (VC), and
   `scripts/missions/convoy_spawner.gd:46`. The garrison schedule is **polled per
   civilian**, not directed — which is why there is no cross-man coordination.
2. **The GLB custom properties are unread.** `_ensure_fsb_markers` reads **only**
   `node.name` and `node.transform` (`site_planner.gd:1034-1046`). The
   `work_clip` / `work_posture` / `work_phase` / `face_yaw_deg` extras on the 18 new
   medical markers in `firebase_v3.2.blend` have **no reader anywhere**.
3. **A naming trap, forward-looking.** `FSB_WORK_OCCUPATION` keys the aid station as
   `"med_surgeon"`, `"med_officer"`, `"med_cot"` … (`site_planner.gd:901-903`), and
   `fsb_garrison_plan` seeds the ward off `by_type.get("medic")` (`:1113-1119`). A
   marker exported as `work_medofficer_01` strips to type `medofficer`, misses the
   table, and falls through to `off_duty` (`:1163`) — **silently**. A marker exported
   as `work_medic_01` is what the ward seeder needs. The memory note records these as
   `work_medofficer*`. This does not affect the shipping demo (the medical complex is
   not in `fsb_main_v3.glb`), but it will bite on the next export.

---

## 3. DAY SNAPS ON — the arithmetic does not support the claim

### 3.1 The brief's premise is a misread, and it matters

`mission_weather.gd:40 TIME_ID_START_HOUR := {"DAWN": 5.5, "DAY": 10.0, "DUSK": 17.5,
"NIGHT": 21.0}` is **not** the lighting-transition table. Its only use is
`mission_weather.gd:51`: the hour a mission *opens at* for a given briefing `time_id`.
`demo_game.gd:39-40` calls it "a four-state table that only changes on a period
boundary", which conflates the two.

**The transition boundaries are `SimClock.period_at`, `scripts/autoload/sim_clock.gd:62-69`:
DAWN [5,7) · DAY [7,17) · DUSK [17,19) · NIGHT else.** Lighting changes when
`time_period_changed` crosses one of those (`sim_clock.gd:57-59` →
`mission_weather.gd:80-83` → `_apply_time(..., false)`, a 6 s ease, `:41`).

So the question is not "when is 10.0 reached". **It is "when is 7.0 reached".**

### 3.2 The numbers — VERIFIED

`sim_clock.gd:45`: `sim_hour += delta * real_to_sim_ratio / 3600.0`. From
`START_HOUR 6.5` (`demo_game.gd:43`) at `DAY_RATIO 38.0` (`:48`):

| Boundary | Δ sim-h | Δ sim-s | **real s** |
|---|---|---|---|
| DAY (7.0) | 0.5 | 1 800 | **47.4** |
| DUSK (17.0) | 10.5 | 37 800 | 994.7 |
| NIGHT (19.0) | 12.5 | 45 000 | **1 184.2** |

Add ~1–2 s: the arc `_clock` starts when `mission_failed` is connected
(`demo_game.gd:399` ↔ `game_flow.gd:684`), while `SimClock.set_time(1, 6.5)` runs once
`_in_world` flips (`demo_game.gd:130-134` ↔ `game_flow.gd:749`) — a handful of frames
later.

**So DAY snaps on at T+~48 s.** The squad is ordered out at T+10 s (`demo_game.gd:326`)
and the release clock allows up to T+220 s for them to reach the gate
(`GATE_ORDER_MAX_S 210`, `:331`). At 48 s the player has had ~38 s since the order —
he is realistically still inside the hootch or crossing the compound.

`demo_game.gd:41-42` asserts *"spawning at 06:30 rather than 07:00 means DAY SNAPPING
ON IS THE PLAYER CLEARING THE GATE."* **The wiring does not deliver that claim.** It is
off by roughly the length of the walk out.

**One-constant fix, if he wants the beat as written.** To land DAY at T+120 s:
`(7.0 − START_HOUR) × 3600 / 38 = 120` → `START_HOUR = 5.733`. That stays inside the
DAWN band [5,7), so the `set_time` cross-period constraint at `demo_game.gd:127-129`
still holds and `plan_demo_world`'s `"time": "DAWN"`
(`mission_generator.gd:706`) still agrees. **No other constant moves — but the
NIGHT seam moves with it** (§4), so this is a pacing decision for the Summoner, not a
bug fix I would apply unasked.

*(Consistency check, VERIFIED: `plan_demo_world` sets `"time": "DAWN"` →
`mission_weather.gd:51` seeds `sim_hour = 5.5`, period DAWN; `set_time(1, 6.5)` is still
DAWN, so the silent `set_time` (which does not emit `time_period_changed`,
`sim_clock.gd:107-111`) cannot desync the sun. The comment at `demo_game.gd:127-129` and
the one at `mission_generator.gd:704-705` are both accurate and both guarding the same
real hazard.)*

---

## 4. THE NIGHT SEAM — the comments are correct to the second

**VERIFIED.** `demo_game.gd:415-419` gates the ratio swap on `MissionWeather.is_night`,
which is set only in `mission_weather.gd:95` (`is_night = time_id == "NIGHT"`), reached
via the `time_period_changed` chain at `:80-83`. **The same authority the siege rolls
on** (`siege_director.gd:178`) — the comment's claim at `demo_game.gd:46-47` holds. The
swap is one-shot (`_night_ratio_set`) and never climbs back inside a run.

**The published arithmetic, checked:**

| Claim (`demo_game.gd`) | Computed | Verdict |
|---|---|---|
| `:46` "06:30 at 38x reaches NIGHT … at ~1184s" | 12.5 h × 3600 ÷ 38 = **1 184.2 s** | ✅ exact |
| `:54` "~616 s from the 19:00 seam cover ~3h25m" | 616 × 20 ÷ 3600 = **3.422 h = 3 h 25 m** | ✅ exact |
| `:54` "the arc ends ~22:25" | 19.0 + 3.422 = **22.42 → 22:25** | ✅ exact |
| `:54` "same sim day" | 22:25 < 24:00 | ✅ on the nominal path |

1184 + 616 = **1 800 s = the 30 real minutes** the rescope decreed
(`demo_game.gd:33-36`). The arc is internally consistent.

Derived beat times, night leg at `NIGHT_RATIO 20.0`:

| Beat | arc s | s past seam | sim time |
|---|---|---|---|
| supper (`civilian_schedules.gd:207`, sitting 0) | ~1 274 | 90 | 19:30 |
| PROBE | 1 395 | 210.8 | **20:10** |
| ASSAULT | 1 440 | 255.8 | **20:26** |
| last air beat (`SIEGE_AIR_BEATS` +300) | 1 740 | 555.8 | 22:05 |
| nominal end | ~1 800 | 615.8 | **22:25** |
| hard end (`MAX_DURATION_S`, §5.3) | 1 875 | 690.8 | 22:50 |

**The evening meal lands 2 minutes before stand-to and 2 minutes before the probe.**
`civilian_schedules.gd:200-202` claims exactly that — *"it lands just before the 21:00
stand-to, the last warm human beat before the wire breaks"* — and the arithmetic
confirms it. This is the one place the day schedule and the arc were designed against
each other and they line up.

---

## 5. PROBE 11 → ASSAULT 45 — end-to-end, and 45 really materialises

### 5.1 The chain — VERIFIED

`demo_game.gd:420-433` is the phase machine. Phase 0 → `_open_siege(PROBE_STRENGTH=11)`
at 1 395 s; phase 1 → `_open_siege(SIEGE_STRENGTH=45)` at 1 440 s.

`_open_siege` (`:436-473`) attaches the director if needed
(`field_director.gd:1654-1658` `_attach_siege`, idempotent), overrides the assault
geometry for the 512 m slice (`ring_min 190` / `ring_max 235` / `rally_m 150` /
`cell_materialize_m 120`, `:443-452`), then branches:

- **Probe (`active == false`)** → `siege.open_siege(11)` (`:470`).
  `siege_director.gd:195-232`: `run_strength = 11`, `run_peak = 11`, `active = true`,
  `nights_run = 1`, `sector_bearing` rolled once at `:229-230`.
- **Assault (`active == true`)** → `siege.reinforce(maxi(1, 45 − run_strength))` (`:462`).
  `run_strength` is not decremented during a run (only at `_break_siege`,
  `siege_director.gd:768`), so `extra = 34` and `reinforce` (`:246-267`) sets
  `run_strength = 45` **and** `run_peak = 45`. **`SIEGE_STRENGTH 45` is honoured,
  unclamped, end-to-end.**

### 5.2 `LIVE_CAP` — the claim checks out, and the margin is 5

**VERIFIED. `siege_director.gd:35` `const LIVE_CAP: int = 50`.** The comment at
`demo_game.gd:83-86` is accurate: at 45 the hold logic
(`siege_director.gd:451-464` `_enforce_live_cap`) never fires, because
`materialized_men` tops out at 45 < 50, and `THAW_HEADROOM = 6` (`:449`) is never
consulted. **All 45 men the roll describes reach the screen.** The 2026-07-28 trickle
failure cannot recur at this value.

`_materialize` at `:425-433` is separately capped by `LIVE_CAP` — same 5-man margin.

### 5.3 A rogue siege cannot step on the arc — VERIFIED, and this is well done

`siege_director.gd:166-173` `_maybe_open()` returns immediately when
`GameFlow.demo_mode` is true. Without that guard the autonomous 1-in-20 night roll could
have opened its own siege anywhere in the 211 s between the night seam (1 184 s) and the
authored probe (1 395 s), at a random `randi_range(1, 50)` strength, and the authored
probe would have degraded into `reinforce(maxi(1, 11 − 37)) = 1`. The guard is correct
and the comment naming the decree (`:169-171`) is accurate.

### 5.4 The probe-breaks-early path is covered

If the 11-man probe breaks between 1 395 s and 1 440 s, `_open_siege(45)` takes the
`active == false` arm and `siege_director.gd:203-213` handles it: `forced_strength > 0`
→ `run_strength = 45`, `run_peak = maxi(run_peak, 45)`. If it was *wiped*,
`run_strength` is 0 (`:768`) so `:198` takes the first arm and sets 45/45 outright.
`nights_run = MAX_RUN_NIGHTS` from the wipe (`:770`) does **not** block, because
`open_siege` never checks it — only `_maybe_open` does (`:184`). **Both arms give 45.**
`sector_bearing` is preserved (re-rolled only at `nights_run == 1`, `:229`), so the air
beats keep aiming at the same axis.

---

## 6. AIR BEATS AND THE ENDING — signal-driven, and the backstop is genuine

### 6.1 The compass walk — VERIFIED

`demo_game.gd:236-244` `SIEGE_AIR_BEATS`, seven beats at +25/+60/+105/+150/+205/+255/+300
after `SIEGE_AT_S`, walked one-per-frame by `_tick_siege_air` (`:261-277`). Bearings
derive from `d.siege.sector_bearing` — `"flank"` = +60°, `"away"` = +180°, default =
the assault's own axis (`:271-275`). Every beat routes through
`field_director.gd:657` `authored_strike(...)` with `danger_close` defaulting **false**
(`:658`), which is the ruling `demo_game.gd:229-232` claims. **The gunships walk the
compass as documented.**

Minimum spacing is 35 s (25→60) against `AIR_MAX_IN_SKY = 14` (`:190`) — matches the
`:235` claim.

### 6.2 The ending fires on `siege_ended`, not on the clock — VERIFIED

`demo_game.gd:478-482` `_watch_for_the_raids_end()` connects
`SiegeDirector.siege_ended` (declared `siege_director.gd:93`, emitted `:771`) to
`_on_raid_ended` (`:485-491`). It is armed on **both** `_open_siege` arms — the
reinforce arm at `:466` and the fresh-open arm at `:471` — and guarded by `_phase < 2`
(`:479`) so a probe that breaks early cannot end the demo at minute 23. **The wiring is
correct and the guard is the right one.**

`_ending()` (`:502-521`) launches `at.launch("huey", "gun_orbit", 0, true)`
(`air_traffic.gd:218-224`, `_dispatch_gun_orbit` at `:268`, finale exempt from the
airframe ceiling at `:279-281`) and then **waits on state, not on a timer**:
`while not at.orbit_on_station()` (`air_traffic.gd:404-408`), capped by
`GUNSHIP_WAIT_MAX_S = 25.0` (`:500`). His 2026-08-04 Q2 ruling — the freeze lands only
once the pair is on station — is honoured.

### 6.3 `END_BACKSTOP_S` is a real backstop — VERIFIED, and it is *doubly* unreachable

`demo_game.gd:429-433` fires it only in phase 2, at 2 700 s.

**In a normal run it cannot be reached.** `siege_director.gd:380-381` breaks the siege
unconditionally at `_elapsed >= MAX_DURATION_S = 480.0` (`:39`). `_elapsed` starts at
the **probe** open (`:220`) and `reinforce` deliberately does not reset it (`:244-245`),
so the raid is guaranteed to emit `siege_ended("dawn", …)` no later than
**1 395 + 480 = 1 875 s** — 825 s before the backstop. The remaining routes to `siege_ended`
(`"wiped"` `:385`, `"broken"` `:389`) are earlier still.

The backstop's *only* live path is `demo_game.gd:453-454` — `d.siege == null`, i.e.
`_attach_siege` refused because `fsb_center == Vector3.ZERO` (`field_director.gd:1655`).
In that case the phase machine stays at 2 and the backstop is the sole terminator.
**So it is a genuine backstop, not a fossil, and it is generous exactly as `:70-72`
claims.** The one correction to the comment: the true pacing ceiling is not 2 700 s, it
is `MAX_DURATION_S` — the arc's hard end is **1 875 s ≈ 31 min**, not 45.

**MINOR, backstop path only:** at 20× the clock crosses midnight at
1 184 + (5.0 × 3600 / 20) = **2 084 s**, incrementing `sim_day`. Between 2 084 s and
2 700 s the fire-support allotment re-grants through `_granted_day` — the exploit
`demo_game.gd:51-53` names and points at `field_director.gd:1240-1245`. It is unreachable
on every normal path, but the comment claims the ratio choice prevents it outright and
it only *nearly* does. `period_at` still returns NIGHT at 03:25 (`sim_clock.gd:69`), so
the sun does not rise — that half of the claim holds.

### 6.4 The end card and `ENDING_PLAYER_SURVIVES`

**VERIFIED, with a caveat worth stating plainly.** `ENDING_PLAYER_SURVIVES`
(`demo_game.gd:81`) is read at exactly one place — `demo_game.gd:521` — where it
selects the **card title string**: `"FIREBASE HELD"` vs
`"THEY CAME BACK FOR THE WIRE"`. It is not a fossil (it is read, it does change output,
and `:79-80` describes it accurately as "deliberately ONE FLAG"), but it is a **label,
not a mechanism**. The player lives because nothing kills him, not because the flag says
so. Death routes independently through `_on_demo_death` (`:524-527`) to a third title.

`EXCLUDE_DEBRIEF` is now genuinely honoured — `demo_game.gd:402-404` disconnects
`mission_failed → _flow._on_mission_ended` and reconnects it to `_on_demo_death`. The
2026-07-31 audit's "inert `EXCLUDE_DEBRIEF`" finding is **CLOSED**; the doc at
`production/war_room/2026-07-31_demo_ship_audit/evidence.md:18` is stale and should be
corrected on contact.

`_show_end_card` (`:534-569`) pauses via `GameManager.pause_game()`
(`scripts/autoload/game_manager.gd:23-27`, `get_tree().paused = true`) and sets
`_flow._in_world = false` first so Esc cannot build a PauseMenu under the card (`:537`).
Only `_card` is `PROCESS_MODE_ALWAYS` (`:567`), so `DemoGame._physics_process` stops with
the tree — no air beats leak out from behind the frozen frame.

---

## 7. FOSSIL LAW findings

**`EXCLUDE_AIR_TRAFFIC` and `EXCLUDE_AMBIENT_WAR` (`demo_game.gd:26-27`) are read by
NOTHING but the boot print loop at `:97`.** Repo-wide grep returns only the declaration,
the print, and War Room prose. Flipping either to `true` would print
`[DEMO] EXCLUDED: air_traffic` and change no behaviour whatsoever.

This is precisely the disease the FOSSIL LAW names: the switchboard's own comment
(`:22-23`) states *"skip-only: it may EXCLUDE systems, never fork them; a flag flipped
true prints at boot so an excluded system is never a mystery."* **The mechanism that
makes the print trustworthy does not exist for half the switches, and the print is what
would lie.** `production/war_room/2026-07-30_demo_audit/analysis/boot_and_arc.md:178`
found this on 2026-07-30 and it was never fixed; `EXCLUDE_DEBRIEF` was fixed and these
two were left. Triage: **UNFINISHED — wire or cut.** Cutting is 2 lines and correct
unless he wants the switches.

**No other fossil in `demo_game.gd`.** Every other constant is read: `DEMO_SEED` `:121`,
`START_HOUR` `:134`, `DAY_RATIO` `:110`, `NIGHT_RATIO` `:417`, `PROBE_AT_S` `:422`,
`SIEGE_AT_S` `:426`, `END_BACKSTOP_S` `:430`, `PROBE_STRENGTH` `:424`,
`SIEGE_STRENGTH` `:428`, `ENDING_PLAYER_SURVIVES` `:521`, `NAPALM_EARLY_S` `:252`,
`NAPALM_RANGE_M` `:284` (default arg), `GATE_ORDER_*` `:350/:365/:367`,
`AIR_*` `:302-313`, `GUNSHIP_WAIT_MAX_S` `:516`.

**No signal declared-but-never-connected in this arc.** `siege_began` and
`siege_overrun` (`siege_director.gd:92, 95`) are outside my lane and I did not chase
their consumers.

---

## 8. Ranked findings

| # | Tag | Finding | Pointer | Effort |
|---|---|---|---|---|
| 1 | BLOCKER | Authored bunk arm does zero floor validation while the fallback arm probes 5.5 m; if `spawn_bunk_01` is over a collider-less hootch the player falls, and the 2 s fall-catcher rescues him **onto the roof** — both halves of B4, one cause | `game_flow.gd:176-184` vs `:206-217`; `game_world.gd:583-591` | measure first (`--roof-probe`, `game_flow.gd:741`); ~1 h to add the probe to the authored arm |
| 2 | MAJOR | **Fourth, undiagnosed patch:** terrain-dirty reseat uses `surface_y` at 0.5 m tolerance on a *merged* rect — mortars during the assault will stand an indoor player on the hootch roof | `game_world.gd:522-525` (merge at `:493-496`) | 1 line → `floor_y` |
| 3 | MAJOR | Two of four switchboard flags exclude nothing; found 2026-07-30, never fixed; the comment claiming they work is the lie | `demo_game.gd:26-27, 97` | 15 min (cut) |
| 4 | MINOR | DAY snaps at T+~48 s, not at gate-clearing; the code comment overstates it | `demo_game.gd:41-42` vs `sim_clock.gd:63` | 1 constant, but a pacing call for the Summoner |
| 5 | MINOR | Handoff FIX 3 points at `demo_game.gd:262`; the real `surface_y` is `:287` and is correct usage | `demo_game.gd:287` | 5 min doc fix |
| 6 | MINOR | Handoff FIX 0d already fixed — `terrain_watchdog` uses `floor_y` | `terrain_watchdog.gd:60` | none; delete the item |
| 7 | MINOR | Handoff's "no friendly-side director" overshoots: placement + an hourly schedule both exist; what is missing is a reader for the GLB extras | `site_planner.gd:1058`, `civilian.gd:940-946`, `civilian_schedules.gd:28` | doc fix |
| 8 | MINOR | `work_medofficer` strips to type `medofficer`, misses `FSB_WORK_OCCUPATION`, ships `off_duty` **silently**; ward seeder needs literal `medic` | `site_planner.gd:901-903, 1113, 1163` | 30 min (a `push_warning` on the fall-through) |
| 9 | MINOR | Backstop path only: midnight at 2 084 s re-grants fire support | `demo_game.gd:51-53`, `field_director.gd:1240-1245` | none; correct the comment |
| 10 | MINOR | `END_BACKSTOP_S` comment implies it is the pacing ceiling; the real one is `MAX_DURATION_S` → 1 875 s | `demo_game.gd:70-72`, `siege_director.gd:39` | comment |
| 11 | OK | Night seam arithmetic (`~1184s`, `~616s`, `~22:25`) correct to the second | `demo_game.gd:46, 54` | — |
| 12 | OK | `SIEGE_STRENGTH 45` honoured end-to-end; `LIVE_CAP 50`; margin 5; all 45 materialise | `siege_director.gd:35, 246-267, 451-464` | — |
| 13 | OK | `_maybe_open` demo guard prevents a rogue siege stepping on the authored probe | `siege_director.gd:172-173` | — |
| 14 | OK | `siege_ended` connected on both arms, `_phase < 2` guard correct; backstop genuinely unreachable in a normal run | `demo_game.gd:466, 471, 479` | — |
| 15 | OK | T+10 s gate order fully wired with three real expiries | `demo_game.gd:326-387` | — |
| 16 | OK | `EXCLUDE_DEBRIEF` now live — the 2026-07-31 "inert" finding is closed | `demo_game.gd:402-404` | — |

---

## 9. What I could not close (stated as findings, per the POINTER LAW)

1. **Whether `spawn_bunk_01` sits over a hootch with collision.** That is a question
   about `fsb_main_v3.glb`, which this session may not open. **NO POINTER.** The
   `[SPAWN-TRUTH]` line (`game_flow.gd:673-674`) answers it in one boot.
2. **Whether the hootch roof actually carries a layer-1 collider.** Finding #2's
   severity depends on it. The 2.88 m roof figure is quoted from
   `game_world.gd:436-441`'s own measurement banner, not measured by me today.
3. **`siege_began` / `siege_overrun` consumers** — outside my lane, not chased.
