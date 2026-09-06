## probe_off_duty_seating.gd - item 24: "men sitting on nothing."
##
## The type existed (civilian.gd `role`, from SitePlanner.FSB_WORK_OCCUPATION) and gated
## mess, gun crew and dig - but hooch_sleep, hooch_table, hooch_radio, hooch_locker,
## hooch_door, rest and smoke all collapsed to one off_duty pool that MIXED standing and
## seated clips. A man stood at a hooch doorway drew sitting_drinking and sat on dirt.
##
## THE INVARIANT, and it is stated here rather than copied from the production tables:
## a man may only play a SEATED or LYING clip at a marker that names a place to sit.
## The probe walks every work_* type site_planner maps to off_duty, plus the unmapped
## role, plus the empty role a curated post carries, and every seed bucket of each.
##   godot --headless --path . res://tests/probe_off_duty_seating.tscn
extends Node

## Clips that put a man's backside or back on a surface. Written out here on purpose:
## a probe that reads the same list the code reads proves only that a copy was made.
const SEATED_CLIPS: Array[String] = [
	"sitting", "sitting_idle_b", "sitting_idle_c", "sitting_talking", "sitting_drinking",
	"chow_talk_seated_a", "chow_talk_seated_b", "chow_eat_seated", "chow_sit_down",
	"sleeping_laying", "laying_idle", "sleeping", "kneeling_idle",
]
## The markers that ARE somewhere to sit or lie down: a bunk, a table, a radio bench,
## a rest spot. Everything else in the firebase is bare ground.
const SEAT_ROLES: Array[String] = ["hooch_sleep", "hooch_table", "hooch_radio", "rest"]
## Enough seeds to reach every bucket of every pool.
const SEEDS: int = 64

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	print("=== OFF-DUTY SEATING PROBE (item 24) ===")

	# Every work_* type the planner actually routes to off_duty, straight off its own
	# table - so a type added later is tested the day it is added.
	var roles: Array[String] = []
	for wt in SitePlanner.FSB_WORK_OCCUPATION:
		if str(SitePlanner.FSB_WORK_OCCUPATION[wt]) == "off_duty":
			roles.append(str(wt))
	if roles.is_empty():
		_fail("no work_* type maps to off_duty - the probe has nothing to measure")
		_finish()
		return
	roles.sort()
	# A curated post carries no role at all, and a type nobody wired reaches off_duty
	# by falling through. Both must land on their feet.
	roles.append("")
	roles.append("work_type_nobody_wired_yet")
	print("  roles under test: %s" % ", ".join(roles))

	var standing_roles: int = 0
	var seat_roles: int = 0
	for role in roles:
		var may_sit: bool = role in SEAT_ROLES
		var saw_seated: bool = false
		var chains: int = 0
		var seen: Dictionary = {}
		for seed_i in range(SEEDS):
			var chain: Array = Civilian.off_duty_chain(role, seed_i)
			if chain.is_empty():
				_fail("role '%s' seed %d returned an empty chain" % [role, seed_i])
				continue
			seen[str(chain)] = true
			for clip in chain:
				if str(clip) in SEATED_CLIPS:
					saw_seated = true
					if not may_sit:
						_fail("role '%s' plays the SEATED clip '%s' - there is nothing to sit on there"
							% [role, str(clip)])
		chains = seen.size()
		if may_sit:
			seat_roles += 1
			if not saw_seated:
				_fail("role '%s' names a seat and never sits down - the type is doing nothing"
					% role)
			else:
				print("  %-28s SEAT   %d distinct chains" % [role, chains])
		else:
			standing_roles += 1
			print("  %-28s STAND  %d distinct chains" % [role, chains])

	# The instrument check. If every role resolved to the same single chain, the type
	# is not gating anything and this probe cannot tell a fix from a coincidence.
	var pooled: Dictionary = {}
	for role2 in roles:
		pooled[str(Civilian.off_duty_chain(role2, 0))] = true
	if pooled.size() < 2:
		_fail("every role resolved to one chain - the marker type gates nothing, "
			+ "and this probe is blind")
	print("  %d standing roles, %d seat roles, %d distinct chains at seed 0"
		% [standing_roles, seat_roles, pooled.size()])
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
