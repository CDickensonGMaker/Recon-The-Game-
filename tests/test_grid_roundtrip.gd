extends Node
## test_grid_roundtrip.gd - world_to_grid and grid_to_world must be mutual inverses
## on EVERY GameplayGrid subclass, not just the base.
##
## THE DEFECT CLASS: a subclass that overrides one half of the pair and not the
## other. ai_stress_arena.gd's ArenaGrid shifts its sample by world_size * 0.5 so
## the arena's negative half does not collapse onto cell 0. If only world_to_grid
## carried that shift, grid_to_world would answer 640m away on a 1280m map - and
## nothing would throw, because both functions return a perfectly valid coordinate.
##
## This is why the pair could not simply be deleted as a fossil (RECONgame-ljm4):
## the override is CORRECT, and it is the base-class math that would be wrong for
## an arena grid. What was missing was an assert that they agree.
##
## Run: godot --headless --path . res://tests/test_grid_roundtrip.tscn

const ArenaScript: GDScript = preload("res://scripts/levels/ai_stress_arena.gd")

var _fails: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: GRID COORDINATE ROUNDTRIP ===")

	# Negative control: a grid whose halves disagree MUST be caught. A probe that
	# has never failed proves nothing.
	var broken := BrokenGrid.new()
	_configure(broken, 1280.0, 12.0)
	if _roundtrip_errors(broken, "control") == 0:
		print("FAIL: self-test - a deliberately desynced grid passed the roundtrip")
		get_tree().quit(1)
		return
	print("Self-test OK: desynced control grid was caught.")

	var base := GameplayGrid.new()
	_configure(base, 3072.0, 12.0)
	_check(base, "GameplayGrid (origin at world 0)")

	var arena: GameplayGrid = ArenaScript.ArenaGrid.new()
	_configure(arena, 200.0, 4.0)
	_check(arena, "ArenaGrid (origin at arena centre)")

	# The two must NOT be interchangeable, or the override is pointless and the
	# real answer to ljm4 would have been deletion. Prove the divergence is real.
	var a_centre: Vector3 = arena.grid_to_world(Vector2i(0, 0))
	if a_centre.x >= 0.0:
		print("FAIL: ArenaGrid cell (0,0) is at x=%.2f - it no longer spans negative space, so the override is dead weight" % a_centre.x)
		_fails += 1
	else:
		print("ArenaGrid cell (0,0) -> x=%.2f (spans negative space, as intended)" % a_centre.x)

	print("--- %d roundtrip failures ---" % _fails)
	if _fails > 0:
		print("FAIL")
		get_tree().quit(1)
		return
	print("PASS")
	get_tree().quit(0)


func _check(grid: GameplayGrid, label: String) -> void:
	var bad: int = _roundtrip_errors(grid, label)
	if bad > 0:
		print("FAIL: %s - %d cells did not survive grid->world->grid" % [label, bad])
		_fails += 1
	else:
		print("OK: %s - all %d sampled cells roundtrip exactly" % [label, grid.grid_size * grid.grid_size])


## Every cell centre must map back to its own cell. Cell centres are the only
## points guaranteed to be unambiguous; edges belong to whichever side rounds.
func _roundtrip_errors(grid: GameplayGrid, _label: String) -> int:
	var bad: int = 0
	for gz in range(grid.grid_size):
		for gx in range(grid.grid_size):
			var cell := Vector2i(gx, gz)
			var back: Vector2i = grid.world_to_grid(grid.grid_to_world(cell))
			if back != cell:
				if bad < 3:
					print("  desync: %s -> %s" % [cell, back])
				bad += 1
	return bad


func _configure(grid: GameplayGrid, world_size: float, cell: float) -> void:
	grid.world_size = world_size
	grid.cell_size_meters = cell
	grid.grid_size = int(world_size / cell)


## A grid that shifts only ONE half of the pair - the exact bug under test.
class BrokenGrid extends GameplayGrid:
	func world_to_grid(world_pos: Vector3) -> Vector2i:
		var off: float = world_size * 0.5
		return Vector2i(
			clampi(int((world_pos.x + off) / cell_size_meters), 0, grid_size - 1),
			clampi(int((world_pos.z + off) / cell_size_meters), 0, grid_size - 1))
