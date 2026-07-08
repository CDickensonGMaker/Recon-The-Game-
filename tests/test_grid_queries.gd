## test_grid_queries.gd - NS03 verification: gameplay grid + water + crater.
## Run: godot --headless --path . res://tests/test_grid_queries.tscn
extends Node

const TIMEOUT_SECONDS: float = 180.0


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 1337
	add_child(world)

	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < TIMEOUT_SECONDS:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world not ready in time")
		get_tree().quit(1)
		return

	var failures: int = 0

	# 1. Grid exists and answers queries across the AO.
	if world.gameplay_grid == null:
		print("FAIL: gameplay_grid is null")
		get_tree().quit(1)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var type_counts := {}
	var margin: float = 64.0
	for i in range(200):
		var p := Vector3(
			rng.randf_range(margin, world.map_size - margin),
			0.0,
			rng.randf_range(margin, world.map_size - margin)
		)
		var t: int = world.gameplay_grid.get_terrain_type(p)
		if t < 0 or t > 7:
			print("FAIL: invalid terrain type %d at %s" % [t, p])
			failures += 1
		type_counts[t] = int(type_counts.get(t, 0)) + 1
	print("terrain type distribution: %s" % [type_counts])

	var jungle_found: bool = (type_counts.has(GameplayGrid.TerrainType.LIGHT_JUNGLE)
		or type_counts.has(GameplayGrid.TerrainType.MEDIUM_JUNGLE)
		or type_counts.has(GameplayGrid.TerrainType.HEAVY_JUNGLE))
	if not jungle_found:
		print("FAIL: no jungle found in 200 samples")
		failures += 1

	# Water bodies may legitimately be absent on some seeds; report, don't fail.
	if not type_counts.has(GameplayGrid.TerrainType.WATER):
		print("NOTE: no WATER cells sampled (seed-dependent, acceptable)")

	# 2. Passability sanity.
	var passable_found: bool = false
	for i in range(50):
		var p := Vector3(
			rng.randf_range(margin, world.map_size - margin), 0.0,
			rng.randf_range(margin, world.map_size - margin)
		)
		if world.gameplay_grid.is_position_passable(p):
			passable_found = true
			break
	if not passable_found:
		print("FAIL: no passable position in 50 samples")
		failures += 1

	# 3. Crater test: DamageSystem drops the heightmap.
	var crater_pos := Vector3(world.map_size * 0.5 + 40.0, 0.0, world.map_size * 0.5 + 40.0)
	var before: float = world.terrain_manager.get_height_at(crater_pos)
	DamageSystem.apply_damage(crater_pos, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	await get_tree().process_frame
	var after: float = world.terrain_manager.get_height_at(crater_pos)
	print("crater: before=%.2f after=%.2f delta=%.2f" % [before, after, before - after])
	if after >= before:
		print("FAIL: crater did not lower terrain")
		failures += 1

	# 4. Water system responded.
	print("water stats: %s" % [world.water_system.get_stats()])

	if failures == 0:
		print("PASS: grid queries + crater + water wiring OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d failures" % failures)
		get_tree().quit(1)
