## test_offview_liveness.gd - DIAGNOSTIC. Measures whether a civilian past
## LOD_FAR_RADIUS still lives through the sim hours, or snaps to them on approach.
##
## Not a guard: it asserts a measured fact with a negative control that makes the
## assertion capable of failing.
## Run: godot --headless --path . res://tests/test_offview_liveness.tscn
extends Node

const CivilianScript := preload("res://scripts/world/civilian.gd")


func _ready() -> void:
	print("=== OFF-VIEW LIVENESS (can the world run unobserved?) ===")
	var failures: int = 0
	failures += _test_civilian_schedule_gate()

	if failures == 0:
		print("PASS: diagnostic complete")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## A civilian past LOD_FAR_RADIUS never re-picks his scheduled action, so he does
## not live through the hours - he snaps to them on approach.
## NEGATIVE CONTROL: the identical civilian inside the radius DOES re-pick.
func _test_civilian_schedule_gate() -> int:
	var far_changed: bool = _picks_new_action_across_hour(CivilianScript.LOD_FAR)
	var near_changed: bool = _picks_new_action_across_hour(CivilianScript.LOD_FULL)

	if far_changed:
		printerr("FAIL: a LOD_FAR civilian re-picked his action - he is already live off-view")
		return 1
	if not near_changed:
		printerr("FAIL(control): a LOD_FULL civilian did not re-pick either - the harness never"
			+ " reached the schedule code, so the LOD_FAR result proves nothing")
		return 1
	print("  civilian schedule: LOD_FAR re-picks=false | LOD_FULL re-picks=true"
		+ " (gate at civilian.gd:200-203, radius %.0fm)" % CivilianScript.LOD_FAR_RADIUS)
	return 0


## Drives one civilian across a sim-hour boundary at a fixed LOD tier and
## reports whether his scheduled action was recomputed.
func _picks_new_action_across_hour(tier: int) -> bool:
	var civ: Node = CivilianScript.new()
	add_child(civ)
	civ.set("occupation", "farmer")
	civ.set("lod_tier", tier)
	# Stale pick from an earlier hour; a live civilian must overwrite it.
	var bb: Dictionary = {"last_pick_hour": 3.0, "scheduled_action": &"stale"}
	civ.set("_bt_bb", bb)
	# Freeze the tier: _update_lod only recomputes every LOD_RECOMPUTE_S, and we
	# step by less than that, so the tier we set is the tier under test.
	SimClock.sim_hour = 9.0

	civ.call("_physics_process", 0.016)

	var out: Dictionary = civ.get("_bt_bb")
	var picked: StringName = out.get("scheduled_action", &"stale")
	civ.queue_free()
	return picked != &"stale"
