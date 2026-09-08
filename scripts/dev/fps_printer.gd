## fps_printer.gd - `--print-fps`: the shipped measurement instrument (audit 2026-08-04, W-4).
## Runs in EXPORTS - no scene load, no res://tests dependency, so it cannot null-crash a
## build the way `--perf-probe` did. One line every WINDOW_S to stdout; M-2/M-3 read these.
class_name FpsPrinter
extends Node

const WINDOW_S: float = 5.0

var _t: float = 0.0
var _frames: int = 0
var _worst_ms: float = 0.0
var _vp_rid: RID = RID()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	## Every row states the scale it was DRAWN at, read off the live viewport. A row that
	## quotes a project setting is not a measurement of anything (fixed 2026-09-08).
	print("[FPS] printer up - %ss windows | render scale %.3f (live) | mode %d"
		% [WINDOW_S, get_viewport().scaling_3d_scale, get_viewport().scaling_3d_mode])


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	if _t < WINDOW_S:
		return
	print("[FPS] %.1f avg (worst frame %.1fms) | scale %.2f | gpu %.2fms cpu %.2fms | draw calls %d | primitives %d | process %.1fms physics %.1fms" % [
		float(_frames) / _t, _worst_ms,
		get_viewport().scaling_3d_scale,
		RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid),
		RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_t = 0.0
	_frames = 0
	_worst_ms = 0.0
