## fps_printer.gd - `--print-fps`: the shipped measurement instrument (audit 2026-08-04, W-4).
## Runs in EXPORTS - no scene load, no res://tests dependency, so it cannot null-crash a
## build the way `--perf-probe` did. One line every WINDOW_S to stdout; M-2/M-3 read these.
class_name FpsPrinter
extends Node

const WINDOW_S: float = 5.0

var _t: float = 0.0
var _frames: int = 0
var _worst_ms: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[FPS] printer up - %ss windows" % WINDOW_S)


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	if _t < WINDOW_S:
		return
	print("[FPS] %.1f avg (worst frame %.1fms) | draw calls %d | primitives %d | process %.1fms physics %.1fms" % [
		float(_frames) / _t, _worst_ms,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_t = 0.0
	_frames = 0
	_worst_ms = 0.0
