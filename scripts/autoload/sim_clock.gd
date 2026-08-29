## sim_clock.gd - autoload that owns sim-time. The world runs on a clock
## that can be paused, fast-forwarded, or rewound without touching real
## wall time. All schedule / time-of-day decisions read sim_hour / sim_day.
##
## The autoload registration creates a global `SimClock`; the class_name is
## deliberately omitted so the file does not collide with the autoload name.
extends Node

enum Period { DAWN, DAY, DUSK, NIGHT }

signal hour_advanced(sim_hour: int)
signal time_period_changed(period: int)
signal sim_event(kind: StringName, payload: Dictionary)

var sim_hour: float = 6.0
var sim_day: int = 1
var real_to_sim_ratio: float = 60.0
var paused: bool = false

# Schedules fire when the clock CROSSES their fractional hour. Each entry is
# {day, hour, kind, payload} with day == -1 meaning "every day". Tests can
# pre-fill schedules before calling advance().
var _schedules: Array[Dictionary] = []
var _fired_event_keys: Dictionary = {}  ## { "day-entryindex" : true }


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if paused:
		return
	advance(delta)


## Advance sim-time by `delta` real seconds at the current real_to_sim_ratio.
## Emits hour_advanced on integer-hour crossings, time_period_changed on
## DAWN/DAY/DUSK/NIGHT transitions, and sim_event when a schedule entry matches.
## Day granularity is polled (sim_day), never signalled.
func advance(delta: float) -> void:
	var prev_hour: float = sim_hour
	var prev_day: int = sim_day
	var prev_period: int = period_at(sim_hour)
	sim_hour += delta * real_to_sim_ratio / 3600.0
	while sim_hour >= 24.0:
		sim_hour -= 24.0
		sim_day += 1
	if int(sim_hour) != int(prev_hour) or sim_day != prev_day:
		hour_advanced.emit(int(sim_hour))
	# Schedules fire at their FRACTIONAL hour, not on the integer crossing: truncation
	# used to fire every same-hour booking in one frame - up to ~14 airframes at the
	# demo's 38x clock (audit 2026-08-04, W-8).
	for d in range(prev_day, sim_day + 1):
		_fire_window(d, prev_hour if d == prev_day else -0.001,
			sim_hour if d == sim_day else 24.0)
	var new_period: int = period_at(sim_hour)
	if new_period != prev_period:
		time_period_changed.emit(new_period)


func period_at(hour: float) -> int:
	if hour >= 5.0 and hour < 7.0:
		return Period.DAWN
	if hour >= 7.0 and hour < 17.0:
		return Period.DAY
	if hour >= 17.0 and hour < 19.0:
		return Period.DUSK
	return Period.NIGHT


func schedule_event(day: int, hour: float, kind: StringName, payload: Dictionary) -> void:
	_schedules.append({
		"day": day,
		"hour": hour,
		"kind": kind,
		"payload": payload,
	})


func clear_schedules() -> void:
	_schedules.clear()
	_fired_event_keys.clear()


## Fire every entry whose fractional hour lies in (from_h, to_h] on `day`. Keyed per
## ENTRY per day: three transits booked in the same hour are three flights, and an entry
## fires at most once per sim day.
func _fire_window(day: int, from_h: float, to_h: float) -> void:
	for i in _schedules.size():
		var s: Dictionary = _schedules[i]
		var s_day: int = int(s.day)
		if s_day != -1 and s_day != day:
			continue
		var s_hour: float = float(s.hour)
		if s_hour <= from_h or s_hour > to_h:
			continue
		var key: String = "%d-%d" % [day, i]
		if _fired_event_keys.has(key):
			continue
		_fired_event_keys[key] = true
		sim_event.emit(s.kind as StringName, s.payload)


## Jump to a sim-time. Skipped hours never fire; entries already due inside the
## destination hour fire once, which is what parks a test clock ON its event.
func set_time(new_day: int, new_hour: float) -> void:
	sim_day = new_day
	sim_hour = new_hour
	hour_advanced.emit(int(sim_hour))
	_fire_window(sim_day, float(int(sim_hour)) - 0.001, sim_hour)


## ---------- SLEEP ----------

## A SLEEP IS A JUMP, NOT A FAST-FORWARD.
##
## advance() fires every schedule entry whose fractional hour falls in the window it
## crosses. Handing it eight hours in one call would fire a whole night's bookings in a
## single frame - the same failure class as the 38x truncation storm that launched ~14
## airframes at once (audit 2026-08-04, W-8). The bookings a man sleeps through HAPPENED;
## nobody was awake to watch them, so they are marked fired and never emitted.
##
## Emits `hour_advanced` once and `time_period_changed` if the destination sits in a
## different period - MissionWeather listens on that signal alone (mission_weather.gd:80),
## so a jump that skips it would leave the sun where he lay down.
func sleep_advance(hours: float) -> void:
	if hours <= 0.0:
		return
	var prev_period: int = period_at(sim_hour)
	var from_h: float = sim_hour
	var from_day: int = sim_day
	var total: float = sim_hour + hours
	var to_day: int = sim_day
	while total >= 24.0:
		total -= 24.0
		to_day += 1
	# Burn every booking inside the slept-through window so it cannot fire on the far side.
	for d in range(from_day, to_day + 1):
		var lo: float = from_h if d == from_day else -0.001
		var hi: float = total if d == to_day else 24.0
		_burn_window(d, lo, hi)
	sim_day = to_day
	sim_hour = total
	hour_advanced.emit(int(sim_hour))
	var new_period: int = period_at(sim_hour)
	if new_period != prev_period:
		time_period_changed.emit(new_period)


## Mark, without emitting, every entry _fire_window would have fired. Same key format
## ("day-index"), so the real window can never double-fire one of these later.
func _burn_window(day: int, from_h: float, to_h: float) -> void:
	for i in _schedules.size():
		var s: Dictionary = _schedules[i]
		var s_day: int = int(s.day)
		if s_day != -1 and s_day != day:
			continue
		var s_hour: float = float(s.hour)
		if s_hour <= from_h or s_hour > to_h:
			continue
		_fired_event_keys["%d-%d" % [day, i]] = true
