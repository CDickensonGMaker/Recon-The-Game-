## test_village_sim.gd - NS11: full VILLAGE RAID autopilot.
## Kill defenders -> plant charge (real crater) -> exfil order enforced.
## Run: godot --headless --path . res://tests/test_village_sim.tscn
extends Node

var mission_done: bool = false
var mission_result: Dictionary = {}


func _on_completed(result: Dictionary) -> void:
	mission_done = true
	mission_result = result


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 555
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

	var director := MissionDirector.new()
	world.add_child(director)
	director.setup(world)
	director.mission_completed.connect(_on_completed)

	var plan: Dictionary = MissionGenerator.plan(world, 66, MissionGenerator.MissionType.VILLAGE_RAID)
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	var player: CharacterBody3D = world.player
	await get_tree().create_timer(1.0).timeout

	var failures: int = 0
	print("village raid: %s defenders=%d" % [plan.codename, get_tree().get_nodes_in_group("village_defenders").size()])

	# Exfil must refuse first.
	var exfil: ExfilZone = built.exfil_zone
	player.global_position = exfil.global_position + Vector3(0, 1, 0)
	await get_tree().create_timer(0.8).timeout
	if mission_done:
		print("FAIL: mission completed before objectives")
		failures += 1

	# Kill all defenders.
	for e in get_tree().get_nodes_in_group("village_defenders"):
		var enemy := e as EnemyBase
		while not enemy.is_dead():
			enemy.take_damage(150, Enums.DamageType.PHYSICAL, player)
	await get_tree().create_timer(0.5).timeout
	if not director.state.is_objective_complete(1):
		print("FAIL: clear objective incomplete after killing all")
		failures += 1

	# Plant at the cache: crater must lower terrain.
	var plant: PlantCharge = null
	for s in built.sensors:
		if s is PlantCharge:
			plant = s
	if plant == null:
		print("FAIL: no plant sensor")
		get_tree().quit(1)
		return
	var cache_pos: Vector3 = plant.global_position
	var before: float = world.terrain_manager.get_height_at(cache_pos)
	player.global_position = cache_pos + Vector3(1, 1, 0)
	plant.set_physics_process(false)
	for i in range(45):
		plant.advance_plant(0.1)
	await get_tree().create_timer(0.5).timeout
	var after: float = world.terrain_manager.get_height_at(cache_pos)
	print("cache crater: before=%.2f after=%.2f" % [before, after])
	if after >= before:
		print("FAIL: no crater from planted charge")
		failures += 1
	if not director.state.is_objective_complete(0):
		print("FAIL: plant objective incomplete")
		failures += 1

	# Exfil now completes (bird cycle: call, land, board).
	var wait: float = 0.0
	while not mission_done and wait < 90.0:
		player.global_position = exfil.global_position + Vector3(0, 1, 0)
		await get_tree().create_timer(0.5).timeout
		wait += 0.5
	if not mission_done or not bool(mission_result.success):
		print("FAIL: mission did not complete after objectives")
		failures += 1
	else:
		print("result: kills=%d objectives=%d/%d" % [mission_result.kills, mission_result.objectives_done, mission_result.objectives_total])

	if failures == 0:
		print("PASS: village raid end-to-end")
		get_tree().quit(0)
	else:
		print("FAIL: %d village failures" % failures)
		get_tree().quit(1)
