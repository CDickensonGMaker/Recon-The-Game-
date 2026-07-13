## hitzone_editor.gd - HITZONE TUNING BENCH (beads yd83 + trqx).
##
## Launch outside the game (hitzone_editor.bat). Loads any character, plays
## any library clip, and overlays the mesh-hull/capsule hitzones as wireframes
## so Caleb can SEE them ride the animation and fine-tune every zone.
##
## Mouse: LEFT-CLICK a zone to select it. LEFT-DRAG moves it in the camera
##        plane. RIGHT-DRAG horizontal TWISTS around the limb axis, vertical
##        TILTS toward/away the camera (screen-space from any view). Starting
##        any drag pauses the clip so the box holds still (P resumes).
##        Shift = fine.
## Keys:  Z/X character  [/] clip  P pause  Q/E rotate model  TAB cycle zone
##        1-9,0 select zone   Arrows offset X/Y  PgUp/PgDn offset Z
##        +/- inflate (hull) or radius (capsule)  Shift fine
##        ,/. damage mult down/up (Shift fine)  F toggle fatal
##        Ctrl+S save data/hitzones/<unit>.tres   R revert (delete overrides)
extends Node3D

const REGION_ORDER: Array[String] = ["HEAD", "BODY", "GUT",
	"ARM_L_UP", "ARM_L_LO", "ARM_R_UP", "ARM_R_LO",
	"LEG_L_UP", "LEG_L_LO", "LEG_R_UP", "LEG_R_LO"]
const NUDGE: float = 0.15      # m/s of key hold
const RADIUS_STEP: float = 0.08
const INFLATE_STEP: float = 0.04   # m/s of key hold (hull margin)
const BENCH_LAYER: int = 1 << 10   # zones collide on this layer for mouse picking

var _units: Array[String] = []
var _unit_idx: int = 0
var _clips: PackedStringArray = PackedStringArray()
var _clip_idx: int = 0
var _holder: Node3D = null
var _model: ModelActor = null
var _sync: Array = []
var _selected: int = 0
var _touched: Dictionary = {}   # region -> true (nudged this session)
var _rot: Dictionary = {}       # region -> Basis (accumulated bench rotation)
var _paused: bool = false
var _held: Dictionary = {}
var _drag_mode: int = 0         # 0 none, 1 move (LMB), 2 rotate (RMB)

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
	_units.append_array(ModelActor.all_units())
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
	if not _model.setup(_units[_unit_idx]):
		return
	# See-through body: x-ray wires carry no depth cue, so a box can LOOK on
	# the leg while floating a meter toward the camera. A translucent mesh
	# puts depth back in the picture.
	var stack: Array = [_model as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			(n as MeshInstance3D).transparency = 0.45
	_rebuild_zones()
	_clips = _model.clip_names()
	_clip_idx = maxi(0, _clips.find("idle"))
	_play_current_clip()


func _play_current_clip() -> void:
	if _model == null or _clips.is_empty():
		return
	_model.play(str(_clips[_clip_idx]), true)


## Drop and rebuild the zone set on the LIVE model - the clip keeps playing.
## (A full _load_unit reload T-pose-flashed the rig just to swap zones.)
func _rebuild_zones() -> void:
	if _holder == null or _model == null:
		return
	for c in _holder.get_children():
		if c is Area3D:
			_holder.remove_child(c)
			c.queue_free()
	_touched = {}
	_rot = {}
	_sync = HitzoneBuilder.build(_holder, _model, BENCH_LAYER, 0, ["hitzone"], true)
	# Seed bench rotation state from saved overrides (builder stamps rot_deg).
	for c in _holder.get_children():
		if c is Area3D:
			var rd: Vector3 = c.get_meta("rot_deg", Vector3.ZERO)
			if rd != Vector3.ZERO:
				_rot[str(c.get_meta("region", ""))] = Basis.from_euler(rd * (PI / 180.0))


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


func _col_for(hz: Area3D) -> CollisionShape3D:
	for c in hz.get_children():
		if c is CollisionShape3D:
			return c
	return null


## How far the zone's shape center sits from the bone segment it guards -
## the live floating-box alarm (a zone off its limb = free misses in game).
func _zone_float_m(hz: Area3D) -> float:
	var entry: Array = _sync_entry_for(hz)
	if entry.is_empty() or _model == null:
		return 0.0
	var skel: Skeleton3D = _model.skeleton()
	if skel == null:
		return 0.0
	var a: Vector3 = skel.global_transform * skel.get_bone_global_pose(entry[1]).origin
	var b: Vector3 = a
	if int(entry[3]) >= 0:
		b = skel.global_transform * skel.get_bone_global_pose(entry[3]).origin
	var center: Vector3 = hz.global_position
	if hz.has_meta("hull_points"):
		var csum := Vector3.ZERO
		var pts: PackedVector3Array = hz.get_meta("hull_points")
		for p in pts:
			csum += p
		center = hz.global_transform * (csum / float(pts.size()))
	var seg: Vector3 = b - a
	var t: float = 0.0
	if seg.length_squared() > 0.0001:
		t = clampf((center - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return center.distance_to(a + seg * t)


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


## ---- mouse: click-select, left-drag move, right-drag rotate ----------------
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var hit: Area3D = _pick_zone(mb.position)
				if hit != null:
					var idx: int = REGION_ORDER.find(str(hit.get_meta("region", "")))
					if idx >= 0:
						_selected = idx
				# LMB only drags a zone you actually grabbed; RMB rotates the
				# selected zone from anywhere (free mouse room to spin).
				if mb.button_index == MOUSE_BUTTON_LEFT:
					_drag_mode = 1 if hit != null else 0
				else:
					_drag_mode = 2
				# Hold the pose while editing - dragging a box that is riding
				# a run cycle is chasing a moving target. P resumes.
				if _drag_mode != 0 and not _paused:
					_paused = true
					if _model != null:
						_model.stop_anim()
			else:
				_drag_mode = 0
	elif event is InputEventMouseMotion and _drag_mode != 0:
		var mm := event as InputEventMouseMotion
		if _drag_mode == 1:
			_drag_move(mm.relative)
		else:
			_drag_rotate(mm.relative)


func _pick_zone(screen_pos: Vector2) -> Area3D:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = BENCH_LAYER
	var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return null
	var hit: Object = res.collider
	return hit as Area3D


func _drag_move(rel: Vector2) -> void:
	var region: String = REGION_ORDER[_selected]
	var hz: Area3D = _zone_for(region)
	if hz == null:
		return
	var entry: Array = _sync_entry_for(hz)
	if entry.is_empty():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var fine: float = 0.25 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var dist: float = cam.global_position.distance_to(hz.global_position)
	var px_to_m: float = dist * 0.0016 * fine
	var world_delta: Vector3 = cam.global_transform.basis.x * rel.x * px_to_m \
		- cam.global_transform.basis.y * rel.y * px_to_m
	entry[2] = Vector3(entry[2]) + hz.global_transform.basis.inverse() * world_delta
	_touched[region] = true


func _drag_rotate(rel: Vector2) -> void:
	var region: String = REGION_ORDER[_selected]
	var hz: Area3D = _zone_for(region)
	if hz == null:
		return
	var entry: Array = _sync_entry_for(hz)
	if entry.is_empty():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var fine: float = 0.25 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var rot: Basis = _rot.get(region, Basis.IDENTITY)
	# Horizontal TWISTS around the zone's own long axis (the missing third
	# axis - fitting a hull to a leg IS a twist). Vertical TILTS around the
	# camera's right, mapped into zone space, so "drag up = lean away" holds
	# from any viewpoint and any model yaw.
	var local_right: Vector3 = (hz.global_transform.basis.inverse()
		* cam.global_transform.basis.x).normalized()
	var delta_rot: Basis = Basis(Vector3.UP, -rel.x * 0.008 * fine) \
		* Basis(local_right, -rel.y * 0.008 * fine)
	rot = rot * delta_rot
	# Pivot IN PLACE: the offset lives in the rotated frame, so rotating a
	# displaced zone orbits it around the joint - the drag-rotate-drag spiral
	# that ballooned offsets past a meter. Counter-rotate the offset so the
	# box spins about its own center and position holds.
	entry[2] = delta_rot.inverse() * Vector3(entry[2])
	_rot[region] = rot
	entry[4] = rot
	hz.set_meta("rot_deg", rot.get_euler() * (180.0 / PI))
	_touched[region] = true


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
	# Zone select: 1-9 then 0 = tenth; TAB cycles all 11; mouse clicks anything.
	for i in range(9):
		if _pressed_once(KEY_1 + i) and i < REGION_ORDER.size():
			_selected = i
	if _pressed_once(KEY_0) and REGION_ORDER.size() > 9:
		_selected = 9
	if _pressed_once(KEY_TAB):
		_selected = (_selected + 1) % REGION_ORDER.size()
	if Input.is_key_pressed(KEY_CTRL) and _pressed_once(KEY_S):
		_save_tuning()
	if Input.is_key_pressed(KEY_CTRL) and _pressed_once(KEY_D):
		_save_tuning(true)
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
	if not entry.is_empty() and off_delta != Vector3.ZERO:
		entry[2] = Vector3(entry[2]) + off_delta * NUDGE * fine * delta
	var col: CollisionShape3D = _col_for(hz)
	if col != null and r_delta != 0.0:
		if hz.has_meta("hull_points"):
			# Hull zone: +/- drives the inflate margin (fairness pad).
			var inflate: float = float(hz.get_meta("inflate", 0.0)) + r_delta * INFLATE_STEP * fine * delta
			inflate = clampf(inflate, -0.05, 0.25)
			hz.set_meta("inflate", inflate)
			col.shape = HitzoneBuilder._hull_shape(hz.get_meta("hull_points"), inflate)
			hz.remove_meta("wire_pts")
		elif col.shape is SphereShape3D:
			var s := col.shape as SphereShape3D
			s.radius = maxf(0.03, s.radius + r_delta * RADIUS_STEP * fine * delta)
		elif col.shape is CapsuleShape3D:
			var cap := col.shape as CapsuleShape3D
			cap.radius = maxf(0.03, cap.radius + r_delta * RADIUS_STEP * fine * delta)


## Ctrl+S writes this unit's file; Ctrl+D (as_default) writes _default.tres,
## which every unit WITHOUT its own file inherits - tune the reference rig
## once and the whole roster lines up (per-unit saves still win).
func _save_tuning(as_default: bool = false) -> void:
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
		var zone_entry: Dictionary = {}
		# Offset delta vs the measured bone offset.
		var base_off: Vector3 = hz.get_meta("base_offset", Vector3.ZERO)
		var cur_off: Vector3 = Vector3(entry[2]) if not entry.is_empty() else base_off
		var delta_off: Vector3 = cur_off - base_off
		if delta_off.length() >= 0.001:
			zone_entry["offset"] = delta_off
		# Rotation (bench-authored Basis, saved as euler degrees - same .tres
		# format the builder has always consumed).
		var rot_rad: Vector3 = (_rot.get(region, Basis.IDENTITY) as Basis).get_euler()
		if rot_rad.length() >= 0.001:
			zone_entry["rotation"] = rot_rad * (180.0 / PI)
		# Shape size: inflate for hulls, radius for capsule fallbacks.
		if hz.has_meta("hull_points"):
			var inflate: float = float(hz.get_meta("inflate", 0.0))
			if absf(inflate) >= 0.0005:
				zone_entry["inflate"] = inflate
		else:
			var base_r: float = hz.get_meta("base_radius", 0.0)
			var cur_r: float = base_r
			var col: CollisionShape3D = _col_for(hz)
			if col != null and col.shape != null:
				var sh: Shape3D = col.shape
				cur_r = (sh as SphereShape3D).radius if sh is SphereShape3D else (sh as CapsuleShape3D).radius
			if absf(cur_r - base_r) >= 0.001:
				zone_entry["radius"] = cur_r
		# Damage overrides persist only when they differ from ADR-016 law.
		var zhz := hz as Hitzone
		if zhz != null:
			var def_mult: float = float(Hitzone.MULTIPLIERS.get(zhz.zone_type, 1.0))
			if zhz.damage_mult_override >= 0.0 \
					and absf(zhz.damage_mult_override - def_mult) > 0.001:
				zone_entry["damage"] = zhz.damage_mult_override
			var law_fatal: bool = zhz.zone_type == Hitzone.ZoneType.HEAD
			if zhz.fatal_override >= 0 and (zhz.fatal_override == 1) != law_fatal:
				zone_entry["fatal"] = zhz.fatal_override == 1
		if not zone_entry.is_empty():
			tuning.zones[region] = zone_entry
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/hitzones"))
	var fname: String = "_default" if as_default else _units[_unit_idx]
	var path: String = HitzoneBuilder.TUNING_DIR + fname + ".tres"
	var err: int = ResourceSaver.save(tuning, path)
	if err == OK:
		if as_default:
			_flash("SAVED DEFAULT -> %s (%d zones, inherited by every unit without its own file)" % [path, tuning.zones.size()])
		else:
			_flash("SAVED -> %s (%d zones)" % [path, tuning.zones.size()])
	else:
		_flash("SAVE FAILED (err %d)" % err)


func _revert_tuning() -> void:
	var path: String = HitzoneBuilder.TUNING_DIR + _units[_unit_idx] + ".tres"
	if ResourceLoader.exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_rebuild_zones()
	_flash("REVERTED to measured zones")


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
		var key_label: String = str(i + 1) if i < 9 else ("0" if i == 9 else "-")
		var size_str: String
		if hz.has_meta("hull_points"):
			size_str = "hull %dpt infl %+.3f" % [(hz.get_meta("hull_points") as PackedVector3Array).size(), float(hz.get_meta("inflate", 0.0))]
		else:
			var r: float = 0.0
			var col: CollisionShape3D = _col_for(hz)
			if col != null and col.shape != null:
				var sh: Shape3D = col.shape
				r = (sh as SphereShape3D).radius if sh is SphereShape3D else (sh as CapsuleShape3D).radius
			size_str = "caps r=%.3f" % r
		var zh := hz as Hitzone
		var dmg_str: String = ""
		if zh != null:
			dmg_str = "  FATAL" if zh.is_fatal_zone() else "  dmg x%.2f" % zh.get_damage_multiplier()
		var rot_str: String = ""
		var rr: Vector3 = (_rot.get(region, Basis.IDENTITY) as Basis).get_euler()
		if rr.length() > 0.001:
			rot_str = "  rot(%.0f,%.0f,%.0f)" % [rad_to_deg(rr.x), rad_to_deg(rr.y), rad_to_deg(rr.z)]
		var float_m: float = _zone_float_m(hz)
		var float_str: String = "  !!OFF-BODY %.2fm" % float_m if float_m > 0.35 else ""
		lines.append("%s%s %s  %s%s%s%s%s" % [marker, key_label, region, size_str, dmg_str, rot_str, float_str, "  *" if _touched.has(region) else ""])
	lines.append("")
	lines.append("CLICK select   L-drag move   R-drag twist(H)/tilt(V)   Shift fine")
	lines.append("drag pauses the clip - P resumes")
	lines.append("Z/X unit  [/] clip  P pause  Q/E spin  TAB/1-0 zone")
	lines.append("arrows/PgUpDn offset  +/- inflate|radius  ,/. dmg  F fatal")
	lines.append("Ctrl+S save unit   Ctrl+D save as DEFAULT (all units)   R revert")
	_hud.text = "\n".join(lines)
