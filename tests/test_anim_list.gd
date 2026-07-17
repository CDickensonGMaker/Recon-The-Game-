extends Node
func _ready() -> void:
	var al = load("res://assets/shared/anim_library.glb").instantiate()
	var ap = al.find_child("AnimationPlayer", true, false)
	if ap:
		var n = ap.get_animation_list()
		print("CLIP_COUNT:", n.size())
		for c in n:
			print("CLIP:", c)
	else:
		print("NO_ANIM_PLAYER_FOUND")
	get_tree().quit(0)
