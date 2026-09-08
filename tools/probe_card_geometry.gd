## probe_card_geometry.gd - are the foliage impostor cards single planes (which would
## VANISH under back-face culling) or double-modelled / crossed quads (which cull free)?
## ADR-026 Part A.2 permits cull_disabled only where a single plane genuinely needs both faces.
##   godot --headless --path . -s res://tools/probe_card_geometry.gd
extends SceneTree

const CARD_DIR := "res://assets/world/vegetation/cards/"


func _initialize() -> void:
	var d := DirAccess.open(CARD_DIR)
	print("\n=== FOLIAGE CARD GEOMETRY (verts / tris / distinct facing normals) ===")
	var single_plane: int = 0
	var multi: int = 0
	for f: String in d.get_files():
		if f.get_extension().to_lower() != "glb":
			continue
		var packed: PackedScene = load(CARD_DIR + f) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		var mi: MeshInstance3D = _first(root)
		if mi != null and mi.mesh != null:
			var arrays: Array = mi.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var dirs: Array[Vector3] = []
			for n: Vector3 in norms:
				var dup: bool = false
				for k: Vector3 in dirs:
					if k.dot(n) > 0.99:
						dup = true
						break
				if not dup:
					dirs.append(n)
			var tris: int = (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
			var opposed: bool = false
			for a: Vector3 in dirs:
				for b: Vector3 in dirs:
					if a.dot(b) < -0.9:
						opposed = true
			if dirs.size() <= 1:
				single_plane += 1
			else:
				multi += 1
			print("  %-34s verts=%4d tris=%4d facings=%d back_to_back=%s"
				% [f, verts.size(), tris, dirs.size(), str(opposed)])
		root.queue_free()
	print("\n  single-facing (back-cull would HIDE them): %d" % single_plane)
	print("  multi-facing  (back-cull is free):          %d" % multi)
	quit(0)


func _first(node: Node) -> MeshInstance3D:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		return mi
	for c: Node in node.get_children():
		var r: MeshInstance3D = _first(c)
		if r != null:
			return r
	return null
