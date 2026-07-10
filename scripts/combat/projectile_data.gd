## projectile_data.gd - Resource definition for bullet projectile types
@tool
class_name ProjectileData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export_group("Movement")
@export var speed: float = 200.0  ## Bullet speed in m/s
@export var gravity_scale: float = 0.0  ## 0 = no drop, 1 = full gravity
@export var lifetime: float = 3.0  ## Max time before expiring

@export_group("Damage")
## ADR-016: flat base damage per hit — deterministic (see WeaponData.base_damage).
@export var base_damage: int = 8
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL

@export_group("Status Effects")
@export var stagger_power: float = 0.0
@export var knockback_force: float = 0.0

@export_group("Area of Effect")
@export var aoe_radius: float = 0.0  ## 0 = no AOE (for grenades/explosives)
@export var aoe_damage_falloff: bool = true

@export_group("Collision")
@export var collision_radius: float = 0.05  ## Bullet is small
@export var hits_enemies: bool = true
@export var hits_players: bool = false
@export var hits_world: bool = true

@export_group("Visuals")
@export var mesh_path: String = ""
@export var scale: Vector3 = Vector3(0.1, 0.1, 0.1)

@export_group("Trail Effect")
@export var has_trail: bool = true
@export var trail_color: Color = Color(1.0, 0.9, 0.5, 0.8)
@export var trail_lifetime: float = 0.1
@export var trail_width: float = 0.02


## Flat per-hit damage (ADR-016). Deterministic.
func get_damage() -> int:
	return maxi(1, base_damage)


## Get damage string for UI
func get_damage_string() -> String:
	return "%d" % base_damage
