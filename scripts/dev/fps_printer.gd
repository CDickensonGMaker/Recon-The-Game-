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
## GPU and render-thread ms sampled EVERY FRAME, not once at report time. The old code read
## the driver timer a single time per 5 s window and printed that one frame's value as the
## window's GPU cost - one sample in ~150, quoted as if it described all of them.
var _gpu: Array[float] = []
var _render: Array[float] = []
var _vp_rid: RID = RID()
var _gpu_ever: bool = false
var _windows: int = 0
## Raw per-frame samples, so a summary can be recomputed by someone who does not trust ours.
## A percentile printed with no way to check it is an assertion, not a measurement.
var _raw: FileAccess = null
var _raw_path: String = ""
var _frame_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## The watchdog in GameSettings fails the run if nothing joins this group.
	add_to_group("fps_printer")
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	## Stall attribution rides with the printer: the walk that shows the drop is the only
	## run that can also say what was in it. Sentinels bracket every other node's
	## callbacks, so they are added FIRST and last-priority sorted by the SceneTree.
	FrameSentinel.install(self)
	## A benched frame must not be quantised to the panel. Vsync at 24-35 fps delivers
	## frames on 60Hz half-steps, which is both a pacing artefact and a throughput lie.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	## Every row states the scale it was DRAWN at, read off the live viewport. A row that
	## quotes a project setting is not a measurement of anything (fixed 2026-09-08).
	## The measurement contract (PERF_LEDGER) needs scale AND renderer on every number. The
	## renderer comes from the RENDERING SERVER: Godot strips
	## `rendering/renderer/rendering_method` on save when it equals the desktop default, so
	## the project setting agrees with reality by luck and proves nothing.
	print("[FPS] printer ATTACHED - %ss windows | vsync forced OFF | render scale %.3f (live) | mode %d | renderer %s/%s"
		% [WINDOW_S, get_viewport().scaling_3d_scale, get_viewport().scaling_3d_mode,
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name()])
	print("[FPS] texture state: %s" % _texture_state())
	_open_raw()


## One CSV per run under user://, never a shared or fixed name: two runs must not overwrite
## each other and neither may touch his logs. Frame id is monotonic across the whole run so
## windows can be reassembled in order.
func _open_raw() -> void:
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	_raw_path = "user://perf_raw_%s.csv" % stamp.replace("T", "_")
	_raw = FileAccess.open(_raw_path, FileAccess.WRITE)
	if _raw == null:
		push_error("[FPS] could not open %s - THIS RUN KEEPS NO RAW SAMPLES and its "
			% _raw_path + "percentiles cannot be independently recomputed.")
		return
	_raw.store_line("frame,window,frame_ms,gpu_ms,render_thread_ms")
	print("[FPS] raw samples -> %s (absolute: %s)"
		% [_raw_path, ProjectSettings.globalize_path(_raw_path)])


## The log states its own texture compression, so a VRAM-compression A/B cannot be
## mislabelled by remembering which run was which.
##
## THE WITNESS MOVED 2026-09-09. It was a canopy CARD sheet, chosen when those were the
## largest textures in the game. The card ring is retired (tree_cover_layer.gd) and no card
## sheet is drawn any more, so that witness reported the compression state of something the
## game never binds. It is now the US kit sheet - 17 MB, the largest single texture that is
## actually drawn, and on every frame the squad is on screen.
func _texture_state() -> String:
	const WITNESS := "res://assets/us/characters/recovered_ref_us_kit.png"
	var t: Texture2D = load(WITNESS) as Texture2D
	if t == null:
		return "UNKNOWN - witness texture did not load (%s)" % WITNESS
	var img: Image = t.get_image()
	if img == null:
		return "UNKNOWN - witness texture carries no image"
	var fmt: int = img.get_format()
	var compressed: bool = fmt >= Image.FORMAT_DXT1
	return "%s (witness %dx%d, format %d, %.1f MB)" % [
		"VRAM COMPRESSED" if compressed else "LOSSLESS/UNCOMPRESSED",
		img.get_width(), img.get_height(), fmt,
		float(img.get_data().size()) / 1048576.0]


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_frame_id += 1
	var ms: float = delta * 1000.0
	_worst_ms = maxf(_worst_ms, ms)
	_ms.append(ms)
	var g: float = RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var r: float = RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
	_gpu.append(g)
	_render.append(r)
	if g > 0.0:
		_gpu_ever = true
	if _raw != null:
		_raw.store_line("%d,%d,%.4f,%.4f,%.4f" % [_frame_id, _windows, ms, g, r])
	if _t < WINDOW_S:
		return
	var gpu: float = _mean(_gpu)
	var render_ms: float = _mean(_render)
	_windows += 1
	## `viewport_get_measured_render_time_cpu` is the RENDER THREAD, not the game thread.
	## Calling it "cpu" hid the render thread's own cost, so part of the frame was
	## attributed to nothing (corrected 2026-09-08).
	##
	## LABEL CORRECTION, 2026-09-08 (second pass), read straight out of Godot main.cpp:
	## `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` are **MAXIMA OVER A ONE-SECOND BUCKET**,
	## not per-frame values - `process_max = MAX(process_ticks, process_max)` every frame,
	## flushed and zeroed only when `frame > 1000000`. They are therefore named
	## `idle_max` / `phys_max` here, and a reader must never multiply them by a frame count
	## or read them as an average. That is why a 43ms `process` sat beside a 44 fps average
	## and the arithmetic looked impossible: nothing was wrong with the fps, the other
	## column was a worst-case.
	##
	## The former `game` column - their SUM - was worse than mislabelled: it added two
	## maxima that need not come from the same frame, and `TIME_PROCESS`'s span in main.cpp
	## also contains `RenderingServer::sync()` and `RenderingServer::draw()`, so renderer
	## backpressure was being printed as game-thread cost. **It is deleted, not renamed.**
	## Honest per-frame script time comes from the [STALL] lines below it.
	## The acceptance budgets are stated in median/p95/p99 (PERF_IMPLEMENTATION_PLAN, Targets),
	## so a row of avg + worst could not be judged against its own gate. Percentiles are of
	## FRAME TIME, so higher is worse and p99 is the tail he feels.
	print("[FPS] %.1f avg (worst frame %.1fms, 1%% low %.1f fps) | median %.1fms p95 %.1fms p99 %.1fms | scale %.2f | gpu %.2fms (window mean of %d) render_thread %.2fms | draw calls %d | primitives %d | idle_max %.2fms phys_max %.2fms nav_max %.2fms (1s bucket MAXIMA, not per-frame) | bodies %d pairs %d islands %d" % [
		float(_frames) / _t, _worst_ms, _one_percent_low(),
		_pct(50.0), _pct(95.0), _pct(99.0),
		get_viewport().scaling_3d_scale,
		gpu, _gpu.size(), render_ms,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))])
	var stall: String = StallLedger.report()
	if stall != "":
		print(stall)
	StallLedger.reset_window()
	## GPU ms reads 0.0 under the dummy renderer and stays 0.0 if measurement was never
	## enabled. Either way the row is not a GPU measurement and must say so out loud.
	if _windows == 3 and not _gpu_ever and DisplayServer.get_name() != "headless":
		push_error("[FPS] gpu ms has read 0.00 for 15s on a windowed run - "
			+ "the GPU timer is not reporting. Do not quote gpu ms from this log.")
	if _raw != null:
		_raw.flush()
	_t = 0.0
	_frames = 0
	_worst_ms = 0.0
	_ms.clear()
	_gpu.clear()
	_render.clear()


## Nearest-rank percentile of this window's frame times, in ms. Higher is worse.
func _pct(q: float) -> float:
	if _ms.is_empty():
		return 0.0
	var sorted: Array[float] = _ms.duplicate()
	sorted.sort()
	var i: int = clampi(int(ceil(q / 100.0 * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[i]


func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var t: float = 0.0
	for v: float in a:
		t += v
	return t / float(a.size())


func _exit_tree() -> void:
	if _raw != null:
		_raw.flush()
		_raw.close()
		_raw = null
		print("[FPS] raw samples closed: %s" % ProjectSettings.globalize_path(_raw_path))


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
