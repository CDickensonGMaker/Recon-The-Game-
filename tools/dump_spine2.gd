## dump_spine2.gd - in-tree spine dump (scene context, frame processed).
extends Node3D


func _ready() -> void:
	var model := ModelActor.new()
	add_child(model)
	model.setup("us_grunt_v2")
	model.play("idle", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var skel: Skeleton3D = model.skeleton()
	print("skel basis: ", skel.global_transform.basis)
	for bone in ["mixamorig_Hips", "mixamorig_Spine1", "mixamorig_Neck", "mixamorig_Head"]:
		var bi: int = skel.find_bone(bone)
		var p: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
		print("%-22s world=(%.3f, %.3f, %.3f)" % [bone, p.x, p.y, p.z])
	get_tree().quit()
