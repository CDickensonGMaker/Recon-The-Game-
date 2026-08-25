## squad_coordinator.gd - per-side, per-squad fight coordination (War Room
## 2026-08-24 Phases 2-3): ONE suppressor slot, N exposure tokens gating who may
## be out of cover at once, a per-squad covering-fire census (both sides - the
## ally global static and EnemySquad's pair are DELETED, this is the one census),
## and two-element bounding overwatch expressed through the token grants.
##
## Static registry in EnemySquad's idiom, not an autoload: members upsert
## themselves at think rate (O(1) dict writes) and the "squad tick" is TTL-lazy
## recompute at query time, so headless scenes and MissionScope.reset() need no
## node lifecycle. All time flows in as now_ms so probes can drive the clock.
## Orders are REFUSABLE by construction: the coordinator only shapes goal picks;
## survival verbs (SEEK_COVER / RETREAT) are never routed through it.
class_name SquadCoordinator
extends RefCounted

const Doctrine := preload("res://scripts/ai/doctrine_data.gd")

const SIDE_ENEMY: int = 0
const SIDE_ALLY: int = 1

## A member unseen this long has left the fight (dead, despawned, disengaged).
const MEMBER_TTL_MS: float = 2000.0
## Suppressor slot re-election cadence - the 1-2 Hz "squad tick" of the decree.
const SUPPRESSOR_REFRESH_MS: float = 1200.0

const DOCTRINE_DIR: String = "res://data/ai/"

static var _squads: Dictionary = {}
static var _doctrines: Dictionary = {}


static func clear() -> void:
	_squads.clear()


## Doctrine by id ("us"/"nva"/"vc"/"assault_press"), cached. A missing file
## yields shared-core defaults rather than a crash - data may lag code.
static func doctrine(id: String) -> Doctrine:
	if _doctrines.has(id):
		return _doctrines[id]
	var d: Doctrine = null
	var path: String = DOCTRINE_DIR + "doctrine_%s.tres" % id
	if ResourceLoader.exists(path):
		d = load(path) as Doctrine
	if d == null:
		d = Doctrine.new()
		d.id = id
	_doctrines[id] = d
	return d


static func _rec(side: int, squad: int) -> Dictionary:
	var key := Vector2i(side, squad)
	if not _squads.has(key):
		_squads[key] = {"doctrine": null, "members": {}, "order": [],
			"tokens": {}, "grant_ms": -1e9,
			"supp_id": 0, "supp_ms": -1e9,
			"fire_ms": -1e9, "firer": 0,
			"fight_ms": -1e9, "fight_pos": Vector3.ZERO,
			"elem": {}, "active_elem": 0, "flip_ms": -1e9}
	return _squads[key]


## Member upsert, called at think rate. Element membership is registration-order
## parity: stable for a man's whole life, and it degrades gracefully as the
## squad is attrited (same reasoning as the hunt's alternating fan).
static func register(side: int, squad: int, who: Object, mg: bool, covered: bool,
		doctrine_id: String, now_ms: float) -> void:
	if squad < 0 or who == null:
		return
	var rec: Dictionary = _rec(side, squad)
	if rec.doctrine == null:
		rec.doctrine = doctrine(doctrine_id)
	var id: int = who.get_instance_id()
	var members: Dictionary = rec.members
	if not members.has(id):
		var order: Array = rec.order
		order.append(id)
		(rec.elem as Dictionary)[id] = (order.size() - 1) % 2
	members[id] = {"mg": mg, "covered": covered, "seen": now_ms}


## A live contact: stamps fight liveness and the position worth suppressing.
static func report_fight(side: int, squad: int, pos: Vector3, now_ms: float) -> void:
	if squad < 0:
		return
	var rec: Dictionary = _rec(side, squad)
	rec.fight_ms = now_ms
	if pos != Vector3.ZERO:
		rec.fight_pos = pos


## ---- covering-fire census (per squad, both sides - one write per trigger pull) ----

static func report_firing(side: int, squad: int, who: Object, now_ms: float) -> void:
	if squad < 0 or who == null:
		return
	var rec: Dictionary = _rec(side, squad)
	rec.fire_ms = now_ms
	rec.firer = who.get_instance_id()


const COVER_FIRE_WINDOW_MS: float = 1500.0

static func has_covering_fire(side: int, squad: int, who: Object, now_ms: float) -> bool:
	if squad < 0 or who == null:
		return false
	var key := Vector2i(side, squad)
	if not _squads.has(key):
		return false
	var rec: Dictionary = _squads[key]
	return (now_ms - float(rec.fire_ms)) < COVER_FIRE_WINDOW_MS \
		and int(rec.firer) != who.get_instance_id()


## ---- exposure tokens (Phase 2) + element gating (Phase 3) ----

static func _fight_fresh(rec: Dictionary, d: Doctrine, now_ms: float) -> bool:
	return (now_ms - float(rec.fight_ms)) < float(d.fight_fresh_ms)


static func _prune_tokens(rec: Dictionary, now_ms: float) -> void:
	var tokens: Dictionary = rec.tokens
	for id in tokens.keys():
		if now_ms >= float(tokens[id]):
			tokens.erase(id)


static func _update_elements(rec: Dictionary, d: Doctrine, now_ms: float) -> void:
	# First sight arms the clock without flipping - element 0 leads the first bound.
	if float(rec.flip_ms) < 0.0:
		rec.flip_ms = now_ms
		return
	if now_ms - float(rec.flip_ms) >= float(d.bound_period_ms):
		rec.flip_ms = now_ms
		rec.active_elem = 1 - int(rec.active_elem)


## The right to be OUT of cover (ADVANCE / FLANK). A held token renews; a fresh
## grant needs a free slot, the ACTIVE element while a live fight is bounding,
## and the stagger gap - so element moves start across thinks, not as one wave.
## press = the siege press: it draws on the assault_press doctrine's near-infinite
## pool, so the 7/30 ruling survives by data (R2), not exception code.
static func request_exposure(side: int, squad: int, who: Object, press: bool,
		now_ms: float) -> bool:
	if squad < 0 or who == null:
		return true
	var rec: Dictionary = _rec(side, squad)
	var d: Doctrine = doctrine("assault_press") if press \
		else (rec.doctrine as Doctrine)
	if d == null:
		return true
	var id: int = who.get_instance_id()
	var tokens: Dictionary = rec.tokens
	_prune_tokens(rec, now_ms)
	if tokens.has(id):
		tokens[id] = now_ms + float(d.token_ttl_ms)
		return true
	if tokens.size() >= d.exposure_tokens:
		return false
	if not press and d.bound_period_ms > 0 and _fight_fresh(rec, d, now_ms):
		_update_elements(rec, d, now_ms)
		if int((rec.elem as Dictionary).get(id, 0)) != int(rec.active_elem):
			return false
	if now_ms - float(rec.grant_ms) < float(d.grant_stagger_ms):
		return false
	rec.grant_ms = now_ms
	tokens[id] = now_ms + float(d.token_ttl_ms)
	return true


static func release_exposure(side: int, squad: int, who: Object) -> void:
	if squad < 0 or who == null:
		return
	var key := Vector2i(side, squad)
	if _squads.has(key):
		(_squads[key].tokens as Dictionary).erase(who.get_instance_id())


## ---- the suppressor slot (Phase 2 - SUPPRESS_TARGET's executor assignment) ----

## The position the slot is worth firing at, or ZERO when the intel went stale.
static func suppress_point(side: int, squad: int, now_ms: float) -> Vector3:
	if squad < 0:
		return Vector3.ZERO
	var key := Vector2i(side, squad)
	if not _squads.has(key):
		return Vector3.ZERO
	var rec: Dictionary = _squads[key]
	var d := rec.doctrine as Doctrine
	if d == null or (now_ms - float(rec.fight_ms)) >= float(d.suppress_point_ttl_ms):
		return Vector3.ZERO
	return rec.fight_pos


## ONE slot per squad, re-elected on the squad-tick cadence. Prefers a covered
## machine gunner (the base of fire IS the MG's job - CoH), never a token holder
## (a mover is not the base of fire), and while bounding prefers the PASSIVE
## element. The slot expires with the fight; TTL guards a dead holder.
static func is_suppressor(side: int, squad: int, who: Object, now_ms: float) -> bool:
	if squad < 0 or who == null:
		return false
	var key := Vector2i(side, squad)
	if not _squads.has(key):
		return false
	var rec: Dictionary = _squads[key]
	var d := rec.doctrine as Doctrine
	if d == null or d.suppressor_slots <= 0 or not _fight_fresh(rec, d, now_ms):
		return false
	if now_ms - float(rec.supp_ms) >= SUPPRESSOR_REFRESH_MS:
		rec.supp_ms = now_ms
		rec.supp_id = _elect_suppressor(rec, now_ms)
	return int(rec.supp_id) == who.get_instance_id()


static func _elect_suppressor(rec: Dictionary, now_ms: float) -> int:
	var members: Dictionary = rec.members
	var tokens: Dictionary = rec.tokens
	var elem: Dictionary = rec.elem
	var best_id: int = 0
	var best_score: int = -1
	for id in members.keys():
		var m: Dictionary = members[id]
		if now_ms - float(m.seen) > MEMBER_TTL_MS:
			members.erase(id)
			continue
		if tokens.has(id):
			continue
		var score: int = 0
		if bool(m.mg):
			score += 4
		if bool(m.covered):
			score += 2
		if int(elem.get(id, 0)) != int(rec.active_elem):
			score += 1
		# Incumbency breaks ties - the slot must not wander between equal men.
		if int(id) == int(rec.supp_id):
			score += 1
		if score > best_score:
			best_score = score
			best_id = int(id)
	return best_id
