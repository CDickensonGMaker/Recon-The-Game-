## probe_chinook_dims.gd - measure the Chinook airframe. Its numbers authored the
## ch47 entry in seat_system.gd FALLBACK_LAYOUTS (2026-08-13; before that the
## Chinook inherited the Huey-measured layout and men unseated inside the
## fuselage). Re-run after any chinook re-export to re-verify the envelope.
##   godot --headless --path . res://tools/probe_chinook_dims.tscn
extends Node


func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/vehicles/chinook.tscn") as PackedScene
	if packed == null:
		packed = load("res://scenes/chinook.tscn") as PackedScene
	if packed == null:
		# The scene path is not canon - find it.
		for p in ["res://scenes/vehicles/chinook.tscn", "res://scenes/air/chinook.tscn"]:
			print("  tried %s" % p)
		print("FAIL: chinook.tscn not found at known paths - listing candidates:")
		_hunt("res://scenes")
		get_tree().quit(1)
		return
	var inst := packed.instantiate() as Node3D
	add_child(inst)
	await get_tree().process_frame
	print("\n=== CHINOOK DIMENSIONS (vehicle-root space) ===")
	print("scene tree:")
	_dump(inst, 0)
	var total := AABB()
	var first: bool = true
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		print("  mesh %-28s size (%.2f, %.2f, %.2f)  pos %.2f..%.2f x, %.2f..%.2f y, %.2f..%.2f z" % [
			mi.name, ab.size.x, ab.size.y, ab.size.z,
			ab.position.x, ab.position.x + ab.size.x,
			ab.position.y, ab.position.y + ab.size.y,
			ab.position.z, ab.position.z + ab.size.z])
		if first:
			total = ab
			first = false
		else:
			total = total.merge(ab)
	print("TOTAL: size (%.2f, %.2f, %.2f)  x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % [
		total.size.x, total.size.y, total.size.z,
		total.position.x, total.position.x + total.size.x,
		total.position.y, total.position.y + total.size.y,
		total.position.z, total.position.z + total.size.z])
	get_tree().quit(0)


func _dump(n: Node, depth: int) -> void:
	print("  %s%s (%s)" % ["  ".repeat(depth), n.name, n.get_class()])
	for c in n.get_children():
		_dump(c, depth + 1)


func _hunt(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		var full: String = dir_path + "/" + f
		if d.current_is_dir() and not f.begins_with("."):
			_hunt(full)
		elif f.to_lower().contains("chinook"):
			print("  found: %s" % full)
		f = d.get_next()
