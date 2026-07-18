## test_site_stamp.gd - NS06: plan+stamp village/firebase/LZs on 3 seeds.
## Run: godot --headless --path . res://tests/test_site_stamp.tscn
extends Node

const SEEDS: Array[int] = [42, 1337, 9001]


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	for seed_val in SEEDS:
		var result: int = await _test_seed(seed_val)
		failures += result
	if failures == 0:
		print("PASS: sites stamped on all seeds")
		get_tree().quit(0)
	else:
		print("FAIL: %d site failures" % failures)
		get_tree().quit(1)


func _test_seed(seed_val: int) -> int:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = seed_val
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL[%d]: world timeout" % seed_val)
		world.queue_free()
		return 1

	var failures: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)

	var village_center: Vector3 = planner.find_site(rng, 26.0)
	var camp_center: Vector3 = planner.find_site(rng, 14.0)
	var lz1: Vector3 = planner.find_site(rng, 16.0)
	var lz2: Vector3 = planner.find_site(rng, 16.0)
	for pair in [["village", village_center], ["camp", camp_center], ["lz1", lz1], ["lz2", lz2]]:
		if pair[1] == Vector3.ZERO:
			print("FAIL[%d]: no site found for %s" % [seed_val, pair[0]])
			failures += 1
	if failures > 0:
		world.queue_free()
		return failures

	var village: Dictionary = planner.stamp_village(village_center, rng)
	var camp: Dictionary = planner.stamp_vc_camp(camp_center, rng)
	planner.stamp_lz(lz1)
	planner.stamp_lz(lz2)

	if village.nodes.size() < 7:
		print("FAIL[%d]: village too small (%d nodes)" % [seed_val, village.nodes.size()])
		failures += 1
	if camp.nodes.size() < 3:
		print("FAIL[%d]: vc camp too small (%d nodes)" % [seed_val, camp.nodes.size()])
		failures += 1

	# Separation check.
	var centers: Array[Vector3] = [village_center, camp_center, lz1, lz2]
	for i in range(centers.size()):
		for j in range(i + 1, centers.size()):
			var d: float = centers[i].distance_to(centers[j])
			if d < 200.0:
				print("FAIL[%d]: sites %d/%d only %.0fm apart" % [seed_val, i, j, d])
				failures += 1

	# No structure under water; all seated near ground.
	for node in (village.nodes as Array) + (camp.nodes as Array):
		var n := node as Node3D
		if world.gameplay_grid.is_water(n.global_position):
			print("FAIL[%d]: %s in water" % [seed_val, n.name])
			failures += 1
		var gy: float = world.terrain_manager.get_height_at(n.global_position)
		if absf(n.global_position.y - gy) > 4.0:
			print("FAIL[%d]: %s floating (%.1fm off ground)" % [seed_val, n.name, absf(n.global_position.y - gy)])
			failures += 1

	print("seed %d: village=%s camp=%s nodes=%d/%d" % [
		seed_val, village_center, camp_center,
		village.nodes.size(), camp.nodes.size()])

	world.queue_free()
	await get_tree().process_frame
	return failures
