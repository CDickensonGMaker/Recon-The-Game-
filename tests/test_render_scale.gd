## test_render_scale.gd - ADR-026 Part A.4 guard.
## The ratified sub-native render scale lives in TWO places that must agree:
## project.godot's rendering/scaling_3d/scale, and GameSettings.DEFAULT_RENDER_SCALE -
## because PsxLook.apply() runs at every boot and writes the GameSettings value straight
## over the project value. From 2026-08-07 to 2026-09-08 they disagreed (0.75 vs 1.0) and
## the game shipped full-resolution frames while the ADR and every perf row said 0.75.
## This test exists so that can never be silent again.
## Run: godot --headless --path . res://tests/test_render_scale.tscn
extends Node

const RATIFIED: float = 0.75  ## ADR-026 Part A.4: scaling_3d/scale <= 0.75

var _failures: int = 0


func _ready() -> void:
	print("=== ADR-026 A.4 RENDER SCALE ===")
	var project_scale: float = float(
		ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))
	var project_mode: int = int(ProjectSettings.get_setting("rendering/scaling_3d/mode", 0))

	_ok("project.godot scaling_3d/scale <= %.2f (is %.3f)" % [RATIFIED, project_scale],
		project_scale <= RATIFIED + 0.0001)
	_ok("project.godot scaling_3d/mode = 5 NEAREST (is %d)" % project_mode, project_mode == 5)
	_ok("GameSettings.DEFAULT_RENDER_SCALE matches project.godot (%.3f vs %.3f)"
		% [GameSettings.DEFAULT_RENDER_SCALE, project_scale],
		is_equal_approx(GameSettings.DEFAULT_RENDER_SCALE, project_scale))
	_ok("the default rung is a real RENDER_SCALE_STEPS rung",
		GameSettings.RENDER_SCALE_STEPS.has(GameSettings.DEFAULT_RENDER_SCALE))

	## The live viewport is what the frame is actually drawn at. PsxLook is the sole
	## writer; if it has run, this is the number a perf row may quote - nothing else.
	PsxLook.apply()
	if GameSettings.has_flag(GameSettings.PERF_BEFORE_FLAG):
		print("  SKIP live viewport check - --perf-before deliberately holds 1.0 (%.3f)"
			% get_viewport().scaling_3d_scale)
	else:
		_ok("live viewport scaling_3d_scale = the ratified value after PsxLook.apply() (%.3f)"
			% get_viewport().scaling_3d_scale,
			is_equal_approx(get_viewport().scaling_3d_scale, RATIFIED))

	print("=== %s ===" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _ok(label: String, cond: bool) -> void:
	if cond:
		print("  OK   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)
