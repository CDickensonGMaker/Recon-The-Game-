## test_cas_sim.gd - NS16: bomb run kills clustered enemies + craters terrain;
## napalm spawns fire that burns bodies. Run: godot --headless --path . res://tests/test_cas_sim.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 88
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
	var director := MissionDirector.new()
	world.add_child(director)
	director.setup(world)

	# Cluster 3 enemies away from the player.
	var target := world.player.global_position + Vector3(120, 0, 0)
	target.y = world.terrain_manager.get_height_at(target)
	var victims: Array[EnemyBase] = []
	for i in range(3):
		victims.append(director.spawn_tracked_enemy(target + Vector3(float(i) * 3.0 - 3.0, 0, 0), "res://data/enemies/german_rifleman.tres"))
	await get_tree().create_timer(0.5).timeout

	# BOMB run.
	var before: float = world.terrain_manager.get_height_at(target)
	var plane: CASAirplane = (load("res://scenes/vehicles/skyraider.tscn") as PackedScene).instantiate()
	world.add_child(plane)
	plane.call_strike(world.terrain_manager, target, CASAirplane.Ordnance.BOMB, Vector3(1, 0, 0))
	var t: float = 0.0
	while t < 30.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		if not is_instance_valid(plane):
			break
	await get_tree().create_timer(1.5).timeout

	var dead: int = 0
	for v in victims:
		if not is_instance_valid(v) or v.is_dead():
			dead += 1
	var after: float = world.terrain_manager.get_height_at(target)
	print("bomb: dead=%d/3 crater delta=%.2f" % [dead, before - after])
	if dead < 2:
		print("FAIL: bomb killed %d expected >=2" % dead)
		failures += 1
	if after >= before:
		print("FAIL: bomb left no crater")
		failures += 1

	# NAPALM fire hazard burns a fresh enemy standing in it.
	var burn_pos := world.player.global_position + Vector3(-80, 0, 40)
	burn_pos.y = world.terrain_manager.get_height_at(burn_pos)
	var burn_victim := director.spawn_tracked_enemy(burn_pos, "res://data/enemies/german_smg.tres")
	await get_tree().create_timer(0.4).timeout
	var hp_before: int = burn_victim.current_hp
	FireHazard.create_at(world, burn_pos, 10.0, 8.0)
	await get_tree().create_timer(2.5).timeout
	var hp_after: int = burn_victim.current_hp if is_instance_valid(burn_victim) and not burn_victim.is_dead() else 0
	print("napalm burn: hp %d -> %d" % [hp_before, hp_after])
	if hp_after >= hp_before:
		print("FAIL: fire hazard did no damage")
		failures += 1

	if failures == 0:
		print("PASS: CAS bomb + napalm fire OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
