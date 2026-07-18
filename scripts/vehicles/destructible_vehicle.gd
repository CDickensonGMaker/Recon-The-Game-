## destructible_vehicle.gd - Vehicle prop demolished by a planted charge or a
## scripted call.
class_name DestructibleVehicle
extends StaticBody3D


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
