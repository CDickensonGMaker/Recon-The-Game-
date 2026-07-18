## test_village_props.gd - uiho: Caleb's market props spawn into villages.
## Asserts: props placed + OUTSIDE building footprints (Summoner hard rule),
## off water + seated, work stations collected from GLB work_* empties,
## deterministic re-stamp, and the 8-man squad + player fit the Huey pax seats.
## Run: godot --headless --path . res://tests/test_village_props.tscn
extends Node

const SEED_VAL: int = 2077


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0

	# Seat contract: the village assault rides in - 8 allies + the player.
	if SeatSystem.PASSENGER_SEATS.size() < SquadSystem.SQUAD_SIZE + 1:
		print("FAIL: %d passenger seats < squad %d + player" % [
			SeatSystem.PASSENGER_SEATS.size(), SquadSystem.SQUAD_SIZE])
		failures += 1

	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
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

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var center: Vector3 = planner.find_site(rng, 26.0)
	if center == Vector3.ZERO:
		print("FAIL: no village site found")
		get_tree().quit(1)
		return

	rng.seed = SEED_VAL + 555
	var village: Dictionary = planner.stamp_village(center, rng)
	var props: Array = village.get("prop_nodes", [])
	var stations: Array = village.get("work_stations", [])

	if props.size() < 8:
		print("FAIL: only %d props placed (want >= 8)" % props.size())
		failures += 1
	if stations.size() < 2:
		print("FAIL: only %d work stations collected (want >= 2)" % stations.size())
		failures += 1
	var has_cook: bool = false
	for st in stations:
		if str((st as Dictionary).get("type", "")) == "cook":
			has_cook = true
	if not has_cook:
		print("FAIL: no cook station (CampDirector cook role starves)")
		failures += 1

	# Summoner hard rule: outside buildings, never inside. Check against the
	# authored footprint (no margin - the margin is placement headroom).
	var structures: Array = village.get("nodes", [])
	for pn in props:
		var prop := pn as Node3D
		for sn in structures:
			var b := sn as Node3D
			if b == null or not is_instance_valid(b):
				continue
			var entry: Dictionary = CollisionTable.get_entry(str(b.get_meta("model_name", b.name)))
			var fp: Vector2 = entry.get("footprint", Vector2(4, 4)) as Vector2
			var clearance: float = maxf(fp.x, fp.y) * 0.5
			var d: float = Vector2(prop.global_position.x - b.global_position.x,
				prop.global_position.z - b.global_position.z).length()
			if d < clearance:
				print("FAIL: %s INSIDE %s footprint (%.1fm < %.1fm)" % [prop.name, b.name, d, clearance])
				failures += 1
		if world.gameplay_grid.is_water(prop.global_position):
			print("FAIL: %s in water" % prop.name)
			failures += 1
		var gy: float = world.terrain_manager.get_height_at(prop.global_position)
		if absf(prop.global_position.y - gy) > 4.0:
			print("FAIL: %s floating %.1fm" % [prop.name, absf(prop.global_position.y - gy)])
			failures += 1

	# Determinism (ADR-010): identical rng seed + center => identical prop layout.
	var fp_a: String = _fingerprint(props, center)
	rng.seed = SEED_VAL + 555
	var village_b: Dictionary = planner.stamp_village(center, rng)
	var fp_b: String = _fingerprint(village_b.get("prop_nodes", []), center)
	if fp_a != fp_b:
		print("FAIL: prop layout not deterministic")
		print("A=" + fp_a)
		print("B=" + fp_b)
		failures += 1

	print("village props: %d props, %d stations, det=%s" % [
		props.size(), stations.size(), str(fp_a == fp_b)])
	world.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("PASS: village props placed, honest, deterministic")
		get_tree().quit(0)
	else:
		print("FAIL: %d village prop failures" % failures)
		get_tree().quit(1)


func _fingerprint(props: Array, center: Vector3) -> String:
	var parts: Array[String] = []
	for pn in props:
		var p := pn as Node3D
		var rel: Vector3 = p.global_position - center
		var model: String = str(p.get_meta("prop_model", p.name))
		parts.append("%s@%.2f,%.2f,%.2f r%.1f" % [model, rel.x, rel.y, rel.z, p.rotation_degrees.y])
	parts.sort()
	return " | ".join(parts)
