## civilian.gd - Village noncombatant (W47): wanders, flees gunfire, cowers.
## An informer who escapes after seeing you raises the alarm. Killing civilians
## costs you at debrief and with the war.
class_name Civilian
extends CharacterBody3D

const BTSelectorS := preload("res://scripts/ai/bt/bt_selector.gd")
const BTNodeS := preload("res://scripts/ai/bt/bt_node.gd")
const BTActionS := preload("res://scripts/ai/bt/bt_action.gd")
const BTConditionS := preload("res://scripts/ai/bt/bt_conditions.gd")
const CivilianSchedulesS := preload("res://scripts/ai/civilian_schedules.gd")

enum CivState { WANDER, FLEE, COWER, GONE }

var state: CivState = CivState.WANDER
var home: Vector3
var is_informer: bool = false
var director: FieldDirector
var _hp: int = 20
var _wander_target: Vector3
var _timer: float = 0.0
var _saw_player_at: Vector3 = Vector3.ZERO
var _inform_clock: float = -1.0
var actor: ModelActor = null
var _last_clip: String = ""

# L1 behavior-tree fields. active_action is the BT's current pick; state
# remains the reactive override (FLEE/COWER/GONE) which wins regardless.
var occupation: String = "farmer"
var active_action: StringName = &"idle"
var working_point: NodePath = NodePath()
var working_point_pos: Vector3 = Vector3.ZERO
## Group id: civilians with the same id walk as one group. -1 = solo.
var group_id: int = -1
## Per-group destination when traveling together. Set by GroupWalk.
var group_destination: Vector3 = Vector3.ZERO
## Is this civilian the LEAD of their group? The lead picks the path; followers slot.
var is_group_lead: bool = false
var _bt_bb: Dictionary = {}
## Behavior tree root. Typed as RefCounted to avoid class_name lookup hazards;
## BTSelector/BTAction are duck-typed at runtime via .tick().
var _bt: RefCounted = null
var _schedule_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# L1 LOD. 3 tiers matching enemy_base.gd:39-54. Hysteresis band (5m) prevents
# a civilian at a tier boundary from flapping between tiers every 2 seconds.
const LOD_FULL: int = 0
const LOD_NEAR: int = 1
const LOD_FAR: int = 2
const LOD_NEAR_RADIUS: float = 80.0
const LOD_FAR_RADIUS: float = 300.0
const LOD_HYSTERESIS: float = 5.0
var lod_tier: int = LOD_FULL
var _lod_timer: float = 0.0
const LOD_RECOMPUTE_S: float = 2.0

## Resolved to a .glb by ModelActor.model_path() - never build the path here.
const VILLAGERS: Array[String] = [
	"civ_farmer_m", "civ_farmer_m_b", "civ_farmer_m_c",
	"civ_farmer_f", "civ_farmer_f_b", "civ_farmer_f_c",
	"civ_elder", "civ_elder_b",
	"civ_kid", "civ_kid_b",
]


static func spawn(parent: Node, pos: Vector3, mission_director: FieldDirector, informer: bool) -> Civilian:
	var civ := Civilian.new()
	civ.director = mission_director
	civ.is_informer = informer
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	civ.add_child(col)
	# A PERSON, not a pill. Deterministic per position so the same village rebuilds
	# with the same faces (ADR-010/017 - the province must come back identical).
	var pick: int = absi(hash(Vector2i(int(pos.x), int(pos.z)))) % VILLAGERS.size()
	var actor := ModelActor.new()
	civ.add_child(actor)
	if actor.setup(VILLAGERS[pick]):
		civ.actor = actor
	else:
		# The model is missing. Fall back to the old pill rather than an invisible
		# man - but say so LOUDLY, because a silent fallback is how a village full
		# of capsules survives for weeks without anyone noticing.
		push_warning("[Civilian] no model for '%s' - falling back to a CAPSULE. The village will look like pills." % VILLAGERS[pick])
		actor.queue_free()
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
	parent.add_child(civ)
	civ.global_position = pos
	civ.home = pos
	civ._wander_target = pos
	civ.add_to_group("civilians")
	AgentRegistry.register(civ, AgentRegistry.Kind.CIVILIAN)
	NoiseBus.noise_emitted.connect(civ._on_noise)
	return civ


func _exit_tree() -> void:
	AgentRegistry.unregister(self)


func _on_noise(type: int, position: Vector3, _radius: float, _team: int) -> void:
	if state == CivState.GONE:
		return
	if type == NoiseBus.NoiseType.GUNSHOT or type == NoiseBus.NoiseType.EXPLOSION:
		if global_position.distance_to(position) < 60.0:
			state = CivState.FLEE if randf() < 0.6 else CivState.COWER


func _physics_process(delta: float) -> void:
	if state == CivState.GONE:
		return
	_update_lod(delta)
	if lod_tier == LOD_FAR:
		# FAR LOD: skip physics this frame. State is still advanced by the
		# SimClock.hour_advanced listener below so when the player approaches
		# the civilian is in the right action.
		return
	_timer += delta
	velocity.y -= 9.8 * delta

	# Informer: spotted you nearby -> starts the clock; escapes -> alarm.
	var player := GameManager.player as Node3D
	if is_informer and player and _inform_clock < 0.0 \
			and global_position.distance_to(player.global_position) < 15.0:
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
			NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, _saw_player_at, 0, 120.0)
			_transform_to_vc()
			visible = false
			set_physics_process(false)
			return

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
		# WANDER — driven by the BT. active_action carries the per-action
		# animation. Walking is "walking_unarmed" only if actually moving.
		match active_action:
			&"walk_home", &"walk_paddy", &"walk_fire", &"walk_market", &"walk_group":
				want = "walking_unarmed" if moving else "idle"
			&"work", &"rest", &"cook", &"fish", &"sleep", &"sit", &"talk":
				want = "idle"
			_:
				want = "walking_unarmed" if moving else "idle"
	if want == _last_clip:
		return
	_last_clip = want
	match want:
		"running_unarmed":
			actor.play_first(["running_unarmed", "sprint_forward", "run_forward", "walk_forward", "idle"])
		"hands_up":
			actor.play_first(["idle_unarmed_2", "idle", "sitting"])
		"crouching":
			actor.play_first(["idle_crouching", "idle_crouching__smg", "idle_unarmed_2", "idle"])
		"kneeling":
			actor.play_first(["kneeling_pointing", "idle_crouching", "idle"])
		"sitting":
			actor.play_first(["sitting", "idle_unarmed_2", "idle"])
		"walking_unarmed":
			actor.play_first(["walking_unarmed", "start_walking", "walk_forward", "walk_crouching_forward", "idle"])
		"idle":
			actor.play_first(["idle", "idle_unarmed_2", "idle_unarmed_3", "idle_unarmed_4"])
		_:
			actor.play_first(["idle", "idle_relaxed"])


func _step_toward(target: Vector3, speed: float, delta: float) -> void:
	var dir := (target - global_position)
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
		velocity.x = lerpf(velocity.x, dir.x * speed, delta * 6.0)
		velocity.z = lerpf(velocity.z, dir.z * speed, delta * 6.0)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)


func take_damage(amount: int, _t: Enums.DamageType = Enums.DamageType.PHYSICAL, _a: Node = null) -> int:
	_hp -= amount
	if _hp <= 0 and state != CivState.GONE:
		state = CivState.GONE
		AgentRegistry.unregister(self)
		set_physics_process(false)
		rotation_degrees.x = 90
		if director:
			director.state.flags["civ_casualties"] = int(director.state.flags.get("civ_casualties", 0)) + 1
			director.toast.emit("CIVILIAN DOWN. THAT FOLLOWS YOU HOME.")
		get_tree().create_timer(30.0).timeout.connect(queue_free)
	return amount


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
	# Flag for the mission director. The director's informer_alarm handler reads
	# this and spawns the actual enemy at the civilian's last position.
	if director:
		director.state.flags["informer_transformed"] = true
		director.state.flags["informer_last_pos"] = global_position


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
		idle_action,  # fallback: any unhandled state returns SUCCESS
	])


func _bt_tick(delta: float) -> void:
	if _bt == null:
		build_bt()
	# Refresh the schedule pick each sim hour so the BT walks the civilian
	# toward a new working_point when the period rolls over.
	var hour: float = _read_sim_hour()
	var last_hour: float = float(_bt_bb.get("last_pick_hour", -1.0))
	if int(hour) != int(last_hour):
		_bt_bb["last_pick_hour"] = hour
		active_action = CivilianSchedulesS.action_for(occupation, hour)
		_bt_bb["target_pos"] = _resolve_target(active_action)
		_bt_bb["arrived"] = false
	_bt_bb["delta"] = delta
	_bt.tick(self, _bt_bb)
	_step_toward(_wander_target, _bt_bb.get("speed", 1.2), delta)
	move_and_slide()
	_animate()


## _read_sim_hour returns SimClock.sim_hour if the autoload is registered;
## otherwise 12.0 so the BT stays on daytime actions in unit tests.
func _read_sim_hour() -> float:
	if Engine.has_singleton("SimClock") or ClassDB.class_exists("SimClock"):
		return SimClock.sim_hour
	return 12.0


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
	if new_tier != lod_tier:
		lod_tier = new_tier
		# FAR: stop physics. FULL/NEAR: run physics (NEAR still runs but at
		# the BT-driven tick rate).
		set_physics_process(new_tier != LOD_FAR)


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
