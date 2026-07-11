## test_anim_library.gd - shared anim library wiring probe (bead 00qp).
## Proves the split pipeline BEFORE the exporters flip EXPORT_ANIMATIONS=False:
##   1. Library loads and is non-trivial (~91 clips).
##   2. Transition era: a character with baked clips gains the library's extra
##      clips (merge, don't replace - embedded clips win).
##   3. Mesh-only era (simulated by stripping the baked AnimationPlayer):
##      ModelActor creates a player, mounts the library, and the borrowed
##      clips actually MOVE the skeleton (PSXRig track paths resolve).
##   4. Borrowed cyclic clips loop (merge ran before _apply_loop_modes).
## Run: godot --headless --path . res://tests/test_anim_library.tscn
extends Node3D


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var failures: int = 0

	# --- 1. library loads
	var lib: AnimationLibrary = ModelActor._load_shared_library()
	if lib == null:
		print("FAIL: shared anim library did not load")
		get_tree().quit(1)
		return
	var lib_count: int = lib.get_animation_list().size()
	print("  library clips: %d" % lib_count)
	if lib_count < 80:
		print("FAIL: library has %d clips, expected ~91" % lib_count)
		failures += 1

	# --- 2. transition era: merge fills gaps on a baked-clips character
	var actor := ModelActor.new()
	add_child(actor)
	if not actor.setup("us_grunt_v2"):
		print("FAIL: us_grunt_v2 setup failed")
		failures += 1
	else:
		var clips: PackedStringArray = actor.clip_names()
		print("  us_grunt_v2 clips after merge: %d" % clips.size())
		if not actor.play("brutal_assassination"):  # library-only clip
			print("FAIL: library-only clip not playable on us_grunt_v2")
			failures += 1
		if clips.size() < lib_count:
			print("FAIL: merged clip count %d < library %d" % [clips.size(), lib_count])
			failures += 1
	actor.queue_free()

	# --- 3+4. mesh-only era simulation: strip the baked player, re-merge
	var actor2 := ModelActor.new()
	add_child(actor2)
	var unit: String = "vc_guerilla_mosin" if ModelActor.model_exists("vc_guerilla_mosin") else "us_grunt_v2"
	if not actor2.setup(unit):
		print("FAIL: %s setup failed for mesh-only sim" % unit)
		failures += 1
	else:
		var inst: Node3D = actor2.instance_root()
		var baked: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if baked != null:
			inst.remove_child(baked)
			baked.free()
		actor2._anim = null
		actor2._merge_shared_library()  # must CREATE a player + mount library
		actor2._apply_loop_modes()
		if actor2._anim == null:
			print("FAIL: mesh-only path did not create an AnimationPlayer")
			failures += 1
		else:
			var skel: Skeleton3D = actor2.skeleton()
			var hips: int = skel.find_bone("mixamorig_Hips")
			if hips < 0:
				print("FAIL: %s has no mixamorig_Hips bone" % unit)
				failures += 1
			else:
				var pos_before: Vector3 = skel.get_bone_pose_position(hips)
				var rot_before: Quaternion = skel.get_bone_pose_rotation(hips)
				if not actor2.play("run_forward"):
					print("FAIL: library clip not playable on mesh-only rig")
					failures += 1
				actor2._anim.advance(0.35)
				var pos_after: Vector3 = skel.get_bone_pose_position(hips)
				var rot_after: Quaternion = skel.get_bone_pose_rotation(hips)
				if pos_before.is_equal_approx(pos_after) and rot_before.is_equal_approx(rot_after):
					print("FAIL: library clip does not move the skeleton (PSXRig track paths dead?)")
					failures += 1
				else:
					print("  mesh-only sim (%s): run_forward drives the rig OK" % unit)
			var cyclic: Animation = actor2._anim.get_animation("run_forward")
			if cyclic != null and cyclic.loop_mode != Animation.LOOP_LINEAR:
				print("FAIL: borrowed cyclic clip not looping (merge ran after loop-marking?)")
				failures += 1
	actor2.queue_free()

	if failures == 0:
		print("PASS: shared anim library pipeline (merge + mesh-only + loops) OK")
	else:
		print("FAIL: anim library probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
