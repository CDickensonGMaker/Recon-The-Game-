## probe_loop_flags.gd - is the ONE-SHOT set smaller than the LOOP set?
##
##   godot --headless --path . -s res://tools/probe_loop_flags.gd
##
## _LOOP_NAMES is a 45-entry HAND-MAINTAINED list, and its own comment admits the prefix
## heuristic misses every entry in it - the definition of a list that should not exist.
## Inverting it (enumerate the one-shots, loop everything else) is only an improvement if the
## one-shot set is genuinely smaller and closed. Nobody has counted. This counts.
extends SceneTree

const LIB := "res://assets/shared/anim_library.glb"


func _initialize() -> void:
	var packed: PackedScene = load(LIB) as PackedScene
	if packed == null:
		print("[LOOPS] anim_library.glb will not load")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		print("[LOOPS] no AnimationPlayer in the library")
		quit(1)
		return
	var looped: Array[String] = []
	var once: Array[String] = []
	for key in ap.get_animation_list():
		var nm := String(key)
		var is_loop: bool = false
		if nm in ModelActor._LOOP_NAMES:
			is_loop = true
		elif nm.contains("turn") or nm.contains("_to_") or nm.contains("jump"):
			is_loop = false
		else:
			for p in ModelActor._LOOP_PREFIXES:
				if nm.begins_with(p):
					is_loop = true
					break
		if is_loop:
			looped.append(nm)
		else:
			once.append(nm)
	looped.sort()
	once.sort()
	print("[LOOPS] %d clips: %d LOOP, %d ONE-SHOT" % [looped.size() + once.size(),
		looped.size(), once.size()])
	print("[LOOPS] the 45-entry hand list would be replaced by a one-shot list of %d" % once.size())
	print("[LOOPS] ONE-SHOTS: %s" % ", ".join(PackedStringArray(once)))
	quit(0)
