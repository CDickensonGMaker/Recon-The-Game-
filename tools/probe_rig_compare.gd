## probe_rig_compare.gd - are the VC and US rigs the SAME skeleton?
## The shared anim library was authored against ONE rig. If another rig's rest
## proportions differ, every borrowed clip distorts on it (limbs reach wrong,
## feet skate, poses sag) - the classic retarget failure. Also reports body
## mesh structure (joined body vs loose parts) and skin bind counts.
##   godot --headless --path . -s res://tools/probe_rig_compare.gd
extends SceneTree

const REF := "us_grunt_v2"

## Segments that define a man's proportions (rest, in normalized world units).
const SEGMENTS: Array = [
	["spine", "mixamorig_Hips", "mixamorig_Neck"],
	["neck_head", "mixamorig_Neck", "mixamorig_Head"],
	["skull", "mixamorig_Head", "mixamorig_HeadTop_End"],
	["shoulders", "mixamorig_LeftArm", "mixamorig_RightArm"],
	["upper_arm", "mixamorig_LeftArm", "mixamorig_LeftForeArm"],
	["forearm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"],
	["thigh", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg"],
	["shin", "mixamorig_LeftLeg", "mixamorig_LeftFoot"],
	["hips_width", "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg"],
]


func _initialize() -> void:
	var ref: Dictionary = await _measure(REF)
	if ref.is_empty():
		quit(1)
		return
	print("\n=== REFERENCE %s ===" % REF)
	_print_unit(ref, ref)
	for unit in ModelActor.all_units():
		if unit == REF:
			continue
		var m: Dictionary = await _measure(unit)
		if m.is_empty():
			continue
		print("\n=== %s vs %s ===" % [unit, REF])
		_print_unit(m, ref)
	# Library track audit: POSITION tracks on non-hip bones are the retarget
	# killer - they force one rig's bone offsets onto every other rig.
	_audit_library()
	quit(0)


func _measure(unit: String) -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		holder.queue_free()
		return {}
	await process_frame
	var skel: Skeleton3D = model.skeleton()
	var k: float = HitzoneBuilder._skel_world_scale(skel)
	var out: Dictionary = {"unit": unit, "bones": skel.get_bone_count(), "k": k, "segs": {}}
	for s in SEGMENTS:
		var a: int = skel.find_bone(str(s[1]))
		var b: int = skel.find_bone(str(s[2]))
		if a < 0 or b < 0:
			continue
		var pa: Vector3 = skel.get_bone_global_rest(a).origin * k
		var pb: Vector3 = skel.get_bone_global_rest(b).origin * k
		out["segs"][str(s[0])] = pa.distance_to(pb)
	# Body mesh structure: one joined body, or loose parts?
	var parts: Array[String] = []
	var stack: Array[Node] = [model.instance_root() as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.visible and mi.skin != null:
			parts.append(String(mi.name))
	parts.sort()
	out["parts"] = parts
	holder.queue_free()
	return out


func _print_unit(m: Dictionary, ref: Dictionary) -> void:
	print("  bones=%d  rig_scale=%.3f  body meshes=%d %s" % [
		m["bones"], m["k"], (m["parts"] as Array).size(), str(m["parts"])])
	for key in (ref["segs"] as Dictionary).keys():
		var mine: float = float((m["segs"] as Dictionary).get(key, 0.0))
		var theirs: float = float((ref["segs"] as Dictionary)[key])
		var pct: float = ((mine / maxf(0.0001, theirs)) - 1.0) * 100.0
		var flag: String = ""
		if absf(pct) >= 5.0:
			flag = "   <-- %+.0f%% (retarget distortion)" % pct
		print("    %-11s %.3fm (ref %.3fm)%s" % [key, mine, theirs, flag])


func _audit_library() -> void:
	print("\n=== anim_library track types ===")
	var packed: PackedScene = load("res://assets/shared/anim_library.glb")
	if packed == null:
		print("  library did not load")
		return
	var inst: Node = packed.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		inst.free()
		return
	var pos_bones: Dictionary = {}
	var rot: int = 0
	var scale_tracks: int = 0
	var clips: PackedStringArray = ap.get_animation_list()
	for cn in clips:
		var anim: Animation = ap.get_animation(cn)
		for t in range(anim.get_track_count()):
			var tt: int = anim.track_get_type(t)
			var path: String = str(anim.track_get_path(t))
			var bone: String = path.split(":")[-1]
			if tt == Animation.TYPE_POSITION_3D:
				pos_bones[bone] = true
			elif tt == Animation.TYPE_ROTATION_3D:
				rot += 1
			elif tt == Animation.TYPE_SCALE_3D:
				scale_tracks += 1
	var keys: Array = pos_bones.keys()
	keys.sort()
	print("  %d clips | rotation tracks %d | scale tracks %d" % [clips.size(), rot, scale_tracks])
	print("  POSITION-animated bones (%d): %s" % [keys.size(), str(keys)])
	print("  (position tracks on anything but Hips force the AUTHORING rig's bone")
	print("   offsets onto every other rig - proportions get overwritten per frame)")
	inst.free()
