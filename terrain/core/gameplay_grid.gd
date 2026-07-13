extends RefCounted
class_name GameplayGrid
## Grid-based metadata storage for efficient game logic queries
## Stores elevation, terrain type, movement cost, cover values per cell
## Designed for RTS gameplay - travel speed modifiers, combat bonuses, pathfinding

signal grid_updated(region: Rect2i)

# Grid dimensions
var grid_size: int = 256  # Cells per side
var cell_size_meters: float = 12.0  # Meters per cell (larger than heightmap for perf)
var world_size: float = 3072.0  # Total world size in meters

# Terrain type enum matching clearing_system
enum TerrainType {
	CLEAR = 0,       # Open ground, fastest movement
	RICE_PADDY = 1,  # Flooded field, slow movement, no cover
	GRASSLAND = 2,   # Light vegetation, normal speed
	LIGHT_JUNGLE = 3,  # Light cover, slight slow
	MEDIUM_JUNGLE = 4, # Good cover, moderate slow
	HEAVY_JUNGLE = 5,  # Excellent cover, very slow
	WATER = 6,       # Impassable for most units
	CLIFF = 7,       # Impassable, blocks LOS
}

# Movement cost multipliers (1.0 = normal, higher = slower)
const MOVEMENT_COSTS: Dictionary = {
	TerrainType.CLEAR: 1.0,
	TerrainType.RICE_PADDY: 1.8,
	TerrainType.GRASSLAND: 1.1,
	TerrainType.LIGHT_JUNGLE: 1.3,
	TerrainType.MEDIUM_JUNGLE: 1.6,
	TerrainType.HEAVY_JUNGLE: 2.2,
	TerrainType.WATER: 99.0,  # Effectively impassable
	TerrainType.CLIFF: 99.0,
}

# Cover values (0.0 = no cover, 1.0 = full concealment)
const COVER_VALUES: Dictionary = {
	TerrainType.CLEAR: 0.0,
	TerrainType.RICE_PADDY: 0.1,
	TerrainType.GRASSLAND: 0.15,
	TerrainType.LIGHT_JUNGLE: 0.35,
	TerrainType.MEDIUM_JUNGLE: 0.55,
	TerrainType.HEAVY_JUNGLE: 0.8,
	TerrainType.WATER: 0.0,
	TerrainType.CLIFF: 0.9,
}

# Defense bonus multipliers (damage reduction when in cover)
const DEFENSE_BONUS: Dictionary = {
	TerrainType.CLEAR: 1.0,
	TerrainType.RICE_PADDY: 0.95,
	TerrainType.GRASSLAND: 0.9,
	TerrainType.LIGHT_JUNGLE: 0.8,
	TerrainType.MEDIUM_JUNGLE: 0.65,
	TerrainType.HEAVY_JUNGLE: 0.5,
	TerrainType.WATER: 1.0,
	TerrainType.CLIFF: 0.4,
}

# Grid data arrays (packed for memory efficiency)
var elevation: PackedFloat32Array      # Height in meters
var slope: PackedFloat32Array          # Slope angle 0-1 (0=flat, 1=vertical)
var terrain_type: PackedByteArray     # TerrainType enum
var vegetation_density: PackedFloat32Array  # 0-1 vegetation coverage
var is_passable: PackedByteArray      # 0=blocked, 1=passable

# References
var heightmap_storage: RefCounted  # HeightmapStorage
var clearing_system: Node
var water_system: Node  # WaterSystem for water queries


func _init(world_size_meters: float = 3072.0, cells_per_side: int = 256) -> void:
	world_size = world_size_meters
	grid_size = cells_per_side
	cell_size_meters = world_size / grid_size

	# Initialize arrays
	var total_cells: int = grid_size * grid_size
	elevation.resize(total_cells)
	slope.resize(total_cells)
	terrain_type.resize(total_cells)
	vegetation_density.resize(total_cells)
	is_passable.resize(total_cells)

	# Default values
	elevation.fill(0.0)
	slope.fill(0.0)
	terrain_type.fill(TerrainType.GRASSLAND)
	vegetation_density.fill(0.5)
	is_passable.fill(1)

	print("[GameplayGrid] Initialized %dx%d grid (%.1fm cells, %.2f MB)" % [
		grid_size, grid_size, cell_size_meters,
		(total_cells * (4 + 4 + 1 + 4 + 1)) / 1048576.0
	])


## Set references
func set_heightmap(hm: RefCounted) -> void:
	heightmap_storage = hm


func set_clearing_system(cs: Node) -> void:
	clearing_system = cs


func set_water_system(ws: Node) -> void:
	water_system = ws


## Build grid from heightmap and vegetation data
func build_from_terrain() -> void:
	if not heightmap_storage:
		push_warning("[GameplayGrid] No heightmap set, using defaults")
		return

	print("[GameplayGrid] Building grid from terrain data...")
	var start_time := Time.get_ticks_msec()

	for gz in grid_size:
		for gx in grid_size:
			var idx: int = gz * grid_size + gx

			# Get world position for this cell center
			var world_x: float = (gx + 0.5) * cell_size_meters
			var world_z: float = (gz + 0.5) * cell_size_meters

			# Sample elevation
			var h: float = heightmap_storage.sample_world(world_x, world_z)
			elevation[idx] = h

			# Calculate slope from heightmap normal
			var normal: Vector3 = heightmap_storage.get_normal_world(world_x, world_z)
			var slope_val: float = 1.0 - normal.y  # 0=flat, 1=vertical
			slope[idx] = clampf(slope_val, 0.0, 1.0)

			# Determine terrain type from slope and elevation
			var ttype: int = _determine_terrain_type(h, slope_val, world_x, world_z)
			terrain_type[idx] = ttype

			# Passability. WATER used to be a flat NO - a knee-deep creek and a 50m river
			# were the same wall. But the creeks ARE the escape routes (water breaks the
			# breadcrumb trail - EnemySquad, ADR-021/LW-12), and a barrier you cannot enter
			# cannot save you. So: WADE THE SHALLOWS, ford the deep.
			var impassable: bool = ttype == TerrainType.CLIFF
			if ttype == TerrainType.WATER:
				impassable = get_water_depth(Vector3(world_x, 0.0, world_z)) > WADE_DEPTH_M
			is_passable[idx] = 0 if impassable else 1

			# Get vegetation density from clearing system if available
			if clearing_system and clearing_system.has_method("get_density_at"):
				vegetation_density[idx] = clearing_system.get_density_at(world_x, world_z)
			else:
				# Estimate from terrain type
				vegetation_density[idx] = _estimate_vegetation(ttype)

	_apply_riparian_belt()
	_roof_the_creeks()

	var elapsed: int = Time.get_ticks_msec() - start_time
	print("[GameplayGrid] Grid built in %dms" % elapsed)


## GALLERY FOREST — the green tunnel along every watercourse.
##
## THE BUG THIS FIXES. _determine_terrain_type() reads elevation and slope ONLY. A
## creek valley is low and flat, so its BANKS classified as RICE_PADDY (density 0.2)
## or GRASSLAND (0.3) — a sight cap around 130m. Every stream in the game ran through
## OPEN GROUND.
##
## Which made water a DEATH TRAP instead of an escape route: wading breaks the enemy's
## breadcrumb trail (shipped 2026-07-12), but you were doing it slow, loud, and visible
## from 130m. The exact opposite of the thing it exists for.
##
## In life it is the other way round. Water plus edge-light is a riot of growth: a
## watercourse is the DENSEST vegetation in the jungle, and a Vietnamese stream is a
## tunnel of green. This dilates the water mask outward and grows real gallery forest
## on the banks, densest at the water and thinning with distance.
##
## Now the creek both ERASES YOUR TRAIL and HIDES YOU, and the hydrology network the
## terrain already generates becomes the E&E network.
## ========================= THE DENSITY KNOBS =========================
## vegetation_density (0-1) is THE number the AI reads. enemy_base._sight_cap()
## lerps 140m (open) -> 45m (deep jungle) straight off it. Turn these and you turn
## how far the enemy can see you, everywhere, at once.
##
## FOUR TABLES DECIDE WHAT THE JUNGLE IS. They are separate and they CAN disagree:
##   1. _determine_terrain_type()  (below)  elevation/slope -> WHICH terrain type
##   2. _estimate_vegetation()     (below)  terrain type    -> the AI's density   <-- THE ONE THAT MATTERS
##   3. JunglePatchLayer.TYPE_DENSITY       terrain type    -> which 12m patches get stamped
##   4. VegetationManager.TYPE_PROPS        terrain type    -> how many loose plants get drawn
## 2 is the truth the AI plays against. 3 and 4 are what the player SEES. If they
## drift apart, the jungle lies: it looks thick and they shoot you through it.
const RIPARIAN_M: float = 22.0     ## how far gallery forest reaches from the bank
const GALLERY_MIN: float = 0.55    ## density at the OUTER edge of the belt
const GALLERY_MAX: float = 0.95    ## density right at the waterline
const WADE_DEPTH_M: float = 1.2    ## deeper than this and you are swimming, not wading

## THE ROOF. A narrow creek in the forest is COVERED - the canopy from both banks
## meets over the water. A wide river is open to the sky. This is the difference
## between a stream you can escape down and a stream that gets you killed.
const ROOF_SAMPLE_M: float = 11.0  ## how far out we look to decide "is this narrow?"
const ROOF_NARROW: float = 0.72    ## land fraction at/above which the canopy fully closes
const ROOF_WIDE: float = 0.30      ## land fraction at/below which it is open sky
const ROOF_FACTOR: float = 0.95    ## the canopy closes, but never quite like solid ground

func _apply_riparian_belt() -> void:
	var reach: int = maxi(1, int(ceil(RIPARIAN_M / cell_size_meters)))
	# Multi-source BFS out from every water cell: O(cells), once, at generation.
	var dist := PackedInt32Array()
	dist.resize(terrain_type.size())
	dist.fill(-1)
	var frontier: Array[int] = []
	for i in range(terrain_type.size()):
		if terrain_type[i] == TerrainType.WATER:
			dist[i] = 0
			frontier.append(i)
	if frontier.is_empty():
		return

	var banks: int = 0
	while not frontier.is_empty():
		var next: Array[int] = []
		for idx in frontier:
			var d: int = dist[idx]
			if d >= reach:
				continue
			var gx: int = idx % grid_size
			var gz: int = idx / grid_size
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = gx + o.x
				var nz: int = gz + o.y
				if nx < 0 or nz < 0 or nx >= grid_size or nz >= grid_size:
					continue
				var n: int = nz * grid_size + nx
				if dist[n] != -1:
					continue
				dist[n] = d + 1
				next.append(n)
				# Cliffs stay cliffs; water stays water. Everything else greens up.
				if terrain_type[n] == TerrainType.CLIFF or terrain_type[n] == TerrainType.WATER:
					continue
				# Densest at the bank, thinning outward.
				var t: float = 1.0 - float(d + 1) / float(reach)
				var gallery: float = lerpf(0.55, 0.95, clampf(t, 0.0, 1.0))
				if gallery > vegetation_density[n]:
					vegetation_density[n] = gallery
					terrain_type[n] = TerrainType.HEAVY_JUNGLE if gallery >= 0.85 						else (TerrainType.MEDIUM_JUNGLE if gallery >= 0.65 else TerrainType.LIGHT_JUNGLE)
					banks += 1
		frontier = next
	print("[GameplayGrid] Gallery forest: %d bank cells greened (reach %.0fm)" % [banks, RIPARIAN_M])


## CREEKS IN THE FOREST — put the roof back on.
##
## Water cells got vegetation_density 0.0 (they fell through _estimate_vegetation's
## default) and JunglePatchLayer.TYPE_DENSITY has no WATER entry, so NOTHING was ever
## stamped on them. A creek was a bald 140m firing lane cut through the middle of the
## best cover on the map - and since wading is how you break the enemy's breadcrumb
## trail, the one escape route in the game was also the one place you could be seen
## from six times further away.
##
## In a real jungle the canopy CLOSES OVER a narrow stream. You wade a green tunnel.
## A wide river is open to the sky and you are naked in it - and that asymmetry is
## exactly the choice we want the player making.
##
## So each water cell is re-scored by HOW NARROW IT IS: look ROOF_SAMPLE_M around it,
## measure what fraction is land, and inherit that land's canopy. A 4m creek between
## two walls of gallery forest is roofed. A 40m river is not.
func _roof_the_creeks() -> void:
	var r: int = maxi(1, int(round(ROOF_SAMPLE_M / cell_size_meters)))
	var roofed: int = 0
	var open_water: int = 0
	var src: PackedFloat32Array = vegetation_density.duplicate()
	for gz in range(grid_size):
		for gx in range(grid_size):
			var i: int = gz * grid_size + gx
			if terrain_type[i] != TerrainType.WATER:
				continue
			var land: int = 0
			var total: int = 0
			var land_veg: float = 0.0
			for oz in range(-r, r + 1):
				for ox in range(-r, r + 1):
					var nx: int = gx + ox
					var nz: int = gz + oz
					if nx < 0 or nz < 0 or nx >= grid_size or nz >= grid_size:
						continue
					var n: int = nz * grid_size + nx
					total += 1
					if terrain_type[n] != TerrainType.WATER:
						land += 1
						land_veg += src[n]
			if total == 0 or land == 0:
				open_water += 1
				continue
			var land_frac: float = float(land) / float(total)
			# Narrow -> the canopy closes. Wide -> open sky. Smooth between.
			var roof: float = smoothstep(ROOF_WIDE, ROOF_NARROW, land_frac)
			var canopy: float = (land_veg / float(land)) * roof * ROOF_FACTOR
			vegetation_density[i] = maxf(vegetation_density[i], canopy)
			if canopy >= 0.6:
				roofed += 1
			else:
				open_water += 1
	print("[GameplayGrid] Creeks roofed: %d water cells under canopy, %d open to the sky" % [
		roofed, open_water])
	grid_updated.emit(Rect2i(0, 0, grid_size, grid_size))


## Determine terrain type from elevation and slope
func _determine_terrain_type(height: float, slope_val: float, wx: float, wz: float) -> int:
	# Check water system first (most accurate water detection)
	if water_system and water_system.has_method("is_water"):
		if water_system.is_water(wx, wz):
			return TerrainType.WATER

	# Cliff detection (steep slopes)
	if slope_val > 0.7:
		return TerrainType.CLIFF

	# Fallback: Low elevation heuristics for flooded areas
	if height < 2.0:
		return TerrainType.WATER

	# Low flat areas = rice paddies
	if height < 5.0 and slope_val < 0.1:
		return TerrainType.RICE_PADDY

	# Medium slopes = lighter vegetation
	if slope_val > 0.4:
		return TerrainType.LIGHT_JUNGLE

	# Based on elevation zones (Vietnam terrain)
	if height < 50.0:
		return TerrainType.RICE_PADDY if randf() < 0.3 else TerrainType.GRASSLAND
	elif height < 150.0:
		return TerrainType.MEDIUM_JUNGLE
	elif height < 250.0:
		return TerrainType.HEAVY_JUNGLE
	else:
		return TerrainType.LIGHT_JUNGLE  # High altitude = sparser


## Estimate vegetation from terrain type
func _estimate_vegetation(ttype: int) -> float:
	match ttype:
		TerrainType.CLEAR: return 0.0
		TerrainType.RICE_PADDY: return 0.2
		TerrainType.GRASSLAND: return 0.3
		TerrainType.LIGHT_JUNGLE: return 0.5
		TerrainType.MEDIUM_JUNGLE: return 0.7
		TerrainType.HEAVY_JUNGLE: return 0.95
		# WATER is left at 0 HERE and then RE-SCORED by _roof_the_creeks(): a narrow
		# channel under jungle is roofed and conceals you; a wide river is open sky.
		# It used to fall through to 0.0 and STAY there, so a creek was a 140m firing
		# lane running through the middle of your best cover.
		_: return 0.0


# ============================================================================
# QUERY METHODS - Fast O(1) lookups for game logic
# ============================================================================

## Convert world position to grid coordinates
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int(world_pos.x / cell_size_meters), 0, grid_size - 1),
		clampi(int(world_pos.z / cell_size_meters), 0, grid_size - 1)
	)


## Convert grid coordinates to world position (cell center)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		(grid_pos.x + 0.5) * cell_size_meters,
		0.0,  # Y filled by caller using get_elevation
		(grid_pos.y + 0.5) * cell_size_meters
	)


## Get cell index from grid coordinates
func _grid_to_index(gx: int, gz: int) -> int:
	return gz * grid_size + gx


## Get elevation at world position (meters)
func get_elevation(world_pos: Vector3) -> float:
	var g := world_to_grid(world_pos)
	return elevation[_grid_to_index(g.x, g.y)]


## Get elevation at grid coordinates
func get_elevation_at(gx: int, gz: int) -> float:
	if gx < 0 or gx >= grid_size or gz < 0 or gz >= grid_size:
		return 0.0
	return elevation[_grid_to_index(gx, gz)]


## Get slope at world position (0=flat, 1=cliff)
func get_slope(world_pos: Vector3) -> float:
	var g := world_to_grid(world_pos)
	return slope[_grid_to_index(g.x, g.y)]


## Get terrain type at world position
func get_terrain_type(world_pos: Vector3) -> int:
	var g := world_to_grid(world_pos)
	return terrain_type[_grid_to_index(g.x, g.y)]


## Get terrain type at grid coordinates
func get_terrain_type_at(gx: int, gz: int) -> int:
	if gx < 0 or gx >= grid_size or gz < 0 or gz >= grid_size:
		return TerrainType.CLIFF
	return terrain_type[_grid_to_index(gx, gz)]


## Get movement cost multiplier at world position
func get_movement_cost(world_pos: Vector3) -> float:
	var ttype: int = get_terrain_type(world_pos)
	var base_cost: float = MOVEMENT_COSTS.get(ttype, 1.0)

	# Slope modifier (steeper = slower)
	var slope_val: float = get_slope(world_pos)
	var slope_penalty: float = 1.0 + slope_val * 0.5  # Up to 50% slower on slopes

	return base_cost * slope_penalty


## Get cover value at world position (0-1)
func get_cover(world_pos: Vector3) -> float:
	var ttype: int = get_terrain_type(world_pos)
	return COVER_VALUES.get(ttype, 0.0)


## Get defense bonus at world position (damage multiplier, lower = better)
func get_defense_bonus(world_pos: Vector3) -> float:
	var ttype: int = get_terrain_type(world_pos)
	return DEFENSE_BONUS.get(ttype, 1.0)


## Get vegetation density at world position (0-1)
func get_vegetation(world_pos: Vector3) -> float:
	var g := world_to_grid(world_pos)
	return vegetation_density[_grid_to_index(g.x, g.y)]


## Check if position is passable
func is_position_passable(world_pos: Vector3) -> bool:
	var g := world_to_grid(world_pos)
	return is_passable[_grid_to_index(g.x, g.y)] == 1


## Check if grid cell is passable
func is_cell_passable(gx: int, gz: int) -> bool:
	if gx < 0 or gx >= grid_size or gz < 0 or gz >= grid_size:
		return false
	return is_passable[_grid_to_index(gx, gz)] == 1


# ============================================================================
# WATER QUERIES - Delegates to WaterSystem for detailed info
# ============================================================================

## Check if position is in water
func is_water(world_pos: Vector3) -> bool:
	if water_system and water_system.has_method("is_water"):
		return water_system.is_water(world_pos.x, world_pos.z)
	# Fallback to terrain type
	return get_terrain_type(world_pos) == TerrainType.WATER


## Get water depth at position (0 if not in water)
func get_water_depth(world_pos: Vector3) -> float:
	if water_system and water_system.has_method("get_water_depth"):
		return water_system.get_water_depth(world_pos.x, world_pos.z)
	return 0.0


## Get water flow direction at position (for boats, debris, unit movement)
func get_water_flow(world_pos: Vector3) -> Vector2:
	if water_system and water_system.has_method("get_flow_at"):
		return water_system.get_flow_at(world_pos.x, world_pos.z)
	return Vector2.ZERO


## Check if position is wadeable (shallow water units can cross)
func is_wadeable(world_pos: Vector3) -> bool:
	var depth: float = get_water_depth(world_pos)
	return depth > 0.0 and depth < 1.5  # Up to 1.5m = wadeable


## Check if position requires swimming/boats
func requires_boat(world_pos: Vector3) -> bool:
	var depth: float = get_water_depth(world_pos)
	return depth >= 1.5  # 1.5m+ = needs boat


## Get elevation difference between two positions (for height advantage)
func get_elevation_advantage(attacker_pos: Vector3, target_pos: Vector3) -> float:
	var attacker_h: float = get_elevation(attacker_pos)
	var target_h: float = get_elevation(target_pos)
	return attacker_h - target_h


## Check line of sight between two positions (basic grid raycast)
func has_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	var from_grid := world_to_grid(from_pos)
	var to_grid := world_to_grid(to_pos)

	var from_h: float = get_elevation(from_pos) + 1.8  # Eye height
	var to_h: float = get_elevation(to_pos) + 1.0  # Target height

	# Bresenham-style raycast through grid
	var dx: int = absi(to_grid.x - from_grid.x)
	var dz: int = absi(to_grid.y - from_grid.y)
	var sx: int = 1 if from_grid.x < to_grid.x else -1
	var sz: int = 1 if from_grid.y < to_grid.y else -1
	var err: int = dx - dz

	var x: int = from_grid.x
	var z: int = from_grid.y
	var steps: int = dx + dz
	if steps == 0:
		return true

	for i in steps:
		# Check if terrain blocks LOS
		var t: float = float(i) / float(steps)
		var expected_h: float = lerpf(from_h, to_h, t)
		var cell_h: float = get_elevation_at(x, z)
		var cell_type: int = get_terrain_type_at(x, z)

		# Cliffs and heavy jungle block LOS
		if cell_type == TerrainType.CLIFF:
			if cell_h > expected_h:
				return false
		elif cell_type == TerrainType.HEAVY_JUNGLE:
			# Dense jungle has chance to block based on distance
			if randf() < 0.3:  # 30% block chance per cell
				return false

		# Step to next cell
		var e2: int = 2 * err
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz

	return true


# ============================================================================
# UPDATE METHODS - Called when terrain changes
# ============================================================================

## Update a region when clearing occurs
func update_region(center: Vector3, radius_meters: float) -> void:
	var g_center := world_to_grid(center)
	var g_radius: int = int(ceil(radius_meters / cell_size_meters))

	var min_x: int = maxi(0, g_center.x - g_radius)
	var max_x: int = mini(grid_size, g_center.x + g_radius + 1)
	var min_z: int = maxi(0, g_center.y - g_radius)
	var max_z: int = mini(grid_size, g_center.y + g_radius + 1)

	for gz in range(min_z, max_z):
		for gx in range(min_x, max_x):
			var idx: int = _grid_to_index(gx, gz)
			var world_x: float = (gx + 0.5) * cell_size_meters
			var world_z: float = (gz + 0.5) * cell_size_meters

			# Re-sample vegetation
			if clearing_system and clearing_system.has_method("get_density_at"):
				var density: float = clearing_system.get_density_at(world_x, world_z)
				vegetation_density[idx] = density

				# Update terrain type based on new vegetation
				if density < 0.1:
					terrain_type[idx] = TerrainType.CLEAR
					is_passable[idx] = 1
				elif density < 0.3:
					terrain_type[idx] = TerrainType.GRASSLAND
				elif density < 0.5:
					terrain_type[idx] = TerrainType.LIGHT_JUNGLE
				elif density < 0.7:
					terrain_type[idx] = TerrainType.MEDIUM_JUNGLE
				# else keep current type

	grid_updated.emit(Rect2i(min_x, min_z, max_x - min_x, max_z - min_z))


## Mark area as cleared (after jungle clearing)
func mark_cleared(center: Vector3, radius_meters: float) -> void:
	var g_center := world_to_grid(center)
	var g_radius: int = int(ceil(radius_meters / cell_size_meters))

	for gz in range(g_center.y - g_radius, g_center.y + g_radius + 1):
		for gx in range(g_center.x - g_radius, g_center.x + g_radius + 1):
			if gx < 0 or gx >= grid_size or gz < 0 or gz >= grid_size:
				continue

			var dist: float = Vector2(gx - g_center.x, gz - g_center.y).length()
			if dist <= g_radius:
				var idx: int = _grid_to_index(gx, gz)
				terrain_type[idx] = TerrainType.CLEAR
				vegetation_density[idx] = 0.0
				is_passable[idx] = 1

	grid_updated.emit(Rect2i(g_center.x - g_radius, g_center.y - g_radius, g_radius * 2, g_radius * 2))


## Get terrain type name (for debug)
func get_terrain_name(ttype: int) -> String:
	match ttype:
		TerrainType.CLEAR: return "Clear"
		TerrainType.RICE_PADDY: return "Rice Paddy"
		TerrainType.GRASSLAND: return "Grassland"
		TerrainType.LIGHT_JUNGLE: return "Light Jungle"
		TerrainType.MEDIUM_JUNGLE: return "Medium Jungle"
		TerrainType.HEAVY_JUNGLE: return "Heavy Jungle"
		TerrainType.WATER: return "Water"
		TerrainType.CLIFF: return "Cliff"
		_: return "Unknown"


## Print grid stats
func print_stats() -> void:
	var counts: Dictionary = {}
	for i in TerrainType.values():
		counts[i] = 0

	for i in terrain_type.size():
		var t: int = terrain_type[i]
		counts[t] = counts.get(t, 0) + 1

	print("[GameplayGrid] Terrain distribution:")
	for ttype: int in counts:
		var pct: float = 100.0 * counts[ttype] / terrain_type.size()
		print("  %s: %d cells (%.1f%%)" % [get_terrain_name(ttype), counts[ttype], pct])
