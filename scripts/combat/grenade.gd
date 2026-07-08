## grenade.gd - Physics-based grenade projectile with fuse and explosion
class_name Grenade
extends RigidBody3D

signal exploded(position: Vector3)

## Configuration
const EXPLOSION_RADIUS: float = 5.0
const MAX_DAMAGE: int = 100
const MIN_DAMAGE: int = 20

## State
var remaining_fuse: float = 4.0
var initial_velocity: Vector3 = Vector3.ZERO
var owner_entity: Node = null
var has_exploded: bool = false

## Visual components
var mesh: MeshInstance3D

func _ready() -> void:
	# Set up collision
	collision_layer = 256  # Projectile layer
	collision_mask = 1  # World layer

	# Apply initial velocity
	linear_velocity = initial_velocity

	# Create visual mesh
	mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.35, 0.2)  # Olive drab
	mesh.material_override = mat

	add_child(mesh)

	# Create collision shape
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.05
	col.shape = shape
	add_child(col)

	# Set physics properties
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 0.5


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	remaining_fuse -= delta

	if remaining_fuse <= 0:
		_explode()


func _explode() -> void:
	if has_exploded:
		return

	has_exploded = true

	# Apply explosion damage
	CombatManager.apply_explosion_damage(
		global_position,
		MAX_DAMAGE,
		MIN_DAMAGE,
		EXPLOSION_RADIUS,
		owner_entity
	)

	# Destructible terrain: real crater (rate-limited globally by DamageSystem
	# being one-at-a-time; small type keeps chunk rebuilds cheap).
	if DamageSystem.has_method("apply_damage"):
		DamageSystem.apply_damage(global_position, DamageSystem.DamageType.SMALL_EXPLOSION, 0.9)

	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, global_position, 0)

	# TODO: Spawn explosion effect

	exploded.emit(global_position)

	# Remove grenade
	queue_free()
