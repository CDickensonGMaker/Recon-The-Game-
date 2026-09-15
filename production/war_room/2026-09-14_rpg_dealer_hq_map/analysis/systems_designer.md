# SYSTEMS DESIGNER — the dealer, the HQ chain, the Huey crash survivors, the observatory (2026-09-14)

Read: briefing; the 9/13 decree + my 9/13 analysis; ADR-005/010/019/032/038/044(draft, memory)/045;
the memories named in the summons; and the code below. Every claim carries a pointer. The code beat
the summons in seven places (§0). Individual sight — no cross-talk. Build nothing.

## 0 · What the code says that the summons does not

1. **The Huey already has a crash state, and nothing sets it.** `Helicopter.State.CRASHING` /
   `DESTROYED` (`helicopter.gd:9`), `_process_crashing` (`:261-272`) sinks the ship 16 m/s on
   `-basis.z`, banks it, and at ground contact deals the ONE airframe-death blast
   (`apply_explosion_damage(150, 40, 10)`, `DamageSystem SMALL_EXPLOSION 0.7` — the same yardstick
   `cas_airplane.gd:244-253` cites) — and then does nothing: no signal, no wreck, no free. `SeatSystem`
   already dresses pilots and gunners for CRASHING/DESTROYED (`seat_system.gd:369, :410`). Grep for
   `State.CRASHING` outside the enum/match/seat dressing: **zero writers.** UNFINISHED under the fossil
   law's triage, not FOSSIL — it is the half of the feature he is asking for.
2. **Only one kind of Huey carries men: the `lz_cycle` slick.** Transit Hueys are empty airframes
   (`air_traffic.gd:664-718`, `_spawn_transit` seats nobody). The pad cycle (`_dispatch_lz_cycle`,
   `:808-836`) attaches `HeliLift`, which mints **2 aircrew** (`Civilian.AIRCREW`, `heli_lift.gd:137-160`)
   and **3–6 garrison Civilians** as pax (`PAX_MIN 3 / PAX_MAX 6`, `:258-284`), all seated and real.
   His roll — pilots 1–2, pax 1–4 — fits that ship exactly: 2 pilots aboard, 3–6 pax aboard.
3. **The pad cycle is on a fixed sim clock**: 07:30, 11:30, 15:30, 19:30 (`air_traffic.gd:138-141`).
   At the shipped arc (START 6.5, DAY_RATIO 27, `demo_game.gd:53`) the 11:30 slick is airborne at
   **667 s real = 11:07** into the demo — inside the handoff's "11–21 min: main outing, a witnessed
   crash" window (`DEMO_40MIN_HANDOFF §0A` table) and past `PilotRecovery.HOLD_FIRE_S = 600`
   (`pilot_recovery.gd:16`). The fixed point already exists; nobody has to invent a timer.
4. **The ZPU can see the slick and refuses to shoot it.** `_acquire` takes anything in group
   `air_traffic` (`zpu_gun.gd:202-217`; the lz_cycle heli joins that group at `air_traffic.gd:822`), but
   `_roll_kill` returns unless `_flight_kind(t) == "skyraider"` (`zpu_gun.gd:225-226`). The demo
   guarantee landed on the Skyraider (`:233`, `GameFlow.demo_mode`). One string is between the ZPU and
   a Huey.
5. **`PilotRecovery`'s escort has no catch-up and no registration.** The pilot is an `AllyBase` with
   `squad_member = false` (`pilot_recovery.gd:170-176`); `SquadSystem._catchup_tick` skips exactly those
   men (`squad_system.gd:727`), so the only anti-stuck he has is his own body's sidestep + snap
   (`ally_base.gd:63-96`). The file's own header records what that cost once. At the wire he is sent
   `MOVE_TO` the ward cot and stays an AllyBase forever (`:248-254`) — he never enters
   `firebase_garrison`, the census never counts him, and `stand_down` never gets his face.
6. **The civilian↔soldier swap with a whole-person snapshot already exists**: `GarrisonDefender.promote`
   (`garrison_defender.gd:26-110`) tears a garrison Civilian down synchronously, stands an AllyBase in
   his place and carries `garrison_occupation / unit / role / dig_ok / home` as metas; `stand_down`
   (`:119-162`) reverses it INTO `firebase_garrison`. That is "survivors register in the garrison" and
   the F10 whole-person fix, in one pair of functions that ship today.
7. **The tasking engine and its close condition exist.** `DynamicMissionFactory.emit_location` dedups
   by entity id and calls `FieldDirector.raise_crisis` (`dynamic_mission_factory.gd:36-49`), which
   pushes `{pos, kind}` to the front of `patrol_locations`, toasts `CRISIS_CALL[kind]`
   (`field_director.gd:1280`, `:1783-1800`) and the journal's ORDERS page draws it under WHAT THEY
   TOLD ME (`journal.gd:353-375`, reads `patrol_location_kind`). Closure is `_poll_sweep` →
   `_finish_sweep(what)` (`:1718-1775`) with `_in_sweep_ring / _hostiles_in_ring / _tunnels_in_ring`.
   `FieldLog` captures every toast (ADR-045 §2). No quest framework is needed; the HQ chain is four
   entries in `CRISIS_CALL` and four close predicates.

Also confirmed live from stage 1: `hm_ledger.gd` (bands by KIND, `note` idempotent, `place_key`), the
three producers (`field_director.gd:55-63` fire, `civilian.gd:1094-1097` civ killed, `:1189-1194`
informer talked), the two consumers (`Civilian._wary()` `:1308-1311` → `CivilianSchedules.action_for`
`:1422`; `night_warning` `field_director.gd:100-104`, called at the seam `demo_game.gd:628`),
`test_hearts_felt.gd`. Stage 2 (the temporary partner) is NOT built — no `temporary` in
`squad_system.gd`.

The only readers of `threat_label()` outside display rows: `_grant_fire_support` (once per day at the
first wire crossing, `field_director.gd:1593-1650`) and the siege night roll (dead in demo,
`siege_director.gd:241`). **`mission_generator.gd` has no density-by-threat** — the "density bands"
there are walking-distance rings (`:499`). Plan-time levers are seeded at boot (ADR-010) and a one-day
demo boots with an empty ledger, so **every band consumer for the demo must be a LIVE lever** (§2).

---

## 1 · THE DEALER — a supply sergeant with a price list

### 1.1 The shape: the armorer's bench with a different rack

The bench is already an in-world `[F]` node with a non-pausing menu, mouse released, built from a rack
the campaign state gates (`armorers_bench.gd:144-173`, `rack_for_tier(CampaignState.title_tier())`
`:46-53`; ADR-032). The dealer is **the same node shape** — `DealerTable`, stamped by `plan_demo_world`
beside the supply hooch the way the bench is stamped just inside the wire
(`mission_generator.gd:988-993`) — whose rack is built from **what the player is carrying** and **which
favours are open**, not from his tier. Nothing new in UI: one more `[F]` prompt, one more menu of the
`BenchMenu` class, the journal's ORDERS page listing his asks beside HQ's, `FieldLog` keeping what he
said. Talking to him is a line on the toast channel (ADR-038 §2: zero new UI).

The typed goods already exist:

| Good | Where it lives today |
|---|---|
| a captured weapon | `WorldWeapon.is_captured` (`world_weapon.gd:37`), `WeaponHolder.primary_is_captured` (`weapon_holder.gd:58`, set on pickup `player.gd:772-780`) |
| magazines | `weapon_holder.primary_mags` (`player.gd:841`) |
| bandages / belts | `SquadSystem.take_medic_bandage / take_mg_belt` (`squad_system.gd:430-449`) |
| off-book fire support | `FieldDirector.fire_support` dict (`:1605-1610`); demo hard-sets it once at the wire (`:1626-1632`) — a grant AFTER that read survives |
| a mark on the sheet | `CampaignState.reported_marks` (`field_director.gd:866-867`, kind "INFORMER") and `try_intel_stash` (`:1464-1513`, 3 marks 1 real) |
| a gun above his tier | `rack_for_tier` — the dealer's rack is the **one** place that ignores `armory_tier` |

### 1.2 The chain (four asks, two of them in conflict with HQ)

Ids are stable strings in one new `CampaignState.taskings: Dictionary` id → `{state, since, cause,
claimant}` (saved in all four places like `hearts` — `campaign_state.gd:322, :371, :413, :462`).
HQ and the dealer share the dictionary, so "same object, two claimants" is one `has()`.

| # | Id | His ask | What he pays | The HQ claimant | Ledger / presence consequence |
|---|---|---|---|---|---|
| D1 | `dealer/ak` | "Bring me one of theirs." A captured rifle (`is_captured` and id in `ak47/ppsh41/mosin/rpd`) laid on his table | three M16 mags, or a Colt for the wounded man later (D3) | **H2** wants the same rifle at S2 (`add_intel(2)` — the shipped intel economy, `player.gd:1031`). The rifle is one object; whoever gets it closes theirs and REFUSES the other (`taskings[other].state = REFUSED`, cause "sold to the dealer" / "turned in to S2") | none in `hearts` — a firebase transaction is not a village deed. HQ standing: the S2 intel that would have moved `next_stash_at` (`campaign_state.gd:97-117`) never arrives — **foregone, never deducted** (rank ratchets, ADR-006-B) |
| D2 | `dealer/ville_run` | "My guy in the ville stopped coming up the road. Walk this down to him." A case (an `[F]`-carried prop, the `supply_crate` model `field_director.gd:1180`) to the village elder | an off-book mortar round (`fire_support["mortar"] += 1`) and his first real line | **H1** says nothing goes down that road (its own close is "eyes on, nothing left behind") | **`trade/<village>/p<n>`, `KIND_TRADE`** — the FIRST deed that is not misconduct, and the dealer's whole point. The band reads it as its own subject (§1.3). Enemy presence: the case ends up in the ZPU camp's cache — H2's sweep finds a US crate in the VC cache (a `place_event_prop` of the same model at the camp, keyed off the deed), so the player meets his own trade on the enemy's side, wordlessly |
| D3 | `dealer/manifest` | after the crash: "There was a crate on that bird and nobody's counted it yet." Bring him the slick's cargo (the crate the wreck GLB carries at a `cargo_socket`, or the `supply_crate` prop placed at impact) and **do not** hand the manifest to the TOC | a rack item one tier above `title_tier()` — the only way a PVT holds an M79 in this demo (ADR-032 bypass, named as such) | **H3** closes on the manifest + tags at the TOC. Manifest reported → the crate is "accounted for" → D3 REFUSED; crate sold → H3 closes on tags only, HQ's line is the shorter one | `bags_unlifted` / `ward_wounded` move on the bank regardless (§3.5); HQ standing foregone = the `pilot_recovered`-class reputation the report would have banked |
| D4 | `dealer/ride` | "You want on a bird, you talk to me first." He puts the player on the next `lz_cycle` slick (`SeatSystem.board_squad`, `seat_system.gd:659`) — a ride to the crash site or home before dark | the ride | HQ has no claim; but a man who rides in is not on the wire at the seam — `night_warning` still fires or not on the ledger, the stand-to still runs | none. It is the favour that makes his standing FELT: he offers it unprompted when D1–D3 are closed his way, and never when they closed HQ's way |

**Rule check.** Loud play is never optimal: every dealer ask is a carry or a hand-over, none is a
kill; the case in D2 is carried into a village where any shot notes `fire/<village>/p<n>` and the trade
deed is refused (`note` returns false when a `fire/` deed for that patrol already exists — order matters,
and it is one `has()`). Stealth stays an economy: a player who wants the dealer's M79 walks a crate
past pickets he could have shot.

### 1.3 How his standing is FELT (ADR-038 §2a, no numbers)

- **Prices.** A price list is the black market's own register (ADR-038 §1) and it names objects for
  objects, never a standing: *"one of theirs for three of ours"* is legal; *"you're worth more to me
  now"* is not (direction of change). Prices do not move; **what is on the rack does.** Closed-his-way
  asks add rows; closed-HQ's-way asks remove them. A locked item is simply absent (ADR-032's rule).
- **What he will and won't say.** His pool is keyed by which `dealer/*` and `hq/*` ids are CLOSED,
  never by how many — a subject-keyed pool exactly like `HM_LINES`, and the same guard
  (`test_hearts_felt.gd` §3) greps it. Unprompted (ADR-038 §2a corollary): one line when the player
  walks within 6 m of the table, chosen by `hash(id) % n`.
- **Who is at his table.** Two `off_duty` chairs at his hooch marker (a `site_planner` post, the
  existing occupation vocabulary — `POST_OFF_DUTY_OCCUPATIONS`, `probe_npc_census.gd:36-38`). The men
  sitting there are draftees by placement (ADR-038 §3a: placement ships, lines do not). When H-side
  closes outnumber D-side closes the chairs are empty at 14:30 — the world's wordless reading, same
  law as the paddy. Nobody says why.
- **What is saved.** `CampaignState.taskings` only. The rack is derived from it every open; the crate
  prop is world state that dies with the world (demo: one day, `EXCLUDE_SAVES` sandbox).

---

## 2 · THE HQ CHAIN — four taskings, one lever per band each

Issued through `raise_crisis({pos, kind})` with a `CRISIS_CALL` line; drawn by the journal ORDERS page;
closed by a `_poll_sweep`-style predicate that a probe can call. HQ's reading is the least true one
(ADR-038 §2 rule 2): its lines are S2's opinion. HQ standing = `bank_reputation` at the wire
(`field_director.gd:2185-2191`) → `title_tier` → the armory rack and the FIELD PROMOTION toast. Hidden,
ratchets, never falls.

| # | Id / kind | Issued | Closes when (probe-able) | Band lever (LIVE only) — quiet / wary / hostile |
|---|---|---|---|---|
| H1 | `hq/eyes_on` `"village"` | at the gate order (`GATE_ORDER_AT_S 10`, `demo_game.gd:517`): *"SIX WANTS EYES ON THE VILLE. NOTHING LEFT BEHIND."* | player inside 40 m of the village centre once, then outside 120 m, with no `fire/` or `civ/` deed for this patrol | **what the ville gives.** quiet: the elder's `talk` bark plus one `reported_marks` entry kind `VILLAGER` on the REAL camp (`try_intel_stash`'s shape, `:1464-1513`, 1 real 0 decoys) · wary: the mark is a DECOY (3 marks, 1 real — the shipped default) · hostile: no mark, elder indoors, and the informer's responders (`INFORMER_RESPONSE 4`, `:469`) come regardless of whether he saw you — the ville sent them |
| H2 | `hq/camp` `"vc_camp"` | on H1 close, or at 600 s if H1 was ignored (Pillar 3: no gate) — the ZPU camp is the pointed location (`p.camp_centers[0]`, `mission_generator.gd:955`) | `_hostiles_in_ring() == 0` or the ZPU `silenced()` (`zpu_gun.gd:121`) | **who comes looking.** `_hunter_pool` at the wire is `maxi(_hunter_pool, 6)` (`:1565`) → 4 / 6 / 8; `_hunter_timer` roll (`:273`) × 1.25 / 1.0 / 0.8; wreck-picket `enemy_count` (`pilot_recovery.gd:184`) 2 / 3 / 5. Never a spawn from nothing: hunters still need an evidence fix (`:262-270`) |
| H3 | `hq/downed_bird` `"downed_bird"` | by the crash incident itself at 667 s (§3): *"SIX: WE LOST A SLICK SHORT OF THE PAD. GET OUT THERE."* — the call references the incident id, never a marker (handoff §0A crash rule 3) | survivors registered (§3.5) **or** the dog tags handed in at the TOC (`[F]` at the `radio_post`/TOC marker — the same proximity verb every `[F]` uses, `player.gd:524-555`) | **who hunts the site.** Pickets by band as H2; the impact's `EXPLOSION` noise (team 0, `NoiseBus.emit_noise` — the CAS impact already does this `cas_airplane.gd:250`; the Huey terminal does not, add it) becomes an evidence fix, so hunters walk to the wreck once the beacon is stamped by real contact (ADR-005) |
| H4 | `hq/before_dark` `"firebase"` | at 1400 s (DUSK, 23:20) *"SIX: GET INSIDE THE WIRE BEFORE DARK."* | `_bank_patrol` fires before the seam at 1667 s | **whether the warning comes.** `night_warning` as built (`:100-104`): `informer/<v>/talked` present → no line, no early stand-to; absent → the kid up the road at 1667, stand-to 73 s before the probe |

What a band changes that the summons asked about and the demo CANNOT deliver: "where a VC cache or
base can be permitted" and "patrol density" are plan-time (`_spawn_enemy_groups`, the `ambient_patrol_%d`
LazyGroups `mission_generator.gd:966-984`, `AmbushPlanner.plan`), seeded at boot from an empty ledger.
They are the 3x-map council's consumers for day 2+, not today's. Say so in the decree rather than
promise them.

---

## 3 · THE HUEY CRASH SURVIVORS

### 3.1 The candidates, from the code

| | (a) `PilotRecovery` follow | (b) `SquadSystem` temporary member | (c) TR pax / `HeliLift` convention |
|---|---|---|---|
| The men are | 1 `AllyBase` minted at the wreck (`:170-176`), `squad_member=false` | `_stand_up_member` → `members.append` (`squad_system.gd:110-137`) | 2 aircrew + 3–6 garrison `Civilian`s already seated in the ship (`heli_lift.gd:137-160, :258-284`) |
| Follow | `OrderMode.FOLLOW` formation slot, `_follow_offset` rolled once (`ally_base.gd:493`) | same FOLLOW plus `file_slot` staggered file (`:1547-1560`) | none — `Civilian` has no follow verb; needs `GarrisonDefender.promote` to become an AllyBase |
| Multi-follower | `_pilot` is a single var; `_tick_wait/_tick_escort` test one man | free — `members` is an array | free — `_pax` is an array |
| Stuck handling | body-level only (`_update_unstick`, `_rescue_snap` `:63-96`); **no** `_catchup_tick` (skipped at `squad_system.gd:727`) | `_catchup_tick` teleports unseen laggards behind the player (`:711-748`) — a lie for a wounded man | as (a) once promoted |
| Wounded speed | `move_speed` per body (`:13`), clips `wounded_crawl 0.8` / `injured_walk_backwards 1.2` exist (`model_actor.gd:1287-1288`) | same | same |
| Arrival | `MOVE_TO` ward cot, stays AllyBase, `state.flags["pilot_recovered"]` (`:248-254`) | stays in the squad — a ninth-to-fourteenth man on the wire; journal lists them as THE SQUAD (`journal.gd:411-427`); `_on_member_died` banks them as squad KIA | `stand_down` → `Civilian` in `firebase_garrison` with occupation/unit/home metas (`garrison_defender.gd:119-162`) = **registered** |
| Cost | none new | `SQUAD_SIZE` hand-synced in four files (memory: spine §rulings 1); `receive_replacements` semantics; Pillar 4 / handoff §0A: *he is not a squadmate* | `promote` refuses a seated man (`is_physics_processing()` false, `:33-36`) — unseat first, promote second |

### 3.2 Recommendation: (c) for the men, (a) for the escort, `GarrisonDefender` for the seams

**The survivors are the slick's own men.** They already exist as real, seated, dressed Civilians the
moment the ship is dispatched; the crash does not mint anybody (handoff crash rule 5: *the same survivor
persists; no duplicate person appears*). The chain, all existing functions:

1. **Shoot-down.** `ZpuGun._roll_kill` accepts `kind == "huey"` when `GameFlow.demo_mode` and the
   roster profile is `"inbound"` (`air_traffic.gd:835`); it calls a new `PilotRecovery.request_down_heli(heli)`
   that keeps every DAY gate `request_down` has (`:60-87`: one event, hold-fire, no siege, no other
   encounter) and calls **`Helicopter.shoot_down(crash_pos)`** — the writer the CRASHING state never had.
   `_process_crashing` gains the CAS terminal's three lines at ground contact: `NoiseBus EXPLOSION`,
   `crashed.emit(ground)`, and the seats' hand-off (below). The ZPU's HE (`:250-270`) and the ship's
   `-basis.z` dive are the spectacle he asked for; the trail is `CASAirplane._build_smoke_trail`
   (`cas_airplane.gd:206-227`) hoisted to a static so both airframes share it.
2. **The roll — seeded** (ADR-010). `PilotRecovery._rng` is deliberately unseeded for the ambient
   Skyraider (`:43-45`); the Huey beat is authored, so it takes its own `RandomNumberGenerator` seeded
   `hash(world.mission_seed) ^ hash("huey/day1")`. Pilots aboard 2 → alive `1 + int(r < 0.5)`; pax
   aboard `n ∈ [3,6]` → alive `randi_range(1, mini(4, n))`; wounded among the alive `randi_range(0, alive-1)`,
   one of them CRIT when alive ≥ 3. Same seed, same men, same states, every run.
3. **At impact.** `seats.unseat_all(door)` (the `_deliver` idiom, `heli_lift.gd:312`) puts every man on
   the ground at the wreck's `pilot_anchor`; the dead take fatal `take_damage` with attacker `null`
   (a garrison man's death is a casualty, never a noncombatant tally — `civilian.gd:1131-1135`; no
   `civ/` deed because `village_center == ZERO`); the living go through `GarrisonDefender.promote`
   (metas carry the pilot's face: `garrison_unit = us_pilot_*`) and get `set_order(HOLD)` at the anchor.
   The wreck is `place_event_prop(huey_crashed.glb)` (`:98-99`; collision entry exists,
   `collision_table.gd:86`), fires at `fire_socket_1..3` (`:151-160`).
4. **Wounded states.** Allies have no down state (`ally_base.gd:45`, ADR-040 post-demo). A wounded
   survivor is `current_hp` set to the journal's own bands (HIT ≤ 0.66, CRIT ≤ 0.33, `journal.gd:417-419`)
   plus `move_speed × {1.0, 0.6, 0.35}` and the walk clip swapped to `injured_walk_backwards` / `wounded_crawl`
   through the state map (`sprite_state_map.gd:261` already routes "crippled" → `wounded_crawl`).
   **The litter rule does not fit today:** `LitterTeam` is dormant until `fb_litter` exports (memory:
   litter architecture). `carry_wounded` / `being_carried` (`model_actor.gd:470`) are the pair a carry
   verb will use; name it, do not build it.
5. **Escort.** `_pilot` → `_men: Array[AllyBase]`; wake at `WAKE_M 12` from any man; all FOLLOW.
   **The group moves at its slowest man and there is no teleport for the wounded** — that is the beat.
   Two additions to `_tick_escort`: (i) gap > 40 m to the slowest man → one toast *"HE CAN'T KEEP UP"*
   (no numbers), gap > 60 m → the group HOLDs where it stands and re-wakes at `WAKE_M` — they do not
   chase a sprinting player across the AO; (ii) for the UNWOUNDED men only, the `_catchup_ground` idiom
   (`squad_system.gd:751-771`) when unseen and > 25 m, the same `perceivable` guard `_rescue_snap` uses.
   Off-mesh: the site is `_passable_near(…, keepout FSB_SITE_CLEARANCE)` seated ground (`:76-81`);
   `NavRouter.OFF_MESH_M` snap per body; the probe (§3.6) asserts `pilot_anchor` exists in
   `huey_crashed.glb` — I could not verify the socket from here and it must be a gate, not a hope.
6. **Arrival** at `HOME_M 30` of `fsb_center`: each man `GarrisonDefender.stand_down` → Civilian in
   `firebase_garrison`, occupation `patient` for the wounded (the ward cot post, `POST_OFF_DUTY_OCCUPATIONS`),
   `off_duty` for the walking; pilots keep `us_pilot_*` through the unit meta. The bank result carries
   `crash_wia` → `friendly_wia` (the explicit-count door `campaign_state.gd:283-285` was written for
   "a scripted event"), `crash_kia` → `kia_total`/`bags_unlifted` beside `pilot_lost` (`:263-265`).
   `taskings["hq/downed_bird"]` CLOSES with cause `"N walked in, M on litters, K in bags"` (observatory
   only — the toast says *"THEY'RE INSIDE THE WIRE. THE REST ARE STILL OUT THERE."* when K > 0).
   The end card's pilot line (`demo_game.gd:794-797`) reads the incident, not the old flag.

### 3.3 The fixed point

**667 s (11:07 real, 11:30 sim), the second pad cycle.** In demo mode `_dispatch_lz_cycle` picks its
inbound bearing so the approach crosses inside `ZpuGun.ENGAGE_M` of the camp gun (the pad and
`camp_centers[0]` are both plan data) instead of `rng.randf_range(0, TAU)` (`air_traffic.gd:824`); the
ZPU takes the pass. The phase table: H1 4–11 min, crash at 11:07 while the player is on the village
side; walk to the site (camp flank, opposite; the smoke column is the waypoint, no marker — the S28
doctrine), escort home 17–24 min at the CRIT man's pace; H4 at 23:20; seam 27:47. It replaces the
Skyraider as the demo's guaranteed shoot-down (`_used`, one event a day, `:8`) — see §5.

### 3.4 VC at the site by band

Pickets 2/3/5 (§2 H2). Hunters walk to the wreck only through the evidence ledger after a real
contact — the crash alone does not stamp `last_combat_contact_ms` (ADR-005), so a player who arrives
quietly meets the pickets and nothing else. Honest, and the DA will say thin; it is the witness rule.

### 3.5 What lands where

| Ledger | Key | Writer |
|---|---|---|
| casualty | `kia_total`, `bags_unlifted`, `ward_wounded` | `on_mission_end` via `_bank_patrol` result (`crash_kia`, `friendly_wia`) |
| garrison | `firebase_garrison` group, `patient`/`off_duty`, F10 metas | `stand_down` |
| HQ | `taskings["hq/downed_bird"]` + `bank_reputation` | `_bank_patrol` |
| hearts | nothing — a crash is not a village deed | — |
| intel | dog tags: `add_intel(1)` per body searched (bodies-give-intel-only) — needs the `lootable_corpses` group on the wreck's dead, today only `EnemyBase` joins it (`enemy_base.gd:3611`) | `player.gd:1150-1164` |

### 3.6 The headless gate

`tools/probe_crash_recovery.gd`, attached by `game_flow.gd` under `--crash-probe` exactly as
`--npc-census` is (`probe_npc_census.gd:5-9`), holding `stand_to_held` the same way. The arc clock is
real seconds (`demo_game.gd:599`), so the probe does not wait: at `SETTLE_S` it calls
`AirTraffic._dispatch_lz_cycle("huey")`, forces `PilotRecovery.request_down_heli`, and asserts per seed
(`--demo-seed=N`, 8 seeds):

1. the ship reaches `DESTROYED`, the wreck prop exists, `pilot_anchor` resolved (not `Vector3.ZERO`);
2. the roll: `1 ≤ pilots_alive ≤ 2`, `1 ≤ pax_alive ≤ min(4, aboard)`, dead = aboard − alive, and
   the same numbers on a second run of the same seed (ADR-010);
3. escort: the headless player node is stepped 15 m toward the gate every 10 s from `WAKE_M` — a
   leash walk; at every step every living man is ≤ 40 m from the player and `velocity.length() > 0.3`
   or within 1 m of his slot (the census's STUCK definition, `WALKING_MPS`), `_unstick_flips` never
   reaches 3 twice on the same man;
4. arrival: `firebase_garrison` grows by `alive`, `ward_wounded` by `wounded`, `bags_unlifted` by `dead`,
   `taskings["hq/downed_bird"].state == CLOSED`, and `_used` stays true (no second event);
5. the census sample at 14.5 re-runs with the survivors in the roster: no STUCK/OVERLAP regression
   against the 9/13 figures (stuck 14, overlaps 15 — memory `recon-n2-furniture`).
Exit 1 on any. Plus `test_demo_arc` unchanged (the crash moves no pin) and `test_hearts_felt` green
(the new lines join `HM_LINES`).

---

## 4 · THE OBSERVATORY — what must be exposed

A dev-only read under `scripts/dev/`, instantiated only under `--observatory` / `OS.is_debug_build()`;
absent = zero cost. It reads fields that exist; the exposure is a `snapshot() -> Dictionary` on three
owners. The `test_hearts_felt` no-count grep exempts `scripts/dev/` by path — a dev tool may count;
no player surface may.

| Owner | Expose | Today |
|---|---|---|
| `HmLedger` | `deeds` (public var) + a new `cause: String` per deed — *"player GUNSHOT 41 m from the well, no hostile inside 80 m, patrol 0"* — written by the producer, never shown to the player | `{kind, place, sim_hour}` only |
| per village | `place_key`, `band(place)`, the deed ids behind it, each villager's `_wary()` result and the `action_for` it chose, informer `is_informer / _inform_clock / _saw_player_at` (`civilian.gd:26, :539-553`) | scattered, readable |
| `FieldDirector` | `_escalation_active`, `_hunter_pool`, `_hunter_timer`, `evidence.best_fix`, `live_enemy_count("hunters"/"wreck_pickets"/"informer_response")`, `_informer_answered`, `night_warning`'s decision and which id withheld it, `fire_support`, `patrol_location_kind`, `taskings` | fields exist |
| `CampaignState.taskings` | per HQ/dealer node: `{state, since, cause, claimant}`; `title_tier()` (dev only) | new dict (§1.2) |
| `PilotRecovery` | incident `{id, phase, since, crash_pos, aboard, alive, wounded, dead}` and per man `{hp band, speed mult, order_mode, dist to player, _unstick_flips}` | `_phase`, `_pilot` only |

---

## 5 · What is sacrificed (Law 2)

- **The Skyraider loses its demo guarantee.** One event a day (`_used`); the slick takes the slot. The
  Sandy shoot-down goes back to the open world's 35% (`KILL_CHANCE`, `zpu_gun.gd:27`).
- **The dealer's rack is an ADR-032 bypass by design.** A PVT who trades holds an M79 the ladder meant
  for SP4. The black market IS the bypass — but a player who always trades never feels the crown, and
  the rank ladder's readout thins to the FIELD PROMOTION toast.
- **HQ standing cannot be spent, only foregone.** Reputation ratchets (ADR-006-B, spine ruling 9/09);
  the "cost in HQ standing" of siding with the dealer is the reputation that never banks. Thinner than
  the word "conflict" promises, and honest.
- **No litter today.** A CRIT survivor crawls home at a third pace; `fb_litter` is unexported. The walk
  home is 3–4 minutes of real time at that pace; the programme absorbs it, a player may not.
- **Plan-time levers do not move in a one-day demo.** Where the VC base, ambush placement and ambient
  patrol counts are seeded from an empty ledger; only the live levers (hunters, pickets, informer
  response, the warning, the ville's mark) read the band today.
- **Hunters at the wreck need a real contact first** (ADR-005) — the crash site is not hunted by the
  crash. The DA will call it quiet; the witness rule is why.
- **`taskings` is a fourth campaign dictionary** with the four-place save tax (`field_marks` was once
  lost by missing one — `campaign_state.gd:441-443` history).
- **Three new writers on old files** (`Helicopter.shoot_down`, `ZpuGun` kind filter, `PilotRecovery`
  generalised) — no new class, per the fossil law; `PilotRecovery`'s name becomes a small lie
  (`class_name` stays; the header must say it owns the Huey too, or it is drift).
