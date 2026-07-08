## hitzone.gd - Body part specific damage zone
class_name Hitzone
extends Area3D

## Zone types with damage multipliers
enum ZoneType {
	HEAD,      # 4x damage - instant kill
	TORSO,     # 1.5x damage - center mass
	LIMB       # 0.6x damage - arms/legs
}

@export var zone_type: ZoneType = ZoneType.TORSO

## Damage multipliers
const MULTIPLIERS := {
	ZoneType.HEAD: 4.0,
	ZoneType.TORSO: 1.5,
	ZoneType.LIMB: 0.6
}

## Owner reference
var owner_entity: Node = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	add_to_group("hitzone")

	# Add to appropriate group based on owner
	call_deferred("_setup_groups")


func _setup_groups() -> void:
	if owner_entity:
		if owner_entity.is_in_group("player"):
			add_to_group("player_hurtbox")
			collision_layer = 32  # Layer 6: player_hurtbox
			collision_mask = 16   # Layer 5: enemy_hitbox
		elif owner_entity.is_in_group("enemies"):
			add_to_group("enemy_hurtbox")
			collision_layer = 64  # Layer 7: enemy_hurtbox
			collision_mask = 8    # Layer 4: player_hitbox


## Get damage multiplier for this zone
func get_damage_multiplier() -> float:
	return MULTIPLIERS.get(zone_type, 1.0)


## Set owner entity
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity


## Get zone name for hit feedback
func get_zone_name() -> String:
	match zone_type:
		ZoneType.HEAD:
			return "HEAD"
		ZoneType.TORSO:
			return "BODY"
		ZoneType.LIMB:
			return "LIMB"
		_:
			return "BODY"


## Check if this is a critical hit zone
func is_critical_zone() -> bool:
	return zone_type == ZoneType.HEAD
