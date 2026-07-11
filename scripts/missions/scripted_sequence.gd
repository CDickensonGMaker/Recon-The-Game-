## scripted_sequence.gd - Lightweight await-based step runner for scripted
## events (batch_research §6 / MISSION_DESIGN_RESEARCH §2.3 - RTCW's resumable
## script threads on GDScript coroutines).
##
## Steps are plain Dictionaries executed in order. Types:
##   {"type": "wait",       "seconds": 2.0}
##   {"type": "move",       "agent": NodePath, "to": Vector3,
##        "urgency": "suspicious"|"alert",           # EnemyBase investigate tier
##        "await_arrival": false, "timeout": 20.0, "arrive_radius": 2.5}
##   {"type": "play_clip",  "agent": NodePath, "clip": "sitting"}
##   {"type": "bark",       "agent": NodePath, "line": "Dung lai!"}  # agent optional
##   {"type": "signal",     "name": "ambush_sprung", "data": {}}
##   {"type": "spawn_prop", "scene": "res://..." or PackedScene,
##        "position": Vector3 / "rotation_deg": Vector3 / "transform": Transform3D}
##   {"type": "hand_off"}
##
## THE ANTI-CORRIDOR LAW (Pillar 3, RTCW interrupt contract): a sequence NEVER
## disables an agent's take_damage, perception, or FSM - cast members stay fully
## mortal and reactive the whole time. `move` reuses existing movement seams
## (AllyBase.set_order / EnemyBase investigate fields - the hunter-seeding
## pattern, mission_director.gd) - there is no bespoke mover.
##
## THE PILLAR 3 GUARANTEE: hand_off releases every referenced agent back to
## systemic AI. It also happens AUTOMATICALLY - aborting the sequence with
## `interrupted` - the moment any cast member takes damage, dies, or acquires a
## combat target. Shooting the actors collapses the script into a real fight.
##
## HONEST-QUIET LAW: spawn_prop instantiates PROPS ONLY. Any scene containing a
## combatant (EnemyBase/AllyBase class or enemies/allies/player group) is
## refused outright - events borrow cast from the AO's finite ledger, never
## conjure it.
##
## Agents that die or free mid-sequence have their remaining steps skipped -
## the runner never blocks on a dead man.
class_name ScriptedSequence
extends Node

signal completed
signal interrupted(reason: String)
signal handed_off(agents: Array[Node])
## Bark stub until a VO pipeline lands for sequences - subtitle/VO systems
## consume this; the runner itself only prints.
signal sequence_bark(agent: Node, line: String)
signal sequence_signal(signal_name: StringName, data: Dictionary)

@export var steps: Array[Dictionary] = []
## Cast declared up front (mortality-watched from start()); agents referenced
## inside steps are added to the watch automatically.
@export var cast_paths: Array[NodePath] = []
@export var auto_start: bool = false
## Where spawn_prop children go. Empty = this node's parent.
@export var prop_parent_path: NodePath = NodePath()

var _running: bool = false
var _aborted: bool = false
var _handed_off: bool = false
var _run_id: int = 0
var _cast: Array[Node] = []
var _hp_baseline: Dictionary = {}  ## instance_id -> int hp at watch start
var _ally_orders: Dictionary = {}  ## instance_id -> {"mode": int, "pos": Vector3}


func _ready() -> void:
	add_to_group("scripted_sequences")
	set_physics_process(false)
	if auto_start:
		start.call_deferred()


func is_running() -> bool:
	return _running


func start() -> void:
	if _running:
		return
	_running = true
	_aborted = false
	_handed_off = false
	_run_id += 1
	_cast.clear()
	_hp_baseline.clear()
	_ally_orders.clear()
	for p in cast_paths:
		_add_cast(get_node_or_null(p))
	for step in steps:
		if step.has("agent"):
			_add_cast(_resolve_agent(step))
	set_physics_process(true)
	_run()


## External kill switch (e.g. a MissionTrigger consumer deciding the beat is
## stale). Same path as the automatic abort: hand off, then report.
func abort(reason: String = "aborted") -> void:
	_abort(reason)


func _run() -> void:
	var my_run: int = _run_id
	for i in range(steps.size()):
		if _aborted or my_run != _run_id:
			return
		var step: Dictionary = steps[i]
		await _execute_step(step)
		if _aborted or my_run != _run_id:
			return
	if not _handed_off:
		_do_hand_off()
	_running = false
	set_physics_process(false)
	completed.emit()


func _abort(reason: String) -> void:
	if not _running or _aborted:
		return
	_aborted = true
	_do_hand_off()
	_running = false
	set_physics_process(false)
	interrupted.emit(reason)


# ---------------------------------------------------------------------------
# Cast watch - the automatic abort-to-handoff (Pillar 3 guarantee).
# ---------------------------------------------------------------------------

func _add_cast(agent: Node) -> void:
	if agent == null or not is_instance_valid(agent) or _cast.has(agent):
		return
	_cast.append(agent)
	var hp: Variant = agent.get("current_hp")
	if hp != null:
		_hp_baseline[agent.get_instance_id()] = int(hp)
	var ally := agent as AllyBase
	if ally != null:
		_ally_orders[agent.get_instance_id()] = {
			"mode": int(ally.order_mode), "pos": ally.order_pos,
		}
	if agent.has_signal("damaged") and not agent.is_connected("damaged", _on_cast_hurt):
		agent.connect("damaged", _on_cast_hurt)
	if agent.has_signal("died") and not agent.is_connected("died", _on_cast_died):
		agent.connect("died", _on_cast_died)


func _disconnect_watch(agent: Node) -> void:
	if agent.has_signal("damaged") and agent.is_connected("damaged", _on_cast_hurt):
		agent.disconnect("damaged", _on_cast_hurt)
	if agent.has_signal("died") and agent.is_connected("died", _on_cast_died):
		agent.disconnect("died", _on_cast_died)


## Default-arg soak: cast signals vary in arity (damaged(amount), died(agent)).
func _on_cast_hurt(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_abort("cast took damage")


func _on_cast_died(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_abort("cast died")


## Poll safety net for agents without a `damaged` signal (EnemyBase/AllyBase
## report hp, not hits) and for combat-target acquisition.
func _physics_process(_delta: float) -> void:
	if not _running or _aborted or _handed_off:
		return
	for agent in _cast:
		if agent == null or not is_instance_valid(agent):
			continue
		var id: int = agent.get_instance_id()
		var hp: Variant = agent.get("current_hp")
		if hp != null and _hp_baseline.has(id):
			if int(hp) < int(_hp_baseline[id]):
				_abort("cast took damage")
				return
			if int(hp) > int(_hp_baseline[id]):
				_hp_baseline[id] = int(hp)  # healed: track up so later hits still read
		var tgt: Variant = agent.get("target")
		if tgt is Node and is_instance_valid(tgt as Node):
			_abort("cast acquired combat target")
			return
		var enemy := agent as EnemyBase
		if enemy != null and enemy.alert_tier == EnemyBase.AlertTier.COMBAT:
			_abort("cast entered COMBAT")
			return


# ---------------------------------------------------------------------------
# Steps.
# ---------------------------------------------------------------------------

func _execute_step(step: Dictionary) -> void:
	var type: String = str(step.get("type", ""))
	match type:
		"wait":
			await _step_wait(step)
		"move":
			await _step_move(step)
		"play_clip":
			_step_play_clip(step)
		"bark":
			_step_bark(step)
		"signal":
			_step_signal(step)
		"spawn_prop":
			_step_spawn_prop(step)
		"hand_off":
			_do_hand_off()
		_:
			push_warning("[ScriptedSequence] unknown step type '%s' - skipped" % type)


func _step_wait(step: Dictionary) -> void:
	var left: float = float(step.get("seconds", 0.0))
	while left > 0.0 and not _aborted:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _step_move(step: Dictionary) -> void:
	var agent := _resolve_agent(step)
	if not _agent_usable(agent):
		return  # dead/gone: skip his beat, never block
	var pos: Vector3 = step.get("to", Vector3.ZERO)
	_order_move(agent, pos, str(step.get("urgency", "suspicious")))
	if not bool(step.get("await_arrival", false)):
		return
	var left: float = float(step.get("timeout", 20.0))
	var radius: float = float(step.get("arrive_radius", 2.5))
	while left > 0.0 and not _aborted:
		if not _agent_usable(agent):
			return
		var a3 := agent as Node3D
		if a3 != null and a3.global_position.distance_to(pos) <= radius:
			return
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	# timeout = keep going; a stuck actor must not stall the beat


## Existing movement only - no new mover (research §6 law).
func _order_move(agent: Node, pos: Vector3, urgency: String) -> void:
	if agent.has_method("sequence_move_to"):
		agent.call("sequence_move_to", pos)
		return
	var ally := agent as AllyBase
	if ally != null:
		ally.set_order(AllyBase.OrderMode.MOVE_TO, pos)
		return
	var enemy := agent as EnemyBase
	if enemy != null:
		# Investigate seam - the hunter-seeding pattern (mission_director.gd:98).
		# Tier only ever escalates here; a sequence never calms anyone down.
		enemy.last_known_target_pos = pos
		enemy.target_last_seen_time = 0.0
		var desired := EnemyBase.AlertTier.ALERT if urgency == "alert" \
			else EnemyBase.AlertTier.SUSPICIOUS
		if enemy.alert_tier < desired:
			enemy._set_tier(desired)
		return
	push_warning("[ScriptedSequence] move: no movement hook on '%s' - skipped" % agent.name)


func _step_play_clip(step: Dictionary) -> void:
	var agent := _resolve_agent(step)
	if not _agent_usable(agent):
		return
	var clip: String = str(step.get("clip", ""))
	if clip.is_empty():
		return
	if agent.has_method("sequence_play_clip"):
		agent.call("sequence_play_clip", clip)
		return
	var ma := agent as ModelActor
	if ma == null:
		var sa: Variant = agent.get("sprite_actor")
		if sa is ModelActor:
			ma = sa as ModelActor
	if ma != null:
		ma.play(clip, true)
	elif agent.has_method("play"):
		agent.call("play", clip)
	else:
		push_warning("[ScriptedSequence] play_clip: no actor on '%s' - skipped" % agent.name)


func _step_bark(step: Dictionary) -> void:
	var line: String = str(step.get("line", ""))
	if line.is_empty():
		return
	var agent: Node = _resolve_agent(step) if step.has("agent") else null
	if agent != null and not _agent_usable(agent):
		return  # dead men don't bark
	print("[SEQ BARK] %s: %s" % [agent.name if agent != null else "-", line])
	sequence_bark.emit(agent, line)


func _step_signal(step: Dictionary) -> void:
	var sig := StringName(str(step.get("name", "")))
	if sig == StringName(""):
		return
	var data: Dictionary = step.get("data", {})
	sequence_signal.emit(sig, data)


func _step_spawn_prop(step: Dictionary) -> void:
	var scene: PackedScene = null
	var sv: Variant = step.get("scene")
	if sv is PackedScene:
		scene = sv as PackedScene
	elif sv is String:
		scene = load(str(sv)) as PackedScene
	if scene == null:
		push_warning("[ScriptedSequence] spawn_prop: no loadable scene - skipped")
		return
	var inst: Node = scene.instantiate()
	if _is_combatant_tree(inst):
		push_warning("[ScriptedSequence] spawn_prop REFUSED '%s' - combatant in prop scene (honest-quiet law: events never conjure fighters)" % scene.resource_path)
		inst.free()
		return
	var parent: Node = get_node_or_null(prop_parent_path)
	if parent == null:
		parent = get_parent()
	parent.add_child(inst)
	var n3 := inst as Node3D
	if n3 != null:
		if step.has("transform"):
			n3.global_transform = step["transform"]
		else:
			if step.has("position"):
				n3.global_position = step["position"]
			if step.has("rotation_deg"):
				n3.rotation_degrees = step["rotation_deg"]


## True if any node in the instanced tree is a combatant. Catches both script
## classes and scene-file persistent groups (applied at instantiate).
func _is_combatant_tree(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is EnemyBase or n is AllyBase:
			return true
		if n.is_in_group("enemies") or n.is_in_group("allies") or n.is_in_group("player"):
			return true
	return false


# ---------------------------------------------------------------------------
# Hand-off - the release back to systemic AI.
# ---------------------------------------------------------------------------

func _do_hand_off() -> void:
	if _handed_off:
		return
	_handed_off = true
	var released: Array[Node] = []
	for agent in _cast:
		if agent == null or not is_instance_valid(agent):
			continue
		released.append(agent)
		_disconnect_watch(agent)
		if agent.has_method("sequence_hand_off"):
			agent.call("sequence_hand_off")
			continue
		var ally := agent as AllyBase
		if ally != null:
			# Restore the order he held before the sequence borrowed him.
			var saved: Dictionary = _ally_orders.get(agent.get_instance_id(), {})
			if not saved.is_empty():
				var order_mode: int = int(saved.get("mode", AllyBase.OrderMode.FOLLOW))
				var order_pos: Vector3 = saved.get("pos", Vector3.ZERO)
				ally.set_order(order_mode as AllyBase.OrderMode, order_pos)
		# EnemyBase: nothing to restore - his FSM/perception were never touched.
	handed_off.emit(released)


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------

func _resolve_agent(step: Dictionary) -> Node:
	var av: Variant = step.get("agent")
	if av == null:
		return null
	if av is NodePath:
		return get_node_or_null(av)
	return get_node_or_null(NodePath(str(av)))


func _agent_usable(agent: Node) -> bool:
	if agent == null or not is_instance_valid(agent):
		return false
	if agent.has_method("is_dead") and bool(agent.call("is_dead")):
		return false
	return true
