extends Node
## test_air_fleet.gd - AirTraffic registered ONE flyable scene while three
## existed, and flew every route through -500..+500 while the AO spans
## 0..map_size. Asserts the whole roster materialises, that routes cross the
## real AO, and that a firebase landing cycle reaches the pad and lifts again.
##
## Run: godot --headless --path . res://tests/test_air_fleet.tscn

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: AIR FLEET ===")
	SimClock.paused = true

	CampaignState.reset_campaign()
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(31337, "OPERATION AIR FLEET")
	var elapsed: float = 0.0
	while elapsed < 180.0:
		if flow.world != null and flow.world.is_world_ready:
			break
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	var world: GameWorld = flow.world
	if world == null or not world.is_world_ready:
		print("FAIL: world timeout")
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.0).timeout

	var at := world.get_node_or_null("AirTraffic") as AirTraffic
	_expect(at != null, "AirTraffic is wired into the world")
	if at == null:
		get_tree().quit(1)
		return

	# --- every registered kind must actually put a node in the sky ---
	var kinds: Array = AirTraffic.FLIGHT_SCENES.keys()
	kinds.append("spooky")
	_expect(kinds.size() >= 6,
		"fleet registers %d kinds (was 1)" % kinds.size())
	for kind: String in kinds:
		at.get_in_flight().clear()
		at._dispatch(kind)
		var roster: Array = at.get_in_flight()
		var ok: bool = roster.size() == 1
		var node: Node3D = (roster[0].get("node") as Node3D) if ok else null
		_expect(node != null and is_instance_valid(node),
			"%s materialises a real aircraft node" % kind)
		if node != null:
			_expect(node.get_parent() == world, "%s is parented into the world" % kind)

	# NEGATIVE CONTROL: an unregistered kind must NOT be rostered as a phantom.
	# A null-node entry sits on the roster for MAX_FLIGHT_SECONDS hushing the
	# wildlife from a position that never moves.
	at.get_in_flight().clear()
	at._dispatch("c130")
	_expect(at.get_in_flight().is_empty(),
		"NEGATIVE CONTROL: an unflyable kind rosters nothing")

	# --- routes must cross the playable AO ---
	var m: float = world.map_size
	var crossed: int = 0
	for _i in range(40):
		var r: Array = at._ao_route()
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var mid: Vector3 = (a + b) * 0.5
		if mid.x > 0.0 and mid.x < m and mid.z > 0.0 and mid.z < m:
			crossed += 1
	_expect(crossed == 40,
		"every route's midpoint lands inside 0..%d (got %d/40)" % [int(m), crossed])

	# --- a transit that reaches its destination retires promptly ---
	# Destinations are ground-plane points and the aircraft cruises well above
	# them, so a 3D distance gate never closes and the flight lingered to the
	# 240s cap.
	at.get_in_flight().clear()
	at._dispatch("huey")
	if at.get_in_flight().size() == 1:
		var tf: Dictionary = at.get_in_flight()[0]
		var tn := tf.get("node") as Node3D
		var td: Vector3 = tf["dest"]
		tn.global_position = Vector3(td.x, td.y + 60.0, td.z)
		at._process(0.0)
		_expect(at.get_in_flight().is_empty(),
			"a transit at its destination retires even while at cruise altitude")

	# --- the firebase landing cycle ---
	at.get_in_flight().clear()
	var lzs: Array = at._firebase_lzs()
	_expect(lzs.size() > 0, "firebase pads resolved into LandingZones (got %d)" % lzs.size())
	if lzs.size() > 0:
		at._dispatch_lz_cycle("huey")
		_expect(at.get_in_flight().size() == 1, "landing cycle dispatched")
		var f: Dictionary = at.get_in_flight()[0]
		var heli := f.get("node") as Helicopter
		_expect(heli != null, "landing cycle spawned a Helicopter")
		if heli != null:
			var lz := lzs[0] as LandingZone
			# Fly it in: wait for the pad touchdown.
			var t: float = 0.0
			while heli.state != Helicopter.State.LANDED and t < 120.0:
				await get_tree().create_timer(0.25).timeout
				t += 0.25
			_expect(heli.state == Helicopter.State.LANDED,
				"huey reached the firebase pad and landed (%.1fs)" % t)
			var pad_y: float = world.terrain_manager.get_height_at(heli.global_position)
			_expect(absf(heli.global_position.y - pad_y) < 2.0,
				"landed on the deck, not hovering (dy=%.2f)" %
				absf(heli.global_position.y - pad_y))
			_expect(lz.helicopters_present >= 1, "pad occupancy taken")
			# Ground time, then it must lift off on its own.
			var t2: float = 0.0
			while String(f.get("phase", "")) != "outbound" and t2 < 120.0:
				await get_tree().create_timer(0.25).timeout
				t2 += 0.25
			_expect(String(f.get("phase", "")) == "outbound",
				"huey sat on the pad then departed (phase=%s)" % f.get("phase", ""))
			_expect(heli.state == Helicopter.State.FLYING,
				"departed under power, not parked forever")

	print("")
	if _failures == 0:
		print("=== PROBE PASS ===")
		get_tree().quit(0)
	else:
		push_error("AIR FLEET: %d assertion(s) failed." % _failures)
		print("=== PROBE FAIL (%d) ===" % _failures)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
