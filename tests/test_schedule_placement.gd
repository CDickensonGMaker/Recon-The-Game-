## test_schedule_placement.gd - a body must be where its schedule says it ALREADY
## is, before the player ever sees it.
##
## civilian.gd hard-returns from _physics_process at LOD_FAR (300m), and
## CivilianSchedules.action_for is only reachable below that. So a distant
## villager - or a firebase garrison man, they are Civilian instances too -
## never advanced a schedule. The STATE was correct on arrival; the POSITION was
## not. A farmer whose 0700 says "at the paddy" stood at his hut until you
## closed, then walked to the paddy in front of you: the world assembling itself
## on approach instead of having been there all along.
##
## place_for_current_hour() stands the body at the scheduled target at spawn and
## again on wake from LOD_FAR. This probe holds that line.
## Run: godot --headless --path . res://tests/test_schedule_placement.tscn
extends Node

const CivilianS := preload("res://scripts/world/civilian.gd")
const CivilianSchedulesS := preload("res://scripts/ai/civilian_schedules.gd")

const HUT := Vector3(100.0, 12.0, 100.0)
const PADDY := Vector3(160.0, 12.0, 100.0)


func _ready() -> void:
	print("=== SCHEDULE PLACEMENT (300m thinking cutoff) ===")
	var failures: int = 0
	failures += _test_schedule_actually_differs_by_hour()
	failures += _test_working_hour_stands_at_post()
	failures += _test_sleeping_hour_stands_at_home()
	failures += _test_wake_from_far_repositions()
	failures += _test_no_placement_without_a_post()

	if failures == 0:
		print("PASS: bodies are where the clock says they are")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Guard for every assertion below: if the schedule returned one action all day,
## the placement tests would pass trivially and prove nothing.
func _test_schedule_actually_differs_by_hour() -> int:
	var at_0300: StringName = CivilianSchedulesS.action_for("farmer", 3.0)
	var at_0900: StringName = CivilianSchedulesS.action_for("farmer", 9.0)
	if at_0300 == at_0900:
		printerr("FAIL: farmer does the same thing at 0300 and 0900 (%s) - probe is blind"
			% String(at_0300))
		return 1
	print("  farmer 0300=%s 0900=%s" % [String(at_0300), String(at_0900)])
	return 0


func _test_working_hour_stands_at_post() -> int:
	var civ: Civilian = _make_farmer()
	SimClock.set_time(SimClock.sim_day, 9.0)     # WORK
	civ.place_for_current_hour()
	var d: float = civ.global_position.distance_to(PADDY)
	civ.queue_free()
	if d > 5.0:
		printerr("FAIL: at 0900 the farmer is %.1fm from the paddy - he walks there in view" % d)
		return 1
	print("  0900: standing at the paddy (%.1fm)" % d)
	return 0


func _test_sleeping_hour_stands_at_home() -> int:
	var civ: Civilian = _make_farmer()
	SimClock.set_time(SimClock.sim_day, 3.0)     # SLEEP
	civ.place_for_current_hour()
	var d: float = civ.global_position.distance_to(HUT)
	civ.queue_free()
	if d > 5.0:
		printerr("FAIL: at 0300 the farmer is %.1fm from his hut - asleep in the paddy" % d)
		return 1
	print("  0300: standing at the hut (%.1fm)" % d)
	return 0


## The wake path, which is the one that fires in play: he tiers out at 300m
## while asleep, the clock runs to the working day, and he must be AT the paddy
## when he tiers back in - not still in bed.
func _test_wake_from_far_repositions() -> int:
	var civ: Civilian = _make_farmer()
	SimClock.set_time(SimClock.sim_day, 3.0)
	civ.place_for_current_hour()
	civ.lod_tier = CivilianS.LOD_FAR

	SimClock.set_time(SimClock.sim_day, 9.0)     # the hours he slept through
	# Wake: _update_lod is what tiers him back in, and placement rides it.
	civ._lod_timer = 999.0
	civ._update_lod(0.0)

	var d: float = civ.global_position.distance_to(PADDY)
	var tier: int = civ.lod_tier
	civ.queue_free()
	if tier == CivilianS.LOD_FAR:
		printerr("FAIL: probe never woke the body - the wake path went untested")
		return 1
	if d > 5.0:
		printerr("FAIL: woke %.1fm from the paddy - he walks to work in front of the player" % d)
		return 1
	print("  wake at 0900 after sleeping through: at the paddy (%.1fm)" % d)
	return 0


## Negative control on the feature itself: a body with no working point must not
## be flung to the origin. _resolve_target falls back to home + wander.
func _test_no_placement_without_a_post() -> int:
	var civ: Civilian = _make_farmer()
	civ.working_point_pos = Vector3.ZERO
	SimClock.set_time(SimClock.sim_day, 9.0)
	civ.place_for_current_hour()
	var d: float = civ.global_position.distance_to(HUT)
	var at_origin: bool = civ.global_position.length() < 1.0
	civ.queue_free()
	if at_origin:
		printerr("FAIL: a post-less civilian was teleported to world origin")
		return 1
	if d > 6.0:
		printerr("FAIL: a post-less civilian landed %.1fm from home - expected home + wander" % d)
		return 1
	print("  no working point: stays home (%.1fm, wander band)" % d)
	return 0


func _make_farmer() -> Civilian:
	var civ: Civilian = CivilianS.new()
	add_child(civ)
	civ.global_position = HUT
	civ.home = HUT
	civ.occupation = "farmer"
	civ.working_point_pos = PADDY
	return civ
