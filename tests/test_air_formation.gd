## test_air_formation.gd - the Spectre gunship flies the real AC-47 airframe
## (not the deleted box placeholder), and TRANSIT dispatch can roster a
## formation whose every ship rides the same leak deadline as a single.
## Run: godot --headless --path . res://tests/test_air_formation.tscn
extends Node

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: AIR FORMATION + SPOOKY AIRFRAME ===")
	SimClock.paused = true
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 44
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world timeout")
		get_tree().quit(1)
		return

	# --- Spectre carries the AC-47 visual ---
	var centre := Vector3(world.map_size * 0.5, 0.0, world.map_size * 0.5)
	centre.y = world.terrain_manager.get_height_at(centre)
	var ship := SpectreGunship.call_in(world, world.terrain_manager, centre)
	await get_tree().process_frame
	var airframe := ship.get_node_or_null("Airframe") as Node3D
	_expect(airframe != null, "gunship carries an Airframe node")
	if airframe != null:
		var aabb: AABB = _merged_aabb(airframe)
		print("  airframe size x=%.2f y=%.2f z=%.2f" % [aabb.size.x, aabb.size.y, aabb.size.z])
		var largest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		_expect(largest >= 26.0 and largest <= 32.0,
			"AC-47 span %.2fm within 26..32" % largest)
		var boxes: int = 0
		var vis_ok: bool = true
		var stack: Array[Node] = [ship]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			var mi := n as MeshInstance3D
			if mi != null:
				if mi.mesh is BoxMesh:
					boxes += 1
				if not is_equal_approx(mi.visibility_range_end, SpectreGunship.VIS_END_M):
					vis_ok = false
			for c in n.get_children():
				stack.push_back(c)
		_expect(boxes == 0, "no BoxMesh placeholder survives under the gunship")
		_expect(vis_ok, "every airframe mesh culls at %.0fm" % SpectreGunship.VIS_END_M)
	ship.queue_free()

	# --- formation dispatch ---
	var at := AirTraffic.new()
	world.add_child(at)
	await get_tree().process_frame

	at.get_in_flight().clear()
	at._dispatch("huey", 3)
	var roster: Array = at.get_in_flight()
	_expect(roster.size() == 3, "forced 3-ship huey flight rosters 3 (got %d)" % roster.size())
	var nodes: Array = []
	var all_real: bool = roster.size() == 3
	for f: Dictionary in roster:
		var n := f.get("node") as Node3D
		if n == null or not is_instance_valid(n) or n.get_parent() != world:
			all_real = false
		else:
			nodes.append(n)
	_expect(all_real, "every ship is a live aircraft parented into the world")
	if nodes.size() == 3:
		var min_sep: float = 1e9
		for i in range(nodes.size()):
			for j in range(i + 1, nodes.size()):
				var a: Vector3 = (nodes[i] as Node3D).global_position
				var b: Vector3 = (nodes[j] as Node3D).global_position
				min_sep = minf(min_sep, Vector2(a.x - b.x, a.z - b.z).length())
		_expect(min_sep >= 30.0, "echelon spread holds (min separation %.1fm)" % min_sep)

	# Drive the roster clock past the leak deadline: all 3 must retire and free.
	var deadline_ms: int = int((AirTraffic.MAX_FLIGHT_SECONDS + 1.0) * 1000.0)
	for f: Dictionary in roster:
		f["born_ms"] = Time.get_ticks_msec() - deadline_ms
	at._process(0.0)
	_expect(at.get_in_flight().is_empty(), "all 3 ships retire at the leak deadline")
	await get_tree().process_frame
	await get_tree().process_frame
	var freed: int = 0
	for n in nodes:
		if not is_instance_valid(n):
			freed += 1
	_expect(freed == nodes.size(), "every ship's node is freed (%d/%d)" % [freed, nodes.size()])

	# Skyraider section: exactly 2, same cleanup path.
	at._dispatch("skyraider", 2)
	_expect(at.get_in_flight().size() == 2,
		"skyraider section rosters 2 (got %d)" % at.get_in_flight().size())
	_retire_all(at)

	# Chinook can never form up, even when forced.
	at._dispatch("chinook", 3)
	_expect(at.get_in_flight().size() == 1,
		"chinook stays solo even when forced (got %d)" % at.get_in_flight().size())
	_retire_all(at)

	# The roll is deterministic per sim hour + kind: two dispatches agree.
	at._dispatch("huey")
	var n1: int = at.get_in_flight().size()
	_retire_all(at)
	at._dispatch("huey")
	var n2: int = at.get_in_flight().size()
	_retire_all(at)
	_expect(n1 >= 1 and n1 <= 3, "unforced huey flight sized 1..3 (got %d)" % n1)
	_expect(n1 == n2, "same sim hour rolls the same formation (%d vs %d)" % [n1, n2])

	print("")
	if _failures == 0:
		print("=== PROBE PASS ===")
		get_tree().quit(0)
	else:
		push_error("AIR FORMATION: %d assertion(s) failed." % _failures)
		print("=== PROBE FAIL (%d) ===" % _failures)
		get_tree().quit(1)


func _retire_all(at: AirTraffic) -> void:
	var deadline_ms: int = int((AirTraffic.MAX_FLIGHT_SECONDS + 1.0) * 1000.0)
	for f: Dictionary in at.get_in_flight():
		f["born_ms"] = Time.get_ticks_msec() - deadline_ms
	at._process(0.0)


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1


func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var xf: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
			var box: AABB = xf * mi.get_aabb()
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c in n.get_children():
			stack.push_back(c)
	return result
