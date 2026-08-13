## road_network.gd - THE ONE ROAD AUTHORITY.
##
## A road is DERIVED FROM THE WORLD, NEVER AN INPUT TO IT. That single rule is what
## keeps this from becoming the fifteenth parallel world-build system. RoadNetwork
## READS the finished GameplayGrid (which already encodes terrain type, water, slope)
## and routes over it. It writes nothing back into terrain height, terrain_type, or
## hydrology. Everything downstream - convoys, the ambush planner, the topo sheet -
## asks THIS object, and there is no second place to ask.
##
## It is also routed AFTER every site is stamped, so set_blockers() can be given the
## real buildings. Routing it in the plan pass routes it against village CENTRES and
## puts the road through the huts.
##
## Consequences of that rule, all deliberate:
##   - NO terrain height edits. Roads are SEATED on the ground, never graded into it.
##     A graded roadbed crossing a carved river channel can dam it, and the channel
##     was just fixed to 100% wet. We do not go near it.
##   - NO TerrainType.ROAD. The enum has two hard blockers: TerrainZoning.configure()
##     runs at world-build step 2, but the sites a road connects do not exist until
##     step 7 - the mask would be empty at classify time - and a road member in
##     GameplayGrid's enum alone fails tests/test_one_classifier.gd against
##     VegetationManager's parallel 6-member enum.
##   - Roads terminate at FORDS, never bridges. A bridge is a chokepoint with no
##     alternative crossing, which is a rail (Pillar 3).
##
## The only thing a road writes to the world is VEGETATION: the corridor is thinned
## via VegetationManager.clear_area(), which edits vegetation bundles and NOT height.
## That is what makes a road legible on foot at PSX fidelity - a road reads as a
## corridor of open sky, not as a texture - and it lowers instance counts rather
## than raising them.
class_name RoadNetwork
extends RefCounted

## Half-width of the cleared corridor, in meters. A 1968 laterite provincial road
## plus its shoulder cut.
const ROAD_HALF_WIDTH_M: float = 5.0
## Spacing of seated polyline points along a route, in meters.
const POINT_SPACING_M: float = 10.0

## Cost multipliers layered on top of GameplayGrid.MOVEMENT_COSTS during routing.
## Water is LARGE BUT FINITE: an engineer would ford a creek rather than detour a
## kilometre, but will route around a river if there is any dry way at all. Infinite
## would make a road impossible on a map whose villages sit across a watercourse.
const WATER_COST: float = 24.0
## Per unit of slope (0=flat, 1=vertical). Roads follow contours.
const SLOPE_COST: float = 40.0
## Cells already carrying road are cheaper, so later routes MERGE onto earlier ones
## instead of running parallel. Junctions emerge from this discount; there is no
## junction code.
const BRAID_DISCOUNT: float = 0.25
## Slope above this is refused outright - a road does not climb a cliff.
const MAX_ROAD_SLOPE: float = 0.55
## Clearance kept between a road centreline and a building's footprint edge, in
## meters. The corridor is thinned ROAD_HALF_WIDTH_M either side, so anything
## nearer than that is a road running through the wall.
const BUILDING_CLEARANCE_M: float = ROAD_HALF_WIDTH_M
## Cost of entering a cell a building stands on. LARGE BUT FINITE for the same
## reason WATER_COST is: a hard block can ring a village centre with its own huts
## and disconnect it, and reaching every village is the network's contract.
const BUILDING_COST: float = 4000.0
## Rings searched when a route endpoint lands on a building. Beyond this the
## endpoint is used as given - a terminus 5 cells out is no longer that village.
const ENDPOINT_SEARCH_RINGS: int = 5

## Road polylines. Each is a PackedVector3Array of SEATED world points (Y = terrain
## height at that XZ). Shaped deliberately like HydrologyMap.rivers so the two read
## the same way to any consumer.
var segments: Array[PackedVector3Array] = []

var _grid: GameplayGrid
var _terrain: TerrainManager
## Grid cells carrying road, for the braid discount and fast proximity rejection.
var _road_cells: Dictionary = {}
## Grid cells a stamped building stands on. Populated by set_blockers().
var _building_cells: Dictionary = {}


func _init(grid: GameplayGrid, terrain: TerrainManager) -> void:
	_grid = grid
	_terrain = terrain


## Build the network: the firebase gate is the hub, every village is a spoke.
##
## VC camps are deliberately NOT connected. A paved road to a Viet Cong base camp is
## absurd on its face, and the ambush planner does not need one - it scores distance
## to a traffic line rather than requiring one (see AmbushPlanner.TRAFFIC_NEAR_M).
## The buildings the router must not cross. Roads are routed AFTER every site is
## stamped (Summoner's ruling 2026-08-12), so `bodies` is the real world: the
## "nav_blockers" group, every member carrying a `model_name` meta whose
## CollisionTable entry gives the authored footprint.
##
## Rotation is ignored deliberately: stamped structures are yaw-only and the
## reach that matters is the half-diagonal, which no yaw changes.
func set_blockers(bodies: Array) -> void:
	_building_cells.clear()
	if _grid == null:
		return
	for b in bodies:
		var n := b as Node3D
		if n == null or not n.has_meta("model_name"):
			continue
		var entry: Dictionary = CollisionTable.get_entry(str(n.get_meta("model_name")))
		var fp: Vector2 = entry.footprint
		_mark_building(n.global_position, fp.length() * 0.5 + BUILDING_CLEARANCE_M)


func _mark_building(center: Vector3, reach: float) -> void:
	var span: int = maxi(1, int(ceil(reach / _grid.cell_size_meters)))
	var c: Vector2i = _grid.world_to_grid(center)
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := Vector2i(c.x + dx, c.y + dz)
			if not _in_bounds(cell, _grid.grid_size):
				continue
			var w: Vector3 = _grid.grid_to_world(cell)
			if Vector2(w.x - center.x, w.z - center.z).length() <= reach:
				_building_cells[cell] = true


func build(gate_pos: Vector3, village_centers: Array) -> void:
	segments.clear()
	_road_cells.clear()
	if _grid == null:
		return
	for v in village_centers:
		var dest: Vector3 = v as Vector3
		var path: PackedVector3Array = _route(gate_pos, dest)
		if path.size() >= 2:
			segments.append(path)
			_mark_cells(path)


## Shortest sensible road between two world points, seated on the terrain.
## Returns an empty array if no route exists.
func _route(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	var start: Vector2i = _open_endpoint(_grid.world_to_grid(from_pos))
	var goal: Vector2i = _open_endpoint(_grid.world_to_grid(to_pos))
	var cells: Array[Vector2i] = _astar(start, goal)
	if cells.size() < 2:
		return PackedVector3Array()
	return _seat_and_resample(cells)


## A* over the gameplay grid's own cost field. Runs once, behind the loading screen.
func _astar(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var n: int = _grid.grid_size
	if not _in_bounds(start, n) or not _in_bounds(goal, n):
		return []
	var total: int = n * n
	var g_score := PackedFloat32Array()
	g_score.resize(total)
	g_score.fill(INF)
	var came_from := PackedInt32Array()
	came_from.resize(total)
	came_from.fill(-1)
	var closed := PackedByteArray()
	closed.resize(total)

	var start_i: int = start.y * n + start.x
	var goal_i: int = goal.y * n + goal.x
	g_score[start_i] = 0.0

	# Binary min-heap over (priority, cell index).
	var heap_pri := PackedFloat32Array()
	var heap_idx := PackedInt32Array()
	_heap_push(heap_pri, heap_idx, _heuristic(start, goal), start_i)

	while heap_idx.size() > 0:
		var cur: int = _heap_pop(heap_pri, heap_idx)
		if cur == goal_i:
			return _reconstruct(came_from, goal_i, n)
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		var cx: int = cur % n
		@warning_ignore("integer_division")
		var cz: int = cur / n
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = cx + dx
				var nz: int = cz + dz
				if nx < 0 or nx >= n or nz < 0 or nz >= n:
					continue
				var ni: int = nz * n + nx
				if closed[ni] == 1:
					continue
				var step_cost: float = _cell_cost(nx, nz)
				if step_cost < 0.0:
					continue
				# Diagonals cost their true length, or the router prefers staircases.
				var diag: float = 1.41421356 if (dx != 0 and dz != 0) else 1.0
				var tentative: float = g_score[cur] + step_cost * diag
				if tentative < g_score[ni]:
					g_score[ni] = tentative
					came_from[ni] = cur
					_heap_push(heap_pri, heap_idx,
						tentative + _heuristic(Vector2i(nx, nz), goal), ni)
	return []


## Cost of entering a cell. Negative means impassable to a road.
func _cell_cost(gx: int, gz: int) -> float:
	var ttype: int = _grid.get_terrain_type_at(gx, gz)
	if ttype == GameplayGrid.TerrainType.CLIFF:
		return -1.0
	var world: Vector3 = _grid.grid_to_world(Vector2i(gx, gz))
	var slope_val: float = _grid.get_slope(world)
	if slope_val > MAX_ROAD_SLOPE:
		return -1.0
	var base: float = float(GameplayGrid.MOVEMENT_COSTS.get(ttype, 1.0))
	if ttype == GameplayGrid.TerrainType.WATER:
		# MOVEMENT_COSTS puts water at 99 (impassable to infantry). A road fords it,
		# so we substitute a large-but-finite crossing cost.
		base = WATER_COST
	var cost: float = base + slope_val * SLOPE_COST
	if _road_cells.has(Vector2i(gx, gz)):
		cost *= BRAID_DISCOUNT
	if _building_cells.has(Vector2i(gx, gz)):
		cost += BUILDING_COST
	return cost


## A village centre is normally the middle of its own hut cluster, so ending a
## route there would seat its last points inside a wall. The terminus walks out
## to the nearest cell no building stands on: the road reaches the village and
## stops at its edge. The scan order is fixed, so this draws nothing and the same
## seed yields the same terminus.
func _open_endpoint(c: Vector2i) -> Vector2i:
	if not _building_cells.has(c):
		return c
	var n: int = _grid.grid_size
	for r in range(1, ENDPOINT_SEARCH_RINGS + 1):
		var best := Vector2i(-1, -1)
		var best_d: float = INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var cell := Vector2i(c.x + dx, c.y + dz)
				if not _in_bounds(cell, n) or _building_cells.has(cell):
					continue
				if _cell_cost(cell.x, cell.y) < 0.0:
					continue
				var d: float = Vector2(float(dx), float(dz)).length()
				if d < best_d:
					best_d = d
					best = cell
		if best.x >= 0:
			return best
	return c


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()


func _in_bounds(c: Vector2i, n: int) -> bool:
	return c.x >= 0 and c.x < n and c.y >= 0 and c.y < n


func _reconstruct(came_from: PackedInt32Array, goal_i: int, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cur: int = goal_i
	while cur != -1:
		@warning_ignore("integer_division")
		out.append(Vector2i(cur % n, cur / n))
		cur = came_from[cur]
	out.reverse()
	return out


## Convert a cell chain into evenly spaced world points seated on the terrain.
## Seating is the whole contract: a road point's Y is the ground's Y at that XZ, so
## a road can never float or bury no matter what the heightmap does.
func _seat_and_resample(cells: Array[Vector2i]) -> PackedVector3Array:
	var raw := PackedVector3Array()
	for c in cells:
		raw.append(_grid.grid_to_world(c))
	var out := PackedVector3Array()
	var carried: float = 0.0
	out.append(_seat(raw[0]))
	for i in range(1, raw.size()):
		var a: Vector3 = raw[i - 1]
		var b: Vector3 = raw[i]
		var seg_len: float = Vector2(b.x - a.x, b.z - a.z).length()
		if seg_len <= 0.0001:
			continue
		var travelled: float = POINT_SPACING_M - carried
		while travelled <= seg_len:
			var t: float = travelled / seg_len
			out.append(_seat(a.lerp(b, t)))
			travelled += POINT_SPACING_M
		carried = fmod(carried + seg_len, POINT_SPACING_M)
	var last: Vector3 = _seat(raw[raw.size() - 1])
	if out.size() == 0 or out[out.size() - 1].distance_to(last) > 0.5:
		out.append(last)
	return out


## Y is ALWAYS the ground's Y at that XZ - that is the seating contract, and it is why
## a road can neither float nor bury no matter what the heightmap does. Synthetic test
## grids have no terrain; those seat at 0 rather than crashing.
func _seat(p: Vector3) -> Vector3:
	if _terrain == null:
		return Vector3(p.x, 0.0, p.z)
	return Vector3(p.x, _terrain.get_height_at(p), p.z)


func _mark_cells(path: PackedVector3Array) -> void:
	for p in path:
		var c: Vector2i = _grid.world_to_grid(p)
		_road_cells[c] = true


## Distance in the XZ plane from a world point to the nearest road centreline, in
## meters. Returns INF when no road exists - callers must treat that as "no traffic
## line here", never as zero.
##
## This is the query the ambush planner and the topo sheet both use. It is the whole
## public surface of the road network besides the polylines themselves.
func distance_to_road(pos: Vector3) -> float:
	var best: float = INF
	for seg in segments:
		for i in range(1, seg.size()):
			var d: float = _point_segment_distance_xz(pos, seg[i - 1], seg[i])
			if d < best:
				best = d
	return best


static func _point_segment_distance_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var pv := Vector2(p.x, p.z)
	var av := Vector2(a.x, a.z)
	var bv := Vector2(b.x, b.z)
	var ab: Vector2 = bv - av
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return pv.distance_to(av)
	var t: float = clampf((pv - av).dot(ab) / len_sq, 0.0, 1.0)
	return pv.distance_to(av + ab * t)


## The longest road in the network, as a convoy route. Convoys run the road that
## carries the most ground, which is the one most worth ambushing.
func longest_route() -> PackedVector3Array:
	var best := PackedVector3Array()
	var best_len: float = -1.0
	for seg in segments:
		var l: float = 0.0
		for i in range(1, seg.size()):
			l += seg[i - 1].distance_to(seg[i])
		if l > best_len:
			best_len = l
			best = seg
	return best


## Total centreline length of the whole network, in meters.
func total_length() -> float:
	var sum: float = 0.0
	for seg in segments:
		for i in range(1, seg.size()):
			sum += seg[i - 1].distance_to(seg[i])
	return sum


## Thin vegetation along every road corridor. This is the ONLY thing a road writes
## into the world, and it writes VEGETATION BUNDLES ONLY - never height, never
## terrain_type, never water. A road you can see from the ground is a corridor of
## open sky; this is what makes one.
## The dust a road wears into the ground. Pulling the plants was the ONLY trace a road left,
## so convoys drove a lane of missing jungle that the topo map confidently drew as a highway.
## ClearingSystem's texture is already a full-map RGBA overlay the terrain shader mixes on
## every pixel (terrain.gdshader:99-100), so this costs no sampler, no uniform and no art.
const ROAD_DUST: Color = Color(0.42, 0.35, 0.24)
## Under 1.0 on purpose: a track worn through jungle keeps some of the ground under it.
const ROAD_DUST_STRENGTH: float = 0.72


func clear_corridor(veg: VegetationManager, chunk_size: float, heightmap: Object) -> int:
	if veg == null or not veg.has_method("clear_area"):
		return 0
	var cleared: int = 0
	for seg in segments:
		for p in seg:
			cleared += int(veg.clear_area(p, ROAD_HALF_WIDTH_M, chunk_size, heightmap))
	_stamp_dust()
	return cleared


func _stamp_dust() -> void:
	if not ClearingSystem.has_method("stamp_ground_line"):
		return
	var lines: int = 0
	for seg in segments:
		for i in range(seg.size() - 1):
			ClearingSystem.stamp_ground_line(seg[i], seg[i + 1], ROAD_HALF_WIDTH_M,
				ROAD_DUST, ROAD_DUST_STRENGTH)
			lines += 1
	if lines > 0:
		ClearingSystem.flush_ground()
	print("[ROADS] dust stamped on %d segment line(s)" % lines)


# ---------------------------------------------------------------------------
# Binary min-heap (parallel arrays), matching the shape HydrologyMap uses for its
# priority flood so the two solvers read alike.
# ---------------------------------------------------------------------------

static func _heap_push(pri: PackedFloat32Array, idx: PackedInt32Array,
		p: float, i: int) -> void:
	pri.append(p)
	idx.append(i)
	var c: int = pri.size() - 1
	while c > 0:
		@warning_ignore("integer_division")
		var parent: int = (c - 1) / 2
		if pri[parent] <= pri[c]:
			break
		var tp: float = pri[parent]
		pri[parent] = pri[c]
		pri[c] = tp
		var ti: int = idx[parent]
		idx[parent] = idx[c]
		idx[c] = ti
		c = parent


static func _heap_pop(pri: PackedFloat32Array, idx: PackedInt32Array) -> int:
	var top: int = idx[0]
	var last: int = pri.size() - 1
	pri[0] = pri[last]
	idx[0] = idx[last]
	pri.resize(last)
	idx.resize(last)
	var c: int = 0
	var n: int = pri.size()
	while true:
		var l: int = c * 2 + 1
		var r: int = c * 2 + 2
		var smallest: int = c
		if l < n and pri[l] < pri[smallest]:
			smallest = l
		if r < n and pri[r] < pri[smallest]:
			smallest = r
		if smallest == c:
			break
		var tp: float = pri[smallest]
		pri[smallest] = pri[c]
		pri[c] = tp
		var ti: int = idx[smallest]
		idx[smallest] = idx[c]
		idx[c] = ti
		c = smallest
	return top
