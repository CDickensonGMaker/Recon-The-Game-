extends SceneTree
## Does the v3 base's bone-parented gear survive glTF -> Godot?
##   1. do the *_worn meshes exist in the imported scene at all?
##   2. are they RIGID (skin == null) so probe_silhouette/HitzoneBuilder skip them?
##   3. do they TRACK THE BONE - i.e. does the helmet stay on his head when he
##      moves? A helmet welded to the origin is worse than a welded-in helmet.
##   4. did the hurtbox actually shrink (the whole point of the exercise)?

func _initialize() -> void:
	for unit in ["us_grunt_rifleman", "us_grunt_mg"]:
		var ps: PackedScene = load(ModelActor.model_path(unit))
		var root: Node3D = ps.instantiate()
		get_root().add_child(root)
		var skel: Skeleton3D = _find_skel(root)
		print("\n=== %s ===  skeleton bones: %d" % [unit, skel.get_bone_count()])

		var worn: Array[MeshInstance3D] = []
		for mi in _all_mesh(root):
			if mi.name.ends_with("_worn"):
				worn.append(mi)
		if worn.is_empty():
			print("  (no *_worn gear - gear is welded into the body)")

		for mi in worn:
			var att := mi.get_parent()
			var bone := "-"
			if att is BoneAttachment3D:
				bone = (att as BoneAttachment3D).bone_name
			print("  %-20s skin=%-5s parent=%-18s bone=%s"
				% [mi.name, str(mi.skin != null), att.get_class(), bone])

		# 3. move the head bone and see if the helmet comes along
		var head := skel.find_bone("mixamorig_Head")
		var helmet: MeshInstance3D = null
		for mi in worn:
			if mi.name.begins_with("helmet"):
				helmet = mi
		if helmet != null and head >= 0:
			var before: Vector3 = helmet.global_position
			var p := skel.get_bone_pose(head)
			skel.set_bone_pose_position(head, p.origin + Vector3(0.0, 0.0, 0.5))
			await process_frame
			await process_frame
			var moved: float = helmet.global_position.distance_to(before)
			skel.set_bone_pose_position(head, p.origin)
			print("  head bone moved 0.50m -> helmet moved %.3fm  %s"
				% [moved, "TRACKS THE BONE" if moved > 0.4 else "*** DOES NOT FOLLOW ***"])

		root.queue_free()
	quit()

func _all_mesh(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_mesh(c))
	return out

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skel(c)
		if s != null:
			return s
	return null
