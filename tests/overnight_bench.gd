## Unattended per-system attribution bench for RECONgame-365s.
##
## Drives the ai_stress_arena through the SAME F1-F6 toggle path a human would press
## (injected InputEventKey), samples the real RenderingServer GPU render-time per
## configuration, and writes a CSV. Render scale is pinned from the command line and
## RECORDED in every row: a number without its scale is the bug 365s exists to name.
##
## Usage:
##   godot --path . res://tests/overnight_bench.tscn [--rendering-method mobile] \
##       -- --scale=1.0 --mode=5 --out=C:/path/rows.csv --tag=forward_plus
extends Node

const WARMUP_SEC: float = 9.0
const SETTLE_SEC: float = 1.5
const SAMPLE_SEC: float = 4.0

## keycode, label. null keycode = the all-systems-on reference row.
const PHASES: Array = [
	[0, "all_systems_on"],
	[KEY_F1, "jungle_patches_OFF"],
	[KEY_F2, "grass_clutter_OFF"],
	[KEY_F3, "lights_OFF"],
	[KEY_F4, "characters_OFF"],
	[KEY_F6, "sun_shadows_OFF"],
]

var _scale: float = 1.0
var _mode: int = 5
var _out_path: String = ""
var _tag: String = "forward_plus"
var _rows: Array[String] = []
var _vp_rid: RID = RID()


func _ready() -> void:
	_parse_args()

	var vp: Viewport = get_viewport()
	vp.scaling_3d_scale = _scale
	vp.scaling_3d_mode = _mode as Viewport.Scaling3DMode
	_vp_rid = vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)

	var arena_scene: PackedScene = load("res://scenes/levels/ai_stress_arena.tscn")
	if arena_scene == null:
		push_error("BENCH: could not load ai_stress_arena.tscn")
		get_tree().quit(1)
		return
	add_child(arena_scene.instantiate())

	_run.call_deferred()


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scale="):
			_scale = float(a.substr(8))
		elif a.begins_with("--mode="):
			_mode = int(a.substr(7))
		elif a.begins_with("--out="):
			_out_path = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)


## One toggle press, through the real input path the overlay listens on.
func _press(keycode: int) -> void:
	if keycode == 0:
		return
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up: InputEventKey = InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)


## Average over a real window of frames. Returns [fps, gpu_ms, cpu_ms, calls, prims].
func _sample(seconds: float) -> Array:
	var t0: float = float(Time.get_ticks_msec())
	var n: int = 0
	var fps_sum: float = 0.0
	var gpu_sum: float = 0.0
	var cpu_sum: float = 0.0
	var calls_sum: float = 0.0
	var prims_sum: float = 0.0
	while (float(Time.get_ticks_msec()) - t0) / 1000.0 < seconds:
		await get_tree().process_frame
		var fps: float = float(Engine.get_frames_per_second())
		if fps <= 0.0:
			continue
		fps_sum += fps
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
		cpu_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 \
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		calls_sum += float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims_sum += float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		n += 1
	if n == 0:
		return [0.0, 0.0, 0.0, 0.0, 0.0]
	var d: float = float(n)
	return [fps_sum / d, gpu_sum / d, cpu_sum / d, calls_sum / d, prims_sum / d]


func _run() -> void:
	await _wait(WARMUP_SEC)

	for phase: Array in PHASES:
		var keycode: int = int(phase[0])
		var label: String = String(phase[1])

		await _press(keycode)
		await _wait(SETTLE_SEC)
		var s: Array = await _sample(SAMPLE_SEC)
		# Restore, so every row is measured against the same all-on baseline.
		await _press(keycode)
		await _wait(0.4)

		var row: String = "%s,%.2f,%d,%s,%.1f,%.2f,%.2f,%d,%d" % [
			_tag, _scale, _mode, label,
			float(s[0]), float(s[1]), float(s[2]), int(s[3]), int(s[4])]
		_rows.append(row)
		print("BENCHROW ", row)

	_write()
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	var t: SceneTreeTimer = get_tree().create_timer(seconds)
	await t.timeout


func _write() -> void:
	if _out_path.is_empty():
		return
	var f: FileAccess = FileAccess.open(_out_path, FileAccess.WRITE)
	if f == null:
		push_error("BENCH: cannot write %s" % _out_path)
		return
	f.store_line("renderer,render_scale,scaling_mode,config,fps,gpu_ms,cpu_ms,draw_calls,primitives")
	for r: String in _rows:
		f.store_line(r)
	f.close()
	print("BENCH: wrote ", _out_path)
