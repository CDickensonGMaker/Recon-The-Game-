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

	# 4. THE CLOCK MUST BE REACHABLE. SimClock is an autoload with no class_name,
	# so Engine.has_singleton and ClassDB both miss it; reading it through either
	# pins every civilian at the 12.0 fallback for the life of the process.
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		print("FAIL: /root/SimClock not reachable by node path - schedules cannot advance")
		get_tree().quit(1)
		return
	clock.paused = true
	print("Clock reachable: PASS (sim_hour=%.1f)" % float(clock.sim_hour))

	# 5. DISPATCH. Every one of the 12 authored actions must be reachable THROUGH
	# THE ROOT. Driving _bt_bb directly keeps this independent of the schedule
	# tables, so a schedule edit cannot silently drop a leaf out of the tree.
	var all_actions: Array[StringName] = [
		&"idle", &"walk_home", &"walk_paddy", &"walk_fire", &"walk_market",
		&"work", &"rest", &"cook", &"sleep", &"fish", &"sit", &"talk",
	]
	for a in all_actions:
		civ.active_action = &"__unset__"
		civ._bt_bb["scheduled_action"] = a
		civ._bt_bb["target_pos"] = civ.working_point_pos
		civ._bt.tick(civ, civ._bt_bb)
		if civ.active_action != a:
			print("FAIL: dispatch(%s) left active_action=%s - leaf not reachable from the BT root" % [a, civ.active_action])
			get_tree().quit(1)
			return
	print("Dispatch: PASS (all %d actions routed through the root)" % all_actions.size())

	# 6. NEGATIVE CONTROL. An action the table does not carry must FAIL the
	# dispatch node and fall through to the idle leaf - not silently succeed.
	civ.active_action = &"__unset__"
	civ._bt_bb["scheduled_action"] = &"not_a_real_action"
	civ._bt.tick(civ, civ._bt_bb)
	if civ.active_action != &"idle":
		print("FAIL: negative control - unknown action left active_action=%s, expected idle" % civ.active_action)
		get_tree().quit(1)
		return
	print("Negative control: PASS (unknown action fell through to idle)")

	# 7. The schedule must actually drive the tree across the day. Each hour is
	# ticked twice: the pick only refreshes on an integer-hour change.
	var seen: Dictionary = {}
	for h in range(0, 24):
		clock.sim_hour = float(h) + 0.5
		civ._bt_tick(0.016)
		seen[String(civ.active_action)] = true
		var expected: StringName = SchedulesScript.action_for("farmer", float(h) + 0.5)
		if civ.active_action != expected:
			print("FAIL: hour %d -> active_action=%s, schedule says %s" % [h, civ.active_action, expected])
			get_tree().quit(1)
			return
	if seen.size() < 4:
		print("FAIL: farmer ran only %d distinct actions across 24h: %s" % [seen.size(), seen.keys()])
		get_tree().quit(1)
		return
	print("Day sweep: PASS (%d distinct actions: %s)" % [seen.size(), seen.keys()])

	civ.queue_free()
	print("=== STEP 2 PASS ===")
	get_tree().quit(0)
