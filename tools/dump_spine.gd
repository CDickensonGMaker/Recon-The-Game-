## dump_spine.gd - print v2 spine-chain world positions (hitzone aim debug).
## Run: godot --headless --path . --script tools/dump_spine.gd
extends SceneTree


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var model := ModelActor.new()
	root.add_child(model)
	model.setup("us_grunt_v2")
	model.play("idle", true)
	model._anim.advance(0.5)
	var skel: Skeleton3D = model.skeleton()
	for bone in ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
			"mixamorig_Neck", "mixamorig_Head", "mixamorig_HeadTop_End",
			"mixamorig_LeftForeArm", "mixamorig_LeftHand"]:
		var bi: int = skel.find_bone(bone)
		if bi < 0:
			print("%-28s MISSING" % bone)
			continue
		var p: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
		print("%-28s idx=%d  world=(%.3f, %.3f, %.3f)" % [bone, bi, p.x, p.y, p.z])
	quit()
