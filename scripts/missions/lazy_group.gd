## lazy_group.gd - Dormant enemy group: spawns through the director when the
## player closes within activation range.
class_name LazyGroup
extends Node3D

@export var enemy_count: int = 3
@export var group_tag: String = ""
@export var activation_range: float = 120.0
@export var spread: float = 12.0
## Route across the AO, handed down by the generator (ADR-021).
## Empty = fall back to a local 16m sentry beat.
var patrol_circuit: Array[Vector3] = []

@export var data_paths: Array[String] = [
	# Weighted by repetition: the pool is sampled uniformly, so a bare list of five
	# archetypes would put an RPG in one hand out of five. Local Force are the
	# bulk; the rocketeer is the exception you remember.
	"res://data/enemies/vc_farmer.tres",
	"res://data/enemies/vc_farmer.tres",
	"res://data/enemies/vc_farmer.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/vc_sapper.tres",
	"res://data/enemies/nva_rpg.tres",
]

var director: FieldDirector
## Camp-life payload, handed down by the generator. A garrison that wakes on
## approach stands up its own CampDirector so it keeps a schedule and a route
## instead of standing in the spawn ring for the rest of the patrol.
var work_stations: Array = []
var paddy_centroids: Array[Vector3] = []
var _spawned: bool = false
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("lazy_groups")


func setup(mission_director: FieldDirector, rng_seed: int) -> void:
	director = mission_director
	_rng.seed = rng_seed


func _physics_process(delta: float) -> void:
	if _spawned or director == null:
		return
	_timer += delta
	if _timer < 1.0:
		return
	_timer = 0.0
	var player := GameManager.player as Node3D
	if player == null:
		return
	if player.global_position.distance_to(global_position) > activation_range:
		return
	force_spawn()


func force_spawn() -> void:
	if _spawned:
		return
	_spawned = true
	# Ambient corridor patrols walk a route instead of standing put.
	var is_patrol := group_tag.begins_with("ambient_patrol")
	var route: Array[Vector3] = []
	if is_patrol:
		route = patrol_circuit.duplicate() if not patrol_circuit.is_empty() \
			else EnemyBase.make_patrol_route(global_position, _rng)
	var spawned_men: Array = []
	for i in range(enemy_count):
		var a: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(2.0, spread)
		var pos := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var data: String = data_paths[_rng.randi() % data_paths.size()]
		var enemy := director.spawn_tracked_enemy(pos, data, group_tag)
		spawned_men.append(enemy)
		if not group_tag.is_empty():
			enemy.add_to_group(group_tag)
		if is_patrol and not route.is_empty():
			enemy.patrol_route = route.duplicate()
			# SINGLE FILE: every man starts at _patrol_index 0, so one point man walks
			# the waypoint and the rest trail him down the leg by their file slot.
			enemy.patrol_file_slot = i
			enemy._patrol_index = 0
		elif not is_patrol:
			# A sentry faces OUTWARD from whatever he is posted on.
			var out: Vector3 = pos - global_position
			out.y = 0.0
			if out.length() > 0.5:
				enemy.facing_dir = out.normalized()
				enemy._home_facing = enemy.facing_dir
	if not is_patrol:
		CampDirector.attach(get_parent(), global_position, spawned_men,
			int(_rng.seed), work_stations, paddy_centroids)
	set_physics_process(false)
