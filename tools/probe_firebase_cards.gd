## probe_firebase_cards.gd - are the ~360 vegetation CARDS still baked into the shipped
## firebase GLB? tree_cover_layer's card ring is retired in code, but an art bake is not
## code and does not go away with it (CALEB_TODO 2026-09-08: "half the job").
## Same facing-count test the canopy audit uses: a card faces 1-2 directions, a model 20+.
##   godot --headless --path . -s res://tools/probe_firebase_cards.gd
extends SceneTree

const FSB := "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
## Sits in a 128..2392 empty gap measured 2026-09-09. Not delicate.
const CARD_TRI_MAX: int = 500


func _initialize() -> void:
	var root: Node = (load(FSB) as PackedScene).instantiate()
	var flat: int = 0
	var solid: int = 0
	var flat_names: Array[String] = []
	var solid_names: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).begins_with("fb_veg_"):
			continue
		# MERGED objects, not single instances: scatter_veg fuses every copy of a species
		# into ONE mesh spanning the treeline ring. So the decisive number is TRIS PER
		# FACING - a merged pile of real plants carries thousands of triangles across
		# dozens of facings; a merged pile of quads carries a handful of each.
		var f: int = _facings(mi.mesh)
		var t: int = _tris(mi.mesh)
		# TRIS is the gate, not facings. Facing count is the right instrument for a SINGLE
		# mesh and the wrong one here: a merged pile of ~17 quads at assorted yaws scores
		# 8-15 facings, which straddles the single-mesh threshold and let three card groups
		# through on the first pass. Triangle count does not straddle anything - the merged
		# card groups are 36-128 tris and the merged real-geometry groups are 2,392-12,840.
		if t < CARD_TRI_MAX:
			flat += 1
			flat_names.append("%-34s %5d tris / %2d facings" % [mi.name, t, f])
		else:
			solid += 1
			solid_names.append("%-34s %5d tris / %2d facings" % [mi.name, t, f])
	print("[FBCARD] fb_veg_ objects: %d flat (card-like), %d volumetric" % [flat, solid])
	print("[FBCARD] --- card-like ---")
	for s: String in flat_names:
		print("[FBCARD]   %s" % s)
	print("[FBCARD] --- volumetric ---")
	for s: String in solid_names:
		print("[FBCARD]   %s" % s)
	root.free()
	quit(0)


func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		n += (idx.size() / 3) if idx.size() > 0 else (v.size() / 3)
	return n


func _facings(mesh: Mesh) -> int:
	var dirs: Array[Vector3] = []
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var indexed: bool = idx.size() > 0
		var tris: int = (idx.size() / 3) if indexed else (v.size() / 3)
		for t in tris:
			var a: Vector3 = v[idx[t * 3]] if indexed else v[t * 3]
			var b: Vector3 = v[idx[t * 3 + 1]] if indexed else v[t * 3 + 1]
			var c: Vector3 = v[idx[t * 3 + 2]] if indexed else v[t * 3 + 2]
			var cr: Vector3 = (b - a).cross(c - a)
			if cr.length() < 0.0000001:
				continue
			var nn: Vector3 = cr.normalized()
			var dup: bool = false
			for k: Vector3 in dirs:
				if absf(k.dot(nn)) > 0.985:
					dup = true
					break
			if not dup:
				dirs.append(nn)
			if dirs.size() > 40:
				return dirs.size()
	return dirs.size()
