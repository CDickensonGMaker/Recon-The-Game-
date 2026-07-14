extends RefCounted
## Spatial rules for spawning VC hideouts around a village. Pure data, no engine
## deps, so a future test can construct a known world and assert placement
## behavior. (RECONgame-bx2m)

enum HideoutType { CAMP, TUNNEL }

const VILLAGE_RADIUS_MIN: float = 175.0
const VILLAGE_RADIUS_MAX: float = 300.0
const HIDEOUT_HIDEOUT_MIN: float = 500.0
const CAMP_FIREBASE_MIN: float = 400.0
const TUNNEL_FIREBASE_MIN: float = 150.0
const VILLAGE_FIREBASE_MIN: float = 250.0
const VILLAGE_FIREBASE_MAX: float = 400.0
const ANGULAR_SEPARATION_DEG: float = 90.0

## Returns true if `proposed` satisfies every spatial rule for the given hideout
## type, given the village it's tied to, the already-placed hideouts, and the
## firebases. The function does not sample a position — it JUDGES a candidate.
## The spawner (village_spawner.gd) tries candidates until one passes.
static func is_legal(
	proposed: Vector2,
	hideout_type: int,
	village_pos: Vector2,
	other_hideouts: Array[Vector2],
	firebases: Array[Vector2],
) -> bool:
	if not _in_village_ring(proposed, village_pos):
		return false
	if not _clear_of_other_hideouts(proposed, other_hideouts):
		return false
	if not _clear_of_firebases(proposed, hideout_type, firebases):
		return false
	if not _angularly_separated(proposed, village_pos, other_hideouts):
		return false
	return true


static func _in_village_ring(p: Vector2, village: Vector2) -> bool:
	var d: float = p.distance_to(village)
	return d >= VILLAGE_RADIUS_MIN and d <= VILLAGE_RADIUS_MAX


static func _clear_of_other_hideouts(p: Vector2, others: Array[Vector2]) -> bool:
	for h in others:
		if p.distance_to(h) < HIDEOUT_HIDEOUT_MIN:
			return false
	return true


static func _clear_of_firebases(p: Vector2, hideout_type: int, firebases: Array[Vector2]) -> bool:
	for fb in firebases:
		var d: float = p.distance_to(fb)
		if hideout_type == HideoutType.CAMP and d < CAMP_FIREBASE_MIN:
			return false
		if hideout_type == HideoutType.TUNNEL and d < TUNNEL_FIREBASE_MIN:
			return false
	return true


static func _angularly_separated(p: Vector2, village: Vector2, others: Array[Vector2]) -> bool:
	if others.is_empty():
		return true
	var p_angle: float = _angle_from_village(p, village)
	for h in others:
		var h_angle: float = _angle_from_village(h, village)
		var delta: float = absf(p_angle - h_angle)
		if delta > 180.0:
			delta = 360.0 - delta
		if delta < ANGULAR_SEPARATION_DEG:
			return false
	return true


static func _angle_from_village(p: Vector2, village: Vector2) -> float:
	var a: float = (p - village).angle()
	return rad_to_deg(a) as float


## Convenience: does the village itself sit in the right distance band from any
## firebase? Used when the spawner is considering whether a candidate village
## location is even legal. (A village at 0m from a firebase is rejected.)
static func village_location_legal(village: Vector2, firebases: Array[Vector2]) -> bool:
	for fb in firebases:
		var d: float = village.distance_to(fb)
		if d < VILLAGE_FIREBASE_MIN or d > VILLAGE_FIREBASE_MAX:
			return false
	return true
