# SYSTEMS DESIGNER — 2026-09-09 firebase kit pivot

Every number below is either a `file:line` or a value I measured myself this session.
Where I could not measure, the line says UNVERIFIED.

---

## ASSIGNMENT 1 — the Huey dropoff

### 1.1 The standing trap is STALE. Correct it on contact.

Claude memory `recon-staged-scenes-are-not-clip-banks` (modified 2026-07-30) says
*"there was never a boarding animation to harvest — which is why `HeliLift.BOARD_CLIPS` is empty."*

**That has not been true since 2026-08-04.**

- `scripts/vehicles/heli_lift.gd:51` — `const BOARD_CLIPS: Array[String] = ["board_heli"]`
- `scripts/vehicles/heli_lift.gd:38-41` — `DISEMBARK_CLIPS` = six real names,
  `disembark_heli`, `_b`, `_c`, `_d`, `_e`, `_f`
- `production/ART_Track_Log.md:404-407` records the ship: `anim_library.glb` re-exported to
  183 clips, `board_heli` verified present, and `BOARD_CLIPS` wired *"(was `[]`)"*.

So the diorama story is **not** the answer to his question. The clips exist, on `PSXRig`, with real
bone channels, gated (elbow max 0.056–0.099 on the six; 0.0191 on `board_heli`).
The memory needs the correction written back.

### 1.2 What actually plays on dropoff today, in order

`heli_lift.gd:277 _on_landed` → `_deliver()` (`:297`):

1. `:301-302` — `var door := seats.door_staging_pos()` then `seats.unseat_all(door)`.
2. `seat_system.gd:613 unseat_all` loops `PASSENGER_SEATS` and calls `unseat()` on **every man in
   one `for` loop, in one frame.** There is no timer, no stagger, no queue.
3. `seat_system.gd:568 unseat` → `:598 body.global_position = exit_pos` — a **teleport** — then
   `:607 out_model.play_first(EXIT_CLIPS)` where `EXIT_CLIPS = ["idle","idle_unarmed"]`
   (`seat_system.gd:144`).
4. Back in `_deliver`, `heli_lift.gd:339-347` overwrites that with the drop-height branch.

**The exit fan is arithmetic, not motion** (`seat_system.gd:628-636`): arc 140°, radius
`min(2.5 + 0.9*i, 7.0)`. For a 6-man stick that is six fixed polar coordinates —
2.5 / 3.4 / 4.3 / 5.2 / 6.1 / 7.0 m at −70° / −42° / −14° / +14° / +42° / +70°.
Deterministic, identical every sortie.

### 1.3 THE MEASURED DELTA: the clips he reviewed carry travel; the shipped clips carry none

`tools/export_anim_library.py:59-63` removes, from **every action in the library**:

    if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 2):
        bag.fcurves.remove(fc)

X and Z root motion, stripped at export, library-wide. `production/ART_Track_Log.md:374-381`
measured both sides: in the source `.blend` the `disembark_heli` family travels **2.37 m (one clip)
and ~0.3 m (five)**; in the shipped `.glb`, **all six travel exactly 0.0 m.**

**That is the answer to his sentence.** In Blender he watched men *travel out of the aircraft*.
In the game the engine teleports them to a fan and plays the same clip **in place**. The clip is not
worse. The *travel he was looking at* is deliberately deleted at export and replaced by a snap.

### 1.4 Second measured defect — the drop-height branch, and how close it runs to killing the clips

`heli_lift.gd:339-347` picks the clip from `drop = door.y - man.global_position.y`:
`>= 1.6` → `hard_landing`; `>= 0.8` → `jump_down`; else the six disembark clips.

Measured, not reasoned:

- `assets/us/vehicles/huey_v3.glb` node 88 `seat_gunner_l` → local **y = 1.010 m**
  (I parsed the GLB JSON chunk directly this session). `_egress()` (`seat_system.gd:747-750`)
  builds the door point from that socket and pushes it out along `basis.z`, which is horizontal —
  **Y is preserved.**
- `helicopter.gd:266` — `_land_y = _lz.global_position.y + 0.5`. The airframe parks **0.5 m above
  the pad.**
- So `door.y` = pad + **1.510 m**.
- `seat_system.gd:842-853 _exit_ground` raycasts down and returns `hit.y + 1.0` — the man is placed
  **one metre above the ground he was just put on.**

`drop = 1.510 − 1.000 = 0.510 m` → under `HOVER_DROP_M` 0.8 → the disembark clips DO play.

**But the margin is 0.29 m, and it is held open entirely by an undocumented `+1.0` in
`_exit_ground`.** Delete or retune that `+1.0` — exactly the kind of magic constant someone
"cleans up" — and `drop` jumps to 1.510, every delivered man plays `jump_down`, and the six
authored disembark clips become unreachable dead assets **with no error**. Flagging it as a latent
trap, not a live bug.

The `+1.0` has a live cost of its own: every man is spawned **1 m in the air** and falls. Six men
popping in at head height and dropping is precisely the "not as perfect as Blender" read.

### 1.5 Mechanical quality of the dropoff, point by point (his checklist)

| Question | Answer | Evidence |
|---|---|---|
| In sequence or all at once? | **ALL AT ONCE, one frame.** | `seat_system.gd:613-636` — one loop, no timer |
| Per-man delay? | **None.** Boarding *has* one (`BOARD_STAGGER_S` in `board_squad`); disembark does not. | asymmetry: `seat_system.gd:639-641` vs `:611-613` |
| Clear the rotor disc? | **Not checked at all.** The fan is a 140° arc capped at 7.0 m. Huey main rotor is 14.63 m diameter = **7.32 m radius** (pinned real numbers, `recon-huey-complete`). The outermost man lands at 7.0 m — **inside the disc.** | `seat_system.gd:635` |
| Claim a destination? | **YES — and this one works.** `heli_lift.gd:326-331` walks the hashed bunk angle by the golden step until `not LandingZone.on_pad(bunk)` **and** `_point_unclaimed(bunk)` (`:368-378`, 2.0 m radius against the live `firebase_garrison` group), then `_bunk_on_nav()`. This is the `5ed4b181` exclusivity check and it is **intact, not regressed**. | |
| Interpenetrate on landing? | Marginal. The two innermost men are ~1.2 m apart (r = 2.5, 28° separation). No obstacle test — the fan is placed blind into whatever is there: sandbags, the pad edge, a man already standing. | `seat_system.gd:628-636` |
| Do they walk away? | No. They are teleported to the fan; `civilian_schedules` then walks them to the bunk from there. **Nobody steps off a skid.** | |

### 1.6 VERDICT + CLASSIFICATION

**Not (b).** The staged-scene story does not explain what he saw, and repeating it to him would be
citing a memory the code refuted five weeks ago.

**(a) — BUG, KNOWN CAUSE. Two of them, both mechanical, both cheap:**

1. **No egress sequencing.** Six men appear simultaneously. The Blender staging had them leave in a
   stick. `unseat_all` needs the stagger `board_squad` already has.
2. **Egress is a teleport into a fixed polar fan, and the clip that would sell it has had its travel
   stripped at export.** The men do not move out of the ship; the ship's contents are relocated and
   then animated in place.

Plus **one latent (c)**: no true *disembark-with-travel* clip can ever exist while
`export_anim_library.py` strips Hips X/Z from every action. Authoring one on `PSXRig` per the
`recon-animation-pipeline` skill is **not the fix by itself** — the exporter would delete its travel
on the way out. The real fix is either an exporter exemption list for egress clips, or (cheaper, and
more in keeping with how the rest of the game drives motion) **drive the walk-out with a `MOVE_TO`
order plus a stagger, and keep the clip in place.**

**Costed, cheapest first:**

- **A. Stagger `unseat_all`** — one man per ~0.45 s instead of all at once. ~15 lines in
  `seat_system.gd`, mirroring `board_squad`'s existing stagger. **~1 h.** Biggest
  look-per-hour in this entire report.
- **B. Re-derive the `+1.0` in `_exit_ground`** from the real capsule offset, and re-check the
  `drop` branch so the disembark clips stay selected. **~30 min + a probe.**
  UNVERIFIED: I did not measure the `Civilian` collision-shape origin, so I cannot say whether
  `+1.0` is a bug or a correct capsule offset. **Measure it before touching it.**
- **C. Raise the fan cap past the rotor disc** — `radius_cap` 7.0 → 9.0 and widen the arc, so the
  last men off land outside 7.32 m. **~10 min.**
- **D. Give the walk-out a real destination** — issue a short `MOVE_TO` 8–10 m outboard on unseat
  instead of teleporting to the fan. This is the fix that actually reproduces the Blender read.
  **~4 h**, and it needs the `Civilian` move-verb that `ART_Track_Log.md:397-401` already logs as
  missing (`board_squad` casts `as AllyBase`; `Civilian` is not one, so the order never issues).
- **E. Author a travelling disembark clip.** **~8 h + the exporter exemption.** Do NOT start here.
  A / C / D buy most of the look for a fifth of the price.

---

## ASSIGNMENT 2 — the driving convoys

### 2.1 What exists

- `scripts/vehicles/convoy.gd` (140 lines) — the column driver.
- `scripts/missions/convoy_spawner.gd` (166 lines) — SimClock-driven producer.
- `scripts/vehicles/destructible_vehicle.gd` (**33 lines**) — the vehicle body.
- `scripts/world/road_network.gd` (458 lines) — routes, and `longest_route()` (`:348`) exists
  *explicitly* to feed convoys.

### 2.2 What it does today — measured

**Spawning.** `mission_generator.gd:338 _schedule_one_convoy` schedules **exactly one convoy per
operation**, at `sim_hour + 2.0` (`:355-360`). Nothing ever reschedules.
`_on_route_finished` (`convoy_spawner.gd:143`) `queue_free()`s it at the end of the road.

**How long that convoy is alive, for the demo:**

- `plan_demo_world` puts **one** village in `village_centers` (`mission_generator.gd:748-749`), so
  `RoadNetwork.build` produces **one** segment: gate → village.
- The village is placed ~185 m from `fsb_center` (`:744`); the road is the A* path from the gate to
  it, so of order 150–200 m.
- `Convoy.speed = 12.0` m/s for trucks (`convoy_spawner.gd:93`).
- **≈ 13–17 seconds of convoy, once, in a 30-minute demo.** Then it deletes itself.

`demo_game.gd:49 DAY_RATIO = 38.0`, `:44 START_HOUR = 6.5`; `_wire_systems` sets the clock to 6.0
for DAWN (`mission_generator.gd:250-254`) and schedules for 8.0, so it fires ~2.4 real minutes in.

**Pathing.** On the road polyline only — `RoadNetwork` A* over `GameplayGrid`, seated to terrain Y
(`road_network.gd:306-309`). Not navmesh, not spline, not raw terrain sampling. That part is sound.

**Physics.** `DestructibleVehicle extends StaticBody3D` with `collision_layer = 1`,
**`collision_mask = 0`** (`destructible_vehicle.gd:4,12-13`). `Convoy._physics_process` moves it by
**direct `global_position` assignment** (`convoy.gd:81-99`). No body motion, no sweep, no
`move_and_collide`. **A convoy truck cannot collide with anything; it is a moving wall that other
things collide with.**

**Terrain conform.** Y only (`convoy.gd:84,98` → `_ground_y`). Rotation is **yaw only**
(`convoy.gd:112 — v.rotation.y = ...`). Pitch and roll are never written. No suspension.

**Passengers.** Zero. Grep of `convoy.gd` + `convoy_spawner.gd` for `seat|passenger|Civilian|AllyBase`
returns only the word "seat" used to mean *place on the ground*. **A convoy carries nobody.**

**Destructible?** `destructible_vehicle.gd` is 33 lines and is **only a constructor**. No `health`,
no `take_damage`, no death, no wreck. Its only caller is `convoy_spawner.gd:118`.
**The class named `DestructibleVehicle` is not destructible.**

**Ambush wiring.** This half is real and complete: `convoy_spawner.gd:153-166` tests each waypoint
against `ambush_sites` within 45 m, calls `Convoy.report_contact` (`convoy.gd:116`), which emits
`ambushed` into `DynamicMissionFactory` (`mission_generator.gd:286-289`).

### 2.3 Failure modes a player sees, ranked worst-first

1. **It is over before you notice it.** One convoy per operation, alive 13–17 s in the demo, on one
   150–200 m road, spawning 2.4 minutes in — while the squad is moving out. He almost certainly saw
   the *only* convoy the world will ever produce.
   `mission_generator.gd:338-360`, `convoy_spawner.gd:143-145`.
2. **The trail cuts every corner.** Trailing vehicles are not path-followers. `convoy.gd:88-102`
   pulls each one along the straight line toward the vehicle in front whenever it falls further than
   `spacing`. On the A*'s bends the tail leaves the 5 m road corridor and drives across whatever is
   inside the turn. A column that will not stay on its own road is the single most obvious
   "the convoy is broken" read.
3. **Deuce-and-a-halves overlap nose to tail.** `Convoy.spacing = 6.0` m centre-to-centre
   (`convoy.gd:27`), while `m35_deuce_truck_v2`'s box is **7.10 m long**
   (`collision_table.gd:151`). Two consecutive deuces interpenetrate by **1.10 m**. Composition is
   75 % deuces (`mission_generator.gd:370-376`), so this happens on most convoys.
4. **Flat trucks on sloped ground.** Yaw only; no pitch/roll. Every vehicle stays level while the
   terrain tilts under it — nose buried on an uphill, tail floating over a crest.
5. **It drives through the world.** `collision_mask = 0` plus direct position writes: through trees,
   through vegetation, through men — and, because `BUILDING_COST` is finite at 4000
   (`road_network.gd:60`), potentially through a hut the router priced as cheaper than a detour.
6. **It drives through the player, or traps him.** A `StaticBody3D` teleported into a
   `CharacterBody3D` produces penetration and ejection, not a push. Same collision-trap family as his
   ladder-and-sandbags report.
7. **Dead silent, wheels frozen, no dust.** No `AudioStreamPlayer3D`, no wheel rotation, no dust —
   confirmed by absence across all three convoy files.
8. **AI ignores it.** `convoy_spawner.gd:124` removes each vehicle from `nav_blockers` (correctly —
   the navmesh baked long before the convoy existed). Consequence: NPCs path straight through the
   column.

### 2.4 ROADS AND CONVOYS ARE ONE JOB. Evidence.

They are not two pieces of work, and pricing them separately overcharges him.

- `RoadNetwork.longest_route()` exists **for no other consumer.** Its own docstring
  (`road_network.gd:346-347`): *"The longest road in the network, as a convoy route."*
- `_schedule_one_convoy` refuses to exist without one: `mission_generator.gd:351` —
  `return  # no road, no convoy - a truck does not drive through jungle`.
- The road already writes its own dirt: `road_network.gd:378-405 _stamp_dust` →
  `ClearingSystem.stamp_ground_line` (`terrain/systems/clearing_system.gd:246`) paints
  `Color(0.42, 0.35, 0.24)` at strength 0.72 across `ROAD_HALF_WIDTH_M = 5.0`, onto a 512-texel
  overlay over a 512 m map = **1 m per texel, a ~10 m band with 3.5 texels of feather each side.**

So the dirt road he says he has never seen **is stamped along exactly the polyline the convoy
drives**, and it is one 150–200 m segment. Painting a better road and fixing the convoy are the same
150–200 m of ground, the same data structure, and the same test. **Do them in one pass, or the road
work has no traffic and the convoy work has no road.**

(The visual half is the level designer's call. My input to him: the road is **not** invisible because
of resolution — it is a flat colour lerp with no rut, no normal, no wheel track, feathered to nothing
at the edges, on one short segment. UNVERIFIED whether the demo's `map_size` is 512; if it is larger,
the texel-per-metre figure degrades proportionally.)

### 2.5 CLASSIFICATION + costed fix list, cheapest first

**Mixed: (a) bug, known cause, for items 2–6; (c) content never built for the road *surface* and for
convoy presence/frequency.** Nothing here is (b) — I did not find a single unexplained behaviour.

- **A. Bump `Convoy.spacing` 6.0 → 9.0** so deuces stop overlapping. **One number.** ~5 min.
- **B. Make the trail follow the ROUTE, not the vehicle in front.** Give each vehicle its own arc
  offset down the polyline — `ConvoySpawner._seat_along_route` (`convoy_spawner.gd:27`) already
  computes exactly this at spawn; reuse it every tick instead of the chain-pull. ~40 lines in
  `convoy.gd`. **~2 h.** This is the fix that stops the column leaving the road.
- **C. Pitch/roll conform.** Sample terrain height fore and aft of each vehicle and set
  `rotation.x` / `.z` from the difference. ~15 lines. **~1 h.**
- **D. More than one convoy.** `_schedule_one_convoy` → schedule 3–5 across the day, and stop
  `queue_free`-ing at the end of the road (turn it round, or despawn out of sight). **~2 h.**
- **E. Engine loop + dust.** **~2 h**, and it is what makes a convoy read as alive from 200 m.
- **F. Give `DestructibleVehicle` a health/wreck path** so an ambushed convoy leaves something.
  **~4 h.** POST-DEMO — feature work, the ADR-015 gate applies.
- **G. Passengers.** `SeatSystem` already carries `AllyBase` and `Civilian` and has fallback layouts
  keyed per airframe (`seat_system.gd:50-101`). A truck layout is a dictionary entry.
  **~3 h**, POST-DEMO — and it is the thing that makes a convoy worth ambushing.

A + B + C is **~3 hours** and closes the four worst visible failures.

---

## ASSIGNMENT 3 — the KIT pivot, systems lens

### 3.1 The 488 is real, and I re-measured it independently

I parsed `assets/world/building models/structures/firebase/fsb_main_v3.glb` directly:
**5,810 nodes, 488 of them named `work_*`.** That matches the count the code itself carries at
`site_planner.gd:1468-1469` (*"measured 2026-09-06: 488 work markers, zero 'medic'"*).

**The composition is the argument for the kit, made by the data:**

| family | count | what it is |
|---|---|---|
| `hooch_*` (sleep / table / locker / door / radio) | **209** | **19 markers × 11 identical hooches** |
| `bunker` | 38 | |
| `rest` | ~35 | |
| `supply` | 31 | |
| `gun`, `eat` | 24 each | |
| `watch` | 21 | |
| `ammo` 14 · `dig` 12 · `wash` 9 · `pad` 8 | | |
| `chow_*` (server / diner / queue / tray / trigger) | 12 | one mess hall, whole routine |
| `med_*` | ~19 | one aid station, whole routine |
| `mortar_{0,1}_{gunner,dropper,runner}` | 6 | **2 pits × a named 3-role crew** |

**43 % of every work marker in the firebase belongs to eleven copies of one hooch**, and every name
carries a Blender `.001 … .011` duplicate suffix. **The part-carried design he is asking for is not a
new idea — it is what the source `.blend` already is. The bake is what destroyed it.**

And the shape he wants already exists twice in the data: `mortar_N_{gunner,dropper,runner}` and the
`chow_*` set are parts that carry their own named staffing. Those are the existence proof. Design the
resource to generalise them, not to invent something new.

### 3.2 The data shape — ten lines

    class_name SitePart extends Resource
    @export var part_id: StringName          # "hooch", "mortar_pit", "mess_hall", "bunker_mg"
    @export var model: PackedScene           # ONE part, own transform, own colliders
    @export var footprint: Vector2           # feeds CollisionTable + NavBaker, authored once
    @export var stations: Array[Dictionary]  # [{local: Vector3, work_type: &"sleep", role: &""}]
    @export var crew: Array[Dictionary]      # [{role: &"gunner", occupation: &"gun_crew", n: 1}]
    @export var demands: Array[StringName]   # what this part NEEDS present to be staffed
    @export var supplies: Array[StringName]  # what this part OFFERS the site
    @export var clips: Dictionary            # work_type -> clip name; the part owns its animation
    @export var terrain_op: StringName       # &"flatten" | &"cut" | &"none" — the berm fix

**How a site declares its parts** — an `Array[Dictionary]` of
`{part: SitePart, xform: Transform3D}`, produced by the Godot placement tool and consumed by
`SitePlanner`. `_collect_stations` (`site_planner.gd:650-666`) already walks a subtree for
`work_`-prefixed `Node3D`s and reads a `work_type` meta — **a part's baked markers feed the existing
reader with no change.** Do not write a second collector (ADR-023).

**How "building combos" produce NPC types without a second spawn path (ADR-028):** they do not spawn
anybody. A combo emits a **post request** — `{pos, occupation, n}` — into the *same*
`fsb_garrison_plan()` post list that `mission_generator.gd:1051-1055` already consumes. The combo
rule is a filter over `supplies` / `demands` across the placed parts: *mess_hall + supply_dump ⇒ a
`mess_cook` post; mortar_pit ⇒ three `gun_crew_arty` posts; aid_station + med_cot ⇒ a `medic` post.*
`Civilian.spawn` stays the one door. The kit changes **what the plan asks for**, never **who builds a
man**.

### 3.3 Does part-carried data make 488-vs-23 impossible by construction?

**No. It relocates it — and that is still worth doing, but say it plainly.**

The 23 is not an authoring accident. It is a code constant:
`site_planner.gd:1419` — `work_budget = clampi(FSB_GARRISON_MAX_MEN - _fsb_curated_men(), 0,
FSB_WORK_POST_CAP)`, with `FSB_GARRISON_MAX_MEN = 40` (`:1230`) and `FSB_WORK_POST_CAP = 24`
(`:1240`). Summing the `men` column of `FSB_GARRISON_POSTS` (`:1100-1116`) gives **17 curated men**,
so `clamp(40 − 17, 0, 24) = 23` **exactly.** The cap is a **perf budget** — bodies are ~94 % of AI
cost (PERF_LEDGER, cited at `heli_lift.gd:23-24`).

Moving the markers into parts does not raise 40. What it changes is the **numerator**: today 209 of
488 markers exist because the author duplicated a hooch eleven times, whether or not the site wants
eleven hooches. Place three hooches and you carry 57 hooch markers, not 209. **The mismatch becomes a
function of what you placed instead of a property of one frozen bake.** That is a real and valuable
change. It is **not** "impossible by construction", and any claim that it is will be false the first
time someone stamps twelve hooches.

The honest framing for the decree: **part-carried markers make the ratio TUNABLE and AUDITABLE per
site. The cap stays. 488 → ~150 is achievable; 488 → 23 is not, and should not be — an empty post is
correct, an over-staffed base is a dead frame.**

### 3.4 TRADEOFFS — what part-carried data sacrifices

**No free lunches. Five, and the second is the one that will hurt.**

1. **Per-site tuning dies at the part boundary.** Today `FSB_WORK_PRIORITY` plus the round-robin
   (`site_planner.gd:1427-1460`) let one central table decide, for the whole compound, that `watch`
   outranks `rest`. When each part carries its own staffing, that global knob is gone: raising the
   watch count means editing the bunker part, which changes **every** bunker on **every** site,
   including the ones that were already right.
2. **You cannot hand-fix ONE marker any more.** Today a bad `work_dig` position is one node in one
   GLB. In a kit it is a node in a part class instanced 11 times — fixing the one that clips into a
   berm requires either a per-instance override channel (which re-introduces exactly the per-site
   data the kit was meant to delete) or re-exporting the part and moving all eleven.
   **Budget the override channel from day one, or accept "fix one, move eleven."**
3. **A whole new class of drift: the part file vs the placed scene.** Right now there is one bake and
   one truth. With parts there are N part resources and M placements, and a part edited after
   placement silently changes finished sites. That is the FOSSIL LAW's disease with a new host. It
   needs a version stamp on the placement and a probe that fails when the two disagree.
4. **Draw-call arithmetic can go the wrong way.** The intent doc's own evidence is *"45 % of draw
   calls for 4 % of geometry — 545 interior props, every one its own mesh in the monolith."*
   Splitting into stamped parts does not fix that by itself; it makes it easier to fix (MultiMesh per
   part type) and easier to make worse (one `PackedScene` instance per part with no batching).
   **UNVERIFIED — I did not profile this. Do not promise a perf win.**
5. **The combo rule is a new authority.** `demands` / `supplies` is a small inference engine. It will
   produce staffing nobody asked for on the first site that has an unexpected pair of parts. It needs
   a deterministic, ADR-010-clean evaluation order and a printed ledger line, the way
   `WorkingPointResolver.ledger_line()` (`mission_generator.gd:904`) already does.

### 3.5 One thing the kit fixes for free, and it is his stated goal

`terrain_op` on the part is the answer to *"remove people falling thru berms."* Today the berm is
geometry inside a 5,810-node bake, and the navmesh is baked around it. A part that declares
`&"flatten"` or `&"cut"` calls machinery that already exists — `DamageSystem.modify_terrain()` and
`ClearingSystem`, both named in `production/FIREBASE_REWORK_INTENT.md` — at **stamp time, before**
`NavBaker.queue_sites`. **The falling-through is a nav/terrain ORDERING defect, and part-carried
`terrain_op` is what fixes the ordering.** It is the strongest systems argument for the pivot and it
should lead the decree.

---

## Summary of everything I could not measure

- The `Civilian` collision-shape origin, which decides whether `_exit_ground`'s `+1.0` is a bug or a
  correct capsule offset. **Measure before touching.**
- The demo's actual `map_size` (I assumed 512 from the briefing) — the road-dust texel/metre figure
  scales with it.
- Draw-call cost of stamped parts vs the monolith. No profile was run; no perf claim is made.
- Whether the road he walked was the demo's one segment, or whether he walked away from it entirely.
  A probe printing `RoadNetwork.total_length()` and the player's `distance_to_road` at the gate would
  settle it in one boot.
