## firebase_site_pick.gd - WHERE A FIREBASE GOES, shared by the probe and the render pass.
##
## It lives in its own file for one reason: the probe measures a site and the render pass
## photographs it, and if the two picked their ground independently they would drift apart
## the first time either was edited - the numbers would describe one hill and the pictures
## another. One function, two callers, same seed, same hill.
##
## SitePlanner.find_site() scores for a clear, flat, well-separated FOOTPRINT. It does not
## know that a firebase goes on high ground, and on this map that put the first stamp of
## fsb_kit_alpha in a hollow: four of six bunkers were looking straight into rising ground
## 12-18 m out. Prominence alone then put it on the shoulder of a ridge - 15.4 m of relief
## across the pad, levelled to the mean, leaving a 7 m cut face in front of the same bunkers.
## So the score is BOTH: how far the ground falls away, minus how much of the hill the pad
## has to cut. A firebase goes on a flat-topped hill.
extends RefCounted


## {centre: Vector3 (y=0, as find_site returns it), prominence: float, relief: float}.
## `centre` is Vector3.ZERO when the map has no site with this footprint.
static func pick(planner: SitePlanner, terrain: Node, rng: RandomNumberGenerator,
		radius: float, pad_radius: float, candidates: int = 24) -> Dictionary:
	var best := Vector3.ZERO
	var best_score: float = -1.0e9
	var best_prom: float = 0.0
	var best_relief: float = 0.0
	for _i in range(candidates):
		var c: Vector3 = planner.find_site(rng, radius)
		if c == Vector3.ZERO:
			continue
		var h: float = terrain.get_height_at(c)
		var ring: float = 0.0
		var n: int = 12
		for k in range(n):
			var a: float = TAU * float(k) / float(n)
			ring += terrain.get_height_at(c + Vector3(cos(a), 0.0, sin(a)) * 54.0)
		var prom: float = h - ring / float(n)
		var rel: Array = relief(terrain, c, pad_radius)
		var relief_m: float = rel[1] - rel[0]
		var score: float = prom - relief_m
		if score > best_score:
			best_score = score
			best_prom = prom
			best_relief = relief_m
			best = c
	return {"centre": best, "prominence": best_prom, "relief": best_relief}


## [min_y, max_y] of the terrain over a disc. Reads the HEIGHTMAP, never a raycast: a
## raycast hits the building and reports the roof, which is how "hanging bulbs at +7.8 m"
## was once measured as correct.
static func relief(terrain: Node, centre: Vector3, radius: float, samples: int = 15) -> Array:
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for iz in range(samples):
		for ix in range(samples):
			var fx: float = float(ix) / float(samples - 1) * 2.0 - 1.0
			var fz: float = float(iz) / float(samples - 1) * 2.0 - 1.0
			if Vector2(fx, fz).length() > 1.0:
				continue
			var h: float = terrain.get_height_at(
				Vector3(centre.x + fx * radius, 0.0, centre.z + fz * radius))
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return [lo, hi]
