## decision_ring.gd - the per-man DECISION RING (council 2026-09-14, S7). A body keeps three
## parallel arrays of at most RING_N entries: WHAT (the enum name as a StringName), CAUSE (a
## StringName the caller already knows) and WHEN (sim hours, absolute). Written ONLY at the
## state choke points; nothing here allocates a String. The observatory formats at read time.
class_name DecisionRing
extends RefCounted

const RING_N: int = 10

## Enum-name tables built once from the enums themselves, so the ring can never drift from
## the code that names a state.
static var _state_names: Array[StringName] = []
static var _goal_names: Array[StringName] = []


static func push(what_arr: Array[StringName], cause_arr: Array[StringName],
		when_arr: PackedFloat64Array, what: StringName, cause: StringName) -> void:
	if what_arr.size() >= RING_N:
		what_arr.remove_at(0)
		cause_arr.remove_at(0)
		when_arr.remove_at(0)
	what_arr.append(what)
	cause_arr.append(cause)
	when_arr.append(now_hours())


## Absolute sim hours: day * 24 + hour. One float read, no allocation.
static func now_hours() -> float:
	return float(SimClock.sim_day) * 24.0 + float(SimClock.sim_hour)


static func state_name(v: int) -> StringName:
	if _state_names.is_empty():
		for k in Enums.AIState.keys():
			_state_names.append(StringName(String(k)))
	return _state_names[v] if v >= 0 and v < _state_names.size() else &"?"


static func goal_name(v: int) -> StringName:
	if _goal_names.is_empty():
		for k in Enums.AIGoal.keys():
			_goal_names.append(StringName(String(k)))
	return _goal_names[v] if v >= 0 and v < _goal_names.size() else &"?"


## READ TIME ONLY. Newest last, "DD HH:MM:SS  WHAT  <- cause".
static func format(what_arr: Array[StringName], cause_arr: Array[StringName],
		when_arr: PackedFloat64Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i in range(what_arr.size()):
		out.append("%s  %-16s <- %s" % [clock(when_arr[i]), String(what_arr[i]),
			String(cause_arr[i]) if cause_arr[i] != &"" else "-"])
	return out


static func clock(hours: float) -> String:
	var day: int = int(floor(hours / 24.0))
	var h: float = hours - float(day) * 24.0
	var hh: int = int(floor(h))
	var mm: int = int(floor((h - float(hh)) * 60.0))
	var ss: int = int(floor(((h - float(hh)) * 60.0 - float(mm)) * 60.0))
	return "d%d %02d:%02d:%02d" % [day, hh, mm, ss]
