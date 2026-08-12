## enemy_base.gd - Goal-driven tactical AI for deadly WW2 combat
class_name EnemyBase
extends CharacterBody3D

signal died(enemy: EnemyBase)

## Enemy data resource
@export var enemy_data_path: String = ""
var enemy_data: EnemyData = null

var max_hp: int = 80
var current_hp: int = 80
var move_speed: float = 4.0
var preferred_range: float = 15.0

var weapon_data: WeaponData = null
var fire_timer: float = 0.0
var can_fire: bool = true

## ============================================
## GOAL-DRIVEN AI SYSTEM (Quake 3 inspired)
## ============================================

var current_goal: Enums.AIGoal = Enums.AIGoal.NONE
var current_state: Enums.AIState = Enums.AIState.IDLE
var personality: Enums.AIPersonality = Enums.AIPersonality.BALANCED
var goal_timer: float = 0.0

var think_timer: float = 0.0
var think_count: int = 0
const THINK_INTERVAL: float = 0.15  # 6-7 Hz thinking, execution every frame

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

var target: Node3D = null
var last_known_target_pos: Vector3 = Vector3.ZERO
var target_last_seen_time: float = 0.0

## A fixed point this man drives to. ZERO = no override, normal FSM.
var assault_objective: Vector3 = Vector3.ZERO

## Whether the objective OWNS his legs through contact. TRUE is sapper doctrine: the
## satchel man pushes through fire instead of stopping to fight it (aggression is
## doctrine-exempt, test_ai_fairness.gd:103), and a withdrawal is the same contract
## pointed the other way.
##
## FALSE for the assault element, and that distinction is the 2026-07-29 playtest bug:
## MarchingCell.materialize set assault_objective on EVERY man it stood up, sappers and
## riflemen alike, and _execute short-circuits the whole combat FSM while it is set. So
## forty men ran at the wire and not one of them ever fought - "the VC started running at
## the base and no one fought besides me". Worse, only SapperCharge._detonate ever cleared
## it, and the assault element carries no charge, so they arrived and kept running at a
## point they were already standing on, forever.
##
## For an undriven man the objective is a DESTINATION: he marches while he has no contact,
## and the moment he is in COMBAT (or arrives) his own brain takes his legs back.
var assault_driven: bool = false

## How close an undriven man has to get before the objective is spent.
const ASSAULT_ARRIVE_M: float = 8.0

## Ordered to press the compound. SiegeDirector raises it on a rotating share of the
## assault so the attack comes in rushes; it feeds CombatGoals.Context.assault_press and
## NOTHING else. Deliberately not a leg override: `assault_driven` short-circuits the
## combat FSM before the dispatch, so a driven man cannot shoot, and an assault of mute
## men running at the wire is the 2026-07-29 playtest bug.
var siege_press: bool = false
## A demolition infiltrator never fires and never barks contact - the satchel is his
## weapon. Silence is an invariant here, independent of the assault-move override, so
## clearing the objective can never turn a "sapper" back into a live gun. Set from data.
var silent_infiltrator: bool = false
var has_line_of_sight: bool = false
var target_visible_duration: float = 0.0

## Alert tiers + perception. Orthogonal to the goal FSM: the tier gates target
## ACQUISITION; once in COMBAT the goal brain takes over.
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
## How close a man must come to NOTICE a body (he still needs eyes on it).
const CORPSE_NOTICE_RANGE: float = 22.0
const CLOSE_SENSE_RANGE: float = 10.0  ## contacts inside this are felt regardless of facing
## What watching the man beside you drop does to you, mid-fight.
const CASUALTY_SHOCK: float = 0.35

var current_aim_dir: Vector3 = Vector3.FORWARD
var target_aim_dir: Vector3 = Vector3.FORWARD
var aim_speed: float = 8.0  # Radians per second - varies by skill

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
var is_moving: bool = false

## Cover: a shared claim broker keeps two units off the same rock/sandbag.
var current_cover: Vector3 = Vector3.ZERO
var has_cover: bool = false
var _moving_to_cover: bool = false
var _cover_search_timer: float = 0.0
static var _cover_claims: Dictionary = {}  # Vector3i cell -> {enemy: EnemyBase}
const COVER_CELL: float = 2.0
const COVER_SEARCH_OFFSETS: Array[Vector3] = [
	Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3),
	Vector3(2.2, 0, 2.2), Vector3(-2.2, 0, 2.2), Vector3(2.2, 0, -2.2), Vector3(-2.2, 0, -2.2),
	Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6),
]
## A blocker only makes a candidate COVER when it stands within this of the man;
## geometry further along the ray to the threat shadows the spot without protecting it.
const COVER_BLOCKER_MAX_M: float = 2.5

var patrol_route: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_pause: float = 0.0
## Slot 0 walks point; the rest trail him in a staggered column.
var patrol_file_slot: int = 0
const FILE_SPACING: float = 4.0     ## metres between men in the column
const FILE_STAGGER: float = 1.1     ## lateral weave, so it is a file and not a queue

## Camp role. The CampDirector writes this; the man's anim name is derived from it.
## Roles: "guard" (default), "patrol", "cook", "sleep", "talk".
var camp_role: String = "guard"
## Non-empty = he is working with his hands and that pose outranks the state map.
var work_clip: String = ""
## Set by whatever KILLED him when the death has a specific performance - a knife takedown
## is not a gunshot fall. Tried first; the normal death picks run if the rig lacks it.
var death_clip_override: String = ""
## Camp work station (CampDirector-assigned village prop marker). ZERO = none.
## An un-alerted idle man WALKS to it and works there - the living camp.
var work_pos: Vector3 = Vector3.ZERO

var strafe_direction: float = 0.0
var strafe_timer: float = 0.0
var shots_fired: int = 0
var burst_count: int = 0
var accuracy_modifier: float = 1.0     # per-frame scratch: range band x strafe x stillness
var base_accuracy_modifier: float = 1.0  # archetype baseline from EnemyData, multiplied in
var aggro_range: float = 50.0          # target-acquisition radius, from EnemyData.alert_range
var d_flanks: bool = true
var d_retreats_when_hurt: bool = false
var d_uses_cover: bool = true
var d_retreat_hp: float = 0.25
var d_exposure_ramp: float = 2.5       # seconds of exposure to full accuracy (EnemyData)
var contact_conf: float = 0.0          # debounced eyes-on 0-1 (goals read THIS, not raw LOS)
var _last_intent: String = ""          # committed anim intent (stability filter)
var _cand_intent: String = ""          # challenger intent + when it started winning
var _cand_since: float = -1e9
var _fired_until_ms: float = -1e9      # fire pose follows the SHOT, 350ms
var _low_posture: bool = false         # crouch-walk this frame (caution/pin, Track B2)
var _prone: bool = false               # latched onto the deck (War Room 2026-07-31)
var _prone_since_ms: float = 0.0       # when he went down, for the dwell ceiling
var _prone_pin_since_ms: float = 0.0   # when the pin started holding, for the entry delay
var _prone_drop_until_ms: float = 0.0  # crouch_to_prone one-shot window
var _prone_rise_until_ms: float = 0.0  # prone_to_crouch one-shot window
var _turn_rate: float = 0.0            # signed yaw rad/s, smoothed - drives turn-in-place
var _yaw_prev: float = 0.0
var _yaw_prev_ms: float = 0.0
var _cover_exit_until_ms: float = 0.0  # one-shot cover_to_stand window (Track B3)
var _throw_until_ms: float = 0.0       # one-shot grenade_throw window (the lob's 1s windup)
var _stumble_until_ms: float = 0.0     # one-shot stumble_hit window (solid non-lethal hit)
var _last_cover_exit_ms: float = -1e9  # debounce so cover-thrash can't stutter the stand-up
## Planar speed cap while low_posture is on. Below LOW_POSTURE_SPEED_MAX so the
## crouch clip always resolves, and near the crouch clips' authored 1.3 mps so
## feet plant (set_locomotion_speed clamps at 1.4x). This is the move-side half
## of B2: "move low" must actually mean "move slow" or the crouch ice-skates.
const CROUCH_SPEED_CAP: float = 1.9
const COVER_EXIT_DEBOUNCE_MS: float = 1500.0
var _hitzone_sync: Array = []          # [[hz, bone_idx, offset]..] - zones ride bones

## WA-A2 body gate: brain/clock work never gates; body work (gravity, slide,
## hitzone sync, sprite) runs only while this is true. Heartbeat de-phased per
## agent so gated bodies never wake in lockstep.
const BODY_HEARTBEAT_MS: int = 300
var _body_hot: bool = true
var _body_heartbeat_ms: int = -1

## Stuck watchdog: commanded to move but not moving for ~1s -> sidestep for a beat.
var _stuck_pos: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _unstick_t: float = 0.0
var _unstick_dir: float = 1.0
var _unstick_flips: int = 0

func _update_unstick(delta: float) -> void:
	if _unstick_t > 0.0:
		_unstick_t -= delta
		var side := global_transform.basis.x * _unstick_dir
		velocity.x = side.x * move_speed * _suppression_move_mult()
		velocity.z = side.z * move_speed * _suppression_move_mult()
		return
	_stuck_t += delta
	if _stuck_t >= 1.0:
		var wants_move: bool = Vector2(velocity.x, velocity.z).length() > 1.0
		if wants_move and global_position.distance_to(_stuck_pos) < 0.3:
			_unstick_t = 0.6
			_unstick_dir = -_unstick_dir  # alternate sides so corners release
			_unstick_flips += 1
			if _unstick_flips >= 3:
				_unstick_flips = 0
				_rescue_snap()
		else:
			_unstick_flips = 0
		_stuck_pos = global_position
		_stuck_t = 0.0


## The geometry has eaten this body: three sidesteps failed and he stands OFF the
## mesh. Snap him back to walkable ground - only while no one can see it, and only
## when the guarded helper found a covered point (an unchanged return means no safe
## snap exists, so he keeps grinding rather than teleporting to a far region).
func _rescue_snap() -> void:
	if CombatManager.perceivable(self):
		return
	var snapped: Vector3 = _router.nearest_mesh_point(global_position)
	var off: Vector3 = snapped - global_position
	off.y = 0.0
	if off.length() <= NavRouter.OFF_MESH_M:
		return
	global_position = snapped
	reset_physics_interpolation()

var reaction_timer: float = 0.0
var has_reacted: bool = false
const BASE_REACTION_TIME: float = 0.25

var grenade_cooldown: float = 0.0
var grenades_left: int = 1
var is_crippled: bool = false

## Spider-hole ambusher: hidden (no mesh/collision) until triggered. Set by the spawner.
var is_spider_hole: bool = false
var _spider_triggered: bool = false
const SPIDER_TRIGGER_RANGE: float = 7.0

var _tunnel_retreat_queued: bool = false
## Arrival-beat window: while now < this, the man is planting his feet.
var _arrive_until_ms: float = 0.0
## Corpse hitzone re-sync clock (6Hz - a dead man is not in a hurry).
var _corpse_sync_t: float = 0.0
## The launcher round this man carries, resolved ONCE.
var _proj_cache: ProjectileData = null
## Local force ratio, refreshed each goal think. >1 = we have the numbers.
var _last_force_ratio: float = 1.0
## Current flight bearing while RETREATING - slides along walls.
var _retreat_bearing: Vector3 = Vector3.ZERO

## Fairness: the first round at a newly acquired target is a deliberate near-miss.
var _first_shot_fired: bool = false

var suppression_level: float = 0.0  # 0-1, affects behavior
var _gut_bleed_dps: float = 0.0     # locational: gutshot bleed-out rate
var _bleed_accum: float = 0.0
const SUPPRESSION_DECAY: float = 0.3  # Per second

var threat_level: float = 0.0
var damage_taken_recently: int = 0
var damage_decay_timer: float = 0.0

var char_aggression: float = 0.5      # 0-1: tendency to advance/flank
var char_accuracy: float = 0.7        # 0-1: base accuracy
var char_reaction: float = 0.6        # 0-1: reaction speed
var char_self_preservation: float = 0.5  # 0-1: tendency to seek cover

const MAX_BURST: int = 5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var mesh: MeshInstance3D
## The visual: a ModelActor (default)
## fallback), or null -> capsule. Both share play/set_facing/flash/muzzle_*.
var sprite_actor: Node3D = null
var _visual_is_model: bool = false
var _router := NavRouter.new()
var squad_id: int = -1     ## EnemySquad coordination group; -1 = lone wolf

## Detection beacon: the last time ANY enemy entered COMBAT (polled by FieldDirector).
static var last_combat_contact_ms: float = -1.0
var _scan_phase: float = 0.0
var _home_facing: Vector3 = Vector3.FORWARD  ## the direction to sweep around
const SCAN_SPEED: float = 0.7
const SCAN_ARC: float = 2.45  ## +/- 140deg sweep - only a narrow wedge behind stays blind
var last_hit_dir: Vector3 = Vector3.FORWARD  ## world dir from attacker -> us; picks the death clip
## Which zone the last round found. Pairs with last_hit_dir to pick the death fall -
## Hitzone.zone_name_is_fatal is the authority on what counts as a head hit.
var last_hit_zone: String = "BODY"
## GORE_WORKFLOW ledger: regions already popped off this man (4-limb names).
var _removed: Array[String] = []
## The killing blow was explosive -> _die() runs the blast doctrine.
var _killed_explosive: bool = false


func _ready() -> void:
	add_to_group("enemies")
	AgentRegistry.register(self, AgentRegistry.Kind.ENEMY)
	_router.setup(nav_agent, get_tree(), "enemy")

	personality = [Enums.AIPersonality.AGGRESSIVE, Enums.AIPersonality.DEFENSIVE, Enums.AIPersonality.BALANCED].pick_random()
	_apply_personality()

	if not enemy_data_path.is_empty():
		enemy_data = load(enemy_data_path)
		if enemy_data:
			max_hp = enemy_data.max_hp
			current_hp = max_hp
			move_speed = enemy_data.move_speed
			preferred_range = enemy_data.preferred_range
			base_accuracy_modifier = enemy_data.accuracy_modifier
			aggro_range = enemy_data.alert_range * 2.0
			d_flanks = enemy_data.flanks
			d_retreats_when_hurt = enemy_data.retreats_when_hurt
			d_uses_cover = enemy_data.uses_cover
			d_retreat_hp = enemy_data.retreat_hp_threshold
			# _apply_personality() ran first: bias its RNG toward the archetype (ordering matters).
			char_aggression = lerpf(char_aggression, enemy_data.aggression, 0.6)
			char_self_preservation = lerpf(char_self_preservation, 1.0 - enemy_data.courage, 0.6)
			d_exposure_ramp = enemy_data.exposure_ramp_time
			if "silent_infiltrator" in enemy_data:
				silent_infiltrator = enemy_data.silent_infiltrator

			if not enemy_data.weapon_path.is_empty():
				weapon_data = load(enemy_data.weapon_path)

	_home_facing = facing_dir
	_scan_phase = randf() * TAU   # desync guards so they do not sweep in lockstep
	_setup_visual()
	_setup_hurtbox()

	current_aim_dir = -global_transform.basis.z
	target_aim_dir = current_aim_dir
	facing_dir = current_aim_dir

	NoiseBus.noise_emitted.connect(_on_noise_heard)
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw != null and "gameplay_grid" in gw:
		_grid = gw.gameplay_grid

	if is_spider_hole:
		visible = false
		collision_layer = 0
		collision_mask = 1


## Mission teardown frees live men without a death path - the roster must not
## hold freed instances (the registry has no cleanup sweep by design).
func _exit_tree() -> void:
	AgentRegistry.unregister(self)


## Remove a LIVING man from the world without a death. `died` never fires, so
## nothing scores him as a kill (ADR-035 §4: a withdrawal is not a casualty).
## Callers holding a roster must drop him first - FieldDirector.despawn_tracked_enemy.
func despawn() -> void:
	set_physics_process(false)
	queue_free()


func _apply_personality() -> void:
	match personality:
		# Accuracy floors raised + self-preservation floors raised (Summoner lethality +
		# FEAR ruling 2026-08-04): every archetype shoots to kill and none charges naked.
		Enums.AIPersonality.AGGRESSIVE:
			char_aggression = randf_range(0.7, 0.9)
			char_accuracy = randf_range(0.6, 0.78)
			char_reaction = randf_range(0.6, 0.8)
			char_self_preservation = randf_range(0.3, 0.5)
			aim_speed = randf_range(6.0, 9.0)
		Enums.AIPersonality.DEFENSIVE:
			char_aggression = randf_range(0.2, 0.4)
			char_accuracy = randf_range(0.75, 0.92)
			char_reaction = randf_range(0.5, 0.7)
			char_self_preservation = randf_range(0.7, 0.9)
			aim_speed = randf_range(5.0, 7.0)
		Enums.AIPersonality.BALANCED:
			char_aggression = randf_range(0.4, 0.6)
			char_accuracy = randf_range(0.68, 0.85)
			char_reaction = randf_range(0.5, 0.7)
			char_self_preservation = randf_range(0.5, 0.7)
			aim_speed = randf_range(5.0, 8.0)


## 3D model when the unit has one; capsule as the fallback (ADR-001).
## One art-gap warning per missing unit per session, not per spawn.
static var _model_gap_warned: Dictionary = {}


func _setup_visual() -> void:
	if enemy_data != null and not str(enemy_data.sprite_unit).is_empty():
		var unit: String = str(enemy_data.sprite_unit)
		# ART-AHEAD WIRING. An archetype may name a model that does not exist YET; if
		# it is missing we fall back to `sprite_unit_fallback` and say so LOUDLY.
		if not ModelActor.model_exists(unit) and "sprite_unit_fallback" in enemy_data:
			var fb: String = str(enemy_data.sprite_unit_fallback)
			if not fb.is_empty() and ModelActor.model_exists(fb):
				if not _model_gap_warned.has(unit):
					_model_gap_warned[unit] = true
					push_warning("[Enemy] '%s' has no model yet - wearing '%s'. Export it and he changes." % [unit, fb])
				unit = fb
		unit = _pick_body(unit)
		if ModelActor.model_exists(unit):
			var ma := ModelActor.new()
			add_child(ma)
			if ma.setup(unit):
				sprite_actor = ma
				_visual_is_model = true
				_dress_visual(ma)
				sprite_actor.play(SpriteStateMap.model_clip_for("idle"))
				return
			ma.queue_free()

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


## The body this man wears: `sprite_unit` plus whichever `sprite_unit_variants`
## exist on disk. Seeded from the shared memberless-man walk, so an operation seed
## rebuilds the same force (ADR-010).
func _pick_body(unit: String) -> String:
	if enemy_data == null or not ("sprite_unit_variants" in enemy_data):
		return unit
	var pool: Array[String] = [unit]
	for v: String in enemy_data.sprite_unit_variants:
		if not v.is_empty() and v != unit and ModelActor.model_exists(v):
			pool.append(v)
	if pool.size() == 1:
		return unit
	var rng := RandomNumberGenerator.new()
	rng.seed = GruntRandomizer.next_bench_seed()
	return pool[rng.randi_range(0, pool.size() - 1)]


## Deal this man a face and his gear. The enemy side of the call allies make
## (ally_base.gd dress_visual) and civilians make (civilian.gd) - without it the
## whole force wears the one face it was exported with.
## Seeded from the shared memberless-man walk, so an operation seed rebuilds the
## same force (ADR-010); MissionScope.reset() rewinds it between missions.
func _dress_visual(ma: ModelActor) -> void:
	if not VcNvaDresser.is_dressable(ma.unit):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GruntRandomizer.next_bench_seed()
	VcNvaDresser.dress(ma, rng)


## Low-posture (crouch) - shared contract via CombatPosture, identical for allies:
## crouch to hold/react/at-cover, stand to advance/flank/rush, a heavy pin crouches
## anyone. SEEKING_COVER crouches only once NEAR the cover point, never on the goal
## flip 10m out.
func _is_low_posture(_firing: bool) -> bool:
	return CombatPosture.decide(current_state, suppression_level, _near_cover(), _prone) \
		== CombatPosture.Posture.CROUCH


## Going down and getting up are 1.833s one-shots (measured off the glTF). ModelActor
## exposes no finished signal, so the window IS the state - same timed-window pattern
## the stumble and grenade one-shots use.
const PRONE_TRANSITION_MS: float = 1833.0
## Below this he counts as stationary. A MOVING man never goes prone and a prone man
## who starts moving gets up, because there is no prone locomotion clip to give him.
const PRONE_STILL_SPEED: float = 0.35


## The prone LATCH. Held across state changes on purpose: he commits to the deck under
## a heavy pin, and as the pin decays back through COMBAT he is still down and returns
## fire from it. Without the latch prone would live entirely inside SUPPRESSED, whose
## executor is a pure freeze (_execute_suppressed) - and prone_firing_rifle would never
## play a single frame.
func _update_prone_latch(now: float, speed: float) -> void:
	var moving: bool = speed > PRONE_STILL_SPEED
	if _prone:
		var dwell: float = (now - _prone_since_ms) / 1000.0
		if CombatPosture.must_rise(suppression_level, moving, dwell):
			_prone = false
			_prone_pin_since_ms = 0.0
			_prone_rise_until_ms = now + PRONE_TRANSITION_MS
		return
	if CombatPosture.wants_prone(current_state, suppression_level, moving):
		if _prone_pin_since_ms <= 0.0:
			_prone_pin_since_ms = now
		elif now - _prone_pin_since_ms >= CombatPosture.PRONE_ENTER_HOLD_S * 1000.0:
			_prone = true
			_prone_since_ms = now
			_prone_drop_until_ms = now + PRONE_TRANSITION_MS
	else:
		_prone_pin_since_ms = 0.0


## True while either transition is playing. His legs are committed - a man crossing
## the ground on his belly with no crawl clip in the library is the ice-skate.
func _in_prone_transition() -> bool:
	var now: float = float(Time.get_ticks_msec())
	return _prone_drop_until_ms > now or _prone_rise_until_ms > now


## Signed yaw rate in rad/s, smoothed. The state map has only ever read SPEED, so a
## stationary man changing facing had no intent of his own and slid his feet round.
## Smoothed because a raw per-frame delta at 60fps flickers across any threshold.
func _update_turn_rate(now: float) -> void:
	var yaw_now: float = atan2(facing_dir.x, facing_dir.z)
	var dt: float = (now - _yaw_prev_ms) / 1000.0
	if _yaw_prev_ms <= 0.0 or dt <= 0.0 or dt > 0.5:
		_yaw_prev = yaw_now
		_yaw_prev_ms = now
		_turn_rate = 0.0
		return
	if dt < 0.008:
		return
	_turn_rate = lerpf(_turn_rate, wrapf(yaw_now - _yaw_prev, -PI, PI) / dt, 0.35)
	_yaw_prev = yaw_now
	_yaw_prev_ms = now


func _near_cover() -> bool:
	return has_cover or (_moving_to_cover \
		and global_position.distance_to(current_cover) <= CombatPosture.COVER_CROUCH_RANGE)


## Drive the clip from the AI. Called every frame from _execute(), never from
## _think() - think is LOD-throttled to 0.6s past 150m and animation would run
## at 1.6 fps.
func _update_sprite() -> void:
	if sprite_actor == null:
		return
	sprite_actor.set_facing(facing_dir)
	if current_state == Enums.AIState.DEAD or is_surrendered or is_downed:
		return  # the death / surrender / downed clip was latched; do not restart it
	# A man on fire outranks every other performance: he is not taking cover,
	# throwing, or doing his job. Burning owns him until it kills him.
	# Resolved by NODE NAME, not by class: a `class_name` is not registered until
	# the editor rescans, and a script that only compiles after an editor visit
	# is a script that breaks every headless run.
	var burn: Node = get_node_or_null("Burning")
	if burn != null and burn.has_method("is_burning") and bool(burn.call("is_burning")) \
			and sprite_actor is ModelActor:
		# "" once he has dropped: the ragdoll owns the skeleton and any clip
		# would fight the physics for the same bones.
		var bclip: String = String(burn.call("clip"))
		if bclip != "" and not (sprite_actor as ModelActor).play(bclip):
			(sprite_actor as ModelActor).play(String(burn.call("clip_alt")))
		return
	# Cover-exit one-shot (Track B3): a man leaving cover stands up before he moves.
	# Self-clearing window - no _anim_override, so no "frozen crouch statue" leak.
	if _cover_exit_until_ms > float(Time.get_ticks_msec()) and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play("cover_to_stand")
		return
	# Stumble outranks the throw: a man hit mid-windup drops the performance.
	if _stumble_until_ms > float(Time.get_ticks_msec()) and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play("stumble_hit")
		return
	# Grenade windup one-shot. The telegraph was a shout and floating text with no
	# body behind it - the arm never moved. Same self-clearing window as above.
	if _throw_until_ms > float(Time.get_ticks_msec()) and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play("grenade_throw")
		return
	# A man doing a JOB shows it, and the job outranks the state map. Set by the behaviour
	# that owns him (SapperCharge while he plants); cleared when the job ends.
	if work_clip != "" and sprite_actor is ModelActor:
		(sprite_actor as ModelActor).play_first([work_clip, "idle_crouching"] as Array[String])
		return
	if _play_camp_role():
		return
	var vel_flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = vel_flat.length()
	var lateral: float = 0.0
	# Signed forward component, so the state map can tell a diagonal from a straight
	# run. Without it a man moving at 45 degrees played the straight-ahead clip and
	# crabbed - feet driving forward while the body slid off sideways.
	var forward_c: float = 1.0
	if speed > 0.1:
		var fwd := Vector3(facing_dir.x, 0.0, facing_dir.z).normalized()
		var vdir := vel_flat.normalized()
		lateral = vdir.dot(fwd.cross(Vector3.UP))
		forward_c = vdir.dot(fwd)
	var now: float = float(Time.get_ticks_msec())
	var firing: bool = now < _fired_until_ms
	var sneaking: bool = current_state == Enums.AIState.SEEKING_COVER \
		and alert_tier <= AlertTier.SUSPICIOUS and _near_cover()
	_update_turn_rate(now)
	_update_prone_latch(now, speed)
	# Going down and getting up are one-shots, and they outrank the state map the same
	# way the stumble and the grenade windup do. Death and stumble are checked ABOVE
	# this, so a man shot mid-transition drops the performance rather than finishing it.
	if sprite_actor is ModelActor:
		if _prone_drop_until_ms > now:
			(sprite_actor as ModelActor).play("crouch_to_prone")
			return
		if _prone_rise_until_ms > now:
			(sprite_actor as ModelActor).play("prone_to_crouch")
			return
	_low_posture = _is_low_posture(firing)
	var prev_intent: String = _last_intent
	var intent: String = SpriteStateMap.intent_for(current_state, is_crippled, is_surrendered, firing, speed, lateral, sneaking, _low_posture, _prone, _turn_rate, forward_c)
	# Stability filter: an intent must WIN continuously for 180ms before the clip
	# commits. Fire and death still switch immediately.
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
	# ARRIVAL BEAT: a fast man settling into a stationary pose plants his feet.
	# Display-only: the latch state above stays honest.
	if _arrive_until_ms > now:
		if intent == "fire" or intent.begins_with("death"):
			_arrive_until_ms = 0.0  # shooting/dying outranks footwork
		else:
			intent = "arrive"
	elif (prev_intent == "run" or prev_intent == "sprint") \
			and (intent == "aim" or intent == "idle" or intent == "cover"):
		_arrive_until_ms = now + 450.0
		intent = "arrive"
	sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_weapon), intent))
	if sprite_actor is ModelActor:
		(sprite_actor as ModelActor).set_locomotion_speed(speed)


## What a camp man's ROLE looks like once he has reached his station. CampDirector rotates
## `camp_role` every sim-hour and seats `work_pos` to a station; without this the cook walks
## to the fire and plays the standing rifle idle, which is the whole camp on one pose.
##
## Mirrors Civilian._play_garrison (the US side has always had role-aware chains). Only the
## clips the shipped library actually carries are named - a missing clip must degrade to a
## T-pose, which is loud, rather than to a weapon pose, which is quiet and wrong.
const CAMP_ROLE_CLIPS: Dictionary = {
	# A guard scans. These are unarmed clips, so his rifle rides the hand at an odd
	# angle - accepted for a man at a post until a weapon-family hold exists.
	"guard": ["sentry_scan", "crouch_scan", "nervous_scan", "idle_aiming"],
	"cook": ["kneeling_idle", "idle_crouching", "sitting_idle_b", "sitting"],
	"rest": ["smoking", "sitting_drinking", "neck_stretch", "arm_stretch",
		"sitting_idle_c", "sitting", "idle_unarmed_5"],
	# NO AMERICAN SOCIAL CLIPS ON A VC CAMP (his ruling, 2026-07-31: "keep for US only,
	# never VC or villagers"). sitting_talking and telling_secret are open-palm gesturing
	# and casual weight shifts - on these men they read as businessmen in costume.
	"talk": ["standing_talking", "sitting_idle_b", "sitting", "idle_unarmed_4"],
	"sleep": ["sleeping_laying", "laying_idle", "sleeping_sitting", "sitting"],
}

## play_first() plays the FIRST clip the rig carries, so a role with one chain is a
## role with one pose: every resting man in the camp smoked, together, forever. The
## chain is ROTATED per man instead - same clips, different head. Keyed off his
## station, which the seeded camp layout fixes, so the camp rebuilds identical
## (ADR-010).
##
## The LAST entry never rotates. It is the degrade target - the clip every rig is
## known to carry - and promoting it to the head would answer "what pose is this
## man in" with "the fallback".
func _role_chain(role: String) -> Array[String]:
	var chain: Array = CAMP_ROLE_CLIPS[role]
	var rotatable: int = chain.size() - 1
	if rotatable < 2:
		# The const's inner arrays are UNTYPED; `as Array[String]` does not convert one
		# and the call fails at runtime. Copy the elements.
		var short: Array[String] = []
		for c in chain:
			short.append(str(c))
		return short
	var off: int = absi(hash(Vector2i(int(work_pos.x * 4.0), int(work_pos.z * 4.0)))) % rotatable
	var out: Array[String] = []
	for i in range(rotatable):
		out.append(str(chain[(i + off) % rotatable]))
	out.append(str(chain[chain.size() - 1]))
	return out
## How close to his station a man must be before the role pose replaces his walk.
const CAMP_ROLE_AT_STATION_M: float = 2.2


## True when a role pose was played and the state map must not overwrite it.
func _play_camp_role() -> bool:
	if not (sprite_actor is ModelActor):
		return false
	# A man who is fighting, hunting, or moving is not off duty. "guard" and "patrol" are
	# deliberately absent from the table: those men hold the armed poses already.
	if target != null or alert_tier > AlertTier.SUSPICIOUS:
		return false
	if current_state != Enums.AIState.IDLE or is_crippled:
		return false
	if not CAMP_ROLE_CLIPS.has(camp_role):
		return false
	if work_pos == Vector3.ZERO or global_position.distance_to(work_pos) > CAMP_ROLE_AT_STATION_M:
		return false
	if Vector3(velocity.x, 0.0, velocity.z).length() > 0.35:
		return false
	(sprite_actor as ModelActor).play_first(_role_chain(camp_role))
	return true


## HitzoneBuilder is the single authority for zones - do not hand-place them here.
func _setup_hurtbox() -> void:
	var ma: ModelActor = sprite_actor as ModelActor if _visual_is_model else null
	# layer 64 = enemy_hurtbox, mask 8 = player_hitbox.
	_hitzone_sync = HitzoneBuilder.build(self, ma, 64, 8, ["hitzone"], true)


## ============================================
## MAIN LOOP - Separate think from execute
## ============================================

## Meters walked since the last audible footstep (~one stride).
var _step_accum: float = 0.0

func _physics_process(delta: float) -> void:
	var t_start: int = Time.get_ticks_usec()
	_body_hot = _body_gate_open()
	if _body_hot:
		CombatManager.bodies_run += 1
	else:
		CombatManager.bodies_gated += 1
	# Zones ride the skeleton even on the corpse; a settled corpse re-syncs at 6Hz.
	if _visual_is_model:
		if current_state == Enums.AIState.DEAD:
			_corpse_sync_t += delta
			if _body_hot and _corpse_sync_t >= 0.16:
				_corpse_sync_t = 0.0
				HitzoneBuilder.sync(sprite_actor as ModelActor, _hitzone_sync)
		elif _body_hot:
			HitzoneBuilder.sync(sprite_actor as ModelActor, _hitzone_sync)
	var t_sync: int = Time.get_ticks_usec()
	CombatManager.ai_usec_hitzone += t_sync - t_start
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
			VOManager.play_enemy("man_down", self, true)
		if _downed_bleed_s <= 0.0:
			_die()
		return

	# Cap delta for framerate independence.
	var capped_delta: float = minf(delta, 0.066)

	# WA-A2 BODY-GATE CONTRACT (DA TRAP 2): everything below this line except
	# gravity, move_and_slide and the sprite/hitzone paths keyed on _body_hot
	# ticks for GATED men too - think, hearing, decay and death clocks never gate.
	if _body_hot and not is_on_floor():
		velocity.y -= gravity * capped_delta

	_update_decay(capped_delta)

	_update_think_lod(capped_delta)
	think_timer += capped_delta
	var usec_think: int = 0
	if think_timer >= _think_interval_current:
		think_timer = 0.0
		var t_think: int = Time.get_ticks_usec()
		_think()
		usec_think = Time.get_ticks_usec() - t_think
		CombatManager.ai_usec_think += usec_think

	_execute(capped_delta)

	_update_unstick(capped_delta)
	# Move-side of low-posture (B2): cap ground speed so the crouch clip reads as a
	# crouch and not a skate. Only cautious/pinned men are low_posture, so this
	# never throttles a firing assault. Applied after _execute sets velocity.
	# HIS LEGS ARE COMMITTED, but his trigger finger is not. Clamped HERE - the one
	# choke point that runs after every executor - rather than by returning early from
	# _execute, so a man on the deck still aims and still fires. The library carries no
	# prone crawl, so any velocity that survives is a man gliding on his belly.
	if _prone or _in_prone_transition():
		velocity.x = 0.0
		velocity.z = 0.0
	elif _low_posture:
		var flat := Vector2(velocity.x, velocity.z)
		if flat.length() > CROUCH_SPEED_CAP:
			flat = flat.normalized() * CROUCH_SPEED_CAP
			velocity.x = flat.x
			velocity.z = flat.y
	var t_move: int = Time.get_ticks_usec()
	if _body_hot:
		move_and_slide()
		_step_accum += Vector2(velocity.x, velocity.z).length() * capped_delta
		if _step_accum >= 0.85:
			_step_accum = 0.0
			AudioManager.play_step_3d(global_position, _low_posture)
	CombatManager.ai_usec_move += Time.get_ticks_usec() - t_move
	CombatManager.ai_usec_anim += (t_move - t_sync) - usec_think


## WA-A2 body gate: only the BODY sleeps. Downed and cover-exit men are pinned
## hot (test_body_gate contract). "Trying to move" needs no nav check - _execute
## writes velocity every frame ungated, so a mover reopens the gate next frame.
## The de-phased heartbeat bounds pose/hitzone staleness for everyone else.
func _body_gate_open() -> bool:
	if is_downed or current_state == Enums.AIState.COMBAT or alert_tier > AlertTier.RELAXED:
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


func _update_decay(delta: float) -> void:
	if suppression_level > 0:
		suppression_level = maxf(0.0, suppression_level
			- SUPPRESSION_DECAY * CombatPosture.suppress_recovery_mult(cover01()) * delta)
		if suppression_level <= CombatPosture.SUPPRESS_PIN:
			pinned_since_ms = 0.0
	if _gut_bleed_dps > 0.0 and current_state != Enums.AIState.DEAD:
		_bleed_accum += _gut_bleed_dps * delta
		if _bleed_accum >= 1.0:
			var _tick := int(_bleed_accum)
			_bleed_accum -= float(_tick)
			current_hp -= _tick
			if current_hp <= 0:
				current_hp = 0
				_die()

	damage_decay_timer += delta
	if damage_decay_timer >= 2.0:
		damage_taken_recently = 0
		damage_decay_timer = 0.0

	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0:
			can_fire = true


## ============================================
## THINK - Goal evaluation and decision making
## ============================================

func _think() -> void:
	think_count += 1
	_refresh_terrain_cover()
	_router.refresh_box(global_position)
	_check_spider_hole()
	_check_tunnel_retreat()
	if is_spider_hole and not _spider_triggered:
		return  # still buried - no perception, no movement
	# WITNESS HEARTBEAT (ADR-005): perception + corpse discovery run on EVERY unit
	# at every tier. This is the guard-rail - tiering never sheds the witness check.
	_update_perception()
	_check_corpse_discovery()
	if enemy_data != null and enemy_data.combat_medic and not is_downed:
		_medic_think()

	# ACTIVITY TIER (ADR-026 Part B): only the rolling hot-set runs the expensive
	# combat brain. The rest of the fight runs cheap behavior with no per-think
	# targeting or LOS raycast. A cold fighter promotes itself the instant a hot
	# slot frees (promote-on-death). Non-combat units are never tiered.
	if alert_tier == AlertTier.COMBAT:
		if EnemySquad.is_hot(self) or EnemySquad.request_hot(self):
			_refresh_separation()
			_think_full_combat()
		else:
			_think_cheap_combat()
		return

	if target != null:
		target = null  # not aware enough to have a hard target
	_update_line_of_sight()
	_assess_threat()
	_evaluate_goals()
	_update_state_for_goal()
	_squad_sync()


## The full combat brain - target acquisition, a precise LOS raycast, threat
## assessment, the scored goal stack, squad designation. Hot-set only.
func _think_full_combat() -> void:
	_find_best_target()
	_update_line_of_sight()
	_assess_threat()
	_evaluate_goals()
	_update_state_for_goal()
	_squad_sync()


## Cheap behavior for a cold fighter: adopt the squad's shared contact (a dict
## read - no scan, no raycast), presume a loose contact so he keeps firing toward
## the fight, hold or close. The hot-set owns precise aim; exposure never ramps
## for a cold man, so his cone stays wide - he sprays, he does not snipe.
func _think_cheap_combat() -> void:
	var st: Node3D = EnemySquad.shared_target(squad_id)
	if st != null and is_instance_valid(st):
		target = st
		last_known_target_pos = EnemySquad.shared_last_known(squad_id)
		_combat_lost_time = 0.0
	else:
		target = null
		_combat_lost_time += _think_interval_current
		if _combat_lost_time > 8.0:
			_set_tier(AlertTier.ALERT, false)  # disengage: frees the hot slot for a live fighter
			return
	# A cold fighter fires only at what it can actually WITNESS - not a squad-shared target it has
	# no line to. Without this every man in the camp poured precision fire on a player only one of
	# them could see. Unseen -> no LOS -> it suppresses/investigates instead of deadeye-firing.
	has_line_of_sight = target != null and _can_witness(last_known_target_pos)
	_assess_threat()
	_cheap_goal()
	_update_state_for_goal()


func _cheap_goal() -> void:
	var g: Enums.AIGoal = Enums.AIGoal.ENGAGE_TARGET if target != null else Enums.AIGoal.HOLD_POSITION
	if g != current_goal:
		_set_goal(g)


## Pop the ambush the moment the player closes to trigger range.
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


## A crippled fighter near a tunnel entrance slips underground and is gone.
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


## ---------- PERCEPTION ----------

## Local sight cap from vegetation density.
func _sight_cap(at: Vector3) -> float:
	return SightCap.at(_grid, global_position, at)


## Share what I see, pull what the squad knows (EnemySquad).
func _squad_sync() -> void:
	if squad_id < 0:
		return
	var now: float = float(Time.get_ticks_msec())
	if target != null and is_instance_valid(target) and has_line_of_sight:
		# Eyes on: designate for the squad + lay a breadcrumb trail.
		# WATER BREAKS TRAIL: a man in the creek leaves no sign to follow.
		var leaves_sign: bool = _grid == null or not _grid.is_water(target.global_position)
		EnemySquad.report_contact(squad_id, target, target.global_position, now, leaves_sign)
		# Census: men already covered by squadmates score lower in _target_score.
		EnemySquad.report_engagement(squad_id, self, target, now)
	elif target == null and EnemySquad.has_fresh_intel(squad_id, now):
		# A buddy sees the enemy; I don't. Adopt the squad's contact and wake up.
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


## ---------- THE WITNESS RULE (ADR-005) ----------

## Bodies nobody reported. A kill nobody saw does not raise the alarm; the body will.
## Cleared per mission by FieldDirector.
##
## BOUNDED, because this is scanned by every living unit on every heartbeat and was only
## ever emptied at world build - over a 30-minute patrol it is the scan that grows, not
## the memory. The OLDEST body is forgotten first: the witness logic is untouched, the
## record just stops being infinite.
const MAX_UNREPORTED_CORPSES: int = 48
static var unreported_corpses: Array[Vector3] = []

## Can this man actually SEE that point? Sight cap + facing cone + smoke + a real ray.
func _can_witness(at: Vector3) -> bool:
	var eye: Vector3 = global_position + Vector3.UP * 1.5
	var tgt: Vector3 = at + Vector3.UP * 1.0
	if global_position.distance_to(at) > _sight_cap(at):
		return false
	if alert_tier != AlertTier.COMBAT:
		var to_c: Vector3 = (at - global_position).normalized()
		var flat: Vector3 = Vector3(facing_dir.x, 0, facing_dir.z).normalized()
		if flat.dot(Vector3(to_c.x, 0, to_c.z).normalized()) <= cos(deg_to_rad(_fov_deg() * 0.5)):
			return false
	if SmokeCloud.blocks_sight(eye, tgt):
		return false
	CombatManager.rays_witness += 1
	return CombatManager.has_line_of_sight(eye, tgt, [self])


## A DEAD MAN TELLS NO TALES - but the man who WATCHED HIM DROP does.
## Called from _die(). If any living enemy could genuinely see this kill happen, HE
## raises the alarm and he knows roughly which way it came from. If nobody saw it,
## the AO learns NOTHING and the body goes on the liability list.
func _witness_check(killer: Node) -> void:
	if killer != null and not is_instance_valid(killer):
		killer = null
	for e in get_tree().get_nodes_in_group("enemies"):
		var w := e as EnemyBase
		if w == null or w == self or w.is_dead() or w.is_surrendered:
			continue
		# ALARM versus REACTION. Raising the tier is pointless once the fight is on,
		# but a man beside you dropping is not a stealth-phase event - bailing the whole
		# loop here made casualty reaction impossible during an actual firefight.
		if w.alert_tier == AlertTier.COMBAT:
			if w.global_position.distance_to(global_position) < CLOSE_SENSE_RANGE:
				w.apply_suppression(CASUALTY_SHOCK)
				w.goal_timer = 99.0
			continue
		# EYES ON, or CLOSE ENOUGH TO HEAR HIM FALL. LOS is still required either way:
		# a wall hides the sound of a fall as surely as the sight of it.
		var heard_him_fall: bool = w.global_position.distance_to(global_position) < CLOSE_SENSE_RANGE 			and CombatManager.has_line_of_sight(
				w.global_position + Vector3.UP * 1.5, global_position + Vector3.UP * 1.0, [w, self])
		if not heard_him_fall and not w._can_witness(global_position):
			continue
		w._stamp_contact()
		w._set_tier(AlertTier.ALERT, false)
		w.awareness = maxf(w.awareness, 0.8)
		if killer is Node3D:
			w.last_known_target_pos = (killer as Node3D).global_position
			w.target_last_seen_time = 0.0
		else:
			w.last_known_target_pos = global_position
		VOManager.play_enemy("spotted_us", w)
		NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, w.global_position, 1, 30.0)
		return
	# NOBODY SAW IT. The kill is clean. But he is still lying there.
	EnemyBase.unreported_corpses.append(global_position)
	while EnemyBase.unreported_corpses.size() > MAX_UNREPORTED_CORPSES:
		EnemyBase.unreported_corpses.remove_at(0)
	# ...and a body does not decay out of the record the way a sound does. ADR-022
	# already calls a corpse you left a liability; this is where it becomes one.
	var fd: Node = get_tree().get_first_node_in_group("mission_director")
	if fd != null and "evidence" in fd:
		var led: EvidenceLedger = fd.get("evidence") as EvidenceLedger
		if led != null:
			led.on_body_left(global_position, float(Time.get_ticks_msec()) * 0.001)


## Walking up on a dead friend: the delayed price of a body you did not hide.
func _check_corpse_discovery() -> void:
	if alert_tier == AlertTier.COMBAT or EnemyBase.unreported_corpses.is_empty():
		return
	for i in range(EnemyBase.unreported_corpses.size()):
		var body: Vector3 = EnemyBase.unreported_corpses[i]
		if global_position.distance_to(body) > CORPSE_NOTICE_RANGE:
			continue
		if not _can_witness(body):
			continue
		EnemyBase.unreported_corpses.remove_at(i)
		_stamp_contact()
		_set_tier(AlertTier.ALERT, false)
		awareness = maxf(awareness, 0.6)
		last_known_target_pos = body   # they sweep outward from where he fell
		target_last_seen_time = 0.0
		if squad_id >= 0:
			EnemySquad.begin_hunt(squad_id, body, body - global_position, float(Time.get_ticks_msec()))
			EnemySquad.reanchor_hunt(squad_id, body, float(Time.get_ticks_msec()))
		VOManager.play_enemy("spotted_us", self)
		NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 30.0)
		return


func _update_perception() -> void:
	# Candidate: nearest living hostile (player weighted first).
	var candidate: Node3D = null
	var best_dist: float = 99999.0
	var player := GameManager.player as Node3D
	if player != null and is_instance_valid(player):
		best_dist = global_position.distance_to(player.global_position)
		candidate = player
	# BUDDY RULE: the player's own SQUAD is perception-exempt until we are in COMBAT, so his
	# stealth is never broken by their AI pathing. It is a rule about HIS men on HIS patrol.
	#
	# It used to exempt every ally alive, and that was the other half of the 2026-07-29
	# "nobody fought" playtest: an assault force crossing the wire could perceive NOTHING but
	# the player. A dozen garrison defenders standing their posts were invisible to them, so
	# the attackers never reached COMBAT tier and never had anyone to shoot at. Men defending
	# a firebase are not the player's buddies and were never what this rule was protecting.
	var combat: bool = alert_tier == AlertTier.COMBAT
	for ally in get_tree().get_nodes_in_group("allies"):
		var a := ally as Node3D
		if a == null or (a.has_method("is_dead") and a.is_dead()):
			continue
		if not combat:
			var ab := a as AllyBase
			if ab == null or ab.squad_member:
				continue   # his squad, and we are not yet in contact - stay blind to them
		var d := global_position.distance_to(a.global_position)
		if d < best_dist:
			best_dist = d
			candidate = a

	var gain: float = 0.0
	if candidate != null:
		var cap := _sight_cap(candidate.global_position)
		# A player who holds still and low conceals HARD. The 12m veg grid cannot see the bush
		# or clutter he is crouched in, so posture tightens the sight cap directly (Pillar 3 -
		# crouch in cover MUST beat the range gate). Moving cancels it (you break your own hide).
		if candidate == player:
			if "is_prone" in player and player.is_prone:
				cap *= 0.4
			elif "is_crouching" in player and player.is_crouching \
					and not (player.has_method("is_moving") and player.is_moving()):
				cap *= 0.6
		if best_dist <= cap:
			# FOV cone (COMBAT = all-round awareness).
			var in_fov := true
			if alert_tier != AlertTier.COMBAT:
				var to_c := (candidate.global_position - global_position).normalized()
				var flat_facing := Vector3(facing_dir.x, 0, facing_dir.z).normalized()
				in_fov = flat_facing.dot(Vector3(to_c.x, 0, to_c.z).normalized()) > cos(deg_to_rad(_fov_deg() * 0.5))
			# A contact this close is FELT regardless of facing (boots, gear, breathing).
			# LOS is still required: a wall hides.
			var point_blank: bool = best_dist < CLOSE_SENSE_RANGE
			var sees: bool = false
			if (in_fov or point_blank) and not SmokeCloud.blocks_sight(
					global_position + Vector3.UP * 1.5,
					candidate.global_position + Vector3.UP * 1.0):
				CombatManager.rays_perception += 1
				sees = CombatManager.has_line_of_sight(
					global_position + Vector3.UP * 1.5,
					candidate.global_position + Vector3.UP * 1.0, [self])
				if sees:
					# Dense jungle or a hill can break the spot even on a clear geometry ray.
					sees = SightCap.has_terrain_los(_grid, global_position + Vector3.UP * 1.5, candidate.global_position + Vector3.UP * 1.0)
			if sees:
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


## How hard this man hunts you once he has lost you - NOT courage (which is
## whether he breaks under fire). This is whether he goes home.
func _determination() -> float:
	if enemy_data != null and "determination" in enemy_data:
		return float(enemy_data.determination)
	return 0.5


func _stamp_contact() -> void:
	EnemyBase.last_combat_contact_ms = float(Time.get_ticks_msec())
	# CONTACT LEDGER (ADR-006): this man went loud, so his whole group is DETECTED.
	# Group identity = the squad he coordinates with; a lone wolf is his own.
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	if d != null and d.has_method("report_contact"):
		d.call("report_contact", squad_id if squad_id >= 0 else get_instance_id())


## `witnessed` = false means "go loud LOCALLY, but you are not proof of anything."
## Used by take_damage: a man being shot fights back, but a corpse raises no alarm.
func _set_tier(tier: AlertTier, witnessed: bool = true) -> void:
	if tier == AlertTier.COMBAT and witnessed:
		_stamp_contact()
	if tier == alert_tier:
		return
	var was_cold: bool = alert_tier == AlertTier.RELAXED or alert_tier == AlertTier.SUSPICIOUS
	alert_tier = tier
	if tier != AlertTier.COMBAT:
		EnemySquad.release_hot(self)  # left the fight: give the hot slot back
	if tier == AlertTier.COMBAT:
		awareness = 1.0
		_first_shot_fired = false  # new fight, new warning shot
		# Bumping into each other at close range startles BOTH sides.
		if was_cold:
			var player := GameManager.player as Node3D
			if player and global_position.distance_to(player.global_position) < 15.0:
				has_reacted = false
				reaction_timer = -randf_range(0.4, 0.7)  # extra startle delay
		if not silent_infiltrator:
			GunFX.play_combat_sting(get_tree().current_scene)


## Heard something. Investigation goes to the NOISE, not the source.
func _on_noise_heard(_type: int, noise_pos: Vector3, radius: float, source_team: int) -> void:
	# A man's own side SHOUTING is the whole point of shouting. Dropping every
	# own-team noise muted six emitters - the witness alarm, corpse discovery, the
	# grenade telegraph, pain, the crippled cry and orders - so no enemy had ever
	# heard another. Only own-team GUNFIRE and movement are still ignored.
	if source_team == 1 and _type != NoiseBus.NoiseType.VOICE:
		return
	if current_state == Enums.AIState.DEAD:
		return
	if global_position.distance_to(noise_pos) > radius:
		return
	last_known_target_pos = noise_pos
	target_last_seen_time = 0.0
	awareness = minf(1.0, awareness + 0.35)
	if alert_tier == AlertTier.RELAXED:
		_set_tier(AlertTier.SUSPICIOUS)
	elif alert_tier == AlertTier.SUSPICIOUS:
		_set_tier(AlertTier.ALERT)


## HONEST ATTENTION: no intrinsic player bias, no sticky-until-dead lock. Rescored
## every RETARGET_INTERVAL, or immediately when the target dies / someone hurts us.
const RETARGET_INTERVAL: float = 2.0
const TARGET_MEMORY: float = 8.0
var _retarget_timer: float = 0.0
var _last_attacker: Node3D = null
var _last_attacker_ms: float = -1e9


## Only ever a player/ally node (take_damage sets it group-gated) - the patrol AAR's
## kill-credit source. Null when no friendly hand ever touched this man.
func last_friendly_attacker() -> Node3D:
	return _last_attacker if is_instance_valid(_last_attacker) else null


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

	# Slip-away rule: unseen too long and not hurting us -> drop to the blind hunt.
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
		# The blind clock must run for a man who holds NO target, or INVESTIGATE
		# never expires and the hunt anchor walks him past his objective forever.
		target_last_seen_time += _think_interval_current
		return

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := target.global_position + Vector3.UP * 1.0

	var new_los := CombatManager.has_line_of_sight(eye_pos, target_pos, [self])
	if new_los:
		new_los = SightCap.has_terrain_los(_grid, eye_pos, target_pos)

	# Exposure clock: accuracy ramps with EXPOSURE TIME; LOS loss DRAINS at 3x the
	# build rate (a foliage blink keeps most of the ramp; ~0.8s blind zeroes it).
	if new_los:
		target_visible_duration += _think_interval_current
		last_known_target_pos = target.global_position
		target_last_seen_time = 0.0
	else:
		target_last_seen_time += _think_interval_current
		target_visible_duration = maxf(0.0, target_visible_duration - _think_interval_current * 3.0)

	# CONTACT CONFIDENCE: the debounced "I see him" that GOALS read - full in ~0.3s
	# of eyes-on, empty over ~2.0s blind. Only FIRING reads the raw LOS boolean.
	if new_los:
		contact_conf = minf(1.0, contact_conf + _think_interval_current / 0.3)
	else:
		contact_conf = maxf(0.0, contact_conf - _think_interval_current / 2.0)

	has_line_of_sight = new_los


func _assess_threat() -> void:
	threat_level = 0.0

	threat_level += suppression_level * 0.4

	var damage_ratio: float = float(damage_taken_recently) / float(max_hp)
	threat_level += damage_ratio * 0.5

	var health_ratio: float = float(current_hp) / float(max_hp)
	if health_ratio < 0.3:
		threat_level += 0.3

	if not has_cover:
		threat_level += 0.2

	threat_level = clampf(threat_level, 0.0, 1.0)


## Contact time + dry cover searches (the escape hatch that stops cover-first
## doctrine producing passive cowards).
var _contact_time: float = 0.0
var _cover_fail_count: int = 0
var _bound_point: Vector3 = Vector3.ZERO
var _bound_pause: float = 0.0
var _bound_fail_count: int = 0


func _evaluate_goals() -> void:
	goal_timer += THINK_INTERVAL

	# Dwell ~1s. Class-A interrupts (taking damage) force goal_timer past this gate
	# from take_damage().
	if goal_timer < 1.0 and current_goal != Enums.AIGoal.NONE:
		return

	# A rush COMPLETES: while moving to claimed cover, hold the goal until
	# arrival (cap 4s so a blocked path can't lock a man forever).
	if current_goal == Enums.AIGoal.SEEK_COVER and _moving_to_cover and goal_timer < 4.0:
		return

	var best_goal: Enums.AIGoal = Enums.AIGoal.NONE
	var best_score: float = 0.0

	if not target or not is_instance_valid(target):
		_contact_time = 0.0
		_cover_fail_count = 0
		# CONTACT BROKEN -> THE HUNT BEGINS. How long the net stays open is his DETERMINATION.
		var now_h: float = float(Time.get_ticks_msec())
		if squad_id >= 0 and last_known_target_pos != Vector3.ZERO and alert_tier >= AlertTier.ALERT:
			# WHICH WAY WAS HE RUNNING. Read the crumb trail oldest -> newest.
			var heading: Vector3 = EnemySquad.trail_heading(squad_id)
			if heading.length() < 0.5:
				# No usable trail (he was seen once and vanished): push away from us, which
				# is the only direction he can possibly have gone.
				heading = last_known_target_pos - global_position
			EnemySquad.begin_hunt(squad_id, last_known_target_pos, heading, now_h)
		var hunting: bool = squad_id >= 0 and EnemySquad.hunt_active(squad_id, now_h, _determination())
		if last_known_target_pos != Vector3.ZERO and (hunting or target_last_seen_time < 5.0):
			best_goal = Enums.AIGoal.INVESTIGATE
		else:
			if squad_id >= 0:
				EnemySquad.end_hunt(squad_id)
			best_goal = Enums.AIGoal.HOLD_POSITION
		_set_goal(best_goal)
		return

	_contact_time += _think_interval_current
	var now_ms: float = float(Time.get_ticks_msec())

	# Local force ratio, refreshed on the think cadence; the rout ladder in
	# take_damage reuses it.
	_last_force_ratio = _local_force_ratio()

	var c := CombatGoals.Context.new()
	c.current_goal = current_goal
	c.dist = global_position.distance_to(target.global_position)
	c.preferred_range = preferred_range
	c.eyes_on = contact_conf > 0.5   # DEBOUNCED confidence, never raw LOS
	c.target_last_seen = target_last_seen_time
	c.has_cover = has_cover
	c.threat_level = threat_level
	c.suppression = suppression_level
	c.contact_time = _contact_time
	c.cover_fail_count = _cover_fail_count
	c.full_auto = weapon_data != null and weapon_data.firing_mode == Enums.FiringMode.FULL_AUTO
	c.hp_frac = float(current_hp) / float(max_hp)
	c.aggression = char_aggression
	c.self_preservation = char_self_preservation
	c.uses_cover = d_uses_cover
	c.flanks = d_flanks
	c.retreats_when_hurt = d_retreats_when_hurt
	c.retreat_hp_frac = d_retreat_hp
	c.has_covering_fire = EnemySquad.has_covering_fire(squad_id, self, now_ms)
	# 4utx: a combat-ineffective squad breaks as a body, layered on the individual
	# rout ladder rather than competing with it.
	c.squad_broken = EnemySquad.is_broken(squad_id)
	c.force_ratio = _last_force_ratio
	c.assault_press = siege_press
	# Player reads `suppression` 0..1; allies read `suppression_level`.
	var ts: Variant = target.get("suppression_level")
	if ts == null:
		ts = target.get("suppression")
	c.target_suppressed = ts is float and (ts as float) > 0.5

	best_goal = CombatGoals.pick(c)
	if best_goal != current_goal:
		_set_goal(best_goal)


## Local force ratio: shooters I can count on within 25m (me included) vs the
## opposition still standing (player + his allies). Local on purpose.
func _local_force_ratio() -> float:
	var friends: int = 1
	for e in get_tree().get_nodes_in_group("enemies"):
		var other := e as EnemyBase
		if other != null and other != self and not other.is_dead() \
				and other.global_position.distance_to(global_position) < 25.0:
			friends += 1
	var foes: int = 0
	var p: Node = GameManager.player
	if p != null and is_instance_valid(p) and p is Node3D:
		foes += 1
	for a in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(a) and a is Node3D \
				and a.has_method("is_dead") and not a.is_dead() \
				and (a as Node3D).global_position.distance_to(global_position) < 25.0:
			foes += 1
	return float(friends) / float(maxi(1, foes))


func _set_goal(new_goal: Enums.AIGoal) -> void:
	# Keep the cover claim when transitioning into a FIGHTING goal: releasing it on
	# SEEK_COVER->ENGAGE flips has_cover false and the goals oscillate forever.
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
	if new_goal == Enums.AIGoal.RETREAT:
		_retreat_bearing = Vector3.ZERO  # fresh flight line each rout

	if new_goal == Enums.AIGoal.ENGAGE_TARGET or new_goal == Enums.AIGoal.SUPPRESS_TARGET:
		if not has_reacted:
			reaction_timer = 0.0


func _update_state_for_goal() -> void:
	match current_goal:
		Enums.AIGoal.ENGAGE_TARGET:
			if suppression_level > CombatPosture.SUPPRESS_PIN:
				_change_state(Enums.AIState.SUPPRESSED)
			else:
				_change_state(Enums.AIState.COMBAT)
		Enums.AIGoal.SEEK_COVER:
			_change_state(Enums.AIState.SEEKING_COVER)
		Enums.AIGoal.SUPPRESS_TARGET:
			_change_state(Enums.AIState.COMBAT)
		Enums.AIGoal.FLANK_TARGET:
			_change_state(Enums.AIState.FLANKING)
			VOManager.play_enemy("flanking", self)
		Enums.AIGoal.ADVANCE:
			_change_state(Enums.AIState.ADVANCING)
			VOManager.play_enemy("advance", self)
		Enums.AIGoal.RETREAT:
			_change_state(Enums.AIState.RETREATING)
		Enums.AIGoal.INVESTIGATE:
			_change_state(Enums.AIState.ALERT)
			VOManager.play_enemy("taunt", self)
		Enums.AIGoal.HOLD_POSITION:
			_change_state(Enums.AIState.IDLE)
		_:
			_change_state(Enums.AIState.IDLE)


## ============================================
## EXECUTE - Smooth movement and aiming
## ============================================

func _execute(delta: float) -> void:
	if _body_hot:
		_update_sprite()

	_update_aim(delta)

	# Objective override: a DRIVEN man (sapper, or a cell withdrawing) runs the point and
	# pushes through fire. Movement only - he still thinks, aims and can be killed;
	# the goal FSM below never touches his legs while the objective stands.
	#
	# An UNDRIVEN man - the assault element - marches to the same point but is not spellbound
	# by it: contact or arrival hands his legs back to the combat brain. Without this the
	# whole assault runs at the wire and never fights.
	if assault_objective != Vector3.ZERO:
		if assault_driven:
			_execute_assault(delta)
			return
		if alert_tier != AlertTier.COMBAT \
				and global_position.distance_to(assault_objective) > ASSAULT_ARRIVE_M:
			_execute_assault(delta)
			return
		assault_objective = Vector3.ZERO

	# Medic override, same contract as the sapper's: his legs belong to the
	# casualty - reach the downed man, drag him toward the rear, release. He
	# still thinks, still telegraphs, still dies.
	if _aid_target != null:
		_execute_aid(delta)
		return

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

	var aim_delta: float = aim_speed * delta
	current_aim_dir = current_aim_dir.lerp(target_aim_dir, aim_delta).normalized()

	# Face the aim direction (Y axis only for body)
	var flat_aim: Vector3 = current_aim_dir
	flat_aim.y = 0
	if flat_aim.length() > 0.1:
		look_at(global_position + flat_aim)
		facing_dir = current_aim_dir


## Drive the satchel to the objective at a run, ignoring cover and contact. The
## behaviour node (sapper_charge.gd) owns the detonation; this owns only the legs.
##
## URGENCY IS THE POINT. 1.15 read as a stroll across ground he knows is covered; a man
## crossing the open with a charge on his back is running for the wire, and the assault
## push is the one place in this file where cover discipline is deliberately absent.
const ASSAULT_URGENCY: float = 1.55
func _execute_assault(delta: float) -> void:
	_move_toward(assault_objective, delta, ASSAULT_URGENCY)


func _execute_idle(delta: float) -> void:
	if not patrol_route.is_empty():
		_execute_patrol(delta)
		return
	if work_pos != Vector3.ZERO and target == null and alert_tier <= AlertTier.SUSPICIOUS \
			and global_position.distance_to(work_pos) > 1.6:
		_move_toward(work_pos, delta)
		return
	velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
	velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)
	# Sentry scan: a standing guard sweeps his gaze, or an idle enemy facing the
	# wrong way is blind forever (perception is FOV-gated).
	if target == null and alert_tier <= AlertTier.SUSPICIOUS:
		_scan_phase += delta * SCAN_SPEED
		var base_yaw: float = atan2(_home_facing.x, _home_facing.z)
		var yaw: float = base_yaw + sin(_scan_phase) * SCAN_ARC
		facing_dir = Vector3(sin(yaw), 0.0, cos(yaw))


func _execute_alert(delta: float) -> void:
	# Search the breadcrumb trail - chase where they WENT, not the last pixel they
	# were seen at. Falls back to last-known when there is no squad / no trail.
	var goal_pos: Vector3 = last_known_target_pos
	if squad_id >= 0:
		# MY WEDGE OF THE NET: every man holds a stable sector and the ring grows with
		# time, so searchers sweep outward line-abreast instead of piling on one crumb.
		var hp := EnemySquad.hunt_point(squad_id, self, float(Time.get_ticks_msec()), _determination())
		if hp != Vector3.ZERO:
			goal_pos = hp
		else:
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

	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_direction = [-1.0, 0.0, 0.0, 1.0].pick_random()  # More likely to stop
		strafe_timer = randf_range(0.8, 2.0) * _tempo()

	if has_line_of_sight:
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
			accuracy_modifier = base_accuracy_modifier

		# Covered men HOLD their cover: damp the wander hard while has_cover
		# (this IS the engage-from-cover feel); drifting off invalidates it.
		if has_cover:
			if current_cover != Vector3.ZERO and global_position.distance_to(current_cover) > 2.5:
				_release_cover()
			else:
				move_dir *= 0.15

		if strafe_direction != 0.0:
			var strafe_vec := transform.basis.x * strafe_direction
			if has_cover:
				move_dir = move_dir + strafe_vec * 0.1  # micro-shuffle in place
			else:
				move_dir = (move_dir + strafe_vec * 0.4).normalized()
			accuracy_modifier *= 1.15

		move_dir += _separation * (0.2 if has_cover else 0.6)
		move_dir.y = 0
		if move_dir.length() > 0.1:
			velocity.x = lerpf(velocity.x, move_dir.x * move_speed * 0.5 * _suppression_move_mult(), delta * 8.0)
			velocity.z = lerpf(velocity.z, move_dir.z * move_speed * 0.5 * _suppression_move_mult(), delta * 8.0)
		else:
			velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)
			accuracy_modifier *= 0.8  # More accurate when still

		if can_fire and suppression_level < CombatPosture.SUPPRESS_FIRE_CEILING:
			if burst_count < MAX_BURST:
				_fire_at_target()
				burst_count += 1
			else:
				can_fire = false
				fire_timer = randf_range(0.4, 1.2) * _tempo()
				burst_count = 0
	else:
		# Target hiding behind cover - flush with a grenade. Hazard-rate roll (~1.7s
		# expected beat) + the squad/global broker: one grenade per AO/5s, per
		# squad/12s, per man/15s.
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
	velocity.x = lerpf(velocity.x, 0.0, delta * 10.0)
	velocity.z = lerpf(velocity.z, 0.0, delta * 10.0)

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
					# A dead end the player can HEAR. The counter existed and said nothing.
					if _cover_fail_count == 2:
						VOManager.play_enemy("retreat", self)

	# Concealment fallback: deep vegetation counts as soft cover.
	if not has_cover and not _moving_to_cover and _grid != null \
			and _grid.get_vegetation(global_position) > 0.6:
		has_cover = true
		current_cover = global_position
		return

	# No cover found (or already covered): duck-and-dodge perpendicular to threat.
	var to_target := (target.global_position - global_position).normalized()
	var perpendicular := Vector3(-to_target.z, 0, to_target.x)

	if strafe_direction == 0.0:
		strafe_direction = [-1.0, 1.0].pick_random()

	var move_dir := (perpendicular * strafe_direction - to_target * 0.3).normalized()
	velocity.x = move_dir.x * move_speed * _suppression_move_mult()
	velocity.z = move_dir.z * move_speed * _suppression_move_mult()


func _execute_flanking(_delta: float) -> void:
	if not target:
		return

	var to_target := (target.global_position - global_position).normalized()
	var perpendicular := Vector3(-to_target.z, 0, to_target.x)

	if strafe_direction == 0.0:
		strafe_direction = [-1.0, 1.0].pick_random()

	var move_dir := (perpendicular * strafe_direction * 0.7 + to_target * 0.5).normalized()
	velocity.x = move_dir.x * move_speed * _suppression_move_mult()
	velocity.z = move_dir.z * move_speed * _suppression_move_mult()

	if has_line_of_sight and can_fire and has_reacted:
		_fire_at_target()


## BOUNDING ADVANCE: rush cover-to-cover toward the target - sprint to a bound
## point, pause, burst, next bound. Two dry searches -> straight advance, slower.
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
			_bound_pause = randf_range(0.8, 1.6) * _tempo()
			return
		# Sprint the rush: full speed, honest fire penalty on the move. With the
		# numbers, 1.3x crosses the sprint-clip animation band.
		_move_toward(_bound_point, delta, 1.3 if _last_force_ratio >= 2.0 else 1.0)
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
				if _bound_fail_count == 2:
					VOManager.play_enemy("retreat", self)
		velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)
		if has_line_of_sight and can_fire and has_reacted and burst_count < 3:
			_fire_at_target()
			burst_count += 1
		return

	# Fallback: straight advance, slower - crossing open ground for real.
	var perpendicular := Vector3(-to_target.z, 0, to_target.x) * strafe_direction * 0.2
	var move_dir := (to_target + perpendicular).normalized()

	velocity.x = move_dir.x * move_speed * 0.85 * _suppression_move_mult()
	velocity.z = move_dir.z * move_speed * 0.85 * _suppression_move_mult()

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
	# known threat instead of freezing.
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
	# Fleeing men read the wall, not the map: the bearing starts pure-away, and wall
	# contact slides it along the surface (dead-square hits pick the tangent away).
	if _retreat_bearing == Vector3.ZERO:
		_retreat_bearing = away_from_target
	_retreat_bearing = _retreat_bearing.slerp(away_from_target, minf(delta * 0.6, 1.0)).normalized()
	if is_on_wall():
		var n: Vector3 = get_wall_normal()
		var slid: Vector3 = _retreat_bearing - n * _retreat_bearing.dot(n)
		slid.y = 0.0
		if slid.length() > 0.15:
			_retreat_bearing = slid.normalized()
		else:
			var t: Vector3 = n.cross(Vector3.UP).normalized()
			_retreat_bearing = t if t.dot(away_from_target) >= 0.0 else -t
	# A ROUTED man (no target) FLEES - 1.25x crosses the sprint-clip band. Tactical
	# withdrawal (still has a target) keeps the wary pace.
	var flee_speed: float = move_speed * (1.25 if target == null else 1.0) * _suppression_move_mult()
	velocity.x = _retreat_bearing.x * flee_speed
	velocity.z = _retreat_bearing.z * flee_speed


func _change_state(new_state: Enums.AIState) -> void:
	if new_state == current_state:
		return
	current_state = new_state


## Routed through NavBaker's per-site navmesh so pursuers path around obstacles.
func _move_toward(pos: Vector3, delta: float, speed_mult: float = 1.0) -> void:
	var direction: Vector3 = _router.step(global_position, pos)
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		facing_dir = direction  # eyes follow movement (perception FOV)
	var suppress_mult: float = _suppression_move_mult()
	velocity.x = lerpf(velocity.x, direction.x * move_speed * speed_mult * suppress_mult, delta * 8.0)
	velocity.z = lerpf(velocity.z, direction.z * move_speed * speed_mult * suppress_mult, delta * 8.0)


## 0-1 suppression multiplier. Light suppression (below 0.5) is only a slight
## pace cut; heavy suppression pins men to a crawl or freezes them in place.
## This makes automatic fire matter: pinning an enemy keeps him from sprinting
## to cover and forces him to return fire slowly from where he is.
func _suppression_move_mult() -> float:
	if suppression_level <= 0.0:
		return 1.0
	if suppression_level >= 0.85:
		return 0.05  # pinned: barely able to shift position
	if suppression_level >= 0.5:
		# 0.5 -> 0.4, 0.85 -> 0.05
		return lerpf(0.4, 0.05, (suppression_level - 0.5) / 0.35)
	# 0.0 -> 1.0, 0.5 -> 0.4
	return lerpf(1.0, 0.4, suppression_level / 0.5)


## ---------- COVER ----------

static func _cover_key(pos: Vector3) -> Vector3i:
	return Vector3i(roundi(pos.x / COVER_CELL), roundi(pos.y / COVER_CELL), roundi(pos.z / COVER_CELL))


## Crowding cost for DISPERSION: claimed points within 4m make a candidate
## expensive. Distance math only, zero raycasts. Allies share this broker too.
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
	var holder: Node = existing.get("enemy")
	if holder != null and is_instance_valid(holder) and holder != claimant \
			and not (holder.has_method("is_dead") and holder.is_dead()):
		return false
	_cover_claims[key] = {"enemy": claimant}
	return true


func _release_cover() -> void:
	var was_covered: bool = has_cover
	if current_cover != Vector3.ZERO:
		var key := EnemyBase._cover_key(current_cover)
		if EnemyBase._cover_claims.get(key, {}).get("enemy") == self:
			EnemyBase._cover_claims.erase(key)
	has_cover = false
	_moving_to_cover = false
	# Cover-exit stand-up (B3): only a living man who actually held cover. Death
	# paths also route through here - a corpse must not stand up. Debounced.
	if was_covered and current_state != Enums.AIState.DEAD and not is_downed:
		var now: float = float(Time.get_ticks_msec())
		if now - _last_cover_exit_ms > COVER_EXIT_DEBOUNCE_MS and sprite_actor is ModelActor:
			var l: float = (sprite_actor as ModelActor).clip_length("cover_to_stand")
			_cover_exit_until_ms = now + (l if l > 0.0 else 0.8) * 1000.0
			_last_cover_exit_ms = now


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
		var origin: Vector3 = candidate + Vector3.UP * 1.3
		var query := PhysicsRayQueryParameters3D.create(
			origin, threat_pos + Vector3.UP * 1.0, 1 | 32)
		query.exclude = [self]
		CombatManager.rays_cover += 1
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit and (hit.position as Vector3).distance_to(origin) <= COVER_BLOCKER_MAX_M:
			candidates.append(candidate)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return global_position.distance_to(a) + EnemyBase._crowding_cost(a) \
			< global_position.distance_to(b) + EnemyBase._crowding_cost(b))
	for c in candidates:
		if EnemyBase._claim_cover(c, self):
			return c
	return Vector3.ZERO


## Sample nearby points that block line-of-sight to the threat; claim the
## closest unclaimed one. Live raycasts against world geometry, no authored markers.
func _find_cover_point() -> Vector3:
	var threat_pos: Vector3 = last_known_target_pos if last_known_target_pos != Vector3.ZERO else global_position
	var space_state := get_world_3d().direct_space_state
	var candidates: Array[Vector3] = []
	for off in COVER_SEARCH_OFFSETS:
		var candidate: Vector3 = global_position + off
		var origin: Vector3 = candidate + Vector3.UP * 1.3
		var query := PhysicsRayQueryParameters3D.create(
			origin, threat_pos + Vector3.UP * 1.0, 1 | 32)
		query.exclude = [self]
		CombatManager.rays_cover += 1
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit and (hit.position as Vector3).distance_to(origin) <= COVER_BLOCKER_MAX_M:
			candidates.append(candidate)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return global_position.distance_to(a) + EnemyBase._crowding_cost(a) \
			< global_position.distance_to(b) + EnemyBase._crowding_cost(b))
	for c in candidates:
		if EnemyBase._claim_cover(c, self):
			return c
	return Vector3.ZERO


## ---------- PATROL ----------

## Zig-zag by construction: order the anchors by bearing around their centroid, then
## walk them as a STAR POLYGON (step ~n/2, coprime with n so every node is visited
## exactly once). Consecutive legs therefore cross the middle of the AO instead of
## tracing a tidy convex ring. Deterministic from the caller's rng (ADR-010).
static func make_patrol_circuit(anchors: Array[Vector3], rng: RandomNumberGenerator, count: int = 7) -> Array[Vector3]:
	var pool: Array[Vector3] = anchors.duplicate()
	if pool.size() < 3:
		return pool
	# Sample without replacement.
	var n: int = clampi(count, 5, mini(10, pool.size()))
	var picked: Array[Vector3] = []
	for i in range(n):
		picked.append(pool.pop_at(rng.randi() % pool.size()))

	# Order by bearing around the centroid.
	var c := Vector3.ZERO
	for v in picked:
		c += v
	c /= float(n)
	picked.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2(a.x - c.x, a.z - c.z) < atan2(b.x - c.x, b.z - c.z))

	# Star step: the biggest stride under n/2 that is coprime with n. gcd == 1 is what
	# guarantees the walk touches every node instead of closing early on a sub-loop.
	var step: int = 1
	@warning_ignore("integer_division")
	for k in range(int(n / 2), 1, -1):
		if _coprime(k, n):
			step = k
			break
	var route: Array[Vector3] = []
	var idx: int = 0
	for i in range(n):
		route.append(picked[idx])
		idx = (idx + step) % n
	return route


static func _coprime(a: int, b: int) -> bool:
	while b != 0:
		var t: int = b
		b = a % b
		a = t
	return a == 1


## Loop of waypoints around a center; deterministic per the caller's rng so
## mission sims stay reproducible. LOCAL loop - a sentry beat, not a patrol.
## For a real patrol across the AO use make_patrol_circuit().
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
	# The point man walks the waypoint; everyone else trails him down the leg.
	# Offsets are in the frame of the CURRENT LEG, so the column bends round corners.
	if patrol_file_slot > 0 and patrol_route.size() > 1:
		var prev: Vector3 = patrol_route[(_patrol_index - 1 + patrol_route.size()) % patrol_route.size()]
		var leg: Vector3 = wp - prev
		leg.y = 0.0
		if leg.length() > 0.5:
			var fwd: Vector3 = leg.normalized()
			var right: Vector3 = fwd.cross(Vector3.UP).normalized()
			var side: float = 1.0 if (patrol_file_slot % 2) == 1 else -1.0
			wp = wp - fwd * (FILE_SPACING * float(patrol_file_slot)) 				+ right * (side * FILE_STAGGER)
	if global_position.distance_to(wp) < 2.5:
		# Only the POINT MAN advances the waypoint, or the tail would flip the index
		# the moment it reached its own trailing offset and the file would eat itself.
		if patrol_file_slot == 0:
			_patrol_index = (_patrol_index + 1) % patrol_route.size()
			_patrol_pause = randf_range(2.5, 6.0)  # sentry boredom: glance around, then move on
		else:
			velocity.x = lerpf(velocity.x, 0.0, delta * 5.0)
			velocity.z = lerpf(velocity.z, 0.0, delta * 5.0)
		return
	_move_toward(wp, delta, 0.5)


## ============================================
## COMBAT - Firing
## ============================================

## This man's launcher round, resolved once - never load() in the firing path.
func _projectile() -> ProjectileData:
	if _proj_cache != null:
		return _proj_cache
	if weapon_data == null or weapon_data.projectile_data_path.is_empty():
		return null
	_proj_cache = load(weapon_data.projectile_data_path) as ProjectileData
	return _proj_cache


func _fire_at_target() -> void:
	if silent_infiltrator:
		return  # the satchel is his weapon - a sapper never squeezes a trigger
	if not weapon_data or not target:
		return

	can_fire = false
	fire_timer = weapon_data.get_fire_delay()
	shots_fired += 1

	var moving: bool = Vector3(velocity.x, 0.0, velocity.z).length() > 0.5
	var exposure_t: float = clampf(target_visible_duration / maxf(d_exposure_ramp, 0.1), 0.0, 1.0)
	var pre_cap: float = AIMarksmanship.cone_spread_deg(
		weapon_data.base_spread, char_accuracy, shots_fired, moving,
		accuracy_modifier * _shot_pressure_mult())
	EnemySquad.report_firing(squad_id, self, float(Time.get_ticks_msec()))
	var final_aim: Vector3 = AIMarksmanship.aim_with_spread(
		current_aim_dir, pre_cap, _target_is_player(), exposure_t, not _first_shot_fired)
	if not _first_shot_fired:
		_first_shot_fired = true
		VOManager.play_enemy("open_fire", self)

	# HOLD-OVER: a trained man elevates for the range, or he shoots low past ~100m.
	if target != null and is_instance_valid(target):
		var t_dist: float = global_position.distance_to((target as Node3D).global_position)
		var hold: float = weapon_data.elevation_for(t_dist)
		# A LAUNCHER is not a rifle: the rocket carries its own (much weaker)
		# gravity, so laying it with rifle maths threw enemy rockets 8x too high.
		var pd: ProjectileData = _projectile()
		if pd != null:
			var ge: float = 9.8 * maxf(0.0, pd.gravity_scale)
			var pv: float = maxf(1.0, pd.speed)
			hold = (ge * t_dist) / (2.0 * pv * pv)
		var hold_up: Vector3 = final_aim.cross(Vector3.UP).normalized().cross(final_aim).normalized()
		final_aim = (final_aim + hold_up * tan(hold)).normalized()

	# Raycast from the gun muzzle, not center mass.
	var origin: Vector3 = get_muzzle_position(final_aim)

	# A weapon that names a ProjectileData fires a real travelling round instead of a
	# hitscan ray - the RPG-2 needs travel time, drop, a warhead and a smoke trail.
	if weapon_data != null and not weapon_data.projectile_data_path.is_empty():
		var pdata: ProjectileData = _projectile()
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
	# FULL-REALISM FRIENDLY FIRE: the ray sees EVERYONE - world, player, enemies,
	# both hurtbox layers. Muzzle discipline below keeps the AI off its own squad.
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

	# A hit is not a near-miss (that is damage, handled below).
	CombatManager.suppress_along_shot(origin, final_aim, self, result)

	# The round is a live BulletSystem bullet - muzzle spawn, gravity drop, travel
	# time, arrival damage/FX through the shared resolver. The tracer IS the bullet;
	# color and ratio come from WeaponData.
	var fx_origin: Vector3 = get_muzzle_visual(final_aim)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, origin, 1)
	GunFX.play_shot_3d(get_tree().current_scene, fx_origin, weapon_data)
	GunFX.muzzle_flash(get_tree().current_scene, fx_origin)
	_fired_until_ms = float(Time.get_ticks_msec()) + 350.0
	var show_tracer: bool = weapon_data.tracer_ratio > 0 \
		and (shots_fired % weapon_data.tracer_ratio) == 0
	# Rounds touch flesh ONLY through hitzone areas - the player's body layer (2) is
	# OUT of the mask on purpose: a capsule eats the hit before the zones inside it
	# and everything lands flat 1.0x.
	# Civilians (512) are IN: a stray round finds a villager the same way it finds
	# a soldier. The crossfire is real on every side of it.
	CombatManager.bullets.fire(weapon_data, self, origin, final_aim,
		1 | 32 | 64 | 512, [self], show_tracer)


## Telegraph shout, then lob a real grenade at the last-known position.
func _throw_grenade() -> void:
	grenades_left -= 1
	grenade_cooldown = 15.0
	EnemySquad.claim_grenade(squad_id, float(Time.get_ticks_msec()))
	# Telegraph: shout (noise event draws attention both ways) + floating text.
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1)
	VOManager.play_enemy("grenade", self)
	_warn_allies_of_grenade()
	var shout := Label3D.new()
	shout.text = "LUU DAN!"
	shout.font_size = 26
	shout.pixel_size = 0.005
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.modulate = Color(1.0, 0.6, 0.3)
	add_child(shout)
	shout.position = Vector3(0, 2.4, 0)
	get_tree().create_timer(1.2).timeout.connect(shout.queue_free)
	# The lob (1s windup) - the arm moves for exactly that window.
	_throw_until_ms = float(Time.get_ticks_msec()) + 1000.0
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


## The nearest friendly who can see the throw calls it. The telegraph is only a
## telegraph if somebody on the player's side reacts to it out loud.
func _warn_allies_of_grenade() -> void:
	var best: Node3D = null
	var best_d: float = 24.0
	for a in AgentRegistry.allies:
		var ally := a as AllyBase
		if ally == null or not is_instance_valid(ally) or ally.is_dead():
			continue
		var d: float = ally.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = ally
	if best != null:
		VOManager.play_squad("grenade", (best as AllyBase).member, best.global_position, true)


## Gun muzzle world position: shoulder height, pushed out along the aim with a
## right-hand offset.
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

## Region-resolved gore channel: BulletSystem feeds the struck Hitzone's REGION
## here (the zone STRING stays the 4-name law for damage/wound logic). One hit
## >= 45 takes the limb; works on corpses too.
func on_zone_hit(region: String, amount: int, dir: Vector3) -> void:
	if not _visual_is_model or sprite_actor == null:
		return
	var limb: String = HitzoneBuilder.base_region(region)
	if limb in ["ARM_L", "ARM_R", "LEG_L", "LEG_R"] \
			and amount >= GibSystem.LIMB_POP_HIT and not _removed.has(limb):
		if GibSystem.dismember(sprite_actor as ModelActor, limb, dir, get_tree().current_scene):
			_removed.append(limb)


func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null, zone: String = "BODY") -> int:
	if current_state == Enums.AIState.DEAD:
		return 0
	# FINISH verb: any further damage on a downed man is final.
	if is_downed:
		current_hp = 0
		_credit_killer(attacker)
		_die()
		return amount
	# Locational outcome: a headshot is a headshot.
	var raw_amount: int = amount  # pre-override weapon damage (head burst gate)
	if Hitzone.zone_name_is_fatal(zone):
		amount = current_hp + 999

	current_hp -= amount
	damage_taken_recently += amount
	damage_decay_timer = 0.0
	goal_timer = 99.0  # Class-A interrupt: getting HIT may always re-plan

	# Remember where it came from, and WHAT it found, so _die() can pick the fall.
	last_hit_zone = zone
	if attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		last_hit_dir = (global_position - (attacker as Node3D).global_position).normalized()
		# Honest attention: whoever is HURTING me outranks whoever is closest.
		if (attacker as Node).is_in_group("player") or (attacker as Node).is_in_group("allies"):
			_last_attacker = attacker as Node3D
			_last_attacker_ms = float(Time.get_ticks_msec())

	# GUT: devastating - immediate crawl + bleed-out. Untreated he dies in ~15-20s.
	if zone == "GUT" and current_hp > 0 and _gut_bleed_dps <= 0.0:
		_gut_bleed_dps = 4.0
		_become_crippled()
	# Badly shot men may go down crawling - slow, loud, drawing their buddies.
	if not is_crippled and current_hp > 0 and float(current_hp) < float(max_hp) / 4.0 and randf() < 0.35:
		_become_crippled()

	# Getting shot = instant COMBAT tier, but LOCALLY ONLY (witnessed=false): he
	# fights back without proving anything. Whether the AO learns is decided by
	# whether he LIVES (below), or by _die() -> _witness_check. THE WITNESS RULE.
	_set_tier(AlertTier.COMBAT, false)
	if attacker is Node3D:
		last_known_target_pos = (attacker as Node3D).global_position
		target_last_seen_time = 0.0

	if current_state == Enums.AIState.IDLE:
		if attacker is Node3D:
			target = attacker as Node3D
			last_known_target_pos = target.global_position
		current_goal = Enums.AIGoal.ENGAGE_TARGET
		_change_state(Enums.AIState.COMBAT)

	var suppress_amount: float = float(amount) / float(max_hp) * 0.5
	suppression_level = minf(1.0, suppression_level + suppress_amount)

	# Flinch: the trigger stalls AND the body yields. A man who only stalls reads
	# as a man who ignored the round.
	can_fire = false
	fire_timer = maxf(fire_timer, 0.25)
	if current_hp > 0 and sprite_actor != null and is_instance_valid(sprite_actor) \
			and sprite_actor.has_method("flinch"):
		sprite_actor.call("flinch", last_hit_dir,
			clampf(float(amount) / float(max_hp) * 2.0, 0.35, 1.0))

	# Pain-quota stagger: a solid hit (>= a third of max HP) that does not kill jolts
	# them into a brief SUPPRESSED stagger + a pain grunt.
	if current_hp > 0 and float(amount) >= float(max_hp) / 3.0:
		apply_stagger(1.0)
		# A man on his feet lurches; a man already crouched or crawling has nowhere
		# to fall, and the clip would launch him upright.
		if not _low_posture:
			_stumble_until_ms = float(Time.get_ticks_msec()) + 500.0
		NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 20.0)

	if current_hp <= 0:
		var overkill: int = -current_hp
		current_hp = 0
		# DOWN-NOT-DEAD: a barely-lethal hit can leave a man dying but not dead. Never
		# on headshots, explosives, or the surrendered. Overkill weights the roll: 35%
		# at zero margin, fading to 0 at 40+ overkill damage.
		if zone != "HEAD" and not is_surrendered \
				and _damage_type == Enums.DamageType.PHYSICAL:
			var down_chance: float = clampf(0.35 * (1.0 - float(overkill) / 40.0), 0.0, 0.35)
			if randf() < down_chance:
				_become_downed()
				# He is down but ALIVE - a witness. (THE WITNESS RULE)
				_stamp_contact()
				return amount
		# HEAD POP on heavy fatal headshots (>= HEAD_POP_KILL raw): burst 25% of the
		# time, one-piece pop otherwise. If the burst finds no head_frag_* donors it
		# returns false, so fall through to the one-piece pop - never a silent no-op.
		if zone == "HEAD" and _visual_is_model and raw_amount >= GibSystem.HEAD_POP_KILL:
			var burst: bool = (GibSystem.force_all_gibs or randf() < 0.25) and GibSystem.dismember_head_burst(sprite_actor as ModelActor, last_hit_dir, get_tree().current_scene)
			if burst or GibSystem.dismember(sprite_actor as ModelActor, "HEAD", last_hit_dir, get_tree().current_scene):
				_removed.append("HEAD")
		_killed_explosive = _damage_type == Enums.DamageType.EXPLOSIVE
		# MASSIVE TRAUMA: a single body-zone event >= 90 (point-blank buck; no rifle
		# chest hit reaches it, max 80) butchers like a blast.
		if not _killed_explosive and raw_amount >= 90 \
				and (zone == "BODY" or zone == "GUT" or zone == "TORSO"):
			_killed_explosive = true  # reuse the blast doctrine in _die()
		_credit_killer(attacker)
		_die()
	elif not is_surrendered:
		# HE LIVED: surviving your attack is what makes it WITNESSED. (ADR-005)
		_stamp_contact()
		# MORALE: courage-powered break ladder. Low-courage men (Local Force) BREAK
		# under pressure - rout, or throw the rifle down (Chieu Hoi). NVA courage holds.
		var courage: float = enemy_data.courage if enemy_data != null else 0.5
		var pressure: float = threat_level + (1.0 - float(current_hp) / float(max_hp)) * 0.5
		# Numbers stiffen the spine: a man with six friends up does not rout
		# off one shooter's pressure (capped so lone-man breaks stay intact).
		var nerve: float = clampf((_last_force_ratio - 1.0) * 0.15, 0.0, 0.35)
		if pressure > 0.7 + courage * 0.6 + nerve and randf() < 0.25:
			var living_nearby: int = 0
			for e in get_tree().get_nodes_in_group("enemies"):
				var other := e as EnemyBase
				if other != self and other and not other.is_dead() \
						and other.global_position.distance_to(global_position) < 30.0:
					living_nearby += 1
			if living_nearby == 0 and float(current_hp) < float(max_hp) / 3.0 and randf() < 0.4:
				try_surrender()  # alone, hurt, broken: hands up
			else:
				# ROUT: drop the fight and run for the rear.
				target = null
				contact_conf = 0.0
				_set_goal(Enums.AIGoal.RETREAT)
				goal_timer = -3.0  # committed flight - no re-plan for ~4s
				VOManager.play_enemy("retreat", self)

	return amount


## Learn-by-doing: credit the killing squadmate's Small Arms + tally his kill. Only
## allies learn by doing (ADR-032) - the player has no skills, so only nodes that
## carry a `member` dict are credited.
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


## Crawling, slow, loud - the shared "down but not out" state.
func _become_crippled() -> void:
	if is_crippled:
		return
	is_crippled = true
	move_speed *= 0.25
	base_accuracy_modifier *= 1.6
	if sprite_actor != null:
		sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_weapon), "crippled"))
	elif mesh:
		mesh.scale.y = 0.45
		mesh.position.y = -0.35
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 30.0)


## Limb hits degrade the man: arm = shaky aim, leg = slowed; a second leg wound
## puts him down crawling.
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
	var was: float = suppression_level
	suppression_level = minf(1.0, suppression_level
		+ amount * CombatPosture.suppress_accrual_mult(cover01()))
	if was <= CombatPosture.SUPPRESS_PIN and suppression_level > CombatPosture.SUPPRESS_PIN:
		pinned_since_ms = float(Time.get_ticks_msec())


## How covered this man is, 0 open -> 1 hard cover. A claimed rock outranks the ground;
## the ground still counts, so a man in heavy jungle is harder to pin than one in a paddy.
var _terrain_cover01: float = 0.0
var pinned_since_ms: float = 0.0

func cover01() -> float:
	return maxf(_terrain_cover01, 0.7 if has_cover else 0.0)


## PERSONAL TEMPO, 0.75-1.25 off the reaction trait. Relic's drift variable: a squad
## whose timers all fire together moves as one organism instead of as men.
func _tempo() -> float:
	return 0.75 + (1.0 - clampf(char_reaction, 0.0, 1.0)) * 0.5


## COMBAT SPACING. FILE_SPACING governs the patrol column only, so nothing kept men
## apart once the shooting started and squads bunched onto one rock. A light push that
## must never beat cover or a bound - it is added to move_dir, never substituted for it.
const COMBAT_SPACING_M: float = 3.0
var _separation: Vector3 = Vector3.ZERO

func _refresh_separation() -> void:
	var push: Vector3 = Vector3.ZERO
	var r2: float = COMBAT_SPACING_M * COMBAT_SPACING_M
	for man in AgentRegistry.enemies:
		if man == self or not is_instance_valid(man) or not man is Node3D:
			continue
		var other: Vector3 = (man as Node3D).global_position
		if global_position.distance_squared_to(other) > r2:
			continue
		var off: Vector3 = global_position - other
		off.y = 0.0
		var d: float = off.length()
		if d > 0.01:
			push += off / d * (1.0 - d / COMBAT_SPACING_M)
	_separation = push.limit_length(1.0)


## Cone multiplier from the pressure in the situation: his own suppression spoils his
## aim, and a target he has just pinned gets the mercy window.
func _shot_pressure_mult() -> float:
	var m: float = CombatPosture.suppress_spread_mult(suppression_level)
	if target != null and is_instance_valid(target) and "pinned_since_ms" in target:
		m *= CombatPosture.pin_mercy_mult(target.pinned_since_ms, float(Time.get_ticks_msec()))
	return m


func _refresh_terrain_cover() -> void:
	if _grid == null:
		return
	_terrain_cover01 = float(GameplayGrid.COVER_VALUES.get(
		_grid.get_terrain_type(global_position), 0.0))


func apply_stagger(power: float) -> void:
	if power >= 1.0 and current_state != Enums.AIState.DEAD:
		suppression_level = minf(1.0, suppression_level + 0.5)
		_change_state(Enums.AIState.SUPPRESSED)


## DOWN-NOT-DEAD: dying, not dead. IRON LAW: he never re-fights. Bleeds out in
## 45-90s unless SECURED; further damage = the FINISH verb.
var is_downed: bool = false
var _downed_bleed_s: float = 0.0
var _downed_fx_s: float = 0.0
var _died_emitted: bool = false

## ---------- COMBAT MEDIC (Summoner ruling 2026-07-29: enemy medics drag their
## wounded out of the combat zone - theater, not an enemy revive) ----------
## Downed men are unregistered from AgentRegistry, so medics find them here.
static var downed_pool: Array[EnemyBase] = []
var _aid_target: EnemyBase = null
var _drag_started: bool = false
var _drag_dest: Vector3 = Vector3.ZERO
var _aid_abort_s: float = 0.0
const DRAG_SPEED_MULT: float = 0.55
const MEDIC_SCAN_RANGE: float = 45.0
const DRAG_OUT_METERS: float = 14.0


func _medic_think() -> void:
	if _aid_target != null:
		if not is_instance_valid(_aid_target) or not _aid_target.is_downed:
			_reset_aid()
		return
	var best: EnemyBase = null
	var best_d: float = MEDIC_SCAN_RANGE
	for w in downed_pool:
		if not is_instance_valid(w) or w == self or not w.is_downed:
			continue
		if w.has_meta("dragged_out") or w.is_in_group("captured"):
			continue
		var d: float = global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	if best != null:
		_aid_target = best
		_drag_started = false
		_drag_dest = Vector3.ZERO
		_aid_abort_s = 30.0
		VOManager.play_enemy("man_down", self)


func _reset_aid() -> void:
	work_clip = ""  # release the haul pose or he carries an invisible man forever
	_aid_target = null
	_drag_started = false
	_drag_dest = Vector3.ZERO


func _execute_aid(delta: float) -> void:
	if not is_instance_valid(_aid_target) or not _aid_target.is_downed:
		_reset_aid()
		return
	_aid_abort_s -= delta
	if _aid_abort_s <= 0.0:
		_aid_target.set_meta("dragged_out", true)  # unreachable ground: stop re-trying
		_reset_aid()
		return
	if not _drag_started:
		if global_position.distance_to(_aid_target.global_position) > 1.6:
			_move_toward(_aid_target.global_position, delta, 1.1)
			return
		# The rear is AWAY from where he believes the threat is - never a peek
		# at the player's true position.
		var threat: Vector3 = last_known_target_pos
		if threat == Vector3.ZERO:
			threat = global_position + global_transform.basis.z
		var away: Vector3 = global_position - threat
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else -global_transform.basis.z
		_drag_dest = _aid_target.global_position + away * DRAG_OUT_METERS
		_drag_started = true
		# Both halves of the haul. The casualty is is_downed, so _update_sprite has
		# already returned on his latched pose - his clip must be set HERE, once.
		work_clip = "carry_wounded"
		if _aid_target.sprite_actor is ModelActor:
			(_aid_target.sprite_actor as ModelActor).play("being_carried", true)
		return
	# Dragging: slow haul, the casualty trails a body-length behind.
	var to_dest: Vector3 = _drag_dest - global_position
	to_dest.y = 0.0
	if to_dest.length() <= 1.2:
		_aid_target.set_meta("dragged_out", true)
		_reset_aid()
		return
	_move_toward(_drag_dest, delta, DRAG_SPEED_MULT)
	var trail: Vector3 = global_position - to_dest.normalized() * 1.1
	trail.y = _aid_target.global_position.y
	_aid_target.global_position = _aid_target.global_position.lerp(trail, minf(1.0, 8.0 * delta))


func _become_downed() -> void:
	is_downed = true
	downed_pool.append(self)
	EnemySquad.release_hot(self)  # out of the fight: free the hot slot for a live man
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
	AgentRegistry.unregister(self)
	if not _died_emitted:
		_died_emitted = true
		died.emit(self)
	if sprite_actor != null and sprite_actor is ModelActor:
		var ma := sprite_actor as ModelActor
		# A DOWNED man must be ON THE GROUND. Fallback ladder: breathless clip ->
		# freeze at a death clip's end (a lying pose) -> gentle ragdoll.
		if ma.play("laying_breathless", true):
			# The clip lies him down 1m OFF THE FLOOR (Blender re-export pending): pin
			# the pose to the ground once the skeleton lands it.
			get_tree().create_timer(0.15).timeout.connect(func() -> void:
				if is_instance_valid(ma) and is_downed:
					ma.ground_current_pose())
		else:
			var posed: bool = false
			for c in ma.clip_names():
				if String(c).begins_with("death"):
					posed = ma.pose_end_of(String(c))
					break
			if not posed:
				ma.start_ragdoll(last_hit_dir, 1.5)
	elif sprite_actor != null:
		sprite_actor.play(SpriteStateMap.clip_for(false, str(enemy_data.sprite_weapon), "crippled"))
	VOManager.play_enemy("man_down", self, true)


## SECURE verb: stabilize + capture a downed man (same economy as surrender).
func secure() -> bool:
	# NOTE: is_dead() is true while downed (by design) - check the real state.
	if not is_downed or current_state == Enums.AIState.DEAD:
		return false
	_downed_bleed_s = 9e9
	add_to_group("surrendered")
	add_to_group("captured")
	return true


func _die() -> void:
	downed_pool.erase(self)
	# THE WITNESS RULE: did anyone actually SEE this happen? If not, the AO learns
	# nothing and this body becomes a liability instead. (ADR-005)
	var killer: Node = null
	if is_instance_valid(_last_attacker):
		killer = _last_attacker
	EnemySquad.release_hot(self)  # a dead man holds no hot slot - promote a live one
	if not is_downed:
		VOManager.play_enemy("man_down", self, true)  # downed men already cried out
	_witness_check(killer)
	GunFX.blood_pool(get_tree().current_scene, global_position)
	_change_state(Enums.AIState.DEAD)
	_release_cover()
	AgentRegistry.unregister(self)
	if not _died_emitted:
		_died_emitted = true
		died.emit(self)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if is_downed:
		# He was already lying in laying_breathless - do not whip a standing death clip
		# over the pose. Insure the ground with a gentle ragdoll.
		is_downed = false
		var mad := sprite_actor as ModelActor
		if _visual_is_model and mad != null and not mad.has_ragdoll():
			mad.start_ragdoll(last_hit_dir, 1.5)
		add_to_group("lootable_corpses")
		_drop_carried_weapon()
		get_tree().create_timer(45.0).timeout.connect(queue_free)
		return

	if sprite_actor != null:
		# GORE_WORKFLOW death doctrine (ONE authority with the gore dummy):
		#   explosion kill -> multi-gib + ragdoll flung by the blast
		#   clean kill     -> RAGDOLL always (dead weight just drops)
		#   gibbed kill    -> the death performance clip (fallback: ragdoll)
		var ma := sprite_actor as ModelActor
		# `handled` means THE BODY IS ON ITS WAY DOWN. A gib pass that fails to start a
		# ragdoll takes the limbs off and leaves the torso hanging in its last pose - the
		# floating corpse - because the gore branch never reported back and the death-clip
		# fallback below was an `else` it could not reach.
		var handled: bool = false
		# A NAMED DEATH OUTRANKS THE RAGDOLL. A clean kill normally drops as dead weight,
		# and that branch would swallow a knife takedown before its performance ever ran -
		# so an authored death (brutal_assassination) is tried before anything else.
		var named: bool = death_clip_override != "" and _visual_is_model and ma != null \
			and _removed.is_empty()
		if (_killed_explosive or GibSystem.force_all_gibs) and _visual_is_model and ma != null:
			handled = GibSystem.explosion_kill(ma, _removed, last_hit_dir, get_tree().current_scene)
		elif not named and _visual_is_model and ma != null and _removed.is_empty() \
				and ma.start_ragdoll(last_hit_dir, 4.5):
			handled = true  # dead weight dropped - the ragdoll owns the body now
		if not handled:
			# last_hit_dir is the bullet's TRAVEL direction (attacker -> us), so
			# the shooter lies along -last_hit_dir.
			var to_attacker: Vector3 = -last_hit_dir
			var intent: String = SpriteStateMap.death_intent(to_attacker, global_transform.basis,
				Hitzone.zone_name_is_fatal(last_hit_zone))
			# A man who died LOW dies low: the authored crouch death outranks the
			# standing picks. Rigs without the clip fall through to them.
			var played: Variant = false
			if death_clip_override != "" and _visual_is_model and ma != null:
				played = ma.play(death_clip_override, true)
			if played is bool and not played and _low_posture and _visual_is_model and ma != null:
				played = ma.play("death_crouching_headshot_front", true)
			if played is bool and not played:
				played = sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_weapon), intent), true)
			# DEAD MEN FALL, whatever the export shipped: mapped clip -> any death clip
			# in the library -> ragdoll.
			if played is bool and not played and _visual_is_model and ma != null:
				if not ma.play_any_death() and not ma.start_ragdoll(last_hit_dir, 4.5):
					push_warning("[ENEMY] %s: no death clip AND no ragdoll slot - corpse froze standing" % name)
		# GUARANTEED FLOOR (stuck-stagger fix): if the body never ragdolled, snap it flat so
		# a janky/latched death clip cannot leave it standing or mid-stagger. This sat
		# INSIDE the fallback, so it covered clean kills and never explosive ones - the
		# exact deaths most likely to strand a torso in the air.
		if _visual_is_model and ma != null:
			var mac: ModelActor = ma
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if is_instance_valid(mac) and not mac.has_ragdoll():
					mac.settle_flat_corpse())
	elif mesh:
		mesh.rotation_degrees.x = 90

	add_to_group("lootable_corpses")
	_drop_carried_weapon()
	get_tree().create_timer(45.0).timeout.connect(queue_free)


## A dead man's rifle falls where he does. The corpse recycles at 45 s; the weapon keeps
## its own longer clock, so the gun outlives the body and is still there when you come
## back for it. Bodies themselves yield only intel (Summoner, 2026-07-30) - this is where
## an enemy weapon actually enters the player's hands.
func _drop_carried_weapon() -> void:
	if weapon_data == null or has_meta("weapon_dropped"):
		return
	set_meta("weapon_dropped", true)
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var at: Vector3 = global_position
	at.y += 0.08      # clear of the ground plane, not sunk into it
	WorldWeapon.drop(host, weapon_data, at, 0, 1, true)


## Broken men throw their hands up. Interact to capture (intel).
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
		sprite_actor.play(SpriteStateMap.clip_for(_visual_is_model, str(enemy_data.sprite_weapon), "surrender"), true)
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


## Is the current target the human player? Gates the Fairness-Law fire profile (near-miss +
## exposure ramp) and, by its negation, the AI-vs-AI firefight widen. Allies are never the player.
func _target_is_player() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target == GameManager.player or target.is_in_group("player")


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
	enemy.reset_physics_interpolation()

	return enemy


