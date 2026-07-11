## diag_anim.gd - does 'idle' actually MOVE the us_grunt_v2 skeleton?
## Run: godot --headless --path . res://tools/diag_anim.tscn
extends Node3D


func _ready() -> void:
	var actor := ModelActor.new()
	add_child(actor)
	if not actor.setup("us_grunt_v2"):
		print("DIAG: setup failed")
		get_tree().quit(1)
		return
	var skel: Skeleton3D = actor.skeleton()
	var anim: AnimationPlayer = actor.instance_root().find_child("AnimationPlayer", true, false)
	if anim == null:
		print("DIAG: no AnimationPlayer")
		get_tree().quit(1)
		return

	print("DIAG: libraries=", anim.get_animation_library_list())
	print("DIAG: root_node=", anim.root_node, " -> resolves=", anim.get_node_or_null(anim.root_node) != null)
	var ok := actor.play("idle")
	print("DIAG: play('idle') -> ", ok, "  playing=", anim.is_playing(), "  current=", anim.current_animation)
	var a: Animation = anim.get_animation("idle")
	if a == null:
		print("DIAG: no 'idle' Animation resource")
	else:
		print("DIAG: idle length=%.2fs tracks=%d loop=%s" % [a.length, a.get_track_count(), str(a.loop_mode)])
		for i in range(mini(8, a.get_track_count())):
			print("  track %d: type=%d path=%s" % [i, a.track_get_type(i), a.track_get_path(i)])
		# do the first few track paths resolve from the player's root?
		var root: Node = anim.get_node_or_null(anim.root_node)
		if root != null and a.get_track_count() > 0:
			var p: NodePath = a.track_get_path(0)
			var target: Node = root.get_node_or_null(NodePath(String(p).split(":")[0]))
			print("DIAG: track0 node target resolves=", target != null)

	var hand_idx: int = skel.find_bone("mixamorig_RightHand")
	var p0: Vector3 = skel.get_bone_global_pose(hand_idx).origin
	for _i in range(40):
		await get_tree().process_frame
	var p1: Vector3 = skel.get_bone_global_pose(hand_idx).origin
	print("DIAG: RightHand moved %.4fm over 40 frames (0 = NOT ANIMATING)" % p0.distance_to(p1))
	print("DIAG: after wait - playing=", anim.is_playing(), " current=", anim.current_animation, " pos=%.2f" % anim.current_animation_position)
	get_tree().quit(0)
