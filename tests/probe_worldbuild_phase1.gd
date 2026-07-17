## probe_worldbuild_phase1.gd - Ratcheting verify for the world-build unification, Phase 1.
## Proves: (1) same seed -> byte-identical placement; (2) the seed is actually folded
## (different seed -> different world); (3) ADR-013 residency - chunk count invariant across
## a camera traverse; (4) clutter is resident - no _process re-scatter, bucket count stable
## as the camera moves. Reports node/instance counts (the perf architect's ask).
extends Node

const SEED_A: int = 47225
const SEED_B: int = 8080


func _ready() -> void:
	var a1: Dictionary = await _build(SEED_A)
	var a2: Dictionary = await _build(SEED_A)
	var b: Dictionary = await _build(SEED_B)

	print("=== WORLDBUILD PHASE-1 VERIFY ===")
	print("seedA #1: veg_hash=%d mmi=%d inst=%d chunks=%d->%d clutter_buckets=%d->%d proc=%s build_ms=%d" % [
		a1.hash, a1.mmi, a1.inst, a1.chunks, a1.chunks_after, a1.buckets, a1.buckets_after, str(a1.has_proc), a1.build_ms])
	print("seedA #2: veg_hash=%d mmi=%d inst=%d chunks=%d->%d clutter_buckets=%d->%d" % [
		a2.hash, a2.mmi, a2.inst, a2.chunks, a2.chunks_after, a2.buckets, a2.buckets_after])
	print("seedB   : veg_hash=%d mmi=%d inst=%d chunks=%d" % [b.hash, b.mmi, b.inst, b.chunks])

	var fails: int = 0

	if a1.hash != a2.hash:
		print("FAIL[determinism]: same seed produced different placement (%d vs %d)" % [a1.hash, a2.hash]); fails += 1
	else:
		print("PASS[determinism]: same seed -> byte-identical placement")

	if a1.hash == b.hash:
		print("FAIL[seed-fold]: different seeds produced identical placement - seed not folded"); fails += 1
	else:
		print("PASS[seed-fold]: different seed -> different world (seed is folded)")

	if a1.chunks != 25:
		print("FAIL[residency]: expected 25 resident chunks, got %d" % a1.chunks); fails += 1
	elif a1.chunks_after != a1.chunks:
		print("FAIL[residency]: chunk count changed across camera traverse (%d -> %d)" % [a1.chunks, a1.chunks_after]); fails += 1
	else:
		print("PASS[residency]: chunk count invariant across traverse (%d)" % a1.chunks)

	if a1.has_proc:
		print("FAIL[clutter]: GroundClutter still defines _process (re-scatter path exists)"); fails += 1
	elif a1.buckets_after != a1.buckets:
		print("FAIL[clutter]: clutter bucket count changed on camera move (%d -> %d)" % [a1.buckets, a1.buckets_after]); fails += 1
	elif a1.buckets == 0:
		print("FAIL[clutter]: no clutter buckets built"); fails += 1
	else:
		print("PASS[clutter]: resident, no _process re-scatter, %d buckets stable across move" % a1.buckets)

	print("")
	if fails == 0:
		print("=== WORLDBUILD PHASE-1 VERIFY PASS ===")
		get_tree().quit(0)
	else:
		print("=== WORLDBUILD PHASE-1 VERIFY FAIL (%d) ===" % fails)
		get_tree().quit(1)


func _build(seed_val: int) -> Dictionary:
	var world: GameWorld = load("res://scenes/levels/game_world.tscn").instantiate()
	world.mission_seed = seed_val
	world.spawn_player_on_ready = false
	var t0: int = Time.get_ticks_msec()
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	var build_ms: int = Time.get_ticks_msec() - t0

	var acc: Array = [0, 0, 0]
	_accumulate(world, acc)
	var mmi: int = acc[0]
	var inst: int = acc[1]
	var vhash: int = acc[2]

	var chunks: int = world.terrain_manager.get_loaded_chunk_count()
	var clutter: Node = _find_clutter(world)
	var buckets: int = clutter.get_child_count() if clutter != null else -1
	var has_proc: bool = clutter != null and clutter.has_method("_process")

	# Camera traverse: wire a moving camera and step across the 1280m AO. With the ADR-013
	# guard the resident world must not stream (chunk count fixed, clutter buckets fixed).
	var cam := Camera3D.new()
	world.add_child(cam)
	world.terrain_manager.set_camera(cam)
	var n: int = 8
	for i in range(n + 1):
		var d: float = 80.0 + (world.map_size - 160.0) * float(i) / float(n)
		cam.global_position = Vector3(d, 60.0, d)
		await get_tree().process_frame
		await get_tree().process_frame
	var chunks_after: int = world.terrain_manager.get_loaded_chunk_count()
	var buckets_after: int = clutter.get_child_count() if clutter != null else -1

	world.queue_free()
	await get_tree().process_frame
	return {
		"hash": vhash, "mmi": mmi, "inst": inst, "chunks": chunks, "chunks_after": chunks_after,
		"buckets": buckets, "buckets_after": buckets_after, "has_proc": has_proc, "build_ms": build_ms,
	}


## Order-independent placement fingerprint: sum each MultiMesh buffer hash. Identical worlds
## sum identically; a single moved instance changes the sum.
func _accumulate(node: Node, acc: Array) -> void:
	var mmi := node as MultiMeshInstance3D
	if mmi != null and mmi.multimesh != null:
		acc[0] += 1
		acc[1] += mmi.multimesh.instance_count
		acc[2] = (acc[2] + hash(mmi.multimesh.buffer)) % 0x7FFFFFFF
	for c in node.get_children():
		_accumulate(c, acc)


func _find_clutter(node: Node) -> Node:
	if node is GroundClutter:
		return node
	for c in node.get_children():
		var found: Node = _find_clutter(c)
		if found != null:
			return found
	return null
