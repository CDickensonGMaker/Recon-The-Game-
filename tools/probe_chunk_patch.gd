## probe_chunk_patch.gd - A PATCHED CHUNK MUST BE THE SAME CHUNK.
##
## A 5 m crater used to destroy and rebuild a whole 256 m chunk: 64x64 quads re-derived,
## 49,152 vertices re-emitted, the node freed and a new Jolt body swapped in. terrain_manager
## now patches the touched samples in place. The only question that matters is whether the
## patched chunk is IDENTICAL to the one the full rebuild would have produced - a fast wrong
## chunk is worse than a slow right one, because it is wrong in ballistics.
##
## The design: fire two shells. The first arms the patch cache and takes the full path; the
## second patches. Then force a full rebuild of that same chunk and compare, vertex for vertex,
## sample for sample, ray for ray.
##
## CONTROL, and the probe fails rather than passes without it: `mesh.patch_quads` must have
## actually run. Otherwise "the two agree" would mean "the patch never happened".
##
##   godot --headless --path . res://tools/probe_chunk_patch.tscn
extends Node

const SEED: int = 47225
const COORD := Vector2i(2, 2)
const RAYS: int = 2000
const PROBE_LAYER: int = 1 << 18

var _fails: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s -- %s" % ["PASS" if ok else "FAIL", label, detail])


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== CHUNK PATCH: is the patched chunk the same chunk? ===\n")

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = SEED
	world.spawn_player_on_ready = false
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 600:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  [FAIL] world never became ready")
		get_tree().quit(1)
		return

	var tm: Node = world.terrain_manager
	var base := Vector3((COORD.x + 0.5) * 256.0, 0.0, (COORD.y + 0.5) * 256.0)

	# Shell 1: full path, arms the patch cache.
	DamageSystem.apply_damage(base, DamageSystem.DamageType.LARGE_EXPLOSION, 1.0)
	for _i in 30:
		await get_tree().process_frame

	# Shell 2: this is the one that must patch.
	StallLedger.enable()
	StallLedger.reset_window()
	DamageSystem.apply_damage(base + Vector3(24.0, 0.0, 17.0),
		DamageSystem.DamageType.LARGE_EXPLOSION, 1.0)
	for _i in 30:
		await get_tree().process_frame

	var patched_quads: int = StallLedger.count("mesh.patch_quads")
	var full_builds: int = StallLedger.count("mesh.fanout")
	_check("the second shell PATCHED rather than rebuilt (the control)",
		patched_quads > 0, "mesh.patch_quads x%d, full mesh.fanout x%d"
			% [patched_quads, full_builds])
	var refreshes: int = StallLedger.count("veg.canopy_refresh")
	var registers: int = StallLedger.count("mmi.register")
	# mmi.register is NOT expected to be zero: the same blast fells trees, and
	# TreeCoverLayer._flush_regen legitimately rebuilds a felled chunk one per frame. The
	# control is that the crater path took the refresh at all; the equivalence below is made
	# airtight by re-running the refresh as the LAST writer before the comparison.
	_check("the crater path RE-SEATED the canopy (the second control)", refreshes > 0,
		"veg.canopy_refresh x%d (full mmi.register x%d, the tree-break flush)"
			% [refreshes, registers])

	var chunk: Node3D = (tm.get("chunks") as Dictionary).get(COORD, null)
	if chunk == null:
		print("  [FAIL] chunk vanished")
		get_tree().quit(1)
		return
	var patched_v: PackedVector3Array = _verts_of(chunk)
	var patched_h: PackedFloat32Array = (chunk.get("_height_samples") as PackedFloat32Array).duplicate()
	var patched_rays: PackedFloat32Array = await _sample_ground(world, chunk)
	var veg: Node = world.vegetation_manager
	var tc: Node = veg.get_node_or_null("TreeCoverLayer")
	var scat: Array = (tc.get("_chunk_scatter") as Dictionary).get(COORD, []) as Array
	var accepted: bool = bool(tc.call("refresh_chunk_transforms", COORD, scat))
	_check("the refresh accepts this chunk, so it is the last writer before the comparison",
		accepted, "refresh_chunk_transforms -> %s" % accepted)
	var patched_xf: Array = _canopy_transforms(tc)
	var patched_scatter: Array = (tc.get("_chunk_scatter") as Dictionary).get(COORD, []) as Array
	var patched_plants: int = patched_scatter.size()
	var patched_y: float = 0.0
	for e: Dictionary in patched_scatter:
		patched_y += (e["xf"] as Transform3D).origin.y

	# Now force the full rebuild the patch replaced, on the same edited heightmap.
	tm.call("_rebuild_chunk_immediate", COORD)
	for _i in 5:
		await get_tree().process_frame
	var full_chunk: Node3D = (tm.get("chunks") as Dictionary).get(COORD, null)
	var full_v: PackedVector3Array = _verts_of(full_chunk)
	var full_h: PackedFloat32Array = full_chunk.get("_height_samples")
	var full_rays: PackedFloat32Array = await _sample_ground(world, full_chunk)
	var full_xf: Array = _canopy_transforms(tc)
	var full_scatter: Array = (tc.get("_chunk_scatter") as Dictionary).get(COORD, []) as Array
	var full_y: float = 0.0
	for e: Dictionary in full_scatter:
		full_y += (e["xf"] as Transform3D).origin.y

	_check("same vertex count", patched_v.size() == full_v.size(),
		"%d vs %d" % [patched_v.size(), full_v.size()])
	var vworst: float = 0.0
	var vbad: int = 0
	for i in range(mini(patched_v.size(), full_v.size())):
		var d: float = (patched_v[i] - full_v[i]).length()
		if d > 0.0001:
			vbad += 1
		vworst = maxf(vworst, d)
	_check("EVERY vertex identical", vbad == 0,
		"%d of %d differ, worst %.6f m" % [vbad, patched_v.size(), vworst])

	var hworst: float = 0.0
	for i in range(mini(patched_h.size(), full_h.size())):
		hworst = maxf(hworst, absf(patched_h[i] - full_h[i]))
	_check("every collision sample identical", patched_h.size() == full_h.size() and hworst == 0.0,
		"%d vs %d samples, worst %.6f m" % [patched_h.size(), full_h.size(), hworst])

	var rworst: float = 0.0
	for i in range(mini(patched_rays.size(), full_rays.size())):
		rworst = maxf(rworst, absf(patched_rays[i] - full_rays[i]))
	_check("the ground answers rays identically (%d rays)" % RAYS,
		patched_rays.size() == full_rays.size() and rworst < 0.0001,
		"worst %.6f m over %d rays" % [rworst, patched_rays.size()])

	_check("the canopy holds the same plants", patched_plants == full_scatter.size(),
		"%d vs %d" % [patched_plants, full_scatter.size()])
	_check("every plant sits at the same height",
		absf(patched_y - full_y) < 0.001,
		"summed Y %.4f vs %.4f" % [patched_y, full_y])

	_check("the canopy has the same MultiMesh nodes and instance counts",
		patched_xf.size() == full_xf.size(), "%d vs %d nodes" % [patched_xf.size(), full_xf.size()])
	var xworst: float = 0.0
	var xbad: int = 0
	var xn: int = 0
	for i in range(mini(patched_xf.size(), full_xf.size())):
		var a: Array = patched_xf[i]
		var b: Array = full_xf[i]
		if a.size() != b.size():
			xbad += 1
			continue
		for j in a.size():
			var d: float = ((a[j] as Transform3D).origin - (b[j] as Transform3D).origin).length()
			xworst = maxf(xworst, d)
			xn += 1
			if d > 0.0001:
				xbad += 1
	_check("EVERY canopy instance sits where the full rebuild puts it",
		xbad == 0 and xn > 0, "%d of %d instances differ, worst %.6f m" % [xbad, xn, xworst])

	print("")
	if _fails == 0:
		print("*** THE PATCHED CHUNK IS THE SAME CHUNK. ***")
	else:
		print("*** %d FAILURE(S) - the partial update is NOT equivalent ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _verts_of(chunk: Node3D) -> PackedVector3Array:
	var mi: MeshInstance3D = chunk.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return PackedVector3Array()
	return (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()


## Ground heights straight down over the chunk, against THIS chunk's collider only.
func _sample_ground(world: GameWorld, chunk: Node3D) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var body: StaticBody3D = chunk.get("collision_body") as StaticBody3D
	if body == null:
		return out
	body.collision_layer = PROBE_LAYER
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_viewport().world_3d.direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var ox: float = COORD.x * 256.0
	var oz: float = COORD.y * 256.0
	for _i in RAYS:
		var wx: float = ox + rng.randf_range(1.0, 255.0)
		var wz: float = oz + rng.randf_range(1.0, 255.0)
		var q := PhysicsRayQueryParameters3D.create(Vector3(wx, 900.0, wz), Vector3(wx, -400.0, wz))
		q.collision_mask = PROBE_LAYER
		var r: Dictionary = space.intersect_ray(q)
		out.append((r["position"] as Vector3).y if not r.is_empty() else -9999.0)
	body.collision_layer = 1
	return out


## Every canopy instance in this chunk, in world space, node by node.
func _canopy_transforms(tc: Node) -> Array:
	var out: Array = []
	var nodes: Array = (tc.get("_chunk_nodes") as Dictionary).get(COORD, []) as Array
	for n in nodes:
		var mmi := n as MultiMeshInstance3D
		var row: Array = []
		if mmi != null and is_instance_valid(mmi) and mmi.multimesh != null:
			for i in mmi.multimesh.instance_count:
				var xf: Transform3D = mmi.multimesh.get_instance_transform(i)
				row.append(Transform3D(xf.basis, xf.origin + mmi.position))
		out.append(row)
	return out
