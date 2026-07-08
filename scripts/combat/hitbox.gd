## hitbox.gd - Reusable hitbox component for dealing damage
class_name Hitbox
extends Area3D

signal hit_landed(target: Node)

## Configuration
@export var damage: int = 10
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var stagger_power: float = 1.0
@export var knockback_force: float = 5.0

## Owner reference (who is attacking)
var owner_entity: Node = null

## Track what we've hit this activation
var hit_targets: Array[Node] = []

## Is this hitbox currently active
var is_active: bool = false

func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	set_meta("damage", damage)
	set_meta("damage_type", damage_type)
	set_meta("stagger_power", stagger_power)


## Activate the hitbox (call when attack starts)
func activate() -> void:
	hit_targets.clear()
	is_active = true
	monitoring = true
	monitorable = true
	force_update_transform()
	call_deferred("_check_initial_overlaps")


## Check for overlaps that existed when hitbox was activated
func _check_initial_overlaps() -> void:
	if not is_active:
		return
	var overlapping: Array[Area3D] = get_overlapping_areas()
	for area in overlapping:
		if area not in hit_targets:
			_on_area_entered(area)


## Deactivate the hitbox (call when attack ends)
func deactivate() -> void:
	is_active = false
	monitoring = false


## Called when we overlap with another Area3D (hurtbox)
func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	if not area is Hurtbox:
		if not area.is_in_group("hurtbox") and not area.is_in_group("enemy_hurtbox") and not area.is_in_group("player_hurtbox"):
			return

	var target: Node = area.get_parent()
	if not target:
		return

	if target == owner_entity:
		return

	if target in hit_targets:
		return

	hit_targets.append(target)
	_apply_hit(target)


## Called when we overlap with a physics body
func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	if body == owner_entity:
		return

	if body in hit_targets:
		return

	if not body.is_in_group("enemies") and not body.is_in_group("player"):
		return

	hit_targets.append(body)
	_apply_hit(body)


## Apply the hit to a target
func _apply_hit(target: Node) -> void:
	hit_landed.emit(target)

	if target.has_method("take_damage"):
		target.take_damage(damage, damage_type, owner_entity)

	if stagger_power > 0 and target.has_method("apply_stagger"):
		target.apply_stagger(stagger_power)

	if knockback_force > 0 and target is CharacterBody3D and owner_entity is Node3D:
		var direction: Vector3 = (target.global_position - (owner_entity as Node3D).global_position).normalized()
		direction.y = 0.2
		(target as CharacterBody3D).velocity += direction * knockback_force


## Set owner (the entity this hitbox belongs to)
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity


## Update damage values
func set_damage_values(new_damage: int, new_type: Enums.DamageType = Enums.DamageType.PHYSICAL) -> void:
	damage = new_damage
	damage_type = new_type
	set_meta("damage", damage)
	set_meta("damage_type", damage_type)
