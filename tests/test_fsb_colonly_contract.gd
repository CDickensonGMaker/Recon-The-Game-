## test_fsb_colonly_contract.gd - `-colonly` is only a contract at the END of a name.
##
##   godot --headless --path . res://tests/test_fsb_colonly_contract.tscn
##
## Godot's glTF importer converts a node whose name ENDS WITH `-colonly` into a
## StaticBody3D and drops the visual. A marker anywhere else in the name satisfies
## nothing: the node imports as an ordinary MeshInstance3D, and because collision
## proxies carry no material it renders as Godot's default WHITE.
## `us_fb_ammo_crate_stack-colonly_P2` did exactly that through the 2026-08-12,
## 2026-09-06 and 2026-09-09 exports - a white box z-fighting the textured crate in
## the P2 mortar pit. It was fixed in the source blend on 2026-09-09; this asserts it
## against the SHIPPED scene so it cannot come back.
extends Node

const FSB: String = "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"

var failures: int = 0


func _ready() -> void:
	var scene: PackedScene = load(FSB) as PackedScene
	if scene == null:
		print("FAIL: cannot load %s" % FSB)
		get_tree().quit(1)
		return
	var root: Node = scene.instantiate()

	var stray_mesh: Array[String] = []
	var white: Array[String] = []
	var bodies: int = 0
	var meshes: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is CollisionObject3D:
			bodies += 1
		if n is MeshInstance3D:
			meshes += 1
			var nm: String = String(n.name)
			if nm.contains("-colonly") or nm.contains("_colonly"):
				stray_mesh.append(nm)
			if _is_unmaterialed(n as MeshInstance3D):
				white.append(nm)

	if not stray_mesh.is_empty():
		print("FAIL: %d collider(s) imported as a VISIBLE mesh: %s"
			% [stray_mesh.size(), ", ".join(stray_mesh)])
		failures += 1
	if not white.is_empty():
		print("FAIL: %d visible mesh(es) with no material - Godot renders these WHITE: %s"
			% [white.size(), ", ".join(white)])
		failures += 1

	root.queue_free()
	if failures == 0:
		print("PASS: fsb colonly contract - %d collider bodies, %d visible meshes, 0 stray, 0 white"
			% [bodies, meshes])
	get_tree().quit(1 if failures > 0 else 0)


## A mesh with neither an override nor a surface material draws in Godot's default
## white. That is the visible half of the defect; the name is only how it got there.
func _is_unmaterialed(mi: MeshInstance3D) -> bool:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return false
	for i: int in range(mesh.get_surface_count()):
		if mi.get_surface_override_material(i) != null:
			continue
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_material(i) != null:
			continue
		if mi.material_override != null:
			continue
		return true
	return false
