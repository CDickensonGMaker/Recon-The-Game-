## sapper_charge.gd - A behaviour node parented to a sapper. It drives the man's
## legs to the objective through EnemyBase.assault_objective (which pushes through
## contact), and blows the satchel when he reaches it. The blast is a full-lethality
## breach: the garrison are participants now (war-room decree 2026-07-20), so it
## spares no one, and it costs the player fire support (FieldDirector.on_firebase_breach).
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


## ZERO is "no objective": an unset satchel must never arm, or it detonates at
## the world origin. Silent and pure so a probe can assert the invariant without
## the shout below turning the whole suite red.
static func is_valid_objective(objective_center: Vector3) -> bool:
	return objective_center != Vector3.ZERO


func setup(objective_center: Vector3) -> void:
	if not is_valid_objective(objective_center):
		push_error("[SapperCharge] refused a ZERO objective - would detonate at origin")
		return
	target_pos = objective_center
	_armed = true
	var enemy := get_parent() as EnemyBase
	if enemy != null:
		enemy.assault_objective = target_pos
		enemy.assault_driven = true   # the satchel pushes THROUGH contact, by doctrine


## Make the satchel inert THIS frame. queue_free alone is deferred, so a charge
## dropped during a withdrawal would still get a physics tick at its old aim point
## and detonate on the way out - and _detonate clears the rally the reap just set.
func disarm() -> void:
	_armed = false
	target_pos = Vector3.ZERO
	set_physics_process(false)


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
	# spare_garrison FALSE: the garrison are participants now - the charge does not
	# discriminate. It hits any body in the radius, promoted defender or not.
	CombatManager.apply_explosion_damage(pos, SATCHEL_DAMAGE, SATCHEL_MIN,
		SATCHEL_RADIUS, enemy, 1.0, false)
	DamageSystem.apply_damage(pos, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	GunFX.play_explosion_3d(get_tree().current_scene, pos, "explosion_grenade")
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, pos, 1)
	# The breach is the point: the satchel blew the firebase's munitions. Tell the
	# director so the cost lands (docked fire support, next patrol short of steel).
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	if d is FieldDirector:
		(d as FieldDirector).on_firebase_breach(pos)
	enemy.assault_objective = Vector3.ZERO
	enemy.assault_driven = false
	enemy.take_damage(9999, Enums.DamageType.EXPLOSIVE, enemy)
	set_physics_process(false)
