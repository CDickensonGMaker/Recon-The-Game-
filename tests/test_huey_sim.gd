## test_huey_sim.gd - NS14: Huey flies 800m, lands on the pad, takes off.
## Run: godot --headless --path . res://tests/test_huey_sim.tscn
extends Node

var states_seen: Array[String] = []
var landed_ok: bool = false
var takeoff_ok: bool = false


func _ready() -> void:
	_run()


func _on_landed(_h: Helicopter, _lz: LandingZone) -> void:
	landed_ok = true


func _on_took_off(_h: Helicopter) -> void:
	takeoff_ok = true


func _run() -> void:
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

	# Flattened LZ.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var lz_center: Vector3 = planner.find_site(rng, 16.0, 0.0)
	planner.stamp_lz(lz_center)
	var lz := LandingZone.new()
	world.add_child(lz)
	lz.global_position = Vector3(lz_center.x, world.terrain_manager.get_height_at(lz_center), lz_center.z)

	var heli: Helicopter = (load("res://scenes/vehicles/huey.tscn") as PackedScene).instantiate()
	world.add_child(heli)
	heli.setup(world.terrain_manager)
	var start := lz_center + Vector3(800, 0, 200)
	start.x = clampf(start.x, 80, world.map_size - 80)
	start.z = clampf(start.z, 80, world.map_size - 80)
	heli.global_position = Vector3(start.x, world.terrain_manager.get_height_at(start) + 30.0, start.z)
	heli.landed.connect(_on_landed)
	heli.took_off.connect(_on_took_off)

	heli.fly_to(lz.global_position, lz)

	var last_state: int = -1
	var t: float = 0.0
	while not landed_ok and t < 90.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if heli.state != last_state:
			last_state = heli.state
			states_seen.append(Helicopter.State.keys()[heli.state])

	var failures: int = 0
	if not landed_ok:
		print("FAIL: never landed (states: %s)" % [states_seen])
		failures += 1
	else:
		var pad_y: float = world.terrain_manager.get_height_at(lz.global_position)
		var dy: float = absf(heli.global_position.y - pad_y)
		print("landed after %.1fs, dy=%.2f, states=%s" % [t, dy, states_seen])
		if dy > 1.5:
			print("FAIL: landed %.2fm off pad height" % dy)
			failures += 1
		if lz.helicopters_present != 1:
			print("FAIL: LZ occupancy wrong")
			failures += 1

	heli.take_off()
	var t2: float = 0.0
	while not takeoff_ok and t2 < 20.0:
		await get_tree().create_timer(0.25).timeout
		t2 += 0.25
	if not takeoff_ok:
		print("FAIL: takeoff never completed")
		failures += 1

	if failures == 0:
		print("PASS: huey flight cycle OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
