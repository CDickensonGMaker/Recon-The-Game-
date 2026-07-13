## probe_hitzone_fit.gd - headless fit report: how far does each hitzone sit
## from the bone segment it guards? Run after tuning a unit in the bench to
## catch zones that drifted off the body (a floating box = free misses).
##   godot --headless --path . -s res://tools/probe_hitzone_fit.gd [unit ...]
## No args = every unit with a .glb. FLOAT flag = zone center > 0.35m off its
## segment; a tuned zone should hug the limb it names.
extends SceneTree

const FLOAT_LIMIT_M: float = 0.35


func _initialize() -> void:
	var units: PackedStringArray = PackedStringArray()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		for unit in ModelActor.all_units():
			units.append(unit)
	else:
		units = args
	var floaters: int = 0
	for unit in units:
		floaters += await _probe(unit)
	quit(1 if floaters > 0 else 0)


func _probe(unit: String) -> int:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		print("%s: setup FAILED" % unit)
		holder.queue_free()
		return 0
	# Bust the hull cache so every probe re-harvests - a cached cold-start
	# harvest would masquerade as a warm one.
	HitzoneBuilder._hull_cache = {}
	var k_before: float = model.skeleton().global_transform.basis.get_scale().x
	var entries: Array = HitzoneBuilder.build(holder, model, 0, 0, ["fit_probe"], true)
	await process_frame
	var k_after: float = model.skeleton().global_transform.basis.get_scale().x
	print("  k at build=%.3f  k after frame=%.3f" % [k_before, k_after])
	HitzoneBuilder.sync(model, entries)
	var tuned: String = "measured"
	if ResourceLoader.exists(HitzoneBuilder.TUNING_DIR + unit + ".tres"):
		tuned = "tuned"
	elif ResourceLoader.exists(HitzoneBuilder.TUNING_DIR + "_default.tres"):
		tuned = "default-tuned"
	print("\n=== %s (%s) ===" % [unit, tuned])
	var skel: Skeleton3D = model.skeleton()
	var floaters: int = 0
	for entry in entries:
		var hz: Area3D = entry[0]
		var a: Vector3 = skel.global_transform * skel.get_bone_global_pose(entry[1]).origin
		var b: Vector3 = a
		if int(entry[3]) >= 0:
			b = skel.global_transform * skel.get_bone_global_pose(entry[3]).origin
		# Distance from the zone's shape center to the joint segment.
		var center: Vector3 = hz.global_position
		if hz.has_meta("hull_points"):
			var c := Vector3.ZERO
			var pts: PackedVector3Array = hz.get_meta("hull_points")
			for p in pts:
				c += p
			center = hz.global_transform * (c / float(pts.size()))
		var seg: Vector3 = b - a
		var t: float = 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((center - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var d: float = center.distance_to(a + seg * t)
		var flag: String = "  <-- FLOAT" if d > FLOAT_LIMIT_M else ""
		if d > FLOAT_LIMIT_M:
			floaters += 1
		print("  %-9s center %.2fm off its segment%s" % [str(hz.get_meta("region", "?")), d, flag])
	holder.queue_free()
	return floaters
