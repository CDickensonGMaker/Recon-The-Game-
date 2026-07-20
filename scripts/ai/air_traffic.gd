## air_traffic.gd - scheduler for the sim's air traffic. Listens to
## SimClock.sim_event(kind=&"air_traffic") and dispatches a helicopter or
## placeholder for the flight. Owns the in-flight roster.
##
## Default seed: 1 flyover per 2 sim-hours, mix of Huey (cargo), Spooky
## (gunship orbit), Chinook (formation), C-130 (high altitude). Random
## routes from one AO edge to another.
class_name AirTraffic
extends Node

## Only the Huey has a flyable scene; the rest are roster-only until they get models.
const FLIGHT_SCENES := {"huey": "res://scenes/vehicles/huey.tscn"}
## A flight that never arrives is a leak. Nothing may outlive this.
const MAX_FLIGHT_SECONDS: float = 240.0
## How close a flight has to pass for the jungle to hear it.
const OVERHEAD_M: float = 120.0

## In-flight roster. {id, kind, node, route, pos, phase, born_ms}.
var _in_flight: Array = []
## Cached RNG so a given seed reproduces the same schedule.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_flight_id: int = 1


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_sim_event")
		if not SimClock.sim_event.is_connected(cb):
			SimClock.sim_event.connect(cb)
	# Seed default schedule: 1 flight per 2 sim-hours, mixed kinds.
	_seed_default_schedule()


## Seed 12 sim-hours of air-traffic events. Each is dispatched via SimClock.
func _seed_default_schedule() -> void:
	if SimClock == null:
		return
	var kinds: Array = ["huey", "spooky", "chinook", "c130"]
	for h in range(6, 24, 2):
		var kind: String = kinds[rng.randi() % kinds.size()]
		var payload: Dictionary = {
			"kind": kind,
			"hour": float(h),
		}
		SimClock.schedule_event(SimClock.sim_day, float(h), &"air_traffic", payload)


func _on_sim_event(kind: StringName, payload: Dictionary) -> void:
	if kind != &"air_traffic":
		return
	var flight_kind: String = String(payload.get("kind", "huey"))
	_dispatch(flight_kind)


func _dispatch(kind: String) -> void:
	# Pick a random route across the AO. The world boundary defaults to 1.28km
	# (mission generator default), so the flight goes from one side to the other
	# at a representative altitude. A real implementation would resolve the AO
	# bounds from the world; the placeholder picks ±500m.
	var altitude: float = 40.0
	match kind:
		"huey":
			altitude = 25.0
		"spooky":
			altitude = 15.0   # orbits low and slow
		"chinook":
			altitude = 35.0
		"c130":
			altitude = 120.0  # high altitude flyover
	var from: Vector3 = Vector3(-500, altitude, rng.randf_range(-500, 500))
	var to: Vector3 = Vector3(500, altitude, rng.randf_range(-500, 500))
	var id: int = _next_flight_id
	_next_flight_id += 1
	_in_flight.append({
		"id": id,
		"kind": kind,
		"node": _spawn_flight(kind, id, from, to),
		"route": [from, to],
		"pos": from,
		"phase": "flying",
		"born_ms": Time.get_ticks_msec(),
	})


## Put a real aircraft in the sky where a scene exists for the kind.
func _spawn_flight(kind: String, id: int, from: Vector3, to: Vector3) -> Node3D:
	var world := get_parent() as Node3D
	if world == null or not FLIGHT_SCENES.has(kind):
		return null
	var packed := load(String(FLIGHT_SCENES[kind])) as PackedScene
	if packed == null:
		return null
	var craft := packed.instantiate() as Node3D
	if craft == null:
		return null
	world.add_child(craft)
	craft.global_position = from
	craft.add_to_group("air_traffic")
	if craft is Helicopter:
		var heli := craft as Helicopter
		heli.traffic_flight_id = id
		heli.setup(world.get("terrain_manager") as TerrainManager)
		heli.fly_to(to)
	return craft


## Retire arrived and over-age flights. The roster only ever appended, so a long
## mission grew it without bound and every entry held a live aircraft.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for i in range(_in_flight.size() - 1, -1, -1):
		var f: Dictionary = _in_flight[i]
		var node := f.get("node") as Node3D
		var alive: bool = node != null and is_instance_valid(node)
		var age_s: float = float(now - int(f.get("born_ms", now))) / 1000.0
		var arrived: bool = false
		if alive:
			var dest: Vector3 = (f["route"] as Array)[1]
			f["pos"] = node.global_position
			arrived = node.global_position.distance_to(dest) < 20.0
		if arrived or age_s > MAX_FLIGHT_SECONDS or (node != null and not alive):
			if alive:
				node.queue_free()
			_in_flight.remove_at(i)


func get_in_flight() -> Array:
	return _in_flight
