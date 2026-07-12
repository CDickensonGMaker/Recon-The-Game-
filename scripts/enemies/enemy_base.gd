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
const CLOSE_SENSE_RANGE: float = 10.0  ## contacts inside this are felt regardless of facing

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
var d_exposure_ramp: float = 2.5       # seconds of exposure to full accuracy (EnemyData)
var contact_conf: float = 0.0          # debounced eyes-on 0-1 (goals read THIS, not raw LOS)
var _last_intent: String = ""          # committed anim intent (stability filter)
var _cand_intent: String = ""          # challenger intent + when it started winning
var _cand_since: float = -1e9
var _fired_until_ms: float = -1e9      # T1.3: fire pose follows the SHOT, 350ms
var _hitzone_sync: Array = []          # [[hz, bone_idx, offset]..] - zones ride bones

## Stuck watchdog (Caleb: units wedging on cover collision): commanded to move
## but not moving for ~1s -> sidestep for a beat. No navmesh required.
var _stuck_pos: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _unstick_t: float = 0.0
var _unstick_dir: float = 1.0

func _update_unstick(delta: float) -> void:
	if _unstick_t > 0.0:
		_unstick_t -= delta
		var side := global_transform.basis.x * _unstick_dir
		velocity.x = side.x * move_speed
		velocity.z = side.z * move_speed
		return
	_stuck_t += delta
	if _stuck_t >= 1.0:
		var wants_move: bool = Vector2(velocity.x, velocity.z).length() > 1.0
		if wants_move and global_position.distance_to(_stuck_pos) < 0.3:
			_unstick_t = 0.6
			_unstick_dir = -_unstick_dir  # alternate sides so corners release
		_stuck_pos = global_position
		_stuck_t = 0.0

## DESIGN 4.2 fairness (the exposure ramp, formerly dead code): x3.0 spread at
## fresh exposure, converging near ramp end via (1 - t^2) - the safe window
## after repositioning stays safe for most of the ramp, then the noose closes.
const EXPOSURE_SPREAD_BONUS: float = 2.0

func _exposure_spread_mult() -> float:
	var t: float = clampf(target_visible_duration / maxf(d_exposure_ramp, 0.1), 0.0, 1.0)
	return 1.0 + EXPOSURE_SPREAD_BONUS * (1.0 - t * t)

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
var _gut_bleed_dps: float = 0.0     # locational: gutshot bleed-out rate
var _bleed_accum: float = 0.0
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
## The visual: a ModelActor (default) or SpriteActor (far-LOD / no-model
## fallback), or null -> capsule. Both share play/set_facing/flash/muzzle_*.
var sprite_actor: Node3D = null
var _visual_is_model: bool = false
var _nav_box: int = -1     ## index into NavBaker._live_boxes, refreshed at think rate
var squad_id: int = -1     ## EnemySquad coordination group; -1 = lone wolf

## Detection beacon: the last time ANY enemy entered COMBAT. The mission director
## polls this to raise the AO alarm on DETECTION, so a silent, unwitnessed kill
## no longer summons the QRF (stealth becomes an economy, not a fail gate).
static var last_combat_contact_ms: float = -1.0
var _nav_warned: bool = false
var _scan_phase: float = 0.0
var _home_facing: Vector3 = Vector3.FORWARD  ## the direction to sweep around
const SCAN_SPEED: float = 0.7
const SCAN_ARC: float = 2.45  ## +/- 140deg sweep - only a narrow wedge behind stays blind
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
			# Same anchor for nerve: courage inverse-biases self-preservation, so
			# a sapper's steadiness is archetype identity, not spawn RNG.
			char_self_preservation = lerpf(char_self_preservation, 1.0 - enemy_data.courage, 0.6)
			d_exposure_ramp = enemy_data.exposure_ramp_time

			if not enemy_data.weapon_path.is_empty():
				weapon_data = load(enemy_data.weapon_path)

	_home_facing = facing_dir
	_scan_phase = randf() * TAU   # desync guards so they do not sweep in lockstep
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


## 3D model when the unit has one (vc_guerilla_* / us_grunt_* v2 exports);
## the old capsule otherwise (WW2 holdovers have no model at all; the v1
## blocky troops are archived in Base Game Assets). Every mesh mutation site
## below is guarded the same way, so a half-rendered art pass cannot crash
## the game.
func _setup_visual() -> void:
	if enemy_data != null and not str(enemy_data.sprite_unit).is_empty():
		var unit: String = str(enemy_data.sprite_unit)
		# 3D model is the default renderer (Caleb, locked). Sprite is the
		# fallback when a unit has no .glb yet; capsule if neither.
		if ModelActor.model_exists(unit):
			var ma := ModelActor.new()
			add_child(ma)
			if ma.setup(unit):
				sprite_actor = ma
				_visual_is_model = true
				sprite_actor.play(SpriteStateMap.model_clip_for("idle"))
				return
			ma.queue_free()
		var sa := SpriteActor.new()
		add_child(sa)
		sa.setup(str(enemy_data.sprite_faction), unit, str(enemy_data.sprite_weapon))
		if sa.play(SpriteStateMap.resolve(str(enemy_data.sprite_faction), unit, str(enemy_data.sprite_weapon), "idle")):
			sprite_actor = sa
			_visual_is_model = false
			return
		sa.queue_free()

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
	if current_state == Enums.AIState.DEAD or is_surrendered or is_downed:
		return  # the death / surrender / downed clip was latched; do not restart it
	var vel_flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = vel_flat.length()
	var lateral: float = 0.0
	if speed > 0.1:
		var fwd := Vector3(facing_dir.x, 0.0, facing_dir.z).normalized()
		lateral = vel_flat.normalized().dot(fwd.cross(Vector3.UP))
	var now: float = float(Time.get_ticks_msec())
	# T1.3: latch set at the actual shot - the old cooldown-tail window put the
	# fire pose BEFORE the bang and flapped fire<->aim around every shot.
	var firing: bool = now < _fired_until_ms
	var intent: String = SpriteStateMap.intent_for(current_state, is_crippled, is_surrendered, firing, speed, lateral)
	# T1.4 stability filter: an intent must WIN continuously for 180ms before
	# the clip commits - a 1-frame blip can never grab the clip and lock it
	# (the old debounce accepted blips instantly, then refused the real intent
	# for 250ms). Fire/death still switch immediately.
	if intent != _last_intent:
		if intent != _cand_intent:
			_cand_intent = intent
			_cand_since = now
		if intent == "fire" or intent.begins_with("death") or now - _cand_since >= 180.0:
			_last_intent = intent
		else:
			intent = _last_intent
	else:
		_cand_intent = intent
	sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_faction), str(enemy_data.sprite_unit), str(enemy_data.sprite_weapon), intent))
	if sprite_actor is ModelActor:
		(sprite_actor as ModelActor).set_locomotion_speed(speed)


## Bone-measured, bone-synced zones on model units (beads 90gj/yd83); the
## legacy static bands only for sprite/capsule units. HitzoneBuilder is the
## single authority - do not hand-place zones here again.
func _setup_hurtbox() -> void:
	var ma: ModelActor = sprite_actor as ModelActor if _visual_is_model else null
	_hitzone_sync = HitzoneBuilder.build(self, ma, 64, 16, ["enemy_hurtbox", "hitzone"], true)


## ============================================
## MAIN LOOP - Separate think from execute
## ============================================

func _physics_process(delta: float) -> void:
	# Zones ride the skeleton even on the corpse - shooting bodies stays honest.
	if _visual_is_model:
		HitzoneBuilder.sync(sprite_actor as ModelActor, _hitzone_sync)
	if current_state == Enums.AIState.DEAD:
		return
	if is_downed:
		# Dying, not dead: no AI, no movement - just the bleed clock and the
		# aliveness signals (pool grows, he stays audible).
		var down_dt: float = minf(delta, 0.066)
		_downed_bleed_s -= down_dt
		_downed_fx_s -= down_dt
		if _downed_fx_s <= 0.0:
			_downed_fx_s = randf_range(4.0, 9.0)
			GunFX.blood_pool(get_tree().current_scene, global_position)
			NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 15.0)
			VOManager.play_enemy("pain", self)
		if _downed_bleed_s <= 0.0:
			_die()
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

	_update_unstick(capped_delta)
	move_and_slide()


func _update_decay(delta: float) -> void:
	# Decay suppression
	if suppression_level > 0:
		suppression_level = maxf(0.0, suppression_level - SUPPRESSION_DECAY * delta)
	# Gutshot bleed-out: no medic is coming for him.
	if _gut_bleed_dps > 0.0 and current_state != Enums.AIState.DEAD:
		_bleed_accum += _gut_bleed_dps * delta
		if _bleed_accum >= 1.0:
			var _tick := int(_bleed_accum)
			_bleed_accum -= float(_tick)
			current_hp -= _tick
			if current_hp <= 0:
				current_hp = 0
				_die()

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

	# Fireteam layer: share what I see, pull what the squad knows.
	_squad_sync()


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
		VOManager.play_enemy("retreat", self)
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


## Share what I see, pull what the squad knows (EnemySquad). This is the layer
## that turns "individuals who happen to be nearby" into a fireteam.
func _squad_sync() -> void:
	if squad_id < 0:
		return
	var now: float = float(Time.get_ticks_msec())
	if target != null and is_instance_valid(target) and has_line_of_sight:
		# I have eyes on: designate for the squad + lay a breadcrumb trail.
		EnemySquad.report_contact(squad_id, target, target.global_position, now)
		# Census for honest attention: who is already covered by squadmates
		# scores lower in _target_score - squads SPREAD, they don't laser one man.
		EnemySquad.report_engagement(squad_id, self, target, now)
	elif target == null and EnemySquad.has_fresh_intel(squad_id, now):
		# A buddy sees the enemy; I don't. Adopt the squad's contact and wake up -
		# no more lone blind man standing next to a firefight.
		var st := EnemySquad.shared_target(squad_id)
		if st != null:
			last_known_target_pos = EnemySquad.shared_last_known(squad_id)
			target_last_seen_time = 0.0
			if alert_tier < AlertTier.ALERT and global_position.distance_to(last_known_target_pos) < EnemySquad.SHARE_RANGE * 2.0:
				_set_tier(AlertTier.ALERT)


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
			# A contact this close is FELT regardless of facing - you hear boots,
			# gear, breathing at 8m. Without this an enemy stared past a player
			# stood 3m off its shoulder forever (they only "walked around"), which
			# is exactly what read as broken AI. LOS still required (a wall hides).
			var point_blank: bool = best_dist < CLOSE_SENSE_RANGE
			if (in_fov or point_blank) and not SmokeCloud.blocks_sight(
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
				if point_blank:
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
	if tier == AlertTier.COMBAT:
		EnemyBase.last_combat_contact_ms = float(Time.get_ticks_msec())
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


## HONEST ATTENTION (HLL doctrine pass, DESIGN 4.5 "honest enemy threat
## distribution"): no intrinsic player bias, no sticky-until-dead lock.
## Rescored every RETARGET_INTERVAL (pure distance math, zero new rays) or
## immediately when the target dies / someone new hurts us.
const RETARGET_INTERVAL: float = 2.0
const TARGET_MEMORY: float = 8.0
var _retarget_timer: float = 0.0
var _last_attacker: Node3D = null
var _last_attacker_ms: float = -1e9


func _target_score(candidate: Node3D, dist: float, now_ms: float) -> float:
	var score: float = 10.0 / maxf(dist, 2.0)              # proximity - NO player bias
	if candidate == _last_attacker and now_ms - _last_attacker_ms < 6000.0:
		score *= 2.5                                       # he is shooting ME
	if candidate == target:
		score *= 1.3                                       # mild stickiness, not a lock
		if target_last_seen_time > 5.0:
			score *= 0.5                                   # ghost: let a visible fight win
	var others: int = EnemySquad.count_engaging(squad_id, candidate, self, now_ms)
	return score / (1.0 + 0.2 * float(others))             # crowded targets less interesting


func _candidate_dead(c: Node3D) -> bool:
	if c.has_method("is_dead"):
		return c.is_dead()
	if c.has_node("HealthSystem"):
		var hs := c.get_node("HealthSystem")
		if hs.has_method("is_dead"):
			return hs.is_dead()
	return false


func _find_best_target() -> void:
	var now_ms: float = float(Time.get_ticks_msec())
	_retarget_timer += _think_interval_current
	var target_alive: bool = target != null and is_instance_valid(target) and not _candidate_dead(target)
	var freshly_shot: bool = _last_attacker != null and now_ms - _last_attacker_ms < 1000.0 \
		and _last_attacker != target

	# Slip-away rule: unseen too long and not hurting us -> drop to the blind
	# hunt (INVESTIGATE on last-known + breadcrumbs). COMBAT can finally decay.
	if target_alive and target_last_seen_time > TARGET_MEMORY \
			and not (target == _last_attacker and now_ms - _last_attacker_ms < 6000.0):
		target = null
		target_alive = false

	if target_alive and _retarget_timer < RETARGET_INTERVAL and not freshly_shot:
		return
	_retarget_timer = 0.0

	var best_target: Node3D = null
	var best_score: float = 0.0

	var candidates: Array[Node3D] = []
	if GameManager.player and is_instance_valid(GameManager.player):
		var pn := GameManager.player as Node3D
		if pn != null:
			candidates.append(pn)
	for ally in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(ally) and ally is Node3D:
			candidates.append(ally as Node3D)

	for c in candidates:
		if _candidate_dead(c):
			continue
		var dist := global_position.distance_to(c.global_position)
		if dist >= aggro_range:
			continue
		var score: float = _target_score(c, dist, now_ms)
		if score > best_score:
			best_score = score
			best_target = c

	if best_target != target:
		target_visible_duration = 0.0  # a new victim gets a fresh exposure clock
	target = best_target


func _update_line_of_sight() -> void:
	if not target:
		has_line_of_sight = false
		target_visible_duration = 0.0
		return

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := target.global_position + Vector3.UP * 1.0

	var new_los := CombatManager.has_line_of_sight(eye_pos, target_pos, [self])

	# Exposure clock (DESIGN 4.2 fairness: accuracy ramps with EXPOSURE TIME).
	# Ticks in real time (_think_interval_current - think LOD runs slower at
	# range). LOS loss DRAINS at 3x build rate instead of hard-resetting: brief
	# foliage blinks keep most of the ramp, ~0.8s truly broken zeroes it -
	# repositioning resets your death clock, peek-strobing does not.
	if new_los:
		target_visible_duration += _think_interval_current
		last_known_target_pos = target.global_position
		target_last_seen_time = 0.0
	else:
		target_last_seen_time += _think_interval_current
		target_visible_duration = maxf(0.0, target_visible_duration - _think_interval_current * 3.0)

	# CONTACT CONFIDENCE (war-room decree): the debounced "I see him" that
	# GOALS read - builds full in ~0.3s of eyes-on, drains empty over ~2.0s
	# blind. LOS flicker can no longer flip a decision; only FIRING reads the
	# raw boolean. Deliberately slower than the exposure drain, so accuracy
	# forgives a repositioning player before intent gives up on him.
	if new_los:
		contact_conf = minf(1.0, contact_conf + _think_interval_current / 0.3)
	else:
		contact_conf = maxf(0.0, contact_conf - _think_interval_current / 2.0)

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


## HLL doctrine state (2026-07-10 pass): how long we've been in contact with
## the current target, and how many cover searches came up dry (escape hatch
## so the cover-first doctrine can't produce passive cowards).
var _contact_time: float = 0.0
var _cover_fail_count: int = 0
var _bound_point: Vector3 = Vector3.ZERO
var _bound_pause: float = 0.0
var _bound_fail_count: int = 0


func _evaluate_goals() -> void:
	goal_timer += THINK_INTERVAL

	# Dwell (Summoner: highly reactive dial = ~1s; smoothness comes from the
	# contact-confidence debounce, not long commitments). Class-A interrupts
	# (taking damage) force goal_timer past this gate from take_damage().
	if goal_timer < 1.0 and current_goal != Enums.AIGoal.NONE:
		return

	# A rush COMPLETES: while moving to claimed cover, hold the goal until
	# arrival (cap 4s so a blocked path can't lock a man forever).
	if current_goal == Enums.AIGoal.SEEK_COVER and _moving_to_cover and goal_timer < 4.0:
		return

	var best_goal: Enums.AIGoal = Enums.AIGoal.NONE
	var best_score: float = 0.0

	# No target - investigate or hold
	if not target or not is_instance_valid(target):
		_contact_time = 0.0
		_cover_fail_count = 0
		if last_known_target_pos != Vector3.ZERO and target_last_seen_time < 5.0:
			best_goal = Enums.AIGoal.INVESTIGATE
		else:
			best_goal = Enums.AIGoal.HOLD_POSITION
		_set_goal(best_goal)
		return

	_contact_time += _think_interval_current
	var dist := global_position.distance_to(target.global_position)
	var now_ms: float = float(Time.get_ticks_msec())

	# Evaluate each possible goal
	var scores: Dictionary = {}

	# Goals read the DEBOUNCED contact confidence, never raw LOS (decree):
	# a leaf blinking the ray cannot flip a man's plan.
	var eyes_on: bool = contact_conf > 0.5

	# ENGAGE - direct combat. COVER-FIRST DOCTRINE (Caleb/HLL): caught in the
	# open on fresh contact, the duel can wait - reach cover or concealment
	# first. Fighting FROM cover is the preferred engagement.
	var engage_score: float = 0.5
	if eyes_on:
		engage_score += 0.3
	if dist < preferred_range * 1.2 and dist > preferred_range * 0.5:
		engage_score += 0.2  # In comfortable range
	if has_cover:
		engage_score += 0.15
	elif _contact_time < 5.0 and char_aggression < 0.75 and _cover_fail_count < 2:
		engage_score *= 0.55
	scores[Enums.AIGoal.ENGAGE_TARGET] = engage_score * (1.0 - threat_level * 0.3)

	# SEEK COVER - preemptive on fresh contact in the open, not just reactive.
	var cover_score: float = threat_level * 0.7 + char_self_preservation * 0.3
	if suppression_level > 0.5:
		cover_score += 0.3
	if not has_cover:
		cover_score += 0.2
		if _contact_time < 6.0 and _cover_fail_count < 2:
			cover_score += 0.4 * (1.0 - char_aggression * 0.7)
	scores[Enums.AIGoal.SEEK_COVER] = cover_score if d_uses_cover else -1.0

	# SUPPRESS - pin down target
	var suppress_score: float = 0.3
	if eyes_on and weapon_data and weapon_data.firing_mode == Enums.FiringMode.FULL_AUTO:
		suppress_score += 0.3
	if dist > preferred_range:
		suppress_score += 0.2  # Good at range
	scores[Enums.AIGoal.SUPPRESS_TARGET] = suppress_score * (1.0 - char_aggression * 0.3)

	# FLANK - move to better position
	var flank_score: float = char_aggression * 0.4
	if not eyes_on and target_last_seen_time < 3.0:
		flank_score += 0.3
	if threat_level < 0.3:
		flank_score += 0.2
	scores[Enums.AIGoal.FLANK_TARGET] = flank_score if d_flanks else -1.0

	# ADVANCE - push forward. OPEN-GROUND DISCIPLINE: crossing needs covering
	# fire from a squadmate (fire-and-maneuver) or real aggression; a lone
	# unsupported man holds and shoots instead of charging.
	var advance_score: float = char_aggression * 0.4
	if dist > preferred_range * 1.5:
		advance_score += 0.25
	if threat_level < 0.2 and dist < preferred_range * 2.0:
		advance_score += 0.15
	if EnemySquad.has_covering_fire(squad_id, self, now_ms):
		advance_score += 0.2
	elif char_aggression < 0.7:
		advance_score *= 0.45
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

	# Incumbent hysteresis 25% (council: 15% was smaller than the input swing
	# it guarded against; with confidence-smoothed inputs, 25% actually holds).
	if scores.has(current_goal):
		scores[current_goal] *= 1.25

	# Find best goal
	for goal in scores:
		if scores[goal] > best_score:
			best_score = scores[goal]
			best_goal = goal

	if best_goal != current_goal:
		_set_goal(best_goal)


func _set_goal(new_goal: Enums.AIGoal) -> void:
	# Keep the cover claim when transitioning into a FIGHTING goal - releasing
	# it on SEEK_COVER->ENGAGE made has_cover flip false and the goals oscillate
	# (reach cover, engage, lose claim, seek cover again, forever).
	if current_goal == Enums.AIGoal.SEEK_COVER \
			and new_goal != Enums.AIGoal.SEEK_COVER \
			and new_goal != Enums.AIGoal.ENGAGE_TARGET \
			and new_goal != Enums.AIGoal.SUPPRESS_TARGET:
		_release_cover()
	if current_goal == Enums.AIGoal.ADVANCE and new_goal != Enums.AIGoal.ADVANCE:
		if _bound_point != Vector3.ZERO:
			_release_cover_point(_bound_point)
			_bound_point = Vector3.ZERO
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
	# Sentry scan: a standing guard sweeps his gaze so he can actually notice a
	# player approaching from off-axis. Without this, perception is FOV-gated and
	# an idle enemy facing the wrong way is blind forever - it never turns because
	# it has no target, and it has no target because it never turns.
	if target == null and alert_tier <= AlertTier.SUSPICIOUS:
		_scan_phase += delta * SCAN_SPEED
		var base_yaw: float = atan2(_home_facing.x, _home_facing.z)
		var yaw: float = base_yaw + sin(_scan_phase) * SCAN_ARC
		facing_dir = Vector3(sin(yaw), 0.0, cos(yaw))


func _execute_alert(delta: float) -> void:
	# Search the breadcrumb trail - chase where they WENT, newest crumb not yet
	# reached, not the single last pixel they were seen at. Falls back to the
	# lone last-known point when there is no squad / no trail.
	var goal_pos: Vector3 = last_known_target_pos
	if squad_id >= 0:
		var sp := EnemySquad.search_point(squad_id, global_position, 3.0)
		if sp != Vector3.ZERO:
			goal_pos = sp
	if goal_pos != Vector3.ZERO:
		if global_position.distance_to(goal_pos) > 2.0:
			_move_toward(goal_pos, delta)
		else:
			# Reached the crumb - slow and let the sentry scan sweep for them.
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

		# Covered men HOLD their cover: damp the wander hard while has_cover
		# (this IS the engage-from-cover feel); drifting off invalidates it.
		if has_cover:
			if current_cover != Vector3.ZERO and global_position.distance_to(current_cover) > 2.5:
				_release_cover()
			else:
				move_dir *= 0.15

		# Apply strafe
		if strafe_direction != 0.0:
			var strafe_vec := transform.basis.x * strafe_direction
			if has_cover:
				move_dir = move_dir + strafe_vec * 0.1  # micro-shuffle in place
			else:
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
		# ANTI-SPAM (Caleb): the old roll ran per-FRAME (~70%/sec!). Hazard-rate
		# roll (~1.7s expected beat) + the squad/global broker: max one grenade
		# in the AO per 5s, one per squad per 12s, one per man per 15s.
		grenade_cooldown = maxf(0.0, grenade_cooldown - delta)
		if grenades_left > 0 and grenade_cooldown <= 0.0 and target_last_seen_time < 3.0:
			var throw_dist := global_position.distance_to(last_known_target_pos)
			if throw_dist > 8.0 and throw_dist < 30.0 and randf() < 0.35 * delta \
					and EnemySquad.grenade_ready(squad_id, float(Time.get_ticks_msec())):
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
				else:
					_cover_fail_count += 1  # doctrine escape hatch: 2 dry searches lift cover-first

	# Concealment fallback (zero raycasts): deep vegetation counts as soft
	# cover - the man melts into the bush instead of dancing in the open.
	if not has_cover and not _moving_to_cover and _grid != null \
			and _grid.get_vegetation(global_position) > 0.6:
		has_cover = true
		cover_quality = 0.4
		current_cover = global_position
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


## BOUNDING ADVANCE (HLL doctrine, Caleb: "they don't just run out in the
## open"): rush cover-to-cover toward the target - sprint to a bound point,
## pause, burst, next bound. Two dry bound searches -> the old straight
## advance at reduced speed (open crossers exist, and they die fast).
func _execute_advancing(delta: float) -> void:
	if not target:
		return

	var to_target := (target.global_position - global_position).normalized()

	# Pause at the bound: settle, shoot, then pick the next rush.
	if _bound_pause > 0.0:
		_bound_pause -= delta
		velocity.x = lerpf(velocity.x, 0.0, delta * 8.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 8.0)
		accuracy_modifier = base_accuracy_modifier * 1.1
		if has_line_of_sight and can_fire and has_reacted:
			if burst_count < 3:
				_fire_at_target()
				burst_count += 1
			else:
				can_fire = false
				fire_timer = randf_range(0.3, 0.8)
				burst_count = 0
		return

	if _bound_point != Vector3.ZERO:
		if global_position.distance_to(_bound_point) < 1.2:
			_release_cover_point(_bound_point)
			_bound_point = Vector3.ZERO
			_bound_pause = randf_range(0.8, 1.6)
			return
		# Sprint the rush: full speed, honest fire penalty on the move.
		_move_toward(_bound_point, delta, 1.0)
		accuracy_modifier = base_accuracy_modifier * 1.6
		if has_line_of_sight and can_fire and has_reacted and burst_count < 2:
			_fire_at_target()
			burst_count += 1
		return

	# Need a bound point (throttled: <=12 rays at <=1Hz, only while advancing).
	if _bound_fail_count < 2:
		_cover_search_timer -= delta
		if _cover_search_timer <= 0.0:
			_cover_search_timer = 1.0
			var p := _find_bound_point(to_target)
			if p != Vector3.ZERO:
				_bound_point = p
				_bound_fail_count = 0
				return
			else:
				_bound_fail_count += 1
		velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)
		if has_line_of_sight and can_fire and has_reacted and burst_count < 3:
			_fire_at_target()
			burst_count += 1
		return

	# Fallback: the old straight advance, slower - crossing open ground for real.
	var perpendicular := Vector3(-to_target.z, 0, to_target.x) * strafe_direction * 0.2
	var move_dir := (to_target + perpendicular).normalized()

	velocity.x = move_dir.x * move_speed * 0.85
	velocity.z = move_dir.z * move_speed * 0.85

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
	# Routed men have no target (they dropped the fight) - flee the last
	# known threat instead of freezing (morale decree).
	var threat: Vector3 = Vector3.ZERO
	if target != null and is_instance_valid(target):
		threat = target.global_position
	elif last_known_target_pos != Vector3.ZERO:
		threat = last_known_target_pos
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)
		return

	var away_from_target := (global_position - threat).normalized()
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


## Claimant loosened to Node: ALLIES share this broker now (squad cover
## parity, Caleb) - friend and foe never stack on the same rock.
## Crowding cost for DISPERSION (decree: no corner piles) - claimed points
## within 4m make a candidate expensive. Distance math only, zero raycasts.
static func _crowding_cost(pos: Vector3) -> float:
	var cost: float = 0.0
	for key in _cover_claims.keys():
		var claim_pos := Vector3(float((key as Vector3i).x), float((key as Vector3i).y), float((key as Vector3i).z)) * COVER_CELL
		var d: float = pos.distance_to(claim_pos)
		if d < 4.0:
			cost += 6.0 * (1.0 - d / 4.0)
	return cost


static func _claim_cover(pos: Vector3, claimant: Node) -> bool:
	var key := _cover_key(pos)
	var existing: Dictionary = _cover_claims.get(key, {})
	var owner: Node = existing.get("enemy")
	if owner != null and is_instance_valid(owner) and owner != claimant \
			and not (owner.has_method("is_dead") and owner.is_dead()):
		return false
	_cover_claims[key] = {"enemy": claimant}
	return true


func _release_cover() -> void:
	if current_cover != Vector3.ZERO:
		var key := EnemyBase._cover_key(current_cover)
		if EnemyBase._cover_claims.get(key, {}).get("enemy") == self:
			EnemyBase._cover_claims.erase(key)
	has_cover = false
	cover_quality = 0.0
	_moving_to_cover = false


## Release a specific claimed point (bound points use the same claim broker
## as cover so two men never rush the same rock).
func _release_cover_point(pos: Vector3) -> void:
	if pos == Vector3.ZERO:
		return
	var key := EnemyBase._cover_key(pos)
	if EnemyBase._cover_claims.get(key, {}).get("enemy") == self:
		EnemyBase._cover_claims.erase(key)


## A bound point: cover ~5m TOWARD the target (fire-and-maneuver step), found
## with the same LOS-blocking raycast test + claim broker as _find_cover_point.
func _find_bound_point(to_target: Vector3) -> Vector3:
	var threat_pos: Vector3 = last_known_target_pos if last_known_target_pos != Vector3.ZERO else global_position
	var center: Vector3 = global_position + to_target * 5.0
	var space_state := get_world_3d().direct_space_state
	var candidates: Array[Vector3] = []
	for off in COVER_SEARCH_OFFSETS:
		var candidate: Vector3 = center + off
		# a bound must actually gain ground
		if candidate.distance_to(threat_pos) >= global_position.distance_to(threat_pos) - 1.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			candidate + Vector3.UP * 1.3, threat_pos + Vector3.UP * 1.0, 1 | 32)
		query.exclude = [self]
		if space_state.intersect_ray(query):
			candidates.append(candidate)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return global_position.distance_to(a) + EnemyBase._crowding_cost(a) \
			< global_position.distance_to(b) + EnemyBase._crowding_cost(b))
	for c in candidates:
		if EnemyBase._claim_cover(c, self):
			return c
	return Vector3.ZERO


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
		return global_position.distance_to(a) + EnemyBase._crowding_cost(a) \
			< global_position.distance_to(b) + EnemyBase._crowding_cost(b))
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
	total_spread *= _exposure_spread_mult()  # DESIGN 4.2: accuracy ramps with exposure, alert != accuracy
	total_spread *= GameSettings.enemy_spread_mult()  # W82 difficulty
	var spread: float = deg_to_rad(total_spread)
	EnemySquad.report_firing(squad_id, self, float(Time.get_ticks_msec()))

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
			_fired_until_ms = float(Time.get_ticks_msec()) + 350.0
			return
		push_error("[EnemyBase] %s names a projectile that will not load: %s" % [
			weapon_data.id, weapon_data.projectile_data_path])

	var space_state := get_world_3d().direct_space_state
	# FULL-REALISM FRIENDLY FIRE (Summoner decree): the ray sees EVERYONE -
	# world, player, enemies, both hurtbox layers. Muzzle discipline below
	# keeps the AI from massacring its own squad.
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_aim * weapon_data.max_range,
		1 | 2 | 4 | 32 | 64
	)
	query.collide_with_areas = true  # player/ally hitzones are Area3D (sponge fix)
	query.exclude = [self]

	var result := space_state.intersect_ray(query)

	# MUZZLE DISCIPLINE: a squadmate in the lane = don't squeeze. The skipped
	# round costs cadence, not ammo - reads as trigger discipline.
	if result:
		var lane: Object = result.collider
		var lane_owner: Node = (lane as Hitzone).owner_entity if lane is Hitzone else lane as Node
		if lane_owner != null and lane_owner != self and is_instance_valid(lane_owner) \
				and lane_owner.is_in_group("enemies") and lane_owner != target:
			return

	# Suppression (R11): if this round CRACKED PAST the player without hitting
	# them, press them. The shot line is origin -> tracer_end; measure the
	# player's perpendicular distance to it. A hit is not a near-miss (that is
	# damage, handled below). This is what makes the player want to get down.
	_suppress_player_if_near(origin, final_aim, result)

	# REAL PROJECTILES (7ks): the round is a live BulletSystem bullet - muzzle
	# spawn, gravity drop, travel time, arrival damage/FX through the shared
	# resolver (zone mults, W37 wound rolls, blood at the point of arrival).
	# The tracer IS the bullet; color/ratio come from WeaponData (nx9n - the
	# hardcoded every-round green dies here). Muzzle flash still betrays the
	# shooter's position; the lane-check ray above still enforces discipline.
	var fx_origin: Vector3 = get_muzzle_visual(final_aim)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, origin, 1)
	GunFX.play_shot_3d(get_tree().current_scene, fx_origin, weapon_data)
	GunFX.muzzle_flash(get_tree().current_scene, fx_origin)
	_fired_until_ms = float(Time.get_ticks_msec()) + 350.0
	var show_tracer: bool = weapon_data.tracer_ratio > 0 \
		and (shots_fired % weapon_data.tracer_ratio) == 0
	# FULL-REALISM FRIENDLY FIRE mask ports verbatim from the retired ray.
	CombatManager.bullets.fire(weapon_data, self, origin, final_aim,
		1 | 2 | 4 | 32 | 64, [self], show_tracer)


## W45: telegraph shout, then lob a real grenade at the last-known position.
func _throw_grenade() -> void:
	grenades_left -= 1
	grenade_cooldown = 15.0
	EnemySquad.claim_grenade(squad_id, float(Time.get_ticks_msec()))
	# Telegraph: shout (noise event draws attention both ways) + floating text.
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1)
	VOManager.play_enemy("grenade", self)
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

func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null, zone: String = "BODY") -> int:
	if current_state == Enums.AIState.DEAD:
		return 0
	# FINISH verb: any further damage on a downed man is final.
	if is_downed:
		current_hp = 0
		_credit_killer(attacker)
		_die()
		return amount
	# Locational outcome (anti-sponge decree): a headshot is a headshot.
	var raw_amount: int = amount  # pre-override weapon damage (head burst gate)
	if zone == "HEAD":
		amount = current_hp + 999

	current_hp -= amount
	damage_taken_recently += amount
	damage_decay_timer = 0.0
	goal_timer = 99.0  # Class-A interrupt (decree): getting HIT may always re-plan

	# Remember where it came from so _die() can pick death_forward vs
	# death_from_right. take_damage() knew this all along and threw it away.
	if attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		last_hit_dir = (global_position - (attacker as Node3D).global_position).normalized()
		# Honest attention: whoever is HURTING me outranks whoever is closest.
		if (attacker as Node).is_in_group("player") or (attacker as Node).is_in_group("allies"):
			_last_attacker = attacker as Node3D
			_last_attacker_ms = float(Time.get_ticks_msec())

	# Visual feedback
	if sprite_actor != null:
		sprite_actor.flash(Color(1.6, 0.5, 0.5), 0.1)
	elif mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if mesh and mesh.material_override:
				mesh.material_override.albedo_color = Color(0.4, 0.4, 0.3)
		)

	# GUT: devastating - immediate crawl + bleed-out. Untreated he dies in ~15-20s.
	if zone == "GUT" and current_hp > 0 and _gut_bleed_dps <= 0.0:
		_gut_bleed_dps = 4.0
		_become_crippled()
	# W46: badly shot men may go down crawling - slow, loud, drawing their buddies.
	if not is_crippled and current_hp > 0 and current_hp < max_hp / 4 and randf() < 0.35:
		_become_crippled()

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

	# Pain-quota stagger (DESIGN 4.3): a solid hit (>= a third of max HP) that does
	# not kill jolts them into a brief SUPPRESSED stagger + a pain grunt, selling the
	# impact and buying the player a beat. Reuses apply_stagger() (was never called).
	if current_hp > 0 and amount >= max_hp / 3:
		apply_stagger(1.0)
		NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 20.0)

	# Check death
	if current_hp <= 0:
		var overkill: int = -current_hp
		current_hp = 0
		# DOWN-NOT-DEAD v1 (bead 5iha): a barely-lethal hit can leave a man
		# dying but not dead. Never on headshots (fatal is fatal), explosives,
		# or the surrendered. Overkill margin weights the roll: 35% at zero
		# margin, fading to 0 at 40+ overkill damage.
		if zone != "HEAD" and not is_surrendered \
				and _damage_type == Enums.DamageType.PHYSICAL:
			var down_chance: float = clampf(0.35 * (1.0 - float(overkill) / 40.0), 0.0, 0.35)
			if randf() < down_chance:
				_become_downed()
				return amount
		# HEAD BURST (bead rc55): heavy fatal headshots (60+ raw - the shotgun
		# slug execution class) occasionally shatter. No-ops silently until a
		# rig ships head_frag_* fragments; one-piece pop stays the default.
		if zone == "HEAD" and _visual_is_model and raw_amount >= 60 and randf() < 0.25:
			GibSystem.dismember_head_burst(sprite_actor as ModelActor, last_hit_dir, get_tree().current_scene)
		_credit_killer(attacker)
		_die()
	elif not is_surrendered:
		# MORALE (war-room decree, Summoner: "in war everyone's goal is to
		# survive"): courage-powered break ladder. Low-courage men (Local
		# Force) BREAK under pressure - rout (forced retreat, drop the fight)
		# or, badly wounded and shaken, throw the rifle down (Chieu Hoi).
		# NVA/sapper courage holds the line (canon: Local Force breaks, NVA
		# doesn't). Uses existing threat_level - no new perception work.
		var courage: float = enemy_data.courage if enemy_data != null else 0.5
		var pressure: float = threat_level + (1.0 - float(current_hp) / float(max_hp)) * 0.5
		if pressure > 0.7 + courage * 0.6 and randf() < 0.25:
			var living_nearby: int = 0
			for e in get_tree().get_nodes_in_group("enemies"):
				var other := e as EnemyBase
				if other != self and other and not other.is_dead() \
						and other.global_position.distance_to(global_position) < 30.0:
					living_nearby += 1
			if living_nearby == 0 and current_hp < max_hp / 3 and randf() < 0.4:
				try_surrender()  # alone, hurt, broken: hands up
			else:
				# ROUT: drop the fight and run for the rear.
				target = null
				contact_conf = 0.0
				_set_goal(Enums.AIGoal.RETREAT)
				goal_timer = -3.0  # committed flight - no re-plan for ~4s
				VOManager.play_enemy("retreat", self)

	return amount


## Learn-by-doing: credit the killing squadmate's Small Arms + tally his kill. The player
## grows via team_xp, not this, so only allies (who carry a `member` dict) are credited.
func _credit_killer(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var mv: Variant = attacker.get("member")
	if not (mv is Dictionary):
		return
	var m: Dictionary = mv
	if m.is_empty():
		return
	m["kills"] = int(m.get("kills", 0)) + 1
	var promo: int = SquadRoster.credit_use(m, "small_arms", 1)
	if promo > 0 and attacker.has_method("on_skill_up"):
		attacker.on_skill_up("small_arms", promo)


## Crawling, slow, loud - the shared "down but not out" state (W46 + gutshot).
func _become_crippled() -> void:
	if is_crippled:
		return
	is_crippled = true
	move_speed *= 0.25
	base_accuracy_modifier *= 1.6  # crippled: durable, was wiped next tick
	if sprite_actor != null:
		sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_faction), str(enemy_data.sprite_unit), str(enemy_data.sprite_weapon), "crippled"))
	elif mesh:
		mesh.scale.y = 0.45
		mesh.position.y = -0.35
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 30.0)


## W37/locational: limb hits degrade the man - arm = shaky aim, leg = slowed;
## a second leg wound puts him down crawling. Mirrors the player's apply_wound.
var _leg_wounds: int = 0
func apply_wound(zone_name: String) -> void:
	if zone_name == "LIMB_ARM":
		base_accuracy_modifier *= 1.35
	else:
		move_speed = maxf(move_speed * 0.6, 0.8)
		_leg_wounds += 1
		if _leg_wounds >= 2:
			_become_crippled()


func apply_suppression(amount: float) -> void:
	suppression_level = minf(1.0, suppression_level + amount)
	incoming_fire_timer = 0.5


func apply_stagger(power: float) -> void:
	if power >= 1.0 and current_state != Enums.AIState.DEAD:
		suppression_level = minf(1.0, suppression_level + 0.5)
		_change_state(Enums.AIState.SUPPRESSED)


## DOWN-NOT-DEAD v1 (bead 5iha, research sec 9): dying, not dead. IRON LAW:
## he never re-fights. Bleeds out in 45-90s unless SECURED; further damage =
## the FINISH verb. Growing blood pool + audible pain are the honest
## aliveness signals that separate him from a corpse.
var is_downed: bool = false
var _downed_bleed_s: float = 0.0
var _downed_fx_s: float = 0.0
var _died_emitted: bool = false


func _become_downed() -> void:
	is_downed = true
	current_hp = 1
	_downed_bleed_s = randf_range(45.0, 90.0)
	_downed_fx_s = randf_range(1.5, 4.0)
	weapon_data = null
	target = null
	contact_conf = 0.0
	velocity = Vector3.ZERO
	_release_cover()
	# Out of the FIGHT immediately: squads stop counting him, allies stop
	# shooting (is_dead() true), wave counters advance.
	CombatManager.unregister_enemy(self)
	if not _died_emitted:
		_died_emitted = true
		died.emit(self)
	if sprite_actor != null and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play("laying_breathless", true)
	elif sprite_actor != null:
		sprite_actor.play(SpriteStateMap.clip_for(false, str(enemy_data.sprite_faction), str(enemy_data.sprite_unit), str(enemy_data.sprite_weapon), "crippled"))
	VOManager.play_enemy("pain", self)


## SECURE verb: stabilize + capture a downed man. Feeds the same intel /
## capture economy as surrender (W63).
func secure() -> bool:
	# NOTE: is_dead() is true while downed (by design) - check the real state.
	if not is_downed or current_state == Enums.AIState.DEAD:
		return false
	_downed_bleed_s = 9e9
	add_to_group("surrendered")
	add_to_group("captured")
	return true


func _die() -> void:
	GunFX.blood_pool(get_tree().current_scene, global_position)  # kill pool spreads under him
	_change_state(Enums.AIState.DEAD)
	_release_cover()
	CombatManager.unregister_enemy(self)
	if not _died_emitted:
		_died_emitted = true
		died.emit(self)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if is_downed:
		# He was already lying in laying_breathless - do not whip a standing
		# death clip over the pose. The pool and stillness read the change.
		is_downed = false
		add_to_group("lootable_corpses")
		get_tree().create_timer(45.0).timeout.connect(queue_free)
		return

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
		sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_faction), str(enemy_data.sprite_unit), str(enemy_data.sprite_weapon), intent), true)
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
		sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_faction), str(enemy_data.sprite_unit), str(enemy_data.sprite_weapon), "surrender"), true)
		sprite_actor.set_base_modulate(Color(1.15, 1.15, 0.95))
	elif mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color(0.7, 0.7, 0.6)
	VOManager.play_enemy("surrender", self)
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
	# Downed counts: he is out of the fight (targeting drops him, waves count
	# him) even though the body is warm - mirrors the player's is_dead().
	return current_state == Enums.AIState.DEAD or is_downed


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


## A round from origin along dir cracked by - if it passed close to the player
## and did NOT hit them, add suppression. NEAR_MISS_RADIUS is generous (the
## snap of a supersonic round is felt wider than its miss distance).
const NEAR_MISS_RADIUS: float = 2.2

func _suppress_player_if_near(origin: Vector3, dir: Vector3, hit: Dictionary) -> void:
	var pl := GameManager.player as Node3D
	if pl == null or not is_instance_valid(pl):
		return
	# If the ray actually hit the player, that is damage, not a near-miss.
	if hit and hit.get("collider") != null:
		var c = hit.collider
		if c is Node and ((c as Node).is_in_group("player") or ((c as Node).get_parent() and (c as Node).get_parent().is_in_group("player"))):
			return
	# Perpendicular distance from the player (centre mass) to the shot line.
	var to_p: Vector3 = (pl.global_position + Vector3.UP * 1.0) - origin
	var along: float = to_p.dot(dir)
	if along <= 0.0:
		return  # shot went the other way
	var closest: Vector3 = origin + dir * along
	var d: float = closest.distance_to(pl.global_position + Vector3.UP * 1.0)
	if d < NEAR_MISS_RADIUS and pl.has_method("add_suppression"):
		# Closer cracks press harder.
		pl.add_suppression(SUPPRESS_ON_MISS * (1.0 - d / NEAR_MISS_RADIUS))


const SUPPRESS_ON_MISS: float = 0.34
