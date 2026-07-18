## test_patrol_aar.gd - ADR-029 W2 / Pillar 5: death outside the wire is a field
## AAR, then you wake at the firebase with the world rebuilt. No soft-lock.
## Run: godot --headless --path . res://tests/test_patrol_aar.tscn -- --test-save
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
	flow._begin_operation(31337, "OPERATION TEST CASE")
	var waited := 0.0
	while waited < 150.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null or flow.world.player == null:
		_fail("patrol world never came up")
		_finish()
		return
	await get_tree().create_timer(1.0).timeout

	# Die in the field.
	var hs: HealthSystem = flow.world.player.get_node_or_null("HealthSystem") as HealthSystem
	if hs == null:
		_fail("no HealthSystem on player")
		_finish()
		return
	hs.force_death()
	waited = 0.0
	while waited < 15.0:
		if flow.current_screen is DebriefScreen:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if not (flow.current_screen is DebriefScreen):
		_fail("death did not reach the field AAR screen (soft-lock)")
		_finish()
		return
	print("AAR reached after death")

	# Walk out of the AAR - wake at the firebase, world rebuilt.
	(flow.current_screen as DebriefScreen).continue_pressed.emit()
	waited = 0.0
	while waited < 150.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null or flow.world.player == null:
		_fail("did not wake at the firebase after the AAR")
	elif SaveManager.context != "hub":
		_fail("woke in context '%s', wanted 'hub'" % SaveManager.context)
	else:
		print("woke at the firebase, world rebuilt")
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(SaveManager.save_dir + "/save_%d.sav" % SaveManager.AUTOSAVE_SLOT)
	CampaignState.reset_campaign()
	if _failures == 0:
		print("PASS: death -> field AAR -> firebase wake (fail forward)")
	else:
		print("FAIL: %d AAR failures" % _failures)
	get_tree().quit(_failures)
