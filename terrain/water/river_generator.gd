extends RefCounted
class_name RiverGenerator
## Extracts river paths from heightmap by computing flow accumulation
## Uses simplified D8 flow direction algorithm to find valleys


## Simple class to hold a river path with varying widths
class RiverPath:
	var points: PackedVector2Array
	var widths: PackedFloat32Array

	func _init() -> void:
		points = PackedVector2Array()
		widths = PackedFloat32Array()

	func add_point(pos: Vector2, width: float) -> void:
		points.append(pos)
		widths.append(width)

	func size() -> int:
		return points.size()


## 8-direction offsets for neighbor cells (D8 algorithm)
const DIR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
]

## Diagonal directions have longer distance
const DIR_DISTANCES: Array[float] = [
	1.414, 1.0, 1.414,
	1.0,        1.0,
	1.414, 1.0, 1.414
]

## Scale factor for converting accumulation to river width
var width_scale: float = 0.1

## Minimum points required to form a valid river path
var min_river_length: int = 10

## Number of rivers to generate in fast mode
var num_rivers: int = 8

## Base width for rivers (meters)
var base_width: float = 4.0

## Width growth rate per step
var width_growth: float = 0.15


## FAST: Extract rivers using gradient descent (no flow accumulation)
## Much faster than full D8 - traces rivers downhill from random high points
func extract_rivers_fast(heightmap: HeightmapStorage, river_count: int = 8) -> Array[RiverPath]:
	var paths: Array[RiverPath] = []
	var map_size: int = heightmap.size
	var cell_size: float = heightmap.cell_size
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Consistent rivers per map

	# Find candidate starting points (high elevation, not at edges)
	var margin: int = map_size / 10
	var candidates: Array[Vector2i] = []

	var sample_step: int = map_size / 20
	for z in range(margin, map_size - margin, sample_step):
		for x in range(margin, map_size - margin, sample_step):
			var h: float = heightmap.get_cell(x, z)
			if h > 0.5:  # Upper half of height range
				candidates.append(Vector2i(x, z))

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return heightmap.get_cell(a.x, a.y) > heightmap.get_cell(b.x, b.y)
	)

	# Track visited cells to avoid overlapping rivers
	var visited: Dictionary = {}

	var rivers_created: int = 0
	for start in candidates:
		if rivers_created >= river_count:
			break

		var too_close := false
		for dx in range(-10, 11):
			for dz in range(-10, 11):
				if visited.has(Vector2i(start.x + dx, start.y + dz)):
					too_close = true
					break
			if too_close:
				break
		if too_close:
			continue

		var path: RiverPath = _trace_river_downhill(heightmap, start, visited)
		if path.size() >= min_river_length:
			paths.append(path)
			rivers_created += 1

	return paths


## Trace a single river path downhill using gradient descent
func _trace_river_downhill(heightmap: HeightmapStorage, start: Vector2i, visited: Dictionary) -> RiverPath:
	var path := RiverPath.new()
	var map_size: int = heightmap.size
	var cell_size: float = heightmap.cell_size
	var current := start
	var width: float = base_width
	var max_steps: int = 2000  # Prevent infinite loops
	var steps: int = 0

	while steps < max_steps:
		steps += 1

		visited[current] = true

		var world_pos := Vector2(current.x * cell_size, current.y * cell_size)
		path.add_point(world_pos, width)

		width += width_growth

		# Find steepest descent neighbor
		var current_h: float = heightmap.get_cell(current.x, current.y)
		var best_neighbor: Vector2i = Vector2i(-1, -1)
		var best_slope: float = 0.0

		for dir_idx in range(8):
			var offset: Vector2i = DIR_OFFSETS[dir_idx]
			var nx: int = current.x + offset.x
			var nz: int = current.y + offset.y

			if nx < 1 or nx >= map_size - 1 or nz < 1 or nz >= map_size - 1:
				continue

			var nh: float = heightmap.get_cell(nx, nz)
			var drop: float = current_h - nh

			if drop > 0:
				var slope: float = drop / DIR_DISTANCES[dir_idx]
				if slope > best_slope:
					best_slope = slope
					best_neighbor = Vector2i(nx, nz)

		# Stop if no downhill neighbor (pit or edge)
		if best_neighbor.x < 0:
			break

		# Stop if we've been here before (joining another river)
		if visited.has(best_neighbor):
			var merge_pos := Vector2(best_neighbor.x * cell_size, best_neighbor.y * cell_size)
			path.add_point(merge_pos, width)
			break

		current = best_neighbor

	return path
