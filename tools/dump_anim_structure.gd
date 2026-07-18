## dump_anim_structure.gd - one-shot probe: compare anim_library.glb vs
## character GLBs (node paths, AnimationPlayer root, track paths) before wiring
## the shared-library pipeline (bead 00qp).
## Run: godot --headless --path . --script tools/dump_anim_structure.gd
extends SceneTree


func _init() -> void:
	var paths: Array[String] = [
		"res://assets/shared/anim_library.glb",
		"res://assets/us/characters/us_grunt_rifleman.glb",
		"res://assets/nva_vc/characters/vc_guerilla_mosin.glb",
	]
	for path in paths:
		print("=== ", path)
		var ps: PackedScene = load(path)
		if ps == null:
			print("  LOAD FAILED")
			continue
		var inst: Node = ps.instantiate()
		_dump(inst, 0)
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null:
			print("  NO AnimationPlayer")
		else:
			print("  AP path=", inst.get_path_to(ap), "  root_node=", ap.root_node)
			print("  libraries=", ap.get_animation_library_list())
			var list: PackedStringArray = ap.get_animation_list()
			print("  clips=", list.size(), " first=", list.slice(0, 6))
			if list.size() > 0:
				var a: Animation = ap.get_animation(list[0])
				print("  clip '", list[0], "' tracks=", a.get_track_count())
				for t in range(mini(5, a.get_track_count())):
					print("    track ", a.track_get_path(t))
		var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel != null:
			print("  skeleton bones=", skel.get_bone_count(), " path_from_root=", inst.get_path_to(skel))
		inst.free()
	quit()


func _dump(n: Node, d: int) -> void:
	if d > 3:
		return
	print("  ".repeat(d + 1), n.name, "  (", n.get_class(), ")")
	for c in n.get_children():
		_dump(c, d + 1)
