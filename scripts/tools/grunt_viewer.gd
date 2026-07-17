## grunt_viewer.gd - Grunt Viewer bench (grunt_viewer.bat). Spawns dressed
## grunts via GruntRandomizer, orbit the model with the mouse, pick any clip,
## lock a role, hit RANDOMIZE. Skin tone + face always match (one material).
extends Node3D

const ORBIT_SPEED: float = 0.008
const ZOOM_STEP: float = 0.25
const PITCH_MIN: float = -1.2
const PITCH_MAX: float = 0.6
const DEFAULT_CLIP: String = "idle"

var _rng := RandomNumberGenerator.new()
var _actor: ModelActor = null
var _loadout: Dictionary = {}
var _seed: int = 0

var _pivot: Node3D = null
var _cam: Camera3D = null
var _yaw: float = 0.35
var _pitch: float = -0.15
var _dist: float = 3.2
var _dragging: bool = false

var _role_pick: OptionButton = null
var _clip_pick: OptionButton = null
var _loadout_label: Label = null


func _ready() -> void:
	_build_scene()
	_build_ui()
	_randomize()


func _build_scene() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, 0.95, 0.0)
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.current = true
	_pivot.add_child(_cam)
	_update_camera()

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.4
	add_child(fill)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.15, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.65, 0.65)
	env.environment = e
	add_child(env)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.22, 0.18)
	floor_mesh.material_override = fm
	add_child(floor_mesh)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "GRUNT VIEWER"
	box.add_child(title)

	box.add_child(_label("Role"))
	_role_pick = OptionButton.new()
	_role_pick.add_item("RANDOM ROLE")
	for r in GruntRandomizer.roles():
		_role_pick.add_item(r)
	_role_pick.item_selected.connect(func(_i: int) -> void: _randomize())
	box.add_child(_role_pick)

	box.add_child(_label("Animation"))
	_clip_pick = OptionButton.new()
	_clip_pick.item_selected.connect(_on_clip_selected)
	box.add_child(_clip_pick)

	var btn := Button.new()
	btn.text = "RANDOMIZE"
	btn.pressed.connect(_randomize)
	box.add_child(btn)

	_loadout_label = Label.new()
	_loadout_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_loadout_label)

	var help := Label.new()
	help.text = "L-drag orbit · wheel zoom"
	help.add_theme_font_size_override("font_size", 12)
	box.add_child(help)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	return l


func _locked_role() -> String:
	if _role_pick == null or _role_pick.selected <= 0:
		return ""
	return _role_pick.get_item_text(_role_pick.selected)


func _randomize() -> void:
	var keep_clip: String = _current_clip_name()
	if _actor != null:
		_actor.queue_free()
		_actor = null
	_seed = randi()
	_rng.seed = _seed
	var got: Dictionary = GruntRandomizer.spawn(self, _rng, _locked_role())
	if got.is_empty():
		_loadout_label.text = "SPAWN FAILED (see console)"
		return
	_actor = got["actor"] as ModelActor
	_loadout = got["loadout"] as Dictionary
	_fill_clips(keep_clip)
	_update_loadout_label()


func _fill_clips(prefer: String) -> void:
	_clip_pick.clear()
	if _actor == null:
		return
	var clips: Array[String] = []
	for c in _actor.clip_names():
		clips.append(String(c))
	clips.sort()
	var want: String = prefer if clips.has(prefer) else DEFAULT_CLIP
	var want_idx: int = 0
	for i in clips.size():
		_clip_pick.add_item(clips[i])
		if clips[i] == want:
			want_idx = i
	if clips.is_empty():
		return
	_clip_pick.selected = want_idx
	_on_clip_selected(want_idx)


func _current_clip_name() -> String:
	if _clip_pick == null or _clip_pick.selected < 0 or _clip_pick.item_count == 0:
		return DEFAULT_CLIP
	return _clip_pick.get_item_text(_clip_pick.selected)


func _on_clip_selected(idx: int) -> void:
	if _actor != null and idx >= 0 and idx < _clip_pick.item_count:
		_actor.play(_clip_pick.get_item_text(idx), true)


func _update_loadout_label() -> void:
	var lines: Array[String] = []
	lines.append("unit: %s" % String(_loadout.get("unit", "?")))
	lines.append("face/skin cell: %d" % int(_loadout.get("face", -1)))
	lines.append("helmet: %s" % String(_loadout.get("helmet", "-")))
	if _loadout.has("ruck"):
		lines.append("ruck: %s" % ("on" if bool(_loadout["ruck"]) else "off"))
	if _loadout.has("radio"):
		lines.append("radio: %s" % ("on" if bool(_loadout["radio"]) else "off"))
	lines.append("seed: %d" % _seed)
	_loadout_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(1.2, _dist - ZOOM_STEP)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(8.0, _dist + ZOOM_STEP)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		# Release over a Control never reaches _unhandled_input - trust the mask,
		# not the stored flag, or the camera sticks to the mouse.
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_dragging = false
			return
		_yaw -= mm.relative.x * ORBIT_SPEED
		_pitch = clampf(_pitch - mm.relative.y * ORBIT_SPEED, PITCH_MIN, PITCH_MAX)
		_update_camera()


func _update_camera() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_cam.position = Vector3(0.0, 0.0, _dist)
