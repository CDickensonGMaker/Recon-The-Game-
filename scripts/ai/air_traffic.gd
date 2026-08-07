## air_traffic.gd - scheduler for the sim's air traffic. Listens to
## SimClock.sim_event(kind=&"air_traffic") and dispatches the aircraft for the
## flight. Owns the in-flight roster; it is the only authority that puts an
## aircraft in the sky.
##
## Two profiles: TRANSIT crosses the AO and leaves; LZ_CYCLE flies a helicopter
## in to a firebase pad, sits on the ground, then lifts off and departs.
class_name AirTraffic
extends Node

## Kinds with a flyable scene. Rotary kinds drive Helicopter, fixed-wing drive
## CASAirplane in transit mode. "spectre" builds itself in code (SpectreGunship)
## and has no scene. There is no C-130: no model exists for one.
const FLIGHT_SCENES := {
	"huey": "res://scenes/vehicles/huey.tscn",
	"chinook": "res://scenes/vehicles/chinook.tscn",
	"f4": "res://scenes/vehicles/f4_phantom.tscn",
	"skyraider": "res://scenes/vehicles/skyraider.tscn",
	"skyhawk": "res://scenes/vehicles/a4_skyhawk.tscn",
}
## Kinds that can fly a firebase landing cycle.
const ROTARY := ["huey", "chinook"]
## Fixed-wing cruise profile: metres AGL, metres/second.
const FIXED_WING := {
	"f4": {"agl": 90.0, "speed": 250.0},
	"skyhawk": {"agl": 80.0, "speed": 200.0},
	"skyraider": {"agl": 60.0, "speed": 110.0},
}
## Formation-capable transit kinds -> [min_ships, max_ships] counting the lead.
## Chinooks and everything unlisted always transit solo.
## Summoner's numbers, 2026-07-28: "heuys fly in packs of 6 to 9 and jets fly in groups
## of 3 to 5". The skyraider is a PROP, not a jet, so it keeps its pair and is not
## covered by the 3-5 rule.
##
## PERF: a nine-ship lift is up to 9x the rotor meshes, animation and audio of a single
## Huey, and framerate is this project's top systemic risk. If it costs too much the
## honest lever is fewer concurrent FLIGHTS - the pack size is the thing that was asked
## for. MEASURE before trusting this.
const FORMATION_SIZES := {"huey": [6, 9], "f4": [3, 5], "skyhawk": [3, 5], "skyraider": [2, 2]}
## "Hueys fly in packs" reads as packs being the NORM, so a lone ship is now the
## exception. Changing the size without this left two thirds of flights flying solo.
const FORMATION_CHANCE: float = 0.85
## Echelon geometry per wingman slot (metres): lateral spread, altitude
## stagger, trail behind the lead. Each multiplies by the slot index.
const ECHELON_LATERAL_M := Vector2(45.0, 70.0)
const ECHELON_ALT_M := Vector2(8.0, 12.0)
const ECHELON_TRAIL_M := Vector2(15.0, 30.0)
## A flight that never arrives is a leak. Nothing may outlive this.
const MAX_FLIGHT_SECONDS: float = 240.0
## How close a flight has to pass for the jungle to hear it.
const OVERHEAD_M: float = 120.0
## Rotors-turning time on the pad before the bird lifts off again.
const GROUND_SECONDS: float = 35.0
## Pad markers inside the firebase GLB.
## DRIFT CORRECTED 2026-08-03: this said "measured: three 15x15m PSP pads". The shipped GLB
## has ONE. Three nodes match the prefixes and all three sit at the IDENTICAL position, so
## `_free_pad` would happily land three aircraft on one square metre. `_firebase_lzs` now
## de-duplicates co-located markers, and a second real pad is Blender work, not code.
const PAD_DISTINCT_M: float = 12.0
## Matched by PREFIX, not by exact name: v2 authored PSPHelipad_001.._003 and the
## v3 re-export renamed them (PSPHelipad, fb_helipad_i, fb_helipad_i_182), which
## resolved to ZERO landing zones without anything failing to load. A Blender
## re-export renumbers nodes freely; the prefix is the contract.
const FSB_PAD_PREFIXES := ["PSPHelipad", "fb_helipad"]
## Transit bookings per daylight sim-hour. At the 60x clock, 3 puts a movement up roughly
## every 20s of wall time instead of every 60s.
const TRANSITS_PER_HOUR: int = 3
## Hard ceiling on airframes in the sky, binding on EVERY caller. PERF_LEDGER: this project
## is call-bound and a nine-ship pack is nine sets of rotor meshes.
const MAX_IN_FLIGHT: int = 14

## In-flight roster. {id, kind, node, route, dest, pos, phase, born_ms, spawned}.
var _in_flight: Array = []
## Cached RNG so a given seed reproduces the same schedule.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_flight_id: int = 1
var _pad_lzs: Array = []
var _pads_resolved: bool = false


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_sim_event")
		if not SimClock.sim_event.is_connected(cb):
			SimClock.sim_event.connect(cb)
	_seed_default_schedule()


## One transit per sim-hour across the daylight span, plus four firebase resupply cycles.
## At the default 60x clock that is a movement every ~60s of wall time. Each movement is a
## FORMATION, not a ship (FORMATION_SIZES: 6-9 Hueys, 3-5 jets), so a single booking can put
## nine airframes up - the combat-load gate below is what keeps that off a fighting frame.
func _seed_default_schedule() -> void:
	if SimClock == null:
		return
	var kinds: Array = FLIGHT_SCENES.keys()
	kinds.append("spectre")
	for h in range(6, 24):
		# Movements PER daylight hour. One booking left ~60s of empty sky between packs at
		# the 60x clock, which reads as a quiet AO rather than a war. Safe to raise only
		# because the combat-load gate now holds these back off a fighting frame - do not
		# raise it further without re-measuring (PERF_LEDGER: this project is call-bound).
		for slot in range(TRANSITS_PER_HOUR):
			var kind: String = String(kinds[rng.randi() % kinds.size()])
			var at_h: float = float(h) + (float(slot) / float(TRANSITS_PER_HOUR))
			# day -1 = every day: booked against the boot day only, the whole sky
			# died at the first midnight rollover (13.5 real minutes at the 60x clock).
			SimClock.schedule_event(-1, at_h, &"air_traffic",
				{"kind": kind, "profile": "transit"})
	for h in [7, 11, 15, 19]:
		var kind: String = String(ROTARY[rng.randi() % ROTARY.size()])
		SimClock.schedule_event(-1, float(h) + 0.5, &"air_traffic",
			{"kind": kind, "profile": "lz_cycle"})


func _on_sim_event(kind: StringName, payload: Dictionary) -> void:
	if kind != &"air_traffic":
		return
	var flight_kind: String = String(payload.get("kind", "huey"))
	if String(payload.get("profile", "transit")) == "lz_cycle":
		_dispatch_lz_cycle(flight_kind)
	else:
		_dispatch(flight_kind)


## ---- THE COMBAT-LOAD GATE (Summoner, 2026-07-30) ----
## "if theres too much ai or computer usage being given to combat AI etc that means there
## isnt a reason to fill the space with ambient air stuff. The player is more than likely
## engaged in a huge fight... so only do a very small number of fly by units or just wait
## til the AI useage drops down and its not as taxing."
##
## Ambient air is ATMOSPHERE. A firefight is the GAME. When the two compete for the frame,
## the firefight wins - and the atmosphere is not even missed, because a man being shot at
## is not watching the horizon.
##
## Two signals, deliberately: the fight is the CAUSE and the frame time is the EFFECT, and
## either alone lies. Counting bodies misses a cheap frame ruined by something else; frame
## time alone throttles the sky on a slow machine that is doing nothing, which would leave
## the AO permanently empty on the Intel-UHD floor (ADR-026) - the opposite of the ask.
enum Load { CLEAR, BUSY, SATURATED }

## Live enemies who are actually FIGHTING, not merely spawned. A populated AO carries
## dozens of men asleep in camps; they cost almost nothing and must not gate anything.
const BUSY_FIGHTERS: int = 8
const SATURATED_FIGHTERS: int = 20
## Main-thread milliseconds. The Intel-UHD floor runs ~19-23fps both-bound (ADR-026), so
## these are ABOVE the normal cost of a quiet frame there - a slow machine idling stays CLEAR.
const BUSY_PROCESS_MS: float = 26.0
const SATURATED_PROCESS_MS: float = 38.0
## Load is sampled on a clock, not per call: walking two rosters every dispatch would make
## the gate its own cost.
const LOAD_SAMPLE_S: float = 1.5

var _load: Load = Load.CLEAR
var _load_timer: float = 0.0
## A transit the gate turned away. ONE is held and retried, which is the "wait til the AI
## usage drops" half of the ask - a dropped flight is silence, a held one is a late arrival.
var _deferred_kind: String = ""
var _gate_reported: Load = Load.CLEAR


func _sample_load() -> void:
	var fighters: int = 0
	for e in AgentRegistry.enemies:
		var man := e as EnemyBase
		if man == null or not is_instance_valid(man) or man.is_dead():
			continue
		# `target != null` is the honest test for "engaged": a man walking a patrol route
		# costs a think and nothing else.
		if man.target != null or man.alert_tier >= EnemyBase.AlertTier.ALERT:
			fighters += 1
	for a in AgentRegistry.allies:
		var ally := a as AllyBase
		if ally != null and is_instance_valid(ally) and not ally.is_dead() and ally.target != null:
			fighters += 1
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var tier: Load = Load.CLEAR
	if fighters >= SATURATED_FIGHTERS or process_ms >= SATURATED_PROCESS_MS:
		tier = Load.SATURATED
	elif fighters >= BUSY_FIGHTERS or process_ms >= BUSY_PROCESS_MS:
		tier = Load.BUSY
	_load = tier
	if tier != _gate_reported:
		_gate_reported = tier
		print("[AIR] load %s - %d fighting, %.1fms process%s" % [
			Load.keys()[int(tier)], fighters, process_ms,
			"" if tier == Load.CLEAR else " - ambient air thinned"])


func _tick_load(delta: float) -> void:
	_load_timer -= delta
	if _load_timer > 0.0:
		return
	_load_timer = LOAD_SAMPLE_S
	_sample_load()
	# The fight has eased: fly the one we held back rather than losing it.
	if _load == Load.CLEAR and _deferred_kind != "":
		var kind: String = _deferred_kind
		_deferred_kind = ""
		print("[AIR] load cleared - flying the held %s" % kind)
		_dispatch(kind)


## PUT A FLIGHT UP NOW. The schedule books one movement per sim-hour, which is right for a
## campaign AO and wrong for the first thirty seconds of a demo - the Summoner's ship gate asks
## for "constant movement of the choppers" and "scope and spectacle right away". A caller that
## owns an ARC (DemoGame) drives the sky directly through here rather than waiting on the clock.
##
## Deliberately NOT a second scheduler: this is the same _dispatch the sim event calls, so
## formations, routes, the flight roster and the MAX_FLIGHT_SECONDS reaper all still apply.
func launch(flight_kind: String, profile: String = "transit", ships: int = 0,
		finale: bool = false) -> void:
	match profile:
		"lz_cycle":
			_dispatch_lz_cycle(flight_kind)
		"gun_orbit":
			_dispatch_gun_orbit(flight_kind, ships, finale)
		_:
			_dispatch(flight_kind, ships)


## ---------- THE GUN ORBIT (the demo's last image) ----------
##
## A flight of gunships circling the wire with the door guns working. There was NO rotary
## orbit in this file - `transit` crosses and leaves, `lz_cycle` lands, and the only thing
## that circled was SpectreGunship, which is a FIXED-WING kind. So the ending had no shape
## to fly.
##
## The circle is flown as WAYPOINTS, not as a parametric curve, because Helicopter already
## knows how to fly to a point and go IDLE on arrival (`helicopter.gd:210-236`). Handing it
## the next point each time it settles reuses the whole existing flight model - speed
## ramping, altitude lerp, yaw lerp - instead of a second movement system that would drift
## out of sync with the first.
const ORBIT_RADIUS_M: float = 130.0
const ORBIT_ALTITUDE_M: float = 45.0
## Twelve waypoints: at 130m that is a ~68m chord, comfortably past the 4m arrival gate and
## short enough that the yaw lerp reads as a bank rather than a series of turns.
const ORBIT_WAYPOINTS: int = 12
const ORBIT_SECONDS: float = 75.0
## Inbound from here, not from the map edge: the whole sortie - run in, orbit, run out - has
## to finish inside MAX_FLIGHT_SECONDS or the reaper deletes the gunships mid-shot.
const ORBIT_INBOUND_M: float = 330.0
## The FINALE pair enters from here instead (his ruling 2026-08-04, Q2): the freeze waits
## for ships on station, so the run-in must be seconds, not a scene of its own.
const ORBIT_FINALE_INBOUND_M: float = 200.0
## Ships in the flight. Two reads as a pair working; the ceiling still binds -
## except for the finale pair, a priced one-time overspend (decree 2026-08-04, W-5).
const ORBIT_SHIPS: int = 2
## NO DOOR GUN IN CODE. Ruled by Caleb 2026-08-04, mid-build: "dont build the gun... im
## going to stage that in a heuy eventually. i just want that idea to be there."
##
## So the ORBIT is the deliverable and the gunner is ART, staged in the Huey on his bench
## later. Nothing here fires, and that is correct rather than unfinished: the huey.tscn
## carries no gunner rig, so a firing door gun today would be rounds leaving an empty
## doorway. When the staged gunner lands, the hook is this phase - the ship is already
## flying a stable circle at a fixed radius and altitude with its nose on the tangent.


## `centre` defaults to the firebase. Ships are staggered around the circle so they never
## overlap and never fire from the same bearing.
func _dispatch_gun_orbit(kind: String, ships: int = 0, finale: bool = false) -> void:
	var world := _world()
	if world == null:
		return
	var centre: Vector3 = _fsb_center()
	if centre == Vector3.ZERO:
		_dispatch(kind, ships)
		return
	var count: int = ships if ships > 0 else ORBIT_SHIPS
	var inbound_m: float = ORBIT_FINALE_INBOUND_M if finale else ORBIT_INBOUND_M
	for i in range(count):
		# The finale pair is exempt from the ceiling (ruled 2026-08-04, Q2/W-5): a full
		# sky at minute 30 must not zero the demo's last image. Priced once, at the freeze.
		if not finale and _in_flight.size() >= MAX_IN_FLIGHT:
			print("[AIR] gun orbit cut to %d of %d - ceiling %d reached"
				% [i, count, MAX_IN_FLIGHT])
			return
		var craft := _instance(kind)
		var heli := craft as Helicopter if craft != null else null
		if heli == null:
			if craft != null:
				craft.free()
			continue
		world.add_child(heli)
		heli.add_to_group("air_traffic")
		heli.cruise_altitude = ORBIT_ALTITUDE_M
		heli.setup(_terrain())
		# Each ship enters on its own bearing and holds its own slot on the circle, so the
		# pair reads as two aircraft working a problem rather than one bird cloned.
		var entry: float = rng.randf_range(0.0, TAU) + TAU * float(i) / float(count)
		var slot: float = entry + PI      # arrive at the far side, having flown across
		var inbound: Vector3 = centre + Vector3(cos(entry), 0.0, sin(entry)) * inbound_m
		inbound.y = _ground_at(inbound) + ORBIT_ALTITUDE_M
		heli.global_position = inbound
		var first: Vector3 = _orbit_point(centre, slot)
		_roster(kind, heli, inbound, first, "orbit_in")
		var f: Dictionary = _in_flight[_in_flight.size() - 1]
		f["orbit_centre"] = centre
		f["orbit_angle"] = slot
		f["orbit_until_ms"] = 0
		var out_ang: float = rng.randf_range(0.0, TAU)
		f["exit"] = centre + Vector3(cos(out_ang), 0.0, sin(out_ang)) * _map_size() * 0.55
		heli.fly_to(first)
	print("[AIR] gun orbit: %d %s on station at %.0fm" % [count, kind, ORBIT_RADIUS_M])


func _orbit_point(centre: Vector3, angle: float) -> Vector3:
	var p: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * ORBIT_RADIUS_M
	p.y = _ground_at(p) + ORBIT_ALTITUDE_M
	return p


func _fsb_center() -> Vector3:
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	if d != null and "fsb_center" in d:
		return d.get("fsb_center") as Vector3
	return Vector3.ZERO


## Walk the circle, then leave. Called from _advance_cycle on the roster's own clock.
func _advance_orbit(f: Dictionary, heli: Helicopter, now: int) -> void:
	var centre: Vector3 = f.get("orbit_centre", Vector3.ZERO)
	match String(f.get("phase", "")):
		"orbit_in":
			if heli.state != Helicopter.State.IDLE:
				return
			f["phase"] = "orbit"
			f["orbit_until_ms"] = now + int(ORBIT_SECONDS * 1000.0)
			_step_orbit(f, heli, centre)
		"orbit":
			if now >= int(f.get("orbit_until_ms", now)):
				f["phase"] = "outbound"
				var exit_pos: Vector3 = f.get("exit", f["dest"])
				f["dest"] = exit_pos
				heli.fly_to(exit_pos)
				return
			if heli.state == Helicopter.State.IDLE:
				_step_orbit(f, heli, centre)


func _step_orbit(f: Dictionary, heli: Helicopter, centre: Vector3) -> void:
	var angle: float = float(f.get("orbit_angle", 0.0)) + TAU / float(ORBIT_WAYPOINTS)
	f["orbit_angle"] = angle
	var next: Vector3 = _orbit_point(centre, angle)
	f["dest"] = next
	heli.fly_to(next)


## True while any flight is walking the orbit circle. The demo's end freeze waits on this
## so the gunships are IN the frozen frame (his ruling 2026-08-04, Q2).
func orbit_on_station() -> bool:
	for f in _in_flight:
		if String((f as Dictionary).get("phase", "")) == "orbit":
			return true
	return false


## How many airframes are in the sky right now. The demo's air package reads this before adding
## more: spectacle is the goal, but this project is call-bound (PERF_LEDGER) and an unbounded
## sky is the cheapest way to spend the frame budget by accident.
func flights_in_air() -> int:
	return _in_flight.size()


## Clear of the compound AND its beaten zone: SpectreGunship orbits at ORBIT_RADIUS 160m and
## saturates a zone around its centre, so "just outside the wire" is still inside the guns.
const SPECTRE_KEEP_OUT_M: float = 420.0


## Centre of the friendly firebase, or ZERO when there is none (arena, bench, tests).
func _friendly_keep_out() -> Vector3:
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	if d is FieldDirector:
		return (d as FieldDirector).fsb_center
	return Vector3.ZERO


## The mission director, when this world has one. Mirrors _friendly_keep_out's lookup rather
## than caching a second reference to the same node.
func _friendly_director() -> FieldDirector:
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	return d as FieldDirector


## Everything an ambient orbit must stay off: the player first, then his firebase.
func _spectre_keep_outs() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if GameManager.player != null and is_instance_valid(GameManager.player):
		out.append((GameManager.player as Node3D).global_position)
	var base: Vector3 = _friendly_keep_out()
	if base != Vector3.ZERO:
		out.append(base)
	return out


func _world() -> Node3D:
	return get_parent() as Node3D


func _terrain() -> TerrainManager:
	var w := _world()
	return (w.get("terrain_manager") as TerrainManager) if w != null else null


## The AO occupies 0..map_size on both axes. Routes used to run -500..+500,
## which put three quarters of every flight path off the map entirely.
func _map_size() -> float:
	var w := _world()
	if w != null:
		var m: float = float(w.get("map_size"))
		if m > 1.0:
			return m
	return WorldConfig.MAP_SIZE


## A chord that crosses the AO: endpoints sit outside the map so the aircraft
## flies in, passes near the middle, and flies out.
## A transit line across the AO that does NOT cross the compound. The bearing is free; the
## LATERAL offset is what gets pushed, so a route still sweeps the whole map and only its
## closest approach to the firebase is constrained.
##
## Transits used to be blind to the base entirely - a random bearing through map centre with
## a +/-30% side offset, which put jets over the wire regularly. The Spooky orbit got its
## keep-out on 2026-07-29; ordinary traffic never did.
const TRANSIT_KEEP_OUT_M: float = 150.0


func _ao_route() -> Array:
	var m: float = _map_size()
	var centre := Vector3(m * 0.5, 0.0, m * 0.5)
	var ang: float = rng.randf_range(0.0, TAU)
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var side_dir := Vector3(-dir.z, 0.0, dir.x)
	var offset: float = rng.randf_range(-m * 0.30, m * 0.30)
	var base: Vector3 = _friendly_keep_out()
	if base != Vector3.ZERO:
		# Signed distance from the base to the flight line, measured along the side axis.
		var to_base: Vector3 = base - centre
		var base_off: float = to_base.dot(side_dir)
		var miss: float = absf(offset - base_off)
		if miss < TRANSIT_KEEP_OUT_M:
			# Push out on whichever side it was already leaning, so the bearing is unchanged
			# and the flight still crosses the map.
			var away: float = 1.0 if offset >= base_off else -1.0
			offset = base_off + away * TRANSIT_KEEP_OUT_M
			offset = clampf(offset, -m * 0.45, m * 0.45)
	var side: Vector3 = side_dir * offset
	var half: float = m * 0.75
	return [centre + side - dir * half, centre + side + dir * half]


func _ground_at(p: Vector3) -> float:
	var t := _terrain()
	return t.get_height_at(p) if t != null else 0.0


func _dispatch(kind: String, force_ships: int = 0) -> void:
	# SATURATED: hold it and fly it when the fight eases. Only the most recent is kept -
	# a queue would dump six flights into the sky the moment the shooting stops.
	if _load == Load.SATURATED:
		_deferred_kind = kind
		print("[AIR] %s held - combat load SATURATED" % kind)
		return
	# The ceiling is enforced HERE so it binds every caller. DemoGame checked
	# flights_in_air() before its own launches, but the sim schedule never did, so a
	# campaign AO had no ceiling at all - and one booking is now a 6-9 ship pack.
	if _in_flight.size() >= MAX_IN_FLIGHT:
		return
	var route: Array = _ao_route()
	var from: Vector3 = route[0]
	var to: Vector3 = route[1]
	var node: Node3D = _spawn_transit(kind, from, to)
	if node == null:
		return
	_roster(kind, node, from, to, "transit")
	var frng: RandomNumberGenerator = _event_rng(kind)
	var ships: int = _ship_count(kind, frng, force_ships)
	if ships <= 1:
		return
	var dir: Vector3 = (to - from).normalized()
	var side: Vector3 = Vector3(-dir.z, 0.0, dir.x) * (1.0 if frng.randf() < 0.5 else -1.0)
	for i in range(1, ships):
		# THE CEILING BINDS EVERY SHIP, NOT JUST THE LEAD. It used to be checked once,
		# above, and then up to eight wingmen were added unchecked - so a dispatch at
		# MAX_IN_FLIGHT - 1 could put 22 airframes up against a ceiling of 14, on a
		# call-bound project. The pack size is what he asked for; the ceiling is what
		# pays for it, and a truncated pack is the honest lever.
		if _in_flight.size() >= MAX_IN_FLIGHT:
			print("[AIR] %s pack cut to %d of %d - ceiling %d reached"
				% [kind, i, ships, MAX_IN_FLIGHT])
			return
		var off: Vector3 = side * (frng.randf_range(ECHELON_LATERAL_M.x, ECHELON_LATERAL_M.y) * float(i)) \
			- dir * (frng.randf_range(ECHELON_TRAIL_M.x, ECHELON_TRAIL_M.y) * float(i))
		var wing: Node3D = _spawn_transit(kind, from + off, to + off,
			frng.randf_range(ECHELON_ALT_M.x, ECHELON_ALT_M.y) * float(i))
		if wing != null:
			_roster(kind, wing, from + off, to + off, "transit")


## The transit schedule payload carries no seed, so a wingman roll derives its
## RNG from the sim calendar + kind (ADR-010: never the global RNG).
func _event_rng(kind: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	var day: int = SimClock.sim_day if SimClock != null else 1
	var hour: int = int(SimClock.sim_hour) if SimClock != null else 0
	r.seed = hash("%d:%d:%s" % [day, hour, kind])
	return r


## force_ships is a test hook; it still cannot form up a solo-only kind.
func _ship_count(kind: String, frng: RandomNumberGenerator, force_ships: int) -> int:
	if not FORMATION_SIZES.has(kind):
		return 1
	# BUSY: "only do a very small number of fly by units." A nine-ship lift is nine sets of
	# rotor meshes, animation and audio; one ship still says the war is bigger than this
	# firefight, which is the whole job of ambient air. This outranks force_ships, because
	# the demo's authored packs are exactly what must thin when the wire is being hit.
	if _load == Load.BUSY:
		return 1
	var band: Array = FORMATION_SIZES[kind]
	if force_ships > 0:
		return clampi(force_ships, 1, int(band[1]))
	if frng.randf() >= FORMATION_CHANCE:
		return 1
	return frng.randi_range(int(band[0]), int(band[1]))


func _roster(kind: String, node: Node3D, from: Vector3, to: Vector3, phase: String) -> int:
	var id: int = _next_flight_id
	_next_flight_id += 1
	_in_flight.append({
		"id": id,
		"kind": kind,
		"node": node,
		"route": [from, to],
		"dest": to,
		"exit": to,
		"pos": from,
		"phase": phase,
		"born_ms": Time.get_ticks_msec(),
		"phase_ms": Time.get_ticks_msec(),
		"spawned": true,
	})
	return id


## Put a real aircraft in the sky. Returns null when the kind has no way to fly.
func _spawn_transit(kind: String, from: Vector3, to: Vector3, alt_bonus: float = 0.0) -> Node3D:
	var world := _world()
	if world == null:
		return null
	var terrain := _terrain()
	if kind == "spectre":
		# The orbit centre is the route midpoint, and a SpectreGunship is not scenery: it
		# pours 60-damage Vulcan and 120-damage Bofors into that point for 30 seconds. A
		# random midpoint can land on the firebase, and on 2026-07-29 it did - Spooky firing
		# directly into the player's own base. Ambient air is atmosphere; live guns on the
		# compound come from the player's fire mission (field_director), never from a
		# scheduled flight. Push the orbit off the base rather than cancelling the sortie -
		# a gun run on the treeline IS the atmosphere this event exists for.
		# The PLAYER is kept out of too, not just his base. The base keep-out only guards
		# the compound, so a patrol two hundred metres into the jungle was still standing
		# in an ambient beaten zone - and his ruling of 2026-07-30 is that nothing gun-runs
		# where he is unless he called it. Applied in order; the base wins ties by going last.
		var centre: Vector3 = (from + to) * 0.5
		for keep_out in _spectre_keep_outs():
			var off: Vector3 = centre - keep_out
			off.y = 0.0
			if off.length() < SPECTRE_KEEP_OUT_M:
				if off.length() < 1.0:
					off = Vector3(1.0, 0.0, 0.0)
				centre = keep_out + off.normalized() * SPECTRE_KEEP_OUT_M
				centre.x = clampf(centre.x, 40.0, _map_size() - 40.0)
				centre.z = clampf(centre.z, 40.0, _map_size() - 40.0)
		centre.y = _ground_at(centre)
		return SpectreGunship.call_in(world, terrain, centre)
	var craft := _instance(kind)
	if craft == null:
		return null
	world.add_child(craft)
	craft.add_to_group("air_traffic")
	if craft is Helicopter:
		var heli := craft as Helicopter
		heli.cruise_altitude += alt_bonus
		var start := from
		start.y = _ground_at(from) + heli.cruise_altitude
		craft.global_position = start
		heli.setup(terrain)
		heli.fly_to(to)
	elif craft is CASAirplane:
		var profile: Dictionary = FIXED_WING.get(kind, {"agl": 80.0, "speed": 180.0})
		var agl: float = float(profile["agl"]) + alt_bonus
		var start := from
		start.y = _ground_at(from) + agl
		craft.global_position = start
		(craft as CASAirplane).call_transit(terrain, start, to,
			agl, float(profile["speed"]))
	return craft


func _instance(kind: String) -> Node3D:
	if not FLIGHT_SCENES.has(kind):
		return null
	var packed := load(String(FLIGHT_SCENES[kind])) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


## ---------- firebase landing cycle ----------

## LandingZones for the authored firebase pads, created once on first need.
## The pads are real nodes inside fsb_main.glb, so their positions are read,
## never guessed.
func _firebase_lzs() -> Array:
	if _pads_resolved:
		return _pad_lzs
	_pads_resolved = true
	var world := _world()
	if world == null:
		return _pad_lzs
	var fsb: Node3D = null
	for c in world.get_children():
		var n := c as Node3D
		if n != null and (String(n.get_meta("model_name", "")) == "fsb_main" or n.name == "fsb_main"):
			fsb = n
			break
	if fsb == null:
		return _pad_lzs
	var pads: Array[Node3D] = []
	var stack: Array[Node] = [fsb]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c2 in nd.get_children():
			stack.append(c2)
		var n3 := nd as Node3D
		if n3 == null or n3 == fsb:
			continue
		for prefix in FSB_PAD_PREFIXES:
			if String(n3.name).begins_with(prefix):
				pads.append(n3)
				break
	pads.sort_custom(func(x: Node3D, y: Node3D) -> bool: return String(x.name) < String(y.name))
	for pad in pads:
		# Co-located markers are ONE pad wearing three names. Landing a second bird on a
		# square metre already occupied is worse than making it wait for the pad to clear.
		var duplicate: bool = false
		for existing in _pad_lzs:
			var e := existing as LandingZone
			if e != null and e.global_position.distance_to(pad.global_position) < PAD_DISTINCT_M:
				duplicate = true
				break
		if duplicate:
			print("[AIR] pad marker %s is co-located with a live pad - ignored" % pad.name)
			continue
		var lz := LandingZone.new()
		lz.lz_name = String(pad.name)
		lz.lz_radius = 7.0
		lz.capacity = 1
		world.add_child(lz)
		lz.global_position = pad.global_position
		_pad_lzs.append(lz)
	if _pad_lzs.is_empty():
		push_warning("[AirTraffic] firebase carries no pad marker matching %s - no bird can land"
			% str(FSB_PAD_PREFIXES))
	return _pad_lzs


func _free_pad() -> LandingZone:
	for l in _firebase_lzs():
		var lz := l as LandingZone
		if lz != null and is_instance_valid(lz) and lz.can_land():
			return lz
	return null


## Fly in from the AO edge, land on a firebase pad, sit, then lift and depart.
## Falls back to a plain overflight when the base has no reachable pad.
func _dispatch_lz_cycle(kind: String) -> void:
	var lz := _free_pad()
	if lz == null:
		_dispatch(kind)
		return
	var craft := _instance(kind)
	var world := _world()
	if craft == null or world == null:
		return
	var heli := craft as Helicopter
	if heli == null:
		craft.free()
		_dispatch(kind)
		return
	world.add_child(heli)
	heli.add_to_group("air_traffic")
	var m: float = _map_size()
	var ang: float = rng.randf_range(0.0, TAU)
	var inbound := lz.global_position + Vector3(cos(ang), 0.0, sin(ang)) * m * 0.55
	inbound.y = _ground_at(inbound) + heli.cruise_altitude
	heli.global_position = inbound
	heli.setup(_terrain())
	# A LANDING SHIP CARRIES SOMETHING. Every seat function in SeatSystem had zero production
	# callers, so a Huey used to land on the pad, idle out its ground seconds and leave empty -
	# the ship-gate clause "Huey landings with troops disembarking" was scenery. HeliLift decides
	# at dispatch whether this sortie is replacements in or men out, and loads it accordingly.
	HeliLift.attach(heli, _friendly_director())
	_roster(kind, heli, inbound, lz.global_position, "inbound")
	var f: Dictionary = _in_flight[_in_flight.size() - 1]
	var out_ang: float = rng.randf_range(0.0, TAU)
	f["exit"] = lz.global_position + Vector3(cos(out_ang), 0.0, sin(out_ang)) * m * 0.55
	heli.fly_to(lz.global_position, lz)


## Advance a landing cycle through its phases. The roster is the only clock:
## no timer node, no second scheduler.
func _advance_cycle(f: Dictionary, heli: Helicopter, now: int) -> void:
	var phase: String = String(f.get("phase", ""))
	if phase == "orbit_in" or phase == "orbit":
		_advance_orbit(f, heli, now)
		return
	match phase:
		"inbound":
			if heli.state == Helicopter.State.LANDED:
				f["phase"] = "ground"
				f["phase_ms"] = now
		"ground":
			if float(now - int(f.get("phase_ms", now))) / 1000.0 >= GROUND_SECONDS:
				heli.take_off()
				f["phase"] = "climbout"
		"climbout":
			if heli.state == Helicopter.State.IDLE:
				var exit_pos: Vector3 = f.get("exit", f["dest"])
				f["dest"] = exit_pos
				f["phase"] = "outbound"
				heli.fly_to(exit_pos)


## Retire arrived and over-age flights. The roster only ever appended, so a long
## mission grew it without bound and every entry held a live aircraft.
func _process(delta: float) -> void:
	_tick_load(delta)
	var now: int = Time.get_ticks_msec()
	for i in range(_in_flight.size() - 1, -1, -1):
		var f: Dictionary = _in_flight[i]
		# Validate BEFORE anything else: on a freed instance even `is` throws, so
		# is_instance_valid must run FIRST (crashed the 07-29 demo playtest).
		var raw: Variant = f.get("node")
		var node: Node3D = raw as Node3D if (is_instance_valid(raw) and raw is Node3D) else null
		var alive: bool = node != null
		var age_s: float = float(now - int(f.get("born_ms", now))) / 1000.0
		var arrived: bool = false
		if alive:
			var heli := node as Helicopter
			if heli != null and String(f.get("phase", "")) != "transit":
				_advance_cycle(f, heli, now)
			f["pos"] = node.global_position
			var dest: Vector3 = f.get("dest", (f["route"] as Array)[1])
			# "orbit_in"/"orbit" MUST be here. An orbiting ship is permanently within 20m of
			# its current waypoint by design, so without this the reaper deletes the flight
			# on its first arrival and the gunships vanish one lap in.
			var settled: bool = String(f.get("phase", "")) in \
				["inbound", "ground", "climbout", "orbit_in", "orbit"]
			# Horizontal only: destinations are ground-plane points and the
			# aircraft is at cruise, so a 3D compare never reaches the gate.
			var flat: float = Vector2(node.global_position.x - dest.x,
				node.global_position.z - dest.z).length()
			arrived = not settled and flat < 20.0
		var vanished: bool = bool(f.get("spawned", false)) and not alive
		if arrived or vanished or age_s > MAX_FLIGHT_SECONDS:
			if alive:
				node.queue_free()
			_in_flight.remove_at(i)


func get_in_flight() -> Array:
	return _in_flight
