# Technical Director — the owner map and the cost (2026-09-13, night)

Lens: who OWNS each variable, what it costs on the Intel UHD, and the seams that already exist.
Every claim below carries a `file:line` read tonight at `5ddf69be`; where the briefing and the
code disagree, the code is quoted and the disagreement is listed in §8. Nothing was edited; no
suite was run; no live probe was run (the clock arithmetic is derived from constants, not measured).

---

## 0. The two facts the Arbiter's read missed

**0.1 The demo's assault is capped at 435 s TODAY, by a constant nobody named.**
`SiegeDirector.MAX_DURATION_S = 480.0` (`siege_director.gd:77`) breaks the siege with reason
`"dawn"` when `_elapsed >= MAX_DURATION_S` (`:684-686`). `_elapsed` is zeroed ONLY in
`open_siege` (`:319`); `reinforce()` deliberately leaves it (`:347-372`, its own header: "the
run's clock is the dawn deadline"). The demo opens the PROBE with `open_siege` at
`PROBE_AT_S` 1395 (`demo_game.gd:596`) and turns it into the assault with `reinforce` at 1440
(`:597`, the `d.siege.active` branch `:583-593`). So the run's clock starts at the probe and the
whole night — probe plus assault — ends by real second **1875 (31:15)**, the assault having had at
most 435 s. `_on_siege_ended` then toasts `"FIRST LIGHT - THEY'VE MELTED AWAY"`
(`field_director.gd:1927`) at sim ≈ 21:12, and `_on_raid_ended` ends the demo (`demo_game.gd:611`).
There is no 15-minute defence to lengthen; there is a 7-minute one to unlock, and the knob is a
`const` on the combat authority (BaseGame-V1 first, both branches).

**0.2 There is exactly ONE siege launcher in the demo already.** `_maybe_open` returns on
`GameFlow.demo_mode` before any roll (`siege_director.gd:239-241`); `roll_night_for_sleep`
(`:272-291`) is reachable only from the sleep station, which is gated off in the demo
(`sleep_station.gd:72`); `demo_game._physics_process` is the only caller of
`open_siege`/`reinforce` (`demo_game.gd:594-597`). The handoff's "three attacks" is a risk of
the NEW quest trigger, not a defect in the code. The council must not build a de-duplicator for a
duplication that does not exist — it must add the quest as a *condition* on the one launcher.

---

## 1. The three variables — where each lives with the least new machinery

| Variable | Owner (exists) | Save path in the demo sandbox | Deterministic? | New machinery |
|---|---|---|---|---|
| **Enemy pressure** | `CampaignState.threat_level` + `threat_modifiers` (`campaign_state.gd:22-23`), read through `effective_threat()` `:207-211` and `threat_label()` `:215-222`; written mid-op through `add_threat_modifier(delta, missions, reason)` `:226` | `user://campaign_demo.cfg` (`demo_game.gd:184`), written by `save_campaign` `:306-334` — but DEFERRED from `begin_mission()` at the wire (`field_director.gd:1481` → `:283-286`) until `_bank_patrol` commits (`:2116-2119`) | Yes: float deltas, no RNG. Boot is always MODERATE: `reset_campaign()` at `demo_game.gd:188` sets `BASE_THREAT` 0.35 | **None.** One guard line: `add_threat_modifier` refuses a duplicate `reason` — the `reason` string becomes the occurrence id (the field already exists on every modifier) |
| **Local support per village** | NEW `HmLedger` (`RefCounted`, pure, seeded — the exact shape of `EvidenceLedger` `evidence_ledger.gd:10-12` and `MissionState`), HELD by `CampaignState` as `var hm: HmLedger` | one `cfg.set_value("campaign","hm", hm.to_dict())` beside `:322`, one `get_value` beside `:361`, one line in `reset_campaign` `:410` and in `to_dict`/`from_dict` | Yes: ints moved by events; village id = `absi(hash(Vector2i(int(cx), int(cz))))` — the SAME id `civilian.gd:475-476` already uses for the distress dedup, fixed per layout, no instance ids | ~100 lines, one file, no autoload, no node |
| **Individual trust per named ally** | the roster dict. `AllyBase.member` IS the roster dict by reference (`ally_base.gd:285`); persisted as `CampaignState.roster` (`campaign_state.gd:29`, saved `:312`); new keys enter through `SquadRoster.migrate_member` (`squad_roster.gd:307-316`) exactly as `christened` did | same cfg, same `roster` key | Yes: ints; witness test is a distance check | **None** — two keys: `member["trust"]: int`, `member["trust_seen"]: Array[String]` (occurrence ids this man has consumed, so a reload cannot pay twice) |

Why NOT the alternatives the briefing names:
- `WorldSim` is a flat registry `entities.clear()`-ed every mission (`world_sim.gd:9, :30-34`); it has no lifetime past the world. Not an owner.
- The site plan `p.sites` is rebuilt per world from the seed (`mission_generator.gd:726-`); it is not saved and is not meant to be.
- `AgentRegistry` is live nodes only and its own header forbids the ledger walking `props` (`agent_registry.gd:12-14`); it stays the *witness* roster (who was within N m), never the store.
- A new autoload has process lifetime; the variables have campaign lifetime. `CampaignState` already owns that lifetime AND the sandbox repoint (`demo_game.gd:184-188`, `_exit_tree` `:281-289`). F15's "large scripts" is answered by keeping the logic in the `RefCounted` and only the plumbing in the autoload.

### 1.1 The typed event result, and why NOT DynamicMissionFactory's dedup

Contract (a Dictionary, built by the producer, applied by `HmLedger.apply(ev) -> Array[String]`):

```
{ id: StringName,            # deterministic, see the id table below
  kind: StringName,          # &"informer_escaped" | &"civilian_killed" | &"fire_near_ville" | &"village_spared" | &"patrol_relieved"
  at: Vector3, site: int,    # world pos; village id (0 when none)
  persons: Array[String],    # person ids: "<village_id>:<ci>" for villagers, roster "name" for allies
  witnesses: Array[String],  # allies within WITNESS_M of `at` (AgentRegistry.allies walk, agent_registry.gd:8)
  consequences: Array[String] }   # filled by apply(); printed as "[HM] <id> -> <consequence>"
```

`apply()` returns `[]` and writes nothing when `consumed.has(id)` — that is the whole idempotency.

**Do not reuse `DynamicMissionFactory._seen`** (`dynamic_mission_factory.gd:11`). Four reasons, all
in the code: (1) its keys are `get_instance_id()` (`:55, :86`, `friendly_patrol_group.gd:172`) or
a hash (`civilian.gd:475`) — instance ids are not durable, which the handoff §5.1 already rules
out, and `field_director.gd:1755-1758` XORs a wave counter into the key precisely because the
dedup was too coarse; (2) it records `_seen` BEFORE validating the event (`:39-42`; handoff G7
names it); (3) its lifetime is the world — a node under the generator with a static ref
(`mission_generator.gd:276-285`), gone at teardown — while H&M must survive the bank; (4) its
semantics are "offer this PLACE once to the patrol loop" (`raise_crisis`, `:47`). Two concerns, two
keys. Leave the factory exactly as it is; `HmLedger.consumed` is the H&M dedup and the two never
share an id.

### 1.2 Stable occurrence ids (no `Time`, no instance ids)

| Producer | id | Where it fires today | Cost |
|---|---|---|---|
| Informer escaped | `informer:<village_id>` | `civilian._transform_to_vc` `civilian.gd:1163-1174` → `on_informer_escaped` `field_director.gd:789` | one dict write |
| Civilian killed | `civ_killed:<village_id>:<ci>` | `_die` `:1080` → `_record_noncombatant_death` `:1116-1124`. Needs `ci` from the deal loop at `mission_generator.gd:1302-1305` stored on the Civilian as `person_id` — the seed of NpcRecord.person_id (handoff §5.1) with no new class | one `String` per villager at spawn |
| Fire discipline near the ville | `fire_near_ville:<village_id>:<sim_hour_int>` | the NoiseBus hook `field_director.gd:27-38` already receives every player shot (`source_team == 0`, `evidence_ledger.gd:57-58`); one more branch: within `VILLE_FIRE_M` of a village center. Bucketed per sim hour so a firefight is ONE event | one distance per player shot |
| Village spared | `spared:<village_id>` | departure edge: the player crosses out of the village radius with neither `civ_killed` nor `fire_near_ville` consumed for that village — one distance check on the existing 0.5 s `_poll_firebase_threat` cadence (`:1735`) | negligible |
| Patrol relieved | `patrol_relieved:<group_tag>` (`"friendly_patrol_%d"`, `mission_generator.gd:1056` — seed-fixed, never the instance id at `friendly_patrol_group.gd:172`) | the element un-breaks (`_update_break` `:123-153`, `pinned_holder` released `:148-150`) while the player is within `RELIEF_M` | already computed every `STRENGTH_TTL_MS` |

Crash survivor: out of scope unless the crash ships (`pilot_recovered` is already a flag at
`demo_game.gd:704-709`; its id would be `pilot:<incident>` and it is the one producer that already
has a bank).

---

## 2. The 45-minute clock

Shipping today: `START_HOUR 6.5`, `DAY_RATIO 38`, `NIGHT_RATIO 20`, `PROBE_AT_S 1395`,
`SIEGE_AT_S 1440`, `END_BACKSTOP_S 2700` (`demo_game.gd:47, :52, :59, :61-62, :79`). Night
(sim 19.0) at 45000/38 = **1184 s**. Assault cap from §0.1 → the demo ENDS by 1875 s.

**Proposed (one line):** `START_HOUR 6.5 · DAY_RATIO 27 · NIGHT_RATIO 12 · PROBE_AT_S 1770 ·
SIEGE_AT_S 1830 · END_BACKSTOP_S 3000 · siege max duration 900 s from the ASSAULT`.

Derived, not measured:
- DAY 07:00 snaps at 0.5h·3600/27 = **67 s** (was 47 s). The "day snapping on IS the player
  clearing the gate" beat (`:41-47`) moves 20 s later; the gate order at `GATE_ORDER_AT_S` 10 s
  (`:509`) and the file-out still land under it.
- Midday 12:00 at **733 s (12:13)** — "the paddy is empty at midday" lands as the main outing opens.
- DUSK 17:00 at **1400 s (23:20)**; NIGHT 19:00 at **1667 s (27:47)**. The return-and-prepare block
  is a real, visible dusk of 267 s (was 189 s). `MissionWeather.is_night` flips there and the ratio
  seam fires on it (`demo_game.gd:586-590`) — unchanged mechanism.
- NIGHT_RATIO **12**: nominal raid end at ~2640 s → 19:00 + 973·12/3600 = **22:15**; the backstop
  at 3000 s → **23:27**. Never crosses midnight even on the backstop, so `_granted_day`
  (`field_director.gd:1192, :1529-1531`) cannot re-arm and `sim_day` never increments. At 15x the
  backstop would reach 00:33 — that is why 12, not 15. (Note: TODAY's backstop at 20x reaches
  03:25; the "never crosses midnight" was only ever true of the raid's end, not the failsafe.)
- The stress boot derives from the constants (`_arc_hour_at` `:242-247`, `_stress_boot_hour`
  `:251-252`): seat = 19 + (1830−1667)·12/3600 − 45·12/3600 = **19:24, NIGHT**; `_seat_the_stress_night`
  (`:259-273`) emits the crossing as before. No edit.
- `START_HOUR` stays 6.5: it must sit inside DAWN (5-7, `sim_clock.gd:71-72`) because `set_time`
  does not emit `time_period_changed` (`:107-112`) and the plan seeds `"time": "DAWN"`
  (`mission_generator.gd:735`); `test_demo_planner.gd:69-76` pins that pairing.

**What the lighting table allows** (`scripts/world/mission_weather.gd`, NOT `missions/`): four
states `TIMES` `:22-27`, chosen by `SimClock.period_at` on the crossing (`:80-83` → `_apply_time`
`:88-`), eased over `TIME_EASE_SECONDS` 6 s. The sun does not move inside a period; a day is four
hard events, so the ratio only decides WHEN the four events land — nothing in the table constrains
the ratio. `is_night` (`:10`, set at `:97`) is the same authority the seam and the siege read.

**Which timing tests move** (grep tonight: `tests/test_demo_arc.gd`, `test_demo_planner.gd`,
`test_fire_support_grant.gd`, `test_campaign_state.gd`, `test_siege.gd`):
- `test_demo_arc.gd:35-41` pins PROBE 1395 / SIEGE 1440 / START 6.5 / DAY 38 / NIGHT 20 — re-pin
  to the decree, same test. `:29-31` (`resolve_stress` returns the constants) and `:44-48` (stress 45 s)
  pass unchanged. `SIEGE_STRENGTH 45`/`PROBE_STRENGTH 11` (`:37-38`) do not move.
- `test_demo_planner.gd:69-76` (DAWN pairing) unchanged. `test_siege.gd` tests the ledger/break/reap
  (`:1-30`), not the clock — unchanged unless `MAX_DURATION_S` becomes a var (then one assertion that
  the default is still 480). `test_fire_support_grant.gd:36` asserts the boot label is MODERATE — still true.
- Drift to correct in the same change: `sleep_station.gd:68` cites "PROBE_AT_S 1395 / SIEGE_AT_S 1440"
  in a comment; `demo_game.gd:49-50` ("~1184s") and `:64-73` (backstop arithmetic) narrate the old numbers.

### 2.1 The 45-minute table (owner and cost lens; the pacing is the game designer's)

| Block | real | sim | Existing system that fills it | Minimum new content | Player who ignores the task |
|---|---|---|---|---|---|
| Arrive | 0-4 min | 06:30-08:18 | bunk boot, `AIR_OPENING` `demo_game.gd:301-309`, gate order `:499-575`, early napalm `:329` | none | walks the compound; garrison schedule runs (census) |
| First task | 4-12 | 08:18-11:52 | wire crossing `field_director.gd:1479-1499`, `_pick_patrol_location`, village + informer (`mission_generator.gd:1297-1309`), schedules | the temporary partner's element routed past the village (`_spawn_friendly_patrols` `:1043-1062`, anchors `:1059`) + ONE producer (`fire_near_ville`/`spared`/`civ_killed`) | nothing happens: the informer needs to SEE him (`civilian.gd:531-535`). **Dead air.** |
| Main outing | 12-24 | 11:52-17:20 | camp, hunters on evidence (`:170-224`), pinned crisis (`friendly_patrol_group.gd:155-176` → `dynamic_mission_factory.gd:17`) | `patrol_relieved` producer + the adopt door (§4) | hunters come only if he left evidence (`:173`, `:198-203`); else **dead air** |
| Return / prepare | 24-28 | 17:20-19:00 DUSK | inward wire `:1500-1508` → `_bank_patrol` `:2095`, fire support `:1526`, resupply | the ARMED transition (§3); stock the siege reserve HERE (§5) | stays out: ARMED at the seam anyway; garrison fights alone; crisis emitted only if `patrol_out` (`:1752-1760`) |
| Warning / probe | 28-30.5 | night | probe 11 (`:596`), stand-to `:1799-1838`, siren `:1899` | the warning line keyed by the village bucket, 60-90 s before the probe | — |
| Assault | 30.5-44 | 19:33-22:15 | reinforce to 45 `:597`, waves `siege_director.gd:749-753`, air beats `demo_game.gd:334-342`, overrun | demo-owned max duration; cadence knobs by pressure tier | the lives economy `:695-706` |
| Ending | 44-45 | | `siege_ended` → gunships `:611-650`, card `:717-` | one consequence line on the card (the pilot pattern `:704-709`) | |

**The dead air, named:** minutes 4-24 have no self-starting drama. Both the friendly element and
every enemy group are `LazyGroup`s that materialise only inside `activation_range` of the PLAYER
(`lazy_group.gd:8`, 140 m at `mission_generator.gd:1057`), so an ambient fight the player is not
near never happens — the pinned crisis fires only when he is within ~140 m of BOTH the element and
an enemy circuit. What kills the dead air is not a system: it is the ROUTE — the outing's anchors
(`_patrol_anchors`, `:1059`) must cross the friendly element's circuit and an enemy circuit inside
the 512 m slice. That is content on the plan, zero runtime cost.

---

## 3. The assault-arming transition — one authority, one occurrence id

Keep `SiegeDirector.open_siege` / `reinforce` as the ONLY doors (they are today). Add to
SiegeDirector: `var run_id: int` assigned in `open_siege` as `hash(Vector2i(fsb)) ^ nights_run`
(seed-fixed; `_rng` is already seeded from the center `:204`), carried on `siege_began(strength,
is_probe)` and `siege_ended(reason, killed, strength)` as a fourth arg (`:149-150`). That id is
the assault's occurrence id for every consumer (the end card, the ledger's `assault:<run_id>`).

The transition lives on `demo_game.gd`'s existing phase machine (`_phase` `:145`, `:592-605`),
widened from 4 states to: `OUTING → RESOLVED → RETURNED → ARMED → WARNING → PROBE → ASSAULT → ENDED`.
Rules, each a boolean the code already exposes:
- `RESOLVED` = the outing's terminal producer applied (any `[HM]` id of the outing) **or** `_clock ≥
  RESOLVE_LATEST_S` (the poor-outing floor: "a poor outing still reaches a defence").
- `RETURNED` = the inward wire edge (`patrol_out` false, `field_director.gd:1500-1508`) **or**
  `_clock ≥ RETURN_LATEST_S`.
- `ARMED` = `RETURNED and MissionWeather.is_night` — the night is a *condition*, not a launcher.
  A player still out at night arms anyway; the garrison holds without him (existing).
- `WARNING` = ARMED + 0 s: the village line by bucket (§1) on `director.toast`; `PROBE` at
  `WARNING + gap(bucket)`, `ASSAULT` at `PROBE + 60 s` — the two `_open_siege` calls exactly as today.
- The clock constants `PROBE_AT_S`/`SIEGE_AT_S` become the LATEST the beats may land (the floor),
  not the only trigger; `resolve_stress` (`:157-170`) keeps handing 20/45 to the stress boot unchanged.

How the two other "launchers" are subordinated without a second combat path: the night roll is
already dead in the demo (`:239-241`); the sleep roll is unreachable (`sleep_station.gd:72`). No
code is added to either. The quest never calls `open_siege` — it flips `RESOLVED`; the phase
machine's single `_open_siege` (`:554-590`) is the only caller, so three triggers cannot make three
attacks because there is one call site behind one state.

The duration: `MAX_DURATION_S` → `var max_duration_s: float = MAX_DURATION_S` on SiegeDirector,
set by `_open_siege` at the ASSAULT step beside `ring_min` (`demo_game.gd:560-573`) to
`SIEGE_MAX_S` (900), AND `reinforce()` re-bases the deadline when the probe becomes the assault
(the `was_probe and not is_probe` branch `:355-360` already re-bases `_wave_t0`, `_illum_timer`,
`_press_clock`; `_elapsed` joins them **only under the demo's request**, or the campaign's dawn
deadline moves too). Combat file → BaseGame-V1 first, fast-forwarded.

---

## 4. The earned companion as DATA (FriendlyPatrolGroup man → SquadSystem member)

The element's men are full `AllyBase` nodes with `squad_member = false` and a `member` dict from
`SquadRoster.generate_member` (`friendly_patrol_group.gd:46-53`), on the `allies` roster
(`ally_base.gd:489-490`), ordered by the group each leg (`:103-106`) and flagged `squad_broken` by
it (`:150-152`). The squad's men are the same class, stood up by `_stand_up_member`
(`squad_system.gd:110-141`), "THE ONE PLACE A SQUADMATE IS STOOD UP".

**Adoption stands nobody up.** `SquadSystem.adopt(man: AllyBase) -> bool` beside
`receive_replacements` (`:145`), and `FriendlyPatrolGroup.release(man) -> bool`:

| Transfers (by reference, never regenerated) | Must change | Must NOT happen (F10's lesson) |
|---|---|---|
| the NODE itself (no respawn) | `squad_member = true` (`ally_base.gd:284`) | no `generate_member` (the garrison promote regenerates the man at `garrison_defender.gd:77` — that IS defect F10) |
| `member` dict — name, mos, face, helmet, skills, `trust`, `trust_seen` | `set_order(FOLLOW)` (`:328`), `file_slot = members.size()+1`, `point_slot = false` (`:137-138`) | no `set_sprite`/`dress_visual` re-roll (`:130-133` are stand-up only) |
| courage (his own; the MOS band at `:113-120` is a stand-up roll) | `director` set (the element never sets it), `weapons_free = squad posture` (`:160`) | no courage re-roll |
| health, weapon, aim | `died.connect(_on_member_died)` (`:135`), `members.append` | no new node, no second body — "he is ONE man" |
| | `CampaignState.roster.append(member)` so the bank/AAR/replacement math sees him | **and the group must let go:** `_men.erase(man)`, `_peak -= 1`, `squad_broken = false`, `pinned_holder` released if his — or `_advance_route` re-orders him MOVE_TO every leg and `_update_break` overwrites his break flag: the two lines that would silently steal him back |

Checked: `SquadRoster.ensure_roster` keeps every living man, no trim (`squad_roster.gd:174-195`),
so the ninth dict survives the bank; but `SquadSystem.setup` stands up only
`mini(SQUAD_SIZE, roster.size())` (`squad_system.gd:71`) — in the campaign he would sit on the
roster and not walk out at the next dawn. Harmless in the one-day demo; a `SQUAD_SIZE`+1 ruling
or a first-eight ordering rule when the campaign takes it. `vacancies()` (`:207-212`) is safe.

**Garrison acknowledgement:** the promoted man has no identity to acknowledge WITH — `promote`
regenerates his dict from his post (`garrison_defender.gd:77`, `_seeded_rng(stand)`); F10 stands.
The cheapest honest form is a line at `_on_siege_began` (`field_director.gd:1883-1899`) from the
nearest `garrison_promoted` ally, keyed on the H&M bucket and naming the SUBJECT only
(`"<call_name> - WE HEARD ABOUT THE VILLE"`), on the toast channel. Zero nodes, zero identity claim.
Carrying the dict through promote/stand_down (the F10 patch) is the real fix and is N4 work, not this council's.

---

## 5. Cost on the Intel UHD, against the ADR-026 cap

Baseline: siege fps 48→55 (pair 1), 1% low 17.5, worst frame 97-98 ms (`PERF_LEDGER.md:3504-3506`);
Mobile renderer shipped (`:3603-3620`); waves cap materialised men 8→50 over 180 s
(`siege_director.gd:66-68`); hot-set ≈ 12, ceiling 16 (`ADR-026:116-119`); `LIVE_CAP` 50 (`:35`),
`SIEGE_STRENGTH` 45 (`demo_game.gd:181`), hunter pool 12 (`field_director.gd:152`, demo floor 6
`:1496`), informer response 4 (`:402`).

| Consumer / producer | Per-frame cost | Materialised men |
|---|---|---|
| `HmLedger` apply / consumed | dict ops on events only; 0 per frame | 0 |
| producers (§1.2) | one distance per player shot on a hook that already runs (`:35-38`); one distance on the 0.5 s poll; a bool read on the informer clock (`civilian.gd:531`) | 0 |
| village: elder at the well / paddy empty | a bucket branch in `CivilianSchedules.action_for` (`civilian_schedules.gd:28`, `"elder"` `:81`), evaluated at the hour crossing — same men, different target | 0 |
| village: who informs | gate `_inform_clock` start (`civilian.gd:531-535`) on bucket ≠ FRIENDLY; the seed draw at `mission_generator.gd:1300-1301` is untouched (ADR-010 draw order) | 0 (he exists either way) |
| enemy: hunter cadence | × tier multiplier on `_hunter_timer = randf_range(100,160) * field_mult` (`:206`), bounded [0.75, 1.25]; pool 12 unchanged | 0 added; never more than 12 |
| enemy: assault cadence / warning quality | per-run vars for `WAVE_RAMP_S`/`SAPPER_HOLD_S`/`MORTAR_FIRST_*` (`siege_director.gd:66-69, :109-110`) by tier; the WARNING→PROBE gap | 0 — the same 45 men arrive on a different clock |
| ally: companion | −1 element man, +1 squad man near the player: net 0 nodes; BUT the squad's near-tier body count goes 8→9 (allies' `move_and_slide` was 9.5% of the siege, `PERF_LEDGER.md:3579`) ≈ +1/8 of the squad's per-frame share | 0 net |
| ally: faction/garrison lines | strings on `director.toast` | 0 |
| **the reserve moved to the WARNING beat** | today `_stock_reserve` builds `LIVE_CAP − 11 = 39` dormant men at the PROBE's open (`:593-601`; ledger `:3521-3536`: "49 builds… 15 surplus… stock at nightfall instead"). With ARMED as a real state, `stock_reserve_for(SIEGE_STRENGTH − PROBE_STRENGTH)` = 34 exact, in the warning minute | **a win**: 15 fewer dormant bodies, and the drip leaves the probe's frames |

Nothing above raises `LIVE_CAP`, `SIEGE_STRENGTH`, the hunter pool or the response size; every
consumer is a multiplier on a timer or a branch on a target. The one nonzero per-frame delta is the
ninth squad body, and it is the design's to keep or to trade (ship 7 + 1).

---

## 6. The cheapest probe

1. **`tests/test_hm_ledger.tscn` — pure, no world, ~2 s.** The pattern of `test_demo_arc.gd`
   (`:1-9`: "a test that has to build the demo to check a number is a test nobody runs"). Construct
   `HmLedger`, apply the scripted day twice (`informer:V`, `civ_killed:V:2`, `fire_near_ville:V:9`,
   `spared:V`, `patrol_relieved:friendly_patrol_0`), assert each consequence exactly once, the
   buckets, and `to_dict → from_dict → apply` still refuses. This is the idempotency gate.
2. **`--hm-probe` on the demo, headless, `-- --test-save`, ~3 min.** Hooked like `--npc-census`
   (`game_flow.gd:773-776`). It cannot play 45 minutes at 38x: the arc is REAL seconds
   (`_clock += minf(delta, 0.066)`, `demo_game.gd:581`), so `Engine.time_scale` buys at most 4x
   (the 0.066 cap) — 11 minutes, too long for a gate. Instead it does what the census does with the
   sim clock (`probe_npc_census.gd:9-12`: jump, pause, settle): seat `_clock` at each beat
   (240, 720, 1440, seam, probe, assault), fire the scripted producers at the village center, and
   print every `[HM] <id> -> <consequence>` and every `[DEMO] phase` line with the `run_id`. Serial,
   under three minutes, and it prints the arming transition as a sequence that a diff can gate.
3. `--stress=assault` stays the combat/frame probe (`:83-96`); `--npc-census` stays the village-life
   gate and must stay green — note it holds stand-to off (`field_director.gd:1793-1796`), so it
   cannot see the garrison line and should not be asked to.

---

## 7. What is sacrificed (law 2)

- The DAY snap moves from 47 s to 67 s after the seat; the "day comes on as you clear the gate"
  beat drifts 20 s.
- NIGHT at 12x is a slow sim night; per-sim-hour bookings (`AirTraffic` schedule, garrison sleep)
  thin — mostly invisible because the demo flies its own sky (`demo_game.gd:295-320`).
- `MAX_DURATION_S` stops being a const: a combat authority gains a knob (BaseGame-V1, both branches).
- A ninth near-tier ally body, or a 7+1 squad.
- The village variable makes ADR-038 §5 false — and the journal ALREADY reads pressure as a word
  (`journal.gd:406` `THREAT: MODERATE`, `barracks.gd:45`, `main_menu.gd:92`). The felt/read guard
  must either grandfather that row (a baseline, like `fossil_baseline.json`) or delete it.
- One village in the demo → the per-village table has one row. True in shape, demo-sized in fact.
- More lines on the one toast channel that already carries `SQUAD MOVING OUT` and `S2 INTEL`.
- Three docs/comments to correct in the same change (`sleep_station.gd:68`, `demo_game.gd:49-50,
  64-73`, `test_demo_arc.gd:35-41`).

## The single riskiest edit

Re-basing the siege deadline (`_elapsed` / `max_duration_s`) together with the widened phase
machine. The demo's END is wired to `siege_ended` (`demo_game.gd:611-618`) and the watch is armed
only in phase ≥ 2 (`:603-608`); the "dawn" break is the only thing today that guarantees the demo
ends at all before the backstop. Get the re-base wrong one way and the demo still ends at 31:15;
the other way and it runs to the 50-minute backstop with a won fight on screen. It is the one edit
that touches both branches at once.

---

## 8. What in the briefing is wrong (the code wins)

1. "PROBE 1395, SIEGE 1440, END_BACKSTOP 2700" is read as if the assault runs to the raid's end or
   the backstop. It runs to `MAX_DURATION_S` 480 **from the probe** (§0.1): the demo ends by 1875 s.
2. "the clock and the night roll must not launch three attacks" — there is one launcher in the demo
   today (§0.2). The risk is new, not existing.
3. `mission_weather.gd:40` — the file is `scripts/world/mission_weather.gd`; the four-state table is
   `TIMES` at `:22-27` and the boot hours `TIME_ID_START_HOUR` at `:43`; `is_night` `:10`/`:97`.
4. "`FieldDirector` (`:1520-1535`, loud patrols raise threat)" — those lines are `_grant_fire_support`
   READING the label (`:1520-1541`). Threat is RAISED only in `CampaignState.on_mission_end`
   (`campaign_state.gd:240-243`), reached only at `_bank_patrol` (`field_director.gd:2116`). In the
   demo the label is MODERATE for the whole day unless a mid-day producer uses `add_threat_modifier`
   — which is exactly why that is the pressure door.
5. "`civilian.gd:718-722` records the ADR-019 deferral" — it is the header of
   `on_atrocity_witnessed` at `:1139-1143`; `:718-722` is the garrison animation chain.
6. "hunter teams are live after first contact" — only with an evidence fix (`:173`, `:198-203`);
   a quiet contact spawns nobody.
7. Drift found in the proposed owner: `reported_marks` is saved (`campaign_state.gd:322`) but
   absent from `to_dict`/`from_dict` (`:363-384`, `:387-407`) — the slot snapshot drops the third ink.
   Correct it in the same change that adds `hm`.
