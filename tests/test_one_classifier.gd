## test_one_classifier.gd - the jungle must not lie (bead 6od4).
## Proves the AI sight-cap grid (GameplayGrid) and the visible-jungle instancer
## (VegetationManager) classify identical LAND terrain, because both route through the
## one TerrainZoning classifier. Ratcheting guard: if either grows its own divergent
## terrain logic again, the AI conceals against ground the player cannot see, and this reds.
## Run: godot --headless --path . res://tests/test_one_classifier.tscn
extends Node3D

const GameplayGridScript := preload("res://terrain/core/gameplay_grid.gd")
const VegManagerScript := preload("res://terrain/vegetation/vegetation_manager.gd")

const SEED: int = 424242
const SAMPLES_PER_AXIS: int = 100          # 100 x 100 = 10,000 positions
const MAP_M: float = 1280.0

# WATER=6 / CLIFF=7 are pathing overrides only the grid applies (ADR-013 passability);
# they are legitimately grid-only, so land-agreement excludes them.
const WATER := 6
const CLIFF := 7


func _ready() -> void:
	print("=== ONE CLASSIFIER: AI-zone vs veg-zone agreement (bead 6od4) ===")
	var failures: int = 0

	var grid: Object = GameplayGridScript.new(MAP_M, 256)
	grid.mission_seed = SEED
	var vm: Object = VegManagerScript.new()
	vm.mission_seed = SEED
	# _ready() (not run off-tree) is the only thing that sets this; do it by hand.
	vm._min_slope_dot = cos(deg_to_rad(vm.max_slope_degrees))
	# The lowland paddy gate is now RELATIVE (configured per-map from the heightmap). This
	# synthetic band (2..400m) has no heightmap, so fix the ceiling inside the band: heights
	# below are lowland (paddy/grass), above are jungle. Both classifiers read this same
	# static, which is exactly the 6od4 agreement under test.
	TerrainZoning._lowland_ceiling = 60.0

	var compared: int = 0
	var disagreements: int = 0
	var seen: Dictionary = {}          # terrain-type histogram (non-degeneracy proof)
	var det_breaks: int = 0

	for iz in SAMPLES_PER_AXIS:
		for ix in SAMPLES_PER_AXIS:
			var wx: float = (float(ix) + 0.5) / SAMPLES_PER_AXIS * MAP_M
			var wz: float = (float(iz) + 0.5) / SAMPLES_PER_AXIS * MAP_M
			# Sweep the full relief band the game generates: lowland paddy -> mountain jungle.
			var height: float = 2.0 + (float(ix * SAMPLES_PER_AXIS + iz) / float(SAMPLES_PER_AXIS * SAMPLES_PER_AXIS)) * 398.0

			# Flat, dry samples so the grid's WATER/CLIFF overrides do not fire (water_system
			# is null here); this isolates the LAND zoning both systems must share.
			var g: int = grid._determine_terrain_type(height, 0.0, wx, wz)
			if g == WATER or g == CLIFF:
				continue
			var v: int = vm._determine_terrain_type(height, 1.0, wx, wz)
			compared += 1
			seen[g] = int(seen.get(g, 0)) + 1
			if g != v:
				disagreements += 1
				if disagreements <= 5:
					push_warning("[6od4] divergence at (%.1f,%.1f) h=%.1f: grid=%d veg=%d" % [wx, wz, height, g, v])

			# Determinism (ADR-010): same cell + seed -> same zone.
			if TerrainZoning.classify(height, wx, wz, SEED) != g:
				det_breaks += 1

	print("  compared land cells: %d" % compared)
	print("  disagreements:       %d" % disagreements)
	print("  determinism breaks:  %d" % det_breaks)
	print("  terrain-type histogram (0..5): %s" % str(seen))

	if disagreements != 0:
		printerr("FAIL: AI zone != veg zone in %d cells - the jungle lies (bead 6od4)" % disagreements)
		failures += 1
	if det_breaks != 0:
		printerr("FAIL: classifier not deterministic in %d cells (ADR-010)" % det_breaks)
		failures += 1
	# Non-degeneracy: a classifier that returns one constant would trivially "agree".
	if seen.size() < 3:
		printerr("FAIL: classifier degenerate - only %d terrain types produced" % seen.size())
		failures += 1
	if not seen.has(TerrainZoning.HEAVY_JUNGLE) or not seen.has(TerrainZoning.RICE_PADDY):
		printerr("FAIL: expected both HEAVY_JUNGLE and RICE_PADDY across the relief band")
		failures += 1

	if failures == 0:
		print("PASS: one classifier - AI concealment matches the visible jungle (%d cells)" % compared)
	else:
		print("=== %d FAILURE(S) ===" % failures)

	get_tree().quit(1 if failures > 0 else 0)
