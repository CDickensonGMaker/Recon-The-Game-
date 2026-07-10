## test_gore_rig.gd - gib rig contract probe (GORE_WORKFLOW Phase 3 / bead 1xqs).
## Drives GoreDummy through the SAME take_damage(zone) channel the weapons use
## and asserts the us_grunt_v2 rig contract holds:
##   - each limb region pops: bone chain collapsed, region mesh hidden, gib body spawned
##   - HEAD pops on kill and the bone-attached helmet flies as gear
##   - gore CAP meshes exist for every region (stump coverage) - missing caps WARN
## Run: godot --headless --path . res://tests/test_gore_rig.tscn -- --test-save
extends Node3D

var _fail: int = 0


func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_fail += 1


func _ready() -> void:
	await get_tree().process_frame
	var dummy := GoreDummy.new()
	add_child(dummy)
	dummy.global_position = Vector3.ZERO
	await get_tree().process_frame

	if dummy.model == null or not dummy.model.has_visual():
		_bad("dummy has no model - us_grunt_v2.glb missing")
		get_tree().quit(1)
		return
	var root: Node3D = dummy.model.instance_root()
	var skel: Skeleton3D = dummy.model.skeleton()

	# --- gib-rig contract: the duplicate uncut body must be hidden ----------
	var joined: MeshInstance3D = root.find_child("us_grunt_joined", true, false) as MeshInstance3D
	if joined != null and joined.visible:
		_bad("us_grunt_joined still visible - double-render ('multi arms') bug")
	elif joined != null:
		print("  duplicate uncut body hidden (contract OK)")

	# --- cap coverage (stumps) --------------------------------------------
	for cap in ["cap_head", "cap_torso", "cap_forearm_l", "cap_forearm_r",
			"cap_uparm_l", "cap_uparm_r", "cap_leg_l", "cap_leg_r"]:
		var c: MeshInstance3D = root.find_child(cap, true, false) as MeshInstance3D
		if c == null or c.mesh == null:
			print("WARN: gore cap '%s' missing or empty - that stump renders hollow (Blender fix)" % cap)

	# --- limb pops through the real damage channel -------------------------
	var gibs_before: int = _count_rigid_bodies()
	for entry in [["ARM_L", "grunt_forearm_l", "mixamorig_LeftForeArm"],
			["ARM_R", "grunt_forearm_r", "mixamorig_RightForeArm"],
			["LEG_L", "grunt_leg_l", "mixamorig_LeftUpLeg"],
			["LEG_R", "grunt_leg_r", "mixamorig_RightUpLeg"]]:
		var region: String = entry[0]
		var mesh_name: String = entry[1]
		var bone_name: String = entry[2]
		dummy.take_damage(21, 0, null, region)  # M16 flat 28 x 0.75 LIMB = 21
		if not dummy.regions_removed().has(region):
			_bad("%s did not pop" % region)
			continue
		var mi: MeshInstance3D = root.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null:
			_bad("%s: region mesh %s not found in rig" % [region, mesh_name])
		elif mi.visible:
			_bad("%s: region mesh %s still visible after pop" % [region, mesh_name])
		var bi: int = skel.find_bone(bone_name)
		if bi < 0:
			_bad("%s: bone %s missing" % [region, bone_name])
		elif skel.get_bone_pose_scale(bi).x > 0.01:
			_bad("%s: bone %s not collapsed (scale %.3f)" % [region, bone_name, skel.get_bone_pose_scale(bi).x])
		print("  %s popped: mesh hidden, bone collapsed" % region)

	# 4 limbs gone = dummy dies by bench rule
	if not dummy.regions_removed().has("ARM_L"):
		pass  # already failed above
	var gibs_after: int = _count_rigid_bodies()
	if gibs_after - gibs_before < 4:
		_bad("expected >=4 gib bodies, got %d" % (gibs_after - gibs_before))
	else:
		print("  gibs spawned: %d rigid bodies live" % (gibs_after - gibs_before))

	# --- head pop + helmet gear separation ---------------------------------
	var helmet: MeshInstance3D = root.find_child("helmet_camo_shell", true, false) as MeshInstance3D
	dummy.take_damage(112, 0, null, "HEAD")
	if not dummy.regions_removed().has("HEAD"):
		_bad("HEAD did not pop on headshot")
	if helmet != null and helmet.visible:
		_bad("helmet still on the collapsed head - gear did not separate")
	elif helmet != null:
		print("  HEAD popped: helmet flew as its own gib")
	if dummy.hp != 0:
		_bad("headshot left HP at %d" % dummy.hp)

	# --- gib cap + cleanup contract ----------------------------------------
	if _count_rigid_bodies() > GibSystem.MAX_LIVE_GIBS:
		_bad("live gibs exceed MAX_LIVE_GIBS cap")
	GibSystem.clear_gibs()
	await get_tree().process_frame
	if _count_rigid_bodies() != 0:
		_bad("clear_gibs() left bodies behind (MissionScope leak)")

	if _fail == 0:
		print("PASS: gore rig contract (4 limbs + head + helmet + caps + gib cap) OK")
	else:
		print("FAIL: gore rig probe had %d failure(s)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _count_rigid_bodies() -> int:
	var n: int = 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.push_back(c)
		if node is RigidBody3D:
			n += 1
	return n
