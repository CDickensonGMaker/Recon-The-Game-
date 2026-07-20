## ambush_planner.gd - where VC stage an ambush, given a camp and the terrain.
##
## Constraints:
##   - PREFERS ground near a traffic line (road/trail) - a preference, never a gate
##   - 4-6 soldiers available in the camp garrison
##   - good cover within 30m of the kill zone
##   - line-of-sight from the kill zone to the trail is BLOCKED by jungle
##   - NOT within 30m of a paddy centroid (no silhouettes)
##   - NOT inside the firebase keep-out (the wire is law)
##
## Returns an empty Dictionary if no good site is found within 200m of the camp.
class_name AmbushPlanner
extends RefCounted

## Distance to the nearest traffic line at which a site scores full marks. Men ambush
## where things move.
##
## THIS IS A SCORE TERM AND MUST NEVER BECOME A HARD REJECT. Camps are sited 400-540m
## from the wire gate; the road network's own termini (the villages) sit at 240-470m.
## The camp band lies OUTSIDE the road band by construction, so a hard "road within
## 80m" gate would return an empty plan for roughly one camp in three, every seed -
## and the loss would be INVISIBLE, because a rejected ambush silently returns its men
## to the camp garrison and no headcount changes. The AO would just quietly get duller.
## Multiplicative weighting cannot zero a site, so adding roads can only MOVE an
## ambush onto better ground, never delete one. tests/test_ambush_traffic.gd asserts
## exactly that.
const TRAFFIC_NEAR_M: float = 80.0
## Beyond this, proximity to traffic contributes nothing. Between the two it fades.
const TRAFFIC_FAR_M: float = 300.0
## Score floor when a site is nowhere near traffic. The site still stands on its cover
## and concealment - which is the substance - and merely scores below one that also
## overwatches a road.
const TRAFFIC_FLOOR: float = 0.55
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


## `keepout` is the firebase rect (already grown by the caller's clearance). An
## empty Rect2 disables the test - synthetic grids have no firebase.
## `roads` may be null - synthetic grids and any world built before the road network
## exists have no traffic lines, and the planner must still return sites.
static func plan(camp_pos: Vector3, garrison_size: int, grid: GameplayGrid,
		paddy_centroids: Array, rng: RandomNumberGenerator,
		keepout: Rect2 = Rect2(), roads: RoadNetwork = null) -> Dictionary:
	if grid == null or garrison_size < AMBUSH_SOLDIERS_MIN:
		return {}
	var best: Dictionary = {}
	var best_score: float = -1.0
	for i in range(CANDIDATES):
		var bearing: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(40.0, SEARCH_RADIUS)
		var site: Vector3 = camp_pos + Vector3(cos(bearing), 0.0, sin(bearing)) * dist
		# A camp within SEARCH_RADIUS of the wire can otherwise site its ambush on
		# the player's own spawn seat.
		if keepout.size != Vector2.ZERO and keepout.has_point(Vector2(site.x, site.z)):
			continue
		# Hard reject paddies
		if _near_paddy(site, paddy_centroids):
			continue
		# Hard reject open ground. Men who spring an ambush from grass get killed by
		# the counter-volley; the doc always claimed cover was a requirement.
		var cover_score: float = _cover_nearby(grid, site)
		if cover_score < GOOD_COVER_MIN:
			continue
		var los_score: float = _los_blocked(grid, site)
		var traffic: float = _traffic_weight(roads, site)
		var score: float = (cover_score * 0.6 + los_score * 0.4) * traffic
		if score > best_score:
			best_score = score
			best = {
				"trigger_pos": site,
				"soldiers": mini(garrison_size, AMBUSH_SOLDIERS_MAX),
				"retreat_to": camp_pos,
				"score": score,
				"traffic_dist": _traffic_distance(roads, site),
			}
	return best


## Distance from a site to the nearest road centreline, or INF when there is no road
## network at all. INF means "no traffic line here" and must never be read as zero.
static func _traffic_distance(roads: RoadNetwork, site: Vector3) -> float:
	if roads == null:
		return INF
	return roads.distance_to_road(site)


## Multiplier in [TRAFFIC_FLOOR, 1.0]. Full marks within TRAFFIC_NEAR_M, fading
## linearly to the floor at TRAFFIC_FAR_M. Never returns zero - see TRAFFIC_NEAR_M.
static func _traffic_weight(roads: RoadNetwork, site: Vector3) -> float:
	var d: float = _traffic_distance(roads, site)
	if is_inf(d):
		return TRAFFIC_FLOOR
	if d <= TRAFFIC_NEAR_M:
		return 1.0
	if d >= TRAFFIC_FAR_M:
		return TRAFFIC_FLOOR
	var t: float = 1.0 - (d - TRAFFIC_NEAR_M) / (TRAFFIC_FAR_M - TRAFFIC_NEAR_M)
	return TRAFFIC_FLOOR + (1.0 - TRAFFIC_FLOOR) * t


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
