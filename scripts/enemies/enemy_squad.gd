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

## HLL doctrine pass (2026-07-10): fire-and-maneuver + anti-spam brokers.
const COVERING_FIRE_WINDOW_MS: float = 1500.0   ## a squadmate shot this recently = you're covered
const SQUAD_GRENADE_COOLDOWN_MS: float = 12000.0
const GLOBAL_GRENADE_SPACING_MS: float = 5000.0 ## max one grenade in the AO per this window
const ENGAGE_TTL_MS: float = 3000.0             ## engagement reports go stale after this

## squad_id -> {target, last_known: Vector3, updated: float (ticks_msec),
##              crumbs: Array[Vector3], last_crumb: float,
##              last_fire: float, last_firer: int, last_grenade: float,
##              engaged: Dictionary (member id -> {tid: int, ms: float})}
static var _squads: Dictionary = {}
static var _last_grenade_global_ms: float = -1e9


static func clear() -> void:
	_squads.clear()
	_last_grenade_global_ms = -1e9


static func _s(id: int) -> Dictionary:
	if not _squads.has(id):
		_squads[id] = {"target": null, "last_known": Vector3.ZERO, "updated": 0.0,
			"crumbs": [], "last_crumb": 0.0,
			"last_fire": -1e9, "last_firer": 0, "last_grenade": -1e9, "engaged": {}}
	return _squads[id]


## ---- fire-and-maneuver: covering fire (doctrine C) -------------------------

## A member fired a shot. One dict write per trigger pull.
static func report_firing(id: int, who: Object, now_ms: float) -> void:
	if id < 0 or who == null:
		return
	var sq := _s(id)
	sq.last_fire = now_ms
	sq.last_firer = who.get_instance_id()


## Is a DIFFERENT squadmate currently putting rounds down? Advancing without
## this (or high aggression) is how men die in the open.
static func has_covering_fire(id: int, me: Object, now_ms: float) -> bool:
	if id < 0 or not _squads.has(id) or me == null:
		return false
	var sq: Dictionary = _squads[id]
	return (now_ms - float(sq.last_fire)) < COVERING_FIRE_WINDOW_MS \
		and int(sq.last_firer) != me.get_instance_id()


## ---- honest attention: engagement census (doctrine D) ----------------------

## Each member reports who it is shooting at, at think rate.
static func report_engagement(id: int, me: Object, tgt: Object, now_ms: float) -> void:
	if id < 0 or me == null or tgt == null:
		return
	var engaged: Dictionary = _s(id).engaged
	engaged[me.get_instance_id()] = {"tid": tgt.get_instance_id(), "ms": now_ms}


## How many OTHER members are on this target right now? Crowded targets score
## lower, so squads spread across the player AND his allies.
static func count_engaging(id: int, tgt: Object, me: Object, now_ms: float) -> int:
	if id < 0 or not _squads.has(id) or tgt == null:
		return 0
	var tid: int = tgt.get_instance_id()
	var my_id: int = me.get_instance_id() if me != null else 0
	var n: int = 0
	var engaged: Dictionary = _squads[id].engaged
	for mid in engaged.keys():
		if int(mid) == my_id:
			continue
		var e: Dictionary = engaged[mid]
		if int(e.tid) == tid and (now_ms - float(e.ms)) < ENGAGE_TTL_MS:
			n += 1
	return n


## ---- anti-spam: grenade broker (doctrine E, the _cover_claims pattern) -----

static func grenade_ready(id: int, now_ms: float) -> bool:
	if (now_ms - _last_grenade_global_ms) < GLOBAL_GRENADE_SPACING_MS:
		return false
	if id >= 0 and _squads.has(id):
		if (now_ms - float(_squads[id].last_grenade)) < SQUAD_GRENADE_COOLDOWN_MS:
			return false
	return true


static func claim_grenade(id: int, now_ms: float) -> void:
	_last_grenade_global_ms = now_ms
	if id >= 0:
		_s(id).last_grenade = now_ms


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
