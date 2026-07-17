class_name VegetationManager
extends Node3D
## Grid-based vegetation with terrain types and density zones.
## Uses 2x2 cell bundles for efficient clearing and LOS.

enum TerrainType {
	CLEAR,          # No vegetation (roads, clearings)
	RICE_PADDY,     # Flat water/crops - no trees
	GRASSLAND,      # Low grass, very sparse trees
	LIGHT_JUNGLE,   # Sparse trees, good visibility
	MEDIUM_JUNGLE,  # Moderate density
	HEAVY_JUNGLE,   # Dense canopy, blocks LOS
}

## Bundle size (2x2 cells treated as one unit)
const BUNDLE_SIZE := 2

## Individual cell size in meters
@export var cell_size: float = 4.0

## Maximum slope for vegetation
@export var max_slope_degrees: float = 50.0

## Mission seed — flows from game_world.gd. Passed to TerrainZoning so two boots with the
## same seed produce a byte-identical world. (RECONgame-cp3s, RECONgame-5r4y)
@export var mission_seed: int = 0

## Use external models (disabled - too heavy for Intel UHD)
@export var use_external_models: bool = false

## Authored 12m jungle patches (tools/make_jungle_patches.py) instead of lone trees.
## The patches carry their own trees, so the single-tree layer stays off while this is on.
@export var use_jungle_patches: bool = true
const JunglePatchLayerScript := preload("res://terrain/vegetation/jungle_patch_layer.gd")
var _patch_layer: JunglePatchLayer = null

## ADR-028 veg-LOD merge: which canopy renderer builds the near/far cover. JUNGLE_PATCH is
## the shipped merged-patch render; TREE_COVER is the individual-species near-solid+collider
## / far-card LOD. The default stays JUNGLE_PATCH - flipping it to TREE_COVER is the
## look-check-gated switchover (Caleb's eyes + the broadleaf .blend fix). The two never run
## together (double canopy). Wired live-capable and driven by probe_tree_cover_wired.
enum CanopySource { JUNGLE_PATCH, TREE_COVER }
@export var canopy_source: CanopySource = CanopySource.JUNGLE_PATCH
const TreeCoverLayerScript := preload("res://terrain/vegetation/tree_cover_layer.gd")
var _tree_cover: TreeCoverLayer = null

## Terrain-type -> weighted individual-species pool (repetition = weight). The per-species
## analog of JunglePatchLayer.TYPE_DENSITY; TYPE_PROPS still governs how MANY. Cover-givers
## (broadleaf/banana/bamboo/palm/deadfall) get a trunk collider via TreeCoverLayer.COVER_TRUNK;
## everything else (bush/fern/grass/rice/vine) is concealment, no collider.
const TYPE_SPECIES := {
	TerrainType.CLEAR: [],
	TerrainType.RICE_PADDY: ["rice_a", "rice_b"],
	TerrainType.GRASSLAND: ["tall_grass_a", "tall_grass_b", "elephant_grass_a", "bush_a", "fern_a"],
	TerrainType.LIGHT_JUNGLE: ["banana_a", "bush_a", "bush_b", "fern_a", "fern_b", "palm_sapling_a", "jungle_palm_a1"],
	TerrainType.MEDIUM_JUNGLE: ["broadleaf_a", "broadleaf_b", "banana_a", "jungle_palm_a1", "jungle_palm_b1", "bamboo_a", "bush_b", "fern_b", "fern_c", "elephant_grass_b"],
	TerrainType.HEAVY_JUNGLE: ["broadleaf_a", "broadleaf_b", "broadleaf_c", "bamboo_a", "bamboo_b", "bamboo_c", "banana_b", "jungle_palm_a2", "jungle_palm_b2", "fern_c", "liana_a", "vine_a"],
}

# Bundle size in meters
var bundle_meters: float:
	get: return cell_size * BUNDLE_SIZE

# Terrain type properties: [tree_chance, tree_count_min, tree_count_max, blocks_los, move_speed]
# move_speed: 1.0 = full speed, 0.5 = half speed, etc.
const TYPE_PROPS := {
	TerrainType.CLEAR:         [0.00, 0, 0, false, 1.0],
	TerrainType.RICE_PADDY:    [0.00, 0, 0, false, 0.4],   # Water/mud - very slow
	TerrainType.GRASSLAND:     [0.08, 0, 1, false, 0.95],  # Very sparse
	TerrainType.LIGHT_JUNGLE:  [0.30, 1, 2, false, 0.8],   # Sparse
	TerrainType.MEDIUM_JUNGLE: [0.55, 1, 3, true,  0.5],   # Moderate density
	TerrainType.HEAVY_JUNGLE:  [0.80, 2, 4, true,  0.3],   # Dense canopy
}

var _meshes: Array[Mesh] = []  # Tree meshes
var _grass_mesh: Mesh  # Grass patch mesh
var _fallback_mesh: ArrayMesh

# Grid data per chunk - stores TerrainType for each bundle
# Dictionary[Vector2i, PackedByteArray]
var _chunk_terrain: Dictionary = {}

# MultiMesh instances per chunk
var _chunk_instances: Dictionary = {}  # Trees
var _chunk_grass: Dictionary = {}  # Grass patches

# Placement cache - built once per chunk, survives terrain changes
var _chunk_placements: Dictionary = {}

const TREE_CANDIDATES_PER_CHUNK := 1200  # FPS fork: reduced from RTS 2000
const GRASS_CANDIDATES_PER_CHUNK := 2000  # PT5: more ground cover (was 1200)

# Grass acceptance thresholds per terrain type
const GRASS_ACCEPT := {
	TerrainType.CLEAR: 0.0,
	TerrainType.RICE_PADDY: 0.0,
	TerrainType.GRASSLAND: 0.15,
	TerrainType.LIGHT_JUNGLE: 0.25,
	TerrainType.MEDIUM_JUNGLE: 0.40,
	TerrainType.HEAVY_JUNGLE: 0.55,
}

# Bundles per chunk side
var _bundles_per_chunk: int

var _min_slope_dot: float

var _camera: Camera3D
var _chunk_size: float = 256.0

# TerrainManager reference for water proximity checks
var _terrain_manager: Node = null

# Frustum culling accumulator (don't check every frame)
var _frustum_accumulator: float = 0.0
const FRUSTUM_UPDATE_INTERVAL := 0.1  # 10Hz

## Perf-attribution toggles (perf_probe.gd): force grass / jungle patches hidden so
## each system's frame cost can be measured by difference.
var grass_disabled: bool = false
var patches_disabled: bool = false


func _ready() -> void:
	_min_slope_dot = cos(deg_to_rad(max_slope_degrees))
	_load_vegetation_meshes()
	if canopy_source == CanopySource.TREE_COVER:
		_tree_cover = TreeCoverLayerScript.new()
		_tree_cover.name = "TreeCoverLayer"
		_tree_cover.load_species(_all_species())
		add_child(_tree_cover)
	elif use_jungle_patches:
		_patch_layer = JunglePatchLayerScript.new()
		_patch_layer.name = "JunglePatchLayer"
		_patch_layer.mission_seed = mission_seed  # fold the seed into patch placement (ADR-010)
		add_child(_patch_layer)


## Unique species names across every TYPE_SPECIES pool (for TreeCoverLayer.load_species).
func _all_species() -> Array:
	var seen: Dictionary = {}
	for pool: Array in TYPE_SPECIES.values():
		for nm: String in pool:
			seen[nm] = true
	return seen.keys()


func _process(delta: float) -> void:
	if not _camera:
		return

	_frustum_accumulator += delta
	if _frustum_accumulator < FRUSTUM_UPDATE_INTERVAL:
		return
	_frustum_accumulator = 0.0

	_update_frustum_culling()


func set_camera(cam: Camera3D) -> void:
	_camera = cam


func set_chunk_size(size: float) -> void:
	_chunk_size = size


func _update_frustum_culling() -> void:
	var frustum := _camera.get_frustum()
	var cam_pos := _camera.global_position

	# Jungle patches live in their own layer, and when they are on _chunk_instances
	# is empty (the lone-tree layer is suppressed) - so they need their own pass
	# or nothing would ever cull.
	if _patch_layer != null and _patch_layer.enabled:
		for coord: Vector2i in _chunk_terrain:
			var paabb := AABB(
				Vector3(coord.x * _chunk_size, -50, coord.y * _chunk_size),
				Vector3(_chunk_size, 400.0, _chunk_size)
			)
			var patch_vis := _aabb_in_frustum(paabb, frustum) and not patches_disabled
			_patch_layer.set_chunk_visible(coord, patch_vis)

	for coord: Vector2i in _chunk_instances:
		var aabb := AABB(
			Vector3(coord.x * _chunk_size, -50, coord.y * _chunk_size),
			Vector3(_chunk_size, 400.0, _chunk_size)
		)

		var in_frustum := _aabb_in_frustum(aabb, frustum)

		# Distance-based grass culling (grass only visible within 100m)
		var chunk_center := Vector3(
			coord.x * _chunk_size + _chunk_size * 0.5,
			0,
			coord.y * _chunk_size + _chunk_size * 0.5
		)
		var dist := cam_pos.distance_to(chunk_center)
		var grass_visible := in_frustum and dist < 60.0 and not grass_disabled  # FPS fork: was 100m

		if _chunk_instances.has(coord):
			_chunk_instances[coord].visible = in_frustum
		if _chunk_grass.has(coord):
			_chunk_grass[coord].visible = grass_visible


func _aabb_in_frustum(aabb: AABB, frustum: Array[Plane]) -> bool:
	for plane: Plane in frustum:
		# Get the positive vertex (furthest in plane normal direction)
		var positive := aabb.position
		if plane.normal.x >= 0:
			positive.x += aabb.size.x
		if plane.normal.y >= 0:
			positive.y += aabb.size.y
		if plane.normal.z >= 0:
			positive.z += aabb.size.z

		# If positive vertex is behind plane, AABB is outside frustum
		if plane.distance_to(positive) < 0:
			return false

	return true


func _load_vegetation_meshes() -> void:
	_meshes.clear()

	if use_external_models:
		var palm := _load_first_mesh("res://terrain/vegetation/models/palm_tree.blend")
		if palm:
			_meshes.append(palm)
			print("[VegetationManager] Using palm tree as primary mesh")

	if _meshes.is_empty():
		_fallback_mesh = _create_procedural_tree()
		_meshes.append(_fallback_mesh)
		print("[VegetationManager] Using procedural tree as primary mesh")

	_grass_mesh = _load_first_mesh("res://terrain/vegetation/models/grass/grass_patch.fbx")
	if not _grass_mesh:
		_grass_mesh = _create_procedural_grass()
		print("[VegetationManager] Using procedural grass")
	else:
		print("[VegetationManager] Loaded grass patch mesh")

	print("[VegetationManager] Loaded %d tree mesh(es)" % _meshes.size())


func _load_first_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		print("[VegetationManager] Path not found: %s" % path)
		return null
	var scene := load(path) as PackedScene
	if not scene:
		print("[VegetationManager] Failed to load as PackedScene: %s" % path)
		return null
	var root := scene.instantiate() as Node3D
	var mesh := _find_first_mesh(root)
	if mesh:
		var aabb := mesh.get_aabb()
		# Skip flat meshes (billboards/planes) - check minimum dimension
		var min_dim := minf(minf(aabb.size.x, aabb.size.y), aabb.size.z)
		if min_dim < 0.001:
			print("[VegetationManager] Skipping flat mesh: %s (min_dim=%.6f)" % [path.get_file(), min_dim])
			root.queue_free()
			return null
		print("[VegetationManager] Loaded mesh from %s: AABB=%s, surfaces=%d" % [
			path.get_file(), aabb.size, mesh.get_surface_count()
		])
	else:
		print("[VegetationManager] No mesh found in: %s" % path)
	root.queue_free()
	return mesh


func _find_first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var mesh := _find_first_mesh(child)
		if mesh:
			return mesh
	return null


func generate_for_chunk(chunk_coord: Vector2i, heightmap: Object, chunk_size: float) -> void:
	clear_chunk_visuals(chunk_coord)  # Clear visuals, keep cache

	if _meshes.is_empty():
		return

	_bundles_per_chunk = int(chunk_size / bundle_meters)

	if not _chunk_terrain.has(chunk_coord):
		var world_offset := Vector3(
			chunk_coord.x * chunk_size,
			0.0,
			chunk_coord.y * chunk_size
		)

		var terrain := PackedByteArray()
		terrain.resize(_bundles_per_chunk * _bundles_per_chunk)

		for bz in _bundles_per_chunk:
			for bx in _bundles_per_chunk:
				var bundle_idx := bz * _bundles_per_chunk + bx

				# Bundle center world position
				var local_x := (bx + 0.5) * bundle_meters
				var local_z := (bz + 0.5) * bundle_meters
				var world_x := world_offset.x + local_x
				var world_z := world_offset.z + local_z

				var height := heightmap.sample_world(world_x, world_z) as float
				var normal := heightmap.get_normal_world(world_x, world_z) as Vector3
				var slope_dot := normal.dot(Vector3.UP)

				var terrain_type := _determine_terrain_type(height, slope_dot, world_x, world_z)
				terrain[bundle_idx] = terrain_type

		_chunk_terrain[chunk_coord] = terrain

	if not _chunk_placements.has(chunk_coord):
		_build_placement_cache(chunk_coord, heightmap, chunk_size)

	# Materialize from cache - ONE branch, shared with clear_area() (see _rematerialize).
	_rematerialize(chunk_coord, heightmap, chunk_size)


## world_x/world_z are passed for water proximity checks
func _determine_terrain_type(height: float, slope_dot: float, world_x: float = 0.0, world_z: float = 0.0) -> int:
	# Steep slopes carry no patches; everything else is the one classifier (bead 6od4).
	if slope_dot < _min_slope_dot:
		return TerrainType.CLEAR
	return TerrainZoning.classify(height, world_x, world_z, mission_seed)


## Build placement cache for a chunk - rolls ALL RNG upfront, stores positions/rotations/scales/accept_rolls
func _build_placement_cache(chunk_coord: Vector2i, _heightmap: Object, chunk_size: float) -> void:
	var placements: Array = []
	var world_offset_x := chunk_coord.x * chunk_size
	var world_offset_z := chunk_coord.y * chunk_size
	var bundle_meters_local := chunk_size / float(_bundles_per_chunk)

	# TREE CANDIDATES
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = hash([chunk_coord, mission_seed]) + 1000

	var density_mult: float = WorldConfig.VEGETATION_DENSITY_MULT
	var tree_count: int = int(round(float(TREE_CANDIDATES_PER_CHUNK) * density_mult))
	for i in tree_count:
		var local_x := tree_rng.randf() * chunk_size
		var local_z := tree_rng.randf() * chunk_size
		var world_x := world_offset_x + local_x
		var world_z := world_offset_z + local_z
		var bundle_x := int(local_x / bundle_meters_local)
		var bundle_z := int(local_z / bundle_meters_local)
		if bundle_x < 0 or bundle_x >= _bundles_per_chunk or bundle_z < 0 or bundle_z >= _bundles_per_chunk:
			continue

		placements.append({
			"type": "tree",
			"world_x": world_x,
			"world_z": world_z,
			"bundle_x": bundle_x,
			"bundle_z": bundle_z,
			"rot_y": tree_rng.randf() * TAU,
			"tilt_x": tree_rng.randf_range(-0.26, 0.26),
			"tilt_z": tree_rng.randf_range(-0.26, 0.26),
			"scale": tree_rng.randf_range(0.7, 1.3),
			"accept_roll": tree_rng.randf(),
		})

	# GRASS CANDIDATES
	var grass_rng := RandomNumberGenerator.new()
	grass_rng.seed = hash([chunk_coord, mission_seed]) + 5000

	var grass_count: int = int(round(float(GRASS_CANDIDATES_PER_CHUNK) * density_mult))
	for i in grass_count:
		var local_x := grass_rng.randf() * chunk_size
		var local_z := grass_rng.randf() * chunk_size
		var world_x := world_offset_x + local_x
		var world_z := world_offset_z + local_z
		var bundle_x := int(local_x / bundle_meters_local)
		var bundle_z := int(local_z / bundle_meters_local)
		if bundle_x < 0 or bundle_x >= _bundles_per_chunk or bundle_z < 0 or bundle_z >= _bundles_per_chunk:
			continue

		placements.append({
			"type": "grass",
			"world_x": world_x,
			"world_z": world_z,
			"bundle_x": bundle_x,
			"bundle_z": bundle_z,
			"rot_y": grass_rng.randf() * TAU,
			"tilt_x": 0.0,
			"tilt_z": 0.0,
			"scale": grass_rng.randf_range(0.8, 1.5),
			"accept_roll": grass_rng.randf(),
		})

	_chunk_placements[chunk_coord] = placements


## Materialize trees from placement cache based on current terrain types
func _materialize_vegetation(chunk_coord: Vector2i, heightmap: Object) -> void:
	if not _chunk_placements.has(chunk_coord) or not _chunk_terrain.has(chunk_coord):
		return

	var placements: Array = _chunk_placements[chunk_coord]
	var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
	var transforms: Array[Transform3D] = []

	for p: Dictionary in placements:
		if p.type != "tree":
			continue

		var bundle_idx: int = p.bundle_z * _bundles_per_chunk + p.bundle_x
		if bundle_idx >= terrain.size():
			continue
		var terrain_type: int = terrain[bundle_idx]
		var props: Array = TYPE_PROPS.get(terrain_type, [0.0])
		var tree_chance: float = props[0]

		if tree_chance <= 0.0 or p.accept_roll > tree_chance:
			continue

		# Sample height NOW (in case terrain was deformed)
		var height := heightmap.sample_world(p.world_x, p.world_z) as float

		var t := Transform3D.IDENTITY
		t = t.rotated(Vector3.RIGHT, p.tilt_x)
		t = t.rotated(Vector3.FORWARD, p.tilt_z)
		t = t.rotated(Vector3.UP, p.rot_y)
		t = t.scaled(Vector3.ONE * p.scale)
		t.origin = Vector3(p.world_x, height, p.world_z)
		transforms.append(t)

	if transforms.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _meshes[0]
	multimesh.instance_count = transforms.size()

	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for i in transforms.size():
		var xform := transforms[i]
		var b := i * 12
		buffer[b+0] = xform.basis.x.x; buffer[b+1] = xform.basis.y.x; buffer[b+2] = xform.basis.z.x; buffer[b+3] = xform.origin.x
		buffer[b+4] = xform.basis.x.y; buffer[b+5] = xform.basis.y.y; buffer[b+6] = xform.basis.z.y; buffer[b+7] = xform.origin.y
		buffer[b+8] = xform.basis.x.z; buffer[b+9] = xform.basis.y.z; buffer[b+10] = xform.basis.z.z; buffer[b+11] = xform.origin.z
	multimesh.buffer = buffer

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = multimesh
	mm_instance.name = "Veg_%d_%d" % [chunk_coord.x, chunk_coord.y]
	add_child(mm_instance)
	_chunk_instances[chunk_coord] = mm_instance

	print("[VegetationManager] Chunk %s: %d trees materialized" % [chunk_coord, transforms.size()])


## Materialize grass from placement cache based on current terrain types
func _materialize_grass(chunk_coord: Vector2i, heightmap: Object) -> void:
	if not _grass_mesh:
		return
	if not _chunk_placements.has(chunk_coord) or not _chunk_terrain.has(chunk_coord):
		return

	var placements: Array = _chunk_placements[chunk_coord]
	var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
	var grass_transforms: Array[Transform3D] = []

	for p: Dictionary in placements:
		if p.type != "grass":
			continue

		var bundle_idx: int = p.bundle_z * _bundles_per_chunk + p.bundle_x
		if bundle_idx >= terrain.size():
			continue
		var terrain_type: int = terrain[bundle_idx]
		var grass_chance: float = GRASS_ACCEPT.get(terrain_type, 0.0)

		if grass_chance <= 0.0 or p.accept_roll > grass_chance:
			continue

		# Sample height NOW (in case terrain was deformed)
		var height := heightmap.sample_world(p.world_x, p.world_z) as float

		var t := Transform3D.IDENTITY
		t = t.rotated(Vector3.UP, p.rot_y)
		t = t.scaled(Vector3.ONE * p.scale)
		t.origin = Vector3(p.world_x, height, p.world_z)
		grass_transforms.append(t)

	if grass_transforms.is_empty():
		return

	var grass_mm := MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	grass_mm.mesh = _grass_mesh
	grass_mm.instance_count = grass_transforms.size()

	var buffer := PackedFloat32Array()
	buffer.resize(grass_transforms.size() * 12)
	for i in grass_transforms.size():
		var t := grass_transforms[i]
		var b := i * 12
		buffer[b+0] = t.basis.x.x; buffer[b+1] = t.basis.y.x; buffer[b+2] = t.basis.z.x; buffer[b+3] = t.origin.x
		buffer[b+4] = t.basis.x.y; buffer[b+5] = t.basis.y.y; buffer[b+6] = t.basis.z.y; buffer[b+7] = t.origin.y
		buffer[b+8] = t.basis.x.z; buffer[b+9] = t.basis.y.z; buffer[b+10] = t.basis.z.z; buffer[b+11] = t.origin.z
	grass_mm.buffer = buffer

	var grass_instance := MultiMeshInstance3D.new()
	grass_instance.multimesh = grass_mm
	grass_instance.name = "Grass_%d_%d" % [chunk_coord.x, chunk_coord.y]
	add_child(grass_instance)

	_chunk_grass[chunk_coord] = grass_instance


## Clear vegetation in a circular area - clears entire bundles
## heightmap is optional - if provided, chunks are re-materialized from cache
func clear_area(center: Vector3, radius: float, chunk_size: float, heightmap: Object = null) -> int:
	var cleared := 0
	var radius_sq := radius * radius
	var affected_chunks: Array[Vector2i] = []

	for chunk_coord: Vector2i in _chunk_terrain.keys().duplicate():
		var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
		var chunk_world_x := chunk_coord.x * chunk_size
		var chunk_world_z := chunk_coord.y * chunk_size
		var changed := false

		for bz in _bundles_per_chunk:
			for bx in _bundles_per_chunk:
				var bundle_idx := bz * _bundles_per_chunk + bx

				if terrain[bundle_idx] == TerrainType.CLEAR:
					continue

				var bundle_x := chunk_world_x + (bx + 0.5) * bundle_meters
				var bundle_z := chunk_world_z + (bz + 0.5) * bundle_meters
				var dist_sq := (bundle_x - center.x) ** 2 + (bundle_z - center.z) ** 2

				if dist_sq < radius_sq:
					terrain[bundle_idx] = TerrainType.CLEAR
					cleared += 1
					changed = true

		if changed:
			_chunk_terrain[chunk_coord] = terrain
			affected_chunks.append(chunk_coord)

	# Re-materialize affected chunks from cache.
	for chunk_coord in affected_chunks:
		clear_chunk_visuals(chunk_coord)
		if heightmap:
			_rematerialize(chunk_coord, heightmap, chunk_size)

	return cleared


## ONE place that decides how a chunk's vegetation is built. Called by generate_for_chunk()
## and by clear_area() -- never duplicate this branch.
func _rematerialize(chunk_coord: Vector2i, heightmap: Object, chunk_size: float) -> void:
	if canopy_source == CanopySource.TREE_COVER and _tree_cover != null and _chunk_terrain.has(chunk_coord):
		# Individual-species near-solid+collider / far-card LOD from the terrain grid.
		_tree_cover.generate_for_chunk(chunk_coord, _build_scatter(chunk_coord, heightmap, chunk_size))
	elif _patch_layer != null and _patch_layer.enabled and _chunk_terrain.has(chunk_coord):
		# Authored patches bring their own trees - the lone-tree layer would double
		# the canopy and blow the tri budget, so it stays off.
		_patch_layer.generate_for_chunk(
			chunk_coord, _chunk_terrain[chunk_coord],
			_bundles_per_chunk, bundle_meters, heightmap, chunk_size)
	else:
		_materialize_vegetation(chunk_coord, heightmap)
	_materialize_grass(chunk_coord, heightmap)


## Derive a per-species {name, xf} scatter from this chunk's terrain grid, deterministically
## from mission_seed (ADR-010). TYPE_PROPS governs how many; TYPE_SPECIES which. Fed to
## TreeCoverLayer.generate_for_chunk when the canopy is TREE_COVER.
func _build_scatter(chunk_coord: Vector2i, heightmap: Object, chunk_size: float) -> Array:
	var scatter: Array = []
	if not _chunk_terrain.has(chunk_coord):
		return scatter
	var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([chunk_coord, mission_seed])
	var origin_x: float = chunk_coord.x * chunk_size
	var origin_z: float = chunk_coord.y * chunk_size
	for bz in _bundles_per_chunk:
		for bx in _bundles_per_chunk:
			var ttype: int = terrain[bz * _bundles_per_chunk + bx]
			var pool: Array = TYPE_SPECIES.get(ttype, [])
			if pool.is_empty():
				continue
			var props: Array = TYPE_PROPS[ttype]
			var chance: float = props[0]
			if chance <= 0.0 or rng.randf() > chance:
				continue
			var count: int = rng.randi_range(int(props[1]), int(props[2]))
			for _i in count:
				var wx: float = origin_x + (bx + rng.randf()) * bundle_meters
				var wz: float = origin_z + (bz + rng.randf()) * bundle_meters
				var nm: String = String(pool[rng.randi_range(0, pool.size() - 1)])
				var h: float = heightmap.sample_world(wx, wz)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2))
				scatter.append({"name": nm, "xf": Transform3D(basis, Vector3(wx, h, wz))})
	return scatter


## Check if position blocks LOS (heavy/medium jungle)
func blocks_los(world_pos: Vector3, chunk_size: float) -> bool:
	var chunk_coord := Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

	if not _chunk_terrain.has(chunk_coord):
		return false

	var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
	var local_x := fmod(world_pos.x, chunk_size)
	var local_z := fmod(world_pos.z, chunk_size)
	if local_x < 0: local_x += chunk_size
	if local_z < 0: local_z += chunk_size

	var bx := int(local_x / bundle_meters)
	var bz := int(local_z / bundle_meters)

	if bx < 0 or bx >= _bundles_per_chunk or bz < 0 or bz >= _bundles_per_chunk:
		return false

	var terrain_type: int = terrain[bz * _bundles_per_chunk + bx]
	var props: Array = TYPE_PROPS[terrain_type]
	return props[3]  # blocks_los


func get_terrain_type_at(world_pos: Vector3, chunk_size: float) -> int:
	var chunk_coord := Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

	if not _chunk_terrain.has(chunk_coord):
		return TerrainType.CLEAR

	var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
	var local_x := fmod(world_pos.x, chunk_size)
	var local_z := fmod(world_pos.z, chunk_size)
	if local_x < 0: local_x += chunk_size
	if local_z < 0: local_z += chunk_size

	var bx := int(local_x / bundle_meters)
	var bz := int(local_z / bundle_meters)

	if bx < 0 or bx >= _bundles_per_chunk or bz < 0 or bz >= _bundles_per_chunk:
		return TerrainType.CLEAR

	return terrain[bz * _bundles_per_chunk + bx]


## Get movement speed multiplier at world position (1.0 = full speed)
func get_movement_multiplier_at(world_pos: Vector3, chunk_size: float) -> float:
	var terrain_type := get_terrain_type_at(world_pos, chunk_size)
	var props: Array = TYPE_PROPS[terrain_type]
	return props[4]  # movement_speed


func set_terrain_type_at(world_pos: Vector3, chunk_size: float, new_type: int) -> void:
	var chunk_coord := Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

	if not _chunk_terrain.has(chunk_coord):
		return

	var terrain: PackedByteArray = _chunk_terrain[chunk_coord]
	var local_x := fmod(world_pos.x, chunk_size)
	var local_z := fmod(world_pos.z, chunk_size)
	if local_x < 0: local_x += chunk_size
	if local_z < 0: local_z += chunk_size

	var bx := int(local_x / bundle_meters)
	var bz := int(local_z / bundle_meters)

	if bx >= 0 and bx < _bundles_per_chunk and bz >= 0 and bz < _bundles_per_chunk:
		terrain[bz * _bundles_per_chunk + bx] = new_type
		_chunk_terrain[chunk_coord] = terrain


## Clear visuals only - keeps cache for re-materialization
func clear_chunk_visuals(chunk_coord: Vector2i) -> void:
	if _chunk_instances.has(chunk_coord):
		var instance: MultiMeshInstance3D = _chunk_instances[chunk_coord]
		if is_instance_valid(instance):
			instance.queue_free()
		_chunk_instances.erase(chunk_coord)
	if _chunk_grass.has(chunk_coord):
		var grass: MultiMeshInstance3D = _chunk_grass[chunk_coord]
		if is_instance_valid(grass):
			grass.queue_free()
		_chunk_grass.erase(chunk_coord)
	if _patch_layer != null:
		_patch_layer.clear_chunk(chunk_coord)
	if _tree_cover != null:
		_tree_cover.clear_chunk(chunk_coord)
	# NOTE: Does NOT erase _chunk_terrain or _chunk_placements


## Full unload - clears visuals AND cache
func clear_chunk_full(chunk_coord: Vector2i) -> void:
	clear_chunk_visuals(chunk_coord)
	_chunk_terrain.erase(chunk_coord)
	_chunk_placements.erase(chunk_coord)


## Legacy alias
func clear_chunk(chunk_coord: Vector2i) -> void:
	clear_chunk_full(chunk_coord)


func clear_all() -> void:
	for instance: MultiMeshInstance3D in _chunk_instances.values():
		if is_instance_valid(instance):
			instance.queue_free()
	for grass: MultiMeshInstance3D in _chunk_grass.values():
		if is_instance_valid(grass):
			grass.queue_free()
	_chunk_instances.clear()
	_chunk_grass.clear()
	_chunk_terrain.clear()
	_chunk_placements.clear()


## OPTIMIZED: Single surface with vertex colors to reduce draw calls from 9 to 1
func _create_procedural_tree() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk_color := Color(0.35, 0.28, 0.2)  # Palm bark color
	var frond_color := Color(0.15, 0.35, 0.1)  # Bright palm green

	# Build trunk (6-sided cylinder, 10m tall)
	var trunk_segments := 6
	var trunk_bottom_radius := 0.25
	var trunk_top_radius := 0.15
	var trunk_height := 8.0

	for i in trunk_segments:
		var angle0 := (float(i) / trunk_segments) * TAU
		var angle1 := (float(i + 1) / trunk_segments) * TAU

		var bottom0 := Vector3(cos(angle0) * trunk_bottom_radius, 0, sin(angle0) * trunk_bottom_radius)
		var bottom1 := Vector3(cos(angle1) * trunk_bottom_radius, 0, sin(angle1) * trunk_bottom_radius)
		var top0 := Vector3(cos(angle0) * trunk_top_radius, trunk_height, sin(angle0) * trunk_top_radius)
		var top1 := Vector3(cos(angle1) * trunk_top_radius, trunk_height, sin(angle1) * trunk_top_radius)

		# Normal pointing outward
		var normal := Vector3(cos((angle0 + angle1) * 0.5), 0.1, sin((angle0 + angle1) * 0.5)).normalized()

		st.set_color(trunk_color)
		st.set_normal(normal)

		# Two triangles per segment
		st.add_vertex(bottom0)
		st.add_vertex(bottom1)
		st.add_vertex(top1)

		st.add_vertex(bottom0)
		st.add_vertex(top1)
		st.add_vertex(top0)

	# Build fronds - 8 radiating from top
	var frond_count := 8
	var frond_length := 4.0
	var crown_height := trunk_height
	var droop_angle := deg_to_rad(35.0)

	for i in frond_count:
		var angle := (float(i) / frond_count) * TAU
		var dir := Vector3(cos(angle), 0, sin(angle))
		var drooped_dir := Vector3(dir.x * cos(droop_angle), -sin(droop_angle), dir.z * cos(droop_angle)).normalized()

		var base := Vector3(0, crown_height, 0)
		var tip := base + drooped_dir * frond_length
		var mid := base + drooped_dir * (frond_length * 0.5) + Vector3(0, 0.3, 0)

		var width := 0.4
		var perp := Vector3(-dir.z, 0, dir.x) * width

		st.set_color(frond_color)
		st.set_normal(Vector3.UP)

		# Front face triangles
		st.add_vertex(base)
		st.add_vertex(mid + perp * 0.8)
		st.add_vertex(mid - perp * 0.8)

		st.add_vertex(mid + perp * 0.8)
		st.add_vertex(tip)
		st.add_vertex(mid - perp * 0.8)

		# Back face triangles
		st.set_normal(-Vector3.UP)
		st.add_vertex(base)
		st.add_vertex(mid - perp * 0.8)
		st.add_vertex(mid + perp * 0.8)

		st.add_vertex(mid - perp * 0.8)
		st.add_vertex(tip)
		st.add_vertex(mid + perp * 0.8)

	st.generate_normals()
	st.index()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	var mesh := st.commit()
	mesh.surface_set_material(0, mat)

	assert(mesh.get_surface_count() == 1, "Tree mesh should have exactly 1 surface")

	return mesh


func _create_procedural_grass() -> ArrayMesh:
	var mesh := ArrayMesh.new()

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.2, 0.4, 0.12)  # Jungle grass green
	grass_mat.roughness = 0.9
	grass_mat.cull_mode = BaseMaterial3D.CULL_BACK

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(grass_mat)

	var blade_count := 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # Consistent for all grass meshes

	for i in blade_count:
		var offset_x := rng.randf_range(-0.3, 0.3)
		var offset_z := rng.randf_range(-0.3, 0.3)
		var height := rng.randf_range(0.4, 0.8)
		var lean := rng.randf_range(-0.15, 0.15)

		var base1 := Vector3(offset_x - 0.03, 0, offset_z)
		var base2 := Vector3(offset_x + 0.03, 0, offset_z)
		var tip := Vector3(offset_x + lean, height, offset_z + lean * 0.5)

		st.set_normal(Vector3(0, 0.5, 0.5).normalized())
		st.add_vertex(base1)
		st.add_vertex(base2)
		st.add_vertex(tip)

		# Back face
		st.add_vertex(base2)
		st.add_vertex(base1)
		st.add_vertex(tip)

	mesh = st.commit()
	return mesh
