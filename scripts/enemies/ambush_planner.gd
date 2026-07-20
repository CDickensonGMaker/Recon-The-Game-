## ambush_planner.gd - where VC stage an ambush, given a camp and the terrain.
##
## Constraints (the doc's "requirements"):
##   - road/trail within 80m
##   - 4-6 soldiers available in the camp garrison
##   - good cover within 30m of the kill zone
##   - line-of-sight from the kill zone to the trail is BLOCKED by jungle
##   - NOT within 30m of a paddy centroid (no silhouettes)
##
## Returns null if no good site is found within 200m of the camp.
class_name AmbushPlanner
extends RefCounted

const ROAD_NEAR_M: float = 80.0
const COVER_NEAR_M: float = 30.0
## Fractions of COVER_NEAR_M to sample. LIGHT_JUNGLE (0.35) is the floor that counts
## as "good cover" - grassland (0.15) and paddy (0.1) are not concealment.
const COVER_SAMPLE_RINGS: Array[float] = [0.2, 0.6, 1.0]
const GOOD_COVER_MIN: float = 0.35
const PADDY_AVOID_M: float = 30.0
const AMBUSH_SOLDIERS_MIN: int = 4
const AMBUSH_SOLDIERS_MAX: int = 6
const SEARCH_RADIUS: float = 200.0
const CANDIDATES: int = 16


static func plan(camp: CampDirector, grid: GameplayGrid,
		paddy_centroids: Array, rng: RandomNumberGenerator) -> Dictionary:
	if camp == null or grid == null or camp.garrison.size() < AMBUSH_SOLDIERS_MIN:
		return {}
	var best: Dictionary = {}
	var best_score: float = -1.0
	for i in range(CANDIDATES):
		var bearing: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(40.0, SEARCH_RADIUS)
		var site: Vector3 = camp.camp_pos + Vector3(cos(bearing), 0.0, sin(bearing)) * dist
		# Hard reject paddies
		if _near_paddy(site, paddy_centroids):
			continue
		# Hard reject open ground. Men who spring an ambush from grass get killed by
		# the counter-volley; the doc always claimed cover was a requirement.
		var cover_score: float = _cover_nearby(grid, site)
		if cover_score < GOOD_COVER_MIN:
			continue
		var los_score: float = _los_blocked(grid, site)
		var score: float = cover_score * 0.6 + los_score * 0.4
		if score > best_score:
			best_score = score
			best = {
				"trigger_pos": site,
				"soldiers": min(camp.garrison.size(), AMBUSH_SOLDIERS_MAX),
				"retreat_to": camp.camp_pos,
				"score": score,
			}
	return best


static func _near_paddy(pos: Vector3, centroids: Array) -> bool:
	for c in centroids:
		if pos.distance_to(c as Vector3) < PADDY_AVOID_M:
			return true
	return false


static func _cover_nearby(grid: GameplayGrid, site: Vector3) -> float:
	# Best cover anywhere within COVER_NEAR_M, sampled on rings of 8 bearings.
	# The old fixed 5m ring ignored the constraint the file documents and rejected
	# good sites whose cover was a short crawl away.
	var best: float = 0.0
	for ring in COVER_SAMPLE_RINGS:
		var radius: float = COVER_NEAR_M * float(ring)
		for k in range(8):
			var a: float = float(k) * TAU / 8.0
			var p: Vector3 = site + Vector3(cos(a), 0.0, sin(a)) * radius
			var g: Vector2i = grid.world_to_grid(p)
			var cv: float = float(GameplayGrid.COVER_VALUES.get(grid.get_terrain_type_at(g.x, g.y), 0.0))
			best = maxf(best, cv)
	return best


static func _los_blocked(grid: GameplayGrid, site: Vector3) -> float:
	# We want jungle BETWEEN us and the road. Sample 4 bearings; reward any
	# where the next 30m is non-clear.
	var blocked: float = 0.0
	for k in range(4):
		var a: float = float(k) * TAU / 4.0
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var jungle_hits: int = 0
		for r in range(3, 18, 3):
			var p: Vector3 = site + d * float(r)
			var tt: int = grid.get_terrain_type_at(grid.world_to_grid(p).x, grid.world_to_grid(p).y)
			if tt in [GameplayGrid.TerrainType.MEDIUM_JUNGLE, GameplayGrid.TerrainType.HEAVY_JUNGLE]:
				jungle_hits += 1
		blocked = maxf(blocked, float(jungle_hits) / 5.0)
	return blocked
