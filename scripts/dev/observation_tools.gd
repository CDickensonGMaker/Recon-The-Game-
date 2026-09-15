class_name ObservationTools
extends Node

## DEV-ONLY AI observation instrument - THE OBSERVATORY (council 2026-09-14, ruling 7).
## Drop this node into a dev scene, or let GameFlow attach it on F9 in the live world, and it
## gives: a free-fly OBSERVER camera that freezes/hides the player and makes the AI BLIND to
## the observer; a per-agent STATE OVERLAY (state/tier/LOD ring/awareness/last-known/last
## noise/civilian action + village band); a LINE LAYER (sight cone, target line, last-known,
## noise circles incl. the player's own, witness-chain arrows, the informer's fix); a SIDE
## PANE for ONE selected man - his snapshot() in full with the ten-deep decision ring and the
## census's own STUCK reason - and a LEDGER pane (every village's deeds with causes and band,
## FieldDirector facts, taskings). Guarded by OS.is_debug_build(); nothing is built until
## toggled, toggling off frees it all, and the _process gate is the first line.
##
## Keys, dev rooms (live_world = false): O observer · I overlay · \ SimClock pause ·
## [ ] motion slower/faster · - = day slower/faster · 0 reset.
## Keys, live world (live_world = true; GameFlow owns F8/H/G/O/I/U): F9 observatory on/off ·
## F7 observer camera · F6 pane tab (MAN / LEDGER) · Tab / Shift+Tab cycle the nearest 12 ·
## left-click select (observer camera, mouse free; hold right button to look) ·
## Backspace clear selection. The time keys above work in both.
##
## This is a SEPARATE dev instrument from the field-mark verb's deleted floating Label3D -
## it does not revive that; it reads the same fields the arena's own debug overlay reads.

const FLY_SPEED: float = 14.0
const LOOK_SENS: float = 0.0025
const OVERLAY_HZ: float = 10.0
const PANE_HZ: float = 5.0
const LABEL_RANGE_M: float = 120.0
const NOISE_RING_S: float = 2.0
const CHAIN_SHOW_S: float = 8.0
const LAST_KNOWN_SHOW_S: float = 30.0
const CYCLE_N: int = 12
const PICK_PX: float = 40.0
const PANE_W: float = 620.0

const DecisionRingS := preload("res://scripts/dev/decision_ring.gd")
const HmLedgerS := preload("res://scripts/world/hm_ledger.gd")
const NOISE_NAMES: PackedStringArray = ["STEPS", "SPRINT", "GUNSHOT", "SUPPRESSED",
	"EXPLOSION", "VOICE", "IMPACT"]

## Set by GameFlow (live world): O/I are its skip-time keys, so the layout above switches.
var live_world: bool = false

var _observing: bool = false
var _overlay_on: bool = false
var _player: CharacterBody3D = null
var _ghost_cam: Camera3D = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _player_was_in_group: bool = false
var _overlay_labels: Dictionary = {}   ## agent instance_id -> Label3D
var _overlay_t: float = 0.0
var _look_held: bool = false

## Observatory parts (exist only while _overlay_on).
var _lines: MeshInstance3D = null
var _line_mesh: ImmediateMesh = null
var _pane: CanvasLayer = null
var _pane_text: RichTextLabel = null
var _pane_title: Label = null
var _pane_tab: int = 0            ## 0 = MAN, 1 = LEDGER
var _pane_t: float = 0.0
var _selected: Node3D = null
var _cycle_i: int = -1
## Noises heard on NoiseBus while on: [{pos, radius, ms, type, team}] - drawn at the SOURCE.
var _noises: Array[Dictionary] = []
## The census's classifier (tools/ ships in no export; null-guarded).
var _census: GDScript = null


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		set_process_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventMouseButton and _overlay_on:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			_pick_at(mb.position)
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_O:
			if not live_world:
				_toggle_observer()
		KEY_I:
			if not live_world:
				_toggle_overlay()
		KEY_F9:
			if live_world:
				toggle_observatory()
		KEY_F7:
			if live_world:
				_toggle_observer()
		KEY_F6:
			if _overlay_on:
				_pane_tab = (_pane_tab + 1) % 2
				_update_pane()
		KEY_TAB:
			if _overlay_on:
				_cycle(-1 if key.shift_pressed else 1)
				get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			if _overlay_on:
				_selected = null
				_cycle_i = -1
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
	if not _observing or _ghost_cam == null:
		return
	# Observer look: captured mouse in dev rooms; in the live world the mouse stays free for
	# picking and the RIGHT button holds the look.
	if live_world and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_look_held = (event as InputEventMouseButton).pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look_held else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		var mm := event as InputEventMouseMotion
		_ghost_cam.rotation.y -= mm.relative.x * LOOK_SENS
		_ghost_cam.rotation.x = clampf(_ghost_cam.rotation.x - mm.relative.y * LOOK_SENS, -1.5, 1.5)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _observing and not _overlay_on:
		return
	if _observing and _ghost_cam != null:
		_fly(delta)
	if _overlay_on:
		_overlay_t += delta
		if _overlay_t >= 1.0 / OVERLAY_HZ:
			_overlay_t = 0.0
			_update_overlay()
			_update_lines()
		_pane_t += delta
		if _pane_t >= 1.0 / PANE_HZ:
			_pane_t = 0.0
			_update_pane()


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if live_world else Input.MOUSE_MODE_CAPTURED
	_look_held = false


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


# ---------------- THE OBSERVATORY (overlay + lines + pane) ----------------

## The one switch GameFlow and the tool scene call. Everything below exists only while on.
func toggle_observatory() -> void:
	_toggle_overlay()


func set_observatory(on: bool) -> void:
	if on != _overlay_on:
		_toggle_overlay()


func is_on() -> bool:
	return _overlay_on


func _toggle_overlay() -> void:
	_overlay_on = not _overlay_on
	if _overlay_on:
		_build_parts()
		if not NoiseBus.noise_emitted.is_connected(_on_noise):
			NoiseBus.noise_emitted.connect(_on_noise)
		_overlay_t = 1.0
		_pane_t = 1.0
		return
	if NoiseBus.noise_emitted.is_connected(_on_noise):
		NoiseBus.noise_emitted.disconnect(_on_noise)
	_noises.clear()
	_selected = null
	_cycle_i = -1
	for key in _overlay_labels:
		var l: Label3D = _overlay_labels[key]
		if is_instance_valid(l):
			l.queue_free()
	_overlay_labels.clear()
	if _lines != null and is_instance_valid(_lines):
		_lines.queue_free()
	_lines = null
	_line_mesh = null
	if _pane != null and is_instance_valid(_pane):
		_pane.queue_free()
	_pane = null
	_pane_text = null
	_pane_title = null


func _build_parts() -> void:
	_line_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _line_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines.material_override = mat
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	_lines.top_level = true
	_lines.global_transform = Transform3D.IDENTITY

	_pane = CanvasLayer.new()
	_pane.layer = 100
	add_child(_pane)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.anchor_left = 1.0
	panel.offset_left = -PANE_W
	panel.offset_right = 0.0
	panel.offset_top = 8.0
	panel.offset_bottom = -8.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.03, 0.82)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	_pane.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	_pane_title = Label.new()
	_pane_title.text = "OBSERVATORY - DEV, not a readout"
	_pane_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	_pane_title.add_theme_font_size_override("font_size", 14)
	col.add_child(_pane_title)
	_pane_text = RichTextLabel.new()
	_pane_text.bbcode_enabled = true
	_pane_text.scroll_active = true
	_pane_text.fit_content = false
	_pane_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane_text.add_theme_font_size_override("normal_font_size", 12)
	_pane_text.add_theme_font_size_override("mono_font_size", 12)
	col.add_child(_pane_text)
	_census = load("res://tools/probe_npc_census.gd") as GDScript


func _on_noise(type: int, position: Vector3, radius: float, source_team: int, _source: Node) -> void:
	_noises.append({"pos": position, "radius": radius, "ms": Time.get_ticks_msec(),
		"type": type, "team": source_team})
	while _noises.size() > 64:
		_noises.remove_at(0)


func _camera() -> Camera3D:
	if _observing and _ghost_cam != null:
		return _ghost_cam
	return get_viewport().get_camera_3d()


func _live_agents() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for roster in [AgentRegistry.enemies, AgentRegistry.allies, AgentRegistry.civilians]:
		for a in roster:
			if a == null or not is_instance_valid(a) or not (a is Node3D):
				continue
			if not (a as Node3D).is_inside_tree():
				continue
			out.append(a as Node3D)
	return out


# ---------------- SELECTION ----------------

func _nearest(n: int) -> Array[Node3D]:
	var cam: Camera3D = _camera()
	var from: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	var all: Array[Node3D] = _live_agents()
	all.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	if all.size() > n:
		all.resize(n)
	return all


func _cycle(step: int) -> void:
	var near: Array[Node3D] = _nearest(CYCLE_N)
	if near.is_empty():
		_selected = null
		return
	var at: int = near.find(_selected) if _selected != null else -1
	_cycle_i = posmod(at + step, near.size()) if at >= 0 else (0 if step > 0 else near.size() - 1)
	_selected = near[_cycle_i]
	_update_pane()


## Screen-space pick: the agent whose head projects nearest the click, under PICK_PX.
func _pick_at(px: Vector2) -> void:
	var cam: Camera3D = _camera()
	if cam == null:
		return
	var best: Node3D = null
	var best_d: float = PICK_PX
	for a in _live_agents():
		var head: Vector3 = a.global_position + Vector3.UP * 1.2
		if cam.is_position_behind(head):
			continue
		var d: float = cam.unproject_position(head).distance_to(px)
		if d < best_d:
			best_d = d
			best = a
	if best != null:
		_selected = best
		_update_pane()


func selected() -> Node3D:
	return _selected


func select(agent: Node3D) -> void:
	_selected = agent


# ---------------- LABELS ----------------

func _update_overlay() -> void:
	var live: Dictionary = {}
	var cam: Camera3D = _camera()
	var eye: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	for agent in _live_agents():
		var far: bool = agent.global_position.distance_to(eye) > LABEL_RANGE_M
		if far and agent != _selected:
			continue
		live[agent.get_instance_id()] = true
		var lbl := _label_for(agent)
		lbl.text = _agent_readout(agent)
		lbl.modulate = _tier_colour(agent)
		lbl.outline_modulate = Color(0.9, 0.9, 0.2) if agent == _selected else Color.BLACK
	# Reap labels whose agent is gone or out of range.
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


func _tier_colour(agent: Node3D) -> Color:
	if agent is EnemyBase:
		match int(agent.get("alert_tier")):
			0: return Color(0.75, 0.75, 0.75)
			1: return Color(1.0, 0.95, 0.3)
			2: return Color(1.0, 0.6, 0.2)
			_: return Color(1.0, 0.3, 0.3)
	if agent is Civilian:
		match int(agent.get("state")):
			0: return Color.WHITE
			1: return Color(0.4, 1.0, 1.0)
			2: return Color(0.5, 0.6, 1.0)
			_: return Color(1.0, 0.4, 1.0)
	return Color(0.6, 1.0, 0.6)


static func _bar(v: float) -> String:
	var n: int = clampi(int(round(clampf(v, 0.0, 1.0) * 8.0)), 0, 8)
	return "[" + "#".repeat(n) + "-".repeat(8 - n) + "]"


## Read what the agent is "thinking" - cheap field reads only (snapshot() is for the pane).
func _agent_readout(agent: Node3D) -> String:
	if agent.has_method("is_dead") and bool(agent.call("is_dead")):
		return "DOWN"
	var parts: PackedStringArray = PackedStringArray()
	var now_ms: float = float(Time.get_ticks_msec())
	if agent is Civilian:
		var c := agent as Civilian
		var band: String = "-"
		if c.village_center != Vector3.ZERO:
			band = String(CampaignState.hearts.band(HmLedgerS.place_key(c.village_center)))
		parts.append("%s %s%s" % [c.occupation, String(c.name), " *" if c.is_informer else ""])
		parts.append("%s  %s>%s  %s" % [String(Civilian.STATE_NAMES[int(c.state)]),
			String(c.scheduled_action()), String(c.active_action), band])
		parts.append("lod %s%s" % [["FULL", "NEAR", "FAR"][clampi(c.lod_tier, 0, 2)],
			" ASLEEP" if (c.has_meta("suspended") or not c.is_physics_processing()) else ""])
		if c._last_noise_ms > 0.0 and c._last_noise_type >= 0 and c._last_noise_type < NOISE_NAMES.size():
			parts.append("heard %s %.0fs" % [NOISE_NAMES[c._last_noise_type], (now_ms - c._last_noise_ms) * 0.001])
		return "\n".join(parts)
	if agent is EnemyBase:
		var e := agent as EnemyBase
		parts.append("%s %s" % [String(e.enemy_data.id) if e.enemy_data != null else "enemy", String(e.name)])
		parts.append("%s / %s" % [String(DecisionRingS.state_name(int(e.current_state))),
			String(DecisionRingS.goal_name(int(e.current_goal)))])
		var ring: String = "ASLEEP" if (e.has_meta("suspended") or not e.is_physics_processing()) \
			else ("FAR" if e.ai_tier == AILod.Tier.FAR else "NEAR")
		parts.append("%s  %s  aw %s" % [String(EnemyBase.TIER_NAMES[int(e.alert_tier)]), ring, _bar(e.awareness)])
		if e.target != null and is_instance_valid(e.target):
			parts.append("TGT %s %.0fm" % [String(e.target.name), e.global_position.distance_to(e.target.global_position)])
		elif e.last_known_target_pos != Vector3.ZERO and e.target_last_seen_time < LAST_KNOWN_SHOW_S:
			parts.append("lk %.0fm %.0fs" % [e.global_position.distance_to(e.last_known_target_pos), e.target_last_seen_time])
		if e._last_noise_ms > 0.0 and e._last_noise_type >= 0 and e._last_noise_type < NOISE_NAMES.size():
			parts.append("heard %s %.0fs" % [NOISE_NAMES[e._last_noise_type], (now_ms - e._last_noise_ms) * 0.001])
		if e.suppression_level > 0.05:
			parts.append("sup %.2f" % e.suppression_level)
		return "\n".join(parts)
	var state: Variant = agent.get("current_state")
	if state != null:
		parts.append(String(DecisionRingS.state_name(int(state))))
	var order: Variant = agent.get("order_mode")
	if order != null:
		parts.append("ord:%d" % int(order))
	var sup: Variant = agent.get("suppression_level")
	if sup != null and float(sup) > 0.05:
		parts.append("sup:%.1f" % float(sup))
	var tgt: Variant = agent.get("target")
	if tgt != null and is_instance_valid(tgt as Node):
		parts.append("TGT")
	return "\n".join(parts) if parts.size() > 0 else agent.name


# ---------------- LINE LAYER ----------------

func _seg(a: Vector3, b: Vector3, c: Color) -> void:
	_line_mesh.surface_set_color(c)
	_line_mesh.surface_add_vertex(a)
	_line_mesh.surface_set_color(c)
	_line_mesh.surface_add_vertex(b)


func _dashed(a: Vector3, b: Vector3, c: Color, dash: float = 1.0) -> void:
	var length: float = a.distance_to(b)
	if length < 0.01:
		return
	var dir: Vector3 = (b - a) / length
	var t: float = 0.0
	while t < length:
		var t2: float = minf(t + dash, length)
		_seg(a + dir * t, a + dir * t2, c)
		t += dash * 2.0


func _circle(center: Vector3, r: float, c: Color, segs: int = 24) -> void:
	var prev: Vector3 = center + Vector3(r, 0.0, 0.0)
	for i in range(1, segs + 1):
		var ang: float = TAU * float(i) / float(segs)
		var p: Vector3 = center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		_seg(prev, p, c)
		prev = p


func _arrow(a: Vector3, b: Vector3, c: Color) -> void:
	_seg(a, b, c)
	var dir: Vector3 = (b - a)
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	_seg(b, b - dir * 0.8 + side * 0.4, c)
	_seg(b, b - dir * 0.8 - side * 0.4, c)


func _cone(e: EnemyBase, c: Color) -> void:
	var cap: float = e._sight_cap(e.global_position + e.facing_dir * 10.0)
	var half: float = deg_to_rad(e._fov_deg() * 0.5)
	var o: Vector3 = e.global_position + Vector3.UP * 1.5
	var f: Vector3 = Vector3(e.facing_dir.x, 0.0, e.facing_dir.z).normalized()
	if f.length() < 0.5:
		f = Vector3.FORWARD
	var prev: Vector3 = o + f.rotated(Vector3.UP, -half) * cap
	_seg(o, prev, c)
	for i in range(1, 13):
		var p: Vector3 = o + f.rotated(Vector3.UP, -half + half * 2.0 * float(i) / 12.0) * cap
		_seg(prev, p, c)
		prev = p
	_seg(o, prev, c)


func _update_lines() -> void:
	if _line_mesh == null:
		return
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var now_ms: float = float(Time.get_ticks_msec())
	var cam: Camera3D = _camera()
	var eye: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	var any: bool = false
	for agent in _live_agents():
		if agent.global_position.distance_to(eye) > LABEL_RANGE_M and agent != _selected:
			continue
		var o: Vector3 = agent.global_position + Vector3.UP * 1.0
		if agent is EnemyBase:
			var e := agent as EnemyBase
			if e.current_state == Enums.AIState.DEAD:
				continue
			any = true
			var chain_fresh: bool = e._chain_ms > 0.0 and (now_ms - e._chain_ms) * 0.001 < CHAIN_SHOW_S
			if e == _selected or chain_fresh:
				_cone(e, Color(1.0, 1.0, 1.0, 0.35) if e == _selected else Color(1.0, 0.4, 1.0, 0.25))
			if e.target != null and is_instance_valid(e.target):
				_seg(o, (e.target as Node3D).global_position + Vector3.UP * 1.0, Color(1.0, 0.2, 0.2))
			elif e.last_known_target_pos != Vector3.ZERO and e.target_last_seen_time < LAST_KNOWN_SHOW_S:
				_dashed(o, e.last_known_target_pos + Vector3.UP * 0.5, Color(1.0, 0.9, 0.2))
				_circle(e.last_known_target_pos + Vector3.UP * 0.1, 0.6, Color(1.0, 0.9, 0.2))
			if e._last_noise_ms > 0.0 and (now_ms - e._last_noise_ms) * 0.001 < 5.0:
				_circle(e._last_noise_pos + Vector3.UP * 0.1, 1.2, Color(0.3, 0.9, 1.0))
				_dashed(o, e._last_noise_pos + Vector3.UP * 0.1, Color(0.3, 0.9, 1.0, 0.6), 0.5)
			if chain_fresh:
				_arrow(e._chain_from + Vector3.UP * 0.5, o, Color(1.0, 0.4, 1.0))
			if e == _selected:
				var s: Dictionary = e.snapshot()
				var dest: Vector3 = s.get("destination", Vector3.ZERO)
				if dest != Vector3.ZERO:
					_dashed(o, dest + Vector3.UP * 0.2, Color(0.4, 1.0, 0.4), 0.5)
					_circle(dest + Vector3.UP * 0.1, 0.4, Color(0.4, 1.0, 0.4))
		elif agent is Civilian:
			var c := agent as Civilian
			if c.state == Civilian.CivState.GONE:
				continue
			any = true
			if c.is_informer and c._saw_player_at != Vector3.ZERO:
				_arrow(o, c._saw_player_at + Vector3.UP * 0.5, Color(1.0, 0.6, 0.1))
			if c._last_noise_ms > 0.0 and (now_ms - c._last_noise_ms) * 0.001 < 5.0:
				_dashed(o, c._last_noise_pos + Vector3.UP * 0.1, Color(0.3, 0.9, 1.0, 0.6), 0.5)
			if c == _selected:
				_dashed(o, c._wander_target + Vector3.UP * 0.2, Color(0.4, 1.0, 0.4), 0.5)
				if c.working_point_pos != Vector3.ZERO:
					_circle(c.working_point_pos + Vector3.UP * 0.1, 0.4, Color(0.4, 1.0, 0.4))
			if c.village_center != Vector3.ZERO and c == _selected:
				var band: StringName = CampaignState.hearts.band(HmLedgerS.place_key(c.village_center))
				var bc: Color = Color(0.3, 1.0, 0.3) if band == HmLedgerS.BAND_QUIET \
					else (Color(1.0, 0.8, 0.2) if band == HmLedgerS.BAND_WARY else Color(1.0, 0.2, 0.2))
				_circle(c.village_center + Vector3.UP * 0.3, 12.0, bc, 48)
	# Noises at their SOURCE (the player's own steps and shots included).
	var keep: Array[Dictionary] = []
	for n in _noises:
		var age: float = (now_ms - float(n.ms)) * 0.001
		if age > NOISE_RING_S:
			continue
		keep.append(n)
		any = true
		var col: Color = Color(1.0, 1.0, 0.4, 1.0 - age / NOISE_RING_S) if int(n.team) == 0 \
			else Color(0.4, 0.8, 1.0, 1.0 - age / NOISE_RING_S)
		var pos: Vector3 = n.pos
		_circle(pos + Vector3.UP * 0.2, float(n.radius) * (0.3 + 0.7 * age / NOISE_RING_S), col, 40)
	_noises = keep
	if not any:
		# An empty surface is a Godot error; draw one degenerate segment instead.
		_seg(eye + Vector3.DOWN * 1000.0, eye + Vector3.DOWN * 1000.0, Color.TRANSPARENT)
	_line_mesh.surface_end()


# ---------------- SIDE PANE ----------------

func _update_pane() -> void:
	if _pane_text == null:
		return
	if _pane_tab == 1:
		_pane_title.text = "OBSERVATORY - LEDGER (DEV - not a readout)   F6 man · Tab cycle · F9 off"
		_pane_text.text = "[code]%s[/code]" % ledger_text()
		return
	_pane_title.text = "OBSERVATORY - MAN (DEV)   F6 ledger · Tab/Shift+Tab cycle · click · Backspace clear · F9 off"
	if _selected == null or not is_instance_valid(_selected) or not _selected.is_inside_tree():
		_selected = null
		var near: Array[Node3D] = _nearest(CYCLE_N)
		var rows: PackedStringArray = PackedStringArray()
		rows.append("no man selected - Tab cycles the nearest %d:" % CYCLE_N)
		for a in near:
			rows.append("  %s" % _agent_readout(a).replace("\n", " | "))
		_pane_text.text = "[code]%s[/code]" % "\n".join(rows)
		return
	_pane_text.text = "[code]%s[/code]" % man_text(_selected)


## The selected man in full - "what is this man thinking and why".
func man_text(agent: Node3D) -> String:
	var rows: PackedStringArray = PackedStringArray()
	rows.append("sim %s   x%.0f   %s" % [DecisionRingS.clock(DecisionRingS.now_hours()),
		SimClock.real_to_sim_ratio, "PAUSED" if SimClock.paused else "running"])
	if not agent.has_method("snapshot"):
		rows.append(_agent_readout(agent))
		return "\n".join(rows)
	var s: Dictionary = agent.call("snapshot")
	var p: Vector3 = agent.global_position
	if String(s.kind) == "enemy":
		rows.append("%s  %s  #%s   at (%+.0f, %+.0f, %+.0f)" % [s.archetype, s.name, str(s.squad), p.x, p.y, p.z])
		rows.append("STATE   %-14s goal %-16s (+%.0f s)" % [s.state, s.goal, float(s.goal_timer)])
		rows.append("TIER    %-11s lod %s%s   hot slot %s   body %s" % [s.tier, s.lod,
			"  ASLEEP" if bool(s.suspended) else "", str(s.hot_slot), "hot" if bool(s.body_hot) else "gated"])
		rows.append("SENSES  awareness %s %.2f   contact_conf %.2f   LOS %s   sight cap %.0f m" % [
			_bar(float(s.awareness)), float(s.awareness), float(s.contact_conf), str(s.los), float(s.sight_cap)])
		rows.append("TARGET  %s   last known (%+.0f, %+.0f) %.0f m, %.1f s ago   squad lk (%+.0f, %+.0f)" % [
			s.target if String(s.target) != "" else "none", (s.last_known as Vector3).x, (s.last_known as Vector3).z,
			p.distance_to(s.last_known), float(s.last_known_age), (s.squad_last_known as Vector3).x, (s.squad_last_known as Vector3).z])
		rows.append("HEARD   %s" % _noise_line(s, p))
		rows.append("DEST    %s (%+.0f, %+.0f) %.1f m   nav %s   box %s   off-mesh %.2f m" % [
			s.dest_kind, (s.destination as Vector3).x, (s.destination as Vector3).z, p.distance_to(s.destination),
			("finished" if bool(s.get("nav_finished", false)) else "%d pts" % int(s.get("nav_path_pts", 0))) if s.has("nav_finished") else "no agent",
			str(s.get("nav_box", -9)), float(s.get("off_mesh_m", -1.0))])
		rows.append("BODY    hp %d/%d   supp %.2f   threat %.2f%s%s%s%s" % [int(s.hp), int(s.max_hp),
			float(s.suppression), float(s.threat), "   DOWNED" if bool(s.downed) else "",
			"   crippled" if bool(s.crippled) else "", "   spider hole" if bool(s.spider) else "",
			"   infiltrator" if bool(s.infiltrator) else ""])
		rows.append("JOB     camp role %s   work clip %s   file slot %d   doctrine %s" % [
			s.camp_role, s.work_clip if String(s.work_clip) != "" else "-", int(s.file_slot), s.doctrine])
		rows.append("DATA    %s" % s.data_path)
		rows.append("WAITING reaction %s (%.2f s)   unstick %.1f s / %d flips   stuck %.1f s   intent %.2f m/s actual %.2f" % [
			"done" if bool(s.has_reacted) else "pending", float(s.reaction_timer), float(s.unstick_t),
			int(s.unstick_flips), float(s.stuck_t), float(s.move_intent), float(s.speed)])
		rows.append("LEGS    %s" % s.legs)
		rows.append("STUCK   %s" % enemy_stuck_line(s))
		if float(s.chain_age) >= 0.0 and float(s.chain_age) < 60.0:
			rows.append("CHAIN   word came from (%+.0f, %+.0f) %.0f s ago" % [(s.chain_from as Vector3).x, (s.chain_from as Vector3).z, float(s.chain_age)])
	else:
		rows.append("%s %s  role %s  village band %s   at (%+.0f, %+.0f, %+.0f)" % [s.occupation, s.name, s.role, s.band, p.x, p.y, p.z])
		rows.append("STATE   %-10s schedule %s -> active %s   clip %s" % [s.state, s.scheduled, s.active, s.clip])
		rows.append("LOD     %s%s   garrison %s   informer %s%s" % [s.lod, "  ASLEEP" if bool(s.suspended) else "",
			str(s.garrison), str(s.informer), ("  clock %.0f s" % float(s.inform_clock)) if float(s.inform_clock) >= 0.0 else ""])
		rows.append("DEST    (%+.0f, %+.0f) %.1f m   post (%+.0f, %+.0f) %.1f m   home %.1f m   nav %s   box %s   off-mesh %.2f m" % [
			(s.destination as Vector3).x, (s.destination as Vector3).z, p.distance_to(s.destination),
			(s.working_point as Vector3).x, (s.working_point as Vector3).z, p.distance_to(s.working_point), p.distance_to(s.home),
			("finished" if bool(s.get("nav_finished", false)) else "%d pts" % int(s.get("nav_path_pts", 0))) if s.has("nav_finished") else "no agent",
			str(s.get("nav_box", -9)), float(s.get("off_mesh_m", -1.0))])
		rows.append("HEARD   %s" % _noise_line(s, p))
		rows.append("JOB     puppet %s   crew driver %s   boarding %s   group %d" % [str(s.puppet),
			s.crew_driver if String(s.crew_driver) != "" else "-", str(s.boarding), int(s.group_id)])
		rows.append("WAITING stand_to_held %s   unstick %.1f s / %d flips   stuck %.1f s   wanted %.2f m/s actual %.2f" % [
			str(s.stand_to_held), float(s.unstick_t), int(s.unstick_flips), float(s.stuck_t), float(s.want_speed), float(s.speed)])
		if bool(s.informer):
			rows.append("FIX     saw the player at (%+.0f, %+.0f)" % [(s.saw_player_at as Vector3).x, (s.saw_player_at as Vector3).z])
		rows.append("STUCK   %s" % stuck_line(agent))
	rows.append("LOG     (last %d, sim time; newest last)" % DecisionRingS.RING_N)
	var ring: PackedStringArray = s.ring
	if ring.is_empty():
		rows.append("  (no transitions yet)")
	for line in ring:
		rows.append("  %s" % line)
	return "\n".join(rows)


func _noise_line(s: Dictionary, p: Vector3) -> String:
	var t: int = int(s.last_noise_type)
	if t < 0 or float(s.last_noise_age) < 0.0:
		return "nothing yet"
	var np: Vector3 = s.last_noise_pos
	return "%s at (%+.0f, %+.0f) %.0f m, %.1f s ago" % [NOISE_NAMES[t] if t < NOISE_NAMES.size() else str(t),
		np.x, np.z, p.distance_to(np), float(s.last_noise_age)]


## THE CENSUS'S OWN WORDS: tools/probe_npc_census.gd classify() - one classifier, two readers.
func stuck_line(agent: Node3D) -> String:
	if not (agent is Civilian):
		return "-"
	if _census == null:
		_census = load("res://tools/probe_npc_census.gd") as GDScript
	if _census == null:
		return "(census classifier absent in this build)"
	var space: PhysicsDirectSpaceState3D = agent.get_world_3d().direct_space_state
	var c: Dictionary = _census.call("classify", agent, space)
	if String(c.skip) != "":
		return "not measured (%s)" % String(c.skip)
	if String(c.flag) == "":
		return "in place" if bool(c.bound) else "- (not post-bound this hour)"
	return String(c.flag)


## The enemy watchdog's own vocabulary (enemy_base.gd _move_intent / _unstick_*).
static func enemy_stuck_line(s: Dictionary) -> String:
	if bool(s.dead) or bool(s.downed):
		return "-"
	if float(s.move_intent) > 0.05 and float(s.speed) < 0.1:
		return "WANTS %.2f m/s, MOVES %.2f: stuck %.1f s, unstick %.1f s / %d flips, off-mesh %.2f m" % [
			float(s.move_intent), float(s.speed), float(s.stuck_t), float(s.unstick_t),
			int(s.unstick_flips), float(s.get("off_mesh_m", -1.0))]
	if float(s.unstick_t) > 0.0:
		return "unsticking %.1f s" % float(s.unstick_t)
	return "-"


# ---------------- LEDGER PANE ----------------

## Every village: key, band, the deeds behind it (id, kind, sim hour, cause). Counting the
## deeds is legal HERE and nowhere else (scripts/dev is outside test_hearts_felt's list).
static func ledger_rows() -> Array[Dictionary]:
	var led: RefCounted = CampaignState.hearts
	var all_deeds: Dictionary = led.get("deeds") as Dictionary
	var places: Dictionary = {}   ## key -> {center, band, deeds: []}
	for n in AgentRegistry.civilians:
		var c := n as Civilian
		if c == null or not is_instance_valid(c) or c.village_center == Vector3.ZERO:
			continue
		var key: int = HmLedgerS.place_key(c.village_center)
		if not places.has(key):
			places[key] = {"key": key, "center": c.village_center, "deeds": []}
	for id in all_deeds:
		var d: Dictionary = all_deeds[id]
		var key: int = int(d.place)
		if not places.has(key):
			places[key] = {"key": key, "center": Vector3.ZERO, "deeds": []}
		var deed: Dictionary = {"id": String(id), "kind": String(d.kind), "sim_hour": float(d.sim_hour),
			"cause": String(d.get("cause", ""))}
		(places[key].deeds as Array).append(deed)
	var out: Array[Dictionary] = []
	for key in places:
		var row: Dictionary = places[key]
		row["band"] = String(led.band(int(key)))
		out.append(row)
	return out


func ledger_text() -> String:
	var rows: PackedStringArray = PackedStringArray()
	rows.append("sim %s   x%.0f" % [DecisionRingS.clock(DecisionRingS.now_hours()), SimClock.real_to_sim_ratio])
	rows.append("")
	rows.append("VILLAGES (CampaignState.hearts)")
	var places: Array[Dictionary] = ledger_rows()
	if places.is_empty():
		rows.append("  none known yet")
	for row in places:
		var c: Vector3 = row.center
		rows.append("  key %d  band %-8s centre (%+.0f, %+.0f)" % [int(row.key), String(row.band).to_upper(), c.x, c.z])
		var deeds: Array = row.deeds
		if deeds.is_empty():
			rows.append("      no deeds")
		for d in deeds:
			rows.append("      %s  %-12s %s" % [DecisionRingS.clock(float(d.sim_hour) + float(SimClock.sim_day) * 24.0), d.kind, d.id])
			if String(d.cause) != "":
				rows.append("          cause: %s" % d.cause)
	rows.append("")
	var fd: Node = get_tree().get_first_node_in_group("mission_director")
	if fd != null:
		rows.append("FIELD DIRECTOR")
		var now_s: float = float(Time.get_ticks_msec()) * 0.001
		var ev: Variant = fd.get("evidence")
		if ev != null and (ev as Object).has_method("best_fix"):
			var fix: Dictionary = ev.call("best_fix", now_s)
			if fix.is_empty():
				rows.append("  evidence: nothing left behind")
			else:
				var fp: Vector3 = fix.get("pos", Vector3.ZERO)
				rows.append("  evidence best fix (%+.0f, %+.0f) weight %.2f   total %.2f" % [fp.x, fp.z,
					float(fix.get("weight", 0.0)), float(ev.call("total_strength", now_s))])
		rows.append("  escalation %s   hunter pool %s   hunter timer %.0f s" % [str(fd.get("_escalation_active")),
			str(fd.get("_hunter_pool")), float(fd.get("_hunter_timer"))])
		rows.append("  stand_to_held %s   standing_to %s   patrol_out %s   informer_answered %s" % [
			str(fd.get("stand_to_held")), str(fd.get("_standing_to")), str(fd.get("patrol_out")), str(fd.get("_informer_answered"))])
		if fd.has_method("_known_village_centers"):
			var known: Array = fd.call("_known_village_centers")
			var talked: PackedStringArray = PackedStringArray()
			for center in known:
				var k: int = HmLedgerS.place_key(center)
				talked.append("%d:%s" % [k, "talked" if CampaignState.hearts.has("informer/%d/talked" % k) else "quiet"])
			rows.append("  night_warning reads: %s" % (", ".join(talked) if not talked.is_empty() else "no villages"))
		rows.append("")
	var taskings: Variant = CampaignState.get("taskings")
	if taskings != null:
		rows.append("TASKINGS (CampaignState.taskings)")
		if taskings is Array:
			for t in (taskings as Array):
				rows.append("  %s" % str(t))
		elif taskings is Dictionary:
			for k in (taskings as Dictionary):
				rows.append("  %s: %s" % [str(k), str((taskings as Dictionary)[k])])
		else:
			rows.append("  %s" % str(taskings))
	else:
		rows.append("TASKINGS: none (CampaignState.taskings absent)")
	return "\n".join(rows)


## One [OBS] line for the selected man - the same text the human reads, for a headless grep.
func dump_selected() -> String:
	if _selected == null:
		return "[OBS] no selection"
	return "[OBS] " + man_text(_selected).replace("\n", " || ")
