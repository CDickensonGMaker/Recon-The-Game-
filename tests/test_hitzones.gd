## test_hitzones.gd - HitzoneBuilder probe (beads 90gj/yd83/trqx).
##   1. HITZONE 2.0 build on a rigged v2 unit yields all 11 zones (limbs split
##      upper/lower), all bone-synced, and the core zones are MESH HULLS
##      (ConvexPolygonShape3D cut from the body mesh), not formula capsules.
##   2. Zones RIDE the bones: after playing a clip and advancing, sync() moves
##      the head zone with the skeleton (static bands never moved - the bug).
##   3. Bench tuning roundtrip: offset/rotation/inflate/damage/fatal overrides
##      are applied on the next build (ADR-016 Amendment B); untouched zones
##      keep the values of record.
## Run: godot --headless --path . res://tests/test_hitzones.tscn
extends Node3D

const REGIONS_11: Array[String] = ["HEAD", "BODY", "GUT",
	"ARM_L_UP", "ARM_L_LO", "ARM_R_UP", "ARM_R_LO",
	"LEG_L_UP", "LEG_L_LO", "LEG_R_UP", "LEG_R_LO"]


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _hull_aabb(shape: ConvexPolygonShape3D) -> AABB:
	var pts: PackedVector3Array = shape.points
	if pts.is_empty():
		return AABB()
	var aabb := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		aabb = aabb.expand(p)
	return aabb


func _shape_of(holder: Node3D, region: String) -> Shape3D:
	for c in holder.get_children():
		if c is Area3D and str(c.get_meta("region", "")) == region:
			for cc in c.get_children():
				if cc is CollisionShape3D:
					return (cc as CollisionShape3D).shape
	return null


func _run() -> void:
	var failures: int = 0

	# --- 1. build on a rigged unit: 11 zones, all synced, hulls on the core
	var holder := Node3D.new()
	add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup("us_grunt_v2"):
		print("FAIL: us_grunt_v2 setup failed")
		get_tree().quit(1)
		return
	var entries: Array = HitzoneBuilder.build(holder, model, 0, 0, ["hitzone_probe"], true)
	var regions_found: Dictionary = {}
	for c in holder.get_children():
		if c is Area3D:
			regions_found[str(c.get_meta("region", ""))] = c
	print("  zones built: %d  bone-synced: %d" % [regions_found.size(), entries.size()])
	if regions_found.size() != 11:
		print("FAIL: expected 11 zones with gut, got %d" % regions_found.size())
		failures += 1
	for r in REGIONS_11:
		if not regions_found.has(r):
			print("FAIL: missing region %s" % r)
			failures += 1
	if entries.size() != regions_found.size():
		print("FAIL: expected all zones bone-synced on a rigged unit (%d vs %d)" % [entries.size(), regions_found.size()])
		failures += 1
	# Mesh hulls on the v2 rig: HEAD + BODY + at least one limb segment must be
	# ConvexPolygonShape3D harvested from the body mesh.
	var base_head_aabb := AABB()
	for r in ["HEAD", "BODY", "ARM_L_UP"]:
		var sh: Shape3D = _shape_of(holder, r)
		if sh is ConvexPolygonShape3D:
			if r == "HEAD":
				base_head_aabb = _hull_aabb(sh as ConvexPolygonShape3D)
		else:
			print("FAIL: %s is not a mesh hull on us_grunt_v2 (got %s)" % [r, str(sh)])
			failures += 1
	# Hull honesty: the BODY hull must be TIGHTER than the old fattened capsule
	# (diameter = 2 * measured base radius) - that oversize was the complaint.
	var body_hz: Area3D = regions_found.get("BODY")
	var body_sh: Shape3D = _shape_of(holder, "BODY")
	if body_hz != null and body_sh is ConvexPolygonShape3D:
		var body_aabb: AABB = _hull_aabb(body_sh as ConvexPolygonShape3D)
		var cap_diam: float = float(body_hz.get_meta("base_radius", 0.2)) * 2.0
		if body_aabb.size.x > cap_diam + 0.05:
			print("FAIL: BODY hull wider than the old capsule (%.3f vs %.3f)" % [body_aabb.size.x, cap_diam])
			failures += 1

	# --- 2. zones ride the bones
	var head_zone: Area3D = regions_found.get("HEAD")
	if head_zone == null:
		print("FAIL: no HEAD zone")
		failures += 1
	else:
		HitzoneBuilder.sync(model, entries)
		var before: Vector3 = head_zone.global_position
		model.play("run_forward", true)
		model._anim.advance(0.25)
		HitzoneBuilder.sync(model, entries)
		var after: Vector3 = head_zone.global_position
		if before.is_equal_approx(after):
			print("FAIL: HEAD zone did not move with the animation (sync dead)")
			failures += 1
		else:
			print("  HEAD zone rode the run cycle %.4fm" % before.distance_to(after))
		var skel: Skeleton3D = model.skeleton()
		var hb: int = skel.find_bone("mixamorig_Head")
		var head_bone_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(hb).origin
		if head_zone.global_position.distance_to(head_bone_pos) > 0.5:
			print("FAIL: HEAD zone %.2fm from head bone" % head_zone.global_position.distance_to(head_bone_pos))
			failures += 1
	holder.queue_free()

	# --- no-gut variant (allies): 10 zones, no GUT
	var holder2 := Node3D.new()
	add_child(holder2)
	var model2 := ModelActor.new()
	holder2.add_child(model2)
	model2.setup("us_grunt_v2")
	HitzoneBuilder.build(holder2, model2, 0, 0, ["hitzone_probe"], false)
	var count2: int = 0
	var has_gut: bool = false
	for c in holder2.get_children():
		if c is Area3D:
			count2 += 1
			if str(c.get_meta("region", "")) == "GUT":
				has_gut = true
	if count2 != 10 or has_gut:
		print("FAIL: no-gut build should be 10 zones without GUT (got %d, gut=%s)" % [count2, has_gut])
		failures += 1
	holder2.queue_free()

	# --- 3. tuning roundtrip (offset + rotation + inflate + damage + fatal)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/hitzones"))
	var tuning := HitzoneTuning.new()
	tuning.zones["HEAD"] = {"offset": Vector3(0, 0.2, 0), "damage": 2.5, "fatal": false,
		"inflate": 0.05, "rotation": Vector3(0, 0, 20)}
	var tpath: String = HitzoneBuilder.TUNING_DIR + "us_grunt_v2.tres"
	var save_err: int = ResourceSaver.save(tuning, tpath)
	if save_err != OK:
		print("FAIL: tuning save err %d" % save_err)
		failures += 1
	else:
		var holder3 := Node3D.new()
		add_child(holder3)
		var model3 := ModelActor.new()
		holder3.add_child(model3)
		model3.setup("us_grunt_v2")
		var entries3: Array = HitzoneBuilder.build(holder3, model3, 0, 0, ["hitzone_probe"], true)
		var dmg_ok: bool = false
		var fatal_ok: bool = false
		var inflate_ok: bool = false
		var rot_ok: bool = false
		var body_law_ok: bool = false
		for c in holder3.get_children():
			if c is Area3D and str(c.get_meta("region", "")) == "HEAD":
				var hzc := c as Hitzone
				if hzc != null:
					dmg_ok = absf(hzc.get_damage_multiplier() - 2.5) < 0.001
					fatal_ok = not hzc.is_fatal_zone()
				var sh3: Shape3D = null
				for cc in c.get_children():
					if cc is CollisionShape3D:
						sh3 = (cc as CollisionShape3D).shape
				if sh3 is ConvexPolygonShape3D and base_head_aabb.size.length() > 0.0:
					var grown: AABB = _hull_aabb(sh3 as ConvexPolygonShape3D)
					inflate_ok = grown.size.x > base_head_aabb.size.x + 0.05
				for e in entries3:
					if e[0] == c and e.size() > 4:
						rot_ok = not (e[4] as Basis).is_equal_approx(Basis.IDENTITY)
			elif c is Area3D and str(c.get_meta("region", "")) == "BODY":
				var bzc := c as Hitzone
				if bzc != null:
					body_law_ok = absf(bzc.get_damage_multiplier() - 2.0) < 0.001 and not bzc.is_fatal_zone()
		if not dmg_ok:
			print("FAIL: damage override 2.5 not applied to HEAD on rebuild")
			failures += 1
		if not fatal_ok:
			print("FAIL: fatal=false override not applied to HEAD on rebuild")
			failures += 1
		if not inflate_ok:
			print("FAIL: inflate 0.05 did not grow the HEAD hull (base %.3f)" % base_head_aabb.size.x)
			failures += 1
		if not rot_ok:
			print("FAIL: rotation override not composed into the HEAD sync entry")
			failures += 1
		if not body_law_ok:
			print("FAIL: untouched BODY zone drifted from ADR-016 law (x2.0, non-fatal)")
			failures += 1
		if dmg_ok and fatal_ok and inflate_ok and rot_ok and body_law_ok:
			print("  tuning roundtrip OK (HEAD offset/rot/inflate/dmg x2.5/non-fatal; BODY kept law)")
		holder3.queue_free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tpath))

	if failures == 0:
		print("PASS: hitzone builder (mesh hulls + 11 regions + bone-sync + tuning) OK")
	else:
		print("FAIL: hitzone probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
