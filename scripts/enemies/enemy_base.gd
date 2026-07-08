## enemy_base.gd - Goal-driven tactical AI for deadly WW2 combat
## Architecture inspired by Quake 3/Spearmint: separate think rate from execution
class_name EnemyBase
extends CharacterBody3D

signal died(enemy: EnemyBase)
signal state_changed(new_state: Enums.AIState)

## Enemy data resource
@export var enemy_data_path: String = ""
var enemy_data: EnemyData = null

## Stats
var max_hp: int = 80
var current_hp: int = 80
var move_speed: float = 4.0
var preferred_range: float = 15.0

## Weapon
var weapon_data: WeaponData = null
var fire_timer: float = 0.0
var can_fire: bool = true

## ============================================
## GOAL-DRIVEN AI SYSTEM (Quake 3 inspired)
## ============================================

## Current goal and state
var current_goal: Enums.AIGoal = Enums.AIGoal.NONE
var current_state: Enums.AIState = Enums.AIState.IDLE
var personality: Enums.AIPersonality = Enums.AIPersonality.BALANCED
var state_timer: float = 0.0
var goal_timer: float = 0.0

## Think system - separate from execution (like Quake 3 bots)
var think_timer: float = 0.0
const THINK_INTERVAL: float = 0.15  # 6-7 Hz thinking, execution every frame
var last_think_time: float = 0.0

## W86: think-LOD - distant brains tick slower (checked every 2s).
var _think_interval_current: float = THINK_INTERVAL
var _lod_timer: float = 0.0


func _update_think_lod(delta: float) -> void:
	_lod_timer += delta
	if _lod_timer < 2.0:
		return
	_lod_timer = 0.0
	var player := GameManager.player as Node3D
	if player == null:
		_think_interval_current = 0.6
		return
	var d: float = global_position.distance_to(player.global_position)
	if d > 150.0:
		_think_interval_current = 0.6
	elif d > 80.0:
		_think_interval_current = 0.3
	else:
		_think_interval_current = THINK_INTERVAL

## Target tracking
var target: Node3D = null
var last_known_target_pos: Vector3 = Vector3.ZERO
var target_last_seen_time: float = 0.0
var has_line_of_sight: bool = false
var target_visible_duration: float = 0.0  # How long we've had eyes on target

## Alert tiers + perception (R12/R13/R14). Orthogonal to the goal FSM: the tier
## gates target ACQUISITION; once in COMBAT the existing goal brain takes over.
enum AlertTier { RELAXED, SUSPICIOUS, ALERT, COMBAT }
var alert_tier: AlertTier = AlertTier.RELAXED
var awareness: float = 0.0            ## 0..1 visibility accumulator
const AWARENESS_DECAY: float = 0.25   ## per second when candidate unseen
const SUSPICIOUS_THRESHOLD: float = 0.45
var facing_dir: Vector3 = Vector3.FORWARD
var _combat_lost_time: float = 0.0
var _grid: GameplayGrid = null        ## fetched from game_world group (sight caps)
const SIGHT_CAP_OPEN: float = 140.0
const SIGHT_CAP_JUNGLE: float = 45.0

## Aim interpolation (smooth aiming like Quake 3 bots)
var current_aim_dir: Vector3 = Vector3.FORWARD
var target_aim_dir: Vector3 = Vector3.FORWARD
var aim_speed: float = 8.0  # Radians per second - varies by skill
var aim_error: Vector3 = Vector3.ZERO  # Current aim offset

## Navigation
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
var move_target: Vector3 = Vector3.ZERO
var is_moving: bool = false

## Cover system (R15): dynamic point discovery + a shared claim broker so two
## enemies never stack on the same rock/sandbag.
var current_cover: Vector3 = Vector3.ZERO
var has_cover: bool = false
var cover_quality: float = 0.0
var _moving_to_cover: bool = false
var _cover_search_timer: float = 0.0
static var _cover_claims: Dictionary = {}  # Vector3i cell -> {enemy: EnemyBase}
const COVER_CELL: float = 2.0
const COVER_SEARCH_OFFSETS: Array[Vector3] = [
	Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3),
	Vector3(2.2, 0, 2.2), Vector3(-2.2, 0, 2.2), Vector3(2.2, 0, -2.2), Vector3(-2.2, 0, -2.2),
	Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6),
]

## R18/R33: assigned wandering trail (ambient corridor patrols); sentries pause
## and glance around at each waypoint instead of marching on a fixed clock.
var patrol_route: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_pause: float = 0.0

## Combat behavior
var strafe_direction: float = 0.0
var strafe_timer: float = 0.0
var shots_fired: int = 0
var burst_count: int = 0
var accuracy_modifier: float = 1.0     # per-frame scratch: range band x strafe x stillness
var base_accuracy_modifier: float = 1.0  # archetype baseline from EnemyData, multiplied in
var aggro_range: float = 50.0          # target-acquisition radius, from EnemyData.alert_range
var d_flanks: bool = true              # archetype may flank
var d_retreats_when_hurt: bool = false # archetype breaks when wounded
var d_uses_cover: bool = true
var d_retreat_hp: float = 0.25

## Reaction system
var reaction_timer: float = 0.0
var has_reacted: bool = false
const BASE_REACTION_TIME: float = 0.25  # Faster = deadlier

## W45: grenades to flush cover. W46: crippled crawl state.
var grenade_cooldown: float = 0.0
var grenades_left: int = 1
var is_crippled: bool = false

## R64: spider-hole ambusher - hidden (no mesh/collision) until the player
## closes to trigger range, then pops straight to COMBAT. Set by the spawner.
var is_spider_hole: bool = false
var _spider_triggered: bool = false
const SPIDER_TRIGGER_RANGE: float = 7.0

## R67: crippled fighters near a tunnel entrance slip underground and vanish
## rather than crawl forever.
var _tunnel_retreat_queued: bool = false

## Fairness (anti-instant-death): the first round fired at a newly acquired
## target is a deliberate near-miss - the CRACK is your warning. Close-range
## acquisitions also startle the shooter (+reaction time).
var _first_shot_fired: bool = false

## Suppression system
var suppression_level: float = 0.0  # 0-1, affects behavior
var incoming_fire_timer: float = 0.0
const SUPPRESSION_DECAY: float = 0.3  # Per second

## Threat assessment
var threat_level: float = 0.0  # How dangerous current situation is
var damage_taken_recently: int = 0
var damage_decay_timer: float = 0.0

## Characteristics (like Quake 3 bot characteristics)
var char_aggression: float = 0.5      # 0-1: tendency to advance/flank
var char_accuracy: float = 0.7        # 0-1: base accuracy
var char_reaction: float = 0.6        # 0-1: reaction speed
var char_self_preservation: float = 0.5  # 0-1: tendency to seek cover

## Constants
const MAX_BURST: int = 5
const ALERT_RANGE: float = 25.0
const AGGRO_RANGE: float = 18.0
const MAX_THINK_TIME: float = 0.2  # Cap think time (like Quake 3's 200ms)

## Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Visual
var mesh: MeshInstance3D
var sprite_actor: SpriteActor = null  ## null when the unit has no rendered sheets
var _nav_box: int = -1     ## index into NavBaker._live_boxes, refreshed at think rate
var _nav_warned: bool = false
var last_hit_dir: Vector3 = Vector3.FORWARD  ## world dir from attacker -> us; picks the death clip


func _ready() -> void:
	add_to_group("enemies")
	CombatManager.register_enemy(self)

	# Randomize personality
	personality = [Enums.AIPersonality.AGGRESSIVE, Enums.AIPersonality.DEFENSIVE, Enums.AIPersonality.BALANCED].pick_random()
	_apply_personality()

	# Load enemy data
	if not enemy_data_path.is_empty():
		enemy_data = load(enemy_data_path)
		if enemy_data:
			max_hp = enemy_data.max_hp
			current_hp = max_hp
			move_speed = enemy_data.move_speed
			preferred_range = enemy_data.preferred_range
			# Step 8: exports that were stored and ignored now drive behaviour.
			base_accuracy_modifier = enemy_data.accuracy_modifier
			aggro_range = enemy_data.alert_range * 2.0   # was a hardcoded ALERT_RANGE*2
			d_flanks = enemy_data.flanks
			d_retreats_when_hurt = enemy_data.retreats_when_hurt
			d_uses_cover = enemy_data.uses_cover
			d_retreat_hp = enemy_data.retreat_hp_threshold
			# _apply_personality() ran first and randomised char_aggression into a
			# disjoint band; bias it toward the archetype so a VC (0.45) and an NVA
			# (0.65) actually differ instead of being pure personality noise.
			char_aggression = lerpf(char_aggression, enemy_data.aggression, 0.6)

			if not enemy_data.weapon_path.is_empty():
				weapon_data = load(enemy_data.weapon_path)

	_setup_visual()
	_setup_hurtbox()

	# Initialize aim direction
	current_aim_dir = -global_transform.basis.z
	target_aim_dir = current_aim_dir
	facing_dir = current_aim_dir

	# Perception wiring (R12/R13)
	NoiseBus.noise_emitted.connect(_on_noise_heard)
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw != null and "gameplay_grid" in gw:
		_grid = gw.gameplay_grid

	# R64: spider-hole starts hidden and inert until triggered.
	if is_spider_hole:
		visible = false
		collision_layer = 0
		collision_mask = 1


func _apply_personality() -> void:
	match personality:
		Enums.AIPersonality.AGGRESSIVE:
			char_aggression = randf_range(0.7, 0.9)
			char_accuracy = randf_range(0.5, 0.7)
			char_reaction = randf_range(0.6, 0.8)
			char_self_preservation = randf_range(0.2, 0.4)
			aim_speed = randf_range(6.0, 9.0)
		Enums.AIPersonality.DEFENSIVE:
			char_aggression = randf_range(0.2, 0.4)
			char_accuracy = randf_range(0.7, 0.9)
			char_reaction = randf_range(0.5, 0.7)
			char_self_preservation = randf_range(0.7, 0.9)
			aim_speed = randf_range(5.0, 7.0)
		Enums.AIPersonality.BALANCED:
			char_aggression = randf_range(0.4, 0.6)
			char_accuracy = randf_range(0.6, 0.8)
			char_reaction = randf_range(0.5, 0.7)
			char_self_preservation = randf_range(0.4, 0.6)
			aim_speed = randf_range(5.0, 8.0)


## 8-dir billboard sprite when the unit has been rendered; the old capsule
## otherwise (vc3_sapper/vc6_heavy are still rendering, and the WW2 holdovers
## have no sprite at all). Every mesh mutation site below is guarded the same
## way, so a half-rendered art pass cannot crash the game.
func _setup_visual() -> void:
	if enemy_data != null and not str(enemy_data.sprite_unit).is_empty():
		sprite_actor = SpriteActor.new()
		add_child(sprite_actor)
		sprite_actor.setup(str(enemy_data.sprite_faction), str(enemy_data.sprite_unit), str(enemy_data.sprite_weapon))
		if sprite_actor.play(SpriteStateMap.resolve(sprite_actor.faction, sprite_actor.unit, sprite_actor.weapon, "idle")):
			return
		# Sheets missing on disk - fall through to the capsule rather than
		# rendering an invisible enemy.
		sprite_actor.queue_free()
		sprite_actor = null

	mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	mesh.mesh = capsule
	mesh.position.y = 0.9

	var mat := StandardMaterial3D.new()
	mat.albedo_color = enemy_data.color if enemy_data != null else Color(0.4, 0.4, 0.3)
	mesh.material_override = mat

	add_child(mesh)


## Drive the clip from the AI. Called every frame from _execute(), never from
## _think() - think is LOD-throttled to 0.6s past 150m and animation would run
## at 1.6 fps.
func _update_sprite() -> void:
	if sprite_actor == null:
		return
	sprite_actor.set_facing(facing_dir)
	if current_state == Enums.AIState.DEAD or is_surrendered:
		return  # the death / surrender clip was already latched; do not restart it
	var speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var firing: bool = not can_fire and fire_timer < 0.12
	var intent: String = SpriteStateMap.intent_for(current_state, is_crippled, is_surrendered, firing, speed)
	sprite_actor.play(SpriteStateMap.resolve(sprite_actor.faction, sprite_actor.unit, sprite_actor.weapon, intent))


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

	hitzone.collision_layer = 64
	hitzone.collision_mask = 16

	hitzone.add_to_group("enemy_hurtbox")
	hitzone.add_to_group("hitzone")

	add_child(hitzone)


## ============================================
## MAIN LOOP - Separate think from execute
## ============================================

func _physics_process(delta: float) -> void:
	if current_state == Enums.AIState.DEAD:
		return

	# Cap delta for framerate independence (Quake 3 pattern)
	var capped_delta: float = minf(delta, 0.066)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * capped_delta

	# Decay systems
	_update_decay(capped_delta)

	# Think on schedule (like Quake 3 bots - not every frame); W86 LOD-scaled.
	_update_think_lod(capped_delta)
	think_timer += capped_delta
	if think_timer >= _think_interval_current:
		think_timer = 0.0
		_think()

	# Execute movement and aiming every frame (smooth)
	_execute(capped_delta)

	move_and_slide()


func _update_decay(delta: float) -> void:
	# Decay suppression
	if suppression_level > 0:
		suppression_level = maxf(0.0, suppression_level - SUPPRESSION_DECAY * delta)

	# Decay recent damage tracking
	damage_decay_timer += delta
	if damage_decay_timer >= 2.0:
		damage_taken_recently = 0
		damage_decay_timer = 0.0

	# Fire timer
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0:
			can_fire = true


## ============================================
## THINK - Goal evaluation and decision making
## ============================================

func _think() -> void:
	_nav_box = NavBaker.box_index_at(global_position) if WorldConfig.NAV_ENABLED else -1
	_check_spider_hole()
	_check_tunnel_retreat()
	if is_spider_hole and not _spider_triggered:
		return  # still buried - no perception, no movement
	# Perception first: the alert tier gates whether we may acquire targets.
	_update_perception()
	if alert_tier == AlertTier.COMBAT:
		_find_best_target()
	elif target != null:
		target = null  # not aware enough to have a hard target
	_update_line_of_sight()
	_assess_threat()

	# Evaluate and potentially change goal
	_evaluate_goals()

	# Update state based on goal
	_update_state_for_goal()


## R64: pop the ambush the moment the player closes to trigger range.
func _check_spider_hole() -> void:
	if not is_spider_hole or _spider_triggered:
		return
	var player := GameManager.player as Node3D
	if player == null:
		return
	if global_position.distance_to(player.global_position) > SPIDER_TRIGGER_RANGE:
		return
	_spider_triggered = true
	visible = true
	collision_layer = 4
	collision_mask = 1
	target = player
	last_known_target_pos = player.global_position
	_set_tier(AlertTier.COMBAT)
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1)


## R67: a crippled fighter near a tunnel entrance slips underground and is
## gone for good instead of crawling forever.
func _check_tunnel_retreat() -> void:
	if not is_crippled or _tunnel_retreat_queued:
		return
	for t in get_tree().get_nodes_in_group("tunnel_entrances"):
		var entrance := t as Node3D
		if entrance == null:
			continue
		if global_position.distance_to(entrance.global_position) > 8.0:
			continue
		_tunnel_retreat_queued = true
		var shout := Label3D.new()
		shout.text = "DI DI MAU!"
		shout.font_size = 22
		shout.pixel_size = 0.005
		shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		shout.modulate = Color(0.85, 0.75, 0.5)
		add_child(shout)
		shout.position = Vector3(0, 2.2, 0)
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if not is_dead():
				_die())
		return


## ---------- PERCEPTION (R12/R13/R14) ----------

## Local sight cap from vegetation density (RECON terrain caps, tuned up).
func _sight_cap(at: Vector3) -> float:
	var mult: float = MissionWeather.sight_mult
	# W54: illumination strips darkness for anyone standing in the light.
	if mult < 0.9 and IllumFlare.is_lit(at):
		mult = maxf(mult, 0.9)
	if _grid == null:
		return SIGHT_CAP_OPEN * mult
	var veg: float = maxf(_grid.get_vegetation(global_position), _grid.get_vegetation(at))
	return lerpf(SIGHT_CAP_OPEN, SIGHT_CAP_JUNGLE, clampf(veg, 0.0, 1.0)) * mult


func _fov_deg() -> float:
	match alert_tier:
		AlertTier.RELAXED:
			return 100.0
		AlertTier.SUSPICIOUS, AlertTier.ALERT:
			return 150.0
		_:
			return 360.0


func _update_perception() -> void:
	# Candidate: nearest living hostile (player weighted first).
	var candidate: Node3D = null
	var best_dist: float = 99999.0
	var player := GameManager.player as Node3D
	if player != null and is_instance_valid(player):
		best_dist = global_position.distance_to(player.global_position)
		candidate = player
	# Buddy rule (W22): squadmates are perception-exempt until we're in COMBAT -
	# the player's stealth is never broken by their AI pathing.
	if alert_tier == AlertTier.COMBAT:
		for ally in get_tree().get_nodes_in_group("allies"):
			var a := ally as Node3D
			if a == null or (a.has_method("is_dead") and a.is_dead()):
				continue
			var d := global_position.distance_to(a.global_position)
			if d < best_dist:
				best_dist = d
				candidate = a

	var gain: float = 0.0
	if candidate != null:
		var cap := _sight_cap(candidate.global_position)
		if best_dist <= cap:
			# FOV cone (COMBAT = all-round awareness).
			var in_fov := true
			if alert_tier != AlertTier.COMBAT:
				var to_c := (candidate.global_position - global_position).normalized()
				var flat_facing := Vector3(facing_dir.x, 0, facing_dir.z).normalized()
				in_fov = flat_facing.dot(Vector3(to_c.x, 0, to_c.z).normalized()) > cos(deg_to_rad(_fov_deg() * 0.5))
			if in_fov and not SmokeCloud.blocks_sight(
					global_position + Vector3.UP * 1.5,
					candidate.global_position + Vector3.UP * 1.0) \
				and CombatManager.has_line_of_sight(
					global_position + Vector3.UP * 1.5,
					candidate.global_position + Vector3.UP * 1.0, [self]):
				# Base gain by proximity; stance/motion modifiers for the player.
				gain = clampf(1.5 * (1.0 - best_dist / cap) + 0.25, 0.2, 2.0)
				if candidate == player:
					if "is_prone" in player and player.is_prone:
						gain *= 0.35
					elif "is_crouching" in player and player.is_crouching:
						gain *= 0.5
					if player.has_method("is_moving"):
						gain *= 1.5 if player.is_moving() else 0.6
				if best_dist < 10.0:
					gain = 3.0  # inner detection bubble: near-instant

	if gain > 0.0:
		awareness = minf(1.0, awareness + gain * THINK_INTERVAL)
		last_known_target_pos = candidate.global_position
		target_last_seen_time = 0.0
	else:
		awareness = maxf(0.0, awareness - AWARENESS_DECAY * THINK_INTERVAL)

	# Tier transitions.
	match alert_tier:
		AlertTier.RELAXED, AlertTier.SUSPICIOUS, AlertTier.ALERT:
			if awareness >= 1.0:
				_set_tier(AlertTier.COMBAT)
			elif awareness >= SUSPICIOUS_THRESHOLD and alert_tier == AlertTier.RELAXED:
				_set_tier(AlertTier.SUSPICIOUS)
		AlertTier.COMBAT:
			if target == null or not is_instance_valid(target):
				_combat_lost_time += THINK_INTERVAL
				if _combat_lost_time > 8.0 and awareness <= 0.0:
					_set_tier(AlertTier.ALERT)  # never back to RELAXED
			else:
				_combat_lost_time = 0.0


func _set_tier(tier: AlertTier) -> void:
	if tier == alert_tier:
		return
	var was_cold: bool = alert_tier == AlertTier.RELAXED or alert_tier == AlertTier.SUSPICIOUS
	alert_tier = tier
	if tier == AlertTier.COMBAT:
		awareness = 1.0
		_first_shot_fired = false  # new fight, new warning shot
		# Bumping into each other at close range startles BOTH sides.
		if was_cold:
			var player := GameManager.player as Node3D
			if player and global_position.distance_to(player.global_position) < 15.0:
				has_reacted = false
				reaction_timer = -randf_range(0.4, 0.7)  # extra startle delay
		GunFX.play_combat_sting(get_tree().current_scene)  # W67: contact sting


## Heard something (R13). Investigation goes to the NOISE, not the source.
func _on_noise_heard(_type: int, position: Vector3, radius: float, source_team: int) -> void:
	if source_team == 1:  # our own side
		return
	if current_state == Enums.AIState.DEAD:
		return
	if global_position.distance_to(position) > radius:
		return
	last_known_target_pos = position
	target_last_seen_time = 0.0
	awareness = minf(1.0, awareness + 0.35)
	if alert_tier == AlertTier.RELAXED:
		_set_tier(AlertTier.SUSPICIOUS)
	elif alert_tier == AlertTier.SUSPICIOUS:
		_set_tier(AlertTier.ALERT)


func _find_best_target() -> void:
	if target and is_instance_valid(target):
		if target.has_method("is_dead"):
			if not target.is_dead():
				return
		else:
			return

	var best_target: Node3D = null
	var best_score: float = 0.0

	# Check player
	if GameManager.player and is_instance_valid(GameManager.player):
		var player_node := GameManager.player as Node3D
		if player_node:
			var player_dead := false
			if player_node.has_method("is_dead"):
				player_dead = player_node.is_dead()
			elif player_node.has_node("HealthSystem"):
				var hs := player_node.get_node("HealthSystem")
				if hs.has_method("is_dead"):
					player_dead = hs.is_dead()

			if not player_dead:
				var dist := global_position.distance_to(player_node.global_position)
				if dist < aggro_range:
					var score: float = 100.0 / maxf(dist, 1.0)
					if score > best_score:
						best_score = score
						best_target = player_node

	# Check allies
	for ally in get_tree().get_nodes_in_group("allies"):
		if not is_instance_valid(ally) or not ally is Node3D:
			continue
		if ally.has_method("is_dead") and ally.is_dead():
			continue

		var dist := global_position.distance_to((ally as Node3D).global_position)
		if dist < aggro_range:
			var score: float = 80.0 / maxf(dist, 1.0)  # Slightly lower priority than player
			if score > best_score:
				best_score = score
				best_target = ally as Node3D

	target = best_target


func _update_line_of_sight() -> void:
	if not target:
		has_line_of_sight = false
		target_visible_duration = 0.0
		return

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := target.global_position + Vector3.UP * 1.0

	var new_los := CombatManager.has_line_of_sight(eye_pos, target_pos, [self])

	if new_los:
		if not has_line_of_sight:
			target_visible_duration = 0.0
		else:
			target_visible_duration += THINK_INTERVAL
		last_known_target_pos = target.global_position
		target_last_seen_time = 0.0
	else:
		target_last_seen_time += THINK_INTERVAL
		target_visible_duration = 0.0

	has_line_of_sight = new_los


func _assess_threat() -> void:
	threat_level = 0.0

	# Factor in suppression
	threat_level += suppression_level * 0.4

	# Factor in recent damage
	var damage_ratio: float = float(damage_taken_recently) / float(max_hp)
	threat_level += damage_ratio * 0.5

	# Factor in low health
	var health_ratio: float = float(current_hp) / float(max_hp)
	if health_ratio < 0.3:
		threat_level += 0.3

	# Factor in exposed position (no cover)
	if not has_cover:
		threat_level += 0.2

	threat_level = clampf(threat_level, 0.0, 1.0)


func _evaluate_goals() -> void:
	goal_timer += THINK_INTERVAL

	# Don't switch goals too frequently
	if goal_timer < 0.5 and current_goal != Enums.AIGoal.NONE:
		return

	var best_goal: Enums.AIGoal = Enums.AIGoal.NONE
	var best_score: float = 0.0

	# No target - investigate or hold
	if not target or not is_instance_valid(target):
		if last_known_target_pos != Vector3.ZERO and target_last_seen_time < 5.0:
			best_goal = Enums.AIGoal.INVESTIGATE
		else:
			best_goal = Enums.AIGoal.HOLD_POSITION
		_set_goal(best_goal)
		return

	var dist := global_position.distance_to(target.global_position)

	# Evaluate each possible goal
	var scores: Dictionary = {}

	# ENGAGE - direct combat
	var engage_score: float = 0.5
	if has_line_of_sight:
		engage_score += 0.3
	if dist < preferred_range * 1.2 and dist > preferred_range * 0.5:
		engage_score += 0.2  # In comfortable range
	scores[Enums.AIGoal.ENGAGE_TARGET] = engage_score * (1.0 - threat_level * 0.3)

	# SEEK COVER - when threatened
	var cover_score: float = threat_level * 0.7 + char_self_preservation * 0.3
	if suppression_level > 0.5:
		cover_score += 0.3
	if not has_cover:
		cover_score += 0.2
	scores[Enums.AIGoal.SEEK_COVER] = cover_score if d_uses_cover else -1.0

	# SUPPRESS - pin down target
	var suppress_score: float = 0.3
	if has_line_of_sight and weapon_data and weapon_data.firing_mode == Enums.FiringMode.FULL_AUTO:
		suppress_score += 0.3
	if dist > preferred_range:
		suppress_score += 0.2  # Good at range
	scores[Enums.AIGoal.SUPPRESS_TARGET] = suppress_score * (1.0 - char_aggression * 0.3)

	# FLANK - move to better position
	var flank_score: float = char_aggression * 0.4
	if not has_line_of_sight and target_last_seen_time < 3.0:
		flank_score += 0.3
	if threat_level < 0.3:
		flank_score += 0.2
	scores[Enums.AIGoal.FLANK_TARGET] = flank_score if d_flanks else -1.0

	# ADVANCE - push forward
	var advance_score: float = char_aggression * 0.5
	if dist > preferred_range * 1.5:
		advance_score += 0.3
	if threat_level < 0.2:
		advance_score += 0.2
	scores[Enums.AIGoal.ADVANCE] = advance_score

	# RETREAT - fall back
	var retreat_score: float = 0.0
	if threat_level > 0.7:
		retreat_score = 0.6  # tactical withdrawal under heavy fire - all archetypes
	# The wounded-man break is what retreats_when_hurt gates; the tactical
	# withdrawal above is separate (the export's NAME is "when hurt").
	if d_retreats_when_hurt and float(current_hp) / float(max_hp) < d_retreat_hp:
		retreat_score += 0.4
	scores[Enums.AIGoal.RETREAT] = retreat_score * char_self_preservation

	# Find best goal
	for goal in scores:
		if scores[goal] > best_score:
			best_score = scores[goal]
			best_goal = goal

	if best_goal != current_goal:
		_set_goal(best_goal)


func _set_goal(new_goal: Enums.AIGoal) -> void:
	if current_goal == Enums.AIGoal.SEEK_COVER and new_goal != Enums.AIGoal.SEEK_COVER:
		_release_cover()
	current_goal = new_goal
	goal_timer = 0.0

	# Reset reaction when changing goals
	if new_goal == Enums.AIGoal.ENGAGE_TARGET or new_goal == Enums.AIGoal.SUPPRESS_TARGET:
		if not has_reacted:
			reaction_timer = 0.0


func _update_state_for_goal() -> void:
	match current_goal:
		Enums.AIGoal.ENGAGE_TARGET:
			if suppression_level > 0.7:
				_change_state(Enums.AIState.SUPPRESSED)
			else:
				_change_state(Enums.AIState.COMBAT)
		Enums.AIGoal.SEEK_COVER:
			_change_state(Enums.AIState.SEEKING_COVER)
		Enums.AIGoal.SUPPRESS_TARGET:
			_change_state(Enums.AIState.COMBAT)
		Enums.AIGoal.FLANK_TARGET:
			_change_state(Enums.AIState.FLANKING)
		Enums.AIGoal.ADVANCE:
			_change_state(Enums.AIState.ADVANCING)
		Enums.AIGoal.RETREAT:
			_change_state(Enums.AIState.RETREATING)
		Enums.AIGoal.INVESTIGATE:
			_change_state(Enums.AIState.ALERT)
		Enums.AIGoal.HOLD_POSITION:
			_change_state(Enums.AIState.IDLE)
		_:
			_change_state(Enums.AIState.IDLE)


## ============================================
## EXECUTE - Smooth movement and aiming
## ============================================

func _execute(delta: float) -> void:
	state_timer += delta
	_update_sprite()

	# Update aim interpolation (smooth like Quake 3)
	_update_aim(delta)

	# Execute based on current state
	match current_state:
		Enums.AIState.IDLE:
			_execute_idle(delta)
		Enums.AIState.ALERT:
			_execute_alert(delta)
		Enums.AIState.COMBAT:
			_execute_combat(delta)
		Enums.AIState.SUPPRESSED:
			_execute_suppressed(delta)
		Enums.AIState.SEEKING_COVER:
			_execute_seeking_cover(delta)
		Enums.AIState.FLANKING:
			_execute_flanking(delta)
		Enums.AIState.ADVANCING:
			_execute_advancing(delta)
		Enums.AIState.RETREATING:
			_execute_retreating(delta)


func _update_aim(delta: float) -> void:
	if not target or not has_line_of_sight:
		return

	# Calculate desired aim direction
	var target_pos: Vector3 = target.global_position + Vector3.UP * 1.0
	var eye_pos: Vector3 = global_position + Vector3.UP * 1.5

	# Lead the target if moving
	if target is CharacterBody3D:
		var target_vel: Vector3 = (target as CharacterBody3D).velocity
		var dist: float = eye_pos.distance_to(target_pos)
		if weapon_data:
			var lead_time: float = dist / weapon_data.projectile_speed * 0.6
			target_pos += target_vel * lead_time

	target_aim_dir = (target_pos - eye_pos).normalized()

	# Smooth aim interpolation (like Quake 3 bot view changes)
	var aim_delta: float = aim_speed * delta
	current_aim_dir = current_aim_dir.lerp(target_aim_dir, aim_delta).normalized()

	# Add aim error based on accuracy
	var error_scale: float = (1.0 - char_accuracy) * 0.1
	aim_error = aim_error.lerp(
		Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * error_scale,
		delta * 2.0
	)

	# Face the aim direction (Y axis only for body)
	var flat_aim: Vector3 = current_aim_dir
	flat_aim.y = 0
	if flat_aim.length() > 0.1:
		look_at(global_position + flat_aim)
		facing_dir = current_aim_dir


func _execute_idle(delta: float) -> void:
	if not patrol_route.is_empty():
		_execute_patrol(delta)
		return
	# Decelerate
	velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
	velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)


func _execute_alert(delta: float) -> void:
	# Move toward last known position
	if last_known_target_pos != Vector3.ZERO:
		var dist := global_position.distance_to(last_known_target_pos)
		if dist > 2.0:
			_move_toward(last_known_target_pos, delta)
		else:
			# Reached position, slow down
			velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)


func _execute_combat(delta: float) -> void:
	if not target:
		return

	var dist := global_position.distance_to(target.global_position)

	# Reaction time before first shot
	if not has_reacted:
		reaction_timer += delta
		var required_reaction: float = BASE_REACTION_TIME * (2.0 - char_reaction)
		if reaction_timer >= required_reaction:
			has_reacted = true
		return

	# Strafe pattern
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_direction = [-1.0, 0.0, 0.0, 1.0].pick_random()  # More likely to stop
		strafe_timer = randf_range(0.8, 2.0)

	if has_line_of_sight:
		# Calculate movement based on range
		var move_dir := Vector3.ZERO

		if dist < preferred_range * 0.5:
			# Too close - back up
			move_dir = (global_position - target.global_position).normalized()
			accuracy_modifier = base_accuracy_modifier * 1.8
		elif dist > preferred_range * 1.3:
			# Too far - advance slightly
			move_dir = (target.global_position - global_position).normalized() * 0.5
			accuracy_modifier = base_accuracy_modifier * 1.3
		else:
			# Good range - minimal movement
			accuracy_modifier = base_accuracy_modifier * (1.0 - (1.0 - suppression_level) * 0.2)

		# Apply strafe
		if strafe_direction != 0.0:
			var strafe_vec := transform.basis.x * strafe_direction
			move_dir = (move_dir + strafe_vec * 0.4).normalized()
			accuracy_modifier *= 1.15

		move_dir.y = 0
		if move_dir.length() > 0.1:
			velocity.x = lerpf(velocity.x, move_dir.x * move_speed * 0.5, delta * 8.0)
			velocity.z = lerpf(velocity.z, move_dir.z * move_speed * 0.5, delta * 8.0)
		else:
			velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)
			accuracy_modifier *= 0.8  # More accurate when still

		# Fire at target
		if can_fire and suppression_level < 0.8:
			if burst_count < MAX_BURST:
				_fire_at_target()
				burst_count += 1
			else:
				can_fire = false
				fire_timer = randf_range(0.4, 1.2)
				burst_count = 0
	else:
		# W45: target hiding behind cover - flush with a grenade.
		grenade_cooldown = maxf(0.0, grenade_cooldown - delta)
		if grenades_left > 0 and grenade_cooldown <= 0.0 and target_last_seen_time < 3.0:
			var throw_dist := global_position.distance_to(last_known_target_pos)
			if throw_dist > 8.0 and throw_dist < 30.0 and randf() < 0.02:
				_throw_grenade()
		# Lost LOS - move to last known
		has_reacted = false
		reaction_timer = 0.0
		_move_toward(last_known_target_pos, delta)


func _execute_suppressed(delta: float) -> void:
	# Hunker down
	velocity.x = lerpf(velocity.x, 0.0, delta * 10.0)
	velocity.z = lerpf(velocity.z, 0.0, delta * 10.0)

	# Reset combat state
	shots_fired = 0
	burst_count = 0
	has_reacted = false


func _execute_seeking_cover(delta: float) -> void:
	if not target:
		return

	if not has_cover:
		if _moving_to_cover:
			if global_position.distance_to(current_cover) < 1.5:
				_moving_to_cover = false
				has_cover = true
				cover_quality = 0.7
			else:
				_move_toward(current_cover, delta)
				return
		else:
			_cover_search_timer -= delta
			if _cover_search_timer <= 0.0:
				_cover_search_timer = 1.0
				var point := _find_cover_point()
				if point != Vector3.ZERO:
					current_cover = point
					_moving_to_cover = true
					return

	# No cover found (or already covered): duck-and-dodge perpendicular to threat.
	var to_target := (target.global_position - global_position).normalized()
	var perpendicular := Vector3(-to_target.z, 0, to_target.x)

	if strafe_direction == 0.0:
		strafe_direction = [-1.0, 1.0].pick_random()

	var move_dir := (perpendicular * strafe_direction - to_target * 0.3).normalized()
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed


func _execute_flanking(delta: float) -> void:
	if not target:
		return

	# Move to side of target
	var to_target := (target.global_position - global_position).normalized()
	var perpendicular := Vector3(-to_target.z, 0, to_target.x)

	if strafe_direction == 0.0:
		strafe_direction = [-1.0, 1.0].pick_random()

	# Flank = move sideways + forward
	var move_dir := (perpendicular * strafe_direction * 0.7 + to_target * 0.5).normalized()
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	# Fire while flanking if we have LOS
	if has_line_of_sight and can_fire and has_reacted:
		_fire_at_target()


func _execute_advancing(delta: float) -> void:
	if not target:
		return

	var to_target := (target.global_position - global_position).normalized()

	# Add slight strafe while advancing
	var perpendicular := Vector3(-to_target.z, 0, to_target.x) * strafe_direction * 0.2
	var move_dir := (to_target + perpendicular).normalized()

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	# Fire while advancing
	if has_line_of_sight and can_fire and has_reacted:
		if burst_count < 3:  # Shorter bursts while moving
			_fire_at_target()
			burst_count += 1
		else:
			can_fire = false
			fire_timer = randf_range(0.3, 0.8)
			burst_count = 0


func _execute_retreating(delta: float) -> void:
	if not target:
		return

	var away_from_target := (global_position - target.global_position).normalized()
	velocity.x = away_from_target.x * move_speed
	velocity.z = away_from_target.z * move_speed


func _change_state(new_state: Enums.AIState) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	state_timer = 0.0
	state_changed.emit(new_state)


## R16 (for real this time): routed through NavBaker's per-site navmesh so
## pursuers path around huts, bunkers and vehicles. The original claim shipped
## against a nav map with zero polygons.
func _move_toward(pos: Vector3, delta: float, speed_mult: float = 1.0) -> void:
	var direction: Vector3 = pos - global_position
	# Nav only when BOTH endpoints sit inside the SAME baked region. Outside one,
	# direct steering is the intended behaviour, not a fallback -- which is the
	# distinction the old code could not make. With no navmesh at all,
	# is_navigation_finished() returned true instantly, the branch below never
	# ran, and R16 shipped as a silent no-op with a green suite.
	#
	# The same-box test also prevents a bug the site-region design would otherwise
	# introduce: an enemy inside a region chasing a target 300m outside it would
	# have its path clamped to the region edge, is_navigation_finished() would fire
	# there, and he would stop dead.
	if WorldConfig.NAV_ENABLED and nav_agent != null and _nav_box >= 0 and NavBaker.box_contains(_nav_box, pos):
		if nav_agent.target_position.distance_squared_to(pos) > 9.0:
			nav_agent.target_position = pos   # each restake is a map_get_path()
		if not nav_agent.is_navigation_finished():
			direction = nav_agent.get_next_path_position() - global_position
		elif OS.is_debug_build() and direction.length_squared() > 25.0 and not _nav_warned:
			_nav_warned = true
			push_error("[NAV] enemy inside baked region %d, %.1fm to target, no path - navmesh missing or region not merged" % [
				_nav_box, direction.length()])
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		facing_dir = direction  # eyes follow movement (perception FOV)
	velocity.x = lerpf(velocity.x, direction.x * move_speed * speed_mult, delta * 8.0)
	velocity.z = lerpf(velocity.z, direction.z * move_speed * speed_mult, delta * 8.0)


## ---------- COVER (R15) ----------

static func _cover_key(pos: Vector3) -> Vector3i:
	return Vector3i(roundi(pos.x / COVER_CELL), roundi(pos.y / COVER_CELL), roundi(pos.z / COVER_CELL))


static func _claim_cover(pos: Vector3, enemy: EnemyBase) -> bool:
	var key := _cover_key(pos)
	var existing: Dictionary = _cover_claims.get(key, {})
	var owner: EnemyBase = existing.get("enemy")
	if owner != null and is_instance_valid(owner) and owner != enemy and not owner.is_dead():
		return false
	_cover_claims[key] = {"enemy": enemy}
	return true


func _release_cover() -> void:
	if current_cover != Vector3.ZERO:
		var key := EnemyBase._cover_key(current_cover)
		if EnemyBase._cover_claims.get(key, {}).get("enemy") == self:
			EnemyBase._cover_claims.erase(key)
	has_cover = false
	cover_quality = 0.0
	_moving_to_cover = false


## Sample nearby points that block line-of-sight to the threat; claim the
## closest unclaimed one. Uses live raycasts against world geometry so it
## works in jungle, village, and firebase alike with no authored markers.
func _find_cover_point() -> Vector3:
	var threat_pos: Vector3 = last_known_target_pos if last_known_target_pos != Vector3.ZERO else global_position
	var space_state := get_world_3d().direct_space_state
	var candidates: Array[Vector3] = []
	for off in COVER_SEARCH_OFFSETS:
		var candidate: Vector3 = global_position + off
		var query := PhysicsRayQueryParameters3D.create(
			candidate + Vector3.UP * 1.3, threat_pos + Vector3.UP * 1.0, 1 | 32)
		query.exclude = [self]
		if space_state.intersect_ray(query):
			candidates.append(candidate)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return global_position.distance_squared_to(a) < global_position.distance_squared_to(b))
	for c in candidates:
		if EnemyBase._claim_cover(c, self):
			return c
	return Vector3.ZERO


## ---------- PATROL (R18/R33) ----------

## Loop of waypoints around a center; deterministic per the caller's rng so
## mission sims stay reproducible.
static func make_patrol_route(center: Vector3, rng: RandomNumberGenerator, point_count: int = 4, radius: float = 16.0) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var base_angle: float = rng.randf_range(0.0, TAU)
	for i in range(point_count):
		var a: float = base_angle + (TAU / float(point_count)) * float(i) + rng.randf_range(-0.3, 0.3)
		var r: float = radius * rng.randf_range(0.6, 1.0)
		pts.append(center + Vector3(cos(a) * r, 0.0, sin(a) * r))
	return pts


func _execute_patrol(delta: float) -> void:
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)
		return
	var wp: Vector3 = patrol_route[_patrol_index]
	if global_position.distance_to(wp) < 2.5:
		_patrol_index = (_patrol_index + 1) % patrol_route.size()
		_patrol_pause = randf_range(2.5, 6.0)  # sentry boredom: glance around, then move on
		return
	_move_toward(wp, delta, 0.5)


## ============================================
## COMBAT - Firing
## ============================================

func _fire_at_target() -> void:
	if not weapon_data or not target:
		return

	can_fire = false
	fire_timer = weapon_data.get_fire_delay()
	shots_fired += 1

	# Use smoothly interpolated aim direction + error
	var final_aim: Vector3 = (current_aim_dir + aim_error).normalized()

	# Add weapon spread
	var base_spread: float = weapon_data.base_spread * 1.3
	var accumulated_spread: float = minf(float(shots_fired) * 0.08, 0.8)
	var total_spread: float = base_spread * accuracy_modifier * (1.0 + accumulated_spread)
	total_spread *= (2.0 - char_accuracy)  # Apply characteristic
	total_spread *= GameSettings.enemy_spread_mult()  # W82 difficulty
	var spread: float = deg_to_rad(total_spread)

	final_aim.x += randf_range(-spread, spread)
	final_aim.y += randf_range(-spread, spread)
	final_aim.z += randf_range(-spread, spread)
	final_aim = final_aim.normalized()

	# First shot at this target: forced near-miss (the warning crack).
	if not _first_shot_fired:
		_first_shot_fired = true
		var miss := deg_to_rad(randf_range(5.0, 9.0))
		var miss_dir := randf_range(0.0, TAU)
		final_aim.x += cos(miss_dir) * miss
		final_aim.y += absf(sin(miss_dir)) * miss * 0.5 + 0.02  # bias high/wide
		final_aim = final_aim.normalized()

	# Raycast from the gun muzzle, not center mass (R03).
	var origin: Vector3 = get_muzzle_position(final_aim)

	# AUDIT-03: the projectile pool has been allocating 50 nodes on every boot
	# with zero callers. A weapon that names a ProjectileData fires a real
	# travelling round instead of a hitscan ray -- the RPG-2 needs travel time,
	# drop, a visible warhead and a smoke trail that gives the shooter away.
	if weapon_data != null and not weapon_data.projectile_data_path.is_empty():
		var pdata: ProjectileData = load(weapon_data.projectile_data_path)
		if pdata != null:
			var fx: Vector3 = get_muzzle_visual(final_aim)
			CombatManager.spawn_projectile(pdata, self, origin, final_aim, target)
			NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, origin, 1)
			GunFX.play_shot_3d(get_tree().current_scene, fx, weapon_data)
			GunFX.muzzle_flash(get_tree().current_scene, fx)
			return
		push_error("[EnemyBase] %s names a projectile that will not load: %s" % [
			weapon_data.id, weapon_data.projectile_data_path])

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_aim * weapon_data.max_range,
		1 | 2 | 32
	)
	query.exclude = [self]

	var result := space_state.intersect_ray(query)

	# Visible tracer from the muzzle (also the "muzzle flash reveals position" tell).
	var tracer_end: Vector3 = origin + final_aim * weapon_data.max_range
	if result:
		tracer_end = result.position
	var fx_origin: Vector3 = get_muzzle_visual(final_aim)
	BulletTracer.spawn_tracer(get_tree().current_scene, fx_origin, tracer_end, Color(0.4, 1.0, 0.5, 1.0))
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, origin, 1)
	GunFX.play_shot_3d(get_tree().current_scene, fx_origin, weapon_data)
	GunFX.muzzle_flash(get_tree().current_scene, fx_origin)
	if result and not (result.collider is Hitzone):
		GunFX.impact(get_tree().current_scene, result.position, result.normal, false)

	if result:
		var hit_target: Object = result.collider
		if hit_target:
			var damage_target: Node = null
			var damage_multiplier: float = 1.0
			var zone_name: String = "BODY"

			if hit_target is Hitzone:
				var hitzone := hit_target as Hitzone
				damage_target = hitzone.owner_entity
				damage_multiplier = hitzone.get_damage_multiplier()
				zone_name = hitzone.get_zone_name()
			elif hit_target is Node and (hit_target as Node).is_in_group("player"):
				damage_target = hit_target as Node
			elif hit_target is Node and (hit_target as Node).is_in_group("allies"):
				damage_target = hit_target as Node
			elif hit_target is Node and (hit_target as Node).get_parent():
				var parent: Node = (hit_target as Node).get_parent()
				if parent.is_in_group("player") or parent.is_in_group("allies"):
					damage_target = parent

			if damage_target and damage_target.has_method("take_damage"):
				var falloff: float = weapon_data.damage_multiplier_at(origin.distance_to(result.position))
				var base_damage: int = weapon_data.roll_damage()
				var final_damage: int = maxi(1, int(float(base_damage) * falloff * damage_multiplier))
				damage_target.take_damage(final_damage, weapon_data.damage_type, self)

				# W37: limb hits wound (arm = shaky aim, leg = no sprint).
				if zone_name == "LIMB" and damage_target.has_method("apply_wound"):
					damage_target.apply_wound("LIMB_LEG" if randf() < 0.5 else "LIMB_ARM")

				if zone_name == "HEAD":
					print("[ENEMY] HEADSHOT! %d damage" % final_damage)


## W45: telegraph shout, then lob a real grenade at the last-known position.
func _throw_grenade() -> void:
	grenades_left -= 1
	grenade_cooldown = 15.0
	# Telegraph: shout (noise event draws attention both ways) + floating text.
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1)
	var shout := Label3D.new()
	shout.text = "LUU DAN!"
	shout.font_size = 26
	shout.pixel_size = 0.005
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.modulate = Color(1.0, 0.6, 0.3)
	add_child(shout)
	shout.position = Vector3(0, 2.4, 0)
	get_tree().create_timer(1.2).timeout.connect(shout.queue_free)
	# The lob (1s windup).
	var throw_target := last_known_target_pos
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if current_state == Enums.AIState.DEAD or not is_inside_tree():
			return
		var grenade := Grenade.new()
		grenade.owner_entity = self
		get_tree().current_scene.add_child(grenade)
		grenade.global_position = global_position + Vector3.UP * 1.6
		var to_target := throw_target - grenade.global_position
		var flat := Vector3(to_target.x, 0, to_target.z)
		grenade.linear_velocity = flat.normalized() * minf(flat.length() * 0.55, 14.0) + Vector3(0, 6.0, 0)
		grenade.remaining_fuse = 3.0)


## Gun muzzle world position: shoulder height, pushed out along the aim with a
## right-hand offset. Sprite states will refine per-frame offsets later (R21/R28).
func get_muzzle_position(aim_dir: Vector3) -> Vector3:
	var flat_aim := Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()
	if sprite_actor != null:
		# Manifest height, enemy-local forward bias, NO lateral term. This value
		# is the intersect_ray() origin below, not just the tracer spawn - a
		# camera-relative lateral offset would make an enemy's bullet origin (and
		# whether it clears a rock) depend on where the player happens to look.
		return sprite_actor.muzzle_ballistic(flat_aim, 0.55)
	var right := flat_aim.cross(Vector3.UP).normalized() * -0.22
	return global_position + Vector3.UP * 1.35 + flat_aim * 0.55 + right


## Where the tracer and muzzle flash APPEAR. Camera-relative, because the quad is
## Y-billboarded and muzzle_px is measured in that plane. Never feed this to a
## raycast.
func get_muzzle_visual(aim_dir: Vector3) -> Vector3:
	if sprite_actor != null:
		return sprite_actor.muzzle_visual()
	return get_muzzle_position(aim_dir)


## ============================================
## DAMAGE AND DEATH
## ============================================

func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if current_state == Enums.AIState.DEAD:
		return 0

	current_hp -= amount
	damage_taken_recently += amount
	damage_decay_timer = 0.0

	# Remember where it came from so _die() can pick death_forward vs
	# death_from_right. take_damage() knew this all along and threw it away.
	if attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		last_hit_dir = (global_position - (attacker as Node3D).global_position).normalized()

	# Visual feedback
	if sprite_actor != null:
		sprite_actor.flash(Color(1.6, 0.5, 0.5), 0.1)
	elif mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if mesh and mesh.material_override:
				mesh.material_override.albedo_color = Color(0.4, 0.4, 0.3)
		)

	# W46: gutshot men go down crawling - slow, loud, drawing their buddies.
	if not is_crippled and current_hp > 0 and current_hp < max_hp / 4 and randf() < 0.35:
		is_crippled = true
		move_speed *= 0.25
		base_accuracy_modifier *= 1.6  # crippled: durable, was wiped next tick
		if sprite_actor != null:
			sprite_actor.play(SpriteStateMap.resolve(sprite_actor.faction, sprite_actor.unit, sprite_actor.weapon, "crippled"))
		elif mesh:
			mesh.scale.y = 0.45
			mesh.position.y = -0.35
		NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 30.0)

	# Getting shot = instant COMBAT tier (R12), whatever we were doing.
	_set_tier(AlertTier.COMBAT)
	if attacker is Node3D:
		last_known_target_pos = (attacker as Node3D).global_position
		target_last_seen_time = 0.0

	# Alert and acquire target
	if current_state == Enums.AIState.IDLE:
		if attacker is Node3D:
			target = attacker as Node3D
			last_known_target_pos = target.global_position
		current_goal = Enums.AIGoal.ENGAGE_TARGET
		_change_state(Enums.AIState.COMBAT)

	# Suppression from damage
	var suppress_amount: float = float(amount) / float(max_hp) * 0.5
	suppression_level = minf(1.0, suppression_level + suppress_amount)

	# Flinch
	can_fire = false
	fire_timer = maxf(fire_timer, 0.25)

	# Check death
	if current_hp <= 0:
		current_hp = 0
		_die()
	elif not is_surrendered and personality == Enums.AIPersonality.DEFENSIVE \
			and current_hp < max_hp / 3 and randf() < 0.15:
		# W63: shaken defensive fighters may quit when nearly alone.
		var living_nearby: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			var other := e as EnemyBase
			if other != self and other and not other.is_dead() \
					and other.global_position.distance_to(global_position) < 30.0:
				living_nearby += 1
		if living_nearby == 0:
			try_surrender()

	return amount


func apply_suppression(amount: float) -> void:
	suppression_level = minf(1.0, suppression_level + amount)
	incoming_fire_timer = 0.5


func apply_stagger(power: float) -> void:
	if power >= 1.0 and current_state != Enums.AIState.DEAD:
		suppression_level = minf(1.0, suppression_level + 0.5)
		_change_state(Enums.AIState.SUPPRESSED)


func _die() -> void:
	_change_state(Enums.AIState.DEAD)
	_release_cover()
	CombatManager.unregister_enemy(self)
	died.emit(self)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if sprite_actor != null:
		# last_hit_dir is the bullet's TRAVEL direction (attacker -> us), so the
		# shooter lies along -last_hit_dir. A round arriving from the man's own
		# right means the attacker sits on +basis.x. Testing last_hit_dir directly
		# inverts it, and the result looks plausible: everyone falls forward.
		#
		# Only two death clips exist. A shot from the left plays death_forward
		# rather than a mirrored death_from_right; derive death_from_left later.
		var to_attacker: Vector3 = -last_hit_dir
		var from_right: bool = to_attacker.dot(global_transform.basis.x) > 0.35
		var intent: String = "death_right" if from_right else "death_forward"
		sprite_actor.play(SpriteStateMap.resolve(sprite_actor.faction, sprite_actor.unit, sprite_actor.weapon, intent), true)
	elif mesh:
		mesh.rotation_degrees.x = 90

	add_to_group("lootable_corpses")  # W61
	get_tree().create_timer(45.0).timeout.connect(queue_free)


## W63: broken men throw their hands up. Interact to capture (intel), shoot
## to... live with it.
var is_surrendered: bool = false


func try_surrender() -> bool:
	if is_surrendered or is_dead():
		return false
	# Never inside wave/objective-critical groups (would soft-lock counters
	# unless captured; capture does count, but don't gamble the mission on it).
	for g in get_groups():
		if str(g).begins_with("wave_"):
			return false
	is_surrendered = true
	weapon_data = null
	target = null
	set_physics_process(false)
	velocity = Vector3.ZERO
	if sprite_actor != null:
		sprite_actor.play(SpriteStateMap.resolve(sprite_actor.faction, sprite_actor.unit, sprite_actor.weapon, "surrender"), true)
		sprite_actor.set_base_modulate(Color(1.15, 1.15, 0.95))
	elif mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color(0.7, 0.7, 0.6)
	var shout := Label3D.new()
	shout.text = "CHIEU HOI!"
	shout.font_size = 24
	shout.pixel_size = 0.005
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.modulate = Color(0.9, 0.9, 0.7)
	add_child(shout)
	shout.position = Vector3(0, 2.4, 0)
	add_to_group("surrendered")
	return true


func is_dead() -> bool:
	return current_state == Enums.AIState.DEAD


## ============================================
## FACTORY
## ============================================

static func spawn_enemy(parent: Node, pos: Vector3, data_path: String) -> EnemyBase:
	var enemy := EnemyBase.new()
	enemy.enemy_data_path = data_path

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	enemy.add_child(col)

	if WorldConfig.NAV_ENABLED:
		var nav := NavigationAgent3D.new()
		nav.name = "NavigationAgent3D"
		# INVARIANT: these must match NavBaker's AGENT_RADIUS / AGENT_HEIGHT, or
		# the agent walks corridors the navmesh never carved. Not a single one of
		# these was set before - everything ran on engine defaults (radius 0.5,
		# avoidance off but unstated).
		nav.radius = NavBaker.AGENT_RADIUS
		nav.height = NavBaker.AGENT_HEIGHT
		nav.path_desired_distance = 0.7
		nav.target_desired_distance = 1.0
		nav.path_max_distance = 5.0
		nav.avoidance_enabled = false   # explicit: RVO is a second silent no-op
		enemy.add_child(nav)

	enemy.collision_layer = 4
	enemy.collision_mask = 1

	parent.add_child(enemy)
	enemy.global_position = pos

	return enemy
