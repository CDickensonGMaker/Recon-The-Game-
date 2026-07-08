## reach_zone.gd - Objective: player reaches a world position (NS08).
## Distance-polled at 4 Hz (robust headless; no layer coupling).
class_name ReachZone
extends ObjectiveSensor

@export var radius: float = 8.0

var _poll_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if is_complete():
		set_physics_process(false)
		return
	_poll_timer += delta
	if _poll_timer < 0.25:
		return
	_poll_timer = 0.0
	var player := _find_player()
	if player == null:
		return
	var flat_dist: float = Vector2(player.global_position.x - global_position.x,
		player.global_position.z - global_position.z).length()
	if flat_dist <= radius:
		complete()
		set_physics_process(false)
