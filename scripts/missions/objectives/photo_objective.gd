## photo_objective.gd - SECURITY verb (W64): photograph the target from range
## with clear line of sight. Zero shots fired possible.
class_name PhotoObjective
extends ObjectiveSensor

signal photo_progress(fraction: float)

@export var max_range: float = 30.0
@export var min_range: float = 8.0
@export var hold_seconds: float = 2.0

var _progress: float = 0.0


func _physics_process(delta: float) -> void:
	if is_complete():
		set_physics_process(false)
		return
	var player := _find_player()
	if player == null:
		return
	var dist: float = player.global_position.distance_to(global_position)
	var in_window: bool = dist >= min_range and dist <= max_range
	var has_los: bool = in_window and CombatManager.has_line_of_sight(
		player.global_position + Vector3.UP * 1.5, global_position + Vector3.UP * 1.0, [player])
	if has_los and Input.is_action_pressed("interact") and GameManager.can_player_act():
		advance_photo(delta)
	elif _progress > 0.0:
		_progress = 0.0
		photo_progress.emit(0.0)


func advance_photo(delta: float) -> void:
	if is_complete():
		return
	_progress += delta / hold_seconds
	photo_progress.emit(clampf(_progress, 0.0, 1.0))
	if _progress >= 1.0:
		CampaignState.intel_points += 1
		CampaignState.save_campaign()
		complete()
		set_physics_process(false)
