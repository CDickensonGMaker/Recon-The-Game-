## ground_clutter.gd - Resident near-ground cover: grass tufts, rocks, fallen logs,
## mushrooms, flowers. Scattered ONCE across the AO behind the loading screen and bucketed
## per sub-cell, each bucket carrying a visibility_range so only the near ring ever draws
## (ADR-013 resident world; ADR-010 deterministic from mission_seed). Grass rides the 6-tri
## star-fan mesh (grass_fan.glb) with the vegetation_sway wind shader; the other layers are
## alpha-scissored billboard quads.
class_name GroundClutter
extends Node3D

## Sub-cell edge, metres. visibility_range culls a whole bucket by its CENTRE, so this dials
## LOD granularity against node count. NEAR_END is the bucket draw radius (the near ring the
## player sees), tuned to the old moving-ring reach so the near look is unchanged.
const SUBCELL: float = 32.0
const NEAR_END: float = 42.0
const NEAR_FADE: float = 8.0

## Per-sub-cell instance counts are the LAYERS ring-counts scaled by area from the old 45m
## ring, so resident density matches what the moving ring used to show at any instant.
const RING_AREA: float = 6361.73  # PI * 45 * 45

const FAN_MESH_PATH := "res://assets/world/vegetation/grass_fan.glb"
const SWAY_SHADER_PATH := "res://terrain/shaders/vegetation_sway.gdshader"

## texture path, ring-count, quad size (w,h), y_sink, jungle-only, star-fan mesh
const LAYERS := [
	["res://terrain/textures/clutter/grassland_2.png", 160, Vector2(1.4, 1.1), 0.05, false, true],
	["res://terrain/textures/clutter/grassland_1.png", 90, Vector2(1.0, 0.9), 0.05, false, true],
	["res://terrain/textures/clutter/grassland_3.png", 70, Vector2(1.2, 0.9), 0.05, false, true],
	["res://terrain/textures/clutter/herb_bush_picked2.png", 30, Vector2(0.9, 0.7), 0.02, true, false],
	["res://terrain/textures/clutter/rock.png", 22, Vector2(0.9, 0.55), 0.02, false, false],
	["res://terrain/textures/clutter/swamp_fallen_1.png", 10, Vector2(2.2, 1.0), 0.02, true, false],
	["res://terrain/textures/clutter/mushroom.png", 12, Vector2(0.4, 0.35), 0.0, true, false],
	["res://terrain/textures/clutter/blue_flower.png", 14, Vector2(0.35, 0.35), 0.0, false, false],
]

var world: GameWorld
var _templates: Array = []
## subcell -> Array[MultiMeshInstance3D] (one per layer that produced instances)
var _buckets: Dictionary = {}
## subcell -> PackedVector3Array of placed WORLD-space origins (probe truth: the
## Y each instance actually received; MultiMesh read-back is blind headless)
var placed_origins: Dictionary = {}
var _dirty_subcells: Dictionary = {}
var _flush_pending: bool = false


## Shared PSX wind material: sway masked by vertex color (R lean / G flutter), scissor +
## cull off + nearest. gore_lab.gd and ai_stress_arena.gd call this - keep the signature.
static func make_sway_material(tex: Texture2D, wind_strength: float = 0.35,
		flutter_strength: float = 0.06, alpha_scissor: float = 0.4) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SWAY_SHADER_PATH)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("flutter_strength", flutter_strength)
	mat.set_shader_parameter("alpha_scissor", alpha_scissor)
	return mat


## First MeshInstance3D mesh inside a GLB scene (null if missing/empty). Reused by callers.
static func load_glb_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	var mesh: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			mesh = mi.mesh
			break
		for c in n.get_children():
			stack.push_back(c)
	inst.free()
	return mesh


func setup(game_world: GameWorld) -> void:
	world = game_world
	var fan_mesh: Mesh = load_glb_mesh(FAN_MESH_PATH)
	if fan_mesh == null:
		push_warning("[CLUTTER] grass_fan.glb missing - grass falls back to billboards")

	# One shared mesh+material template per layer; every bucket reuses these resources.
	for layer: Array in LAYERS:
		var use_fan: bool = bool(layer[5]) and fan_mesh != null
		var size: Vector2 = layer[2]
		var mesh: Mesh
		var override_mat: Material = null
		if use_fan:
			mesh = fan_mesh
			override_mat = make_sway_material(load(str(layer[0])) as Texture2D, 0.18, 0.05)
		else:
			var quad := QuadMesh.new()
			quad.size = size
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = load(str(layer[0]))
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.4
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 crunch
			quad.material = mat
			mesh = quad
		var per_cell: int = int(ceil(float(int(layer[1])) * (SUBCELL * SUBCELL) / RING_AREA))
		_templates.append({
			"mesh": mesh, "override": override_mat, "fan": use_fan, "size": size,
			"y_sink": float(layer[3]), "jungle_only": bool(layer[4]), "per_cell": per_cell,
		})

	var subcells: int = int(ceil(world.map_size / SUBCELL))
	for sz in range(subcells):
		for sx in range(subcells):
			_scatter_subcell(Vector2i(sx, sz))
	world.terrain_manager.region_rebuilt.connect(_on_region_rebuilt)


## Deterministic per-subcell scatter (ADR-010: hash([subcell, layer, seed])).
## RNG draws are UNCONDITIONAL per candidate so a flipped accept (crater cleared
## a veg cell) never shifts the stream - untouched plants keep their transforms.
func _scatter_subcell(sc: Vector2i) -> void:
	_clear_subcell(sc)
	var origin_x: float = sc.x * SUBCELL
	var origin_z: float = sc.y * SUBCELL
	var centre := Vector3(origin_x + SUBCELL * 0.5, 0.0, origin_z + SUBCELL * 0.5)
	centre.y = world.terrain_manager.get_height_at(centre)
	var nodes: Array = []
	var origins := PackedVector3Array()
	for li in range(_templates.size()):
		var t: Dictionary = _templates[li]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sc, li, world.mission_seed])
		var xforms: Array[Transform3D] = []
		for _i in range(int(t.per_cell)):
			var pos := Vector3(origin_x + rng.randf() * SUBCELL, 0.0, origin_z + rng.randf() * SUBCELL)
			var ang: float = rng.randf_range(0.0, TAU)
			var plant_scale: float = rng.randf_range(0.75, 1.3)
			if not _accept(pos, bool(t.jungle_only)):
				continue
			var plant_basis := Basis(Vector3.UP, ang)
			var size: Vector2 = t.size
			if bool(t.fan):
				# star-fan: origin at the feet, stretched to the card size on the ground
				pos.y = world.terrain_manager.get_height_at(pos) - float(t.y_sink)
				plant_basis = plant_basis.scaled(Vector3(size.x * plant_scale, size.y * plant_scale, size.x * plant_scale))
			else:
				pos.y = world.terrain_manager.get_height_at(pos) + size.y * 0.5 - float(t.y_sink)
				plant_basis = plant_basis.scaled(Vector3.ONE * plant_scale)
			origins.append(pos)
			xforms.append(Transform3D(plant_basis, pos - centre))
		if not xforms.is_empty():
			nodes.append(_add_bucket(t, xforms, centre))
	if not nodes.is_empty():
		_buckets[sc] = nodes
		placed_origins[sc] = origins


func _clear_subcell(sc: Vector2i) -> void:
	if _buckets.has(sc):
		for n in _buckets[sc]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		_buckets.erase(sc)
	placed_origins.erase(sc)


## Coalesced deferred re-seat: build stamps fire 12-18 modify_terrain calls in one
## synchronous stretch (6 on the same fsb subcells), and clear_and_flatten updates
## the gameplay grid AFTER modify_terrain - so re-scattering synchronously would
## both waste work and read stale water/veg state in _accept. One flush, next frame.
func _on_region_rebuilt(world_rect: Rect2) -> void:
	var min_sc := Vector2i(int(floor(world_rect.position.x / SUBCELL)),
		int(floor(world_rect.position.y / SUBCELL)))
	var max_sc := Vector2i(int(floor(world_rect.end.x / SUBCELL)),
		int(floor(world_rect.end.y / SUBCELL)))
	for sz in range(min_sc.y, max_sc.y + 1):
		for sx in range(min_sc.x, max_sc.x + 1):
			_dirty_subcells[Vector2i(sx, sz)] = true
	if not _flush_pending:
		_flush_pending = true
		_flush_dirty.call_deferred()


func _flush_dirty() -> void:
	_flush_pending = false
	var dirty: Array = _dirty_subcells.keys()
	_dirty_subcells.clear()
	var subcells: int = int(ceil(world.map_size / SUBCELL))
	for sc: Vector2i in dirty:
		if sc.x < 0 or sc.y < 0 or sc.x >= subcells or sc.y >= subcells:
			continue
		_scatter_subcell(sc)


## Water is never clutter; jungle-only layers need real jungle density (matches the old ring).
func _accept(pos: Vector3, jungle_only: bool) -> bool:
	if world.gameplay_grid == null:
		return true
	if world.gameplay_grid.is_water(pos):
		return false
	if jungle_only and world.gameplay_grid.get_vegetation(pos) < 0.3:
		return false
	return true


func _add_bucket(t: Dictionary, xforms: Array[Transform3D], centre: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = t.mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if t.override != null:
		mmi.material_override = t.override
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = centre
	mmi.visibility_range_end = NEAR_END
	mmi.visibility_range_end_margin = NEAR_FADE
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	return mmi
