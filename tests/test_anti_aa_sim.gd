## test_anti_aa_sim.gd - W03: ANTI-AA sweep end-to-end (satchel all guns).
## Run: godot --headless --path . res://tests/test_anti_aa_sim.tscn
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
	world.mission_seed = 911
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

	var plan: Dictionary = MissionGenerator.plan(world, 77, MissionGenerator.MissionType.ANTI_AA)
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	var player: CharacterBody3D = world.player
	await get_tree().create_timer(0.5).timeout

	var failures: int = 0
	var plants: Array = []
	for s in built.sensors:
		if s is PlantCharge:
			plants.append(s)
	print("anti-aa: %d gun objectives" % plants.size())
	if plants.size() < 2:
		print("FAIL: expected >=2 AA objectives")
		failures += 1

	for p in plants:
		var pc := p as PlantCharge
		player.global_position = pc.global_position + Vector3(1, 1, 0)
		pc.set_physics_process(false)
		for i in range(45):
			pc.advance_plant(0.1)
		await get_tree().create_timer(0.3).timeout

	if not director.state.is_exfil_unlocked():
		print("FAIL: exfil locked after all guns destroyed")
		failures += 1
	if not bool(director.state.flags.get("is_anti_aa", false)):
		print("FAIL: is_anti_aa flag missing")
		failures += 1

	# Ride out.
	var exfil: ExfilZone = built.exfil_zone
	var wait: float = 0.0
	while not mission_done and wait < 90.0:
		player.global_position = exfil.global_position + Vector3(0, 1, 0)
		await get_tree().create_timer(0.5).timeout
		wait += 0.5
	if not mission_done or not bool(result.get("is_anti_aa", false)):
		print("FAIL: mission did not complete with anti_aa flag (done=%s)" % mission_done)
		failures += 1

	if failures == 0:
		print("PASS: ANTI-AA sweep end-to-end")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
