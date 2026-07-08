## sapper_charge.gd - Attached to a sapper enemy (W57): sprints for the wire,
## detonates the satchel when close to the objective.
class_name SapperCharge
extends Node

const DETONATE_RANGE: float = 9.0

var target_pos: Vector3 = Vector3.ZERO
var director: MissionDirector
var _warned: bool = false


func setup(objective_center: Vector3, mission_director: MissionDirector) -> void:
	target_pos = objective_center
	director = mission_director


func _physics_process(_delta: float) -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.is_dead():
		set_physics_process(false)
		return
	# Drive toward the objective regardless of the combat brain.
	enemy.last_known_target_pos = target_pos
	var dist: float = enemy.global_position.distance_to(target_pos)
	if not _warned and dist < 40.0 and director:
		_warned = true
		director.toast.emit("SAPPER IN THE WIRE!")
	if dist <= DETONATE_RANGE:
		var pos: Vector3 = enemy.global_position
		CombatManager.apply_explosion_damage(pos, 180, 60, 10.0, enemy)
		DamageSystem.apply_damage(pos, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
		GunFX.play_explosion_3d(get_tree().current_scene, pos, "explosion_heavy")
		NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, pos, 1)
		enemy.take_damage(9999, Enums.DamageType.EXPLOSIVE, enemy)
		set_physics_process(false)
