extends Node3D
class_name TerrainChunk
## A single terrain chunk (256m x 256m) with mesh, collision, and navigation

var coord: Vector2i  # Chunk grid coordinates
var chunk_size: float = 256.0  # Meters
var cell_size: float = 2.0  # Meters per vertex
var grid_resolution: int = 128  # Vertices per side (256m / 2m)

var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D  # Optional - only for raycast picking

## Real (height_scale-multiplied) sample heights for this chunk, row-major z*(res+1)+x, in
## the exact order HeightMapShape3D wants them. Filled by build_mesh, consumed by
## create_raycast_collision - the collider and the visible mesh therefore read ONE array and
## cannot describe different ground.
var _height_samples: PackedFloat32Array = PackedFloat32Array()

## PATCH CACHE. A 5m crater edits a handful of samples and then rebuilt this whole chunk:
## 64x64 quads re-derived, 49,152 vertices re-emitted, the node destroyed and a new Jolt body
## swapped in. These four arrays are what patch_mesh() edits in place instead.
##
## ARMED BY THE FIRST PATCH, NOT BY THE FIRST BUILD, and that is the whole memory argument:
## the fan-out arrays are ~2 MB a chunk, and in a mission only the few chunks that actually
## take shells are ever patched. Holding them for all 25 would be ~49 MB to save time on
## ground nothing ever hits.
var _keep_patch_cache: bool = false
var _grid_v: PackedVector3Array = PackedVector3Array()
var _grid_c: PackedColorArray = PackedColorArray()
var _verts: PackedVector3Array = PackedVector3Array()
var _norms: PackedVector3Array = PackedVector3Array()
var _cols: PackedColorArray = PackedColorArray()
## The last inputs build_mesh was handed, so a patch can reproduce colours without them.
var _veg_bytes: PackedByteArray = PackedByteArray()
var _veg_bundles: int = 0

## STATIC on purpose: a crater rebuild throws the TerrainChunk away and constructs a new
## one, so a per-instance flag would still print once per rebuild - which is the case this
## exists to stop. One line per session, and it is diagnostic only. See build_mesh().
static var _announced: bool = false

## Handed down from HeightmapStorage at build time - never authored here.
var height_scale: float = TerrainConfig.WORLD_HEIGHT_MAX

# Material (shared across chunks) - can be ShaderMaterial or StandardMaterial3D
static var shared_material: Material
static var _using_shader: bool = false


func _init(chunk_coord: Vector2i, size: float = 256.0, c_size: float = 2.0) -> void:
	coord = chunk_coord
	chunk_size = size
	cell_size = c_size
	grid_resolution = int(chunk_size / cell_size)


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	add_child(mesh_instance)


	var world_x: float = coord.x * chunk_size
	var world_z: float = coord.y * chunk_size
	position = Vector3(world_x, 0, world_z)


## Build mesh from heightmap region data
## region_data: PackedFloat32Array of normalized heights (grid_resolution+1 x grid_resolution+1)
## vegetation_terrain: Optional PackedByteArray of terrain types per bundle (for rice paddy coloring)
## bundles_per_chunk: Number of bundles per side (typically chunk_size / 8)
func build_mesh(region_data: PackedFloat32Array, h_scale: float = TerrainConfig.WORLD_HEIGHT_MAX, vegetation_terrain: PackedByteArray = PackedByteArray(), bundles_per_chunk: int = 0) -> void:
	height_scale = h_scale
	_veg_bytes = vegetation_terrain
	_veg_bundles = bundles_per_chunk

	if region_data.size() < (grid_resolution + 1) * (grid_resolution + 1):
		push_error("[TerrainChunk] Region data too small: %d (expected %d)" % [
			region_data.size(), (grid_resolution + 1) * (grid_resolution + 1)
		])
		return

	## BUILT STRAIGHT INTO PACKED ARRAYS, NOT THROUGH SurfaceTool (2026-09-08).
	## The geometry, winding, flat per-triangle normals and vertex colours below are
	## IDENTICAL to the SurfaceTool version this replaces - only the machinery changed.
	## Why it changed: a 128-resolution chunk is 16,384 quads, so the old path made
	## 98,304 `add_vertex` calls plus 196,608 `set_normal`/`set_color` calls across the
	## GDScript/engine boundary, and then paid `st.index()` to hash all 98,304 verts
	## looking for duplicates it could never find - the shading is FLAT, so the two
	## triangles of a quad carry different normals and nothing in the surface is ever a
	## duplicate. That whole pass was cost for no vertices saved.
	##
	## This matters because a single crater rebuilds whole chunks: measured on the
	## headless stall bench, 6 large explosions spent 534ms in the chunk rebuild chain,
	## 185ms of it right here.
	StallLedger.begin("mesh.grid")
	var step: float = chunk_size / float(grid_resolution)
	var data_width: int = grid_resolution + 1

	var grid_v := PackedVector3Array()
	var grid_c := PackedColorArray()
	grid_v.resize(data_width * data_width)
	grid_c.resize(data_width * data_width)
	_height_samples.resize(data_width * data_width)
	for z in range(data_width):
		for x in range(data_width):
			var gi: int = z * data_width + x
			var local_x: float = x * step
			var local_z: float = z * step
			var norm_h: float = region_data[gi]
			var h: float = norm_h * height_scale
			grid_v[gi] = Vector3(local_x, h, local_z)
			_height_samples[gi] = h
			grid_c[gi] = _get_terrain_color(h, norm_h, local_x, local_z,
				vegetation_terrain, bundles_per_chunk)

	StallLedger.end()
	StallLedger.begin("mesh.fanout")
	var quads: int = grid_resolution * grid_resolution
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(quads * 6)
	norms.resize(quads * 6)
	cols.resize(quads * 6)

	var w: int = 0
	for z in range(grid_resolution):
		for x in range(grid_resolution):
			var i: int = z * data_width + x
			var v0: Vector3 = grid_v[i]
			var v1: Vector3 = grid_v[i + 1]
			var v2: Vector3 = grid_v[i + data_width]
			var v3: Vector3 = grid_v[i + data_width + 1]
			var c0: Color = grid_c[i]
			var c1: Color = grid_c[i + 1]
			var c2: Color = grid_c[i + data_width]
			var c3: Color = grid_c[i + data_width + 1]

			# Triangle 1: v0, v1, v2 (counter-clockwise winding for upward normals)
			var n1: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
			if n1.y < 0.0:
				n1 = -n1
			verts[w] = v0; norms[w] = n1; cols[w] = c0; w += 1
			verts[w] = v1; norms[w] = n1; cols[w] = c1; w += 1
			verts[w] = v2; norms[w] = n1; cols[w] = c2; w += 1

			# Triangle 2: v1, v3, v2
			var n2: Vector3 = (v3 - v1).cross(v2 - v1).normalized()
			if n2.y < 0.0:
				n2 = -n2
			verts[w] = v1; norms[w] = n2; cols[w] = c1; w += 1
			verts[w] = v3; norms[w] = n2; cols[w] = c3; w += 1
			verts[w] = v2; norms[w] = n2; cols[w] = c2; w += 1

	StallLedger.end()
	StallLedger.begin("mesh.surface")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = am
	if _keep_patch_cache:
		_grid_v = grid_v
		_grid_c = grid_c
		_verts = verts
		_norms = norms
		_cols = cols

	if not shared_material:
		_create_shared_material()
	mesh_instance.material_override = shared_material
	StallLedger.end()

	## Was an unconditional print. A raid rebuilds chunks continuously and each line was
	## a synchronous write into the redirected bench log, inside the very stall being
	## measured - the instrument was paying part of the cost it reported. First build of
	## each chunk only.
	if not _announced:
		_announced = true
		print("[TerrainChunk] Chunk %s mesh built: %d vertices" % [coord, verts.size()])


## Create shared material for all chunks
## Uses terrain shader with vertex colors if available, falls back to StandardMaterial3D
static func _create_shared_material() -> void:
	var shader_path := "res://terrain/shaders/terrain.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader := load(shader_path) as Shader
		if shader:
			var shader_mat := ShaderMaterial.new()
			shader_mat.shader = shader

			# Load ground textures (jungle floor from Poly Haven CC0)
			var diff_path := "res://terrain/textures/jungle_floor_diff.jpg"
			var norm_path := "res://terrain/textures/jungle_floor_normal.jpg"
			var rough_path := "res://terrain/textures/jungle_floor_rough.jpg"

			if ResourceLoader.exists(diff_path):
				var diff_tex := load(diff_path) as Texture2D
				if diff_tex:
					shader_mat.set_shader_parameter("ground_diffuse", diff_tex)
					print("[TerrainChunk] Loaded ground diffuse texture")

			if ResourceLoader.exists(norm_path):
				var norm_tex := load(norm_path) as Texture2D
				if norm_tex:
					shader_mat.set_shader_parameter("ground_normal", norm_tex)
					print("[TerrainChunk] Loaded ground normal texture")

			if ResourceLoader.exists(rough_path):
				var rough_tex := load(rough_path) as Texture2D
				if rough_tex:
					shader_mat.set_shader_parameter("ground_roughness", rough_tex)
					print("[TerrainChunk] Loaded ground roughness texture")

			shader_mat.set_shader_parameter("ground_texture_scale", 0.08)  # ~12m per tile
			shader_mat.set_shader_parameter("ground_texture_blend", 0.35)  # Subtle blend

			shared_material = shader_mat
			_using_shader = true
			print("[TerrainChunk] Using terrain shader with ground textures")
			return

	var fallback_mat := StandardMaterial3D.new()
	fallback_mat.albedo_color = Color(0.3, 0.5, 0.2)
	fallback_mat.roughness = 0.9
	fallback_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fallback_mat.vertex_color_use_as_albedo = true
	fallback_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	shared_material = fallback_mat
	_using_shader = false
	print("[TerrainChunk] Using fallback standard material")


static func is_using_shader() -> bool:
	return _using_shader


static func set_shader_texture(param_name: String, texture: Texture2D) -> void:
	if not _using_shader or not shared_material:
		return
	var shader_mat := shared_material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter(param_name, texture)


static func set_shader_parameters(params: Dictionary) -> void:
	if not _using_shader or not shared_material:
		return
	var shader_mat := shared_material as ShaderMaterial
	if shader_mat:
		for key: String in params:
			shader_mat.set_shader_parameter(key, params[key])


## Terrain coloring with vegetation type override
## VegetationManager.TerrainType values:
## 0=CLEAR, 1=RICE_PADDY, 2=GRASSLAND, 3=LIGHT_JUNGLE, 4=MEDIUM_JUNGLE, 5=HEAVY_JUNGLE
func _get_terrain_color(_h: float, _normalized_h: float, local_x: float, local_z: float, vegetation_terrain: PackedByteArray, bundles_per_chunk: int) -> Color:
	if not vegetation_terrain.is_empty() and bundles_per_chunk > 0:
		var bundle_meters: float = chunk_size / float(bundles_per_chunk)
		var bx: int = int(local_x / bundle_meters)
		var bz: int = int(local_z / bundle_meters)
		if bx >= 0 and bx < bundles_per_chunk and bz >= 0 and bz < bundles_per_chunk:
			var idx: int = bz * bundles_per_chunk + bx
			if idx < vegetation_terrain.size():
				var terrain_type: int = vegetation_terrain[idx]
				match terrain_type:
					1:  # RICE_PADDY
						return Color(0.42, 0.58, 0.22)
					5:  # HEAVY_JUNGLE
						return Color(0.10, 0.22, 0.07)

	# UNIFORM BASE GREEN - no height variation
	return Color(0.18, 0.35, 0.12)


## Re-derive ONLY the samples and quads a heightmap edit touched, in place, and hand the
## surface back. The chunk NODE survives: no MeshInstance3D churn, no StaticBody3D destroyed
## and re-added to Jolt, no re-classification of vegetation.
##
## cell_rect is in this chunk's own sample coordinates. A sample at x feeds the quads at x-1
## and x, so the quad span is the sample span widened by one on the low side.
##
## Returns false when the chunk has no patch cache yet - the caller then does a full build,
## which arms the cache (see _keep_patch_cache). The first shell on a chunk pays full price;
## every later one on the same chunk does not, and shells cluster.
func patch_mesh(region_data: PackedFloat32Array, h_scale: float, cell_rect: Rect2i) -> bool:
	if not _keep_patch_cache or _grid_v.is_empty() or _verts.is_empty():
		return false
	height_scale = h_scale
	var data_width: int = grid_resolution + 1
	if region_data.size() < data_width * data_width:
		return false

	var step: float = chunk_size / float(grid_resolution)
	var vx0: int = clampi(cell_rect.position.x, 0, data_width - 1)
	var vz0: int = clampi(cell_rect.position.y, 0, data_width - 1)
	var vx1: int = clampi(cell_rect.position.x + cell_rect.size.x, 0, data_width - 1)
	var vz1: int = clampi(cell_rect.position.y + cell_rect.size.y, 0, data_width - 1)

	StallLedger.begin("mesh.patch_grid")
	for z in range(vz0, vz1 + 1):
		for x in range(vx0, vx1 + 1):
			var gi: int = z * data_width + x
			var local_x: float = x * step
			var local_z: float = z * step
			var norm_h: float = region_data[gi]
			var h: float = norm_h * height_scale
			_grid_v[gi] = Vector3(local_x, h, local_z)
			_grid_c[gi] = _get_terrain_color(h, norm_h, local_x, local_z,
				_veg_bytes, _veg_bundles)
			_height_samples[gi] = h
	StallLedger.end()

	StallLedger.begin("mesh.patch_quads")
	var qx0: int = maxi(0, vx0 - 1)
	var qz0: int = maxi(0, vz0 - 1)
	var qx1: int = mini(grid_resolution - 1, vx1)
	var qz1: int = mini(grid_resolution - 1, vz1)
	for z in range(qz0, qz1 + 1):
		for x in range(qx0, qx1 + 1):
			var i: int = z * data_width + x
			var v0: Vector3 = _grid_v[i]
			var v1: Vector3 = _grid_v[i + 1]
			var v2: Vector3 = _grid_v[i + data_width]
			var v3: Vector3 = _grid_v[i + data_width + 1]
			var n1: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
			if n1.y < 0.0:
				n1 = -n1
			var n2: Vector3 = (v3 - v1).cross(v2 - v1).normalized()
			if n2.y < 0.0:
				n2 = -n2
			var w: int = (z * grid_resolution + x) * 6
			_verts[w] = v0; _norms[w] = n1; _cols[w] = _grid_c[i]
			_verts[w + 1] = v1; _norms[w + 1] = n1; _cols[w + 1] = _grid_c[i + 1]
			_verts[w + 2] = v2; _norms[w + 2] = n1; _cols[w + 2] = _grid_c[i + data_width]
			_verts[w + 3] = v1; _norms[w + 3] = n2; _cols[w + 3] = _grid_c[i + 1]
			_verts[w + 4] = v3; _norms[w + 4] = n2; _cols[w + 4] = _grid_c[i + data_width + 1]
			_verts[w + 5] = v2; _norms[w + 5] = n2; _cols[w + 5] = _grid_c[i + data_width]
	StallLedger.end()

	StallLedger.begin("mesh.patch_surface")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = am
	mesh_instance.material_override = shared_material
	StallLedger.end()
	return true


## Arm the patch cache. The next full build_mesh keeps its working arrays so the shell after
## that can patch instead of rebuild.
func arm_patch_cache() -> void:
	_keep_patch_cache = true


## Re-seat the heightfield on the patched samples. The shape is one array assignment; the
## body and its Jolt registration are untouched, which is the other half of the saving.
func refresh_collision() -> void:
	if collision_body == null or collision_body.get_child_count() == 0:
		return
	var cs := collision_body.get_child(0) as CollisionShape3D
	if cs == null:
		return
	var shape := cs.shape as HeightMapShape3D
	if shape == null:
		return
	shape.map_data = _height_samples


## Terrain collision: a HEIGHTFIELD over the same samples the mesh was built from, not a
## trimesh over its triangles. This is what bullets and boots hit, so it was ruled in by the
## Summoner rather than assumed, and it ships with tools/probe_heightfield_shape.gd +
## tools/probe_terrain_collision.gd rather than with an argument.
##
## Why it is the same ground and not merely similar: the grid is regular, and Godot/Jolt split
## each cell on the SAME diagonal build_mesh does. Measured over 4,000 rays against an analytic
## surface, the two shapes disagree by 0.0002 m worst - float noise, not geometry.
##
## Two contracts that are easy to get wrong and are the whole reason this comment exists:
##   - HeightMapShape3D has NO cell size. It is ONE UNIT PER SAMPLE, so the shape carries a
##     (cell_size, 1, cell_size) scale.
##   - It is CENTRED on its own origin, so it is offset by half a chunk in X and Z to sit
##     where the mesh sits.
func create_raycast_collision() -> void:
	if collision_body:
		return

	var data_width: int = grid_resolution + 1
	if _height_samples.size() != data_width * data_width:
		return

	var shape := HeightMapShape3D.new()
	shape.map_width = data_width
	shape.map_depth = data_width
	shape.map_data = _height_samples

	collision_body = StaticBody3D.new()
	collision_body.name = "RaycastCollision"
	collision_body.collision_layer = 1  # Terrain layer
	collision_body.collision_mask = 0   # No response

	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.transform = Transform3D(
		Basis.IDENTITY.scaled(Vector3(cell_size, 1.0, cell_size)),
		Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5))
	collision_body.add_child(collision_shape)

	add_child(collision_body)


func unload() -> void:
	if mesh_instance:
		mesh_instance.mesh = null
	if collision_body:
		collision_body.queue_free()
		collision_body = null
