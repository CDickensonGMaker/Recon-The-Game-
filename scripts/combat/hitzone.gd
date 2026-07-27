## hitzone.gd - Body part specific damage zone
class_name Hitzone
extends Area3D

## Zone types with damage multipliers (ADR-016 Amendment D: punishing)
enum ZoneType {
	HEAD,      # fatal to ANYONE - enemy, ally, player. Nothing saves you.
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

## Layer and mask belong to whoever BUILDS the zone, never to the zone itself:
## a deferred rewrite here would land after the builder's and silently win, which
## is how enemy_base's mask argument became dead input.
func _ready() -> void:
	monitoring = true
	monitorable = true
	add_to_group("hitzone")


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


## Zones that kill outright regardless of damage value.
func is_fatal_zone() -> bool:
	if fatal_override >= 0:
		return fatal_override == 1
	return zone_type == ZoneType.HEAD


## THE fatal-zone authority, by the 4-name law (ADR-016 Amendment D).
##
## Damage arrives at take_damage as a zone STRING, not a Hitzone, so every
## damageable actor asks HERE. It is faction-blind by the Summoner's ruling of
## 2026-07-27: a headshot kills an enemy, an ally and the player alike. Before
## that ruling only enemy_base implemented the bypass, so at falloff range an
## ally survived a headshot that always killed a VC.
##
## Instance overrides (fatal_override) are bench-only and cannot ride a string;
## if that ever ships to gameplay, damage must carry the Hitzone instead.
static func zone_name_is_fatal(zone: String) -> bool:
	return zone == "HEAD"
