## destructible_vehicle.gd - Vehicle prop that can be demolished (NS17).
## Destruction via planted charge / scripted calls (satchel the tank).
class_name DestructibleVehicle
extends StaticBody3D

signal destroyed(vehicle: DestructibleVehicle)

var is_destroyed: bool = false


static func create(parent: Node, model_path: String, world_pos: Vector3, rotation_deg: float, terrain: TerrainManager) -> DestructibleVehicle:
	var model_name := model_path.get_file().get_basename()
	var entry: Dictionary = CollisionTable.get_entry(model_name)
	var vehicle := DestructibleVehicle.new()
	vehicle.name = model_name
	vehicle.collision_layer = 1
	vehicle.collision_mask = 0
	var scene: PackedScene = load(model_path)
	if scene:
		var visual := scene.instantiate()
		var s: float = float(entry.scale)
		if s != 1.0:
			visual.scale = Vector3(s, s, s)
		vehicle.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = entry.box
	vehicle.add_to_group("nav_blockers")   # NavBaker carves it; APCs and AA guns block a path
	vehicle.set_meta("nav_box", entry.box)
	shape.shape = box
	shape.position = Vector3(0, float(entry.y_offset), 0)
	vehicle.add_child(shape)
	parent.add_child(vehicle)
	var gy: float = terrain.get_height_at(world_pos) if terrain else world_pos.y
	vehicle.global_position = Vector3(world_pos.x, gy, world_pos.z)
	vehicle.rotation_degrees = Vector3(0, rotation_deg, 0)
	return vehicle


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	CombatManager.apply_explosion_damage(global_position, 140, 40, 9.0, null)
	DamageSystem.apply_damage(global_position, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	_blacken()
	destroyed.emit(self)


func _blacken() -> void:
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.08, 0.07, 0.06)
	burnt.roughness = 1.0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = burnt
		for c in n.get_children():
			stack.push_back(c)
	rotation_degrees.z = 4.0  # slumped
