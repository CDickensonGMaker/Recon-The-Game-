extends Node3D
class_name TerrainManager
## Manages terrain chunks. On maps <= 2km the whole grid loads once, behind the loading
## screen, and stays resident for the mission (ADR-013) - chunk count is invariant after
## terrain_ready. The streaming path below is dormant, kept for future 3km+ AOs.

const HeightmapStorageClass := preload("res://terrain/core/heightmap_storage.gd")
const TerrainChunkClass := preload("res://terrain/core/terrain_chunk.gd")
const HydrologyMapClass := preload("res://terrain/water/hydrology_map.gd")

signal terrain_ready
## Terrain heights changed in this world-space rect (cell-accurate, not
## chunk-aligned). Anything that baked heights at build time re-seats on this -
## the wire-is-law lesson: one terrain-change channel, every height consumer
## listens or floats.
signal region_rebuilt(world_rect: Rect2)

@export var map_size: float = 3000.0  # Playable map size in meters
@export var chunk_size: float = 256.0  # Chunk size in meters
@export var cell_size: float = 2.0    # Height sample resolution

@export var load_distance: int = 3     # Chunks to load around camera
@export var unload_distance: int = 5   # Chunks to unload beyond this

## ADR-013: maps at or below this size load whole and never stream (resident world).
const STREAMING_MIN_MAP_SIZE: float = 2000.0

## Depth of the carved channel bed below grade. WaterSystem seats its sheet
## CHANNEL_WATER_DEPTH above this bed, and HydrologyMap derives the same figure
## for gameplay depth - change one and the other two must follow.
const CHANNEL_CARVE_DEPTH: float = 1.2

@export var rivers_enabled: bool = true

var heightmap: RefCounted  # HeightmapStorage
var chunks: Dictionary = {}  # Vector2i -> TerrainChunk
var loading_chunks: Array[Vector2i] = []

var is_ready: bool = false
var chunks_per_side: int  # Chunks per side
var chunk_cells: int

## Chunk coords that have taken a heightmap edit at least once. Their chunks keep the working
## arrays build_mesh produces so a later edit can patch them in place.
var _patch_armed: Dictionary = {}

var camera: Camera3D
var terrain_generator: Node  # TerrainEngine autoload
var vegetation_manager: Node  # VegetationManager - set externally for rice paddy coloring

var river_paths: Array = []
## The one hydrology solve for this AO. WaterSystem reuses it (game_world.gd:147)
## rather than running a second one against the terrain this carve just changed.
var hydrology: RefCounted = null  # HydrologyMap

func _ready() -> void:
	chunks_per_side = int(ceil(map_size / chunk_size))
	chunk_cells = int(chunk_size / cell_size) + 1  # +1 for edge overlap

	print("[TerrainManager] Map: %.0fm (%dx%d chunks)" % [
		map_size, chunks_per_side, chunks_per_side
	])

	terrain_generator = get_node_or_null("/root/TerrainEngine")

	heightmap = HeightmapStorageClass.new(map_size, cell_size, TerrainConfig.WORLD_HEIGHT_MAX)


func _process(_delta: float) -> void:
	if not is_ready:
		return

	_drain_veg_regen()

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
		var preset_scale: float = TerrainConfig.preset_relief(preset)
		terrain_generator.set_preset(preset)
		terrain_generator.target_relief = preset_scale / TerrainConfig.WORLD_HEIGHT_MAX

		await get_tree().process_frame
		terrain_generator.generate(seed_value)

		heightmap.data = terrain_generator.heightmap_data.duplicate()

		# Mesh, shader and every gameplay query decode against the storage's scale.
		TerrainChunkClass.set_shader_parameters({"height_scale": heightmap.height_scale})

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
	# EVERY chunk keeps its patch arrays, not just ground that has already been hit.
	#
	# MEASURED 2026-09-09 (tests/probe_napalm_stall.tscn, the Summoner's live "when the
	# ambient napalm hits tho it still stutters really bad"): a NAPALM crater is
	# radius_cells 22 = 88 m of ground, which spans FOUR 256 m chunks. On the first
	# napalm of a mission none of those four was armed, so all four took the full
	# _rebuild_chunk_immediate path in ONE idle frame: terrain.crater 122.2 ms of a
	# 125.43 ms worst idle script step. The lazy arming was written for shells that
	# CLUSTER, and it is right for artillery - but the first shell on a chunk is exactly
	# the frame the player feels, and air support never gets a second one on the same
	# ground to pay it off.
	#
	# The cost is RAM, not time: build_mesh already builds these arrays, arming only
	# stops them being dropped afterwards. Measured at ~1.0 MB per 256 m chunk
	# (24,576 verts+norms+colors plus the 65x65 sample grid) - 4 MB on the demo's 512 m
	# map, ~67 MB on the 2 km ceiling ADR-013 sets. If that ceiling is ever built, this
	# is the line to make conditional on chunk count, and it is the Summoner's call.
	chunk.arm_patch_cache()
	_patch_armed[coord] = true

	# Classify vegetation BEFORE mesh build so the mesh can color rice paddies
	var veg_bytes := PackedByteArray()
	var bundles_per_chunk: int = 0
	if vegetation_manager:
		StallLedger.begin("terrain.veg_generate")
		vegetation_manager.generate_for_chunk(coord, heightmap, chunk_size)
		StallLedger.end()
		if vegetation_manager._chunk_terrain.has(coord):
			veg_bytes = vegetation_manager._chunk_terrain[coord]
			bundles_per_chunk = vegetation_manager._bundles_per_chunk

	StallLedger.begin("terrain.build_mesh")
	chunk.build_mesh(region, heightmap.height_scale, veg_bytes, bundles_per_chunk)
	StallLedger.end()

	StallLedger.begin("terrain.collision")
	chunk.create_raycast_collision()
	StallLedger.end()

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
## This is the primary API for unit movement - does NOT use physics.
## Returns sea level before generation: this is called every physics tick by
## movement and by TerrainWatchdog, so on an ungenerated manager it must answer,
## not throw. A flat world reads as a rig artefact; a per-tick crash spew buries
## whatever the run was actually testing.
func get_height_at(world_pos: Vector3) -> float:
	if heightmap == null:
		return 0.0
	return heightmap.sample_world(world_pos.x, world_pos.z)


func get_normal_at(world_pos: Vector3) -> Vector3:
	if heightmap == null:
		return Vector3.UP
	return heightmap.get_normal_world(world_pos.x, world_pos.z)


func modify_terrain(center: Vector3, radius_meters: float, modifier: Callable) -> void:
	var cell_center: Vector2i = heightmap.world_to_cell(center.x, center.z)
	var cell_radius: int = int(ceil(radius_meters / cell_size))

	StallLedger.begin("terrain.heightmap_edit")
	var affected: Rect2i = heightmap.modify_region(cell_center, cell_radius, modifier)
	StallLedger.end()

	StallLedger.begin("terrain.chunk_rebuild")
	_rebuild_chunks_in_region(affected)
	StallLedger.end()
	region_rebuilt.emit(Rect2(
		Vector2(float(affected.position.x), float(affected.position.y)) * cell_size,
		Vector2(float(affected.size.x), float(affected.size.y)) * cell_size))


## Rebuild chunks that overlap with a cell region
func _rebuild_chunks_in_region(cell_region: Rect2i) -> void:
	var cells_per_chunk: int = int(chunk_size / cell_size)

	@warning_ignore("integer_division")
	var min_chunk := Vector2i(
		cell_region.position.x / cells_per_chunk,
		cell_region.position.y / cells_per_chunk
	)
	@warning_ignore("integer_division")
	var max_chunk := Vector2i(
		(cell_region.position.x + cell_region.size.x) / cells_per_chunk,
		(cell_region.position.y + cell_region.size.y) / cells_per_chunk
	)

	for cz in range(min_chunk.y, max_chunk.y + 1):
		for cx in range(min_chunk.x, max_chunk.x + 1):
			var coord := Vector2i(cx, cz)
			if chunks.has(coord):
				# PATCH the chunk in place if it can be patched; otherwise the full
				# rebuild, which arms the patch cache for the next shell on this ground.
				# _rebuild_chunk_immediate (not _unload_chunk) because clear_chunk_full
				# wipes _chunk_terrain and _chunk_placements, which respawns the trees in
				# their pre-blast positions.
				if not _patch_chunk_region(coord, cell_region, cells_per_chunk):
					# Arm the COORD, not the node: _rebuild_chunk_immediate throws the
					# chunk away and builds a new one, so arming the doomed instance
					# armed nothing and every shell rebuilt forever.
					_patch_armed[coord] = true
					_rebuild_chunk_immediate(coord)


## Re-derive only the part of a chunk a heightmap edit actually touched. The chunk node, its
## MeshInstance3D and its Jolt static body all survive; the vegetation is re-seated from the
## cached scatter exactly as the full path does. Returns false when this chunk has no patch
## cache yet, so the caller can do the full build that arms it.
func _patch_chunk_region(coord: Vector2i, cell_region: Rect2i, cells_per_chunk: int) -> bool:
	var chunk: Node3D = chunks[coord]
	var start_x: int = coord.x * cells_per_chunk
	var start_z: int = coord.y * cells_per_chunk
	var local := Rect2i(
		cell_region.position.x - start_x, cell_region.position.y - start_z,
		cell_region.size.x, cell_region.size.y)
	var region: PackedFloat32Array = heightmap.extract_region(start_x, start_z, chunk_cells)

	StallLedger.begin("terrain.patch_mesh")
	var ok: bool = bool(chunk.call("patch_mesh", region, heightmap.height_scale, local))
	StallLedger.end()
	if not ok:
		return false

	StallLedger.begin("terrain.collision")
	chunk.call("refresh_collision")
	StallLedger.end()

	if vegetation_manager:
		# The edited cells, in world metres, ride along so the vegetation can re-seat only the
		# plants that stood on ground that moved instead of rebuilding the chunk.
		_queue_veg_regen(coord, Rect2(
			Vector2(float(cell_region.position.x), float(cell_region.position.y)) * cell_size,
			Vector2(float(cell_region.size.x), float(cell_region.size.y)) * cell_size))
	return true


## ---- DISTANT EVENTS MAY NOT COST A NEAR FRAME (his ruling 2026-09-09: "that way theres
## not things happening across the map thats lagging the game") ----
##
## MEASURED, and this is the whole napalm stutter: one NAPALM canister edits 88 m of
## heightmap, which touches FOUR 256 m chunks, and each touched chunk re-derived its
## vegetation in the SAME frame - terrain.veg_generate 96.1 ms over 4 calls (worst single
## 29.6 ms) inside a 125.43 ms idle step, on ground 210 m behind the player.
##
## THE SPLIT, and it is the law the coordinator set - outcome identical, presentation
## degraded:
##   OUTCOME, still immediate and never deferred:
##     * the heightmap edit itself (modify_terrain, above) - every height query, every
##       navmesh sample and every man's footing reads it the moment the shell lands;
##     * the chunk's mesh patch and its HeightMapShape3D collision - so no round and no
##       boot ever meets ground the shell has already moved;
##     * TreeBreakSystem's registry and VegetationManager.clear_area - so ballistics
##       already know the felled trunks are gone.
##   PRESENTATION, deferred one chunk per frame:
##     * the vegetation MultiMesh re-derive. What lags is which grass is DRAWN, for at
##       most three frames, on chunks that are 88 m wide.
##
## Chunk-deduped: eight canisters walking one treeline queue the same four coords once,
## not thirty-two times.
var _veg_regen_queue: Array[Vector2i] = []
## coord -> the union of edited rects (world metres) waiting on that chunk. A zero-size rect
## means "the whole chunk" and wins over any partial that merges into it.
var _veg_regen_rect: Dictionary = {}
## One chunk per frame. Same reasoning and the same number as TreeCoverLayer's
## REGEN_PER_FRAME: a single re-derive is 14-30 ms and two in a frame is the stall.
const VEG_REGEN_PER_FRAME: int = 1


func _queue_veg_regen(coord: Vector2i, rect: Rect2 = Rect2()) -> void:
	if not _veg_regen_queue.has(coord):
		_veg_regen_queue.append(coord)
		_veg_regen_rect[coord] = rect
		return
	var have: Rect2 = _veg_regen_rect.get(coord, Rect2())
	if have.size == Vector2.ZERO or rect.size == Vector2.ZERO:
		_veg_regen_rect[coord] = Rect2()
	else:
		_veg_regen_rect[coord] = have.merge(rect)


func _drain_veg_regen() -> void:
	if _veg_regen_queue.is_empty() or vegetation_manager == null \
			or not is_instance_valid(vegetation_manager):
		return
	StallLedger.begin("terrain.veg_generate")
	for _i in range(mini(VEG_REGEN_PER_FRAME, _veg_regen_queue.size())):
		var coord: Vector2i = _veg_regen_queue.pop_front()
		var rect: Rect2 = _veg_regen_rect.get(coord, Rect2())
		_veg_regen_rect.erase(coord)
		if chunks.has(coord):
			vegetation_manager.generate_for_chunk(coord, heightmap, chunk_size, rect)
	StallLedger.end()


## Chunks whose ground has moved and whose planting has not caught up. For the probe.
func pending_veg_regen() -> int:
	return _veg_regen_queue.size()


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


func get_loaded_chunk_count() -> int:
	return chunks.size()


# ============================================================================
# RIVER SYSTEM
# ============================================================================

## One authority decides where water goes: HydrologyMap. The beds are carved where
## flow actually accumulates, using the same model, thresholds and downsample that
## WaterSystem later uses to place the water surface, so a carved groove and the
## creek that fills it can never describe different ground.
func _extract_and_carve_rivers() -> void:
	river_paths.clear()

	var hydro := HydrologyMapClass.new()
	# Mirrors WaterSystem._auto_downsample: ~400-cell hydrology grid at any map size.
	hydro.downsample = maxi(1, int(round(float(heightmap.size) / 450.0)))
	hydro.ocean_edges = WorldConfig.OCEAN_EDGES
	hydro.sea_level = WorldConfig.SEA_LEVEL
	hydro.generate(heightmap)
	hydrology = hydro
	river_paths = hydro.rivers

	# Smooth paths (D8 discretization is jaggy)
	for path in river_paths:
		_smooth_river_path(path)

	# ONE CUT PER CELL, NOT ONE PER PATH POINT. Consecutive points on a smoothed path sit
	# well inside each other's reach, so a cell used to be carved once for every nearby
	# point: intended 1.2m, measured 7.97m mean and 34.19m worst (tools/probe_carve_depth.gd).
	# The water sheet is seated from the GRADE, so the river ran metres above its own bed.
	# Depth is accumulated as a per-cell MAXIMUM across every path, then subtracted once.
	var mask: Dictionary = {}
	for path in river_paths:
		_carve_riverbed(path, mask)
	var deepest: float = 0.0
	for key in mask:
		var d: float = float(mask[key])
		deepest = maxf(deepest, d)
		@warning_ignore("integer_division")
		var nz: int = int(key) / heightmap.size
		var nx: int = int(key) % heightmap.size
		heightmap.set_cell(nx, nz,
			maxf(0.0, heightmap.get_cell(nx, nz) - heightmap.meters_to_norm(d)))
	print("[TerrainManager] Carved %d hydrology channels, %d cell(s), deepest cut %.2fm (cap %.2fm)"
		% [river_paths.size(), mask.size(), deepest, CHANNEL_CARVE_DEPTH])


## Smooth a river path with windowed averaging
func _smooth_river_path(path: Dictionary) -> void:
	var points: PackedVector2Array = path["points"]
	if points.size() < 5:
		return
	var smoothed := PackedVector2Array()
	smoothed.resize(points.size())
	smoothed[0] = points[0]
	smoothed[points.size() - 1] = points[points.size() - 1]
	for i in range(1, points.size() - 1):
		var prev: Vector2 = points[i - 1]
		var curr: Vector2 = points[i]
		var next_pt: Vector2 = points[i + 1]
		smoothed[i] = (prev + curr * 2.0 + next_pt) * 0.25
	path["points"] = smoothed


## Accumulate this path's cut into `mask` (cell key -> METRES, per-cell maximum). It does not
## touch the heightmap: the caller subtracts once, after every path, or overlapping points
## carve the same cell over and over. Radius follows the channel's own hydrology width, so a
## headwater creek cuts a narrow groove and a trunk river cuts a wide one. Must run BEFORE
## chunk mesh generation.
func _carve_riverbed(path: Dictionary, mask: Dictionary) -> void:
	var points: PackedVector2Array = path["points"]
	var widths: PackedFloat32Array = path["widths"]
	for i in points.size():
		var p: Vector2 = points[i]
		var half_w: float = (widths[i] if i < widths.size() else 4.0) * 0.5
		# Full depth across the channel, then a shoulder that ramps back to grade.
		# A radius derived from half_w alone rounds to one cell on a 4m grid, which
		# cuts a single-node spike with no floor for the water sheet to sit in.
		var shoulder: float = maxf(half_w * 0.6, heightmap.cell_size)
		var reach: float = half_w + shoulder
		var carve_radius: int = clampi(int(ceil(reach / heightmap.cell_size)), 2, 14)
		var center_cell: Vector2i = heightmap.world_to_cell(p.x, p.y)
		for dz in range(-carve_radius, carve_radius + 1):
			for dx in range(-carve_radius, carve_radius + 1):
				var nx: int = center_cell.x + dx
				var nz: int = center_cell.y + dz
				if nx < 0 or nx >= heightmap.size:
					continue
				if nz < 0 or nz >= heightmap.size:
					continue
				var dist_m: float = sqrt(float(dx * dx + dz * dz)) * heightmap.cell_size
				if dist_m > reach:
					continue
				var falloff: float = 1.0 - smoothstep(half_w, reach, dist_m)
				var key: int = nz * heightmap.size + nx
				mask[key] = maxf(float(mask.get(key, 0.0)), CHANNEL_CARVE_DEPTH * falloff)


