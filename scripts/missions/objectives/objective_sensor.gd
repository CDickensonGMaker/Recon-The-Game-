## objective_sensor.gd - Base for objective completion sensors.
## Each sensor owns one bit in MissionState and reports through the director.
class_name ObjectiveSensor
extends Node3D

@export var objective_index: int = 0
@export var title: String = "OBJECTIVE"
@export var required: bool = true

var director: MissionDirector


func register(mission_director: MissionDirector) -> void:
	director = mission_director
	director.state.register_objective(objective_index, title, required)


func complete() -> void:
	if director:
		director.complete_objective(objective_index)


func is_complete() -> bool:
	return director != null and director.state.is_objective_complete(objective_index)


func _find_player() -> Node3D:
	return GameManager.player as Node3D
