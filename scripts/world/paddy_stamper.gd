extends RefCounted
## Stamps rice paddy polygons from the GameplayGrid's RICE_PADDY cells, scatters
## rice_a/b props inside each paddy, and groups paddies into village anchors.
## Terrain-first: runs before any village or firebase is placed.

const PaddyFieldScript := preload("res://scripts/world/paddy_field.gd")

const RICE_PADDY: int = 1  # GameplayGrid.TerrainType.RICE_PADDY

# Cluster parameters — tune via smoke test until ≥4 viable village anchors.
const MIN_PADDY_AREA_CELLS: int = 2
const PROP_DENSITY: float = 0.8             # rice plants per cell, on average
const VILLAGE_GROUPING_RADIUS_M: float = 140.0  # paddies within this band → one village (was 220; tighter = more villages)
const VILLAGE_TARGET_PADDY_MAX: int = 2     # 1-2 paddies per village = 8-10 villages from a normal AO
const ANCHOR_OFFSET_MIN_M: float = 8.0      # hut center sits on the bund, not in the water
const ANCHOR_OFFSET_MAX_M: float = 15.0
const HARD_FLOOR_VILLAGES: int = 4          # one village per quadrant — mission_generator.gd:459-462 builds exactly four

const RICE_A := "res://assets/world/vegetation/rice_a.glb"
const RICE_B := "res://assets/world/vegetation/rice_b.glb"


## Returns: {
##   paddies: Array[PaddyField],         # every stamped paddy, in BFS order
##   village_anchors: Array[Dictionary], # each = { center: Vector3, working_points: Array[NodePath], paddies: Array[PaddyField] }
##   paddy_centroids: Array[Vector3],    # for firebase extra_reject
## }
## Asserts the hard floor; raises if fewer than HARD_FLOOR_VILLAGES anchors were produced.
static func stamp(
	mission_seed: int,
	grid: GameplayGrid,
	terrain,  # TerrainManager
	parent: Node,
	village_floor: int = HARD_FLOOR_VILLAGES,  # patrol law; small demo slices pass 0
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed + 1009  # separate stream from mission-type roll

	# Grid geometry comes from the LIVE grid, never a const copy: the shipped
	# const pair (256 / 12.0m) silently placed every centroid at 2.4x its true
	# world position on the 1280m map (cells are actually 5.0m).
	var gsize: int = grid.grid_size
	var paddy_fields: Array[PaddyFieldScript] = []
	var paddy_centroids: Array[Vector3] = []
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(gsize * gsize)
	for i in range(visited.size()):
		visited[i] = 0

	for gz in gsize:
		for gx in gsize:
			var idx: int = gz * gsize + gx
			if visited[idx] == 1:
				continue
			if grid.get_terrain_type_at(gx, gz) != RICE_PADDY:
				continue
			var cluster: PackedInt32Array = _flood_fill(gx, gz, grid, visited)
			if cluster.size() < MIN_PADDY_AREA_CELLS:
				continue
			var pf: PaddyFieldScript = _build_paddy_field(
				cluster, grid, terrain, parent, rng
			)
			paddy_fields.append(pf)
			paddy_centroids.append(pf.world_position)

	# Group paddies into village anchors (2-3 paddies within VILLAGE_GROUPING_RADIUS_M).
	var anchors: Array[Dictionary] = _group_into_village_anchors(
		paddy_fields, paddy_centroids, rng
	)
	if anchors.size() < village_floor:
		push_error(
			"PaddyStamper: only %d village anchors produced (floor=%d). " % [anchors.size(), village_floor]
			+ "AO is malformed — relax MIN_PADDY_AREA_CELLS, lower VILLAGE_GROUPING_RADIUS_M, "
			+ "or expand the grid's RICE_PADDY classification."
		)
	return {
		"paddies": paddy_fields,
		"village_anchors": anchors,
		"paddy_centroids": paddy_centroids,
	}


static func _flood_fill(
	start_gx: int, start_gz: int, grid: GameplayGrid, visited: PackedByteArray
) -> PackedInt32Array:
	# Iterative 4-conn BFS; returns flat indices of all RICE_PADDY cells in the cluster.
	var gsize: int = grid.grid_size
	var cluster: PackedInt32Array = PackedInt32Array()
	var queue: PackedInt32Array = PackedInt32Array()
	var start_idx: int = start_gz * gsize + start_gx
	queue.append(start_idx)
	visited[start_idx] = 1
	while not queue.is_empty():
		var cur: int = queue[0]
		queue.remove_at(0)
		cluster.append(cur)
		var gx: int = cur % gsize
		@warning_ignore("integer_division")
		var gz: int = cur / gsize
		# 4-neighbors: +x, -x, +z, -z
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = gx + off.x
			var nz: int = gz + off.y
			if nx < 0 or nx >= gsize or nz < 0 or nz >= gsize:
				continue
			var n: int = nz * gsize + nx
			if visited[n] == 1:
				continue
			if grid.get_terrain_type_at(nx, nz) != RICE_PADDY:
				continue
			visited[n] = 1
			queue.append(n)
	return cluster


static func _build_paddy_field(
	cluster: PackedInt32Array, grid: GameplayGrid, terrain, parent: Node, rng: RandomNumberGenerator
) -> PaddyFieldScript:
	# Centroid + bounds in cell coords; world Y from terrain height.
	var gsize: int = grid.grid_size
	var cell_m: float = grid.cell_size_meters
	var sum_x: float = 0.0
	var sum_z: float = 0.0
	var min_x: int = gsize
	var max_x: int = 0
	var min_z: int = gsize
	var max_z: int = 0
	for idx in cluster:
		var gx: int = idx % gsize
		@warning_ignore("integer_division")
		var gz: int = idx / gsize
		sum_x += gx
		sum_z += gz
		if gx < min_x: min_x = gx
		if gx > max_x: max_x = gx
		if gz < min_z: min_z = gz
		if gz > max_z: max_z = gz
	var count: int = cluster.size()
	var cgx: float = sum_x / float(count)
	var cgz: float = sum_z / float(count)
	var world_x: float = (cgx + 0.5) * cell_m
	var world_z: float = (cgz + 0.5) * cell_m
	var world_y: float = terrain.get_height_at(Vector3(world_x, 0.0, world_z))

	var pf: PaddyFieldScript = PaddyFieldScript.new()
	pf.paddy_id = StringName("paddy_%d" % [rng.randi()])
	pf.world_position = Vector3(world_x, world_y, world_z)
	pf.cell_count = count
	pf.bounds_min = Vector2i(min_x, min_z)
	pf.bounds_max = Vector2i(max_x, max_z)

	# working_point Marker3D at the centroid, on the terrain.
	var wp := Marker3D.new()
	wp.name = "working_point_%s" % pf.paddy_id
	wp.position = pf.world_position
	parent.add_child(wp)
	pf.working_point = parent.get_path_to(wp)

	_scatter_rice_props(pf, parent, rng, cell_m)
	return pf


static func _scatter_rice_props(
	pf: PaddyFieldScript, parent: Node, rng: RandomNumberGenerator, cell_m: float
) -> void:
	# Rice is visual only — MeshInstance3D, no StaticBody3D (programmer-council rule).
	var plant_count: int = maxi(1, int(round(float(pf.cell_count) * PROP_DENSITY)))
	for i in range(plant_count):
		var gx: int = rng.randi_range(pf.bounds_min.x, pf.bounds_max.x)
		var gz: int = rng.randi_range(pf.bounds_min.y, pf.bounds_max.y)
		var world_x: float = (float(gx) + rng.randf()) * cell_m
		var world_z: float = (float(gz) + rng.randf()) * cell_m
		var world_y: float = pf.world_position.y
		var model_path: String = RICE_A if rng.randf() < 0.5 else RICE_B
		var scene: PackedScene = load(model_path)
		if scene == null:
			continue
		var mi: MeshInstance3D = scene.instantiate() as MeshInstance3D
		if mi == null:
			continue
		mi.position = Vector3(world_x, world_y, world_z)
		mi.rotation.y = rng.randf() * TAU
		parent.add_child(mi)


static func _group_into_village_anchors(
	paddies: Array, centroids: Array[Vector3], rng: RandomNumberGenerator
) -> Array[Dictionary]:
	# Greedy: for each unclaimed paddy, take it + its unclaimed neighbors within
	# VILLAGE_GROUPING_RADIUS_M until we have 2-3 paddies or run out of neighbors.
	# Each anchor gets a center = paddy-cluster centroid + 8-15m offset toward the
	# densest neighbor — the dry bund, not the water.
	var claimed: PackedByteArray = PackedByteArray()
	claimed.resize(paddies.size())
	for i in range(claimed.size()):
		claimed[i] = 0

	var anchors: Array[Dictionary] = []
	for seed_i in range(paddies.size()):
		if claimed[seed_i] == 1:
			continue
		var group_indices: Array[int] = [seed_i]
		claimed[seed_i] = 1
		# Pull in neighbors within radius until VILLAGE_TARGET_PADDY_MAX or no more.
		while group_indices.size() < VILLAGE_TARGET_PADDY_MAX:
			var added_any: bool = false
			for j in range(paddies.size()):
				if claimed[j] == 1:
					continue
				if j in group_indices:
					continue
				var closest: float = INF
				for gi in group_indices:
					var d: float = centroids[j].distance_to(centroids[gi])
					if d < closest:
						closest = d
				if closest <= VILLAGE_GROUPING_RADIUS_M:
					group_indices.append(j)
					claimed[j] = 1
					added_any = true
					if group_indices.size() >= VILLAGE_TARGET_PADDY_MAX:
						break
			if not added_any:
				break

		var group_working_points: Array[NodePath] = []
		var group_centroid: Vector3 = Vector3.ZERO
		for gi in group_indices:
			group_working_points.append((paddies[gi] as PaddyFieldScript).working_point)
			group_centroid += centroids[gi]
		group_centroid /= float(group_indices.size())

		var anchor_pos: Vector3 = _compute_anchor_offset(group_centroid, group_indices, centroids, rng)
		anchors.append({
			"center": anchor_pos,
			"working_points": group_working_points,
			"paddies": group_indices,
		})
	return anchors


static func _compute_anchor_offset(
	group_centroid: Vector3, group_indices: Array[int], centroids: Array[Vector3], rng: RandomNumberGenerator
) -> Vector3:
	# Direction: from group centroid to the densest paddy edge. With 1 paddy, push
	# toward the centroid's nearest non-paddy neighbor — but in practice 1-paddy
	# groups are unusual (most have 2-3). With 2+ paddies, the densest edge is
	# the direction the cluster *already* extends. Offset magnitude 8-15m.
	var direction: Vector2 = Vector2(0.0, 1.0)
	if group_indices.size() >= 2:
		var max_dist: float = -1.0
		for gi in group_indices:
			var d: float = centroids[gi].distance_to(group_centroid)
			if d > max_dist:
				max_dist = d
				direction = Vector2(
					centroids[gi].x - group_centroid.x,
					centroids[gi].z - group_centroid.z
				).normalized()
	else:
		# Single paddy: nudge in a deterministic direction derived from the seed.
		var a: float = rng.randf() * TAU
		direction = Vector2(cos(a), sin(a))

	var offset: float = rng.randf_range(ANCHOR_OFFSET_MIN_M, ANCHOR_OFFSET_MAX_M)
	return Vector3(
		group_centroid.x + direction.x * offset,
		group_centroid.y,
		group_centroid.z + direction.y * offset,
	)
