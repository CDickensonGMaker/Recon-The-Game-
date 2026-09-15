## probe_ford_paths.gd - the navmesh over THE STREAM: no route across deep water, a route
## across every ford (ADR-041 thawed for the demo AO, Caleb 2026-09-15).
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --ford-probe --demo-map=1024 --test-save
##
## Attached to the live demo world by game_flow.gd under `--ford-probe`. Holds the stand-to
## off, waits for every queued bake to land, then:
##   1. each ford centre lies on the map (map_get_closest_point within 1 m in XZ; the rise is printed);
##   2. the two banks connect THROUGH F1 and through F2 (a bank->bank path lands, and passes
##      within FORD_REACH_M of the ford);
##   3. for PAIRS seeded pairs of points on opposite banks (the plan's polyline +-BANK_M along
##      the village bearing) the uncapped server path never samples deep water further than
##      FORD_REACH_M from a ford - it crosses at a ford or it stops on the near bank.
## Exit 1 on any failure. At 512 the plan carries no stream and the probe says so and fails.
extends Node

const SETTLE_S: float = 20.0
const BAKE_WAIT_S: float = 150.0
const PAIRS: int = 40
const BANK_M: float = 40.0
## A ford is three plan points (12 m along the stream) and the deep point either side reads
## 7.2 m out, so the corridor's last shallow quad centre sits ~13 m from the ford centre and a
## path hugging it samples deep water at ~12 m. Measured 2026-09-15: worst 12.1 m.
const FORD_REACH_M: float = 14.0
const SAMPLE_M: float = 1.0
const SEED: int = 4171

var _fail: int = 0
var _director: FieldDirector = null


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("\n=== FORD PROBE ===")
	var waited: float = 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if _director == null:
			_director = get_tree().get_first_node_in_group("mission_director") as FieldDirector
			if _director != null:
				_director.stand_to_held = true
	var book: BeatBook = get_tree().get_first_node_in_group("beat_book") as BeatBook
	_check(book != null and book.plan.has("stream"),
		"the plan carries a stream at map %.0f (the 512 slice has no bank for one)" % GameFlow.demo_map_size())
	if book == null or not book.plan.has("stream"):
		_finish()
		return
	var world: GameWorld = get_tree().get_first_node_in_group("game_world") as GameWorld
	var baker: NavBaker = NavBaker.instance(self)
	_check(world != null and world.gameplay_grid != null and baker != null, "a world, a grid and a baker")
	if world == null or world.gameplay_grid == null or baker == null:
		_finish()
		return
	waited = 0.0
	while waited < BAKE_WAIT_S and not (baker._queue.is_empty() and baker._job.is_empty()
			and baker._active_mesh == null and baker.regions_live > 0):
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	_check(baker._queue.is_empty() and baker._job.is_empty() and baker._active_mesh == null,
		"every queued bake landed (%d region(s) after %.0f s)" % [baker.regions_live, waited])
	# The last region's polygons need a server sync before a query can see them.
	await get_tree().create_timer(2.0).timeout
	var fsb: Vector3 = book.plan.get("fsb_center", Vector3.ZERO)
	print("  [FORD] fsb %.0f,%.0f  village %.0f,%.0f  gate %.0f,%.0f" % [fsb.x, fsb.z,
		(book.plan.get("village_centers", [Vector3.ZERO]) as Array)[0].x,
		(book.plan.get("village_centers", [Vector3.ZERO]) as Array)[0].z,
		(book.plan.get("gate_pos", Vector3.ZERO) as Vector3).x, (book.plan.get("gate_pos", Vector3.ZERO) as Vector3).z])
	for bi in NavBaker._live_boxes.size():
		var bx: AABB = NavBaker._live_boxes[bi]
		print("  [FORD] box %d: x %.0f..%.0f  z %.0f..%.0f" % [bi, bx.position.x, bx.end.x, bx.position.z, bx.end.z])
	for r in get_tree().root.find_children("NavRegion_*", "NavigationRegion3D", true, false):
		var reg := r as NavigationRegion3D
		if reg.navigation_mesh == null:
			continue
		var vs: PackedVector3Array = reg.navigation_mesh.get_vertices()
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for v in vs:
			lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
			hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
		print("  [FORD] %s: %d verts, x %.0f..%.0f y %.1f..%.1f z %.0f..%.0f, enabled %s, map %s" % [reg.name, vs.size(),
			lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, reg.enabled, reg.get_navigation_map() == get_tree().root.get_world_3d().navigation_map])
	_fords(world, book.plan.stream)
	_pairs(world, book.plan.stream)
	_finish()


func _ground(world: GameWorld, p: Vector3) -> Vector3:
	return Vector3(p.x, world.terrain_manager.get_height_at(p), p.z)


func _fords(world: GameWorld, stream: Dictionary) -> void:
	var map: RID = get_tree().root.get_world_3d().navigation_map
	var fords: Dictionary = stream.fords
	var axis: Vector3 = stream.axis
	for fname: String in ["F1", "F2", "F3"]:
		if not fords.has(fname):
			_check(false, "%s exists" % fname)
			continue
		var f: Vector3 = _ground(world, fords[fname])
		var on: Vector3 = NavigationServer3D.map_get_closest_point(map, f)
		# XZ: the 4 m nav quads ride up to ~0.5 m above the 2 m heightmap's carved bed.
		var d: float = Vector2(on.x - f.x, on.z - f.z).length()
		_check(d <= 1.0 and NavBaker.box_index_at(f) >= 0, "%s at %.0f,%.0f lies on the map (closest point %.2f m off in XZ, %.2f m up, box %d, depth %.2f m)"
			% [fname, f.x, f.z, d, on.y - f.y, NavBaker.box_index_at(f), world.gameplay_grid.get_water_depth(f)])
		if fname == "F3":
			continue
		var a: Vector3 = _ground(world, f - axis * 25.0)
		var b: Vector3 = _ground(world, f + axis * 25.0)
		var path: PackedVector3Array = NavRouter.server_path(map, a, b)
		var tail: float = -1.0
		var nearest: float = INF
		if path.size() >= 2:
			var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, b)
			tail = Vector2(path[path.size() - 1].x - goal.x, path[path.size() - 1].z - goal.z).length()
			for pt in path:
				nearest = minf(nearest, Vector2(pt.x - f.x, pt.z - f.z).length())
		_check(path.size() >= 2 and tail <= 2.0 and nearest <= FORD_REACH_M,
			"bank->bank through %s: %d point(s), lands %.1f m off the far bank, passes %.1f m from the ford"
			% [fname, path.size(), tail, nearest])
	var ws: Dictionary = (get_tree().get_first_node_in_group("beat_book") as BeatBook).plan.get("way_station", {})
	if not ws.is_empty():
		var c: Vector3 = ws.center
		print("  [FORD] way-station at %.0f,%.0f box %d; runner stand box %d" % [c.x, c.z,
			NavBaker.box_index_at(c), NavBaker.box_index_at(stream.runner_stand)])


func _pairs(world: GameWorld, stream: Dictionary) -> void:
	var map: RID = get_tree().root.get_world_3d().navigation_map
	var grid: GameplayGrid = world.gameplay_grid
	var points: PackedVector2Array = stream.points
	var axis: Vector3 = stream.axis
	var fords: Array = (stream.fords as Dictionary).values()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var crossed: int = 0
	var stopped: int = 0
	var empty: int = 0
	var bad: int = 0
	var off_box: int = 0
	var worst: float = 0.0
	var deep_samples: int = 0
	for k in PAIRS:
		var i: int = rng.randi_range(0, points.size() - 1)
		var c := Vector3(points[i].x, 0.0, points[i].y)
		var side: float = 1.0 if (k % 2 == 0) else -1.0
		var a: Vector3 = _ground(world, c - axis * BANK_M * side)
		var b: Vector3 = _ground(world, c + axis * BANK_M * side)
		if NavBaker.box_index_at(a) < 0 or NavBaker.box_index_at(b) < 0:
			off_box += 1
			continue
		var path: PackedVector3Array = NavRouter.server_path(map, a, b)
		if path.size() < 2:
			empty += 1
			continue
		var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, b)
		var tail: float = Vector2(path[path.size() - 1].x - goal.x, path[path.size() - 1].z - goal.z).length()
		var far_deep: float = 0.0
		for s in range(path.size() - 1):
			var seg: Vector3 = path[s + 1] - path[s]
			var n: int = maxi(1, int(ceil(seg.length() / SAMPLE_M)))
			for j in range(n + 1):
				var pt: Vector3 = path[s] + seg * (float(j) / float(n))
				if grid.get_water_depth(pt) <= GameplayGrid.WADE_DEPTH_M:
					continue
				deep_samples += 1
				var df: float = INF
				for f: Vector3 in fords:
					df = minf(df, Vector2(pt.x - f.x, pt.z - f.z).length())
				far_deep = maxf(far_deep, df)
		worst = maxf(worst, far_deep)
		if far_deep > FORD_REACH_M:
			bad += 1
			print("  [FORD] pair %d at %.0f,%.0f: deep sample %.1f m from the nearest ford (tail %.1f m)"
				% [k, c.x, c.z, far_deep, tail])
		elif tail <= 2.0:
			crossed += 1
		else:
			stopped += 1
	print("  [FORD] %d pairs: %d crossed at a ford, %d stopped on the near bank, %d empty, %d off every box, %d deep samples, worst deep sample %.1f m from a ford"
		% [PAIRS, crossed, stopped, empty, off_box, deep_samples, worst])
	_check(bad == 0, "no path samples deep water further than %.0f m from a ford (%d bad)" % [FORD_REACH_M, bad])
	_check(crossed > 0, "at least one pair crossed at a ford (%d)" % crossed)


func _finish() -> void:
	if _fail == 0:
		print("=== FORD PROBE PASS ===")
	else:
		print("=== FORD PROBE FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
