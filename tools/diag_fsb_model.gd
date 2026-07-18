extends SceneTree
## Headless audit of the fsb_main.glb IMPORTED resource: node layout, mesh
## spread, material/texture truth. Runs without a world - pure asset probe.

func _init() -> void:
	var scene: PackedScene = load("res://assets/building models/structures/firebase/fsb_main.glb")
	if scene == null:
		print("[FSB-MODEL] FAIL: scene did not load")
		quit(1)
		return
	var root := scene.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			meshes.append(n as MeshInstance3D)
	print("[FSB-MODEL] mesh instances: %d" % meshes.size())

	# Combined model-space AABB using each node's transform relative to root.
	var combined := AABB()
	var first := true
	var origin_count: int = 0
	var min_y: float = 1.0e9
	var max_y: float = -1.0e9
	for mi in meshes:
		var xf: Transform3D = _rel_transform(mi, root)
		var b: AABB = xf * mi.get_aabb()
		if first:
			combined = b
			first = false
		else:
			combined = combined.merge(b)
		if xf.origin.length() < 0.5:
			origin_count += 1
		min_y = minf(min_y, b.position.y)
		max_y = maxf(max_y, b.end.y)
	print("[FSB-MODEL] combined AABB pos=%s size=%s" % [str(combined.position.round()), str(combined.size.round())])
	print("[FSB-MODEL] mesh node origins AT root origin (<0.5m): %d of %d" % [origin_count, meshes.size()])
	print("[FSB-MODEL] geometry min_y=%.2f max_y=%.2f (ground contract: min_y ~ 0)" % [min_y, max_y])

	# Radial spread of mesh AABB centers from root origin (the 200m question).
	var rings := {"0-50": 0, "50-100": 0, "100-150": 0, "150-200": 0, "200+": 0}
	for mi in meshes:
		var xf2: Transform3D = _rel_transform(mi, root)
		var c2: Vector3 = (xf2 * mi.get_aabb()).get_center()
		var d: float = Vector2(c2.x, c2.z).length()
		if d < 50.0: rings["0-50"] += 1
		elif d < 100.0: rings["50-100"] += 1
		elif d < 150.0: rings["100-150"] += 1
		elif d < 200.0: rings["150-200"] += 1
		else: rings["200+"] += 1
	print("[FSB-MODEL] AABB-center radial spread: %s" % str(rings))

	# Material truth: per-surface, does an active material carry an albedo texture?
	var surf_total: int = 0
	var surf_textured: int = 0
	var surf_flat: int = 0
	var surf_null: int = 0
	var flat_names := {}
	for mi in meshes:
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			surf_total += 1
			var mat: Material = mi.get_active_material(s)
			if mat == null:
				surf_null += 1
				continue
			var sm := mat as StandardMaterial3D
			if sm != null and sm.albedo_texture != null:
				surf_textured += 1
			else:
				surf_flat += 1
				var mname: String = mat.resource_name
				if sm != null and sm.albedo_color.is_equal_approx(Color.WHITE):
					flat_names[mname] = flat_names.get(mname, 0) + 1
	print("[FSB-MODEL] surfaces: %d total, %d textured, %d flat-color, %d NULL material" % [
		surf_total, surf_textured, surf_flat, surf_null])
	print("[FSB-MODEL] flat surfaces that are PURE WHITE (render gray, likely lost texture): %s" % str(flat_names))

	# Visibility: anything imported hidden?
	var hidden: int = 0
	for mi in meshes:
		if not mi.visible:
			hidden += 1
	print("[FSB-MODEL] hidden mesh instances: %d" % hidden)
	root.free()
	quit(0)


func _rel_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
