## windowed_confirm_47225.gd - batched Phase-1+Phase-2 windowed look/FPS confirm.
## Boots game_world on seed 47225 via the DEFAULT JUNGLE_PATCH canopy (NEVER TREE_COVER -
## the resident colliders exceed Jolt's body limit). VSYNC forced OFF for an honest FPS read.
## Logs FPS + draw/prim/object counts + veg/chunk counts at spawn and across a scripted
## traverse, then HOLDS the window up (idle, still logging) for Caleb's eyes until stop_project.
extends Node

const SEED_VAL: int = 47225

var world: GameWorld
var _phase: String = "boot"
var _t: float = 0.0
var _fps: Array[float] = []
var _leg: int = 0
var _legs: Array[Vector3] = []


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("[WCONFIRM] booting game_world seed %d (JUNGLE_PATCH default, vsync OFF)" % SEED_VAL)
	world = load("res://scenes/levels/game_world.tscn").instantiate()
	world.mission_seed = SEED_VAL
	add_child(world)
	while not world.is_world_ready:
		await get_tree().create_timer(0.25).timeout
	_report_static()
	# Traverse legs from the spawn (AO centre) outward across biomes.
	var c: float = world.map_size * 0.5
	_legs = [
		Vector3(c, 0, c), Vector3(c + 180, 0, c + 120),
		Vector3(c - 200, 0, c + 220), Vector3(c + 60, 0, c - 260),
	]
	_phase = "warmup"
	_t = 0.0


func _report_static() -> void:
	var veg: int = 0
	var patch_nodes: int = 0
	var clutter_nodes: int = 0
	var vm: Node = world.vegetation_manager
	var pl: Node = vm.get_node_or_null("JunglePatchLayer")
	if pl != null:
		patch_nodes = _count_mmi(pl)
	for ch in world.get_children():
		if ch is GroundClutter:
			clutter_nodes = ch.get_child_count()
	veg = _count_mmi(world)
	print("[WCONFIRM] READY. chunks=%d | total MultiMeshInstance3D=%d | patch_buckets=%d | clutter_buckets=%d" % [
		world.terrain_manager.get_loaded_chunk_count(), veg, patch_nodes, clutter_nodes])
	print("[WCONFIRM] draw_calls=%d prims=%d objects=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])


func _count_mmi(n: Node) -> int:
	var c: int = 1 if n is MultiMeshInstance3D else 0
	for ch in n.get_children():
		c += _count_mmi(ch)
	return c


func _flush(tag: String) -> void:
	if _fps.is_empty():
		return
	var mn: float = _fps[0]
	var mx: float = _fps[0]
	var sum: float = 0.0
	for f in _fps:
		mn = minf(mn, f); mx = maxf(mx, f); sum += f
	print("[WCONFIRM] %s FPS avg=%.1f min=%.1f max=%.1f (n=%d) | draw=%d prims=%d" % [
		tag, sum / _fps.size(), mn, mx, _fps.size(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	_fps.clear()


func _process(delta: float) -> void:
	if world == null or not world.is_world_ready:
		return
	_t += delta
	match _phase:
		"warmup":
			if _t >= 2.0:
				_phase = "spawn"; _t = 0.0
		"spawn":
			_fps.append(Engine.get_frames_per_second())
			if _t >= 6.0:
				_flush("SPAWN")
				_leg = 1; _teleport(); _phase = "leg"; _t = 0.0
		"leg":
			_fps.append(Engine.get_frames_per_second())
			if _t >= 5.0:
				_flush("LEG%d" % _leg)
				_leg += 1
				if _leg < _legs.size():
					_teleport(); _t = 0.0
				else:
					_phase = "hold"; _t = 0.0
					print("[WCONFIRM] traverse done - HOLDING window for the look. stop_project when done.")
		"hold":
			if _t >= 3.0:
				_t = 0.0
				print("[WCONFIRM] HOLD FPS=%.1f (window up for Caleb)" % Engine.get_frames_per_second())


func _teleport() -> void:
	if world.player == null:
		return
	var p: Vector3 = _legs[_leg]
	p.y = world.terrain_manager.get_height_at(p) + 1.6
	world.player.global_position = p
	world.player.velocity = Vector3.ZERO
	print("[WCONFIRM] -> leg %d at (%.0f, %.0f)" % [_leg, p.x, p.z])
