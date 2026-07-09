## combat_manager.gd - Handles combat calculations and damage processing
## Architecture inspired by Quake 3: multi-point visibility, knockback system
extends Node

signal damage_dealt(attacker: Node, target: Node, damage: int, damage_type: Enums.DamageType)
signal entity_killed(entity: Node, killer: Node)

## Active combatants tracking
var active_enemies: Array[Node] = []
var active_allies: Array[Node] = []
var player: Node = null

## Projectile pool for all projectiles in the game
var projectile_pool: ProjectilePool = null

## Cleanup timer for invalid entities
var _cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 5.0

## Knockback settings (Quake 3 inspired)
const KNOCKBACK_SCALE: float = 1.0
const MAX_KNOCKBACK: float = 200.0


func _ready() -> void:
	projectile_pool = ProjectilePool.new()
	projectile_pool.name = "ProjectilePool"
	add_child(projectile_pool)


func _process(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_cleanup_invalid_entities()


## Register player reference
func register_player(player_node: Node) -> void:
	player = player_node


## Register an enemy
func register_enemy(enemy: Node) -> void:
	if enemy not in active_enemies:
		active_enemies.append(enemy)


## Unregister an enemy
func unregister_enemy(enemy: Node) -> void:
	active_enemies.erase(enemy)


## Register an ally
func register_ally(ally: Node) -> void:
	if ally not in active_allies:
		active_allies.append(ally)


## Unregister an ally
func unregister_ally(ally: Node) -> void:
	active_allies.erase(ally)


## Calculate bullet damage with optional knockback
func apply_bullet_damage(
	attacker: Node,
	target: Node,
	base_damage: int,
	damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL,
	knockback_force: float = 0.0,
	knockback_dir: Vector3 = Vector3.ZERO
) -> int:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0

	var total_damage: int = maxi(1, base_damage)
	var actual_damage: int = target.take_damage(total_damage, damage_type, attacker)

	# Apply knockback if target supports it
	if knockback_force > 0.0 and knockback_dir.length() > 0.1:
		_apply_knockback(target, knockback_dir, knockback_force, actual_damage)

	damage_dealt.emit(attacker, target, actual_damage, damage_type)

	if target.has_method("is_dead") and target.is_dead():
		entity_killed.emit(target, attacker)
		GameManager.on_enemy_killed()

	return actual_damage


## Apply knockback to a target (Quake 3 pattern: scales with damage, capped)
func _apply_knockback(target: Node, direction: Vector3, force: float, damage: int) -> void:
	if not target is CharacterBody3D:
		return

	var body := target as CharacterBody3D

	# Scale knockback with damage but cap it (Quake 3 pattern)
	var knockback_amount: float = minf(float(damage) * force * KNOCKBACK_SCALE, MAX_KNOCKBACK)

	# Apply horizontal knockback
	var knockback_vel: Vector3 = direction.normalized() * knockback_amount
	knockback_vel.y = knockback_amount * 0.3  # Slight upward kick

	body.velocity += knockback_vel


## Apply explosion damage with multi-point visibility (Quake 3 CanDamage pattern)
func apply_explosion_damage(
	center: Vector3,
	max_damage: int,
	min_damage: int,
	radius: float,
	attacker: Node,
	knockback_scale: float = 1.0
) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state

	# Damage player if in range
	if player and is_instance_valid(player) and player is Node3D:
		var player_pos: Vector3 = (player as Node3D).global_position
		var dist: float = center.distance_to(player_pos)
		if dist <= radius:
			# Multi-point visibility check (Quake 3 pattern)
			if _can_damage_multipoint(space_state, center, player_pos, player):
				var falloff: float = 1.0 - (dist / radius)
				var damage: int = maxi(1, int(lerpf(float(min_damage), float(max_damage), falloff)))

				if player.has_method("take_damage"):
					player.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker)

				# Apply knockback from explosion
				var knockback_dir: Vector3 = (player_pos - center).normalized()
				if knockback_dir.length() < 0.1:
					knockback_dir = Vector3.UP
				_apply_knockback(player, knockback_dir, knockback_scale * 2.0, damage)

	# Damage allies in range
	for ally in active_allies:
		if not is_instance_valid(ally) or not ally is Node3D:
			continue
		var ally_pos: Vector3 = (ally as Node3D).global_position
		var dist: float = center.distance_to(ally_pos)
		if dist <= radius:
			if _can_damage_multipoint(space_state, center, ally_pos, ally):
				var falloff: float = 1.0 - (dist / radius)
				var damage: int = maxi(1, int(lerpf(float(min_damage), float(max_damage), falloff)))
				# Asymmetric danger-close (War Room decree): indirect / ordnance fire
				# (attacker == null - arty, CAS, napalm, CBU, placed charges) does only
				# ~0.4x to your own men, so a called strike THREATENS but doesn't delete
				# the veterans you've grown to love. Direct fire (a real attacker) is full.
				if attacker == null:
					damage = maxi(1, int(float(damage) * 0.4))

				if ally.has_method("take_damage"):
					ally.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker)

				var knockback_dir: Vector3 = (ally_pos - center).normalized()
				if knockback_dir.length() < 0.1:
					knockback_dir = Vector3.UP
				_apply_knockback(ally, knockback_dir, knockback_scale * 2.0, damage)

	# Damage enemies in range
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var enemy_pos: Vector3 = (enemy as Node3D).global_position
		var dist: float = center.distance_to(enemy_pos)
		if dist <= radius:
			if _can_damage_multipoint(space_state, center, enemy_pos, enemy):
				var falloff: float = 1.0 - (dist / radius)
				var damage: int = maxi(1, int(lerpf(float(min_damage), float(max_damage), falloff)))

				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker)
					if enemy.has_method("apply_stagger"):
						enemy.apply_stagger(2.0)

				var knockback_dir: Vector3 = (enemy_pos - center).normalized()
				if knockback_dir.length() < 0.1:
					knockback_dir = Vector3.UP
				_apply_knockback(enemy, knockback_dir, knockback_scale * 2.0, damage)


## Multi-point visibility check (Quake 3 CanDamage pattern)
## Traces to 8 points around target bounds, returns true if ANY point is visible
func _can_damage_multipoint(space_state: PhysicsDirectSpaceState3D, from: Vector3, target_pos: Vector3, target: Node) -> bool:
	# Define 8 check points around target (corners of a box + center)
	var offsets: Array[Vector3] = [
		Vector3.ZERO,           # Center
		Vector3(0, 1.0, 0),     # Head
		Vector3(0, 0.5, 0),     # Torso
		Vector3(0.3, 0.5, 0),   # Right
		Vector3(-0.3, 0.5, 0),  # Left
		Vector3(0, 0.5, 0.3),   # Front
		Vector3(0, 0.5, -0.3),  # Back
		Vector3(0, 0.1, 0),     # Feet
	]

	var exclude_rids: Array[RID] = []
	if target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())

	for offset in offsets:
		var check_pos: Vector3 = target_pos + offset
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from,
			check_pos,
			1  # World collision layer only
		)
		query.exclude = exclude_rids

		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			# Clear line of sight to this point
			return true

	return false


## Apply suppression to nearby enemies (for sustained fire)
func apply_suppression_in_area(center: Vector3, radius: float, amount: float, exclude: Node = null) -> void:
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy == exclude:
			continue
		if not enemy is Node3D:
			continue

		var dist: float = center.distance_to((enemy as Node3D).global_position)
		if dist <= radius:
			var falloff: float = 1.0 - (dist / radius)
			if enemy.has_method("apply_suppression"):
				enemy.apply_suppression(amount * falloff)


## Remove any invalid/freed entities from tracking arrays
func _cleanup_invalid_entities() -> void:
	var valid_enemies: Array[Node] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	active_enemies = valid_enemies

	var valid_allies: Array[Node] = []
	for ally in active_allies:
		if is_instance_valid(ally):
			valid_allies.append(ally)
	active_allies = valid_allies


## Get all enemies in range of a point
func get_enemies_in_range(point: Vector3, range_dist: float) -> Array[Node]:
	var result: Array[Node] = []
	_cleanup_invalid_entities()
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node3D:
			var dist: float = (enemy as Node3D).global_position.distance_to(point)
			if dist <= range_dist:
				result.append(enemy)
	return result


## Get closest enemy to a point
func get_closest_enemy(point: Vector3, max_range: float = 100.0) -> Node:
	var closest: Node = null
	var closest_dist: float = max_range

	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node3D:
			var dist: float = (enemy as Node3D).global_position.distance_to(point)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy

	return closest


## Check line of sight between two positions
func has_line_of_sight(from_pos: Vector3, to_pos: Vector3, exclude: Array[Node] = []) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_pos,
		to_pos,
		1  # World collision layer
	)
	for node in exclude:
		if node is CollisionObject3D:
			query.exclude.append((node as CollisionObject3D).get_rid())
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()


## Spawn a projectile from the pool
func spawn_projectile(data: ProjectileData, source: Node, spawn_position: Vector3, direction: Vector3, target: Node3D = null) -> ProjectileBase:
	if not projectile_pool:
		push_warning("[CombatManager] Projectile pool not initialized!")
		return null
	return projectile_pool.spawn(data, source, spawn_position, direction, target)


## Spawn a projectile aimed at a specific position
func spawn_projectile_at_target(data: ProjectileData, source: Node, spawn_position: Vector3, target_position: Vector3, target: Node3D = null) -> ProjectileBase:
	if not projectile_pool:
		push_warning("[CombatManager] Projectile pool not initialized!")
		return null
	return projectile_pool.spawn_at_target(data, source, spawn_position, target_position, target)


## Clear all active projectiles
func clear_all_projectiles() -> void:
	if projectile_pool:
		projectile_pool.clear_all()
