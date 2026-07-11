## probe_huey_frame.gd - TEMP probe: where does the huey mesh actually sit in
## heli space after helicopter.gd's recenter, and what class do GLB "empties"
## import as? Run:
##   godot --headless --path . res://tools/probe_huey_frame.tscn
extends Node3D


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/vehicles/huey.tscn") as PackedScene
	var heli: Node3D = packed.instantiate() as Node3D
	add_child(heli)
	await get_tree().process_frame

	var model: Node3D = heli.get_node("Model") as Node3D
	print("Model.position (post-recenter) = ", model.position)

	var fus: MeshInstance3D = model.find_child("Huey_Copy", true, false) as MeshInstance3D
	if fus == null:
		print("Huey_Copy MISSING")
	else:
		var aabb: AABB = fus.get_aabb()
		print("Huey_Copy.position (Model space) = ", fus.position)
		print("Huey_Copy local aabb centre = ", aabb.get_center())
		var inv: Transform3D = heli.global_transform.affine_inverse()
		print("fuselage centre in HELI space = ", inv * (fus.global_transform * aabb.get_center()))

	var dl: Node3D = model.find_child("Door_Left", true, false) as Node3D
	if dl != null:
		var inv2: Transform3D = heli.global_transform.affine_inverse()
		print("Door_Left origin in HELI space = ", inv2 * dl.global_position, "  class=", dl.get_class())

	for n: String in ["seat_pilot_l", "seat_gunner_l", "seat_pax_1"]:
		var s: Node = model.find_child(n, true, false)
		if s == null:
			print(n, " -> MISSING from GLB")
		else:
			var s3 := s as Node3D
			var inv3: Transform3D = heli.global_transform.affine_inverse()
			print(n, " -> class=", s.get_class(), " heli-space pos=", inv3 * s3.global_position, " local +Z=", s3.global_transform.basis.z)
	get_tree().quit(0)
