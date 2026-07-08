## test_patrol_sim.gd - NS10: full PATROL mission autopilot.
## Insert -> checkpoints -> (contacts may spawn) -> exfil -> mission_completed.
## Run: godot --headless --path . res://tests/test_patrol_sim.tscn
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
	world.mission_seed = 4242
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
	director.toast.connect(func(t: String) -> void: print("[TOAST] %s" % t))

	var plan: Dictionary = MissionGenerator.plan(world, 99, MissionGenerator.MissionType.PATROL)
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	var player: CharacterBody3D = world.player

	print("patrol: %s, %d objectives, %d groups" % [plan.codename, plan.objectives.size(), plan.enemy_groups.size()])

	# Autopilot: teleport through REQUIRED checkpoints (walk pace is not the test).
	for obj in plan.objectives:
		if not bool(obj.required):
			continue
		var pos: Vector3 = obj.pos
		player.global_position = Vector3(pos.x, world.terrain_manager.get_height_at(pos) + 1.0, pos.z)
		await get_tree().create_timer(0.7).timeout

	var required_done := true
	for obj in plan.objectives:
		if bool(obj.required) and not director.state.is_objective_complete(int(obj.index)):
			required_done = false
			print("FAIL: checkpoint %s incomplete" % obj.title)
	if not required_done:
		get_tree().quit(1)
		return
	if not director.state.is_exfil_unlocked():
		print("FAIL: exfil locked after all required checkpoints")
		get_tree().quit(1)
		return

	# Contacts: lazy groups near checkpoints should have spawned when we passed.
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	print("enemies spawned by proximity: %d" % enemies)

	# Exfil.
	var exfil_pos: Vector3 = plan.exfil_lz
	player.global_position = Vector3(exfil_pos.x, world.terrain_manager.get_height_at(exfil_pos) + 1.0, exfil_pos.z)
	await get_tree().create_timer(1.0).timeout

	if mission_done and bool(mission_result.success):
		print("result: %s" % [mission_result])
		print("PASS: patrol mission end-to-end")
		get_tree().quit(0)
	else:
		print("FAIL: mission did not complete at exfil")
		get_tree().quit(1)
