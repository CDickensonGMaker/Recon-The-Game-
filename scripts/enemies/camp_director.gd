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
## Village work stations from SitePlanner prop stamping: [{pos: Vector3, type: String}].
## Empty = no village props nearby; men hold position as before.
var work_stations: Array = []
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


## Stand up a director over a garrison and put it to work immediately. Both the
## world-build pass and a LazyGroup waking mid-patrol come through here, so a
## garrison that spawns on approach gets the same schedule, stations and patrol
## route as one that existed at mission start.
static func attach(world: Node, mean_pos: Vector3, members: Array, rng_seed: int,
		stations: Array, paddy_centroids: Array[Vector3]) -> CampDirector:
	if members.size() < 2:
		return null
	var cd := CampDirector.new()
	cd.work_stations = stations
	var crng := RandomNumberGenerator.new()
	crng.seed = rng_seed
	world.add_child(cd)
	cd.setup(mean_pos, members, crng)
	var grid: Object = world.get("gameplay_grid")
	if grid != null:
		var route: Array[Vector3] = PatrolGenerator.generate(
			grid, mean_pos, 5, paddy_centroids, cd.rng)
		if route.size() >= 2:
			cd.set_patrol_anchor(route[1])
			for i in range(mini(3, members.size())):
				var m: Object = members[i]
				if m != null and is_instance_valid(m) and m is EnemyBase:
					(m as EnemyBase).patrol_route = route
					(m as EnemyBase).patrol_file_slot = i
	return cd


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
	var stations: Array = _stations_for_role(role)
	var idx: int = 0
	for s in garrison:
		if s == null or not is_instance_valid(s):
			continue
		if s in on_guard:
			continue
		s.camp_role = role
		if stations.is_empty():
			s.work_pos = Vector3.ZERO
		else:
			var pick: Dictionary = stations[idx % stations.size()]
			s.work_pos = (pick.get("pos", Vector3.ZERO) as Vector3) \
				+ Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
		idx += 1


## Which stations a role gathers at. Patrol/sleep/guard keep their posts.
func _stations_for_role(role: String) -> Array:
	if work_stations.is_empty():
		return []
	match role:
		"cook":
			var cooks: Array = work_stations.filter(
				func(s: Dictionary) -> bool: return str(s.get("type", "")) == "cook")
			return cooks if not cooks.is_empty() else work_stations
		"talk", "rest":
			return work_stations
	return []


## Called by an external patrol generator (Step 9) at mission start. The director
## rotates soldiers through this waypoint over the day.
func set_patrol_anchor(anchor: Vector3) -> void:
	patrol_anchor = anchor
	has_patrol_anchor = true


## SimClock is an AUTOLOAD with no class_name (sim_clock.gd:5) - it is absent
## from both Engine.has_singleton and ClassDB, so it can only be reached by
## node path. 12.0 is the out-of-tree fallback for unit tests.
func _read_sim_hour() -> float:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		return 12.0
	return float(clock.sim_hour)
