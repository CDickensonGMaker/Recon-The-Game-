## test_generator.gd - NS09: plans deterministic, spawns valid, all 3 types.
## Run: godot --headless --path . res://tests/test_generator.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 42
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

	for type in [MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID, MissionGenerator.MissionType.FIREBASE_DEFENSE]:
		for mseed in [7, 8, 9]:
			var p: Dictionary = MissionGenerator.plan(world, mseed, type)
			var obj_count: int = p.objectives.size()
			if obj_count < 1 or obj_count > 5:
				print("FAIL: type %d seed %d objectives=%d" % [type, mseed, obj_count])
				failures += 1
			# All positioned objectives + groups valid.
			for obj in p.objectives:
				if obj.has("pos") and obj.pos != Vector3.ZERO:
					if world.gameplay_grid.is_water(obj.pos):
						print("FAIL: objective in water (type %d seed %d)" % [type, mseed])
						failures += 1
			for g in p.enemy_groups:
				if world.gameplay_grid.is_water(g.pos):
					print("FAIL: enemy group in water")
					failures += 1
			if p.insertion_lz == Vector3.ZERO or p.exfil_lz == Vector3.ZERO:
				print("FAIL: missing LZ (type %d seed %d)" % [type, mseed])
				failures += 1

	# Determinism: same seed+type twice -> identical plans.
	var a: Dictionary = MissionGenerator.plan(world, 55, MissionGenerator.MissionType.PATROL)
	var b: Dictionary = MissionGenerator.plan(world, 55, MissionGenerator.MissionType.PATROL)
	if str(a) != str(b):
		print("FAIL: plans not deterministic")
		failures += 1
	print("determinism check: codename=%s objectives=%d groups=%d" % [a.codename, a.objectives.size(), a.enemy_groups.size()])

	# Build one village raid end (heaviest build path) and count content.
	var director := MissionDirector.new()
	add_child(director)
	director.setup(world)
	var plan_v: Dictionary = MissionGenerator.plan(world, 21, MissionGenerator.MissionType.VILLAGE_RAID)
	var built: Dictionary = MissionGenerator.build(world, director, plan_v)
	await get_tree().create_timer(1.0).timeout
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	print("village build: sensors=%d enemies=%d sites=%d" % [built.sensors.size(), enemy_count, built.sites.size()])
	if built.sensors.size() != 2:
		print("FAIL: village raid sensors=%d expected 2" % built.sensors.size())
		failures += 1
	if enemy_count < 6:
		print("FAIL: village defenders=%d expected >=6" % enemy_count)
		failures += 1
	if built.exfil_zone == null:
		print("FAIL: no exfil zone")
		failures += 1

	if failures == 0:
		print("PASS: generator plans + build OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d generator failures" % failures)
		get_tree().quit(1)
