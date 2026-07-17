## fire_hazard.gd - Napalm burn area: damages bodies inside it over time.
class_name FireHazard
extends Area3D

@export var damage_per_second: float = 25.0
@export var duration: float = 15.0
@export var hazard_radius: float = 10.0

var _tick_timer: float = 0.0
var _life: float = 0.0


static func create_at(parent: Node, pos: Vector3, radius: float = 10.0, dur: float = 15.0) -> FireHazard:
	var hazard := FireHazard.new()
	hazard.hazard_radius = radius
	hazard.duration = dur
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	hazard.add_child(shape)
	hazard.collision_layer = 0
	hazard.collision_mask = 2 | 4  # player + enemies (allies share layer 2)
	parent.add_child(hazard)
	hazard.global_position = pos
	# Fire visual: simple emissive cylinder patch + light (placeholder VFX).
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.9
	cyl.bottom_radius = radius * 0.9
	cyl.height = 0.5
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.05, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	hazard.add_child(mesh)
	return hazard


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		queue_free()
		return
	_tick_timer += delta
	if _tick_timer < 0.5:
		return
	_tick_timer = 0.0
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(int(damage_per_second * 0.5), Enums.DamageType.FIRE, null)
