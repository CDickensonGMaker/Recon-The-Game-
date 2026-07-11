## grenade.gd - Physics-based grenade projectile with fuse and explosion
class_name Grenade
extends RigidBody3D

signal exploded(position: Vector3)

## Configuration
# M26 frag (Caleb gore-lab retune): bigger, deadlier. Real M26 casualty
# radius ~15m; game-tuned to 8m so cover play stays meaningful indoors.
# 130 center = no survivors point-blank; 25 at the rim = wounded, not shrugged.
const EXPLOSION_RADIUS: float = 8.0
const MAX_DAMAGE: int = 130
const MIN_DAMAGE: int = 25

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

	# Collision: a BOX, deliberately not a sphere - spheres roll forever
	# (physics has no rolling resistance) and the frag slid across the map
	# like a curling stone (Caleb, gore lab). A box lands, hops once or
	# twice, tumbles a few cm and STOPS - the M26 'thunk' feel.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.09, 0.06, 0.06)
	col.shape = shape
	add_child(col)

	# Set physics properties: small lively bounces, dead quickly.
	gravity_scale = 1.0
	linear_damp = 0.6
	angular_damp = 2.0
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.3
	physics_material_override = pm
	# Each ground contact bleeds energy fast - by the second hop it's done.
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_touched_world)


func _on_touched_world(_body: Node) -> void:
	# progressive energy bleed: 1st touch damps, 2nd+ kills the slide
	linear_damp = minf(linear_damp + 2.5, 8.0)
	angular_damp = minf(angular_damp + 4.0, 12.0)


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
	GunFX.play_explosion_3d(get_tree().current_scene, global_position)  # now spawns flash+fireball+smoke

	exploded.emit(global_position)

	# Remove grenade
	queue_free()
