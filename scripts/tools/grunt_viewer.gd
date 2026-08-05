## grunt_viewer.gd - Grunt Viewer bench (grunt_viewer.bat). Spawns dressed
## grunts via GruntRandomizer, orbit with the mouse, pick any clip, lock a role,
## hit RANDOMIZE. Skin tone + face always match (one material).
##
## SQUAD MODE is the point of this bench, not a convenience: one man tells you
## nothing about a randomizer. Clones only show up side by side - identical faces,
## the same helmet twice, every man wearing the pot at the same angle. Spawn eight
## and the spawner either looks like a squad or it does not.
##
## The seed is shown and re-enterable. ADR-010 is one seed per operation, so the
## same seed must rebuild the same squad, man for man - that is a property worth
## being able to check by eye rather than trusting.
extends Node3D

const ORBIT_SPEED: float = 0.008
const ZOOM_STEP: float = 0.25
const PITCH_MIN: float = -1.2
const PITCH_MAX: float = 0.6
const DEFAULT_CLIP: String = "idle"
const SPACING: float = 1.15
const COUNTS: Array[int] = [1, 4, 8, 12]

var _rng := RandomNumberGenerator.new()
var _actors: Array[ModelActor] = []
var _loadouts: Array[Dictionary] = []
var _seed: int = 0

var _pivot: Node3D = null
var _cam: Camera3D = null
var _yaw: float = 0.35
var _pitch: float = -0.15
var _dist: float = 3.2
var _dragging: bool = false

var _role_pick: OptionButton = null
var _clip_pick: OptionButton = null
var _count_pick: OptionButton = null
var _helmet_pick: OptionButton = null
var _seed_edit: LineEdit = null
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
	plane.size = Vector2(30, 30)
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
	box.custom_minimum_size = Vector2(300, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "GRUNT VIEWER"
	box.add_child(title)

	box.add_child(_label("Squad size"))
	_count_pick = OptionButton.new()
	for c in COUNTS:
		_count_pick.add_item("%d" % c)
	_count_pick.selected = 0
	_count_pick.item_selected.connect(func(_i: int) -> void: _respawn_same_seed())
	box.add_child(_count_pick)

	box.add_child(_label("Role"))
	_role_pick = OptionButton.new()
	_role_pick.add_item("RANDOM ROLE")
	for r in GruntRandomizer.roles():
		_role_pick.add_item(r)
	_role_pick.item_selected.connect(func(_i: int) -> void: _randomize())
	box.add_child(_role_pick)

	box.add_child(_label("Helmet"))
	_helmet_pick = OptionButton.new()
	_helmet_pick.add_item("RANDOM HELMET")
	for h in GruntDresser.HELMETS:
		_helmet_pick.add_item(String(h))
	_helmet_pick.item_selected.connect(func(_i: int) -> void: _respawn_same_seed())
	box.add_child(_helmet_pick)

	box.add_child(_label("Animation"))
	_clip_pick = OptionButton.new()
	_clip_pick.item_selected.connect(_on_clip_selected)
	box.add_child(_clip_pick)

	var btn := Button.new()
	btn.text = "RANDOMIZE"
	btn.pressed.connect(_randomize)
	box.add_child(btn)

	box.add_child(_label("Seed (enter to rebuild the same squad)"))
	_seed_edit = LineEdit.new()
	_seed_edit.text_submitted.connect(_on_seed_entered)
	box.add_child(_seed_edit)

	var again := Button.new()
	again.text = "RESPAWN THIS SEED"
	again.pressed.connect(_respawn_same_seed)
	box.add_child(again)

	_loadout_label = Label.new()
	_loadout_label.add_theme_font_size_override("font_size", 12)
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


func _locked_helmet() -> String:
	if _helmet_pick == null or _helmet_pick.selected <= 0:
		return ""
	return _helmet_pick.get_item_text(_helmet_pick.selected)


func _count() -> int:
	if _count_pick == null or _count_pick.selected < 0:
		return 1
	return COUNTS[_count_pick.selected]


func _randomize() -> void:
	_seed = randi()
	_spawn_squad()


## Same seed, same men - so changing squad size or helmet lock does not also
## reroll everything and hide what the change actually did.
func _respawn_same_seed() -> void:
	_spawn_squad()


func _on_seed_entered(text: String) -> void:
	if text.strip_edges().is_valid_int():
		_seed = int(text)
		_spawn_squad()


func _spawn_squad() -> void:
	var keep_clip: String = _current_clip_name()
	for a in _actors:
		if is_instance_valid(a):
			a.queue_free()
	_actors.clear()
	_loadouts.clear()

	_rng.seed = _seed
	var n: int = _count()
	var opts: Dictionary = {}
	var forced: String = _locked_helmet()
	if not forced.is_empty():
		opts["helmet_id"] = forced

	var x0: float = -0.5 * SPACING * float(n - 1)
	for i in n:
		var got: Dictionary = GruntRandomizer.spawn(self, _rng, _locked_role(), opts)
		if got.is_empty():
			continue
		var actor: ModelActor = got["actor"] as ModelActor
		actor.position = Vector3(x0 + SPACING * float(i), 0.0, 0.0)
		_actors.append(actor)
		_loadouts.append(got["loadout"] as Dictionary)

	if _actors.is_empty():
		_loadout_label.text = "SPAWN FAILED (see console)"
		return

	# frame the whole rank, not just the first man
	_pivot.position = Vector3(0.0, 0.95, 0.0)
	_dist = clampf(2.4 + 0.55 * float(n), 2.4, 12.0)
	_update_camera()

	_fill_clips(keep_clip)
	_update_loadout_label()
	if _seed_edit != null:
		_seed_edit.text = str(_seed)


func _fill_clips(prefer: String) -> void:
	_clip_pick.clear()
	if _actors.is_empty():
		return
	var clips: Array[String] = []
	for c in _actors[0].clip_names():
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
	if idx < 0 or _clip_pick == null or idx >= _clip_pick.item_count:
		return
	var clip: String = _clip_pick.get_item_text(idx)
	for a in _actors:
		if is_instance_valid(a):
			a.play(clip, true)


## Counts repeats as well as listing the men: a squad that reads as clones should
## say so in numbers, not only to the eye.
func _update_loadout_label() -> void:
	var lines: Array[String] = []
	var faces: Dictionary = {}
	var helmets: Dictionary = {}
	for i in _loadouts.size():
		var l: Dictionary = _loadouts[i]
		var f: int = int(l.get("face", -1))
		var h: String = String(l.get("helmet", "-"))
		faces[f] = int(faces.get(f, 0)) + 1
		helmets[h] = int(helmets.get(h, 0)) + 1
		var extra: String = ""
		if bool(l.get("ruck", false)):
			extra += " +ruck"
		if bool(l.get("radio", false)):
			extra += " +radio"
		lines.append("%d. %-22s face %-3d %s%s"
			% [i + 1, String(l.get("unit", "?")), f, h, extra])
	lines.append("")
	lines.append("distinct faces: %d/%d   distinct helmets: %d/%d"
		% [faces.size(), _loadouts.size(), helmets.size(), _loadouts.size()])
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
			_dist = minf(14.0, _dist + ZOOM_STEP)
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
