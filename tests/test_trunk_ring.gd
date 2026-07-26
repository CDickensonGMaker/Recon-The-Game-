## test_trunk_ring.gd - the player-keyed pooled trunk-collision ring (Caleb's ruling
## 2026-07-25: physics only for trees within 70m of the player). Proves:
##   (a) a built chunk stores trunk CANDIDATES with zero bodies while no center is set;
##   (b) setting a center in jungle assigns pooled bodies, bounded by POOL_MAX, shapes
##       shared per distinct radius;
##   (c) total physics bodies at a dense center stay far under Jolt's 32,768 cap;
##   (d) moving the center 200m releases the old ring and bodies the new one;
##   (e) clear_chunk under an active ring releases that chunk's bodies;
##   (f) a blast rebuild (clear_area path) creates ZERO net new bodies - pure pool reuse.
## Run: godot --headless --path . res://tests/test_trunk_ring.tscn -- --test-save
extends Node

const SEED_VAL: int = 47225
const VegManagerScript := preload("res://terrain/vegetation/vegetation_manager.gd")
## Densest measured spot for this seed (ring-demand measurement, 2026-07-25).
const DENSE_XZ := Vector2(560.0, 160.0)

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	print("=== TRUNK COLLISION RING (seed %d) ===" % SEED_VAL)
	var world: GameWorld = load("res://scenes/levels/game_world.tscn").instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		_fail("world timeout")
		return _finish()

	var hm: Object = world.terrain_manager.heightmap
	var cs: float = world.terrain_manager.chunk_size

	var vm: VegetationManager = VegManagerScript.new()
	vm.canopy_source = VegManagerScript.CanopySource.TREE_COVER
	vm.mission_seed = SEED_VAL
	vm.cell_size = WorldConfig.CELL_SIZE
	vm._terrain_manager = world.terrain_manager
	add_child(vm)
	await get_tree().process_frame
	var tc: TreeCoverLayer = vm._tree_cover

	var center := Vector3(DENSE_XZ.x, 0.0, DENSE_XZ.y)
	center.y = world.terrain_manager.get_height_at(center)
	var far_center: Vector3 = center + Vector3(200.0, 0.0, 0.0)
	far_center.y = world.terrain_manager.get_height_at(far_center)
	for coord: Vector2i in _ring_chunks(center, cs) + _ring_chunks(far_center, cs):
		vm.generate_for_chunk(coord, hm, cs)

	# (a) candidates without bodies
	var candidates: int = 0
	for coord: Vector2i in tc._chunk_trunks:
		candidates += (tc._chunk_trunks[coord]["positions"] as PackedVector3Array).size()
	print("candidates=%d  bodies(before center)=%d" % [candidates, tc.collider_count()])
	if candidates <= 0:
		_fail("(a) built chunks stored no trunk candidates")
	if tc.collider_count() != 0:
		_fail("(a) %d bodies exist with no ring center set" % tc.collider_count())

	# (b) center in jungle -> pooled bodies
	tc.ring_center_override = center
	await get_tree().physics_frame
	await get_tree().physics_frame
	var assigned: int = tc.collider_count()
	print("bodies(center set)=%d  POOL_MAX=%d  shared shapes=%d" % [
		assigned, tc.POOL_MAX, tc._shape_by_radius.size()])
	if assigned <= 0:
		_fail("(b) no bodies assigned at a jungle center")
	if assigned > tc.POOL_MAX:
		_fail("(b) %d assigned bodies exceed POOL_MAX %d" % [assigned, tc.POOL_MAX])
	if tc._shape_by_radius.size() > 7:
		_fail("(b) %d cylinder shapes - shapes not shared per radius" % tc._shape_by_radius.size())
	if not _all_bodies_within(tc, center):
		_fail("(b) an assigned body sits outside RING_RADIUS of the center")

	# (c) total physics bodies bounded
	var total_bodies: int = _count_physics_bodies(get_tree().root)
	print("total physics bodies in tree=%d" % total_bodies)
	if total_bodies >= 5000:
		_fail("(c) %d physics bodies - ring did not bound the body count" % total_bodies)

	# (d) moving 200m releases + reassigns
	tc.ring_center_override = far_center
	await get_tree().physics_frame
	await get_tree().physics_frame
	var moved: int = tc.collider_count()
	print("bodies(center +200m)=%d" % moved)
	if moved <= 0:
		_fail("(d) no bodies after moving the center 200m")
	if not _all_bodies_within(tc, far_center):
		_fail("(d) a body from the OLD ring survived the 200m move")

	# (e) clear_chunk releases its bodies
	if tc._chunk_bodies.is_empty():
		_fail("(e) no chunk holds assigned bodies to clear")
	else:
		var coord: Vector2i = (tc._chunk_bodies.keys() as Array)[0]
		var held: int = (tc._chunk_bodies[coord] as Dictionary).size()
		var before: int = tc.collider_count()
		tc.clear_chunk(coord)
		if tc._chunk_bodies.has(coord):
			_fail("(e) clear_chunk left assignment records behind")
		if tc.collider_count() != before - held:
			_fail("(e) clear_chunk released %d of %d bodies" % [before - tc.collider_count(), held])

	# (f) blast rebuild = pure pool reuse, zero net new bodies
	var pool_before: int = tc._pool.size()
	vm.clear_area(far_center, 15.0, cs, hm)
	await get_tree().physics_frame
	var pool_after: int = tc._pool.size()
	var body_children: int = 0
	for c: Node in tc.get_children():
		if c is StaticBody3D:
			body_children += 1
	print("pool before/after blast=%d/%d  body children=%d  bodies=%d" % [
		pool_before, pool_after, body_children, tc.collider_count()])
	if pool_after != pool_before:
		_fail("(f) blast rebuild grew the pool %d -> %d" % [pool_before, pool_after])
	if body_children != pool_after:
		_fail("(f) %d StaticBody3D children vs pool %d - bodies built outside the pool" % [
			body_children, pool_after])
	if pool_after > tc.POOL_MAX:
		_fail("(f) pool %d exceeds POOL_MAX %d" % [pool_after, tc.POOL_MAX])
	if tc.collider_count() <= 0:
		_fail("(f) blast rebuild left the ring bodiless")

	_finish()


func _ring_chunks(center: Vector3, cs: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: float = 80.0
	for cz in range(int(floor((center.z - r) / cs)), int(floor((center.z + r) / cs)) + 1):
		for cx in range(int(floor((center.x - r) / cs)), int(floor((center.x + r) / cs)) + 1):
			out.append(Vector2i(cx, cz))
	return out


func _all_bodies_within(tc: TreeCoverLayer, center: Vector3) -> bool:
	var r: float = tc.RING_RADIUS + 0.5
	for coord: Vector2i in tc._chunk_bodies:
		for body: StaticBody3D in (tc._chunk_bodies[coord] as Dictionary).values():
			var p: Vector3 = body.position
			if Vector2(p.x - center.x, p.z - center.z).length() > r:
				return false
	return true


func _count_physics_bodies(root: Node) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is PhysicsBody3D:
			n += 1
		for c: Node in node.get_children():
			stack.append(c)
	return n


func _finish() -> void:
	print("")
	if _failures == 0:
		print("=== TRUNK RING PASS ===")
	else:
		print("=== TRUNK RING FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
