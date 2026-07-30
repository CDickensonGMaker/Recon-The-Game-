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

## Travelling actions a household walks together. Stationary actions (work,
## cook, sleep) are done side by side at home, not in formation.
const GROUP_WALK_ACTIONS: Array[StringName] = [
	&"walk_home", &"walk_paddy", &"walk_fire", &"walk_market",
]
const GROUP_WALK_SPEED: float = 1.3

const IDLE_VARIANTS: Array[String] = [
	"idle_unarmed_2", "idle_unarmed_3", "idle_unarmed_4", "idle_unarmed_5",
]

# L1 behavior-tree fields. active_action is the BT's current pick; state
# remains the reactive override (FLEE/COWER/GONE) which wins regardless.
var occupation: String = "farmer"
## A US garrison man inside the wire: same schedule machinery, US model, armed
## idle chains, and no noncombatant panic. Background life, never a combatant
## and never a squad member.
var is_garrison: bool = false
## The village this man belongs to. Written at build time so a panicking villager
## can name his own hamlet without a radius scan guessing at it.
var village_center: Vector3 = Vector3.ZERO
var active_action: StringName = &"idle"
var working_point: NodePath = NodePath()
var working_point_pos: Vector3 = Vector3.ZERO
## Group id: civilians with the same id walk as one group. -1 = solo.
var group_id: int = -1
## Where THIS civilian walks while grouped: the destination if lead, else a
## formation slot. Written by GroupWalk, consumed by _step_toward.
var group_destination: Vector3 = Vector3.ZERO
## The household's members, self included. Assigned at spawn.
var group_members: Array = []
## Is this civilian the LEAD of their group? The lead picks the path; followers slot.
var is_group_lead: bool = false
var _bt_bb: Dictionary = {}
## Behavior tree root. Typed as RefCounted to avoid class_name lookup hazards;
## BTSelector/BTAction are duck-typed at runtime via .tick().
var _bt: RefCounted = null
var _router := NavRouter.new()
var _box_timer: float = 0.0

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
	"us_grunt_rifleman", "us_grunt_v3", "us_grunt_pointman",
	"us_grunt_mg", "us_grunt_grenadier", "us_grunt_marksman", "us_grunt_rto",
]


static func spawn(parent: Node, pos: Vector3, mission_director: FieldDirector, informer: bool,
		models: Array[String] = VILLAGERS, garrison: bool = false) -> Civilian:
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


func _on_noise(type: int, noise_pos: Vector3, _radius: float, _team: int) -> void:
	if state == CivState.GONE:
		return
	if is_garrison:
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
		place_for_current_hour()
	_update_lod(delta)
	if lod_tier == LOD_FAR:
		# Skip the body, never the tick: _update_lod is the only thing that can
		# tier this civilian back IN, and it runs from here.
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
			_bt_tick(delta)
		CivState.FLEE:
			var flee_from := _saw_player_at
			if player and flee_from == Vector3.ZERO:
				flee_from = player.global_position
			var away := (global_position - flee_from)
			away.y = 0
			_step_toward(global_position + away.normalized() * 10.0, 4.0, delta)
		CivState.COWER:
			velocity.x = 0
			velocity.z = 0
	move_and_slide()
	_animate()


## _animate() maps CivState to a fallback chain of clip names that exist in
## res://assets/shared/anim_library.glb. play_first() walks the chain and plays
## the first one the rig actually carries, so a missing clip degrades to the
## next one instead of freezing the model mid-stride.
func _animate() -> void:
	if actor == null or not is_instance_valid(actor):
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


## Garrison chains carry the ARMED poses the villager chains deliberately refuse:
## a man standing his post holds a rifle, and `idle`/`walk_forward` are the
## rifleman clips. Off-post actions fall back to the unarmed loafing poses.
func _play_garrison(want: String) -> void:
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
	rotation_degrees.x = 90
	_record_noncombatant_death(attacker)
	get_tree().create_timer(30.0).timeout.connect(queue_free)


## Per-patrol noncombatant tally: COUNT ONLY. The hook's old ban was on SCORING and
## none is added - surfacing and any XP/escalation weight stay the Summoner's call
## (ADR-006 re-host). A revealed informer is a combatant now: _transform_to_vc drops
## him from "civilians" without going GONE, so the group check keeps him out of it.
func _record_noncombatant_death(_killer: Node) -> void:
	if not is_in_group("civilians"):
		return
	if director != null:
		director.record_noncombatant_death()


func _teardown_hitzones() -> void:
	for c in get_children():
		if c is Hitzone:
			(c as Hitzone).queue_free()


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
		var picked: StringName = CivilianSchedulesS.action_for(occupation, hour)
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
		CivilianSchedulesS.action_for(occupation, hour))
	if target == Vector3.ZERO:
		return
	# home/working_point come from markers and carry valid ground Y, and the
	# wander offset is XZ-only, so the target is already grounded.
	global_position = target
	_wander_target = target


func _resolve_target(action: StringName) -> Vector3:
	# Working_point is the only position-bound location today. Other actions
	# (fire/market/home) fall back to home with a small wander.
	if action == CivilianSchedulesS.ACTION_WALK_PADDY or action == CivilianSchedulesS.ACTION_WORK \
			or action == CivilianSchedulesS.ACTION_FISH:
		if working_point_pos != Vector3.ZERO:
			return working_point_pos
	return home + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))


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

func _bt_work(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"work"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS

func _bt_rest(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"rest"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS

func _bt_cook(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"cook"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS

func _bt_sleep(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"sleep"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS

func _bt_fish(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"fish"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS

func _bt_sit(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"sit"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS

func _bt_talk(_civ: Civilian, bb: Dictionary) -> int:
	active_action = &"talk"
	bb["speed"] = 0.0
	_wander_target = global_position
	velocity.x = 0
	velocity.z = 0
	return BTNodeS.BTStatus.SUCCESS
