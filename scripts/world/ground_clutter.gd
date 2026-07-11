## ground_clutter.gd - Near-player ground-cover pass (PT5): grass tufts, rocks,
## fallen logs, mushrooms, flowers as billboard quads. One MultiMesh per
## texture, re-scattered deterministically as the player moves.
## Grass layers ride the 6-tri star-fan mesh (grass_fan.glb, batch-built by
## tools/make_jungle_vegetation.py) with the vegetation_sway wind shader;
## billboard quads remain the fallback if the GLB is absent.
class_name GroundClutter
extends Node3D

const RADIUS: float = 45.0
const RESCATTER_DIST: float = 22.0

const FAN_MESH_PATH := "res://assets/models/vegetation/grass_fan.glb"
const SWAY_SHADER_PATH := "res://terrain/shaders/vegetation_sway.gdshader"

## texture path, count, quad size (w,h), y_sink, jungle-only, star-fan mesh
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
var _mmis: Array[MultiMeshInstance3D] = []
var _fan_layers: Array[bool] = []
var _last_center: Vector3 = Vector3(99999, 0, 99999)


## Shared PSX wind material: sway masked by vertex color (R lean / G flutter),
## scissor + cull off + nearest to match the billboard clutter recipe.
## gore_lab.gd reuses this for its bench palms and grass patches.
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


## First MeshInstance3D mesh inside a GLB scene (null if missing/empty).
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
	for layer in LAYERS:
		var use_fan: bool = bool(layer[5]) and fan_mesh != null
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = int(layer[1])
		if use_fan:
			mm.mesh = fan_mesh
			var fan_tex: Texture2D = load(str(layer[0])) as Texture2D
			mmi.material_override = make_sway_material(fan_tex, 0.18, 0.05)
		else:
			var quad := QuadMesh.new()
			quad.size = layer[2]
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = load(str(layer[0]))
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.4
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 crunch
			quad.material = mat
			mm.mesh = quad
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mmis.append(mmi)
		_fan_layers.append(use_fan)


var _poll: float = 0.0


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0.0
	var center := world.player.global_position
	if center.distance_to(_last_center) < RESCATTER_DIST:
		return
	_last_center = center
	_scatter(center)


func _scatter(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(center.x / RESCATTER_DIST), int(center.z / RESCATTER_DIST)))
	for li in range(LAYERS.size()):
		var layer: Array = LAYERS[li]
		var mm: MultiMesh = _mmis[li].multimesh
		var jungle_only: bool = layer[4]
		var half_h: float = (layer[2] as Vector2).y * 0.5
		for i in range(mm.instance_count):
			var a := rng.randf_range(0.0, TAU)
			var r := sqrt(rng.randf()) * RADIUS
			var pos := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var ok := true
			if world.gameplay_grid != null:
				if world.gameplay_grid.is_water(pos):
					ok = false
				elif jungle_only and world.gameplay_grid.get_vegetation(pos) < 0.3:
					ok = false
			if not ok:
				# park it out of sight
				mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -500, 0)))
				continue
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			var scale := rng.randf_range(0.75, 1.3)
			if _fan_layers[li]:
				# star-fan mesh: origin at the feet, unit 1m x 1m - stretch to
				# the layer's card size and plant on the ground
				var size: Vector2 = layer[2]
				pos.y = world.terrain_manager.get_height_at(pos) - float(layer[3])
				basis = basis.scaled(Vector3(size.x * scale, size.y * scale, size.x * scale))
			else:
				pos.y = world.terrain_manager.get_height_at(pos) + half_h - float(layer[3])
				basis = basis.scaled(Vector3(scale, scale, scale))
			mm.set_instance_transform(i, Transform3D(basis, pos))