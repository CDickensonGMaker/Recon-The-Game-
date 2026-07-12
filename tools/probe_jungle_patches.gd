## probe_jungle_patches.gd - does the patch layer actually load and lay tiles?
## Run: godot --headless -s tools/probe_jungle_patches.gd
extends SceneTree

const JunglePatchLayerScript := preload("res://terrain/vegetation/jungle_patch_layer.gd")

## Stand-in heightmap: flat ground, so every cell is placeable.
class FakeHeightmap:
	func sample_world(_x: float, _z: float) -> float:
		return 0.0
	func get_normal_world(_x: float, _z: float) -> Vector3:
		return Vector3.UP


## A cliff - nothing may be planted on it.
class SteepHeightmap:
	func sample_world(_x: float, _z: float) -> float:
		return 0.0
	func get_normal_world(_x: float, _z: float) -> Vector3:
		return Vector3(0.9, 0.44, 0.0).normalized()   # ~64 degrees


func _count_nodes(layer: JunglePatchLayer, coord: Vector2i) -> int:
	return (layer._chunk_nodes.get(coord, []) as Array).size()


func _count_tiles(layer: JunglePatchLayer, coord: Vector2i) -> int:
	var n := 0
	for mmi: MultiMeshInstance3D in (layer._chunk_nodes.get(coord, []) as Array):
		n += mmi.multimesh.instance_count
	return n


func _init() -> void:
	var fails := 0
	var layer: JunglePatchLayer = JunglePatchLayerScript.new()
	root.add_child(layer)
	layer._load_patches()

	# 1. meshes loaded
	print("[PROBE] patches loaded : %d" % layer._mesh.size())
	print("[PROBE] density classes: %s" % [layer._by_density.keys()])
	if layer._mesh.size() < 15:
		printerr("FAIL: expected >=15 patch meshes, got %d" % layer._mesh.size())
		fails += 1
	for want: String in ["open", "light", "medium", "dense", "wall"]:
		if not layer._by_density.has(want):
			printerr("FAIL: no patches in density class '%s'" % want)
			fails += 1

	# 2. meshes carry real geometry + the sway vertex colours
	var total_surfaces := 0
	for nm: String in layer._mesh:
		var m: Mesh = layer._mesh[nm]
		total_surfaces += m.get_surface_count()
		if m.get_surface_count() == 0:
			printerr("FAIL: %s has no surfaces" % nm)
			fails += 1
		var arrays := m.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_COLOR] == null:
			printerr("FAIL: %s surface 0 has no COLOR (sway mask missing!)" % nm)
			fails += 1
	print("[PROBE] total surfaces  : %d" % total_surfaces)

	# 3. lay a chunk of HEAVY_JUNGLE and see tiles come out
	var bundles := 32
	var bundle_m := 8.0
	var chunk_size := bundles * bundle_m         # 256m
	var terrain := PackedByteArray()
	terrain.resize(bundles * bundles)
	terrain.fill(JunglePatchLayer.T_HEAVY_JUNGLE)
	layer.generate_for_chunk(Vector2i(0, 0), terrain, bundles, bundle_m,
			FakeHeightmap.new(), chunk_size)

	var cells := int(chunk_size / layer.tile_meters)
	var mmis: int = _count_nodes(layer, Vector2i(0, 0))
	var instances: int = _count_tiles(layer, Vector2i(0, 0))
	print("[PROBE] heavy chunk     : %d MultiMeshInstances, %d tiles (grid %dx%d)"
			% [mmis, instances, cells, cells])
	if instances < int(cells * cells * 0.6):
		printerr("FAIL: only %d tiles placed on a full HEAVY_JUNGLE chunk" % instances)
		fails += 1

	# 4. CLEAR terrain must stay bare (count THIS chunk's bookkeeping - queue_free
	#    is deferred, so counting live children would still see the old chunk)
	var bare := PackedByteArray()
	bare.resize(bundles * bundles)
	bare.fill(JunglePatchLayer.T_CLEAR)
	layer.generate_for_chunk(Vector2i(1, 0), bare, bundles, bundle_m,
			FakeHeightmap.new(), chunk_size)
	var bare_inst: int = _count_tiles(layer, Vector2i(1, 0))
	print("[PROBE] CLEAR chunk     : %d tiles (want 0)" % bare_inst)
	if bare_inst != 0:
		printerr("FAIL: CLEAR terrain grew %d patches" % bare_inst)
		fails += 1

	# 5. steep ground must be skipped
	var steep := PackedByteArray()
	steep.resize(bundles * bundles)
	steep.fill(JunglePatchLayer.T_HEAVY_JUNGLE)
	layer.generate_for_chunk(Vector2i(2, 0), steep, bundles, bundle_m,
			SteepHeightmap.new(), chunk_size)
	var steep_inst: int = _count_tiles(layer, Vector2i(2, 0))
	print("[PROBE] steep chunk     : %d tiles (want 0)" % steep_inst)
	if steep_inst != 0:
		printerr("FAIL: %d patches planted on a cliff" % steep_inst)
		fails += 1

	# 6. DRAW BUDGET: what does a player standing in solid jungle actually pay?
	#    Buckets outside view_distance never render, so count only those whose
	#    centre is within range of a camera in the middle of the chunk.
	var cam := Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)
	var near_tris := 0
	var far_tris := 0
	var drawn_buckets := 0
	for mmi: MultiMeshInstance3D in (layer._chunk_nodes.get(Vector2i(0, 0), []) as Array):
		var d := mmi.position.distance_to(cam)
		var b: float = mmi.visibility_range_begin
		var e: float = mmi.visibility_range_end
		if d < b - layer.view_fade_margin or d > e + layer.view_fade_margin:
			continue                       # this bucket never renders from here
		var tris: int = _mesh_tris(mmi.multimesh.mesh) * mmi.multimesh.instance_count
		drawn_buckets += 1
		if b <= 0.0:
			near_tris += tris
		else:
			far_tris += tris
	var drawn_tris := near_tris + far_tris
	print("[PROBE] DRAWN near(<%dm): %.2fM tris" % [int(layer.near_distance), near_tris / 1e6])
	print("[PROBE] DRAWN far (<%dm): %.2fM tris" % [int(layer.view_distance), far_tris / 1e6])
	print("[PROBE] DRAWN total     : %.2fM tris in %d buckets" % [drawn_tris / 1e6, drawn_buckets])
	if drawn_tris > 2_500_000:
		printerr("FAIL: %.2fM tris on screen - past the GPU budget" % (drawn_tris / 1e6))
		fails += 1

	# 7. clear really clears
	layer.clear_chunk(Vector2i(0, 0))
	if layer._chunk_nodes.has(Vector2i(0, 0)):
		printerr("FAIL: clear_chunk left bookkeeping behind")
		fails += 1

	if fails == 0:
		print("\n[PROBE] JUNGLE PATCHES: ALL GREEN")
	else:
		printerr("\n[PROBE] JUNGLE PATCHES: %d FAILURE(S)" % fails)
	quit(fails)


func _mesh_tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			t += idx.size() / 3
		else:
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			t += v.size() / 3
	return t
