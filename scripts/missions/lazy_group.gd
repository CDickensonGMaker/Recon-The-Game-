## lazy_group.gd - Dormant enemy group: spawns through the director when the
## player closes within activation range (NS09). RTCW dormant-population rule.
class_name LazyGroup
extends Node3D

@export var enemy_count: int = 3
@export var group_tag: String = ""
@export var activation_range: float = 120.0
@export var spread: float = 12.0
@export var data_paths: Array[String] = [
	"res://data/enemies/german_rifleman.tres",
	"res://data/enemies/german_smg.tres",
]

var director: MissionDirector
var _spawned: bool = false
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(mission_director: MissionDirector, rng_seed: int) -> void:
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
	for i in range(enemy_count):
		var a: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(2.0, spread)
		var pos := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var data: String = data_paths[_rng.randi() % data_paths.size()]
		var enemy := director.spawn_tracked_enemy(pos, data, group_tag)
		if not group_tag.is_empty():
			enemy.add_to_group(group_tag)
	set_physics_process(false)
