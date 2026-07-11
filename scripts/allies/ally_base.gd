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
## Seconds since we last had eyes on the target (mirrors EnemyBase) - recent
## contact keeps a follower FIGHTING instead of falling back to heel.
var target_last_seen_time: float = 999.0
## Human beat between acquiring a new target and the first aimed shot.
var _aim_settle: float = 0.0
## Debounced eyes-on 0-1 (war-room decree): goals read THIS, never raw LOS.
var contact_conf: float = 0.0
## Animation intent stability filter + fire latch (smoothness plan T1.3/T1.4).
var _last_intent: String = ""
var _cand_intent: String = ""
var _cand_since: float = -1e9
var _fired_until_ms: float = -1e9
var _cover_pose_until_ms: float = -1e9  # T1.5a: min hold before hold/peek re-pick
var _hitzone_sync: Array = []           # [[hz, bone_idx, offset]..] - zones ride bones

## Stuck watchdog (mirrors EnemyBase): trying to move but pinned -> sidestep.
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
			_unstick_dir = -_unstick_dir
		_stuck_pos = global_position
		_stuck_t = 0.0
## Goal dwell + contact clock (decree: ~1s reactive dwell, Class-A interrupts).
var goal_timer: float = 99.0
var _contact_time: float = 0.0

## ---- PERSONALITY SPECTRUM (Summoner: "everyone's goal is to survive...
## there can be men that cower or anchor and complain and miss, and total
## go-getters getting kills"). Rolled random per man, per playthrough.
## courage: <0.35 = the coward (anchors deep, suppressive fire, sluggish),
##          >0.70 = the go-getter (pushes with the player, skips the cover trip)
## skill:   scales personal spread (0 = sprays, 1 = deadly)
var courage: float = 0.5
var skill: float = 0.5
const RALLY_RADIUS: float = 6.0
const RALLY_BONUS: float = 0.25  # presence rally (Army doctrine): lead from the front


## Effective nerve right now - the player standing close steadies a man.
func effective_courage() -> float:
	var c: float = courage
	var p := GameManager.player
	if p != null and is_instance_valid(p) and p is Node3D:
		if global_position.distance_to((p as Node3D).global_position) < RALLY_RADIUS:
			c += RALLY_BONUS
	return clampf(c, 0.0, 1.0)
var has_line_of_sight: bool = false

## Aim interpolation
var current_aim_dir: Vector3 = Vector3.FORWARD
var target_aim_dir: Vector3 = Vector3.FORWARD
var aim_speed: float = 7.0

## Follow player
var follow_distance: float = 5.0
var max_follow_distance: float = 15.0

## Squad layer (W14-W16): roster identity + orders.
enum OrderMode { FOLLOW, HOLD, MOVE_TO }
var member: Dictionary = {}      ## roster entry (name/mos/stats) - IS the roster dict
var director: MissionDirector = null  ## toast channel for learn-by-doing promotion barks


## Promotion bark surfaced at the moment of the deed (War Room decree - visibility is
## 90% of the value). Called when this soldier's skill levels up from doing the thing.
func on_skill_up(skill_id: String, level: int) -> void:
	if director == null:
		return
	var sk_name: String = str(SkillCatalog.SKILLS.get(skill_id, {}).get("name", skill_id))
	director.toast.emit("%s — %s ★%d" % [str(member.get("nick", "GRUNT")), sk_name, level])
var order_mode: OrderMode = OrderMode.FOLLOW
var order_pos: Vector3 = Vector3.ZERO
## Personal formation slot around the player (rolled once) - the squad spreads
## into an arc instead of stacking on the player's back (Caleb).
var _follow_offset: Vector3 = Vector3.ZERO
var weapons_free: bool = true
var fire_rate_mult: float = 1.0  ## Pigman sustained-fire bonus


func set_order(mode: OrderMode, pos: Vector3 = Vector3.ZERO) -> void:
	order_mode = mode
	order_pos = pos

## Combat behavior
var strafe_direction: float = 0.0
var strafe_timer: float = 0.0
var shots_fired: int = 0
var burst_count: int = 0
const MAX_BURST: int = 6

## Suppression
var suppression_level: float = 0.0
const SUPPRESSION_DECAY: float = 0.4

## ---- COVER (squad parity with EnemyBase R15, Caleb 2026-07-10) ----
## Same raycast LOS-block sampling + the SAME claim broker as enemies, so
## friend and foe never stack on one rock. Cover-first doctrine: in contact
## and in the open -> reach cover, THEN fight from it.
var has_cover: bool = false
var current_cover: Vector3 = Vector3.ZERO
var _moving_to_cover: bool = false
var _cover_search_timer: float = 0.0
var _cover_fail_count: int = 0
## Animation override for cover behavior (leap in, crouch-hold, peek). Rigs
## differ, so these are fallback chains resolved by ModelActor.play_first.
var _anim_override: String = ""
var _leap_until_ms: float = -1e9
const LEAP_CLIPS: Array[String] = ["falling_to_roll", "stand_to_cover", "idle_crouching", "kneeling_pointing"]
const COVER_HOLD_CLIPS: Array[String] = ["idle_crouching_aiming", "kneeling_pointing", "idle_crouching", "rifle_aiming_idle"]
const COVER_PEEK_CLIPS: Array[String] = ["idle_aiming", "rifle_aiming_idle", "firing_rifle"]
const RUSH_CLIPS: Array[String] = ["sprint_forward", "run_forward", "start_walking"]

## Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Visual
var mesh: MeshInstance3D
var sprite_actor: Node3D = null  ## ModelActor (default) or SpriteActor (fallback)
var _visual_is_model: bool = false
var last_hit_dir: Vector3 = Vector3.FORWARD
## Which rendered unit this man wears. SquadSystem overrides for the PIGMAN,
## who carries an M60 and was rendered as a separate unit.
var sprite_faction: String = "US Army and Co"
## us_grunt_v2 (Caleb): the gib-rig grunt is THE squadmate model - full gore
## contract, the big clip library, and the cover/crouch animation set.
var sprite_unit: String = "us_grunt_v2"
var sprite_weapon: String = "m16a1"


func _ready() -> void:
	add_to_group("allies")
	CombatManager.register_ally(self)
	var slot_angle: float = randf_range(0.0, TAU)
	_follow_offset = Vector3(cos(slot_angle), 0.0, sin(slot_angle)) * randf_range(2.5, 4.5)
	# The man he is this playthrough (decree: random spectrum, roster later).
	courage = randf()
	skill = randf()

	# Default ally weapon: M16A1 (matches the m16 models/sprites — audit)
	weapon_data = load("res://data/weapons/m16a1.tres")

	_setup_visual()
	_setup_hurtbox()

	current_aim_dir = -global_transform.basis.z


func _setup_visual() -> void:
	if not sprite_unit.is_empty():
		if ModelActor.model_exists(sprite_unit):
			var ma := ModelActor.new()
			add_child(ma)
			if ma.setup(sprite_unit):
				sprite_actor = ma
				_visual_is_model = true
				sprite_actor.play(SpriteStateMap.model_clip_for("idle"))
				return
			ma.queue_free()
		var sa := SpriteActor.new()
		add_child(sa)
		sa.setup(sprite_faction, sprite_unit, sprite_weapon)
		if sa.play(SpriteStateMap.resolve(sprite_faction, sprite_unit, sprite_weapon, "idle")):
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
	mat.albedo_color = Color(0.3, 0.35, 0.25)  # Olive drab (US Army)
	mesh.material_override = mat

	add_child(mesh)


## SquadSystem assigns MOS AFTER spawn_ally() has already run _ready(), so the
## Pigman's M60 sheets have to swap in after the fact. Rebuilds the actor.
func set_sprite(unit: String, weapon: String, faction: String = "US Army and Co") -> void:
	if unit == sprite_unit and weapon == sprite_weapon:
		return
	sprite_faction = faction
	sprite_unit = unit
	sprite_weapon = weapon
	if sprite_actor != null:
		sprite_actor.queue_free()
		sprite_actor = null
	if mesh != null:
		mesh.queue_free()
		mesh = null
	_setup_visual()


## AllyBase has no facing_dir (EnemyBase does, at :76). Derive it: aim at a
## target if we have one, otherwise face where we are walking.
func _update_sprite() -> void:
	if sprite_actor == null:
		return
	var facing: Vector3 = current_aim_dir
	# T1.2 stale-aim fix: without LOS, current_aim_dir never updates - an ally
	# chasing last-known ran sideways facing his OLD aim, then snapped when
	# LOS returned. Moving without eyes-on = face where you're going.
	if target == null or not has_line_of_sight:
		var vel := Vector3(velocity.x, 0.0, velocity.z)
		if vel.length_squared() > 0.09:
			facing = vel
	sprite_actor.set_facing(facing)
	if current_state == Enums.AIState.DEAD:
		return
	var vel_flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = vel_flat.length()
	var lateral: float = 0.0
	if speed > 0.1:
		var fwd := Vector3(facing.x, 0.0, facing.z).normalized()
		lateral = vel_flat.normalized().dot(fwd.cross(Vector3.UP))
	var now: float = float(Time.get_ticks_msec())
	# T1.3: fire pose follows the actual shot (350ms latch), not the cooldown
	# tail before the NEXT shot.
	var firing: bool = now < _fired_until_ms
	# Cover behavior owns the clip while an override is set (leap / crouch-hold
	# / peek) - the state map would stomp it every frame otherwise.
	if _anim_override != "" and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play(_anim_override)
		(sprite_actor as ModelActor).set_locomotion_speed(speed)
		return
	var intent: String = SpriteStateMap.intent_for(current_state, false, false, firing, speed, lateral)
	# T1.4 stability filter: intent must win continuously for 180ms before the
	# clip commits (1-frame blips can never grab the clip). Fire/death bypass.
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
	sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, sprite_faction, sprite_unit, sprite_weapon, intent))
	if sprite_actor is ModelActor:
		(sprite_actor as ModelActor).set_locomotion_speed(speed)


## Bone-measured, bone-synced zones on model units (beads 90gj/yd83).
## Allies use player hurtbox layer 32 (enemies shoot at them too); no GUT
## (ally damage has no gut handling - BODY spans hips to neck instead).
func _setup_hurtbox() -> void:
	var ma: ModelActor = sprite_actor as ModelActor if _visual_is_model else null
	_hitzone_sync = HitzoneBuilder.build(self, ma, 32, 16, ["ally_hurtbox", "hitzone"], false)


func _physics_process(delta: float) -> void:
	# Zones ride the skeleton even on the corpse - shooting bodies stays honest.
	if _visual_is_model:
		HitzoneBuilder.sync(sprite_actor as ModelActor, _hitzone_sync)
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

	_update_unstick(capped_delta)
	move_and_slide()


func _think() -> void:
	_find_target()
	_update_line_of_sight()
	_evaluate_goals()


func _find_target() -> void:
	# Find closest living enemy
	var closest_enemy: Node3D = null
	var closest_dist: float = 60.0  # was 40 - squadmates spotted contacts late (Caleb)

	for enemy in CombatManager.active_enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if enemy.has_meta("non_hostile"):
			continue  # practice dummies / surrendered - not a squad target

		var dist := global_position.distance_to((enemy as Node3D).global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy as Node3D

	# Aim settle: a NEW target costs a human beat before the first shot (the
	# enemies pay reaction + first-miss + exposure ramp; the squad shouldn't
	# be an instant laser - Caleb: waves were deleted before firing back).
	if closest_enemy != target and closest_enemy != null:
		_aim_settle = randf_range(0.45, 0.9)
	target = closest_enemy


func _update_line_of_sight() -> void:
	if not target:
		has_line_of_sight = false
		target_last_seen_time = 999.0
		return

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := target.global_position + Vector3.UP * 1.0

	has_line_of_sight = CombatManager.has_line_of_sight(eye_pos, target_pos, [self])

	if has_line_of_sight:
		target_last_seen_time = 0.0
		contact_conf = minf(1.0, contact_conf + THINK_INTERVAL / 0.3)
	else:
		target_last_seen_time += THINK_INTERVAL
		contact_conf = maxf(0.0, contact_conf - THINK_INTERVAL / 2.0)

	if has_line_of_sight:
		last_known_target_pos = target.global_position


func _evaluate_goals() -> void:
	goal_timer += THINK_INTERVAL

	# Contact clock + new-contact reset (fixes the never-reset fail counter).
	if target != null and is_instance_valid(target):
		if _contact_time == 0.0:
			_cover_fail_count = 0
		_contact_time += THINK_INTERVAL
	else:
		_contact_time = 0.0

	# Dwell ~1s (Summoner's reactive dial); Class-A interrupts (take_damage)
	# force past the gate. A cover rush COMPLETES (cap 4s).
	if goal_timer < 1.0 and current_goal != Enums.AIGoal.NONE:
		return
	if current_state == Enums.AIState.SEEKING_COVER and _moving_to_cover and goal_timer < 4.0:
		return
	goal_timer = 0.0

	var nerve: float = effective_courage()

	# Suppression band with HYSTERESIS (enter >0.6, exit <0.35 - no boundary
	# flicker). Suppressed WITH cover = hunker where you are (decree), never
	# relocate under fire.
	var supp_gate: float = 0.35 if current_state == Enums.AIState.SEEKING_COVER else 0.6
	if suppression_level > supp_gate and not has_cover:
		current_goal = Enums.AIGoal.SEEK_COVER
		_change_state(Enums.AIState.SEEKING_COVER)
		return

	# In contact = FIGHT (Caleb). Reads the DEBOUNCED confidence, never raw
	# LOS - a leaf can't send a man back to heel. COVER-FIRST is personality-
	# gated: go-getters (nerve >= 0.75) skip the cover trip and push; everyone
	# else covers once, on fresh contact only (<5s), fail-count escapes apply.
	if target and weapons_free and (contact_conf > 0.4 or target_last_seen_time < 6.0):
		if not has_cover and _cover_fail_count < 2 and _contact_time < 5.0 and nerve < 0.75:
			current_goal = Enums.AIGoal.SEEK_COVER
			_change_state(Enums.AIState.SEEKING_COVER)
			return
		current_goal = Enums.AIGoal.ENGAGE_TARGET
		_change_state(Enums.AIState.COMBAT)
		return

	# Otherwise follow player
	current_goal = Enums.AIGoal.HOLD_POSITION
	_change_state(Enums.AIState.IDLE)


func _execute(delta: float) -> void:
	_update_sprite()
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
	match order_mode:
		OrderMode.FOLLOW:
			var player := GameManager.player
			if player and is_instance_valid(player) and player is Node3D:
				# Formation slot, not a conga line: each man holds his own
				# offset around the player so the squad has spacing and arcs.
				var slot: Vector3 = (player as Node3D).global_position + _follow_offset
				var dist := global_position.distance_to(slot)
				if dist > follow_distance:
					_move_toward(slot, delta)
				else:
					_settle(delta)
		OrderMode.HOLD:
			_settle(delta)
		OrderMode.MOVE_TO:
			if order_pos != Vector3.ZERO and global_position.distance_to(order_pos) > 2.0:
				_move_toward(order_pos, delta)
			else:
				_settle(delta)


func _settle(delta: float) -> void:
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
		# Movement based on range - PERSONALITY-SHAPED (decree): the go-getter
		# (nerve >= 0.7) closes distance and pushes; the coward (nerve < 0.35)
		# ANCHORS - he is not leaving his rock to close distance, he suppresses
		# from where he is. The middle holds the base of fire.
		var move_dir := Vector3.ZERO
		var nerve: float = effective_courage()
		var advance_band: float = 0.9 if nerve >= 0.7 else 1.2

		if dist > preferred_range * advance_band:
			if not (nerve < 0.35 and has_cover):
				move_dir = (target.global_position - global_position).normalized()
		elif dist < preferred_range * 0.6:
			move_dir = (global_position - target.global_position).normalized()

		# Apply strafe
		if strafe_direction != 0.0:
			var strafe_vec := transform.basis.x * strafe_direction
			move_dir = (move_dir + strafe_vec * 0.4).normalized()

		# Covered men HOLD their piece of cover: leash RE-ANCHORS (never
		# releases by drift - the release loop was the cover-obsession bug).
		# T1.3 latch replaces the 1-frame cooldown boolean that flipped the
		# cover pose every burst cycle (bypassing the intent filter entirely).
		var now_ms: float = float(Time.get_ticks_msec())
		var firing_now: bool = now_ms < _fired_until_ms or burst_count > 0
		if has_cover:
			var leash: float = global_position.distance_to(current_cover) if current_cover != Vector3.ZERO else 0.0
			if leash > 1.5:
				move_dir = (current_cover - global_position).normalized()  # step back to the rock
			else:
				move_dir *= 0.1
				# T1.5a pose latch: hold a chosen cover pose >=600ms before
				# re-picking - covered men change stance deliberately.
				if now_ms > _leap_until_ms and now_ms > _cover_pose_until_ms:
					if sprite_actor is ModelActor:
						var chain: Array[String] = COVER_PEEK_CLIPS if firing_now else COVER_HOLD_CLIPS
						var prev_override: String = _anim_override
						_anim_override = (sprite_actor as ModelActor).play_first(chain)
						if _anim_override != prev_override:
							_cover_pose_until_ms = now_ms + 600.0
		else:
			_anim_override = ""

		move_dir.y = 0
		if move_dir.length() > 0.1:
			velocity.x = lerpf(velocity.x, move_dir.x * move_speed * 0.6, delta * 8.0)
			velocity.z = lerpf(velocity.z, move_dir.z * move_speed * 0.6, delta * 8.0)
		else:
			velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)

		# Fire at target (after the aim settles on a fresh acquisition)
		if _aim_settle > 0.0:
			_aim_settle -= delta
		elif can_fire and suppression_level < 0.5:
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
	if _moving_to_cover:
		if global_position.distance_to(current_cover) < 1.4:
			# LEAP INTO COVER (Caleb): one-shot arrival clip, then crouch-hold.
			_moving_to_cover = false
			has_cover = true
			var leap: String = ""
			if sprite_actor is ModelActor:
				leap = (sprite_actor as ModelActor).play_first(LEAP_CLIPS, true)
			_anim_override = leap
			# T1.5c: window sized by the actual clip (fixed 900ms froze short
			# fallback clips and cut long ones mid-roll).
			var leap_len: float = 0.9
			if leap != "" and sprite_actor is ModelActor:
				leap_len = clampf((sprite_actor as ModelActor).clip_length(leap), 0.4, 1.5)
			_leap_until_ms = float(Time.get_ticks_msec()) + leap_len * 1000.0
			_change_state(Enums.AIState.COMBAT if target != null else Enums.AIState.IDLE)
			return
		# Sprint the rush.
		_anim_override = RUSH_CLIPS[0]
		_move_toward(current_cover, delta)
		return

	# Throttled raycast search (same 1Hz budget as enemies).
	_cover_search_timer -= delta
	if _cover_search_timer <= 0.0:
		_cover_search_timer = 1.0
		var p := _find_cover_point()
		if p != Vector3.ZERO:
			current_cover = p
			_moving_to_cover = true
			return
		_cover_fail_count += 1

	# No point found (yet): old perpendicular duck-and-dodge.
	if target:
		var to_target := (target.global_position - global_position).normalized()
		var perpendicular := Vector3(-to_target.z, 0, to_target.x)
		if strafe_direction == 0.0:
			strafe_direction = [-1.0, 1.0].pick_random()
		var move_dir := (perpendicular * strafe_direction - to_target * 0.2).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed

	# Exit after moving - to the FIGHT if we still have one (the old exit to
	# IDLE mid-firefight was half the cover-thrash loop).
	if state_timer > 2.0:
		_anim_override = ""
		if target != null and is_instance_valid(target):
			_change_state(Enums.AIState.COMBAT)
		else:
			_change_state(Enums.AIState.IDLE)


## Same LOS-block sampling as EnemyBase._find_cover_point, same claim broker.
func _find_cover_point() -> Vector3:
	var threat_pos: Vector3 = Vector3.ZERO
	if target != null and is_instance_valid(target):
		threat_pos = target.global_position
	elif last_known_target_pos != Vector3.ZERO:
		threat_pos = last_known_target_pos
	else:
		return Vector3.ZERO
	var space_state := get_world_3d().direct_space_state
	var candidates: Array[Vector3] = []
	for off in EnemyBase.COVER_SEARCH_OFFSETS:
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


func _release_cover() -> void:
	if current_cover != Vector3.ZERO:
		var key := EnemyBase._cover_key(current_cover)
		if EnemyBase._cover_claims.get(key, {}).get("enemy") == self:
			EnemyBase._cover_claims.erase(key)
	has_cover = false
	_moving_to_cover = false
	_anim_override = ""


func _change_state(new_state: Enums.AIState) -> void:
	if new_state == current_state:
		return
	# T1.5b: the cover claim + anim override must not outlive the fight. They
	# leaked on COMBAT->IDLE (target died), leaving allies gliding after the
	# player in a frozen crouch and leashed to a rock hundreds of meters back.
	var was_fighting: bool = current_state == Enums.AIState.COMBAT \
		or current_state == Enums.AIState.SEEKING_COVER
	var still_fighting: bool = new_state == Enums.AIState.COMBAT \
		or new_state == Enums.AIState.SEEKING_COVER
	if was_fighting and not still_fighting:
		_release_cover()  # also clears _anim_override
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
	if sprite_actor != null:
		return sprite_actor.muzzle_ballistic(flat_aim, 0.55)  # camera-independent: this is the ray origin
	var right := flat_aim.cross(Vector3.UP).normalized() * -0.22
	return global_position + Vector3.UP * 1.35 + flat_aim * 0.55 + right


func get_muzzle_visual(aim_dir: Vector3) -> Vector3:
	if sprite_actor != null:
		return sprite_actor.muzzle_visual()
	return get_muzzle_position(aim_dir)


func _fire_at_target() -> void:
	if not weapon_data or not target or not weapons_free:
		return

	can_fire = false
	fire_timer = weapon_data.get_fire_delay() / maxf(0.5, fire_rate_mult)
	shots_fired += 1

	# Use smoothly interpolated aim
	var final_aim: Vector3 = current_aim_dir

	# Add spread. W28: this soldier's OWN Small Arms skill tightens their cone - was
	# ignored (only the player's skill mattered), so a veteran rifleman now shoots
	# measurably tighter than a rookie. Same formula the player uses (weapon_holder).
	var spread: float = deg_to_rad(weapon_data.base_spread * 1.2 + float(shots_fired) * 0.05)
	var sa: int = SquadRoster.skill_level(member, "small_arms") if not member.is_empty() else 0
	spread *= 1.0 / (1.0 + 0.06 * float(sa))
	# Personality skill (decree): the bad soldier sprays wide ("and miss but
	# maybe hit"), the natural shoots tight. x1.6 at skill 0 -> x0.8 at skill 1.
	spread *= (1.6 - skill * 0.8)
	# Fire-and-move is allowed but costs accuracy (Caleb) - same idea as the
	# enemy's x1.6 bounding-fire penalty.
	if Vector3(velocity.x, 0.0, velocity.z).length() > 0.5:
		spread *= 1.5
	final_aim.x += randf_range(-spread, spread)
	final_aim.y += randf_range(-spread, spread)
	final_aim.z += randf_range(-spread, spread)
	final_aim = final_aim.normalized()

	# Raycast from the gun muzzle (R03). FULL-REALISM FF (decree): the ray
	# sees the player (2) and fellow-ally hurtboxes (32) too.
	var origin: Vector3 = get_muzzle_position(final_aim)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_aim * weapon_data.max_range,
		1 | 2 | 4 | 32 | 64
	)
	query.collide_with_areas = true  # enemy hitzones are Area3D (sponge fix)
	query.exclude = [self]

	var result := space_state.intersect_ray(query)

	# MUZZLE DISCIPLINE (decree): the player or a squadmate in the lane =
	# don't squeeze. The skipped round costs cadence, not ammo.
	if result:
		var lane: Object = result.collider
		var lane_owner: Node = (lane as Hitzone).owner_entity if lane is Hitzone else lane as Node
		if lane_owner != null and lane_owner != self and is_instance_valid(lane_owner) \
				and (lane_owner.is_in_group("player") or lane_owner.is_in_group("allies")):
			return

	var tracer_end: Vector3 = origin + final_aim * weapon_data.max_range
	if result:
		tracer_end = result.position
	BulletTracer.spawn_tracer(get_tree().current_scene, origin, tracer_end, Color(1.0, 0.85, 0.4, 1.0))
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, origin, 0)
	GunFX.play_shot_3d(get_tree().current_scene, origin, weapon_data)
	GunFX.muzzle_flash(get_tree().current_scene, origin)
	_fired_until_ms = float(Time.get_ticks_msec()) + 350.0

	# Flesh gets blood; world gets a dust puff + hole (allies spawned no impact FX before).
	if result:
		var hit_col: Object = result.collider
		var is_flesh: bool = hit_col is Hitzone
		if not is_flesh and hit_col is Node:
			var n := hit_col as Node
			var np: Node = n.get_parent()
			is_flesh = n.is_in_group("enemies") or (np != null and np.is_in_group("enemies"))
		if is_flesh:
			var victim: Node = (hit_col as Hitzone).owner_entity if hit_col is Hitzone else hit_col as Node
			GunFX.blood(get_tree().current_scene, result.position, result.normal, final_aim, victim)
		else:
			GunFX.impact(get_tree().current_scene, result.position, result.normal, false)
			GunFX.bullet_hole(get_tree().current_scene, result.position, result.normal)

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
			elif hit_target is Node and (hit_target as Node).is_in_group("enemies"):
				damage_target = hit_target as Node
			elif hit_target is Node and (hit_target as Node).get_parent() and (hit_target as Node).get_parent().is_in_group("enemies"):
				damage_target = (hit_target as Node).get_parent()

			if damage_target and damage_target.has_method("take_damage"):
				var falloff: float = weapon_data.damage_multiplier_at(origin.distance_to(result.position))
				var base_damage: int = weapon_data.get_damage()
				var final_damage: int = maxi(1, int(float(base_damage) * falloff * damage_multiplier))
				damage_target.take_damage(final_damage, weapon_data.damage_type, self, zone_name)


## Take damage
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, _attacker: Node = null, _zone: String = "BODY") -> int:
	goal_timer = 99.0  # Class-A interrupt (decree): getting hit may always re-plan
	if _attacker != null and is_instance_valid(_attacker) and _attacker is Node3D:
		last_hit_dir = (global_position - (_attacker as Node3D).global_position).normalized()
	if current_state == Enums.AIState.DEAD:
		return 0

	current_hp -= amount

	# Visual feedback
	if sprite_actor != null:
		sprite_actor.flash(Color(1.6, 0.5, 0.5), 0.1)
	elif mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
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
	GunFX.blood_pool(get_tree().current_scene, global_position)  # a man bleeding out is a place
	_release_cover()
	_change_state(Enums.AIState.DEAD)
	CombatManager.unregister_ally(self)
	died.emit(self)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if sprite_actor != null:
		var to_attacker: Vector3 = -last_hit_dir
		var from_right: bool = to_attacker.dot(global_transform.basis.x) > 0.35
		sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, sprite_faction, sprite_unit, sprite_weapon,
			"death_right" if from_right else "death_forward"), true)
	elif mesh:
		mesh.rotation_degrees.x = 90

	# PT9: their kit is still on the ground - a real window to recover it.
	add_to_group("ally_corpses")
	get_tree().create_timer(45.0).timeout.connect(queue_free)


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
