extends RefCounted
class_name PondDetector
## Detects depressions in terrain for pond/lake generation
## Uses flood fill from local minima to find water bodies

var _heightmap: RefCounted = null  # HeightmapStorage

## Direction offsets for 4-neighbor connectivity (for flood fill)
const DIRS_4 := [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)
]


## Result structure for a detected depression
class Depression:
	var cells: Array[Vector2i] = []  # All cells in the depression
	var minimum: Vector2i = Vector2i.ZERO  # Lowest point cell
	var pour_point: Vector2i = Vector2i.ZERO  # Where water overflows
	var min_elevation: float = 0.0  # Height at minimum (meters)
	var pour_elevation: float = 0.0  # Height at pour point (meters)
	var water_depth: float = 0.0  # pour_elevation - min_elevation
	var area: float = 0.0  # Area in square meters
	var bounds: Rect2 = Rect2()  # World bounds


## Convert depression cells to a polygon outline (for mesh generation)
func cells_to_polygon(depression: Depression) -> PackedVector2Array:
	if depression.cells.size() == 0:
		return PackedVector2Array()

	var cell_size: float = _heightmap.cell_size

	var cell_set: Dictionary = {}
	for cell in depression.cells:
		cell_set[cell] = true

	# Find edge cells (cells with at least one neighbor not in the set)
	var edge_cells: Array[Vector2i] = []
	for cell in depression.cells:
		for dir in DIRS_4:
			var neighbor := Vector2i(cell.x + dir.x, cell.y + dir.y)
			if not cell_set.has(neighbor):
				edge_cells.append(cell)
				break

	if edge_cells.size() < 3:
		return PackedVector2Array()

	# Convert edge cells to world coordinates (cell centers)
	var points: PackedVector2Array = PackedVector2Array()
	for cell in edge_cells:
		var world_x: float = (cell.x + 0.5) * cell_size
		var world_z: float = (cell.y + 0.5) * cell_size
		points.append(Vector2(world_x, world_z))

	# Sort points by angle from centroid for proper polygon winding
	var centroid := Vector2.ZERO
	for pt in points:
		centroid += pt
	centroid /= points.size()

	var sorted_points: Array[Vector2] = []
	for pt in points:
		sorted_points.append(pt)

	sorted_points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var angle_a := atan2(a.y - centroid.y, a.x - centroid.x)
		var angle_b := atan2(b.y - centroid.y, b.x - centroid.x)
		return angle_a < angle_b
	)

	var polygon := PackedVector2Array()
	for pt in sorted_points:
		polygon.append(pt)

	return polygon


## Simplify polygon using Douglas-Peucker algorithm
func simplify_polygon(polygon: PackedVector2Array, tolerance: float = 2.0) -> PackedVector2Array:
	if polygon.size() < 4:
		return polygon

	return _douglas_peucker(polygon, 0, polygon.size() - 1, tolerance)


func _douglas_peucker(points: PackedVector2Array, start_idx: int, end_idx: int, tolerance: float) -> PackedVector2Array:
	if end_idx - start_idx < 2:
		var result := PackedVector2Array()
		result.append(points[start_idx])
		if start_idx != end_idx:
			result.append(points[end_idx])
		return result

	# Find point with maximum distance from line
	var max_dist: float = 0.0
	var max_idx: int = start_idx

	var start_pt: Vector2 = points[start_idx]
	var end_pt: Vector2 = points[end_idx]
	var line_vec: Vector2 = end_pt - start_pt
	var line_len: float = line_vec.length()

	if line_len > 0.001:
		line_vec /= line_len

		for i in range(start_idx + 1, end_idx):
			var pt: Vector2 = points[i]
			var to_pt: Vector2 = pt - start_pt
			var proj: float = to_pt.dot(line_vec)
			var closest: Vector2 = start_pt + line_vec * clampf(proj, 0.0, line_len)
			var dist: float = pt.distance_to(closest)

			if dist > max_dist:
				max_dist = dist
				max_idx = i

	if max_dist > tolerance:
		var left := _douglas_peucker(points, start_idx, max_idx, tolerance)
		var right := _douglas_peucker(points, max_idx, end_idx, tolerance)

		# Combine (skip duplicate middle point)
		var result := PackedVector2Array()
		for i in range(left.size() - 1):
			result.append(left[i])
		for pt in right:
			result.append(pt)
		return result
	else:
		var result := PackedVector2Array()
		result.append(start_pt)
		result.append(end_pt)
		return result
