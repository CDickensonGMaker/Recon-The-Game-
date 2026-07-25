extends Node3D
## PS2-budget perf probe: boots the AI stress arena at a FIXED camera pose, measures
## frame/CPU/GPU-ms over a fixed sample window, and prints a machine-readable SUMMARY
## line to stdout. Lets GPU fill-bound fixes be A/B'd from a windowed (real-GPU) run
## without reading the on-screen overlay. Headless has no rasterizer, so GPU-ms is 0
## there; run WINDOWED for GPU numbers.
##
## CLI levers (pass after a bare `--`, e.g. `-- --scale=0.75 --mode=5 --no-lights`):
##   --seconds=F   sample-window length after warmup (default 14)
##   --warmup=F    seconds discarded while nav bakes + jungle builds (default 5)
##   --scale=F     viewport 3D render scale (default: leave project setting)
##   --mode=I      viewport scaling_3d_mode int (0 bilinear .. 5 nearest)
##   --no-lights   hide the arena BenchLights root (campfires + illum flares) = F3 off
##   --no-shadows  sun.shadow_enabled = false = F6 off

const CAM_POS: Vector3 = Vector3(-70.0, 6.0, 70.0)
const CAM_LOOK: Vector3 = Vector3(0.0, 1.0, 0.0)

var _arena: Node3D = null
var _cam: Camera3D = null
var _vp_rid: RID = RID()

var _seconds: float = 14.0
var _warmup: float = 5.0
var _no_lights: bool = false
var _no_shadows: bool = false

var _elapsed: float = 0.0
var _sampling: bool = false
var _frames: int = 0
var _sum_frame: float = 0.0
var _sum_cpu: float = 0.0
var _sum_gpu: float = 0.0
var _sum_render_cpu: float = 0.0
var _sum_calls: float = 0.0
var _samples_frame: PackedFloat32Array = PackedFloat32Array()
var _label: String = "run"


func _ready() -> void:
	_parse_args()
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)

	if _has_arg_value("--scale"):
		get_viewport().scaling_3d_scale = _arg_float("--scale", 1.0)
	if _has_arg_value("--mode"):
		get_viewport().scaling_3d_mode = _arg_int("--mode", 1)

	_arena = AIStressArena.new()
	_arena.bench_dressing = true
	_arena.spawn_cover = true
	_arena.spawn_vegetation = true
	_arena.spawn_hud = false
	_arena.spawn_player = true
	add_child(_arena)

	print("[PS2PROBE] booting | label=%s scale=%.2f mode=%d no_lights=%s no_shadows=%s"
		% [_label, get_viewport().scaling_3d_scale, get_viewport().scaling_3d_mode,
			str(_no_lights), str(_no_shadows)])


func _process(delta: float) -> void:
	_elapsed += delta
	if not _sampling and _elapsed >= _warmup:
		_begin_sampling()
	if _sampling:
		_accumulate()
		if _elapsed >= _warmup + _seconds:
			_finish()


func _begin_sampling() -> void:
	_sampling = true
	# Pin the camera so every run frames the identical heavy-jungle view.
	_cam = _find_current_camera(_arena)
	if _cam != null:
		_cam.global_position = CAM_POS
		_cam.look_at(CAM_LOOK, Vector3.UP)
	if _no_lights:
		var lights: Node = _arena.get_node_or_null("BenchLights")
		if lights != null and lights is Node3D:
			(lights as Node3D).visible = false
	if _no_shadows:
		var sun: Node = _arena.get_node_or_null("SunLight")
		if sun != null and sun is DirectionalLight3D:
			(sun as DirectionalLight3D).shadow_enabled = false
	print("[PS2PROBE] sampling %ds ..." % int(_seconds))


func _accumulate() -> void:
	var fps: float = maxf(1.0, float(Engine.get_frames_per_second()))
	var frame_ms: float = 1000.0 / fps
	var cpu_ms: float = (Performance.get_monitor(Performance.TIME_PROCESS)
		+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var render_cpu_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
	var calls: float = float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_frames += 1
	_sum_frame += frame_ms
	_sum_cpu += cpu_ms
	_sum_gpu += gpu_ms
	_sum_render_cpu += render_cpu_ms
	_sum_calls += calls
	_samples_frame.append(frame_ms)


func _finish() -> void:
	var n: float = maxf(1.0, float(_frames))
	var avg_frame: float = _sum_frame / n
	var median_frame: float = _median(_samples_frame)
	var avg_fps: float = 1000.0 / maxf(0.001, avg_frame)
	var median_fps: float = 1000.0 / maxf(0.001, median_frame)
	print("[PS2PROBE] SUMMARY label=%s | frames=%d | avg_fps=%.1f median_fps=%.1f | frame=%.1fms cpu=%.1fms gpu=%.1fms render_cpu=%.1fms | calls=%d"
		% [_label, _frames, avg_fps, median_fps, avg_frame, _sum_cpu / n,
			_sum_gpu / n, _sum_render_cpu / n, int(_sum_calls / n)])
	var shot: String = _arg_str("--shot", "")
	if shot != "":
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot)
		print("[PS2PROBE] screenshot saved: %s" % shot)
	get_tree().quit()


func _median(arr: PackedFloat32Array) -> float:
	if arr.is_empty():
		return 0.0
	var copy: Array = Array(arr)
	copy.sort()
	return float(copy[copy.size() / 2])


func _find_current_camera(root: Node) -> Camera3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Camera3D and (n as Camera3D).current:
			return n as Camera3D
		for c in n.get_children():
			stack.append(c)
	return get_viewport().get_camera_3d()


func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if a == "--no-lights":
			_no_lights = true
			_label += "_nolights"
		elif a == "--no-shadows":
			_no_shadows = true
			_label += "_noshadow"
		elif a.begins_with("--label="):
			_label = a.substr(8)
	_seconds = _arg_float("--seconds", _seconds)
	_warmup = _arg_float("--warmup", _warmup)


func _has_arg_value(key: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return true
	return false


func _arg_float(key: String, def: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1).to_float()
	return def


func _arg_int(key: String, def: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1).to_int()
	return def


func _arg_str(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def
