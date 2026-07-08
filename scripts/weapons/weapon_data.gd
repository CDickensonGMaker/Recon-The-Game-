## weapon_data.gd - Resource class for FPS weapon definitions
@tool
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Firing Properties")
@export var firing_mode: Enums.FiringMode = Enums.FiringMode.SEMI_AUTO
@export var fire_rate: float = 600.0  ## Rounds per minute
@export var magazine_size: int = 30
@export var reload_time: float = 2.5  ## Seconds

@export_group("Damage")
## Dice notation: [num_dice, die_size, flat_bonus] e.g., [2, 6, 6] = 2d6+6
@export var base_damage: Array[int] = [2, 6, 6]
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL

@export_group("Accuracy")
@export var base_spread: float = 2.0  ## Degrees of spread at hip
@export var ads_spread_mult: float = 0.3  ## Multiplier when ADS (30%)
@export var recoil_vertical: float = 2.5  ## Degrees kick up
@export var recoil_horizontal: float = 0.5  ## Degrees random horizontal

@export_group("ADS Properties")
@export var ads_fov: float = 55.0  ## FOV when aiming down sights
@export var ads_move_mult: float = 0.6  ## Movement speed multiplier when ADS

@export_group("Range")
@export var effective_range: float = 50.0  ## Meters - full damage range
@export var max_range: float = 100.0  ## Meters - damage falloff beyond

@export_group("Projectile")
@export var projectile_speed: float = 400.0  ## m/s
@export var projectile_data_path: String = ""  ## Path to ProjectileData resource

@export_group("Visuals")
@export var model_path: String = ""  ## Path to weapon GLTF model
@export var viewmodel_scale: float = 1.0  ## Relative scale (1.0 = reference size like Thompson)
@export var hip_position: Vector3 = Vector3(0.3, -0.2, -0.4)
@export var ads_position: Vector3 = Vector3(0, -0.15, -0.3)
@export var hip_rotation: Vector3 = Vector3(0, 0, 0)
@export var ads_rotation: Vector3 = Vector3(0, 0, 0)


## Roll damage using the dice notation
func roll_damage() -> int:
	var total := 0
	for i in range(base_damage[0]):
		total += randi_range(1, base_damage[1])
	total += base_damage[2]
	return max(1, total)


## Get damage string for UI display (e.g., "2d6+6")
func get_damage_string() -> String:
	var s := "%dd%d" % [base_damage[0], base_damage[1]]
	if base_damage[2] > 0:
		s += "+%d" % base_damage[2]
	elif base_damage[2] < 0:
		s += "%d" % base_damage[2]
	return s


## Get fire rate in seconds between shots
func get_fire_delay() -> float:
	return 60.0 / fire_rate


## Calculate spread based on ADS state (0-1 lerp value)
func get_spread(ads_amount: float) -> float:
	return base_spread * lerp(1.0, ads_spread_mult, ads_amount)
