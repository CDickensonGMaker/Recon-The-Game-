## enemy_data.gd - Resource class for enemy definitions
@tool
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Stats")
@export var max_hp: int = 80
@export var move_speed: float = 4.0
@export var preferred_range: float = 15.0  ## Ideal combat distance
@export var alert_range: float = 20.0  ## Detection range

@export_group("Combat")
@export var weapon_path: String = ""  ## Path to WeaponData resource
@export var accuracy_modifier: float = 1.0  ## 1.0 = normal, <1 = less accurate
@export var aggression: float = 0.5  ## 0 = defensive, 1 = aggressive

@export_group("Behavior")
@export var uses_cover: bool = true
@export var flanks: bool = false
@export var retreats_when_hurt: bool = false
@export var retreat_hp_threshold: float = 0.25

@export_group("Visuals")
@export var model_path: String = ""  ## Path to character GLTF
@export var color: Color = Color(0.4, 0.4, 0.3)  ## Fallback color for placeholder
