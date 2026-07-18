## test_mission_state.gd - NS07: kill-count fix + bitmask/exfil-gate math.
## Run: godot --headless --path . res://tests/test_mission_state.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0

	# --- Pure bitmask math ---
	var s := MissionState.new()
	s.register_objective(0, "DESTROY CACHE", true)
	s.register_objective(1, "CLEAR VILLAGE", true)
	s.register_objective(2, "BONUS RECON", false)
	if s.is_exfil_unlocked():
		print("FAIL: exfil unlocked with nothing done")
		failures += 1
	s.complete_objective(0)
	if s.is_exfil_unlocked():
		print("FAIL: exfil unlocked at 1/2 required")
		failures += 1
	s.complete_objective(2)  # optional shouldn't unlock
	if s.is_exfil_unlocked():
		print("FAIL: optional objective unlocked exfil")
		failures += 1
	s.complete_objective(1)
	if not s.is_exfil_unlocked():
		print("FAIL: exfil locked with all required done")
		failures += 1
	if s.complete_objective(1):
		print("FAIL: re-completion not idempotent")
		failures += 1
	if s.objectives_done() != 3:
		print("FAIL: objectives_done=%d expected 3" % s.objectives_done())
		failures += 1

	# --- Kill counting through real EnemyBase deaths ---
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)

	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player := player_scene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 1.0, 0)

	var director := FieldDirector.new()
	add_child(director)
	director.setup(null)  # no GameWorld in this synthetic scene

	for i in range(3):
		director.spawn_tracked_enemy(Vector3(10.0 + float(i) * 3.0, 1.0, 10.0), ENEMY_DATA)
	await get_tree().create_timer(0.5).timeout

	if director.live_enemy_count() != 3:
		print("FAIL: live_enemy_count=%d expected 3" % director.live_enemy_count())
		failures += 1

	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		while not enemy.is_dead():
			enemy.take_damage(100, Enums.DamageType.PHYSICAL, player)
	await get_tree().create_timer(0.5).timeout

	print("kills=%d live=%d" % [director.state.kills, director.live_enemy_count()])
	if director.state.kills != 3:
		print("FAIL: kills=%d expected 3 (kill-count fix broken)" % director.state.kills)
		failures += 1
	if director.live_enemy_count() != 0:
		print("FAIL: live enemies remain")
		failures += 1

	var result: Dictionary = director.state.build_result(true)
	if int(result.kills) != 3 or int(result.objectives_total) != 0:
		print("FAIL: result dict wrong: %s" % result)
		failures += 1

	if failures == 0:
		print("PASS: mission state + kill tracking OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d failures" % failures)
		get_tree().quit(1)
