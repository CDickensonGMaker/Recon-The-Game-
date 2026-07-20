## grenade.gd - Physics-based grenade projectile with fuse and explosion
class_name Grenade
extends RigidBody3D

## SHRAPNEL (ADR-016 Amendment F). The M26 is a FRAG grenade - its killing is done
## by wire-coil fragments, not blast. Real casualty radius is ~15m; 10m keeps
## cover play meaningful while letting the fragments reach.
##
## The damage OF RECORD is data/weapons/m26_grenade.tres, like every other weapon
## (ADR-016: base_damage is the flat value). The .tres rules - FALLBACK_DAMAGE
## applies ONLY when it fails to load.
const EXPLOSION_RADIUS: float = 10.0
const FALLBACK_DAMAGE: int = 190
## Rim damage as a fraction of centre: the far fragments WOUND, they do not kill.
const RIM_FRAC: float = 0.13

static var _m26: WeaponData = null


static func _grenade_damage() -> int:
	if _m26 == null:
		_m26 = load("res://data/weapons/m26_grenade.tres") as WeaponData
	return _m26.base_damage if _m26 != null else FALLBACK_DAMAGE

## State
var remaining_fuse: float = 4.0
var initial_velocity: Vector3 = Vector3.ZERO
var owner_entity: Node = null
var has_exploded: bool = false

## Visual components
var mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 256  # Projectile layer
	collision_mask = 1  # World layer

	linear_velocity = initial_velocity

	mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.35, 0.2)  # Olive drab
	mesh.material_override = mat

	add_child(mesh)

	# Collision: a BOX, deliberately NOT a sphere. Godot physics has no rolling
	# resistance, so a sphere rolls forever; a box lands, hops once or twice,
	# tumbles a few cm and STOPS.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.09, 0.06, 0.06)
	col.shape = shape
	add_child(col)

	# Small lively bounces, dead quickly.
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

	# Apply explosion damage - centre kills outright, the rim wounds (shrapnel).
	var centre: int = _grenade_damage()
	CombatManager.apply_explosion_damage(
		global_position,
		centre,
		maxi(1, int(float(centre) * RIM_FRAC)),
		EXPLOSION_RADIUS,
		owner_entity
	)

	# Destructible terrain: real crater (rate-limited globally by DamageSystem
	# being one-at-a-time; small type keeps chunk rebuilds cheap).
	if DamageSystem.has_method("apply_damage"):
		DamageSystem.apply_damage(global_position, DamageSystem.DamageType.SMALL_EXPLOSION, 0.9)

	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, global_position, 0)
	GunFX.play_explosion_3d(get_tree().current_scene, global_position)

	queue_free()
