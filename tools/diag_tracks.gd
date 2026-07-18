@tool
extends SceneTree
func _init() -> void:
	var packed: PackedScene = load("res://assets/us/characters/us_grunt_rifleman.glb")
	var inst: Node = packed.instantiate()
	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	for name in ["idle", "run_forward", "firing_rifle", "death_from_the_front", "reloading", "idle_aiming"]:
		var a: Animation = anim.get_animation(name)
		print("%s: %s tracks" % [name, str(a.get_track_count()) if a else "MISSING"])
	inst.free()
	quit(0)
