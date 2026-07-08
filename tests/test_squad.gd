## test_squad.gd - W13-W24: roster spawn, orders, hold-fire, medic revive,
## casualty persistence. Run: godot --headless --path . res://tests/test_squad.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	CampaignState.reset_campaign()
	var failures: int = 0

	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 616
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
	director.toast.connect(func(t: String) -> void: print("[TOAST] %s" % t))

	var squad := SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, director, world.player.global_position + Vector3(4, 0, 0))
	await get_tree().create_timer(0.6).timeout

	# 1. Five rostered members with distinct MOS.
	if squad.members.size() != 5:
		print("FAIL: squad size %d" % squad.members.size())
		failures += 1
	var mos_seen := {}
	for a in squad.members:
		mos_seen[str(a.member.mos)] = true
		if str(a.member.name).is_empty():
			print("FAIL: unnamed member")
			failures += 1
	print("roster MOS: %s" % [mos_seen.keys()])
	if not mos_seen.has("MEDIC") or not mos_seen.has("RTO") or not mos_seen.has("POINT"):
		print("FAIL: missing core MOS")
		failures += 1
	if CampaignState.roster.size() != 5:
		print("FAIL: roster not persisted")
		failures += 1

	# 2. Orders: HOLD then MOVE_TO.
	for a in squad.members:
		a.set_order(AllyBase.OrderMode.HOLD)
	var hold_pos: Vector3 = squad.members[0].global_position
	await get_tree().create_timer(2.0).timeout
	if squad.members[0].global_position.distance_to(hold_pos) > 4.0:
		print("FAIL: HOLD order ignored")
		failures += 1
	var move_target: Vector3 = world.player.global_position + Vector3(25, 0, 0)
	move_target.y = world.terrain_manager.get_height_at(move_target)
	for a in squad.members:
		a.set_order(AllyBase.OrderMode.MOVE_TO, move_target)
	await get_tree().create_timer(10.0).timeout
	var arrived: int = 0
	for a in squad.members:
		if a.global_position.distance_to(move_target) < 12.0:
			arrived += 1
	print("MOVE_TO arrivals: %d/5" % arrived)
	if arrived < 3:
		print("FAIL: MOVE_TO order mostly ignored")
		failures += 1

	# 3. Hold fire gates weapons.
	squad.weapons_free = false
	for a in squad.members:
		a.weapons_free = false
	var dummy := director.spawn_tracked_enemy(world.player.global_position + Vector3(10, 0, 0), "res://data/enemies/german_rifleman.tres")
	await get_tree().create_timer(2.5).timeout
	if dummy.is_dead():
		print("FAIL: hold-fire squad killed the target")
		failures += 1
	for a in squad.members:
		a.weapons_free = true
	squad.weapons_free = true

	# 4. Medic revive: force the player down.
	var hs: HealthSystem = world.player.get_node("HealthSystem")
	var revived := [false]
	hs.downed_ended.connect(func(ok: bool) -> void: revived[0] = ok)
	# Bring medic close so the channel starts fast.
	var medic := squad.member_by_mos("MEDIC")
	medic.global_position = world.player.global_position + Vector3(2, 0.5, 0)
	hs.take_damage(999, Enums.DamageType.PHYSICAL, null)
	if not hs.is_downed:
		print("FAIL: player not downed (went straight to death)")
		failures += 1
	var t: float = 0.0
	while not revived[0] and t < 20.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	print("revive took %.1fs, hp=%d" % [t, hs.current_hp])
	if not revived[0] or hs.current_hp < 30:
		print("FAIL: medic revive failed")
		failures += 1
	if squad.revives_left != 1:
		print("FAIL: revive count wrong (%d)" % squad.revives_left)
		failures += 1

	# 5. Casualty persists to roster.
	var victim: AllyBase = squad.member_by_mos("GRENADIER")
	var victim_name: String = str(victim.member.name)
	while not victim.is_dead():
		victim.take_damage(200, Enums.DamageType.PHYSICAL, null)
	await get_tree().create_timer(0.5).timeout
	var still_alive_in_roster := false
	for m in CampaignState.roster:
		if str(m.name) == victim_name and bool(m.alive):
			still_alive_in_roster = true
	if still_alive_in_roster:
		print("FAIL: KIA not persisted")
		failures += 1
	# Next roster fill replaces him.
	var refilled: Array = SquadRoster.ensure_roster(999)
	if refilled.size() != 5:
		print("FAIL: roster not refilled (%d)" % refilled.size())
		failures += 1

	CampaignState.reset_campaign()
	if failures == 0:
		print("PASS: squad system (roster/orders/holdfire/medic/casualties) OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d squad failures" % failures)
		get_tree().quit(1)
