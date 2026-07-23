extends SceneTree
## Model-space check: what geometry exists under the raised gate-area meshes?

func _init() -> void:
	var scene: PackedScene = load("res://assets/world/building models/structures/firebase/fsb_main.glb")
	var root := scene.instantiate() as Node3D
	var meshes: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var xf := Transform3D.IDENTITY
			var p: Node = mi
			while p != null and p != root:
				if p is Node3D:
					xf = (p as Node3D).transform * xf
				p = p.get_parent()
			meshes.append([mi.name, xf * mi.mesh.get_aabb()])
	# The gate metrics give gate model-space position; the +13m mesh sat ~5m from
	# the gate. Find every mesh whose XZ AABB overlaps a 16m disc there.
	var probe := Vector2(1110.0 - 997.0, 538.0 - 687.8)   # world -> model space
	print("[GATE-TOWER] probing model-space %.1f, %.1f" % [probe.x, probe.y])
	for m in meshes:
		var b: AABB = m[1]
		var cx := Vector2(b.get_center().x, b.get_center().z)
		if cx.distance_to(probe) < 16.0:
			print("[GATE-TOWER] %-28s y %.2f..%.2f  xz %.0f,%.0f size %.1fx%.1f" % [
				str(m[0]), b.position.y, b.end.y, cx.x, cx.y, b.size.x, b.size.z])
	root.free()
	quit(0)
