## dump_viewmodels.gd - probe the 7 new FP arms GLBs before wiring scenes.
## Run: godot --headless --path . --script tools/dump_viewmodels.gd
extends SceneTree


func _init() -> void:
	var names: Array[String] = ["ppsh_fp", "m60_fp", "rpg2_fp", "rpd_fp", "ithaca_fp", "m70_fp", "colt45_fp", "m16_fp"]
	for nm in names:
		var path: String = "res://assets/player/viewmodels/" + nm + ".glb"
		print("=== ", path)
		if not ResourceLoader.exists(path):
			print("  MISSING")
			continue
		var ps: PackedScene = load(path)
		if ps == null:
			print("  LOAD FAILED")
			continue
		var inst: Node = ps.instantiate()
		_dump(inst, 0)
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null:
			print("  anims=", ap.get_animation_list())
		var mp: Node3D = inst.find_child("MuzzlePoint", true, false) as Node3D
		print("  muzzle=", "yes @ " + str(mp.position) if mp != null else "NO")
		var aabb := AABB()
		var first := true
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.push_back(c)
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var a: AABB = mi.get_aabb()
			if first:
				aabb = a
				first = false
			else:
				aabb = aabb.merge(a)
		print("  mesh aabb size=", aabb.size)
		inst.free()
	quit()


func _dump(n: Node, d: int) -> void:
	if d > 2:
		return
	print("  ".repeat(d + 1), n.name, "  (", n.get_class(), ")")
	for c in n.get_children():
		_dump(c, d + 1)
