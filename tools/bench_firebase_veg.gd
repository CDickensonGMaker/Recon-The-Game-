## bench_firebase_veg.gd - the firebase treeline A/B instrument. WINDOWED ONLY (headless
## reads every counter as zero).
##
## bench_canopy.gd deliberately stands at 120/120, away from the compound, because the
## firebase's own 2,455 surfaces would bury the canopy delta. This bench measures the
## opposite population: the ~350 vegetation instances BAKED INTO fsb_main_v3.glb around the
## treeline ring, which exist nowhere else.
##
## IT LOADS THE GLB, NOT THE WORLD, AND THAT IS DELIBERATE. The firebase bake is a baked
## asset - it does not vary with the operation seed, so "same seed" buys nothing here, while
## build_patrol_world would put a live garrison, air traffic and terrain streaming between
## the two runs of an A/B whose whole subject is one asset's geometry. This scene holds the
## firebase, one sun and a fixed camera; the only thing that can differ between two runs is
## the GLB. The cost it reports is therefore the FULL cost of the change, not the fraction
## of it that survives into a frame that also contains jungle, terrain and men.
##
## It prints the fb_veg_ census (nodes, surfaces, triangles) as well as the frame, because a
## geometry change can be real and still sit under frame-to-frame noise. The census is the
## number that cannot be argued with; the frame is the one that costs him something.
##   Godot_v4.7 --path . res://tools/bench_firebase_veg.tscn
##
## IT MUST ANNOUNCE ITSELF - same law as bench_canopy: a fixed camera on his screen reads as
## a broken game. Title bar, on-screen banner, self-closing countdown.
extends Node

const FSB: String = "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
const EYE: float = 1.7
const WARMUP: float = 6.0
const SETTLE: float = 1.5
const HOLD: float = 6.0
const RENDER_SCALE: float = 0.75   ## ship parity (ADR-026)

const YAWS: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

var _fsb: Node = null
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


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_viewport().scaling_3d_scale = RENDER_SCALE
	_announce()
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)

	var packed: PackedScene = load(FSB) as PackedScene
	if packed == null:
		print("[FBVEG] FAIL: could not load %s" % FSB)
		get_tree().quit(1)
		return
	_fsb = packed.instantiate()
	add_child(_fsb)

	## One sun, matching the demo's daylight bearing closely enough to be identical between
	## the two runs - which is all an A/B needs of it.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	add_child(sun)

	var stand: Vector3 = _census_and_centre()
	if stand == Vector3.INF:
		print("[FBVEG] FAIL: no fb_veg_ meshes in the GLB - wrong asset or a renamed bake")
		get_tree().quit(1)
		return

	_cam = Camera3D.new()
	_cam.fov = 75.0            ## the player's hip FOV (ADR-004)
	_cam.far = 600.0
	add_child(_cam)
	_cam.current = true
	_cam.global_position = stand
	print("[FBVEG] stand %s | render scale %.2f | fov %.0f | renderer %s"
		% [str(stand.round()), RENDER_SCALE, _cam.fov,
			ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")])
	## ASK THE VIEWPORT, not ProjectSettings - the standing sin of this project's perf work
	## was quoting a configured scale that never reached the frame (PERF_LEDGER 2026-09-08).
	print("[FBVEG] viewport scaling_3d_scale reads %.3f | size %s"
		% [get_viewport().scaling_3d_scale, str(get_viewport().get_visible_rect().size)])
	await get_tree().create_timer(WARMUP).timeout
	_advance()


## The census AND the stand, from the same walk. Returns the veg ring's centre at eye height
## over the compound floor, or Vector3.INF if nothing named fb_veg_ is in the tree.
func _census_and_centre() -> Vector3:
	var nodes: int = 0
	var surfaces: int = 0
	var tris: int = 0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var floor_y: float = 0.0
	var stack: Array[Node] = [_fsb]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		## The compound floor the player stands on, so the camera eye is at his height and
		## not buried in the mound or floating over it (site_planner: y=0 is the mound TOE).
		if String(mi.name).begins_with("fb_terrain_mound"):
			floor_y = maxf(floor_y, (mi.global_transform * mi.get_aabb()).end.y)
		if not String(mi.name).begins_with("fb_veg_"):
			continue
		nodes += 1
		surfaces += mi.mesh.get_surface_count()
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += (idx.size() / 3) if idx.size() > 0 else (v.size() / 3)
		var box: AABB = mi.global_transform * mi.get_aabb()
		lo = lo.min(box.position)
		hi = hi.max(box.end)
	if nodes == 0:
		return Vector3.INF
	print("[FBVEG] census: %d fb_veg_ node(s), %d surface(s), %d triangle(s) (LOD0)"
		% [nodes, surfaces, tris])
	print("[FBVEG] ring spans %.1f x %.1f m | compound floor y %.2f" % [hi.x - lo.x, hi.z - lo.z, floor_y])
	return Vector3((lo.x + hi.x) * 0.5, floor_y + EYE, (lo.z + hi.z) * 0.5)


func _announce() -> void:
	var run_s: int = int(WARMUP + YAWS.size() * (SETTLE + HOLD))
	DisplayServer.window_set_title(
		"RECON FIREBASE VEG BENCH - MEASUREMENT, NOT THE GAME - closes itself in ~%ds" % run_s)
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
	_banner.text = ("FIREBASE VEG BENCH - THIS IS A MEASUREMENT, NOT THE GAME\n"
		+ "The camera is fixed on purpose. Nothing to control. It closes itself.\n"
		+ "%s - about %ds left" % [what, maxi(0, int(_run_left))])


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
	print("[FBVEG] yaw %3.0f | %5.1f avg | worst %6.2fms | 1%% low %5.1f | calls %6.0f | prims %9.0f | gpu %5.2fms"
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
	print("[FBVEG] === WORST FRAME %.2fms | WORST 1%% LOW %.1f fps ===" % [worst_ms, worst_low])
	print("[FBVEG] === mean over %d poses: %.1f fps | calls %.0f | prims %.0f | gpu %.2fms ==="
		% [_rows.size(), sum_avg / n, sum_calls / n, sum_prims / n, sum_gpu / n])
	get_tree().quit(0)
