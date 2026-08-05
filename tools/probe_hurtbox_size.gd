extends SceneTree
## Did cutting the gear out of the body actually SHRINK the hurtbox?
##
## HitzoneBuilder harvests hulls from SKINNED meshes and skips anything whose
## name matches _GEAR_NAME_HINTS. On us_grunt_rifleman the helmet and ruck are welded
## into `us_grunt_joined` - which is not a gear name - so they were harvested
## straight into the HEAD and TORSO hulls: you could shoot a man's backpack and
## hurt his spine. On us_grunt_v3 they are bone-parented `*_worn` meshes - rigid,
## unskinned, gear-named - so the harvester cannot see them.
##
##   godot --headless --path . -s res://tools/probe_hurtbox_size.gd

func _initialize() -> void:
	for unit in ["us_grunt_rifleman", "us_grunt_mg"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var model := ModelActor.new()
		holder.add_child(model)
		if not model.setup(unit):
			print("%s: setup FAILED" % unit)
			continue
		HitzoneBuilder._hull_cache = {}          # force a cold re-harvest
		var entries: Array = HitzoneBuilder.build(holder, model, 0, 0, ["hb_probe"], true)
		await process_frame
		HitzoneBuilder.sync(model, entries)
		print("=== %s ===" % unit)
		for area in _areas(holder):
			for c in area.get_children():
				var cs := c as CollisionShape3D
				if cs == null:
					continue
				var hull := cs.shape as ConvexPolygonShape3D
				if hull == null or hull.points.is_empty():
					continue
				var aabb := AABB(hull.points[0], Vector3.ZERO)
				for p in hull.points:
					aabb = aabb.expand(p)
				print("  %-9s %.3f w  %.3f h  %.3f d   vol %.4f m3" % [area.name,
					aabb.size.x, aabb.size.y, aabb.size.z,
					aabb.size.x * aabb.size.y * aabb.size.z])
		holder.queue_free()
		await process_frame
	quit()


func _areas(n: Node) -> Array[Area3D]:
	var out: Array[Area3D] = []
	if n is Area3D:
		out.append(n as Area3D)
	for c in n.get_children():
		out.append_array(_areas(c))
	return out
