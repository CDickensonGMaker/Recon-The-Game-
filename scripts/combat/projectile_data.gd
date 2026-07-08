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
@export var base_damage: Array[int] = [2, 6, 0]  ## [num_dice, die_size, flat_bonus]
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


## Roll damage for this projectile
func roll_damage() -> int:
	var total := 0
	for i in range(base_damage[0]):
		total += randi_range(1, base_damage[1])
	total += base_damage[2]
	return max(1, total)


## Get damage string for UI
func get_damage_string() -> String:
	var s := "%dd%d" % [base_damage[0], base_damage[1]]
	if base_damage[2] > 0:
		s += "+%d" % base_damage[2]
	elif base_damage[2] < 0:
		s += "%d" % base_damage[2]
	return s
