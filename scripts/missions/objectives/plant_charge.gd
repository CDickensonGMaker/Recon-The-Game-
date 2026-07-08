## plant_charge.gd - Objective: hold interact near the target to plant a
## demolition charge (NS08). The vulnerability-window beat.
class_name PlantCharge
extends ObjectiveSensor

signal plant_progress(fraction: float)
signal charge_planted(at_position: Vector3)

@export var interact_radius: float = 3.5
@export var plant_seconds: float = 4.0

var _progress: float = 0.0


func _physics_process(delta: float) -> void:
	if is_complete():
		set_physics_process(false)
		return
	var player := _find_player()
	if player == null:
		return
	var in_range: bool = player.global_position.distance_to(global_position) <= interact_radius
	if in_range and Input.is_action_pressed("interact") and GameManager.can_player_act():
		advance_plant(delta)
	elif _progress > 0.0:
		_progress = 0.0
		plant_progress.emit(0.0)


## Extracted so tests/autopilots can drive planting without input injection.
func advance_plant(delta: float) -> void:
	if is_complete():
		return
	_progress += delta / plant_seconds
	plant_progress.emit(clampf(_progress, 0.0, 1.0))
	if _progress >= 1.0:
		charge_planted.emit(global_position)
		complete()
		set_physics_process(false)
