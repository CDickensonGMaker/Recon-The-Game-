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
## GRADUATED: green since 2026-07-16, and listed in $Graduated in
## run_all_tests.ps1 - a graduated test going red fails the build as a REGRESSION.
##
## Run: godot --headless --path . res://tests/test_nav_path.tscn -- --test-save
extends Node

const SEED_VAL: int = 4242
const HUT_PATH := "res://assets/world/building models/structures/village/thatched_hut.glb"
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

	# Bake a region over the hut, exactly as MissionGenerator.build() does.
	var baker := NavBaker.new()
	world.add_child(baker)
	baker.setup(world.terrain_manager)
	baker.queue_site(center, 20.0)
	var waited: float = 0.0
	while baker.regions_live == 0 and waited < 30.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if baker.regions_live == 0:
		_fail("NavBaker produced no region in 30s")
		_finish(world)
		return

	# regions_live means the mesh was ASSIGNED; the nav map has not necessarily
	# SYNCED it yet. Under suite load that race made this test flaky. Force a sync
	# and wait until map_get_path actually returns something before asserting.
	var map: RID = world.get_world_3d().navigation_map
	var settle: float = 0.0
	while settle < 5.0:
		NavigationServer3D.map_force_update(map)
		await get_tree().physics_frame
		if NavigationServer3D.map_get_path(map, a, b, true).size() >= 2:
			break
		settle += 1.0 / 60.0

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

	# --- Assertion 3: the path bends, rather than passing straight through. ----
	# A 4m hut skirted from 12m out only adds ~0.8m, so the length delta is small;
	# the load-bearing checks are Assertion 2 (clearance) and Assertion 4 (a real
	# enemy walks around and arrives). This is just "it is not a straight line".
	var straight: float = Vector2(a.x - b.x, a.z - b.z).length()
	var walked: float = _xz_path_length(path)
	if walked <= straight + 0.2:
		_fail("path length %.1fm is a straight line through %.1fm - not routing around the hut" % [walked, straight])

	print("path: %d pts, %.1fm walked vs %.1fm straight, closest approach %.2fm" % [
		path.size(), walked, straight, min_dist])

	# --- Assertion 4: drive a real EnemyBase past the hut. --------------------
	# The one that matters: proves _move_toward() actually CONSUMES the navmesh.
	# Today's bee-line code fails both halves - it jams on the hut and never
	# arrives.
	var enemy := EnemyBase.spawn_enemy(world, a, "res://data/enemies/vc_rifleman.tres")
	await get_tree().process_frame
	enemy.set_physics_process(false)  # we drive it by hand at a fixed step
	enemy._nav_box = NavBaker.box_index_at(enemy.global_position)
	var closest: float = INF
	var reached: bool = false
	# Gravity is enemy_base.gd:481-482, inside the _physics_process we just
	# disabled. Without it the agent floats at spawn height while the path
	# descends, and NavigationAgent3D's path_desired_distance is a 3D distance -
	# so it hovers over each waypoint's XZ and never advances.
	for i in range(1200):  # up to 20s @ 60Hz
		enemy._nav_box = NavBaker.box_index_at(enemy.global_position)
		enemy._move_toward(b, 1.0 / 60.0)
		if not enemy.is_on_floor():
			enemy.velocity.y -= enemy.gravity * (1.0 / 60.0)
		enemy.move_and_slide()
		closest = minf(closest, Vector2(enemy.global_position.x - center.x, enemy.global_position.z - center.z).length())
		if enemy.global_position.distance_to(b) < 4.0:
			reached = true
			break
	print("enemy: closest approach to hut %.2fm, reached target %s" % [closest, reached])
	if closest <= CLEARANCE:
		_fail("enemy walked through the hut (closest %.2fm) - agent not using the navmesh" % closest)
	if not reached:
		_fail("enemy never reached the target - path stalled")


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
