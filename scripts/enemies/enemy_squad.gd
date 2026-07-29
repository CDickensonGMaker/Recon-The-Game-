## enemy_squad.gd - static per-squad registry: shared target, alert propagation, breadcrumbs.
## Static registry (no node lifecycle), keyed by squad id. Each EnemyBase pushes
## what it sees and pulls what the squad knows, at think rate.
## Cleared by MissionScope.reset() - squad 3 of mission 5 is not squad 3 of mission 1.
class_name EnemySquad
extends RefCounted

const SHARE_RANGE: float = 30.0        ## a spotter wakes squadmates within this
const CRUMB_INTERVAL: float = 0.6      ## seconds between trail crumbs
const CRUMB_MAX: int = 20              ## ~12 seconds of the player's actual path
const KNOWLEDGE_TTL: float = 12.0      ## squad "loses the scent" after this

## Fire-and-maneuver + anti-spam brokers.
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


## ============================================================================
## ACTIVITY TIERING (ADR-026 Part B): the rolling hot-set compute budget.
## A bounded set of fighters run FULL combat AI (target acquisition, LOS raycasts,
## precise aim, cover, grenades - the expensive _think work). Everyone else in the
## fight runs cheap behavior and is promoted into the hot-set when a hot fighter
## dies or disengages. This is the single authority: one global roster across the
## AO's live combat, so per-frame AI cost stays flat regardless of body count.
##
## GUARD-RAIL (ADR-005): the WITNESS heartbeat is NOT tiered here. Cold units keep
## physics + perception; tiering only sheds the expensive targeting/aiming path.
## Raised 12 -> 50 (ceiling 16 -> 64), Summoner's ruling 2026-07-28, on the ledger's
## own attribution: at 65+ live units think is 1.20 ms of a 37.5 ms physics wall while
## the BODY is ~94% (PERF_LEDGER.md:295-304). A d50 siege must field 50 men who each
## hold their own intent, and the throttle was on the cheapest term in the loop.
## NOTE: request_hot gates on mini(HOT_CAP, HOT_CEILING) - raising one alone does nothing.
const HOT_CAP: int = 50          ## rolling target: this many fighters run full combat AI
const HOT_CEILING: int = 64      ## the roster may never exceed this (defensive clamp)
## Probe A/B switch. false => is_hot() is always true => every fighter runs full
## combat AI (the pre-tiering behavior), for measuring the frame-time delta.
static var tiering_enabled: bool = true
static var _hot: Dictionary = {} ## instance_id -> true, the current hot fighters


## Drop dead / freed references so a leaked slot cannot starve promotion. Bounded
## by HOT_CEILING, so this is cheap even when called from every cold think.
static func _prune_hot() -> void:
	for id in _hot.keys():
		var o: Object = instance_from_id(int(id))
		if o == null or not is_instance_valid(o) or (o.has_method("is_dead") and o.is_dead()):
			_hot.erase(id)


static func hot_count() -> int:
	_prune_hot()
	return _hot.size()


static func is_hot(who: Object) -> bool:
	if not tiering_enabled:
		return true            ## tiering off: everyone runs full combat AI
	if who == null:
		return false
	return _hot.has(who.get_instance_id())


## Claim a hot slot if one is free. Returns true if `who` is (now) hot. The natural
## promote-on-death: a cold fighter thinking after a hot man falls finds the freed
## slot here and takes it.
static func request_hot(who: Object) -> bool:
	if not tiering_enabled:
		return true
	if who == null:
		return false
	var id: int = who.get_instance_id()
	if _hot.has(id):
		return true
	_prune_hot()
	if _hot.size() >= mini(HOT_CAP, HOT_CEILING):
		return false
	_hot[id] = true
	return true


## Give up the slot on death or disengage - frees it for the next cold fighter.
static func release_hot(who: Object) -> void:
	if who == null:
		return
	_hot.erase(who.get_instance_id())


static func clear() -> void:
	_squads.clear()
	_hot.clear()
	_last_grenade_global_ms = -1e9


## ---- squad strength & break (4utx) ----------------------------------------
## A squad that has lost too many men breaks: the collective goal biases to
## withdrawal (layered on the individual courage rout ladder, not replacing it).
## Strength = living members / peak ever fielded (a squad only shrinks). Cached
## ~1s - never scanned per man per frame (that is the O(n2) the hot-set kills).
const BREAK_RATIO: float = 0.45          ## breaks below this fraction of peak strength
const STRENGTH_TTL_MS: float = 1000.0    ## recompute cadence

## Pure break math (both sides reuse it, allies over SquadSystem.members).
## ratio = live / peak; threshold = 0.45 shifted by courage - elite/NVA (high
## courage) hold longer (lower threshold), green/Local Force break earlier.
##
## base_ratio overrides BREAK_RATIO for a caller that owns its own strength ledger
## and needs a different band (ADR-035 §4: the siege breaks at 0.575, and reaching
## that through the courage term would make every besieger individually cowardly).
## Callers passing nothing keep the shipped behaviour exactly.
static func break_state(live: int, peak: int, avg_courage: float,
		base_ratio: float = BREAK_RATIO) -> Dictionary:
	var ratio: float = float(live) / float(maxi(1, peak))
	var threshold: float = clampf(base_ratio + (0.5 - avg_courage) * 0.4, 0.20, 0.80)
	return {"ratio": ratio, "threshold": threshold, "broken": ratio < threshold}


static func _strength(id: int) -> Dictionary:
	var s: Dictionary = _s(id)
	var now: float = float(Time.get_ticks_msec())
	if now - float(s.get("str_t", -1e9)) < STRENGTH_TTL_MS:
		return s
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var live: int = 0
	var courage_sum: float = 0.0
	if tree != null:
		for n: Node in tree.get_nodes_in_group("enemies"):
			var e := n as EnemyBase
			if e != null and e.squad_id == id and not e.is_dead():
				live += 1
				courage_sum += e.enemy_data.courage if e.enemy_data != null else 0.5
	var peak: int = maxi(int(s.get("peak", 0)), live)
	var bs: Dictionary = break_state(live, peak, courage_sum / float(maxi(1, live)))
	s["peak"] = peak
	s["live"] = live
	s["str_t"] = now
	s["ratio"] = bs.ratio
	s["threshold"] = bs.threshold
	return s


## Living members / peak strength (1.0 = full, lower = attrited). 1.0 for a lone wolf.
static func strength_ratio(id: int) -> float:
	if id < 0:
		return 1.0
	return float(_strength(id).get("ratio", 1.0))


## True once the squad is combat-ineffective (below its courage-modulated threshold).
static func is_broken(id: int) -> bool:
	if id < 0:
		return false
	var s: Dictionary = _strength(id)
	return float(s.get("ratio", 1.0)) < float(s.get("threshold", BREAK_RATIO))


static func _s(id: int) -> Dictionary:
	if not _squads.has(id):
		_squads[id] = {"target": null, "last_known": Vector3.ZERO, "updated": 0.0,
			"crumbs": [], "last_crumb": 0.0,
			"last_fire": -1e9, "last_firer": 0, "last_grenade": -1e9, "engaged": {}}
	return _squads[id]


## ---- fire-and-maneuver: covering fire -------------------------------------

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


## ---- honest attention: engagement census ----------------------------------

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


## ---- anti-spam: grenade broker --------------------------------------------

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
## `leaves_trail = false` means: they SEE him, but he is LEAVING NO SIGN.
## WATER BREAKS TRAIL: wade a creek and no crumbs are laid. The freshest crumb
## stays at the bank where you went IN; come out elsewhere and the trail stops.
static func report_contact(id: int, target: Node3D, pos: Vector3, now_ms: float,
		leaves_trail: bool = true) -> void:
	if id < 0 or target == null:
		return
	var sq := _s(id)
	sq.target = target
	sq.last_known = pos
	sq.updated = now_ms
	sq["hunt_start"] = 0.0   # found him. The hunt is over; the fight is on.
	if not leaves_trail:
		return               # eyes on, but no sign. The trail ends at the bank.
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
## A SECTORED, EXPANDING NET, biased along the direction you ran:
##   - Each searcher holds a STABLE SECTOR. They fan into wedges; they never clump.
##   - The ring GROWS with time. Standing still does not save you - it buries you.
##   - The cone is biased toward your HEADING (from the breadcrumb trail).
##   - DETERMINATION decides how long and how far (NVA ~85s, past 60m; VC ~40s).
##   - Fresh sign RE-ANCHORS the whole net (the witness rule and the hunt are one).

const HUNT_R0: float = 8.0            ## the net starts this wide
const HUNT_GROWTH: float = 1.4        ## m/s the ring pushes outward (x determination).
                                      ## A sweep CLEARS GROUND - close in first, then wider:
                                      ## ~17m at 5s, 42m at 20s, 70m by 45s.
const HUNT_R_MAX: float = 70.0        ## ...for an average man; scaled by determination below
## THE NET ADVANCES. It does not just inflate. The anchor SLIDES down the heading -
## they extrapolate your run and push the whole sweep after you.
const HUNT_ADVANCE: float = 1.1        ## m/s the anchor slides along the trail (x determination)
const HUNT_ADVANCE_MAX: float = 130.0  ## ...but they cannot chase you to the horizon
const HUNT_ARC_DEG: float = 80.0      ## half-angle of the search cone about the heading
const HUNT_STEP_DEG: float = 32.0     ## angular gap between adjacent searchers
const HUNT_BASE_S: float = 25.0       ## everyone hunts at least this long
const HUNT_DET_S: float = 65.0        ## ...plus this much, scaled by determination


## WHICH WAY WAS HE RUNNING? The crumb trail, read oldest -> newest, IS his course.
static func trail_heading(id: int) -> Vector3:
	if id < 0 or not _squads.has(id):
		return Vector3.ZERO
	var crumbs: Array = _squads[id].crumbs
	if crumbs.size() < 2:
		return Vector3.ZERO
	var newest: Vector3 = crumbs[crumbs.size() - 1]
	var older: Vector3 = crumbs[maxi(0, crumbs.size() - 4)]   # a few back: smooth out jinking
	var h: Vector3 = newest - older
	h.y = 0.0
	return h.normalized() if h.length() > 0.5 else Vector3.ZERO


## How much of the trail THIS MAN can actually read. A farmer sees churned mud. An
## NVA regular reads the whole run: how many, how fast, how long ago.
static func readable_crumbs(determination: float) -> int:
	return clampi(int(lerpf(4.0, float(CRUMB_MAX), clampf(determination, 0.0, 1.0))), 4, CRUMB_MAX)


## The centre of the net RIGHT NOW - it slides down the trail as they push after you.
static func hunt_anchor_now(id: int, now_ms: float, determination: float) -> Vector3:
	if id < 0 or not _squads.has(id):
		return Vector3.ZERO
	var sq: Dictionary = _squads[id]
	if float(sq.get("hunt_start", 0.0)) <= 0.0:
		return Vector3.ZERO
	var elapsed: float = (now_ms - float(sq.hunt_start)) / 1000.0
	var det: float = clampf(determination, 0.0, 1.0)
	var advance: float = minf(HUNT_ADVANCE_MAX, HUNT_ADVANCE * elapsed * (0.4 + det))
	return (sq.hunt_anchor as Vector3) + (sq.hunt_heading as Vector3) * advance


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

	var radius: float = hunt_radius(id, now_ms, determination)

	# ALTERNATING FAN, opening outward from the heading:
	#   slot 0 -> dead ahead   1 -> +step   2 -> -step   3 -> +2step   4 -> -2step
	# Deliberately does NOT depend on how many men are in the squad: it must degrade
	# gracefully as searchers are killed, and never collapse men onto one flank.
	@warning_ignore("integer_division")
	var ring: int = (slot + 1) / 2
	var side: float = 1.0 if (slot % 2) == 1 else -1.0
	var off_deg: float = clampf(side * float(ring) * HUNT_STEP_DEG, -HUNT_ARC_DEG, HUNT_ARC_DEG)
	# The flanks trail slightly - a sweep line bends back at its wings, and it also
	# guarantees two clamped outer men never stand on the same square metre.
	radius *= 1.0 - 0.07 * float(ring)

	var heading: Vector3 = sq.hunt_heading
	var yaw: float = atan2(heading.x, heading.z) + deg_to_rad(off_deg)
	# The net's centre has MOVED - they are chasing, not circling a memory.
	var anchor: Vector3 = hunt_anchor_now(id, now_ms, determination)
	return anchor + Vector3(sin(yaw), 0.0, cos(yaw)) * radius


## How wide the net currently is - for barks, and for the probe.
static func hunt_radius(id: int, now_ms: float, determination: float) -> float:
	if id < 0 or not _squads.has(id):
		return 0.0
	var start: float = float(_squads[id].get("hunt_start", 0.0))
	if start <= 0.0:
		return 0.0
	var elapsed: float = (now_ms - start) / 1000.0
	var det: float = clampf(determination, 0.0, 1.0)
	# A determined man casts a WIDER net as well as a longer one: 45m for a farmer,
	# ~88m for an NVA regular.
	var cap: float = HUNT_R_MAX * (0.65 + 0.6 * det)
	return minf(cap, HUNT_R0 + HUNT_GROWTH * elapsed * (0.6 + det))


## ---- formation slots: where each squad member should stand RIGHT NOW ------
## The leader publishes its position + facing; followers slot relative to both.
## Slot 0 is the point (returns leader_pos). Slot 1 cover-left, 2 cover-right,
## 3+ trail behind in pairs. The formation KEYS the squad to the leader's body
## - if the leader dies the formation collapses; promote the next man.

const FORMATION_SPACING: float = 3.2
const FORMATION_TRAIL_SPACING: float = 2.4


static func formation_positions(leader_pos: Vector3, leader_facing: Vector3, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var fwd: Vector3 = Vector3(leader_facing.x, 0.0, leader_facing.z)
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	out.append(leader_pos)
	if count >= 2:
		out.append(leader_pos - right * FORMATION_SPACING)
	if count >= 3:
		out.append(leader_pos + right * FORMATION_SPACING)
	for i in range(3, count):
		@warning_ignore("integer_division")
		var pair: int = (i - 3) / 2
		var side: float = -1.0 if (i % 2) == 1 else 1.0
		var offset: Vector3 = -fwd * (FORMATION_TRAIL_SPACING * (pair + 1)) \
			+ right * side * FORMATION_SPACING
		out.append(leader_pos + offset)
	return out
