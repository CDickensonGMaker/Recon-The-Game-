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

# Bundle size in meters
var bundle_meters: float:
	get: return cell_size * BUNDLE_SIZE

# Terrain type properties: [tree_chance, tree_count_min, tree_count_max]
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
	# Not a scatter species - nothing plants a felled log - but the mesh must be loaded
	# or generate_for_chunk silently drops every entry _fell_registry re-emits.
	seen[FELLED_SPECIES] = true
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

## Holes bucketed by world cell. _in_veg_hole runs per CANDIDATE PLANT on every chunk
## re-scatter, so a linear scan makes every rebuild slower for the rest of the mission -
## the cost that decides whether persistent damage is affordable at all. A hole is filed
## in every cell its bounding square touches, so a lookup reads one cell.
const HOLE_BUCKET_M: float = 32.0
var _veg_hole_buckets: Dictionary = {}


func _hole_cell(wx: float, wz: float) -> Vector2i:
	return Vector2i(floori(wx / HOLE_BUCKET_M), floori(wz / HOLE_BUCKET_M))


func _file_veg_hole(hole: Dictionary) -> void:
	var c: Vector3 = hole["c"]
	var r: float = sqrt(float(hole["r2"]))
	var lo: Vector2i = _hole_cell(c.x - r, c.z - r)
	var hi: Vector2i = _hole_cell(c.x + r, c.z + r)
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			var key := Vector2i(cx, cz)
			if not _veg_hole_buckets.has(key):
				_veg_hole_buckets[key] = []
			(_veg_hole_buckets[key] as Array).append(hole)


func _in_veg_hole(wx: float, wz: float) -> bool:
	var bucket: Array = _veg_hole_buckets.get(_hole_cell(wx, wz), [])
	for hole: Dictionary in bucket:
		var c: Vector3 = hole["c"]
		if (wx - c.x) ** 2 + (wz - c.z) ** 2 < float(hole["r2"]):
			return true
	return false


## Clear vegetation in a circular blast FOOTPRINT: record the hole and rebuild only
## the chunk(s) it overlaps, excluding just the plant instances inside the radius
## (see _build_scatter). The old path set whole 32m bundles to CLEAR, so a 10m blast
## wiped a chunk's worth of trees - "half the trees gone, not a crater". The veg
## terrain grid is untouched, so AI sight is unaffected; this is visual removal.
func clear_area(center: Vector3, radius: float, chunk_size: float, heightmap: Object = null) -> int:
	var min_cx := floori((center.x - radius) / chunk_size)
	var max_cx := floori((center.x + radius) / chunk_size)
	var min_cz := floori((center.z - radius) / chunk_size)
	var max_cz := floori((center.z + radius) / chunk_size)
	# The canopy trees this hole is about to delete, gathered BEFORE the hole is
	# recorded (the hole filters them out of the scatter): they go down VISIBLY.
	var doomed: Array = []
	var doomed_bush: Array = []
	if canopy_source == CanopySource.TREE_COVER and _tree_cover != null and heightmap != null:
		for cx in range(min_cx, max_cx + 1):
			for cz in range(min_cz, max_cz + 1):
				var chunk_coord := Vector2i(cx, cz)
				if not _chunk_terrain.has(chunk_coord):
					continue
				if doomed.size() >= FELL_MAX_PER_BLAST and doomed_bush.size() >= FELL_BUSH_MAX:
					continue
				for e: Dictionary in _build_scatter(chunk_coord, heightmap, chunk_size):
					var p: Vector3 = (e.xf as Transform3D).origin
					if Vector2(p.x - center.x, p.z - center.z).length() > radius:
						continue
					# Bushes take their own budget. Sharing one would let the undergrowth -
					# far more numerous than trees - spend the whole allowance on shrubs
					# while the treeline he is watching stands there untouched.
					if _is_bush_species(String(e.name)):
						if doomed_bush.size() < FELL_BUSH_MAX:
							doomed_bush.append(e)
					elif _is_fell_species(String(e.name)):
						if doomed.size() < FELL_MAX_PER_BLAST:
							doomed.append(e)
		doomed.append_array(doomed_bush)
	var hole := {"c": center, "r2": radius * radius}
	_veg_holes.append(hole)
	_file_veg_hole(hole)

	var rebuilt := 0
	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var chunk_coord := Vector2i(cx, cz)
			if not _chunk_terrain.has(chunk_coord):
				continue
			clear_chunk_visuals(chunk_coord)
			if heightmap:
				_rematerialize(chunk_coord, heightmap, chunk_size)
			rebuilt += 1
	for e: Dictionary in doomed:
		_fell_tree_visual(String(e.name), e.xf as Transform3D, center, chunk_size)
	# The logs just registered are not in the scatter yet - this chunk was rebuilt above,
	# before they existed. Re-scatter once the fall has landed so they become cover then,
	# not at some unrelated later rebuild. This is the VEGETATION MultiMesh rebuild, not
	# the terrain SurfaceTool dig, so it is cheap; the chunks are deduped.
	if not doomed.is_empty() and heightmap != null:
		var touched: Dictionary = {}
		for e: Dictionary in doomed:
			var p: Vector3 = (e.xf as Transform3D).origin
			touched[Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))] = true
		var hm: Object = heightmap
		# A beat AFTER the fall lands, not on the same tick: the tween's finish callback is
		# what writes the resting log into the registry, and this re-scatter must read it.
		get_tree().create_timer(FELL_TIME + 0.15).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			for c: Vector2i in touched.keys():
				if _chunk_terrain.has(c):
					clear_chunk_visuals(c)
					_rematerialize(c, hm, chunk_size), CONNECT_ONE_SHOT)
	return rebuilt


## LIVE-WORLD TREE FELLING (decree 2026-08-04). A felled tree is COVER, not decoration
## (his ruling 2026-08-05): the tween below is only the falling MOTION. The log itself is
## recorded in _fell_registry as DATA and re-emitted by _build_scatter as an ordinary
## `felled_tree` scatter instance, so the pooled 70m ring bodies it on demand like any
## other trunk. Nothing here holds a permanent collider and nothing accumulates nodes.
const FELL_MAX_PER_BLAST := 12
const FELL_BUSH_MAX := 8
const FELL_TIME := 2.0
## Falling VISUALS only (transient, ~FELL_TIME each). Registry entries are not capped by
## count: a FIFO would free the log a man is lying behind because of a blast 200m away,
## which ADR-031 forbids inside the firefight radius.
const FALLEN_VISUAL_MAX := 24
var _fallen_visuals: Array[Node3D] = []

## The species the ring bodies a lying log as. In COVER_TRUNK (0.40m) and on disk as
## felled_tree.glb; added to the load list by _all_species().
const FELLED_SPECIES := "felled_tree"

## SEGMENTED BREAKS (his ruling 2026-08-05). Each species ships _low/_mid/_high parts and
## a manifest of the two joint heights, so a blast breaks the tree WHERE IT HIT instead of
## always at the base: everything above the nearest joint goes over, everything below stays
## up as a snag. State-swap only - the parts are keyed meshes, never RigidBody (ADR-031).
const SEG_MANIFEST := "res://assets/world/vegetation/vegetation_segments_manifest.json"
## A log lying in the grass is crouch cover, not a 3m post.
const LOG_TRUNK_H := 0.9
var _seg_cuts: Dictionary = {}


## Joint heights for a species, or empty if it was never segmented (floor plants).
func _seg_for(nm: String) -> Dictionary:
	if _seg_cuts.is_empty():
		_seg_cuts = {"_loaded": true}
		var f: FileAccess = FileAccess.open(SEG_MANIFEST, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in (parsed as Dictionary).get("species", {}):
					_seg_cuts[k] = (parsed as Dictionary)["species"][k]
	var v: Variant = _seg_cuts.get(nm, {})
	return v as Dictionary if v is Dictionary else {}


## Where the ground actually is under a point. NOT arithmetic off the tree's own origin:
## the blast that felled this tree also craters the terrain under it, and that dig is
## QUEUED - so a resting height computed at detonation floats over the hole that arrives
## a few frames later. Probed at touchdown, against the real floor.
func _probe_ground(p: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 60.0)
	q.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if hit.has("position") else p.y

## Every log dropped this mission: {name, xf (final, lying), chunk}. Survives chunk
## rebuilds because _build_scatter re-emits it; cleared per-mission in clear_all().
var _fell_registry: Array = []


## Bushes break too (his ruling 2026-08-05: "trees and bushes for sure"), but a bush loses
## its top and leaves a stub - it never becomes a log you can hide behind.
func _is_bush_species(nm: String) -> bool:
	return nm.begins_with("bush_") or nm.begins_with("lp_bush_")


## Only trunked cover-givers fall as logs; grass and ferns just vanish in the blast.
func _is_fell_species(nm: String) -> bool:
	return nm.begins_with("broadleaf") or nm.begins_with("banana") \
		or nm.begins_with("bamboo") or nm.begins_with("jungle_palm") \
		or nm.begins_with("palm_")


func _fell_tree_visual(nm: String, xf: Transform3D, blast: Vector3, chunk_size: float) -> void:
	if _tree_cover == null:
		return
	# WHICH JOINT. The blast height above this tree's own base picks the break: above the
	# canopy joint only the crown comes off; above the stem joint the whole top goes; below
	# both, the tree is cut off at the ankles and falls entire, as it always did.
	var cuts: Dictionary = _seg_for(nm)
	var bh: float = blast.y - xf.origin.y
	var lo: float = float(cuts.get("cut_low_m", 0.0))
	var hi: float = float(cuts.get("cut_high_m", 0.0))
	var cut: float = 0.0
	var standing: Array[String] = []
	var falling: Array[String] = []
	if hi > 0.0 and bh >= hi:
		cut = hi
		standing = [nm + "_low", nm + "_mid"]
		falling = [nm + "_high"]
	elif lo > 0.0 and bh >= lo:
		cut = lo
		standing = [nm + "_low"]
		falling = [nm + "_mid", nm + "_high"]
	if not falling.is_empty():
		_break_tree_at(nm, xf, blast, chunk_size, cut, standing, falling)
		return

	var mesh: Mesh = _tree_cover.solid_mesh_for(nm)
	if mesh == null:
		return
	var root := Node3D.new()
	add_child(root)
	root.global_transform = Transform3D(Basis.IDENTITY, xf.origin)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(xf.basis, Vector3.ZERO)
	root.add_child(mi)
	var away: Vector3 = xf.origin - blast
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(1, 0, 0)
	var axis: Vector3 = away.normalized().cross(Vector3.UP).normalized()
	var hinged := Basis(axis, PI * 0.47)
	var chunk := Vector2i(floori(xf.origin.x / chunk_size), floori(xf.origin.z / chunk_size))
	# Recorded at its RESTING transform up front, not when the tween lands: the entry is
	# what makes the log cover, and a strike that kills the node mid-fall must not lose it.
	_fell_registry.append({
		"name": FELLED_SPECIES,
		"xf": Transform3D(hinged * xf.basis, xf.origin),
		"chunk": chunk,
	})
	root.set_meta("fell_chunk", chunk)
	var tw := root.create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(root):
			root.basis = Basis(axis, a),
		0.0, PI * 0.47, FELL_TIME)
	_fallen_visuals.append(root)
	while _fallen_visuals.size() > FALLEN_VISUAL_MAX:
		var old: Variant = _fallen_visuals.pop_front()
		if is_instance_valid(old):
			(old as Node3D).queue_free()


## A tree broken at height: the part below the joint stays up as a snag, the part above
## hinges over and lies where it lands. Both halves end as _fell_registry DATA, so the
## pooled ring bodies them on demand and a chunk rebuild cannot forget them.
func _break_tree_at(nm: String, xf: Transform3D, blast: Vector3, chunk_size: float,
		cut: float, standing: Array[String], falling: Array[String]) -> void:
	_tree_cover.load_species(standing + falling)   # idempotent; segments load on first break
	var chunk := Vector2i(floori(xf.origin.x / chunk_size), floori(xf.origin.z / chunk_size))
	# ZERO for anything not in COVER_TRUNK. Bushes are CONCEALMENT - they cut sight, never
	# stop a round - so a broken bush must not leave a solid stub behind.
	var radius: float = float(TreeCoverLayer.COVER_TRUNK.get(nm, 0.0))
	# Manifest cuts are UNSCALED object space; _build_scatter plants every instance at a
	# random 0.85-1.2. Without this a big tree snaps below its real joint and a small one
	# above it, and the snag collider is the wrong height for the stump you can see.
	var s: float = xf.basis.get_scale().y
	var cut_w: float = cut * s
	var up_local: Vector3 = xf.basis * Vector3(0.0, cut, 0.0)

	# THE SNAG. Only the first part carries the collider - one shortened post for the whole
	# standing stump, not one per mesh, and cut high so you cannot shoot through what is
	# still solid to head height.
	for i in standing.size():
		var e: Dictionary = {"name": standing[i], "xf": xf, "chunk": chunk}
		if i == 0 and radius > 0.0:
			e["trunk_r"] = radius * s
			e["trunk_h"] = cut_w
		_fell_registry.append(e)

	# THE FALLING TOP. Hinged away from the blast on the same tween the whole-tree path
	# uses, then resolved against the real floor at touchdown.
	var away: Vector3 = xf.origin - blast
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(1, 0, 0)
	var axis: Vector3 = away.normalized().cross(Vector3.UP).normalized()
	var pivot: Vector3 = xf.origin + up_local
	var root := Node3D.new()
	add_child(root)
	root.global_transform = Transform3D(Basis.IDENTITY, pivot)
	root.set_meta("fell_chunk", chunk)
	for part: String in falling:
		var m: Mesh = _tree_cover.solid_mesh_for(part)
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		# Every part was cut IN PLACE, so it carries the whole tree's object space. Seating
		# it at -up_local puts the geometry back exactly where it stood before the break.
		mi.transform = Transform3D(xf.basis, -up_local)
		root.add_child(mi)
	_fallen_visuals.append(root)

	var tw := root.create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(root):
			root.basis = Basis(axis, a),
		0.0, PI * 0.47, FELL_TIME)
	tw.finished.connect(func() -> void:
		if not is_instance_valid(self):
			return
		# It came to rest a little way out from the stump, in the direction it fell, and
		# its height is PROBED - the crater from the same blast may have arrived by now.
		var rest: Vector3 = pivot + away.normalized() * (cut_w * 0.5)
		rest.y = _probe_ground(rest)
		var lying := Transform3D(Basis(axis, PI * 0.47) * xf.basis, rest)
		for i in falling.size():
			var e: Dictionary = {"name": falling[i], "xf": lying, "chunk": chunk}
			if i == 0 and radius > 0.0:   # one log collider for the fallen top, not one per part
				e["trunk_r"] = radius * s
				e["trunk_h"] = LOG_TRUNK_H
			_fell_registry.append(e)
		if is_instance_valid(root):
			root.queue_free()
		_fallen_visuals.erase(root), CONNECT_ONE_SHOT)


## THE HANDOFF. Once this chunk's scatter has re-emitted its logs from _fell_registry, the
## transient falling visual is a duplicate standing in the same place - free it. Called at
## the top of _rematerialize so the swap happens in one frame, never leaving a gap.
func _retire_fallen_visuals(chunk_coord: Vector2i) -> void:
	var keep: Array[Node3D] = []
	for f: Node3D in _fallen_visuals:
		if not is_instance_valid(f):
			continue
		if f.get_meta("fell_chunk", Vector2i(0, 0)) == chunk_coord:
			f.queue_free()
		else:
			keep.append(f)
	_fallen_visuals = keep


## ONE place that decides how a chunk's vegetation is built. Called by generate_for_chunk()
## and by clear_area() -- never duplicate this branch.
func _rematerialize(chunk_coord: Vector2i, heightmap: Object, chunk_size: float) -> void:
	_retire_fallen_visuals(chunk_coord)
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
			var e: Dictionary = {"name": String(f["name"]), "xf": f["xf"] as Transform3D}
			# Snags and lying logs carry their own collider size; without these they would
			# inherit the standing tree's full-height post.
			if f.has("trunk_r"):
				e["trunk_r"] = f["trunk_r"]
				e["trunk_h"] = f.get("trunk_h", 1.0)
			scatter.append(e)
	return scatter


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
	for f in _fallen_visuals:
		if is_instance_valid(f):
			f.queue_free()
	_fallen_visuals.clear()
	for instance: MultiMeshInstance3D in _chunk_instances.values():
		if is_instance_valid(instance):
			instance.queue_free()
	_chunk_instances.clear()
	_chunk_terrain.clear()
	_chunk_placements.clear()
	_veg_holes.clear()
	_veg_hole_buckets.clear()
	_fell_registry.clear()


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


