# TECHNICAL DIRECTOR — the doors to keep open before the solo/franchise pivot

**Council:** 2026-09-09 THE PROGRESSION SPINE · **Lens:** architecture, cost, performance, foreclosure.
**Method:** static read of `scripts/`, `terrain/`, `project.godot`, `production/adr/`. **No game run**
(Caleb is in the build, pid 13196), no editor launched, no gameplay file touched. Per ADR-015 these are
**located facts, not proven behaviours.** I timed nothing; every perf figure is quoted from
`PERF_LEDGER.md` with its line.

---

## 1 · THE DOORS TO KEEP OPEN

### 1.1 `SQUAD_SIZE` is hand-synced in FOUR places, and a Huey drives the roster back to eight

`measurements.md` named two sites. There are four — `squad_system.gd:23`, `squad_roster.gd:67`,
`barracks.gd:48`, `debrief.gd:118` — and the machine underneath them is worse than a constant.
`SquadRoster.vacancies()` (`squad_roster.gd:206-211`) returns `maxi(0, SQUAD_SIZE - living)`; it is read
by `field_director.gd:2145` and by `heli_lift.gd:417`, which calls `draft_replacements()`.
**The replacement bird is a servo whose set-point is 8.** A solo player is permanently seven short and
the game permanently tries to fix him. `ensure_roster()`'s refill (`:178-179`) is only half the blocker.

**Door:** one saved `CampaignState.squad_authorised`, read by all four sites *and* `vacancies()`, before
any ladder code exists. Two hours now; an unpicking job later.

### 1.2 Orders live inside `SquadSystem`, so a man who is yours but not in your squad cannot be ordered

`SquadSystem._unhandled_input` (`squad_system.gd:275-291`) is the **only** order handler in the game.
There is no player-side command node. And `friendly_patrol_group.gd:4-6` states the world's contract for
other US elements: *"they are NOT the player's squad: `squad_member` is false, they never enter
`SquadSystem.members`, and they take no orders."* **A borrowed RTO companion is exactly that shape.**
**Door:** orders must be owned by the player (or a command node) over a *listener set*, not by the squad
container.

### 1.3 The radio GATE and the radio SKILL read two different authorities — nobody has noticed

The sharpest find here. The gate is group-based and squad-blind: `_radio_check()` → `nearest_radioman()`
(`field_director.gd:795-821`), *"nearest living man in `radioman` wins, wherever he came from."* But the
skill is squad-only: `field_director.gd:554-556` calls `squad_system.member_by_mos("RTO")` and reads
`fo_fac` off **that** man; the learn-by-doing credit at `:602-605` does the same.

So a call through a **borrowed** radioman gets `_fo = 0` — widest sheaf (`FirePlan.sheaf_scale`), longest
cooldown (`_cas_cooldown = 25.0`), no extra arty round — **and banks no skill.** His best idea currently
ships strictly worse than his own RTO, with no fiction saying so, and feeds no progression.
**Door:** `fo_fac` belongs to the man on the net, not to the squad slot.

### 1.4 There is no world-side radioman to borrow

`add_to_group("radioman")` has four producers: `squad_system.gd:235` (the player's own RTO) and three
test levels (`ai_stress_arena.gd:1347`, `support_fire_range.gd:269`, `test_range.gd:127`). Zero hits in
`scenes/` or `data/`. The firebase garrison joins `"firebase_garrison"` (`mission_generator.gd:1070`,
`:1099`, `:1140`) and never `"radioman"` — even though `site_planner.gd:1173` already maps work markers
`"radio"`/`"plot"` to occupation `"radioman"` and `civilian_schedules.gd:165` gives it a round-the-clock
schedule. **One missing line.** `field_director.gd:792-794` describes borrowing a firebase radioman's
PRC-25 as a solved case; no such man exists.

### 1.5 The kit pivot's work-marker vocabulary is a `const Dictionary` in code

`site_planner.gd:1170-1240` — `FSB_WORK_OCCUPATION` and `FSB_WORK_PRIORITY` are GDScript consts naming
`chow_server`, `hooch_sleep`, `med_cot`, `latrine`, `pad`, `bunker`. Open question 3 of
`FIREBASE_REWORK_INTENT.md` asks whether markers should ride on the parts. **Yes — and the reason is not
the 488/23 mismatch. It is that a WW1 trench kit cannot add `work_firestep` / `work_sap` /
`work_dugout_signals` without editing `site_planner.gd`.** The kit build is the only cheap moment to move
this out of code.

### 1.6 The ambient war is anchored to the player, not to the world

`ambient_war.gd:58-70` places every distant-war event at `player.global_position + bearing * dist`,
400–800 m, 1–3 per sim hour, `FIRE_CAP = 2`. There is no front, no territory, no faction geography.
Correct and cheap for a firebase demo; **structurally unable to represent "other people's squads and
fights"**, which is the atmosphere the solo pivot leans on. Do not extend it on the player-relative frame.

### 1.7 One biome, in an enum — and no era concept anywhere

`vegetation_manager.gd:6-13` — `TerrainType { CLEAR, RICE_PADDY, GRASSLAND, LIGHT_JUNGLE, MEDIUM_JUNGLE,
HEAVY_JUNGLE }`, with `TYPE_SPECIES` (`:47-54`) and `TYPE_PROPS` (`:84-92`) as consts. The climate *is*
the enum. `world_config.gd:16` offers only a density multiplier, not a table selector.

More broadly: **no "era", "period", "theatre" or "campaign setting" concept exists in this codebase.**
`SimClock.Period` is time of day (`sim_clock.gd:9`); `TerrainConfig.Preset` is relief shape
(`terrain_config.gd:19-24`). The franchise decree's own reasoning — that TerrainEngine is already
preset-swappable — is true of *geography* and of nothing else. A WW1 title introduces that abstraction
layer; it does not extend one.

---

## 2 · PERIOD-AGNOSTIC FRAMES vs PERIOD CONTENT

**The communications ladder generalises, and the frame already exists — do not build a new one.**
`nearest_radioman()` asks one era-free question: *is there a living node in group `"radioman"` within N
metres?* A WW1 signaller at a field telephone, a runner, an OP — all are "a node in a group with a
reach." Two things must change and both are cheap now:

1. **Reach must move onto the comms asset.** `RTO_RADIO_RANGE = 10.0` is a `const` on `FieldDirector`
   (`:364`), so reach is global. A field telephone is a fixed post with reach along a wire; a runner is
   *latency*, not distance.
2. **The asset token must stop being the interface.** `"prc25_handset"` is a literal mesh-name lookup
   (`radio_handset.gd:110`), `OPTIONAL_GEAR_PREFIXES = ["prc25_"]` (`model_actor.gd:445`), and
   `grunt_dresser.gd:71` keys the whole radio kit off `prc25_*`. The *gate* is period-agnostic; the
   *body wiring* is spelled "PRC-25" in four files.

**The fire-support ladder is period CONTENT and should stay content.** `field_director.gd:558-600` is an
eight-arm `match kind:` over string literals, mirrored by a second `match` in `fire_plan.gd:74-103`, with
hardcoded toasts (*"FAST MOVER — SNAKE EYE"*) and VO ids. Each arm is a genuinely different *shape* —
`arty` walks a golden-angle spiral, `spectre` puts an airframe on station, `illum` changes the lighting.
A creeping barrage, a box barrage and a gas shell are equally shape-specific. **A generic "call fire"
system would be good at no war.** Only three things around the `match` must be agnostic: the gate
(already is), the budget dictionary (already is, `:345-346`), and the skill lookup (currently is not).

**The command verbs generalise completely** — only the *acknowledgement fiction* is period (a shouted
name in 1967, a whistle in 1916). **The squad is a frame; the MOS list is content**, and it is already an
array (`squad_roster.gd:64`).

**The one place the frame is genuinely missing is FACTION.** `EnemyData` has **no faction field at all**;
faction is inferred by string prefix in the shared base class — `enemy_base.gd:305-312`, *"the id prefix
IS the faction"*, returning `"vc"` if the id begins with `vc` and **`"nva"` for everything else.** It is a
binary with no third branch. `vc_nva_dresser.gd` is a class named for exactly two factions. Doctrine
itself is properly data-driven (`squad_coordinator.gd:38-49` loads `doctrine_%s.tres`), so **the gap is
one field on `EnemyData` and one function.** That is the cheapest era-abstraction available and it is
worth doing whenever `enemy_base.gd` is next opened.

**Cost of over-abstracting, named.** Do **not** generalise the firebase load path. `site_planner.gd` is
2,758 lines and, per the firebase council's TD, **63.5% is firebase-specific** — `FSB_CLEAR_DISCS`,
`_wire_m101_rigs`, `_stamp_hooch_radios`, `_animate_fsb_baked_cast`, `fsb_gate_metrics`. Generalising it
yields a placement engine that can express neither an FSB nor a trench line. **The kit is the
generalisation; the assembler stays specific per site type.**

---

## 3 · THE CONVERGENCE — honest

**The franchise raises the kit pivot's value, but not for the reason the analogy gives.** *"A trench
system is the same system with different parts"* is half true.

**Ports:** `DamageSystem.modify_terrain()` (the cut), `ClearingSystem`, the destructible naming contract
(ADR-042 — the `-colonly` / soft-hard prefix grammar), `Hitzone`, the ballistic classifier,
`MaterialBudget`, `InteriorPropFold`, the marker builders, `MarchingCell`, `TerrainConfig.Preset`.

**Does not port:** the bake; `FSB_WORK_OCCUPATION` (§1.5); the vegetation enum (§1.7);
`place_firebase_main()` with its 2,071 runtime collider mutations (`PERF_LEDGER.md:2028-2036`);
`VOManager.ENEMY_DIRS = ["vi_vais1000","vi_25hours","vi_vivos"]` (`vo_manager.gd:16` — the only enemy VO
source); the `"huey"` string key threaded through `air_traffic.gd:15,22,39,56,148`; the tunnel/punji
mechanics baked into the **save schema** (`campaign_state.gd:33-36`, `collapsed_tunnels`).

**The honest claim is narrower and stronger than the intent doc's:** the naming contract, the
destructible grammar and the in-engine placement loop are the only war-agnostic assets this project has,
and today they are exercised *only* through a Vietnam monolith that hides their generality. **The second
war is not a reason to build the kit; it is the test that tells you the kit was built right.**

Correction to `FIREBASE_REWORK_INTENT.md`: *"a WW1 battlefield is cut terrain plus trench modules and
shell holes. Nothing else about it changes."* Vegetation, the work vocabulary, the ambient-war frame,
enemy VO and the faction binary all change. Five things — cheap now, none free later.

---

## 4 · COST OF THE LADDER

| Rung | Cost | Why |
|---|---|---|
| **Solo start** | **CHEAP.** `ensure_roster` refill + `vacancies()` + four `SQUAD_SIZE` sites. Half a day, plus the empty-squad headless probe `measurements.md` §8 correctly says does not exist. | Every consumer already null-checks. |
| **Borrowable NPC RTO** | **CHEAP GATE, NOT FREE.** One `add_to_group` line (§1.4) — but the `fo_fac` split (§1.3) must be fixed or it ships broken. 1–2 days. | Gate, leash, handset grab, menu all read the group. |
| **RTO companion** | **MEDIUM.** An `AllyBase` who is not a `SquadSystem` member (§1.2): needs a non-squad order listener plus persistence outside the roster array. | The cord/RESCUE machinery already handles one leashed ally. |
| **Player handheld** | **MEDIUM, and a canon fight not a code fight.** `RadioHandset.attach_to()` is typed `AllyBase` and needs a `prc25_handset` mesh on a `ModelActor` (`radio_handset.gd:101-113`) — **the player has neither.** It is a viewmodel plus a `_radio_check()` bypass, and ADR-011 says *"no bypass paths."* | The `radio` action (key G) is declared and unread — the bind exists. |
| **Variable squad 1→8** | **CHEAP, half-built by accident** — `setup()` already spawns `mini(SQUAD_SIZE, roster.size())` (`squad_system.gd:71`). | Falls out of §1.1. |
| **The four verbs** | **MEDIUM.** MOVE/HOLD/REGROUP exist; hold-and-defend is not a rename but the mechanism exists (§5). | |
| **Aimed ATTACK** | **RISKIEST, genuinely new.** `_aim_ground_point()` uses collision mask **1** (`squad_system.gd:339`) — world only; it cannot hit a man on layer 3. And **nothing anywhere assigns `AllyBase.target` externally**; `CombatGoals.Context` has no called-target field. New field, new scorer input, new ray, new refusal rule. | It is also the only verb that spends a named man on a keypress, under permadeath. |

---

## 5 · THE AI OBEDIENCE PROBLEM

Not a small fix, and **not two authorities fighting.** It is a bug class this project **already found,
already fixed once, and left standing in three other places.** `ally_base.gd:1372-1377`, at the top of
`_execute`:

> *"RESCUE outranks every combat state: the medic-revive bug was `set_order()` writing a variable
> `_execute_combat` never read, so Doc held cover while the player bled out."*

RESCUE was promoted out of `_execute_idle` into `_execute` as a **state override**. FOLLOW, HOLD and
MOVE_TO were not. The diagnosis is already in the file.

But the state-override form is the wrong thing to generalise, because **the right form is also already
shipped.** `defense_zone` / `defense_zone_radius` (`ally_base.gd:255-256`) is a spatial **constraint that
survives combat**: it kills ADVANCE/FLANK at the scorer (`:1217-1219`), stops aggressive footwork at 0.8
of the radius (`:1571-1572`), pulls a man back past the rim (`:1600-1605`), and drops him out of
ADVANCING outright (`:1709-1711`). It is set today by `garrison_defender.gd:75-76`,
`mg_emplacement.gd:168-169`, `mortar_pit.gd:68`, `ai_stress_arena.gd:1602-1603`. `garrison_defender.gd:8`
states the pattern: *"he holds his post (`defense_zone` + `OrderMode.HOLD`, so the perimeter never
empties)."*

**RECOMMENDATION — orders as CONSTRAINTS, with one state override kept.**
1. `MOVE HERE` sets `MOVE_TO` **and** promotes relocation out of `_execute_idle` the way RESCUE was
   promoted, at a suppression-gated pace.
2. On arrival it sets `defense_zone = order_pos`, `defense_zone_radius = R`. **HOLD AND DEFEND is not new
   behaviour — it is the garrison's behaviour aimed at a player-chosen point.** This is the single
   highest-leverage sentence in this document.
3. `REGROUP` clears the zone and restores FOLLOW.
4. `ATTACK` is a *called target* consumed by `CombatGoals.Context`, **biasing never forcing**
   ENGAGE/SUPPRESS; aimed ATTACK raises the bias and spends an exposure token
   (`SquadCoord.request_exposure`, already built, `:1210-1214`).

**Why not orders-as-goals in the scorer:** `CombatGoals.pick` is shared with the enemy. Player orders in
it puts a player-only concept in the enemy's brain. The scorer already has four post-pick constraint
filters (cord, zone, slot order, exposure token); orders belong in that layer, which is faction-agnostic
by construction.

**What could go wrong.** (a) **A constraint is silent.** A man obeying by *not advancing* looks identical
to a man ignoring you — and per `evidence_pack.md` §2 suppression is already invisible. An invisible
constraint on invisible suppression reads as broken AI. **The ack is the feature, not the polish.**
(b) **Constraints stack and can deadlock** — cord + zone + exposure refusal can freeze a man for three
good reasons. There is one precedence rule today (*"cord outranks zone"*, `:1598`); a third and fourth
entrant needs it written, not inferred. (c) ADR-029 Amendment C §5's gate — *"enabled only once the AI
provably obeys in a playtest"* — is the right gate and should bind this work.

---

## 6 · PERFORMANCE — the brief's premise is wrong

**"Fewer allies = fewer AI ticks" is not where the money is.** `PERF_LEDGER.md:295-300`, at 65+ live
units: think **1.20 ms** of a **37.5 ms** AI physics wall — **~3%**. The wall is the BODY: hitzone sync
9.87 ms, `move_and_slide` 8.78 ms, anim/execute remainder 17.63 ms. `marching_cell.gd:4-8` states the
consequence: *"A hivemind that shares thinking banks nothing; one that shares BODIES banks everything."*

- **Solo helps more than expected** — seven fewer *bodies* (~15% off the AI wall) plus their draw calls,
  in a project `PERF_LEDGER` repeatedly calls **call-bound**.
- **A living world is affordable iff its squads are body-less until seen.** The abstraction exists and is
  proven: `MarchingCell` (`MATERIALIZE_M = 80.0`, `STEP_INTERVAL = 0.25`, `SPAWN_PER_FRAME = 2`).
- **The living world currently uses the wrong one.** `FriendlyPatrolGroup` extends `LazyGroup`, which
  spawns at `activation_range = 120.0` (`lazy_group.gd:9`) and sets `_spawned = true` **one-way — there
  is no despawn path.** A patrol walked past once stays full-cost for the rest of the operation. The
  world monotonically fills and never sheds.
- **Allies have no think LOD at all.** Enemies band 0.15/0.3/0.6 s by distance (`enemy_base.gd:41-56`);
  civilians have `lod_tier` FULL/NEAR/FAR (`civilian.gd:279`, `:1279-1296`); `ally_base.gd:855` ticks a
  flat `THINK_INTERVAL = 0.15` at any range — and the ally think is the expensive one (20-field context,
  `SquadCoord` queries, cover sweeps). **The living world is made of allies.**

**THE PROBE THAT SETTLES IT, and it does not exist.** One headless run on the demo firebase **under the
siege — never on quiet terrain**, per his ruling at `PERF_LEDGER.md:2356-2359` — using the `StallLedger`
attribution already in place: add ambient `FriendlyPatrolGroup`s at 0 / 8 / 24 / 48 men, walk the player
past each so they materialise, record ms/physics-frame and draw calls at each step. **The output is a
men-per-frame budget for the living world.** Without it, "how many other squads" is a guess.

---

## 7 · FOSSILS AND DRIFT FOUND (NO MORE DRIFT)

1. **`WorldSim.current_ao` is written `false` (`world_sim.gd:18`) and set `true` nowhere in the repo.**
   `count_live()` (`:23-28`) returns **0, unconditionally, forever** — and `tests/test_world_alive.gd:334`
   and `:374` print it as a measurement.
2. **`mission_generator.gd:224`** — *"register all spawned enemies so the region grid can LOD them."*
   There is no region grid and no LOD.
3. **This session's own brief is wrong about ADR-025.** It is not DRAFT:
   `ADR-025-lod-tier-simulation.md:3` reads **SUPERSEDED 2026-07-20**, and `:10` reads *"Do not extend
   `WorldSim`, and do not wire `materialize_near`/`dematerialize_far`."* Its blessed successor
   `AIDirector` has **zero implementation files** — the only non-doc hit is a future-tense comment at
   `ally_base.gd:45`. `COMPETING_SYSTEMS_2026-07-19.md:50` blessed WorldSim's *burial*; 51 days on it
   still stands, with a dead flag inside it.
4. **`dynamic_mission_factory.gd:1`** claims to turn *"WorldSim state transitions"* into missions.
   `WorldSim` has no transitions of any kind.
5. **`squad_system.gd:22`** — *"Player-led squad for the village assault."* That mission type was retired
   by ADR-029; `"PATROL"` is the only type the generator emits (`mission_generator.gd:881`).
6. **`field_director.gd:792-794`** describes borrowing a *firebase* radioman's PRC-25 as working. No
   production code puts a garrison man in that group (§1.4).
7. **The `fo_fac` authority split** (§1.3) — two authorities for one concept, the ADR-023 hazard exactly.
8. **`player.gd:470`** — a live `print("[NETDBG] set_on_net(...)")` on the shipping net path.
9. **`project.godot:250-254`** — input action `radio` (key G), zero `is_action_*` references. Confirmed.
10. **The firebase council's own briefing** (`2026-09-09_firebase_kit_pivot/briefing.md:71-75`) gives the
    napalm agent's boundary as `scripts/systems/tree_break_system.gd` and `scripts/systems/damage_system.gd`.
    **There is no `scripts/systems/` directory** — the files are `scripts/world/tree_break_system.gd` and
    `terrain/systems/damage_system.gd`. A live agent brief pointing at paths that do not exist.
11. Restated so they are not lost: `GAME_GUIDE.md:181` *"5-man persistent fireteam"* vs the code's 8;
    `GAME_GUIDE.md:304` *"suppression, morale — RECON has neither"* while `combat_posture.gd` and
    `combat_manager.gd:402-468` are live and probe-covered.

---

## 8 · WHAT IS SACRIFICED (Law 2)

- **A variable squad size costs the compile-time guarantee** that roster, spawner, barracks and debrief
  agree. Four consts that cannot silently disagree become one runtime value that can. Mitigation is a
  probe, not a hope.
- **Orders-as-constraints costs legibility of refusal.** Correct behaviour bought with the player's
  confidence, until an ack layer exists. **Do not ship the verbs without it.**
- **Moving `fo_fac` onto the man on the net costs your own Sparks his uniqueness** — the reason to keep
  him alive. That is a design cost and it is the Summoner's call, not mine.
- **Making the marker vocabulary data costs a compile-time check.** A misspelled `work_` type today falls
  to `off_duty` *deliberately, by name* (`site_planner.gd:1213-1215`); in data it falls through silently.
- **Body-less ambient squads cost fidelity.** A `MarchingCell` cannot be shot at, walked up to, or
  borrowed from. If the living world is where you find a stranger's radio, the cheap representation and
  the mechanic are in direct tension and something must give.
- **The ladder defers Pillar 4 by however long it takes to climb** — an architecture cost as well as a
  design one: every hour of solo play is an hour the squad code is loaded, maintained, and unexercised.
