## terrain_watchdog.gd - Re-seats any body that fell through terrain (NS09).
class_name TerrainWatchdog
extends Node

const POLL_SECONDS: float = 2.0
const UNDER_DEPTH: float = 5.0

var terrain: TerrainManager
var _timer: float = 0.0


func setup(terrain_manager: TerrainManager) -> void:
	terrain = terrain_manager


func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	_timer += delta
	if _timer < POLL_SECONDS:
		return
	_timer = 0.0
	for group in ["enemies", "allies"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody3D
			if body == null or not is_instance_valid(body):
				continue
			var ground_y: float = terrain.get_height_at(body.global_position)
			if body.global_position.y < ground_y - UNDER_DEPTH:
				body.global_position.y = ground_y + 0.5
				body.velocity = Vector3.ZERO
