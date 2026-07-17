## kill_count.gd - Objective: eliminate a fraction of a tagged enemy group.
class_name KillCountObjective
extends ObjectiveSensor

@export var group_tag: String = ""
@export var total_count: int = 0
@export var required_fraction: float = 0.8

var _killed: int = 0


func register(mission_director: MissionDirector) -> void:
	super.register(mission_director)
	director.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_enemy: EnemyBase, tag: String) -> void:
	if is_complete():
		return
	if not group_tag.is_empty() and tag != group_tag:
		return
	_killed += 1
	if total_count > 0 and float(_killed) / float(total_count) >= required_fraction:
		complete()
