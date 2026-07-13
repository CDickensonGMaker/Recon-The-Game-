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
	sq["hunt_start"] = 0.0   # found him. The hunt is over; the fight is on.
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


## ============================== THE HUNT ==============================
## Summoner, bead 0623: "they need patrol routes, A TOUGH SEARCHING MECHANISM WHEN
## YOU ARE EVADING THEM, teamwork and firing cohesion."
##
## What search USED to be: every man in the squad walked to the same breadcrumb,
## stood on it, and the goal-scorer dropped INVESTIGATE after 5 seconds. So five men
## piled onto one point and then forgot about you. Evasion was trivial - and until
## the witness rule shipped this morning, breaking contact wasn't even possible, so
## nobody noticed.
##
## What it is now: a SECTORED, EXPANDING NET, biased along the direction you ran.
##   - Each searcher holds a STABLE SECTOR. They fan into wedges; they never clump.
##   - The ring GROWS with time. Standing still does not save you - it buries you.
##   - The cone is biased toward your HEADING (from the breadcrumb trail), because a
##     man who saw you break left does not search right.
##   - DETERMINATION decides how long and how far. NVA hunt ~85s and push the net
##     out past 60m. A VC farmer quits in 40s. Same code, different men.
##   - Fresh sign RE-ANCHORS the whole net (a body you left behind moves the hunt
##     onto it - the witness rule and the hunt are one system).

const HUNT_R0: float = 8.0            ## the net starts this wide
const HUNT_GROWTH: float = 1.4        ## m/s the ring pushes outward (x determination).
                                      ## Tuned DOWN from 3.2: the net was hitting its 70m
                                      ## cap in 16s, so searchers sprinted straight past the
                                      ## player to the outer ring. A sweep CLEARS GROUND -
                                      ## close in first, then wider. ~17m at 5s, 42m at 20s,
                                      ## 70m by 45s. Slow enough to be menacing.
const HUNT_R_MAX: float = 70.0
const HUNT_ARC_DEG: float = 80.0      ## half-angle of the search cone about the heading
const HUNT_STEP_DEG: float = 32.0     ## angular gap between adjacent searchers
const HUNT_BASE_S: float = 25.0       ## everyone hunts at least this long
const HUNT_DET_S: float = 65.0        ## ...plus this much, scaled by determination


## Contact broken. Start the net at `anchor`, pushing along `heading` (where he was
## going, not where he was standing). Idempotent: re-calling while a hunt already
## runs does NOT restart the clock - the hunt is supposed to expire.
static func begin_hunt(id: int, anchor: Vector3, heading: Vector3, now_ms: float) -> void:
	if id < 0:
		return
	var sq := _s(id)
	if sq.get("hunt_start", 0.0) > 0.0:
		return
	var h: Vector3 = Vector3(heading.x, 0.0, heading.z)
	sq["hunt_anchor"] = anchor
	sq["hunt_heading"] = h.normalized() if h.length() > 0.01 else Vector3(0, 0, 1)
	sq["hunt_start"] = now_ms
	sq["hunt_slots"] = {}


## Fresh sign (a body, a noise, a footprint). Move the net onto it and reset the
## clock - but KEEP the sector assignments, so the squad pivots as a squad.
static func reanchor_hunt(id: int, anchor: Vector3, now_ms: float) -> void:
	if id < 0 or not _squads.has(id):
		return
	var sq: Dictionary = _squads[id]
	if float(sq.get("hunt_start", 0.0)) <= 0.0:
		return
	var from: Vector3 = sq.hunt_anchor
	var h: Vector3 = Vector3(anchor.x - from.x, 0.0, anchor.z - from.z)
	if h.length() > 1.0:
		sq["hunt_heading"] = h.normalized()
	sq["hunt_anchor"] = anchor
	sq["hunt_start"] = now_ms


static func end_hunt(id: int) -> void:
	if id < 0 or not _squads.has(id):
		return
	_squads[id]["hunt_start"] = 0.0
	_squads[id]["hunt_slots"] = {}


## Is this man still looking? DETERMINATION is the whole difference between an NVA
## regular and a farmer who wants to go home.
static func hunt_active(id: int, now_ms: float, determination: float) -> bool:
	if id < 0 or not _squads.has(id):
		return false
	var start: float = float(_squads[id].get("hunt_start", 0.0))
	if start <= 0.0:
		return false
	var persistence: float = HUNT_BASE_S + HUNT_DET_S * clampf(determination, 0.0, 1.0)
	return (now_ms - start) < persistence * 1000.0


## THIS MAN's wedge of the net. Stable sector + a ring that grows with time, so the
## squad sweeps OUTWARD together instead of five men treading the same 2m.
static func hunt_point(id: int, me: Object, now_ms: float, determination: float) -> Vector3:
	if id < 0 or me == null or not _squads.has(id):
		return Vector3.ZERO
	var sq: Dictionary = _squads[id]
	if float(sq.get("hunt_start", 0.0)) <= 0.0:
		return Vector3.ZERO
	var slots: Dictionary = sq.hunt_slots
	var mid: int = me.get_instance_id()
	if not slots.has(mid):
		slots[mid] = slots.size()   # first come, first sector - and he KEEPS it
	var slot: int = int(slots[mid])

	var elapsed: float = (now_ms - float(sq.hunt_start)) / 1000.0
	var radius: float = minf(HUNT_R_MAX,
		HUNT_R0 + HUNT_GROWTH * elapsed * (0.6 + clampf(determination, 0.0, 1.0)))

	# ALTERNATING FAN, opening outward from the heading:
	#   slot 0 -> dead ahead   1 -> +step   2 -> -step   3 -> +2step   4 -> -2step
	# Deliberately does NOT depend on how many men are in the squad. The first
	# version divided by the number of men who had ASKED SO FAR, so every man after
	# the first computed slot == n-1 and they ALL walked to the right-hand flank -
	# four men in single file to the same bush. The probe caught it; the fan can't
	# have that bug, and it degrades gracefully as searchers are killed.
	var ring: int = (slot + 1) / 2
	var side: float = 1.0 if (slot % 2) == 1 else -1.0
	var off_deg: float = clampf(side * float(ring) * HUNT_STEP_DEG, -HUNT_ARC_DEG, HUNT_ARC_DEG)
	# The flanks trail slightly - a sweep line bends back at its wings, and it also
	# guarantees two clamped outer men never stand on the same square metre.
	radius *= 1.0 - 0.07 * float(ring)

	var heading: Vector3 = sq.hunt_heading
	var yaw: float = atan2(heading.x, heading.z) + deg_to_rad(off_deg)
	var anchor: Vector3 = sq.hunt_anchor
	return anchor + Vector3(sin(yaw), 0.0, cos(yaw)) * radius


## How wide the net currently is - for barks, and for the probe.
static func hunt_radius(id: int, now_ms: float, determination: float) -> float:
	if id < 0 or not _squads.has(id):
		return 0.0
	var start: float = float(_squads[id].get("hunt_start", 0.0))
	if start <= 0.0:
		return 0.0
	var elapsed: float = (now_ms - start) / 1000.0
	return minf(HUNT_R_MAX, HUNT_R0 + HUNT_GROWTH * elapsed * (0.6 + clampf(determination, 0.0, 1.0)))
