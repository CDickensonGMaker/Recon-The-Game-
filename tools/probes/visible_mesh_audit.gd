## visible_mesh_audit.gd - WHAT ACTUALLY RENDERS ON A DRESSED MAN?
## Not what the hide passes intend - what survives them. Spawns each US unit
## through the real ModelActor.setup() + GruntDresser.dress() path and prints
## every visible MeshInstance3D with its size, material, albedo and UV state.
## Run: godot --headless --path . res://tools/probes/visible_mesh_audit.tscn
extends Node3D


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	for unit in ModelActor.all_units():
		if not unit.begins_with("us_"):
			continue
		var actor := ModelActor.new()
		add_child(actor)
		if not actor.setup(unit):
			actor.queue_free()
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var loadout: Dictionary = GruntDresser.dress(actor, rng)
		await get_tree().process_frame
		_dump(unit, actor, loadout)
		actor.queue_free()
	print("AUDIT DONE")
	get_tree().quit()


func _dump(unit: String, actor: ModelActor, loadout: Dictionary) -> void:
	var root: Node3D = actor.instance_root()
	print("\n===== %s  loadout=%s =====" % [unit, str(loadout)])
	var helmets: Array[String] = []
	var vis: int = 0
	for n in _walk(actor):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if not mi.is_visible_in_tree():
			continue
		vis += 1
		var nm := String(mi.name)
		if nm.to_lower().contains("helm") or nm.to_lower().contains("pot"):
			helmets.append(nm)
		var mesh: Mesh = mi.mesh
		var box: Vector3 = mesh.get_aabb().size
		var parts: Array[String] = []
		for s in mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				m = mesh.surface_get_material(s)
			var bm := m as BaseMaterial3D
			var has_uv: bool = (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV) != 0
			if bm == null:
				parts.append("[%d]%s(shader) uv=%s" % [s, m.resource_name if m else "NULL", has_uv])
				continue
			var c: Color = bm.albedo_color
			parts.append("[%d]%s tex=%s uv=%s rgb=%.2f,%.2f,%.2f" % [s, bm.resource_name,
				"Y" if bm.albedo_texture != null else "N", "Y" if has_uv else "N", c.r, c.g, c.b])
		print("  %-24s size=%.3f,%.3f,%.3f  %s" % [nm, box.x, box.y, box.z, ", ".join(parts)])
	print("  -> VISIBLE MESHES: %d   HELMET-LIKE VISIBLE: %d %s" % [vis, helmets.size(), str(helmets)])


func _walk(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		out.append(c)
		for k in c.get_children():
			stack.push_back(k)
	return out
