## test_vehicle_kill.gd - NS17: vehicle-target variant works; both variants roll.
## Run: godot --headless --path . res://tests/test_vehicle_kill.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 202
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

	var failures: int = 0

	# Variant coverage across 12 seeds (plans only - cheap).
	var kinds := {}
	for s in range(12):
		var p: Dictionary = MissionGenerator.plan(world, 300 + s, MissionGenerator.MissionType.VILLAGE_RAID)
		kinds[str(p.village_target)] = true
	print("village target variants seen: %s" % [kinds.keys()])
	if kinds.size() < 2:
		print("FAIL: only one variant across 12 seeds")
		failures += 1

	# Find a vehicle-variant seed and run destruction.
	var vehicle_seed: int = -1
	for s in range(300, 340):
		var p2: Dictionary = MissionGenerator.plan(world, s, MissionGenerator.MissionType.VILLAGE_RAID)
		if str(p2.village_target) == "vehicle":
			vehicle_seed = s
			break
	if vehicle_seed < 0:
		print("FAIL: no vehicle variant found")
		get_tree().quit(1)
		return

	var director := MissionDirector.new()
	world.add_child(director)
	director.setup(world)
	var plan: Dictionary = MissionGenerator.plan(world, vehicle_seed, MissionGenerator.MissionType.VILLAGE_RAID)
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	await get_tree().create_timer(0.5).timeout

	var plant: PlantCharge = null
	for s in built.sensors:
		if s is PlantCharge:
			plant = s
	var vehicle: DestructibleVehicle = null
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is DestructibleVehicle:
			vehicle = n
			break
		for c in n.get_children():
			stack.push_back(c)
	if vehicle == null or plant == null:
		print("FAIL: vehicle target or plant sensor missing")
		get_tree().quit(1)
		return

	var target_pos: Vector3 = vehicle.global_position
	var before: float = world.terrain_manager.get_height_at(target_pos)
	world.player.global_position = target_pos + Vector3(1.5, 1, 0)
	plant.set_physics_process(false)
	for i in range(45):
		plant.advance_plant(0.1)
	await get_tree().create_timer(0.6).timeout

	if not vehicle.is_destroyed:
		print("FAIL: vehicle not destroyed after plant")
		failures += 1
	var after: float = world.terrain_manager.get_height_at(target_pos)
	print("vehicle destroyed=%s crater=%.2f objective=%s" % [vehicle.is_destroyed, before - after, director.state.is_objective_complete(0)])
	if after >= before:
		print("FAIL: no crater under vehicle")
		failures += 1
	if not director.state.is_objective_complete(0):
		print("FAIL: plant objective incomplete")
		failures += 1

	if failures == 0:
		print("PASS: destructible vehicle objective OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
