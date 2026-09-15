# SYSTEMS DESIGNER — the 45-minute arc and a demo-sized Hearts & Minds ledger (2026-09-13)

Read: briefing; ADR-010/017/019/032/035/038; handoff §0A, §0B, §5.1; ADR-044 draft; the code below.
Every claim carries a pointer or a date. Code beat the briefing in six places (§6).

## 0 · The two facts the code adds to the briefing

1. **The assault cannot be 15 minutes today, whatever the clock does.** The siege's run clock `_elapsed`
   starts when the PROBE opens (`siege_director.gd:319`), `reinforce()` deliberately does NOT touch it
   (`:345`), and `MAX_DURATION_S = 480.0` ends the run on the stopwatch (`:77`, `:684`). Probe at 1395 →
   run ends at 1875 s regardless of the 45-man reinforce at 1440 — a ≤ 435 s assault. Fifteen minutes of
   defence is a SiegeDirector edit first and a clock edit second.
2. **Enemy pressure is producer-live and consumer-dead in the demo.** `_bank_patrol` calls
   `CampaignState.on_mission_end` (`field_director.gd:2116`), which nudges `threat_level` ±0.03/0.05 from
   0.35 (`campaign_state.gd:244-248`) — never out of MODERATE (0.25-0.5, `:214-222`). The only consumers:
   `_maybe_open` returns at `siege_director.gd:241` in demo_mode; `roll_night_for_sleep` (`:272`) needs a
   sleep that is dormant (`SLEEP_POST_LAUNCH`, `field_director.gd:1506`); `_grant_fire_support` reads the
   tier once per day at the first wire crossing (`:1524-1535`), before anything has banked. So the one
   Hearts & Minds variable that exists is read by nothing the player meets.

## 1 · The 45-minute arc (Part A)

### 1.1 The clock

Constraints, from code: the boot hour must sit inside DAWN 5-7 (`demo_game.gd:213-215`; `sim_clock.gd:70-77`
holds the period table — DAWN 5, DAY 7, DUSK 17, NIGHT 19); the night must never cross midnight
(`demo_game.gd:50-56`: the sim-day rollover unlatches `_granted_day` fire support at `field_director.gd:1529`
and, in the full game, re-arms the night roll at `siege_director.gd:243-246`); `mission_weather.gd:39`
`TIME_ID_START_HOUR` is a per-time_id START hour, not a lighting table — lighting changes only on
`time_period_changed`, so the day still sells as four hard events and the 06:30 "DAY snaps on as you clear
the gate" beat survives any ratio that puts 07:00 within the gate walk.

| Const | Today | Proposed | Why |
|---|---|---|---|
| `START_HOUR` | 6.5 | **6.5** | DAWN period contract; the gate beat |
| `DAY_RATIO` | 38 | **27** | 12.5 sim h → night at **1667 s (27:47)**; DAY snaps at 67 s (was 47); DUSK 17:00 at 1400 s (23:20) |
| `NIGHT_RATIO` | 20 | **12** | 2700−1667 = 1033 s → 3.44 sim h → ends **22:27**, same end hour as today's arc; backstop 3000 s → 23:27, still inside the day |
| `PROBE_AT_S` | 1395 | **1740** | 73 s after the seam; the warning window (§2.5) lives in 1667-1740 |
| `SIEGE_AT_S` | 1440 | **1800** | 30:00; 14 min of assault to ~2640; gunships by 45 |
| `END_BACKSTOP_S` | 2700 | **3000** | failsafe only; must stay ≤ 3167 (5 sim h at 12x) or midnight |
| `SiegeDirector.MAX_DURATION_S` | 480 | **demo-set `max_duration_s` 900** | the shipped override pattern: the demo already sets `ring_min/ring_max/rally_m/mortar_standoff_m/cell_materialize_m` on the instance at `demo_game.gd:636-646` |
| `SIEGE_AIR_BEATS` | tuned for 360 s (`demo_game.gd:59`, `:395`) | retimed to the four phases | first beat at +60 s is the probe-phase gun run; later beats belong to "local crisis" |
| `tests/test_demo_arc.gd:34-40` | pins 1395/1440/6.5/38/20 | re-pinned **intentionally** + a new check `arc_hour_at(END_BACKSTOP_S) < 24.0` | the handoff §0A demands the timing tests move on purpose |

Alternative rejected: keep 38x (night at 1184) and stretch the night to 25 min. Ten minutes of dark before a
probe is dead air in the dark; the day is where the RPG is.

### 1.2 The blocks

Circuit facts (briefing, DEMO_TWO_QUESTS_PLAN): gate → village (165 m from the FSB, `mission_generator.gd:775-776`)
→ camp (opposite flank, `:821` region) → home is 850-1000 m, 170 s at walk, 340-500 s cautious. A 27-minute
day is ~5× the cautious circuit. **The dead air is the day. What kills it is not more tasks — it is that
every producer in §2 is a PLACE with a consequence, so the circuit is walked twice for two reasons.**

| Min | Block | Existing system that fills it | Minimum new content | The player who ignores the task |
|---|---|---|---|---|
| 0-3 | Boot on the bunk, title splash, gate order at 10 s (`GATE_ORDER_AT_S`, `demo_game.gd:511`), DAY snaps on ~67 s | demo boot, `_tick_opening`, squad move-out | one garrison rifleman ATTACHED for the day at the gate (`member.temporary = true`, §2.6); one toast | walks anywhere; the squad still moves out |
| 3-10 | **Task 1 — the village, quiet.** Schedules run (farmer/elder/cook/fisherman, `civilian_schedules.gd:31-81`); the informer must SEE you (`civilian.gd:531-534`); 25 s later he is gone (`:543-548`) | village stamp, schedules, informer, `report_village_distress` (`dynamic_mission_factory.gd:69`) | producers P2/P3/P5 (§2.3); one villager bark when the band is warm | shoots — the informer runs, hunters come from the far side (`field_director.gd:789-816`). That is the branch, built |
| 10-21 | **Task 2 — the camp** (crash optional per handoff §0B; the camp is built, the crash is not) | CampDirector, AmbushPlanner, hunters on evidence (`field_director.gd:186-224`), `EvidenceLedger` | the OUTING RESOLVED occurrence (§2.4) when the camp's live count hits its floor or the player is 250 m home-side of it | wanders; OUTING RESOLVED is stamped by the DUSK crossing at 1400 s with outcome `abandoned` — the assault is still armed |
| 21-27 | **Return.** Dusk 23:20; the wire bank `_bank_patrol` (`:2097-2130`); the partner's transition; a garrison man acknowledges; two faction lines walked past | wire bank, `VOManager.play_squad` (`:1594`), toast channel | `HeartsLedger.bank()` at the wire; the TEMPORARY→COMPANION/GARRISON transition; 12 canned faction lines gated by subject | stays out — the siege fires whether he is inside or not (ADR-035 §1, `_poll_firebase_threat` `:1735`) |
| 27:47-30 | Night at 1667 (ratio → 12x). **WARNING** — the local-support consumer (§2.5): warm → "MOVEMENT ON THE ROAD, THE VILLE SENT A KID" at 1680 and stand-to; quiet → nothing until the probe; cold → nothing (they told the other side). Probe 29:00 | `_garrison_stand_to` (`:1799`), `_poll_firebase_threat` | the warning lead | the probe stands the garrison to anyway (`:1749`) |
| 30-44 | Assault: 45 men (`SIEGE_STRENGTH`, pinned by `test_demo_arc.gd:36`), phased per handoff §0A; arrival cadence is the pressure consumer (§2.5) | SiegeDirector waves (`WAVE_CAP_START 8 → LIVE_CAP over WAVE_RAMP_S 180`, `siege_director.gd:66-68,750-753`), press cycle, mortars, illum, air beats | `max_duration_s` 900; `wave_ramp_s` by band; air beats retimed | dies → end card (`EXCLUDE_DEBRIEF`) |
| 44-45 | Break → `siege_ended` → gunships → the player lives (`demo_game.gd:674-697`) | built | none | — |

### 1.3 How the assault is ARMED — one authority, one id

The handoff's transition is already half-built as the demo's `_phase` (`demo_game.gd:614-626`): 0 → probe → 2
→ backstop. Make the phases named states — `OUTING_OPEN → OUTING_RESOLVED → RETURN → ASSAULT_ARMED → WARNING →
ATTACK → RESOLVED` — on DemoGame, which remains the ONLY caller of `open_siege`/`reinforce` (`:648-666`) and
SiegeDirector remains the only siege authority. The occurrence id of the night is
`assault/day1/<seed>`; `_open_siege` refuses a second open for the same id (today the `d.siege.active`
branch at `:650` is the idempotency, and it works because reinforce grows strength+peak together). The
arming CONDITION is `OUTING_RESOLVED or clock ≥ 1667`, whichever first — a poor or abandoned outing still
reaches the defence; nothing teleports him. Quest completion never opens a siege; it only stamps
OUTING_RESOLVED. The clock only backstops.

## 2 · Hearts & Minds, demo-sized (Part B)

### 2.1 The three variables and their owner

| Variable | Lives where | Shape | Why there |
|---|---|---|---|
| **Enemy pressure** | `CampaignState.threat_level` + `threat_modifiers` — **exists**, `campaign_state.gd:22-23, 207-226` | 0.1-0.9 float, campaign-wide | ADR-010 forbids a second global; ADR-017 says the place-attachment is the province, post-launch. Its producer API exists: `add_threat_modifier(delta, missions, reason)` `:225` |
| **Local support** | `HeartsLedger._support: {site_key: float}` in **[-1, 1]**, starts 0 | one village in the demo (`village/0`) | new, private float; only a 3-band reader leaves the class (§2.7) |
| **Individual trust** | `HeartsLedger._trust: {person_key: int}` in **[-2, 2]**, starts 0 | the roster dict IS the ally (`ally_base.gd:285`); `person_key = member.name` for the demo, a `roster_id` allocator for the full game (handoff §5.1) | the ADR-044 draft hangs the grant on trust, never a tally (`ADR-044:122`); the demo needs exactly one transition |

**Owner: a `HeartsLedger` RefCounted held by FieldDirector**, built at director setup beside
`evidence = EvidenceLedger.new(world.mission_seed)` (`field_director.gd:26,155`). Not an autoload: an
autoload's mutable state must register in `MissionScope` (ADR-010) and a per-op RefCounted dies with the
world — the EvidenceLedger is the shipped precedent. **Not on MissionState**: `_bank_patrol` replaces the
state every wire crossing (`state = MissionState.new()`, `:2126`), so anything per-patrol in it is discarded
at the bank — the exact place the ledger must survive. Not on the site plan: `p.sites` entries are
`{kind, center}` dicts with no id (`mission_generator.gd:776`), the plan is generation data (handoff §5.3),
and a village's centre is not its identity.

**Persistence in the demo's sandbox.** The ledger serialises to ONE dict `CampaignState.hearts =
{events: {id: true}, support: {...}, trust: {...}}`, written in all four places (`save_campaign` `:307`,
`to_dict` `:398`, `from_dict` `:423`, `reset_campaign` `:454`) — `field_marks` was once lost by missing one of
them (`:441-443`). Mid-mission writes are deferred to the bank (`_defer_saves`, `:15-20`), which is right:
a consequence lands with the patrol it belongs to. In the demo `EXCLUDE_SAVES` repoints to
`user://campaign_demo.cfg`, wipes and resets (`demo_game.gd:185-194`) — every boot is virgin (fresh-player
law), there is no mid-arc reload (`SaveData.mission` reserved, F14), so "idempotent across restart" means:
ids are stable across BOOTS (a probe can diff two runs), and the `events` set dedups within a run and
across any future reload with no new mechanism.

**Determinism (ADR-010).** The ledger holds NO RNG. Producers are facts; ids are derived from
generator order and the patrol number, never from positions or node names. The one consumer that rolls
(hunter cadence) already rolls the global RNG under the demo's declared honest scope
(`demo_game.gd:9-11`; `field_director.gd:206-214`). Faction line choice is `hash(occurrence_id) % n` —
deterministic per event. **Drift found:** the informer response seeds from
`hash(from_pos) ^ int(Time.get_ticks_msec())` (`field_director.gd:803`) — a Time seed on the edge this
whole model builds on; fix to `hash(from_pos) ^ world.mission_seed` in the same change.

### 2.2 The typed event (handoff §0A)

```
HeartsEvent { id: String, site: StringName, persons: Array[String], witnesses: Array[String],
              consequences: Array[Dictionary] }   # {kind, target, delta|band}
```
`HeartsLedger.record(ev) -> bool` returns false and applies nothing when `events.has(ev.id)`. Witnesses are
taken from `AgentRegistry.allies` within `WITNESS_M` (`agent_registry.gd:9`; the ADR-005 rule the ear
witness already uses, `player.gd:254-257`) — a man who was not there learns nothing (handoff: "do not give
every squadmate identical instant respect").

### 2.3 Producers (five; each with its id and its existing hook)

| # | Occurrence id | Hook (exists) | Consequences |
|---|---|---|---|
| **P1** | `informer/village/0/escaped` | `_transform_to_vc` → `on_informer_escaped` (`civilian.gd:1163-1174`, `field_director.gd:789-792`, already latched by `_informer_answered`) | support −0.5; `add_threat_modifier(+0.10, 1, "INFORMER")`; witnesses: squad trust unchanged (nobody's conduct) |
| **P2** | `civ_death/village/0/<person_idx>/p<patrol_no>` | `_record_noncombatant_death` → `director.record_noncombatant_death` (`civilian.gd:1118-1127`, `field_director.gd:120-122`) — today a COUNT into `state.civilian_deaths` (`mission_state.gd:23-27`) that the bank throws into the score | support −0.4 each, floor −1; each witnessing ally trust −1 (Pillar 4: the men saw it) |
| **P3** | `fire/village/0/p<patrol_no>` — **fire discipline IS allegiance** (ADR-038 §4) | `EvidenceLedger.on_noise` already receives only player-side GUNSHOT/EXPLOSION (`evidence_ledger.gd:56-62`); add a village-radius test (150 m, the `VILLAGE_DISTRESS_M` figure, `dynamic_mission_factory.gd:63`) | support −0.3, **once per patrol** — a boolean, so it cannot be farmed or scored |
| **P3'** | `clean/village/0/p<patrol_no>` | stamped at `_bank_patrol` (`:2097`) when: came within 40 m of the centre AND no P2/P3 this patrol AND no P1 | support +0.4. The "spared" half of ADR-019's table, and the only positive producer a first patrol can earn |
| **P4** | `relief/village/0/w<wave>` | `village_requesting_aid` crisis, deduped by entity id (`dynamic_mission_factory.gd:36-49, 69-73`) — the player reaches the centre while the crisis is live and the shooters are dead/gone | support +0.5; the temporary partner trust +1 if he was there |
| **P5** | `ear/village/0/p<patrol_no>` | `on_atrocity_witnessed` (`civilian.gd:1139-1157`, wired 2026-08-07) | support −0.5; witnessing allies trust −1. It already makes an informer; that stays |

A rescue/recovery producer waits on the crash (handoff §0B keeps it optional); its id shape is
`incident/<kind>/<n>/<outcome>` and it lands trust +1 for the partner who carried. Not in this first batch.

### 2.4 The outing's result — one id, three outcomes

`outing/day1/<seed>` with outcome ∈ {resolved, partial, abandoned}: stamped by the camp task (§1.2) or by
the DUSK crossing. It is the arming condition (§1.3) and the trust producer for the partner: resolved with
him alive and present → trust +1. This is the "one personal-trust transition" the handoff budgets.

### 2.5 Consumers (one per audience, all bounded, all read a BAND not a number)

`HeartsLedger.band(site) -> StringName` ∈ {`&"cold"`, `&"quiet"`, `&"warm"`} at thresholds −0.3 / +0.3.
`trust_of(person) -> int` is read by exactly two call sites. The float never leaves the class.

**Villages — the world's wordless reading (build first: the paddy).** At the next hour tick after a
`cold` band, `civilian_schedules` skips the farmer's paddy slot and the elder's sit — the paddy is empty at
midday, the old man is not at the well (ADR-038 §2, "the world's reading is never a line"). `warm`: one
villager (the elder) gets a `talk` bark when the player is within 8 m — a line about the road, under §2a.
`quiet`: today's behaviour, untouched. This is `civilian_schedules.gd:31-81` reading one band; no new node.

**Enemies — hunter cadence and the assault's cadence (build first: the warning).**
- Warning lead (support consumer, ONE effect): at 1667 s, `warm` → `_garrison_stand_to()` at +13 s with the
  toast above; `quiet`/`cold` → nothing; the probe at 1740 stands them to as today (`:1749`). Bounded by
  construction: the stand-to exists, the lead is 0 or 73 s.
- Hunter cadence (pressure consumer): `_hunter_timer` × {LOW 1.25, MODERATE 1.0, HIGH 0.8} and the demo
  pool `maxi(_hunter_pool, 6)` (`:1496`) → 4/6/8 by tier. Never a spawn from nothing — hunters still need an
  evidence fix (`:186-200`).
- Assault cadence (pressure consumer, the second and last support/pressure effect): `wave_ramp_s` demo-set
  to {240, 180, 150} by tier — reserves arrive faster, the total stays 45 and under `LIVE_CAP` (`:35`).
  The night-roll odds (`NIGHT_CHANCE`, `:12`) are the full game's consumer and already exist; the demo
  authors its night and must say so.

**Allies — the earned companion (build first).** The temporary partner is a garrison rifleman stood up
through `_stand_up_member` (`squad_system.gd:110-138`, the ONE door) with `member.temporary = true`. At the
bank: `trust_of(him) ≥ 1` → he stays in `members` and, at stand-to, moves to the player instead of his post
(one VO line via `VOManager.play_squad`, `:1594`); else `GarrisonDefender.promote` takes him back to his
post like any garrison civilian (`garrison_defender.gd:26`). Both branches end in a rifle on the wire —
no softlock, no reward click. The garrison acknowledgement: in `promote`, a man with `trust_of ≥ 1` barks
once. The factions: four canned lines per SUBJECT (`informer`, `village_cold`, `village_warm`), the
subject chosen by which occurrence ids exist — a line pool keyed by id PREFIX, never by the float — spoken
unprompted on proximity to the hooch marker (ADR-038 §2a corollary). Twelve lines, under twenty words,
no digit, no comparative.

### 2.6 What is FELT and what would be READ

Felt: the paddy, the elder, the bark, the lead on the stand-to, who walks beside you at night, the faster
second wave. Read (forbidden): any of `band()`, `_support`, `_trust`, `events.size()` on a screen, in the
journal, in a toast with a number, or as a faction line naming a direction. The THREAT row at
`journal.gd:406` / `barracks.gd:47` / `main_menu.gd:103` is ADR-019 §4's diegetic briefing carve-out for
enemy pressure; the ledger must never join it.

### 2.7 The grep-enforceable guard — `tests/test_hearts_felt.gd` (pure, no world)

1. `rg "HeartsLedger|\.hearts\b|band\(|trust_of\(" scripts/ui/` → **zero hits**, same law as ADR-032's
   reputation.
2. The ledger's only public readers are `has(id)`, `band(site)`, `trust_of(person)`; a grep for
   `func .*-> float` in `hearts_ledger.gd` → zero.
3. Every faction/villager line file: no `[0-9]`, no `more|less|better|worse|halfway|around|since last|
   again` (ADR-038 §2a, the comparatives of degree).
4. Round-trip: `record` five events twice → five consequences; `to_dict/from_dict` → same `events` set.

## 3 · Build order — the first producer and consumer per audience, and why

1. **P3/P3' fire discipline + the paddy consumer** (village). Cheapest and the ADR-038 §4 sentence itself;
   uses `EvidenceLedger`'s existing player-side noise filter and one schedule skip. It is also the only
   positive producer a first patrol can earn, so the warm band is reachable in one playthrough.
2. **`outing/day1` + the temporary partner's transition** (ally). One flag on a roster dict, one branch at
   the bank, one VO line; the handoff's exact "one personal-trust transition".
3. **The warning lead** (enemy). One `if band == &"warm"` at the seam; bounded by an existing function.
4. Then P1 (already fires — the ledger only listens), P2, P5, hunter and wave cadence, the twelve lines.

## 4 · Sacrificed (Law 2)

- **No province.** One village, one float, no place for pressure; ADR-017 stays unbuilt and the ledger is
  a dict, not `ProvinceState`. The full game rebuilds the owner, not the producers.
- **The band blinds the designer too.** Tuning −0.3/+0.3 with no readout means the playtest, not a
  number, says whether warm is reachable. ADR-019 said it would feel wrong to build. It will.
- **45 men is pinned** (`test_demo_arc.gd:36`), so pressure moves cadence only; the worst patrol meets
  the same company, faster. Honest, and less than ADR-019 promises.
- **A ninth body all day** (the partner) on the Intel UHD bench; and 12 lines of writing.
- **The 27x day is 40% longer for the same circuit** — dead air unless the two tasks land. The clock does
  not fix pacing; the producers do.
- **The stopwatch moves** (§5), and every siege figure in the ledger was measured against 480 s.

## 5 · The single riskiest edit

`MAX_DURATION_S` → a demo-set 900 (`siege_director.gd:77, 684`). Everything after it — a 45-man peak
breaking at 0.575 (`:29, :691`), the WAVE_CAP ramp, retimed air beats, the backstop — depends on the fight
resolving by the BREAK, and the comment at `:944` records that pacing the cap made nights run to the
stopwatch. Read that comment before the ramp is touched. Second: putting anything per-patrol on
`MissionState` — the bank replaces it (`:2126`).

## 6 · The cheapest probe

Not an arc run — the arc is 45 real minutes and cannot be fast-forwarded (`_clock` is real seconds,
`demo_game.gd:599`). Two pure tests: `test_hearts_felt.gd` (§2.7, builds a ledger, feeds each producer
twice, asserts one consequence per id and the greps) and `test_demo_arc.gd` re-pinned with
`arc_hour_at(END_BACKSTOP_S) < 24`. The census (`tools/probe_npc_census.gd`) stays green because the
paddy skip only changes a schedule under a band the census run never reaches (support starts at 0).
A headless arc probe printing every `record()` with its id is a `--hearts-probe` print flag, added when
the first producer lands, run by him, not by the suite.

## 7 · What the briefing gets wrong (the code wins)

1. "`FieldDirector :1520-1535`, loud patrols raise threat" — those lines READ the tier
   (`_grant_fire_support`); the raise is `CampaignState.on_mission_end` `:244-248`, reached via
   `_bank_patrol` `:2116`, and it cannot leave MODERATE in one patrol.
2. "SiegeDirector night-attack chance by label" — dead in the demo (`siege_director.gd:241`).
3. "`civilian.gd:718-722` records the deferral" — it moved; the deferral is at `:1139-1143`
   (`on_atrocity_witnessed`). ADR-019's status note and ADR-038 §5 both cite the stale line — drift to
   correct in the same change.
4. "hunter teams are live after first contact" — they need an evidence FIX and a rising global contact
   clock (`:168-177, :196-200`); a quiet patrol is never hunted.
5. "the assault — 360 s of it" — the run clock is 480 s from the PROBE (`:77, :319, :345, :684`).
6. "`mission_weather.gd:40` lighting table" — it is `TIME_ID_START_HOUR` (`:39`), a boot hour per time_id;
   the period boundaries that gate the arc are `sim_clock.gd:70-77`.
7. The informer response is Time-seeded (`field_director.gd:803`) — an ADR-010 break on the one H&M edge
   the briefing calls "built".
