# DEVIL'S ADVOCATE — review of DRAFT ADR-035 "The Siege"

**Written 2026-07-28.** Every claim below was read out of the code, not the ADR. This is a review of
the DOCUMENT, not of the Summoner's rulings — every ruling (any night, 3 nights, d50, 2d6, cells of
3–6, one axis, objectives, 40–50% break, no respawn when overrun, higher lethality) is LAW and is not
argued here. What is argued is the ADR's **ability to deliver them**.

Findings already in `analysis/devils_advocate.md` and `synthesis.md` are NOT repeated. Where the ADR
absorbed a prior finding correctly, I say nothing. Everything below is NEW.

**VERDICT: SEND BACK.** Not for tone, not for scope, and not for any of the honest gaps it already
names. It goes back because **§4 and §9 — the objectives and the stake, the two sections that carry
the entire decree — are anchored to objects that do not exist in the game and cannot be made to exist
by any GDScript change.** An ADR whose spine is a Blender re-export it never mentions is not an ADR
that can be ratified. Everything else in this document is amendable. That one is not.

---

## 1. §4 IS ANCHORED TO NOTHING. THE FIREBASE IS ONE NODE.

This is the finding. Everything else in this review is smaller.

**The entire firebase is a single instantiated GLB.** `scripts/world/site_planner.gd:904-910`:

```gdscript
var scene: PackedScene = load(FSB_MAIN_PATH)
var root := scene.instantiate() as Node3D
root.set_meta("model_name", "fsb_main")
_parent.add_child(root)
```

The returned site dict is `"nodes": [root]` — **one node** (`site_planner.gd:925`). Every structure
the ADR names as an objective is baked geometry inside `fsb_main_v3.glb`, authored by
`tools/gen_firebase_v3.py` and welded at export time.

*(Correction for the record, POINTER LAW: `site_planner.gd` and `site_layouts.gd` live at
`scripts/world/`, not `scripts/missions/`. `site_layouts.gd` is 128 lines of pure village content —
zero firebase, zero military anything.)*

**Objective by objective, as §4 names them:**

| §4 objective | Does it exist as a placeable, damageable thing? |
|---|---|
| **TOC → "the base is OVERRUN"** | **NO.** Blender geometry family `fb_toc` only (`gen_firebase_v3.py:945`, station plan `:583`). No .tscn, no .glb, **zero GDScript references.** Its only runtime handle is the alias `FOOTPRINT_003` (`gen_firebase_v3.py:692`), consumed at `site_planner.gd:696` as a **radioman spawn post**. Not in `FSB_MARKER_KEYS` under any name resembling "toc". |
| **Depot → fire support docked** | Marker only (`USSupplyDepot_001/007`, `site_planner.gd:678`), used solely to seat two `quartermaster` civilians (`site_planner.gd:694-695`). The "depot breach" is **pure abstract state** — `field_director.gd:1085` zeroes a dict and writes `CampaignState.depot_loss`, triggered by a satchel at the *armorer's bench* (`:796-797, :801`), not at any depot object. |
| **Commo bunker → no net, no radio VO** | **DOES NOT EXIST IN ANY FORM.** The only `commo_bunker` string repo-wide is a stale row in `scripts/world/collision_table.gd:114, :232` — a fossil by ADR-023's own definition. The firebase's entire radio presence is one `radio.tscn` prop dropped *outside the wire* at the spawn point (`site_planner.gd:922, 932-939`). |
| **MG bunkers → that sector of wire opens** | The **only** partial exception. `MGEmplacement` is a real class (`scripts/world/mg_emplacement.gd:12`) really placed at runtime (`mission_generator.gd:757-758, 784-791`). But it has **no `take_damage` and no `AgentRegistry.register`** — it is not on the blast bus. And there is exactly **ONE** in the world: `FSB_GARRISON_POSTS` has a single `gun_crew` entry (`site_planner.gd:693`). §4 says "MG bunkerS" and "that sector"; there is one gun and one sector. |
| **Armory / armorer's bench** | `ArmorersBench` is real (`scripts/levels/armorers_bench.gd:7-8`) and really placed (`mission_generator.gd:668-673`). **No `take_damage`, no registration, not a `Destructible`.** It is the sapper's *aim coordinate* (`field_director.gd:801`), i.e. a location, not a target object. There is no armory *building* anywhere in the project. |
| **(mortar pit, implied by "the mortars are gone")** | Blender geometry only (`gen_firebase_v3.py:941`). Not in `FSB_MARKER_KEYS`, not in `FSB_GARRISON_POSTS`; its `work_mortar` markers are **deliberately excluded** from occupations (`site_planner.gd:715-722`). **There is no mortar tube object in this game.** Player mortars are pure fire-support abstraction (`field_director.gd:255, 586-605`). |

**§4 says: "Objectives register on the existing blast bus — `AgentRegistry.props` / `take_damage` per
ADR-031. No new damage authority."** That sentence is true and completely empty. There is no new
damage authority because **there is no damage RECEIVER**, and there cannot be one until the monolith
is broken up.

**And ADR-031 has never touched the live world.** `Destructible` (`scripts/world/destructible.gd:1-2`)
is instantiated in **exactly four places, all of them benches**: `ai_stress_arena.gd:1248, 1276, 1302`
and `fire_support_bench.gd:76`. The only live-world `AgentRegistry.Kind.PROP` registrations in the
whole codebase are `punji_trap.gd:39` and `fellable_tree.gd:41`. **Not one firebase node has ever
entered `combat_manager.gd:178-185`.** The ADR cites ADR-031 as though registering objectives were a
line of wiring; it is the first live-world use of that ADR, on the hardest possible subject.

**The evidence that somebody already started and stopped:**
`assets/world/building models/structures/firebase/kit/firebase_v3_destructibles.json` — 80 sandbag
segments, `"hp": 140`, `"kind": "sandbag_wall"` — is read by **zero `.gd` and zero `.tscn`.** That is
an UNFINISHED artifact under the ADR-023 triage, sitting in the exact place §4 needs work, and the ADR
does not mention it.

### What §4 actually costs, which the ADR never states

To make the TOC losable you must:
1. Re-author `tools/gen_firebase_v3.py` to emit the objective families as **separate exported
   objects** rather than welding them into `fsb_main_v3.glb`.
2. Re-export the firebase — a **Blender pipeline job**, subject to the "measure the scene, act, then
   verify" rule and to the floater hunt, not a GDScript edit.
3. Teach `site_planner._build_fsb` to instantiate, position and register N objective nodes instead of
   one root (`:904-925`).
4. Give each a `take_damage`, an `AgentRegistry.register`, and a destroyed state with a rubble bed.
5. Wire each destroyed state to its consequence — of which **only one exists today**
   (`CampaignState.depot_loss`), and see §5 below for why even that one is already broken.

**§4 is the least-costed section in the ADR and it is the most expensive.** It is not "the anchors are
already there." Markers are transforms. **A marker cannot be shot.**

### Therefore §9's fatal condition is a spawn marker for a radioman

§9 reads: *"If the TOC falls and the base is overrun, that anchor is gone."* Today the only thing in
the running game that corresponds to "the TOC" is the string `FOOTPRINT_003` (`gen_firebase_v3.py:692`),
which `site_planner.gd:696` uses to decide **where a radioman civilian stands.** The ADR's entire fail
condition — the thing that makes the firebase "a place you can lose" — currently resolves to losing a
civilian spawn point.

---

## 2. §9's STAKE IS CURRENTLY A **DOWNGRADE**, NOT A STAKE

§9 names its gap honestly ("there is no respawn system to take away yet") and asks whether a named gap
is acceptable. Here is why, in this specific case, it is not — and the reason is not the missing
system, it is what already ships in its place.

**Today, player death ends the operation outright.** `health_system.gd:240-256` → `force_death()` →
`GameManager.on_player_death()` (`game_manager.gd:50-52`) → `field_director._on_player_died:141-142` →
`fail_mission("KIA")` → `game_flow.gd:328` → `_on_mission_ended:155-172` → Iron Man wipe on
`reason == "KIA"` (`:169-171`) → `_teardown_world()` → DebriefScreen → hub.

So the shipped consequence of dying is: **the world is torn down and the operation is over.** There is
no respawn to remove because there is no *return* at all.

Which means §9, as written, promises the player a **milder** outcome than the one he already has. "You
cannot come back to a base that has fallen" is only a stake in a game where you otherwise come back.
Until the respawn concept exists, §9 does not raise the stakes — it describes a restriction on a
privilege the player has never had.

**And it takes §10 with it.** §10's central argument is *"lethality is unshippable when a death ends a
campaign, and fine when the firebase is somewhere you come back to."* Today **a death ends the
campaign.** By §10's own test, the higher lethality the ADR is written to unlock is **unshippable
right now**, and stays unshippable until respawn is built. The ADR treats §9 as a named gap in a
side clause and §10 as an independent benefit; they are the same dependency, and §10 sits on the wrong
side of it.

A named gap is acceptable when the rest of the ADR stands without it. Here the gap is load-bearing
for two sections. **§9 and §10 belong in a follow-on ADR that ships with the respawn concept**, and
ADR-035 should ship without a fatal objective at all — every objective a cost, none fatal — rather
than ratify a fail condition it cannot implement and a lethality change its own reasoning forbids.

---

## 3. THE BREAK NUMBER HAS NO SLOT — AND THE ONLY SLOT IT HAS IS A COWARDICE DIAL

§5 states: *"The siege carries a threshold of **0.575** (breaks at 42.5% killed)"*, delivered "by
giving the assault its own `squad_id` and a siege-specific threshold override rather than by moving
`BREAK_RATIO`."

**There is no threshold override.** Read the signature (`scripts/enemies/enemy_squad.gd:109-112`):

```gdscript
static func break_state(live: int, peak: int, avg_courage: float) -> Dictionary:
	var ratio: float = float(live) / float(maxi(1, peak))
	var threshold: float = clampf(BREAK_RATIO + (0.5 - avg_courage) * 0.4, 0.20, 0.65)
	return {"ratio": ratio, "threshold": threshold, "broken": ratio < threshold}
```

Three parameters, none of them a threshold. `squad_id` does not enter this function at all. The
threshold is **computed**, from a `const` and from courage. There are exactly two ways to reach 0.575
and the ADR names neither:

**Route A — courage.** Solve `0.45 + (0.5 - c) * 0.4 = 0.575` → **`courage = 0.1875`.** This works and
requires no code change. It is also a disaster, because **courage is triple-purposed**:
- `enemy_base.gd:279` — `char_self_preservation = lerpf(char_self_preservation, 1.0 - enemy_data.courage, 0.6)`.
  Courage 0.19 → self-preservation ~0.81. These men go to ground instead of closing.
- `enemy_base.gd:2243-2248` — `if pressure > 0.7 + courage * 0.6 + nerve and randf() < 0.25`: the
  INDIVIDUAL rout/Chieu-Hoi ladder. Courage 0.5 breaks a man at pressure > 1.0; courage 0.19 breaks
  him at **> 0.81**.

**The dial that delivers the Summoner's 42.5% formation break also makes every besieger an
individually cowardly man who hugs cover and routs early.** The decree says "death or life"; Route A
ships a company of the most timid soldiers in the game and calls it a siege.

**Route B — a 4th parameter.** Technically fine (a defaulted arg would survive the probes), but it
changes the signature of the function that **`squad_system.gd:293`** (the player's own squad) and
**`friendly_patrol_group.gd:114`** (friendly patrols) both call, and that two suites probe-lock as the
sole break authority by literal string match: `tests/test_squad_break.gd:107` and
`tests/test_friendly_patrols.gd:127`.

Either route has a real cost. **The ADR states the number 0.575 with confidence and names no
mechanism that can produce it.** That is a number without a pointer.

---

## 4. THE MARCHING-CELL BREAK MATH RUNS BACKWARD. THE SIEGE WILL END ON THE TIMER, NEVER ON THE BREAK.

§2 contract 3 is the ADR's guard against a premature break: *"The break counts TOTAL strength,
materialized or not, or killing 8 of the 15 currently real reads as 53% and a 43-man siege breaks on
its first echelon."* Correct worry. **The actual failure is the opposite one, and it is worse.**

`break_state` is pure, but at squad scope its only feeder is `_strength(id)`
(`enemy_squad.gd:115-137`), and `_strength` counts by walking the scene tree:

```gdscript
for n: Node in tree.get_nodes_in_group("enemies"):
	var e := n as EnemyBase
	if e != null and e.squad_id == id and not e.is_dead():
		live += 1
...
var peak: int = maxi(int(s.get("peak", 0)), live)
```

**A dormant marching cell has no node in the `enemies` group.** It contributes 0 to `live` AND 0 to
`peak`. And `peak` **only ratchets up from observed live** (`:129`).

So during the materialization phase — which §2 designs to be staggered "by terrain and pace instead of
in one spike" — `live` is continuously *replenished* by newly-real cells while `peak` climbs behind it.
`ratio = live / peak` hovers near 1.0 and **cannot approach 0.575 while cells are still arriving.**
The assault-scope break is structurally suppressed for exactly as long as the cell system is doing its
job.

Consequence: **the 480 s hard break-off (§1) becomes the actual end condition of nearly every siege,
and the 40–50% kill threshold — the Summoner's Ruling 6 — becomes decoration.** The ADR's own line
*"A siege never runs to dawn undecided"* is delivered by a stopwatch, not by the player.

And satisfying contract 3 requires a **total-strength ledger** — a running tally of intended strength
across dormant and live cells — that `_strength` cannot produce. That ledger is a second piece of
morale accounting. §5's headline claim, *"No second morale system is built,"* survives only on a
technicality: the same `break_state` is called, but with numbers a different bookkeeper produced.

### And the cells re-introduce the O(n²) the file was written to kill

`_strength` is cached at `STRENGTH_TTL_MS = 1000.0` (`:104`) and the comment above it (`:102-103`)
says why: *"never scanned per man per frame (that is the O(n²) the hot-set kills)."*

Each cached recompute is a **full walk of every enemy node in the tree**. The ADR raises the siege's
squad count from 2 groups to **~10–12 cells** (§2: "A d50 of 43 is ~9–10 cells", plus sapper cells).
Each cell is a `squad_id`; each `squad_id` polls `_strength` at 1 Hz; each poll walks the *entire*
enemies group — which §1 permits to reach 150 attackers over three nights, on top of village garrisons
(`randi_range(4,7)` × 4), camp garrisons (`randi_range(6,9)` × 3) and the hunter pool. **Cells convert
a per-squad cost into a per-cell × per-population cost on the one axis the file's author explicitly
protected.**

---

## 5. THE ARITHMETIC HOLES THE ADR NEVER CLOSES

The d50-vs-2d6 contradiction is already on the record and the ADR still does not reconcile it (§1
states both numbers and no clamp). Here is what else does not close.

### 5a. There is no cap on anything, anywhere, and three nights is 150 men

`field_director.gd:12` — `var _live_enemies: Array[EnemyBase] = []`. No reserve, no ceiling.
`spawn_tracked_enemy` (`:31-45`) **caps nothing, budgets nothing and debits nothing** — it seats Y,
spawns, assigns `squad_id`, connects `died`, appends, and calls `state.register_group(...)`. There is
no `if _live_enemies.size() >= N`. The only removal path in the entire codebase is
`_on_enemy_died → _live_enemies.erase(enemy)` (`:65`).

**Repo-wide, `MAX_*` caps exist only for FX and projectiles, never for actors** — `bullet_system.gd:25-28`
(128/48), `gib_system.gd:11` (12), `model_actor.gd:545` `MAX_ACTIVE_RAGDOLLS: int = 8`,
`projectile_pool.gd:6` (64). Bodies have no such ceiling and never have. The ADR's §2 "Honest limit"
paragraph says a ceiling "is still required" and then leaves it unspecified in a document that just
raised the ceiling's required height by a factor of ten.

### 5b. ADR-006: the ledger's OWNER is destroyed mid-siege

The ADR's drift-law list notes the debit asymmetry. It misses the lifetime bug underneath it.
`spawn_tracked_enemy:44` registers every spawned group on `state` — the current `MissionState`. But
`_bank_patrol` **constructs a brand-new `MissionState`** on every inbound wire crossing
(`field_director.gd:1230`). Removing the `patrol_out` gate means sieges now happen while the player is
crossing his own wire (see 5c). **Every cell registered before a crossing scores against a
`MissionState` object that no longer exists after it.** ADR-006's ledger is per-EXCURSION; the siege is
per-NIGHT. The ADR never reconciles the two lifetimes.

### 5c. **The fire-support economy that §10 makes the death cost is farmable during a siege**

This is the sharpest arithmetic hole in the document, and it sits inside the ADR's own answer to
"death must keep a cost."

§10: *"fire support is granted crossing the wire outbound (`field_director.gd:946`) and the patrol
banks only crossing back inward."* True. Now read `_grant_fire_support` (`:957-985`):

```gdscript
fire_support = {
	"bombs": 1, "napalm": 0, "arty": 1,
	"mortar": 3 + (1 if fo >= 6 else 0), "spectre": 0, "cbu": 0,
}
```

**A hard assign. No latch, no per-day cap, no cost, no check on what was spent.** Every outbound
crossing refills the allotment to full.

And the thresholds: `WIRE_GATE_M = 120.0` outbound, `WIRE_RETURN_M = 95.0` inbound (`:772-773`). **A
25-metre hysteresis band.** Meanwhile `FSB_THREAT_M = 90.0` (`:775`) — the ring that defines "enemies
on the wire" — sits *inside* the return threshold. **The siege is fought in the refill band.** A player
holding the perimeter can step out to 121 m and back to 94 m and draw three fresh mortar missions and
an arty mission, all night, three nights running. He does not need to discover this; he will cross that
band by fighting.

**And it erases the depot penalty.** `:975-981` — the `depot_loss` dict is applied to *this* allotment
and then `CampaignState.depot_loss = {}` **and saved.** §4 names "Depot → fire support docked (the
shipped `CampaignState.depot_loss` path)" as one of its four loss classes. That penalty is one
allotment deep and is **consumed and cleared by the first wire crossing.** The first of §4's four loss
classes is wiped by a 25-metre walk, and §10's death cost is refillable by the same walk.

### 5d. The siege's own corpses become a growing per-think quadratic across the three nights

`enemy_base.gd:742` — `static var unreported_corpses: Array[Vector3] = []`. Appended on every
**unwitnessed** kill (`:792`). `_check_corpse_discovery()` (`:796-805`) **iterates the whole array per
unit per think** (called from `:590`). It is cleared in exactly one place: `field_director.gd:22`,
i.e. at world build.

Now apply §1. Three nights × d50, mean 25.5 ≈ **76 attackers per operation**, plus garrison and squad
dead. Fought **at night**, where the sight cap is 56 m open / 18 m jungle — so a large fraction of
those deaths are unwitnessed by construction. The array is never cleared between nights.

By night 3 you have ~100+ living actors each walking a ~100-entry `Vector3` array on every think tick,
in addition to everything else. **The ADR's own three-night structure manufactures a monotonically
growing O(units × corpses) cost that peaks precisely on the night the ADR most needs frame budget.**
No prior analysis costed this, and §2's perf argument — "the body is the cost, not the brain" — does
not cover it, because this one lives in the think.

### 5e. Registration is quadratic over a spawn wave

`scripts/autoload/agent_registry.gd:16-19` — `register()` performs a linear `actor not in roster`
membership test before appending. **O(n) per registration → O(n²) over a wave**, against a roster that
§1 lets grow to 150+. The marching cells stagger this, which helps within one night; nothing helps
across three, because nothing ever unregisters a living man.

### 5f. Two spawn-gate rulings the ADR deletes and never replaces

`_maybe_launch_sappers` (`:1099-1109`) — which the ADR's fossil list DELETES — carries two gates the
ADR never re-rules:
- **`if patrol_count < 1 ... return` (`:1104`)** — "the world must have settled." Today no siege can
  fire before the player's first walk-out. §1 says "any night" and does not say whether this survives.
- **The roll fires on the FIRST TICK of night** (`:1100`, `MissionWeather.is_night`, driven from
  `SimClock.time_period_changed` at `mission_weather.gd:53, :95`). §1 rules WHICH NIGHT and never
  rules WHEN IN THE NIGHT. Combined with the constant-per-operation bearing hash (`:1120-1122`,
  already on the record), the siege arrives **at the same minute from the same compass point three
  nights running.** Night 2 and night 3 are pre-sighted before they start.

---

## 6. STATE MACHINE: FOUR EXITS, NONE OF THEM RULED

§1 removes the `patrol_out` gate and never says what a siege does when the player is not there. All
four exits are open today.

**(a) He walks out mid-siege.** `_poll_wire_gate:925-943` flips `patrol_out` at 120 m and does not
consult any siege state. Nothing in the codebase can stop him, pause the siege, end it, or follow him.
**There is no distance-based despawn or cleanup of spawned enemies anywhere** — `queue_free` appears
in `scripts/enemies/` exactly once, on a model node (`enemy_base.gd:360`), and `LazyGroup` is a one-way
latch (`:67-69`). Walking away is free and permanent. The ADR removes the gate that made "he is home"
matter and adds no rule for "he left."

**(b) He is 3 km away when night 2 falls.** Nothing in `_maybe_launch_sappers` or
`_poll_firebase_threat` tests player distance from `fsb_center`. Under the ADR the siege fires anyway,
50 men assault a base the player cannot reach inside a 600-second night, the garrison is ground down
per §8's "dead men stay dead," and he returns at dawn to a fort he never had the chance to defend.
That is the ADR's *dramatic engine* firing with the player absent, and §1's "it fires whether or not
the player is inside the wire" reads as though only the home case were being unlocked.

**(c) He is dead or downed when the siege starts.** Death is not a state the operation survives (see
§2 of this review): `fail_mission("KIA")` → teardown → debrief → hub. **Nights 2 and 3 do not exist
after a death.** Note also `field_director.gd:128-130, :153-154` — `_ended` stops the *director*, but
`game_flow.gd:175-185` awaits **3 seconds** before teardown, during which the siege AI, physics and
mortars all keep running with no director. Downed is worse: `health_system.gd:237` gives a 30-second
`DOWNED_BLEED_SECONDS` window requiring a squad medic — inside a firebase whose garrison has been
promoted away from him and pinned to 8 m post leashes.

**(d) He saves and quits mid-siege.** The ADR states the defect (`save_data.gd:15-17` serializes zero
live enemies) in its drift-law list and **then does not rule on it.** That is the gap I would press
hardest after §4, because the answer determines the shape of the whole feature:
- If the siege must survive a save → Phase E mission serialization is a project of its own and belongs
  in the dependency chain (§7 below).
- If it must not → the ADR must say so and pick a rule (siege blocks saving; or a save during a siege
  resolves it as a loss; or quicksave is disabled at night).
- If nothing is ruled → **F5 is the dominant strategy for surviving three nights**, and the decree's
  stakes evaporate on a keypress.

Related and also unruled: `SimClock.sim_day` **exists** (`sim_clock.gd:16`) but is in neither save
store (`campaign_state.gd:212-226, :281-294`) — and `mission_generator.gd:236` calls `set_time` without
resetting it, so the day counter **carries across operations in-process** and resets to 1 only on a
process restart. A "night 3 already spent" latch hung on `sim_day` would leak from a dead operation
into a fresh one.

---

## 7. "REUSES THE SHIPPED `LazyGroup` PATTERN" IS A ONE-LINE REUSE DRESSED AS AN ARCHITECTURE

§2 is the ADR's answer to perf, and it rests on this sentence: *"This reuses the shipped `LazyGroup`
pattern (`lazy_group.gd:88`)."* The pointer is accurate. **Line 88 is literally the only line that is
reused** — `var enemy := director.spawn_tracked_enemy(pos, data, group_tag)`.

Read the class (`scripts/missions/lazy_group.gd`, 108 lines). A marching cell needs six things.
LazyGroup does **none** of them:

1. **It never moves.** `_physics_process:49-61` polls player distance from a fixed `global_position`
   and nothing else. A *marching* cell must walk the sector axis. That is the defining verb and it is
   absent.
2. **It has no strength ledger.** `force_spawn()` sets `_spawned = true` and
   `set_physics_process(false)` (`:67-69`). After firing, the node is inert — it does not track its
   men, cannot report live/peak, and cannot feed contract 3.
3. **It emits no `NoiseBus` noise.** §2 contract 4 ("dormant cells emit noise") is new code.
4. **It has no illumination hook.** §2 contract 2 is new code.
5. **Its roster is HETEROGENEOUS BY CONSTRUCTION.** `data_paths` (`:14-27`) is a nine-entry weighted
   pool sampled uniformly *per man* (`:87`). The Summoner's ruling — and §2's own text — is **"3–6 men
   of ONE type."** LazyGroup is structurally the opposite of a homogeneous cell.
6. **It attaches a camp brain.** `_spawn_men:105-107` calls `CampDirector.attach(get_parent(), ...)`
   for every group whose tag is not `ambient_patrol` — a camp-life schedule and work stations. A siege
   cell reusing this class stands its assault element up with an occupation roster.

And one more: `force_spawn` materializes the whole cell **in a single frame** with `think_timer = 0.0`
on every man — the aligned think-spike that `production/research/engine_mining_2026-07-18/recon_survey.md:23`
already flagged for this exact class.

**The marching cell is a NEW class that borrows one function call.** Costing it as a reuse is the
ADR's largest estimation error, and the shape of the error is the one the POINTER LAW exists to catch:
a citation that is technically true and rhetorically false.

---

## 8. §2 AND §7 SPECIFY THE SAME SYMBOL INCOMPATIBLY — AND MAKE THE STRATEGIC VERB A FRAME BOMB

`IllumFlare.is_lit` (`illum_flare.gd:14-18`) is **static** and tests against the **class constant**
`LIGHT_RADIUS = 30.0` (`:9`), not a per-instance radius:

```gdscript
static func is_lit(pos: Vector3) -> bool:
	for f in active_flares:
		if is_instance_valid(f) and Vector2(...).length() < LIGHT_RADIUS:
```

- **§2 contract 2** names `IllumFlare.is_lit(pos)` as *the hook* for materializing dormant cells.
- **§7** mandates that the mortar round get "its own [constants] — higher, wider, longer."

**These cannot both hold.** A mortar flare with a 120 m radius would still only materialize cells
within **30 m** of it, because the hook reads the const. `is_lit` must become per-instance, and no
section of the ADR says so. Two sections of one document specify the same symbol two different ways —
and this one bites at ratification time, not at review time, because it looks like two independent
paragraphs.

**And the coupling neither section admits.** §7 sells mortar illum as *"the siege's strategic verb —
deciding when to spend light."* §2 makes being lit a **materialization trigger**. Therefore: firing an
illum round 400 m down the axis **instantiates every dormant cell it lights** — bodies that would
otherwise have stayed integers. **The player's strategic verb is a button that spawns bodies.** §7
argues for a wider, longer-burning mortar flare; every metre of that radius is more men made real at
once, at night, in the densest mesh site in the game. The ADR's headline perf mitigation and its
headline tactical verb are the same lever pulled in opposite directions, and Consequence 1 ("frame
budget") does not mention it.

*(For the record, since it reads as a defect and is not one: a flare CAN be the marginal trigger,
because it can be fired 300–500 m out while the 80 m materialize radius is measured from the player.
The incompatibility is the const, not the geometry.)*

---

## 9. §8's STAND-DOWN SILENTLY BREAKS ADR-010 IDENTITY — AND IT IS THE ONE THING §8 IS FOR

§8 is right and the Arbiter was right to rule it in-scope. But it is specified as a one-line revert
("surviving defenders revert to Civilians at their posts") and the promotion it must invert is not
symmetric.

`GarrisonDefender.promote` derives the man's **name and MOS** from
`SquadRoster.generate_member(_seeded_rng(stand), ...)` (`garrison_defender.gd:56`), where
`stand = civ.global_position` (`:37`) — **the spot he happened to be standing on when the alarm went.**
The comment at `:55` says *"Deterministic per post (ADR-010: same seed, same men)."* That holds for
**one** stand-to.

On night 2 the same civilian is somewhere else on his work schedule when the siege opens. He is
re-seeded from a different position and stands up as a **different named man.** Across three nights,
the garrison the player fought beside on night 1 is a roster of strangers on night 2 and different
strangers on night 3.

**That destroys the exact thing §8 exists to protect.** §8's argument is that "dead men stay dead and
are not replaced" is "the dramatic engine the three-night structure needs." A dramatic engine built on
attrition requires **persistent identity** — the player has to notice that the man on the north gun is
not the man who was there last night. And the nameplate is the blue-on-blue affordance
(`garrison_defender.gd:53-54`), so this is a safety regression as well as a narrative one.

Fix is cheap — seed on `post`, not `stand`, and persist the generated `member` dict across the
stand-down/stand-to cycle — but the ADR must say it, because "revert to Civilians at their posts"
sounds complete and is not.

*(One thing I checked and it is FINE, so nobody wastes a day on it: the MG emplacement self-heals.
`mg_emplacement.gd:80-90` and `:93-96` clear a freed or dead occupant, so a stood-down gunner releases
the gun and night 2's crew can man it.)*

---

## 10. IS THIS ONE ADR? NO. COUNT THE CHAIN.

§"The gate (binding)" names one blocker: THE REAP. The "Live defects this ADR must fix on contact"
list adds four more. Every one of those is now **on the critical path**, because none of them can be
deferred without the siege shipping broken. Count what must land before a single siege can run
end-to-end:

| # | System | Exists today? | Named as a blocker? |
|---|---|---|---|
| 1 | **THE REAP** — withdrawal + despawn + map clamp + sapper hand-back | No, in any form | **Yes** (the one gate) |
| 2 | **Firebase objective destructibility** — GLB split, re-export, N nodes, registration, consequences | **No — and it needs a Blender pipeline job** | **No.** §4 asserts the anchors exist |
| 3 | **Marching cell class** — movement, homogeneity, strength ledger, noise, illum trigger | No (§7 above) | **No.** Costed as a LazyGroup reuse |
| 4 | **Total-strength break ledger** — contract 3 (§4 above) | No; `_strength` cannot produce it | **No.** Claimed as "already written" |
| 5 | **Enemy indirect fire** — `from` bearing, own impact terminal, own-troop exclusion | No | Partly (§6 names the fixes) |
| 6 | **Garrison stand-down** + identity persistence (§9 above) | No | Yes (§8), identity not |
| 7 | **Mortar illum** — `fire_support` entry, grant, input key, per-instance flare radius | No | Yes (§7), radius coupling not |
| 8 | **Save serialization** of live enemies + `sim_day` | No | Named, **not ruled** (§6 above) |
| 9 | **Respawn concept** — for §9's stake and §10's lethality | No | Named as a gap; its blast radius is not |
| 10 | **A live-enemy ceiling** — §2's "honest limit" | No; no actor cap exists anywhere | Named, unspecified |
| 11 | **Fixing `_update_line_of_sight`** — and §4 must land first or the assault stalls at 300 m | Live bug | Yes, with a stated ordering constraint |
| 12 | **Un-banking the `firebase_attack` patrol location** | Live bug | Yes |
| 13 | **`_bank_patrol` / ADR-006 debit asymmetry** + the MissionState lifetime (5b) | Live bug | Partly |

**Thirteen items, of which nine do not exist in any form, and two (2 and 9) are projects in their own
right.** The ADR's Consequence 3 lists nine of these in a single sentence beginning "Scope. Multi-session"
and then moves on.

**This is not one ADR. It is a decree plus a programme.** And the risk is not that it is big — the
Summoner ruled it and it is worth building. The risk is the shape: **a single ADR with a thirteen-link
chain and one binding gate will be built out of order**, because twelve of the thirteen read as
follow-ups. The one thing that would actually protect it is the thing ADR-015 exists to do: **split
it.** ADR-035 should be the siege *state machine* — cadence, cells, axis, break, reap, stand-down.
Objectives (§4/§9) and lethality (§10) should each be their own ADR with their own gate, because each
is blocked on work that is not GDScript.

---

## 11. WHAT IS SACRIFICED, THAT THE CONSEQUENCES SECTION DOES NOT ADMIT

The Consequences section names four things: frame budget, the passive-player win, scope, and the
living firebase. All four are real and all four are already on the record. Here is what it does not
say.

### 11.1 THE BIGGEST ONE: §4 RE-FRAGMENTS THE PROTECTED WORLD FOUNDATION, AND IT IS A DRAW-CALL REGRESSION AT THE WORST SITE IN THE GAME

The unified game world is the **protected foundation** — the standing ruling is *improve it, never
rebuild or re-fragment it.* The firebase is the purest expression of that: **one export, one node**
(`site_planner.gd:904-910, :925`).

§4 requires shattering it. To make the TOC, the depot, the commo bunker and the MG bunkers into
losable installations, `fsb_main_v3.glb` must stop being one welded mesh and become ~20 separately
instantiated, separately collidable, separately registered nodes.

**And that is a DRAW CALL increase, at the one site where the frame is already worst.** The measured
ruling on this project is explicit: **cutting 33% of primitives moved FPS ~0; the levers are draw
calls and fill, never triangle count.** The firebase is already the densest mesh site in the game
(678 meshes / 1,116 bodies). §4 proposes to raise its node and draw-call count — and then §1 proposes
to put fifty men inside it at night with mortars falling.

**Consequence 1 says "frame budget" and reasons entirely about AI bodies.** The rendering cost of §4
is not mentioned anywhere in the ADR, and it is the half that cannot be fixed by a marching cell,
because the geometry is there whether anyone is fighting or not — including on the other 21 real
minutes of every sim day, on every operation, forever, whether a siege ever fires or not. **§4 taxes
every hour of the game to pay for eight minutes of it.**

That is the sacrifice I would put in front of the Summoner first, because it is permanent, it is
invisible until it ships, and it lands on Rule #1: the world must be FUN to walk.

### 11.2 The rest, briefly

- **ADR-031's live-world debut is a 20-object firebase.** Destruction has never shipped outside a
  bench (`ai_stress_arena.gd:1248/1276/1302`, `fire_support_bench.gd:76`). The ADR spends its
  reputation as if it were proven in the world. It is proven in a sterile arena — and there is a
  standing ruling that arena tuning must be re-confirmed in the real build.
- **The Summoner's top deferred feature is the mannable MG emplacement.** §4 makes the MG bunkers
  objectives, `garrison_defender.gd:63-71` gives them AI crews, and there is exactly **one** gun
  (`site_planner.gd:693`). This ADR touches, complicates and pre-commits the design of the feature
  the Summoner said he wanted next, without saying so.
- **The FP viewmodel pipeline is the ruled top priority (2026-07-25) and PLAYTEST R4 is the standing
  session entry gate, still undischarged.** Consequence 3 says "Other work parks." It does not name
  which work, and both of those are standing rulings, not backlog.
- **The three-night run is a ~72-minute forced-attendance window in a no-rails game** — already on the
  record — and this draft makes it *worse* rather than better, because §1 lets the siege fire whether
  the player is there or not while §6 offers him no way to be elsewhere and no way to save through it.

---

## 12. THE SHORT LIST — NEW DEFECTS, DAY ONE OF IMPLEMENTATION

| # | Defect | Pointer |
|---|---|---|
| 1 | The whole firebase is ONE node; no objective is damageable | `site_planner.gd:904-910, :925` |
| 2 | TOC exists only as Blender geometry; runtime handle is a radioman post marker | `gen_firebase_v3.py:945, :692`; `site_planner.gd:696` |
| 3 | Commo bunker does not exist; only string is a fossil collision row | `collision_table.gd:114, :232` |
| 4 | `Destructible` is instantiated only in bench scenes — ADR-031 has never run in the world | `ai_stress_arena.gd:1248/1276/1302`; `fire_support_bench.gd:76` |
| 5 | 80 sandbag destructibles authored, read by zero code (UNFINISHED) | `firebase_v3_destructibles.json` |
| 6 | Exactly ONE MG emplacement exists; §4 says "MG bunkers" | `site_planner.gd:693` |
| 7 | `break_state` has no threshold parameter; 0.575 has no mechanism | `enemy_squad.gd:109-112` |
| 8 | The only in-signature route to 0.575 is courage 0.19 — which makes every besieger individually cowardly | `enemy_base.gd:279, :2243-2248` |
| 9 | `_strength` ratchets `peak` from observed live only — contract 3 unimplementable; siege ends on the 480 s timer, not the break | `enemy_squad.gd:115-137, :129` |
| 10 | Cells multiply `squad_id` count ×5, and `_strength` is O(squads × all enemies) | `enemy_squad.gd:102-104, :124` |
| 11 | `_grant_fire_support` is an unlatched hard assign; 25 m hysteresis band; §10's death cost is farmable | `field_director.gd:957-963, :772-773` |
| 12 | `depot_loss` is consumed and cleared on the first wire crossing — §4's depot penalty is one walk deep | `field_director.gd:975-981` |
| 13 | `unreported_corpses` is never cleared during an operation; iterated per unit per think | `enemy_base.gd:742, :792, :796-805, :590` |
| 14 | `AgentRegistry.register` is O(n) per call — quadratic over a wave | `agent_registry.gd:16-19` |
| 15 | `_bank_patrol` builds a NEW `MissionState`; siege groups outlive their ledger owner | `field_director.gd:1230`, `:44` |
| 16 | `is_lit` reads a class const — §7's wider flare cannot drive §2's materialization | `illum_flare.gd:9, :14-18` |
| 17 | Materialize-on-illumination makes the player's strategic verb a body-spawn button | §7 vs §2 contract 2 |
| 18 | LazyGroup never moves, has no strength, no noise, no illum hook, a heterogeneous roster, and attaches a CampDirector | `lazy_group.gd:49-61, :67-69, :14-27, :105-107` |
| 19 | Stand-down re-seeds names/MOS from stand position — the garrison is strangers every night | `garrison_defender.gd:37, :55-56` |
| 20 | `patrol_count < 1` gate deleted with `_maybe_launch_sappers`, never re-ruled | `field_director.gd:1104` |
| 21 | The roll fires at the first tick of night — same minute, same bearing, three nights | `field_director.gd:1100, :1120-1122` |
| 22 | Player death tears the world down — nights 2 and 3 cannot exist after a death; §10's own test forbids the lethality change today | `field_director.gd:141-142`; `game_flow.gd:169-185` |
| 23 | `sim_day` exists, is unsaved, and carries across operations in-process | `sim_clock.gd:16`; `mission_generator.gd:236`; `campaign_state.gd:212-226` |
| 24 | No actor cap exists anywhere in the project; `MAX_*` guards FX only | `field_director.gd:12, :31-45`; `gib_system.gd:11`; `model_actor.gd:545` |
| 25 | Walking away mid-siege is free, permanent, and uncleaned — no distance despawn exists | `enemy_base.gd:360`; `lazy_group.gd:67-69` |

---

## VERDICT: SEND BACK

Not for a rewrite of the intent — the decree is sound and the ADR reasons well about most of it. Send
it back for **three specific structural repairs**:

1. **§4 must be severed into its own ADR** and must open with the truth: the firebase is one welded
   GLB, every named objective is baked geometry, ADR-031 has never touched the live world, and making
   objectives real is a Blender re-export followed by a node-count and draw-call increase at the
   densest site in the game. Until that ADR exists, ADR-035 ships with **no fatal objective** — every
   loss a cost, none of them the base.
2. **§9 and §10 must move behind the respawn concept.** §9 as written promises a milder consequence
   than the one that already ships, and §10's own test ("lethality is unshippable when a death ends a
   campaign") forbids the lethality change until respawn exists. Both are correct designs on the wrong
   side of a dependency.
3. **§5 must name a real mechanism for 0.575 and a real ledger for contract 3**, and admit that the
   ledger is new bookkeeping — or accept that the siege will end on the 480-second timer and tell the
   Summoner that his 40–50% ruling is being delivered by a stopwatch.

Everything else in this review is an amendment. Those three are the difference between an ADR and a
wish.
