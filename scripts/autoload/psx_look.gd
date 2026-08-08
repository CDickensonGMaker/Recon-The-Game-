## psx_look.gd - the PSX render treatment (PS1_SETUP.md layers 1+3): low
## internal 3D resolution via scaling_3d_scale + the ps1_postprocess crush/
## dither pass. Driven by GameSettings.psx_look, OFF by default - perf
## numbers govern default-on (SHIP_AUDIT_2026-08-07.md S5).
## SOLE writer of viewport scaling_3d_scale: PSX look owns the scale when ON;
## the manual GameSettings.render_scale rung applies only when it is OFF.
extends CanvasLayer

const SHADER := preload("res://assets/shaders/ps1_postprocess.gdshader")
## Internal 3D render height when enabled (PS1_SETUP.md step 1: 480x270).
const TARGET_HEIGHT_PX: float = 270.0

var _rect: ColorRect


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
		return
	var view: Vector2 = vp.get_visible_rect().size
	var scale_3d: float = clampf(TARGET_HEIGHT_PX / maxf(view.y, 1.0), 0.1, 1.0)
	vp.scaling_3d_scale = scale_3d
	var mat: ShaderMaterial = _rect.material as ShaderMaterial
	mat.set_shader_parameter("internal_resolution", (view * scale_3d).floor())
