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

# Schedules are read on sim_hour change. Each entry is {day, hour, kind, payload}
# with day == -1 meaning "every day". Tests can pre-fill schedules before
# calling advance().
var _schedules: Array[Dictionary] = []
var _fired_event_keys: Dictionary = {}  ## { "day-hour-entryindex" : true }


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
	var prev_hour_int: int = int(sim_hour)
	var prev_day: int = sim_day
	var prev_period: int = period_at(sim_hour)
	sim_hour += delta * real_to_sim_ratio / 3600.0
	while sim_hour >= 24.0:
		sim_hour -= 24.0
		sim_day += 1
	if int(sim_hour) != prev_hour_int:
		hour_advanced.emit(int(sim_hour))
		_tick_schedules(prev_day)
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


func _tick_schedules(_prev_day: int) -> void:
	var cur_hour_int: int = int(sim_hour)
	for i in _schedules.size():
		var s: Dictionary = _schedules[i]
		var s_day: int = int(s.day)
		var s_hour: int = int(s.hour)
		var s_kind: StringName = s.kind
		var match_day: bool = s_day == -1 or s_day == sim_day
		if not match_day:
			continue
		if s_hour != cur_hour_int:
			continue
		# Keyed per ENTRY, not per kind: three transits booked in the same hour are
		# three flights, and a kind-wide key silently dropped all but the first.
		var key: String = "%d-%d-%d" % [sim_day, s_hour, i]
		if _fired_event_keys.has(key):
			continue
		_fired_event_keys[key] = true
		sim_event.emit(s_kind, s.payload)


## Test helper: jump to a sim-time without firing per-hour schedules between.
func set_time(new_day: int, new_hour: float) -> void:
	sim_day = new_day
	sim_hour = new_hour
	hour_advanced.emit(int(sim_hour))
	_tick_schedules(sim_day)
