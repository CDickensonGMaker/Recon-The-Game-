## probe_terrain_collision.gd - THE HEIGHTFIELD SHIPS ONLY IF THE GROUND DID NOT MOVE.
##
## terrain_chunk.create_raycast_collision used to build a trimesh over 32,768 triangles per
## chunk; it now builds a HeightMapShape3D over the same 129x129 samples. That shape is what
## bullets, boots and every terrain raycast in the game hit, so this probe rebuilds the OLD
## shape alongside the new one in the REAL world and fires the same rays at both.
##
## Three questions, each answered against the shape it replaces rather than against a claim:
##   1. straight down - does the ground surface sit at the same height?
##   2. near-horizontal - does a bullet into a slope hit the same point? A grazing ray is
##      where a triangulation difference would show up worst.
##   3. after a CRATER - does the answer survive an edited heightmap and a chunk rebuild?
## Build cost for both shapes is reported on the same chunk, in the same run.
##
##   godot --headless --path . res://tools/probe_terrain_collision.tscn
extends Node

const SEED: int = 47225
const REF_LAYER: int = 1 << 19   ## a layer nothing in the game uses, for the reference shape
## The chunk collider is moved onto its own layer for the duration of the comparison. Layer 1
## is the WORLD layer and a blast puts broken trunks and lying logs on it - a downward ray
## near ground zero hit a felled log 1.47m up and read as a collision-shape disagreement.
## Isolating the chunk is the difference between measuring the shape and measuring the jungle.
const TERRAIN_PROBE_LAYER: int = 1 << 18
const DROPS: int = 3000
const GRAZERS: int = 600
const TOL_M: float = 0.01

var _fails: int = 0
var _world: GameWorld = null
var _ref_body: StaticBody3D = null


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s -- %s" % ["PASS" if ok else "FAIL", label, detail])


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== TERRAIN COLLISION: heightfield vs the trimesh it replaces ===\n")

	_world = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	_world.mission_seed = SEED
	_world.spawn_player_on_ready = false
	add_child(_world)
	var spins: int = 0
	while not _world.is_world_ready and spins < 600:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not _world.is_world_ready:
		print("  [FAIL] world never became ready")
		get_tree().quit(1)
		return

	var tm: Node = _world.terrain_manager
	var coord := Vector2i(2, 2)
	var chunk: Node3D = (tm.get("chunks") as Dictionary).get(coord, null)
	_check("the chunk under test exists and carries a collider",
		chunk != null and chunk.get("collision_body") != null, "chunk %s" % coord)
	if chunk == null:
		get_tree().quit(1)
		return
	var shipped: Shape3D = _shape_of(chunk)
	_check("the shipped collider IS a heightfield now", shipped is HeightMapShape3D,
		shipped.get_class() if shipped != null else "none")

	await _compare(chunk, coord, tm, "PRISTINE")

	# ---- and again after a real shell has edited the heightmap under it ----
	var centre := Vector3((coord.x + 0.5) * 256.0, 0.0, (coord.y + 0.5) * 256.0)
	DamageSystem.apply_damage(centre, DamageSystem.DamageType.LARGE_EXPLOSION, 1.0)
	for _i in 30:
		await get_tree().process_frame
	var chunk2: Node3D = (tm.get("chunks") as Dictionary).get(coord, null)
	_check("the chunk was rebuilt by the shell", chunk2 != null and chunk2 != chunk,
		"rebuilt: %s" % (chunk2 != chunk))
	if chunk2 != null:
		await _compare(chunk2, coord, tm, "CRATERED")

	print("")
	if _fails == 0:
		print("*** THE GROUND DID NOT MOVE. ***")
	else:
		print("*** %d FAILURE(S) - do NOT ship this shape ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _shape_of(chunk: Node3D) -> Shape3D:
	var body: Node = chunk.get("collision_body")
	if body == null or body.get_child_count() == 0:
		return null
	return (body.get_child(0) as CollisionShape3D).shape


func _compare(chunk: Node3D, coord: Vector2i, tm: Node, tag: String) -> void:
	print("\n  ---- %s ----" % tag)
	# Rebuild the OLD shape from the very mesh the chunk is rendering.
	var mi: MeshInstance3D = chunk.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null or mi.mesh == null:
		_check("%s: the chunk has a mesh to build the reference from" % tag, false, "no mesh")
		return
	var t0: int = Time.get_ticks_usec()
	var tri: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape()
	var tri_us: int = Time.get_ticks_usec() - t0
	var samples: PackedFloat32Array = chunk.get("_height_samples")
	var side: int = int(chunk.get("grid_resolution")) + 1
	var t1: int = Time.get_ticks_usec()
	var hf := HeightMapShape3D.new()
	hf.map_width = side
	hf.map_depth = side
	hf.map_data = samples
	var hf_us: int = Time.get_ticks_usec() - t1
	@warning_ignore("integer_division")
	var tri_count: int = tri.get_faces().size() / 3
	print("  shape build on this chunk: trimesh %.2f ms (%d tris) vs heightfield %.2f ms (%d samples)"
		% [float(tri_us) / 1000.0, tri_count, float(hf_us) / 1000.0, samples.size()])

	var body: StaticBody3D = chunk.get("collision_body") as StaticBody3D
	if body != null:
		body.collision_layer = TERRAIN_PROBE_LAYER

	if _ref_body != null:
		# REMOVE, do not merely queue_free: a queued node is still in the physics space for
		# the frames that follow, so the PRISTINE reference answered CRATERED rays and read
		# as a 1.47m "disagreement" that was really the crater it had never been dug.
		remove_child(_ref_body)
		_ref_body.queue_free()
		_ref_body = null
		await get_tree().physics_frame
	_ref_body = StaticBody3D.new()
	_ref_body.collision_layer = REF_LAYER
	_ref_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = tri
	_ref_body.add_child(cs)
	add_child(_ref_body)
	_ref_body.global_position = Vector3(coord.x * 256.0, 0.0, coord.y * 256.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space: PhysicsDirectSpaceState3D = _world.get_viewport().world_3d.direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var ox: float = coord.x * 256.0
	var oz: float = coord.y * 256.0

	# 1. straight down
	var worst: float = 0.0
	var sum: float = 0.0
	var n: int = 0
	var missed: int = 0
	var bilinear_gap: float = 0.0
	for _i in DROPS:
		var wx: float = ox + rng.randf_range(2.0, 254.0)
		var wz: float = oz + rng.randf_range(2.0, 254.0)
		var a: Variant = _cast(space, Vector3(wx, 900.0, wz), Vector3(wx, -400.0, wz), TERRAIN_PROBE_LAYER)
		var b: Variant = _cast(space, Vector3(wx, 900.0, wz), Vector3(wx, -400.0, wz), REF_LAYER)
		if a == null or b == null:
			missed += 1
			continue
		var d: float = absf((a as Vector3).y - (b as Vector3).y)
		sum += d
		n += 1
		worst = maxf(worst, d)
		bilinear_gap = maxf(bilinear_gap,
			absf((b as Vector3).y - float(tm.call("get_height_at", Vector3(wx, 0.0, wz)))))
	_check("%s: every downward ray hits both shapes" % tag, missed == 0,
		"%d of %d missed" % [missed, DROPS])
	if n > 0:
		print("  down: mean %.5f m, worst %.5f m over %d rays" % [sum / float(n), worst, n])
	_check("%s: ground height unchanged (under %.0f cm)" % [tag, TOL_M * 100.0],
		n > 0 and worst < TOL_M, "worst %.5f m" % worst)

	# 2. grazing bullet rays into the slope - a fired round, not a plumb line
	var gworst: float = 0.0
	var gn: int = 0
	var gmiss: int = 0
	for _i in GRAZERS:
		var wx: float = ox + rng.randf_range(20.0, 236.0)
		var wz: float = oz + rng.randf_range(20.0, 236.0)
		var h: float = float(tm.call("get_height_at", Vector3(wx, 0.0, wz)))
		var yaw: float = rng.randf() * TAU
		var from := Vector3(wx, h + 1.6, wz)
		var to: Vector3 = from + Vector3(cos(yaw), -0.12, sin(yaw)) * 120.0
		var a: Variant = _cast(space, from, to, TERRAIN_PROBE_LAYER)
		var b: Variant = _cast(space, from, to, REF_LAYER)
		if a == null or b == null:
			if (a == null) != (b == null):
				gmiss += 1
			continue
		gworst = maxf(gworst, (a as Vector3).distance_to(b as Vector3))
		gn += 1
	_check("%s: no bullet hits one shape and misses the other" % tag, gmiss == 0,
		"%d disagreement(s) of %d" % [gmiss, GRAZERS])
	_check("%s: grazing impact points land together (under 10 cm)" % tag,
		gn > 0 and gworst < 0.10, "worst separation %.4f m over %d rays" % [gworst, gn])
	if body != null:
		body.collision_layer = 1
	print("  (context, NOT a regression: the collider and the bilinear get_height_at oracle differ by up to %.3f m here - they always have, because a triangulated cell is not a bilinear patch.)" % bilinear_gap)


func _cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = mask
	var r: Dictionary = space.intersect_ray(q)
	if r.is_empty():
		return null
	return r["position"] as Vector3
