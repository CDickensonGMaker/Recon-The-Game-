## projectile_base.gd - Base bullet projectile with movement, collision, damage
class_name ProjectileBase
extends Area3D

signal hit_target(target: Node, damage: int)
signal expired
signal returned_to_pool

## Projectile configuration
var projectile_data: ProjectileData
var owner_entity: Node = null
var direction: Vector3 = Vector3.FORWARD
var current_speed: float = 200.0

## State tracking
var is_active: bool = false
var lifetime_timer: float = 0.0
var hit_targets: Array[Node] = []

## Components
var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D
var trail: GPUParticles3D = null

## Physics
var gravity_value: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var velocity: Vector3 = Vector3.ZERO

## Pool reference
var _pool: Node = null

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 256  # Layer 9 - projectiles
	collision_mask = 0

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Create collision shape
	collision_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.05
	collision_shape.shape = sphere
	add_child(collision_shape)

	# Create mesh instance for visual (small bullet)
	mesh_instance = MeshInstance3D.new()
	var bullet_mesh := SphereMesh.new()
	bullet_mesh.radius = 0.02
	bullet_mesh.height = 0.04
	mesh_instance.mesh = bullet_mesh
	add_child(mesh_instance)

	deactivate()


## Initialize projectile with data
func initialize(data: ProjectileData, source: Node, dir: Vector3, _target: Node3D = null) -> void:
	projectile_data = data
	owner_entity = source
	direction = dir.normalized()

	current_speed = data.speed
	lifetime_timer = 0.0
	hit_targets.clear()

	if collision_shape and collision_shape.shape is SphereShape3D:
		(collision_shape.shape as SphereShape3D).radius = data.collision_radius

	# Set collision mask based on what we hit
	collision_mask = 0
	if data.hits_enemies:
		collision_mask |= 4  # Enemy layer
		collision_mask |= 64  # Enemy hurtbox layer
	if data.hits_players:
		collision_mask |= 2  # Player layer
		collision_mask |= 32  # Player hurtbox layer
	if data.hits_world:
		collision_mask |= 1  # World layer

	_setup_visuals()

	if data.has_trail:
		_setup_trail()

	velocity = direction * current_speed


func _setup_visuals() -> void:
	if not projectile_data:
		return
	mesh_instance.scale = projectile_data.scale


func _setup_trail() -> void:
	if trail:
		trail.queue_free()

	trail = GPUParticles3D.new()
	trail.emitting = true
	trail.amount = 10
	trail.lifetime = projectile_data.trail_lifetime
	trail.one_shot = false
	trail.explosiveness = 0.0

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 0.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.2
	mat.gravity = Vector3.ZERO
	mat.scale_min = projectile_data.trail_width
	mat.scale_max = projectile_data.trail_width
	mat.color = projectile_data.trail_color
	trail.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	trail.draw_pass_1 = quad

	add_child(trail)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	lifetime_timer += delta
	if lifetime_timer >= projectile_data.lifetime:
		_expire()
		return

	# Apply gravity if configured
	if projectile_data.gravity_scale > 0:
		velocity.y -= gravity_value * projectile_data.gravity_scale * delta

	# Move
	global_position += velocity * delta

	# Face movement direction
	if velocity.length() > 0.1:
		look_at(global_position + velocity.normalized())


func _on_area_entered(area: Area3D) -> void:
	var target: Node = area.get_parent()
	_handle_collision(target)


func _on_body_entered(body: Node3D) -> void:
	_handle_collision(body)


func _handle_collision(target: Node) -> void:
	if not is_active or not target:
		return

	if target == owner_entity:
		return

	if target in hit_targets:
		return

	var is_enemy: bool = target.is_in_group("enemies")
	var is_player: bool = target.is_in_group("player")
	var is_world: bool = not is_enemy and not is_player

	if is_world:
		if projectile_data.hits_world:
			_on_hit_world()
		return

	if is_enemy and not projectile_data.hits_enemies:
		return
	if is_player and not projectile_data.hits_players:
		return

	hit_targets.append(target)
	var damage: int = projectile_data.roll_damage()

	if target.has_method("take_damage"):
		target.take_damage(damage, projectile_data.damage_type, owner_entity)
		hit_target.emit(target, damage)

	if projectile_data.stagger_power > 0 and target.has_method("apply_stagger"):
		target.apply_stagger(projectile_data.stagger_power)

	if projectile_data.knockback_force > 0 and target is CharacterBody3D:
		var knockback_dir: Vector3 = (target.global_position - global_position).normalized()
		knockback_dir.y = 0.2
		target.velocity += knockback_dir * projectile_data.knockback_force

	# AOE damage
	if projectile_data.aoe_radius > 0:
		_apply_aoe_damage()

	_expire()


func _on_hit_world() -> void:
	if projectile_data.aoe_radius > 0:
		_apply_aoe_damage()
	_expire()


func _apply_aoe_damage() -> void:
	var enemies: Array[Node] = CombatManager.get_enemies_in_range(global_position, projectile_data.aoe_radius)
	var base_damage: int = projectile_data.roll_damage()

	for enemy in enemies:
		if enemy in hit_targets:
			continue
		if not enemy is Node3D:
			continue

		var dist: float = global_position.distance_to((enemy as Node3D).global_position)
		var damage: int = base_damage

		if projectile_data.aoe_damage_falloff:
			var falloff: float = 1.0 - (dist / projectile_data.aoe_radius)
			damage = int(damage * falloff)

		damage = maxi(1, damage)

		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, projectile_data.damage_type, owner_entity)
			hit_targets.append(enemy)


func _expire() -> void:
	if not is_active:
		return

	expired.emit()

	if trail:
		trail.emitting = false

	if _pool:
		deactivate()
		returned_to_pool.emit()
	else:
		queue_free()


## Activate projectile (called by pool)
func activate() -> void:
	is_active = true
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	set_physics_process(true)
	set_deferred("monitoring", true)

	if trail:
		trail.emitting = true


## Deactivate projectile (called by pool)
func deactivate() -> void:
	is_active = false
	visible = false
	set_deferred("monitoring", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	if trail:
		trail.emitting = false

	hit_targets.clear()
	lifetime_timer = 0.0


## Set pool reference
func set_pool(pool: Node) -> void:
	_pool = pool
