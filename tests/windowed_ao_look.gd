## windowed_ao_look.gd - Look-only windowed confirm of the REAL PATROL WORLD
## (ADR-029): Caleb's firebase + villages + paddies + civilians + camps, the
## arena feel at world scale. Blender may be open so FPS is INVALID - this run
## is for Caleb's EYES + the counts. Builds the AO, settles physics, then
## reveals the player at a vantage over the nearest village and holds.
extends Node

const SEEDS: Array[int] = [47225, 11020, 8080, 424242]


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var world: GameWorld = null
	var plan: Dictionary = {}
	var seed_used: int = 0
	for s in SEEDS:
		world = load("res://scenes/levels/game_world.tscn").instantiate()
		world.mission_seed = s
		world.spawn_player_on_ready = false
		add_child(world)
		var elapsed: float = 0.0
		while not world.is_world_ready and elapsed < 180.0:
			await get_tree().create_timer(0.25).timeout
			elapsed += 0.25
		if not world.is_world_ready:
			world.queue_free()
			continue
		var director := FieldDirector.new()
		world.add_child(director)
		director.setup(world)
		plan = MissionGenerator.plan_patrol_world(world, s)
		if (plan.get("village_centers", []) as Array).is_empty():
			print("[AOLOOK] seed %d planned no villages - trying next" % s)
			world.queue_free()
			await get_tree().process_frame
			continue
		plan["village_center"] = (plan.village_centers as Array)[0]
		MissionGenerator.build_patrol_world(world, director, plan)
		seed_used = s
		break

	if world == null or plan.is_empty():
		print("[AOLOOK] FAIL: no seed produced a village")
		get_tree().quit(1)
		return

	# Force a bright DAY so civilians work the paddies and the jungle reads.
	var weather := MissionWeather.new()
	world.add_child(weather)
	weather.setup(world, "CLEAR", "DAY")

	# A SAFE VANTAGE overlooking the hamlet: close enough to SEE the village + paddies +
	# jungle, far enough that the (asleep-until-~140m) defenders don't shoot at spawn.
	# Spawning at village_center walks you onto the 6 defenders and you die instantly; the
	# real insertion_lz is ~1km off (no view). Pick the closest passable ring point that is
	# a safe stand-off from EVERY enemy.
	var spawn: Vector3 = _safe_vantage(world, plan.village_center)
	world.spawn_player_at(spawn)

	await get_tree().physics_frame
	await get_tree().physics_frame

	_report(world, seed_used, plan, spawn)
	print("[AOLOOK] HOLDING window for Caleb's eyes - stop_project when done.")


## Closest passable ring point around the hamlet that is >= SAFE_STANDOFF from every enemy.
## Expands the ring until one is found; falls back to a far offset if the AO is crowded.
const SAFE_STANDOFF: float = 155.0
func _safe_vantage(world: GameWorld, village: Vector3) -> Vector3:
	for dist: float in [200.0, 240.0, 290.0, 350.0, 430.0]:
		for a in range(12):
			var ang: float = TAU * float(a) / 12.0
			var cand: Vector3 = village + Vector3(cos(ang), 0.0, sin(ang)) * dist
			cand.x = clampf(cand.x, 24.0, world.map_size - 24.0)
			cand.z = clampf(cand.z, 24.0, world.map_size - 24.0)
			cand.y = world.terrain_manager.get_height_at(cand) + 1.6
			if world.gameplay_grid != null and not world.gameplay_grid.is_position_passable(cand):
				continue
			if _nearest_enemy(world, cand).dist >= SAFE_STANDOFF:
				return cand
	return village + Vector3(430, 0, 0)  # crowded AO fallback


## Nearest enemy to a point - the safety check. Walks the tree for every EnemyBase so it
## catches defenders AND ambient patrols/spider-holes/mortar/AA, not just one group.
func _nearest_enemy(world: GameWorld, spawn: Vector3) -> Dictionary:
	var stack: Array[Node] = [world]
	var best: float = INF
	var count: int = 0
	var who: String = "none"
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is EnemyBase and (n as Node3D).is_inside_tree():
			count += 1
			var d: float = spawn.distance_to((n as Node3D).global_position)
			if d < best:
				best = d
				who = (n as Node3D).name
		for c in n.get_children():
			stack.push_back(c)
	return {"dist": best, "count": count, "who": who}


func _report(world: GameWorld, seed_used: int, plan: Dictionary, spawn: Vector3) -> void:
	var vm: Node = world.vegetation_manager
	var tc: Node = vm.get_node_or_null("TreeCoverLayer")
	var species: int = tc._solid_mesh.size() if tc != null else -1
	var tc_nodes: int = tc.get_child_count() if tc != null else -1
	var colliders: int = tc.collider_count() if (tc != null and tc.has_method("collider_count")) else -1
	var clutter: int = 0
	for ch in world.get_children():
		if ch is GroundClutter:
			clutter = ch.get_child_count()
	var defenders: int = get_tree().get_nodes_in_group("enemies").size()
	var civilians: int = get_tree().get_nodes_in_group("civilians").size()
	print("=== AO LOOK (seed %d, PATROL WORLD) ===" % seed_used)
	print("[AOLOOK] canopy=%s | tree_cover species=%d nodes=%d colliders=%d | clutter=%d" % [
		"TREE_COVER" if WorldConfig.USE_TREE_COVER else "JUNGLE_PATCH", species, tc_nodes, colliders, clutter])
	var near: Dictionary = _nearest_enemy(world, spawn)
	var vdist: float = spawn.distance_to(plan.village_center)
	print("[AOLOOK] spawn=%s | village_center=%s (%.0fm away) | defenders=%d civilians=%d" % [
		str(spawn.round()), str(plan.village_center.round()), vdist, defenders, civilians])
	print("[AOLOOK] SAFETY: nearest of %d enemies is %.0fm away (%s) - %s" % [
		near.count, near.dist, near.who,
		"SAFE" if near.dist > 100.0 else "TOO CLOSE - player may be shot at spawn"])
	print("[AOLOOK] draw_calls=%d prims=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
