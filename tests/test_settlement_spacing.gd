## test_settlement_spacing.gd - village structures scatter >= 14m
## apart on a flattened footprint, deterministically. On 3 seeds.
## Run: <godot> --headless --path . res://tests/test_settlement_spacing.tscn
extends Node

const SEEDS: Array[int] = [42, 1337, 9001]
const MIN_SEP_M: float = 14.0
const SEP_EPSILON: float = 0.05  ## float tolerance
const MAX_FLAT_SPREAD_M: float = 6.0  ## building Y spread on a flattened footprint


func _ready() -> void:
	var failures: int = 0
	for seed_val in SEEDS:
		failures += await _test_seed(seed_val)
	if failures == 0:
		print("PASS: villages scatter >=14m, flat, deterministic")
		get_tree().quit(0)
	else:
		print("FAIL: %d settlement failures" % failures)
		get_tree().quit(1)


func _test_seed(seed_val: int) -> int:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = seed_val
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL[%d]: world timeout" % seed_val)
		world.queue_free()
		return 1

	var failures: int = 0
	# Villages sit on flat lowland (paddy anchors in-game): pick the flattest of a
	# few candidate sites, matching where the mission generator actually places them.
	var probe := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var center := Vector3.ZERO
	var best_slope: float = INF
	for _c in range(3):
		var cand: Vector3 = probe.find_site(_rng(seed_val + _c), 30.0)
		if cand == Vector3.ZERO:
			continue
		var s: float = world.gameplay_grid.get_slope(cand)
		if s < best_slope:
			best_slope = s
			center = cand
	if center == Vector3.ZERO:
		print("FAIL[%d]: no village site" % seed_val)
		world.queue_free()
		return 1

	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var village: Dictionary = planner.stamp_village(center, _rng(seed_val))
	var nodes: Array = village.nodes
	# The >=14m / flatness rules govern BUILDINGS (huts + centre feature). Concealed
	# VC props (cache behind a hut, spider holes, punji) are deliberately close/outside.
	var huts: Array[Vector3] = _huts(nodes)

	# 1) Minimum separation among huts, and hut-to-centre feature.
	var min_d: float = INF
	for i in range(huts.size()):
		min_d = minf(min_d, Vector2(huts[i].x, huts[i].z).distance_to(Vector2(center.x, center.z)))
		for j in range(i + 1, huts.size()):
			min_d = minf(min_d, huts[i].distance_to(huts[j]))
	if min_d < MIN_SEP_M - SEP_EPSILON:
		print("FAIL[%d]: two buildings only %.2fm apart (min %.0fm)" % [seed_val, min_d, MIN_SEP_M])
		failures += 1

	# 2) No per-building tilt - every structure is upright (the offset/spinning fix
	# is diegetic: place_structure only yaws, so pitch/roll must be exactly zero).
	for n in nodes:
		if not (is_instance_valid(n) and n is Node3D):
			continue
		var rot: Vector3 = (n as Node3D).global_rotation
		if absf(rot.x) > 0.01 or absf(rot.z) > 0.01:
			print("FAIL[%d]: %s tilted (pitch %.3f roll %.3f)" % [seed_val, (n as Node3D).name, rot.x, rot.z])
			failures += 1
			break

	# 3) Shared foundation: hut Y spread stays small (no per-hut stagger on a slope).
	var y_min: float = INF
	var y_max: float = -INF
	for p in huts:
		y_min = minf(y_min, p.y)
		y_max = maxf(y_max, p.y)
	var spread: float = y_max - y_min
	var allowed: float = maxf(MAX_FLAT_SPREAD_M, best_slope * SiteLayouts.VILLAGE_FOOTPRINT_RADIUS * 2.0)
	if spread > allowed:
		print("FAIL[%d]: footprint not flat - %.2fm hut Y spread (allowed %.2f, site slope %.3f)" % [seed_val, spread, allowed, best_slope])
		failures += 1

	# 4) Determinism: same seed + centre reproduces the same structure positions.
	var planner2 := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var village2: Dictionary = planner2.stamp_village(center, _rng(seed_val))
	var positions: Array[Vector3] = _positions(nodes)
	var positions2: Array[Vector3] = _positions(village2.nodes)
	if positions.size() != positions2.size():
		print("FAIL[%d]: non-deterministic node count %d vs %d" % [seed_val, positions.size(), positions2.size()])
		failures += 1
	else:
		for i in range(positions.size()):
			var xz1 := Vector2(positions[i].x, positions[i].z)
			var xz2 := Vector2(positions2[i].x, positions2[i].z)
			if xz1.distance_to(xz2) > 0.01:
				print("FAIL[%d]: non-deterministic position %d" % [seed_val, i])
				failures += 1
				break

	print("seed %d: huts=%d nodes=%d min_sep=%.2fm hut_spread=%.2fm" % [
		seed_val, huts.size(), positions.size(), min_d, spread])
	world.queue_free()
	await get_tree().process_frame
	return failures


## Hut building positions - the structures the >=14m spread rule governs.
func _huts(nodes: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n in nodes:
		if is_instance_valid(n) and n is Node3D and (n as Node3D).is_in_group("flammable_structures"):
			out.append((n as Node3D).global_position)
	return out


func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val + 555
	return r


func _positions(nodes: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n in nodes:
		if is_instance_valid(n) and n is Node3D:
			out.append((n as Node3D).global_position)
	return out
