extends SceneTree
## Model-space audit: which fsb_main clusters violate the y=0 ground contract?
## A mesh is SUSPENDED if its bottom is >0.5m up with no other mesh beneath it.

func _init() -> void:
	var scene: PackedScene = load("res://assets/world/building models/structures/firebase/fsb_main.glb")
	var root := scene.instantiate() as Node3D
	var boxes: Array = []
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
			boxes.append([mi.name, xf * mi.mesh.get_aabb()])
	var hist := {"0-0.3": 0, "0.3-1": 0, "1-2": 0, "2-4": 0, "4+": 0}
	var suspended: Array = []
	for m in boxes:
		var b: AABB = m[1]
		var bot: float = b.position.y
		if bot < 0.3: hist["0-0.3"] += 1
		elif bot < 1.0: hist["0.3-1"] += 1
		elif bot < 2.0: hist["1-2"] += 1
		elif bot < 4.0: hist["2-4"] += 1
		else: hist["4+"] += 1
		if bot <= 0.5:
			continue
		# supported if any other mesh occupies the space below it (XZ overlap,
		# top >= bottom-0.6, bottom below it)
		var supported := false
		var c2 := Vector2(b.get_center().x, b.get_center().z)
		for o in boxes:
			if o[0] == m[0]:
				continue
			var ob: AABB = o[1]
			var oc := Vector2(ob.get_center().x, ob.get_center().z)
			if absf(oc.x - c2.x) < (b.size.x + ob.size.x) * 0.5 \
					and absf(oc.y - c2.y) < (b.size.z + ob.size.z) * 0.5 \
					and ob.position.y < bot - 0.3 and ob.end.y >= bot - 1.0:
				supported = true
				break
		if not supported:
			suspended.append([bot, m[0], c2])
	print("[CLUSTERS] mesh-bottom histogram (model space): %s" % str(hist))
	print("[CLUSTERS] SUSPENDED (bottom>0.5m, nothing beneath): %d" % suspended.size())
	suspended.sort()
	suspended.reverse()
	for i in range(mini(40, suspended.size())):
		var s: Array = suspended[i]
		var c3: Vector2 = s[2]
		print("[CLUSTERS]   bottom=%.2f  %-30s at %.0f,%.0f" % [s[0], str(s[1]), c3.x, c3.y])
	root.free()
	quit(0)
