## jungle_patch_layer.gd - Pre-composed 12m jungle tiles instead of lone trees.
##
## The old layer scattered single procedural trees per bundle: a palm grove, not
## a jungle. This one stamps AUTHORED patches (tools/make_jungle_patches.py) -
## a bamboo grove reads as a grove, a deadfall as a blowdown, a canopy stand has
## vines actually strung between its trees.
##
## Each patch is one merged mesh, so a whole 12x12m tile of jungle is ONE
## MultiMesh instance. A chunk holds one MultiMeshInstance3D per patch type it
## used, which is a handful of draw calls for an entire chunk of jungle.
##
## Patch choice is driven by the SAME TerrainType grid the old layer used, via
## the density class baked into patches.json:
##   GRASSLAND -> open/light    LIGHT_JUNGLE -> light
##   MEDIUM_JUNGLE -> medium    HEAVY_JUNGLE -> dense/wall
## so the mission's patch-noise still carves the open ground and the thickets.
class_name JunglePatchLayer
extends Node3D

const PATCH_DIR := "res://assets/models/vegetation/patches/"
const MANIFEST := PATCH_DIR + "patches.json"
const SWAY_SHADER := "res://terrain/shaders/vegetation_sway.gdshader"

## THE PADDY WATER. A rice paddy is a flooded pan, and the terrain already knows how to
## render exactly that: water_swamp.gdshader describes itself as "shallow, vegetated
## wetland" and has ripples, muck, depth fade and a shore fade.
##
## The patches used to BAKE a flat quad of water into the vegetation mesh. That quad got
## merged into the one big patch surface and rendered through vegetation_sway.gdshader -
## which is OPAQUE, alpha-scissored and lambert-lit. So the water was not water. It was a
## dark leaf lying flat, and a rice paddy read as a black hole in the ground.
##
## Now the patch DECLARES its pan in patches.json ("water": {level, half, at}) and we
## render it here with the terrain's own water shader. One source of truth for water.
const WATER_SHADER := "res://terrain/water/water_swamp.gdshader"
const PALETTE_TEX := PATCH_DIR + "jungle_palette.png"

## Terrain types (mirrors GameplayGrid.TerrainType - kept local to avoid a hard dep)
const T_CLEAR := 0
const T_RICE_PADDY := 1
const T_GRASSLAND := 2
const T_LIGHT_JUNGLE := 3
const T_MEDIUM_JUNGLE := 4
const T_HEAVY_JUNGLE := 5

## Which density classes may serve each terrain type (weighted by repetition).
const TYPE_DENSITY := {
	T_RICE_PADDY: ["paddy"],
	T_GRASSLAND: ["open", "open", "light"],
	T_LIGHT_JUNGLE: ["light", "light", "medium"],
	T_MEDIUM_JUNGLE: ["medium", "medium", "light", "dense"],
	T_HEAVY_JUNGLE: ["dense", "dense", "wall", "medium"],
}

## Jitter each tile off its grid node and spin it freely. The patches now
## OVERHANG their tile (plants sampled past the edge), so they interlock instead
## of sitting in their own square - which is what made the first pass read as a
## grid of blobs. Snapping to 90 degrees would still repeat the overhang pattern,
## so we take any angle.
@export var tile_jitter: float = 2.2

@export var tile_meters: float = 12.0
@export var enabled: bool = true
## Skip patches on ground steeper than this (they are modelled flat-footed).
@export var max_slope_degrees: float = 26.0
## Chance a legal cell actually gets a patch. < 1.0 opens the jungle up.
@export var fill_chance: float = 0.78
@export var wind_strength: float = 0.30
@export var flutter_strength: float = 0.07

## --- Draw budget ------------------------------------------------------------
## A patch is ~6-26k tris. A 256m chunk is 21x21 tiles, so a chunk of solid
## jungle is MILLIONS of triangles - far past what this game's GPU target eats.
## So patches are bucketed into sub-cells and given a hard visibility range:
## only the buckets near the camera ever draw, and BillboardVegetation carries
## the far field (that is exactly what it is for).
## Raise view_distance for beefy GPUs; drop it (or fill_chance) for weak ones.
@export var subcell_meters: float = 36.0
## Full-detail patches (grass, fern, bush, moss + structure) out to here...
@export var near_distance: float = 46.0
## ...then the structure-only `_far` twin (trees, bamboo, vines) out to here.
@export var view_distance: float = 128.0
@export var view_fade_margin: float = 14.0

var _by_density: Dictionary = {}          ## density -> Array[String] names
var _mesh: Dictionary = {}                ## name -> Mesh (full detail)
var _mesh_far: Dictionary = {}            ## name -> Mesh (structure only)
var _material: ShaderMaterial
var _chunk_nodes: Dictionary = {}         ## Vector2i -> Array[MultiMeshInstance3D]
var _loaded := false

## name -> {level: float, half: float, at: [x, y]} for patches that declare a flooded pan.
var _water: Dictionary = {}
## name -> PlaneMesh sized to that patch's pan.
var _water_mesh: Dictionary = {}
var _water_material: ShaderMaterial = null


func _ready() -> void:
	_load_patches()


func _load_patches() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		push_warning("[JunglePatch] no manifest at %s - patch layer OFF" % MANIFEST)
		enabled = false
		return
	var txt := FileAccess.get_file_as_string(MANIFEST)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("patches"):
		push_warning("[JunglePatch] manifest unreadable - patch layer OFF")
		enabled = false
		return
	var dict := data as Dictionary
	tile_meters = float(dict.get("tile_m", tile_meters))
	for entry_v: Variant in (dict["patches"] as Array):
		var entry := entry_v as Dictionary
		var nm := String(entry.get("name", ""))
		var density := String(entry.get("density", "medium"))
		var mesh := _load_patch_mesh(PATCH_DIR + nm + ".glb")
		if mesh == null:
			continue
		_mesh[nm] = mesh
		var far := _load_patch_mesh(PATCH_DIR + nm + "_far.glb")
		if far != null:
			_mesh_far[nm] = far
		if not _by_density.has(density):
			_by_density[density] = []
		(_by_density[density] as Array).append(nm)

		# Flooded pans, declared by the patch and rendered with the terrain's water.
		# A LIST: patch_paddy_quad is cross-bunded into FOUR pans, each its own sheet.
		if entry.has("water"):
			var pans := entry["water"] as Array
			if not pans.is_empty():
				_water[nm] = pans
				_water_mesh[nm] = _build_pan_mesh(pans)

	_material = ShaderMaterial.new()
	_material.shader = load(SWAY_SHADER)
	_material.set_shader_parameter("wind_strength", wind_strength)
	_material.set_shader_parameter("flutter_strength", flutter_strength)
	_material.set_shader_parameter("albedo_tint", Color.WHITE)
	# CRITICAL: every patch is ONE surface whose colours come from a palette
	# atlas (1 texel per colour, UVs point at them). material_override throws
	# away the GLB's own material, so without re-binding the atlas here the whole
	# jungle renders blank.
	var pal := load(PALETTE_TEX) as Texture2D
	if pal == null:
		push_error("[JunglePatch] palette atlas missing at %s - jungle would render blank"
			% PALETTE_TEX)
		enabled = false
		return
	_material.set_shader_parameter("albedo_tex", pal)

	if not _water.is_empty():
		var wsh := load(WATER_SHADER) as Shader
		if wsh == null:
			# Do not silently fall back to a black quad - that is the bug we just fixed.
			push_error("[JunglePatch] %s missing - paddies would render dry" % WATER_SHADER)
		else:
			_water_material = ShaderMaterial.new()
			_water_material.shader = wsh
			_water_material.render_priority = 1   # draw after the vegetation it sits under

	if _mesh.is_empty():
		push_warning("[JunglePatch] no patch meshes loaded - patch layer OFF")
		enabled = false
	else:
		print("[JunglePatch] %d patches across %d density classes"
			% [_mesh.size(), _by_density.size()])


func _load_patch_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate() as Node3D
	var mesh := _first_mesh(root)
	root.queue_free()
	return mesh


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for c: Node in node.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


## Lay patches over one terrain chunk.
##   terrain: PackedByteArray of TerrainType, `bundles` per side, `bundle_m` each
func generate_for_chunk(chunk_coord: Vector2i, terrain: PackedByteArray,
		bundles: int, bundle_m: float, heightmap: Object, chunk_size: float) -> void:
	if not enabled or _mesh.is_empty():
		return
	clear_chunk(chunk_coord)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk_coord) ^ 0x5EED
	var min_dot := cos(deg_to_rad(max_slope_degrees))
	var origin := Vector3(chunk_coord.x * chunk_size, 0.0, chunk_coord.y * chunk_size)
	var cells := int(chunk_size / tile_meters)

	# (subcell, name) -> Array[Transform3D]; bucketing by subcell is what lets a
	# distant slab of jungle cull as a unit instead of drawing the whole chunk.
	var batches: Dictionary = {}

	for cz in cells:
		for cx in cells:
			var lx := (cx + 0.5) * tile_meters
			var lz := (cz + 0.5) * tile_meters
			var wx := origin.x + lx
			var wz := origin.z + lz

			# terrain type at this cell centre, read off the bundle grid
			var bx := clampi(int(lx / bundle_m), 0, bundles - 1)
			var bz := clampi(int(lz / bundle_m), 0, bundles - 1)
			var ttype := int(terrain[bz * bundles + bx])
			if not TYPE_DENSITY.has(ttype):
				continue                      # CLEAR / water: bare

			# A PADDY FIELD IS CONTIGUOUS. Every other density is a scatter, and skipping
			# a tile just thins the jungle - fine. But a paddy is a MOSAIC OF BUNDED PANS:
			# skip one and you punch a hole in the middle of the field where the water
			# drains out and the bunds run into nothing. So paddies always fill.
			var is_paddy := ttype == T_RICE_PADDY
			if not is_paddy and rng.randf() > fill_chance:
				continue

			var normal := heightmap.get_normal_world(wx, wz) as Vector3
			if normal.dot(Vector3.UP) < min_dot:
				continue                      # too steep - patches are flat-footed

			var pool := TYPE_DENSITY[ttype] as Array
			var density := String(pool[rng.randi_range(0, pool.size() - 1)])
			var names := _by_density.get(density, []) as Array
			if names.is_empty():
				continue
			var nm := String(names[rng.randi_range(0, names.size() - 1)])

			var h := heightmap.sample_world(wx, wz) as float
			var xf := Transform3D()
			# 90-degree steps only: the patches are authored to tile that way.
			# A paddy's bund ring is 4-fold symmetric, so a quarter turn maps it onto
			# itself and the bunds still meet their neighbours.
			xf = xf.rotated(Vector3.UP, TAU * 0.25 * rng.randi_range(0, 3))
			if not is_paddy:
				# THE SCALE JITTER MUST NOT TOUCH A PADDY. It is what stops a jungle
				# looking stamped - but it turns a 12 m tile into an 11.0-13.2 m tile,
				# and a bund that is meant to butt against its neighbour's then misses by
				# up to a metre. A paddy field is a grid; a grid has to be on the grid.
				xf = xf.scaled(Vector3.ONE * rng.randf_range(0.92, 1.10))
			xf.origin = Vector3(wx, h, wz)

			var sub := Vector2i(int(lx / subcell_meters), int(lz / subcell_meters))
			var key := "%d_%d|%s" % [sub.x, sub.y, nm]
			if not batches.has(key):
				batches[key] = []
			(batches[key] as Array).append(xf)

	var nodes: Array[MultiMeshInstance3D] = []
	for key_v: Variant in batches:
		var key := String(key_v)
		var parts := key.split("|")
		var nm := parts[1]
		var xforms := batches[key] as Array

		# bucket centre: visibility range is measured from the node's origin, so
		# the instances are re-based around it
		var centre := Vector3.ZERO
		for i in xforms.size():
			centre += (xforms[i] as Transform3D).origin
		centre /= maxf(1.0, float(xforms.size()))
		var local: Array[Transform3D] = []
		for i in xforms.size():
			var t := xforms[i] as Transform3D
			t.origin -= centre
			local.append(t)

		# NEAR: everything, close in.
		nodes.append(_make_bucket(
			"%s_%s_%d_%d" % [nm, parts[0], chunk_coord.x, chunk_coord.y],
			_mesh[nm], local, centre, 0.0, near_distance))

		# FAR: structure only (no grass/fern/bush/moss/leaf-sprays), picking up
		# where NEAR fades out. This is what keeps a chunk of solid jungle from
		# being a 4M-triangle bill.
		if _mesh_far.has(nm):
			nodes.append(_make_bucket(
				"%s_%s_%d_%d_far" % [nm, parts[0], chunk_coord.x, chunk_coord.y],
				_mesh_far[nm], local, centre, near_distance, view_distance))

		# THE FLOODED PANS. All of a patch's pans are baked into ONE mesh, so a
		# cross-bunded tile with four sheets still costs a single MultiMesh - and a whole
		# chunk of rice paddy costs ONE extra draw call, not one per tile, let alone one
		# per pan.
		#
		# The pans ride the tile's own transform, so they inherit its 90-degree yaw and
		# stay inside their bunds whichever way it landed.
		#
		# No near/far split: water has no detail to drop, and a paddy that DRIED UP at
		# 46 m would be far more noticeable than the triangles it saved.
		if _water.has(nm) and _water_material != null:
			nodes.append(_make_water_bucket(
				"%s_%s_%d_%d_water" % [nm, parts[0], chunk_coord.x, chunk_coord.y],
				_water_mesh[nm], local, centre))
	_chunk_nodes[chunk_coord] = nodes


## One mesh holding every pan this patch declares, in the patch's own local space.
func _build_pan_mesh(pans: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# Each pan is subdivided rather than a single quad: the swamp shader ripples the
	# surface and fades it at the shore, and both need vertices to work with. A bare quad
	# would band across a 12 m pan.
	const CUTS := 6
	for pan_v: Variant in pans:
		var pan := pan_v as Dictionary
		var at: Array = pan.get("at", [0.0, 0.0])
		var cx := float(at[0])
		var cz := float(at[1])
		var y := float(pan.get("level", 0.055))
		# half is [hx, hy] - a paddy that is only wet on one side of the tile has a
		# RECTANGULAR pan, not a square one.
		var hh: Array = pan.get("half", [6.0, 6.0])
		var hx := float(hh[0])
		var hy := float(hh[1])
		var base := verts.size()
		for r in range(CUTS + 1):
			for c in range(CUTS + 1):
				var u := float(c) / float(CUTS)
				var v := float(r) / float(CUTS)
				verts.append(Vector3(cx + (u - 0.5) * hx * 2.0, y,
					cz + (v - 0.5) * hy * 2.0))
				normals.append(Vector3.UP)
				uvs.append(Vector2(u, v))
		for r in range(CUTS):
			for c in range(CUTS):
				var i0 := base + r * (CUTS + 1) + c
				var i1 := i0 + 1
				var i2 := i0 + CUTS + 1
				var i3 := i2 + 1
				idx.append_array([i0, i2, i1, i1, i2, i3])

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _make_water_bucket(nm: String, mesh: Mesh, xforms: Array[Transform3D],
		centre: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = _water_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = centre
	# runs to the full view distance - see the note at the call site
	mmi.visibility_range_end = view_distance
	mmi.visibility_range_end_margin = view_fade_margin
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	return mmi


func _make_bucket(nm: String, mesh: Mesh, xforms: Array[Transform3D],
		centre: Vector3, range_begin: float, range_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = centre
	if range_begin > 0.0:
		mmi.visibility_range_begin = range_begin
		mmi.visibility_range_begin_margin = view_fade_margin
	mmi.visibility_range_end = range_end
	mmi.visibility_range_end_margin = view_fade_margin
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	return mmi


func clear_chunk(chunk_coord: Vector2i) -> void:
	if not _chunk_nodes.has(chunk_coord):
		return
	for n: MultiMeshInstance3D in (_chunk_nodes[chunk_coord] as Array):
		if is_instance_valid(n):
			n.queue_free()
	_chunk_nodes.erase(chunk_coord)


func set_chunk_visible(chunk_coord: Vector2i, vis: bool) -> void:
	if not _chunk_nodes.has(chunk_coord):
		return
	for n: MultiMeshInstance3D in (_chunk_nodes[chunk_coord] as Array):
		if is_instance_valid(n):
			n.visible = vis
