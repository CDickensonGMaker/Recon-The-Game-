## hitzone.gd - Body part specific damage zone
class_name Hitzone
extends Area3D

## Zone types with damage multipliers (ADR-016 Amendment D: punishing)
enum ZoneType {
	HEAD,      # fatal on enemies - a headshot is a headshot, nothing saves you
	TORSO,     # 2.5x - center mass. One rifle round drops the weak, two end anyone
	GUT,       # 2.25x + bleed-out - devastating, downs a man fast
	LIMB       # 1.0x - full pass-through damage; the man is CHANGED (wounds/cripple)
}

@export var zone_type: ZoneType = ZoneType.TORSO

## Damage multipliers (values of record: ADR-016 Amendment D, 2026-07-11)
const MULTIPLIERS := {
	ZoneType.HEAD: 4.0,
	ZoneType.TORSO: 2.5,
	ZoneType.GUT: 2.25,
	ZoneType.LIMB: 1.0
}

## Per-unit overrides (ADR-016 Amendment B), authored in the hitzone bench and
## applied by HitzoneBuilder from data/hitzones/<unit>.tres. Negative = no
## override, ADR-016 defaults rule.
var damage_mult_override: float = -1.0
## Lab-only: when set, get_zone_name() reports THIS (e.g. "ARM_L_UP") instead
## of the type name. Ships empty - live wound/damage logic keys on the four
## type names and must never see region strings.
var zone_label_override: String = ""
## -1 = law default (HEAD fatal, rest not) · 0 = forced non-fatal · 1 = forced fatal
var fatal_override: int = -1

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
	if damage_mult_override >= 0.0:
		return damage_mult_override
	return MULTIPLIERS.get(zone_type, 1.0)


## Set owner entity
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity


## Get zone name for hit feedback
func get_zone_name() -> String:
	if zone_label_override != "":
		return zone_label_override
	match zone_type:
		ZoneType.HEAD:
			return "HEAD"
		ZoneType.TORSO:
			return "BODY"
		ZoneType.GUT:
			return "GUT"
		ZoneType.LIMB:
			return "LIMB"
		_:
			return "BODY"


## Zones that kill an enemy outright regardless of damage value.
func is_fatal_zone() -> bool:
	if fatal_override >= 0:
		return fatal_override == 1
	return zone_type == ZoneType.HEAD
