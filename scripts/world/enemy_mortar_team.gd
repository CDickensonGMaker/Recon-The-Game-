## enemy_mortar_team.gd - R66: enemy indirect-fire team. Once the AO is hot it
## drops rounds on the player's position periodically. Kill both crew (the
## counter-battery payoff) and it falls silent for good.
class_name EnemyMortarTeam
extends Node3D

var director: MissionDirector
var _crew: Array[EnemyBase] = []
var _fire_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
const FIRE_INTERVAL_MIN: float = 22.0
const FIRE_INTERVAL_MAX: float = 38.0


static func spawn(parent: Node, pos: Vector3, mission_director: MissionDirector, rng_seed: int, data_paths: Array[String]) -> EnemyMortarTeam:
	var team := EnemyMortarTeam.new()
	team.director = mission_director
	team._rng.seed = rng_seed
	parent.add_child(team)
	team.global_position = pos
	for i in range(2):
		var e := mission_director.spawn_tracked_enemy(pos + Vector3(1.5 * float(i), 0, 0), data_paths[i % data_paths.size()], "mortar_crew")
		e.add_to_group("mortar_crew")
		team._crew.append(e)
	team._fire_timer = team._rng.randf_range(FIRE_INTERVAL_MIN, FIRE_INTERVAL_MAX)
	return team


func _is_alive() -> bool:
	for e in _crew:
		if is_instance_valid(e) and not e.is_dead():
			return true
	return false


func _physics_process(delta: float) -> void:
	if not _is_alive():
		set_physics_process(false)
		return
	if director == null or not is_instance_valid(director) or director.world == null or director.world.player == null:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = _rng.randf_range(FIRE_INTERVAL_MIN, FIRE_INTERVAL_MAX)
		var target: Vector3 = director.world.player.global_position
		director.toast.emit("INCOMING MORTARS - GET DOWN")
		for i in range(3):
			var t: float = 2.5 + float(i) * 1.4
			var scatter: Vector3 = target + Vector3(randf_range(-10.0, 10.0), 0, randf_range(-10.0, 10.0))
			get_tree().create_timer(t).timeout.connect(func() -> void:
				if director != null and is_instance_valid(director):
					director.enemy_mortar_impact(scatter))
