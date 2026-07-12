## probe_lying_height.gd - which lying poses actually reach the ground?
## Freezes every death_* clip + laying_breathless at its final frame and
## reports the LOWEST bone's world height. A lying man's low point belongs at
## ~0; anything > 0.3m is a floater (Caleb: "dying guys lay down but they are
## floating in the air").
##   godot --headless --path . -s res://tools/probe_lying_height.gd [unit]
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var unit: String = args[0] if args.size() > 0 else "vc_guerilla"
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		print("setup FAILED")
		quit(1)
		return
	var skel: Skeleton3D = model.skeleton()
	var clips: Array[String] = []
	for c in model.clip_names():
		var cn: String = String(c)
		if cn.begins_with("death") or cn == "laying_breathless":
			clips.append(cn)
	clips.sort()
	print("=== %s lying-pose ground check (%d clips) ===" % [unit, clips.size()])
	for clip in clips:
		if not model.pose_end_of(clip):
			continue
		await process_frame
		await process_frame
		var lo: float = 999.0
		var hips_y: float = -1.0
		for bi in range(skel.get_bone_count()):
			var y: float = (skel.global_transform * skel.get_bone_global_pose(bi).origin).y
			lo = minf(lo, y)
			if skel.get_bone_name(bi) == "mixamorig_Hips":
				hips_y = y
		print("  %-32s lowest bone y=%.2fm  hips y=%.2fm%s" % [clip, lo, hips_y,
			"   <-- FLOATER" if lo > 0.3 else ""])
	quit(0)
