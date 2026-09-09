## probe_unnamed_colliders.gd - WHAT are the colliders whose name carries no information?
##
##   godot --headless --path . -s res://tools/probe_unnamed_colliders.gd
##
## ADR-042 at its purest. The ballistics census reports 128 colliders literally named
## `StaticBody3D` plus an auto-name bucket: a prefix contract cannot judge them, a re-export
## cannot be diffed against them, and nobody had looked at what they actually ARE. They do not
## appear under that name in the GLB - Godot MINTS them at import, one per `-colonly` node it
## converts - so the question can only be asked of the imported scene.
extends SceneTree

const FSB := "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"


func _initialize() -> void:
	var root: Node = (load(FSB) as PackedScene).instantiate()
	var anon: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is CollisionObject3D:
			var nm: String = String(n.name)
			if nm.begins_with("@") or nm == "StaticBody3D" or nm.begins_with("StaticBody3D"):
				anon.append(n)
	print("[ANON] %d collider(s) whose NAME carries no information" % anon.size())
	var by_parent: Dictionary = {}
	for n in anon:
		var p: Node = n.get_parent()
		var pname: String = String(p.name) if p != null else "<root>"
		var stem: String = pname
		while true:
			var cut: int = stem.rfind("_")
			if cut <= 0 or not stem.substr(cut + 1).is_valid_int():
				break
			stem = stem.substr(0, cut)
		by_parent[stem] = int(by_parent.get(stem, 0)) + 1
	var keys: Array = by_parent.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(by_parent[a]) > int(by_parent[b]))
	for k in keys:
		print("   parent %-40s x%d" % [k, int(by_parent[k])])
	quit(0)
