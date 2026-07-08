## inspect_huey.gd - dev probe: print the huey.glb node tree + mesh AABBs.
extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://assets/building models/vehicles/huey.glb")
	var inst := scene.instantiate()
	add_child(inst)
	_dump(inst, 0)
	get_tree().quit(0)


func _dump(node: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var info := "%s%s (%s)" % [pad, node.name, node.get_class()]
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		info += "  aabb pos=%s size=%s  xform_origin=%s" % [aabb.position, aabb.size, mi.position]
	elif node is Node3D:
		info += "  pos=%s" % [(node as Node3D).position]
	print(info)
	for c in node.get_children():
		_dump(c, depth + 1)
