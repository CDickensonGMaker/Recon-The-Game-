## ww2_map_generator.gd - Procedural WW2 ruined town and field generator
## PS1/PS2 retro-style 100x100 tilemap generator for Godot 4.5
@tool
class_name WW2MapGenerator
extends Node

signal map_generated
signal generation_progress(percent: float)

## Tile type enumeration matching tileset IDs
enum Tile {
	GRASS = 0,
	DIRT = 1,
	MUD = 2,
	ROAD_H = 3,
	ROAD_V = 4,
	CROSSROAD = 5,
	RUBBLE = 6,
	WALL_N = 7,
	WALL_S = 8,
	WALL_E = 9,
	WALL_W = 10,
	FLOOR = 11,
	CRATER = 12,
	WATER = 13,
	BRIDGE = 14,
	TRENCH_H = 15,
	TRENCH_V = 16,
	BARBED_WIRE = 17,
	TREE = 18,
	DEAD_TREE = 19,
	SANDBAG = 20,
	TANK_WRECK = 21,
	CHURCH = 22,
	GRAVESTONE = 23,
	FENCE = 24,
	HAY_BALE = 25,
	CROPS = 26,
	DESTROYED_WALL = 27,
	DOOR = 28,
	AMMO_CRATE = 29,
	BARREL = 30,
	RUINED_FLOOR = 31,
}

## Tile properties lookup
const TILE_PROPERTIES: Dictionary = {
	Tile.GRASS: {"solid": false, "walkable": true, "damage": false, "speed": 1.0},
	Tile.DIRT: {"solid": false, "walkable": true, "damage": false, "speed": 1.0},
	Tile.MUD: {"solid": false, "walkable": true, "damage": false, "speed": 0.6},
	Tile.ROAD_H: {"solid": false, "walkable": true, "damage": false, "speed": 1.2},
	Tile.ROAD_V: {"solid": false, "walkable": true, "damage": false, "speed": 1.2},
	Tile.CROSSROAD: {"solid": false, "walkable": true, "damage": false, "speed": 1.2},
	Tile.RUBBLE: {"solid": false, "walkable": true, "damage": false, "speed": 0.5},
	Tile.WALL_N: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.WALL_S: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.WALL_E: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.WALL_W: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.FLOOR: {"solid": false, "walkable": true, "damage": false, "speed": 1.0},
	Tile.CRATER: {"solid": false, "walkable": true, "damage": true, "speed": 0.4},
	Tile.WATER: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.BRIDGE: {"solid": false, "walkable": true, "damage": false, "speed": 1.0},
	Tile.TRENCH_H: {"solid": false, "walkable": true, "damage": false, "speed": 0.7},
	Tile.TRENCH_V: {"solid": false, "walkable": true, "damage": false, "speed": 0.7},
	Tile.BARBED_WIRE: {"solid": false, "walkable": true, "damage": true, "speed": 0.3},
	Tile.TREE: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.DEAD_TREE: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.SANDBAG: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.TANK_WRECK: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.CHURCH: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.GRAVESTONE: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.FENCE: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.HAY_BALE: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.CROPS: {"solid": false, "walkable": true, "damage": false, "speed": 0.7},
	Tile.DESTROYED_WALL: {"solid": false, "walkable": true, "damage": false, "speed": 0.5},
	Tile.DOOR: {"solid": false, "walkable": true, "damage": false, "speed": 1.0},
	Tile.AMMO_CRATE: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.BARREL: {"solid": true, "walkable": false, "damage": false, "speed": 0.0},
	Tile.RUINED_FLOOR: {"solid": false, "walkable": true, "damage": false, "speed": 0.8},
}

## Configuration
@export var target_tilemap: TileMap
@export var map_seed: int = 0
@export var map_width: int = 100
@export var map_height: int = 100
@export var generate_now: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate()
		generate_now = false

## Generation parameters
@export_group("Town")
@export var town_center_x: int = 50
@export var town_center_y: int = 50
@export var town_radius: int = 25
@export var building_count: int = 12
@export var destruction_level: float = 0.4  # 0-1, how destroyed buildings are

@export_group("Terrain")
@export var river_enabled: bool = true
@export var river_width: int = 3
@export var farmland_patches: int = 4
@export var crater_count: int = 15

@export_group("Military")
@export var trench_enabled: bool = true
@export var tank_wreck_count: int = 3
@export var sandbag_positions: int = 8

@export_group("Vegetation")
@export var tree_density: float = 0.03
@export var dead_tree_ratio: float = 0.4

## Internal state
var map_data: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var buildings: Array = []  # Track building positions for spawning


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Auto-generate in game mode if no map exists
		if map_data.is_empty():
			generate()


## Main generation entry point
func generate() -> Array:
	if map_seed == 0:
		rng.randomize()
		map_seed = rng.seed
	else:
		rng.seed = map_seed

	print("[WW2 MapGen] Generating map with seed: %d" % map_seed)

	# Initialize empty map
	map_data.clear()
	buildings.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append(Tile.GRASS)
		map_data.append(row)

	# Run generation passes
	_pass_base_terrain()
	generation_progress.emit(10.0)

	_pass_farmland()
	generation_progress.emit(20.0)

	if river_enabled:
		_pass_river()
	generation_progress.emit(30.0)

	_pass_roads()
	generation_progress.emit(40.0)

	_pass_town_buildings()
	generation_progress.emit(50.0)

	_pass_church_graveyard()
	generation_progress.emit(60.0)

	_pass_craters()
	generation_progress.emit(70.0)

	if trench_enabled:
		_pass_trenches()
	generation_progress.emit(80.0)

	_pass_vegetation()
	generation_progress.emit(85.0)

	_pass_tank_wrecks()
	generation_progress.emit(90.0)

	_pass_sandbag_positions()
	generation_progress.emit(95.0)

	_pass_fences()
	generation_progress.emit(100.0)

	# Apply to tilemap
	_apply_to_tilemap()

	print("[WW2 MapGen] Generation complete!")
	map_generated.emit()

	return map_data


## Pass 1: Base terrain with dirt/mud patches
func _pass_base_terrain() -> void:
	for i in range(rng.randi_range(8, 15)):
		var cx: int = rng.randi_range(0, map_width - 1)
		var cy: int = rng.randi_range(0, map_height - 1)
		var radius: int = rng.randi_range(5, 15)
		var tile: Tile = Tile.DIRT if rng.randf() > 0.3 else Tile.MUD

		_fill_circle(cx, cy, radius, tile, 0.7)


## Pass 2: Farmland with crops and hay bales
func _pass_farmland() -> void:
	for i in range(farmland_patches):
		# Place farms away from town center
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(town_radius + 10, minf(map_width, map_height) / 2.0 - 5)
		var fx: int = int(town_center_x + cos(angle) * dist)
		var fy: int = int(town_center_y + sin(angle) * dist)

		var fw: int = rng.randi_range(8, 15)
		var fh: int = rng.randi_range(8, 15)

		# Fill with crops
		for x in range(fx, fx + fw):
			for y in range(fy, fy + fh):
				if _in_bounds(x, y) and map_data[y][x] == Tile.GRASS:
					map_data[y][x] = Tile.CROPS

		# Add hay bales
		for j in range(rng.randi_range(2, 5)):
			var hx: int = rng.randi_range(fx, fx + fw - 1)
			var hy: int = rng.randi_range(fy, fy + fh - 1)
			if _in_bounds(hx, hy):
				map_data[hy][hx] = Tile.HAY_BALE


## Pass 3: Meandering river
func _pass_river() -> void:
	var start_y: int = rng.randi_range(10, map_height - 10)
	var current_y: float = float(start_y)

	for x in range(map_width):
		# Meander
		current_y += rng.randf_range(-1.5, 1.5)
		current_y = clampf(current_y, 5.0, float(map_height - 5))

		# Variable width
		var width: int = river_width + rng.randi_range(-1, 1)

		for dy in range(-width, width + 1):
			var y: int = int(current_y) + dy
			if _in_bounds(x, y):
				map_data[y][x] = Tile.WATER


## Pass 4: Roads with bridges over water
func _pass_roads() -> void:
	# Main horizontal road through town
	var road_y: int = town_center_y + rng.randi_range(-5, 5)
	for x in range(map_width):
		if _in_bounds(x, road_y):
			if map_data[road_y][x] == Tile.WATER:
				map_data[road_y][x] = Tile.BRIDGE
			else:
				map_data[road_y][x] = Tile.ROAD_H

	# Main vertical road through town
	var road_x: int = town_center_x + rng.randi_range(-5, 5)
	for y in range(map_height):
		if _in_bounds(road_x, y):
			if map_data[y][road_x] == Tile.WATER:
				map_data[y][road_x] = Tile.BRIDGE
			elif map_data[y][road_x] == Tile.ROAD_H:
				map_data[y][road_x] = Tile.CROSSROAD
			else:
				map_data[y][road_x] = Tile.ROAD_V

	# Secondary roads
	for i in range(rng.randi_range(2, 4)):
		var is_horizontal: bool = rng.randf() > 0.5
		if is_horizontal:
			var sy: int = town_center_y + rng.randi_range(-town_radius, town_radius)
			var start_x: int = rng.randi_range(town_center_x - town_radius, town_center_x)
			var end_x: int = rng.randi_range(town_center_x, town_center_x + town_radius)
			for x in range(start_x, end_x):
				if _in_bounds(x, sy):
					if map_data[sy][x] == Tile.ROAD_V:
						map_data[sy][x] = Tile.CROSSROAD
					elif map_data[sy][x] == Tile.WATER:
						map_data[sy][x] = Tile.BRIDGE
					elif not _is_building_tile(map_data[sy][x]):
						map_data[sy][x] = Tile.ROAD_H
		else:
			var sx: int = town_center_x + rng.randi_range(-town_radius, town_radius)
			var start_y: int = rng.randi_range(town_center_y - town_radius, town_center_y)
			var end_y: int = rng.randi_range(town_center_y, town_center_y + town_radius)
			for y in range(start_y, end_y):
				if _in_bounds(sx, y):
					if map_data[y][sx] == Tile.ROAD_H:
						map_data[y][sx] = Tile.CROSSROAD
					elif map_data[y][sx] == Tile.WATER:
						map_data[y][sx] = Tile.BRIDGE
					elif not _is_building_tile(map_data[y][sx]):
						map_data[y][sx] = Tile.ROAD_V


## Pass 5: Town buildings with destruction
func _pass_town_buildings() -> void:
	var attempts: int = 0
	var placed: int = 0

	while placed < building_count and attempts < building_count * 10:
		attempts += 1

		var bw: int = rng.randi_range(4, 8)
		var bh: int = rng.randi_range(4, 8)

		# Position near roads in town
		var bx: int = town_center_x + rng.randi_range(-town_radius + 2, town_radius - bw - 2)
		var by: int = town_center_y + rng.randi_range(-town_radius + 2, town_radius - bh - 2)

		# Check if area is clear
		if not _area_clear(bx - 1, by - 1, bw + 2, bh + 2):
			continue

		# Place building
		_place_building(bx, by, bw, bh)
		buildings.append({"x": bx, "y": by, "w": bw, "h": bh})
		placed += 1


func _place_building(bx: int, by: int, bw: int, bh: int) -> void:
	var dest_level: float = destruction_level + rng.randf_range(-0.2, 0.2)
	dest_level = clampf(dest_level, 0.0, 1.0)

	# Floor
	for x in range(bx, bx + bw):
		for y in range(by, by + bh):
			if _in_bounds(x, y):
				if rng.randf() < dest_level * 0.3:
					map_data[y][x] = Tile.RUINED_FLOOR
				else:
					map_data[y][x] = Tile.FLOOR

	# Walls
	for x in range(bx, bx + bw):
		# North wall
		if _in_bounds(x, by):
			if rng.randf() < dest_level:
				map_data[by][x] = Tile.DESTROYED_WALL if rng.randf() > 0.5 else Tile.RUBBLE
			else:
				map_data[by][x] = Tile.WALL_N
		# South wall
		if _in_bounds(x, by + bh - 1):
			if rng.randf() < dest_level:
				map_data[by + bh - 1][x] = Tile.DESTROYED_WALL if rng.randf() > 0.5 else Tile.RUBBLE
			else:
				map_data[by + bh - 1][x] = Tile.WALL_S

	for y in range(by, by + bh):
		# West wall
		if _in_bounds(bx, y):
			if rng.randf() < dest_level:
				map_data[y][bx] = Tile.DESTROYED_WALL if rng.randf() > 0.5 else Tile.RUBBLE
			else:
				map_data[y][bx] = Tile.WALL_W
		# East wall
		if _in_bounds(bx + bw - 1, y):
			if rng.randf() < dest_level:
				map_data[y][bx + bw - 1] = Tile.DESTROYED_WALL if rng.randf() > 0.5 else Tile.RUBBLE
			else:
				map_data[y][bx + bw - 1] = Tile.WALL_E

	# Add door(s)
	var door_side: int = rng.randi_range(0, 3)
	match door_side:
		0:  # North
			var dx: int = bx + rng.randi_range(1, bw - 2)
			if _in_bounds(dx, by):
				map_data[by][dx] = Tile.DOOR
		1:  # South
			var dx: int = bx + rng.randi_range(1, bw - 2)
			if _in_bounds(dx, by + bh - 1):
				map_data[by + bh - 1][dx] = Tile.DOOR
		2:  # West
			var dy: int = by + rng.randi_range(1, bh - 2)
			if _in_bounds(bx, dy):
				map_data[dy][bx] = Tile.DOOR
		3:  # East
			var dy: int = by + rng.randi_range(1, bh - 2)
			if _in_bounds(bx + bw - 1, dy):
				map_data[dy][bx + bw - 1] = Tile.DOOR

	# Interior rubble and props
	for x in range(bx + 1, bx + bw - 1):
		for y in range(by + 1, by + bh - 1):
			if _in_bounds(x, y) and rng.randf() < dest_level * 0.4:
				var prop: Tile = [Tile.RUBBLE, Tile.BARREL, Tile.AMMO_CRATE].pick_random()
				map_data[y][x] = prop


## Pass 6: Church and graveyard
func _pass_church_graveyard() -> void:
	# Find spot for church near town center
	var cx: int = town_center_x + rng.randi_range(-10, 10)
	var cy: int = town_center_y + rng.randi_range(-10, 10)

	if _area_clear(cx, cy, 6, 8):
		# Church building
		for x in range(cx, cx + 6):
			for y in range(cy, cy + 8):
				if _in_bounds(x, y):
					if x == cx or x == cx + 5 or y == cy or y == cy + 7:
						map_data[y][x] = Tile.CHURCH
					else:
						map_data[y][x] = Tile.FLOOR

		# Door
		if _in_bounds(cx + 2, cy + 7):
			map_data[cy + 7][cx + 2] = Tile.DOOR
		if _in_bounds(cx + 3, cy + 7):
			map_data[cy + 7][cx + 3] = Tile.DOOR

		# Graveyard
		var gy: int = cy - rng.randi_range(4, 6)
		for i in range(rng.randi_range(6, 12)):
			var gx: int = cx + rng.randi_range(-2, 7)
			var stone_y: int = gy + rng.randi_range(0, 3)
			if _in_bounds(gx, stone_y) and map_data[stone_y][gx] == Tile.GRASS:
				map_data[stone_y][gx] = Tile.GRAVESTONE


## Pass 7: Bomb craters
func _pass_craters() -> void:
	for i in range(crater_count):
		var cx: int = rng.randi_range(5, map_width - 5)
		var cy: int = rng.randi_range(5, map_height - 5)
		var radius: int = rng.randi_range(2, 4)

		# Crater center
		_fill_circle(cx, cy, radius, Tile.CRATER, 0.9)

		# Mud ring around crater
		_fill_ring(cx, cy, radius, radius + 2, Tile.MUD, 0.6)


## Pass 8: Trenches
func _pass_trenches() -> void:
	# Main trench line (typically on one side of map)
	var trench_base_y: int = rng.randi_range(map_height - 30, map_height - 15)

	for x in range(10, map_width - 10):
		var ty: int = trench_base_y + int(sin(float(x) * 0.1) * 3.0)
		if _in_bounds(x, ty) and map_data[ty][x] != Tile.WATER:
			map_data[ty][x] = Tile.TRENCH_H

			# Vertical offshoots
			if rng.randf() < 0.1:
				var offshoot_len: int = rng.randi_range(3, 8)
				for oy in range(offshoot_len):
					if _in_bounds(x, ty - oy) and map_data[ty - oy][x] != Tile.WATER:
						map_data[ty - oy][x] = Tile.TRENCH_V

	# Sandbags along trench
	for x in range(10, map_width - 10, 5):
		var ty: int = trench_base_y + int(sin(float(x) * 0.1) * 3.0)
		if _in_bounds(x, ty - 1) and rng.randf() < 0.5:
			map_data[ty - 1][x] = Tile.SANDBAG

	# Barbed wire in front of trench
	for x in range(10, map_width - 10):
		var ty: int = trench_base_y + int(sin(float(x) * 0.1) * 3.0) + 3
		if _in_bounds(x, ty) and map_data[ty][x] == Tile.GRASS and rng.randf() < 0.4:
			map_data[ty][x] = Tile.BARBED_WIRE


## Pass 9: Vegetation
func _pass_vegetation() -> void:
	for x in range(map_width):
		for y in range(map_height):
			if map_data[y][x] == Tile.GRASS and rng.randf() < tree_density:
				# More dead trees near town/craters
				var dist_to_town: float = Vector2(x, y).distance_to(Vector2(town_center_x, town_center_y))
				var dead_chance: float = dead_tree_ratio
				if dist_to_town < town_radius:
					dead_chance += 0.3

				if rng.randf() < dead_chance:
					map_data[y][x] = Tile.DEAD_TREE
				else:
					map_data[y][x] = Tile.TREE


## Pass 10: Tank wrecks
func _pass_tank_wrecks() -> void:
	for i in range(tank_wreck_count):
		var tx: int = rng.randi_range(10, map_width - 10)
		var ty: int = rng.randi_range(10, map_height - 10)

		if map_data[ty][tx] in [Tile.GRASS, Tile.DIRT, Tile.MUD]:
			map_data[ty][tx] = Tile.TANK_WRECK
			# Debris around tank
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if _in_bounds(tx + dx, ty + dy) and rng.randf() < 0.3:
						if map_data[ty + dy][tx + dx] == Tile.GRASS:
							map_data[ty + dy][tx + dx] = Tile.RUBBLE


## Pass 11: Sandbag positions
func _pass_sandbag_positions() -> void:
	for i in range(sandbag_positions):
		var sx: int = rng.randi_range(10, map_width - 10)
		var sy: int = rng.randi_range(10, map_height - 10)

		if map_data[sy][sx] in [Tile.GRASS, Tile.DIRT]:
			# Create small sandbag emplacement
			map_data[sy][sx] = Tile.SANDBAG
			if _in_bounds(sx + 1, sy) and map_data[sy][sx + 1] in [Tile.GRASS, Tile.DIRT]:
				map_data[sy][sx + 1] = Tile.SANDBAG
			if _in_bounds(sx, sy + 1) and map_data[sy + 1][sx] in [Tile.GRASS, Tile.DIRT]:
				map_data[sy + 1][sx] = Tile.SANDBAG


## Pass 12: Fences
func _pass_fences() -> void:
	# Add fences along some field edges
	for x in range(map_width):
		for y in range(map_height):
			if map_data[y][x] == Tile.CROPS:
				# Check if at edge of crops
				if _in_bounds(x - 1, y) and map_data[y][x - 1] == Tile.GRASS and rng.randf() < 0.3:
					map_data[y][x - 1] = Tile.FENCE
				if _in_bounds(x, y - 1) and map_data[y - 1][x] == Tile.GRASS and rng.randf() < 0.3:
					map_data[y - 1][x] = Tile.FENCE


## Apply generated data to tilemap
func _apply_to_tilemap() -> void:
	if not target_tilemap:
		push_warning("[WW2 MapGen] No target tilemap assigned!")
		return

	target_tilemap.clear()

	for y in range(map_height):
		for x in range(map_width):
			var tile_id: int = map_data[y][x]
			var atlas_coords: Vector2i = _tile_id_to_atlas(tile_id)
			target_tilemap.set_cell(0, Vector2i(x, y), 0, atlas_coords)


func _tile_id_to_atlas(tile_id: int) -> Vector2i:
	# Horizontal strip layout: ID maps directly to X coordinate
	return Vector2i(tile_id, 0)


## Utility functions
func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < map_width and y >= 0 and y < map_height


func _area_clear(x: int, y: int, w: int, h: int) -> bool:
	for cx in range(x, x + w):
		for cy in range(y, y + h):
			if not _in_bounds(cx, cy):
				return false
			if _is_blocking_tile(map_data[cy][cx]):
				return false
	return true


func _is_blocking_tile(tile: Tile) -> bool:
	return tile in [Tile.WATER, Tile.WALL_N, Tile.WALL_S, Tile.WALL_E, Tile.WALL_W,
					Tile.FLOOR, Tile.CHURCH, Tile.ROAD_H, Tile.ROAD_V, Tile.CROSSROAD]


func _is_building_tile(tile: Tile) -> bool:
	return tile in [Tile.WALL_N, Tile.WALL_S, Tile.WALL_E, Tile.WALL_W,
					Tile.FLOOR, Tile.DOOR, Tile.RUINED_FLOOR]


func _fill_circle(cx: int, cy: int, radius: int, tile: Tile, density: float = 1.0) -> void:
	for x in range(cx - radius, cx + radius + 1):
		for y in range(cy - radius, cy + radius + 1):
			if _in_bounds(x, y):
				var dist: float = Vector2(x, y).distance_to(Vector2(cx, cy))
				if dist <= radius and rng.randf() < density:
					map_data[y][x] = tile


func _fill_ring(cx: int, cy: int, inner_radius: int, outer_radius: int, tile: Tile, density: float = 1.0) -> void:
	for x in range(cx - outer_radius, cx + outer_radius + 1):
		for y in range(cy - outer_radius, cy + outer_radius + 1):
			if _in_bounds(x, y):
				var dist: float = Vector2(x, y).distance_to(Vector2(cx, cy))
				if dist >= inner_radius and dist <= outer_radius and rng.randf() < density:
					if map_data[y][x] == Tile.GRASS:
						map_data[y][x] = tile


## Query functions
func get_tile(x: int, y: int) -> Tile:
	if _in_bounds(x, y):
		return map_data[y][x] as Tile
	return Tile.GRASS


func is_solid(x: int, y: int) -> bool:
	var tile := get_tile(x, y)
	return TILE_PROPERTIES[tile]["solid"]


func is_damage_tile(x: int, y: int) -> bool:
	var tile := get_tile(x, y)
	return TILE_PROPERTIES[tile]["damage"]


func get_speed_mod(x: int, y: int) -> float:
	var tile := get_tile(x, y)
	return TILE_PROPERTIES[tile]["speed"]


func get_tile_name(x: int, y: int) -> String:
	var tile := get_tile(x, y)
	return Tile.keys()[tile]


## Save/Load
func save_to_json(path: String) -> void:
	var data := {
		"seed": map_seed,
		"width": map_width,
		"height": map_height,
		"tiles": map_data,
		"buildings": buildings
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[WW2 MapGen] Saved map to: " + path)
	else:
		push_error("[WW2 MapGen] Failed to save map to: " + path)


func load_from_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()

		if error == OK:
			var data: Dictionary = json.data
			map_seed = data.get("seed", 0)
			map_width = data.get("width", 100)
			map_height = data.get("height", 100)
			map_data = data.get("tiles", [])
			buildings = data.get("buildings", [])
			_apply_to_tilemap()
			print("[WW2 MapGen] Loaded map from: " + path)
		else:
			push_error("[WW2 MapGen] Failed to parse JSON: " + json.get_error_message())
	else:
		push_error("[WW2 MapGen] Failed to open file: " + path)


## Stats
func print_stats() -> void:
	var stats := get_stats()
	print("=== WW2 Map Statistics ===")
	print("Seed: %d" % map_seed)
	print("Size: %dx%d" % [map_width, map_height])
	print("Buildings: %d" % stats["building_count"])
	print("Walkable tiles: %d (%.1f%%)" % [stats["walkable"], stats["walkable_percent"]])
	print("Solid tiles: %d (%.1f%%)" % [stats["solid"], stats["solid_percent"]])
	print("Damage tiles: %d" % stats["damage"])
	print("===========================")


func get_stats() -> Dictionary:
	var walkable: int = 0
	var solid: int = 0
	var damage: int = 0
	var total: int = map_width * map_height

	for y in range(map_height):
		for x in range(map_width):
			var props: Dictionary = TILE_PROPERTIES[map_data[y][x]]
			if props["walkable"]:
				walkable += 1
			if props["solid"]:
				solid += 1
			if props["damage"]:
				damage += 1

	return {
		"seed": map_seed,
		"width": map_width,
		"height": map_height,
		"building_count": buildings.size(),
		"walkable": walkable,
		"walkable_percent": float(walkable) / float(total) * 100.0,
		"solid": solid,
		"solid_percent": float(solid) / float(total) * 100.0,
		"damage": damage
	}


## Get spawn points for gameplay
func get_player_spawn() -> Vector2i:
	# Spawn player near center of town on a road
	for attempts in range(50):
		var x: int = town_center_x + rng.randi_range(-10, 10)
		var y: int = town_center_y + rng.randi_range(-10, 10)
		if _in_bounds(x, y) and map_data[y][x] in [Tile.ROAD_H, Tile.ROAD_V, Tile.CROSSROAD, Tile.FLOOR]:
			return Vector2i(x, y)
	return Vector2i(town_center_x, town_center_y)


func get_enemy_spawns(count: int) -> Array[Vector2i]:
	var spawns: Array[Vector2i] = []
	var attempts: int = 0

	while spawns.size() < count and attempts < count * 20:
		attempts += 1
		var x: int = rng.randi_range(10, map_width - 10)
		var y: int = rng.randi_range(10, map_height - 10)

		# Enemies spawn away from player spawn, in cover or buildings
		var dist_to_center: float = Vector2(x, y).distance_to(Vector2(town_center_x, town_center_y))
		if dist_to_center < 15:
			continue

		if _in_bounds(x, y) and map_data[y][x] in [Tile.FLOOR, Tile.RUINED_FLOOR, Tile.TRENCH_H, Tile.TRENCH_V]:
			spawns.append(Vector2i(x, y))

	return spawns


func get_cover_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	for y in range(map_height):
		for x in range(map_width):
			if map_data[y][x] in [Tile.SANDBAG, Tile.TANK_WRECK, Tile.HAY_BALE]:
				# Find adjacent walkable tile
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if _in_bounds(x + dx, y + dy):
							var adj_tile: Tile = map_data[y + dy][x + dx] as Tile
							if TILE_PROPERTIES[adj_tile]["walkable"]:
								positions.append(Vector2i(x + dx, y + dy))
								break

	return positions
