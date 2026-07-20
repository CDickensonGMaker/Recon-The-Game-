## ally_base.gd - Allied soldier AI that fights alongside the player
class_name AllyBase
extends CharacterBody3D

signal died(ally: AllyBase)

var max_hp: int = 80
var current_hp: int = 80
var move_speed: float = 5.6
var preferred_range: float = 12.0

var weapon_data: WeaponData = null
var fire_timer: float = 0.0
var can_fire: bool = true

var current_state: Enums.AIState = Enums.AIState.IDLE
var current_goal: Enums.AIGoal = Enums.AIGoal.NONE
var state_timer: float = 0.0

var think_timer: float = 0.0
const THINK_INTERVAL: float = 0.15

var target: Node3D = null
var last_known_target_pos: Vector3 = Vector3.ZERO
## Seconds since we last had eyes on the target. Recent contact keeps a follower
## FIGHTING instead of falling back to heel.
var target_last_seen_time: float = 999.0
## Human beat between acquiring a new target and the first aimed shot.
var _aim_settle: float = 0.0
## Debounced eyes-on 0-1: goals read THIS, never raw LOS.
var contact_conf: float = 0.0
## Animation intent stability filter + fire latch.
var _last_intent: String = ""
var _cand_intent: String = ""
var _cand_since: float = -1e9
var _fired_until_ms: float = -1e9
var _cover_pose_until_ms: float = -1e9  # min hold before hold/peek re-pick
var _hitzone_sync: Array = []           # [[hz, bone_idx, offset]..] - zones ride bones

## WA-A2 body gate (same shape as EnemyBase; allies get pinned HOT when the
## AIDirector lands). Allies have no alert tier or downed state - an armed
## target is their "in a fight" equivalent.
const BODY_HEARTBEAT_MS: int = 300
var _body_hot: bool = true
var _body_heartbeat_ms: int = -1

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
## Goal dwell + contact clock (~1s reactive dwell, Class-A interrupts).
var goal_timer: float = 99.0
var _contact_time: float = 0.0

## ---- PERSONALITY SPECTRUM ---- rolled random per man, per playthrough.
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

## Set by SquadSystem when the squad falls below its strength threshold
## (EnemySquad.break_state - the same authority the enemy side breaks on).
var squad_broken: bool = false


## COVER-FIRST is personality-gated: go-getters (nerve >= 0.75) skip the cover trip
## and push; everyone else covers once, on fresh contact only (<5s). A BROKEN squad
## always takes it - surviving outranks nerve and outranks how long the fight
## has run. The fail count still applies: a man who cannot find cover twice stops
## hunting for it instead of thrashing.
func wants_cover_first(nerve: float) -> bool:
	if _cover_fail_count >= 2:
		return false
	return squad_broken or (_contact_time < 5.0 and nerve < 0.75)


## May this man close the range? The coward anchors on his rock; a broken squad
## does not push at all.
func may_close_distance(nerve: float) -> bool:
	return not squad_broken and not (nerve < 0.35 and has_cover)

var has_line_of_sight: bool = false

var current_aim_dir: Vector3 = Vector3.FORWARD
var target_aim_dir: Vector3 = Vector3.FORWARD
var aim_speed: float = 7.0

## Slot tolerance when halted. A man INSIDE it is where he belongs and moves on
## his own business; only outside it does he correct toward the slot.
var follow_distance: float = 2.5
## Slot lag that puts a man into catch-up.
var max_follow_distance: float = 10.0
## Slot tolerance on the move. Wider - a walking file breathes.
const FILE_DEADZONE: float = 3.0
## Player ground speed that strings the huddle into a file, and the lower speed
## that lets it collapse back. Crouch (2.5) sits inside the band, so a stealth
## patrol never oscillates.
const FORMATION_ENTER_SPD: float = 3.2
const FORMATION_EXIT_SPD: float = 1.5
## Ceiling on how fast a slot may travel. A shape flip or a 180 turn relocates
## the slot ~28m; without this the man chases a teleport.
const SLOT_TRACK_SPEED: float = 12.0
const CATCHUP_MULT: float = 1.35
## Firefight footwork is signed off (2026-07-12) - this holds its absolute speed
## (~2.7 m/s) across the patrol-speed raise. Retune only with the combat feel.
const COMBAT_SPEED_MULT: float = 0.48
## Amble inside the deadzone. Slow enough to read as a man, not a reposition.
const IDLE_DRIFT_SPEED: float = 0.45

## Squad layer: roster identity + orders.
enum OrderMode { FOLLOW, HOLD, MOVE_TO }
## False for a US element that is not in the player's squad (an ambient friendly
## patrol). Group "allies" answers "will the player's bullets hurt him"; this
## answers "is he MINE". Anything keyed to the squad - break state, distance
## exemptions, orders - must ask this, not the group.
var squad_member: bool = true
var member: Dictionary = {}      ## roster entry (name/mos/stats) - IS the roster dict
var director: FieldDirector = null  ## toast channel for learn-by-doing promotion barks


## Promotion bark. Called when this soldier's skill levels up from doing the thing.
func on_skill_up(skill_id: String, level: int) -> void:
	if director == null:
		return
	var sk_name: String = str(SkillCatalog.SKILLS.get(skill_id, {}).get("name", skill_id))
	director.toast.emit("%s — %s ★%d" % [str(member.get("nick", "GRUNT")), sk_name, level])
var order_mode: OrderMode = OrderMode.FOLLOW
var order_pos: Vector3 = Vector3.ZERO
## Staggered-file slot on the move (SquadSystem assigns; point man walks ahead).
var file_slot: int = 1
var point_slot: bool = false
## Personal formation slot around the player (rolled once) - the squad spreads
## into an arc instead of stacking on the player's back.
var _follow_offset: Vector3 = Vector3.ZERO
## Latched formation shape + the rate-limited slot the man actually walks to.
var _in_file: bool = false
var _slot_smooth: Vector3 = Vector3.ZERO
var _slot_valid: bool = false
## Micro-idle: his own business inside the deadzone.
var _idle_drift: Vector3 = Vector3.ZERO
var _idle_hold: float = 0.0
## Sight grid, fetched lazily - allies can spawn before game_world joins its group.
var _grid: GameplayGrid = null
var _grid_checked: bool = false
var weapons_free: bool = true
## Self-defense window while weapons-tight: opens on taking fire or on a COMBAT
## enemy holding this ally as its target; the man defends himself without
## breaking the squad's hold-fire.
var _defend_until_ms: int = 0
var fire_rate_mult: float = 1.0  ## Pigman sustained-fire bonus


func _may_engage() -> bool:
	return weapons_free or Time.get_ticks_msec() < _defend_until_ms


func set_order(mode: OrderMode, pos: Vector3 = Vector3.ZERO) -> void:
	order_mode = mode
	order_pos = pos

var strafe_direction: float = 0.0
var strafe_timer: float = 0.0
var shots_fired: int = 0
var burst_count: int = 0
const MAX_BURST: int = 6

var suppression_level: float = 0.0
const SUPPRESSION_DECAY: float = 0.4

## ---- COVER ----
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
var _low_posture: bool = false         # crouch-walk this frame (heavy pin / eyes-off cover move, B2)
var _cover_exit_until_ms: float = 0.0  # one-shot cover_to_stand window (Track B3)
var _last_cover_exit_ms: float = -1e9  # debounce so cover-thrash can't stutter the stand-up
## See EnemyBase.CROUCH_SPEED_CAP - the move-side half of B2 so the crouch does
## not ice-skate. Allies default aggressive, so low_posture is a high bar below.
const CROUCH_SPEED_CAP: float = 1.9
const COVER_EXIT_DEBOUNCE_MS: float = 1500.0
const LOW_POSTURE_SUPPRESS: float = 0.6  # heavy pin; allies have no SUPPRESSED state
## Cover-arrival posture. A controlled crouch-down is the default; the dive-roll
## is the rare exception, rationed so a whole squad never rolls in unison.
const STAND_COVER_CLIPS: Array[String] = ["stand_to_cover", "stand_to_cover_2", "stand_to_cover_3"]
const COVER_ARRIVAL_FALLBACK: Array[String] = ["idle_crouching", "kneeling_pointing"]
const ROLL_URGENT_DIST: float = 18.0
const ROLL_LOW_COURAGE: float = 0.3
const ROLL_BASE_CHANCE: float = 0.15
const ROLL_COOLDOWN_MS: float = 8000.0
const SQUAD_ROLL_WINDOW_MS: float = 1500.0
static var _squad_last_roll_ms: float = -1.0e9
var _last_roll_ms: float = -1.0e9
var _cover_rush_dist: float = 0.0
var _cover_arrivals: int = 0
const COVER_HOLD_CLIPS: Array[String] = ["idle_crouching_aiming", "kneeling_pointing", "idle_crouching", "rifle_aiming_idle"]
const COVER_PEEK_CLIPS: Array[String] = ["idle_aiming", "rifle_aiming_idle", "firing_rifle"]
const RUSH_CLIPS: Array[String] = ["sprint_forward", "run_forward", "start_walking"]

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var mesh: MeshInstance3D
var sprite_actor: Node3D = null  ## ModelActor (capsule when the model is missing)
var _visual_is_model: bool = false
var last_hit_dir: Vector3 = Vector3.FORWARD
## Which rendered unit this man wears. SquadSystem overrides it per MOS.
var sprite_faction: String = "US Army and Co"
## The gib-rig grunt: full gore contract, big clip library, cover/crouch anim set.
var sprite_unit: String = "us_grunt_v3"
var sprite_weapon: String = "m16a1"


func _ready() -> void:
	add_to_group("allies")
	AgentRegistry.register(self, AgentRegistry.Kind.ALLY)
	var slot_angle: float = randf_range(0.0, TAU)
	_follow_offset = Vector3(cos(slot_angle), 0.0, sin(slot_angle)) * randf_range(2.5, 4.5)
	# The man he is this playthrough: a random point on the spectrum.
	courage = randf()
	skill = randf()

	weapon_data = load("res://data/weapons/m16a1.tres")

	_setup_visual()
	_setup_hurtbox()

	current_aim_dir = -global_transform.basis.z


## Mission teardown frees live men without a death path - the roster must not
## hold freed instances (the registry has no cleanup sweep by design).
func _exit_tree() -> void:
	AgentRegistry.unregister(self)


func _setup_visual() -> void:
	if not sprite_unit.is_empty():
		if ModelActor.model_exists(sprite_unit):
			var ma := ModelActor.new()
			add_child(ma)
			if ma.setup(sprite_unit):
				sprite_actor = ma
				_visual_is_model = true
				sprite_actor.play(SpriteStateMap.model_clip_for("idle"))
				# Deferred: SquadSystem assigns `member` after _ready(), so by
				# end of frame a named man wears HIS face, not a reroll.
				call_deferred("dress_visual")
				return
			ma.queue_free()

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
	# The zones were cut from the OLD body's mesh and ride the OLD skeleton's bone
	# indices. A swap that skips this leaves damage regions mapped to a dead rig.
	HitzoneBuilder.clear(self)
	_setup_hurtbox()


## Dress the rendered man - THE game-side entry into the one shared
## randomization core (GruntRandomizer, same code the grunt_viewer bench runs).
## A named member wears his STORED face + helmet (Pillar 4: identity, never a
## reroll); gear still rolls per mission (kit is the mission, skin is the man).
## Memberless allies (benches, POWs) draw the per-mission bench sequence.
## Safe to call repeatedly - dress_actor's "dressed" meta makes it a no-op.
func dress_visual() -> void:
	var ma := sprite_actor as ModelActor
	if ma == null or not is_instance_valid(ma) or not _visual_is_model:
		return
	if not GruntRandomizer.is_dressable(ma.unit):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GruntRandomizer.next_bench_seed()
	var opts: Dictionary = {}
	if member.has("face"):
		opts["face"] = int(member["face"])
	if member.has("helmet"):
		opts["helmet_id"] = str(member["helmet"])
	GruntRandomizer.dress_actor(ma, rng, opts)


## AllyBase has no facing_dir. Derive it: aim at a target if we have one,
## otherwise face where we are walking.
## Low-posture (Track B2): allies default to the aggressive stand-and-push the
## Summoner liked, so this is a HIGH bar - only a heavy pin, or a careful eyes-off
## move into cover, drops them low. No alert tiers / no SUPPRESSED state here.
func _is_low_posture(firing: bool) -> bool:
	if firing:
		return false
	if suppression_level >= LOW_POSTURE_SUPPRESS:
		return true
	if current_state == Enums.AIState.SEEKING_COVER and not has_line_of_sight:
		return true
	return false


func _update_sprite() -> void:
	if sprite_actor == null:
		return
	var facing: Vector3 = current_aim_dir
	# Without LOS, current_aim_dir never updates - so moving without eyes-on must
	# face where you are going, or the man runs sideways facing his OLD aim.
	if target == null or not has_line_of_sight:
		var vel := Vector3(velocity.x, 0.0, velocity.z)
		if vel.length_squared() > 0.09:
			facing = vel
	sprite_actor.set_facing(facing)
	if current_state == Enums.AIState.DEAD:
		return
	# Cover-exit one-shot (Track B3): stand up before moving off. Self-clearing,
	# outranks the cover _anim_override (which _release_cover just cleared).
	if _cover_exit_until_ms > float(Time.get_ticks_msec()) and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play("cover_to_stand")
		return
	var vel_flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = vel_flat.length()
	var lateral: float = 0.0
	if speed > 0.1:
		var fwd := Vector3(facing.x, 0.0, facing.z).normalized()
		lateral = vel_flat.normalized().dot(fwd.cross(Vector3.UP))
	var now: float = float(Time.get_ticks_msec())
	# Fire pose follows the actual shot (350ms latch), not the cooldown tail.
	var firing: bool = now < _fired_until_ms
	# Cover behavior owns the clip while an override is set (leap / crouch-hold
	# / peek) - the state map would stomp it every frame otherwise.
	if _anim_override != "" and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play(_anim_override)
		(sprite_actor as ModelActor).set_locomotion_speed(speed)
		return
	_low_posture = _is_low_posture(firing)
	var intent: String = SpriteStateMap.intent_for(current_state, false, false, firing, speed, lateral, false, _low_posture)
	# Stability filter: intent must win continuously for 180ms before the clip
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


## Allies use the player hurtbox layer 32 (enemies shoot at them too); no GUT
## zone - ally damage has no gut handling, so BODY spans hips to neck instead.
func _setup_hurtbox() -> void:
	var ma: ModelActor = sprite_actor as ModelActor if _visual_is_model else null
	_hitzone_sync = HitzoneBuilder.build(self, ma, 32, 16, ["ally_hurtbox", "hitzone"], false)


func _physics_process(delta: float) -> void:
	var t_start: int = Time.get_ticks_usec()
	_body_hot = _body_gate_open()
	if _body_hot:
		CombatManager.bodies_run += 1
	else:
		CombatManager.bodies_gated += 1
	# Zones ride the skeleton even on the corpse - shooting bodies stays honest.
	if _visual_is_model and _body_hot:
		HitzoneBuilder.sync(sprite_actor as ModelActor, _hitzone_sync)
	var t_sync: int = Time.get_ticks_usec()
	CombatManager.ai_usec_hitzone += t_sync - t_start
	if current_state == Enums.AIState.DEAD:
		return

	# Cap delta for framerate independence
	var capped_delta: float = minf(delta, 0.066)

	# WA-A2 BODY-GATE CONTRACT (DA TRAP 2): everything below except gravity,
	# move_and_slide and the sprite/hitzone paths keyed on _body_hot ticks for
	# GATED men too - think, suppression decay and fire timers never gate.
	if _body_hot and not is_on_floor():
		velocity.y -= gravity * capped_delta

	if suppression_level > 0:
		suppression_level = maxf(0.0, suppression_level - SUPPRESSION_DECAY * capped_delta)

	if not can_fire:
		fire_timer -= capped_delta
		if fire_timer <= 0:
			can_fire = true

	think_timer += capped_delta
	var usec_think: int = 0
	if think_timer >= THINK_INTERVAL:
		think_timer = 0.0
		var t_think: int = Time.get_ticks_usec()
		_think()
		usec_think = Time.get_ticks_usec() - t_think
		CombatManager.ai_usec_think += usec_think

	_execute(capped_delta)

	_update_unstick(capped_delta)
	# Move-side of low-posture (B2): cap ground speed so the crouch reads, not skates.
	if _low_posture:
		var flat := Vector2(velocity.x, velocity.z)
		if flat.length() > CROUCH_SPEED_CAP:
			flat = flat.normalized() * CROUCH_SPEED_CAP
			velocity.x = flat.x
			velocity.z = flat.y
	var t_move: int = Time.get_ticks_usec()
	if _body_hot:
		move_and_slide()
	CombatManager.ai_usec_move += Time.get_ticks_usec() - t_move
	CombatManager.ai_usec_anim += (t_move - t_sync) - usec_think


## WA-A2 body gate. Cover-exit men are pinned hot (test_body_gate contract);
## "trying to move" needs no nav check - _execute writes velocity every frame
## ungated, so a mover reopens the gate next frame.
func _body_gate_open() -> bool:
	if current_state == Enums.AIState.COMBAT or target != null:
		return true
	if _cover_exit_until_ms > float(Time.get_ticks_msec()):
		return true
	if velocity.length_squared() > 0.01:
		return true
	if CombatManager.perceivable(self):
		return true
	var now_ms: int = Time.get_ticks_msec()
	if _body_heartbeat_ms <= 0:
		_body_heartbeat_ms = now_ms + absi(hash(get_instance_id())) % BODY_HEARTBEAT_MS
	if now_ms >= _body_heartbeat_ms:
		_body_heartbeat_ms = now_ms + BODY_HEARTBEAT_MS
		return true
	return false


func _think() -> void:
	_find_target()
	_check_threat()
	_update_line_of_sight()
	_evaluate_goals()


func _check_threat() -> void:
	if weapons_free:
		return
	for enemy in AgentRegistry.enemies:
		if enemy is EnemyBase:
			var e := enemy as EnemyBase
			if not e.is_dead() and e.target == self and e.alert_tier == EnemyBase.AlertTier.COMBAT:
				_defend_until_ms = Time.get_ticks_msec() + 8000
				return


## Lazy: allies can spawn before game_world joins its group, so _ready() is too early.
func _sight_grid() -> GameplayGrid:
	if _grid_checked:
		return _grid
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw != null and "gameplay_grid" in gw:
		_grid = gw.gameplay_grid
		_grid_checked = true
	return _grid


func _find_target() -> void:
	var closest_enemy: Node3D = null
	var closest_dist: float = INF
	var grid: GameplayGrid = _sight_grid()

	for enemy in AgentRegistry.enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if enemy.has_meta("non_hostile"):
			continue  # practice dummies / surrendered - not a squad target

		var epos: Vector3 = (enemy as Node3D).global_position
		var dist := global_position.distance_to(epos)
		if dist >= closest_dist:
			continue
		if dist > SightCap.at(grid, global_position, epos):
			continue
		closest_dist = dist
		closest_enemy = enemy as Node3D

	# Aim settle: a NEW target costs a human beat before the first shot, so the
	# squad is not an instant laser.
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

	# Contact clock + new-contact reset of the cover fail counter.
	if target != null and is_instance_valid(target):
		if _contact_time == 0.0:
			_cover_fail_count = 0
		_contact_time += THINK_INTERVAL
	else:
		_contact_time = 0.0

	# Dwell ~1s. Class-A interrupts (take_damage) force past the gate.
	# A cover rush COMPLETES (cap 4s).
	if goal_timer < 1.0 and current_goal != Enums.AIGoal.NONE:
		return
	if current_state == Enums.AIState.SEEKING_COVER and _moving_to_cover and goal_timer < 4.0:
		return
	goal_timer = 0.0

	var nerve: float = effective_courage()

	# Suppression band with HYSTERESIS (enter >0.6, exit <0.35 - no boundary
	# flicker). Suppressed WITH cover = hunker where you are, never
	# relocate under fire.
	var supp_gate: float = 0.35 if current_state == Enums.AIState.SEEKING_COVER else 0.6
	if suppression_level > supp_gate and not has_cover:
		current_goal = Enums.AIGoal.SEEK_COVER
		_change_state(Enums.AIState.SEEKING_COVER)
		return

	# In contact = FIGHT. Reads the DEBOUNCED confidence, never raw LOS.
	if target and _may_engage() and (contact_conf > 0.4 or target_last_seen_time < 6.0):
		if not has_cover and wants_cover_first(nerve):
			current_goal = Enums.AIGoal.SEEK_COVER
			_change_state(Enums.AIState.SEEKING_COVER)
			return
		current_goal = Enums.AIGoal.ENGAGE_TARGET
		_change_state(Enums.AIState.COMBAT)
		return

	current_goal = Enums.AIGoal.HOLD_POSITION
	_change_state(Enums.AIState.IDLE)


func _execute(delta: float) -> void:
	if _body_hot:
		_update_sprite()
	state_timer += delta

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
				# On the move (ADR-029 patrol feel) the huddle strings into a
				# staggered file: point man 12m AHEAD, the column trailing on the
				# movement vector - the enemy column's math, worn by our side.
				var slot: Vector3 = (player as Node3D).global_position + _follow_offset
				var pv := Vector3.ZERO
				if player is CharacterBody3D:
					pv = (player as CharacterBody3D).velocity
				pv.y = 0.0
				var spd: float = pv.length()
				if spd > FORMATION_ENTER_SPD:
					_in_file = true
				elif spd < FORMATION_EXIT_SPD:
					_in_file = false
				if _in_file and spd > 0.05:
					var dir: Vector3 = pv.normalized()
					var side := Vector3(-dir.z, 0.0, dir.x)
					if point_slot:
						slot = (player as Node3D).global_position + dir * 12.0
					else:
						var lateral: float = 1.1 if (file_slot % 2 == 0) else -1.1
						slot = (player as Node3D).global_position \
							- dir * (3.5 * float(file_slot)) + side * lateral
				# Rate-limit the slot itself: one mechanism eases BOTH the shape
				# flip and a 180 turn, either of which relocates it ~28m at once.
				if not _slot_valid:
					_slot_smooth = slot
					_slot_valid = true
				else:
					_slot_smooth = _slot_smooth.move_toward(slot, SLOT_TRACK_SPEED * delta)
				var deadzone: float = FILE_DEADZONE if _in_file else follow_distance
				var dist := global_position.distance_to(_slot_smooth)
				if dist > deadzone:
					var catchup: float = CATCHUP_MULT if dist > max_follow_distance else 1.0
					_move_toward(_slot_smooth, delta, catchup)
				else:
					_micro_idle(delta)
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


## In his slot and free: he wanders his own metre or two and looks the ground
## over, instead of standing frozen on an exact offset.
func _micro_idle(delta: float) -> void:
	_idle_hold -= delta
	if _idle_hold <= 0.0:
		if _idle_drift == Vector3.ZERO:
			var a: float = randf_range(0.0, TAU)
			_idle_drift = Vector3(cos(a), 0.0, sin(a))
			_idle_hold = randf_range(2.0, 4.0)
		else:
			_idle_drift = Vector3.ZERO
			_idle_hold = randf_range(1.5, 3.0)
	if _idle_drift == Vector3.ZERO:
		_settle(delta)
		return
	var step: Vector3 = _idle_drift * IDLE_DRIFT_SPEED
	velocity.x = lerpf(velocity.x, step.x, delta * 3.0)
	velocity.z = lerpf(velocity.z, step.z, delta * 3.0)


func _execute_combat(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_change_state(Enums.AIState.IDLE)
		return

	if target.has_method("is_dead") and target.is_dead():
		target = null
		_change_state(Enums.AIState.IDLE)
		return

	var dist := global_position.distance_to(target.global_position)

	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_direction = [-1.0, 0.0, 1.0].pick_random()
		strafe_timer = randf_range(1.5, 3.0)

	if has_line_of_sight:
		# Movement by range, PERSONALITY-SHAPED: the go-getter (nerve >= 0.7) closes
		# and pushes; the coward (nerve < 0.35) ANCHORS - he will not leave his rock.
		var move_dir := Vector3.ZERO
		var nerve: float = effective_courage()
		var advance_band: float = 0.9 if nerve >= 0.7 else 1.2
		# A broken squad breaks CONTACT: it stops closing and it opens the range it
		# will accept, so the fight is fought at arm's length while men get out.
		var hold_band: float = 1.0 if squad_broken else 0.6

		if dist > preferred_range * advance_band:
			if may_close_distance(nerve):
				move_dir = (target.global_position - global_position).normalized()
		elif dist < preferred_range * hold_band:
			move_dir = (global_position - target.global_position).normalized()

		if strafe_direction != 0.0:
			var strafe_vec := transform.basis.x * strafe_direction
			move_dir = (move_dir + strafe_vec * 0.4).normalized()

		# Covered men HOLD their piece of cover: the leash RE-ANCHORS and never
		# releases by drift (that release loop was the cover-obsession bug).
		var now_ms: float = float(Time.get_ticks_msec())
		var firing_now: bool = now_ms < _fired_until_ms or burst_count > 0
		if has_cover:
			var leash: float = global_position.distance_to(current_cover) if current_cover != Vector3.ZERO else 0.0
			if leash > 1.5:
				move_dir = (current_cover - global_position).normalized()  # step back to the rock
			else:
				move_dir *= 0.1
				# Pose latch: hold a chosen cover pose >=600ms before re-picking -
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
			velocity.x = lerpf(velocity.x, move_dir.x * move_speed * COMBAT_SPEED_MULT, delta * 8.0)
			velocity.z = lerpf(velocity.z, move_dir.z * move_speed * COMBAT_SPEED_MULT, delta * 8.0)
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
			# LEAP INTO COVER: one-shot arrival clip, then crouch-hold.
			_moving_to_cover = false
			has_cover = true
			_anim_override = _pick_cover_arrival_clip()
			var leap: String = _anim_override
			# Window sized by the ACTUAL clip length: a fixed window freezes short
			# fallback clips and cuts long ones mid-roll.
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
			_cover_rush_dist = global_position.distance_to(p)
			_moving_to_cover = true
			return
		_cover_fail_count += 1

	# No point found (yet): perpendicular duck-and-dodge.
	if target:
		var to_target := (target.global_position - global_position).normalized()
		var perpendicular := Vector3(-to_target.z, 0, to_target.x)
		if strafe_direction == 0.0:
			strafe_direction = [-1.0, 1.0].pick_random()
		var move_dir := (perpendicular * strafe_direction - to_target * 0.2).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed

	# Exit after moving - to the FIGHT if we still have one (exiting to IDLE
	# mid-firefight is half the cover-thrash loop).
	if state_timer > 2.0:
		_anim_override = ""
		if target != null and is_instance_valid(target):
			_change_state(Enums.AIState.COMBAT)
		else:
			_change_state(Enums.AIState.IDLE)


## Cover-arrival clip. Default is a per-man crouch-down variant; the dive-roll
## fires only on an urgent long sprint-in or a shaken man, at low odds, gated by
## a per-man cooldown and a squad-wide window so at most one ally rolls at a time.
## Deterministic per (man, arrival) - no shared-RNG draw (ADR-010).
func _pick_cover_arrival_clip() -> String:
	if not (sprite_actor is ModelActor):
		return ""
	var ma := sprite_actor as ModelActor
	_cover_arrivals += 1
	var now: float = float(Time.get_ticks_msec())
	var urgent: bool = _cover_rush_dist >= ROLL_URGENT_DIST
	var shaken: bool = courage < ROLL_LOW_COURAGE
	var cooled: bool = now - _last_roll_ms >= ROLL_COOLDOWN_MS
	var window_open: bool = now - _squad_last_roll_ms >= SQUAD_ROLL_WINDOW_MS
	if (urgent or shaken) and cooled and window_open:
		var chance: float = ROLL_BASE_CHANCE + (0.2 if shaken else 0.0)
		if _arrival_hash() < chance:
			_last_roll_ms = now
			_squad_last_roll_ms = now
			var roll_clips: Array[String] = ["falling_to_roll", "stand_to_cover"]
			roll_clips.append_array(COVER_ARRIVAL_FALLBACK)
			return ma.play_first(roll_clips, true)
	var v: int = int(get_instance_id() % 3)
	var clips: Array[String] = [
		STAND_COVER_CLIPS[v],
		STAND_COVER_CLIPS[(v + 1) % 3],
		STAND_COVER_CLIPS[(v + 2) % 3],
	]
	clips.append_array(COVER_ARRIVAL_FALLBACK)
	return ma.play_first(clips, true)


## Deterministic pseudo-random in [0,1) keyed to this man and this arrival.
## Not the shared gameplay RNG - clip choice is presentation, not a sim event.
func _arrival_hash() -> float:
	var h: int = hash([get_instance_id(), _cover_arrivals])
	return float(h & 0xFFFFFF) / float(0x1000000)


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
		CombatManager.rays_cover += 1
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
	var was_covered: bool = has_cover
	if current_cover != Vector3.ZERO:
		var key := EnemyBase._cover_key(current_cover)
		if EnemyBase._cover_claims.get(key, {}).get("enemy") == self:
			EnemyBase._cover_claims.erase(key)
	has_cover = false
	_moving_to_cover = false
	_anim_override = ""
	# Cover-exit stand-up (B3): a living man who actually held cover. Debounced so
	# cover-thrash can't stutter a perpetual half-rise.
	if was_covered and current_state != Enums.AIState.DEAD:
		var now: float = float(Time.get_ticks_msec())
		if now - _last_cover_exit_ms > COVER_EXIT_DEBOUNCE_MS and sprite_actor is ModelActor:
			var l: float = (sprite_actor as ModelActor).clip_length("cover_to_stand")
			_cover_exit_until_ms = now + (l if l > 0.0 else 0.8) * 1000.0
			_last_cover_exit_ms = now


func _change_state(new_state: Enums.AIState) -> void:
	if new_state == current_state:
		return
	# The cover claim + anim override must NOT outlive the fight: leaking them on
	# COMBAT->IDLE leaves allies gliding in a frozen crouch, leashed to a far rock.
	var was_fighting: bool = current_state == Enums.AIState.COMBAT \
		or current_state == Enums.AIState.SEEKING_COVER
	var still_fighting: bool = new_state == Enums.AIState.COMBAT \
		or new_state == Enums.AIState.SEEKING_COVER
	if was_fighting and not still_fighting:
		_release_cover()  # also clears _anim_override
	current_state = new_state
	state_timer = 0.0


func _move_toward(pos: Vector3, delta: float, speed_mult: float = 1.0) -> void:
	var direction := (pos - global_position).normalized()
	direction.y = 0
	var spd: float = move_speed * speed_mult
	velocity.x = lerpf(velocity.x, direction.x * spd, delta * 8.0)
	velocity.z = lerpf(velocity.z, direction.z * spd, delta * 8.0)


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
	if not weapon_data or not target or not _may_engage():
		return

	can_fire = false
	fire_timer = weapon_data.get_fire_delay() / maxf(0.5, fire_rate_mult)
	shots_fired += 1

	var final_aim: Vector3 = current_aim_dir

	# Shared AI spread model (Fossil Law: one cone path for both sides). Small Arms skill folds
	# into ONE accuracy scalar so a mirror match against the enemy path trends 1:1.
	var sa: int = SquadRoster.skill_level(member, "small_arms") if not member.is_empty() else 0
	var acc01: float = clampf(skill + 0.04 * float(sa), 0.0, 1.0)
	var moving: bool = Vector3(velocity.x, 0.0, velocity.z).length() > 0.5
	var pre_cap: float = AIMarksmanship.cone_spread_deg(
		weapon_data.base_spread, acc01, shots_fired, moving, 1.0)
	final_aim = AIMarksmanship.aim_with_spread(final_aim, pre_cap, _target_is_player(), 1.0, false)
	if target != null and is_instance_valid(target) and target is Node3D:
		var td: float = global_position.distance_to((target as Node3D).global_position)
		var a_up: Vector3 = final_aim.cross(Vector3.UP).normalized().cross(final_aim).normalized()
		final_aim = (final_aim + a_up * tan(weapon_data.elevation_for(td))).normalized()

	# Raycast from the gun muzzle. FULL-REALISM FF: the ray sees the player (2)
	# and fellow-ally hurtboxes (32) too.
	var origin: Vector3 = get_muzzle_position(final_aim)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_aim * weapon_data.max_range,
		1 | 2 | 4 | 32 | 64
	)
	query.collide_with_areas = true  # enemy hitzones are Area3D
	query.exclude = [self]

	var result := space_state.intersect_ray(query)

	# MUZZLE DISCIPLINE: the player or a squadmate in the lane = don't squeeze.
	# The skipped round costs cadence, not ammo.
	if result:
		var lane: Object = result.collider
		var lane_owner: Node = (lane as Hitzone).owner_entity if lane is Hitzone else lane as Node
		if lane_owner != null and lane_owner != self and is_instance_valid(lane_owner) \
				and (lane_owner.is_in_group("player") or lane_owner.is_in_group("allies")):
			return

	# Live BulletSystem round - muzzle spawn, drop, travel, arrival damage/FX
	# through the shared resolver. The tracer IS the bullet; color from WeaponData.
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, origin, 0)
	GunFX.play_shot_3d(get_tree().current_scene, origin, weapon_data)
	GunFX.muzzle_flash(get_tree().current_scene, origin)
	_fired_until_ms = float(Time.get_ticks_msec()) + 350.0
	var show_tracer: bool = weapon_data.tracer_ratio > 0 \
		and (shots_fired % weapon_data.tracer_ratio) == 0
	# Rounds touch flesh ONLY through hitzone areas: every body-capsule layer is
	# OUT of the mask on purpose. A capsule in the mask eats the hit before the
	# zones inside it and the hit lands flat 1.0x.
	# Civilians (512) are IN: a stray round finds a villager the same way it finds
	# a soldier. The crossfire is real on every side of it.
	CombatManager.bullets.fire(weapon_data, self, origin, final_aim,
		1 | 32 | 64 | 512, [self], show_tracer)


## Is the current target the human player? Allies engage the enemy, never the player, so this is
## effectively always false - but the shared fire model requires the flag, and honesty beats a
## hardcoded false if a future friendly-fire path ever aims one at the player.
func _target_is_player() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target == GameManager.player or target.is_in_group("player")


## GORE_WORKFLOW ledger + explosive-kill flag (same doctrine as every model).
var _removed: Array[String] = []
var _killed_explosive: bool = false


## Region-resolved gore channel (BulletSystem): one hit >= 45 takes the limb.
## Allies bleed like everyone else.
func on_zone_hit(region: String, amount: int, dir: Vector3) -> void:
	if not _visual_is_model or sprite_actor == null:
		return
	var limb: String = HitzoneBuilder.base_region(region)
	if limb in ["ARM_L", "ARM_R", "LEG_L", "LEG_R"] \
			and amount >= GibSystem.LIMB_POP_HIT and not _removed.has(limb):
		if GibSystem.dismember(sprite_actor as ModelActor, limb, dir, get_tree().current_scene):
			_removed.append(limb)


func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, _attacker: Node = null, _zone: String = "BODY") -> int:
	goal_timer = 99.0  # Class-A interrupt: getting hit may always re-plan
	_defend_until_ms = Time.get_ticks_msec() + 8000
	if _attacker != null and is_instance_valid(_attacker) and _attacker is Node3D:
		last_hit_dir = (global_position - (_attacker as Node3D).global_position).normalized()
	if current_state == Enums.AIState.DEAD:
		return 0

	if current_hp - amount <= 0:
		_killed_explosive = _damage_type == Enums.DamageType.EXPLOSIVE
	current_hp -= amount

	if sprite_actor != null:
		sprite_actor.flash(Color(1.6, 0.5, 0.5), 0.1)
	elif mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if mesh and mesh.material_override:
				mesh.material_override.albedo_color = Color(0.3, 0.35, 0.25)
		)

	suppression_level = minf(1.0, suppression_level + 0.3)

	if current_hp <= 0:
		current_hp = 0
		_die()

	return amount


func apply_suppression(amount: float) -> void:
	suppression_level = minf(1.0, suppression_level + amount)


func _die() -> void:
	GunFX.blood_pool(get_tree().current_scene, global_position)
	_release_cover()
	_change_state(Enums.AIState.DEAD)
	AgentRegistry.unregister(self)
	died.emit(self)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if sprite_actor != null:
		# GORE_WORKFLOW death doctrine - allies are treated exactly like every
		# other model: explosion kill -> multi-gib + flung ragdoll; clean kill
		# -> ragdoll (dead weight); gibbed kill -> death clip (ragdoll fallback).
		var ma := sprite_actor as ModelActor
		if _killed_explosive and _visual_is_model and ma != null:
			GibSystem.explosion_kill(ma, _removed, last_hit_dir, get_tree().current_scene)
		elif _visual_is_model and ma != null and _removed.is_empty() \
				and ma.start_ragdoll(last_hit_dir, 4.5):
			pass
		else:
			var to_attacker: Vector3 = -last_hit_dir
			var from_right: bool = to_attacker.dot(global_transform.basis.x) > 0.35
			var played: Variant = sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, sprite_faction, sprite_unit, sprite_weapon,
				"death_right" if from_right else "death_forward"), true)
			if played is bool and not played and _visual_is_model and ma != null:
				if not ma.play_any_death() and not ma.start_ragdoll(last_hit_dir, 4.5):
					push_warning("[ALLY] %s: no death clip AND no ragdoll slot - corpse froze standing" % name)
	elif mesh:
		mesh.rotation_degrees.x = 90

	# Their kit is still on the ground - a real window to recover it.
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
