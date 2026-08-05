# Systems Designer — Garrison men are soldiers (2026-08-04)

Lens: system topology and cost of change. Every claim below was read from code this session
(Pointer Law). No plan documents were consulted beyond the briefing.

---

## 1. The complete touch map — who knows a garrison man is a Civilian

A retype ripples through every site below. Counted by file, this is the blast radius ledger
the options are priced against.

### The identity itself
- `scripts/world/civilian.gd:8-9` — `class_name Civilian extends CharacterBody3D`. ~910 lines.
- `civilian.gd:94` — `var is_garrison: bool` on the class; `:160` set in `spawn()`.
- `civilian.gd:250-251` — **the ruling's trigger**: `_on_noise` hard-returns `if is_garrison`.
  A garrison man is deaf by design; outside stand-to VC in the wire meet a man sweeping floors.
- `civilian.gd:372-373, 438-501` — `_play_garrison`: ~65 lines of US role-aware clip chains
  (off_duty, medic, patient, detail, mess_cook, quartermaster, ARMED_POSTS at `:147`).
- `civilian.gd:149-152` — `GARRISON_MEN` model roster.
- `civilian.gd:113` — `puppet` flag (LitterTeam drives position AND clip; `:289-291` physics
  stands down when puppet).
- `civilian.gd:123-133, 735-761` — 3-tier LOD; LOD_FAR (300m) hard-returns the whole body tick.
- `civilian.gd:214-218` — **hitzones are STATIC BANDS by measured decree**: "16-40 civilians and
  11 bone-synced convex hulls each is ~6.4ms/frame of hitzone sync." Remember this number; it is
  the perf landmine under option (a).
- `civilian.gd:601-909` — the schedule BT: dispatch + 12 leaves + `_bt_settle` (`:867`, THE ONE
  settle implementation), `place_for_current_hour()` (`:777`), group walk (`:684-722`).
- `civilian.gd:28, briefing W-9` — **no order verb exists.** `_wander_target` is rewritten every
  BT tick from the schedule (`_bt_tick:652-671`); nothing external can command a walk.

### The promote/demote bridge
- `scripts/allies/garrison_defender.gd:26-89` — `promote()`: synchronous 1:1 Civilian teardown →
  `AllyBase.spawn_ally`, HOLD at post, MG emplacement / mortar station claim, groups swapped
  `firebase_garrison` → `garrison_promoted` (`:42, :84`), occupation/unit carried in meta (`:87-88`).
- `garrison_defender.gd:98-126` — `stand_down()`: reverse swap, `Civilian.spawn(..., true)` (`:122`).
- `scripts/missions/field_director.gd:985` — `_garrison_stood_to` latch; `_garrison_stand_to()`
  `:1394-1410`; `_garrison_stand_down()` `:1492-1500`.
- **When stand-to actually fires** (the briefing asked): exactly two callers —
  `_on_siege_began` (`field_director.gd:1441-1442`, siege/probe only) and a delivery landing into
  an already-stood-to base (`heli_lift.gd:249-250`, gated on `_garrison_stood_to` already true, so
  it promotes only the fresh arrivals). **Nothing else.** A VC squad walking to the wire off-siege
  hits `civilian.gd:250-251` deafness and no promotion path. The confirmed-multi-man-threat
  trigger the comment at `field_director.gd:1391-1393` describes does not exist as code — the
  comment over-claims ("a confirmed multi-man threat on the wire"); the only threat detector,
  `_fsb_threat_active` (`:991`), feeds the crisis radio, not stand-to. That is the gap the ruling
  is aimed at.

### Consumers of the flag/groups (each a retype touch)
1. `scripts/autoload/combat_manager.gd:114, 166` — `spare_garrison` satchel decree; **duck-typed**
   `civ.get("is_garrison") == true` while iterating `AgentRegistry.civilians` (`:161`). Moving the
   men out of the CIVILIAN registry bucket silently changes who a satchel spares AND who ordinary
   blast reaches (allies are iterated separately at `:138` with the 0.4x indirect discount `:149-150`
   that civilians never get — a retype changes garrison blast math whether you mean it to or not).
2. `scripts/enemies/placed_satchel.gd:59` — passes `spare_garrison` FALSE by decree; comment names
   the mechanism.
3. `scripts/vehicles/heli_lift.gd` — the deepest coupling: `_pax: Array[Civilian]` (`:58`),
   `_rotated_off: Array[Civilian]` (`:62`), `_load_pax` spawns `Civilian.spawn(..., GARRISON_MEN, true)`
   (`:191-192`), `garrison_strength()` counts both groups (`:117-118`), `_extract` casts
   `as Civilian` (`:272`), `_on_took_off` casts `as Civilian` (`:303`). Plus the 2026-07-30 ruling
   carved into `:178-181`.
4. `scripts/vehicles/seat_system.gd:321-338` — **W-9**: `board_squad` casts `as AllyBase` (`:332`);
   null for a Civilian → no MOVE_TO (`:334`) → `_board_one` glue-teleports on the stagger timer.
   The dead/downed guards (`:328-330`) are already duck-typed and would pass either class.
5. `scripts/missions/siege_director.gd:690-693` — mortar victims = `allies` + `garrison_promoted` +
   `civilians` groups. Group-based, survives a retype only if group membership is preserved/renamed.
6. `scripts/missions/mission_generator.gd:917-980` — `_build_firebase_garrison`: the spawner. Sets
   `occupation` and `working_point_pos` AFTER `Civilian.spawn` returns (`:968-971` — answering the
   briefing's "who sets occupation/working_point": this function, and `garrison_defender.stand_down:123-124`,
   and `heli_lift._load_pax` does NOT — a replacement's occupation defaults to "farmer",
   `civilian.gd:90`, a small pre-existing wart). Litter team spawned here `:931-948`.
7. `scripts/world/litter_team.gd` (via `civilian.gd:113` puppet contract) — bearers are
   `Array[Civilian]` handed over whole (`mission_generator.gd:932-940`).
8. `scripts/missions/terrain_watchdog.gd:28` — reseats `["enemies", "allies", "civilians"]` groups.
   Garrison men in `firebase_garrison` but also `civilians` (spawn adds it, `civilian.gd:234`).
9. `scripts/player/player.gd:244` — iterates `"civilians"` group (garrison currently included).
10. `scripts/ai/civilian_schedules.gd:99-215` — seven garrison occupations plus the three-sitting
    `mess_hall` chow block (`:202-209`). Pure static functions keyed on occupation string — this
    is the most PORTABLE piece; it does not care what class calls it.
11. `scripts/ai/group_walk.gd:29, :49` — casts `as Civilian`; villagers only in practice (garrison
    never gets `group_id`), no retype cost.
12. `scripts/autoload/agent_registry.gd:10-38` — Kind.CIVILIAN bucket feeds combat_manager blast.
13. `scripts/allies/ally_base.gd:115, 155-157, 1117` — the promoted half already exists in AllyBase:
    `_is_garrison_defender()` = `post_anchor != ZERO`, post leash, no-close-distance (`:114-117`).
14. `scenes/tests` — `tests/test_firebase_garrison.gd` reads SitePlanner's plan constant
    (`site_planner.gd:858`).

**Fourteen files/systems know.** That is the honest retype bill.

### What AllyBase LACKS (the porting cost of any migration)
Read of `ally_base.gd:1-170`: combat brain (think 0.15s, goals, cover, personality, orders
FOLLOW/HOLD/MOVE_TO/RESCUE `:160`), navmesh routing, post leash. It has **no** schedule hook, no
occupation, no working point, no SimClock listener, no chow, no LOD_FAR tier (it has the WA-A2
body heartbeat gate `:43-45`, a different, shallower throttle), no puppet latch, and **bone-synced
hitzones** (`:38 _hitzone_sync`) where Civilian deliberately runs static bands.

---

## 2. VC-side audit — CONFIRMED: no armed VC runs as Civilian

The ruling's second sentence is **already satisfied by the code's topology**:

- VC/NVA camp garrisons are `EnemyBase` end to end. `camp_director.gd:29` `garrison: Array
  ## Array[EnemyBase]`; roles + `work_pos` swapped hourly (`:111-132`); guards assigned `:93-104`.
- Camp-life POSES run ON the soldier class: `enemy_base.gd:584-596` `CAMP_ROLE_CLIPS`
  (guard/cook/rest/talk/sleep), `_play_camp_role()` `:628-644` — explicitly "Mirrors
  Civilian._play_garrison" (`:581`). A VC cook who takes contact is already a full combat AI —
  `_play_camp_role` bails the moment `target != null or alert_tier > SUSPICIOUS` (`:633`).
- `lazy_group.gd:75-111` spawns every camp/patrol body via `director.spawn_tracked_enemy` (`:88`)
  from `EnemyData` .tres pools (`:14-27`) and attaches a CampDirector (`:110`). `vc_farmer.tres`
  is an ENEMY archetype (Local Force in farmer clothes), not a Civilian.
- `mission_generator.gd:1021` — village `Civilian.spawn` is the only VC-adjacent Civilian, and he
  is a true noncombatant. The informer (`civilian.gd:582-593` `_transform_to_vc`) swaps the MODEL,
  leaves the `civilians` group, and the body is immediately `visible = false` +
  `set_physics_process(false)` (`:312-313`) — a despawning courier, never an armed actor. The
  actual fighters come from `director.on_informer_escaped` as EnemyBase.

**Finding:** the VC side needs ZERO class work. If anything needs touching it is presentation
(the archetype NAME `vc_farmer` and any debrief/label strings), which is out of my lane. More
important: **the VC side is the architectural proof** that one soldier class can carry camp life —
role string + work_pos + an hourly director, no second class, no promote bridge.

---

## 3. The ~14-man-systems count, per option

Live man-representations today: EnemyBase, AllyBase, Civilian, Player — plus the bridges/drivers
that make them plural: GarrisonDefender promote/demote, informer `_transform_to_vc`, LitterTeam
puppet, CampDirector (enemy camp life), FriendlyPatrolGroup (`squad_member=false` allies),
LazyGroup, HeliLift pax handling. The garrison man alone exists in TWO representations with a
2x/day identity swap.

- **(a) migrate to AllyBase/GarrisonSoldier**: SUBTRACTS one — GarrisonDefender dies whole
  (fossil law satisfied in the same change), the day/night swap dies, `is_garrison` dies from
  Civilian, `_play_garrison` (~65 lines) moves out of civilian.gd. End state mirrors the VC side:
  one class per side, roles as data.
- **(b) shared person base**: ADDS the 15th system. It touches Civilian AND AllyBase AND (for
  symmetry) EnemyBase, the three most load-bearing files in the game, to solve a problem the VC
  side already solved without one. Reject on the divergent-systems constraint alone.
- **(c) minimal bridge**: adds a verb, keeps both representations and the swap. Net zero systems,
  debt retained.
- **(d) staged**: (c)'s wiring now, (a)'s subtraction after the demo.

---

## 4. Weighing

### Blast radius (files touched)
- (a): ~13 (all of §1 except group_walk) + new GarrisonDirector + delete garrison_defender.gd.
- (b): those 13 + enemy_base/ally_base/civilian class headers + every `extends` consumer. Largest.
- (c): 3-4 (civilian.gd verb + reaction hook, seat_system.gd caller, field_director trigger widen,
  optionally heli_lift group rename).

### The W-9 asymmetry — the single strongest fact for (a)
Under (a), **W-9 closes for free**: `seat_system.gd:332` `as AllyBase` succeeds,
`OrderMode.MOVE_TO` already exists (`ally_base.gd:160`), men walk to the staging point and the
shipped `board_heli` clip (`heli_lift.gd:45`) finally plays over a real approach. Under (c) we
build a SECOND order channel into Civilian that (a) would then delete — deliberate scaffolding,
must be marked as such or it becomes the next fossil.

### Fossil law
(a) is the only option that BURIES something: garrison_defender.gd, the `is_garrison` deafness
gate, the meta-carried occupation laundering (`garrison_defender.gd:87-88, 106-107`), and the
`firebase_garrison`+`garrison_promoted` double-group accounting that `heli_lift.garrison_strength`
(`:113-118`) and `siege_director.gd:692` both have to know about. (c) preserves all of it.

### Determinism (ADR-010)
All options survivable. (a) must keep: spawn-position-hashed model pick and idle seed
(`civilian.gd:186-190`) → move the same hash into the AllyBase garrison spawn;
`SquadRoster.generate_member(_seeded_rng(stand))` (`garrison_defender.gd:56`) already seeded.
The mess-sitting derivation keys off node NAME (`civilian_schedules.gd:205`,
`civilian.gd:663`) — preserve naming or the sittings reshuffle.

### Perf at 40 heads — the landmine in (a), with a number on it
`civilian.gd:214-218` is a MEASURED decree: bone-synced hulls at 16-40 bodies ≈ 6.4ms/frame, so
Civilians run static hitzone bands. AllyBase rides zones on bones (`ally_base.gd:38`). Forty
garrison AllyBase spawned the default way re-buys the exact cost the static bands were built to
avoid. **Condition on (a): garrison AllyBase must spawn with static bands off-combat** (swap to
bone-sync on stand-to if fidelity demands, which is when zone accuracy matters anyway). Think
cost is the smaller worry: an idle AllyBase think at 6.7Hz with no target is cheap, and the WA-A2
body gate exists; but AllyBase has no LOD_FAR body skip, and the garrison lives exactly where the
player does. Port the LOD hard-return or accept ~40 always-ticking bodies. This is real
engineering, not a rename — it is why (a) is not a one-day change.

### Demo-ship risk
(a) mid-migration breaks: stand-to, stand-down, heli rotation, satchel sparing, siege mortars,
litter team, chow — the demo's whole "living firebase" spine. Days of work plus his playtest.
(c) is additive and shippable in ~a day.

### Reconciling the 2026-07-30 heli ruling
`heli_lift.gd:178-181`: pax are Civilians BECAUSE "an AllyBase has no schedule or work marker so
it would stand where it landed forever." The 2026-08-04 ruling does not contradict this — it
**removes its premise**. Once the schedule brain lives where the soldier class can reach it
(GarrisonDirector on the VC pattern), the 07-30 ruling's reason evaporates and pax become
garrison soldiers with no loss. Supersession, not conflict. Until then the 07-30 ruling stands,
which is exactly why the retype cannot precede the schedule port.

---

## 5. Verdict — (d): stage (a) through (c)'s wiring

**End state (a), on the VC precedent**: garrison men are AllyBase (`squad_member=false`,
`post_anchor` set) with occupation/working_point as fields and a **GarrisonDirector mirroring
CampDirector** — role string + station + SimClock hour, calling into the already-class-agnostic
`civilian_schedules.gd` statics. GarrisonDefender, the deafness gate, and the double-group
bookkeeping are deleted in the same change (fossil law). Civilian returns to being ONLY true
noncombatants, which is the ruling verbatim.

**Demo slice (~a day), ships first**:
1. **React = widen the existing promote trigger** (no third combat brain): route garrison noise
   through the stand-to path — replace `civilian.gd:250-251` deaf-return with, for
   gunshot/explosion inside the wire radius, `director._garrison_stand_to()` (idempotent,
   `field_director.gd:1395-1396`). One line of behavior; the base stops ignoring contact
   (Pillar 1) using the ONE shipped path (ADR-023).
2. **W-9 = promote-on-boarding OR a marked scaffold verb.** Cheapest honest fix: in
   `heli_lift._extract` (`:271-285`), promote the boarding men (`GarrisonDefender.promote`) and
   let `board_squad`'s existing AllyBase branch issue MOVE_TO — they are leaving the garrison's
   books anyway (`_on_took_off:306` strips the group), so no stand-down orphan. Zero new verbs,
   zero new files.
3. **Honest naming now, retype later**: the demo keeps the class; the ruling's visible surface
   (any UI/debrief string calling a garrison man a civilian, the casualty accounting in
   `_record_noncombatant_death` `civilian.gd:565-569` — a garrison man who dies must NOT tally
   as a noncombatant death; today he does until promoted, via the `civilians` group he holds at
   `civilian.gd:234`) is corrected by pulling garrison men from the `civilians` group at spawn
   and auditing the three group-consumers (`combat_manager.gd:161` — moves him out of civilian
   blast iteration, so verify satchel/blast paths still reach him via a garrison-aware branch;
   `siege_director.gd:693` already covers him via `garrison_promoted` only when promoted — add
   `firebase_garrison`; `terrain_watchdog.gd:28` add the group).
   NOTE: step 3's group surgery is the riskiest of the three (blast-path semantics). If the day
   runs short, ship 1+2 and ledger 3 into the migration.

**Named sacrifice**: through the demo, the class is still called Civilian and two representations
of the same man persist — the ruling is satisfied in BEHAVIOR (they react, they fight, they are
not counted as noncombatants) but not yet in TYPE. And the full migration, when it lands, spends
the static-hitzone economy unless the bands are ported with the men — that port is a hard
condition, not a nice-to-have.

**What I refuse**: (b). A shared person base is the 15th parallel man-system, minted to solve a
problem the EnemyBase camp-life pattern (`enemy_base.gd:584`, `camp_director.gd`) demonstrably
solves with role data on the soldier class.
