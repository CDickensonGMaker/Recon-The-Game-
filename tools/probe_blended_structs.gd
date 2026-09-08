## probe_blended_structs.gd - names the BLENDED / DEPTH_PRE_PASS surfaces in the firebase
## and helipad kits so a material fix can be aimed at real geometry instead of a count.
##   godot --headless --path . -s res://tools/probe_blended_structs.gd
extends SceneTree

const DIRS: Array[String] = [
	"res://assets/world/building models/structures/firebase/",
	"res://assets/world/building models/structures/firebase/kit/",
	"res://assets/world/building models/structures/emplacements_real/",
	"res://assets/world/building models/structures/converted/",
]


func _initialize() -> void:
	var tally: Dictionary = {}
	for dir_path: String in DIRS:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f: String in d.get_files():
			if f.get_extension().to_lower() != "glb":
				continue
			var packed: PackedScene = load(dir_path + f) as PackedScene
			if packed == null:
				continue
			var root: Node = packed.instantiate()
			_walk(root, f, tally)
			root.queue_free()
	var keys: Array = tally.keys()
	keys.sort()
	print("\n=== NON-OPAQUE SURFACES IN STRUCTURE KITS (file | material | mode) ===")
	for k: String in keys:
		print("  %-6d %s" % [int(tally[k]), k])
	quit(0)


func _walk(node: Node, file_name: String, tally: Dictionary) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var bm := mi.get_active_material(i) as BaseMaterial3D
			if bm == null:
				continue
			var mode: String = ""
			match bm.transparency:
				BaseMaterial3D.TRANSPARENCY_ALPHA: mode = "BLENDED"
				BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: mode = "DEPTH_PRE_PASS"
				_: continue
			var key: String = "%s | %s | %s" % [file_name, bm.resource_name, mode]
			tally[key] = int(tally.get(key, 0)) + 1
	for c: Node in node.get_children():
		_walk(c, file_name, tally)
