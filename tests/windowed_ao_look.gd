## windowed_ao_look.gd - Look-only windowed confirm of a REAL POPULATED mission AO with the
## individual-3D-species canopy (TREE_COVER) live: villages + rice paddies + civilians +
## enemies + activity, the arena feel at world scale. NOT bare game_world. Blender may be open
## so FPS is INVALID - this run is for Caleb's EYES + the objective counts. Builds the whole AO
## behind the scenes, settles physics, then reveals the player standing IN the village and holds.
extends Node

const SEEDS: Array[int] = [47225, 11020, 8080, 424242]
const MISSION_TYPE := MissionGenerator.MissionType.VILLAGE_RAID


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
		var director := MissionDirector.new()
		world.add_child(director)
		director.setup(world)
		plan = MissionGenerator.plan(world, s, MISSION_TYPE)
		var vc: Vector3 = plan.get("village_center", Vector3.ZERO)
		if vc == Vector3.ZERO:
			print("[AOLOOK] seed %d has no village_center - trying next" % s)
			world.queue_free()
			await get_tree().process_frame
			continue
		MissionGenerator.build(world, director, plan)
		seed_used = s
		break

	if world == null or plan.is_empty():
		print("[AOLOOK] FAIL: no inhabited seed produced a village")
		get_tree().quit(1)
		return

	# Force a bright DAY so civilians work the paddies and the jungle reads.
	var weather := MissionWeather.new()
	world.add_child(weather)
	weather.setup(world, "CLEAR", "DAY")

	# Stand IN the ville (not the far insertion pad).
	var vc2: Vector3 = plan.village_center
	world.spawn_player_at(vc2 + Vector3(6, 0, 8))

	await get_tree().physics_frame
	await get_tree().physics_frame

	_report(world, seed_used, plan)
	print("[AOLOOK] HOLDING window for Caleb's eyes - stop_project when done.")


func _report(world: GameWorld, seed_used: int, plan: Dictionary) -> void:
	var vm: Node = world.vegetation_manager
	var tc: Node = vm.get_node_or_null("TreeCoverLayer")
	var species: int = tc._solid_mesh.size() if tc != null else -1
	var tc_nodes: int = tc.get_child_count() if tc != null else -1
	var colliders: int = tc.collider_count() if (tc != null and tc.has_method("collider_count")) else -1
	var clutter: int = 0
	for ch in world.get_children():
		if ch is GroundClutter:
			clutter = ch.get_child_count()
	var defenders: int = get_tree().get_nodes_in_group("village_defenders").size()
	var civilians: int = get_tree().get_nodes_in_group("civilians").size()
	print("=== AO LOOK (seed %d, VILLAGE_RAID) ===" % seed_used)
	print("[AOLOOK] canopy=%s | tree_cover species=%d nodes=%d colliders=%d | clutter=%d" % [
		"TREE_COVER" if WorldConfig.USE_TREE_COVER else "JUNGLE_PATCH", species, tc_nodes, colliders, clutter])
	print("[AOLOOK] village_center=%s | defenders=%d civilians=%d" % [
		str(plan.village_center), defenders, civilians])
	print("[AOLOOK] draw_calls=%d prims=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
