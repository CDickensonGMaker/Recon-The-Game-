## test_hitzones.gd - HitzoneBuilder probe (beads 90gj/yd83).
##   1. Bone-measured build on a rigged unit yields all 7 zones (6 without GUT).
##   2. Zones RIDE the bones: after playing a clip and advancing, sync() moves
##      the head zone with the skeleton (static bands never moved - the bug).
##   3. Bench tuning roundtrip: a saved HitzoneTuning override is applied on
##      the next build (radius absolute, offset delta, damage/fatal overrides
##      per ADR-016 Amendment B; untouched zones keep values-of-record).
## Run: godot --headless --path . res://tests/test_hitzones.tscn
extends Node3D


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var failures: int = 0

	# --- 1. build on a rigged unit
	var holder := Node3D.new()
	add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup("us_grunt_v2"):
		print("FAIL: us_grunt_v2 setup failed")
		get_tree().quit(1)
		return
	var entries: Array = HitzoneBuilder.build(holder, model, 0, 0, ["hitzone_probe"], true)
	var zones: Array = []
	for c in holder.get_children():
		if c is Area3D:
			zones.append(c)
	print("  zones built: %d  bone-synced: %d" % [zones.size(), entries.size()])
	if zones.size() != 7:
		print("FAIL: expected 7 zones with gut, got %d" % zones.size())
		failures += 1
	if entries.size() != 7:
		print("FAIL: expected all 7 zones bone-synced on a rigged unit, got %d" % entries.size())
		failures += 1

	# --- 2. zones ride the bones
	var head_zone: Area3D = null
	for z in zones:
		if str(z.get_meta("region", "")) == "HEAD":
			head_zone = z
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
		# sanity: head zone sits near the actual head bone
		var skel: Skeleton3D = model.skeleton()
		var hb: int = skel.find_bone("mixamorig_Head")
		var head_bone_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(hb).origin
		if head_zone.global_position.distance_to(head_bone_pos) > 0.5:
			print("FAIL: HEAD zone %.2fm from head bone" % head_zone.global_position.distance_to(head_bone_pos))
			failures += 1
	holder.queue_free()

	# --- no-gut variant (allies)
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
	if count2 != 6 or has_gut:
		print("FAIL: no-gut build should be 6 zones without GUT (got %d, gut=%s)" % [count2, has_gut])
		failures += 1
	holder2.queue_free()

	# --- 3. tuning roundtrip
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/hitzones"))
	var tuning := HitzoneTuning.new()
	tuning.zones["HEAD"] = {"radius": 0.5, "offset": Vector3(0, 0.2, 0), "damage": 2.5, "fatal": false}
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
		var applied: bool = false
		var dmg_ok: bool = false
		var fatal_ok: bool = false
		var body_law_ok: bool = false
		for c in holder3.get_children():
			if c is Area3D and str(c.get_meta("region", "")) == "HEAD":
				for cc in c.get_children():
					if cc is CollisionShape3D and (cc as CollisionShape3D).shape is SphereShape3D:
						var r: float = ((cc as CollisionShape3D).shape as SphereShape3D).radius
						applied = absf(r - 0.5) < 0.001
				var hzc := c as Hitzone
				if hzc != null:
					dmg_ok = absf(hzc.get_damage_multiplier() - 2.5) < 0.001
					fatal_ok = not hzc.is_fatal_zone()
			elif c is Area3D and str(c.get_meta("region", "")) == "BODY":
				var bzc := c as Hitzone
				if bzc != null:
					body_law_ok = absf(bzc.get_damage_multiplier() - 2.0) < 0.001 and not bzc.is_fatal_zone()
		if not applied:
			print("FAIL: tuning override radius not applied on rebuild")
			failures += 1
		if not dmg_ok:
			print("FAIL: damage override 2.5 not applied to HEAD on rebuild")
			failures += 1
		if not fatal_ok:
			print("FAIL: fatal=false override not applied to HEAD on rebuild")
			failures += 1
		if not body_law_ok:
			print("FAIL: untouched BODY zone drifted from ADR-016 law (x2.0, non-fatal)")
			failures += 1
		if applied and dmg_ok and fatal_ok and body_law_ok:
			print("  tuning roundtrip OK (HEAD r=0.5, dmg x2.5, non-fatal; BODY kept law)")
		holder3.queue_free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tpath))

	if failures == 0:
		print("PASS: hitzone builder (bone-measured + bone-synced + tuning) OK")
	else:
		print("FAIL: hitzone probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
