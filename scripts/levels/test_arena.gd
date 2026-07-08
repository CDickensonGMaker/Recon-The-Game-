## test_arena.gd - Test level script for Hell of Duty (Procedural WW2 Map)
extends Node3D

## Map generator reference
@onready var map_generator: WW2MapGenerator = $WW2MapGenerator

## References
@onready var hud: HUD = $HUD
@onready var environment_root: Node3D = $Environment
@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D

## Preloaded scenes
var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

## Configuration
const TILE_SIZE: float = 2.0  # 1 tile = 2 meters in world space
const WALL_HEIGHT: float = 3.0
const PROP_HEIGHT: float = 2.0

## Materials for procedural geometry
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var road_material: StandardMaterial3D
var water_material: StandardMaterial3D

## Instances
var player: CharacterBody3D = null
var allies: Array[AllyBase] = []
var generated_geometry: Node3D = null

## Cover points for AI (from generator)
var cover_points: Array[Vector3] = []


func _ready() -> void:
	_create_materials()
	_generate_map()
	_build_3d_geometry()
	_spawn_player()
	_spawn_allies()
	_spawn_enemies()
	_setup_hud()
	_bake_navigation()


func _create_materials() -> void:
	# Floor material (dirt/grass)
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.35, 0.3, 0.25)

	# Wall material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.5, 0.45, 0.4)

	# Road material
	road_material = StandardMaterial3D.new()
	road_material.albedo_color = Color(0.3, 0.3, 0.35)

	# Water material
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.2, 0.3, 0.5)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.albedo_color.a = 0.7


func _generate_map() -> void:
	# Generate the procedural map
	if map_generator.map_seed == 0:
		map_generator.map_seed = randi()

	print("[TestArena] Generating map with seed: %d" % map_generator.map_seed)
	map_generator.generate()

	# Get cover positions from generator for AI
	var cover_tiles: Array[Vector2i] = map_generator.get_cover_positions()
	for tile_pos in cover_tiles:
		var world_pos: Vector3 = _tile_to_world(tile_pos.x, tile_pos.y)
		cover_points.append(world_pos)

	print("[TestArena] Found %d cover positions" % cover_points.size())


func _tile_to_world(tile_x: int, tile_y: int) -> Vector3:
	# Convert tile coordinates to 3D world position
	# Center the map around origin
	var offset_x: float = -float(map_generator.map_width) * TILE_SIZE / 2.0
	var offset_z: float = -float(map_generator.map_height) * TILE_SIZE / 2.0
	return Vector3(
		float(tile_x) * TILE_SIZE + offset_x + TILE_SIZE / 2.0,
		0.0,
		float(tile_y) * TILE_SIZE + offset_z + TILE_SIZE / 2.0
	)


func _build_3d_geometry() -> void:
	# Create container for generated geometry
	generated_geometry = Node3D.new()
	generated_geometry.name = "GeneratedGeometry"
	environment_root.add_child(generated_geometry)

	# Create ground plane (single large mesh for performance)
	_create_ground_plane()

	# Create 3D geometry for special tiles
	for y in range(map_generator.map_height):
		for x in range(map_generator.map_width):
			var tile: WW2MapGenerator.Tile = map_generator.get_tile(x, y)
			_create_tile_geometry(x, y, tile)


func _create_ground_plane() -> void:
	# Large ground plane covering entire map
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1  # World layer

	var ground_size: float = maxf(map_generator.map_width, map_generator.map_height) * TILE_SIZE

	# Collision
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size, 1.0, ground_size)
	col_shape.shape = box
	col_shape.position = Vector3(0, -0.5, 0)
	ground.add_child(col_shape)

	# Visual mesh
	var mesh_inst := MeshInstance3D.new()
	var plane_mesh := BoxMesh.new()
	plane_mesh.size = Vector3(ground_size, 1.0, ground_size)
	mesh_inst.mesh = plane_mesh
	mesh_inst.material_override = floor_material
	mesh_inst.position = Vector3(0, -0.5, 0)
	ground.add_child(mesh_inst)

	generated_geometry.add_child(ground)


func _create_tile_geometry(x: int, y: int, tile: WW2MapGenerator.Tile) -> void:
	var world_pos: Vector3 = _tile_to_world(x, y)

	# Only create geometry for solid tiles that need collision/visual
	match tile:
		WW2MapGenerator.Tile.WALL_N, WW2MapGenerator.Tile.WALL_S, \
		WW2MapGenerator.Tile.WALL_E, WW2MapGenerator.Tile.WALL_W:
			_create_wall(world_pos, tile)

		WW2MapGenerator.Tile.CHURCH:
			_create_wall(world_pos, tile, WALL_HEIGHT * 1.5)  # Taller church walls

		WW2MapGenerator.Tile.TREE, WW2MapGenerator.Tile.DEAD_TREE:
			_create_tree(world_pos, tile == WW2MapGenerator.Tile.DEAD_TREE)

		WW2MapGenerator.Tile.SANDBAG:
			_create_cover_prop(world_pos, "Sandbag", 1.0)

		WW2MapGenerator.Tile.TANK_WRECK:
			_create_cover_prop(world_pos, "TankWreck", 2.5)

		WW2MapGenerator.Tile.HAY_BALE:
			_create_cover_prop(world_pos, "HayBale", 1.5)

		WW2MapGenerator.Tile.GRAVESTONE:
			_create_cover_prop(world_pos, "Gravestone", 1.2)

		WW2MapGenerator.Tile.FENCE:
			_create_fence(world_pos)

		WW2MapGenerator.Tile.BARREL, WW2MapGenerator.Tile.AMMO_CRATE:
			_create_cover_prop(world_pos, "Barrel", 1.0)

		WW2MapGenerator.Tile.WATER:
			_create_water(world_pos)


func _create_wall(pos: Vector3, tile: WW2MapGenerator.Tile, height: float = WALL_HEIGHT) -> void:
	var wall := StaticBody3D.new()
	wall.name = "Wall_%d_%d" % [int(pos.x), int(pos.z)]
	wall.collision_layer = 1
	wall.position = pos

	# Collision
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE_SIZE, height, TILE_SIZE)
	col.shape = box
	col.position = Vector3(0, height / 2.0, 0)
	wall.add_child(col)

	# Visual
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(TILE_SIZE, height, TILE_SIZE)
	mesh.mesh = box_mesh
	mesh.material_override = wall_material
	mesh.position = Vector3(0, height / 2.0, 0)
	wall.add_child(mesh)

	generated_geometry.add_child(wall)


func _create_tree(pos: Vector3, is_dead: bool) -> void:
	var tree := StaticBody3D.new()
	tree.name = "Tree_%d_%d" % [int(pos.x), int(pos.z)]
	tree.collision_layer = 1
	tree.position = pos

	# Trunk collision
	var col := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = PROP_HEIGHT * 2.0
	col.shape = cylinder
	col.position = Vector3(0, PROP_HEIGHT, 0)
	tree.add_child(col)

	# Trunk visual
	var trunk_mesh := MeshInstance3D.new()
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.25
	cyl_mesh.bottom_radius = 0.35
	cyl_mesh.height = PROP_HEIGHT * 2.0
	trunk_mesh.mesh = cyl_mesh
	trunk_mesh.position = Vector3(0, PROP_HEIGHT, 0)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.15) if not is_dead else Color(0.3, 0.25, 0.2)
	trunk_mesh.material_override = trunk_mat
	tree.add_child(trunk_mesh)

	# Foliage (if not dead)
	if not is_dead:
		var foliage := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.5
		sphere.height = 2.5
		foliage.mesh = sphere
		foliage.position = Vector3(0, PROP_HEIGHT * 2.0 + 1.0, 0)

		var foliage_mat := StandardMaterial3D.new()
		foliage_mat.albedo_color = Color(0.15, 0.35, 0.15)
		foliage.material_override = foliage_mat
		tree.add_child(foliage)

	generated_geometry.add_child(tree)


func _create_cover_prop(pos: Vector3, prop_name: String, height: float) -> void:
	var prop := StaticBody3D.new()
	prop.name = "%s_%d_%d" % [prop_name, int(pos.x), int(pos.z)]
	prop.collision_layer = 1
	prop.position = pos

	# Collision
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE_SIZE * 0.8, height, TILE_SIZE * 0.8)
	col.shape = box
	col.position = Vector3(0, height / 2.0, 0)
	prop.add_child(col)

	# Visual
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(TILE_SIZE * 0.8, height, TILE_SIZE * 0.8)
	mesh.mesh = box_mesh
	mesh.position = Vector3(0, height / 2.0, 0)

	var mat := StandardMaterial3D.new()
	match prop_name:
		"Sandbag":
			mat.albedo_color = Color(0.6, 0.55, 0.4)
		"TankWreck":
			mat.albedo_color = Color(0.25, 0.3, 0.25)
		"HayBale":
			mat.albedo_color = Color(0.7, 0.6, 0.3)
		"Gravestone":
			mat.albedo_color = Color(0.5, 0.5, 0.55)
		_:
			mat.albedo_color = Color(0.4, 0.35, 0.3)
	mesh.material_override = mat
	prop.add_child(mesh)

	generated_geometry.add_child(prop)


func _create_fence(pos: Vector3) -> void:
	var fence := StaticBody3D.new()
	fence.name = "Fence_%d_%d" % [int(pos.x), int(pos.z)]
	fence.collision_layer = 1
	fence.position = pos

	# Thin collision
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE_SIZE, 1.5, 0.2)
	col.shape = box
	col.position = Vector3(0, 0.75, 0)
	fence.add_child(col)

	# Visual
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(TILE_SIZE, 1.5, 0.15)
	mesh.mesh = box_mesh
	mesh.position = Vector3(0, 0.75, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2)
	mesh.material_override = mat
	fence.add_child(mesh)

	generated_geometry.add_child(fence)


func _create_water(pos: Vector3) -> void:
	# Water is just a visual plane below ground level
	var water := MeshInstance3D.new()
	water.name = "Water_%d_%d" % [int(pos.x), int(pos.z)]

	var plane := PlaneMesh.new()
	plane.size = Vector2(TILE_SIZE, TILE_SIZE)
	water.mesh = plane
	water.material_override = water_material
	water.position = Vector3(pos.x, -0.3, pos.z)

	generated_geometry.add_child(water)


func _spawn_player() -> void:
	var spawn_tile: Vector2i = map_generator.get_player_spawn()
	var spawn_pos: Vector3 = _tile_to_world(spawn_tile.x, spawn_tile.y)
	spawn_pos.y = 1.0  # Spawn above ground

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	print("[TestArena] Player spawned at tile (%d, %d) -> world %s" % [spawn_tile.x, spawn_tile.y, spawn_pos])


func _spawn_allies() -> void:
	var player_pos: Vector3 = player.global_position

	# Spawn 2 allied soldiers near the player
	var ally_offsets := [
		Vector3(-2.5, 0, -1.5),  # Left and slightly back
		Vector3(2.5, 0, -1.5),   # Right and slightly back
	]

	for offset in ally_offsets:
		var ally := AllyBase.spawn_ally(self, player_pos + offset)
		if ally:
			allies.append(ally)
			print("[ALLY] Spawned allied soldier")


func _spawn_enemies() -> void:
	var enemy_count: int = 8  # More enemies for larger map
	var enemy_tiles: Array[Vector2i] = map_generator.get_enemy_spawns(enemy_count)

	var total_spawned: int = 0
	var rifleman_path: String = "res://data/enemies/german_rifleman.tres"
	var smg_path: String = "res://data/enemies/german_smg.tres"

	for i in range(enemy_tiles.size()):
		var tile_pos: Vector2i = enemy_tiles[i]
		var world_pos: Vector3 = _tile_to_world(tile_pos.x, tile_pos.y)
		world_pos.y = 1.0  # Spawn above ground

		# Alternate between riflemen and SMG troops
		var enemy_data_path: String = rifleman_path if i % 2 == 0 else smg_path

		var enemy := EnemyBase.spawn_enemy(self, world_pos, enemy_data_path)
		if enemy:
			total_spawned += 1
			print("[ENEMY] Spawned at tile (%d, %d) -> world %s" % [tile_pos.x, tile_pos.y, world_pos])

	GameManager.set_total_enemies(total_spawned)
	print("[TestArena] Spawned %d enemies" % total_spawned)


func _setup_hud() -> void:
	if player and hud:
		var health_system := player.get_node("HealthSystem") as HealthSystem
		var weapon_holder := player.get_node("Head/Camera3D/WeaponHolder") as WeaponHolder
		var equipment_manager := player.get_node("EquipmentManager") as EquipmentManager
		var grenade_handler := player.get_node("Head/Camera3D/GrenadeHandler") as GrenadeHandler

		hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)


func _bake_navigation() -> void:
	# Create navigation mesh for AI pathfinding
	if navigation_region:
		var nav_mesh := NavigationMesh.new()
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_height = 2.0
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25

		# Set baking bounds based on map size
		var map_extent: float = maxf(map_generator.map_width, map_generator.map_height) * TILE_SIZE / 2.0
		nav_mesh.filter_baking_aabb = AABB(
			Vector3(-map_extent, -1.0, -map_extent),
			Vector3(map_extent * 2.0, 10.0, map_extent * 2.0)
		)

		navigation_region.navigation_mesh = nav_mesh

		# Bake navigation mesh
		NavigationServer3D.bake_from_source_geometry_data(
			nav_mesh,
			NavigationMeshSourceGeometryData3D.new()
		)

		print("[TestArena] Navigation mesh baked")


## Get cover positions for AI
func get_cover_positions() -> Array[Vector3]:
	return cover_points


## Get speed modifier at world position (for player/AI movement)
func get_speed_modifier(world_pos: Vector3) -> float:
	var tile_x: int = _world_to_tile_x(world_pos.x)
	var tile_y: int = _world_to_tile_y(world_pos.z)
	return map_generator.get_speed_mod(tile_x, tile_y)


## Check if position deals damage (barbed wire, craters)
func is_damage_tile(world_pos: Vector3) -> bool:
	var tile_x: int = _world_to_tile_x(world_pos.x)
	var tile_y: int = _world_to_tile_y(world_pos.z)
	return map_generator.is_damage_tile(tile_x, tile_y)


func _world_to_tile_x(world_x: float) -> int:
	var offset_x: float = -float(map_generator.map_width) * TILE_SIZE / 2.0
	return int((world_x - offset_x) / TILE_SIZE)


func _world_to_tile_y(world_z: float) -> int:
	var offset_z: float = -float(map_generator.map_height) * TILE_SIZE / 2.0
	return int((world_z - offset_z) / TILE_SIZE)
