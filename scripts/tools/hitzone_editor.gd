## hitzone_editor.gd - HITZONE TUNING BENCH (bead yd83).
##
## Launch outside the game (hitzone_editor.bat). Loads any character, plays
## any of the 91 library clips, and overlays the bone-synced hitzones as
## wireframes so Caleb can SEE them ride the animation and fine-tune.
##
## Keys: Z/X character  [/] clip  P pause  Q/E rotate
##       1-7 select zone (HEAD BODY GUT ARM_L ARM_R LEG_L LEG_R)
##       Arrows offset X/Y  PgUp/PgDn offset Z  +/- radius  Shift fine
##       ,/. damage mult down/up (Shift fine)  F toggle fatal
##       Ctrl+S save data/hitzones/<unit>.tres   R revert (delete overrides)
extends Node3D

const REGION_ORDER: Array[String] = ["HEAD", "BODY", "GUT", "ARM_L", "ARM_R", "LEG_L", "LEG_R"]
const NUDGE: float = 0.15      # m/s of key hold
const RADIUS_STEP: float = 0.08

var _units: Array[String] = []
var _unit_idx: int = 0
var _clips: PackedStringArray = PackedStringArray()
var _clip_idx: int = 0
var _holder: Node3D = null
var _model: ModelActor = null
var _sync: Array = []
var _selected: int = 0
var _touched: Dictionary = {}   # region -> true (nudged this session)
var _paused: bool = false
var _held: Dictionary = {}

var _wire_node: MeshInstance3D = null
var _wire_mesh: ImmediateMesh = null
var _hud: Label = null
var _flash_label: Label = null
var _flash_timer: float = 0.0


func _ready() -> void:
	_build_scene()
	_scan_units()
	if not _units.is_empty():
		# Open on the bona fide rig (Caleb): us_grunt_v2 is the reference model
		# hitboxes are tuned against - v1 rigs are legacy fallbacks.
		_load_unit(maxi(0, _units.find("us_grunt_v2")))


func _build_scene() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.05, 2.6)
	cam.fov = 50.0
	cam.current = true
	add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.15, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e
	add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.22, 0.18)
	floor_mesh.material_override = fm
	add_child(floor_mesh)

	_wire_mesh = ImmediateMesh.new()
	_wire_node = MeshInstance3D.new()
	_wire_node.mesh = _wire_mesh
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	wm.no_depth_test = true
	_wire_node.material_override = wm
	add_child(_wire_node)

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_hud = Label.new()
	_hud.position = Vector2(10, 10)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 3)
	canvas.add_child(_hud)
	_flash_label = Label.new()
	_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash_label.position = Vector2(-150, 40)
	_flash_label.add_theme_font_size_override("font_size", 18)
	_flash_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	_flash_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_flash_label.add_theme_constant_override("outline_size", 3)
	_flash_label.visible = false
	canvas.add_child(_flash_label)


func _scan_units() -> void:
	var dir := DirAccess.open("res://assets/models/characters")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".glb") and not f.begins_with("anim_library"):
			var unit: String = f.trim_suffix(".glb")
			_units.append(unit)
	_units.sort()


func _load_unit(idx: int) -> void:
	_unit_idx = wrapi(idx, 0, _units.size())
	if _holder != null:
		_holder.queue_free()
	_holder = Node3D.new()
	add_child(_holder)
	_model = ModelActor.new()
	_holder.add_child(_model)
	_sync = []
	_touched = {}
	if not _model.setup(_units[_unit_idx]):
		return
	_sync = HitzoneBuilder.build(_holder, _model, 0, 0, ["hitzone"], true)
	_clips = _model.clip_names()
	_clip_idx = maxi(0, _clips.find("idle"))
	_play_current_clip()


func _play_current_clip() -> void:
	if _model == null or _clips.is_empty():
		return
	_model.play(str(_clips[_clip_idx]), true)


func _zone_for(region: String) -> Area3D:
	if _holder == null:
		return null
	for c in _holder.get_children():
		if c is Area3D and str(c.get_meta("region", "")) == region:
			return c
	return null


func _sync_entry_for(hz: Area3D) -> Array:
	for entry in _sync:
		if entry[0] == hz:
			return entry
	return []


func _pressed_once(keycode: int) -> bool:
	if Input.is_key_pressed(keycode):
		if not bool(_held.get(keycode, false)):
			_held[keycode] = true
			return true
		return false
	_held[keycode] = false
	return false


func _process(delta: float) -> void:
	_handle_input(delta)
	_draw_wires()
	_update_hud()
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_label.visible = false


func _physics_process(_delta: float) -> void:
	if _model != null:
		HitzoneBuilder.sync(_model, _sync)


func _handle_input(delta: float) -> void:
	if _pressed_once(KEY_Z):
		_load_unit(_unit_idx - 1)
	if _pressed_once(KEY_X):
		_load_unit(_unit_idx + 1)
	if _pressed_once(KEY_BRACKETLEFT):
		_clip_idx = wrapi(_clip_idx - 1, 0, _clips.size())
		_play_current_clip()
	if _pressed_once(KEY_BRACKETRIGHT):
		_clip_idx = wrapi(_clip_idx + 1, 0, _clips.size())
		_play_current_clip()
	if _pressed_once(KEY_P):
		_paused = not _paused
		if _model != null and _model.has_method("stop_anim"):
			if _paused:
				_model.stop_anim()
			else:
				_play_current_clip()
	for i in range(REGION_ORDER.size()):
		if _pressed_once(KEY_1 + i):
			_selected = i
	if Input.is_key_pressed(KEY_CTRL) and _pressed_once(KEY_S):
		_save_tuning()
	if _pressed_once(KEY_R) and not Input.is_key_pressed(KEY_CTRL):
		_revert_tuning()

	if _holder != null:
		var rot: float = 0.0
		if Input.is_key_pressed(KEY_Q):
			rot += 1.0
		if Input.is_key_pressed(KEY_E):
			rot -= 1.0
		_holder.rotation.y += rot * 1.6 * delta

	# Nudge the selected zone
	var hz: Area3D = _zone_for(REGION_ORDER[_selected])
	if hz == null:
		return

	# Damage threshold editing (ADR-016 Amendment B): ,/. mult, F fatal toggle.
	var zh := hz as Hitzone
	if zh != null:
		var dstep: float = 0.05 if Input.is_key_pressed(KEY_SHIFT) else 0.25
		if _pressed_once(KEY_COMMA):
			zh.damage_mult_override = maxf(0.0, zh.get_damage_multiplier() - dstep)
			_touched[REGION_ORDER[_selected]] = true
		if _pressed_once(KEY_PERIOD):
			zh.damage_mult_override = zh.get_damage_multiplier() + dstep
			_touched[REGION_ORDER[_selected]] = true
		if _pressed_once(KEY_F):
			zh.fatal_override = 0 if zh.is_fatal_zone() else 1
			_touched[REGION_ORDER[_selected]] = true

	var fine: float = 0.15 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var off_delta := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		off_delta.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		off_delta.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		off_delta.y += 1.0
	if Input.is_key_pressed(KEY_DOWN):
		off_delta.y -= 1.0
	if Input.is_key_pressed(KEY_PAGEUP):
		off_delta.z -= 1.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		off_delta.z += 1.0
	var r_delta: float = 0.0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		r_delta += 1.0
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		r_delta -= 1.0
	if off_delta == Vector3.ZERO and r_delta == 0.0:
		return
	_touched[REGION_ORDER[_selected]] = true
	var entry: Array = _sync_entry_for(hz)
	if not entry.is_empty():
		entry[2] = Vector3(entry[2]) + off_delta * NUDGE * fine * delta
	var col: CollisionShape3D = null
	for c in hz.get_children():
		if c is CollisionShape3D:
			col = c
			break
	if col != null and r_delta != 0.0:
		if col.shape is SphereShape3D:
			var s := col.shape as SphereShape3D
			s.radius = maxf(0.03, s.radius + r_delta * RADIUS_STEP * fine * delta)
		elif col.shape is CapsuleShape3D:
			var cap := col.shape as CapsuleShape3D
			cap.radius = maxf(0.03, cap.radius + r_delta * RADIUS_STEP * fine * delta)


func _save_tuning() -> void:
	if _model == null:
		return
	var tuning := HitzoneTuning.new()
	# Persist every zone that differs from its measured baseline (not just this
	# session's touches - keeps previously saved values alive).
	for region in REGION_ORDER:
		var hz: Area3D = _zone_for(region)
		if hz == null:
			continue
		var entry: Array = _sync_entry_for(hz)
		var base_off: Vector3 = hz.get_meta("base_offset", Vector3.ZERO)
		var base_r: float = hz.get_meta("base_radius", 0.0)
		var cur_off: Vector3 = Vector3(entry[2]) if not entry.is_empty() else base_off
		var cur_r: float = base_r
		for c in hz.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
				var sh: Shape3D = (c as CollisionShape3D).shape
				cur_r = (sh as SphereShape3D).radius if sh is SphereShape3D else (sh as CapsuleShape3D).radius
		var delta_off: Vector3 = cur_off - base_off
		# Damage overrides persist only when they differ from ADR-016 law.
		var zhz := hz as Hitzone
		var dmg_diff: bool = false
		var fatal_diff: bool = false
		if zhz != null:
			var def_mult: float = float(Hitzone.MULTIPLIERS.get(zhz.zone_type, 1.0))
			dmg_diff = zhz.damage_mult_override >= 0.0 \
				and absf(zhz.damage_mult_override - def_mult) > 0.001
			var law_fatal: bool = zhz.zone_type == Hitzone.ZoneType.HEAD
			fatal_diff = zhz.fatal_override >= 0 and (zhz.fatal_override == 1) != law_fatal
		if delta_off.length() < 0.001 and absf(cur_r - base_r) < 0.001 \
				and not dmg_diff and not fatal_diff:
			continue
		var zone_entry: Dictionary = {"radius": cur_r, "offset": delta_off}
		if dmg_diff:
			zone_entry["damage"] = zhz.damage_mult_override
		if fatal_diff:
			zone_entry["fatal"] = zhz.fatal_override == 1
		tuning.zones[region] = zone_entry
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/hitzones"))
	var path: String = HitzoneBuilder.TUNING_DIR + _units[_unit_idx] + ".tres"
	var err: int = ResourceSaver.save(tuning, path)
	if err == OK:
		_flash("SAVED -> %s (%d zones)" % [path, tuning.zones.size()])
	else:
		_flash("SAVE FAILED (err %d)" % err)


func _revert_tuning() -> void:
	var path: String = HitzoneBuilder.TUNING_DIR + _units[_unit_idx] + ".tres"
	if ResourceLoader.exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_flash("REVERTED to measured zones")
	_load_unit(_unit_idx)


func _flash(text: String) -> void:
	_flash_label.text = text
	_flash_label.visible = true
	_flash_timer = 2.5


func _draw_wires() -> void:
	_wire_mesh.clear_surfaces()
	if _holder == null:
		return
	_wire_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# guarantee at least one segment so an empty surface never errors
	_wire_mesh.surface_set_color(Color(0, 0, 0, 0))
	_wire_mesh.surface_add_vertex(Vector3.ZERO)
	_wire_mesh.surface_set_color(Color(0, 0, 0, 0))
	_wire_mesh.surface_add_vertex(Vector3.ZERO)
	for c in _holder.get_children():
		if c is Area3D:
			HitzoneBuilder.draw_zone_wire(_wire_mesh, c as Area3D)
	_wire_mesh.surface_end()


func _update_hud() -> void:
	if _hud == null or _units.is_empty():
		return
	var lines: Array[String] = []
	lines.append("HITZONE BENCH   unit %s (%d/%d)" % [_units[_unit_idx], _unit_idx + 1, _units.size()])
	var clip_name: String = str(_clips[_clip_idx]) if not _clips.is_empty() else "-"
	lines.append("clip %s (%d/%d)%s" % [clip_name, _clip_idx + 1, _clips.size(), "  [PAUSED]" if _paused else ""])
	lines.append("")
	for i in range(REGION_ORDER.size()):
		var region: String = REGION_ORDER[i]
		var hz: Area3D = _zone_for(region)
		if hz == null:
			continue
		var marker: String = ">> " if i == _selected else "   "
		var r: float = 0.0
		for c in hz.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
				var sh: Shape3D = (c as CollisionShape3D).shape
				r = (sh as SphereShape3D).radius if sh is SphereShape3D else (sh as CapsuleShape3D).radius
		var zh := hz as Hitzone
		var dmg_str: String = ""
		if zh != null:
			dmg_str = "  FATAL" if zh.is_fatal_zone() else "  dmg x%.2f" % zh.get_damage_multiplier()
		lines.append("%s%d %s  r=%.3f%s%s" % [marker, i + 1, region, r, dmg_str, "  *" if _touched.has(region) else ""])
	lines.append("")
	lines.append("Z/X unit  [/] clip  P pause  Q/E rotate")
	lines.append("1-7 zone  arrows/PgUpDn offset  +/- radius  Shift fine")
	lines.append(",/. damage mult (Shift fine)  F fatal toggle")
	lines.append("Ctrl+S save   R revert")
	_hud.text = "\n".join(lines)
