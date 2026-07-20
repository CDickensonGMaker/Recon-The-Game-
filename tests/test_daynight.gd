extends Node
## test_daynight.gd - proves SimClock.time_period_changed actually drives the world.
##
## The signal existed with zero consumers. The game read MissionWeather.is_night, a
## static frozen at mission start, so night never fell and tracers stayed
## daylight-bright for a 21:00 insert that ran until dawn.
##
## Run: godot --headless --path . res://tests/test_daynight.tscn

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: DAY/NIGHT CYCLE ===")

	SimClock.paused = true          # this probe owns the clock; no wall-time drift

	var mw := MissionWeather.new()
	add_child(mw)
	mw.setup(null, "CLEAR", "DAY")

	_expect(not MissionWeather.is_night, "opens in DAY: is_night false")
	_expect(is_equal_approx(MissionWeather.sight_mult, 1.0),
		"opens in DAY: sight_mult 1.0 (got %.3f)" % MissionWeather.sight_mult)
	_expect(SimClock.time_period_changed.get_connections().size() > 0,
		"MissionWeather is CONNECTED to time_period_changed")

	# 10:00 -> 21:00. At ratio 60 one real second is one sim minute.
	_advance_to(21.0)
	_expect(MissionWeather.is_night, "after dusk->night: is_night TRUE")
	_expect(is_equal_approx(MissionWeather.sight_mult, 0.4),
		"night tightens sight_mult to 0.4 (got %.3f)" % MissionWeather.sight_mult)

	# ...and back. A latch that only ever sets night is not a cycle.
	_advance_to(10.0)
	_expect(not MissionWeather.is_night, "after night->day: is_night FALSE again")
	_expect(is_equal_approx(MissionWeather.sight_mult, 1.0),
		"day restores sight_mult 1.0 (got %.3f)" % MissionWeather.sight_mult)

	# NEGATIVE CONTROL. Cut the one wire and the same time change must do nothing.
	# If night still falls with the signal disconnected, this probe is measuring
	# something other than the wiring it claims to test.
	SimClock.time_period_changed.disconnect(mw._on_time_period_changed)
	_advance_to(21.0)
	_expect(not MissionWeather.is_night,
		"NEGATIVE CONTROL: disconnected, 21:00 does NOT bring night")
	_expect(is_equal_approx(MissionWeather.sight_mult, 1.0),
		"NEGATIVE CONTROL: disconnected, sight_mult unchanged (got %.3f)" % MissionWeather.sight_mult)

	mw.queue_free()

	print("")
	if _failures == 0:
		print("=== PROBE PASS ===")
		get_tree().quit(0)
	else:
		push_error("DAY/NIGHT: %d assertion(s) failed." % _failures)
		print("=== PROBE FAIL (%d) ===" % _failures)
		get_tree().quit(1)


## Step the clock in one-real-second ticks until sim_hour reaches `target_hour`,
## so every period boundary in between is actually crossed and emitted.
func _advance_to(target_hour: float) -> void:
	var guard: int = 0
	while guard < 5000:
		guard += 1
		SimClock.advance(1.0)
		if absf(SimClock.sim_hour - target_hour) < 0.02:
			return
	push_error("test_daynight: clock never reached %.1f" % target_hour)
	_failures += 1


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
