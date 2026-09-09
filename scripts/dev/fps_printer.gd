## fps_printer.gd - `--print-fps`: the shipped measurement instrument (audit 2026-08-04, W-4).
## Runs in EXPORTS - no scene load, no res://tests dependency, so it cannot null-crash a
## build the way `--perf-probe` did. One line every WINDOW_S to stdout; M-2/M-3 read these.
class_name FpsPrinter
extends Node

const WINDOW_S: float = 5.0

var _t: float = 0.0
var _frames: int = 0
var _worst_ms: float = 0.0
var _ms: Array[float] = []
var _vp_rid: RID = RID()
var _gpu_ever: bool = false
var _windows: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## The watchdog in GameSettings fails the run if nothing joins this group.
	add_to_group("fps_printer")
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	## A benched frame must not be quantised to the panel. Vsync at 24-35 fps delivers
	## frames on 60Hz half-steps, which is both a pacing artefact and a throughput lie.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	## Every row states the scale it was DRAWN at, read off the live viewport. A row that
	## quotes a project setting is not a measurement of anything (fixed 2026-09-08).
	print("[FPS] printer ATTACHED - %ss windows | vsync forced OFF | render scale %.3f (live) | mode %d"
		% [WINDOW_S, get_viewport().scaling_3d_scale, get_viewport().scaling_3d_mode])


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	var ms: float = delta * 1000.0
	_worst_ms = maxf(_worst_ms, ms)
	_ms.append(ms)
	if _t < WINDOW_S:
		return
	var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
	if gpu > 0.0:
		_gpu_ever = true
	_windows += 1
	## `viewport_get_measured_render_time_cpu` is the RENDER THREAD, not the game thread.
	## Calling it "cpu" hid the game thread entirely, so ~24% of the frame was attributed
	## to nothing. `game_ms` is that missing half (corrected 2026-09-08).
	print("[FPS] %.1f avg (worst frame %.1fms, 1%% low %.1f fps) | scale %.2f | gpu %.2fms render_thread %.2fms game %.2fms | draw calls %d | primitives %d | process %.2fms physics %.2fms" % [
		float(_frames) / _t, _worst_ms, _one_percent_low(),
		get_viewport().scaling_3d_scale,
		gpu, render_ms,
		(Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	## GPU ms reads 0.0 under the dummy renderer and stays 0.0 if measurement was never
	## enabled. Either way the row is not a GPU measurement and must say so out loud.
	if _windows == 3 and not _gpu_ever and DisplayServer.get_name() != "headless":
		push_error("[FPS] gpu ms has read 0.00 for 15s on a windowed run - "
			+ "the GPU timer is not reporting. Do not quote gpu ms from this log.")
	_t = 0.0
	_frames = 0
	_worst_ms = 0.0
	_ms.clear()


## Frame PACING, not throughput: the mean of the worst 1% of frames, as fps. A run that
## averages 30 and hitches to 8 is the "sluggish" complaint; the average alone hides it.
func _one_percent_low() -> float:
	if _ms.is_empty():
		return 0.0
	var sorted: Array[float] = _ms.duplicate()
	sorted.sort()
	var n: int = maxi(1, int(float(sorted.size()) * 0.01))
	var total: float = 0.0
	for i in range(sorted.size() - n, sorted.size()):
		total += sorted[i]
	return 1000.0 / (total / float(n))
