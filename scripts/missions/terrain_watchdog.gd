## terrain_watchdog.gd - Re-seats fallen bodies (NS09) AND suspends distant
## NPCs entirely (PT-perf): past 240m nothing sees or hears you anyway, so
## far actors get physics+brain frozen until you close in.
class_name TerrainWatchdog
extends Node

const POLL_SECONDS: float = 2.0
const UNDER_DEPTH: float = 5.0
const SUSPEND_DIST: float = 240.0
const RESUME_DIST: float = 210.0  # hysteresis

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
	var player := GameManager.player as Node3D
	for group in ["enemies", "allies", "civilians"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody3D
			if body == null or not is_instance_valid(body):
				continue
			if body.has_method("is_dead") and body.is_dead():
				continue
			# Distance suspension (allies exempt - they follow orders far).
			if player != null and group != "allies":
				var dist: float = body.global_position.distance_to(player.global_position)
				var suspended: bool = body.has_meta("suspended")
				if not suspended and dist > SUSPEND_DIST:
					body.set_meta("suspended", true)
					body.set_physics_process(false)
					body.visible = false
					continue
				elif suspended and dist < RESUME_DIST:
					body.remove_meta("suspended")
					body.set_physics_process(true)
					body.visible = true
					body.global_position.y = terrain.get_height_at(body.global_position) + 0.5
				elif suspended:
					continue
			# Fall-through re-seat.
			var ground_y: float = terrain.get_height_at(body.global_position)
			if body.global_position.y < ground_y - UNDER_DEPTH:
				body.global_position.y = ground_y + 0.5
				body.velocity = Vector3.ZERO
