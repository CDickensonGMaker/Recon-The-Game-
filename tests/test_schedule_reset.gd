## test_schedule_reset.gd - SimClock is an autoload, so its schedule outlives the
## world that seeded it. AirTraffic seeds 22 events per patrol
## (air_traffic.gd:63,68). Nothing cleared them, so patrol N carried patrols
## 1..N-1's flights: _schedules and _fired_event_keys grew without bound, and the
## dedupe key (sim_clock.gd:95 - day+hour+kind, NOT payload) meant a later
## patrol's flight at an already-fired hour was SILENTLY SUPPRESSED. Air traffic
## thinned out the longer you played.
##
## Fixed by calling SimClock.clear_schedules() in mission_generator._wire_systems
## before AirTraffic is constructed. This probe holds that line.
## Run: godot --headless --path . res://tests/test_schedule_reset.tscn
extends Node

const AirTrafficScript := preload("res://scripts/ai/air_traffic.gd")


func _ready() -> void:
	print("=== SCHEDULE RESET (SimClock autoload leak) ===")
	var failures: int = 0
	failures += _test_seed_is_nonzero()
	failures += _test_two_patrols_do_not_accumulate()
	failures += _test_clear_resets_fired_keys()
	failures += _test_generator_clears_before_seeding()

	if failures == 0:
		print("PASS: patrol N's sky is patrol 1's sky")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Guards the other assertions: if seeding ever produced zero events, the
## no-accumulation test below would pass trivially and prove nothing.
func _test_seed_is_nonzero() -> int:
	SimClock.clear_schedules()
	var n: int = _seed_one_patrol()
	if n <= 0:
		printerr("FAIL: a patrol seeded %d events - the leak test cannot bite" % n)
		return 1
	print("  one patrol seeds %d events" % n)
	return 0


func _test_two_patrols_do_not_accumulate() -> int:
	SimClock.clear_schedules()
	var after_first: int = _seed_one_patrol()

	# What the generator now does between patrols.
	SimClock.clear_schedules()
	var after_second: int = _seed_one_patrol()

	if after_second != after_first:
		printerr("FAIL: patrol 2 left %d events, patrol 1 left %d - schedule accumulating"
			% [after_second, after_first])
		return 1
	print("  patrol 1: %d events, patrol 2: %d - no growth" % [after_first, after_second])
	return 0


## The fired-key set is the half of the leak that suppressed flights rather than
## merely growing. Clearing schedules must clear it too, or patrol 2's 09:00
## flight is silently eaten by patrol 1's already-fired 09:00 key.
func _test_clear_resets_fired_keys() -> int:
	SimClock.clear_schedules()
	# The hour gate is exact (sim_clock.gd:93), so park the clock on the event.
	SimClock.set_time(SimClock.sim_day, 9.0)
	SimClock.schedule_event(SimClock.sim_day, 9.0, &"probe_kind", {"tag": "first"})
	SimClock._tick_schedules(SimClock.sim_day)
	if SimClock._fired_event_keys.is_empty():
		printerr("FAIL: firing an event recorded no key - probe cannot detect suppression")
		return 1

	SimClock.clear_schedules()
	if not SimClock._fired_event_keys.is_empty():
		printerr("FAIL: clear_schedules left %d fired key(s) - patrol 2 loses that hour"
			% SimClock._fired_event_keys.size())
		return 1
	print("  fired-key set cleared with the schedule")
	return 0


## The wiring itself. A clear that runs AFTER AirTraffic seeds would wipe the
## flights instead of the stale ones - correct call, wrong place, empty sky.
func _test_generator_clears_before_seeding() -> int:
	var src: String = FileAccess.get_file_as_string(
		"res://scripts/missions/mission_generator.gd")
	var clear_at: int = src.find("SimClock.clear_schedules()")
	var seed_at: int = src.find("AirTrafficScript.new()")
	if clear_at < 0:
		printerr("FAIL: _wire_systems no longer clears the schedule - the leak is back")
		return 1
	if seed_at >= 0 and clear_at > seed_at:
		printerr("FAIL: schedule cleared AFTER AirTraffic is built - wipes the new sky")
		return 1
	print("  generator clears before AirTraffic seeds")
	return 0


## Mimics one patrol: a fresh AirTraffic enters the tree and seeds its day.
func _seed_one_patrol() -> int:
	var at: AirTraffic = AirTrafficScript.new()
	add_child(at)
	var n: int = SimClock._schedules.size()
	at.queue_free()
	return n
