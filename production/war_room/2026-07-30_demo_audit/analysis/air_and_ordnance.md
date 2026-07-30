# DEMO AUDIT — AIR WAR AND ORDNANCE

Audited 2026-07-30 by code + asset reading only. Game NOT launched, Blender NOT opened.
GLBs parsed with python (`json`/`struct` on the glTF JSON chunk). **Every runtime claim below is
UNPROVEN by execution** — the maths and asset contents are proven, the frame-by-frame behaviour is
not. Where a conclusion depends on a runtime ordering I say so explicitly.

Scope: `scripts/ai/air_traffic.gd`, `scripts/vehicles/heli_lift.gd`, `helicopter.gd`,
`seat_system.gd`, `cas_airplane.gd`, `spectre_gunship.gd`, `scripts/combat/bullet_system.gd`,
`scripts/levels/demo_game.gd` (air cadence + napalm), `scripts/missions/field_director.gd`
(`authored_strike` + gun-standoff guard), `scenes/vehicles/huey.tscn`, `chinook.tscn`,
`assets/us/vehicles/huey.glb`, `ch47_chinook.glb`,
`assets/world/building models/structures/firebase/fsb_main_v3.glb`.

---

## P0-1 — Every delivered replacement teleports back to the spawn point, in mid-air, on his first tick

`heli_lift.gd:179-180` spawns each passenger with
`Civilian.spawn(world, heli.global_position, director, false, Civilian.GARRISON_MEN, true)`.
At that moment the helicopter is at `inbound` (`air_traffic.gd:398-400`): `lz.global_position +
unit_vector * map_size*0.55`, at `ground + cruise_altitude` — on the 512 m demo map that is **~281 m
from the pad and 30 m in the air**.

`Civilian.spawn` stores that position as the man's HOME: `civilian.gd:187` `civ.home = pos`.

`SeatSystem.seat` (`seat_system.gd:182`) calls `body.set_physics_process(false)`, so the man never
runs a tick while airborne — `civilian.gd:235-237`'s `_placed_for_hour` latch stays **false**.
`unseat` restores the tick (`seat_system.gd:236`). So the **first physics tick a delivered man ever
runs is on the pad**, and its first action is:

```
if not _placed_for_hour:
    _placed_for_hour = true
    place_for_current_hour()          # civilian.gd:235-237
```

`place_for_current_hour` (`civilian.gd:639-650`) resolves a target and does
`global_position = target`. `_resolve_target` (`civilian.gd:653-661`) only returns a real post when
`working_point_pos != Vector3.ZERO`; nothing in HeliLift ever sets `working_point_pos` or
`occupation` (default is `"farmer"`, `civilian.gd:50`), so it falls through to
`home + Vector3(randf(-3,3), 0, randf(-3,3))`.

**Failure:** the Huey lands, the doors swing, `unseat_all` puts six men on the pad, they start
`disembark_heli`, and **on the very next physics tick all six teleport ~281 m away and 30 m up, then
fall out of the sky into the jungle at the map edge.** Deterministic, every delivery, every boot.
The one thing the whole system was built to show — "Huey landings with troops disembarking" — cannot
be seen.

Fix shape: set `civ.home` (and `working_point_pos`) to the pad/his post after `unseat`, or set
`_placed_for_hour = true` before seating. Note the comment at `heli_lift.gd:183-185` believes it has
already solved this by leaving the `firebase_garrison` group — that group is irrelevant;
`place_for_current_hour` is called from the man's own `_physics_process`, not from a group sweep.

## P0-2 — `_deliver`'s stand-to call is a guaranteed no-op (inverted guard)

`heli_lift.gd:230-231`:

```
if director != null and is_instance_valid(director) and director._garrison_stood_to:
    director._garrison_stand_to()
```

`field_director.gd:1325-1328`:

```
func _garrison_stand_to() -> void:
    if _garrison_stood_to:
        return
```

The call is gated on the exact flag that makes the callee return immediately. **The branch can never
do anything.** Replacements delivered into a live siege are never promoted to `GarrisonDefender`;
they stay unarmed `Civilian`s with occupation `"farmer"` standing on the pad (and per P0-1, not even
there). The comment claiming this reaches "the director's own stand-to rather than duplicating
promote()" is describing code that does not run.

Fix shape: call `GarrisonDefender.promote(man, director, director.fsb_center)` per delivered man when
`director._garrison_stood_to` is true. That is the same single authority, not a second path.

## P0-3 — The Huey lands ~3.5 m below the pad deck (inside the mound)

`fsb_main_v3.glb` puts all pad nodes at model-space `y = 4.014`
(`fb_helipad_i` / `PSPHelipad` / `fb_helipad_i_182-colonly`, all `T = [22.183, 4.014, -41.295]`).
`AirTraffic._firebase_lzs` sets `lz.global_position = pad.global_position`
(`air_traffic.gd:362`) — the correct deck height.

`Helicopter` then **throws that Y away**. `helicopter.gd:219`:

```
_land_y = _ground_y(_target) + 0.5      # terrain height, not lz.global_position.y
```

and the terrain under the firebase is flattened to a **flat seat**, not to the mound —
`site_planner.gd:999,1031-1033` lerps toward `seat_norm`, and the mound manifest
(`fsb_main_v3_mound.json`, `mound_h: 3.4`) is consumed only for prop placement
(`site_planner.gd:1226`). The manifest's own `_step` note records the ruling that the mound is MESH,
so the heightmap is deliberately flat there.

**Failure:** `_land_y = seat_y + 0.5` while the PSP deck is at `seat_y + 4.01`. The Huey descends
through the pad and comes to rest ~3.5 m inside the mound; the doors open underground and
`door_staging_pos()` (`seat_system.gd:303-310`, socket Y + 1.3) stages the men inside the earth.
Confidence: high (arithmetic from the GLB + the sculpt code). UNPROVEN at runtime.

Fix shape: `Helicopter._process_flying` should prefer `_lz.global_position.y + 0.5` when an LZ is
supplied, and only fall back to terrain when it is not.

## P1-4 — There is only ONE helipad, and AirTraffic creates THREE stacked LandingZones on it

`air_traffic.gd:54-59` asserts "measured: three 15x15m PSP pads" and matches by prefix. The GLB
holds three nodes — `fb_helipad_i`, `PSPHelipad`, `fb_helipad_i_182-colonly` — and **all three carry
the identical translation** `[22.183, 4.014, -41.295]`. They are one physical pad exported as
visual + collider + duplicate. The `-colonly` suffix is stripped by the Godot importer, so it still
matches the `fb_helipad` prefix.

Result: three `LandingZone` nodes at the same point, each `capacity = 1`, each independently
`can_land()`. Compounding it, nothing reserves a pad at dispatch — `helicopters_present` is only
incremented **on touchdown** (`helicopter.gd:239`), so `_free_pad()` (`air_traffic.gd:370-375`) hands
the same LZ (or its two twins) to every inbound ship until one has actually landed.

**Failure:** up to three helicopters converge on one 15 m pad and interpenetrate. In the 20-minute
demo the two authored cycles (14 s Huey, 95 s Chinook) are 81 s apart against `GROUND_SECONDS = 35`,
so it probably will not bite in the demo — but the sim schedule books four more
(`air_traffic.gd:90-93`) and `launch()` can be called at any time. The doc claim at `:54-55` is
drift regardless.

## P1-5 — HeliLift on the Chinook: no doors, and UH-1 seats bolted into a CH-47

`demo_game.gd:80` — `[95.0, "chinook", "lz_cycle"]` — puts a Chinook through
`_dispatch_lz_cycle`, which attaches HeliLift unconditionally (`air_traffic.gd:406`).

`ch47_chinook.glb` contains **no** `Door_Left`/`Door_Right` (it has `Cargo_Ramp`, `Cargo_Door_L`,
`Cargo_Door_R`) and **no** `seat_*` sockets at all.

- `_find_doors` (`heli_lift.gd:113-125`) finds nothing, so `_physics_process` (`:139-141`) hard
  returns and **the reveal silently never happens** — exactly the failure mode the task asked about.
  Nothing warns. Confirmed from the asset.
- `SeatSystem._scan_sockets` (`seat_system.gd:99-117`) then generates **all 11** UH-1
  `FALLBACK_LAYOUT` markers into a CH-47 root frame. The layout is a measured UH-1 cabin
  (x ±1.15, z −2.0…−5.35 — I verified it against `huey.glb` and it is exact, see note below);
  in a ~15 m tandem airframe those coordinates land near the cockpit, and men will be seated
  floating in or outside the hull.
- `heli_lift.gd:79-80`'s claim that the fallback layout means it "works whether or not the airframe
  exports sockets" is only true for the Huey.

Fix shape: `HeliLift.attach` should refuse (or the door/seat contract should be per-airframe) when
the airframe carries neither `Door_*` nor `seat_*`. At minimum push_warning instead of failing mute.

## P1-6 — Passengers leak: bodies frozen in mid-air forever when the ship is freed

`_on_took_off` (`heli_lift.gd:272-281`) removes remaining occupants from `firebase_garrison` and
**never unseats or frees them**. They are not children of the helicopter — `Civilian.spawn` parents
them to the world (`civilian.gd:174`) — they are driven by a `RemoteTransform3D` that is a child of
the seat socket (`seat_system.gd:196-200`).

When `AirTraffic._process` reaps the flight and calls `node.queue_free()`
(`air_traffic.gd:460-463`), the socket and the glue die with the airframe. The passengers survive
with:
- `_physics_process` still **false** (`seat_system.gd:182`) — no gravity, no schedule, no LOD;
- their body `CollisionShape3D` still **disabled** (`:190-192`);
- their `Hitzone` Area3Ds still **live** (HitzoneBuilder attaches Areas, not direct
  `CollisionShape3D` children, so `seat()`'s shape sweep never touches them);
- still in the `civilians` group and still registered in `AgentRegistry` (`civilian.gd:190-193`).

**Failure:** every EXTRACT sortie parks 3–6 permanently frozen, un-tickable, shootable soldiers
30 m in the air at the map edge (or off-map — the exit point is `map_size*0.55` from the pad,
`air_traffic.gd:409-410`). They accumulate for the whole session, each holding a full PSX body,
~11 hitzone areas and an AgentRegistry slot. This is a leak in the dimension the project is bound
by. Also note `garrison_strength()` drops each time, which makes the *next* lift a DELIVER — so the
loop is: extract 6, freeze 6 in the sky, deliver 6 more, repeat.

Fix shape: in `_on_took_off`, `queue_free()` the occupants after removing them from the group
(they are leaving the world by design), or unseat them into the aircraft as tracked children with an
explicit teardown on `queue_free`.

## P1-7 — The gun-standoff guard measures the wrong 310 m of ground

`_beaten_path_miss` (`field_director.gd:551-563`) samples 9 points along
`at + dir*t`, `t ∈ [CASAirplane.STRAFE_OPEN_M, STRAFE_CLOSE_M] = [-260, +50]`, and returns the
minimum horizontal distance to the player.

That interval is **where the AIRCRAFT is**, not where the rounds land. `_fire_strafe_burst`
(`cas_airplane.gd:249`) aims each burst at `global_position + _run_dir * STRAFE_LEAD_M` with
`STRAFE_LEAD_M = 160.0` (`:62`). The impacts therefore span `at + dir*t` for
**`t ∈ [-100, +210]`** — the sampled window is offset from the real beaten path by **+160 m** and
overlaps it on only ~150 of 310 m.

Two consequences:
1. **Under-protective downrange.** Impacts from `+50` to `+210` are never tested. A player standing
   120–210 m *past* the aim point along the run axis passes the check while 20mm lands on him.
2. **Over-protective uprange.** The guard rejects axes because the player is 100–260 m *short* of
   the aim point, where no round ever lands, and then rotates to a bearing that is only "clear" by
   the same wrong metric.

Concrete kill scenario: `at` is 210 m out from `fsb_center` on the assault bearing
(`demo_game.gd:131-137`), and the player is in the compound. Rotate the axis inbound
(`_gun_axis_clear_of_player`, `:566-574`, tries 11 bearings at 30° steps). The aircraft track then
runs radius 470 m → 160 m; nearest sample to the player at the centre is **160 m ≥ GUN_STANDOFF_M
120**, so the guard **accepts** it. The impacts, at `+160` of that, run radius 310 m → **0 m** — the
gun run walks straight through the compound, the garrison, and the player.

Answers to the specific questions asked:
- `CASAirplane.STRAFE_OPEN_M` / `STRAFE_CLOSE_M` **are** accessible as written — GDScript exposes
  script `const`s through the `class_name`. No defect there.
- The 12-bearing loop **cannot return an axis worse than the original**: the original gets an early
  return when it already clears, and any rotated axis returned has been tested to ≥120 m. But every
  test uses the wrong 310 m window, so "clear" does not mean clear.
- The guard protects **only the player**. Nothing keeps a rotated gun axis off the firebase, the
  garrison, or the squad. `_friendly_in_danger_close` exists in this file but is not consulted here.
- Secondary: 9 point-samples across 310 m leaves 38.75 m gaps, so a point-to-sample minimum
  overestimates true clearance by up to ~19 m — real standoff can be ~101 m, not 120 m.
- Secondary: `_run_axis`'s no-placement fallback (`:611`) returns `target - player_position`
  **without zeroing Y**, and `_beaten_path_miss` normalises that 3-vector, so `dir.x/dir.z` are
  shrunk and the sampled ground track is shorter than the real one. `call_flyby` zeroes Y, so the
  guard and the aircraft do not use the same line. Small on flat ground.

## P2-8 — `huey.tscn` already ships a SeatSystem; HeliLift adds a second one

`heli_lift.gd:79-80` states "The huey scene ships no SeatSystem node". `scenes/vehicles/huey.tscn:13-14`
**is** a `Node` named `Seats` with `seat_system.gd` attached. `heli_lift.gd:81-83` then adds another
`SeatSystem` also named `Seats`, which Godot auto-renames on collision.

Consequences:
- Two `SeatSystem`s on one airframe. `Helicopter.seats()` (`helicopter.gd:152-153`) resolves
  `get_node_or_null("Seats")` — the **scene** one, which has zero occupants forever. (Mitigating:
  `seats()` has zero production callers today — grep confirms — so it is a fossil-shaped hazard, not
  a live bug. It becomes a live bug the moment anything asks the helicopter who is aboard.)
- Both instances run `_scan_sockets`. `HeliLift`'s runs **synchronously** (forced by `seat()` →
  `_scan_sockets()`, `seat_system.gd:167`) inside `HeliLift._ready`, while the scene's runs
  **deferred** (`seat_system.gd:87`). The sync one wins, generates the one missing socket, and the
  deferred one then finds it — so they end up sharing sockets while keeping *separate* occupancy
  dictionaries. Any future second consumer will double-book a seat.

Lifecycle question asked, answered: **`SeatSystem._ready` does run before `_load_pax`** — the heli is
already in the tree (`air_traffic.gd:394` precedes `:406`), so `heli.add_child(seats)` fires
`_ready` synchronously. But `_ready` only *defers* the socket scan; the thing that actually makes
`_load_pax` work is `seat()`'s own lazy `_scan_sockets()` call. `_free_berth`
(`heli_lift.gd:160-164`) queries `occupant()`, which does **not** scan, so on the first call it is
reasoning about an empty socket table and returns `seat_pax_1` by luck. It works, but for the wrong
reason, and it will silently mis-berth the day `occupant()` starts consulting `_sockets`.

## P2-9 — The cabin doors scissor through the fuselage (origin is mid-panel, and a UH-1 door slides)

`huey.glb`: `Door_Left` at `[-9.30, 2.145, -1.2675]`, `Door_Right` at `[-6.18, ...]` — in
recentered vehicle-root space `x = ±1.56`, `z ≈ -2.66` (I verified the whole transform chain:
`Model` is rotated 180° about Y in `huey.tscn:11` and `helicopter.gd:76-80` recenters on the
`Huey_Copy` AABB; every real `seat_*` socket lands **exactly** on its `FALLBACK_LAYOUT` value, e.g.
`seat_pilot_l → (0.55, 1.35, -5.359)` vs the table's `(0.55, 1.35, -5.35)`. The layout table is
sound).

The door meshes span local `z ∈ [-0.7525, +0.7475]` — **1.5 m wide with the origin at the panel
centre, not at a hinge**. `heli_lift.gd:147-152` yaws them ±105° about that centre, so ~0.72 m of
panel sweeps outward and ~0.72 m sweeps **inward through the cabin floor, the bench and the
seated passengers**. The comment at `:148` ("each door slides back along its own side of the cabin")
describes a slide; the code is a swing; and a real UH-1 cabin door slides aft on rails.

Fix shape: translate along the door's local axis (a slide) instead of yawing, or re-author the door
origin at its forward edge in Blender.

## P2-10 — Extraction teleports men into the cabin; no one walks to the ship

`_extract` (`heli_lift.gd:240-262`) gathers garrison `Civilian`s within `EXTRACT_REACH_M = 35` and
hands them to `SeatSystem.board_squad`. `board_squad` (`seat_system.gd:261-278`) issues a walk order
**only** for `AllyBase`:

```
var ally := body as AllyBase
if ally != null:
    ally.set_order(AllyBase.OrderMode.MOVE_TO, staging)
```

A `Civilian` is not an `AllyBase`, so it gets **no order at all** — and `_board_one` fires
`BOARD_STAGGER_S * n` seconds later and calls `seat()`, which does
`body.global_transform = sock.global_transform` (`seat_system.gd:194`). **Men up to 35 m away
vanish from the ground and pop into the cabin, 0.6 s apart.** `heli_lift.gd:44-45`'s "a man walks to
the door and seats with no boarding animation" is not what happens; there is no walk.

Related smaller items in the same path:
- `_free_berth` (`heli_lift.gd:161`) walks `PASSENGER_SEATS`, which **includes the two door-gunner
  stations** (`seat_system.gd:32`). With `PAX_MAX = 6` the bench absorbs everyone, so this is latent,
  but a 7th+ man ends up in a door gun seat playing the `sitting` clip.
- `unseat_all` (`seat_system.gd:248-256`) rings men with `TAU * i / 10.0` while `SEAT_NAMES` holds
  **11** entries — the 11th man lands on top of the 1st.
- `unseat`'s AI path never grounds the body (only the *player* path raycasts, via `_exit_ground`,
  `:394-405`), so delivered men appear at deck height and drop ~1.3 m.
  `heli_lift.gd:217-219`'s claim that unseat "has already restored his ... ground position" is
  drift.
- `seat_system.gd:115,117` print "%d/10" and "all 10 seat_* sockets" — there are 11.

## P2-11 — Spooky's Vulcan: three perfectly collinear rounds, and 30 noise/suppression fans per second

Rate maths **checks out**: `project.godot:304` `physics_ticks_per_second=30`, and
`VULCAN_ROUNDS_PER_TICK = 3` (`spectre_gunship.gd:37`) gives exactly the 90 rounds/s the header
claims. Slant range √(160²+130²) ≈ 206 m at `projectile_speed = 1030` = 0.20 s of flight → ~18 in
the air. `BulletSystem.MAX_BULLETS = 500` (`bullet_system.gd:32`) is nowhere near binding; the cap
warning path (`:53-70`) will not fire from this. **No defect on the budget.**

Defects that are real:

1. **No spread.** `_fire_vulcan` (`:208-211`) computes ONE `aim` per tick and fires all three rounds
   on the identical `dir` from the identical `muzzle`. `BulletSystem.fire` applies **no** spread of
   its own (`bullet_system.gd:51-92` takes `dir` verbatim; `aircraft_20mm.tres`'s `base_spread = 1.4`
   is never consulted on this path). So the three rounds occupy the same point in space for their
   whole flight: **one visible tracer streak per tick, and 3× the damage delivered to a single
   point.** The header's "continuous sheet of tracer into a wide beaten zone" is one pencil line that
   jumps 25 m every 33 ms. Compare `CASAirplane._fire_strafe_burst`, which *does* scatter
   (`cas_airplane.gd:253-254`) — one aircraft, two ideas of what a burst is, which is the exact
   disease the 07-29 rewrite was supposed to cure.
2. **Per-tick fan-outs.** `apply_suppression_in_area` and `NoiseBus.emit_noise`
   (`spectre_gunship.gd:212-213`) run **every physics tick** while hot — 30/s for a 2 s window, six
   windows per 30 s sortie. `NoiseBus.noise_emitted` is connected by every `Civilian`
   (`civilian.gd:192`) and the enemy population; during the demo siege that is ~30 × (45 + civilians)
   signal dispatches per second from one gunship, plus 30 area suppression sweeps. Move both to the
   `VULCAN_REPORT_S` clock that already exists for the audio.
3. **Damage-of-record drift.** `aircraft_20mm.tres` `base_damage = 87` (the ADR-016 *sniper* value).
   `air_traffic.gd:270` still says "60-damage Vulcan". One of the two is wrong; at 87 × TORSO 2.5,
   three collinear rounds land 652 damage on one body in a single tick.
4. **The "directly above the target" case asked about is unreachable.** `inward = target -
   global_position` flattened (`:204-206`) — the ship is pinned to `ORBIT_RADIUS = 160`
   (`:159-160`, `call_in` seeds it at exactly +160 X), so `inward.length()` is ~160 and the
   `Vector3.RIGHT` fallback at `:206` is dead code. Deriving `inward` in world space is correct and I
   found no defect in it. The `muzzle` at `+inward*3.2, -0.9` sits inside the fuselage rather than on
   the port sponson — cosmetic, and harmless only because the airframe carries no collider.
5. `exclude` is ineffective on both aircraft: `[self]` is passed at `spectre_gunship.gd:211` and
   `cas_airplane.gd:256`, but `BulletSystem.fire` only collects RIDs from `CollisionObject3D`
   (`bullet_system.gd:71-74`) and a `SpectreGunship`/`CASAirplane` is a bare `Node3D`. Harmless
   today (no colliders on the airframes), a self-hit the day one gets a hull.
6. Header comment `:36` computes the tracer streak as `speed*0.016` (a 60 Hz delta). At 30 Hz it is
   34 m, not 16.5 m. Cosmetic, but it is the number the design argument rests on.

## P3-12 — The strafe's beaten path is centred ~85 m PAST the aim point, and never reaches its authored opening

`STRAFE_OPEN_M = -260` (`cas_airplane.gd:58`) but `call_flyby` spawns the aircraft at
`FLYBY_SPAWN_DIST = 200` (`:22`, `:127`), so `along` starts at **−200** and the authored 260 m
opening leg is unreachable — the guns are hot from the spawn frame. With `STRAFE_LEAD_M = 160`, the
impacts run `along ∈ [-40, +210]`, i.e. **centred ~85 m beyond the thing the run was called on**,
and the target itself is only under fire in the first fraction of a second. At `F4_SPEED = 250` the
whole gun run lasts (50 − (−200))/250 = **1.0 s**, about 10 bursts / 30 rounds.

## P3-13 — Demo air cadence: the cap is advisory, and the opening bypasses it

`demo_game.gd:157-166`. `AIR_MAX_IN_SKY = 14` is checked **before** a launch that can add 6–9 ships
(`FORMATION_SIZES["huey"] = [6,9]`, `FORMATION_CHANCE = 0.85`), so the real ceiling is 13 + 9 = **22**
airframes. The authored opening (`:74-81`) `return`s before the cap check entirely: 3 s (6–9 Hueys),
14 s (+1), 26 s (3–5 F4), 48 s (6–9 Hueys), 70 s (2 Skyraiders), 95 s (+1) = **up to 27 launches
inside 95 s with no cap consulted at all**.

Mitigating, and why this is P3 not P1: on the 512 m demo map a transit chord is
`m*1.5 = 768 m`, which a Huey clears in ~15 s at `max_speed = 50` and an F-4 in ~3 s at 250, and
the reaper frees on arrival (`air_traffic.gd:456-463`). Concurrency should stay low. But nothing in
the code guarantees it, and `flights_in_air()` counts roster rows (one per ship), so the number the
cap compares is the right one — it is just checked at the wrong moment. **UNPROVEN — needs one
measured boot with a frame counter.**

Also `_tick_air` never reads `EXCLUDE_AIR_TRAFFIC` (`demo_game.gd:21`); it only probes for the node.
Flipping the switchboard flag would leave this ticker calling a null lookup every frame rather than
being visibly excluded.

## P3-14 — Napalm beat timings are clean; the toast lies about danger close

Verified no collision with the siege arc: `PROBE_AT_S 600`, `SIEGE_AT_S 720`, `DAWN_AT_S 1080`;
`NAPALM_EARLY_S 160` sits alone in the explore window, `NAPALM_ASSAULT_S = 780` sits 60 s into the
main assault and 300 s before dawn. No overlap. `_tick_napalm`'s `elif` (`demo_game.gd:117-127`)
cannot starve the second beat because they are 620 s apart.

Bearing maths (`_strike_at`, `demo_game.gd:131-139`) is sound **as written**: `at` is
`centre + outward * 210`, the run axis is the tangent `across = (-outward.z, 0, outward.x)`, and
every point on that tangent line is ≥ 210 m from `fsb_center` (√(210² + s²) ≥ 210). The napalm strip
is `NAPALM_DROPS 5 × NAPALM_SPACING 15 = 60 m` long with `NAPALM_BLAST_M 10`
(`fire_plan.gd:23-25`), laid along the tangent — worst case ~40 m of lateral reach, so it cannot
touch the compound. **The tangential axis is safe. The danger is that P1-7's guard is allowed to
rotate it** (see the kill scenario there): nothing in `authored_strike` constrains the rotated axis
to stay off the firebase, and the map bounds are never consulted either — `at` is only 210 m from
the base so an off-map run is not reachable on the 512 m demo map, but there is no guard, only
geometry.

Two smaller things:
- `demo_game.gd:126` toasts "GUN RUN AND NAPALM - **DANGER CLOSE**" while calling
  `authored_strike(..., across)` with `danger_close` defaulted to **false** (`field_director.gd:578`).
  The UI says one thing, the safety path takes the other.
- `demo_game.gd:120` comments the early bearing `PI*0.5` as "opposite the gate, out over the
  jungle". I could not verify where the wire gate is on `fsb_main_v3` from code; that is an
  **unpointered assumption**. If the gate happens to be on +Z, the 160 s spectacle beat lands
  210 m off the player's own exit route.

## Question 5 — leftover fake damage / fake tracers

**Code: clean.** Grep over `scripts/vehicles/` finds no decorative-tracer painter and no fake-damage
application on either gun path. Both `SpectreGunship._fire_vulcan` and
`CASAirplane._fire_strafe_burst` route through `CombatManager.bullets.fire`. Remaining
`apply_explosion_damage` calls are all genuinely explosive ordnance (bomb `:285`, napalm `:301`,
CBU bomblet `:337`, Bofors shell `spectre_gunship.gd:225`, heli crash `helicopter.gd:207`).

**Comments: not clean — three fossil descriptions of the system that was deleted today.**
- `cas_airplane.gd:48-53` — a whole paragraph asserting, in the present tense, that
  "SpectreGunship._fire_vulcan picks a point on the ground, paints three decorative tracers at it and
  applies a small explosion there... so the tracers carry no damage". That has been false since this
  morning's rewrite. A reader who greps for the fake-tracer bug finds this and concludes the bug is
  live.
- `spectre_gunship.gd:24-29` — the same history, now inside the file that fixed it.
- `air_traffic.gd:270-271` — "pours 60-damage Vulcan", contradicted by
  `aircraft_20mm.tres` `base_damage = 87`.

Per the standing drift law these are the corpse-markers the FOSSIL LAW names: the sentence recording
a bug's death reads exactly like the bug being alive. They belong in the commit message.

---

## Verified sound (no action)

- `FALLBACK_LAYOUT` matches `huey.glb`'s real sockets to within 1 cm through the full
  `Model`-rotation + AABB-recenter chain. The layout table is trustworthy for the Huey.
- `huey.glb` **does** contain `Door_Left` and `Door_Right` and `seat_pilot_l/r`,
  `seat_gunner_l/r`, `seat_pax_1..6`. Only `seat_pax_7` is missing, so exactly one fallback marker
  is generated — and it lands in the correct frame (added to the vehicle root,
  `seat_system.gd:108`, which is the frame the table is authored in).
- `SeatSystem.seat` correctly kills `_physics_process`, `_process`, `velocity`, and the direct-child
  `CollisionShape3D`s. Nothing else moves a seated body: `place_for_current_hour` and `_update_lod`
  both live behind the disabled `_physics_process` (`civilian.gd:234-244, 596-623`), gravity is in
  the same function, and the `NavigationAgent3D` is only driven from there. `_on_noise`
  (`civilian.gd:199-204`) early-returns for `is_garrison`. **A seated passenger does not get moved
  or dropped mid-flight** — the P0-1 teleport happens *after* landing, on the resumed first tick, not
  in the air. (It does keep live `Hitzone` areas at altitude, so he can be shot in flight; arguably
  correct.)
- `_advance_cycle`'s phase machine (`air_traffic.gd:416-431`) is consistent with
  `Helicopter`'s state enum, and `take_off()`'s `state != LANDED` guard cannot be tripped out of
  order. Total lz_cycle wall time ≈ 55 s against `MAX_FLIGHT_SECONDS = 240`.
- `_dispatch_lz_cycle`'s `HeliLift.attach` runs **after** `world.add_child(heli)`, so the
  synchronous-`_ready` assumption in the task brief holds.
- `authored_strike` → `_launch_flyby` → `_run_axis(target, run)` double-applies `_run_axis`, but
  harmlessly: a non-zero axis is returned verbatim (`field_director.gd:608-609`).
- The 12-bearing rotation loop cannot return an axis that is worse **by its own metric** (see P1-7).
- `class_name` constant access (`CASAirplane.STRAFE_OPEN_M`) is valid GDScript.
- `MAX_BULLETS 500` is not binding for either aircraft gun.
- The `spectre` keep-out logic (`air_traffic.gd:277-287`) does clamp the pushed orbit centre inside
  `40 .. map_size-40`, so an ambient Spooky cannot end up orbiting off the map.

## Ranked summary

| # | Severity | File:line | Defect |
|---|---|---|---|
| 1 | P0 | `heli_lift.gd:179-180` + `civilian.gd:187,235-237,653-661` | Delivered men teleport to the airborne spawn point on their first tick |
| 2 | P0 | `heli_lift.gd:230-231` vs `field_director.gd:1326` | Stand-to call gated on the flag that makes it return; dead branch |
| 3 | P0 | `helicopter.gd:219` vs `site_planner.gd:1031-1033` | Huey lands ~3.5 m below the pad deck |
| 4 | P1 | `air_traffic.gd:54-59,351-363,370-375` | One pad exported 3×; three stacked LZs, no dispatch-time reservation |
| 5 | P1 | `heli_lift.gd:113-125,79-80` + `ch47_chinook.glb` | Chinook has no doors and no seats; reveal silently never happens |
| 6 | P1 | `heli_lift.gd:272-281` | Passengers leak — frozen bodies left in mid-air when the ship is freed |
| 7 | P1 | `field_director.gd:551-563` | Standoff guard samples the aircraft path, not the beaten path (+160 m error) |
| 8 | P2 | `huey.tscn:13-14` vs `heli_lift.gd:79-83` | Duplicate SeatSystem; `Helicopter.seats()` resolves the empty one |
| 9 | P2 | `heli_lift.gd:147-152` + `huey.glb` door origins | Doors yaw about their own centre — panel scissors through the cabin |
| 10 | P2 | `seat_system.gd:272-277` | Extraction teleports Civilians into seats; nobody walks |
| 11 | P2 | `spectre_gunship.gd:208-213` | 3 collinear rounds/tick (no spread); noise + suppression fan out 30×/s |
| 12 | P3 | `cas_airplane.gd:58,127,249` | Gun run centred 85 m past the target; `STRAFE_OPEN_M` unreachable |
| 13 | P3 | `demo_game.gd:157-166` | `AIR_MAX_IN_SKY` checked before a 9-ship launch; opening bypasses it |
| 14 | P3 | `cas_airplane.gd:48-53`, `spectre_gunship.gd:24-29`, `air_traffic.gd:270` | Comments still describe today's deleted fake-tracer system as live |
