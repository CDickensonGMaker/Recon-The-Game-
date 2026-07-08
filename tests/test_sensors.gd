## test_sensors.gd - NS08: sensors flip bits in order; exfil refuses early.
## Run: godot --headless --path . res://tests/test_sensors.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/nva_regular.tres"

## Member vars (GDScript lambdas capture locals by value).
var mission_done: bool = false
var refusals: int = 0
var planted: bool = false


func _ready() -> void:
	_run()


func _on_mission_completed(_r: Dictionary) -> void:
	mission_done = true


func _on_at_exfil(unlocked: bool) -> void:
	if not unlocked:
		refusals += 1


func _on_planted(_p: Vector3) -> void:
	planted = true


func _run() -> void:
	var failures: int = 0

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0, 1.0, 0)

	var director := MissionDirector.new()
	add_child(director)
	director.setup(null)

	var reach := ReachZone.new()
	reach.objective_index = 0
	reach.title = "REACH CHECKPOINT"
	add_child(reach)
	reach.global_position = Vector3(50, 0, 0)
	reach.register(director)

	var plant := PlantCharge.new()
	plant.objective_index = 1
	plant.title = "DESTROY CACHE"
	add_child(plant)
	plant.global_position = Vector3(80, 0, 0)
	plant.register(director)

	var kills := KillCountObjective.new()
	kills.objective_index = 2
	kills.title = "CLEAR AREA"
	kills.group_tag = "grp_test"
	kills.total_count = 2
	kills.required_fraction = 1.0
	add_child(kills)
	kills.register(director)

	var exfil := ExfilZone.new()
	exfil.complete_on_enter = true
	add_child(exfil)
	exfil.global_position = Vector3(-60, 0, 0)
	exfil.register(director)

	director.mission_completed.connect(_on_mission_completed)
	exfil.player_at_exfil.connect(_on_at_exfil)

	# 1. Exfil must refuse while nothing is done.
	player.global_position = Vector3(-60, 1.0, 0)
	await get_tree().create_timer(0.6).timeout
	if refusals == 0:
		print("FAIL: exfil did not refuse early")
		failures += 1
	if mission_done:
		print("FAIL: mission completed with objectives open")
		failures += 1

	# 2. Reach.
	player.global_position = Vector3(50, 1.0, 2)
	await get_tree().create_timer(0.6).timeout
	if not director.state.is_objective_complete(0):
		print("FAIL: reach zone did not complete")
		failures += 1

	# 3. Plant (driven via advance_plant; disable its input polling first so
	# the release-reset doesn't fight the test driver).
	player.global_position = Vector3(80, 1.0, 1)
	plant.set_physics_process(false)
	plant.charge_planted.connect(_on_planted)
	for i in range(45):
		plant.advance_plant(0.1)
	await get_tree().process_frame
	if not director.state.is_objective_complete(1) or not planted:
		print("FAIL: plant charge did not complete")
		failures += 1

	# 4. Kill group.
	var e1 := director.spawn_tracked_enemy(Vector3(100, 1, 0), ENEMY_DATA, "grp_test")
	var e2 := director.spawn_tracked_enemy(Vector3(104, 1, 0), ENEMY_DATA, "grp_test")
	e1.add_to_group("grp_test")
	e2.add_to_group("grp_test")
	await get_tree().create_timer(0.3).timeout
	for e in [e1, e2]:
		while not e.is_dead():
			e.take_damage(120, Enums.DamageType.PHYSICAL, player)
	await get_tree().create_timer(0.3).timeout
	if not director.state.is_objective_complete(2):
		print("FAIL: kill count did not complete")
		failures += 1

	# 5. Exfil now unlocks and finishes the mission.
	if not director.state.is_exfil_unlocked():
		print("FAIL: exfil still locked after all objectives")
		failures += 1
	player.global_position = Vector3(-60, 1.0, 0)
	await get_tree().create_timer(0.8).timeout
	if not mission_done:
		print("FAIL: mission did not complete at exfil")
		failures += 1

	if failures == 0:
		print("PASS: all sensors + exfil gate OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d sensor failures" % failures)
		get_tree().quit(1)
