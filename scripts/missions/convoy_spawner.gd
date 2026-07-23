## convoy_spawner.gd - SimClock-driven convoy producer. Owns a queue of pending
## convoys (kind, route, spawn-time). On SimClock.hour_advanced, pops any that
## are due and instantiates them in the world.
class_name ConvoySpawner
extends Node

## Pending: {day, hour, kind, route: Array[Vector3], vehicle_models: Array[String]}
var _queue: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Planned ambush sites (from MissionGenerator's plan). A convoy that drives into one
## reports contact - this is how a planned ambush becomes a live event rather than a
## set of men standing in a bush.
var ambush_sites: Array = []
## How close a convoy must come to a planned ambush site to spring it, in meters.
const AMBUSH_TRIGGER_M: float = 45.0

const VEHICLE_MODEL_DIR: String = "res://assets/us/vehicles/"


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
	cv.speed = 12.0 if spec.kind == "truck" else 8.0
	world.add_child(cv)
	var terrain: TerrainManager = null
	if world is GameWorld:
		terrain = (world as GameWorld).terrain_manager
	cv.terrain = terrain
	# A convoy with no vehicles cannot drive: Convoy._physics_process returns early on
	# an empty list, so it would never reach a waypoint or finish a route.
	var built: Array = []
	var start: Vector3 = route[0]
	var heading: Vector3 = (route[1] - route[0])
	var yaw: float = rad_to_deg(atan2(heading.x, heading.z))
	for i in range(spec.vehicle_models.size()):
		var model_path: String = VEHICLE_MODEL_DIR + str(spec.vehicle_models[i]) + ".glb"
		if not ResourceLoader.exists(model_path):
			continue
		var back: Vector3 = -heading.normalized() * (float(i) * 6.0)
		var v := DestructibleVehicle.create(cv, model_path, start + back, yaw, terrain)
		if v == null:
			continue
		# A convoy vehicle MOVES. Leaving it in nav_blockers would drag a nav-carving
		# static body across the world every frame; the navmesh was baked at world
		# build, long before this convoy existed.
		v.remove_from_group("nav_blockers")
		built.append(v)
	if built.is_empty():
		cv.queue_free()
		return
	cv.setup(route, built)
	cv.route_finished.connect(_on_route_finished)
	cv.waypoint_reached.connect(_on_waypoint_reached)
	# Wire the convoy's ambushed signal into the mission's DynamicMissionFactory
	# (created and stashed by MissionGenerator._wire_systems).
	# The function lives on MissionGenerator as a static helper, so we call it
	# by the script preload to avoid the class_name resolution hazard at parse.
	var mg_script: GDScript = load("res://scripts/missions/mission_generator.gd")
	if mg_script != null and mg_script.has_method("_wire_convoy_to_factory"):
		mg_script.call("_wire_convoy_to_factory", cv)


## The convoy reached the end of its road. It has left the AO - take it off the map
## rather than leaving trucks parked at the map edge forever.
func _on_route_finished(convoy: Convoy) -> void:
	if convoy != null and is_instance_valid(convoy):
		convoy.queue_free()


## Each waypoint is the natural cadence to ask whether the convoy has driven into a
## planned ambush. This is the link that makes an ambush site a live event: it gives
## Convoy.report_contact its caller, which fires `ambushed`, which reaches
## DynamicMissionFactory._on_convoy_ambushed and raises the crisis the player hears
## on the radio.
func _on_waypoint_reached(convoy: Convoy) -> void:
	if convoy == null or not is_instance_valid(convoy):
		return
	if convoy.vehicles.is_empty() or not is_instance_valid(convoy.vehicles[0]):
		return
	var lead: Node3D = convoy.vehicles[0]
	for site in ambush_sites:
		var sd: Dictionary = site
		var trigger: Vector3 = sd.get("trigger_pos", Vector3.ZERO)
		if trigger == Vector3.ZERO:
			continue
		if lead.global_position.distance_to(trigger) <= AMBUSH_TRIGGER_M:
			convoy.report_contact(self, trigger)
			return
