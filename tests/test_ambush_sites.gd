## test_ambush_sites.gd - does AmbushPlanner's cover constraint starve the world of ambushes?
##
## Builds synthetic GameplayGrids (no world generation) and runs AmbushPlanner.plan()
## many times per grid, reporting the fraction of trials that yield a site.
extends Node

const TRIALS: int = 250
const WORLD_SIZE: float = 3072.0
const CELLS: int = 256

const JUNGLE_TYPES: Array[int] = [
	GameplayGrid.TerrainType.LIGHT_JUNGLE,
	GameplayGrid.TerrainType.MEDIUM_JUNGLE,
	GameplayGrid.TerrainType.HEAVY_JUNGLE,
]
const OPEN_TYPES: Array[int] = [
	GameplayGrid.TerrainType.CLEAR,
	GameplayGrid.TerrainType.GRASSLAND,
	GameplayGrid.TerrainType.RICE_PADDY,
]
## Cells per patch side. 4 cells x 12m = 48m blocks - contiguous terrain, not per-cell noise.
const PATCH_CELLS: int = 4


func _ready() -> void:
	print("=== PROBE: AMBUSH SITE YIELD ===")
	print("AmbushPlanner: GOOD_COVER_MIN=%.2f  COVER_NEAR_M=%.1f  rings=%s  candidates=%d" % [
		AmbushPlanner.GOOD_COVER_MIN, AmbushPlanner.COVER_NEAR_M,
		str(AmbushPlanner.COVER_SAMPLE_RINGS), AmbushPlanner.CANDIDATES])
	print("Grids: %dm world / %d cells = %.1fm cells. %d trials per grid.\n" % [
		WORLD_SIZE, CELLS, WORLD_SIZE / float(CELLS), TRIALS])

	var rows: Array[Dictionary] = []
	rows.append(_run("ALL-CLEAR (neg ctrl)", _uniform_grid(GameplayGrid.TerrainType.CLEAR), []))
	rows.append(_run("ALL-HEAVY (pos ctrl)", _uniform_grid(GameplayGrid.TerrainType.HEAVY_JUNGLE), []))
	rows.append(_run("MIXED ~55% jungle", _patch_grid(0.55, 4242), []))
	rows.append(_run("MIXED + 6 paddies", _patch_grid(0.55, 4242), _paddy_centroids(6, 909)))
	rows.append(_run("SPARSE ~20% jungle", _patch_grid(0.20, 7171), []))
	# THE WIRE IS LAW: a keep-out over the whole map must starve the planner even on
	# perfect terrain. A site that survives here is a site that can land on the
	# player's spawn seat.
	rows.append(_run("ALL-HEAVY + keepout (neg ctrl)",
		_uniform_grid(GameplayGrid.TerrainType.HEAVY_JUNGLE), [],
		Rect2(0.0, 0.0, WORLD_SIZE, WORLD_SIZE)))

	_print_table(rows)

	# Where does the gate actually start to bite? Sweep jungle fraction below the
	# sparse case, so the owner can see the margin rather than a single number.
	print("\n--- starvation sweep: jungle fraction vs yield ---")
	var sweep: Array[Dictionary] = []
	for frac in [0.10, 0.05, 0.03, 0.02, 0.01]:
		sweep.append(_run("jungle %4.1f%%" % (float(frac) * 100.0),
			_patch_grid(float(frac), 7171), []))
	_print_table(sweep)

	var neg_yield: float = float((rows[0] as Dictionary)["yield_pct"])
	var keepout_yield: float = float((rows[5] as Dictionary)["yield_pct"])
	var pass_ok: bool = true
	print("")
	if neg_yield > 0.0:
		pass_ok = false
		print("!!! NEGATIVE CONTROL LEAKED: all-CLEAR terrain produced %.1f%% ambush sites." % neg_yield)
		print("!!! The cover gate is NOT biting. This is a bug, not a tuning number.")
	else:
		print("Negative control clean: all-CLEAR terrain yields 0 ambush sites.")
	if keepout_yield > 0.0:
		pass_ok = false
		print("!!! KEEP-OUT LEAKED: %.1f%% of sites landed inside the firebase rect." % keepout_yield)
	else:
		print("Keep-out control clean: a map-wide keep-out yields 0 ambush sites.")

	# The party the generator will place must be the party the planner promised.
	var party_rng := RandomNumberGenerator.new()
	party_rng.seed = 24
	var sample: Dictionary = AmbushPlanner.plan(Vector3(1500.0, 0.0, 1500.0), GARRISON,
		_uniform_grid(GameplayGrid.TerrainType.HEAVY_JUNGLE), [], party_rng)
	var want: int = mini(GARRISON, AmbushPlanner.AMBUSH_SOLDIERS_MAX)
	if sample.is_empty() or int(sample["soldiers"]) != want:
		pass_ok = false
		print("!!! PARTY SIZE WRONG: got %s, wanted %d men from a %d-man garrison." % [
			str(sample.get("soldiers", "no site")), want, GARRISON])
	else:
		print("Party size: a %d-man garrison fields %d men." % [GARRISON, want])
	if sample.has("soldiers") and int(sample["soldiers"]) < AmbushPlanner.AMBUSH_SOLDIERS_MIN:
		pass_ok = false
		print("!!! PARTY BELOW THE DOCUMENTED MINIMUM of %d." % AmbushPlanner.AMBUSH_SOLDIERS_MIN)
	print("=== PROBE PASS ===" if pass_ok else "=== PROBE FAIL ===")
	get_tree().quit(0 if pass_ok else 1)


func _uniform_grid(ttype: int) -> GameplayGrid:
	var grid := GameplayGrid.new(WORLD_SIZE, CELLS)
	grid.terrain_type.fill(ttype)
	return grid


## Contiguous PATCH_CELLS-square blocks; jungle_frac of them are jungle, rest open.
func _patch_grid(jungle_frac: float, grid_seed: int) -> GameplayGrid:
	var grid := GameplayGrid.new(WORLD_SIZE, CELLS)
	var rng := RandomNumberGenerator.new()
	rng.seed = grid_seed
	var patches: int = int(ceil(float(CELLS) / float(PATCH_CELLS)))
	for pz in range(patches):
		for px in range(patches):
			var t: int = 0
			if rng.randf() < jungle_frac:
				t = JUNGLE_TYPES[rng.randi_range(0, JUNGLE_TYPES.size() - 1)]
			else:
				t = OPEN_TYPES[rng.randi_range(0, OPEN_TYPES.size() - 1)]
			for cz in range(pz * PATCH_CELLS, mini((pz + 1) * PATCH_CELLS, CELLS)):
				for cx in range(px * PATCH_CELLS, mini((px + 1) * PATCH_CELLS, CELLS)):
					grid.terrain_type[cz * CELLS + cx] = t
	return grid


func _paddy_centroids(n: int, cseed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = cseed
	var out: Array = []
	for i in range(n):
		out.append(Vector3(rng.randf_range(1000.0, 2000.0), 0.0, rng.randf_range(1000.0, 2000.0)))
	return out


## Matches the generator's camp roll floor (mission_generator.gd AMBUSH_CAMP_FLOOR
## split): a camp must field AMBUSH_SOLDIERS_MIN and still keep men at home.
const GARRISON: int = 6


func _run(label: String, grid: GameplayGrid, paddies: Array,
		keepout: Rect2 = Rect2()) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var pos_rng := RandomNumberGenerator.new()
	pos_rng.seed = 1337
	var found: int = 0
	var score_sum: float = 0.0
	var score_min: float = 999.0
	var score_max: float = -1.0
	for t in range(TRIALS):
		rng.seed = 10000 + t
		var camp_pos := Vector3(
			pos_rng.randf_range(400.0, WORLD_SIZE - 400.0), 0.0,
			pos_rng.randf_range(400.0, WORLD_SIZE - 400.0))
		var plan: Dictionary = AmbushPlanner.plan(camp_pos, GARRISON, grid, paddies,
			rng, keepout)
		if plan.is_empty():
			continue
		found += 1
		var s: float = float(plan["score"])
		score_sum += s
		score_min = minf(score_min, s)
		score_max = maxf(score_max, s)
	var mean_score: float = (score_sum / float(found)) if found > 0 else 0.0
	return {
		"label": label,
		"trials": TRIALS,
		"found": found,
		"yield_pct": 100.0 * float(found) / float(TRIALS),
		"mean_score": mean_score,
		"min_score": score_min if found > 0 else 0.0,
		"max_score": score_max if found > 0 else 0.0,
	}


func _print_table(rows: Array[Dictionary]) -> void:
	print("")
	print("| grid type            | trials | sites | yield % | mean score | min   | max   |")
	print("|----------------------|--------|-------|---------|------------|-------|-------|")
	for r in rows:
		print("| %-20s | %6d | %5d | %6.1f%% | %10.3f | %5.3f | %5.3f |" % [
			String(r["label"]), int(r["trials"]), int(r["found"]),
			float(r["yield_pct"]), float(r["mean_score"]),
			float(r["min_score"]), float(r["max_score"])])
