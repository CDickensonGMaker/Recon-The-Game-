extends Node
## Smoke test for PaddyStamper. Loads game_world.tscn, awaits is_world_ready,
## runs the stamper, asserts ≥4 village anchors and per-seed determinism.
## Run: godot --headless --path . res://tests/test_paddy_stamper.tscn

const StamperScript := preload("res://scripts/world/paddy_stamper.gd")
const TIMEOUT_SECONDS: float = 180.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 42
	add_child(world)

	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < TIMEOUT_SECONDS:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world not ready in time")
		get_tree().quit(1)
		return

	print("=== PADDY STAMPER SMOKE TEST ===")

	# Seed 42: primary check.
	var result_a: Dictionary = StamperScript.stamp(
		42, world.gameplay_grid, world.terrain_manager, world
	)
	_report("seed 42", result_a)

	# Determinism: same seed, same AO.
	var result_b: Dictionary = StamperScript.stamp(
		42, world.gameplay_grid, world.terrain_manager, world
	)
	var same: bool = _same_centroids(
		result_a.paddy_centroids, result_b.paddy_centroids
	)
	print("Determinism (seed 42): %s" % ("PASS" if same else "FAIL"))

	# Floor check across 5 seeds. Quit non-zero if any seed drops below 4.
	var any_below: bool = false
	for s in [1, 7, 42, 99, 256]:
		var r: Dictionary = StamperScript.stamp(
			s, world.gameplay_grid, world.terrain_manager, world
		)
		var n: int = r.village_anchors.size()
		var ok: String = "OK" if n >= 4 else "BELOW FLOOR"
		if n < 4:
			any_below = true
		print("Seed %d: %d paddies, %d village anchors [%s]" % [s, r.paddies.size(), n, ok])

	if any_below:
		print("FAIL: at least one seed produced fewer than 4 village anchors")
		get_tree().quit(1)
		return

	print("=== SMOKE TEST COMPLETE ===")
	get_tree().quit(0)


func _report(label: String, r: Dictionary) -> void:
	print("%s: %d paddies, %d village anchors" % [
		label, r.paddies.size(), r.village_anchors.size()
	])
	for i in range(r.paddies.size()):
		var pf: Resource = r.paddies[i]
		print("  paddy[%d] id=%s cells=%d center=%s" % [
			i, pf.paddy_id, pf.cell_count, str(pf.world_position)
		])
	for i in range(r.village_anchors.size()):
		var a: Dictionary = r.village_anchors[i]
		print("  anchor[%d] center=%s paddies=%s working_points=%d" % [
			i, str(a.center), str(a.paddies), a.working_points.size()
		])


func _same_centroids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true
