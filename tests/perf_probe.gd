## perf_probe.gd - perf gate + per-system attribution. Windowed (NOT headless).
## Run via MCP run_project with scene res://tests/perf_probe.tscn.
## Samples FPS + RenderingServer frame counters. With cycle_systems = true it also
## toggles each foliage system off one window at a time, so the frame cost of
## billboards / jungle patches / grass can be read by difference.
extends Node

## true  -> baseline, then canopy off, then ground clutter off (attribution run)
## false -> single baseline window (fast re-measure after a code change)
@export var cycle_systems: bool = false

const WARMUP: float = 5.0     ## skip engine/scene warm-up
const WINDOW: float = 7.0     ## seconds per phase
const SETTLE: float = 2.5     ## ignore this long after a toggle (visibility is 10Hz)
const SCREENSHOT_AT: float = 1.5  ## into the baseline window, inside SETTLE so its stall is not sampled

var world: GameWorld
var _elapsed: float = 0.0
var _phase: int = -1
var _phases: Array[String] = []
var _fps: Dictionary = {}     ## phase -> Array[float]
var _prims: Dictionary = {}   ## phase -> Array[float]
var _calls: Dictionary = {}   ## phase -> Array[float]
var _objs: Dictionary = {}    ## phase -> Array[float]
var _shot_taken: bool = false


func _ready() -> void:
	# Vsync quantises the frame rate to display half-steps (30/60 on a 60Hz panel),
	# which hides real GPU-cost deltas. Uncap for a true throughput measurement.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if cycle_systems:
		_phases = ["baseline", "no_canopy", "no_clutter"]
	else:
		_phases = ["baseline"]
	for p: String in _phases:
		_fps[p] = [] as Array[float]
		_prims[p] = [] as Array[float]
		_calls[p] = [] as Array[float]
		_objs[p] = [] as Array[float]
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	world = world_scene.instantiate()
	world.mission_seed = 2077
	add_child(world)


func _process(delta: float) -> void:
	if world == null or not world.is_world_ready:
		return
	_elapsed += delta
	if _elapsed < WARMUP:
		return

	var t: float = _elapsed - WARMUP
	var idx: int = int(t / WINDOW)
	if idx >= _phases.size():
		_finish()
		return

	if idx != _phase:
		_phase = idx
		_apply_toggle(_phases[idx])

	var in_window: float = t - float(idx) * WINDOW

	if idx == 0 and not _shot_taken and in_window >= SCREENSHOT_AT:
		_take_screenshot()
		_shot_taken = true

	if in_window < SETTLE:
		return

	var fps: float = float(Engine.get_frames_per_second())
	if fps <= 3.0:
		return  # screenshot-capture stall artifact, not a real dip
	var phase_name: String = _phases[idx]
	(_fps[phase_name] as Array).append(fps)
	(_prims[phase_name] as Array).append(float(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
	(_calls[phase_name] as Array).append(float(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	(_objs[phase_name] as Array).append(float(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)))


## The canopy source is chosen at runtime (VegetationManager.CanopySource), so the
## attribution run must toggle whichever layer is actually live. A phase that cannot
## find its system still prints a row, so an unresolved system must be LOUD - a silent
## no-op row reads as "this system costs nothing".
func _apply_toggle(phase_name: String) -> void:
	var vg: VegetationManager = world.vegetation_manager
	var canopy_hit: bool = false
	if vg != null:
		vg.patches_disabled = phase_name == "no_canopy"
		canopy_hit = true
		var tc: Node = vg.find_child("TreeCoverLayer", false, false)
		if tc is Node3D:
			(tc as Node3D).visible = phase_name != "no_canopy"
	if not canopy_hit:
		push_error("[PERF] no VegetationManager - the no_canopy row measures nothing.")

	var clutter: Node = null
	for c: Node in world.get_children():
		if c is GroundClutter:
			clutter = c
			break
	if clutter is Node3D:
		(clutter as Node3D).visible = phase_name != "no_clutter"
	else:
		push_error("[PERF] no GroundClutter under GameWorld - the no_clutter row measures nothing.")
	print("[PERF] phase -> %s" % phase_name)


func _take_screenshot() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
	var path := "res://screenshots/perf_baseline.png"
	img.save_png(ProjectSettings.globalize_path(path))
	print("[PERF] screenshot saved: %s" % path)


func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in arr:
		total += v
	return total / float(arr.size())


func _minimum(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var m: float = 99999.0
	for v: float in arr:
		m = minf(m, v)
	return m


func _finish() -> void:
	set_process(false)
	var scale: float = float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))
	var method: String = str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "forward_plus (default)"))

	print("PERF TABLE scale=%.2f renderer=%s seed=2077" % [scale, method])
	for p: String in _phases:
		print("PERF ROW %-14s fps_avg=%5.1f fps_min=%5.1f prims=%9d calls=%5d objs=%5d n=%d" % [
			p, _avg(_fps[p]), _minimum(_fps[p]),
			int(_avg(_prims[p])), int(_avg(_calls[p])), int(_avg(_objs[p])),
			(_fps[p] as Array).size(),
		])

	if cycle_systems:
		var base_fps: float = _avg(_fps["baseline"])
		var base_prims: float = _avg(_prims["baseline"])
		var base_calls: float = _avg(_calls["baseline"])
		for p: String in _phases:
			if p == "baseline":
				continue
			print("PERF DELTA %-14s dFps=%+.1f dPrims=%+d dCalls=%+d" % [
				p, _avg(_fps[p]) - base_fps,
				int(_avg(_prims[p]) - base_prims), int(_avg(_calls[p]) - base_calls),
			])

	var base_avg: float = _avg(_fps["baseline"])
	if base_avg >= 30.0:
		print("PASS: perf gate met (baseline avg %.1f >= 30)" % base_avg)
	else:
		print("FAIL: perf gate missed (baseline avg %.1f < 30)" % base_avg)
	get_tree().quit(0)
