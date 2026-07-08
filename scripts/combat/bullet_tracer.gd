## bullet_tracer.gd - Visual tracer effect for bullet paths
class_name BulletTracer
extends Node3D

## Tracer settings
@export var tracer_color: Color = Color(1.0, 0.9, 0.5, 1.0)  ## Yellow/white tracer
@export var tracer_width: float = 0.02  ## Width of the tracer line
@export var fade_time: float = 0.1  ## How long the tracer stays visible
@export var travel_speed: float = 500.0  ## Visual travel speed (m/s)

## Internal
var start_pos: Vector3
var end_pos: Vector3
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var lifetime: float = 0.0
var total_distance: float = 0.0
var current_length: float = 0.0
var is_fading: bool = false
var fade_timer: float = 0.0


func _ready() -> void:
	_create_mesh()


func _create_mesh() -> void:
	mesh_instance = MeshInstance3D.new()

	# Create material
	material = StandardMaterial3D.new()
	material.albedo_color = tracer_color
	material.emission_enabled = true
	material.emission = tracer_color
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create a simple box mesh (will be stretched)
	var box := BoxMesh.new()
	box.size = Vector3(tracer_width, tracer_width, 1.0)  # Z will be scaled to length
	mesh_instance.mesh = box
	mesh_instance.material_override = material

	add_child(mesh_instance)
	mesh_instance.visible = false


## Initialize the tracer with start and end positions
func fire(from: Vector3, to: Vector3) -> void:
	start_pos = from
	end_pos = to
	global_position = from

	total_distance = from.distance_to(to)
	current_length = 0.0
	is_fading = false
	fade_timer = 0.0
	lifetime = 0.0

	# Orient toward target
	if total_distance > 0.01:
		look_at(to, Vector3.UP)

	mesh_instance.visible = true
	material.albedo_color.a = 1.0


func _process(delta: float) -> void:
	if not mesh_instance.visible:
		return

	lifetime += delta

	if not is_fading:
		# Extend the tracer toward the target
		current_length += travel_speed * delta

		if current_length >= total_distance:
			current_length = total_distance
			is_fading = true

		# Update mesh scale and position
		var direction: Vector3 = (end_pos - start_pos).normalized()
		mesh_instance.scale.z = current_length
		mesh_instance.position.z = -current_length / 2.0
	else:
		# Fade out
		fade_timer += delta
		var fade_progress: float = fade_timer / fade_time
		material.albedo_color.a = 1.0 - fade_progress

		if fade_timer >= fade_time:
			queue_free()


## Static factory to spawn a tracer
static func spawn_tracer(parent: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.9, 0.5, 1.0)) -> BulletTracer:
	var tracer := BulletTracer.new()
	tracer.tracer_color = color
	parent.add_child(tracer)
	tracer.fire(from, to)
	return tracer
