## dump_character_tree.gd - print a character .glb's node tree, bones, and clips.
## Usage: godot --headless --path . -s tools/dump_character_tree.gd -- <unit_id>
@tool
extends SceneTree


func _init() -> void:
	var unit := "us_grunt_rifleman"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		unit = args[0]
	var path := ModelActor.model_path(unit)
	if path.is_empty():
		print("NO SUCH MODEL: ", unit)
		quit(1)
		return
	var packed: PackedScene = load(path)
	var inst: Node = packed.instantiate()
	print("=== %s node tree ===" % unit)
	_dump(inst, 0)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		print("=== bones (%d) ===" % skel.get_bone_count())
		for i in range(skel.get_bone_count()):
			print("  [%d] %s" % [i, skel.get_bone_name(i)])
	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		print("=== clips ===")
		for a in anim.get_animation_list():
			print("  ", a)
	inst.free()
	quit(0)


func _dump(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var skinned := "SKINNED" if mi.skin != null or not mi.skeleton.is_empty() else "STATIC"
		extra = " [MESH tris~%s vis=%s %s]" % [str(mi.mesh.get_faces().size() / 3) if mi.mesh else "?", str(mi.visible), skinned]
	elif n is Node3D:
		extra = " pos=%s" % str((n as Node3D).position)
	print("%s%s (%s)%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		_dump(c, depth + 1)
