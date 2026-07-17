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

## FUZE STATE: how far this warhead has flown, and whether that was far enough
## to arm it. A real RPG round is drop-safe and arms on setback + a few metres of
## travel - fire it into the dirt at your feet and you get a clang, not a crater.
var traveled: float = 0.0


## The shooter and his own hitzones - a warhead must not detonate on the man
## who fired it as it leaves the tube.
var _exclude_rids: Array[RID] = []


func is_armed() -> bool:
	return projectile_data == null or traveled >= projectile_data.arming_distance

## Pool reference
var _pool: Node = null

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 256  # Layer 9 - projectiles
	collision_mask = 0     # set per-projectile in initialize(), from hits_* flags

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
	traveled = 0.0          # fresh fuze: the metres start counting at the muzzle
	hit_targets.clear()
	_exclude_rids.clear()
	if source is CollisionObject3D:
		_exclude_rids.append((source as CollisionObject3D).get_rid())
	if source is Node:
		for c in (source as Node).get_children():
			if c is CollisionObject3D:   # the shooter's own hitzones
				_exclude_rids.append((c as CollisionObject3D).get_rid())

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


## Build the visual: the data's mesh_path scene if it has one, else a procedural
## rocket cone (aoe_radius > 0) or bullet.
func _setup_visuals() -> void:
	if not projectile_data:
		return
	mesh_instance.scale = projectile_data.scale
	if not projectile_data.mesh_path.is_empty():
		var packed: PackedScene = load(projectile_data.mesh_path)
		if packed != null:
			for c in mesh_instance.get_children():
				c.queue_free()
			mesh_instance.add_child(packed.instantiate())
			mesh_instance.mesh = null
			return
	mesh_instance.mesh = _rocket_mesh() if projectile_data.aoe_radius > 0.0 else _bullet_mesh()


## Warhead: a fat cone with a bright, unshaded skin so it reads at 100m through
## jungle. No light - perf-first rule, and the trail already sells it.
static func _rocket_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.09
	m.height = 0.34
	m.radial_segments = 8
	m.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.29, 0.24)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.material = mat
	return m


static func _bullet_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.03
	m.height = 0.06
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	return m


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

	# Rockets get a fat, drifting smoke column; bullets keep the fine tracer dust.
	var is_rocket: bool = projectile_data.aoe_radius > 0.0
	if is_rocket:
		trail.amount = 48
		trail.lifetime = maxf(projectile_data.trail_lifetime, 1.1)
		mat.initial_velocity_min = 0.2
		mat.initial_velocity_max = 0.9
		mat.gravity = Vector3(0, 0.35, 0)          # smoke rises
		mat.scale_min = projectile_data.trail_width
		mat.scale_max = projectile_data.trail_width * 3.2
		mat.damping_min = 0.4
		mat.damping_max = 1.2

	var quad := QuadMesh.new()
	var s: float = 0.16 if is_rocket else 0.02
	quad.size = Vector2(s, s)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qmat.vertex_color_use_as_albedo = true
	qmat.albedo_color = projectile_data.trail_color
	quad.material = qmat
	trail.draw_pass_1 = quad

	add_child(trail)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	lifetime_timer += delta
	if lifetime_timer >= projectile_data.lifetime:
		# SELF-DESTRUCT, not a silent vanish: a warhead that reaches the end of its
		# run detonates (real PG-7 rounds self-destruct at 3.8-6s). A round that
		# never ARMED is just falling scrap - it does not blow.
		if projectile_data.aoe_radius > 0.0 and projectile_data.self_destruct and is_armed():
			_apply_aoe_damage()
		_expire()
		return

	# Apply gravity if configured
	if projectile_data.gravity_scale > 0:
		velocity.y -= gravity_value * projectile_data.gravity_scale * delta

	# SEGMENT CAST, not overlap: at 84 m/s a warhead crosses 1.4m per physics tick,
	# so Area3D overlap detection MISSES anything thinner than that (it would fly
	# through a wall). Sweep the step and stop at what it crosses, as BulletSystem does.
	var step: Vector3 = velocity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + step
	var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = _exclude_rids
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		traveled += from.distance_to(hit.position)
		global_position = hit.position
		var col: Object = hit.collider
		var struck: Node = null
		if col is Hitzone:
			struck = (col as Hitzone).owner_entity
		elif col is Area3D:
			struck = (col as Area3D).get_parent()
		elif col is Node:
			struck = col as Node
		_handle_collision(struck)
		return

	traveled += step.length()   # the fuze counts metres, not seconds
	global_position = to

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

	# DUD: the fuze never armed (fired at something inside the arming distance).
	# The warhead still ARRIVES - 1.8kg of steel at 84 m/s ruins the man it hits -
	# it simply does not detonate. No AOE, no fireball, no crater.
	if not is_armed():
		var kinetic: int = maxi(1, int(float(projectile_data.get_damage()) * projectile_data.dud_impact_frac))
		if target.has_method("take_damage"):
			target.take_damage(kinetic, Enums.DamageType.PHYSICAL, owner_entity)
			hit_target.emit(target, kinetic)
		_dud_impact()
		return

	var damage: int = projectile_data.get_damage()

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
	# Fire it into the dirt at your feet and you get a CLANG, not a crater.
	if not is_armed():
		_dud_impact()
		return
	if projectile_data.aoe_radius > 0:
		_apply_aoe_damage()
	_expire()


## An unarmed warhead striking anything: hard impact, a puff, and a piece of
## ordnance lying there inert. No detonation.
func _dud_impact() -> void:
	var scene: Node = get_tree().current_scene
	var n: Vector3 = -velocity.normalized() if velocity.length() > 0.1 else Vector3.UP
	GunFX.impact(scene, global_position, n, true)
	print("[FUZE] %s struck at %.1fm - UNARMED (arms at %.1fm): no detonation" % [
		projectile_data.id, traveled, projectile_data.arming_distance])
	_expire()


## MUST route through the same 8-point-visibility explosion the grenades use: it
## is FACTION-BLIND, does knockback, and respects cover. (A faction-scoped query
## here would let an enemy rocket never touch the player.)
func _apply_aoe_damage() -> void:
	# ADR-016 Amendment F: a rocket outclasses a grenade. The centre is death; the
	# rim (0.15 of centre) still puts a man down - fragments and overpressure.
	var base_damage: int = projectile_data.get_damage()
	var min_damage: int = maxi(1, int(float(base_damage) * 0.15))
	CombatManager.apply_explosion_damage(
		global_position,
		base_damage,
		min_damage,
		projectile_data.aoe_radius,
		owner_entity,
		maxf(projectile_data.knockback_force, 1.0))
	GunFX.play_explosion_3d(get_tree().current_scene, global_position, "explosion_rocket")
	if DamageSystem.has_method("apply_damage"):
		DamageSystem.apply_damage(global_position, DamageSystem.DamageType.SMALL_EXPLOSION, 0.7)


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
