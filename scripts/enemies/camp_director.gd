## camp_director.gd - owns a VC camp's garrison, schedule, and patrol rotation.
## The director swaps garrison roles on SimClock.hour_advanced. The goal is a
## village that LOOKS alive: cooking in the evening, a guard post overnight,
## cooking fires + patrols during the day.
##
## Schedule (sim-hour, 0..24, half-open [start, end) like the civilian schedule):
##   05-07  : rise / cook
##   07-11  : patrol, work
##   11-13  : rest at fire
##   13-17  : patrol, work
##   17-19  : cook, gather
##   19-22  : cook, talk
##   22-05  : sleep
class_name CampDirector
extends Node

## Daily schedule: each entry is {start: float, end: float, role: String, rest_at_fire: bool}.
const SCHEDULE: Array = [
	{"start": 5.0, "end": 7.0, "role": "cook"},
	{"start": 7.0, "end": 11.0, "role": "patrol"},
	{"start": 11.0, "end": 13.0, "role": "rest", "rest_at_fire": true},
	{"start": 13.0, "end": 17.0, "role": "patrol"},
	{"start": 17.0, "end": 19.0, "role": "cook"},
	{"start": 19.0, "end": 22.0, "role": "talk"},
	{"start": 22.0, "end": 29.0, "role": "sleep"},
]

var camp_pos: Vector3 = Vector3.ZERO
var garrison: Array = []     ## Array[EnemyBase]
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Outpost: only some men are on guard at a time. The rest follow the schedule.
var on_guard: Array = []     ## Array[EnemyBase] - those exempt from schedule
const ALWAYS_GUARD: int = 1  ## one man always on guard at the post

## Patrol anchor (an additional waypoint spawned at mission start). Optional.
var patrol_anchor: Vector3 = Vector3.ZERO
var has_patrol_anchor: bool = false

## Hour at which we last swapped roles. Bumping this avoids re-issuing anims
## every frame when the schedule hasn't actually changed.
var _last_swap_hour: int = -1


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_hour_advanced")
		if not SimClock.hour_advanced.is_connected(cb):
			SimClock.hour_advanced.connect(cb)


func setup(pos: Vector3, soldiers: Array, seed_rng: RandomNumberGenerator) -> void:
	camp_pos = pos
	garrison = soldiers
	if seed_rng != null:
		rng = seed_rng
	_assign_guards(ALWAYS_GUARD)
	_apply_schedule_for_hour(_read_sim_hour())


static func role_for_hour(sim_hour: float) -> Dictionary:
	for entry in SCHEDULE:
		if sim_hour >= float(entry.start) and sim_hour < float(entry.end):
			return entry
	return SCHEDULE[SCHEDULE.size() - 1]


func _assign_guards(n: int) -> void:
	on_guard.clear()
	if garrison.is_empty():
		return
	for i in range(mini(n, garrison.size())):
		var s = garrison[i]
		if s != null and is_instance_valid(s):
			on_guard.append(s)
			s.camp_role = "guard"


func _on_hour_advanced(_sim_hour: int) -> void:
	_apply_schedule_for_hour(_read_sim_hour())


func _apply_schedule_for_hour(sim_hour: float) -> void:
	var cur_hour_int: int = int(sim_hour)
	if cur_hour_int == _last_swap_hour:
		return
	_last_swap_hour = cur_hour_int
	var entry: Dictionary = role_for_hour(sim_hour)
	var role: String = String(entry.role)
	for s in garrison:
		if s == null or not is_instance_valid(s):
			continue
		if s in on_guard:
			continue
		s.camp_role = role


## Called by an external patrol generator (Step 9) at mission start. The director
## rotates soldiers through this waypoint over the day.
func set_patrol_anchor(anchor: Vector3) -> void:
	patrol_anchor = anchor
	has_patrol_anchor = true


func _read_sim_hour() -> float:
	if Engine.has_singleton("SimClock") or ClassDB.class_exists("SimClock"):
		if SimClock != null:
			return SimClock.sim_hour
	return 12.0
