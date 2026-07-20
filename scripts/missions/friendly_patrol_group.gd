## friendly_patrol_group.gd - an ambient US element walking the AO. Inherits the
## dormant proximity contract from LazyGroup and replaces only the men.
##
## They are US-side and armed, but they are NOT the player's squad: `squad_member`
## is false, they never enter SquadSystem.members, and they take no orders. When
## one is shot to pieces it calls for help on the net - the ONE producer for
## &"friendly_patrol_pinned" (dynamic_mission_factory.gd:17).
class_name FriendlyPatrolGroup
extends LazyGroup

## Waypoints this element walks, in order, looping. Handed down by the generator.
var route: Array[Vector3] = []
## Arrival tolerance. Wider than the squad's, because nobody is dressing on him.
const WAYPOINT_REACHED_M: float = 6.0
## A man who has seen an enemy this recently counts the element as in contact.
const CONTACT_TTL_MS: float = 10000.0

## Exactly ONE element may hold the net's attention at a time. Instance id of the
## group currently reporting pinned, 0 when the net is clear. Reset by
## MissionScope.reset() - patrol 5's crisis is not patrol 1's.
static var pinned_holder: int = 0

var _men: Array[AllyBase] = []
var _peak: int = 0
var _wp: int = 0
var _break_ms: float = -1e9
var _last_contact_ms: float = -1e9
var _reported: bool = false


static func clear_static() -> void:
	pinned_holder = 0


func _spawn_men() -> void:
	var mos_pool: Array[String] = ["POINTMAN", "RIFLEMAN", "RIFLEMAN", "MG"]
	for i in range(enemy_count):
		var a: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(2.0, spread)
		var pos: Vector3 = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var man: AllyBase = AllyBase.spawn_ally(get_parent(), pos)
		man.squad_member = false
		# The nameplate (squad_nameplate.gd:112) reads this dict to identify a man
		# at 5m. Without it an ambient friendly is an unnamed silhouette in US
		# green - the blue-on-blue the r4bk affordance exists to prevent.
		man.member = SquadRoster.generate_member(_rng, mos_pool[i % mos_pool.size()])
		man.add_to_group("friendly_patrol")
		if not group_tag.is_empty():
			man.add_to_group(group_tag)
		_men.append(man)
	_peak = _men.size()
	# AllyBase defaults to FOLLOW (ally_base.gd:152), which walks to the player.
	# These men are not his: every one of them is taken off the follow chain here,
	# and a routeless element holds its ground rather than falling back to it.
	for man in _men:
		if route.is_empty():
			man.set_order(AllyBase.OrderMode.HOLD)
		else:
			man.set_order(AllyBase.OrderMode.MOVE_TO, route[0])
	# LazyGroup halts physics once the men exist; this element keeps walking and
	# keeps score, so it must tick on.
	call_deferred("set_physics_process", true)


func _physics_process(delta: float) -> void:
	if not _spawned:
		super(delta)
		return
	_advance_route()
	_update_break()


## The element walks its circuit. The whole element steps to the next leg when
## its living point of contact reaches the current one, so they stay a group.
func _advance_route() -> void:
	if route.is_empty():
		return
	var lead: AllyBase = _first_living()
	if lead == null:
		return
	if lead.global_position.distance_to(route[_wp]) > WAYPOINT_REACHED_M:
		return
	_wp = (_wp + 1) % route.size()
	for man in _men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			man.set_order(AllyBase.OrderMode.MOVE_TO, route[_wp])


func _first_living() -> AllyBase:
	for man in _men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			return man
	return null


## Strength and break, on the SAME authority and the same cadence as the player's
## squad (squad_system.gd:265) and every VC squad: EnemySquad.break_state. There
## is one break rule in this game and this element is judged by it.
func _update_break() -> void:
	var now: float = float(Time.get_ticks_msec())
	if now - _break_ms < EnemySquad.STRENGTH_TTL_MS:
		return
	_break_ms = now
	var live: int = 0
	var courage_sum: float = 0.0
	var in_contact: bool = false
	for man in _men:
		if man == null or not is_instance_valid(man) or man.is_dead():
			continue
		live += 1
		courage_sum += man.courage
		if man.target != null and is_instance_valid(man.target):
			in_contact = true
	if in_contact:
		_last_contact_ms = now
	_peak = maxi(_peak, live)
	var bs: Dictionary = EnemySquad.break_state(live, _peak,
		courage_sum / float(maxi(1, live)))
	var broken: bool = bool(bs.broken)
	for man in _men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			man.squad_broken = broken
	if not broken or live <= 0:
		if pinned_holder == get_instance_id():
			pinned_holder = 0
		return
	_report_pinned(now)


## PINNED = shot below the break threshold AND still in contact. Both halves are
## required: attrition alone is a patrol that walked into a minefield, and contact
## alone is a firefight they are winning. Neither is a call for help.
func _report_pinned(now: float) -> void:
	if _reported:
		return
	if (now - _last_contact_ms) > CONTACT_TTL_MS:
		return
	if pinned_holder != 0 and pinned_holder != get_instance_id():
		return
	pinned_holder = get_instance_id()
	_reported = true
	var dmf: Node = MissionGenerator.dynamic_factory_ref
	if dmf is DynamicMissionFactory:
		var lead: AllyBase = _first_living()
		var at: Vector3 = lead.global_position if lead != null else global_position
		(dmf as DynamicMissionFactory).emit_location(&"friendly_patrol_pinned",
			get_instance_id(), {"position": at})


func is_pinned() -> bool:
	return _reported


func living_count() -> int:
	var n: int = 0
	for man in _men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			n += 1
	return n
