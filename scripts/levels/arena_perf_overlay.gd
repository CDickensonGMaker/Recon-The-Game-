## arena_perf_overlay.gd - live, targeted profiling HUD for the night-jungle bench.
## Shows total frame-ms with the CPU-vs-GPU split (so the binding side is obvious),
## draw-call/primitive/object counts, a rolling frame-time graph, a spike catcher that
## names the event behind a stutter, per-system CPU buckets, and F-key toggles that
## disable each cost source live so the FPS delta attributes it.
##
## GPU-ms is the REAL per-viewport figure from RenderingServer's render-time
## measurement (viewport_get_measured_render_time_gpu). If the driver returns 0 the
## overlay says so and derives bound-ness from frame-ms minus CPU-ms instead of
## inventing a number.
class_name ArenaPerfOverlay
extends CanvasLayer

## A frame slower than this flashes the graph red and fires the spike catcher.
const SPIKE_MS: float = 25.0
## Reference target line drawn on the graph (30 FPS floor).
const TARGET_MS: float = 1000.0 / 30.0
const HISTORY: int = 120
const GRAPH_CEIL_MS: float = 50.0


## Rolling frame-time graph. CanvasLayer cannot _draw, so the graph lives on a Control.
class GraphPanel extends Control:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var spiking: bool = false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.02, 0.55))
		var target_y: float = size.y * (1.0 - clampf(ArenaPerfOverlay.TARGET_MS / ArenaPerfOverlay.GRAPH_CEIL_MS, 0.0, 1.0))
		draw_line(Vector2(0, target_y), Vector2(size.x, target_y), Color(0.9, 0.8, 0.2, 0.5), 1.0)
		var spike_y: float = size.y * (1.0 - clampf(ArenaPerfOverlay.SPIKE_MS / ArenaPerfOverlay.GRAPH_CEIL_MS, 0.0, 1.0))
		draw_line(Vector2(0, spike_y), Vector2(size.x, spike_y), Color(0.9, 0.25, 0.2, 0.45), 1.0)
		if samples.size() < 2:
			return
		var line_col: Color = Color(1.0, 0.35, 0.3) if spiking else Color(0.45, 0.9, 0.55)
		var step: float = size.x / float(ArenaPerfOverlay.HISTORY - 1)
		var pts: PackedVector2Array = PackedVector2Array()
		var start: int = ArenaPerfOverlay.HISTORY - samples.size()
		for i in samples.size():
			var ms: float = samples[i]
			var y: float = size.y * (1.0 - clampf(ms / ArenaPerfOverlay.GRAPH_CEIL_MS, 0.0, 1.0))
			pts.append(Vector2(float(start + i) * step, y))
		draw_polyline(pts, line_col, 1.5)


var _stats: Label = null
var _graph: GraphPanel = null
var _vp_rid: RID = RID()

var _history: PackedFloat32Array = PackedFloat32Array()
## CPU sub-timings fed by the arena each frame (name -> ms). Everything the arena does
## not report falls into the engine "other _process" remainder.
var _cpu_buckets: Dictionary = {}
## Physics-side buckets (1s averages fed by the arena). Kept OUT of the process
## remainder above - _physics_process lives in a different monitor.
var _phys_buckets: Dictionary = {}
## Ray census window (reads the CombatManager counters as 1s deltas).
var _ray_t: float = 0.0
var _ray_frames: int = 0
var _ray_prev: Array[int] = [0, 0, 0, 0, 0]
var _ray_line: String = ""
## Events that happened this frame, so a spike can be blamed on one.
var _frame_events: Array[String] = []
var _spike_log: Array[String] = []

## Toggle targets, wired by setup(). Null-safe: a missing system just disables its key.
var _arena: Node = null
var _jungle: Node3D = null
var _clutter: Node3D = null
var _lights: Node3D = null
var _sun: DirectionalLight3D = null

var _jungle_on: bool = true
var _clutter_on: bool = true
var _lights_on: bool = true
var _chars_on: bool = true
var _debug_on: bool = true
var _shadows_on: bool = true


func setup(arena: Node, jungle: Node3D, clutter: Node3D, lights: Node3D, sun: DirectionalLight3D) -> void:
	_arena = arena
	_jungle = jungle
	_clutter = clutter
	_lights = lights
	_sun = sun
	_shadows_on = sun != null and sun.shadow_enabled


func _ready() -> void:
	layer = 2
	_vp_rid = get_viewport().get_viewport_rid()
	# Turn on per-viewport CPU+GPU render-time measurement so the split is a real
	# measurement, not an estimate.
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)

	_graph = GraphPanel.new()
	_graph.position = Vector2(12, 12)
	_graph.size = Vector2(360, 90)
	add_child(_graph)

	_stats = Label.new()
	_stats.position = Vector2(12, 108)
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	_stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_stats.add_theme_constant_override("outline_size", 4)
	add_child(_stats)


## The arena reports its own per-system timings here (ms). Called before the overlay's
## own _process each frame. physics_side buckets display in their own section so
## they never pollute the process-remainder subtraction.
func report_cpu_bucket(system: String, ms: float, physics_side: bool = false) -> void:
	if physics_side:
		_phys_buckets[system] = ms
	else:
		_cpu_buckets[system] = ms


## The arena (or any system) tags an event that plausibly spikes a frame, so the spike
## catcher can attribute a stutter instead of just reporting it.
func note_event(tag: String) -> void:
	_frame_events.append(tag)


func _process(delta: float) -> void:
	var fps: float = float(Engine.get_frames_per_second())
	var frame_ms: float = 1000.0 / maxf(1.0, fps)

	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nav_ms: float = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	var cpu_ms: float = process_ms + physics_ms

	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var render_cpu_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)

	var bound: String
	if gpu_ms > 0.01:
		bound = "GPU-BOUND" if gpu_ms >= cpu_ms + render_cpu_ms else "CPU-BOUND"
	else:
		# Driver gave no GPU timing this frame: derive from what is left of the frame
		# after CPU work, and say so - no fabricated number.
		var derived: float = maxf(0.0, frame_ms - cpu_ms)
		bound = "%s (GPU derived=%.1fms, no driver timer)" % [
			"GPU-BOUND" if derived >= cpu_ms else "CPU-BOUND", derived]

	var calls: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objs: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)

	# Rolling graph.
	_history.append(frame_ms)
	while _history.size() > HISTORY:
		_history.remove_at(0)
	var spiking: bool = frame_ms > SPIKE_MS
	_graph.samples = _history
	_graph.spiking = spiking
	_graph.queue_redraw()

	if spiking:
		var cause: String = ", ".join(_frame_events) if not _frame_events.is_empty() else "steady-state"
		var line: String = "%5.1fms | calls %d | %s" % [frame_ms, calls, cause]
		_spike_log.push_front(line)
		while _spike_log.size() > 5:
			_spike_log.pop_back()
	_frame_events.clear()

	var gpu_txt: String = "%.1f ms" % gpu_ms if gpu_ms > 0.01 else "n/a"
	var stats: String = "FRAME %5.1f ms  (%3d fps)   [%s]\n" % [frame_ms, int(fps), bound]
	stats += "  CPU %5.1f ms  (proc %.1f + phys %.1f)   render-cpu %.1f ms\n" % [
		cpu_ms, process_ms, physics_ms, render_cpu_ms]
	stats += "  GPU %s   nav %.1f ms\n" % [gpu_txt, nav_ms]
	stats += "  draw calls %d | prims %s | objects %d\n" % [calls, _commas(prims), objs]

	# Per-system CPU buckets: the arena-driven managers by name, then the engine
	# remainder (AI think + agent physics + veg = everything not itemised below).
	var itemised: float = 0.0
	for name_v: Variant in _cpu_buckets:
		itemised += float(_cpu_buckets[name_v])
	stats += "  --- CPU per-system (arena-timed) ---\n"
	for name_v: Variant in _cpu_buckets:
		stats += "  %-12s %.2f ms\n" % [String(name_v), float(_cpu_buckets[name_v])]
	stats += "  %-12s %.2f ms\n" % ["ai/agents", maxf(0.0, process_ms - itemised)]

	# Physics-side AI buckets (1s averages) against this frame's physics monitor -
	# the first split of the wall where the AI actually lives.
	if not _phys_buckets.is_empty():
		var phys_itemised: float = 0.0
		for name_v: Variant in _phys_buckets:
			phys_itemised += float(_phys_buckets[name_v])
		stats += "  --- physics-side AI (1s avg) ---\n"
		for name_v: Variant in _phys_buckets:
			stats += "  %-12s %.2f ms\n" % [String(name_v), float(_phys_buckets[name_v])]
		stats += "  %-12s %.2f ms\n" % ["phys/other", maxf(0.0, physics_ms - phys_itemised)]

	# Ray census: perc/wit rays pass through has_line_of_sight, so "los" is shown
	# net of them; cover + bullet are direct space casts.
	_ray_t += delta
	_ray_frames += 1
	if _ray_t >= 1.0:
		var now_c: Array[int] = [CombatManager.rays_los, CombatManager.rays_perception,
			CombatManager.rays_witness, CombatManager.rays_cover, CombatManager.rays_bullet]
		var d: Array[int] = []
		for i in now_c.size():
			d.append(now_c[i] - _ray_prev[i])
		_ray_prev = now_c
		var rf: float = float(maxi(1, _ray_frames))
		var ray_total: int = d[0] + d[3] + d[4]
		_ray_line = "  rays/f %.1f (perc %.1f wit %.1f los %.1f cov %.1f bul %.1f) | %d/s\n" % [
			float(ray_total) / rf, float(d[1]) / rf, float(d[2]) / rf,
			float(d[0] - d[1] - d[2]) / rf, float(d[3]) / rf, float(d[4]) / rf, ray_total]
		_ray_t = 0.0
		_ray_frames = 0
	if not _ray_line.is_empty():
		stats += "  --- rays (1s window) ---\n" + _ray_line

	if not _spike_log.is_empty():
		stats += "  --- last spikes (>%.0fms) ---\n" % SPIKE_MS
		for s: String in _spike_log:
			stats += "  ! %s\n" % s

	# Toggles live in the SAME label so they can never overlap the variable-height
	# stats block above them.
	stats += "  --- TOGGLES (watch the numbers move) ---\n"
	stats += "  F1 jungle patches [%s]   F2 grass/clutter [%s]   F3 lights [%s]\n" % [
		_onoff(_jungle_on), _onoff(_clutter_on), _onoff(_lights_on)]
	stats += "  F4 characters [%s]   F5 debug-vis [%s]   F6 sun shadows [%s]" % [
		_onoff(_chars_on), _onoff(_debug_on), _onoff(_shadows_on)]
	_stats.text = stats


func _onoff(v: bool) -> String:
	return "ON" if v else "OFF"


func _commas(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key: int = (event as InputEventKey).keycode
	match key:
		KEY_F1:
			_jungle_on = not _jungle_on
			if _jungle != null:
				_jungle.visible = _jungle_on
		KEY_F2:
			_clutter_on = not _clutter_on
			if _clutter != null:
				_clutter.visible = _clutter_on
		KEY_F3:
			_lights_on = not _lights_on
			if _lights != null:
				_lights.visible = _lights_on
		KEY_F4:
			_chars_on = not _chars_on
			if _arena != null and _arena.has_method("set_characters_active"):
				_arena.call("set_characters_active", _chars_on)
		KEY_F5:
			_debug_on = not _debug_on
			if _arena != null and _arena.has_method("set_debug_vis_active"):
				_arena.call("set_debug_vis_active", _debug_on)
		KEY_F6:
			_shadows_on = not _shadows_on
			if _sun != null:
				_sun.shadow_enabled = _shadows_on


func _exit_tree() -> void:
	if _vp_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(_vp_rid, false)
