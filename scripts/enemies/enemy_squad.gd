## enemy_squad.gd - the coordinator the enemies never had.
##
## Council keystone: the individual soldier brain is good; what was missing was a
## layer ABOVE it that makes a group act like a fireteam. This is a static
## registry (no node lifecycle) keyed by squad id. Each EnemyBase pushes what it
## sees and pulls what the squad knows, at think rate (6.7 Hz).
##
## What it buys, all from data the soldier brain already consumes:
##   - SHARED TARGET DESIGNATION -> focus fire (everyone shoots the same man)
##   - ALERT PROPAGATION -> a buddy spotting you wakes the squad (no lone blind man)
##   - BREADCRUMBS -> searchers go where you WENT, not where you were last pixel-seen
##
## Cleared by MissionScope.reset() so squad 3 of mission 5 is not squad 3 of
## mission 1.
class_name EnemySquad
extends RefCounted

const SHARE_RANGE: float = 30.0        ## a spotter wakes squadmates within this
const CRUMB_INTERVAL: float = 1.0      ## seconds between trail crumbs
const CRUMB_MAX: int = 5               ## trail length
const KNOWLEDGE_TTL: float = 12.0      ## squad "loses the scent" after this

## squad_id -> {target, last_known: Vector3, updated: float (ticks_msec),
##              crumbs: Array[Vector3], last_crumb: float}
static var _squads: Dictionary = {}


static func clear() -> void:
	_squads.clear()


static func _s(id: int) -> Dictionary:
	if not _squads.has(id):
		_squads[id] = {"target": null, "last_known": Vector3.ZERO, "updated": 0.0,
			"crumbs": [], "last_crumb": 0.0}
	return _squads[id]


## A member with eyes on reports the contact. Designates the squad target, drops
## a breadcrumb trail, and stamps the time so the knowledge decays.
static func report_contact(id: int, target: Node3D, pos: Vector3, now_ms: float) -> void:
	if id < 0 or target == null:
		return
	var sq := _s(id)
	sq.target = target
	sq.last_known = pos
	sq.updated = now_ms
	if now_ms - float(sq.last_crumb) >= CRUMB_INTERVAL * 1000.0:
		sq.last_crumb = now_ms
		var crumbs: Array = sq.crumbs
		crumbs.append(pos)
		while crumbs.size() > CRUMB_MAX:
			crumbs.pop_front()


## Does the squad hold a fresh contact a member could act on without seeing it?
static func has_fresh_intel(id: int, now_ms: float) -> bool:
	if id < 0 or not _squads.has(id):
		return false
	var sq: Dictionary = _squads[id]
	return sq.target != null and is_instance_valid(sq.target) \
		and (now_ms - float(sq.updated)) < KNOWLEDGE_TTL * 1000.0


static func shared_target(id: int) -> Node3D:
	if id < 0 or not _squads.has(id):
		return null
	var t = _squads[id].target
	return t if (t != null and is_instance_valid(t)) else null


static func shared_last_known(id: int) -> Vector3:
	if id < 0 or not _squads.has(id):
		return Vector3.ZERO
	return _squads[id].last_known


## The freshest breadcrumb a searcher has NOT yet reached, walking newest->oldest
## (chase where they went). Returns last_known if the trail is empty.
static func search_point(id: int, from_pos: Vector3, reached_radius: float) -> Vector3:
	if id < 0 or not _squads.has(id):
		return Vector3.ZERO
	var sq: Dictionary = _squads[id]
	var crumbs: Array = sq.crumbs
	for i in range(crumbs.size() - 1, -1, -1):
		var c: Vector3 = crumbs[i]
		if from_pos.distance_to(c) > reached_radius:
			return c
	return sq.last_known
