# GAME DESIGNER — the player's 45 minutes, and a Hearts & Minds that is FELT inside them

**Lens:** the loop and the clock. Every claim below carries a `file:line` read tonight at `5ddf69be`; where a
doc and the code disagree, the code is cited and the doc is named as wrong. No game file was edited; no
suite was run; no headless probe was run (the findings are constants and call sites, readable cold).

---

## 0 · WHAT THE BRIEFING GETS WRONG (the code wins)

1. **A 15-minute assault is impossible today.** `SiegeDirector.MAX_DURATION_S = 480.0`
   (`scripts/missions/siege_director.gd:77`) and `_run_siege` breaks the siege with reason `"dawn"` the
   moment `_elapsed >= MAX_DURATION_S` (`:684-686`). Every demo night ends at 8:00 of fighting whatever
   the phases say. The handoff §0A's phase table (2-3 + 4-5 + 3-4 + 3-4 = 12-16 min) cannot occur.
   `demo_game.gd:59` still comments "360 s of it". **This is the one thing the Arbiter's read missed:**
   the briefing names `SIEGE_AT_S`, `END_BACKSTOP_S` and the reinforce path, never the 480 s wall.
2. **`threat_level` has ZERO live consumers in the demo.** `_maybe_open` returns at
   `siege_director.gd:239-240` when `GameFlow.demo_mode` — the night roll at `:256` is never reached;
   `:283` is the sleep roll, post-launch. `_grant_fire_support` reads the label at `:1536` and then the
   demo override at `field_director.gd:1557-1563` hard-assigns `{"bombs": 3, ...}` regardless of tier;
   the only toasts that read the tier (`:1580-1581`) still fire, so the label is SPOKEN and never ACTED
   on. "Enemy pressure by another name" is generous: in the shipping demo it is a string on the barracks
   wall. Making it a variable with a consumer is part of this council's job, not a given.
3. **The witnessed crash is BUILT, not a candidate.** `scripts/world/pilot_recovery.gd` (S28): the ZPU's
   kill roll (`zpu_gun.gd:27` `KILL_CHANCE 0.35`, `:230-234`) downs a transiting Skyraider after
   `HOLD_FIRE_S 600` (`pilot_recovery.gd:16, :61`), wreck + smoke column 220 m ahead of the plane
   (`:18`), a pilot who wakes at 12 m and FOLLOWs (`:218-234`), an escort that banks
   `state.flags["pilot_recovered"]` at 30 m from `fsb_center` (`:236-255`), a loss branch (`:257-263`),
   and the demo end card already prints THE PILOT CAME HOME / DIDN'T MAKE IT (`demo_game.gd:776-780`).
   It is attached only where the plan names a ZPU crew (`mission_generator.gd:954-962`) — the demo camp
   has one (two-quests plan `:88`). **It is a coin flip:** an unseeded RNG (`pilot_recovery.gd:43-45`)
   on a 0.35 per-pass roll on a plane that has to transit at all. The handoff §0A prices a build; the
   demo needs a GUARANTEE (the same demo short-circuit the informer already has,
   `mission_generator.gd:1297-1301`).
4. **The DOOR is built too.** `ambient_encounters.gd` `_start_contact` (`:404-430`): 3 US vs 3 VC, real
   combat AI both sides, 110-200 m from the player, capped once a day (`:25`), rolled at 0.35 every 65 m
   walked (`:18-19`) after a 600 s hold (`:21`), exclusive with the pilot chain (`:222-226`). Also dice.
5. **The village sweep cannot finish quietly.** `_poll_sweep` needs a kill in the 90 m ring
   (`field_director.gd:1663-1665`), a tunnel shut (`:1667-1669`) or a stash stripped (`:1671-1672`).
   `plan_demo_world` stamps no `FieldCache` and no tunnel at the village (grep `FieldCache|stash` in
   `mission_generator.gd` = 0 hits); the only enemies that ever stand there are the informer's four
   (`INFORMER_RESPONSE 4`, `:402`, spawned 90-140 m from where he saw you, `:807-816`). A player who is
   never seen gets no SWEEP COMPLETE, Six never offers the camp (`_finish_sweep :1701-1712`), and the
   toast channel goes silent for the rest of the day. **This is the dead-air generator, not the clock.**
6. **"The paddy empty at midday" is already the schedule.** Farmers REST 11:00-12:00 and WALK_HOME
   12:00-13:00 (`civilian_schedules.gd:33-38`). The wordless reading has to be a DEVIATION from the
   schedule — the afternoon paddy (13:00-17:00 WORK, `:39-40`) that stays empty — or it reads as nothing.
7. **`test_demo_arc.gd:32-41` pins 1395/1440/06:30/38x/20x "until he re-decrees them."** He has
   (45 minutes). "Must stay green" means rewritten to the new numbers in the same change, not kept at
   38x. It is a pure-constants test (`resolve_stress` is static, `demo_game.gd:133`), so the rewrite is
   the cheapest edit in this council.
8. Minor: the briefing's `field_director.gd:1520-1535` for "loud patrols raise threat" is the header
   comment; the raise is `campaign_state.gd:239-243` (`on_mission_end`, kills >= 12 → +0.05), which in
   the demo fires once, at `_bank_patrol :2109`, AFTER the only walk-out — and nothing reads it after.

---

## 1 · THE CLOCK — what fits 45 minutes

The engine sells the day as four hard lighting events on the `sim_clock.period_at` boundaries 07:00 /
17:00 / 19:00 / 05:00 (`sim_clock.gd:70-77`; `mission_weather.gd:40` only seats the boot hour). The demo
needs: DAY snapping on as the player clears the gate, a DUSK window to walk home in, NIGHT at ~25:00,
and a night long enough to hold a 15-minute fight without crossing midnight (midnight increments
`sim_day`, which re-arms `_granted_day` at `field_director.gd:1528-1531` and is the exploit
`demo_game.gd:51-55` names).

| Constant | Today | Proposed | Why |
|---|---|---|---|
| `START_HOUR` (`demo_game.gd:44`) | 6.5 | **6.5** | DAY snaps at 60 s instead of 47 — still "the player clearing the gate" (`:39-43`) |
| `DAY_RATIO` (`:49`) | 38 | **30** | 06:30→19:00 = 12.5 h = **1500 s = 25:00**. DUSK lighting at 17:00 = **1260 s = 21:00** — the return window is 4 real minutes of dusk light |
| `NIGHT_RATIO` (`:56`) | 20 | **12** | 1 sim-hour = 300 s. Assault 29:00→44:00 runs sim 19:48→22:48. **Midnight = 1500 + 1500 = 3000 s (50:00) — never crossed.** At 20x midnight lands at 2400 s (40:00), mid-assault |
| `PROBE_AT_S` (`:58`) | 1395 | **1650** (27:30, sim 19:30) | 150 s after the seam, as today's 211 s gap but tighter — stand-to must not be a wait |
| `SIEGE_AT_S` (`:59`) | 1440 | **1740** (29:00, sim 19:48) | 90 s of probe before the wave, as today's 45 s |
| `SiegeDirector.MAX_DURATION_S` (`siege_director.gd:77`) | 480 (const) | **a `max_duration_s` var the demo sets to 900**, exactly as it sets `ring_min` (`demo_game.gd:636-645`) | the only way 15 minutes exists. The full game keeps 480 |
| `END_BACKSTOP_S` (`:74`) | 2700 | **2900** | under midnight (3000); 260 s past the 900 s cap |
| `_arc_hour_at` / `_stress_boot_hour` (`:247-256`) | derived | untouched | derived from the ratios; `--stress` follows |

`SIEGE_AIR_BEATS` (`:395-403`, 25→300 s) are re-spaced across 900 s at the same ≥35 s spacing (`:393-394`);
`WAVE_RAMP_S 180` (`siege_director.gd:68`) stretches to ~360 so the cap ramp is the first phase, not a
blink. `SIEGE_STRENGTH 45` does not move (`demo_game.gd:148-152`, the LIVE_CAP finding).

---

## 2 · THE 45-MINUTE TABLE (a normal player, not a harness)

Walk 5.0 m/s (two-quests plan `:23`), village 185 m from centre (`mission_generator.gd:770-772`),
compound half-extents 149×111 m (`site_planner.gd:809` per the plan). All "existing" pointers verified.

| Block (min) | The beat | EXISTING system that fills it | Minimum NEW content | A player who ignores it |
|---|---|---|---|---|
| **0:00-1:00** THE COT | Title card, the bunk, the sky already working | `TITLE_SPLASH` (`demo_game.gd:199-200`); `AIR_OPENING` beats at 3/14/26/48 s (`:337-344`); gate order at 10 s files the squad to the gate (`_tick_opening :524-579`); DAY snaps at 60 s | none | walks the compound; the squad holds the file up to `GATE_ORDER_MAX_S 210` (`:516`) then FOLLOWs him |
| **1:00-4:00** THE WIRE AND THE WORD | Napalm on somebody else's horizon; one man says one thing face to face; out the gate | `NAPALM_EARLY_S 35` (`:370, :414-417`); the wire crossing at 120 m tasks the village and grants 3 bombs (`_poll_wire_gate :1465-1505`, `_grant_fire_support :1557-1563`); `rebark_patrol` (`:1585-1595`) | **ONE faction man** pinned to a billet on the gate route with **one unprompted line** (ADR-038 §2a; two-quests plan §5-6: the `asked` bit, never re-readable) | walks out anyway; Six's sweep fires at 120 m regardless. The ask is forgettable by law (plan `:135-137`) |
| **4:00-11:00** THE VILLE | The sweep circle sits on the village; the informer must SEE you; the paddy is full (sim 07:00-11:00 = real 1:00-9:00 at 30x) | informer 15 m + LOS, 25 s, four VC from the far side (`civilian.gd:531-549`, `field_director.gd:789-816`); `_call_for_aid` when shooting starts and the player is elsewhere (`civilian.gd:459-477` → `dynamic_mission_factory.gd:65-69`); chickens as noise traps (`mission_generator.gd:1326-1329`) | **none for the beat.** This is where producers P1/P2/P4 (§4) record the village's first facts | sits at 40 m, is never seen, kills nobody → no SWEEP COMPLETE (§0.5). He walks on to the camp or the temple on his own bearing — Pillar 3 — and the smoke column (next row) is the next thing he sees |
| **11:00-21:00** THE OUTING — the bird | A Skyraider is hit over the trees, goes down 220 m ahead, smoke column stands; a pilot and a VC picket; the walk home with a man who "keeps up" | `PilotRecovery` end to end (`pilot_recovery.gd:60-89, :163-196, :218-255`); hunters on the evidence lead, 2-4 men every 100-160 s, pool 12 with a 6-man floor per walk-out (`field_director.gd:198-224, :1500-1504`); the ambient contact as the fallback door (`ambient_encounters.gd:404-430`) | **GUARANTEE the shoot-down:** in `demo_mode`, `request_down` is called on the first transiting Skyraider after `HOLD_FIRE_S` regardless of the ZPU roll (same short-circuit shape as `mission_generator.gd:1300-1301`); if no Skyraider transits by 780 s, `AirTraffic.launch("skyraider","transit")` once from the arc (`demo_game.gd:490` already does this for the opening). **The escort is the slow verb** the two-quests plan asked for (`:51-54`): 220 m out + ~250 m home at FOLLOW pace ≈ 4-6 min without adding a metre of map | the column burns `WRECK_BURN_S 1500` (`:19`); the pilot waits `WAIT_TIMEOUT_S 420` then `_lose` (`:27, :222-224`) → `pilot_lost` → the card says so (`demo_game.gd:779-780`). The world does not stop; the hunters still come |
| **21:00-25:00** DUSK RETURN | DUSK light at 21:00; back through the wire; the patrol logs; the dead are read; the bird brings replacements | DUSK at 17:00 sim (1260 s); `_bank_patrol` at 95 m (`:1506-1516, :2095-2130`); `_read_the_dead`, `_call_replacements` (`:2129-2130`) | consumer **C-V** is on the walk home (the afternoon paddy, §4); faction man #2 speaks **unprompted**, reading the world; the pilot goes to the ward (`pilot_recovery.gd:250`) | stays out. NIGHT falls on him at 25:00; the assault opens ON THE FIREBASE anyway (`_poll_firebase_threat` runs regardless of `patrol_out`, `:1735-1738`; ADR-035 §1) and he walks home into it. Fail forward, no teleport |
| **25:00-29:00** STAND-TO AND THE PROBE | Night; the ratio drops; 11 men on the wire; the garrison stands to; mortars range | seam at `MissionWeather.is_night` (`demo_game.gd:608-612`); `_open_siege(PROBE_STRENGTH 11)` (`:615-617`); stand-to (`field_director.gd:1799-1841`); `MORTAR_FIRST 12-20 s` (`siege_director.gd:109-110`) | consumer **C-E** (warning quality) lands here (§4) | nothing to ignore — it happens to him |
| **29:00-44:00** THE ASSAULT | 45 men in four squads plus a base of fire; the press rotates; illum; breaches; the wire is overrun or holds; they break | `reinforce` to 45 on the probe (`demo_game.gd:649-662`, `siege_director.gd:347-396`); `ASSAULT_SQUADS 4` (`:397`); `_rotate_press` every 8 s (`:123, :902-940`); wave cap 8→50 over 180 s (`:66-68, :749-753`); illum every 70 s (`:140`); breach re-aim (`:481-540`); overrun (`:1081`); break at 42.5% (`:29, :690-692`); the reap (`:1230-1281`); seven air beats (`demo_game.gd:395-403`) | `max_duration_s` = 900 (§1); **two reinforce steps, not one** — 11→30 at 29:00, →45 at ~36:00 — the cheapest "phases" that fork no second combat path (handoff §0A, `:75`). The 45 is the budget; only the CADENCE moves | the garrison fights it (ADR-035 §4 credit rule). He can hide. The end card lists who held |
| **44:00-46:00** THE ENDING | They break; gunships on station; the frozen frame; names | `siege_ended` → `_on_raid_ended` → `_ending` (`:678-714`); the card (`:751-790`) | one line of consequence the card already carries (the pilot, `:776-780`) | none |

**Total: ~45-46 minutes for a walker; ~40 for a sprinter who skips the ville; ~50 for a man who
explores the temple.** All within the handoff's "target, not a gate" (`§0B :251`).

### The dead air, named, and what kills it

| Dead air | Where it is | What kills it |
|---|---|---|
| The quiet village that never "completes" and silences Six for the day | `_poll_sweep :1663-1672` needs a kill; the village has no cache and no tunnel | **Do not fix the sweep.** The bird is the next beat and it announces itself (`SANDY'S HIT`, `pilot_recovery.gd:87`); Six's silence is Pillar 3 doing its job. The ask at the gate gives the village a human reason that is not a completion flag (two-quests plan §6: "read the world, do not store a quest") |
| Minutes 10-13 with dice deciding whether anything happens | `HOLD_FIRE_S 600` + `KILL_CHANCE 0.35` + an unseeded RNG + a plane that has to transit | the guarantee (§2 row 4). ADR-020 §1: a guarantee is not a rail — he can watch the smoke and walk away |
| The walk home with nothing at the wire but a toast | `_bank_patrol :2118-2119` "PATROL 1 LOGGED" | the pilot walking beside him is the beat; the faction man's unprompted line; the ward door |
| The stand-to wait | 150 s between the seam and the probe | already short; the sentry's line (`:1887-1889`) and the ranging mortar own it |

### How the assault is ARMED — one authority, one occurrence id, a poor outing still defends

- **The authority is already one:** `DemoGame._open_siege` (`demo_game.gd:629-666`); `_maybe_open` bows
  out in demo mode (`siege_director.gd:239-240`); `reinforce` is the reinforcement path (`:347`). Nothing
  else may call `open_siege` in the demo — that is the grep guard (`open_siege(` in `scripts/levels/` =
  one site).
- **The arm is the NIGHT SEAM, never the quest.** `MissionWeather.is_night` is the same authority
  ADR-035 rolls on (`demo_game.gd:46-48`). OUTING RESOLVED is a **fact the ledger holds** (§4:
  `pilot:recovered|lost`, `contact:relieved`, or nothing) — it changes the assault's CONDITIONS, never
  whether it comes. The handoff's chain (`§0A :58-67`) maps: INTRO/OUTING = blocks 1-4 · RESOLVED =
  a ledger fact · RETURN = the wire crossing or not · ARMED = the seam at 25:00 · WARNING = the probe at
  27:30 · ATTACK = 29:00 · RESOLUTION = `siege_ended`.
- **Occurrence id:** `"demo_night:%d:%d" % [DEMO_SEED, SimClock.sim_day]`, written once to
  `director.state.flags["assault_id"]` when `_phase` goes 0→1 and printed with every `[DEMO] phase`
  line. Deterministic (seed + day, ADR-010); idempotent by construction (`_phase` only climbs, `:613-627`).
- **A poor outing:** pilot lost or never walked to → the same 45 men, the sentry's warning comes late
  (C-E), nobody new stands beside him (C-A), the card says THE PILOT DIDN'T MAKE IT. A player still
  outside at the seam: the siege opens on the base (ADR-035 §1) and the walk home is the defence's first
  phase. **No timeout ever moves him** (handoff `:71`).

---

## 3 · THE H&M MODEL — the smallest thing that makes ADR-038 §5 false

### The three variables, and the one design rule

> **A ledger of DEEDS, not a score.** Each variable is a SET of stable occurrence ids — what a village
> saw, what a man saw. Consumers ask *which* deeds happened, never *how many*. A set cannot be rendered as
> a number without somebody writing `.size()`, and that call is the grep guard.

| Variable | Shape | Lives where | Saves how | Deterministic how |
|---|---|---|---|---|
| **local support** | `support: Dictionary` village_id → `Array[StringName]` of deed ids | a new `ConductLedger` (RefCounted, like `EvidenceLedger`) held as `FieldDirector.conduct`, created in `setup` beside `evidence` — **not** CampaignState (the demo sandboxes it, `demo_game.gd:185-194`, and the value is per-AO), **not** WorldSim (a flat registry, `world_sim.gd:1-30`) | **it does not, in the demo.** One day, `EXCLUDE_SAVES`; it must survive `_bank_patrol` recreating `state` (`:2122-2126`), so it hangs on the director, not on `MissionState`. Post-demo: a versioned `conduct` dict on CampaignState, which is where ADR-017's province will read it | ids are `"<kind>:<site_id>:<serial>"`; `site_id` is the hash `_call_for_aid` already uses (`civilian.gd:475-477`); no RNG, no `Time` |
| **individual trust** | `trust: Dictionary` person_id → `Array[StringName]` of deeds that person **witnessed** (was within a witness radius of, alive) | same ledger | same | person_id = `member.name` for squad/garrison (`squad_roster.gd:84`), the pilot's unit name; witness radius reuses `EAR_WITNESS_M` (`player.gd:252`) |
| **enemy pressure** | `CampaignState.threat_level` + modifiers (`campaign_state.gd:22-23, :207-219`) | stays where it is | already saved | already |

The handoff's "small typed event result" (`§0B :212`) is the ledger's `record(id, site_id, persons,
witnesses, consequences: Array[StringName])`; `record` is idempotent (a set) and returns whether it was
new, so a consequence applies once across any reload.

### PRODUCERS (3-5, stable ids)

| # | Deed | Existing hook (the producer is a one-line call at) | Audience it moves |
|---|---|---|---|
| **P1** `informer:<village>:talked` | the villager who saw you left with the word | `civilian.gd:545-549` (`_transform_to_vc`) / `field_director.gd:789-792` (`_informer_answered` latch already exists) | village support; enemy pressure (`add_threat_modifier(+0.1, 1, "INFORMER")`, bounded) |
| **P2** `civ_killed:<village>:<n>` | a noncombatant died | `civilian.gd:1115-1123` → `field_director.gd:120-122` (counted today, consumed by nothing, `:117-119`) | village support; **trust** — every squad man within the witness radius `saw` it (Pillar 4: the men were there) |
| **P3** `pilot:<incident>:recovered` / `:lost` | the pilot walked home, or didn't | `pilot_recovery.gd:248-255` / `:257-263` (flags exist) | **trust** — the pilot himself, and every squad man alive at `_recover`. **This is the one personal-trust transition** the handoff allows (`§0B :214`) |
| **P4** `fire_near_ville:<village>` | the player's side fired within 60 m of a calm villager | `civilian.gd:459-465` (`_on_noise`, GUNSHOT/EXPLOSION, `team` is on the signal) — the branch that already calls `_call_for_aid` | village support (ADR-038 §4: fire discipline near the ville IS allegiance). One id per village per patrol — bounded |
| **P5** (opt.) `ear:<village>` | a villager watched the necklace grow | `player.gd:252-258` → `on_atrocity_witnessed` (`civilian.gd:1147-1160`) | village support (it already makes him an informer — P1 follows) |

Not built for the demo: a burned hooch (no burn verb on huts today), a supply task (no content), the
tax collector (ADR-019 §2 — no such enemy). Named so nobody claims them.

### CONSUMERS (one per audience, all FELT, none READ)

| Audience | Consumer | Where it plugs in | What the player sees | Bounded how |
|---|---|---|---|---|
| **VILLAGE** — **C-V THE AFTERNOON PADDY** | if `support[village]` holds any of P1/P2/P4, farmers' 13:00-17:00 `WORK` resolves to `WALK_HOME`/`REST`, the fisherman's 13:30-17:00 `FISH` likewise, the cook stays at the fire | `civilian_schedules.gd:28-43` `action_for(occupation, hour, who, wary := false)`; `civilian.gd:1288-1294` `scheduled_action` passes `director.conduct.wary(village_center)`. The `is_informer`/`GONE` men are untouched | on the dusk walk home the paddy he walked past full at 08:00 is empty at 15:00, the seedlings are in nobody's hand, the ville is indoors. **Zero words.** ADR-038 §2 rule 4 | it moves a schedule, never a spawn. A village that saw nothing works its afternoon exactly as today |
| **ENEMY** — **C-E WARNING QUALITY at the probe** | if P1 talked and P4 fired: the sentry's "MOVEMENT ON THE WIRE - STAND TO" (`field_director.gd:1887-1889`) is withheld until the first man is inside `FSB_THREAT_M 90` (`:1179`) — the mortar is the first warning. If P3 recovered and no P2: `probe_at -= 60` (the pilot's flight told battalion where the guns were — an intel line, ADR-019 §4 permits briefing language) | `demo_game.gd:613-617` reads `director.conduct` once at the seam; `_on_siege_began :1883-1890` takes a `warned: bool` | he hears the mortar before the shout, or the shout a minute early | 60 s and one toast. **45 men is 45 men.** Hunters: the first `_hunter_timer` (`:176`, 70-110 s) minus 20 s when P1 — bounded, no popping |
| **ALLY** — **C-A THE MAN WHO CAME HOME WITH YOU** | if P3 recovered: at `siege_began` the pilot (already an `AllyBase` with an M1911, `pilot_recovery.gd:14, :163-177`, parked at `_ward_pos` `:250`) stands to at the aid-station door on `OrderMode.HOLD` — a living named person in his base role (handoff `§0B :204`), not a squadmate, not on the roster, not on the card as squad | `pilot_recovery.gd` listens to `director.siege.siege_began` when `_phase == DONE and recovered` | the man he walked home is at the door with a pistol when the wire goes hot. He fought beside you because you came | he is `temporary` in data (not in `SquadSystem.members`, `squad_system.gd:27`); wounded is not healthy — HOLD, never FOLLOW |
| **ALLY (voice)** — the four factions | **two** faction men (the two the two-quests plan already priced, `§6`) each speak one **unprompted** line at the wire on return, chosen by pattern on the ledger: `pilot:recovered` → the draftee: *"that pilot's in the ward. He asked who you were."* · `fire_near_ville` → the dealer: *"my guy from the ville didn't come up the road today."* · nothing → the lifer: *"quiet day. Don't get used to it."* | a `FACTION_LINES` const on the faction man (a `Civilian` pinned to a billet, plan `§7.1`), spoken via `director.toast` on the player's approach inside the wire | four grievances on the channel radio traffic already rides | **ADR-038 §2a:** subject only. No numerals, no comparatives, no direction of change. Grep-enforced (below) |

### FELT vs READ — the guard, grep-enforceable

1. `tests/test_conduct_felt.gd`: **no `.size()` / `len(` / `is_empty()` on `conduct.support` or
   `conduct.trust` outside `scripts/missions/conduct_ledger.gd` and `tests/`.** The ledger exposes
   `saw(person, deed)`, `village_saw(village, deed)`, `wary(village)`, `warned()` — booleans and
   `StringName`s only; no `count`, no `label`, no `to_string`.
2. The same test walks every `FACTION_LINES` entry and fails on `\d`, `more|less|better|worse|half|
   most|every time|again|since you|coming around|turned` — ADR-038 §2a's illegal list, literally.
3. ADR-032's never-a-number sweep (`tests/test_reputation.tscn`, ADR-032 `:118-122`) extends to the
   end card and the toast log: no line may carry a support or trust numeral because none exists.
4. **The world channel is wordless by construction:** C-V changes a schedule and nothing else; no toast
   is emitted from `action_for`. A future PR that toasts "the paddy is empty" is the meter coming back
   (ADR-038 §2 rule 4) — the test asserts `action_for` emits nothing.

### Which ONE producer and ONE consumer per audience to build FIRST, and why

- **VILLAGE: P4 `fire_near_ville` → C-V the afternoon paddy.** P4 is the deed every player makes or
  withholds in minutes 4-11 whether or not he was seen; C-V is visible on the dusk walk home inside the
  same 45 minutes — **the only village consequence that pays out before the credits.** It needs no art,
  no line, no new node: one bool through `action_for`. And it is ADR-038 §4 in code: fire discipline IS
  allegiance.
- **ENEMY: P1 `informer talked` → C-E the withheld sentry.** P1 is the one H&M edge that already runs
  end to end (`civilian.gd:531-549` → `field_director.gd:789-816`); the probe is guaranteed by the arc,
  so the consumer is guaranteed to be felt. It gives `threat_level` its first demo consumer in the same
  change (`add_threat_modifier` at P1), which is what makes "enemy pressure" a variable rather than a
  barracks string (§0.2).
- **ALLY: P3 `pilot recovered` → C-A the man at the ward door.** The whole chain is built and banked
  (§0.3); the consumer is one `set_order` on a listener. It is the handoff's exact sample (`§0A :50`,
  "one soldier ... after seeing the player's actions, he chooses to accompany/help") without touching
  `SquadSystem.members` — the demo keeps its squad (ADR-044 §0), and "earn the men" is shown by ONE man,
  which ADR-044 §0.5 says is the shape (a man agrees to go out with you; nobody is awarded).
- The faction lines come **after** these three, because they cost art days (ADR-038 §5 "named
  individuals cost far more than dressing") and the three above cost none.

---

## 4 · WHAT IS SACRIFICED (Law 2)

- **The bird stops being a surprise.** Guaranteeing the shoot-down makes minute ~11 the same every run
  (ADR-020 §1 accepts exactly this trade for the first patrol; it is a guarantee, not a rail — the
  smoke column can be walked away from). Replay value moves to the seed, as GAME_GUIDE §8 already says.
- **A 900 s cap doubles the window for the stall class.** The 2026-09-11 pacing found nights running
  to dawn with 25-31 men ALERT at 60-150 m and the kill count flat (`siege_director.gd:946-957`,
  `_reaim_stalled`). A weak defence now spends up to 15 minutes in that state before "dawn" ends it.
  The fix is the same one the file already carries; the risk is that it is not enough.
- **The demo squad stays eight.** The RPG premise "you start alone" is NOT demonstrated; one pilot and
  four faction voices stand in for it. ADR-044 §0 rules this and the handoff `§0A :52` accepts it.
- **A ledger of sets cannot decay.** ADR-019 §3's "the cost comes later and quietly" — recruitment
  rising over weeks — is out of reach in a one-day demo, and a set has no rate. The demo shows the
  first day of a grudge, not the grudge. Post-demo the sets become dated (`EvidenceLedger` already
  shows the shape, `evidence_ledger.gd:19-27`).
- **Four men with lines cost art days** the ship budget does not have (ADR-038 §5). Two, not four.
- **30x means a sim hour every two minutes.** Nothing on a villager's schedule can be RENDERED as a
  day; the four lighting snaps sell it. The empty afternoon paddy therefore has ~8 real minutes to be
  seen (sim 13:00-17:00 at 30x = real 780-1260 s, i.e. 13:00-21:00 on the arc) — the dusk walk home is
  inside that window, which is why C-V is the village consumer and not the elder at the well.

---

## 5 · THE SINGLE RISKIEST EDIT

**Making `MAX_DURATION_S` a demo-settable `max_duration_s` and dropping `NIGHT_RATIO` to 12.** It is
one var and one const, and it is the edit every other number in §1 stands on — get it wrong and either
the assault is cut at 8:00 (today) or the sun comes up mid-fight / `sim_day` ticks and `_granted_day`
re-arms (`field_director.gd:1528-1531`). It also retimes seven air beats (`demo_game.gd:395-403`), the
wave ramp (`siege_director.gd:66-68`), `_stress_boot_hour` (derived, safe, `:247-256`) and rewrites
`test_demo_arc.gd:32-41`. Second riskiest: the shoot-down guarantee — `request_down` refuses when an
ambient encounter is live (`pilot_recovery.gd:71-74`) and the plane must be `in_transit()` (`:63`); a
guarantee that silently fails is worse than dice.

---

## 6 · THE CHEAPEST PROBE THAT PROVES IT RUNS

1. **`tests/test_conduct_ledger.gd` (pure, no world):** feed P1-P4 ids twice, assert each `record`
   returns new once; assert `wary(village)` flips on P4 and not on an unrelated village; assert
   `action_for("farmer", 15.0, "", true)` is `WALK_HOME`/`REST` and `false` is `WORK`; run the §3 grep
   guard over `scripts/`. Serial, seconds.
2. **`tests/test_demo_arc.gd` rewritten** to the §1 numbers, plus two new pure checks: night at
   `(19.0-6.5)*3600/DAY_RATIO == 1500` and midnight `> END_BACKSTOP_S` at `NIGHT_RATIO` — the
   invariant, not the literal.
3. **One headless arc probe** (`Godot_v4.7 --headless -- --test-save --demo-arc-probe`), the existing
   `--stress=assault` route with the clock seated at the seam and `max_duration_s 900`, printing
   `[CONDUCT] <id> -> <consumer>` for every consequence and `[DEMO] assault_id demo_night:...` exactly
   once; assert `siege_ended` reason ∈ {broken, wiped} within 900 s, or `dawn` with the survivors row.
   Under three minutes because the stress route collapses the day (`demo_game.gd:133-145`).
4. The census (`--npc-census`) unchanged.

---

## 7 · ANSWERS TO THE BRIEFING'S LIST, in one place

- **Table:** §2. **Clock:** §1 (30x/12x, 06:30, NIGHT at 1500 s, `max_duration_s` 900, backstop 2900).
- **Armed:** §2 — the night seam arms, `_open_siege` is the one authority, id `demo_night:<seed>:<day>`,
  a poor outing changes conditions only.
- **Dead air:** §2 table — the quiet village that cannot complete, the dice at minute 10, the empty wire.
- **H&M:** §3 — a ledger of deeds on `FieldDirector.conduct`; P1-P4; C-V/C-E/C-A; the grep guard.
- **First per audience:** §3 last block. **Sacrificed:** §4. **Riskiest:** §5. **Probe:** §6.
- **Briefing wrong:** §0 — the 480 s wall, `threat_level`'s zero demo consumers, the crash already built,
  the door already built, the unfinishable village sweep, the midday paddy that is already empty, the
  arc test that must be rewritten not kept.
