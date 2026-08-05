## combat_manager.gd - Handles combat calculations and damage processing
## Architecture inspired by Quake 3: multi-point visibility, knockback system
extends Node

var player: Node = null

## Projectile pool for all projectiles in the game
var projectile_pool: ProjectilePool = null

## Real bullet simulation - every small-arms round in the game.
var bullets: BulletSystem = null

## W0 ray census - monotonic totals bumped at every AI/bullet raycast site; perf
## overlays and probes read deltas. perception/witness rays also pass through
## has_line_of_sight, so rays_los is their superset, not a disjoint class.
var rays_los: int = 0
var rays_perception: int = 0
var rays_witness: int = 0
var rays_cover: int = 0
var rays_bullet: int = 0

## W0 physics-side CPU buckets - usec accumulated inside enemy/ally
## _physics_process, reported by the arena at 1Hz via report_cpu_bucket.
var ai_usec_think: int = 0
var ai_usec_move: int = 0
var ai_usec_hitzone: int = 0
var ai_usec_anim: int = 0

## WA-A2 body-gate census - monotonic per-agent-tick totals like rays_*;
## overlays and probes read deltas.
var bodies_run: int = 0
var bodies_gated: int = 0

## WA-A2 perceivability oracle (A1's PerceptionServer absorbs this later; C1's
## FX gate reuses it). Cheap by contract: distance + one dot against the player
## camera - no rays, no VisibleOnScreenNotifier3D, so it is headless-valid and
## probes drive it by placing the camera. No player = no observer: stay hot.
const PERCEIVE_RANGE: float = 150.0
const PERCEIVE_NEAR: float = 20.0


func perceivable(actor: Node3D) -> bool:
	var player_node := GameManager.player as Node3D
	if player_node == null or not is_instance_valid(player_node):
		return true
	var vp: Viewport = actor.get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	var eye: Transform3D = cam.global_transform if cam != null else player_node.global_transform
	var to_actor: Vector3 = actor.global_position - eye.origin
	var dist: float = to_actor.length()
	if dist > PERCEIVE_RANGE:
		return false
	if dist <= PERCEIVE_NEAR:
		return true
	return (-eye.basis.z).dot(to_actor / dist) > 0.0

## Knockback: blast SHOVE, not blast LAUNCH (realistic-combat pillar). A near miss
## staggers a man a step; the dead crumple via the ragdoll doctrine, they do not
## fly.
const KNOCKBACK_SCALE: float = 0.05
const MAX_KNOCKBACK: float = 6.0


func _ready() -> void:
	projectile_pool = ProjectilePool.new()
	projectile_pool.name = "ProjectilePool"
	add_child(projectile_pool)
	bullets = BulletSystem.new()
	bullets.name = "BulletSystem"
	add_child(bullets)


## Register player reference
func register_player(player_node: Node) -> void:
	player = player_node


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


## Blast damage curve: FULL damage inside the kill plateau (40% of radius - a
## grenade in a fireteam's lap WIPES it), then a linear taper to the edge. A pure
## linear falloff is NOT enough: it lets men 4m from an M26 shrug it off.
func _explosion_damage_at(dist: float, radius: float, max_damage: int, min_damage: int) -> int:
	var plateau: float = radius * 0.4
	if dist <= plateau:
		return max_damage
	var t: float = clampf((dist - plateau) / maxf(0.01, radius - plateau), 0.0, 1.0)
	return maxi(1, int(lerpf(float(max_damage), float(min_damage), t)))


## Apply explosion damage with multi-point visibility (Quake 3 CanDamage pattern)
func apply_explosion_damage(
	center: Vector3,
	max_damage: int,
	min_damage: int,
	radius: float,
	attacker: Node,
	knockback_scale: float = 1.0,
	spare_garrison: bool = false
) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state

	# Damage player if in range
	if player and is_instance_valid(player) and player is Node3D:
		var player_pos: Vector3 = (player as Node3D).global_position
		var dist: float = center.distance_to(player_pos)
		if dist <= radius:
			# Multi-point visibility check (Quake 3 pattern)
			var pmult: float = _blast_multiplier(space_state, center, player_pos, player, max_damage)
			if pmult > 0.0:
				var damage: int = maxi(1, int(float(_explosion_damage_at(dist, radius, max_damage, min_damage)) * pmult))

				if player.has_method("take_damage"):
					player.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker)

				# Apply knockback from explosion
				var knockback_dir: Vector3 = (player_pos - center).normalized()
				if knockback_dir.length() < 0.1:
					knockback_dir = Vector3.UP
				_apply_knockback(player, knockback_dir, knockback_scale * 2.0, damage)

	# Damage allies in range. ITERATE A SNAPSHOT: a kill unregisters the man from
	# this very array mid-loop, which shifts it and SKIPS his neighbour.
	for ally in AgentRegistry.allies.duplicate():
		if not is_instance_valid(ally) or not ally is Node3D:
			continue
		var ally_pos: Vector3 = (ally as Node3D).global_position
		var dist: float = center.distance_to(ally_pos)
		if dist <= radius:
			var amult: float = _blast_multiplier(space_state, center, ally_pos, ally, max_damage)
			if amult > 0.0:
				var damage: int = maxi(1, int(float(_explosion_damage_at(dist, radius, max_damage, min_damage)) * amult))
				# Asymmetric danger-close: INDIRECT fire (attacker == null - arty, CAS,
				# napalm, CBU, placed charges) does only ~0.4x to your own men, so a
				# called strike threatens without deleting your squad. Direct fire is full.
				if attacker == null:
					damage = maxi(1, int(float(damage) * 0.4))

				if ally.has_method("take_damage"):
					ally.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker)

				var knockback_dir: Vector3 = (ally_pos - center).normalized()
				if knockback_dir.length() < 0.1:
					knockback_dir = Vector3.UP
				_apply_knockback(ally, knockback_dir, knockback_scale * 2.0, damage)

	# Noncombatants take blast like anyone else - snapshot for the same reason.
	for civ in AgentRegistry.civilians.duplicate():
		if not is_instance_valid(civ) or not civ is Node3D:
			continue
		# A placed satchel spares the noncombatant garrison by decree (Pillar 5):
		# men who cannot react are not deleted in a scripted breach.
		if spare_garrison and civ.get("is_garrison") == true:
			continue
		var civ_pos: Vector3 = (civ as Node3D).global_position
		var civ_dist: float = center.distance_to(civ_pos)
		if civ_dist <= radius:
			var cmult: float = _blast_multiplier(space_state, center, civ_pos, civ, max_damage)
			if cmult > 0.0:
				var damage: int = maxi(1, int(float(_explosion_damage_at(civ_dist, radius, max_damage, min_damage)) * cmult))
				if civ.has_method("take_damage"):
					civ.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker, "BODY")

	# Traps and other damageable world objects. No knockback, no stagger - a pit
	# in the ground is destroyed or it is not.
	for prop in AgentRegistry.props.duplicate():
		if not is_instance_valid(prop) or not prop is Node3D:
			continue
		var prop_pos: Vector3 = (prop as Node3D).global_position
		var prop_dist: float = center.distance_to(prop_pos)
		if prop_dist <= radius and prop.has_method("take_damage"):
			prop.take_damage(_explosion_damage_at(prop_dist, radius, max_damage, min_damage),
				Enums.DamageType.EXPLOSIVE, attacker, "BODY")

	# Damage enemies in range - snapshot for the same mid-loop-kill reason.
	for enemy in AgentRegistry.enemies.duplicate():
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var enemy_pos: Vector3 = (enemy as Node3D).global_position
		var dist: float = center.distance_to(enemy_pos)
		if dist <= radius:
			var emult: float = _blast_multiplier(space_state, center, enemy_pos, enemy, max_damage)
			if emult > 0.0:
				var damage: int = maxi(1, int(float(_explosion_damage_at(dist, radius, max_damage, min_damage)) * emult))

				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, Enums.DamageType.EXPLOSIVE, attacker)
					if enemy.has_method("apply_stagger"):
						enemy.apply_stagger(2.0)

				var knockback_dir: Vector3 = (enemy_pos - center).normalized()
				if knockback_dir.length() < 0.1:
					knockback_dir = Vector3.UP
				_apply_knockback(enemy, knockback_dir, knockback_scale * 2.0, damage)

	# A blast that misses you still puts you in the dirt (Pillar 1). Before this, NOTHING
	# routed through this function suppressed anyone - not a grenade, not an RPG, not the
	# mortars, not a 40mm shell from Spooky. The only two callers of apply_suppression_in_area
	# repo-wide were the player's own muzzle and the CAS bomb, so 30 seconds of gunship fire
	# inside the wire changed nobody's behaviour unless it killed them outright.
	apply_suppression_in_area(center, radius * SUPPRESS_RADIUS_MULT,
		clampf(float(max_damage) / SUPPRESS_DAMAGE_FULL, 0.15, 1.0))


## What a blast does to the men it does NOT hit. The kill radius is small on purpose (a 40mm
## is lethal at 5m) but the fear reaches much further, so suppression runs on a multiple of it.
##
## 2.5 is not a taste call: it is the ratio the project had already authored for the one
## explosion that DID suppress - FirePlan's bomb, 40m of suppression around a 16m blast. Every
## other explosive now inherits that same relationship instead of a second invented number.
const SUPPRESS_RADIUS_MULT: float = 2.5
## Damage at which a blast fully suppresses at the centre. An M26 (190) and anything heavier
## pins; a rifle-grade pop still rattles.
const SUPPRESS_DAMAGE_FULL: float = 190.0


## COVER DEFEAT (Summoner ruling 2026-08-04, at the gun range: "the rpg thumper grenades
## and any bombs and stuff can penetrate sandbags and bunkers 50 percent of the time or
## something like that"). Explosives only - bullets keep the absolute hard stop in
## bullet_system. Damage through defeated cover is bled, not full: the wall soaks part
## of the pressure even when it fails the man behind it.
const BLAST_THROUGH_COVER_MULT: float = 0.6
## Untagged colliders (terrain heightmap) and these families stay absolute: meters of
## earth stop blast outright, and the compound mound/berm double as the ground itself -
## a 50% roll there would half-disarm the wire against every arty shell.
const BLAST_PROOF_PREFIXES: Array[String] = ["fb_terrain_mound", "fb_berm_ring"]


## Defeat chance per blast, keyed to ordnance class via max_damage: his 50% floor for
## grenade/thumper grade, rising for rockets (LAW/RPG-2 ~0.66, RPG-7 0.75 cap).
static func _blast_defeat_chance(max_damage: int) -> float:
	return clampf(float(max_damage) / 380.0, 0.5, 0.75)


## Multi-point blast reach (Quake 3 CanDamage pattern + cover defeat). Traces to 8
## points around target bounds. Returns the damage multiplier: 1.0 with any clear line,
## 0.0 fully blocked by blast-proof cover, BLAST_THROUGH_COVER_MULT when the blast
## defeats the cover - soft cover (thatch/canvas) always fails, hard cover
## (sandbag/bunker/masonry) fails on the per-target roll.
func _blast_multiplier(space_state: PhysicsDirectSpaceState3D, from: Vector3, target_pos: Vector3, target: Node, max_damage: int) -> float:
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

	var soft_blocker: bool = false
	var hard_blocker: bool = false
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
			return 1.0
		var blocker: Object = result.collider
		if blocker is Node:
			var bn := blocker as Node
			if bn.is_in_group("soft_cover"):
				soft_blocker = true
			elif bn.is_in_group("hard_surface") and not _blast_proof(bn):
				hard_blocker = true

	if soft_blocker:
		return BLAST_THROUGH_COVER_MULT
	if hard_blocker and randf() < _blast_defeat_chance(max_damage):
		return BLAST_THROUGH_COVER_MULT
	return 0.0


static func _blast_proof(blocker: Node) -> bool:
	var nm := String(blocker.name)
	for p in BLAST_PROOF_PREFIXES:
		if nm.begins_with(p):
			return true
	return false


## Apply suppression to nearby enemies (for sustained fire)
func apply_suppression_in_area(center: Vector3, radius: float, amount: float, exclude: Node = null) -> void:
	for enemy in AgentRegistry.enemies:
		if not is_instance_valid(enemy) or enemy == exclude:
			continue
		if not enemy is Node3D:
			continue

		var dist: float = center.distance_to((enemy as Node3D).global_position)
		if dist <= radius:
			var falloff: float = 1.0 - (dist / radius)
			if enemy.has_method("apply_suppression"):
				enemy.apply_suppression(amount * falloff)


	# Suppression is faction-blind: nearby friendly AI feel the rounds/blast too.
	for ally in AgentRegistry.allies:
		if not is_instance_valid(ally) or ally == exclude or not ally is Node3D:
			continue
		var dist_a: float = center.distance_to((ally as Node3D).global_position)
		if dist_a <= radius and ally.has_method("apply_suppression"):
			ally.apply_suppression(amount * (1.0 - dist_a / radius))

	# ...and so does the man holding the camera. He was the one body this loop skipped, so
	# shells could land inside his own compound and every AI on both sides would flinch while
	# the player's screen sat perfectly still.
	if player != null and is_instance_valid(player) and player != exclude and player is Node3D:
		var dist_p: float = center.distance_to((player as Node3D).global_position)
		if dist_p <= radius and player.has_method("add_suppression"):
			player.add_suppression(amount * (1.0 - dist_p / radius))


## Get all enemies in range of a point
func get_enemies_in_range(point: Vector3, range_dist: float) -> Array[Node]:
	var result: Array[Node] = []
	for enemy in AgentRegistry.enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node3D:
			var dist: float = (enemy as Node3D).global_position.distance_to(point)
			if dist <= range_dist:
				result.append(enemy)
	return result


## Check line of sight between two positions
func has_line_of_sight(from_pos: Vector3, to_pos: Vector3, exclude: Array[Node] = []) -> bool:
	rays_los += 1
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
	# Every flying explosive promotes trunk colliders down its corridor (decree
	# 2026-08-04), so a canopy contact is possible wherever ordnance goes.
	if data != null and data.aoe_radius > 0.0:
		var reach: float = minf(data.speed * data.lifetime, 250.0)
		TreeCoverLayer.threat_corridor(get_tree(), spawn_position,
			spawn_position + direction.normalized() * reach, data.aoe_radius + 3.0, 10.0)
	return projectile_pool.spawn(data, source, spawn_position, direction, target)
