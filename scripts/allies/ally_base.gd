## ally_base.gd - Allied soldier AI that fights alongside the player
## Goal-driven architecture matching enemy AI for tactical combat
class_name AllyBase
extends CharacterBody3D

signal died(ally: AllyBase)
signal state_changed(new_state: Enums.AIState)

## Stats
var max_hp: int = 80
var current_hp: int = 80
var move_speed: float = 4.5
var preferred_range: float = 12.0

## Weapon
var weapon_data: WeaponData = null
var fire_timer: float = 0.0
var can_fire: bool = true

## AI State
var current_state: Enums.AIState = Enums.AIState.IDLE
var current_goal: Enums.AIGoal = Enums.AIGoal.NONE
var state_timer: float = 0.0

## Think system (like Quake 3 - separate from execution)
var think_timer: float = 0.0
const THINK_INTERVAL: float = 0.15

## Target (enemies)
var target: Node3D = null
var last_known_target_pos: Vector3 = Vector3.ZERO
var has_line_of_sight: bool = false

## Aim interpolation
var current_aim_dir: Vector3 = Vector3.FORWARD
var target_aim_dir: Vector3 = Vector3.FORWARD
var aim_speed: float = 7.0

## Follow player
var follow_distance: float = 5.0
var max_follow_distance: float = 15.0

## Combat behavior
var strafe_direction: float = 0.0
var strafe_timer: float = 0.0
var shots_fired: int = 0
var burst_count: int = 0
const MAX_BURST: int = 6

## Suppression
var suppression_level: float = 0.0
const SUPPRESSION_DECAY: float = 0.4

## Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Visual
var mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("allies")
	CombatManager.register_ally(self)

	# Load Thompson as default weapon for allies
	weapon_data = load("res://data/weapons/thompson.tres")

	_setup_visual()
	_setup_hurtbox()

	current_aim_dir = -global_transform.basis.z


func _setup_visual() -> void:
	mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	mesh.mesh = capsule
	mesh.position.y = 0.9

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.35, 0.25)  # Olive drab (US Army)
	mesh.material_override = mat

	add_child(mesh)


func _setup_hurtbox() -> void:
	_create_hitzone(Hitzone.ZoneType.HEAD, Vector3(0, 1.65, 0), 0.15)
	_create_hitzone(Hitzone.ZoneType.TORSO, Vector3(0, 1.1, 0), 0.3, 0.6)
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(-0.35, 1.0, 0), 0.12, 0.5)
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(0.35, 1.0, 0), 0.12, 0.5)
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(-0.12, 0.4, 0), 0.12, 0.8)
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(0.12, 0.4, 0), 0.12, 0.8)


func _create_hitzone(zone_type: Hitzone.ZoneType, pos: Vector3, radius: float, height: float = -1.0) -> void:
	var hitzone := Hitzone.new()
	hitzone.zone_type = zone_type
	hitzone.set_owner_entity(self)

	var col := CollisionShape3D.new()
	if height > 0:
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = height
		col.shape = shape
	else:
		var shape := SphereShape3D.new()
		shape.radius = radius
		col.shape = shape

	col.position = pos
	hitzone.add_child(col)

	# Allies use player hurtbox layer (enemies shoot at them too)
	hitzone.collision_layer = 32  # Layer 6: player_hurtbox
	hitzone.collision_mask = 16   # Layer 5: enemy_hitbox

	hitzone.add_to_group("ally_hurtbox")
	hitzone.add_to_group("hitzone")

	add_child(hitzone)


func _physics_process(delta: float) -> void:
	if current_state == Enums.AIState.DEAD:
		return

	# Cap delta for framerate independence
	var capped_delta: float = minf(delta, 0.066)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * capped_delta

	# Decay suppression
	if suppression_level > 0:
		suppression_level = maxf(0.0, suppression_level - SUPPRESSION_DECAY * capped_delta)

	# Update fire timer
	if not can_fire:
		fire_timer -= capped_delta
		if fire_timer <= 0:
			can_fire = true

	# Think on schedule
	think_timer += capped_delta
	if think_timer >= THINK_INTERVAL:
		think_timer = 0.0
		_think()

	# Execute every frame
	_execute(capped_delta)

	move_and_slide()


func _think() -> void:
	_find_target()
	_update_line_of_sight()
	_evaluate_goals()


func _find_target() -> void:
	# Find closest living enemy
	var closest_enemy: Node3D = null
	var closest_dist: float = 40.0

	for enemy in CombatManager.active_enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var dist := global_position.distance_to((enemy as Node3D).global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy as Node3D

	target = closest_enemy


func _update_line_of_sight() -> void:
	if not target:
		has_line_of_sight = false
		return

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := target.global_position + Vector3.UP * 1.0

	has_line_of_sight = CombatManager.has_line_of_sight(eye_pos, target_pos, [self])

	if has_line_of_sight:
		last_known_target_pos = target.global_position


func _evaluate_goals() -> void:
	# If suppressed, seek cover
	if suppression_level > 0.6:
		current_goal = Enums.AIGoal.SEEK_COVER
		_change_state(Enums.AIState.SEEKING_COVER)
		return

	# If we have a target with LOS, engage
	if target and has_line_of_sight:
		current_goal = Enums.AIGoal.ENGAGE_TARGET
		_change_state(Enums.AIState.COMBAT)
		return

	# Otherwise follow player
	current_goal = Enums.AIGoal.HOLD_POSITION
	_change_state(Enums.AIState.IDLE)


func _execute(delta: float) -> void:
	state_timer += delta

	# Update aim
	_update_aim(delta)

	match current_state:
		Enums.AIState.IDLE:
			_execute_idle(delta)
		Enums.AIState.COMBAT:
			_execute_combat(delta)
		Enums.AIState.SEEKING_COVER:
			_execute_seeking_cover(delta)


func _update_aim(delta: float) -> void:
	if not target or not has_line_of_sight:
		return

	var target_pos: Vector3 = target.global_position + Vector3.UP * 1.0
	var eye_pos: Vector3 = global_position + Vector3.UP * 1.5

	target_aim_dir = (target_pos - eye_pos).normalized()
	current_aim_dir = current_aim_dir.lerp(target_aim_dir, aim_speed * delta).normalized()

	# Face target
	var flat_aim: Vector3 = current_aim_dir
	flat_aim.y = 0
	if flat_aim.length() > 0.1:
		look_at(global_position + flat_aim)


func _execute_idle(delta: float) -> void:
	# Follow player if too far
	var player := GameManager.player
	if player and is_instance_valid(player) and player is Node3D:
		var dist := global_position.distance_to((player as Node3D).global_position)

		if dist > follow_distance:
			_move_toward((player as Node3D).global_position, delta)
		else:
			velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)


func _execute_combat(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_change_state(Enums.AIState.IDLE)
		return

	if target.has_method("is_dead") and target.is_dead():
		target = null
		_change_state(Enums.AIState.IDLE)
		return

	var dist := global_position.distance_to(target.global_position)

	# Update strafe timer
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_direction = [-1.0, 0.0, 1.0].pick_random()
		strafe_timer = randf_range(1.5, 3.0)

	if has_line_of_sight:
		# Movement based on range
		var move_dir := Vector3.ZERO

		if dist > preferred_range * 1.2:
			move_dir = (target.global_position - global_position).normalized()
		elif dist < preferred_range * 0.6:
			move_dir = (global_position - target.global_position).normalized()

		# Apply strafe
		if strafe_direction != 0.0:
			var strafe_vec := transform.basis.x * strafe_direction
			move_dir = (move_dir + strafe_vec * 0.4).normalized()

		move_dir.y = 0
		if move_dir.length() > 0.1:
			velocity.x = lerpf(velocity.x, move_dir.x * move_speed * 0.6, delta * 8.0)
			velocity.z = lerpf(velocity.z, move_dir.z * move_speed * 0.6, delta * 8.0)
		else:
			velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)

		# Fire at target
		if can_fire and suppression_level < 0.5:
			if burst_count < MAX_BURST:
				_fire_at_target()
				burst_count += 1
			else:
				can_fire = false
				fire_timer = randf_range(0.3, 1.0)
				burst_count = 0
				shots_fired = 0
	else:
		# Lost sight - move toward target
		_move_toward(last_known_target_pos, delta)

		state_timer += delta
		if state_timer > 3.0:
			_change_state(Enums.AIState.IDLE)


func _execute_seeking_cover(delta: float) -> void:
	# Move perpendicular to nearest enemy
	if target:
		var to_target := (target.global_position - global_position).normalized()
		var perpendicular := Vector3(-to_target.z, 0, to_target.x)

		if strafe_direction == 0.0:
			strafe_direction = [-1.0, 1.0].pick_random()

		var move_dir := (perpendicular * strafe_direction - to_target * 0.2).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed

	# Exit after moving
	if state_timer > 2.0:
		_change_state(Enums.AIState.IDLE)


func _change_state(new_state: Enums.AIState) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	state_timer = 0.0
	state_changed.emit(new_state)


func _move_toward(pos: Vector3, delta: float) -> void:
	var direction := (pos - global_position).normalized()
	direction.y = 0
	velocity.x = lerpf(velocity.x, direction.x * move_speed, delta * 8.0)
	velocity.z = lerpf(velocity.z, direction.z * move_speed, delta * 8.0)


## Gun muzzle world position (mirrors EnemyBase.get_muzzle_position).
func get_muzzle_position(aim_dir: Vector3) -> Vector3:
	var flat_aim := Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()
	var right := flat_aim.cross(Vector3.UP).normalized() * -0.22
	return global_position + Vector3.UP * 1.35 + flat_aim * 0.55 + right


func _fire_at_target() -> void:
	if not weapon_data or not target:
		return

	can_fire = false
	fire_timer = weapon_data.get_fire_delay()
	shots_fired += 1

	# Use smoothly interpolated aim
	var final_aim: Vector3 = current_aim_dir

	# Add spread
	var spread: float = deg_to_rad(weapon_data.base_spread * 1.2 + float(shots_fired) * 0.05)
	final_aim.x += randf_range(-spread, spread)
	final_aim.y += randf_range(-spread, spread)
	final_aim.z += randf_range(-spread, spread)
	final_aim = final_aim.normalized()

	# Raycast from the gun muzzle (R03).
	var origin: Vector3 = get_muzzle_position(final_aim)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_aim * weapon_data.max_range,
		1 | 4 | 64  # World, enemies, enemy hurtboxes
	)
	query.exclude = [self]

	var result := space_state.intersect_ray(query)

	var tracer_end: Vector3 = origin + final_aim * weapon_data.max_range
	if result:
		tracer_end = result.position
	BulletTracer.spawn_tracer(get_tree().current_scene, origin, tracer_end, Color(1.0, 0.85, 0.4, 1.0))

	if result:
		var hit_target: Object = result.collider
		if hit_target:
			var damage_target: Node = null
			var damage_multiplier: float = 1.0

			if hit_target is Hitzone:
				var hitzone := hit_target as Hitzone
				damage_target = hitzone.owner_entity
				damage_multiplier = hitzone.get_damage_multiplier()
			elif hit_target is Node and (hit_target as Node).is_in_group("enemies"):
				damage_target = hit_target as Node
			elif hit_target is Node and (hit_target as Node).get_parent() and (hit_target as Node).get_parent().is_in_group("enemies"):
				damage_target = (hit_target as Node).get_parent()

			if damage_target and damage_target.has_method("take_damage"):
				var base_damage := weapon_data.roll_damage()
				var final_damage := int(base_damage * damage_multiplier)
				damage_target.take_damage(final_damage, weapon_data.damage_type, self)


## Take damage
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, _attacker: Node = null) -> int:
	if current_state == Enums.AIState.DEAD:
		return 0

	current_hp -= amount

	# Visual feedback
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(func():
			if mesh and mesh.material_override:
				mesh.material_override.albedo_color = Color(0.3, 0.35, 0.25)
		)

	# Add suppression
	suppression_level = minf(1.0, suppression_level + 0.3)

	# Check death
	if current_hp <= 0:
		current_hp = 0
		_die()

	return amount


func apply_suppression(amount: float) -> void:
	suppression_level = minf(1.0, suppression_level + amount)


func _die() -> void:
	_change_state(Enums.AIState.DEAD)
	CombatManager.unregister_ally(self)
	died.emit(self)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if mesh:
		mesh.rotation_degrees.x = 90

	get_tree().create_timer(5.0).timeout.connect(queue_free)


func is_dead() -> bool:
	return current_state == Enums.AIState.DEAD


## Static factory for spawning allies
static func spawn_ally(parent: Node, pos: Vector3) -> AllyBase:
	var ally := AllyBase.new()

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	ally.add_child(col)

	ally.collision_layer = 2  # Player layer (so enemies target them)
	ally.collision_mask = 1   # World

	parent.add_child(ally)
	ally.global_position = pos

	return ally
