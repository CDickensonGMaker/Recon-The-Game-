## Probe: does the imported fsb_main_v3 scene actually carry StaticBody colliders?
## Run: godot --headless --path . --script tools/probe_fsb_collision.gd
extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://assets/world/building models/structures/firebase/fsb_main_v3.glb")
	if scene == null:
		print("PROBE: scene failed to load")
		quit(1)
		return
	var root: Node = scene.instantiate()
	var bodies: int = 0
	var shapes: int = 0
	var meshes: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			bodies += 1
		elif n is CollisionShape3D:
			shapes += 1
		elif n is MeshInstance3D:
			meshes += 1
		for c in n.get_children():
			stack.append(c)
	print("PROBE fsb_main_v3: %d StaticBody3D, %d CollisionShape3D, %d MeshInstance3D" % [bodies, shapes, meshes])
	# The gate must be an OPENING: name every collider near the gate marker.
	var gate_node: Node3D = root.find_child("gate_pos*", true, false) as Node3D
	var markers: Array[String] = []
	var stack2: Array[Node] = [root]
	while not stack2.is_empty():
		var n2: Node = stack2.pop_back()
		if n2 is Marker3D or n2.name.to_lower().contains("gate"):
			markers.append("%s @ %s" % [n2.name, str((n2 as Node3D).position) if n2 is Node3D else "?"])
		for c2 in n2.get_children():
			stack2.append(c2)
	for m in markers:
		print("PROBE marker: %s" % m)
	if gate_node != null:
		var gp: Vector3 = gate_node.position
		var near: int = 0
		var stack3: Array[Node] = [root]
		while not stack3.is_empty():
			var n3: Node = stack3.pop_back()
			if n3 is StaticBody3D and (n3 as Node3D).position.distance_to(gp) < 8.0:
				near += 1
				print("PROBE collider near gate: %s @ %s" % [n3.name, str((n3 as Node3D).position)])
			for c3 in n3.get_children():
				stack3.append(c3)
		print("PROBE colliders within 8m of gate: %d" % near)
	root.free()
	quit(0)
