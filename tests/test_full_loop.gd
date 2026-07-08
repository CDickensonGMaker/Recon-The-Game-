## test_full_loop.gd - NS22: THE MONEY TEST. menu -> select -> briefing ->
## world -> autopilot mission -> debrief -> menu, for all 3 mission types.
## Run: godot --headless --path . res://tests/test_full_loop.tscn
extends Node

var flow: GameFlow


func _ready() -> void:
	_run()


func _run() -> void:
	flow = (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as GameFlow
	add_child(flow)
	await get_tree().process_frame

	var failures: int = 0
	var type_list := [MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID, MissionGenerator.MissionType.FIREBASE_DEFENSE]
	for type in type_list:
		var r: int = await _run_type(type)
		failures += r

	if failures == 0:
		print("PASS: FULL LOOP x3 mission types")
		get_tree().quit(0)
	else:
		print("FAIL: %d full-loop failures" % failures)
		get_tree().quit(1)


func _run_type(type: int) -> int:
	print("=== FULL LOOP: type %d ===" % type)
	# 1. Menu is up.
	if not (flow.current_screen is MainMenuScreen):
		flow.show_menu()
		await get_tree().process_frame
	if not (flow.current_screen is MainMenuScreen):
		print("FAIL: no menu")
		return 1

	# 2. Select.
	flow.show_select()
	await get_tree().process_frame
	var select := flow.current_screen as MissionSelectScreen
	if select == null or select.offers.size() != 3:
		print("FAIL: select screen bad")
		return 1
	# Force the offer type under test.
	var offer: Dictionary = select.offers[0]
	offer["type"] = type
	offer["type_name"] = str(MissionGenerator.TYPE_NAMES[type])

	# 3. Briefing.
	flow.show_briefing(offer)
	await get_tree().process_frame
	if not (flow.current_screen is BriefingScreen):
		print("FAIL: no briefing")
		return 1

	# 4. Deploy.
	flow.start_mission(offer)
	var t: float = 0.0
	while (flow.world == null or not flow.world.is_world_ready or flow.director == null) and t < 200.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if flow.director == null:
		print("FAIL: mission never started")
		return 1
	# Wait for build completion (mission_hud is the last thing GameFlow wires).
	t = 0.0
	while flow.mission_hud == null and t < 60.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if flow.mission_hud == null:
		print("FAIL: mission build incomplete")
		return 1
	if flow.world.mission_seed != int(offer.world_seed):
		print("FAIL: world seed mismatch")
		return 1

	# 5. Autopilot the mission.
	var ok: bool = await _autopilot(type)
	if not ok:
		return 1

	# 6. Debrief appears (GameFlow delays 3s).
	t = 0.0
	while not (flow.current_screen is DebriefScreen) and t < 30.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if not (flow.current_screen is DebriefScreen):
		print("FAIL: no debrief")
		return 1

	# 7. Continue -> menu.
	(flow.current_screen as DebriefScreen).continue_pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not (flow.current_screen is MainMenuScreen):
		print("FAIL: no return to menu")
		return 1
	print("=== type %d loop OK ===" % type)
	return 0


func _autopilot(type: int) -> bool:
	var world := flow.world
	var director := flow.director
	var player: CharacterBody3D = world.player
	var tm := world.terrain_manager

	match type:
		MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID:
			# Kill everything tagged, plant if needed, walk checkpoints, exfil.
			await get_tree().create_timer(1.0).timeout
			# Activate + kill all enemies (also triggers lazy groups when near).
			for s in flow.mission_hud.sensors:
				if s is ReachZone:
					var rz := s as ReachZone
					player.global_position = Vector3(rz.global_position.x, tm.get_height_at(rz.global_position) + 1.0, rz.global_position.z)
					await get_tree().create_timer(0.7).timeout
				elif s is PlantCharge:
					var pc := s as PlantCharge
					player.global_position = pc.global_position + Vector3(1, 1, 0)
					pc.set_physics_process(false)
					for i in range(45):
						pc.advance_plant(0.1)
					await get_tree().create_timer(0.5).timeout
				elif s is KillCountObjective:
					for e in get_tree().get_nodes_in_group((s as KillCountObjective).group_tag):
						var enemy := e as EnemyBase
						while enemy and not enemy.is_dead():
							enemy.take_damage(200, Enums.DamageType.PHYSICAL, player)
					await get_tree().create_timer(0.5).timeout
		MissionGenerator.MissionType.FIREBASE_DEFENSE:
			# Kill waves as they spawn until survive completes.
			var deadline: float = 150.0
			var t: float = 0.0
			while not director.state.is_exfil_unlocked() and t < deadline:
				await get_tree().create_timer(0.5).timeout
				t += 0.5
				for e in get_tree().get_nodes_in_group("enemies"):
					var enemy := e as EnemyBase
					if enemy and not enemy.is_dead():
						enemy.take_damage(250, Enums.DamageType.PHYSICAL, player)

	if not director.state.is_exfil_unlocked():
		print("FAIL: objectives never completed (type %d)" % type)
		return false

	# Ride the bird.
	var exfil := flow.mission_hud.exfil_zone
	var wait: float = 0.0
	while flow.current_screen == null and not director.is_ended() and wait < 120.0:
		await get_tree().create_timer(0.5).timeout
		wait += 0.5
		var pos: Vector3 = exfil.global_position
		player.global_position = Vector3(pos.x, tm.get_height_at(pos) + 1.0, pos.z)
	if not director.is_ended():
		print("FAIL: extraction never completed (type %d)" % type)
		return false
	return true
