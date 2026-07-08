## game_world.gd - Generated AO gameplay scene: terrain + player + HUD.
## The terrain-FPS bridge. Mission systems attach on top of this (NS07+).
class_name GameWorld
extends Node3D

signal world_ready

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const TerrainManagerScript := preload("res://terrain/core/terrain_manager.gd")
const TerrainChunkScript := preload("res://terrain/core/terrain_chunk.gd")

@export var mission_seed: int = 12345
@export var map_size: float = 1280.0
@export var spawn_position_override: Vector3 = Vector3.ZERO  ## zero = AO center

var terrain_manager: TerrainManager
var player: CharacterBody3D
var hud: HUD
var is_world_ready: bool = false

## Safety net: re-seat the player if they end up under the terrain surface.
const RESEAT_DEPTH: float = 5.0
var _reseat_timer: float = 0.0


func _ready() -> void:
	_setup_environment()
	_setup_terrain()


func _setup_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 250.0
	add_child(light)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.46, 0.6)
	sky_material.sky_horizon_color = Color(0.7, 0.72, 0.65)
	sky_material.ground_bottom_color = Color(0.2, 0.22, 0.16)
	sky_material.ground_horizon_color = Color(0.65, 0.67, 0.6)

	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.78, 0.7)
	env.fog_density = 0.004

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


func _setup_terrain() -> void:
	terrain_manager = TerrainManagerScript.new()
	terrain_manager.name = "TerrainManager"
	terrain_manager.map_size = map_size
	terrain_manager.chunk_size = 256.0
	terrain_manager.cell_size = 4.0
	terrain_manager.load_distance = 2
	terrain_manager.unload_distance = 3
	add_child(terrain_manager)
	terrain_manager.terrain_ready.connect(_on_terrain_ready)
	# Shared chunk material must exist before chunks build or terrain renders white.
	TerrainChunkScript._create_shared_material()
	await terrain_manager.generate_terrain(mission_seed)


func _on_terrain_ready() -> void:
	_spawn_player()
	_setup_hud()
	is_world_ready = true
	world_ready.emit()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	var spawn := spawn_position_override
	if spawn == Vector3.ZERO:
		spawn = Vector3(map_size * 0.5, 0.0, map_size * 0.5)
	var ground_y: float = terrain_manager.get_height_at(spawn)
	player.global_position = Vector3(spawn.x, ground_y + 1.0, spawn.z)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	terrain_manager.set_camera(cam)


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)


func _physics_process(delta: float) -> void:
	if not is_world_ready or player == null:
		return
	_reseat_timer += delta
	if _reseat_timer < 2.0:
		return
	_reseat_timer = 0.0
	var ground_y: float = terrain_manager.get_height_at(player.global_position)
	if player.global_position.y < ground_y - RESEAT_DEPTH:
		player.global_position.y = ground_y + 1.0
		player.velocity = Vector3.ZERO


## Ground height helper for spawners/missions.
func get_ground_height(world_pos: Vector3) -> float:
	return terrain_manager.get_height_at(world_pos)
