## test_rescue_sim.gd - W48: free the POW, he joins, exfil completes.
## Run: godot --headless --path . res://tests/test_rescue_sim.tscn
extends Node

var mission_done: bool = false
var result: Dictionary = {}


func _on_done(r: Dictionary) -> void:
	mission_done = true
	result = r


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 848
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
	director.mission_completed.connect(_on_done)

	var plan: Dictionary = MissionGenerator.plan(world, 55, MissionGenerator.MissionType.RESCUE)
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	var player: CharacterBody3D = world.player
	await get_tree().create_timer(0.5).timeout

	var failures: int = 0
	var rescue: RescueObjective = null
	for s in built.sensors:
		if s is RescueObjective:
			rescue = s
	if rescue == null:
		print("FAIL: no rescue objective")
		get_tree().quit(1)
		return

	# Kill the guards (they'd shred the POW walk otherwise).
	for e in get_tree().get_nodes_in_group("pow_guards"):
		var enemy := e as EnemyBase
		while enemy and not enemy.is_dead():
			enemy.take_damage(200, Enums.DamageType.PHYSICAL, player)
	await get_tree().create_timer(0.5).timeout

	# Free the POW.
	player.global_position = rescue.global_position + Vector3(1, 1, 0)
	rescue.set_physics_process(false)
	for i in range(30):
		rescue.advance_free(0.1)
	await get_tree().create_timer(0.5).timeout
	if not director.state.is_objective_complete(0):
		print("FAIL: rescue objective incomplete")
		failures += 1
	if rescue.pow_ally == null or rescue.pow_ally.is_dead():
		print("FAIL: no living POW ally")
		failures += 1

	# Exfil ride.
	var exfil: ExfilZone = built.exfil_zone
	var wait: float = 0.0
	while not mission_done and wait < 90.0:
		player.global_position = exfil.global_position + Vector3(0, 1, 0)
		await get_tree().create_timer(0.5).timeout
		wait += 0.5
	if not mission_done or not bool(result.success):
		print("FAIL: rescue mission did not complete")
		failures += 1
	if bool(result.get("pow_lost", false)):
		print("FAIL: pow_lost flag set on a clean run")
		failures += 1

	if failures == 0:
		print("PASS: POW rescue end-to-end")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
