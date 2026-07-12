## test_hub_loop.gd - Phase B end-to-end: operation -> firebase hub (TOC + bird +
## autosave) -> accept a mission -> launch -> mission world builds. Drives GameFlow
## exactly as the menu would. Run: godot --headless --path . res://tests/test_hub_loop.tscn -- --test-save
extends Node

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	CampaignState.reset_campaign()
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame

	# --- enter the hub for a fixed operation ---
	flow._begin_operation(31337, "OPERATION TEST CASE")
	var waited := 0.0
	while waited < 120.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null or flow.world.player == null:
		_fail("hub world/player never came up")
		_finish()
		return
	await get_tree().create_timer(1.0).timeout  # let hub controller/autosave settle

	if SaveManager.context != "hub":
		_fail("context is '%s', wanted 'hub'" % SaveManager.context)
	if get_tree().get_nodes_in_group("hq_tent").size() == 0:
		_fail("no HQ tent in the hub")
	if int(SaveManager.hub_snapshot.get("operation_seed", 0)) != 31337:
		_fail("hub snapshot lost the operation seed")
	if not SaveManager.has_save(SaveManager.AUTOSAVE_SLOT):
		_fail("hub entry did not autosave")
	var huey_found := false
	for h in get_tree().get_nodes_in_group("helicopters"):
		huey_found = true
	# helicopters group may not exist; fall back to class scan
	if not huey_found:
		var stack: Array[Node] = [flow.world]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Helicopter:
				huey_found = true
				break
			for c in n.get_children():
				stack.append(c)
	if not huey_found:
		_fail("no Huey parked at the hub")
	print("hub OK: tent + bird + autosave + context")

	# --- accept an offer and launch (the TOC board path) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var offers := MissionOffers.roll(rng)
	SaveManager.hub_snapshot["accepted_offer"] = offers[0]
	flow.launch_accepted()
	waited = 0.0
	while waited < 150.0:
		if SaveManager.context == "mission" and flow.world != null \
				and flow.world.is_world_ready and flow.world.player != null \
				and flow.director != null and flow.director.state.required_mask > 0:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if SaveManager.context != "mission":
		_fail("launch_accepted never reached mission context")
	elif flow.director == null or flow.director.state.required_mask == 0:
		_fail("mission world has no objectives")
	else:
		print("mission OK: %s launched from the hub with objectives" % str(offers[0].get("type_name")))
	# THE BIRD FLIES (ADR-008 condition 2). This assertion used to be the exact
	# INVERSE - it demanded the ride NOT spawn - which is how a fully built
	# insertion (boarding, flight, AA fire, shoot-down, crash E&E) sat dead in
	# the repo while every reachable launch skipped it. The hub launch IS the
	# ride: you board at the firebase and you fly in.
	var ride_found := false
	if flow.world != null:
		var stack2: Array[Node] = [flow.world]
		while not stack2.is_empty():
			var n2: Node = stack2.pop_back()
			if n2 is InsertionRide:
				ride_found = true
				break
			for c2 in n2.get_children():
				stack2.append(c2)
	if not ride_found:
		_fail("hub launch did not spawn an InsertionRide - the bird must fly (ADR-008)")
	else:
		print("insertion OK: the Huey ride is live on the campaign path")

	_finish()


func _finish() -> void:
	# cleanup the autosave the test wrote
	DirAccess.remove_absolute("user://saves/save_%d.sav" % SaveManager.AUTOSAVE_SLOT)
	DirAccess.remove_absolute("user://saves/save_5.sav")
	CampaignState.reset_campaign()
	if _failures == 0:
		print("PASS: hub loop end-to-end (operation -> hub -> TOC accept -> mission)")
	else:
		print("FAIL: %d hub loop failures" % _failures)
	get_tree().quit(_failures)
