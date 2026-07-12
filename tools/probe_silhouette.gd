## probe_silhouette.gd - the RENDERED man: skin the vertices to the rest
## skeleton (the renderer's own math) and measure what the player actually
## sees - height, shoulder width, body depth, and where the lowest vertex
## sits relative to the man's origin (his feet plane).
## Bone rigs can be identical while the MESHES that hang on them are not.
##   godot --headless --path . -s res://tools/probe_silhouette.gd
extends SceneTree


func _initialize() -> void:
	var dir := DirAccess.open("res://assets/models/characters")
	var units: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".glb") and not f.begins_with("anim_library"):
			units.append(f.trim_suffix(".glb"))
	units.sort()
	print("unit                     height  shoulders  depth   lowest_y  parts")
	for unit in units:
		await _measure(unit)
	quit(0)


func _measure(unit: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		holder.queue_free()
		return
	holder.global_position = Vector3.ZERO
	await process_frame
	var skel: Skeleton3D = model.skeleton()
	# WORLD space: the armature node carries the glTF Z-up -> Y-up rotation, so
	# skeleton-LOCAL vertices are Z-up. Only skel.global_transform gives the man
	# the player actually sees (scale + ground offset included). Holder sits at
	# the origin, so world Y == height above his feet plane.
	var to_world: Transform3D = skel.global_transform
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	# Chest slab: vertices within +-8cm of the Spine1 bone height, for an
	# honest shoulder-width / torso-depth read.
	var spine_i: int = skel.find_bone("mixamorig_Spine1")
	var spine_y: float = (to_world * skel.get_bone_global_rest(spine_i).origin).y if spine_i >= 0 else 1.2
	var chest_lo := Vector3(INF, 0, INF)
	var chest_hi := Vector3(-INF, 0, -INF)
	var parts: int = 0
	var stack: Array[Node] = [model.instance_root() as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null or mi.skin == null:
			continue
		parts += 1
		var xf: Array = HitzoneBuilder._bind_rest_xforms(mi.skin, skel)
		for s in range(mi.mesh.get_surface_count()):
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty():
				continue
			var infl: int = bones.size() / verts.size()
			for vi in range(verts.size()):
				var best_w: float = -1.0
				var best_b: int = -1
				for j in range(infl):
					var w: float = float(weights[vi * infl + j])
					if w > best_w:
						best_w = w
						best_b = bones[vi * infl + j]
				if best_b < 0 or best_b >= xf.size():
					continue
				# Skin the vertex to the rest skeleton, then into WORLD - exactly
				# what the renderer draws.
				var v: Vector3 = to_world * ((xf[best_b] as Transform3D) * verts[vi])
				lo = lo.min(v)
				hi = hi.max(v)
				if absf(v.y - spine_y) < 0.08:
					chest_lo.x = minf(chest_lo.x, v.x)
					chest_lo.z = minf(chest_lo.z, v.z)
					chest_hi.x = maxf(chest_hi.x, v.x)
					chest_hi.z = maxf(chest_hi.z, v.z)
	var height: float = hi.y - lo.y
	var shoulders: float = chest_hi.x - chest_lo.x
	var depth: float = chest_hi.z - chest_lo.z
	print("%-22s  %.3f    %.3f    %.3f   %+.3f    %d" % [
		unit, height, shoulders, depth, lo.y, parts])
	holder.queue_free()
