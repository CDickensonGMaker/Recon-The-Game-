## air_traffic.gd - scheduler for the sim's air traffic. Listens to
## SimClock.sim_event(kind=&"air_traffic") and dispatches a helicopter or
## placeholder for the flight. Owns the in-flight roster.
##
## Default seed: 1 flyover per 2 sim-hours, mix of Huey (cargo), Spooky
## (gunship orbit), Chinook (formation), C-130 (high altitude). Random
## routes from one AO edge to another.
class_name AirTraffic
extends Node

## In-flight roster. {id, kind, model, route, pos, phase, scheduled_remove_ms}.
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
		"route": [from, to],
		"pos": from,
		"phase": "flying",
		"scheduled_remove_ms": -1,
	})
	# Note: instantiation of the actual model is left to the world initializer.
	# AirTraffic here is the SCHEDULER + the roster; the world reads `_in_flight`
	# and materializes entities as needed.


func get_in_flight() -> Array:
	return _in_flight
