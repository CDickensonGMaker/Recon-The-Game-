## dump_mesh_names.gd - list every MeshInstance3D in a character rig with its
## visibility, so gib-rig contract name rules can be checked against reality.
## Runs the unit through ModelActor.setup (the LIVE path - contract hiding,
## rescale, library merge) and reports each visible mesh's world position, so
## floaters stand out by distance from the body column.
##   godot --headless --path . -s res://tools/dump_mesh_names.gd [unit ...]
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = PackedStringArray(["vc_guerilla"])
	for unit in args:
		await _dump(unit)
	quit(0)


func _dump(unit: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		print("%s: setup FAILED" % unit)
		holder.queue_free()
		return
	await process_frame
	print("\n=== %s (post-setup, visible meshes only) ===" % unit)
	var stack: Array[Node] = [model.instance_root() as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		var center: Vector3 = mi.global_transform * mi.get_aabb().get_center()
		var lateral: float = Vector2(center.x, center.z).length()
		print("  %-22s at (%.2f, %.2f, %.2f)%s" % [mi.name, center.x, center.y, center.z,
			"   <-- OFF-BODY" if lateral > 0.55 or center.y > 2.0 or center.y < -0.1 else ""])
	holder.queue_free()
