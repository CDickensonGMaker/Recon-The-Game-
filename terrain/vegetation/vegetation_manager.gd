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

## Authored 12m jungle patches (tools/make_jungle_patches.py) instead of lone trees.
## The patches carry their own trees, so the single-tree layer stays off while this is on.
@export var use_jungle_patches: bool = true
const JunglePatchLayerScript := preload("res://terrain/vegetation/jungle_patch_layer.gd")
var _patch_layer: JunglePatchLayer = null

## Which canopy renderer builds the near/far cover. The two never run together (double canopy).
## This @export default is NOT what ships: game_world.gd:100-101 overrides it from
## WorldConfig.USE_TREE_COVER, which is true, so the generated AO runs TREE_COVER and
## JunglePatchLayer is never built. Read world_config.gd:21 for the live value, never this default.
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
	TerrainType.GRASSLAND: ["tall_grass_a", "tall_grass_b", "elephant_grass_a", "bush_a", "bush_a", "bush_c", "fern_a"],
	TerrainType.LIGHT_JUNGLE: ["banana_a", "bush_a", "bush_a", "bush_b", "bush_c", "fern_a", "fern_b", "palm_sapling_a", "jungle_palm_a1"],
	TerrainType.MEDIUM_JUNGLE: ["broadleaf_a", "broadleaf_b", "banana_a", "jungle_palm_a1", "jungle_palm_b1", "bamboo_a", "bush_b", "bush_b", "bush_c", "fern_b", "fern_c", "elephant_grass_b"],
	TerrainType.HEAVY_JUNGLE: ["broadleaf_a", "broadleaf_b", "broadleaf_c", "bamboo_a", "bamboo_b", "bamboo_c", "banana_b", "jungle_palm_a2", "jungle_palm_b2", "bush_b", "bush_c", "fern_c", "liana_a", "vine_a"],
}

## A RICE PADDY IS A PLANTED FIELD, NOT A SCATTER. Every other zone rolls a per-bundle
## chance and drops plants at random positions; a paddy is worked ground, so its rice is laid
## on a ROW LATTICE anchored to the FIELD, which is why the rows run unbroken across bundle and
## chunk seams instead of restarting every 8 m.
const PADDY_FIELD_TILE: float = 48.0    ## one field; rows change direction at its edge
const PADDY_ROW_PITCH: float = 2.6      ## m between rows - the open water/mud lane you see down
const PADDY_HILL_PITCH: float = 1.25    ## m between clumps along a row; a clump is 1.2-1.4 m wide,
                                        ## so a row reads as one continuous green line
const PADDY_JITTER_ALONG: float = 0.16  ## hand-planted, not machine-planted - but small enough
const PADDY_JITTER_ACROSS: float = 0.10 ## that the rows survive it
## A clump seats this far BELOW a flooded cell's water surface, so it stands IN the water rather
## than on the bed. Past PADDY_MAX_WADE the cell is a channel or a pond, not field: nothing is
## planted there, and that is what cuts the open water lanes through a paddy.
## How far a feathered clearing edge wanders in and out around its nominal radius. Small
## enough that a 20 m stand-off is still 20 m; large enough that no bearing shows a drawn circle.
const FEATHER_WOBBLE_M: float = 6.0

const PADDY_SUBMERGE: float = 0.18
const PADDY_MAX_WADE: float = 0.85

# Bundle size in meters
var bundle_meters: float:
	get: return cell_size * BUNDLE_SIZE

# Terrain type properties: [tree_chance, tree_count_min, tree_count_max]
# RICE_PADDY's 0.00 is DELIBERATE and must stay: it governs the random per-bundle scatter,
# and a worked field is not a scatter. Its rice comes from _plant_paddy_rows below.
const TYPE_PROPS := {
	TerrainType.CLEAR:         [0.00, 0, 0],
	TerrainType.RICE_PADDY:    [0.00, 0, 0],
	TerrainType.GRASSLAND:     [0.16, 0, 1],  # Very sparse
	TerrainType.LIGHT_JUNGLE:  [0.42, 1, 3],  # Sparse
	TerrainType.MEDIUM_JUNGLE: [0.72, 2, 4],  # Moderate density
	TerrainType.HEAVY_JUNGLE:  [0.92, 3, 6],  # Dense canopy
}

var _meshes: Array[Mesh] = []  # Tree meshes
var _fallback_mesh: ArrayMesh

# Grid data per chunk - stores TerrainType for each bundle
# Dictionary[Vector2i, PackedByteArray]
var _chunk_terrain: Dictionary = {}

# MultiMesh instances per chunk
var _chunk_instances: Dictionary = {}  # Trees

# Placement cache - built once per chunk, survives terrain changes
var _chunk_placements: Dictionary = {}

const TREE_CANDIDATES_PER_CHUNK := 1200  # FPS fork: reduced from RTS 2000

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

## Perf-attribution toggles (perf_probe.gd): force jungle patches hidden so
## each system's frame cost can be measured by difference.
var patches_disabled: bool = false

## Localized density thickening set AFTER the mission plan is known (set_density_centers):
## the player insertion ring and each hamlet. Each entry:
##   {pos: Vector3, radius: float, chance_floor: float, count_boost: int, bush_bias: bool}
## Read by _build_scatter; only lifts density within a cell's own classified pool.
var _density_centers: Array = []


func _ready() -> void:
	_min_slope_dot = cos(deg_to_rad(max_slope_degrees))
	_load_vegetation_meshes()
	if canopy_source == CanopySource.TREE_COVER:
		_tree_cover = TreeCoverLayerScript.new()
		_tree_cover.name = "TreeCoverLayer"
		_tree_cover.load_species(_all_species())
		TreeBreakSystem.warm_parts(_tree_cover)
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

		var chunk_center := Vector3(
			coord.x * _chunk_size + _chunk_size * 0.5,
			0,
			coord.y * _chunk_size + _chunk_size * 0.5
		)
		if _chunk_instances.has(coord):
			_chunk_instances[coord].visible = in_frustum


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

	if _meshes.is_empty():
		_fallback_mesh = _create_procedural_tree()
		_meshes.append(_fallback_mesh)
		print("[VegetationManager] Using procedural tree as primary mesh")

	print("[VegetationManager] Loaded %d tree mesh(es)" % _meshes.size())



func _find_first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var mesh := _find_first_mesh(child)
		if mesh:
			return mesh
	return null


## `partial` is the world-metre rect of ground that moved (a crater's patch) or the spot a
## felled log settled on. With it, and a chunk the tree layer already draws, the redraw is a
## diff against what is standing instead of a rebuild of everything - see TreeCoverLayer.update_chunk.
func generate_for_chunk(chunk_coord: Vector2i, heightmap: Object, chunk_size: float,
		partial: Rect2 = Rect2()) -> void:
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
	_rematerialize(chunk_coord, heightmap, chunk_size, partial)


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



## A blast footprint where individual plant instances are removed. Persisted so a
## chunk rebuild keeps the crater clear. Cleared per-mission in clear_all().
var _veg_holes: Array = []

## SCATTER CACHE. _build_scatter walks every bundle in the chunk, rolls the RNG, tests every
## density centre and picks a species - and it is fully determined by (chunk_coord,
## mission_seed, the terrain grid, the veg holes, the fell registry, the density centres).
## A CRATER changes NONE of those: it edits the heightmap, so the only thing that moves is
## each plant's Y. Rebuilding a chunk after a shell was paying 18.8ms to re-derive an answer
## it already had (measured 2026-09-09, veg.build_scatter over 110 rebuilds).
##
## The epoch is the designed invalidation, and it is deliberately COARSE - one counter for
## the whole layer, bumped by every writer of the inputs. A stale scatter index is a real
## hazard (a crater and a felling can touch the same chunk in one window), and a
## conservative bump costs one recompute where a clever key would cost a wrong tree.
var _scatter_cache: Dictionary = {}
var _scatter_epoch: int = 0
## chunk -> the epoch at which THAT chunk's inputs last changed. The global counter above is
## the clock; this is what a chunk actually has to beat. A felled tree in one chunk used to
## invalidate the scatter of every chunk on the map, and an assault fells trees continuously -
## measured 2026-09-09: veg.build_scatter back at 80.1 ms inside the 45-man fight.
var _scatter_dirty: Dictionary = {}

## Holes bucketed by world cell. _in_veg_hole runs per CANDIDATE PLANT on every chunk
## re-scatter, so a linear scan makes every rebuild slower for the rest of the mission -
## the cost that decides whether persistent damage is affordable at all. A hole is filed
## in every cell its bounding square touches, so a lookup reads one cell.
const HOLE_BUCKET_M: float = 32.0
var _veg_hole_buckets: Dictionary = {}


func _hole_cell(wx: float, wz: float) -> Vector2i:
	return Vector2i(floori(wx / HOLE_BUCKET_M), floori(wz / HOLE_BUCKET_M))


## Mark one chunk's scatter stale. Callers that know WHICH chunks they touched use this; the
## coarse global bump stays as the clock, so a caller that forgets to name a chunk is still
## caught by set_density_centers/clear_all invalidating everything.
##
## CONTRACT: every writer bumps _scatter_epoch BEFORE naming its chunks, so "the epoch this
## chunk must beat" IS the current one - a rebuild stamped at it has already read the change.
## This read `_scatter_epoch + 1`, which no rebuild can ever satisfy: _build_scatter stamps
## the cache with the CURRENT epoch, so a dirtied chunk missed on its own rebuild and stayed
## missing until some unrelated writer happened to raise the clock. Measured 2026-09-09,
## stall_bench crater phase: `veg.scatter_miss x36, veg.scatter_hit x0` - the cache built to
## make craters cheap never hit once.
func _dirty_scatter(chunk_coord: Vector2i) -> void:
	_scatter_dirty[chunk_coord] = _scatter_epoch


## Apply a hole to the CACHED scatter instead of invalidating it, and say whether it took.
##
## A blast footprint DELETES plants; it does not change what the generator would produce for
## the survivors. _build_scatter draws every RNG value for a candidate - position, species,
## basis - BEFORE it tests the hole, so removing entries cannot perturb the stream. Pruning is
## therefore identical to regenerating with the hole in place (guarded by
## tools/probe_crater_veg.gd, which regenerates the same chunk and compares), and it is the
## difference between a ~15ms re-scatter and a sub-millisecond filter on the frame a shell lands.
##
## Felled logs are exempt: _build_scatter re-emits them INSIDE holes on purpose - the log lies
## in the crater the blast just made, which is where the cover is wanted.
func _prune_scatter_cache(chunk_coord: Vector2i, hole: Dictionary) -> bool:
	var hit: Dictionary = _scatter_cache.get(chunk_coord, {}) as Dictionary
	if hit.is_empty() or int(hit["epoch"]) < int(_scatter_dirty.get(chunk_coord, 0)):
		return false
	# DEAD IN PLACE, OVER THE CELLS THE HOLE REACHES (2026-09-11). This used to walk every
	# entry in the chunk and rebuild the list without the ones the hole took - ~9,700
	# dictionary reads and appends per touched chunk, four chunks for a mortar round, inside
	# the frame the shell landed in: dz.crater 49 ms worst in the siege ledger. The index says
	# which cells the footprint can touch; a plant it takes is marked dead where it stands
	# (its uid and index stay valid for everything downstream, which now skips dead entries),
	# and nothing else in the chunk is read.
	var scatter: Array = hit["scatter"]
	var cells: Dictionary = hit.get("cells", {})
	if cells.is_empty():
		cells = _index_cells(scatter)
		hit["cells"] = cells
	var c: Vector3 = hole["c"]
	var reach: float = sqrt(float(hole.get("r2_out", hole["r2"]))) + FEATHER_WOBBLE_M
	var c0 := Vector2i(floori((c.x - reach) / CACHE_CELL_M), floori((c.z - reach) / CACHE_CELL_M))
	var c1 := Vector2i(floori((c.x + reach) / CACHE_CELL_M), floori((c.z + reach) / CACHE_CELL_M))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var ck := Vector2i(cx, cz)
			if not cells.has(ck):
				continue
			for i: int in (cells[ck] as PackedInt32Array):
				var e: Dictionary = scatter[i]
				if bool(e.get("dead", false)) or bool(e.get("fell", false)):
					continue
				var o: Vector3 = (e["xf"] as Transform3D).origin
				if _hole_removes(hole, o.x, o.z):
					e["dead"] = true
	hit["epoch"] = _scatter_epoch
	return true


func _file_veg_hole(hole: Dictionary) -> void:
	_scatter_epoch += 1
	var c: Vector3 = hole["c"]
	var r: float = sqrt(float(hole.get("r2_out", hole["r2"]))) + FEATHER_WOBBLE_M
	var lo: Vector2i = _hole_cell(c.x - r, c.z - r)
	var hi: Vector2i = _hole_cell(c.x + r, c.z + r)
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			var key := Vector2i(cx, cz)
			if not _veg_hole_buckets.has(key):
				_veg_hole_buckets[key] = []
			(_veg_hole_buckets[key] as Array).append(hole)


## A bundle whose centre sits well inside a hole's HARD radius has nothing to contribute:
## every plant it would lay is thrown away one line later.
##
## THE PADDY LATTICE IS THE ONLY CALLER, and that is not a preference. The random scatter
## draws its RNG BEFORE it tests the hole, on purpose: that is what makes pruning a cached
## scatter identical to regenerating it with the hole in place (tools/probe_crater_veg.gd,
## which caught exactly this - skipping a holed bundle there shifted the chunk's RNG stream
## and moved 1,805 unrelated plants). The lattice draws no RNG at all, so skipping one of its
## bundles moves nothing.
func _bundle_fully_holed(bcx: float, bcz: float) -> bool:
	var margin: float = bundle_meters * 0.7072
	for hole: Dictionary in _veg_hole_buckets.get(_hole_cell(bcx, bcz), []):
		var c: Vector3 = hole["c"]
		var ri: float = sqrt(float(hole["r2"])) - margin
		if ri > 0.0 and (bcx - c.x) ** 2 + (bcz - c.z) ** 2 < ri * ri:
			return true
	return false


func _in_veg_hole(wx: float, wz: float) -> bool:
	var bucket: Array = _veg_hole_buckets.get(_hole_cell(wx, wz), [])
	for hole: Dictionary in bucket:
		if _hole_removes(hole, wx, wz):
			return true
	return false


## THE ONE HOLE PREDICATE. A blast footprint is a hard disc; a site clearing can carry a
## FEATHER, and both are answered here so the live scatter and the cached-scatter prune can
## never disagree about which plants a hole took.
##
## The feather is why a clearing no longer reads as a stamped circle. Inside r2 everything
## goes. Between r2 and r2_out a plant SURVIVES with a probability that ramps 0 -> 1 outward,
## drawn from a position hash (0.25 m grain) so it is deterministic and identical on every
## rebuild, and the band's own edge wanders with a low-frequency angular term. What the player
## walks out through is thinning scrub, not a shaved ring.
func _hole_removes(hole: Dictionary, wx: float, wz: float) -> bool:
	var c: Vector3 = hole["c"]
	var dx: float = wx - c.x
	var dz: float = wz - c.z
	var d2: float = dx * dx + dz * dz
	var r2i: float = float(hole["r2"])
	if d2 < r2i:
		return true
	var r2o: float = float(hole.get("r2_out", r2i))
	if d2 >= r2o:
		return false
	var ri: float = sqrt(r2i)
	var ro: float = sqrt(r2o)
	var wob: float = FEATHER_WOBBLE_M * sin(3.0 * atan2(dz, dx) + float(hole.get("phase", 0.0)))
	var t: float = clampf((sqrt(d2) - ri - wob) / maxf(0.001, ro - ri), 0.0, 1.0)
	return _hash01(floori(wx * 4.0), floori(wz * 4.0), 7919) > t


## Clear vegetation in a circular blast FOOTPRINT: record the hole and rebuild only
## the chunk(s) it overlaps, excluding just the plant instances inside the radius
## (see _build_scatter). The old path set whole 32m bundles to CLEAR, so a 10m blast
## wiped a chunk's worth of trees - "half the trees gone, not a crater". The veg
## terrain grid is untouched, so AI sight is unaffected; this is visual removal.
## defer_rebuild: the caller has ALREADY queued a terrain dig over this same footprint
## (DamageSystem drains it at TERRAIN_DEFORMS_PER_FRAME), and that dig rebuilds every chunk
## it touches. The hole is filed and the scatter dirtied here; the redraw rides the dig.
## Without it a shell re-materialised each touched chunk TWICE - measured 2026-09-09,
## stall_bench crater phase: 36 build_scatter + 36 tree_cover_mmi calls for 6 shells over
## 18 chunk rebuilds, exactly two per chunk, 790ms of the phase. The deferred pass is also
## the CORRECT one: it runs after the heightmap edit, so plants re-seat on the new ground
## instead of the old.
func clear_area(center: Vector3, radius: float, chunk_size: float, heightmap: Object = null,
		defer_rebuild: bool = false, feather: float = 0.0) -> int:
	var outer: float = radius + maxf(0.0, feather) + (FEATHER_WOBBLE_M if feather > 0.0 else 0.0)
	var min_cx := floori((center.x - outer) / chunk_size)
	var max_cx := floori((center.x + outer) / chunk_size)
	var min_cz := floori((center.z - outer) / chunk_size)
	var max_cz := floori((center.z + outer) / chunk_size)
	var hole := {"c": center, "r2": radius * radius}
	if feather > 0.0:
		hole["r2_out"] = (radius + feather) * (radius + feather)
		hole["phase"] = _hash01(floori(center.x), floori(center.z), 4441) * TAU
	_veg_holes.append(hole)
	_file_veg_hole(hole)
	for cx2 in range(min_cx, max_cx + 1):
		for cz2 in range(min_cz, max_cz + 1):
			var cc := Vector2i(cx2, cz2)
			if not _prune_scatter_cache(cc, hole):
				_dirty_scatter(cc)

	var rebuilt := 0
	if defer_rebuild:
		for cx3 in range(min_cx, max_cx + 1):
			for cz3 in range(min_cz, max_cz + 1):
				if _chunk_terrain.has(Vector2i(cx3, cz3)):
					rebuilt += 1
		return rebuilt
	# THE HOLE'S OWN FOOTPRINT rides along (2026-09-11). Past the per-mission dig ceiling
	# DamageSystem skips the dig and calls this with defer_rebuild false - and this branch
	# rebuilt every touched chunk in FULL: mmi.group 18-23 ms + mmi.register 12-13 ms +
	# build 5 ms + scatter re-seat 9 ms, ~45 ms a chunk, for a bomb 260 m behind the player.
	# With the footprint named, _rematerialize takes the same local path a crater takes;
	# a chunk the tree layer does not draw yet (roads and the firebase at load) still goes full.
	var foot := Rect2(Vector2(center.x - outer, center.z - outer), Vector2(outer * 2.0, outer * 2.0))
	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var chunk_coord := Vector2i(cx, cz)
			if not _chunk_terrain.has(chunk_coord):
				continue
			if heightmap:
				_rematerialize(chunk_coord, heightmap, chunk_size, foot)
			rebuilt += 1
	return rebuilt


## Every snag and lying log dropped this mission: {name (segment part), xf, chunk,
## trunk_r?, trunk_h?}. TreeBreakSystem writes them when a broken tree settles; they
## survive chunk rebuilds because _build_scatter re-emits them, and the pooled 70m ring
## bodies them on demand. Cleared per-mission in clear_all().
var _fell_registry: Array = []
## Next plant uid (see _build_scatter). Never reused within a mission.
var _next_uid: int = 1
## coord -> the rect a just-settled log landed in, consumed by rebuild_chunk so the redraw
## for it is the local path.
var _fell_partial: Dictionary = {}


## A settled tree's snag and log. When the chunk's cached scatter is current they are APPENDED
## to it - the generator would have emitted them as ordinary candidates on the next miss, and
## nothing else in the list moves - and the chunk is marked for a local redraw around them.
## A chunk with no current cache is dirtied as before and takes the full path.
func add_fell_entries(entries: Array) -> void:
	_scatter_epoch += 1
	for e: Dictionary in entries:
		_fell_registry.append(e)
		if not e.has("chunk"):
			continue
		var cc: Vector2i = e["chunk"]
		var hit: Dictionary = _scatter_cache.get(cc, {}) as Dictionary
		if hit.is_empty() or int(hit["epoch"]) < int(_scatter_dirty.get(cc, 0)):
			_dirty_scatter(cc)
			continue
		var live: Dictionary = {"name": String(e["name"]), "xf": e["xf"] as Transform3D,
			"fell": true, "uid": _next_uid}
		_next_uid += 1
		if e.has("trunk_r"):
			live["trunk_r"] = e["trunk_r"]
			live["trunk_h"] = e.get("trunk_h", 1.0)
		(hit["scatter"] as Array).append(live)
		if hit.has("cells"):
			_index_add(hit["cells"] as Dictionary, (hit["scatter"] as Array).size() - 1,
				(live["xf"] as Transform3D).origin)
		var o: Vector3 = (e["xf"] as Transform3D).origin
		var spot := Rect2(Vector2(o.x, o.z), Vector2.ZERO).grow(1.0)
		var have: Rect2 = _fell_partial.get(cc, Rect2())
		_fell_partial[cc] = spot if have.size == Vector2.ZERO else have.merge(spot)


## A pin hole over one promoted tree, so no later _build_scatter re-emits the standing
## original TreeBreakSystem just replaced.
func add_break_hole(p: Vector3) -> void:
	var hole := {"c": p, "r2": 0.36}
	_veg_holes.append(hole)
	_file_veg_hole(hole)


## Re-scatter one chunk so fresh _fell_registry entries become live cover candidates.
func rebuild_chunk(chunk_coord: Vector2i) -> void:
	if _terrain_manager == null or not _chunk_terrain.has(chunk_coord):
		return
	var hm: Object = _terrain_manager.heightmap
	if hm == null:
		return
	var cs: float = _terrain_manager.chunk_size
	var partial: Rect2 = _fell_partial.get(chunk_coord, Rect2())
	_fell_partial.erase(chunk_coord)
	if partial.size != Vector2.ZERO and _tree_cover != null and _tree_cover.has_chunk(chunk_coord):
		_rematerialize(chunk_coord, hm, cs, partial)
		return
	clear_chunk_visuals(chunk_coord)
	_rematerialize(chunk_coord, hm, cs)


## ONE place that decides how a chunk's vegetation is built. Called by generate_for_chunk()
## and by clear_area() -- never duplicate this branch.
func _rematerialize(chunk_coord: Vector2i, heightmap: Object, chunk_size: float,
		partial: Rect2 = Rect2()) -> void:
	if canopy_source == CanopySource.TREE_COVER and _tree_cover != null and _chunk_terrain.has(chunk_coord):
		# Individual-species near-solid+collider / far-card LOD from the terrain grid.
		StallLedger.begin("veg.build_scatter")
		var scatter: Array = _build_scatter(chunk_coord, heightmap, chunk_size, partial)
		StallLedger.end()
		# THE LOCAL PATH (2026-09-11). A crater re-seats the plants on the moved ground and a
		# settled log adds two entries; neither is a reason to free and re-instance every
		# bucket in a 256 m chunk. When the tree layer already draws this chunk and the caller
		# named the ground that changed, it is handed the new list and diffs it by entry uid.
		var cells: Dictionary = (_scatter_cache.get(chunk_coord, {}) as Dictionary).get("cells", {})
		if partial.size != Vector2.ZERO and _tree_cover.has_chunk(chunk_coord):
			StallLedger.begin("veg.tree_cover_partial")
			_tree_cover.update_chunk(chunk_coord, scatter, partial, cells)
			StallLedger.end()
			return
		StallLedger.begin("veg.tree_cover_mmi")
		# THE CANOPY IS ALWAYS REBUILT, and an in-place re-seat was BUILT, MEASURED AND
		# REMOVED rather than left in as an unexercised path. The re-seat needs the plant
		# LIST unchanged, which a pure height edit guarantees - but a crater is never a pure
		# height edit: the same blast fells trees, TreeBreakSystem drops those entries, and a
		# changed list is exactly the case the re-seat has to refuse. Measured with a success
		# counter (not a span, which counts attempts): 0 successes in the crater bench.
		clear_chunk_visuals(chunk_coord)
		_tree_cover.generate_for_chunk(chunk_coord, scatter, cells)
		StallLedger.end()
	elif _patch_layer != null and _patch_layer.enabled and _chunk_terrain.has(chunk_coord):
		clear_chunk_visuals(chunk_coord)
		# Authored patches bring their own trees - the lone-tree layer would double
		# the canopy and blow the tri budget, so it stays off.
		_patch_layer.generate_for_chunk(
			chunk_coord, _chunk_terrain[chunk_coord],
			_bundles_per_chunk, bundle_meters, heightmap, chunk_size)
	else:
		clear_chunk_visuals(chunk_coord)
		_materialize_vegetation(chunk_coord, heightmap)


## Derive a per-species {name, xf} scatter from this chunk's terrain grid, deterministically
## from mission_seed (ADR-010). TYPE_PROPS governs how many; TYPE_SPECIES which. Fed to
## TreeCoverLayer.generate_for_chunk when the canopy is TREE_COVER.
## `partial`: the ground that moved. On a cache hit only the plants standing in it are
## re-seated; the rest of the chunk did not move and is not touched. Without it the hit path
## re-sampled the heightmap for every plant in the chunk on every crater - veg.scatter_hit
## 417 ms over a siege, ~9,700 samples a round for a 20 m hole.
func _build_scatter(chunk_coord: Vector2i, heightmap: Object, chunk_size: float,
		partial: Rect2 = Rect2()) -> Array:
	var scatter: Array = []
	if not _chunk_terrain.has(chunk_coord):
		return scatter
	var hit: Dictionary = _scatter_cache.get(chunk_coord, {}) as Dictionary
	if not hit.is_empty() and int(hit["epoch"]) >= int(_scatter_dirty.get(chunk_coord, 0)):
		# Same answer, new ground: re-seat every plant on the current heightmap and hand back
		# the cached list. This is the crater path - the shell moved the dirt, not the trees.
		StallLedger.begin("veg.scatter_hit")
		var cached: Array = hit["scatter"]
		if partial.size != Vector2.ZERO and hit.has("cells"):
			var grown: Rect2 = partial.grow(2.0)
			var cells: Dictionary = hit["cells"]
			var c0 := Vector2i(floori(grown.position.x / CACHE_CELL_M), floori(grown.position.y / CACHE_CELL_M))
			var c1 := Vector2i(floori(grown.end.x / CACHE_CELL_M), floori(grown.end.y / CACHE_CELL_M))
			for cx in range(c0.x, c1.x + 1):
				for cz in range(c0.y, c1.y + 1):
					var ck := Vector2i(cx, cz)
					if not cells.has(ck):
						continue
					for i: int in (cells[ck] as PackedInt32Array):
						var e: Dictionary = cached[i]
						if bool(e.get("dead", false)):
							continue
						var xf: Transform3D = e["xf"]
						if not grown.has_point(Vector2(xf.origin.x, xf.origin.z)):
							continue
						xf.origin.y = heightmap.sample_world(xf.origin.x, xf.origin.z)
						e["xf"] = xf
		else:
			for e: Dictionary in cached:
				if bool(e.get("dead", false)):
					continue
				var xf: Transform3D = e["xf"]
				xf.origin.y = heightmap.sample_world(xf.origin.x, xf.origin.z)
				e["xf"] = xf
		StallLedger.end()
		return cached
	StallLedger.begin("veg.scatter_miss")
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
			if ttype == TerrainType.RICE_PADDY:
				if _bundle_fully_holed(origin_x + (bx + 0.5) * bundle_meters,
						origin_z + (bz + 0.5) * bundle_meters):
					continue
				_plant_paddy_rows(scatter,
					origin_x + bx * bundle_meters, origin_z + bz * bundle_meters, heightmap)
				continue
			var props: Array = TYPE_PROPS[ttype]
			var chance: float = props[0]
			var cmin: int = int(props[1])
			var cmax: int = int(props[2])
			var bush_bias: bool = false
			var bcx: float = origin_x + (bx + 0.5) * bundle_meters
			var bcz: float = origin_z + (bz + 0.5) * bundle_meters
			for c: Dictionary in _density_centers:
				var cp: Vector3 = c["pos"]
				var rad: float = float(c.get("radius", 0.0))
				if Vector2(bcx - cp.x, bcz - cp.z).length() <= rad:
					chance = maxf(chance, float(c.get("chance_floor", chance)))
					cmin += int(c.get("count_boost", 0))
					cmax += int(c.get("count_boost", 0))
					if bool(c.get("bush_bias", false)):
						bush_bias = true
			if chance <= 0.0 or rng.randf() > chance:
				continue
			var count: int = rng.randi_range(cmin, cmax)
			for _i in count:
				var wx: float = origin_x + (bx + rng.randf()) * bundle_meters
				var wz: float = origin_z + (bz + rng.randf()) * bundle_meters
				var nm: String = _pick_species(pool, bush_bias, rng)
				var h: float = heightmap.sample_world(wx, wz)
				var plant_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2))
				# Blast footprints remove individual plants, not whole bundles.
				if _in_veg_hole(wx, wz):
					continue
				scatter.append({"name": nm, "xf": Transform3D(plant_basis, Vector3(wx, h, wz))})
	# Logs dropped earlier this mission re-enter as ordinary candidates, so the ring
	# bodies them. Deliberately NOT filtered by _in_veg_hole: the log lies in the crater
	# the blast just made, which is exactly where he needs the cover.
	for f: Dictionary in _fell_registry:
		if f["chunk"] == chunk_coord:
			var e: Dictionary = {"name": String(f["name"]), "xf": f["xf"] as Transform3D, "fell": true}
			# Snags and lying logs carry their own collider size; without these they would
			# inherit the standing tree's full-height post.
			if f.has("trunk_r"):
				e["trunk_r"] = f["trunk_r"]
				e["trunk_h"] = f.get("trunk_h", 1.0)
			scatter.append(e)
	# A STABLE IDENTITY per plant, so a later partial update can diff the list it is handed
	# against the list the tree layer drew without comparing dictionaries by value.
	for e: Dictionary in scatter:
		if not e.has("uid"):
			e["uid"] = _next_uid
			_next_uid += 1
	_scatter_cache[chunk_coord] = {"epoch": _scatter_epoch, "scatter": scatter,
		"cells": _index_cells(scatter)}
	StallLedger.end()
	return scatter


## THE CACHE'S OWN SPATIAL INDEX: scatter indices bucketed by CACHE_CELL_M so a blast footprint
## can be applied to the plants it can reach instead of to the whole chunk. Built as plain
## Arrays and packed at the end - a PackedInt32Array is a VALUE in GDScript and appending
## through `as` appends to a copy (the trap tree_cover_layer.gd already paid for).
const CACHE_CELL_M: float = 32.0


func _index_cells(scatter: Array) -> Dictionary:
	var lists: Dictionary = {}
	for i: int in scatter.size():
		var o: Vector3 = ((scatter[i] as Dictionary)["xf"] as Transform3D).origin
		var ck := Vector2i(floori(o.x / CACHE_CELL_M), floori(o.z / CACHE_CELL_M))
		if not lists.has(ck):
			lists[ck] = []
		(lists[ck] as Array).append(i)
	var cells: Dictionary = {}
	for ck_any in lists.keys():
		cells[ck_any] = PackedInt32Array(lists[ck_any] as Array)
	return cells


static func _index_add(cells: Dictionary, i: int, o: Vector3) -> void:
	var ck := Vector2i(floori(o.x / CACHE_CELL_M), floori(o.z / CACHE_CELL_M))
	var packed: PackedInt32Array = cells.get(ck, PackedInt32Array())
	packed.append(i)
	cells[ck] = packed


## Lay this bundle's share of its field's row lattice. The lattice is anchored to the 48 m
## FIELD tile, not to the bundle, so rows run unbroken across every bundle and chunk seam; a
## lattice point is owned by exactly one bundle (half-open containment), so no clump is planted
## twice at a seam and none is dropped.
##
## It draws NOTHING from the chunk's shared RNG - jitter, yaw and scale come from a position
## hash. Planting a paddy therefore cannot shift one tree anywhere else in the world, and every
## jungle that existed before rice did still generates identically.
func _plant_paddy_rows(scatter: Array, bx0: float, bz0: float, heightmap: Object) -> void:
	var tile_x: int = floori(bx0 / PADDY_FIELD_TILE)
	var tile_z: int = floori(bz0 / PADDY_FIELD_TILE)
	var ang: float = floor(_hash01(tile_x, tile_z, mission_seed) * 8.0) * (PI / 8.0)
	# ONE crop per field, not per plant: a field is sown in one go, and it halves the MultiMesh
	# nodes (TreeCoverLayer builds one per species x 64 m bucket).
	var nm: String = "rice_a" if _hash01(tile_x, tile_z, mission_seed + 7) < 0.5 else "rice_b"
	var ax: float = float(tile_x) * PADDY_FIELD_TILE
	var az: float = float(tile_z) * PADDY_FIELD_TILE
	var ca: float = cos(ang)
	var sa: float = sin(ang)
	var bx1: float = bx0 + bundle_meters
	var bz1: float = bz0 + bundle_meters

	# The bundle's four corners in field space bound the lattice indices that can reach it.
	var u_lo: float = INF
	var u_hi: float = -INF
	var v_lo: float = INF
	var v_hi: float = -INF
	for cx: float in [bx0, bx1]:
		for cz: float in [bz0, bz1]:
			var dx: float = cx - ax
			var dz: float = cz - az
			var u: float = dx * ca + dz * sa
			var v: float = -dx * sa + dz * ca
			u_lo = minf(u_lo, u); u_hi = maxf(u_hi, u)
			v_lo = minf(v_lo, v); v_hi = maxf(v_hi, v)

	var hydro: Object = _terrain_manager.hydrology if _terrain_manager != null else null
	var hm_size: int = int(heightmap.size)
	var hm_cell: float = float(heightmap.cell_size)

	for j in range(floori(v_lo / PADDY_ROW_PITCH), floori(v_hi / PADDY_ROW_PITCH) + 1):
		var v: float = float(j) * PADDY_ROW_PITCH
		for i in range(floori(u_lo / PADDY_HILL_PITCH), floori(u_hi / PADDY_HILL_PITCH) + 1):
			var u: float = float(i) * PADDY_HILL_PITCH
			var wx: float = ax + u * ca - v * sa
			var wz: float = az + u * sa + v * ca
			if wx < bx0 or wx >= bx1 or wz < bz0 or wz >= bz1:
				continue
			var ja: float = (_hash01(i, j, mission_seed + 11) - 0.5) * 2.0 * PADDY_JITTER_ALONG
			var jc: float = (_hash01(i, j, mission_seed + 13) - 0.5) * 2.0 * PADDY_JITTER_ACROSS
			wx += ja * ca - jc * sa
			wz += ja * sa + jc * ca
			if _in_veg_hole(wx, wz):
				continue
			var y: float = heightmap.sample_world(wx, wz)
			var surf: float = _standing_water_y(hydro, hm_size, hm_cell, wx, wz)
			if surf != -INF:
				if surf - y > PADDY_MAX_WADE:
					continue  # a channel or a pond, not field - leave the water open
				y = maxf(y, surf - PADDY_SUBMERGE)
			var rot: float = _hash01(i, j, mission_seed + 17) * TAU
			var sc: float = 0.85 + 0.30 * _hash01(i, j, mission_seed + 19)
			var basis := Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc)
			scatter.append({"name": nm, "xf": Transform3D(basis, Vector3(wx, y, wz))})


## Water here is real geometry fed by ONE hydrology solve, so the paddy asks that solve
## directly instead of the WaterSystem: the water bodies are built after the first chunks
## load (game_world.gd _on_terrain_ready), while terrain_manager.hydrology exists before
## them. Returns -INF where there is no standing water.
func _standing_water_y(hydro: Object, hm_size: int, hm_cell: float, wx: float, wz: float) -> float:
	if hydro == null or hm_size <= 0 or hm_cell <= 0.0:
		return -INF
	var cx: int = floori(wx / hm_cell)
	var cz: int = floori(wz / hm_cell)
	if cx < 0 or cx >= hm_size or cz < 0 or cz >= hm_size:
		return -INF
	var idx: int = cz * hm_size + cx
	var types: PackedByteArray = hydro.water_type_full
	var surfaces: PackedFloat32Array = hydro.water_surface_full
	if idx >= types.size() or idx >= surfaces.size():
		return -INF
	if types[idx] == 0:
		return -INF
	return surfaces[idx]


## Deterministic 0..1 from three ints. No RNG object and no allocation, which is what lets the
## paddy lattice stay outside the chunk's RNG stream.
static func _hash01(a: int, b: int, c: int) -> float:
	var n: int = a * 374761393 + b * 668265263 + c * 1274126177
	n = (n ^ (n >> 13)) * 1103515245
	return float((n >> 8) & 0xFFFFFF) / 16777216.0


## Weighted pick from the cell's classified pool. Under bush_bias (hamlet brush) a
## non-bush first draw gets ONE re-roll toward a bush, so villages read thick without
## planting species the classification does not carry (keeps the one-classifier contract).
func _pick_species(pool: Array, bush_bias: bool, rng: RandomNumberGenerator) -> String:
	var nm: String = String(pool[rng.randi_range(0, pool.size() - 1)])
	if bush_bias and not nm.begins_with("bush_"):
		var alt: String = String(pool[rng.randi_range(0, pool.size() - 1)])
		if alt.begins_with("bush_"):
			nm = alt
	return nm


## IMPROVE-in-place hook (ADR-028): thicken veg around given world points (the player
## insertion ring, each hamlet) AFTER the mission plan is known, still behind the loading
## screen. Re-scatters only the TREE_COVER chunks the centers touch. Adds no placement path
## and no new seed: the same _build_scatter runs with the same per-chunk seed, now reading
## _density_centers, so the world stays deterministic for a given (seed, centers).
func set_density_centers(centers: Array) -> void:
	_density_centers = centers
	_scatter_epoch += 1
	_scatter_cache.clear()
	if canopy_source != CanopySource.TREE_COVER or _terrain_manager == null:
		return
	var hm: Object = _terrain_manager.heightmap
	if hm == null:
		return
	var cs: float = _terrain_manager.chunk_size
	var affected: Dictionary = {}
	for c: Dictionary in centers:
		var cp: Vector3 = c["pos"]
		var rad: float = float(c.get("radius", 0.0))
		var minx: int = int(floor((cp.x - rad) / cs))
		var maxx: int = int(floor((cp.x + rad) / cs))
		var minz: int = int(floor((cp.z - rad) / cs))
		var maxz: int = int(floor((cp.z + rad) / cs))
		for cz in range(minz, maxz + 1):
			for cx in range(minx, maxx + 1):
				affected[Vector2i(cx, cz)] = true
	for coord: Vector2i in affected:
		if _chunk_terrain.has(coord):
			generate_for_chunk(coord, hm, cs)


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


## Clear visuals only - keeps cache for re-materialization
func clear_chunk_visuals(chunk_coord: Vector2i) -> void:
	if _chunk_instances.has(chunk_coord):
		var instance: MultiMeshInstance3D = _chunk_instances[chunk_coord]
		if is_instance_valid(instance):
			instance.queue_free()
		_chunk_instances.erase(chunk_coord)
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
	_chunk_instances.clear()
	_chunk_terrain.clear()
	_chunk_placements.clear()
	_veg_holes.clear()
	_veg_hole_buckets.clear()
	_fell_registry.clear()
	_scatter_cache.clear()
	_scatter_dirty.clear()
	_scatter_epoch += 1


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


