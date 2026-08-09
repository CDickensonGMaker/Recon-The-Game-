## probe_huey_frame.gd - asserts the huey_v3 facing + seat-socket contract in
## HELI space. Run:
##   godot --headless --path . res://tools/probe_huey_frame.tscn
##
## Conventions under test (three exist in this repo - name yours or it drifts):
##   VEHICLE ASSET: nose Blender +Y -> Godot -Z. Same forward helicopter.gd
##     steers with atan2(-dir.x, -dir.z).
##   SEAT SOCKET: the occupant faces the socket's local +Z, up is local +Y
##     (seat_system.gd:9-11). Pilots -Z (nose), gunners/pax +-X (out the doors).
extends Node3D

var failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	failures += 1


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/vehicles/huey.tscn") as PackedScene
	var heli: Node3D = packed.instantiate() as Node3D
	add_child(heli)
	await get_tree().process_frame

	var model: Node3D = heli.get_node("Model") as Node3D
	print("Model.transform = ", model.transform)
	if not model.transform.is_equal_approx(Transform3D.IDENTITY):
		_fail("Model is not identity - a rotated Model negates every seat socket's local +Z")

	var inv: Transform3D = heli.global_transform.affine_inverse()

	# Nose is -Z: the forward fuselage must reach further -Z than the tail boom.
	var fwd: MeshInstance3D = model.find_child("fuselage_fwd", true, false) as MeshInstance3D
	var aft: MeshInstance3D = model.find_child("fuselage_aft", true, false) as MeshInstance3D
	if fwd == null or aft == null:
		_fail("fuselage_fwd / fuselage_aft missing - is this the v3 GLB?")
	else:
		var nose_z: float = (inv * (fwd.global_transform * fwd.get_aabb().get_center())).z
		var tail_z: float = (inv * (aft.global_transform * aft.get_aabb().get_center())).z
		print("fuselage_fwd centre z = %.3f | fuselage_aft centre z = %.3f" % [nose_z, tail_z])
		if nose_z >= tail_z:
			_fail("nose is not at -Z - the airframe flies backwards")

	# Rotor empties helicopter.gd drives by name.
	for n: String in ["New_Blade_1", "New_TailBlade_2_002"]:
		if model.find_child(n, true, false) == null:
			_fail("rotor node '%s' missing - blades will not spin" % n)

	# Seat sockets: facing and up.
	var want: Dictionary = {
		"seat_pilot_l": Vector3(0, 0, -1), "seat_pilot_r": Vector3(0, 0, -1),
		"seat_gunner_l": Vector3(1, 0, 0), "seat_gunner_r": Vector3(-1, 0, 0),
		"seat_pax_1": Vector3(1, 0, 0), "seat_pax_2": Vector3(1, 0, 0),
		"seat_pax_3": Vector3(1, 0, 0), "seat_pax_4": Vector3(1, 0, 0),
		"seat_pax_5": Vector3(-1, 0, 0), "seat_pax_6": Vector3(-1, 0, 0),
		"seat_pax_7": Vector3(-1, 0, 0),
	}
	for n: String in want.keys():
		var s := model.find_child(n, true, false) as Node3D
		if s == null:
			_fail("%s MISSING from the GLB" % n)
			continue
		var b: Basis = (inv * s.global_transform).basis
		var face: Vector3 = b.z.normalized()
		var up: Vector3 = b.y.normalized()
		var pos: Vector3 = inv * s.global_position
		print("%-15s pos=%s face=%s up=%s" % [n, pos, face, up])
		if face.dot(want[n] as Vector3) < 0.99:
			_fail("%s faces %s, wanted %s" % [n, face, want[n]])
		if up.dot(Vector3.UP) < 0.99:
			_fail("%s up is %s - occupant is not upright" % [n, up])
		if pos.y < 0.6 or pos.y > 1.6:
			_fail("%s sits at y=%.2f - off the cabin/cockpit deck" % [n, pos.y])

	if failures == 0:
		print("PASS: huey_v3 frame + seat socket contract OK")
		get_tree().quit(0)
	else:
		print("FAIL: huey frame probe had %d failure(s)" % failures)
		get_tree().quit(1)
