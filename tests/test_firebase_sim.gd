## test_firebase_sim.gd - NS12: FIREBASE DEFENSE waves progress + complete.
## Run: godot --headless --path . res://tests/test_firebase_sim.tscn
extends Node

var waves_seen: Array[int] = []
var mission_done: bool = false


func _on_wave_started(n: int, _total: int, dir_text: String) -> void:
	waves_seen.append(n)
	print("wave %d from %s" % [n, dir_text])


func _on_completed(_r: Dictionary) -> void:
	mission_done = true


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 777
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

	var plan: Dictionary = MissionGenerator.plan(world, 31, MissionGenerator.MissionType.FIREBASE_DEFENSE)
	# Speed up for the sim.
	for obj in plan.objectives:
		if str(obj.kind) == "survive":
			obj["lull"] = 1.5
			obj["initial_delay"] = 1.0
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.firebase_center + Vector3(4, 0, 0))
	var player: CharacterBody3D = world.player

	var sw: SurviveWaves = null
	for s in built.sensors:
		if s is SurviveWaves:
			sw = s
	if sw == null:
		print("FAIL: no SurviveWaves sensor")
		get_tree().quit(1)
		return
	sw.wave_started.connect(_on_wave_started)

	var allies: int = get_tree().get_nodes_in_group("allies").size()
	print("allies inside the wire: %d" % allies)
	var failures: int = 0
	if allies != 5:
		print("FAIL: expected 5 allies, got %d" % allies)
		failures += 1

	# Fight the waves (force-kill each as it spawns).
	var deadline: float = 120.0
	var t: float = 0.0
	while not director.state.is_exfil_unlocked() and t < deadline:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		for e in get_tree().get_nodes_in_group("enemies"):
			var enemy := e as EnemyBase
			if enemy and not enemy.is_dead():
				enemy.take_damage(200, Enums.DamageType.PHYSICAL, player)
	# Exfil bird cycle: stand glued to the exfil zone until boarded.
	var exfil: ExfilZone = built.exfil_zone
	var wait: float = 0.0
	while not mission_done and wait < 90.0:
		player.global_position = exfil.global_position + Vector3(0, 1, 0)
		await get_tree().create_timer(0.5).timeout
		wait += 0.5

	print("waves_seen=%s kills=%d done=%s" % [waves_seen, director.state.kills, mission_done])
	if waves_seen != [1, 2, 3]:
		print("FAIL: wave order wrong: %s" % [waves_seen])
		failures += 1
	if not director.state.is_objective_complete(0):
		print("FAIL: survive objective incomplete")
		failures += 1
	if not mission_done:
		print("FAIL: mission not completed")
		failures += 1
	if director.state.kills < 15:
		print("FAIL: kills=%d expected >=15 (3 waves of 5+)" % director.state.kills)
		failures += 1

	if failures == 0:
		print("PASS: firebase defense end-to-end")
		get_tree().quit(0)
	else:
		print("FAIL: %d firebase failures" % failures)
		get_tree().quit(1)
