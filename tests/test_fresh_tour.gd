## test_fresh_tour.gd - THE FRESH-PLAYER LAW (Summoner, 2026-07-18): the dev's
## save is a lie about the fresh player. This probe starts from a VIRGIN
## profile and proves the first tour progresses from zero: menu carries no
## "OPERATION" language, deploy works with no save, the wire gate fires, the
## AAR banks the first patrol into rank/log from nothing.
## Run: godot --headless --path . res://tests/test_fresh_tour.tscn -- --test-save
extends Node

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _wipe_profile() -> void:
	CampaignState.reset_campaign()
	var d := DirAccess.open(SaveManager.save_dir)
	if d != null:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.begins_with("save_"):
				DirAccess.remove_absolute(SaveManager.save_dir + "/" + f)
			f = d.get_next()
	DirAccess.remove_absolute(CampaignState.TEST_SAVE_PATH)


func _run() -> void:
	_wipe_profile()

	# Menu language law: no "OPERATION" reaches a fresh player's eyes.
	var menu := MainMenuScreen.new()
	add_child(menu)
	await get_tree().process_frame
	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Label and (n as Label).text.to_upper().contains("OPERATION"):
			_fail("menu shows banned language: '%s'" % (n as Label).text)
	menu.queue_free()
	await get_tree().process_frame

	# Deploy from nothing.
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow.continue_campaign()   # virgin profile: must fall through to a fresh tour
	var waited := 0.0
	while waited < 180.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null \
				and flow.squad != null and flow.squad.members.size() > 0:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null or flow.world.player == null:
		_fail("fresh deploy never reached the world")
		_finish()
		return
	await get_tree().create_timer(1.0).timeout

	var d: FieldDirector = flow.director
	var member0: Dictionary = flow.squad.members[0].member
	if int(member0.get("missions", 0)) != 0:
		_fail("fresh roster starts with missions=%d, want 0" % int(member0.get("missions", 0)))

	# Walk out the wire (teleport past the gate), then walk back in.
	var out_pos: Vector3 = d.patrol_gate_pos + d.patrol_gate_out * 140.0
	out_pos.y = flow.world.terrain_manager.get_height_at(out_pos) + 1.0
	flow.world.player.global_position = out_pos
	waited = 0.0
	while waited < 5.0 and not d.patrol_out:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if not d.patrol_out:
		_fail("wire gate never fired on walking out")
	if d.patrol_count != 1:
		_fail("patrol_count=%d after first walk-out, want 1" % d.patrol_count)
	if d.patrol_location == Vector3.ZERO:
		_fail("no location pointed on walk-out")

	var back_pos: Vector3 = d.patrol_gate_pos - d.patrol_gate_out * 40.0
	back_pos.y = flow.world.terrain_manager.get_height_at(back_pos) + 1.0
	flow.world.player.global_position = back_pos
	waited = 0.0
	while waited < 5.0 and d.patrol_out:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if d.patrol_out:
		_fail("wire gate never re-armed on walking back in")
	elif int(member0.get("missions", 0)) != 1:
		_fail("first patrol did not bank: member missions=%d, want 1 (rank clock, Q1)" % int(member0.get("missions", 0)))
	if CampaignState.missions_played != 1:
		_fail("campaign missions_played=%d after first patrol, want 1" % CampaignState.missions_played)
	print("fresh tour: gate fired, patrol banked from zero")
	_finish()


func _finish() -> void:
	_wipe_profile()
	if _failures == 0:
		print("PASS: fresh-player law - first tour progresses from a virgin profile")
	else:
		print("FAIL: %d fresh-tour failures" % _failures)
	get_tree().quit(_failures)
