extends Node
## Unit test for the civilian behavior tree. Exercises CivilianSchedules.action_for
## and a minimal BT tick on a real Civilian, without a GameWorld.
## Run: godot --headless --path . res://tests/test_bt_civilian.tscn

const CivScript := preload("res://scripts/world/civilian.gd")
const SchedulesScript := preload("res://scripts/ai/civilian_schedules.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== STEP 2: BT CIVILIAN ===")

	# 1. Schedule returns expected action names for the user-doc scenarios.
	# Note: schedule windows are half-open [start, end) so the test uses values
	# that fall unambiguously inside each window.
	var checks: Array = [
		["farmer", 8.0, "work"],
		["farmer", 11.5, "rest"],
		["farmer", 15.0, "work"],
		["farmer", 18.0, "cook"],
		["farmer", 23.0, "sleep"],
		["fisherman", 9.0, "fish"],
		["cook", 8.0, "cook"],
		["elder", 8.0, "walk_fire"],
		["elder", 23.0, "sleep"],
	]
	var fail: int = 0
	for c in checks:
		var action: StringName = SchedulesScript.action_for(c[0], c[1])
		if String(action) != c[2]:
			print("FAIL: action_for(%s, %s) returned %s, expected %s" % [c[0], c[1], action, c[2]])
			fail += 1
	if fail > 0:
		print("=== SCHEDULE FAILED (%d) ===" % fail)
		get_tree().quit(1)
		return
	print("Schedule: PASS (%d cases)" % checks.size())

	# 2. Pick an occupation: farmer is the most likely outcome.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var occ_count: Dictionary = {}
	for i in range(200):
		var occ: String = SchedulesScript.pick_occupation(rng)
		occ_count[occ] = int(occ_count.get(occ, 0)) + 1
	if int(occ_count.get("farmer", 0)) < 100:
		print("FAIL: farmer weight too low: %s" % occ_count)
		get_tree().quit(1)
		return
	print("Occupation: PASS (%s)" % occ_count)

	# 3. Spawn a Civilian at a fake home, give it a working_point, build the
	# BT, tick it, and assert active_action moves through the schedule.
	var civ: Civilian = CivScript.new()
	civ.home = Vector3(100, 0, 100)
	civ.working_point_pos = Vector3(120, 0, 105)
	civ.occupation = "farmer"
	# global_position only exists inside the tree; setting it first silently drops it
	# and leaves the civilian at the origin, 141m from the home it is standing on.
	add_child(civ)
	civ.global_position = Vector3(100, 0, 100)
	civ.build_bt()

	# Without SimClock, _read_sim_hour returns 12.0 -> walk_home
	civ._bt_tick(0.016)
	if civ.active_action != &"walk_home":
		print("FAIL: at sim_hour=12 (default), active_action=%s expected walk_home" % civ.active_action)
		get_tree().quit(1)
		return
	print("Default-time tick: PASS (active_action=%s)" % civ.active_action)

	civ.queue_free()
	print("=== STEP 2 PASS ===")
	get_tree().quit(0)
