# SYSTEMS DESIGNER — the four unverified systems (S27 / S28 / S29 / ambient)

**Date banner: 2026-08-12.** Read-only audit. No file outside this one was modified, no
Godot suite was run, no `.blend` or Blender MCP was touched.

**Every claim below carries a `file:line` read on disk today.** Where I could not find a
pointer, the absence is stated as the finding (POINTER LAW).

**Constraint under which these verdicts are written:** the Summoner's 2026-08-11 ruling —
*"all of those need to be in the demo"* (`production/SHIP_AUDIT_2026-08-11.md:64`, `:241`) —
withdrew the cut lever. So every flag-off instruction below is a **playtest isolation
switch**, not a cut, and each is a single constant so it can be flipped and un-flipped in
seconds. FIX-CHEAP verdicts are given where the fix is measured in lines.

**Demo clock used for all arithmetic** (`scripts/levels/demo_game.gd:43-87`):
boot 0 s → night falls ≈ 1184 s (`demo_game.gd:45-46`) → probe `PROBE_AT_S` 1395 s
(`:57`) → assault `SIEGE_AT_S` 1440 s (`:58`), 45 men (`:87`) → resolves on
`siege_ended`, backstop `END_BACKSTOP_S` 2700 s (`:73`).

---

## 1 · S27 — `scripts/world/camp_mortar.gd` — CAMP MORTAR HARASSMENT

### Verdict: **FIX-CHEAP** (two guards, ~4 lines). The cadence is right; one guard is missing and it fires at the worst possible moment.

### Reachability in the demo: **GUARANTEED, and it will fire 1–7 times.**

The demo plan stamps the camp and the mortar tag unconditionally when passable ground
exists (`scripts/missions/mission_generator.gd:833-837`, `p["camp_mortar_tag"] =
"camp_mortar_crew"`), the failure branch is a `push_warning` only
(`mission_generator.gd:844`). `_build_camp_site` attaches the node whenever the tag is set
(`mission_generator.gd:1172-1182`). This is not a maybe — it is on the critical path of
every demo boot.

### The cadence is SANE. Measured, not asserted.

- Hold: `HOLD_FIRE_S = 600.0` real seconds (`camp_mortar.gd:14`).
- First volley scheduled at `HOLD_FIRE_S + randf(0, GAP_MAX_S)` → **600–1020 s**
  (`camp_mortar.gd:46`).
- Gap thereafter `randf(GAP_MIN_S 120, GAP_MAX_S 420)` (`camp_mortar.gd:16-17`, `:132`).
- One volley = `MORTAR_VOLLEY = 3` shells (`scripts/missions/siege_director.gd:49`,
  fired in the loop at `siege_director.gd:687-690`).
- Shell: `data/projectiles/mortar_81mm.tres:12` `base_damage = 140`, `:16` `aoe_radius = 10.0`.
- Dispersion: `SiegeDirector.MORTAR_DISPERSION_START = 50.0` (`siege_director.gd:46`),
  passed always and never walked in (`camp_mortar.gd:141-142`). Impacts are
  `at + randf(-50,+50)` on x and z (`siege_director.gd:688-689`) — a **100 m × 100 m box**
  centred on `fsb_center`.

**Rounds per minute at demo pacing**, over the pre-probe window 600 s → 1395 s (795 s):

| Case | Volleys | Shells | Rate |
|---|---|---|---|
| Worst (first at 600, every gap 120 s) | 7 | 21 | **1.75 rds/min** |
| Median (first at 810, gaps 270 s) | 3 | 9 | **0.68 rds/min** |
| Best (first at 1020, gaps 420 s) | 1 | 3 | **0.23 rds/min** |

That is harassment, not spam. **KEEP the numbers.** The parapet radius is 96.1 m
(cited at `scripts/world/ambient_encounters.gd:29-30` against `demo_game.gd:413-418`), so
a ±50 m box drops shells across the compound and out into the wire — correct for the beat.
Lethality to the player is roughly 2–3 % per volley for a man standing in the open
(π·5² lethal-ish area per shell against a 10,000 m² box, ×3 shells) against Player HP 100.
Fair.

### FINDING S27-1 (WORST) — a volley is GUARANTEED to land on the ending beat.

`camp_mortar.gd:127-133`:

```
if director.fsb_center == Vector3.ZERO or _elapsed < _next_fire:   # :127
    return
if director.siege != null and ... director.siege.active:           # :130
    return
_next_fire = _elapsed + _rng.randf_range(GAP_MIN_S, GAP_MAX_S)     # :132
_fire()                                                            # :133
```

**The siege check sits AFTER the timer check and BEFORE the reschedule.** While the siege
is active the node returns without touching `_next_fire`, so `_elapsed` runs away past it.
`SiegeDirector.active` goes false in `_break_siege` (`siege_director.gd:743-746`) — which
is exactly the event the demo's ending listens for (`demo_game.gd:502-509`, gunships in).

At the assault's resolution `_elapsed` ≈ 1800 s and `_next_fire` is a value last written
before 1395 s. On the **next 1-second poll** (`camp_mortar.gd:121-124`) the guard clears
and `_fire()` runs immediately: three 140-damage 81 mm shells into a 100 m box on the
compound, plus the toast `"INCOMING - MORTARS ON THE COMPOUND"` (`camp_mortar.gd:144`),
laid across the gunship end card while the player is standing in the wreckage of the fight
he just won.

This is the single most likely "visibly stupid moment at the exact minute a reviewer is
watching" on the whole board.

**Fix (1 line): defer the schedule instead of skipping it.** Move the `_next_fire`
assignment above the siege check, or on the siege branch set
`_next_fire = _elapsed + _rng.randf_range(GAP_MIN_S, GAP_MAX_S)` before returning
(`camp_mortar.gd:130-131`). Cost: minutes.

### FINDING S27-2 — it does NOT respect DAY/NIGHT. The comment says it does.

`camp_mortar.gd:129` — *"The assault's own ranging walk owns the night's mortars;
harassment is the day's."* The only guard actually written is `director.siege.active`
(`:130`). There is **no `MissionWeather.is_night` check anywhere in the file** — grep of
`camp_mortar.gd` returns zero hits for `is_night`, while its sibling `AmbientEncounters`
does gate on it (`ambient_encounters.gd:174-175`, authority
`scripts/world/mission_weather.gd`).

Night falls ≈ 1184 s; the probe does not open until 1395 s. **That is a 211-second window
in which the "day's harassment" fires in full darkness**, competing with the stand-to beat
the demo is trying to sell. This is COMMENT DISCIPLINE / drift: the comment asserts a guard
that was never written.

**Fix (1 line):** add `if MissionWeather.is_night: return` alongside the siege check at
`camp_mortar.gd:130`, with the same defer-the-schedule treatment as S27-1.

### FINDING S27-3 — spawn is guarded; scripted beats are not, beyond the siege.

`HOLD_FIRE_S 600` (`camp_mortar.gd:14`) covers the bunk boot and the squad move-out at
T+10 s. Nothing else is guarded: the early napalm beat at 35 s (`demo_game.gd:211`) is
inside the hold so it is safe by accident, not by design. The gap between probe-break and
`SIEGE_AT_S` (1395–1440 s) is unguarded and is the second-worst window after S27-1.

### FINDING S27-4 — the silencing chain reads correctly.

`silenced()` (`camp_mortar.gd:87-98`) latches on tube destroyed or crew dead;
`_crew_gone()` (`:101-110`) correctly distinguishes "unspawned LazyGroup" from "dead" via
`_crew_seen`, returning `false` before the group ever wakes. `SiegeDirector._camp_mortar_silenced`
reads the `camp_mortars` group and requires ALL to be silenced
(`siege_director.gd:653-664`), gating the night ranging walk at `:641-642`. **This half is
correct and should not be touched.**

### FLAG-OFF INSTRUCTION (S27)

**`scripts/world/camp_mortar.gd:14` — `const HOLD_FIRE_S: float = 600.0` → `99999.0`.**

One constant. `_next_fire` is seeded from it at `camp_mortar.gd:46`, so the node never
reaches `_fire()` in a 45-minute run. The pit, the crew, the destructible tube, the
silencing latch and the `SiegeDirector` night-walk link all stay live and unaffected.
Nothing else in the repo reads `CampMortar.HOLD_FIRE_S` (grep: the only other hits are the
doc-comment cross-references at `pilot_recovery.gd:15` and `ambient_encounters.gd:20`).

---

## 2 · S28 — `scripts/world/pilot_recovery.gd` — DOWNED-PILOT RECOVERY

### Verdict: **FIX-CHEAP, but only just — two timeouts, ~10 lines. Do NOT ship it as written.**

### Reachability in the demo: **LOW and UNPREDICTABLE — maybe half of runs, and it cannot be steered.**

The chain needs every one of these:

1. A crewed ZPU exists — requires `zpu_crew_tag` + a camp (`mission_generator.gd:918-925`).
   Satisfied by the demo plan (`mission_generator.gd:840-842`).
2. A **Skyraider** must be the NEAREST `air_traffic` node within `ENGAGE_M = 420.0` m of
   the camp gun during a 1 Hz think (`zpu_gun.gd:20`, `:165-180`, `_acquire` at `:192-206`).
   `_acquire` returns the single nearest airframe — with `AIR_MAX_IN_SKY = 14`
   (`demo_game.gd:190`) and Hueys dominating `AIR_ROTATION` (`demo_game.gd:191`), the
   Skyraider frequently is not the nearest, and a non-Skyraider still burns the roll
   (`zpu_gun.gd:210-216`: `_rolled[id] = true` is set *before* the kind check).
3. `KILL_CHANCE = 0.35` (`zpu_gun.gd:27`), one roll per airframe ever (`:210-214`).
4. `_elapsed >= HOLD_FIRE_S 600` in PilotRecovery (`pilot_recovery.gd:16`, `:53`).
5. No siege (`pilot_recovery.gd:61-62`) and no live ambient encounter
   (`pilot_recovery.gd:65-67`).
6. `_passable_near` must return a crash site (`pilot_recovery.gd:69-71`); `Vector3.ZERO`
   aborts silently.

Skyraiders launch roughly every 6 × `AIR_CADENCE_S 42` ≈ 252 s (`demo_game.gd:187`, `:191`)
in pairs (`scripts/ai/air_traffic.gd:39` `"skyraider": [2, 2]`), so ~3 launches / 6
airframes fall in the 600–1395 s window, each a 0.35 roll *if* it wins the nearest-target
contest. **This is a coin flip, and a playtest that does not see it has not verified it.**
The wiring itself is sound: `ZpuGun` is added to `world` (`zpu_gun.gd:70`) and `AirTraffic`
is a child of `world` named `"AirTraffic"` (`mission_generator.gd:263-265`), so
`_flight_kind`'s `get_parent().get_node_or_null(^"AirTraffic")` (`zpu_gun.gd:228`)
resolves — that lookup is NOT broken.

### FINDING S28-1 (WORST) — **NO TIMEOUT ON EITHER PHASE, AND A STALL PERMANENTLY KILLS THE AMBIENT SYSTEM TOO.**

`pilot_recovery.gd:177-198`. `_tick_wait` exits only on pilot death (`:178-179`) or the
player closing to `WAKE_M = 12.0` m (`:20`, `:184-188`). `_tick_escort` exits only on pilot
death (`:192-193`) or the pilot reaching within `HOME_M = 30.0` m of `fsb_center` (`:22`,
`:195-197`). **There is no elapsed-time bound in this file at all** — grep of
`pilot_recovery.gd` for a phase deadline returns nothing; the only time constants are
`HOLD_FIRE_S` (`:16`) and `WRECK_BURN_S` (`:19`, cosmetic, feeds `FireHazard.create_at`
at `:92`).

Now the second-order damage. `encounter_active()` returns true for both WAIT and ESCORT
(`pilot_recovery.gd:84-85`), and `AmbientEncounters._pilot_busy()` reads it every roll
(`ambient_encounters.gd:181-182`, `:204-208`). So:

> **If the player never walks to the smoke column, the chain sits in `Phase.WAIT` for the
> rest of the run and EVERY ambient encounter is suppressed for the rest of the run.**

`_used` is latched true at `pilot_recovery.gd:74` so nothing resets it. The player is given
no marker by decree (`pilot_recovery.gd:6-7` — the smoke column IS the waypoint), and the
crash lands `CRASH_AHEAD_M = 220.0` m ahead of a transiting plane (`:18`, `:68`) — which on
a 512 m demo map can be any corner. **Ignoring the pilot is the likeliest player behaviour,
and it silently disables a second shipped system.** That is the worst finding in this audit.

**Fix (~10 lines):** a `MAX_WAIT_S` and a `MAX_ESCORT_S` (`AmbientEncounters` already has
the pattern — `MAX_LIVE_S`, `ambient_encounters.gd:26`), each falling through to `_lose()`
(`pilot_recovery.gd:209-214`), which already banks `pilot_lost` and clears the column.
The bounded failure exit **exists and is correct**; nothing calls it on a clock.

### FINDING S28-2 — the pilot DOES pathfind, but into the sealed navmesh named in FIX 0.

The pilot is a real `AllyBase` (`pilot_recovery.gd:139` `AllyBase.spawn_ally`), and
`spawn_ally` builds a `NavigationAgent3D` matched to `NavBaker.AGENT_RADIUS`
(`scripts/allies/ally_base.gd:2154-2159`), wired into `NavRouter` at
`ally_base.gd:437`. **It is not a lerp.** `set_order(FOLLOW)` (`pilot_recovery.gd:187`)
routes to the formation-slot follow at `ally_base.gd:1282-1320`, which tracks
`GameManager.player` — so the pilot goes where the player goes, which is the right shape.

But the ESCORT terminates on the pilot reaching **within 30 m of `fsb_center`**
(`pilot_recovery.gd:195-197`) — a point inside the compound. Cross-referencing
`production/HANDOFF_CODE_FIXES_2026-08-12.md:12-42` (**FIX 0, VERIFIED**): all ~80 parapet
colliders are reparented to `GameWorld` (`scripts/world/site_planner.gd:1607-1631`) and are
therefore invisible to `nav_baker.gd:374 _add_colliders`. **The navmesh has no perimeter
wall.** The pilot's agent will path straight through the berm, jam on the physical
collider, and `_rescue_snap` cannot help him — he is standing on valid navmesh
(`ally_base.gd:86-95`, the same reasoning as the handoff note). FIX 2
(`HANDOFF_CODE_FIXES_2026-08-12.md:113-149`) compounds it if the player takes shelter
indoors.

**This is the exact scenario S28-1's missing timeout was supposed to catch, and it is a
navmesh defect that is already on the fix list.** S28's stall is therefore not a remote
possibility — it is the *expected* outcome until FIX 0 lands.

### FINDING S28-3 — what happens on each failure path

| Event | Handled? | Pointer |
|---|---|---|
| Pilot dies (WAIT or ESCORT) | ✅ `_lose()`, `pilot_lost` flag, column cleared, `Phase.DONE` | `pilot_recovery.gd:178-179`, `:192-193`, `:209-214` |
| Player leaves / never comes | ❌ **infinite WAIT**, ambient dice dead | `pilot_recovery.gd:177-188` |
| Path fails / pilot stuck | ❌ **infinite ESCORT**, ambient dice dead | `pilot_recovery.gd:191-197` |
| No passable crash site | ✅ aborts before `_used` is set, flight escapes | `pilot_recovery.gd:69-74` |
| No passable pilot seat | ⚠ falls back to `pos + (6,0,0)` — an unvalidated point that may be inside the wreck or off a cliff | `pilot_recovery.gd:135-138` |
| No passable picket site | ✅ silently no pickets; chain still works | `pilot_recovery.gd:149-150` |
| Wreck placement fails | ❓ **no pointer** — `SitePlanner.place_structure` return is discarded | `pilot_recovery.gd:91` |

### FINDING S28-4 — the pilot fights the player's own squad for a file slot.

`file_slot` defaults to `1` (`ally_base.gd:287`) and `SquadSystem` assigns `ally.file_slot = i + 1`
(`scripts/squad/squad_system.gd:95`), so the pilot shares slot 1 with the first squad
member. In file mode the slot is `player.pos - dir*3.5 + side*1.1` (`ally_base.gd:1304-1306`)
— **identical for both men**. They will shove each other for the several minutes of the
escort. Cosmetic, but it is on screen continuously during the one beat S28 exists to sell.
One line: set `_pilot.file_slot` to something outside the squad's range at
`pilot_recovery.gd:139-145`.

### FLAG-OFF INSTRUCTION (S28)

**`scripts/world/pilot_recovery.gd:16` — `const HOLD_FIRE_S: float = 600.0` → `99999.0`.**

`request_down` short-circuits on `_elapsed < HOLD_FIRE_S` at the very first line of the
gate (`pilot_recovery.gd:53`) and returns `false`, which `ZpuGun._roll_kill` already
tolerates (`zpu_gun.gd:222-224` — it ignores the return). The ZPU keeps firing its tracer
theatre, the crew keeps being killable, `aa_killed` still banks. **Critically, this also
un-blocks AmbientEncounters**, because `encounter_active()` can then never be true
(`pilot_recovery.gd:84-85` — `_phase` never leaves `IDLE`).

Alternative, if the whole chain must not exist: comment `mission_generator.gd:925`
(`PilotRecovery.attach(world, director)`). `ZpuGun._roll_kill` null-checks the group lookup
at `zpu_gun.gd:222-223`, so removal is safe. Prefer the constant — it is reversible without
touching the generator.

---

## 3 · AMBIENT — `scripts/world/ambient_encounters.gd` — THE WALKING DICE

### Verdict: **FIX-CHEAP** (two guards, ~6 lines). The start-gates are the best-guarded thing in this audit; the LIVE state is not guarded at all.

### Reachability in the demo: **MODERATE — a ~10-minute window, 1–2 encounters, and only if the player leaves the wire.**

The eligible window is `HOLD_S 600` (`ambient_encounters.gd:21`) → night ≈ 1184 s
(`ambient_encounters.gd:174-175` gates on `MissionWeather.is_night`) = **584 seconds**.
Within it the player must accumulate `ROLL_EVERY_M = 65.0` m of travel beyond
`WIRE_M = 110.0` m from `fsb_center` (`:18`, `:30`, `_track_walk` at `:157-170`), then pass
`EVENT_CHANCE = 0.35` (`:19`), then serve `COOLDOWN_S = 240.0` before the next
(`:23`, `:271`). Ceiling in practice: **2, maybe 3.** Day caps allow 4 total
(`DAY_CAPS`, `:25`). A player who stays inside the wire sees **zero** — and that is correct
design, not a defect.

### WHAT IS GUARDED (the start gate, `_try_roll`, `ambient_encounters.gd:172-201`)

| Guard | Pointer |
|---|---|
| First 10 minutes | `:173` `_elapsed < HOLD_S` |
| Post-encounter cooldown | `:173` `_cool > 0.0` |
| Night | `:174-175` `MissionWeather.is_night` |
| The siege | `:179-180` `director.siege.active` |
| The pilot chain (two-way) | `:181-182` `_pilot_busy()` → `:204-208` |
| Inside the wire | `:164-169` — the walk meter only accrues beyond `WIRE_M` |
| Teleports / Huey rides | `:164` `step > 8.0` discards the sample |
| Standing still | `:162-169` — no step, no roll |
| Per-type day caps | `:212`, `:220`, `:225` |
| Harass only near the ville | `:211-216`, 40–160 m |
| Contact only at audio range | `:224-232`, 110–200 m |

**That is a genuinely thorough gate.** The opening bunk beat, the siege and the pilot escort
are all correctly excluded from *starting* an encounter.

### WHAT IS **NOT** GUARDED — enumerated

**N-1 (WORST) — a LIVE encounter is not interrupted by anything.** `_physics_process`
branches to `_tick_live` before any gate is consulted (`ambient_encounters.gd:145-147`).
`MAX_LIVE_S.contact = 420.0` (`:26`). A firefight started at 1370 s therefore runs until
~1790 s — **through the entire 45-man assault** (`SIEGE_AT_S` 1440, `demo_game.gd:58`),
adding 3 `FriendlyPatrolGroup` allies (`CONTACT_ALLIES`, `:33`) and 3 tracked VC
(`CONTACT_VC`, `:34`, spawned at `:412-417`) to the AI load at the single most
perf-critical minute of the demo — against a project whose last bench was **CPU-bound in
the AI at 23.1 fps** (`production/OVERSEER_CHARTER.md:94`). Night is likewise only a
start-gate, never a live-gate.

**Fix (~3 lines):** in `_tick_live` (`:493-503`), if `director.siege.active`, force the
RTB/cleanup path — `_order_rtb` + `_free_element` + `_finish` already exist
(`:453-463`, `:486-490`, `:264-272`).

**N-2 — `_hidden_near` returns a VISIBLE point when every try is in line of sight.**
`ambient_encounters.gd:238-253`:

```
best = cand                                   # :245  assigned unconditionally
if player == null: break                      # :246-247
if not CombatManager.has_line_of_sight(...):  # :249-251
    break
return best                                   # :253  ← last candidate, LOS or not
```

After `SPAWN_HIDE_TRIES = 6` (`:45`) failures it returns the sixth candidate regardless.
`_start_patrol` then materialises **4 US soldiers** (`PATROL_MEN`, `:33`) at 70–130 m
(`:43-44`, `:347-348`) in the player's plain view. The function's own doc-comment at
`:235-237` claims it is "a point the player cannot currently see" — **the comment asserts a
guarantee the code does not make.** Fix: return `Vector3.ZERO` when no hidden candidate was
found and let `_start_patrol`'s existing `if at == Vector3.ZERO: return` (`:349-350`)
decline the roll. ~2 lines.

**N-3 — `_start_harass` has no visibility check at all.** It plants a `LazyGroup` at the
fixed `_harass_anchor` (`:276-286`) with `activation_range = 120.0` (`:282`). The harass
eligibility window is 40–160 m from the ville (`HARASS_NEAR_M`/`HARASS_FAR_M`, `:38-39`),
so a player at 100 m triggers a roll **and is inside activation range** — three VC
materialise in the village while he is looking at it.

**N-4 — harass can never time out while the player loiters.** `_tick_harass`
(`:289-318`) cleans up ONLY when `far > HARASS_ABANDON_M 260` **AND** `age > MAX_LIVE_S.harass 300`
(`:296-298`, `:313-318`). A player who watches from 200 m without engaging leaves `_live =
"harass"` set forever → `encounter_active()` true forever (`:130-131`) → **no further
encounters, and `PilotRecovery.request_down` is blocked for the rest of the run**
(`pilot_recovery.gd:65-67`). Same soft-lock class as S28-1, mirrored. Fix: make the
`age > MAX_LIVE_S.harass` branch unconditional. ~2 lines.

**N-5 — surviving contact VC are never reaped.** `_tick_contact` frees the friendlies
(`_free_element`, `:486-490`) but `_finish` only clears `_vc_tag` (`:264-272`). The comment
at `:434-435` rules this deliberate ("the AO's business"). Bounded at 3 men; noted, not a
defect.

**N-6 — cross-class private access.** `_lg._spawned` (`:295`), `_fp._spawned` (`:373`),
`fp._men` (`:460`, `:466`, `:479`, `:487`). Works today; fragile. Not a demo risk.

**N-7 — `_free_element` on an unspawned group.** `_men_gone` iterates an empty `_men` and
returns `true` (`:465-471`), so an unspawned patrol self-cleans after
`PATROL_MIN_LIVE_S 60` (`:51`, `:380-384`). **Correctly bounded — this path is fine.**

### FLAG-OFF INSTRUCTION (ambient)

**`scripts/world/ambient_encounters.gd:19` — `const EVENT_CHANCE: float = 0.35` → `0.0`.**

`_try_roll` reads `if _dice.randf() >= EVENT_CHANCE: return` (`:183`). `randf()` returns
`[0,1)`, so at `0.0` the comparison is always true and the function always returns before
any encounter is staged. The node stays alive, `attach` still prints its arm line
(`:122-124`), the walk meter still runs, and `encounter_active()` stays `false` so
`PilotRecovery` is not blocked. Nothing else reads `EVENT_CHANCE` (single grep hit).

---

## 4 · S29 — `scripts/world/tree_break_system.gd` — BLAST DESTRUCTION

### Verdict: **FIX-CHEAP** (one 2-line guard for the gunplay defect; the perf hazard is a 3-line dedup). Do NOT flag off — the 8/11 fix is real and the naming is correct.

### Reachability in the demo: **CERTAIN, and heavily.** Every explosion routes here —
`CombatManager.apply_explosion_damage` (`scripts/autoload/combat_manager.gd:200`) and
`DamageSystem.apply_damage` (`terrain/systems/damage_system.gd:194`) — plus every AOE
projectile's flight test (`scripts/combat/projectile_base.gd:276-290`). The demo's seven
scripted air beats (`demo_game.gd:236-244`) include CBU, two napalm runs and a bomb, on top
of the camp mortar, the siege ranging walk and every RPG the 45 men carry.

### (a) DOES A BLAST PROMOTE ONLY THE HIT TREE? **No — by design, and the design is right, but there is no yield gate.**

- **Single resolved hit** (`promote`, `:239-244`) consumes exactly one entry. Correct.
  **⚠ FOSSIL: `promote()` has ZERO callers repo-wide** (grep for `promote(`: the only hits
  are `GarrisonDefender.promote`, an unrelated symbol). It was planned at
  `production/BUILD_PLAN_2026-08-07_LOOPS.md:32` and never wired — `projectile_base.gd:279`
  uses `query_ahead` and then routes damage back through `apply_blast`. FOSSIL LAW: wire it
  or cut it.
- **Blast** (`apply_blast`, `:205-234`) sweeps every registered instance whose **horizontal**
  distance from centre is ≤ `radius` (`:220-222`) and takes up to
  `MAX_TREES_PER_BLAST = 12` + `MAX_BUSH_PER_BLAST = 8` (`:17-18`). So a mortar shell flattens
  a **10 m circle** of jungle (`mortar_81mm.tres:16`), an RPG an 8 m circle
  (`rpg7_rocket.tres:16`), a Snakeye a 16 m circle (`snakeye_bomb.tres:16`).

**There is NO minimum-yield threshold anywhere.** Neither call site passes damage
(`combat_manager.gd:200`, `damage_system.gd:194` both pass only `center, radius`), and
`apply_blast` never reads one. Checked against the explosive values of record
(`CLAUDE.md:196-197`): **M26 190 · M79 150 · LAW 250 · RPG-2 250 · RPG-7 290** — the code
distinguishes none of them. The only differentiator is `aoe_radius`, and by that measure
an **M79 (150 dmg, 6 m — `m79_he.tres:16`) fells the same 12 trees as an RPG-7
(290 dmg, 8 m)**. A thrown frag and a rocket flatten comparable stands of timber.

Whether that is wrong is the Summoner's call, not mine — but it is undocumented, and the
file's own header (`:3-8`) claims a "banded break" doctrine while the band selection is by
**burst height only** (`break_at`, `:346-362`: `at_high` compares `height_m` to
`cut_low`/`cut_high`, nothing else). **The bands are height bands, not yield bands.** If the
intent was for yield to matter, it is a MISSING FEATURE, not a bug.

Also note: within the radius, selection is **iteration order, not nearest-first**
(`:212-227`). In dense canopy a 12-tree cap picks arbitrary trees, so the felled set can
look scattered rather than centred on the crater.

### (b) DOES IT BREAK AT THE RIGHT BAND? **Yes, and the ART NAMING MATCHES. Verified against disk.**

- Code builds `nm + "_stump"`, `nm + "_stem"`, `nm + "_crown"` (`:293`) and asks the layer
  for `"%s_%s"` per suffix (`:336`, suffix list `["stump","stem","crown"]` at `:333`).
- `data/veg_break_bands.json` (3,813 bytes, 2026-08-11 20:42) holds **20 species, every one
  carrying `parts: [stump, stem, crown]`**, generated from the GLBs by
  `tools/gen_veg_break_bands.py` (`_source` field, line 2). **No naming mismatch.** This
  matches the memory note that the parts are `_stump`/`_stem`/`_crown`, never
  `_low`/`_mid`/`_high`.
- `break_at` picks the joint nearest the burst height (`:353-354`), keeps stump+stem
  standing on a high break and stump alone on a low one (`:358-362`). Correct.
- The 8/11 `Array[String]` ternary crash is genuinely fixed — the two literals are now
  assigned to typed locals (`:358-362`), with the reason recorded at `:356-357`.

**Two data defects visible in the bands file, both silent:**

| Species | `top_m` | `trunk_r_m` | Problem |
|---|---|---|---|
| `banana_a` | 2.045 | **1.644** | trunk radius ≈ 80 % of total height |
| `bush_c` | 1.54 | **0.933** | knee-high bush with a 1.9 m-wide "trunk" |
| `bush_b` | 1.34 | 0.685 | same class |
| `lp_bush_a` | 0.46 | 0.399 | ground clutter with a 0.8 m-wide "trunk" |

`gen_veg_break_bands.py` is measuring crown/foliage width as trunk radius for the
broad-form species. Harmless for `apply_blast` (which only uses the origin), but see (d).

### (c) COLLIDER FLOOD — **the physics bodies are bounded. The CHUNK REBUILDS are not, and that is the real hazard.**

Per blast, worst case: **20 `BrokenTree` nodes** (12 + 8, `:17-18`, `:228`). Each spawns:

- up to 3 `MeshInstance3D` (`:339-343`),
- **exactly one `StaticBody3D` "SnagTrunk"** whenever `trunk_r > 0` (`:365-379`) — and all
  20 species have `trunk_r_m > 0`, so **always one**,
- one pivot `Node3D` (`:392-394`) and one 2.0 s `Tween` (`FELL_TIME`, `:318`, `:403-408`).

Drained at `BREAKS_PER_FRAME = 6` (`:19`, `:277-286`), so 20 breaks resolve over ~4 frames
and each body lives ~2 s before `_settle` frees the node (`:445`) and hands the geometry to
`VegetationManager._fell_registry` for the pooled 70 m ring (`:417-446`,
`terrain/vegetation/vegetation_manager.gd:451-457`, `:545-553`). **Steady-state collider
count is bounded by the ring, not by this system. That part is correct.**

**But:** `_settle` calls `vm.call("rebuild_chunk", chunk)` **once per broken tree**
(`tree_break_system.gd:444`). `rebuild_chunk` is a full `clear_chunk_visuals` +
`_rematerialize` of a 256 m vegetation chunk
(`terrain/vegetation/vegetation_manager.gd:468-476`). Twenty trees in one blast almost
always share one or two chunks → **up to 20 redundant full-chunk vegetation rebuilds per
blast, with no dedup, no budget and no coalescing.**

Now scale it. `_break_queue` (`:26`, appended at `:233`) has **no length cap**. The CBU
beat drops `CBU_CANS 3` × `CBU_BOMBLETS 16` = **48 bomblets**
(`scripts/gameplay/fire_plan.gd:35`, `:42`), each with `aoe_radius 5.0`
(`data/projectiles/cbu_bomblet.tres:16`), each calling `apply_blast` independently.
Worst case that is **48 × 20 = 960 queued breaks → up to 960 `rebuild_chunk` calls**,
draining over ~160 frames. And it is scheduled at `SIEGE_AT_S + 205` ≈ **1645 s — inside
the 45-man assault** (`demo_game.gd:241`).

**This is the single largest perf risk in the four systems, it lands on the demo's climax,
and it is exactly the "its def laggy with everything going on" the Summoner reported
(`SHIP_AUDIT_2026-08-11.md:58`).**

**Fix (~3 lines):** collect the touched chunks in a set and rebuild each **once** per
drain frame, rather than once per tree, inside `_process` (`:277-286`) — the same
`by_chunk` coalescing pattern `_consume` already uses at `:249-274`. Optionally cap
`_break_queue.size()`.

**Secondary:** `add_break_hole` appends one entry per consumed instance
(`tree_break_system.gd:268-269` → `vegetation_manager.gd:461-464`), and `_veg_holes` is
never trimmed. 960 holes are then re-tested against every plant in `_build_scatter`
(`vegetation_manager.gd:539`). Bucketed (`_veg_hole_buckets`), so probably survivable —
but it is unbounded growth on the same event.

### (d) FINDING S29-1 (WORST GAMEPLAY DEFECT) — **rockets detonate on undergrowth.**

`register_chunk` registers **every** species in `_bands` (`:75-82`), bushes included.
`query_ahead` (`:136-163`) then tests each as a vertical trunk cylinder via
`_ray_hits_trunk` (`:167-198`) using `band.trunk_r`. `_is_bush` **exists** (`:61-63`) and is
used ONLY for the `apply_blast` budget split (`:223`) — **it is never consulted in
`query_ahead`.**

`projectile_base.gd:276-290`: any round with `aoe_radius > 0` that crosses one of these
cylinders detonates there. So an RPG-7 fired at a man across a clearing will burst on:

- a `bush_c` — 0.933 m radius, 1.54 m tall (an 1.9 m-wide invisible shell-catcher at chest
  height),
- a `banana_a` — 1.644 m radius,
- an `lp_bush_a` — 0.399 m radius at ankle height, which a low rocket clips.

**This is a Pillar 1 defect** (*"weapons that kill like weapons"*): the grenadier's and the
VC rocketeer's rounds explode in the player's face on foliage he cannot see as an obstacle.
It also fires `apply_blast` at the shooter's own feet.

**Fix (2 lines):** skip bush species in the `query_ahead` cell loop —
`if _is_bush(String(entry["species"])): continue` at `tree_break_system.gd:153-155`.

### FINDING S29-2 — a failed part load leaves an invisible collider.

`BrokenTree._ready` (`:332-343`) `continue`s when `solid_mesh_for` returns null, but
`break_at` builds the `SnagTrunk` `StaticBody3D` unconditionally from `band.trunk_r`
(`:363-379`). A missing `_stump` GLB therefore leaves a **solid, `hard_surface`, invisible
post** standing in the jungle with no error. Silent-default class
(`production/SILENT_DEFAULTS_2026-08-12.md:73` already lists `:36` for the sibling case).

### FINDING S29-3 — `parts` is loaded and discarded.

`_load_bands` reads `cut_low/cut_high/top/trunk_r` and drops the `parts` array
(`:42-50`), while `_spawn_broken` hardcodes the three suffixes (`:293`). Today every species
has all three so nothing breaks, but a future 2-part species would silently degrade rather
than fail. Minor.

### FLAG-OFF INSTRUCTION (S29)

**Full off — `scripts/world/tree_break_system.gd:15` — `const BANDS_JSON := "res://data/veg_break_bands.json"` → any path that does not exist.**

`_load_bands` then `push_warning`s (`:36`) and leaves `_bands` empty, so `is_breakable`
returns false for everything (`:57-58`), `register_chunk` drops every instance (`:80-82`),
`_cells` stays empty, `apply_blast` returns 0 at `:206-207` and `query_ahead` returns `{}`
at `:137-138`. **This is the exact, proven-inert state the jungle was in from 8/7 to 8/11**
(`SHIP_AUDIT_2026-08-11.md:42`) — the game shipped in it for four days with no crash. The
autoload must stay registered (`project.godot:38`); do NOT remove it, since
`combat_manager.gd:200`, `damage_system.gd:194` and `projectile_base.gd:279` call it
unconditionally.

**Cost of that flip:** `tests/test_support_fire_bench.gd:80` goes RED by design ("loaded 0
break bands"). That is a correct, honest failure — but it means the full-off switch is not
free during a suite run.

**Preferred partial (no test breakage, kills the perf hazard only) —
`scripts/world/tree_break_system.gd:17-18` — `MAX_TREES_PER_BLAST: 12 → 0` and
`MAX_BUSH_PER_BLAST: 8 → 0`.** `apply_blast` then returns 0 with an empty `doomed`
(`:228-230`) and no chunk rebuilds ever fire, while `query_ahead`, `is_breakable` and the
bench probe all keep working.

---

## SUMMARY TABLE

| System | Verdict | Worst finding | Flag-off (one constant) | Demo reachability |
|---|---|---|---|---|
| **S27 camp mortar** | FIX-CHEAP (~4 lines) | Guaranteed volley on the gunship ending — `camp_mortar.gd:127-133` | `camp_mortar.gd:14` `HOLD_FIRE_S` → `99999.0` | **Guaranteed**, 1–7 volleys |
| **S28 pilot recovery** | FIX-CHEAP (~10 lines) — do not ship as written | No timeout on WAIT or ESCORT; a stall permanently disables ambient encounters — `pilot_recovery.gd:177-198` + `:84-85` | `pilot_recovery.gd:16` `HOLD_FIRE_S` → `99999.0` | **Low / coin-flip** — `zpu_gun.gd:20,27,192-206` |
| **Ambient encounters** | FIX-CHEAP (~6 lines) | A live encounter is never interrupted — runs through the 45-man assault — `ambient_encounters.gd:145-147` + `:26` | `ambient_encounters.gd:19` `EVENT_CHANCE` → `0.0` | **Moderate** — 584 s window, 1–2 events |
| **S29 tree break** | FIX-CHEAP (~5 lines) — **keep, do not flag off** | Rockets detonate on undergrowth (`_is_bush` never consulted in `query_ahead`) — `tree_break_system.gd:153-163` vs `:61-63`; and up to 960 un-deduped `rebuild_chunk` calls on the CBU beat — `:444` | Partial: `:17-18` caps → `0`. Full: `:15` `BANDS_JSON` → missing path (turns `test_support_fire_bench.gd:80` red) | **Certain and heavy** |

## THE ONE THING I WOULD SAY TO THE ARBITER

Three of the four systems are **cheap to fix and expensive to leave**, and the cheapest
fixes are the ones nobody would find in a playtest: S27's post-siege volley only shows up
if the playtester is still watching after the assault resolves, and S28's soft-lock is
*invisible* — its symptom is that the ambient encounters the Summoner ruled in on 8/7 never
fire again, which reads as "the dice are boring", not as "a system is stuck".

**S28 and the ambient dice are welded together by a shared exclusivity gate**
(`pilot_recovery.gd:84-85` ↔ `ambient_encounters.gd:181-182, 204-208`). Neither side has an
unconditional timeout. **That coupling — not any single system — is the demo's real
soft-lock surface**, and it is roughly a dozen lines of clock to close on both sides.

**Named sacrifice (Law 2):** fixing rather than flagging costs roughly a half-day of code
against a 26-day calendar, and it does not touch the art critical path (C1). Flagging all
four off instead is free today and costs the four systems the Summoner explicitly ruled
into the demo — a lever `SHIP_AUDIT_2026-08-11.md:241` records as already spent.
