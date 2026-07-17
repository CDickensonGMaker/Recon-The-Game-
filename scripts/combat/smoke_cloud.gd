## smoke_cloud.gd - concealment volume: blocks AI sight lines through it.
class_name SmokeCloud
extends Node3D

static var active_clouds: Array[SmokeCloud] = []

@export var max_radius: float = 8.0
@export var duration: float = 25.0
@export var smoke_color: Color = Color(0.8, 0.35, 0.8)  ## goofy grape marking smoke

var _age: float = 0.0
var _mesh: MeshInstance3D


static func blocks_sight(from: Vector3, to: Vector3) -> bool:
	for cloud in active_clouds:
		if not is_instance_valid(cloud):
			continue
		var r: float = cloud.current_radius()
		if r < 1.0:
			continue
		# Segment-sphere intersection.
		var c := cloud.global_position + Vector3(0, 1.5, 0)
		var ab := to - from
		var t: float = clampf((c - from).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
		if (from + ab * t).distance_to(c) <= r:
			return true
	return false


func current_radius() -> float:
	return max_radius * clampf(_age / 3.0, 0.1, 1.0) * (1.0 if _age < duration - 5.0 else clampf((duration - _age) / 5.0, 0.0, 1.0))


static func spawn_at(parent: Node, pos: Vector3, color: Color = Color(0.75, 0.75, 0.72)) -> SmokeCloud:
	var cloud := SmokeCloud.new()
	cloud.smoke_color = color
	parent.add_child(cloud)
	cloud.global_position = pos
	return cloud


func _ready() -> void:
	active_clouds.append(self)
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(smoke_color.r, smoke_color.g, smoke_color.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 1.5, 0)
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		active_clouds.erase(self)
		queue_free()
		return
	var r := current_radius()
	_mesh.scale = Vector3(r, r * 0.8, r)


func _exit_tree() -> void:
	active_clouds.erase(self)
