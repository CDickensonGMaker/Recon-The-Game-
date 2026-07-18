## probe_veg_material.gd - diagnose the "tree opacity" bug. Dumps, for each veg GLB:
## how many MeshInstance3D nodes it has (TreeCoverLayer._extract_mesh takes only the FIRST -
## a multi-mesh tree would render incomplete), and every surface material's transparency mode
## + cull + alpha (alpha-blend reads see-through; solid foliage wants alpha-scissor/opaque).
extends Node

const NAMES: Array[String] = [
	"broadleaf_a", "broadleaf_b", "banana_a", "bamboo_a", "jungle_palm_a1", "bush_a", "fern_a",
]
const DIRS := ["res://assets/world/vegetation/", "res://assets/world/vegetation/cards/"]


func _ready() -> void:
	for nm in NAMES:
		_dump(DIRS[0] + nm + ".glb", nm + " (solid)")
	_dump(DIRS[1] + "broadleaf_a_card.glb", "broadleaf_a_card (card)")
	_dump(DIRS[1] + "bamboo_a_card.glb", "bamboo_a_card (card)")
	get_tree().quit(0)


func _dump(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		print("  %s: MISSING %s" % [label, path])
		return
	var root: Node = (load(path) as PackedScene).instantiate()
	var meshes: Array[MeshInstance3D] = []
	_collect(root, meshes)
	print("=== %s: %d MeshInstance3D node(s) ===" % [label, meshes.size()])
	for mi in meshes:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var m: Material = mi.get_active_material(si)
			var mode: String = "?"
			var cull: String = "?"
			var scissor: float = -1.0
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				mode = ["DISABLED(opaque)", "ALPHA(blend)", "ALPHA_SCISSOR", "ALPHA_HASH", "DEPTH_PRE"][sm.transparency] if sm.transparency < 5 else str(sm.transparency)
				cull = ["BACK", "FRONT", "DISABLED"][sm.cull_mode] if sm.cull_mode < 3 else str(sm.cull_mode)
				scissor = sm.alpha_scissor_threshold
			print("    [%s.surf%d] mat=%s transparency=%s cull=%s scissor=%.2f" % [
				mi.name, si, m.get_class() if m != null else "null", mode, cull, scissor])
	root.free()


func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect(c, out)
