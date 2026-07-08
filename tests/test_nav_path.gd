## test_nav_path.gd - the assertion that R16 never had.
##
## Commit 2321323 claimed "enemies now actually use the baked chunk navmesh to
## chase/investigate instead of bee-lining into walls." They do not:
## terrain_chunk.gd bake_navigation() is the ONLY place a navmesh is ever
## assigned, and its call site (terrain_manager.gd) is commented out. With no
## nav map, NavigationAgent3D.is_navigation_finished() returns true immediately,
## the get_next_path_position() branch never runs, and _move_toward() falls
## through to the bee-line vector. A silent-success fallback.
##
## No test in the suite touched navigation (`grep -li nav tests/` -> nothing),
## and every sim test TELEPORTS the player rather than walking, so pathfinding
## was never exercised at all. This file is that gap, closed.
##
## KNOWN-RED until Step 6 (see $KnownRed in run_all_tests.ps1). When this goes
## green, delete it from that list.
##
## Run: godot --headless --path . res://tests/test_nav_path.tscn -- --test-save
extends Node

const SEED_VAL: int = 4242
const HUT_PATH := "res://assets/building models/structures/village/thatched_hut.glb"
const HUT_HALF_EXTENT: float = 2.0  ## CollisionTable thatched_hut box = (4, 2.5, 4)
const CLEARANCE: float = 2.0        ## must path at least this far from hut center
const APPROACH: float = 12.0        ## start/end distance either side of the hut

var _failures: int = 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)

	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		_fail("world timeout")
		_finish()
		return

	# Flat, clear ground with exactly one obstacle in the middle.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var center: Vector3 = planner.find_site(rng, 20.0)
	if center == Vector3.ZERO:
		_fail("no flat site found for the hut")
		_finish()
		return
	planner.clear_and_flatten(center, 30.0)
	planner.place_structure(HUT_PATH, center, 0.0)
	await get_tree().physics_frame

	var ground_y: float = world.terrain_manager.get_height_at(center)
	center = Vector3(center.x, ground_y, center.z)
	var a: Vector3 = _seat(world, center + Vector3(0, 0, -APPROACH))
	var b: Vector3 = _seat(world, center + Vector3(0, 0, APPROACH))

	var map: RID = world.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(map)

	# --- Assertion 1: a navmesh exists at all. --------------------------------
	# With no baked region, map_get_path returns an EMPTY PackedVector3Array.
	# This is the assertion the original commit fails.
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, a, b, true)
	print("regions on map: %d | path points: %d" % [
		NavigationServer3D.map_get_regions(map).size(), path.size()])
	if path.size() < 2:
		_fail("nav map returned empty path (navmesh not baked / region not merged)")
		_finish(world)
		return

	# --- Assertion 2: the structure is carved out of the navmesh. -------------
	var min_dist: float = _min_xz_distance_to(path, center)
	if min_dist <= CLEARANCE:
		_fail("path crosses hut footprint (structures not carved into navmesh) - closest approach %.2fm, need > %.2fm" % [min_dist, CLEARANCE])

	# --- Assertion 3: the detour is real. -------------------------------------
	var straight: float = Vector2(a.x - b.x, a.z - b.z).length()
	var walked: float = _xz_path_length(path)
	if walked <= straight + 2.0:
		_fail("path length %.1fm barely exceeds straight line %.1fm - not funnelling around the hut" % [walked, straight])

	print("path: %d pts, %.1fm walked vs %.1fm straight, closest approach %.2fm" % [
		path.size(), walked, straight, min_dist])

	# --- Assertion 4 (Step 6): drive a real EnemyBase through it. -------------
	# Deliberately absent until NavBaker lands. Assertions 1-3 prove the navmesh;
	# Assertion 4 proves _move_toward() actually consumes it, which is the bug.

	_finish(world)


func _seat(world: GameWorld, p: Vector3) -> Vector3:
	return Vector3(p.x, world.terrain_manager.get_height_at(p) + 0.1, p.z)


## Sample along each segment - a 2-point path can still pass straight through
## the hut, so testing only the corner vertices would be a false green.
func _min_xz_distance_to(path: PackedVector3Array, center: Vector3) -> float:
	var best: float = INF
	for i in range(path.size() - 1):
		for s in range(11):
			var p: Vector3 = path[i].lerp(path[i + 1], float(s) / 10.0)
			best = minf(best, Vector2(p.x - center.x, p.z - center.z).length())
	return best


func _xz_path_length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for i in range(path.size() - 1):
		total += Vector2(path[i + 1].x - path[i].x, path[i + 1].z - path[i].z).length()
	return total


func _finish(world: GameWorld = null) -> void:
	if world != null:
		world.queue_free()
		await get_tree().process_frame
	if _failures == 0:
		print("PASS: enemies can path around a structure")
		get_tree().quit(0)
	else:
		print("FAIL: %d nav assertion(s) failed" % _failures)
		get_tree().quit(1)
