## convoy_spawner.gd - SimClock-driven convoy producer. Owns a queue of pending
## convoys (kind, route, spawn-time). On SimClock.hour_advanced, pops any that
## are due and instantiates them in the world.
class_name ConvoySpawner
extends Node

## Pending: {day, hour, kind, route: Array[Vector3], vehicle_models: Array[String]}
var _queue: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_hour_advanced")
		if not SimClock.hour_advanced.is_connected(cb):
			SimClock.hour_advanced.connect(cb)


## Schedule a convoy to spawn at the given sim-time.
func schedule(day: int, hour: float, kind: String, route: Array, vehicle_models: Array) -> void:
	_queue.append({
		"day": day,
		"hour": hour,
		"kind": kind,
		"route": route,
		"vehicle_models": vehicle_models,
	})


func _on_hour_advanced(_sim_hour: int) -> void:
	_spawn_due()


func _spawn_due() -> void:
	if SimClock == null:
		return
	var cur_day: int = SimClock.sim_day
	var cur_hour: int = int(SimClock.sim_hour)
	var kept: Array = []
	for s in _queue:
		var sd: int = int(s.day)
		var sh: int = int(s.hour)
		var match: bool = sd == -1 or sd == cur_day
		if match and sh == cur_hour:
			_instantiate(s)
		else:
			kept.append(s)
	_queue = kept


func _instantiate(spec: Dictionary) -> void:
	# The world is a Node, not always passed in. We assume the parent is the world
	# (mission director adds ConvoySpawner as a child of world). If vehicles can't
	# be created, no-op; the spawner is best-effort.
	var world := get_parent()
	if world == null:
		return
	var route: Array = spec.route
	if route.size() < 2:
		return
	var cv := Convoy.new()
	cv.setup(route, [])
	cv.speed = 12.0 if spec.kind == "truck" else 8.0
	world.add_child(cv)
	# Wire the convoy's ambushed signal into the mission's DynamicMissionFactory
	# (created and stashed by MissionGenerator._wire_systems).
	# The function lives on MissionGenerator as a static helper, so we call it
	# by the script preload to avoid the class_name resolution hazard at parse.
	var mg_script: GDScript = load("res://scripts/missions/mission_generator.gd")
	if mg_script != null and mg_script.has_method("_wire_convoy_to_factory"):
		mg_script.call("_wire_convoy_to_factory", cv)
