## sapper_charge.gd - A behaviour node parented to a sapper. It drives the man's
## legs to the objective through EnemyBase.assault_objective (which pushes through
## contact), and blows the satchel when he reaches it. The explosion spares the
## noncombatant garrison by decree - see the war-room synthesis 2026-07-20.
##
## The player is NOT told from here: notification is the RTO net's job
## (FieldDirector.raise_crisis), so no marker ever appears from nothing.
class_name SapperCharge
extends Node

# Satchel = placed demolition charge. Damage sits at the LAW/RPG-2 tier (ADR-016:
# 250) - a rocket-warhead equivalent, below the RPG-7 (290) which stays the king;
# its identity is the wide 14m radius, not a new above-canon damage record.
const DETONATE_RANGE: float = 5.0
const SATCHEL_DAMAGE: int = 250
const SATCHEL_MIN: int = 70
const SATCHEL_RADIUS: float = 14.0

var target_pos: Vector3 = Vector3.ZERO
var _armed: bool = false


func setup(objective_center: Vector3) -> void:
	# ZERO is "no objective" (an unset satchel at the world origin must never arm).
	if objective_center == Vector3.ZERO:
		push_error("[SapperCharge] refused a ZERO objective - would detonate at origin")
		return
	target_pos = objective_center
	_armed = true
	var enemy := get_parent() as EnemyBase
	if enemy != null:
		enemy.assault_objective = target_pos


func _physics_process(_delta: float) -> void:
	if not _armed:
		return
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.is_dead():
		# A sapper cut down before the wire never detonates - that is the win.
		set_physics_process(false)
		return
	if enemy.global_position.distance_to(target_pos) <= DETONATE_RANGE:
		_detonate(enemy)


func _detonate(enemy: EnemyBase) -> void:
	_armed = false
	var pos: Vector3 = enemy.global_position
	# spare_garrison: the placed charge does not delete the men who cannot react.
	CombatManager.apply_explosion_damage(pos, SATCHEL_DAMAGE, SATCHEL_MIN,
		SATCHEL_RADIUS, enemy, 1.0, true)
	DamageSystem.apply_damage(pos, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	GunFX.play_explosion_3d(get_tree().current_scene, pos, "explosion_grenade")
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, pos, 1)
	enemy.assault_objective = Vector3.ZERO
	enemy.take_damage(9999, Enums.DamageType.EXPLOSIVE, enemy)
	set_physics_process(false)
