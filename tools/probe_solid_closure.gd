## probe_solid_closure.gd - which near-ring vegetation solids are CLOSED shells (back faces
## can never be seen, so back-face culling is free) and which are open leaf/frond planes
## (culling would hole them). ADR-026 Part A.2 permits cull_disabled only for the latter.
## Closure test: every triangle edge shared by exactly two triangles.
##   godot --headless --path . -s res://tools/probe_solid_closure.gd
extends SceneTree

const SOLID_DIR := "res://assets/world/vegetation/"


func _initialize() -> void:
	var d := DirAccess.open(SOLID_DIR)
	var closed_names: Array[String] = []
	var open_names: Array[String] = []
	print("\n=== NEAR-RING SOLID CLOSURE ===")
	for f: String in d.get_files():
		if f.get_extension().to_lower() != "glb":
			continue
		var packed: PackedScene = load(SOLID_DIR + f) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		var meshes: Array[MeshInstance3D] = []
		_collect(root, meshes)
		var all_closed: bool = meshes.size() > 0
		for mi: MeshInstance3D in meshes:
			for s in mi.mesh.get_surface_count():
				if not _closed(mi.mesh, s):
					all_closed = false
		if all_closed:
			closed_names.append(f.get_basename())
		else:
			open_names.append(f.get_basename())
		root.queue_free()
	print("  CLOSED (back-cull is free): %d" % closed_names.size())
	print("    %s" % ", ".join(closed_names))
	print("  OPEN   (must stay cull_disabled): %d" % open_names.size())
	print("    %s" % ", ".join(open_names))
	quit(0)


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(mi)
	for c: Node in node.get_children():
		_collect(c, out)


func _closed(mesh: Mesh, surf: int) -> bool:
	var arrays: Array = mesh.surface_get_arrays(surf)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return false
	## Weld by position: GLB splits vertices on UV/normal seams, so raw indices
	## would report every seam as a hole.
	var weld: Dictionary = {}
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(verts.size())
	for i in verts.size():
		var key: Vector3 = verts[i].snappedf(0.0005)
		if not weld.has(key):
			weld[key] = weld.size()
		remap[i] = int(weld[key])
	var edges: Dictionary = {}
	var t: int = 0
	while t < idx.size():
		var a: int = remap[idx[t]]
		var b: int = remap[idx[t + 1]]
		var c: int = remap[idx[t + 2]]
		for e: Array in [[a, b], [b, c], [c, a]]:
			var k: Vector2i = Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
			edges[k] = int(edges.get(k, 0)) + 1
		t += 3
	for k: Vector2i in edges:
		if int(edges[k]) != 2:
			return false
	return true
