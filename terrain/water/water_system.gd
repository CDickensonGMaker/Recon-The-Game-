extends Node
class_name WaterSystem
## Central manager for all water bodies in the terrain
## Handles generation, tracking, and queries for water features

## Preload dependencies (must be before signals that use these types)
const WaterBodyDataClass := preload("res://terrain/water/water_body_data.gd")
const HydrologyMapClass := preload("res://terrain/water/hydrology_map.gd")
const PondDetectorClass := preload("res://terrain/water/pond_detector.gd")


## All water bodies indexed by ID
var water_bodies: Dictionary = {}  # id -> WaterBodyData

## Spatial index: chunk coordinate -> array of water body IDs

## Global sea level in meters (for coastal generation)
## Set to 0.5 (effectively sea floor) so that the COASTAL_HILLS AO (max 60m)
## never produces cells below sea level. The real water you see in the AO is
## rain-fed basins and channels, not ocean. Set higher than 0 to keep the
## coastal-flood code path alive for any future archipelago map.
var sea_level: float = 0.5

## Which map edges have ocean (bitmask: 1=North, 2=East, 4=South, 8=West)
## Set to 0 to disable coastal generation
var ocean_edges: int = 0b0000  # Disabled by default

var generate_swamps: bool = false  # Swamps were rendering as wet lakes; off so the AO reads as creeks + dry land

## Water type grid for O(1) lookups
## Each byte encodes: bits 0-2 = WaterType (0-6), bits 3-7 = depth_index (0-31)
var water_map: PackedByteArray = PackedByteArray()
var water_map_size: int = 0
var water_map_cell_size: float = 2.0

var _next_id: int = 0

var _heightmap: RefCounted = null  # HeightmapStorage

## Last hydrology result (for water-level queries)
var _hydrology: RefCounted = null  # HydrologyMap

## Downsample factor for hydrology compute (0 = auto from map size)
var hydrology_downsample: int = 0

## Chunk size for spatial indexing

var _water_container: Node3D = null

## The ground the hydrology was solved against, plus the map it produced. Terrain is
## edited at runtime; without these the water map cannot tell whether the floor under
## it has moved. Normalised heights, heightmap resolution.
var _gen_terrain: PackedFloat32Array = PackedFloat32Array()
var _gen_water_map: PackedByteArray = PackedByteArray()

## Ground must rise this far through standing water before the cell stops being water.
const RETIRE_RISE_M: float = 1.0


func _ready() -> void:
	_water_container = Node3D.new()
	_water_container.name = "WaterBodies"
	add_child(_water_container)


func initialize(heightmap: RefCounted) -> void:
	_heightmap = heightmap

	water_map_size = heightmap.size
	water_map_cell_size = heightmap.cell_size
	water_map.resize(water_map_size * water_map_size)
	water_map.fill(0)

	print("[WaterSystem] Initialized: %dx%d grid, %.1fm cells" % [
		water_map_size, water_map_size, water_map_cell_size
	])


## Generate all water bodies from a single coherent hydrology pass.
## Water cascades from the peaks downhill: channels (creeks/rivers) form where flow
## concentrates, pools (ponds/lakes) form in depressions, swamps in flat wet lowland.
## `prebuilt` is the HydrologyMap TerrainManager already ran to carve the riverbeds.
## Reusing it is what makes hydrology the single authority for where water goes: the
## surface is placed in the same channels that were cut, not in channels recomputed
## against terrain those very cuts changed.
func generate_water_bodies(prebuilt: RefCounted = null) -> void:
	if not _heightmap:
		push_error("[WaterSystem] Cannot generate: no heightmap set")
		return

	var start_time := Time.get_ticks_msec()

	clear()

	var hydro: RefCounted = prebuilt
	if hydro == null:
		hydro = HydrologyMapClass.new()
		hydro.downsample = _auto_downsample()
		hydro.ocean_edges = ocean_edges
		hydro.sea_level = sea_level
		hydro.generate(_heightmap)
	_hydrology = hydro

	# Rivers/creeks come out as flow-traced polylines.
	for river in hydro.rivers:
		_create_river_body(river["points"], river["widths"])

	# Ponds, lakes, swamps and coastal come out as connected cell groups.
	var static_bodies: Array = hydro.extract_static_bodies(_heightmap)
	for b in static_bodies:
		_create_static_body(b)

	# Render ALL water as a single batched mesh (one draw call) for performance.
	_build_combined_water_mesh(static_bodies, hydro.rivers)

	# Build the O(1) lookup grid straight from the hydrology cell types.
	_build_water_map_from_hydrology(hydro)

	_gen_terrain = _heightmap.data.duplicate()
	_gen_water_map = water_map.duplicate()

	var elapsed := Time.get_ticks_msec() - start_time
	print("[WaterSystem] Generated %d water bodies in %dms (downsample %d)" % [
		water_bodies.size(), elapsed, hydro.downsample
	])


## Pick a hydrology compute resolution that keeps the flood/accumulation cheap.
func _auto_downsample() -> int:
	if hydrology_downsample > 0:
		return hydrology_downsample
	# Target roughly a 400-cell hydrology grid regardless of map size.
	return maxi(1, int(round(float(water_map_size) / 450.0)))


## Build a river/creek WaterBodyData from a flow-traced polyline.
func _create_river_body(points: PackedVector2Array, widths: PackedFloat32Array) -> void:
	if points.size() < 2:
		return

	var body := WaterBodyDataClass.new()
	body.id = _next_id
	_next_id += 1

	var avg_width: float = 0.0
	for w in widths:
		avg_width += w
	avg_width /= widths.size()

	body.type = WaterBodyDataClass.Type.CREEK if avg_width < 6.0 else WaterBodyDataClass.Type.RIVER
	body.path = points
	body.widths = widths
	body.depth = 1.0 if body.type == WaterBodyDataClass.Type.CREEK else 2.5

	var min_pt := Vector2(INF, INF)
	var max_pt := Vector2(-INF, -INF)
	for pt in points:
		min_pt.x = minf(min_pt.x, pt.x)
		min_pt.y = minf(min_pt.y, pt.y)
		max_pt.x = maxf(max_pt.x, pt.x)
		max_pt.y = maxf(max_pt.y, pt.y)
	var max_width: float = 0.0
	for w in widths:
		max_width = maxf(max_width, w)
	min_pt -= Vector2(max_width, max_width) * 0.5
	max_pt += Vector2(max_width, max_width) * 0.5
	body.bounds = Rect2(min_pt, max_pt - min_pt)

	body.flow_direction = (points[points.size() - 1] - points[0]).normalized()

	var total_elev: float = 0.0
	for pt in points:
		total_elev += _heightmap.sample_world(pt.x, pt.y)
	body.elevation = total_elev / points.size()

	_register_water_body(body)


## Build a pond/lake/swamp/coastal WaterBodyData from a hydrology cell group.
func _create_static_body(b: Dictionary) -> void:
	var cells: Array[Vector2i] = b["cells"]
	if cells.size() < 8:
		return  # Skip tiny fragments

	var type_code: int = b["type"]
	if type_code == WaterBodyDataClass.Type.SWAMP and not generate_swamps:
		return

	var body := WaterBodyDataClass.new()
	body.id = _next_id
	_next_id += 1

	# Standing fresh water splits into pond/lake/swamp by area + max depth.
	# Rules (in order):
	#   1. Shallow wide puddles (max depth < 3.0 m) are SWAMP regardless of size
	#      — they read as wet ground, not as a "lake in the middle of the map".
	#   2. Deep-but-small basins (< 8000 m^2) are PONDS.
	#   3. Deep AND big are LAKES.
	var area: float = cells.size() * _heightmap.cell_size * _heightmap.cell_size
	var max_depth: float = b.get("depth_max", b.get("depth", 0.0))
	if type_code == WaterBodyDataClass.Type.LAKE:
		if max_depth < 6.0:
			body.type = WaterBodyDataClass.Type.SWAMP
		elif area < 15000.0:
			body.type = WaterBodyDataClass.Type.POND
		else:
			body.type = type_code as WaterBodyDataClass.Type
	else:
		body.type = type_code as WaterBodyDataClass.Type

	body.elevation = b["surface"]
	body.depth = b["depth"]
	body.bounds = b["bounds"]
	body.polygon = _cells_to_polygon(cells)

	_register_water_body(body)


## Build an outline polygon from a group of cells (for point-in-body queries).
func _cells_to_polygon(cells: Array[Vector2i]) -> PackedVector2Array:
	var detector := PondDetectorClass.new()
	detector._heightmap = _heightmap
	var dep := PondDetectorClass.Depression.new()
	dep.cells.assign(cells)
	var poly: PackedVector2Array = detector.cells_to_polygon(dep)
	if poly.size() >= 4:
		poly = detector.simplify_polygon(poly, _heightmap.cell_size * 2.0)
	return poly


## Shore fade distance (meters) baked into the combined mesh vertex colors.
const COMBINED_SHORE_FADE: float = 2.5
## Depth (meters) that maps to fully "deep" in vertex color G.
const COMBINED_DEPTH_RANGE: float = 4.0
## River water sits this far below the sampled bank height (sits in its channel).
const RIVER_RECESS: float = 0.1
const WATER_SHADER := preload("res://terrain/water/water_static.gdshader")

## Build ONE mesh + ONE material for every water body. Collapsing ~dozens of
## transparent MeshInstances into a single draw call is the big win on low-end GPUs.
func _build_combined_water_mesh(static_bodies: Array, rivers: Array) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for b in static_bodies:
		var cells: Array[Vector2i] = b["cells"]
		if cells.size() < 8:
			continue
		if b["type"] == WaterBodyDataClass.Type.SWAMP and not generate_swamps:
			continue
		_append_static_quads(cells, b["surface"], verts, normals, uvs, colors, indices)

	for r in rivers:
		_append_river_strip(r["points"], r["widths"], verts, normals, uvs, colors, indices)

	if verts.is_empty():
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	array_mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "CombinedWater"
	mi.mesh = array_mesh
	_water_container.add_child(mi)


## Append flat quads for a standing-water body (pond/lake/swamp/coastal).
func _append_static_quads(cells: Array[Vector2i], elevation: float,
		verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var cs: float = _heightmap.cell_size
	var hs: float = _heightmap.height_scale
	var hmax: int = _heightmap.size - 1

	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true

	for cell in cells:
		var wx: float = cell.x * cs
		var wz: float = cell.y * cs
		var shore: float = clampf(_cell_distance_to_edge(cell, cell_set) * cs / COMBINED_SHORE_FADE, 0.0, 1.0)
		var base: int = verts.size()

		for i in range(4):
			var ccx: int = clampi(cell.x + (1 if i == 1 or i == 2 else 0), 0, hmax)
			var ccz: int = clampi(cell.y + (1 if i == 2 or i == 3 else 0), 0, hmax)
			var terrain: float = _heightmap.get_cell(ccx, ccz) * hs
			var depth: float = clampf(maxf(0.0, elevation - terrain) / COMBINED_DEPTH_RANGE, 0.0, 1.0)
			var cx: float = wx + (cs if i == 1 or i == 2 else 0.0)
			var cz: float = wz + (cs if i == 2 or i == 3 else 0.0)
			verts.append(Vector3(cx, elevation, cz))
			normals.append(Vector3.UP)
			uvs.append(Vector2(cell.x + (1.0 if i == 1 or i == 2 else 0.0), cell.y + (1.0 if i == 2 or i == 3 else 0.0)))
			colors.append(Color(shore, depth, 0.0, 1.0))

		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## Append a triangle ribbon for a river/creek path, following the terrain downhill.
func _append_river_strip(points: PackedVector2Array, widths: PackedFloat32Array,
		verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	if points.size() < 2:
		return

	var base: int = verts.size()
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var half: float = widths[i] * 0.5
		var perp: Vector2 = _path_perpendicular(points, i)
		var left: Vector2 = p - perp * half
		var right: Vector2 = p + perp * half
		# Water surface follows the terrain (rivers flow downhill), recessed slightly.
		var y: float = (_heightmap.sample_world(left.x, left.y) + _heightmap.sample_world(right.x, right.y)) * 0.5 - RIVER_RECESS
		# R = 1 (narrow channels shouldn't fade out), G = medium depth -> blue.
		var col := Color(1.0, 0.35, 0.0, 1.0)
		verts.append(Vector3(left.x, y, left.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, float(i)))
		colors.append(col)
		verts.append(Vector3(right.x, y, right.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(1.0, float(i)))
		colors.append(col)

	for i in range(points.size() - 1):
		var l0: int = base + i * 2
		var r0: int = l0 + 1
		var l1: int = base + (i + 1) * 2
		var r1: int = l1 + 1
		indices.append_array([l0, r0, r1, l0, r1, l1])


## Distance (in cells) from a cell to the nearest cell outside the body.
func _cell_distance_to_edge(cell: Vector2i, cell_set: Dictionary) -> int:
	const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for dist in range(1, 20):
		for dir in DIRS:
			if not cell_set.has(cell + dir * dist):
				return dist
	return 20


## Perpendicular to a path at a point (for river ribbon width).
func _path_perpendicular(path: PackedVector2Array, index: int) -> Vector2:
	var direction: Vector2
	if index == 0:
		direction = (path[1] - path[0]).normalized()
	elif index == path.size() - 1:
		direction = (path[index] - path[index - 1]).normalized()
	else:
		var di: Vector2 = (path[index] - path[index - 1]).normalized()
		var do: Vector2 = (path[index + 1] - path[index]).normalized()
		direction = ((di + do) * 0.5).normalized()
	return Vector2(-direction.y, direction.x)


## Register a water body by id.
func _register_water_body(body: Resource) -> void:
	water_bodies[body.id] = body


## Build the O(1) lookup grid directly from hydrology cell types + surfaces.
func _build_water_map_from_hydrology(hydro: RefCounted) -> void:
	water_map.fill(0)

	var water_cells: int = 0
	var total_cells: int = water_map_size * water_map_size
	for i in range(total_cells):
		var t: int = hydro.water_type_full[i]
		if t == 0:
			continue
		var x: int = i % water_map_size
		@warning_ignore("integer_division")
		var z: int = i / water_map_size
		var terrain: float = _heightmap.get_cell(x, z) * _heightmap.height_scale
		var depth: float = maxf(0.0, hydro.water_surface_full[i] - terrain)
		var depth_index: int = clampi(int(depth * 2.0), 0, 31)
		water_map[i] = t | (depth_index << 3)
		water_cells += 1

	var percent: float = 100.0 * water_cells / total_cells
	print("[WaterSystem] Water map: %d/%d cells (%.1f%%)" % [water_cells, total_cells, percent])


## Re-seat the O(1) water lookup against the CURRENT ground. Terrain is editable at
## runtime (firebase flatten, craters) and that moves the floor under standing water:
## where the ground has risen through the surface the cell is no longer water, and
## everywhere else the depth changed. Recomputed from the retained hydrology, so it is
## idempotent and ground dropping again restores the water.
##
## Deliberately does NOT re-run hydrology (a whole-map flood + mesh rebuild, far too
## expensive per crater) - so this never creates NEW water. A crater does not fill.
func reseat_region(world_rect: Rect2) -> void:
	if _heightmap == null or _gen_terrain.is_empty():
		return

	# Compared against the ground the hydrology was SOLVED on, not against
	# water_surface_full: channel cells never get a surface written
	# (hydrology_map._trace_channel sets the type only), so a surface comparison
	# reads 0 for every creek and would retire the entire watercourse.
	var rise_norm: float = RETIRE_RISE_M / _heightmap.height_scale

	var min_x: int = clampi(int(floor(world_rect.position.x / water_map_cell_size)), 0, water_map_size - 1)
	var min_z: int = clampi(int(floor(world_rect.position.y / water_map_cell_size)), 0, water_map_size - 1)
	var max_x: int = clampi(int(ceil(world_rect.end.x / water_map_cell_size)), 0, water_map_size - 1)
	var max_z: int = clampi(int(ceil(world_rect.end.y / water_map_cell_size)), 0, water_map_size - 1)

	for cz in range(min_z, max_z + 1):
		for cx in range(min_x, max_x + 1):
			var i: int = cz * water_map_size + cx
			if _gen_water_map[i] == 0:
				continue
			# Re-derived from the generation snapshot every time, so lowering the
			# ground again restores the water this retired.
			if _heightmap.get_cell(cx, cz) - _gen_terrain[i] > rise_norm:
				water_map[i] = 0
			else:
				water_map[i] = _gen_water_map[i]


func clear() -> void:
	for child in _water_container.get_children():
		# Detach before freeing: queue_free lands at end of frame, and a regenerate
		# adds the new mesh this frame - leaving two water surfaces overlapping.
		_water_container.remove_child(child)
		child.queue_free()

	water_bodies.clear()
	water_map.fill(0)
	_next_id = 0
	_hydrology = null


# =============================================================================
# PUBLIC QUERY API
# =============================================================================

func is_water(world_x: float, world_z: float) -> bool:
	var cx: int = int(floor(world_x / water_map_cell_size))
	var cz: int = int(floor(world_z / water_map_cell_size))

	if cx < 0 or cx >= water_map_size or cz < 0 or cz >= water_map_size:
		return false

	return water_map[cz * water_map_size + cx] > 0


## Get water depth at a world position (meters, 0 if not in water)
func get_water_depth(world_x: float, world_z: float) -> float:
	var cx: int = int(floor(world_x / water_map_cell_size))
	var cz: int = int(floor(world_z / water_map_cell_size))

	if cx < 0 or cx >= water_map_size or cz < 0 or cz >= water_map_size:
		return 0.0

	var byte_value: int = water_map[cz * water_map_size + cx]
	if byte_value == 0:
		return 0.0

	var depth_index: int = (byte_value >> 3) & 0x1F  # Bits 3-7
	return depth_index * 0.5  # 0.5m per index unit


## Get the flat water-surface height (meters) at a world position.
## Returns -INF when there is no water there (callers should check is_water first).
func get_water_level_at(world_x: float, world_z: float) -> float:
	if not _hydrology:
		return -INF
	var cx: int = int(floor(world_x / water_map_cell_size))
	var cz: int = int(floor(world_z / water_map_cell_size))
	if cx < 0 or cx >= water_map_size or cz < 0 or cz >= water_map_size:
		return -INF
	var idx: int = cz * water_map_size + cx
	if _hydrology.water_type_full[idx] == 0:
		return -INF
	return _hydrology.water_surface_full[idx]


## Generate wetness texture for terrain shore blending
## Returns an ImageTexture with R = wetness (1 = water, fades to 0)
func generate_wetness_texture(fade_distance: float = 20.0) -> ImageTexture:
	var img := Image.create(water_map_size, water_map_size, false, Image.FORMAT_R8)
	img.fill(Color(0, 0, 0, 1))

	# First pass: mark water cells
	for z in range(water_map_size):
		for x in range(water_map_size):
			if water_map[z * water_map_size + x] > 0:
				img.set_pixel(x, z, Color(1, 0, 0, 1))

	# Calculate distance in cells for fade
	var fade_cells: int = int(ceil(fade_distance / water_map_cell_size))

	# Second pass: expand wetness outward from water edges
	# Use a simple distance field approximation
	for dist in range(1, fade_cells + 1):
		var wetness: float = 1.0 - (float(dist) / float(fade_cells))
		wetness = wetness * wetness  # Square for smoother falloff

		for z in range(water_map_size):
			for x in range(water_map_size):
				if img.get_pixel(x, z).r >= wetness:
					continue

				# Check if any neighbor at dist-1 has wetness
				var has_wet_neighbor := false
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dz == 0:
							continue
						var nx: int = x + dx
						var nz: int = z + dz
						if nx >= 0 and nx < water_map_size and nz >= 0 and nz < water_map_size:
							var neighbor_wetness: float = img.get_pixel(nx, nz).r
							if neighbor_wetness > wetness:
								has_wet_neighbor = true
								break
					if has_wet_neighbor:
						break

				if has_wet_neighbor:
					img.set_pixel(x, z, Color(wetness, 0, 0, 1))

	var tex := ImageTexture.create_from_image(img)
	print("[WaterSystem] Generated wetness texture: %dx%d, fade %.1fm" % [
		water_map_size, water_map_size, fade_distance
	])
	return tex


func print_stats() -> void:
	print("[WaterSystem] === Water System Stats ===")
	print("  Total bodies: %d" % water_bodies.size())

	var by_type: Dictionary = {}
	for body in water_bodies.values():
		var type_name: String = WaterBodyDataClass.type_name(body.type)
		by_type[type_name] = by_type.get(type_name, 0) + 1

	for type_name in by_type:
		print("  - %s: %d" % [type_name, by_type[type_name]])

	var water_cells: int = 0
	for byte in water_map:
		if byte > 0:
			water_cells += 1

	print("  Water cells: %d (%.1f%%)" % [
		water_cells,
		100.0 * water_cells / (water_map_size * water_map_size)
	])


func get_stats() -> Dictionary:
	var stats := {
		"total": water_bodies.size(),
		"rivers": 0,
		"creeks": 0,
		"ponds": 0,
		"lakes": 0,
		"swamps": 0,
		"coastal": false
	}

	for body in water_bodies.values():
		match body.type:
			1:  # Creek
				stats["creeks"] += 1
			2:  # River
				stats["rivers"] += 1
			3:  # Pond
				stats["ponds"] += 1
			4:  # Lake
				stats["lakes"] += 1
			5:  # Swamp
				stats["swamps"] += 1
			6:  # Coastal
				stats["coastal"] = true

	return stats
