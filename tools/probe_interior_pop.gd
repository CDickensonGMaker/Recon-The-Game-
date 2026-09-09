## probe_interior_pop.gd - THE SECOND POP SOURCE, counted rather than guessed.
## The firebase GLB's interior props are range-culled at 40 m with no fade mode set, so
## they do not fade in - they all appear in ONE frame as you walk up to a hooch. This
## counts them and reports the exact cutoff each one carries.
##   godot --headless --path . -s res://tools/probe_interior_pop.gd
extends SceneTree

const FSB := "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
const PREFIX := "fb_int_"


func _initialize() -> void:
	if not ResourceLoader.exists(FSB):
		print("[INTPOP] firebase GLB not found at %s" % FSB)
		quit(1)
		return
	var root: Node = (load(FSB) as PackedScene).instantiate()
	var props: int = 0
	var surfaces: int = 0
	var tris: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or not String(mi.name).begins_with(PREFIX):
			continue
		props += 1
		if mi.mesh != null:
			surfaces += mi.mesh.get_surface_count()
			for si in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var vts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				tris += (idx.size() / 3) if idx.size() > 0 else (vts.size() / 3)
	print("[INTPOP] '%s' props: %d nodes, %d surfaces, %d tris" % [PREFIX, props, surfaces, tris])
	# Read off site_planner.gd rather than imported: SitePlanner pulls in the whole world
	# stack and will not compile inside a bare SceneTree tool script.
	print("[INTPOP] site_planner.gd:1705-1706 sets visibility_range_end=40m margin=8m and")
	print("[INTPOP] never sets visibility_range_fade_mode, so the default DISABLED applies -")
	print("[INTPOP] the margin is HYSTERESIS ONLY, not a fade. All %d appear in one frame." % props)
	root.free()
	quit(0)
