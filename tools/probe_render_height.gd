## probe_render_height.gd - where does the RENDERED man actually stand?
## Skinned verts render pulled to the REST skeleton, so rest head-top world Y
## IS the rendered height. If it disagrees with ModelActor's 1.7132m contract,
## the height normalizer measured the bind-pose mesh AABB instead of the man.
##   godot --headless --path . -s res://tools/probe_render_height.gd [unit ...]
extends SceneTree

func _initialize() -> void:
	var units: PackedStringArray = OS.get_cmdline_user_args()
	if units.is_empty():
		units = PackedStringArray(["us_grunt_rifleman", "vc_guerilla", "vc_guerilla_mosin"])
	for unit in units:
		var holder := Node3D.new()
		root.add_child(holder)
		var model := ModelActor.new()
		holder.add_child(model)
		if not model.setup(unit):
			print("%s: setup FAILED" % unit)
			holder.queue_free()
			continue
		await process_frame
		var skel: Skeleton3D = model.skeleton()
		if skel == null:
			print("%s: no skeleton" % unit)
			holder.queue_free()
			continue
		var top: int = skel.find_bone("mixamorig_HeadTop_End")
		var foot: int = skel.find_bone("mixamorig_LeftToeBase")
		var top_y: float = (skel.global_transform * skel.get_bone_global_rest(top).origin).y if top >= 0 else -1.0
		var foot_y: float = (skel.global_transform * skel.get_bone_global_rest(foot).origin).y if foot >= 0 else -1.0
		print("%s: rendered head-top y=%.2fm  toe y=%.2fm  (contract: man is 1.71m)" % [unit, top_y, foot_y])
		holder.queue_free()
	quit(0)
