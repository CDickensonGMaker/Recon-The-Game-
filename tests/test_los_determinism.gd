## test_los_determinism.gd - proves GameplayGrid.has_line_of_sight() is
## deterministic and does NOT consume the shared gameplay RNG stream (ADR-010).
## The old bug (RECONgame-atov): a bare randf() inside the per-frame LOS check
## advanced the global RNG, so the same seed produced a different war depending
## on framerate, and jungle LOS strobed frame to frame.
## Run: godot --headless --path . res://tests/test_los_determinism.tscn
extends Node

const STRIP_Z: float = 600.0
const RAY_FROM := Vector3(20.0, 0.0, STRIP_Z)
const RAY_TO := Vector3(2400.0, 0.0, STRIP_Z)


func _ready() -> void:
	print("=== LOS Determinism Probe (atov) ===")
	var failures: int = 0

	var grid := _make_jungle_grid(4242)

	# --- 1. SHARED-RNG POISON TEST -------------------------------------------
	# Run the LOS check a DIFFERENT number of times on each pass (simulating two
	# framerates), then draw from the GLOBAL RNG. If LOS poisoned the shared
	# stream, more checks = more advancement = a different draw.
	seed(999)
	for i in 200:
		grid.has_line_of_sight(RAY_FROM, RAY_TO)
	var draw_a: float = randf()

	seed(999)
	for i in 900:
		grid.has_line_of_sight(RAY_FROM, RAY_TO)
	var draw_b: float = randf()

	if not is_equal_approx(draw_a, draw_b):
		failures += 1
		print("FAIL: LOS consumed the shared RNG stream (200 checks -> %.9f, 900 checks -> %.9f)" % [draw_a, draw_b])
	else:
		print("PASS poison: global draw identical after 200 vs 900 LOS checks (%.9f)" % draw_a)

	# --- 2. IDEMPOTENCY / NO-STROBE TEST -------------------------------------
	var first: bool = grid.has_line_of_sight(RAY_FROM, RAY_TO)
	var strobe: int = 0
	for i in 500:
		if grid.has_line_of_sight(RAY_FROM, RAY_TO) != first:
			strobe += 1
	if strobe != 0:
		failures += 1
		print("FAIL: LOS strobed - %d of 500 repeat checks disagreed with the first" % strobe)
	else:
		print("PASS idempotent: 500 repeat LOS checks all returned %s" % str(first))

	# --- 3. SAME-SEED DETERMINISM ACROSS FRESH GRIDS -------------------------
	var grid_b := _make_jungle_grid(4242)
	var mismatch: int = 0
	for i in 64:
		var a := Vector3(20.0 + i, 0.0, STRIP_Z)
		var b := Vector3(2400.0 - i, 0.0, STRIP_Z)
		if grid.has_line_of_sight(a, b) != grid_b.has_line_of_sight(a, b):
			mismatch += 1
	if mismatch != 0:
		failures += 1
		print("FAIL: two grids with mission_seed 4242 disagreed on %d of 64 rays" % mismatch)
	else:
		print("PASS determinism: two seed-4242 grids agree on all 64 rays")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)


## A grid with a HEAVY_JUNGLE strip along STRIP_Z so the LOS ray crosses many
## cells that exercise the (formerly bare-randf) block-chance path.
func _make_jungle_grid(seed_val: int) -> GameplayGrid:
	var grid := GameplayGrid.new(3072.0, 256)
	grid.mission_seed = seed_val
	var gz: int = int(STRIP_Z / grid.cell_size_meters)
	for gx in grid.grid_size:
		for dz in range(-1, 2):
			var z: int = gz + dz
			if z >= 0 and z < grid.grid_size:
				grid.terrain_type[z * grid.grid_size + gx] = GameplayGrid.TerrainType.HEAVY_JUNGLE
	return grid
