# TECHNICAL DIRECTOR — 2026-08-03 DEMO DAY RESCOPE

Lens: **does this fit in the frame?** This project is CALL-BOUND (`PERF_LEDGER.md:686,700` —
canopy is the only lever above noise at ship parity, and it is a draw-call lever).

Method note: everything below is either a code pointer or a number I measured this session by
parsing the shipped `.glb` headers (read-only, no game boot). **I ran no windowed bench** — the
Summoner owns those. Where a number is owed I specify the exact run instead of guessing (§F.5).

---

## F. THE LIVE_CAP COLLISION — WHAT ACTUALLY COUNTS (the headline)

### F.1 Every counter, cited. LIVE_CAP is NOT a global body budget.

`LIVE_CAP = 50` (`siege_director.gd:36`) is read in exactly **two** places, and both walk the same
population: `SiegeDirector.cells` (`siege_director.gd:106`), an `Array[MarchingCell]` the siege
director builds itself.

| counter | pointer | what it sums |
|---|---|---|
| `_enforce_live_cap()` | `siege_director.gd:435-446` | `c.live_strength()` for `c in cells` **where `c.materialized`** |
| `_light_check()` | `siege_director.gd:421-430` | identical population, identical guard |
| `MarchingCell.live_strength()` | `marching_cell.gd:55-62` | materialized → living men only; dormant → full paper strength (excluded by the `materialized` guard in both callers) |

**Therefore the following do NOT count toward LIVE_CAP, and I found no counter anywhere that
aggregates them:**

- **The garrison — DOES NOT COUNT.** `_garrison_stand_to()` (`field_director.gd:1364-1378`)
  promotes `firebase_garrison` Civilians into the `garrison_promoted` group. It never touches
  `SiegeDirector.cells`. Ceiling is **40** (`site_planner.gd:853`, `FSB_GARRISON_MAX_MEN`).
- **Hunters — DO NOT COUNT.** `_process_escalation` (`field_director.gd:155-162`) spawns them
  through `spawn_tracked_enemy` with tag `"hunters"`. No MarchingCell, no cell array. Pool **12**
  (`field_director.gd:106`).
- **Allies / the player's squad — DO NOT COUNT.** They are `AllyBase`, never in `cells`.
- **Camp and village enemies stamped by the generator — DO NOT COUNT.**
- **`spawn_tracked_enemy` itself has NO cap of any kind** (`field_director.gd:41-57`).
  `_live_enemies` (`:53`) is an unbounded `Array`.

**Conclusion: there is no global headcount cap in this project, and by decree there must not be**
(`ADR-026:74-79`, quoted at `DEMO_PERF_PLAN.md:203-206`: *"There is NO headcount cap"*).
`LIVE_CAP` is a **per-siege materialization budget**, nothing more. The briefing's framing —
"live hunters + a 40-man garrison + a 45-man assault against a 50 cap" — **is not what the code
computes.** Those three populations never meet in any counter.

### F.2 What the collision actually IS: a one-way latch that has never been armed

`_enforce_live_cap` freezes over-budget cells: `c.set_physics_process(false)`
(`siege_director.gd:444`).

**`set_physics_process(true)` appears NOWHERE in `marching_cell.gd` or `siege_director.gd`.**
(Verified: the only three occurrences in those two files are `marching_cell.gd:71`,
`marching_cell.gd:112` and `siege_director.gd:444` — all `false`.)

A frozen cell therefore **never resumes marching**, even after the assault is bled to five men.
Its only surviving door into the fight is `materialize_if_lit()` (`marching_cell.gd:99-105`) via
`_light_check`. Garrison illum stands off at **140 m** on the sector bearing
(`ILLUM_STANDOFF_M`, `siege_director.gd:89`) while the demo's cells sit at ring **190–235 m**
(`demo_game.gd:287-288`). So a frozen cell is, in practice, a **permanent statue at the ring**.

And it is a statue that still counts as paper strength: `live_strength()` returns
`strength` for a non-materialized cell (`marching_cell.gd:56-57`), and `_run_siege` feeds that
into the break test (`siege_director.gd:390-394`). **A latched assault can never break.** It runs
to `MAX_DURATION_S = 480 s` (`:40`) — past any end card — with a squad of men standing still at
190 m. This is the same class of unbreakable-assault failure the code already documents for a
different cause at `siege_director.gd:202-206`.

### F.3 Today the latch is disarmed BY ONE NUMBER, and the rescope arms it

`SIEGE_STRENGTH = 45` (`demo_game.gd:48`) with the comment at `:44-47` explaining exactly this:
*"45 and not 50: LIVE_CAP is 50 materialized men, and an assault authored at the cap freezes its
late cells at the ring — the 2026-07-28 trickle failure."*

The Arbiter's sketch in the briefing (§1) proposes **clean day 35 / default 45 / seen-and-camp-intact
55**. **55 > 50.** That sketch re-arms the latch by construction and re-creates the 2026-07-28
failure on the *worst* outcome branch — the branch a player earns by playing badly, i.e. the one
most likely to be the demo's lasting impression.

**Ruling I recommend: the day's outcome may only move SIEGE_STRENGTH DOWNWARD from 45.**
Band **35 / 45 / 45-plus-a-shorter-fuse**, never upward past 50. If the "punished" branch must
feel worse, spend it on *cadence* (earlier `SIEGE_AT_S`, tighter `PRESS_CYCLE_S`
`siege_director.gd:68`) or on the RTO/air allotment — not on headcount. Raising `LIVE_CAP` above
50 is a canon number and a Summoner ruling (`siege_director.gd:32-36`), not a knob I may turn.

### F.4 The hunt net is not "softer" in the second half — it is DEAD

Adjacent to F and worth the council's time. `_process_escalation` returns immediately when
`_hunter_pool <= 0` (`field_director.gd:124`). The pool is **12** (`:106`) and each wave takes
2–4 (`:149-150`). **Three to six waves and the net is permanently empty.** At a wave interval of
`randf_range(100,160) * field_mult` (`:148`), 12 men are spent in roughly 8–14 real minutes.

So in a 30-minute demo, question D's `field_mult` decay (`:130-133`) is arguing about the shape of
a curve that has already hit zero. **By minute ~15 there are no hunters at all**, which directly
contradicts ruling 9 (*"a hunter patrol must be able to hit the player at any time outside the
wire"*). Whatever the council decides about `field_mult`, the pool size is the binding constraint
and nobody has flagged it.

### F.5 THE MEASUREMENT (I did not run it — here is the exact run)

**What has genuinely never been measured** is not "hunters + garrison + assault" (the probe at
`demo_game.gd:33` is a COMBAT contact, so `_check_detection` `field_director.gd:113-119` arms the
net inside the first minute and hunters may already co-exist with the siege today). It is:
**(a) an assault authored above 50, and (b) any run longer than 7 minutes.**

**Setup (binding, from `PERF_LEDGER.md:18-29` and `DEMO_PERF_PLAN.md:217-221`):** Blender CLOSED.
Single Godot instance verified. Record `rendering/scaling_3d/scale`, the RUNTIME-printed renderer
(never grep `project.godot` — `PERF_LEDGER.md:24-27`), and seed 29072026 on every row.

**Command (exported build, the same instrument as the W7 A/B):**

```
build/RECON_Demo.exe --print-fps -- --demo
```

**Three runs, A/B/A, one variable:**

| run | change | duration |
|---|---|---|
| A1 baseline | `SIEGE_STRENGTH = 45` (shipped) | 300 s |
| B  the collision | `SIEGE_STRENGTH = 55` — the ONLY edit | 300 s |
| A2 baseline | back to 45 | 300 s |

**Counters to read (stdout — no new instrumentation needed for the pass/fail):**
1. `[Siege] cell of N held at the ring - live cap 50 reached` (`siege_director.gd:445-446`) —
   **presence of this line in run B and absence in A1/A2 is the whole experiment.**
2. `[Siege] reinforced +N - the assault is now N men (peak N)` (`:259-260`) — confirms peak grew.
3. `[Siege] OVERRUN - N attacker(s) inside the wire` (`:598`) — did the wire still get reached?
4. `[DEMO] dawn at Ns` vs `[Siege] ... broken` — **did the siege ever break?**
5. `--print-fps` rows through the 60–360 s window.

**PASS/FAIL — stated in advance so the result cannot be rationalized after the fact:**
- **FAIL if run B prints the `held at the ring` line at all.** That is the latch arming and it is
  disqualifying on its own, independent of frame rate.
- **FAIL if run B reaches `DAWN_AT_S` with `active == true` and no `_break_siege` line** while
  A1/A2 broke. That is the unbreakable assault.
- FPS is the *secondary* read. Noise floor = the widest gap between A1 and A2
  (`PERF_LEDGER.md:519-521`); any FPS delta inside it is INSIDE NOISE and must be reported as such.

**My prior, stated so it can be falsified:** FPS will move **~0**, because the W7 A/B already
measured **48.0 FPS mid-siege at garrison 24 AND at garrison 40** — 16 extra live bodies for zero
frames (`site_planner.gd:850-853`, `DEMO_SHIP_BACKLOG.md:339`). *The men are not the frame cost in
this scene.* Ten more attackers will not be either. **The LIVE_CAP collision is a CORRECTNESS and
DRAMA failure, not a performance one** — and that is the most useful thing I can tell this council,
because it means the fix is a number in `demo_game.gd`, not an optimization programme.

### F.6 A separate defect in the same code, found on the way

`_enforce_live_cap` returns early on `materialized_men < LIVE_CAP` (`siege_director.gd:440-441`)
and freezes at `>=`. Because it counts only materialized men, and because a materialized cell's
count *falls as men die*, the enforcement is **hysteresis-free**: it can freeze cells at 50, then
5 men die, and nothing un-freezes them (per F.2). The cap is a ratchet in one direction only.

---

## C. MULTI-PAD HUEYS — PRICED, AND THE FEATURE AS SPECIFIED IS BLOCKED

### C.1 MEASURED: there is only ONE physical pad. The code comment is drift.

`air_traffic.gd:54-55` states *"Pad markers inside the firebase GLB (measured: three 15x15m PSP
pads)"* and `:56-58` names them: `PSPHelipad`, `fb_helipad_i`, `fb_helipad_i_182`.

**I parsed `assets/world/building models/structures/firebase/fsb_main_v3.glb` this session.
All three nodes exist. All three sit at the IDENTICAL world position `(22.18, 4.01, -41.29)`.**
They are one pad wearing three names: the visual mesh (`fb_helipad_i`, mesh 106), a bare marker
Empty (`PSPHelipad`, no mesh), and the collision-only twin (`fb_helipad_i_182-colonly`, same mesh).

Consequence: `_firebase_lzs()` (`air_traffic.gd:467-507`) faithfully builds **three LandingZones at
the same coordinates**, each `capacity = 1` (`:500`). `_free_pad()` (`:510-515`) will therefore
hand out three "free" pads for three concurrent `lz_cycle` sorties and **land three helicopters on
top of each other.**

**So the multi-pad ask is a BLENDER job, not a code job.** The scheduler side the briefing says
"needs a per-pad scheduler" is **already built** — `_dispatch_lz_cycle` (`:520-551`) allocates a
free pad per sortie and nothing serializes them. What does not exist is a second and third pad at
distinct positions in `fsb_main_v3.blend`. Correct `air_traffic.gd:54-55` on contact (NO-DRIFT law).

### C.2 The price of an airframe — MEASURED from the shipped GLBs

Godot 4 does not auto-batch 3D meshes: one draw call per mesh primitive per MeshInstance3D.

| aircraft | file | mesh primitives = **draw calls** | materials | tris |
|---|---|---:|---:|---:|
| **Huey** | `assets/us/vehicles/huey.glb` | **27** | 7 | 1,446 |
| **Chinook** | `assets/us/vehicles/ch47_chinook.glb` | **84** | 10 | **12,028** |
| Skyraider | `assets/us/aircraft/a1_skyraider.glb` | 20 | 8 | 11,870 |
| Skyhawk | `assets/us/aircraft/a4_skyhawk.glb` | 21 | 6 | 2,294 |
| F-4 | `assets/us/aircraft/f4_phantom.glb` | 16 | 5 | 1,024 |

Reference frame: ship-parity baseline at the firebase spawn is **~1,346–1,411 draw calls** at
~34 FPS (`PERF_LEDGER.md:683-691`), of which the canopy owns ~1,000 (`:686`: 1,346 → 355 calls
with canopy off, worth **+6.3 FPS** — `:700`). That is the only calibrated call→FPS exchange rate
this project owns: **~1,000 calls ≈ 6 FPS ≈ 0.006 FPS per call.**

### C.3 The budget, and a real ceiling bug

- One 6–9-ship Huey pack (`FORMATION_SIZES`, `air_traffic.gd:39`; 85% of transits,
  `FORMATION_CHANCE :42`) = **162–243 calls** = +12–18% on the frame. ≈ **−1.0 to −1.5 FPS**.
- `MAX_IN_FLIGHT = 14` (`:65`) all-Huey = **378 calls** = +28%. ≈ **−2.3 FPS**.
- **CEILING OVERSHOOT BUG:** `_dispatch` tests `_in_flight.size() >= MAX_IN_FLIGHT` **once, before
  the lead** (`:328-329`), then spawns up to 8 wingmen at `:343-349` **with no re-check.** At 13
  in flight a 9-ship pack reaches **22 airframes = 594 calls = +44% ≈ −3.7 FPS.** The comment at
  `:63-64` claims the ceiling is *"Hard … binding on EVERY caller"*. It is not; it is binding per
  *formation*, not per ship. This is the cheapest real fix on my whole list.
- **One Chinook is 3.1× a Huey in calls and 8.3× in tris.** `AIR_OPENING` books one on a pad at
  95 s (`demo_game.gd:111`) and `_seed_default_schedule` can roll one for every lz slot
  (`ROTARY`, `air_traffic.gd:22,105-108`).

### C.4 The night already protects itself; the DAY does not

The combat-load gate (`air_traffic.gd:121-202`) is the good news and it is real:
`_sample_load` (`:163-188`) counts engaged fighters across `AgentRegistry`; at
`SATURATED_FIGHTERS = 20` (`:140`) `_dispatch` **holds every transit** (`:321-324`), and at
`BUSY_FIGHTERS = 8` (`:139`) `_ship_count` **collapses every formation to one ship**
(`:370-371`) — and that override explicitly outranks the demo's authored packs (`:368-369`).

So during the night attack the sky is already throttled to ~nothing. **The multi-pad Huey ask
lives entirely in the DAY, where load is CLEAR and packs are 6–9.** The 48 FPS mid-siege figure is
therefore *not* the number that governs this feature — it is a number measured with the sky
switched off. **The daytime frame has never been measured in the demo scene at all.**

### C.5 VERDICT ON C — BOUND IT, DO NOT KILL IT

Multi-pad is affordable and it is bounded by machinery that already exists. My bounds:

1. **Ship at most 2 concurrent `lz_cycle` sorties**, which needs **one new pad marker** authored at
   a distinct position in `fsb_main_v3.blend` (prefix `fb_helipad` or `PSPHelipad` —
   `FSB_PAD_PREFIXES`, `air_traffic.gd:59`, is the contract). A third pad is a third 27-call
   airframe plus a landing pattern to deconflict; not worth it for the opening beat.
2. **Ban the Chinook from concurrent cycles.** 84 calls and 12k tris is three Hueys' worth of
   frame for one silhouette. Keep it as a solo beat, never overlapping.
3. **Fix the formation ceiling overshoot** (`air_traffic.gd:328-349`) — re-check
   `_in_flight.size()` inside the wingman loop. Two lines, removes a 44% draw-call spike nobody
   budgeted.
4. **Do not raise `MAX_IN_FLIGHT` (14) or `AIR_MAX_IN_SKY` (14, `demo_game.gd:117`)** for this.
   The spectacle asked for is *staggered concurrency*, which is a scheduling shape, not a higher
   ceiling.

---

## A. THE CLOCK RATIO — SANITY CHECK, AND A BLOCKER ON BEAT 1

### A.1 THE BLOCKER: the demo cannot choose 0700 today

`MissionWeather.setup()` **sets the clock itself**:
`SimClock.sim_hour = float(TIME_ID_START_HOUR.get(time_id, 10.0))` (`mission_weather.gd:51`),
where `TIME_ID_START_HOUR = {DAWN 5.5, DAY 10.0, DUSK 17.5, NIGHT 21.0}` (`:40`) and `time_id`
comes from the mission roll, not from `demo_game.gd`.

**The demo's 17:30 is DUSK's constant, not an authored number.** `demo_game.gd:39`'s comment
("the demo currently starts at 17:30") states the effect and hides the cause — the ratio at `:42`
is the only clock knob `DemoGame` actually owns.

**There is no 7.0 in that table.** Ruling 3 ("spawn 0700") therefore cannot be satisfied by
changing `DEMO_CLOCK_RATIO`. The options are: add an explicit start-hour override for the demo
(the honest fix, ~3 lines), or accept **DAY = 10:00** as the opening hour. Re-seeding to roll DAWN
gives 05:30 *and re-rolls the entire layout* — seed 29072026 (`demo_game.gd:14`) is what fixes the
demo's world. **This is a decision the council must surface, not an implementation detail.**

### A.2 THE ARITHMETIC

- 07:00 → 19:00 = 12 sim hours = 43,200 sim s. Over 23 real min (1,380 s) → **31.3×**. The
  briefing's ~31x is correct.
- 19:00 → ~05:30 = 10.5 h = 37,800 s over 7 real min (420 s) → **90×**.
- A variable ratio is therefore a **2.9× step**, not a gentle ramp.

### A.3 EVERY CLOCK CONSUMER, AND WHAT THE RATIO DOES TO IT

| consumer | pointer | effect of a slower day / faster night |
|---|---|---|
| **AI sight** | `sight_cap.gd:24-28`, `DARKNESS_BY_PERIOD` `:11` (DAWN 1.0, DAY 1.0, DUSK 0.75, NIGHT 0.4) | Reads `period_at` live. Period-based, so **rate-invariant** — the ratio changes *when* the AI goes blind in wall time, never *how*. Safe. |
| **Sun / ambient light** | `mission_weather._on_time_period_changed :80-83` → `_apply_time :88-120` | **THE GAP — see A.4.** |
| **Ambient air schedule** | `air_traffic._seed_default_schedule :88-108` | **THE COST — see A.5.** |
| **AmbientWar** | `ambient_war.gd:47-51` — rolls 1–3 events **per sim hour** | Today (17:30→06:20) ≈ 13 h fire. A 0700→dawn day fires ~22 h → **~1.7× the ambient events**, and at 90× the night they arrive ~3× faster in wall time than the day. |
| **CampDirector role swap** | `camp_director.gd:45-47,107` | Per sim hour. 3× faster at a 90× night. |
| **ConvoySpawner** | `convoy_spawner.gd:45-47,61-69` | Per sim hour. Same. |
| **CivilianSchedules** | `civilian_schedules.gd:25-140` | **Never exercised.** Today's 17:30→06:20 demo runs almost entirely the evening/sleep branches. A day demo activates the *entire* daytime civilian behaviour table for the first time in the demo build. |
| **Tracer/flash brightness** | `bullet_system.gd:250` (`4.5 if MissionWeather.is_night else 2.0`) | Reads `is_night`, set at `mission_weather.gd:95` on period crossings. Correct, no action. |
| **Siege night gate** | `siege_director.gd:175` | Irrelevant — the demo calls `open_siege()` directly (`demo_game.gd:310`). |

### A.4 THE SUN DOES NOT MOVE — the rescope's biggest unflagged atmosphere hole

`_apply_time` runs **only on DAWN/DAY/DUSK/NIGHT crossings** (`mission_weather.gd:80-83`), and
`TIMES` (`:20-25`) holds **one** sun rotation per period (`DAY: sun_x = -50°`). `period_at`
(`sim_clock.gd:57-63`) makes DAY a **ten-hour block, 07:00–17:00.**

**So a 23-real-minute "full day on the firebase" renders with a FIXED sun for ~19 of those
minutes**, then eases to DUSK over `TIME_EASE_SECONDS = 6.0` (`:41`). At 31× that 6-second sunset
sits inside a 6.5-real-minute dusk window — which is precisely the light-bulb effect the comment at
`:86-88` was written to prevent. It reads fine at 110× over 7 minutes; it will not at 31× over 23.

This is a real cost of the rescope that no other architect is positioned to see. It is not a
blocker, but **"one full day" with a nailed-down sun is a caption, exactly the failure the 110×
comment (`demo_game.gd:36-41`) exists to avoid** — the rescope moves that failure from the clock
to the sun. Fix is a continuous sun-angle lerp across the DAY window (cheap: one property on one
DirectionalLight3D per frame, no shadow — `game_world.gd:48` keeps `shadow_enabled = false`, and
`PERF_LEDGER.md:727-734` measured that turning it on costs **−10.5 FPS at any cap**, so *the sun
may move but it must never cast*).

### A.5 THE RATIO'S REAL PERF COUPLING: daylight is where the air schedule lives

`_seed_default_schedule` books `TRANSITS_PER_HOUR = 3` (`air_traffic.gd:62`) for **hours 6..23**
(`:93-104`) plus lz cycles at **07, 11, 15, 19** (`:105-108`).

- **Today** (17:30 → 06:20): hours 18–23 fire ≈ **18 transit bookings, 1 lz cycle.**
- **Rescoped** (07:00 → 19:00 then night): hours 7–19 fire ≈ **39 transit bookings and ALL FOUR
  lz cycles**, plus the night's remainder.

Each booking is a 6–9-ship pack 85% of the time (`:39,42`). **That is roughly 2.2× the ambient air
events, and it lands entirely in the daylight half where the combat-load gate is CLEAR and packs
are at full size** — i.e. exactly where nothing throttles them. On top of that, `DemoGame` runs its
*own* rolling launch every `AIR_CADENCE_S = 42 s` (`demo_game.gd:114,234-241`).

**This, not the multi-pad ask, is the largest new frame cost in the whole rescope,** and it arrives
as a side effect of a constant nobody proposed changing.

### A.6 WHAT LEAKS OR ACCUMULATES OVER 30 MINUTES (never run that long)

Checked every accumulator I could find. Most are clean; two are not.

**CLEAN (bounded, verified):**
- Decals: `MAX_DECALS 48` (`gun_fx.gd:69`), `MAX_SCORCH 12` (`:231`), `MAX_BLOOD_DECALS 24`
  (`:535`), blood pools FIFO (`:724-729`). All queue_free the evictee.
- Corpses: 45 s to `queue_free` (`enemy_base.gd:2721`, and `:2661` for the downed path).
- Flights: reaped at `MAX_FLIGHT_SECONDS 240` (`air_traffic.gd:49,601-604`).
- `_live_enemies`: erased on death (`field_director.gd:96`) and despawn (`:75`).
- `SimClock._fired_event_keys` (`sim_clock.gd:25`): never pruned, but bounded at ~58/day. Fine.

**LEAK 1 — `EnemyBase.unreported_corpses` has no TTL.** Static `Array[Vector3]`
(`enemy_base.gd:961`), appended on every unwitnessed kill (`:1011`), drained **only** when a live
enemy walks within `CORPSE_NOTICE_RANGE = 22 m` (`:107`) and can witness it (`:1023-1032`), and
cleared only per-mission (`field_director.gd:22`). It is also **scanned linearly by every
non-COMBAT enemy on every think.** Strictly monotonic across a 30-minute patrol. Small in absolute
ms; it is the only genuinely unbounded structure on the kill path, and it deserves a TTL prune the
way the `EvidenceLedger` already has one (`field_director.gd:142`).

**LEAK 2 — DROPPED WEAPONS. This one I measured, and it is worse than a leak.**

`_drop_carried_weapon` fires on **every** death (`enemy_base.gd:2720`, `:2661`) and calls
`WorldWeapon.drop` (`:2737`). `WorldWeapon._build_visual` (`world_weapon.gd:63-70`) instantiates
`weapon_data.model_path` — and for the VC line rifle that is
`res://scenes/weapons/ak47_arms_viewmodel.tscn` (`data/weapons/ak47.tres:27`), which wraps
`assets/player/viewmodels/ak_fp.glb`.

**I parsed that GLB this session: 11 mesh primitives (= 11 draw calls), 9 materials, 1,968 tris,
1 skin, 6 animations — and its first mesh is named `ArmsMesh`.** Every dropped enemy rifle in this
game instantiates a **first-person viewmodel including the player's arms**, as a skinned mesh with
an animation library, into the world.

Three consequences, all first-ever-visible in a 30-minute demo:
1. **Cost.** ~11 calls + a skinned mesh per corpse. `LIFETIME_S = 600.0` (`world_weapon.gd:22`) —
   **ten minutes, so in the shipped 7-minute demo the reaper at `:87-94` has literally never
   run.** Worse: `:89-92` **resets the age to 300 s whenever the player is within 40 m.** During
   the night attack the player stands at the wire while ~45 attackers die there — **every one of
   those rifles is immortal.** 45 × 11 ≈ **495 draw calls, ~+37% on a 1,350-call frame**, and
   skinned meshes are the expensive kind. Add a day's kills on top and this is the single largest
   unbudgeted accumulator in the rescope.
2. **Correctness.** The viewmodel scene offsets its model by **−1.81 m in Y**
   (`scenes/weapons/ak47_arms_viewmodel.tscn`, the Model node transform) — the FP ruler-root
   convention. `WorldWeapon` reuses it raw, so **dropped weapons are buried ~1.8 m underground**:
   invisible, unpickable-looking, still submitted to the renderer.
3. `model_path` is documented as *"Path to weapon GLTF model"* (`weapon_data.gd:91`) and is being
   used for two incompatible jobs. There is no separate world-model field.

**Recommendation: this is a bug, not a tuning item, and it is squarely in the demo's blast radius.
Give `WeaponData` a `world_model_path` (or strip `ArmsMesh` and the ruler offset in a world
variant), and make the 40 m proximity rule *cap* the extension rather than reset it.** It is not
War Room scope to fix — but the council should know that the 30-minute demo is the first build
that will ever pay this bill, and it will pay it standing on the wire.

---

## WHAT IS SACRIFICED (Law 2 — every recommendation, priced)

| I recommend | what it costs |
|---|---|
| **SIEGE_STRENGTH may only fall from 45, never rise to 55** | The day's *worst* outcome loses its most legible expression. A player who gets seen and leaves the camp intact will not face a visibly bigger attack; he faces an earlier/tighter one, which is a subtler signal. **Pillar-adjacent risk:** the r4bk Law says an invisible consequence is no consequence — so this pushes even harder on the briefing's own requirement of one RTO line at the gate and one on the end card. Without those lines, do not build the link at all. |
| **Multi-pad bounded to 2 concurrent, Chinook excluded from concurrency** | Loses the "busy airfield" read the Summoner asked for — three or four birds working at once. Two is a *pattern*; three is a *base*. And it costs Blender time on `fsb_main_v3.blend` (a new pad marker) that this council cannot spend for him, on a file with a live truth-source history (`firebase-truth-source`). |
| **Add a demo start-hour override rather than re-seeding** | Adds a third clock authority alongside `MissionWeather.setup` and `SimClock` — mild architectural debt in a file the fossil law watches. The alternative (accept 10:00) sacrifices the Summoner's own words ("spawn 0700") and the morning light that makes the Huey liftoff beat read. |
| **Move the sun continuously across the DAY window** | A per-frame property write on the sun, and a new thing that can drift out of sync with `MissionWeather`'s period tweens (`:114-120`) — two authorities animating one light. **Hard constraint: it must never cast.** `PERF_LEDGER.md:727-734` measured the sun shadow as **−10.5 FPS at 40 m, 80 m and uncapped alike** — it is binary and unaffordable. |
| **Fix the air formation ceiling overshoot** | None worth naming. It makes the sky slightly less spectacular at the exact moment it was already over budget. |
| **Prune `unreported_corpses` on a TTL** | A body you left twenty minutes ago stops being a liability. That is a small, real subtraction from ADR-022's "a corpse you left is a liability" and from stealth-as-an-economy (Pillar 3). Set the TTL generously (10+ min) so it prunes only what the demo will never revisit. |
| **Treat the dropped-weapon viewmodel as a bug to fix before the 30-min build** | It is work outside this council's scope and it touches `WeaponData`, which the viewmodel pipeline (ADR-034) and the `--strict` export gate both read. Not free, and not this session's. |

---

## THE ONE-LINE ANSWER TO MY OWN LENS

**Yes, this fits in the frame — but not for the reason the briefing assumes.** The bodies are
measured free (48.0 FPS at garrison 24 *and* 40, `site_planner.gd:850-853`). The frame risk in
this rescope is not the men at all: it is **daylight** — 2.2× the ambient air schedule
(`air_traffic.gd:93-108`) arriving in the half of the demo where the combat-load gate is CLEAR —
and **duration**, which is the first thing that will ever make the dropped-weapon viewmodel bill
come due. The LIVE_CAP question is real, but it is a **latch that has never been armed**
(`siege_director.gd:444`, no matching `true` anywhere), and the correct output is a ruling that
keeps `SIEGE_STRENGTH ≤ 45`, not an optimization programme.

---

### NO-DRIFT corrections owed (found while reading; log them)

1. `air_traffic.gd:54-55` — *"measured: three 15x15m PSP pads"*. **There is one pad.** All three
   prefix-matching nodes in `fsb_main_v3.glb` are at `(22.18, 4.01, -41.29)`.
2. `air_traffic.gd:63-64` — *"Hard ceiling … binding on EVERY caller"*. It binds per formation,
   not per ship (`:328-329` vs `:343-349`); the real ceiling is `MAX_IN_FLIGHT + max wingmen = 22`.
3. `DEMO_PERF_PLAN.md:5,48` — states *"main siege `open_siege(40)` at 720s"* and *"strength 40"*.
   The code now reads `SIEGE_AT_S = 60.0` and `SIEGE_STRENGTH = 45` (`demo_game.gd:34,48`), and
   §0.4's "landmine" (missing ring override) **is fixed** — `demo_game.gd:286-296` sets
   `ring_min/ring_max/rally_m/mortar_standoff_m/cell_materialize_m`. The plan is stale in three
   places; it is otherwise the best document in this folder.
