## test_observation_tools.gd - the dev AI-observation instrument. Exercises the observer
## end-to-end (activate blinds + freezes + hides the player and re-acquires nothing; deactivate
## restores) and the overlay toggle, so a "committed but never ran" break fails loudly here.
## Run: godot --headless --path . res://tests/test_observation_tools.tscn -- --test-save
extends Node

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	_test_observer_blinds_and_restores()
	_test_overlay_toggles()
	_finish()


func _test_observer_blinds_and_restores() -> void:
	var tools := ObservationTools.new()
	add_child(tools)
	var pl := CharacterBody3D.new()
	add_child(pl)
	pl.add_to_group("player")
	var saved: CharacterBody3D = GameManager.player
	GameManager.player = pl

	tools._activate_observer()
	if not tools._observing:
		_fail("observer did not activate")
	if pl.is_in_group("player"):
		_fail("player still in 'player' group while observed — the AI is NOT blind")
	if pl.visible:
		_fail("player still visible while observed")
	if pl.is_physics_processing():
		_fail("player physics still running while observed (body not frozen)")
	if tools._ghost_cam == null or not is_instance_valid(tools._ghost_cam):
		_fail("no ghost camera spawned")

	tools._deactivate_observer()
	if tools._observing:
		_fail("observer did not deactivate")
	if not pl.is_in_group("player"):
		_fail("player NOT restored to the 'player' group after observing")
	if not pl.visible:
		_fail("player not made visible again")
	if not pl.is_physics_processing():
		_fail("player physics not restored")

	GameManager.player = saved
	tools.queue_free()
	pl.queue_free()


func _test_overlay_toggles() -> void:
	var tools := ObservationTools.new()
	add_child(tools)
	tools._toggle_overlay()
	if not tools._overlay_on:
		_fail("overlay did not turn on")
	tools._update_overlay()   # empty roster must not crash
	tools._toggle_overlay()
	if tools._overlay_on:
		_fail("overlay did not turn off")
	tools.queue_free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: observation tools - observer blinds+restores, overlay toggles")
	else:
		print("FAIL: %d observation tools failures" % _failures)
	get_tree().quit(_failures)
