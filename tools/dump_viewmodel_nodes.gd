## dump_viewmodel_nodes.gd - node/mesh names inside a weapon viewmodel scene,
## so code can find the parts it must animate (e.g. the RPG warhead that has to
## LEAVE THE TUBE when you fire).
##   godot --headless --path . -s res://tools/dump_viewmodel_nodes.gd -- rpg2
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "rpg2"
	var path: String = "res://scenes/weapons/%s_arms_viewmodel.tscn" % which
	var packed: PackedScene = load(path)
	if packed == null:
		print("no scene at %s" % path)
		quit(1)
		return
	var inst: Node = packed.instantiate()
	print("=== %s ===" % path)
	var stack: Array = [[inst, 0]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var n: Node = pair[0]
		var d: int = pair[1]
		var kind: String = n.get_class()
		var extra: String = ""
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			extra = "  [mesh, %d surf]" % (n as MeshInstance3D).mesh.get_surface_count()
		print("%s%s (%s)%s" % ["  ".repeat(d), n.name, kind, extra])
		# Per-surface breakdown: which chunk of geometry is the WARHEAD? It is the
		# one living out past the muzzle end of the tube.
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var arr: Array = mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				if verts.is_empty():
					continue
				var lo := Vector3(INF, INF, INF)
				var hi := Vector3(-INF, -INF, -INF)
				for v in verts:
					lo = lo.min(v)
					hi = hi.max(v)
				var mat: Material = mi.mesh.surface_get_material(s)
				var mname: String = mat.resource_name if mat != null else "-"
				print("%s  surf %d '%s' %d verts  z[%.2f..%.2f] y[%.2f..%.2f] size(%.2f,%.2f,%.2f)" % [
					"  ".repeat(d), s, mname, verts.size(), lo.z, hi.z, lo.y, hi.y,
					hi.x - lo.x, hi.y - lo.y, hi.z - lo.z])
		var kids: Array = n.get_children()
		kids.reverse()
		for c in kids:
			stack.append([c, d + 1])
	inst.free()
	quit(0)
