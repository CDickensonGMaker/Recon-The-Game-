## perf_probe.gd - NS04 perf gate: run world windowed, log FPS, save screenshots.
## Run via MCP run_project with scene res://tests/perf_probe.tscn (NOT headless).
extends Node

const RUN_SECONDS: float = 45.0
const SCREENSHOT_TIMES: Array[float] = [15.0, 30.0]

var world: GameWorld
var _elapsed: float = 0.0
var _fps_samples: Array[float] = []
var _shots_taken: int = 0


func _ready() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	world = world_scene.instantiate()
	world.mission_seed = 2077
	add_child(world)


func _process(delta: float) -> void:
	if world == null or not world.is_world_ready:
		return
	_elapsed += delta
	if _elapsed > 5.0:  # skip warm-up
		_fps_samples.append(Engine.get_frames_per_second())

	if _shots_taken < SCREENSHOT_TIMES.size() and _elapsed >= SCREENSHOT_TIMES[_shots_taken]:
		_take_screenshot()
		_shots_taken += 1

	if _elapsed >= RUN_SECONDS:
		_finish()


func _take_screenshot() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
	var path := "res://screenshots/perf_%d.png" % _shots_taken
	img.save_png(ProjectSettings.globalize_path(path))
	print("[PERF] screenshot saved: %s" % path)


func _finish() -> void:
	set_process(false)
	if _fps_samples.is_empty():
		print("PERF SUMMARY: no samples")
		get_tree().quit(1)
		return
	var total: float = 0.0
	var minimum: float = 99999.0
	for s in _fps_samples:
		total += s
		minimum = minf(minimum, s)
	var avg: float = total / float(_fps_samples.size())
	print("PERF SUMMARY: avg=%.1f min=%.1f samples=%d" % [avg, minimum, _fps_samples.size()])
	if avg >= 30.0:
		print("PASS: perf gate met (avg >= 30)")
		get_tree().quit(0)
	else:
		print("FAIL: perf gate missed (avg %.1f < 30)" % avg)
		get_tree().quit(1)
