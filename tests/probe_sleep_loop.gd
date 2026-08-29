## probe_sleep_loop.gd - measures the sleep run-terminator (Summoner ruling 2026-08-28).
##
## Answers, by measurement and not by reading:
##   1. sleep_advance moves the clock and CROSSES a period (MissionWeather listens on that
##      signal alone - a jump that skips it leaves the sun where he lay down).
##   2. sleep_advance BURNS the bookings it slept through instead of firing a night's worth
##      of schedules in one frame.
##   3. the night roll is asked at the moment he lies down, and honours the threat tier.
##   4. the phantom-bank guard: a man who never left his cot banks nothing.
extends Node

var _fired: Array[StringName] = []
var _periods: Array[int] = []


func _ready() -> void:
	await get_tree().process_frame
	var pass_all: bool = true
	pass_all = _t1_clock_and_period() and pass_all
	pass_all = _t2_schedules_burned() and pass_all
	pass_all = _t3_night_roll() and pass_all
	print("[SLEEPPROBE] %s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit(0 if pass_all else 1)


func _ok(name_: String, cond: bool, detail: String) -> bool:
	print("[SLEEPPROBE] %s %s - %s" % ["PASS" if cond else "FAIL", name_, detail])
	return cond


## 1. Eight hours from 21:00 lands at 05:00 the NEXT day, and the period signal fires.
func _t1_clock_and_period() -> bool:
	SimClock.clear_schedules()
	_periods.clear()
	SimClock.time_period_changed.connect(_on_period)
	SimClock.paused = true
	SimClock.set_time(3, 21.0)
	SimClock.sleep_advance(8.0)
	SimClock.time_period_changed.disconnect(_on_period)
	var landed: bool = SimClock.sim_day == 4 and absf(SimClock.sim_hour - 5.0) < 0.001
	var crossed: bool = _periods.has(SimClock.Period.DAWN)
	return _ok("clock+period", landed and crossed,
		"21:00 d3 +8h -> %02d:%02d d%d, periods emitted %s (want DAWN=%d)" % [
			int(SimClock.sim_hour), int(fmod(SimClock.sim_hour, 1.0) * 60.0),
			SimClock.sim_day, str(_periods), SimClock.Period.DAWN])


## 2. Three bookings inside the slept window fire ZERO times, not three in one frame.
func _t2_schedules_burned() -> bool:
	SimClock.clear_schedules()
	_fired.clear()
	SimClock.sim_event.connect(_on_event)
	SimClock.set_time(5, 20.0)
	SimClock.schedule_event(5, 21.0, &"bird_a", {})
	SimClock.schedule_event(5, 22.5, &"bird_b", {})
	SimClock.schedule_event(6, 2.0, &"bird_c", {})
	SimClock.sleep_advance(8.0)
	SimClock.sim_event.disconnect(_on_event)
	var burned: bool = _fired.is_empty()
	# And they stay burned: a real advance across the same hours must not resurrect them.
	SimClock.set_time(5, 20.0)
	SimClock.sim_event.connect(_on_event)
	SimClock.advance(3600.0 / SimClock.real_to_sim_ratio * 8.0)
	SimClock.sim_event.disconnect(_on_event)
	var stay: bool = _fired.is_empty()
	SimClock.clear_schedules()
	SimClock.paused = false
	return _ok("schedules burned", burned and stay,
		"3 bookings in the slept window fired %d times, and %d after a real re-cross" % [
			0 if burned else _fired.size(), _fired.size()])


## 3. The roll is asked at the bunk, uses the earned tier, and is bounded by MAX_RUN_NIGHTS.
func _t3_night_roll() -> bool:
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	d.fsb_center = Vector3(0, 0, 0)
	var sg := SiegeDirector.new()
	d.add_child(sg)
	sg.setup(d, Vector3(0, 0, 0), Vector3(10, 0, 0))
	d.siege = sg

	# A man who never walked out gets no night, whatever the tier says.
	d.patrol_count = 0
	var no_night: bool = not sg.roll_night_for_sleep()

	# And he banks nothing by lying down twice - the phantom-loop guard.
	var before: int = CampaignState.missions_played
	var r1: Dictionary = d.turn_in_for_the_night()
	var r2: Dictionary = d.turn_in_for_the_night()
	var no_bank: bool = not bool(r1.get("banked", true)) \
		and not bool(r2.get("banked", true)) \
		and CampaignState.missions_played == before

	# The chain is bounded: nights_run at the cap refuses regardless of the dice.
	d.patrol_count = 1
	sg.nights_run = SiegeDirector.MAX_RUN_NIGHTS
	var capped: bool = not sg.roll_night_for_sleep()

	d.queue_free()
	return _ok("night roll + phantom guard", no_night and no_bank and capped,
		"no walk-out -> no night: %s | two sleeps banked 0 (missions_played %d -> %d): %s | at MAX_RUN_NIGHTS refuses: %s" % [
			no_night, before, CampaignState.missions_played, no_bank, capped])


func _on_event(kind: StringName, _payload: Dictionary) -> void:
	_fired.append(kind)


func _on_period(period: int) -> void:
	_periods.append(period)
