## psx_look.gd - the PSX render treatment (PS1_SETUP.md layers 1-3): low
## internal 3D resolution via scaling_3d_scale, the per-mesh ps1_material
## vertex snap / affine warp (PsxMaterial), and the ps1_postprocess crush/
## dither pass. Driven by GameSettings.psx_look, OFF by default - perf
## numbers govern default-on (SHIP_AUDIT_2026-08-07.md S5).
## SOLE writer of viewport scaling_3d_scale: PSX look owns the scale when ON;
## the manual GameSettings.render_scale rung applies only when it is OFF.
## Layer 4 (fog) is deliberately NOT here: fog density is fenced by the
## fairness floor at game_world.gd:77-81 and belongs to MissionWeather.
extends CanvasLayer

const SHADER := preload("res://assets/shaders/ps1_postprocess.gdshader")
## Internal 3D render height when enabled (PS1_SETUP.md step 1: 480x270).
const TARGET_HEIGHT_PX: float = 270.0

var _rect: ColorRect
var _materials_on: bool = false


func _ready() -> void:
	## Below the default canvas (layer 0): the pass samples the screen after
	## the 3D render but before any UI draws, so HUD/menus stay crisp.
	layer = -10
	_rect = ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_rect.material = mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	var vp: Viewport = get_viewport()
	vp.size_changed.connect(apply)
	apply()


func set_enabled(on: bool) -> void:
	GameSettings.psx_look = on
	GameSettings.save_settings()
	apply()


func apply() -> void:
	var on: bool = GameSettings.psx_look
	_rect.visible = on
	var vp: Viewport = get_viewport()
	if not on:
		vp.scaling_3d_scale = GameSettings.render_scale
		_set_materials(false)
		return
	var view: Vector2 = vp.get_visible_rect().size
	var scale_3d: float = clampf(TARGET_HEIGHT_PX / maxf(view.y, 1.0), 0.1, 1.0)
	vp.scaling_3d_scale = scale_3d
	var internal: Vector2 = (view * scale_3d).floor()
	var mat: ShaderMaterial = _rect.material as ShaderMaterial
	mat.set_shader_parameter("internal_resolution", internal)
	## One pixel grid for both halves: vertices snap to the same lattice the
	## dither aligns to, so the wobble never fights the crush.
	PsxMaterial.snap_resolution = internal
	if _materials_on:
		PsxMaterial.refresh_uniforms()
	else:
		_set_materials(true)


## Converting the live tree is a one-frame hitch proportional to mesh count -
## acceptable for a settings toggle, and the usual path is set-then-load.
func _set_materials(on: bool) -> void:
	if on == _materials_on:
		return
	_materials_on = on
	var tree: SceneTree = get_tree()
	if on:
		PsxMaterial.apply(tree.root)
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
	else:
		if tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)
		PsxMaterial.restore(tree.root)


## Everything spawned while the look is on - NPCs, gibs, destructible chunks,
## streamed structures. A MeshInstance3D is often added before its mesh is
## assigned, so retry once deferred rather than converting only what is ready.
func _on_node_added(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi != null:
		if PsxMaterial.apply_one(mi) == 0:
			_retry_convert.call_deferred(mi)
		return
	var mmi := node as MultiMeshInstance3D
	if mmi != null and PsxMaterial.apply_multi(mmi) == 0:
		_retry_convert.call_deferred(mmi)


func _retry_convert(gi: GeometryInstance3D) -> void:
	if not _materials_on or not is_instance_valid(gi):
		return
	var mi := gi as MeshInstance3D
	if mi != null:
		PsxMaterial.apply_one(mi)
		return
	var mmi := gi as MultiMeshInstance3D
	if mmi != null:
		PsxMaterial.apply_multi(mmi)
