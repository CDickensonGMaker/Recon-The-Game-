## probe_huey_rotor.gd - prove the rotors are found and actually rotate.
extends Node

func _ready() -> void:
	var heli: Helicopter = load("res://scenes/vehicles/huey.tscn").instantiate()
	add_child(heli)
	await get_tree().physics_frame

	var main: Node3D = heli.get("_main_rotor")
	var tail: Node3D = heli.get("_tail_rotor")
	var fail := 0
	if main == null: print("FAIL: main rotor node not found"); fail += 1
	if tail == null: print("FAIL: tail rotor node not found"); fail += 1
	if fail > 0: get_tree().quit(1); return

	# Recentre check: fuselage hull centre should sit near the heli origin.
	var fus: MeshInstance3D = heli.get_node("Model").find_child("Huey_Copy", true, false)
	var hull: Vector3 = fus.global_position + fus.get_aabb().get_center()
	print("hull centre (world) = (%.2f, %.2f, %.2f)" % [hull.x, hull.y, hull.z])
	if absf(hull.x) > 0.5 or absf(hull.z) > 0.5:
		print("FAIL: hull not recentred on origin"); fail += 1

	heli.state = Helicopter.State.FLYING
	var m0: float = main.rotation.y
	var t0: float = tail.rotation.x
	for i in range(60):
		heli._physics_process(1.0 / 60.0)
	var dm: float = absf(main.rotation.y - m0)
	var dt: float = absf(tail.rotation.x - t0)
	print("after 1s FLYING: main dY=%.3f rad  tail dX=%.3f rad" % [dm, dt])
	if dm < 0.5: print("FAIL: main rotor did not spin"); fail += 1
	if dt < 0.5: print("FAIL: tail rotor did not spin"); fail += 1

	heli.state = Helicopter.State.DESTROYED
	for i in range(180):
		heli._physics_process(1.0 / 60.0)
	var rpm: float = heli.get("_rotor_rpm")
	print("after 3s DESTROYED: rpm=%.3f (should spool to ~0)" % rpm)
	if rpm > 0.05: print("FAIL: rotor did not spool down"); fail += 1

	print("PASS: huey rotors live" if fail == 0 else "FAIL: %d" % fail)
	get_tree().quit(0 if fail == 0 else 1)
