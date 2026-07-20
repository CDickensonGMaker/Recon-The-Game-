## perf_probe.gd - perf gate + per-system attribution. Windowed (NOT headless):
## under RendererDummy every figure it reads is zero.
## Launched by `--perf-probe` on the normal boot; GameFlow.enter_hub calls attach()
## with the live patrol world. It does NOT build a world of its own - a bare
## game_world has no firebase, no sites and no LazyGroups, so it cannot measure the
## world the player walks.
extends Node

## true  -> baseline, then canopy off, then clutter off, then sun shadow off
## false -> single baseline window (fast re-measure after a code change)
@export var cycle_systems: bool = false

## Costs the sun shadow the game does NOT currently ship, at three near-field caps. This is an
## "what would atmosphere cost" study, not a saving: the shipped sun is shadow_enabled = false
## (game_world.gd:48), so turning shadows off can never be a win.
@export var shadow_study: bool = false

const WARMUP: float = 5.0     ## skip engine/scene warm-up
const WINDOW: float = 7.0     ## seconds per phase
const SETTLE: float = 2.5     ## ignore this long after a toggle (visibility is 10Hz)
## Engine.get_frames_per_second() reports frames counted over the PREVIOUS SECOND, so a capture
## stall keeps depressing the reading for ~1s after the stall frame itself. Firing at 0.25 leaves
## >2s of clearance before SETTLE ends; at 1.5 the stall was still inside the first sampled reading.
const SCREENSHOT_AT: float = 0.25

var world: GameWorld
var _elapsed: float = 0.0
var _phase: int = -1
var _phases: Array[String] = []
var _fps: Dictionary = {}     ## phase -> Array[float]
var _prims: Dictionary = {}   ## phase -> Array[float]
var _calls: Dictionary = {}   ## phase -> Array[float]
var _objs: Dictionary = {}    ## phase -> Array[float]
var _shot_taken: bool = false
## The world's OWN shadow config, captured before any phase runs. Baselines must reproduce ship,
## never force a shadow on: ADR-026:137-144 voided a 12ms "sun-shadow win" that was the arena bench
## enabling a shadow the game does not ship. Reading ship here is what keeps that from recurring.
var _shipped_shadow: bool = false
var _shipped_shadow_dist: float = 100.0


func _ready() -> void:
	# Vsync quantises the frame rate to display half-steps (30/60 on a 60Hz panel),
	# which hides real GPU-cost deltas. Uncap for a true throughput measurement.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	set_process(false)


## The caller owns the world. Nothing is sampled until this lands.
func attach(w: GameWorld) -> void:
	world = w
	var sun0 := world.get_node_or_null("SunLight") as DirectionalLight3D
	if sun0 != null:
		_shipped_shadow = sun0.shadow_enabled
		_shipped_shadow_dist = sun0.directional_shadow_max_distance
	print("[PERF] ship config: sun shadow_enabled=%s max_distance=%.1f" % [
		str(_shipped_shadow), _shipped_shadow_dist])
	if shadow_study:
		_phases = ["ship", "shadow_40m", "shadow_80m", "shadow_uncapped", "ship_2"]
	elif cycle_systems:
		# A/B/A: the baseline is re-measured between every lever. Run-to-run drift on
		# this hardware was 1.4 fps on identical config (ledger, 2026-07-20), which is
		# wider than some levers - a single baseline cannot carry four deltas.
		_phases = ["baseline", "no_campfires", "baseline_2", "no_canopy",
			"baseline_3", "no_clutter", "baseline_4", "no_sun_shadow", "baseline_5"]
	else:
		_phases = ["baseline"]
	for p: String in _phases:
		_fps[p] = [] as Array[float]
		_prims[p] = [] as Array[float]
		_calls[p] = [] as Array[float]
		_objs[p] = [] as Array[float]
	set_process(true)


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
		_shot_taken = false
		_apply_toggle(_phases[idx])

	var in_window: float = t - float(idx) * WINDOW

	if in_window >= SCREENSHOT_AT and not _shot_taken and (idx == 0 or shadow_study):
		_take_screenshot(_phases[idx])
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

	var sun := world.get_node_or_null("SunLight") as DirectionalLight3D
	if sun == null:
		push_error("[PERF] no SunLight under GameWorld - every shadow row measures nothing.")
	else:
		match phase_name:
			"shadow_40m":
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 40.0
			"shadow_80m":
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 80.0
			"shadow_uncapped":
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = _shipped_shadow_dist
			"no_sun_shadow":
				sun.shadow_enabled = false
			_:
				sun.shadow_enabled = _shipped_shadow
				sun.directional_shadow_max_distance = _shipped_shadow_dist
		if phase_name == "no_sun_shadow" and not _shipped_shadow:
			push_warning("[PERF] sun shadow is already OFF in ship config - the no_sun_shadow row measures NOTHING.")

	# Campfires exist only at NIGHT/DUSK/DAWN (mission_generator.gd:643). At a DAY
	# seed this lever toggles nothing, so the census is printed with the row - a
	# zero-campfire world must never read as "campfires are free".
	var fires: Array[Node] = get_tree().get_nodes_in_group("campfire")
	for f: Node in fires:
		if f is Node3D:
			(f as Node3D).visible = phase_name != "no_campfires"
	if fires.is_empty() and phase_name == "no_campfires":
		push_warning("[PERF] 0 campfires in this world - the no_campfires row measures NOTHING.")
	print("[PERF] phase -> %s (campfires=%d)" % [phase_name, fires.size()])


func _take_screenshot(phase_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
	var path := "res://screenshots/perf_%s.png" % phase_name
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

	print("PERF TABLE scale=%.2f renderer=%s seed=%d" % [scale, method, world.mission_seed])
	for p: String in _phases:
		print("PERF ROW %-14s fps_avg=%5.1f fps_min=%5.1f prims=%9d calls=%5d objs=%5d n=%d" % [
			p, _avg(_fps[p]), _minimum(_fps[p]),
			int(_avg(_prims[p])), int(_avg(_calls[p])), int(_avg(_objs[p])),
			(_fps[p] as Array).size(),
		])

	if shadow_study or cycle_systems:
		# Each lever is scored against the MEAN of the two baselines that bracket it,
		# so baseline drift across the run is halved instead of landing in one delta.
		var brackets: Dictionary = {
			"no_campfires": ["baseline", "baseline_2"],
			"no_canopy": ["baseline_2", "baseline_3"],
			"no_clutter": ["baseline_3", "baseline_4"],
			"no_sun_shadow": ["baseline_4", "baseline_5"],
		}
		if shadow_study:
			brackets = {
				"shadow_40m": ["ship", "ship_2"],
				"shadow_80m": ["ship", "ship_2"],
				"shadow_uncapped": ["ship", "ship_2"],
			}
		var spread: float = _spread_of_baselines()
		print("PERF DRIFT baseline spread across run = %.1f fps (noise floor)" % spread)
		for p: String in brackets:
			var pair: Array = brackets[p]
			var b_fps: float = (_avg(_fps[pair[0]]) + _avg(_fps[pair[1]])) * 0.5
			var b_prims: float = (_avg(_prims[pair[0]]) + _avg(_prims[pair[1]])) * 0.5
			var b_calls: float = (_avg(_calls[pair[0]]) + _avg(_calls[pair[1]])) * 0.5
			var d: float = _avg(_fps[p]) - b_fps
			print("PERF DELTA %-14s dFps=%+.1f dPrims=%+d dCalls=%+d %s" % [
				p, d, int(_avg(_prims[p]) - b_prims), int(_avg(_calls[p]) - b_calls),
				"INSIDE NOISE" if absf(d) <= spread else "",
			])
	get_tree().quit(0)


## Widest gap between any two baseline windows in this run - the honest noise floor.
func _spread_of_baselines() -> float:
	var vals: Array[float] = []
	for p: String in _phases:
		if p.begins_with("baseline") or p.begins_with("ship"):
			vals.append(_avg(_fps[p]))
	if vals.size() < 2:
		return 0.0
	var lo: float = vals[0]
	var hi: float = vals[0]
	for v: float in vals:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo
