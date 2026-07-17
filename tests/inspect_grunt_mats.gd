## inspect_grunt_mats.gd - art-drift inspector: per US unit, count face-atlas
## surfaces and report the dresser-contract meshes (stock helmet, PRC-25, ruck).
## This is the instrument that caught the grunt_face_skin/face_atlas_mat drift.
## Run: godot --headless --path . res://tests/inspect_grunt_mats.tscn
extends Node3D

func _ready() -> void:
	await get_tree().process_frame
	for unit in ModelActor.all_units():
		if not unit.begins_with("us_"):
			continue
		var actor := ModelActor.new()
		add_child(actor)
		if not actor.setup(unit):
			print("SUMMARY %s setup_failed" % unit)
			continue
		var face_n: int = 0
		var helmet: bool = false
		var prc25: bool = false
		var ruck: bool = false
		var stack: Array[Node] = [actor.instance_root()]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.push_back(c)
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var nm := String(mi.name)
			if nm.contains("helmet_shell_worn"):
				helmet = true
			if nm.begins_with("prc25_pack"):
				prc25 = true
			if nm.contains("ruck_pack_worn"):
				ruck = true
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(s)
				if m != null and m.resource_name.begins_with("face_atlas"):
					face_n += 1
		print("SUMMARY %-20s face_surfaces=%d stock_helmet=%s prc25=%s ruck=%s" % [
			unit, face_n, helmet, prc25, ruck])
		actor.queue_free()
	get_tree().quit(0)
