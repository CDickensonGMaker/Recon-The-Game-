## probe_zone_shapes.gd - WHY does this man have holes? Lists every zone that
## got built on a unit: is it a real mesh HULL (cut from his body) or did it fall
## back to a formula CAPSULE, how many points does the hull have, and how big is
## it. A region that harvested too few vertices silently becomes a capsule - and
## a capsule on a thin man is exactly where rounds slip past.
##   godot --headless --path . -s res://tools/probe_zone_shapes.gd [unit ...]
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var units: Array = args if args.size() > 0 else ["us_grunt_v2", "vc_guerilla"]
	for u in units:
		await _probe(str(u))
	quit(0)


func _probe(unit: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		print("%s: setup FAILED" % unit)
		return
	await process_frame
	HitzoneBuilder._hull_cache = {}   # fresh harvest, no stale cache
	var entries: Array = HitzoneBuilder.build(holder, model, 64, 0, ["probe"], true)
	HitzoneBuilder.sync(model, entries)
	await process_frame
	print("\n=== %s ===" % unit)
	print("  region      shape     points  size (x,y,z)")
	var hulls: int = 0
	var caps: int = 0
	for c in holder.get_children():
		if not (c is Area3D):
			continue
		var hz := c as Area3D
		var region: String = str(hz.get_meta("region", "?"))
		var col: CollisionShape3D = null
		for cc in hz.get_children():
			if cc is CollisionShape3D:
				col = cc
		if col == null or col.shape == null:
			print("  %-11s NO SHAPE" % region)
			continue
		var kind: String = "?"
		var pts: int = 0
		var size := Vector3.ZERO
		if col.shape is ConvexPolygonShape3D:
			kind = "HULL"
			hulls += 1
			var p: PackedVector3Array = (col.shape as ConvexPolygonShape3D).points
			pts = p.size()
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for v in p:
				lo = lo.min(v)
				hi = hi.max(v)
			size = hi - lo
		elif col.shape is CapsuleShape3D:
			kind = "capsule*"   # FALLBACK - no usable mesh data for this region
			caps += 1
			var cap := col.shape as CapsuleShape3D
			size = Vector3(cap.radius * 2.0, cap.height, cap.radius * 2.0)
		elif col.shape is SphereShape3D:
			kind = "sphere*"
			caps += 1
			var r: float = (col.shape as SphereShape3D).radius
			size = Vector3(r * 2.0, r * 2.0, r * 2.0)
		print("  %-11s %-9s %4d    (%.2f, %.2f, %.2f)" % [region, kind, pts, size.x, size.y, size.z])
	print("  --> %d mesh hulls, %d formula fallbacks%s" % [hulls, caps,
		"   <-- FALLBACKS ARE THE HOLES" if caps > 0 else ""])
	holder.queue_free()
