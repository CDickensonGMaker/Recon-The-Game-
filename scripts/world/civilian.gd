## civilian.gd - Village noncombatant: wanders, flees gunfire, cowers.
## An informer who escapes after seeing you raises the alarm.
##
## Civilians are killable and there is NO consequence system behind it today -
## no debrief cost, no war reaction. `_record_noncombatant_death()` is the single
## hook a future ROE/war-crime ledger attaches to; it is called on every
## noncombatant death and is intentionally empty.
class_name Civilian
extends CharacterBody3D

const BTSelectorS := preload("res://scripts/ai/bt/bt_selector.gd")
const BTNodeS := preload("res://scripts/ai/bt/bt_node.gd")
const BTActionS := preload("res://scripts/ai/bt/bt_action.gd")
const CivilianSchedulesS := preload("res://scripts/ai/civilian_schedules.gd")
const GunCrewPerformanceS := preload("res://scripts/world/gun_crew_performance.gd")

enum CivState { WANDER, FLEE, COWER, GONE }

## Layer 10. Its own layer, in the PLAYER's fire masks only - AI strays pass
## through villagers. Widening it to the AI masks changes who gets shot and is a
## Summoner call, not a silent one.
const CIVILIAN_HURTBOX_LAYER: int = 512

var state: CivState = CivState.WANDER
var home: Vector3
var is_informer: bool = false
var director: FieldDirector
var _hp: int = 20
var _wander_target: Vector3
var _saw_player_at: Vector3 = Vector3.ZERO
var _inform_clock: float = -1.0
var actor: ModelActor = null
var _last_clip: String = ""
## Per-villager unarmed idle, picked deterministically at spawn so a village is a
## crowd of individuals and not four copies of one pose (ADR-010: same seed, same ville).
var _idle_variant: String = "idle_unarmed_2"
## The same spawn hash _idle_variant is drawn from, kept so other per-man picks
## (the off-duty chain) vary with the man instead of all landing on one clip.
var _idle_seed: int = 0
## Latched when a diner has played his sit-down beat; cleared when he walks again.
var _chow_seated: bool = false
## Length of chow_sit_down, measured off anim_library.glb (25 keys @ 30fps).
const CHOW_SIT_S: float = 0.83

## Travelling actions a household walks together. Stationary actions (work,
## cook, sleep) are done side by side at home, not in formation.
const GROUP_WALK_ACTIONS: Array[StringName] = [
	&"walk_home", &"walk_paddy", &"walk_fire", &"walk_market",
]
const GROUP_WALK_SPEED: float = 1.3

const IDLE_VARIANTS: Array[String] = [
	"idle_unarmed_2", "idle_unarmed_3", "idle_unarmed_4", "idle_unarmed_5",
]

## What a villager DOES at a scheduled action, as opposed to what shape he is in.
## Every chain is rotated per man by _rotate(): a hamlet of sixteen used to sleep in
## one pose, talk in one pose and work in one pose, because play_first() takes the
## head of the chain and every villager was handed the same chain.
##
## NO ARMED CLIP MAY ENTER THESE. `idle` and `idle_crouching` are the rifleman idle
## and the rifleman weapon crouch - either at a head and the whole village stands
## and squats like a firing line. A missing clip must degrade to a T-pose, which is
## loud, rather than to a weapon pose, which is quiet and wrong.
const VILLAGE_ACTION_CLIPS: Dictionary = {
	&"sleep": ["sleeping_laying", "sleeping_sitting", "sitting"],
	# NO AMERICAN SOCIAL CLIPS ON VILLAGERS (his ruling, 2026-07-31: "keep for US only,
	# never VC or villagers"). sitting_talking and telling_secret are modern open-palm
	# gesturing; on a village elder they read as a man in costume.
	&"talk": ["standing_talking", "sitting_idle_b", "sitting"],
	&"work": ["plant_seeds", "digging", "idle_unarmed_3"],
	&"rest": ["sitting_idle_c", "sitting_drinking", "sitting"],
	&"sit": ["sitting_idle_b", "sitting_idle_c", "sitting"],
}

## Off-duty men had ONE chain, and play_first() takes the head of it whenever the
## rig carries it - so every off-duty man in the compound smoked, forever, together.
## Six of the seventeen curated garrison are off_duty, plus every unmapped work post.
const OFF_DUTY_CHAINS: Array = [
	["smoking", "sitting_drinking", "idle_unarmed_5"],
	["sitting_drinking", "drinking", "sitting_idle_c", "idle_unarmed_5"],
	["sitting_talking", "standing_talking", "sitting_idle_b", "idle_unarmed_4"],
	["neck_stretch", "arm_stretch", "idle_unarmed_3"],
	["jumping_jacks", "neck_stretch", "arm_stretch", "idle_unarmed_3"],
	["sitting_idle_c", "sitting_idle_b", "sitting", "idle_unarmed_5"],
	["standing_talking", "telling_secret", "idle_unarmed_2"],
	# The American social set, US-ONLY by his 2026-07-31 ruling. These are the last three
	# clips of the Mixamo wave with no caller anywhere; off-duty GIs are the one cast they
	# were ever going to read on.
	["standing_arguing", "telling_secret", "standing_talking", "idle_unarmed_2"],
	["briefing_group", "standing_talking", "sitting_idle_b", "idle_unarmed_4"],
]

# L1 behavior-tree fields. active_action is the BT's current pick; state
# remains the reactive override (FLEE/COWER/GONE) which wins regardless.
var occupation: String = "farmer"
## A US garrison man inside the wire: same schedule machinery, US model, armed
## idle chains. A SOLDIER, not a noncombatant (Summoner ruling 2026-08-04): enemy
## fire on the wire stands him to via GarrisonDefender.promote. Never the player's
## squad.
var is_garrison: bool = false
## The village this man belongs to. Written at build time so a panicking villager
## can name his own hamlet without a radius scan guessing at it.
var village_center: Vector3 = Vector3.ZERO
var active_action: StringName = &"idle"
var working_point: NodePath = NodePath()
var working_point_pos: Vector3 = Vector3.ZERO
## The work_* marker type this man was seated on ("cook", "mess", "dig"...). Finer
## than occupation, which collapses several markers onto one schedule. Empty for
## curated posts and villagers.
var role: String = ""
## Group id: civilians with the same id walk as one group. -1 = solo.
var group_id: int = -1
## Where THIS civilian walks while grouped: the destination if lead, else a
## formation slot. Written by GroupWalk, consumed by _step_toward.
var group_destination: Vector3 = Vector3.ZERO
## The household's members, self included. Assigned at spawn.
var group_members: Array = []
## Is this civilian the LEAD of their group? The lead picks the path; followers slot.
var is_group_lead: bool = false
## Boarding latch (SeatSystem.board_squad). While set, the man walks here instead of
## ticking his schedule; SeatSystem clears it when it seats him or the ship gives up.
var board_target: Vector3 = Vector3.ZERO
const BOARD_WALK_SPEED: float = 1.8
## PUPPET. This body is inside a scripted performance (LitterTeam) and its driver
## owns position AND clip. The BT, the schedule and _animate() all stand down: an
## unlatched body re-issues its own pose and the casualty sits up on the stretcher.
var puppet: bool = false
## The staged crew driving this body (gun_crew_performance.gd). Null for every
## other puppet. GarrisonDefender.promote releases through it at stand-to, so a
## crewman fights while a litter bearer (no driver ref) stays guarded.
var crew_driver: Node3D = null
var _bt_bb: Dictionary = {}
## Behavior tree root. Typed as RefCounted to avoid class_name lookup hazards;
## BTSelector/BTAction are duck-typed at runtime via .tick().
var _bt: RefCounted = null
var _router := NavRouter.new()
var _box_timer: float = 0.0

## Stuck watchdog (mirrors EnemyBase): trying to move but pinned -> sidestep.
## Threshold sits below IDLE_SPEED (0.8) - civilians amble where soldiers run.
const UNSTICK_WANTS_MOVE: float = 0.5
const UNSTICK_SPEED: float = 1.6
var _stuck_pos: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _unstick_t: float = 0.0
var _unstick_dir: float = 1.0
var _unstick_flips: int = 0

func _update_unstick(delta: float) -> void:
	if _unstick_t > 0.0:
		_unstick_t -= delta
		var side := global_transform.basis.x * _unstick_dir
		velocity.x = side.x * UNSTICK_SPEED
		velocity.z = side.z * UNSTICK_SPEED
		return
	_stuck_t += delta
	if _stuck_t >= 1.0:
		var wants_move: bool = Vector2(velocity.x, velocity.z).length() > UNSTICK_WANTS_MOVE
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

# L1 LOD. 3 tiers matching enemy_base.gd:39-54. Hysteresis band (5m) prevents
# a civilian at a tier boundary from flapping between tiers every 2 seconds.
const LOD_FULL: int = 0
const LOD_NEAR: int = 1
const LOD_FAR: int = 2
const LOD_NEAR_RADIUS: float = 80.0
const LOD_FAR_RADIUS: float = 300.0
const LOD_HYSTERESIS: float = 5.0
var lod_tier: int = LOD_FULL
## Cleared until the body has been stood at its scheduled position once.
var _placed_for_hour: bool = false
var _lod_timer: float = 0.0
const LOD_RECOMPUTE_S: float = 2.0

## Resolved to a .glb by ModelActor.model_path() - never build the path here.
const VILLAGERS: Array[String] = [
	"civ_farmer_m", "civ_farmer_m_b", "civ_farmer_m_c",
	"civ_farmer_f", "civ_farmer_f_b", "civ_farmer_f_c",
	"civ_elder", "civ_elder_b",
	"civ_kid", "civ_kid_b",
]


## US firebase garrison models. Resolved by bare unit_id like VILLAGERS.
## Occupations whose WORK is standing a post with a weapon up, not stooping over
## a job. Drives the armed idle chain.
const ARMED_POSTS: Array[String] = ["sentry", "sentry_night", "gun_crew", "radioman"]

const GARRISON_MEN: Array[String] = [
	"us_grunt_rifleman", "us_grunt_pointman", "us_medic",
	"us_grunt_mg", "us_grunt_grenadier", "us_grunt_marksman", "us_grunt_rto",
]

## A few posts are a SPECIFIC man, not a body off the pool. The medical station is
## staffed by the surgeon - a rifleman bent over a cot reads as a guard, not a doctor -
## and the aircrew fly the ship. Everything not named here draws from GARRISON_MEN.
const OCCUPATION_MODELS: Dictionary = {
	"medic": ["us_surgeon"],
}

## Aircrew: the two pilots, and the two door gunners on a gun-orbit ship
## (AirTraffic._crew_gunners). Four crew berths in SeatSystem.SEAT_NAMES.
const AIRCREW: Array[String] = ["us_pilot_white", "us_pilot_black"]


## Bodies allowed to stand a given post. Keeps the special-casing in one place so a
## caller cannot quietly staff the aid station with whoever the pool rolled.
static func models_for(occupation: String) -> Array[String]:
	var got: Array = OCCUPATION_MODELS.get(occupation, []) as Array
	if got.is_empty():
		return GARRISON_MEN
	var out: Array[String] = []
	for m in got:
		out.append(String(m))
	return out


static func spawn(parent: Node, pos: Vector3, mission_director: FieldDirector, informer: bool,
		models: Array[String] = VILLAGERS, garrison: bool = false) -> Civilian:
	SpawnLedger.note("Civilian.spawn")
	var civ := Civilian.new()
	civ.director = mission_director
	civ.is_informer = informer
	civ.is_garrison = garrison
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	civ.add_child(col)
	# THE SHARED ROUTING PATH (ADR-023). nav_router.gd's own header records that allies once
	# "steered straight into walls for want of this" - and the Civilian never got it. So the
	# firebase garrison, 21 men whose whole behaviour is walking between quarters, post and
	# work point, had no way to get around a hootch: _step_toward is a straight line. They
	# have had schedules and working points the entire time and no legs to execute them.
	if WorldConfig.NAV_ENABLED:
		var nav := NavigationAgent3D.new()
		nav.name = "NavigationAgent3D"
		# INVARIANT: must match NavBaker's agent metrics, or he walks corridors nothing carved.
		nav.radius = NavBaker.AGENT_RADIUS
		nav.height = NavBaker.AGENT_HEIGHT
		nav.path_desired_distance = 0.7
		nav.target_desired_distance = 1.0
		nav.path_max_distance = 5.0
		nav.avoidance_enabled = false
		civ.add_child(nav)
	# A PERSON, not a pill. Deterministic per position so the same village rebuilds
	# with the same faces (ADR-010/017 - the province must come back identical).
	var seed_h: int = absi(hash(Vector2i(int(pos.x), int(pos.z))))
	var pick: int = seed_h % models.size()
	@warning_ignore("integer_division")
	civ._idle_variant = IDLE_VARIANTS[(seed_h / 7) % IDLE_VARIANTS.size()]
	civ._idle_seed = seed_h
	var model_actor := ModelActor.new()
	civ.add_child(model_actor)
	if model_actor.setup(models[pick]):
		civ.actor = model_actor
	else:
		# The model is missing. Fall back to the old pill rather than an invisible
		# man - but say so LOUDLY, because a silent fallback is how a village full
		# of capsules survives for weeks without anyone noticing.
		push_warning("[Civilian] no model for '%s' - falling back to a CAPSULE. The village will look like pills." % models[pick])
		model_actor.queue_free()
		var mesh := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.6
		mesh.mesh = cm
		mesh.position = Vector3(0, 0.8, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.45, 0.3)
		mesh.material_override = mat
		civ.add_child(mesh)
	civ.collision_layer = 2
	civ.collision_mask = 1
	# Rounds touch flesh ONLY through hitzone areas - the body capsule is out of
	# every fire mask, so a capsule can never shadow the zones inside it.
	# Static bands, not skeleton hulls: a populated AO carries 16-40 civilians and
	# 11 bone-synced convex hulls each is ~6.4ms/frame of hitzone sync.
	HitzoneBuilder._build_static(civ, CIVILIAN_HURTBOX_LAYER, 0,
		["civilian_hurtbox", "hitzone"], true)
	parent.add_child(civ)
	civ.global_position = pos
	# DRESS THE GARRISON. GARRISON_MEN are us_grunt_* bodies, every one of them dressable, and
	# this call was simply never here: the firebase's 21 men ran ModelActor.setup and stopped.
	# So they wore the welded stock pot - one white helmet, no face variation, twenty-one
	# identical men - while fifteen authored helmet variants sat unused on disk. AllyBase does
	# this in dress_visual(); the Civilian is the same body under a different script.
	# Dressed AFTER add_child: the helmet swap reads where the stock helmet RENDERS, which
	# needs the actor in the tree.
	if GruntRandomizer.is_dressable(models[pick]):
		var drng := RandomNumberGenerator.new()
		drng.seed = seed_h            # deterministic per position (ADR-010: same seed, same men)
		GruntRandomizer.dress_actor(model_actor, drng)
	civ.home = pos
	civ._wander_target = pos
	civ.add_to_group("civilians")
	# After add_child: setup() reads the tree for a lab navmesh.
	civ._router.setup(civ.get_node_or_null("NavigationAgent3D") as NavigationAgent3D,
		civ.get_tree(), "garrison" if garrison else "civilian")
	AgentRegistry.register(civ, AgentRegistry.Kind.CIVILIAN)
	NoiseBus.noise_emitted.connect(civ._on_noise)
	return civ


func _exit_tree() -> void:
	AgentRegistry.unregister(self)


func _on_noise(type: int, noise_pos: Vector3, radius: float, team: int) -> void:
	if state == CivState.GONE:
		return
	if is_garrison:
		# A soldier answers audible ENEMY fire (audibility = the emitted radius).
		# Friendly noise never stands the base to, and the director gates on the
		# noise being AT the wire - a fight raging 300m out is the AO's business,
		# or camp life dies to every ambient contact. One promote path (ADR-023).
		if (type == NoiseBus.NoiseType.GUNSHOT or type == NoiseBus.NoiseType.EXPLOSION) \
				and team != 0 and director != null \
				and global_position.distance_to(noise_pos) <= radius:
			director.garrison_alarm(noise_pos)
		return
	if type == NoiseBus.NoiseType.GUNSHOT or type == NoiseBus.NoiseType.EXPLOSION:
		if global_position.distance_to(noise_pos) < 60.0:
			var was_calm: bool = state == CivState.WANDER
			state = CivState.FLEE if randf() < 0.6 else CivState.COWER
			if was_calm:
				_call_for_aid()


## Shooting started at this man's hamlet and the player is somewhere else. The
## village becomes a place worth walking to.
func _call_for_aid() -> void:
	if village_center == Vector3.ZERO:
		return
	var dmf: Node = MissionGenerator.dynamic_factory_ref
	var player := GameManager.player as Node3D
	if not (dmf is DynamicMissionFactory) or player == null:
		return
	(dmf as DynamicMissionFactory).report_village_distress(village_center,
		absi(hash(Vector2i(int(village_center.x), int(village_center.z)))),
		player.global_position)


func _physics_process(delta: float) -> void:
	if state == CivState.GONE:
		return
	# The spawner sets occupation/working_point AFTER spawn() returns, so first
	# tick is the earliest this body knows its own job. Place before it is ever
	# drawn thinking, rather than letting it walk to its post from its bunk.
	if not _placed_for_hour:
		_placed_for_hour = true
		if not puppet:
			place_for_current_hour()
	_update_lod(delta)
	if lod_tier == LOD_FAR:
		# Skip the body, never the tick: _update_lod is the only thing that can
		# tier this civilian back IN, and it runs from here.
		return
	if puppet:
		# The driver writes position every frame; gravity and the BT would fight it.
		return
	velocity.y -= 9.8 * delta

	# Informer: spotted you nearby -> starts the clock; escapes -> alarm.
	var player := GameManager.player as Node3D
	# ADR-005: proximity is not sight. He must actually SEE you to carry the word.
	if is_informer and player and _inform_clock < 0.0 \
			and global_position.distance_to(player.global_position) < 15.0 \
			and CombatManager.has_line_of_sight(global_position + Vector3.UP * 1.5,
				player.global_position + Vector3.UP * 1.0, [self]):
		_inform_clock = 0.0
		_saw_player_at = player.global_position
		state = CivState.FLEE
	if _inform_clock >= 0.0:
		_inform_clock += delta
		if _inform_clock > 25.0:
			_inform_clock = -1.0
			state = CivState.GONE
			if director:
				director.toast.emit("THAT VILLAGER TALKED - THEY KNOW YOU'RE HERE")
			_transform_to_vc()
			visible = false
			set_physics_process(false)
			return

	# Which baked region he stands in, at think rate - never per frame (nav_router's contract).
	_box_timer -= delta
	if _box_timer <= 0.0:
		_box_timer = 0.5
		if lod_tier == LOD_FULL:
			_router.refresh_box(global_position)

	match state:
		CivState.WANDER:
			if board_target != Vector3.ZERO:
				active_action = &"board"
				_step_toward(board_target, BOARD_WALK_SPEED, delta)
			else:
				_bt_tick(delta)
		CivState.FLEE:
			var flee_from := _saw_player_at
			if player and flee_from == Vector3.ZERO:
				flee_from = player.global_position
			var away := (global_position - flee_from)
			away.y = 0
			# Clamped only where a region covers the ville; at an unbaked one the
			# helper hands the raw point back and the flee stays a direct line.
			_step_toward(_router.nearest_mesh_point(
				global_position + away.normalized() * 10.0), 4.0, delta)
		CivState.COWER:
			velocity.x = 0
			velocity.z = 0
	_update_unstick(delta)
	move_and_slide()
	# Face travel. Without this the only yaw a civilian ever gets is the one
	# SeatSystem.unseat() stamps from the seat socket, and heli-delivered men
	# cross the pad locked at the door's sideways heading.
	var vel := Vector3(velocity.x, 0.0, velocity.z)
	if vel.length_squared() > 0.09 and actor != null and is_instance_valid(actor):
		actor.set_facing(vel)
	_animate()


## _animate() maps CivState to a fallback chain of clip names that exist in
## res://assets/shared/anim_library.glb. play_first() walks the chain and plays
## the first one the rig actually carries, so a missing clip degrades to the
## next one instead of freezing the model mid-stride.
func _animate() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if puppet:
		return
	# Burning outranks every state, BT action and reactive override. By node name,
	# not class: an unregistered `class_name` fails to compile on a cold run.
	var burn: Node = get_node_or_null("Burning")
	if burn != null and burn.has_method("is_burning") and bool(burn.call("is_burning")):
		var bclip: String = String(burn.call("clip"))
		if bclip != "" and not actor.play(bclip):
			actor.play(String(burn.call("clip_alt")))
		return
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.4
	var want: String = ""
	# Reactive states (FLEE/COWER/GONE) win over the BT action; FLEE/COWER
	# are driven by the noise listener and the informer alarm, not the BT.
	if state == CivState.FLEE:
		want = "running_unarmed"
	elif state == CivState.COWER:
		want = "hands_up" if is_informer and _inform_clock >= 0.0 else "crouching"
	elif state == CivState.GONE:
		return
	else:
		match active_action:
			&"walk_home", &"walk_paddy", &"walk_fire", &"walk_market", &"walk_group":
				want = "walking_unarmed" if moving else "idle"
			&"sit", &"talk", &"rest", &"sleep":
				want = "walking_unarmed" if moving else "seated"
			&"work", &"cook", &"fish":
				want = "walking_unarmed" if moving else "stooped"
			_:
				want = "walking_unarmed" if moving else "idle"
	if want == _last_clip:
		return
	_last_clip = want
	if is_garrison:
		_play_garrison(want)
		return
	# CIVILIAN CHAINS CARRY NO ARMED CLIP. `idle` and `idle_crouching` are the
	# RIFLEMAN idle and the rifleman weapon crouch - with either at the head of a
	# chain, play_first() returns on it and the whole village stands and squats
	# like a firing line. A missing clip must degrade to a T-pose, which is loud,
	# rather than to a weapon pose, which is quiet and wrong.
	# The SCHEDULE knows what he is DOING; `want` only knows what shape he is in.
	# A seated man talking and a seated man asleep share one pose otherwise.
	# Movement poses are left alone - a walking man is not asleep.
	if want != "running_unarmed" and want != "walking_unarmed":
		var act: StringName = scheduled_action()
		if act == &"sit" and occupation == "elder":
			actor.play_first(_rotate(["praying", "praying_b", "sitting_idle_b"]))
			return
		if VILLAGE_ACTION_CLIPS.has(act):
			actor.play_first(_rotate(VILLAGE_ACTION_CLIPS[act] as Array))
			return
	match want:
		"running_unarmed":
			actor.play_first(["running_unarmed", "walking_unarmed"])
		"hands_up":
			actor.play_first(["idle_unarmed_2", "idle_unarmed"])
		"crouching":
			actor.play_first(["sitting", "idle_unarmed_4", "idle_unarmed"])
		"seated":
			actor.play_first(["sitting", "idle_unarmed_5", "idle_unarmed"])
		"stooped":
			actor.play_first([_idle_variant, "idle_unarmed_3", "idle_unarmed"])
		"walking_unarmed":
			actor.play_first(["walking_unarmed", "running_unarmed"])
		_:
			actor.play_first([_idle_variant, "idle_unarmed"])


## An untyped Array cannot be passed where Array[String] is declared, and `as Array[String]`
## does NOT convert one - it fails the call at runtime. Const Array-of-Array literals hold
## untyped inners, so every chain read out of one must come through here.
func _as_clips(chain: Array) -> Array[String]:
	var out: Array[String] = []
	for c in chain:
		out.append(str(c))
	return out


## Same clips, different head, fixed per man by his spawn hash so the ville rebuilds
## identical (ADR-010). The LAST entry never rotates: it is the degrade target - the
## clip every rig is known to carry - and promoting it to the head would answer "what
## is this man doing" with "the fallback".
func _rotate(chain: Array) -> Array[String]:
	var rotatable: int = chain.size() - 1
	if rotatable < 2:
		return _as_clips(chain)
	@warning_ignore("integer_division")
	var off: int = (_idle_seed / 11) % rotatable
	var out: Array[String] = []
	for i in range(rotatable):
		out.append(str(chain[(i + off) % rotatable]))
	out.append(str(chain[chain.size() - 1]))
	return out


## Garrison chains carry the ARMED poses the villager chains deliberately refuse:
## a man standing his post holds a rifle, and `idle`/`walk_forward` are the
## rifleman clips. Off-post actions fall back to the unarmed loafing poses.
func _play_garrison(want: String) -> void:
	# The quartermaster's whole job is moving crates, and the library has carried
	# `cargo_carry` / `cargo_unload_stack` with no caller since they landed.
	# Off-duty men loaf; the schedule already keeps them away from a post. These are
	# the unarmed poses, which is the point - a man smoking is not standing to.
	if occupation == "off_duty" and want != "running_unarmed" and want != "walking_unarmed":
		# Seeded per man so six off-duty men are not one man six times.
		@warning_ignore("integer_division")
		var pick: int = (_idle_seed / 3) % OFF_DUTY_CHAINS.size()
		actor.play_first(_as_clips(OFF_DUTY_CHAINS[pick] as Array))
		return
	# The aid station. medic_treat_give had exactly one caller (the squad revive) and
	# medic_treat_receive had none at all - the library carried a whole aid station
	# nobody was standing in.
	if occupation == "medic":
		if want == "walking_unarmed":
			actor.play_first(["walk_forward", "walking_unarmed"])
			return
		if want != "running_unarmed":
			actor.play_first(["medic_treat_give", "kneeling_idle", "sitting_idle_b",
				"idle_unarmed_3"])
			return
	# The man on the cot. medic_treat_receive shipped with the wave and had ZERO
	# callers - the library carried the patient and the game carried the empty bed.
	if occupation == "patient" and want != "walking_unarmed" and want != "running_unarmed":
		actor.play_first(["medic_treat_receive", "laying_idle", "sleeping_laying",
			"sitting"])
		return
	# The working party: digging, filling, hauling, policing. `plant_seeds` is a
	# kneeling ground-work clip and reads as filling a sandbag, not as farming.
	if occupation == "detail":
		if want == "walking_unarmed":
			actor.play_first(["cargo_carry", "walk_forward", "walking_unarmed"])
			return
		if want == "stooped":
			actor.play_first(["digging", "plant_seeds", "cargo_unload_stack",
				"idle_unarmed_3"])
			return
	# THE MESS. work_cook seats a man at the stoves, work_mess at the serving line -
	# two different jobs that both resolved to mess_cook, so both sat on a crate.
	# The chow clips shipped 2026-08-03 and had no caller until the marker role
	# reached this far.
	if occupation == "mess_cook":
		if want == "walking_unarmed":
			actor.play_first(["chow_carry_walk", "walk_forward", "walking_unarmed"])
			return
		if want == "stooped":
			if role == "mess":
				actor.play_first(["chow_serve_ladle", "chow_tray_hold",
					"cargo_unload_stack", "idle_unarmed_3"])
				return
			# Three stove beats so four cooks are not one cook four times.
			@warning_ignore("integer_division")
			var beat: int = (_idle_seed / 5) % 3
			var stove: Array[String] = ["chow_cook_stir", "chow_cook_prep",
				"chow_cook_check"]
			var chain: Array[String] = [stove[beat], "chow_cook_stir",
				"sitting_idle_b", "idle_unarmed_3"]
			actor.play_first(chain)
			return
	# THE GUNS. The synchronised pit loop lives in gun_crew_performance.gd, which
	# puppets this man once he reaches his station; this branch only covers the
	# walk up and any man the driver has not captured. `role` is the raw work_type,
	# so one occupation serves both weapons.
	if occupation == "gun_crew_arty":
		if want == "walking_unarmed":
			actor.play_first(["cargo_carry", "walk_forward", "walking_unarmed"])
			return
		if want == "stooped" or want == "seated":
			# Every man on the piece has a DIFFERENT job - that is the whole read of a served
			# gun. Seeded per man so a pit is a crew and not four gunners.
			var crew: Array[String] = ["gun_gunner", "gun_loader", "gun_agunner",
				"gun_ammo_bearer"]
			if role == "mortar":
				crew = ["mortar_gunner", "mortar_dropper", "mortar_runner"]
			@warning_ignore("integer_division")
			var seat: int = (_idle_seed / 13) % crew.size()
			actor.play_first([crew[seat], "kneeling_idle", "idle_unarmed_3", "idle"])
			return
	# THE DINER SIDE. The servery above shipped wired; the twelve clips the men EATING
	# use had no caller at all, so the cook stirred and the server ladled to an empty
	# hall. `role` is the marker that seated him (site_planner FSB_WORK_OCCUPATION):
	# queue/eat/chow_diner/chow_exit are different jobs at the same meal.
	if occupation == "mess_hall":
		if want == "walking_unarmed":
			_chow_seated = false
			if role == "queue":
				actor.play_first(["chow_queue_walk", "walk_forward", "walking_unarmed"])
			else:
				# Two carry gaits so a tray line is not one stride copied down it.
				@warning_ignore("integer_division")
				var ci: int = (_idle_seed / 3) % 2
				var carry: Array[String] = ["chow_tray_carry_walk", "chow_carry_step"]
				actor.play_first([carry[ci], "chow_tray_carry_walk", "chow_carry_walk",
					"walk_forward", "walking_unarmed"])
			return
		if want == "stooped" or want == "seated":
			if role == "queue":
				# Shuffling forward, waiting, taking the tray - three beats so a queue
				# is not one pose repeated down the line.
				@warning_ignore("integer_division")
				var qb: int = (_idle_seed / 7) % 3
				var q: Array[String] = ["chow_queue_step", "chow_tray_wait",
					"chow_tray_receive"]
				actor.play_first([q[qb], "chow_tray_wait", "idle_unarmed_3", "idle"])
				return
			if role == "chow_exit":
				actor.play_first(["chow_tray_dump", "chow_stand_up", "idle_unarmed_3"])
				return
			# A man still on his FEET at the table eats standing. The seated chain on a
			# standing man reads as a chair that is not there.
			if want == "stooped":
				actor.play_first(["chow_eat_standing", "chow_talk_seated_a",
					"idle_unarmed_3"])
				return
			# At table. Eating and talking alternate per man so a full bench is not
			# twenty men chewing in unison.
			@warning_ignore("integer_division")
			var eb: int = (_idle_seed / 11) % 4
			var beats: Array[String] = ["chow_eat_seated", "chow_talk_seated_a",
				"chow_eat_seated", "chow_talk_seated_b"]
			var table: Array[String] = [beats[eb], "chow_eat_seated",
				"sitting_idle_b", "sitting"]
			# He sits DOWN before he sits: one beat, then the table hold. The latch is
			# what keeps it from replaying every time the schedule re-dresses him.
			if not _chow_seated:
				_chow_seated = true
				if actor.play_first(["chow_sit_down"]) != "":
					get_tree().create_timer(CHOW_SIT_S).timeout.connect(
						func() -> void:
							if actor != null and is_instance_valid(actor):
								actor.play_first(table))
					return
			actor.play_first(table)
			return
	if occupation == "quartermaster":
		if want == "walking_unarmed":
			actor.play_first(["cargo_carry", "walk_forward", "walking_unarmed"])
			return
		if want == "stooped":
			actor.play_first(["cargo_unload_stack", "idle_unarmed_3", "idle"])
			return
	match want:
		"running_unarmed":
			actor.play_first(["run_forward", "running_unarmed"])
		"crouching":
			actor.play_first(["idle_crouching", "sitting", "idle"])
		"seated":
			actor.play_first(["sitting", "idle_unarmed_5", "idle"])
		"stooped":
			if ARMED_POSTS.has(occupation):
				actor.play_first(["idle", "idle_aiming"])
			else:
				actor.play_first([_idle_variant, "idle_unarmed_3", "idle"])
		"walking_unarmed":
			actor.play_first(["walk_forward", "walking_unarmed"])
		_:
			actor.play_first(["idle", "idle_unarmed"])


func _step_toward(target: Vector3, speed: float, delta: float) -> void:
	# Routing is for the men you can see walking. A villager 300m out crossing a paddy has
	# nothing to path around, and a populated AO carries 16-40 of them - each path query is
	# a cost the frame pays for a man nobody is looking at.
	var dir: Vector3 = _router.step(global_position, target) if lod_tier == LOD_FULL \
		else (target - global_position)
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
		velocity.x = lerpf(velocity.x, dir.x * speed, delta * 6.0)
		velocity.z = lerpf(velocity.z, dir.z * speed, delta * 6.0)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)


## Arity is a CONTRACT: every caller (bullet_system.gd, weapon_holder.gd) passes
## four arguments, and has_method() checks the name, not the signature - a 3-arg
## version binds fine and errors on the first hit.
func take_damage(amount: int, _t: Enums.DamageType = Enums.DamageType.PHYSICAL,
		attacker: Node = null, zone: String = "BODY") -> int:
	if state == CivState.GONE:
		return 0
	# Deferred: promote() is a synchronous teardown and this body is mid-damage.
	if is_garrison and attacker is EnemyBase and director != null:
		director.garrison_alarm.call_deferred(global_position)
	if Hitzone.zone_name_is_fatal(zone):
		amount = _hp + 999
	_hp -= amount
	if _hp > 0:
		state = CivState.FLEE if randf() < 0.5 else CivState.COWER
		return amount
	_die(attacker, zone, amount)
	return amount


func _die(attacker: Node, zone: String, amount: int) -> void:
	state = CivState.GONE
	AgentRegistry.unregister(self)
	set_physics_process(false)
	# Zones ride the body. The body is about to be laid flat, which would swing a
	# fatal HEAD zone out to chest height a metre and a half away, invisible, and
	# leave it eating rounds for the whole corpse linger.
	_teardown_hitzones()
	if actor != null and is_instance_valid(actor):
		var dir: Vector3 = Vector3.FORWARD
		if attacker is Node3D:
			dir = (global_position - (attacker as Node3D).global_position).normalized()
		var popped: bool = false
		if zone == "HEAD" and amount >= GibSystem.HEAD_POP_KILL:
			popped = GibSystem.dismember_head_burst(actor, dir, get_tree().current_scene)
			if not popped:
				popped = GibSystem.dismember(actor, "HEAD", dir, get_tree().current_scene)
		if not popped:
			actor.play_first(["death_from_the_front", "death_forward", "laying_breathless"])
		# GUARANTEED FLOOR (same contract as enemy_base): the clip gets its 1.5s to
		# fall, then the pose is measured and laid flat if it never went prone.
		var mac: ModelActor = actor
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(mac):
				mac.settle_flat_corpse())
	_record_noncombatant_death(attacker)
	get_tree().create_timer(30.0).timeout.connect(queue_free)


## Per-patrol noncombatant tally: COUNT ONLY. The hook's old ban was on SCORING and
## none is added - surfacing and any XP/escalation weight stay the Summoner's call
## (ADR-006 re-host). A revealed informer is a combatant now: _transform_to_vc drops
## him from "civilians" without going GONE, so the group check keeps him out of it.
func _record_noncombatant_death(_killer: Node) -> void:
	# A garrison man is a soldier (ruling 2026-08-04) - his death is a casualty,
	# never a noncombatant tally. He stays in "civilians" for blast semantics only.
	if is_garrison:
		return
	if not is_in_group("civilians"):
		return
	if director != null:
		director.record_noncombatant_death()


func _teardown_hitzones() -> void:
	for c in get_children():
		if c is Hitzone:
			(c as Hitzone).queue_free()


## HE WATCHED YOU TAKE AN EAR, AND NOW HE HAS SOMETHING TO CARRY.
##
## player.gd:249 has called this on every witness within EAR_WITNESS_M since the ear system
## shipped, guarded by has_method - and nothing implemented it, so the branch was a permanent
## no-op and "THEY SAW YOU DO THAT" was a toast with nothing behind it. Wired on his ruling,
## 2026-08-07.
##
## Deliberately NOT a new system. ADR-019's sentiment ledger does not exist and is deferred
## post-launch; what DOES exist is the informer, who already runs, already carries the word,
## and already trips the alarm at 25s. A witness becomes one of those. No meter, no score - the
## consequence is a man leaving with your position, which is the shape ADR-019 asked for
## anyway: sentiment moves in words, never as a number.
##
## `at` is the corpse, which is where you were standing when he saw you - so it is the honest
## value for the fix he carries, and it is already what the caller passes.
func on_atrocity_witnessed(at: Vector3) -> void:
	if state == CivState.GONE or is_garrison:
		return
	# Already running with a story: seeing a second one does not restart his clock.
	if _inform_clock >= 0.0:
		return
	is_informer = true
	_inform_clock = 0.0
	_saw_player_at = at
	state = CivState.FLEE


## Informer alarm fired. Swap the model to a VC variant, drop the civilian out
## of the civilians group, ready the faction flip. The actual `EnemyBase` is
## spawned by the mission director (it owns the enemy roster); here we just
## make the visual hand-off so a villager-shaped VC is not a hard bug.
func _transform_to_vc() -> void:
	if not is_informer:
		return
	remove_from_group("civilians")
	AgentRegistry.unregister(self)
	if actor != null and is_instance_valid(actor):
		var vc_pick: String = "vc_farmer_m"
		if not actor.setup(vc_pick):
			vc_pick = "vc_regular_m"
			actor.setup(vc_pick)
	if director:
		director.on_informer_escaped(global_position, _saw_player_at)


# ---- L1 behavior tree ------------------------------------------------------
## Build the BT once, after spawn. Root is a Selector of (reactive, schedule,
## idle). Reactive is empty for now (state changes handle FLEE/COWER inline)
## and exists as a hook for future "if informer alarm then HANDS_UP" nodes.

func build_bt() -> void:
	var idle_action = BTActionS.new(Callable(self, "_bt_do_idle"), "idle")
	var walk_home = BTActionS.new(Callable(self, "_bt_walk_home"), "walk_home")
	var walk_paddy = BTActionS.new(Callable(self, "_bt_walk_working"), "walk_paddy")
	var walk_fire = BTActionS.new(Callable(self, "_bt_walk_fire"), "walk_fire")
	var walk_market = BTActionS.new(Callable(self, "_bt_walk_market"), "walk_market")
	var work = BTActionS.new(Callable(self, "_bt_work"), "work")
	var rest = BTActionS.new(Callable(self, "_bt_rest"), "rest")
	var cook = BTActionS.new(Callable(self, "_bt_cook"), "cook")
	var sleep_act = BTActionS.new(Callable(self, "_bt_sleep"), "sleep")
	var fish = BTActionS.new(Callable(self, "_bt_fish"), "fish")
	var sit = BTActionS.new(Callable(self, "_bt_sit"), "sit")
	var talk = BTActionS.new(Callable(self, "_bt_talk"), "talk")
	var by_action: Dictionary = {
		CivilianSchedulesS.ACTION_IDLE: idle_action,
		CivilianSchedulesS.ACTION_WALK_HOME: walk_home,
		CivilianSchedulesS.ACTION_WALK_PADDY: walk_paddy,
		CivilianSchedulesS.ACTION_WALK_FIRE: walk_fire,
		CivilianSchedulesS.ACTION_WALK_MARKET: walk_market,
		CivilianSchedulesS.ACTION_WORK: work,
		CivilianSchedulesS.ACTION_REST: rest,
		CivilianSchedulesS.ACTION_COOK: cook,
		CivilianSchedulesS.ACTION_SLEEP: sleep_act,
		CivilianSchedulesS.ACTION_FISH: fish,
		CivilianSchedulesS.ACTION_SIT: sit,
		CivilianSchedulesS.ACTION_TALK: talk,
	}
	_bt_bb["by_action"] = by_action
	_bt_bb["last_pick_hour"] = -1.0
	_bt_bb["home"] = home
	_bt = BTSelectorS.new([
		BTActionS.new(Callable(self, "_bt_dispatch"), "dispatch"),
		idle_action,  # fallback: schedule named no action this hour
	])
	# The artillery crew assembles its own driver here because mission_generator
	# hands crew posts through the generic path - and a dawn stand-down rebuilds
	# this body lazily through _bt_tick, which lands back here.
	if is_garrison and occupation == "gun_crew_arty":
		_join_gun_crew()


## Find-or-create the pit's GunCrewPerformance, LitterTeamScript-style external
## construction (a static factory would self-reference a fresh class_name).
func _join_gun_crew() -> void:
	if working_point_pos == Vector3.ZERO or get_tree() == null:
		return
	for d in get_tree().get_nodes_in_group("gun_crew_performances"):
		var drv := d as Node3D
		if drv == null or not drv.has_method("register_man"):
			continue
		if Vector2(drv.global_position.x - working_point_pos.x,
				drv.global_position.z - working_point_pos.z).length() \
				<= GunCrewPerformanceS.PIT_RADIUS:
			drv.call("register_man", self)
			return
	var parent: Node = get_parent()
	if parent == null:
		return
	var drv2 := GunCrewPerformanceS.new() as Node3D
	parent.add_child(drv2)
	drv2.global_position = working_point_pos
	drv2.call("register_man", self)


## Tick the leaf the schedule named. FAILURE when the hour maps to no action,
## which drops the selector through to the idle fallback.
## active_action is set by the LEAF, never by the scheduler - it must report
## what the tree actually ran, or a dead tree looks alive.
func _bt_dispatch(civ: Civilian, bb: Dictionary) -> int:
	var table: Dictionary = bb.get("by_action", {})
	var want: StringName = StringName(bb.get("scheduled_action", &""))
	if not table.has(want):
		return BTNodeS.BTStatus.FAILURE
	var leaf: RefCounted = table[want]
	if leaf == null:
		return BTNodeS.BTStatus.FAILURE
	return int(leaf.tick(civ, bb))


func _bt_tick(delta: float) -> void:
	if _bt == null:
		build_bt()
	# Refresh the schedule pick each sim hour so the BT walks the civilian
	# toward a new working_point when the period rolls over.
	var hour: float = _read_sim_hour()
	var last_hour: float = float(_bt_bb.get("last_pick_hour", -1.0))
	if int(hour) != int(last_hour):
		_bt_bb["last_pick_hour"] = hour
		# The man's own node name, the same identity the work offset derives from below
		# (:870) - it is what makes his mess sitting identical every run.
		var picked: StringName = CivilianSchedulesS.action_for(occupation, hour, String(name))
		_bt_bb["scheduled_action"] = picked
		_bt_bb["target_pos"] = _resolve_target(picked)
	_bt_bb["delta"] = delta
	_bt.tick(self, _bt_bb)
	var speed: float = float(_bt_bb.get("speed", 1.2))
	if _group_walk_apply():
		speed = GROUP_WALK_SPEED
	_step_toward(_wander_target, speed, delta)


## The action the schedule named this hour. Stable for the whole hour, unlike
## active_action, which GroupWalk rewrites to walk_group mid-frame.
func scheduled_action() -> StringName:
	return StringName(_bt_bb.get("scheduled_action", &""))


## Redirect _wander_target to this civilian's formation slot when the household
## is travelling. Returns true if the group took the target. The BT still picks
## the destination - the lead's own scheduled target is what the party walks to,
## so a family walking to the paddy is the schedule, not a second behavior.
func _group_walk_apply() -> bool:
	if group_id < 0 or group_members.size() < 2:
		return false
	if not GROUP_WALK_ACTIONS.has(scheduled_action()):
		return false
	var party: Array = _group_party()
	if party.size() < 2:
		return false
	var lead: Civilian = GroupWalk.lead_of(party)
	if lead == null:
		return false
	if lead == self:
		GroupWalk.tick(party, _wander_target)
	elif lead.group_destination == Vector3.ZERO:
		return false
	# Each civilian reports its OWN action. If the lead set it for the party,
	# a follower that ticks after the lead would overwrite it from its schedule
	# leaf and read as walking alone.
	active_action = &"walk_group"
	_wander_target = group_destination
	return true


## Household members who are travelling on the SAME scheduled action and are not
## in a reactive state. A fleeing or cowering villager is not in the party, so a
## family under fire scatters into individuals.
func _group_party() -> Array:
	var out: Array = []
	var mine: StringName = scheduled_action()
	for m in group_members:
		if m == null or not is_instance_valid(m):
			continue
		var c: Civilian = m as Civilian
		if c.state != CivState.WANDER:
			continue
		if c.scheduled_action() != mine:
			continue
		out.append(c)
	return out


## SimClock is an AUTOLOAD with no class_name (sim_clock.gd:5) - it is absent
## from both Engine.has_singleton and ClassDB, so it can only be reached by
## node path. 12.0 is the out-of-tree fallback for unit tests.
func _read_sim_hour() -> float:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		return 12.0
	return float(clock.sim_hour)


func _update_lod(delta: float) -> void:
	_lod_timer += delta
	if _lod_timer < LOD_RECOMPUTE_S:
		return
	_lod_timer = 0.0
	var player := GameManager.player as Node3D
	var d: float = 0.0
	if player:
		d = global_position.distance_to(player.global_position)
	var new_tier: int = lod_tier
	if lod_tier == LOD_FULL:
		if d > LOD_NEAR_RADIUS + LOD_HYSTERESIS:
			new_tier = LOD_NEAR
	elif lod_tier == LOD_NEAR:
		if d < LOD_NEAR_RADIUS - LOD_HYSTERESIS:
			new_tier = LOD_FULL
		elif d > LOD_FAR_RADIUS + LOD_HYSTERESIS:
			new_tier = LOD_FAR
	else:  # LOD_FAR
		if d < LOD_FAR_RADIUS - LOD_HYSTERESIS:
			new_tier = LOD_NEAR
	# Waking from LOD_FAR: this body has not ticked a schedule since it tiered
	# out at 300m, so it is standing wherever the hour left it. Put it where the
	# clock says it already is, at ~300m where the correction cannot be read.
	if lod_tier == LOD_FAR and new_tier != LOD_FAR:
		place_for_current_hour()
	lod_tier = new_tier


## Stand this body where its schedule says it ALREADY is.
##
## _physics_process hard-returns at LOD_FAR (300m), and action_for is only
## reachable below that, so a distant civilian never advances a schedule. The
## state was always correct on arrival - the POSITION was not. A farmer whose
## 0700 says "at the paddy" stood at his hut until the player closed, then
## walked to the paddy in front of him. That is the world assembling itself on
## approach instead of having been there all along.
##
## Called by the spawner once occupation/working_point are configured, and again
## on wake from LOD_FAR. camp_director.gd:109-134 already does the same on
## hour_advanced with no distance check - this is that pattern, applied to the
## bodies that sleep. O(1) per wake: no off-view behaviour trees.
func place_for_current_hour() -> void:
	if state == CivState.GONE:
		return
	var hour: float = SimClock.sim_hour if SimClock != null else 12.0
	var target: Vector3 = _resolve_target(
		CivilianSchedulesS.action_for(occupation, hour, String(name)))
	if target == Vector3.ZERO:
		return
	# Markers carry valid ground Y; a nav-clamped point carries the mesh's Y,
	# which sits at most a cell-height under it - gravity settles either.
	global_position = target
	_wander_target = target


func _resolve_target(action: StringName) -> Vector3:
	# Working_point is the only position-bound location today. Other actions
	# (fire/market/home) fall back to home with a small wander. Every return is
	# clamped through the guarded helper - a marker inside a carved hut footprint
	# is a destination no body can stand on, and place_for_current_hour teleports
	# straight to this value.
	if action == CivilianSchedulesS.ACTION_WALK_PADDY or action == CivilianSchedulesS.ACTION_WORK \
			or action == CivilianSchedulesS.ACTION_FISH:
		if working_point_pos != Vector3.ZERO:
			return _router.nearest_mesh_point(working_point_pos)
	return _router.nearest_mesh_point(
		home + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0)))


# ---- BT actions ------------------------------------------------------------
## Each action sets _wander_target and the per-action move speed. SUCCESS
## when the action is "complete" (a soft check, e.g. close to target), which
## for civilians means: arrived and the schedule window is still open. RUNNING
## otherwise. The BT root is just `idle_action` for now, so SUCCESS terminates.

func _bt_do_idle(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"idle"
	bb["speed"] = 0.0
	velocity.x = 0
	velocity.z = 0
	_wander_target = global_position
	return BTNodeS.BTStatus.SUCCESS

func _bt_walk_home(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"walk_home"
	bb["speed"] = 1.6
	_wander_target = home
	if global_position.distance_to(home) < 1.5:
		return BTNodeS.BTStatus.SUCCESS
	return BTNodeS.BTStatus.RUNNING

func _bt_walk_working(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"walk_paddy"
	bb["speed"] = 1.4
	_wander_target = bb.get("target_pos", working_point_pos) if bb.has("target_pos") else working_point_pos
	if global_position.distance_to(_wander_target) < 1.5:
		return BTNodeS.BTStatus.SUCCESS
	return BTNodeS.BTStatus.RUNNING

func _bt_walk_fire(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"walk_fire"
	bb["speed"] = 1.4
	var fire := home + Vector3(2.0, 0, 2.0)
	_wander_target = fire
	if global_position.distance_to(fire) < 1.5:
		return BTNodeS.BTStatus.SUCCESS
	return BTNodeS.BTStatus.RUNNING

func _bt_walk_market(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"walk_market"
	bb["speed"] = 1.4
	_wander_target = home + Vector3(-3.0, 0, 4.0)
	if global_position.distance_to(_wander_target) < 1.5:
		return BTNodeS.BTStatus.SUCCESS
	return BTNodeS.BTStatus.RUNNING

## A post is somewhere to BE. This used to freeze the man wherever he already stood, which
## is why twelve scheduled actions collapsed into four behaviours and why the firebase night
## shift only LOOKED manned - place_for_current_hour() teleports everyone at spawn, so the
## sentries, gun crew, radioman and quartermaster appeared on station and then never walked
## to one again for the rest of the night. The 191 work markers were already resolved into
## bb["target_pos"] every sim hour and nothing read them.
const WORK_ARRIVE_M: float = 1.6
const WORK_JITTER_M: float = 1.5
const WORK_SPEED: float = 1.1


## THE ONE SETTLE IMPLEMENTATION. There were SEVEN of these and they were byte-identical
## freezes, so twelve scheduled actions collapsed into four behaviours: the cook cooked wherever
## he happened to be standing, the sleeper slept on his feet in the open, and the firebase night
## shift only LOOKED manned because place_for_current_hour() teleports everyone at spawn.
## `bb["target_pos"]` was resolved from the marker set every sim hour and read by nothing.
##
## Walk there, then hold. The destination is whatever the schedule resolved for THIS action, so
## this function never needs to know which action it is serving.
func _bt_settle(action: StringName, bb: Dictionary, speed: float) -> int:
	active_action = action
	var dest: Vector3 = bb.get("target_pos", Vector3.ZERO)
	# The pad is boarding/unloading ONLY (his ruling 2026-08-15). A no-marker
	# action settles in place, so a man fresh off the ramp dug or bedded down on
	# the LZ itself. If he is standing inside a pad's keep-out, he clears it
	# first - home is off-pad by construction (heli_lift fences the bunk ring).
	if dest == Vector3.ZERO and home != Vector3.ZERO \
			and LandingZone.on_pad(global_position) and not LandingZone.on_pad(home):
		bb["speed"] = speed
		_wander_target = home
		return BTNodeS.BTStatus.RUNNING
	if dest != Vector3.ZERO:
		# Two men sent to one marker must not stand in each other. The offset comes from the
		# name so it is identical every run (ADR-010 - never Time, never an unseeded roll).
		var a: float = float(absi(hash(name)) % 360) * (TAU / 360.0)
		var at: Vector3 = _router.nearest_mesh_point(
			dest + Vector3(cos(a), 0.0, sin(a)) * WORK_JITTER_M)
		if global_position.distance_to(at) > WORK_ARRIVE_M:
			bb["speed"] = speed
			_wander_target = at
			return BTNodeS.BTStatus.RUNNING
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS


func _bt_work(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"work", bb, WORK_SPEED)

## An amble, not a march: a man crossing camp to sit down does not move at working pace.
const IDLE_SPEED: float = 0.8


func _bt_rest(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"rest", bb, IDLE_SPEED)

func _bt_cook(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"cook", bb, WORK_SPEED)

func _bt_sleep(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"sleep", bb, IDLE_SPEED)

func _bt_fish(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"fish", bb, IDLE_SPEED)

func _bt_sit(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"sit", bb, IDLE_SPEED)

func _bt_talk(_civ: Civilian, bb: Dictionary) -> int:
	return _bt_settle(&"talk", bb, IDLE_SPEED)
