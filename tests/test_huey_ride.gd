## test_huey_ride.gd - W05-W10: board -> fly -> land -> dismount; plus forced
## shoot-down -> crash dismount, mission continues.
## Run: godot --headless --path . res://tests/test_huey_ride.tscn
extends Node

var ride_done: bool = false
var ride_crashed: bool = false
var ride_end_pos: Vector3 = Vector3.ZERO


func _on_ride_finished(pos: Vector3, crashed: bool) -> void:
	ride_done = true
	ride_crashed = crashed
	ride_end_pos = pos


func _ready() -> void:
	_run()


func _run() -> void:
	CampaignState.reset_campaign()
	CampaignState.threat_level = 0.0  # no AA events in scenario 1

	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 313
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

	var plan: Dictionary = MissionGenerator.plan(world, 41, MissionGenerator.MissionType.PATROL)
	MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.start_pad)
	var player: CharacterBody3D = world.player
	var failures: int = 0

	# --- Scenario 1: clean ride ---
	var ride := InsertionRide.new()
	world.add_child(ride)
	ride.setup(world, director, plan.start_pad, plan.insertion_lz)
	ride.ride_finished.connect(_on_ride_finished)
	await get_tree().create_timer(0.5).timeout

	if ride.state != InsertionRide.RideState.WAITING_BOARD:
		print("FAIL: ride not waiting")
		failures += 1
	ride.board()
	if not player.is_seated:
		print("FAIL: player not seated after board")
		failures += 1

	var t: float = 0.0
	while ride.state != InsertionRide.RideState.LANDED_LZ and t < 90.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if ride.state != InsertionRide.RideState.LANDED_LZ:
		print("FAIL: never landed at LZ (state=%d)" % ride.state)
		get_tree().quit(1)
		return
	print("ride 1: landed after %.1fs" % t)

	ride.dismount(false)
	if player.is_seated:
		print("FAIL: player still seated after dismount")
		failures += 1
	var lz_dist: float = Vector2(player.global_position.x - plan.insertion_lz.x, player.global_position.z - plan.insertion_lz.z).length()
	print("dismount distance from LZ: %.1fm" % lz_dist)
	if lz_dist > 25.0:
		print("FAIL: dismounted too far from LZ")
		failures += 1
	if not ride_done or ride_crashed:
		print("FAIL: ride_finished wrong (done=%s crashed=%s)" % [ride_done, ride_crashed])
		failures += 1

	# --- Scenario 2: shoot-down mid-flight ---
	ride_done = false
	ride_crashed = false
	var pad2: Vector3 = plan.exfil_lz  # reuse a flat pad
	var ride2 := InsertionRide.new()
	world.add_child(ride2)
	ride2.setup(world, director, pad2, plan.insertion_lz)
	ride2.ride_finished.connect(_on_ride_finished)
	player.global_position = Vector3(pad2.x + 2, world.terrain_manager.get_height_at(pad2) + 1, pad2.z)
	await get_tree().create_timer(0.3).timeout
	ride2.board()
	await get_tree().create_timer(3.0).timeout  # let it lift + start flying
	ride2.heli.shoot_down()
	t = 0.0
	while not ride_done and t < 30.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if not ride_done or not ride_crashed:
		print("FAIL: crash ride did not finish as crashed (done=%s crashed=%s)" % [ride_done, ride_crashed])
		failures += 1
	if player.is_seated:
		print("FAIL: player seated after crash")
		failures += 1
	print("crash scenario: survivors on the ground at %s" % [ride_end_pos])

	CampaignState.reset_campaign()
	if failures == 0:
		print("PASS: huey ride (clean + shootdown) OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d ride failures" % failures)
		get_tree().quit(1)
