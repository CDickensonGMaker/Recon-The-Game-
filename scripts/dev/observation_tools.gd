class_name ObservationTools
extends Node

## DEV-ONLY AI observation instrument. Drop this node into a dev scene (the AI arena or a
## populated patrol world) and it gives: a free-fly OBSERVER camera that freezes/hides the
## player and makes the AI BLIND to the observer (so watching never changes behavior); a
## floating STATE OVERLAY over every live agent (goal/state/target/suppression/tier); and
## TIME CONTROLS (SimClock day-speed + Engine.time_scale motion-speed). Guarded by
## OS.is_debug_build() so it cannot act in a shipping player build.
##
## Keys (debug builds only): O observer on/off · I overlay on/off · \ SimClock pause ·
## [ / ] motion slower/faster (Engine.time_scale) · - / = day slower/faster (SimClock ratio) · 0 reset time.
##
## This is a SEPARATE dev instrument from the field-mark verb's deleted floating Label3D —
## it does not revive that; it reads the same fields the arena's own debug overlay reads.

const FLY_SPEED: float = 14.0
const LOOK_SENS: float = 0.0025
const OVERLAY_HZ: float = 10.0

var _observing: bool = false
var _overlay_on: bool = false
var _player: CharacterBody3D = null
var _ghost_cam: Camera3D = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _player_was_in_group: bool = false
var _overlay_labels: Dictionary = {}   ## agent instance_id -> Label3D
var _overlay_t: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		set_process_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).keycode:
		KEY_O:
			_toggle_observer()
		KEY_I:
			_toggle_overlay()
		KEY_BACKSLASH:
			SimClock.paused = not SimClock.paused
		KEY_BRACKETLEFT:
			Engine.time_scale = maxf(0.1, Engine.time_scale * 0.5)
		KEY_BRACKETRIGHT:
			Engine.time_scale = minf(8.0, Engine.time_scale * 2.0)
		KEY_MINUS:
			SimClock.real_to_sim_ratio = maxf(1.0, SimClock.real_to_sim_ratio * 0.5)
		KEY_EQUAL:
			SimClock.real_to_sim_ratio = minf(3600.0, SimClock.real_to_sim_ratio * 2.0)
		KEY_0:
			Engine.time_scale = 1.0
			SimClock.paused = false


func _input(event: InputEvent) -> void:
	# Free-look while observing: consume mouse motion so it does not also drive the player.
	if _observing and _ghost_cam != null and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_ghost_cam.rotation.y -= mm.relative.x * LOOK_SENS
		_ghost_cam.rotation.x = clampf(_ghost_cam.rotation.x - mm.relative.y * LOOK_SENS, -1.5, 1.5)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _observing and _ghost_cam != null:
		_fly(delta)
	if _overlay_on:
		_overlay_t += delta
		if _overlay_t >= 1.0 / OVERLAY_HZ:
			_overlay_t = 0.0
			_update_overlay()


# ---------------- OBSERVER MODE ----------------

func _toggle_observer() -> void:
	if _observing:
		_deactivate_observer()
	else:
		_activate_observer()


func _activate_observer() -> void:
	_player = GameManager.player as CharacterBody3D
	if _player == null or not is_instance_valid(_player):
		return
	_observing = true
	# The ghost camera starts where the player was looking, so the view is continuous.
	_ghost_cam = Camera3D.new()
	add_child(_ghost_cam)
	var pcam := _player.get_node_or_null("Head/Camera3D") as Camera3D
	if pcam != null:
		_ghost_cam.global_transform = pcam.global_transform
	else:
		_ghost_cam.global_position = _player.global_position + Vector3(0, 2, 0)
	_ghost_cam.current = true
	# Freeze + hide the player and make the AI blind to it.
	_player.set_physics_process(false)
	_player.visible = false
	_player_was_in_group = _player.is_in_group("player")
	if _player_was_in_group:
		_player.remove_from_group("player")   # no new acquisition of the observer
	_clear_player_locks()                     # drop any existing lock on the observer
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _deactivate_observer() -> void:
	_observing = false
	if _ghost_cam != null and is_instance_valid(_ghost_cam):
		_ghost_cam.queue_free()
	_ghost_cam = null
	if _player != null and is_instance_valid(_player):
		_player.set_physics_process(true)
		_player.visible = true
		if _player_was_in_group and not _player.is_in_group("player"):
			_player.add_to_group("player")
		var pcam := _player.get_node_or_null("Head/Camera3D") as Camera3D
		if pcam != null:
			pcam.current = true
	Input.mouse_mode = _prev_mouse_mode


## Enemies that had eyes on the player lose the lock the frame observation begins. The
## group-removal above stops re-acquisition; enemy_base.target is public (enemy_base.gd:56),
## so no invasive targeting change is needed.
func _clear_player_locks() -> void:
	for e in AgentRegistry.enemies:
		if e != null and is_instance_valid(e) and e.get("target") == _player:
			e.set("target", null)


func _fly(delta: float) -> void:
	var basis := _ghost_cam.global_transform.basis
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= basis.z
	if Input.is_key_pressed(KEY_S): dir += basis.z
	if Input.is_key_pressed(KEY_A): dir -= basis.x
	if Input.is_key_pressed(KEY_D): dir += basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	var boost: float = 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	if dir.length() > 0.01:
		_ghost_cam.global_position += dir.normalized() * FLY_SPEED * boost * delta


# ---------------- STATE OVERLAY ----------------

func _toggle_overlay() -> void:
	_overlay_on = not _overlay_on
	if not _overlay_on:
		for key in _overlay_labels:
			var l: Label3D = _overlay_labels[key]
			if is_instance_valid(l):
				l.queue_free()
		_overlay_labels.clear()


func _update_overlay() -> void:
	var live: Dictionary = {}
	for roster in [AgentRegistry.enemies, AgentRegistry.allies, AgentRegistry.civilians]:
		for a in roster:
			if a == null or not is_instance_valid(a) or not (a is Node3D):
				continue
			var agent := a as Node3D
			live[agent.get_instance_id()] = true
			var lbl := _label_for(agent)
			lbl.text = _agent_readout(agent)
	# Reap labels whose agent is gone.
	for key in _overlay_labels.keys():
		if not live.has(key):
			var l: Label3D = _overlay_labels[key]
			if is_instance_valid(l):
				l.queue_free()
			_overlay_labels.erase(key)


func _label_for(agent: Node3D) -> Label3D:
	var key: int = agent.get_instance_id()
	if _overlay_labels.has(key) and is_instance_valid(_overlay_labels[key]):
		return _overlay_labels[key]
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0006
	l.font_size = 22
	l.outline_size = 6
	l.position = Vector3(0, 2.3, 0)
	agent.add_child(l)
	_overlay_labels[key] = l
	return l


## Read what the agent is "thinking" defensively — the three body classes expose different
## fields, so pull each via get() and format what is present (a missing field is just absent).
func _agent_readout(agent: Node3D) -> String:
	if agent.has_method("is_dead") and bool(agent.call("is_dead")):
		return "DOWN"
	var parts: PackedStringArray = PackedStringArray()
	var state: Variant = agent.get("current_state")
	if state != null:
		var sk: Array = Enums.AIState.keys()
		parts.append(str(sk[int(state)]) if int(state) >= 0 and int(state) < sk.size() else "st:%d" % int(state))
	var goal: Variant = agent.get("current_goal")
	if goal != null:
		var gk: Array = Enums.AIGoal.keys()
		parts.append(str(gk[int(goal)]) if int(goal) >= 0 and int(goal) < gk.size() else "gl:%d" % int(goal))
	var order: Variant = agent.get("order_mode")
	if order != null:
		parts.append("ord:%d" % int(order))
	var tier: Variant = agent.get("alert_tier")
	if tier != null:
		parts.append("tier:%d" % int(tier))
	var sup: Variant = agent.get("suppression_level")
	if sup != null:
		parts.append("sup:%.1f" % float(sup))
	var tgt: Variant = agent.get("target")
	if tgt != null and is_instance_valid(tgt as Node):
		parts.append("TGT")
	return "\n".join(parts) if parts.size() > 0 else agent.name
