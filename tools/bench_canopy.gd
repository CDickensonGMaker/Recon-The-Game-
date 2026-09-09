## bench_canopy.gd - the canopy A/B instrument. WINDOWED ONLY (headless reads every
## counter as zero).
##
## Why it exists: perf_walk.bat is a HUMAN walk, and a human cannot repeat a viewpoint
## closely enough to resolve a ~2 ms difference. This builds the same world at a fixed
## seed, parks a camera at fixed poses in deep jungle, and holds each one. No player, no
## AI, no siege - so the only thing that differs between two runs is the change under
## test. It is not a substitute for his eyes; it only proves a direction and a size.
##
## Reports per pose: avg fps, WORST FRAME, 1% low, draw calls, primitives, gpu ms.
## Averages are the weakest number here and are printed last on purpose.
##   Godot_v4.7 --path . res://tools/bench_canopy.tscn
##
## IT MUST ANNOUNCE ITSELF. A window that opens on Caleb's screen showing a camera he
## cannot move reads as a broken game, and it has happened three times. This one states
## what it is in the window title AND on screen, counts down its own runtime, and quits
## on its own. NOTHING HE IS MEANT TO JUDGE MAY BE SHOWN THIS WAY - the look, the pop and
## the night are handed to him as perf_walk.bat, the real game with the real player camera.
extends Node

const SEED: int = 47225
const EYE: float = 1.7
const WARMUP: float = 6.0     ## world settle + shader/pipeline compile
const SETTLE: float = 1.5     ## after each camera move, before sampling
const HOLD: float = 6.0       ## sampled window per pose
const RENDER_SCALE: float = 0.75   ## ship parity (ADR-026)

## Eight yaws from one deep-jungle stand. One direction can luck into a clearing; eight
## cannot, and the WORST of the eight is the number that matters.
const YAWS: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

var _world: GameWorld = null
var _cam: Camera3D = null
var _vp: RID = RID()
var _pose: int = -1
var _t: float = 0.0
var _sampling: bool = false
var _frames: int = 0
var _worst_ms: float = 0.0
var _ms: Array[float] = []
var _calls: float = 0.0
var _prims: float = 0.0
var _gpu: float = 0.0
var _n: int = 0
var _rows: Array[Dictionary] = []
var _banner: Label = null
var _run_left: float = 0.0
## --shots=<dir> --tag=<name>: save the last sampled frame of each pose. A look change has to
## be looked at, and the same yaw from the same stand is the only honest before/after pair.
var _shot_dir: String = ""
var _shot_tag: String = "run"


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_viewport().scaling_3d_scale = RENDER_SCALE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--lod-threshold="):
			get_viewport().mesh_lod_threshold = float(a.split("=")[1])
		if a.begins_with("--shots="):
			_shot_dir = a.split("=")[1]
		if a.begins_with("--tag="):
			_shot_tag = a.split("=")[1]
	_announce()
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)

	_world = load("res://scenes/levels/game_world.tscn").instantiate()
	_world.mission_seed = SEED
	_world.spawn_player_on_ready = false
	add_child(_world)
	var waited: float = 0.0
	while not _world.is_world_ready and waited < 180.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if not _world.is_world_ready:
		print("[CANOPY] FAIL: world never became ready")
		get_tree().quit(1)
		return

	_cam = Camera3D.new()
	_cam.fov = 75.0            ## the player's hip FOV (ADR-004)
	_cam.far = 600.0
	add_child(_cam)
	_cam.current = true
	_cam.global_position = _stand()
	# EVERY dial this bench can move is read back off the VIEWPORT, never off
	# ProjectSettings - the 2026-08-07..09-08 measurement window was voided by exactly that
	# confusion, and mesh_lod_threshold is now a lever this bench pulls.
	print("[CANOPY] live viewport: scale %.3f | mesh_lod_threshold %.2f px | ground-cover ring %.0f m"
		% [get_viewport().scaling_3d_scale, get_viewport().mesh_lod_threshold, _small_ring()])
	print("[CANOPY] seed %d | stand %s | render scale %.2f | fov %.0f"
		% [SEED, str(_cam.global_position.round()), RENDER_SCALE, _cam.fov])
	await get_tree().create_timer(WARMUP).timeout
	_advance()


## Say on screen and in the title bar what this window is, so it is never mistaken for the
## game. run_s is the honest total: world build is unbounded, so the countdown covers only
## the sampling once it starts.
func _announce() -> void:
	var run_s: int = int(WARMUP + YAWS.size() * (SETTLE + HOLD))
	DisplayServer.window_set_title(
		"RECON CANOPY BENCH - MEASUREMENT, NOT THE GAME - closes itself in ~%ds" % run_s)
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(0.0, 12.0)
	layer.add_child(panel)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_banner)
	_run_left = float(run_s)
	_set_banner("building the world")


func _set_banner(what: String) -> void:
	if _banner == null:
		return
	_banner.text = ("CANOPY BENCH - THIS IS A MEASUREMENT, NOT THE GAME
"
		+ "The camera is fixed on purpose. Nothing to control. It closes itself.
"
		+ "%s - about %ds left" % [what, maxi(0, int(_run_left))])


## A fixed point in the AO, lifted to the terrain surface, with the camera at eye height.
## Deliberately NOT the firebase: the compound's own geometry would dominate the frame and
## bury the canopy difference this bench exists to read.
func _stand() -> Vector3:
	var p := Vector3(120.0, 0.0, 120.0)
	if _world.terrain_manager != null:
		p.y = _world.terrain_manager.get_height_at(p)
	return p + Vector3(0.0, EYE, 0.0)


func _advance() -> void:
	if _pose >= 0:
		_close_row()
	_pose += 1
	if _pose >= YAWS.size():
		_summarise()
		return
	_cam.rotation = Vector3(0.0, deg_to_rad(YAWS[_pose]), 0.0)
	_set_banner("sampling view %d of %d" % [_pose + 1, YAWS.size()])
	_t = 0.0
	_sampling = false
	_frames = 0
	_worst_ms = 0.0
	_ms.clear()
	_calls = 0.0
	_prims = 0.0
	_gpu = 0.0
	_n = 0


func _process(delta: float) -> void:
	if _cam == null or _pose < 0 or _pose >= YAWS.size():
		return
	_t += delta
	_run_left -= delta
	if not _sampling:
		if _t >= SETTLE:
			_sampling = true
			_t = 0.0
		return
	_frames += 1
	var ms: float = delta * 1000.0
	_worst_ms = maxf(_worst_ms, ms)
	_ms.append(ms)
	_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_gpu += RenderingServer.viewport_get_measured_render_time_gpu(_vp)
	_n += 1
	if _t >= HOLD:
		if _shot_dir != "":
			# No await here: awaiting inside _process turns it into a coroutine and the
			# frames that keep arriving before it resumes land in a row that is already
			# being closed. The image is the previously presented frame, which is the
			# same view - this is a look reference, not a measurement.
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("%s/canopy_%s_yaw%03d.png" % [_shot_dir, _shot_tag, int(YAWS[_pose])])
		_advance()


func _close_row() -> void:
	if _n == 0:
		return
	var row := {
		"yaw": YAWS[_pose],
		"avg": float(_frames) / maxf(0.001, HOLD),
		"worst_ms": _worst_ms,
		"low1": _one_percent_low(),
		"calls": _calls / float(_n),
		"prims": _prims / float(_n),
		"gpu": _gpu / float(_n),
	}
	_rows.append(row)
	print("[CANOPY] yaw %3.0f | %5.1f avg | worst %6.2fms | 1%% low %5.1f | calls %6.0f | prims %9.0f | gpu %5.2fms"
		% [row["yaw"], row["avg"], row["worst_ms"], row["low1"], row["calls"], row["prims"], row["gpu"]])


## Mean of the worst 1% of frames, as fps - the pacing number, not the throughput one.
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


func _summarise() -> void:
	var worst_ms: float = 0.0
	var worst_low: float = 999.0
	var sum_avg: float = 0.0
	var sum_calls: float = 0.0
	var sum_prims: float = 0.0
	var sum_gpu: float = 0.0
	for r: Dictionary in _rows:
		worst_ms = maxf(worst_ms, float(r["worst_ms"]))
		worst_low = minf(worst_low, float(r["low1"]))
		sum_avg += float(r["avg"])
		sum_calls += float(r["calls"])
		sum_prims += float(r["prims"])
		sum_gpu += float(r["gpu"])
	var n: float = maxf(1.0, float(_rows.size()))
	print("[CANOPY] === WORST FRAME %.2fms | WORST 1%% LOW %.1f fps ===" % [worst_ms, worst_low])
	print("[CANOPY] === mean over %d poses: %.1f fps | calls %.0f | prims %.0f | gpu %.2fms ==="
		% [_rows.size(), sum_avg / n, sum_calls / n, sum_prims / n, sum_gpu / n])
	get_tree().quit(0)


## The ground-cover ring the TreeCoverLayer is actually running, read off the live node.
func _small_ring() -> float:
	for n in get_tree().get_nodes_in_group("tree_cover"):
		return float(n.get("small_ring"))
	return -1.0
