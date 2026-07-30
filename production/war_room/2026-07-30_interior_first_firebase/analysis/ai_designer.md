# AI / GAMEPLAY SYSTEMS DESIGNER — interior-first firebase, the living compound

**Date: 2026-07-30.** Every claim below carries a `file:line`. Where the briefing and the code
disagree I say so and the code wins. Godot was NOT launched and Blender was NOT opened; this is a
read of the source only, so every runtime number is marked as an estimate or as a ledger citation.

**Owner ruling received mid-analysis and designed against, not re-litigated:**
1. Occupancy is the **casualty ledger, SEEDED** — 1–2 wounded present on a fresh boot, growing with
   real field casualties, "stacking up AROUND the medic tent" (overflow outside is part of it).
2. **NEW: body bags for the dead, stacked.**
3. HQ officers study **MAPS** (the "studying tents" reading was a typo; confirmed).

---

## 0. THE TRUE STATE OF THE NPC-LIFE RIG — read before designing anything

The briefing's §"WHAT ALREADY EXISTS" is optimistic in three places. Correct them first, or every
schedule authored below lands on machinery that cannot execute it.

### 0.1 `_bt_work` walks. SIX LEAVES ARE STILL FROZEN.
`_bt_work` (`scripts/world/civilian.gd:721-737`) now walks to `bb["target_pos"]` with a
name-hashed jitter ring (`:727-728`, deterministic per ADR-010). Confirmed fixed.

**But the other six are byte-identical freezes, live at HEAD:**
`_bt_rest` (`:739`) · `_bt_cook` (`:747`) · `_bt_sleep` (`:755`) · `_bt_fish` (`:763`) ·
`_bt_sit` (`:771`) · `_bt_talk` (`:779`). Each one sets `speed = 0`, sets
`_wander_target = global_position`, zeroes velocity, returns SUCCESS.

Consequences already shipping in the firebase, before any tent exists:
- `mess_cook` is scheduled `ACTION_COOK` from 04:00–08:00 (`civilian_schedules.gd:175-176`). He
  cooks **wherever the previous hour left him**, not at the field range.
- `off_duty`'s `ACTION_TALK` blocks (`:198`, `:204`) and every `ACTION_SLEEP` block park a man on
  the spot. `off_duty` has three separate `WALK_FIRE` legs whose destination is fake (see 0.2).
- `gun_crew`'s `ACTION_REST` at 23:00–04:00 is documented as "resting AT the pit, not in a hootch"
  (`:149`) — true only by accident, because REST cannot move him anywhere.

**Ruling:** the tent work below must express itself through `ACTION_WORK` or through ONE new leaf.
Do not route a nurse through `rest`/`talk`. And note this as a standing defect: six frozen leaves
means the schedule tables read far richer than the behaviour they produce.

### 0.2 `walk_fire` and `walk_market` are FAKE destinations.
`_resolve_target` (`civilian.gd:653-660`) honours `working_point_pos` for **exactly three** actions:
`ACTION_WALK_PADDY`, `ACTION_WORK`, `ACTION_FISH`. Everything else returns
`home + random(±3m)`.

Worse, the leaves ignore even that: `_bt_walk_fire` (`:693-700`) hardcodes `home + Vector3(2,0,2)`
and `_bt_walk_market` (`:702-708`) hardcodes `home + Vector3(-3,0,4)`. So a garrison man "going to
chow" walks 2.8 m from his bunk and stands there. There is no mess marker in that path.

**Briefing:93 says "The HQ traffic and the nurse rounds are schedule + marker work, NOT a new
system." That is only true through `ACTION_WORK`.** It is still not a new system — but it is not
pure data either, and pretending otherwise is how this gets scheduled as "an afternoon of TOML".

### 0.3 The target refreshes ONCE PER SIM HOUR.
`_bt_tick` (`civilian.gd:521-527`) re-picks the action and re-resolves `target_pos` only when
`int(hour)` changes. **One destination per sim hour, per man.**

This is the single biggest blocker to "doctors/nurses walking around checking on people". Through
the existing tree, a medic assigned `ACTION_WORK` walks to one bedside and stands there for a full
sim hour. He cannot walk the rows. Fixing it is a new leaf that owns its own sub-target list —
see 2.3 — not a change to the hour cadence (the hour cadence is correct and cheap; do not touch it).

### 0.4 Garrison men have never group-walked.
`_assign_households` is called only for villagers (`mission_generator.gd:948`). Garrison men are
spawned in `_build_firebase_garrison` (`:871-911`) and **never get `group_id` or `group_members`** —
they keep the `-1` default (`civilian.gd:62`). `_group_walk_apply` (`:547`) returns false on
`group_id < 0`. GroupWalk is proven on villagers only (`tests/test_group_walk.gd`).

So the stretcher pair is the FIRST garrison group-walk. Expect it to be the first thing that
exposes a GroupWalk assumption.

### 0.5 The firebase interior is NOT FURNISHED IN GAME, and there is no code to furnish it.
`production/firebase_interior_wiring.md` (2026-07-26) proposes `US_INTERIOR_PROPS` / `US_PROP_DIR`
and a `_furnish_interior` call from `place_firebase_main`. **None of it landed.**
- `US_INTERIOR_PROPS`, `US_PROP_DIR`: **zero hits repo-wide.**
- `place_firebase_main` (`site_planner.gd:990`) never calls `_furnish_interior` (`:524`) or
  `_collect_stations` (`:555`). Only `stamp_village` does (`:299-300`).
- `_furnish_interior` (`:527`) still reads `prop_class` via bare `get_meta`, which the kit exports
  strip — so even if called, every marker would furnish nothing. §3 of that doc is unlanded too.

**Interior-first therefore has NO CONSUMER today.** The first code slice of this whole council is
those three edits, and it must land before any tent art is exported or the props sit on disk unseen.

### 0.6 Two independent work-marker readers already exist (ADR-023 hazard, live).
- `SitePlanner._collect_stations` (`:555-566`) — instance method, village path, returns
  `{pos, type}` dicts, folds any `cook` variant to `"cook"`.
- `SitePlanner._ensure_fsb_markers` (`:864-895`) — **static**, firebase path, walks the GLB
  offline for `work_` prefixes, strips the `_001` suffix, sorts by XZ for determinism.

Both parse `work_<type>` names. Neither knows about the other. Any new marker convention must be
taught to both, or the tent will staff correctly from one path and be empty from the other. Flagging
it rather than fixing it here — merging them is its own change.

### 0.7 `CampDirector` cannot drive the firebase garrison.
Briefing:78 says gun/mortar pits go "through the EXISTING `camp_director`". `CampDirector`
(`scripts/enemies/camp_director.gd:14`) writes `EnemyBase.camp_role` and `EnemyBase.work_pos`
(`:122-128`) over an `Array[EnemyBase]` garrison. **The firebase garrison is `Civilian` with
`is_garrison = true`** and is driven by `CivilianSchedules` + `working_point_pos`. There is no path
from CampDirector to a Civilian. The US-side authority that actually exists is
`SitePlanner.fsb_garrison_plan` (`:900-946`) + the schedule tables. Wire the tent there.

---

## 1. THE BIG ONE — RANDOM, OR THE CASUALTY LEDGER?

**The owner has ruled: ledger, seeded at 1–2. My job is to name what the ledger actually is, and
the honest finding is that IT DOES NOT EXIST YET.** Here is the audit, field by field.

### 1.1 What persists a KIA — one field, and it self-destructs
`CampaignState` (`scripts/autoload/campaign_state.gd:22-60`) persists: `threat_level`,
`threat_modifiers`, `reputation`, `roster`, `missions_played`, `mission_log`, `iron_man`,
`player_data`, `intel_points`, `collapsed_tunnels`, `field_marks`, `pencil_marks`,
`reported_marks`, `lifetime_intel`, `next_stash_at`, `ears_taken`, `rack_condition`, `depot_loss`.
The save keys are `save_campaign` (`:255-282`). **There is no casualty field of any kind.**

The nearest thing that exists:
- `SquadSystem._on_member_died` (`scripts/squad/squad_system.gd:437-445`) sets
  `m["alive"] = false` on the roster dict, appends the man's name to
  `director.state.flags["squad_kia"]`, and calls `CampaignState.save_campaign()`.
- `flags` are merged into the AAR result (`mission_state.gd:138-139`), so
  **`result["squad_kia"]` reaches `_bank_patrol` today** (`field_director.gd:1530-1535`).
- `CampaignState.on_mission_end` (`:204-237`) then reads only `kills`, `success`, `is_anti_aa`,
  `aa_killed`, and logs `{type, success, kills, seed}`. **`squad_kia` is banked into the result
  dictionary and then thrown away.** It is one key away from being a ledger and nothing reads it.
- And the roster's own record is destroyed on the next patrol: `SquadRoster.ensure_roster`
  (`squad_roster.gd:165-173`) filters `alive == false` out of the roster and backfills rookies.
  The comment even says it — *"Drop the dead (they stay in memory only via the log)"* — and the log
  it names (`mission_log`, `campaign_state.gd:233-238`) records `{type, success, kills, seed}` and
  **not the dead man**. So a KIA persists for exactly one save/load transition and is then erased.

**MINIMAL FIELD TO ADD (KIA): `CampaignState.kia_total: int` + `kia_names: Array`.** Incremented in
`_on_member_died` (`squad_system.gd:437`), which already touches the roster and already saves. One
var, one increment, one `cfg.set_value` in `save_campaign` (`:255`), one `get_value` in
`load_campaign` (`:284`), and a `reset_campaign` (`:378`) clear. `SAVE_VERSION` bump only if the
loader is strict — it reads with defaults, so an absent key reads 0 and old saves migrate free.

### 1.2 What persists a WOUNDED — nothing, anywhere
`MissionState._base_result` (`mission_state.gd:143-159`) returns
`{success, reason, mission_type, seed, kills, damage_taken, time_sec, contacts_detected,
contacts_avoided, ground_covered, waypoints_reached}`. `kills` is ENEMIES killed
(`field_director.gd:1539` prints it as "%d KILLS"). `civilian_deaths` (`:23`) is noncombatants and
is *deliberately* held out of `build_result` (`:20-22`).

**There is no friendly-WIA concept in this codebase at all.** Grep for `wounded` / `WIA` /
`wounded_days` across `scripts/`: **zero hits.** The only wounded state that exists is:
- `EnemyBase.is_downed` (`enemy_base.gd:2289`) + `downed_pool` (`:2297`) — enemy side, cleared by
  `MissionScope` (`mission_scope.gd:28`).
- `HealthSystem.downed_started` / `downed_ended(revived)` (`health_system.gd:8-9`) — the PLAYER's
  bleed-out window, counted nowhere.
- `AllyBase.OrderMode.RESCUE` (`ally_base.gd:160`), issued by `SquadSystem` (`:232-237`) to send
  the medic to the player. It has **no completion counter** — nothing increments when Doc gets
  there.

**MINIMAL FIELD TO ADD (WIA): `MissionState.friendly_wia: int`, incremented on (a) every completed
ally revive and (b) every `downed_ended(true)` on the player; then banked to
`CampaignState.ward_wounded: int` in `_bank_patrol` (`field_director.gd:1525`).** A man who was
downed and saved is a wounded man — that is exactly the event the owner means by "the more
casualties you're taking out in the field". A man who was downed and NOT saved is a KIA and goes to
1.1. **The two counters must be fed by two different outcomes of the same event, or one incident
double-counts as both a bag and a bed.**

### 1.3 THE RULING — a QUEUE with real arrivals and a seeded prior
Not a random number, not a persistent ward roster. **Occupancy = `bed_count` slots, filled by a
three-source arrival queue with per-bed dwell, held on a per-operation node, seeded from the
persistent ledger.**

| source | value on a fresh boot | value after a bad patrol | provenance |
|---|---|---|---|
| **seeded prior** | **1–2** (owner's number) | 1–2 | `f(mission_seed, sim_day)` — deterministic, ADR-010, never `randf()` |
| **field arrivals** | 0 | +1 per `friendly_wia` banked at the wire | `_bank_patrol` (`field_director.gd:1525`) |
| **siege arrivals** | 0 | +1 per garrison man wounded in the night | `_on_siege_ended` (`:1408`), `_garrison_stand_down` (`:1423`) already walks the survivors |
| **departures** | dwell timeout, or a bearer carry to a heli | same | see 3 and 5.4 |

Why the seeded prior is the right shape and not a cheat: the owner supplied it himself, and it is
also the only thing that answers **the fresh-player concern**. A firebase aid station that is EMPTY
on patrol 1 reads worse than random — an unused hospital is a diorama with no timer at all. 1–2
occupied litters says "this base has been here six months and the war happened before you arrived."
It is the SAME argument `civilian.gd:626-638` already makes about `place_for_current_hour`: the
world must have been there all along, not assemble itself on approach.

**Fresh-boot hazards, both real:**
- The prior must be computed and the props placed **before the tent is first drawn**, not on a
  timer. If bed 3 fills while the player is looking at bed 3, the whole illusion inverts.
  **Rule: a bed's occupancy may change ONLY (a) before first visibility, (b) via a bearer carry, or
  (c) while the player is >25 m away or has no line of sight to that bed.** A litter that blinks is
  the one failure that reads worse than a static diorama.
- The ward node must **not** be an autoload. It is per-operation, built with the world, dies with
  it. An autoload would survive `CampaignState.reset_campaign` (`:378`) and carry a dead campaign's
  casualties into a new one — exactly the drift class this project keeps paying for.

**What this SACRIFICES:** no cross-operation identity. The man you failed to save on patrol 3 is
not still in that bed on patrol 4 — only the COUNT carries, via `ward_wounded`. Named,
individually-tracked wounded would need a real ward roster in the save file, a save migration, and
a second persistence system for set dressing. Refused. The count is the story; the name is not.

---

## 2. THE MEDICAL TENT AS SCHEDULE + MARKER DATA

### 2.1 New occupations — `scripts/ai/civilian_schedules.gd`
Four new blocks in `action_for` (`:26-210`). **Each must be added to
`tests/test_firebase_garrison.gd:13-16 GARRISON_OCCUPATIONS` or the suite goes red twice**: once
because `_check_world` fails any garrison man whose occupation is not in that list (`:141-142`),
and once because `_check_schedules` (`:45-58`) requires **≥3 distinct actions across 24 h** and
forbids falling through to `ACTION_IDLE`. Both are good ratchets. Design to them.

| occupation | shape of the day | notes |
|---|---|---|
| `medic` | 05–12 ROUNDS · 12–13 WALK_FIRE · 13–20 ROUNDS · 20–21 TALK (handover) · 21–05 REST | 4 distinct actions ✓ |
| `medic_night` | 18–06 ROUNDS · 06–07 WALK_FIRE · 07–14 SLEEP · 14–16 SIT · 16–18 WALK_FIRE | the ward is never empty at dusk — the exact bug the garrison rewrite records at `civilian_schedules.gd:95-103` |
| `orderly` | 05–11 WORK (triage marker) · 11–12 WALK_FIRE · 12–18 WORK · 18–20 TALK · 20–05 SLEEP | the litter-humping, water-carrying man; **also the stretcher-bearer pool** |
| `officer` | 06–11 WORK (`work_plot`) · 11–12 WALK_FIRE · 12–19 WORK · 19–21 TALK · 21–06 REST | HQ map study |
| `runner` | WORK all day against a rotating door list, SLEEP 22–05 | HQ traffic; see 4 |

Two men on `medic`/`medic_night`, two on `orderly`, two on `officer`, two on `runner`.

**One-line dictionary change with real payoff:** `FSB_WORK_OCCUPATION` (`site_planner.gd:818-826`)
currently maps `"plot" → "radioman"`. Split it: `"plot" → "officer"`, `"radio" → "radioman"`. Today
the TOC is staffed by three RTOs and no one is reading the map.
Add `"aid" → "orderly"`, `"triage" → "medic"`, `"graves" → "orderly"`. **Without these entries every
new marker falls through to `off_duty`** (`site_planner.gd:927`) and the aid station staffs itself
with loafers.

### 2.2 Markers the tent chunk must carry (HIS Blender time)
All `work_`-prefixed markers are picked up by `_ensure_fsb_markers` (`site_planner.gd:864-895`) with
**zero code change** — it already strips the Blender `.001` / glTF `_001` suffix (`:884-887`) and
sorts by XZ for determinism (`:889-895`).

| marker | count | purpose |
|---|---:|---|
| `work_aid_001..012` | 8–12 | one per litter, at the litter's **head** end, facing the litter. This is where a nurse stands over a patient. The litter count IS the marker count. |
| `work_triage_001..002` | 2 | the medical chest / plasma table — the medic's stationary WORK post |
| `work_graves_001` | 1 | the body-bag stack post (see 5) |
| `prop_medic_001..012` | 8–12 | so `_furnish_interior` places `fb_litter` — the `medic` prop class already exists in the wiring doc (`firebase_interior_wiring.md:47,74`) but **the pool does not exist in code** (0.5) |
| `door_aid_out_001` | 1 | **on the OUTSIDE sill.** Bearer form-up point and the despawn anchor. |
| `bed_patient_001..012` | 8–12 | position + facing for a laid-out casualty. **`bed_` prefix, NOT `work_`** — a `work_` name here would be swept up by the garrison sampler (`:913-928`) and put a standing rifleman on top of every litter. |
| `bed_overflow_001..008` | 6–8 | **the owner's "stacking up AROUND the medic tent."** Litters on the ground outside, under the fly. |
| `bag_stack_001` | 1 | origin + facing of the body-bag row (see 5) |

Same for HQ: `work_plot_001..002`, `work_radio_001`, `door_hq_out_001`.

### 2.3 The ONE new leaf — `_bt_rounds` (`ACTION_ROUNDS`)
Everything above rides existing machinery except a nurse walking the rows, which 0.3 forbids. One
leaf, on the existing tree, ~20 lines:

- Reads a new blackboard key `round_points: Array[Vector3]`, written once at spawn from the tent's
  `work_aid_*` markers (the ward node has them; it hands them to its two medics).
- Holds `round_idx` and a dwell timer in the same blackboard. Walk to `round_points[round_idx]`,
  dwell 6–10 s (deterministic per man from `hash(name)`, the pattern `_bt_work` already uses at
  `civilian.gd:727` — never `Time`, ADR-010), advance the index, return RUNNING throughout.
- **Skip unoccupied beds.** The nurse checks the men who are there. She should read the ward's
  occupancy mask, so a half-empty tent produces a short circuit and a full one a long one — the
  rounds get visibly busier as the player's war goes worse, for free.
- `_resolve_target` (`:653-660`) gains `ACTION_ROUNDS → round_points[0]`, so
  `place_for_current_hour` (`:639-650`) still seats her correctly and a wake from LOD_FAR does not
  drop her at her bunk.
- Registered in `build_bt`'s `by_action` table (`:478-491`) and given an anim mapping in `_animate`
  (`:309-317`) — `"stooped"` when stopped, `"walking_unarmed"` when moving, which the existing
  garrison chain already resolves (`_play_garrison:357-361`).

That is the entire code cost of the medical tent's LIFE: one leaf, one `_resolve_target` case, one
anim case, four schedule blocks, six dictionary entries. **Nothing parallel to the BT. ADR-023 clean.**

**What this SACRIFICES:** `_bt_rounds` is a seventh flavour of "walk somewhere and wait", and the
right long-term move is to collapse `_bt_work` and `_bt_rounds` into one parametric leaf and then
un-freeze `rest`/`cook`/`sit`/`talk` through it. I am not proposing that here — it touches every
occupation in the game and it belongs in its own change. But adding `_bt_rounds` without noting it
is how the seventh leaf becomes the eighth.

---

## 3. STRETCHER BEARERS — FORM UP OUTSIDE

### 3.1 It is BOTH, and the nav constraint is the harder half
**Nav, measured from the code:** `NavBaker.AGENT_RADIUS = 0.5` (`nav_baker.gd:45`) — a 1.0 m agent
diameter before voxel quantization (`:193`). `GroupWalk.FOLLOWER_SPACING = 1.6` (`group_walk.gd:10`)
places a follower 1.6 m **behind** and 1.6 m **to the side** of the lead (`:34-36`). A two-man party
therefore occupies a ~3.2 m-wide, ~2.6 m-deep box, and needs ~4.2 m of clear navigable width to
form up without a body being pushed off-mesh.

An aid-tent aisle between two rows of litters is 1.5–2 m. **A two-man litter team cannot form up
inside the tent. The second man would stand in a litter or outside the canvas.** His instruction is
a nav fact first and a taste call second — say that to him, because it means the rule survives any
future re-tune of the tent's interior.

**Spectacle, second:** it is also the better shot. Two men jog out empty-handed, take stations at
the sill, and the litter appears between them. The alternative is a 2 m rigid object being yawed
through a doorway, which is where the clipping lives.

**The Blender lesson holds and constrains this:** the front bearer ends **at the sill** and the
litter is a **legged cot**. So the load never rotates inside the doorway — the front man stops at
the threshold and the pivot happens outside, in the open, where the legs have room. The form-up-
outside rule and the sill-stop lesson are the same geometry seen from two ends.

### 3.2 Implementation on the EXISTING GroupWalk — three gates to open
GroupWalk itself needs **no change**. It is already the right mechanism and its movement-authority
header (`group_walk.gd:3-6`) is the contract to honour: *it writes no velocity; `_step_toward`
(`civilian.gd:368`), called once at the tail of `_bt_tick`, is the only thing that moves a
Civilian.* The dustoff must obey that absolutely — write blackboards, never velocity.

Three gates in `civilian.gd`:
1. **`group_id` / `group_members` are never set for garrison men** (0.4). Set them on the bearer
   pair — at spawn is cleanest (a standing pair, id fixed), not at dustoff time.
2. **`GROUP_WALK_ACTIONS`** (`:39-41`) lists only the four villager travel actions.
   Add `&"walk_litter"`, or `_group_walk_apply` (`:549`) refuses the party.
3. **`_group_party`** (`:572-584`) requires both men on the **same** `scheduled_action()`, and
   `scheduled_action()` (`:538-539`) reads `_bt_bb["scheduled_action"]`, which `_bt_tick` **rewrites
   from the schedule on every hour rollover** (`:523-527`). A dustoff that spans an hour boundary
   yanks both bearers back to their day jobs mid-carry, with a litter between them.
   **Fix: an `override_action` blackboard key, checked before the hour re-pick, cleared by the leaf
   on arrival.** ~4 lines in `_bt_tick`. This is a real bug waiting, not a hypothetical — a
   35-second dustoff crosses an hour boundary roughly once every few runs at any sim-clock rate.

### 3.3 The four beats — one owner, driving two men by blackboard
Trigger: `AirTraffic` LZ_CYCLE. `_advance_cycle` (`air_traffic.gd:404-419`) moves a flight
`inbound → ground → climbout`, and `GROUND_SECONDS = 35.0` (`:53`).

**Trigger on `inbound`, not `ground`.** `heli.fly_to(lz…)` is called at `:399`; the descent gives
the bearers the whole approach. A 60 m carry at `GROUP_WALK_SPEED = 1.3` (`civilian.gd:42`) is ~46 s
plus form-up — **35 s of ground time is not enough** and triggering on `ground` guarantees a missed
bird. There is no signal on AirTraffic today (grep: no `signal` declarations in that file); add
**one** — `lz_inbound(lz_pos)` — and let the ward listen. One signal, one listener; not a scheduler.

1. **SUMMON.** Two `orderly` men get `override_action = &"walk_litter"`, `group_id` set, destination
   `door_aid_out_001`. They walk there **unloaded**, side by side, at group speed.
2. **FORM UP.** Both within 1.5 m of the door marker → lead faces the door, follower takes the
   trailing slot, dwell ~2 s. **This beat happens entirely outside the canvas. This is the thing he
   asked for.**
3. **CARRY.** The patient prop is attached between them and the destination becomes the pad. Use
   `SeatSystem`'s pattern verbatim (`seat_system.gd:14`: *"AI bodies get physics/process/collision
   off + a RemoteTransform3D"*) — a patient prop needs even less, since it has no physics to
   disable. Keep 1.3 m/s. Do not speed a litter carry up; the slowness is the shot.
4. **HAND OFF.** At the pad the patient prop frees, ward occupancy decrements, `override_action`
   clears, both men fall back to their schedule.
   **If the bird has lifted, they carry him back.** A missed dustoff is better theatre than a
   teleport, and it is the honest consequence of a 35 s ground hold.

**Bearers must be men who ALREADY EXIST** — two `orderly` men off their posts. Spawning two bodies
per dustoff is the perf sin this whole analysis is trying to avoid, and it would also mean two men
materialising in front of the player 20 m from a landing helicopter.

**Slice-1 shortcut worth taking:** have the first dustoffs pull from the **overflow litters
outside** (`bed_overflow_*`). No doorway, no interior nav, no sill-stop — the entire choreography
can ship and be judged by his eyes before the tent interior is furnished at all.

**What this SACRIFICES:** the pair is committed for ~90 s per dustoff. Their `orderly` WORK post
stands empty for that time, and if the aid station has only two orderlies, a dustoff during a siege
means nobody is at the triage table. Accept it (it reads correctly — everyone is at the pad) or
budget a third orderly, which is one more body.

---

## 4. HQ TRAFFIC — DOOR-MARKER DESPAWN. He walks in and he is gone.

**Ruling: they never enter the tent.** A runner paths to `door_hq_out_001`, steps through the flap,
`visible = false` + `set_physics_process(false)`, dwells 90–180 s, then re-enables at the door and
walks out to the next building.

**Why, on the code:**
- The interior is unfurnished today (0.5), and once furnished it holds a field desk, two chairs, a
  map board and a plotting board in a ~5×8 m tent. `_furnish_interior` places props **after** the
  site is stamped; the firebase navmesh is baked from `_queue_firebase` (`nav_baker.gd:126-135`)
  over the GLB root's colliders (`_add_colliders`, `:208-209`) — **the runtime-placed interior props
  are not in that source geometry.** So an NPC pathing inside walks straight through the desk.
  A man clipping a desk destroys exactly the illusion the interior-first workflow exists to create.
  A man who steps through canvas and is gone does not: **the canvas is the occluder, and the player
  cannot see in.**
- It is also nearly free. A despawned body costs zero physics. HQ traffic is the ONE living-world
  feature on this list that does not spend the body budget while it is inside.
- The pattern already exists — this is `LazyGroup`'s 1 Hz distance poll (`lazy_group.gd:48-60`)
  inverted, and `Civilian` already does exactly this pair of calls in its informer path
  (`civilian.gd:263-264`: `visible = false; set_physics_process(false)`). **Do not write a new
  despawner.** One `_bt_errand` leaf, or `ACTION_WORK` against a door target plus a hide-on-arrival
  branch.

**The permanent staff are REAL BODIES and are never despawned.** Two `officer` men at
`work_plot_001..002` studying the map and one `radioman` at `work_radio_001` stand inside, always.
The tent is always manned; only the TRAFFIC is theatre.

**Cost, named honestly:** if the player walks into the HQ tent he finds three men and no traffic.
He will find this. Mitigations: (a) permanent staff as above, so the room is never empty;
(b) put the despawn point ~1.5 m inside the flap, behind the occluder, so the vanish is never on
camera from outside. A player standing in the doorway watching would still see it. **That is the
accepted hole, and it is the correct trade: one hole visible only to a man deliberately staring at
a tent flap, versus every NPC walking through the furniture.**

**Cadence:** two `runner` men, phase-offset by `hash(name)` (deterministic, ADR-010). Their route is
**door → door**, not into one building: HQ door, then supply depot door, then the mess, then back.
Traffic BETWEEN buildings is worth more than traffic into one, and it costs the same. Two runners on
opposed phases give 1–2 men in transit at any moment and a flap that opens every couple of minutes —
his spec, exactly.

**Fresh-boot hazard:** `place_for_current_hour` (`:639-650`) teleports each man to his schedule
target on his FIRST physics tick (`:235-237`). A runner whose boot-hour target is a door marker
spawns standing in the flap. Seat runners at their quarters at boot, or bias the first target to the
route's outdoor leg.

---

## 5. THE DEAD — BODY BAGS AS A DIEGETIC SCOREBOARD

This is the strongest item in the brief and I am treating it as first-class. It is a cumulative,
wordless record of the player's own failure that costs the frame **one draw call** and **zero AI**.
It fits ADR-029's no-objective-counter rule and the standing "XP is never shown" doctrine precisely:
the player is never told his butcher's bill; he walks past it.

### 5.1 Where the stack lives
At `bag_stack_001`, on the **pad side** of the medical tent — between the aid station and the
helipad, so it sits on the path the bearers walk and on the path the player walks coming back
through the wire. Rows of 4, ~0.7 m pitch, ~2.0 m row spacing. Deterministic layout, no jitter roll.

### 5.2 How it grows, and the two counters it needs
- **Persistent, never clears: `CampaignState.kia_total: int` (+ optional `kia_names: Array`)** —
  the war record. Added per 1.1, incremented in `_on_member_died` (`squad_system.gd:437`).
- **Per-operation, clears on a lift: `bags_unlifted: int`** on the ward node. Seeded at world build
  from `min(kia_total, CAP)`, incremented by each in-operation KIA and by garrison dead after a
  siege (`_garrison_stand_down`, `field_director.gd:1423`, already enumerates the promoted men).
- **`CAP = 12` visible.** Three rows of four. Above twelve the stack reads as a pile, not a count,
  so the twelfth bag is the last one that communicates anything. Overflow is silently held in the
  integer, not drawn.

### 5.3 Does it ever clear? YES — graves registration, on a heli, with a floor
Lift the stack on an LZ_CYCLE `ground` phase (`air_traffic.gd:410-412`) **only when
`bags_unlifted >= 6` AND the oldest bag is at least one sim day old.** So:
- The first few bags **always sit there**, through at least one night. That is the point.
- A campaign going badly still accumulates faster than the lifts clear it.
- The pad never becomes a permanent horror set in a 20-patrol campaign.

`kia_total` is **never** decremented by a lift. The persistent number is the war's record; the
visible stack is only the unlifted backlog.

**What this SACRIFICES:** the stack is not a faithful lifetime total — a player who has lost 30 men
across a long campaign sees at most 12 bags and often fewer. I am choosing legibility over
accounting: 12 bags beside the pad says "we are losing" better than an honest 30 would, because 30
reads as scenery. If he wants the true total visible, that is a different feature (a graves plot
outside the wire that only grows) and it should be asked for explicitly.

### 5.4 Does the WOUNDED count decay? YES — and the bearers are the mechanism
The owner already put evacuation in the picture, so connect the two directly:

- **Bearer carry completes → occupancy decrements by 1.** The bearers ARE the decay path, and that
  is why the choreography earns its cost: it is not a cutscene, it is the ward's drain.
- **Pull order: OVERFLOW FIRST, then beds.** The worst cases lying outside go out first. It is
  correct triage-theatre, it means the tent visibly "un-swells" from the outside in, and it lets
  slice 1 ship with no interior pathing at all (3.3).
- **Passive decay for the light cases:** a bed's dwell timer expires and the man walks out — but
  **only under the never-blink rule** (1.3): decrement off-camera or >25 m, never in view. Do not
  spawn a body to walk him out; just clear the slot while nobody is looking.
- **Net effect the owner asked for:** a quiet run drains the ward toward the seeded 1–2 floor; a bad
  patrol fills the beds and then spills onto the overflow litters outside; a very bad night fills
  the overflow AND grows the bag row. Three visible registers, one integer each, no UI.

---

## 6. PERF — THE BODY BUDGET

### 6.1 The measurement, cited
`production/PERF_LEDGER.md:288-304`, arena, 65+ live units: AI physics wall **37.5–39.8 ms per
physics tick**. Think **1.20–1.28 ms (~3%)**. Hitzone sync **~10 ms**. `move_and_slide` **~9 ms**.
Anim/execute remainder **~18 ms**. **~94% is the BODY.** Counters at `CombatManager.ai_usec_*`.

First-order marginal cost per body: 39 ms / 65 ≈ **0.6 ms/physics-tick**. That is an estimate from a
mixed-unit arena, not a measured `Civilian` figure — a Civilian is cheaper than an EnemyBase (no
perception, static hitzone bands per `civilian.gd:170-173`) but it still pays `move_and_slide` and
`_animate`. Treat 0.6 as a ceiling and **measure before spending more than I authorise below.**

### 6.2 THE FINDING: the civilian LOD does not help you inside the firebase
`civilian.gd:239-242` skips the body **only at `LOD_FAR`, which is 300 m** (`:83`). Between 80 m and
300 m (`LOD_NEAR`) the only savings are the nav router (`_step_toward`, `:372-373` falls back to
direct steering) and the navmesh box refresh (`:271-272`). **`move_and_slide()` (`:287`) and
`_animate()` (`:288`) still run every frame.**

The firebase footprint is ~369 m across (`FSB_HALF`, and `place_firebase_main`'s corner reach is
~252 m, `site_planner.gd:1000-1003`). **A player standing anywhere inside the wire has essentially
the entire garrison at full body cost.** The three-tier LOD is a WORLD LOD, not a base LOD. Nobody
should plan firebase population on the assumption that LOD will pay for it.

### 6.3 The budget ruling: **+8 bodies gross, +4 net. Occupied beds cost ZERO bodies.**
Current ceiling `FSB_GARRISON_MAX_MEN = 24` (`site_planner.gd:830`): 17 curated
(`FSB_GARRISON_POSTS`, `:791-806`) plus a work-post sample clamped by
`work_budget = clampi(24 - 17, 0, FSB_WORK_POST_CAP=12)` (`:913`), i.e. 7 work-post men today.
`tests/test_firebase_garrison.gd:20` reads the constant from the planner, so raising it moves the
test with it — that ratchet is correctly built and I am not fighting it.

**Raise `FSB_GARRISON_MAX_MEN` 24 → 28 and no further.** Spend it:

| new men | occupation | bodies |
|---|---|---:|
| ward | `medic` + `medic_night` | 2 |
| ward | `orderly` ×2 (also the bearer pair) | 2 |
| HQ | `officer` ×2 (map study) | 2 |
| HQ | `runner` ×2 (despawned most of their cycle) | 2 |
| | **gross** | **8** |
| reclaimed | `FSB_WORK_POST_CAP` 12 → 8 (drop 4 `off_duty` work-post men) | −4 |
| | **NET** | **+4** |

Take the four back from the `off_duty` work-post sample specifically. Loafers at a wash drum are the
least legible men in the compound and there are already three curated `off_duty` posts of 2 men each
(`:802-804`). Four fewer loafers for four men with a visible job is a straight upgrade in
legibility at zero net cost.

**Net frame cost: +4 bodies ≈ +2.4 ms on a 38–40 ms wall ≈ 6%,** minus whatever the two runners give
back while despawned. **That is the honest price of the entire living-world pass and it is
spendable.** Anything beyond 28 men inside the wire needs a measured Civilian figure first, not this
estimate.

### 6.4 THE MOST IMPORTANT PERF RULING: patients and bags are NOT AGENTS
**Occupied beds must cost zero bodies.** A wounded man on a litter does not move, does not think,
does not path, and must not be shootable as an agent. He is a **prop**.

The arithmetic that settles it: 12 patients as `Civilian` bodies ≈ **+7.2 ms** on a 38–40 ms wall
(~18%) — for twelve men who lie still. That single mistake would cost three times the entire rest of
this pass. Refused.

**And the project is CALL-BOUND, so 12 separate patient meshes is 12+ draw calls in one tent.**
The answer to both problems is the same, and the pattern already exists in-repo:
- **Patients: ONE `MultiMeshInstance3D` per pose variant.** `MultiMesh.TRANSFORM_3D`, transforms
  written from the `bed_patient_*` / `bed_overflow_*` markers, and **occupancy is
  `instance_count`**. Ship **two** pose variants = **two draw calls** for the whole ward, inside and
  overflow. Existing pattern: `ai_stress_arena.gd:556-566`, `gore_lab.gd:218-220`.
  Rotating occupancy then costs one integer write. **That is why "rotating occupancy" is affordable
  at all.**
- **Body bags: ONE MultiMesh, one draw call, `instance_count = bags_unlifted`.** Same economy as
  `Destructible`'s shared rubble. A bag needs no AI, no physics, no collider (or one shared box if
  he wants to not walk through the stack). Growing the stack is `instance_count += 1` plus one
  `set_instance_transform`. **The entire body-bag feature is one node and one draw call.**
- **ART CONSTRAINT THIS IMPOSES, and it must go to him:** a MultiMesh patient is a **static pose**,
  so the patient mesh must be **BLANKETED**. A blanketed litter reads correctly at 2 m in a dim
  tent; a bare unanimated body would read as a corpse or a mannequin. The visible variety must come
  from the blanket and litter, not from the man.
- **One exception worth paying for:** the patient nearest the entrance may be a real `ModelActor`
  playing `laying_breathless` — **the clip exists** (`enemy_base.gd:2396`) — so the ward has one
  visibly breathing man. One skinned mesh, no AI, no physics, `SeatSystem`'s glue pattern
  (`seat_system.gd:14`). One draw call and one animated skeleton, for the read of the whole tent.

**What this SACRIFICES:** no per-patient variation, no breathing on 11 of 12 men, and the wounded
cannot be interacted with — you cannot talk to them, treat them, or recognise your own squadmate in
a bed. If he ever wants "that's Doc in bed three", that patient becomes a real body and gets its own
budget line. The ward as designed is atmosphere, not a system with verbs.

---

## 7. WHAT EACH RULING SACRIFICES — collected

| ruling | sacrifice |
|---|---|
| Seeded ledger, per-operation ward node | No cross-operation wounded identity. Only the COUNT carries (`ward_wounded`). No save migration, no second persistence system. |
| `kia_total` persists, visible stack caps at 12 | The bag row is not a faithful lifetime total. Legibility chosen over accounting. |
| Graves lift at ≥6 bags + 1 sim day | A tidy player may rarely see more than 6 bags. The floor exists so the first ones always sit through a night. |
| Patients + bags as MultiMesh props | No breathing (except one), no variety, no interaction with the wounded. The ward is atmosphere, not a system with verbs. Art must deliver BLANKETED patients. |
| `_bt_rounds` as a new leaf | A seventh flavour of walk-and-wait, when the right fix is one parametric leaf plus un-freezing the six frozen ones. Deferred deliberately, recorded here so it is not forgotten. |
| Runners despawn at the door | Walk into the HQ tent and there are three men and no traffic. Stand in the doorway watching and you see a man vanish. Accepted against every NPC clipping the furniture. |
| Bearers are existing `orderly` men | The triage table stands empty for ~90 s per dustoff. A third orderly is one more body. |
| Trigger dustoff on `inbound`, carry him back on a miss | Sometimes the player watches two men carry a casualty back to the tent. That is the honest cost of a 35 s ground hold, and it reads as war. |
| 28-man ceiling, 4 loafers traded out | The compound loses four ambient bodies at wash drums and ammo niches. ~+6% on the AI physics wall for the whole pass. Beyond 28 needs a MEASURED Civilian figure. |
| Never-blink rule on occupancy | Occupancy cannot change in front of the player, so a ward drain can look stalled if he camps the tent. A blink would be worse. |

---

## 8. WHERE THE CODE CONTRADICTS THE BRIEFING

| briefing | code |
|---|---|
| `:92` "before that every scheduled action froze the man in place" — implying it is fixed | Only `_bt_work` is fixed (`civilian.gd:721-737`). **Six leaves are still byte-identical freezes:** `_bt_rest` `:739` · `_bt_cook` `:747` · `_bt_sleep` `:755` · `_bt_fish` `:763` · `_bt_sit` `:771` · `_bt_talk` `:779`. `mess_cook`'s COOK block cooks wherever he stands. |
| `:93` "HQ traffic and nurse rounds are schedule + marker work, NOT a new system" | Only `ACTION_WORK`/`WALK_PADDY`/`FISH` resolve a marker (`_resolve_target` `:656-659`). `walk_fire` and `walk_market` are hardcoded home offsets (`:696`, `:705`). `target_pos` refreshes once per SIM HOUR (`:523`). Nurse rounds need a new leaf. Still not a new system — but not pure data. |
| `:83` "21 US interior props exist and are UNEXPORTED" | True, **and the code to place them does not exist either.** `US_INTERIOR_PROPS` / `US_PROP_DIR`: zero hits. `place_firebase_main` (`site_planner.gd:990`) never calls `_furnish_interior` (`:524`) or `_collect_stations` (`:555`). `_furnish_interior` still reads `prop_class` via bare `get_meta` (`:527`), which the export strips. **`firebase_interior_wiring.md` §2–§4 are ALL unlanded. Interior-first has no consumer.** |
| `:78` "the EXISTING `camp_director` … is the mechanism" | `CampDirector` (`camp_director.gd:14`) writes `EnemyBase.camp_role` / `work_pos` (`:122-128`) over an `Array[EnemyBase]`. The firebase garrison is `Civilian` with `is_garrison = true`, driven by `CivilianSchedules` + `working_point_pos`, spawned by `mission_generator._build_firebase_garrison` (`:871-911`). **No path exists from CampDirector to a Civilian.** The real US authority is `SitePlanner.fsb_garrison_plan` (`:900-946`). |
| `:108-111` "is rotating occupancy random, or is it the CASUALTY LEDGER?" (framed as a choice between two existing things) | **Neither exists.** No casualty field in `CampaignState` (`:22-60`) or `MissionState._base_result` (`:143-159`). `result["squad_kia"]` reaches `_bank_patrol` via `flags` (`squad_system.gd:441` → `mission_state.gd:138`) and **`on_mission_end` (`:204-237`) discards it.** `SquadRoster.ensure_roster` (`:165-173`) then deletes the dead from the roster. The ledger must be BUILT: two ints (1.1, 1.2). |
| — (not in briefing) | Garrison men have **never group-walked**: `_assign_households` is villager-only (`mission_generator.gd:948`), so every garrison man keeps `group_id = -1` (`civilian.gd:62`) and `_group_walk_apply` (`:547`) refuses. The stretcher pair is the first garrison group-walk in the project. |
| — (not in briefing) | **Two independent `work_` marker readers** already exist and do not know about each other: `_collect_stations` (`site_planner.gd:555-566`, instance, village) and `_ensure_fsb_markers` (`:864-895`, static, firebase). ADR-023 hazard, live today. |

---

## 9. SEQUENCE — smallest slice that visibly pays off

1. **CODE, no art needed.** Land `firebase_interior_wiring.md` §2–§4: `US_INTERIOR_PROPS`,
   `US_PROP_DIR`, the `prop_class` name fallback, and the `_furnish_interior` +
   `_collect_stations` call in `place_firebase_main`. **Nothing else on this list can be seen until
   this exists.**
2. **CODE.** The two ledger ints (`kia_total`, `ward_wounded`) + `MissionState.friendly_wia`.
   Four small edits, no new files, no save migration.
3. **CODE.** The ward node: patient MultiMesh ×2 + bag MultiMesh ×1, seeded prior 1–2, overflow
   outside. **This alone gives him rotating occupancy AND the bag stack with zero new bodies and
   three draw calls** — and it can be judged by his eyes against a bare tent floor before a single
   interior prop is exported.
4. **HIS BLENDER TIME.** The marker set in 2.2, on the tent chunk, interior-first.
5. **CODE.** The four schedule blocks + `_bt_rounds` + the `FSB_WORK_OCCUPATION` entries + the
   `GARRISON_OCCUPATIONS` test list. Nurses walk the rows.
6. **CODE.** `AirTraffic.lz_inbound` signal + the four-beat dustoff, pulling from the OVERFLOW
   litters first — no interior nav required for the first version.
7. **CODE.** HQ runners + door despawn.
8. **LAST.** Raise `FSB_GARRISON_MAX_MEN` to 28 / drop `FSB_WORK_POST_CAP` to 8, and **measure**
   before believing my 0.6 ms/body estimate.
