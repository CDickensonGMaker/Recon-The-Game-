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

## The outlook ring this picker measures prominence on. It stays a CIRCLE here because a kit
## site plan has a circular pad; the game's rectangular monolith uses an ellipse sized off its
## own footprint (SitePlanner.FSB_OUTLOOK_M). Same function, different ring.
const OUTLOOK_RING_M: float = 54.0


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
		# BOTH TERMS COME OUT OF SitePlanner, and that is the point of this file since
		# 2026-09-10. They used to be local copies, the game's own picker had no prominence
		# term at all, and the two scored different hills off the same seed - so the tool
		# photographed one base and the game built another.
		var prom: float = SitePlanner.prominence(terrain, c, OUTLOOK_RING_M, OUTLOOK_RING_M)
		var rel: Array = SitePlanner.relief(terrain, c, pad_radius)
		var relief_m: float = rel[1] - rel[0]
		var score: float = prom - relief_m
		if score > best_score:
			best_score = score
			best_prom = prom
			best_relief = relief_m
			best = c
	return {"centre": best, "prominence": best_prom, "relief": best_relief}


## Kept as a name only. The measurement lives in SitePlanner so the probe, the render pass
## and the game all read one instrument (see pick() above).
static func relief(terrain: Node, centre: Vector3, radius: float, samples: int = 15) -> Array:
	return SitePlanner.relief(terrain, centre, radius, samples)
