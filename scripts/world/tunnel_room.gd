## tunnel_room.gd - Tunnel-rat micro-dungeon (W51): a dark cache chamber 40m
## under the entrance. Interact at the entrance to drop in, at the ladder to
## climb out. Pistol-light work down there.
class_name TunnelRoom
extends Node3D

const ROOM_SIZE := Vector3(10.0, 3.0, 14.0)

var surface_return: Vector3 = Vector3.ZERO
var looted: bool = false


static func get_or_create(world: Node, entrance: Node3D) -> TunnelRoom:
	if entrance.has_meta("tunnel_room"):
		return entrance.get_meta("tunnel_room") as TunnelRoom
	var room := TunnelRoom.new()
	world.add_child(room)
	room.global_position = entrance.global_position + Vector3(0, -40.0, 0)
	room.surface_return = entrance.global_position + Vector3(1.5, 1.0, 0)
	room._build()
	entrance.set_meta("tunnel_room", room)
	return room


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.2, 0.14)
	# Floor / ceiling / 4 walls as one StaticBody3D of boxes.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var panels := [
		[Vector3(ROOM_SIZE.x, 0.4, ROOM_SIZE.z), Vector3(0, -0.2, 0)],
		[Vector3(ROOM_SIZE.x, 0.4, ROOM_SIZE.z), Vector3(0, ROOM_SIZE.y, 0)],
		[Vector3(0.4, ROOM_SIZE.y, ROOM_SIZE.z), Vector3(-ROOM_SIZE.x * 0.5, ROOM_SIZE.y * 0.5, 0)],
		[Vector3(0.4, ROOM_SIZE.y, ROOM_SIZE.z), Vector3(ROOM_SIZE.x * 0.5, ROOM_SIZE.y * 0.5, 0)],
		[Vector3(ROOM_SIZE.x, ROOM_SIZE.y, 0.4), Vector3(0, ROOM_SIZE.y * 0.5, -ROOM_SIZE.z * 0.5)],
		[Vector3(ROOM_SIZE.x, ROOM_SIZE.y, 0.4), Vector3(0, ROOM_SIZE.y * 0.5, ROOM_SIZE.z * 0.5)],
	]
	for p in panels:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = p[0]
		col.shape = box
		col.position = p[1]
		body.add_child(col)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mesh.mesh = bm
		mesh.position = p[1]
		mesh.material_override = mat
		body.add_child(mesh)
	# Candle light - barely enough.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 0.7
	light.omni_range = 7.0
	light.position = Vector3(2.5, 1.6, -4.0)
	add_child(light)
	# The cache (lootable) at the far end.
	var cache := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.4, 0.9, 1.0)
	cache.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.4, 0.32, 0.2)
	cache.material_override = cmat
	cache.position = Vector3(2.5, 0.45, -5.0)
	add_child(cache)
	# Ladder marker (exit) under the shaft.
	var ladder := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.4, ROOM_SIZE.y, 0.15)
	ladder.mesh = lm
	ladder.material_override = mat
	ladder.position = Vector3(0, ROOM_SIZE.y * 0.5, ROOM_SIZE.z * 0.5 - 0.6)
	add_child(ladder)


func entry_point() -> Vector3:
	return global_position + Vector3(0, 1.0, ROOM_SIZE.z * 0.5 - 1.5)


func ladder_point() -> Vector3:
	return global_position + Vector3(0, 0, ROOM_SIZE.z * 0.5 - 1.5)


func cache_point() -> Vector3:
	return global_position + Vector3(2.5, 0.5, -5.0)
