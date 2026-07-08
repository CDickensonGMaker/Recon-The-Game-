## hurtbox.gd - Reusable hurtbox component for receiving damage
class_name Hurtbox
extends Area3D

signal hurt(damage: int, damage_type: Enums.DamageType, attacker: Node)

## Owner reference
var owner_entity: Node = null

## Invincibility state
var is_invincible: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)


## Called when a hitbox enters our area
func _on_area_entered(area: Area3D) -> void:
	if is_invincible:
		return

	if not area is Hitbox:
		if not area.is_in_group("hitbox") and not area.is_in_group("enemy_hitbox") and not area.is_in_group("player_hitbox"):
			return

	if area is Hitbox and not (area as Hitbox).is_active:
		return

	var damage: int = area.get_meta("damage", 10)
	var damage_type: Enums.DamageType = area.get_meta("damage_type", Enums.DamageType.PHYSICAL)

	var attacker: Node = null
	if area is Hitbox:
		attacker = (area as Hitbox).owner_entity
	else:
		attacker = area.get_parent()

	if attacker == owner_entity:
		return

	hurt.emit(damage, damage_type, attacker)

	if owner_entity and owner_entity.has_method("take_damage"):
		if area is Hitbox:
			var hb := area as Hitbox
			if owner_entity in hb.hit_targets:
				return
			hb.hit_targets.append(owner_entity)
		owner_entity.take_damage(damage, damage_type, attacker)


## Set owner entity
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity


## Enable/disable invincibility (for i-frames)
func set_invincible(value: bool) -> void:
	is_invincible = value


## Temporarily disable (for death, etc.)
func disable() -> void:
	set_deferred("monitorable", false)


## Re-enable
func enable() -> void:
	set_deferred("monitorable", true)
