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
## Pad markers inside the firebase GLB (measured: three 15x15m PSP pads).
## Matched by PREFIX, not by exact name: v2 authored PSPHelipad_001.._003 and the
## v3 re-export renamed them (PSPHelipad, fb_helipad_i, fb_helipad_i_182), which
## resolved to ZERO landing zones without anything failing to load. A Blender
## re-export renumbers nodes freely; the prefix is the contract.
const FSB_PAD_PREFIXES := ["PSPHelipad", "fb_helipad"]

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


## One transit per sim-hour across the daylight span, plus four firebase
## resupply cycles. At the default 60x clock that is a movement every ~60s of
## wall time and rarely more than two airframes up at once.
func _seed_default_schedule() -> void:
	if SimClock == null:
		return
	var kinds: Array = FLIGHT_SCENES.keys()
	kinds.append("spectre")
	for h in range(6, 24):
		var kind: String = String(kinds[rng.randi() % kinds.size()])
		SimClock.schedule_event(SimClock.sim_day, float(h), &"air_traffic",
			{"kind": kind, "profile": "transit"})
	for h in [7, 11, 15, 19]:
		var kind: String = String(ROTARY[rng.randi() % ROTARY.size()])
		SimClock.schedule_event(SimClock.sim_day, float(h) + 0.5, &"air_traffic",
			{"kind": kind, "profile": "lz_cycle"})


func _on_sim_event(kind: StringName, payload: Dictionary) -> void:
	if kind != &"air_traffic":
		return
	var flight_kind: String = String(payload.get("kind", "huey"))
	if String(payload.get("profile", "transit")) == "lz_cycle":
		_dispatch_lz_cycle(flight_kind)
	else:
		_dispatch(flight_kind)


## PUT A FLIGHT UP NOW. The schedule books one movement per sim-hour, which is right for a
## campaign AO and wrong for the first thirty seconds of a demo - the Summoner's ship gate asks
## for "constant movement of the choppers" and "scope and spectacle right away". A caller that
## owns an ARC (DemoGame) drives the sky directly through here rather than waiting on the clock.
##
## Deliberately NOT a second scheduler: this is the same _dispatch the sim event calls, so
## formations, routes, the flight roster and the MAX_FLIGHT_SECONDS reaper all still apply.
func launch(flight_kind: String, profile: String = "transit", ships: int = 0) -> void:
	if profile == "lz_cycle":
		_dispatch_lz_cycle(flight_kind)
	else:
		_dispatch(flight_kind, ships)


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
func _ao_route() -> Array:
	var m: float = _map_size()
	var centre := Vector3(m * 0.5, 0.0, m * 0.5)
	var ang: float = rng.randf_range(0.0, TAU)
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-dir.z, 0.0, dir.x) * rng.randf_range(-m * 0.30, m * 0.30)
	var half: float = m * 0.75
	return [centre + side - dir * half, centre + side + dir * half]


func _ground_at(p: Vector3) -> float:
	var t := _terrain()
	return t.get_height_at(p) if t != null else 0.0


func _dispatch(kind: String, force_ships: int = 0) -> void:
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
	match String(f.get("phase", "")):
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
func _process(_delta: float) -> void:
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
			var settled: bool = String(f.get("phase", "")) in ["inbound", "ground", "climbout"]
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
