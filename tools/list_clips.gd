extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://assets/shared/anim_library.glb")
	var inst: Node = ps.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ap.get_animation_list():
		print(a, "  len=", "%.2f" % ap.get_animation(a).length)
	inst.free()
	quit()
