extends Node3D
class_name TerrainManager
## Manages terrain chunks. On maps <= 2km the whole grid loads once, behind the loading
## screen, and stays resident for the mission (ADR-013) - chunk count is invariant after
## terrain_ready. The streaming path below is dormant, kept for future 3km+ AOs.

const HeightmapStorageClass := preload("res://terrain/core/heightmap_storage.gd")
const TerrainChunkClass := preload("res://terrain/core/terrain_chunk.gd")
const RiverGeneratorClass := preload("res://terrain/water/river_generator.gd")

signal terrain_ready
## Terrain heights changed in this world-space rect (cell-accurate, not
## chunk-aligned). Anything that baked heights at build time re-seats on this -
## the wire-is-law lesson: one terrain-change channel, every height consumer
## listens or floats.
signal region_rebuilt(world_rect: Rect2)

@export var map_size: float = 3000.0  # Playable map size in meters
@export var chunk_size: float = 256.0  # Chunk size in meters
@export var cell_size: float = 2.0    # Height sample resolution
const WORLD_HEIGHT_MAX: float = 350.0  # Shader/world height cap.
@export var height_scale: float = 280.0  # Max terrain height (legacy; see WORLD_HEIGHT_MAX)

@export var load_distance: int = 3     # Chunks to load around camera
@export var unload_distance: int = 5   # Chunks to unload beyond this

## ADR-013: maps at or below this size load whole and never stream (resident world).
const STREAMING_MIN_MAP_SIZE: float = 2000.0

@export var rivers_enabled: bool = true
@export var river_count: int = 6  # Number of rivers to generate

var heightmap: RefCounted  # HeightmapStorage
var chunks: Dictionary = {}  # Vector2i -> TerrainChunk
var loading_chunks: Array[Vector2i] = []

var is_ready: bool = false
var chunks_per_side: int  # Chunks per side
var chunk_cells: int

var camera: Camera3D
var terrain_generator: Node  # TerrainEngine autoload
var vegetation_manager: Node  # VegetationManager - set externally for rice paddy coloring

var river_paths: Array = []

func _ready() -> void:
	chunks_per_side = int(ceil(map_size / chunk_size))
	chunk_cells = int(chunk_size / cell_size) + 1  # +1 for edge overlap

	print("[TerrainManager] Map: %.0fm (%dx%d chunks)" % [
		map_size, chunks_per_side, chunks_per_side
	])

	terrain_generator = get_node_or_null("/root/TerrainEngine")

	heightmap = HeightmapStorageClass.new(map_size, cell_size)


func _process(delta: float) -> void:
	if not is_ready:
		return

	# ADR-013: streaming is disabled on <= 2km AOs - the world is fully resident and
	# chunk count must not change after terrain_ready. Kept live only for 3km+ maps.
	if camera and map_size > STREAMING_MIN_MAP_SIZE:
		_stream_chunks_around_camera()


func _rebuild_chunk_immediate(coord: Vector2i) -> void:
	if not chunks.has(coord):
		return

	# Clear vegetation visuals but preserve placement cache
	if vegetation_manager and vegetation_manager.has_method("clear_chunk_visuals"):
		vegetation_manager.clear_chunk_visuals(coord)

	# Unload chunk without touching vegetation (we already handled it)
	var chunk: Node3D = chunks[coord]
	chunk.unload()
	chunk.queue_free()
	chunks.erase(coord)

	# Reload chunk - generate_for_chunk will re-materialize from cache
	_load_chunk(coord)


## Initialize terrain generation (async with frame yields for loading screen)
func generate_terrain(seed_value: int = -1) -> void:
	is_ready = false

	# Yield a frame to allow loading screen to render
	await get_tree().process_frame

	if terrain_generator:
		terrain_generator.terrain_size = heightmap.size
		terrain_generator.cell_size = cell_size

		# AO archetype: derive preset from mission seed. Deterministic by construction —
		# the same seed always produces the same AO. (RECONgame-xo7i, RECONgame-5r4y)
		var preset: int = _derive_ao_preset(seed_value)
		var preset_scale: float = _preset_height_scale(preset)
		terrain_generator.set_preset(preset)
		terrain_generator.height_scale = WORLD_HEIGHT_MAX
		terrain_generator.target_relief = preset_scale / WORLD_HEIGHT_MAX

		await get_tree().process_frame
		terrain_generator.generate(seed_value)

		heightmap.data = terrain_generator.heightmap_data.duplicate()
		# Mesh and shader both use the same world-space cap; the actual occupied
		# relief is the fraction `target_relief` stored in the heightmap data.
		heightmap.height_scale = WORLD_HEIGHT_MAX

		# Ensure the terrain shader uses the same world-space scale as the mesh.
		TerrainChunkClass.set_shader_parameters({"height_scale": WORLD_HEIGHT_MAX})

		await get_tree().process_frame
	else:
		_generate_fallback_terrain()

	heightmap.print_stats()

	# The one classifier's lowland ceiling is derived from THIS map's relief. Must be set
	# before any classify() call (veg runs during chunk load below; the AI grid later).
	TerrainZoning.configure(heightmap)

	# Extract rivers and carve riverbeds BEFORE building chunks (optional - slow on large maps)
	if rivers_enabled:
		await get_tree().process_frame
		_extract_and_carve_rivers()
		await get_tree().process_frame

	await get_tree().process_frame
	await _load_initial_chunks_async()

	is_ready = true
	terrain_ready.emit()


## Fallback terrain generation if TerrainEngine not available
func _generate_fallback_terrain() -> void:
	print("[TerrainManager] Using fallback terrain generation")

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = 0.002
	noise.seed = randi()

	heightmap.data.resize(heightmap.size * heightmap.size)

	for z in range(heightmap.size):
		for x in range(heightmap.size):
			var h: float = noise.get_noise_2d(x, z)
			h = (h + 1.0) * 0.5  # Normalize to 0-1
			heightmap.data[z * heightmap.size + x] = h


## Load chunks with frame yields for loading screen updates
func _load_initial_chunks_async() -> void:
	var total_chunks: int = chunks_per_side * chunks_per_side
	var loaded: int = 0
	var chunks_per_frame: int = 4  # Load 4 chunks per frame for good balance

	for z in range(chunks_per_side):
		for x in range(chunks_per_side):
			var coord := Vector2i(x, z)
			if not chunks.has(coord):
				_load_chunk(coord)
				loaded += 1

				if loaded % chunks_per_frame == 0:
					var progress: float = 0.6 + (float(loaded) / float(total_chunks)) * 0.3
					await get_tree().process_frame

	print("[TerrainManager] Loaded %d chunks" % loaded)


func _stream_chunks_around_camera() -> void:
	var camera_chunk := _world_to_chunk(camera.global_position)

	_load_chunks_around(camera_chunk, load_distance)

	_unload_distant_chunks(camera_chunk, unload_distance)


func _load_chunks_around(center: Vector2i, radius: int) -> void:
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var coord := center + Vector2i(dx, dz)

			if coord.x < 0 or coord.x >= chunks_per_side:
				continue
			if coord.y < 0 or coord.y >= chunks_per_side:
				continue

			if chunks.has(coord) or coord in loading_chunks:
				continue

			_load_chunk(coord)


func _load_chunk(coord: Vector2i) -> void:
	loading_chunks.append(coord)

	var start_x: int = coord.x * int(chunk_size / cell_size)
	var start_z: int = coord.y * int(chunk_size / cell_size)
	var region: PackedFloat32Array = heightmap.extract_region(start_x, start_z, chunk_cells)

	var chunk := TerrainChunkClass.new(coord, chunk_size, cell_size)
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)

	# Classify vegetation BEFORE mesh build so the mesh can color rice paddies
	var veg_bytes := PackedByteArray()
	var bundles_per_chunk: int = 0
	if vegetation_manager:
		vegetation_manager.generate_for_chunk(coord, heightmap, chunk_size)
		if vegetation_manager._chunk_terrain.has(coord):
			veg_bytes = vegetation_manager._chunk_terrain[coord]
			bundles_per_chunk = vegetation_manager._bundles_per_chunk

	chunk.build_mesh(region, heightmap.height_scale, veg_bytes, bundles_per_chunk)

	chunk.create_raycast_collision()

	# (Navigation is NOT baked per chunk. A 256m chunk at the nav map's 0.25 cell
	#  size is a 1024x1024 Recast heightfield, x25, over jungle nobody paths
	#  through - and chunks do not know where the structures are. See NavBaker.)

	chunks[coord] = chunk
	loading_chunks.erase(coord)


## Uses Chebyshev distance (max of dx, dy) to match the square loading pattern
func _unload_distant_chunks(center: Vector2i, max_distance: int) -> void:
	var to_unload: Array[Vector2i] = []

	for coord in chunks:
		var dist := maxi(absi(coord.x - center.x), absi(coord.y - center.y))
		if dist > max_distance:
			to_unload.append(coord)

	for coord in to_unload:
		_unload_chunk(coord)


func _unload_chunk(coord: Vector2i) -> void:
	if not chunks.has(coord):
		return

	var chunk: Node3D = chunks[coord]  # TerrainChunk
	chunk.unload()
	chunk.queue_free()
	chunks.erase(coord)

	# Full clear vegetation when streaming out (not rebuilding)
	if vegetation_manager and vegetation_manager.has_method("clear_chunk_full"):
		vegetation_manager.clear_chunk_full(coord)


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)


## Get terrain height at world position (O(1) bilinear interpolation)
## This is the primary API for unit movement - does NOT use physics
func get_height_at(world_pos: Vector3) -> float:
	return heightmap.sample_world(world_pos.x, world_pos.z)


func get_normal_at(world_pos: Vector3) -> Vector3:
	return heightmap.get_normal_world(world_pos.x, world_pos.z)


func modify_terrain(center: Vector3, radius_meters: float, modifier: Callable) -> void:
	var cell_center: Vector2i = heightmap.world_to_cell(center.x, center.z)
	var cell_radius: int = int(ceil(radius_meters / cell_size))

	var affected: Rect2i = heightmap.modify_region(cell_center, cell_radius, modifier)

	_rebuild_chunks_in_region(affected)
	region_rebuilt.emit(Rect2(
		Vector2(float(affected.position.x), float(affected.position.y)) * cell_size,
		Vector2(float(affected.size.x), float(affected.size.y)) * cell_size))


## Rebuild chunks that overlap with a cell region
func _rebuild_chunks_in_region(cell_region: Rect2i) -> void:
	var cells_per_chunk: int = int(chunk_size / cell_size)

	var min_chunk := Vector2i(
		cell_region.position.x / cells_per_chunk,
		cell_region.position.y / cells_per_chunk
	)
	var max_chunk := Vector2i(
		(cell_region.position.x + cell_region.size.x) / cells_per_chunk,
		(cell_region.position.y + cell_region.size.y) / cells_per_chunk
	)

	for cz in range(min_chunk.y, max_chunk.y + 1):
		for cx in range(min_chunk.x, max_chunk.x + 1):
			var coord := Vector2i(cx, cz)
			if chunks.has(coord):
				# Use _rebuild_chunk_immediate which preserves the vegetation cache.
				# _unload_chunk calls vegetation_manager.clear_chunk_full() which wipes
				# _chunk_terrain and _chunk_placements, causing trees to respawn in
				# their original positions after every explosion.
				_rebuild_chunk_immediate(coord)


func set_camera(cam: Camera3D) -> void:
	camera = cam


# AO archetype mapping. The 40/60 split:
#   40% INHABITED — COASTAL_HILLS, RIVER_VALLEY (paddy country, low relief, witnessable)
#   60% EMPTY     — ROLLING_HILLS, STEEP_MOUNTAINS (jungle highlands, triple canopy)
# PLATEAU is a rare roll (1-in-5 of the empty 60% branch).
# Deterministic: same seed -> same preset, always. (RECONgame-5r4y)
const AO_INHABITED := [0, 1]  # COASTAL_HILLS, RIVER_VALLEY


func _derive_ao_preset(seed_value: int) -> int:
	if seed_value < 0:
		seed_value = 0
	var roll: int = seed_value % 100
	if roll < 40:
		# 0-39 = inhabited, 50/50 split between COASTAL_HILLS and RIVER_VALLEY
		return AO_INHABITED[seed_value % 2]
	# 40-99 = empty; 80% ROLLING_HILLS / STEEP_MOUNTAINS, 20% PLATEAU
	var sub: int = seed_value % 5
	if sub == 4:
		return 4  # PLATEAU
	return 2 + (seed_value % 2)  # ROLLING_HILLS or STEEP_MOUNTAINS


static func _preset_height_scale(preset: int) -> float:
	## Per-preset target peak-to-valley relief in meters.
	## Tied directly to the relief budgets in tests/test_terrain_relief_bounds.gd.
	## (RECONgame-p7wx)
	match preset:
		0:  # COASTAL_HILLS — flat coastal plain, paddies
			return 25.0
		1:  # RIVER_VALLEY — low center, gentle ridges
			return 40.0
		2:  # ROLLING_HILLS — gentle highlands
			return 90.0
		3:  # STEEP_MOUNTAINS — dramatic peaks
			return 300.0
		4:  # PLATEAU — flat top, cliff edges
			return 160.0
		_:
			return 90.0

func get_loaded_chunk_count() -> int:
	return chunks.size()


# ============================================================================
# RIVER SYSTEM
# ============================================================================

func _extract_and_carve_rivers() -> void:
	river_paths.clear()

	var gen := RiverGeneratorClass.new()
	gen.min_river_length = 50
	gen.base_width = 6.0
	gen.width_growth = 0.08
	# Use fast gradient descent instead of slow D8 flow accumulation
	var paths: Array = gen.extract_rivers_fast(heightmap, river_count)
	river_paths = paths

	# Smooth paths (D8 discretization is jaggy)
	for path in river_paths:
		_smooth_river_path(path)

	for path in river_paths:
		_carve_riverbed(path)

	print("[TerrainManager] Extracted %d river paths" % river_paths.size())


## Smooth a river path with windowed averaging
func _smooth_river_path(path) -> void:
	if path.points.size() < 5:
		return
	var smoothed := PackedVector2Array()
	smoothed.resize(path.points.size())
	smoothed[0] = path.points[0]
	smoothed[path.points.size() - 1] = path.points[path.points.size() - 1]
	for i in range(1, path.points.size() - 1):
		var prev: Vector2 = path.points[i - 1]
		var curr: Vector2 = path.points[i]
		var next_pt: Vector2 = path.points[i + 1]
		smoothed[i] = (prev + curr * 2.0 + next_pt) * 0.25
	path.points = smoothed


## Carve riverbed into heightmap (must happen BEFORE chunk mesh generation)
func _carve_riverbed(path) -> void:
	var carve_depth_meters: float = 1.8
	var carve_radius: int = 2  # cells perpendicular
	for i in path.points.size():
		var p: Vector2 = path.points[i]
		var center_cell: Vector2i = heightmap.world_to_cell(p.x, p.y)
		for dz in range(-carve_radius, carve_radius + 1):
			for dx in range(-carve_radius, carve_radius + 1):
				var nx: int = center_cell.x + dx
				var nz: int = center_cell.y + dz
				if nx < 0 or nx >= heightmap.size:
					continue
				if nz < 0 or nz >= heightmap.size:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz))
				if dist > float(carve_radius):
					continue
				var falloff: float = 1.0 - (dist / float(carve_radius))
				var current: float = heightmap.get_cell(nx, nz)
				var depth_normalized: float = (carve_depth_meters * falloff) / height_scale
				heightmap.set_cell(nx, nz, maxf(0.0, current - depth_normalized))


