## viewmodel_editor.gd - standalone viewmodel ALIGNMENT WORKBENCH (launched from
## viewmodel_editor.bat, outside the game).
##
## SYNC CONTRACT (CLAUDE.md) - DO NOT CHANGE: this rig must mirror the player
## exactly - camera at Y=1.7, hip FOV 75, WeaponHolder on an IDENTITY transform.
## Break any of the three and what you align here is not what the game renders.
##
## Workflow: nudge until the bore laser dot sits on the board center (= the
## crosshair), or press B to auto-align, then Ctrl+S to write into the .tres.
extends Node3D

## Weapon data resources for preview (auto-discovered when empty)
@export var weapons: Array[WeaponData] = []

## UI References
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var crosshair: Control = $CanvasLayer/Crosshair
@onready var position_label: Label = $CanvasLayer/PositionPanel/PositionLabel
@onready var weapon_selector: OptionButton = $CanvasLayer/ControlPanel/WeaponSelector
@onready var mode_toggle: Button = $CanvasLayer/ControlPanel/ModeToggle
@onready var copy_button: Button = $CanvasLayer/ControlPanel/CopyButton
@onready var reload_button: Button = $CanvasLayer/ControlPanel/ReloadButton
@onready var instructions_label: Label = $CanvasLayer/InstructionsPanel/InstructionsLabel
@onready var copy_feedback: Label = $CanvasLayer/CopyFeedback

## Feedback state
var copy_feedback_timer: float = 0.0

## State
var current_weapon_index: int = 0
var current_weapon: WeaponData = null
var weapon_model: Node3D = null
var preview_mode: int = 0  ## 0 = hip, 1 = ADS
var laser_enabled: bool = true

## Position editing (mirrors into current_weapon live; Ctrl+S persists)
var edit_position: Vector3 = Vector3.ZERO
var edit_rotation: Vector3 = Vector3.ZERO

## Original .tres values per resource_path, so R can revert unsaved edits.
var _snapshots: Dictionary = {}

## Edge-guard for polled keys (existing editor convention: poll, don't InputMap)
var _held: Dictionary = {}

## Lens-shaded meshes of the loaded model (ADR-034)
var _vm_meshes: Array[MeshInstance3D] = []

## Clip review (N cycles; non-idle clips fall back to rifle_idle when done)
var _vm_anim: AnimationPlayer = null
var _clips: PackedStringArray = []
var _clip_index: int = 0

## Range visuals
var _laser_node: MeshInstance3D = null
var _laser_mesh: ImmediateMesh = null
var _grid_node: MeshInstance3D = null
var _no_model_label: Label = null
var _save_button: Button = null
var _bore_offset: Vector2 = Vector2.ZERO  ## meters on the board plane
var _bore_valid: bool = false

## Movement speeds
const MOVE_SPEED: float = 0.15
const ROTATE_SPEED: float = 20.0

## Target board: dead ahead at eye height, so board center == crosshair.
const BOARD_DIST: float = 25.0
const BOARD_CENTER := Vector3(0.0, 1.7, -25.0)
const ALIGN_TOLERANCE_M: float = 0.025  ## 1 mrad at 25m reads as "aligned"

const BASE_FOV: float = 75.0


func _ready() -> void:
	if weapons.is_empty():
		_load_default_weapons()

	if weapon_selector:
		for weapon in weapons:
			var label: String = weapon.display_name
			if weapon.model_path.is_empty():
				label += "  [NO MODEL]"
			weapon_selector.add_item(label)
		weapon_selector.item_selected.connect(_on_weapon_selected)

	if mode_toggle:
		mode_toggle.pressed.connect(_on_mode_toggle)
	if copy_button:
		copy_button.pressed.connect(_on_copy_values)
	if reload_button:
		reload_button.pressed.connect(_on_reload_weapon)

	_build_save_button()
	_build_no_model_label()
	_build_range()
	_build_laser()
	_build_grid()

	if not weapons.is_empty():
		_load_weapon(0)

	if instructions_label:
		instructions_label.text = _get_instructions()


## Every WeaponData in data/weapons/ - new guns show up with zero edits here.
func _load_default_weapons() -> void:
	var dir: DirAccess = DirAccess.open("res://data/weapons")
	if not dir:
		push_error("[ViewmodelEditor] cannot open res://data/weapons")
		return
	var files: PackedStringArray = dir.get_files()
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var w: WeaponData = load("res://data/weapons/" + f) as WeaponData
		if w:
			weapons.append(w)
	weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool:
		return a.display_name < b.display_name)


func _process(delta: float) -> void:
	_handle_input(delta)
	_update_laser()
	_update_position_display()
	_update_copy_feedback(delta)


func _handle_input(delta: float) -> void:
	var speed_mult: float = 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed_mult = 0.1
	if Input.is_key_pressed(KEY_ALT):
		speed_mult *= 0.1

	## Ctrl+S save (don't grab S as movement when Ctrl held)
	if Input.is_key_pressed(KEY_CTRL):
		if _pressed_once(KEY_S):
			_save_weapon()
		return

	var move_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		move_input.y += 1.0

	var rot_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP):
		rot_input.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		rot_input.x += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		rot_input.y -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		rot_input.y += 1.0
	if Input.is_key_pressed(KEY_PAGEUP):
		rot_input.z -= 1.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		rot_input.z += 1.0

	if move_input != Vector3.ZERO:
		edit_position += move_input * MOVE_SPEED * speed_mult * delta
	if rot_input != Vector3.ZERO:
		_rotate_about_gun(rot_input * ROTATE_SPEED * speed_mult * delta)
	if move_input != Vector3.ZERO or rot_input != Vector3.ZERO:
		_apply_edit()

	## Weapon switching: Z/X prev/next, 1-9 direct select
	if _pressed_once(KEY_Z):
		_step_weapon(-1)
	if _pressed_once(KEY_X):
		_step_weapon(1)
	for i in range(9):
		if _pressed_once(KEY_1 + i) and i < weapons.size():
			weapon_selector.select(i)
			_load_weapon(i)

	## Space toggles Hip/ADS
	if _pressed_once(KEY_SPACE):
		_on_mode_toggle()

	## F5 reload model scene
	if _pressed_once(KEY_F5):
		_on_reload_weapon()

	## Laser toggle
	if _pressed_once(KEY_L):
		laser_enabled = not laser_enabled

	## Clip review: N next, Shift+N previous
	if _pressed_once(KEY_N):
		_cycle_clip(-1 if Input.is_key_pressed(KEY_SHIFT) else 1)

	## Bore calibration: hip calibrates WeaponData.bore_dir; ADS calibrates WeaponData.ads_bore_dir.
	var bore_input := Vector2.ZERO   # x = yaw (U/O), y = pitch (I/K)
	if current_weapon != null:
		if Input.is_key_pressed(KEY_I):
			bore_input.y += 1.0
		if Input.is_key_pressed(KEY_K):
			bore_input.y -= 1.0
		if Input.is_key_pressed(KEY_U):
			bore_input.x += 1.0
		if Input.is_key_pressed(KEY_O):
			bore_input.x -= 1.0
	if bore_input != Vector2.ZERO and current_weapon != null:
		var b: Vector3 = _get_current_bore_dir()
		if b == Vector3.ZERO:
			b = Vector3(0, 0, -1)
		var bstep: float = deg_to_rad(20.0) * speed_mult * delta
		b = b.rotated(Vector3.RIGHT, bore_input.y * bstep)
		b = b.rotated(Vector3.UP, bore_input.x * bstep)
		_set_current_bore_dir(b.normalized())

	if _pressed_once(KEY_R) and not Input.is_key_pressed(KEY_CTRL):
		_revert_to_snapshot()
	if _pressed_once(KEY_B):
		if Input.is_key_pressed(KEY_SHIFT):
			if current_weapon != null:
				if preview_mode == 0:
					current_weapon.bore_dir = Vector3.ZERO
					_flash("HIP bore reset to contract axis (-Z)")
				else:
					current_weapon.ads_bore_dir = Vector3.ZERO
					_flash("ADS bore reset to contract axis (-Z)")
		else:
			_auto_align()
	if _pressed_once(KEY_V) and not Input.is_key_pressed(KEY_CTRL):
		_auto_align_ads_sights()
	if _pressed_once(KEY_C) and not Input.is_key_pressed(KEY_CTRL):
		_on_copy_values()
	if _pressed_once(KEY_G) and _grid_node != null:
		_grid_node.visible = not _grid_node.visible
	if _pressed_once(KEY_H) and not Input.is_key_pressed(KEY_CTRL):
		_auto_align_hip()
	if _pressed_once(KEY_F) and not Input.is_key_pressed(KEY_CTRL):
		_frame_model()


## Rotation must pivot ON the gun: the exported rigs park the node origin at the
## armory ruler station (PPSh 28m out), so origin rotation swings the visible
## gun on a meters-long lever arm. Compensate position so the pivot stays put.
func _rotate_about_gun(rot_delta_deg: Vector3) -> void:
	var pivot: Vector3 = _gun_pivot_local()
	var b0: Basis = Basis.from_euler(Vector3(
		deg_to_rad(edit_rotation.x), deg_to_rad(edit_rotation.y), deg_to_rad(edit_rotation.z)))
	edit_rotation += rot_delta_deg
	var b1: Basis = Basis.from_euler(Vector3(
		deg_to_rad(edit_rotation.x), deg_to_rad(edit_rotation.y), deg_to_rad(edit_rotation.z)))
	edit_position += (b0 * pivot) - (b1 * pivot)


## Pivot in weapon_model space: sight-line midpoint, else muzzle, else AABB center.
func _gun_pivot_local() -> Vector3:
	if not weapon_model:
		return Vector3.ZERO
	var to_model: Transform3D = weapon_model.global_transform.affine_inverse()
	var rear: Node3D = _find_ads_marker("rear")
	var front: Node3D = _find_ads_marker("front")
	if rear != null and front != null:
		return to_model * ((rear.global_position + front.global_position) * 0.5)
	var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
	if muzzle:
		return to_model * muzzle.global_position
	return _model_aabb(weapon_model).get_center()


func _cycle_clip(dir: int) -> void:
	if _vm_anim == null or _clips.is_empty():
		_flash("NO CLIPS in this model")
		return
	_clip_index = wrapi(_clip_index + dir, 0, _clips.size())
	var clip: String = _clips[_clip_index]
	_vm_anim.play(clip)
	_flash("CLIP %d/%d: %s  (%.1fs)" % [_clip_index + 1, _clips.size(), clip,
		_vm_anim.get_animation(clip).length])


## Idle self-loops; a finished review clip drops back to idle so the pose
## never sticks on a reload's last frame.
func _on_clip_finished(_anim: StringName) -> void:
	if _vm_anim and _vm_anim.has_animation("rifle_idle"):
		_vm_anim.play("rifle_idle")
		_clip_index = maxi(0, _clips.find("rifle_idle"))


## Poll a key but fire once per press (editor convention: no InputMap actions).
func _pressed_once(keycode: int) -> bool:
	if Input.is_key_pressed(keycode):
		if not bool(_held.get(keycode, false)):
			_held[keycode] = true
			return true
		return false
	_held[keycode] = false
	return false


func _step_weapon(dir: int) -> void:
	if weapons.is_empty():
		return
	var idx: int = wrapi(current_weapon_index + dir, 0, weapons.size())
	weapon_selector.select(idx)
	_load_weapon(idx)


func _load_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return

	current_weapon_index = index
	current_weapon = weapons[index]

	# Snapshot the on-disk values once, so R reverts and * flags unsaved edits
	if not _snapshots.has(current_weapon.resource_path):
		_snapshots[current_weapon.resource_path] = {
			"hp": current_weapon.hip_position, "hr": current_weapon.hip_rotation,
			"ap": current_weapon.ads_position, "ar": current_weapon.ads_rotation,
			"hb": current_weapon.bore_dir, "ab": current_weapon.ads_bore_dir,
		}

	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null
		_vm_meshes = []
		_vm_anim = null
		_clips = PackedStringArray()
		_clip_index = 0

	var load_failed := false
	if not current_weapon.model_path.is_empty():
		# Bypass cache so .tscn edits show after F5 without restarting
		var scene: PackedScene = ResourceLoader.load(current_weapon.model_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if scene:
			weapon_model = scene.instantiate()
			if weapon_model:
				weapon_holder.add_child(weapon_model)
				# WYSIWYG CONTRACT: the bench renders through the SAME ViewmodelLens
				# calls as weapon_holder.gd (ADR-034) - shared code, not copied math.
				if ViewmodelLens.ENABLED:
					_vm_meshes = ViewmodelLens.apply(weapon_model)
				else:
					weapon_model.scale *= WeaponHolder._lens_ratio(current_weapon)
				# Mirror the game: without the idle clip an arms viewmodel renders in bind pose.
				_vm_anim = weapon_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if _vm_anim:
					for a in _vm_anim.get_animation_list():
						if a != "RESET":
							_clips.append(a)
					_vm_anim.animation_finished.connect(_on_clip_finished)
					if _vm_anim.has_animation("rifle_idle"):
						_clip_index = maxi(0, _clips.find("rifle_idle"))
						_vm_anim.play("rifle_idle")
			else:
				load_failed = true
				push_warning("[ViewmodelEditor] %s scene instantiate failed: %s" % [current_weapon.display_name, current_weapon.model_path])
		else:
			load_failed = true
			push_warning("[ViewmodelEditor] %s scene load failed: %s" % [current_weapon.display_name, current_weapon.model_path])

	# Unconditionally, even for [NO MODEL] weapons: otherwise the previous
	# weapon's edit values would be saved into this weapon's .tres on Ctrl+S
	_load_edit_from_resource()

	if _no_model_label:
		if load_failed:
			_no_model_label.text = "VIEWMODEL LOAD FAILED\n%s" % current_weapon.model_path
			_no_model_label.visible = true
		elif weapon_model == null:
			_no_model_label.text = "NO VIEWMODEL\n(model_path is empty in the .tres)"
			_no_model_label.visible = true
		else:
			_no_model_label.visible = false
	_update_mode_button()
	_update_camera_fov()
	print("[ViewmodelEditor] loaded %s  model=%s" % [current_weapon.display_name, current_weapon.model_path])


func _load_edit_from_resource() -> void:
	if not current_weapon:
		return
	if preview_mode == 0:
		edit_position = current_weapon.hip_position
		edit_rotation = current_weapon.hip_rotation
	else:
		edit_position = current_weapon.ads_position
		edit_rotation = current_weapon.ads_rotation
	if weapon_model:
		weapon_model.position = edit_position
		weapon_model.rotation_degrees = edit_rotation


## Write the current nudge into the model AND the in-memory resource. The
## resource is the save unit - Ctrl+S just serializes what you see.
func _apply_edit() -> void:
	if weapon_model:
		weapon_model.position = edit_position
		weapon_model.rotation_degrees = edit_rotation
	if not current_weapon:
		return
	if preview_mode == 0:
		current_weapon.hip_position = edit_position
		current_weapon.hip_rotation = edit_rotation
	else:
		current_weapon.ads_position = edit_position
		current_weapon.ads_rotation = edit_rotation


func _revert_to_snapshot() -> void:
	if not current_weapon:
		return
	var snap: Dictionary = _snapshots.get(current_weapon.resource_path, {})
	if snap.is_empty():
		return
	current_weapon.hip_position = snap["hp"]
	current_weapon.hip_rotation = snap["hr"]
	current_weapon.ads_position = snap["ap"]
	current_weapon.ads_rotation = snap["ar"]
	current_weapon.bore_dir = snap["hb"]
	current_weapon.ads_bore_dir = snap["ab"]
	_load_edit_from_resource()
	_flash("REVERTED to saved values")


func _save_weapon() -> void:
	if not current_weapon:
		return
	if weapon_model:
		_apply_edit()
	var err: int = ResourceSaver.save(current_weapon, current_weapon.resource_path)
	if err == OK:
		_snapshots[current_weapon.resource_path] = {
			"hp": current_weapon.hip_position, "hr": current_weapon.hip_rotation,
			"ap": current_weapon.ads_position, "ar": current_weapon.ads_rotation,
			"hb": current_weapon.bore_dir, "ab": current_weapon.ads_bore_dir,
		}
		_flash("SAVED -> %s" % current_weapon.resource_path)
		print("[ViewmodelEditor] saved %s" % current_weapon.resource_path)
	else:
		_flash("SAVE FAILED (err %d)" % err)


## [origin, direction] of the bore in GLOBAL space. Origin = the MuzzlePoint
## marker (the node the game spawns rounds from). Direction = the CALIBRATED
## bore_dir for the current preview mode, falling back to the contract axis
## (root -Z) - NEVER the marker's own basis: the Blender empties are position
## markers and are not aimed.
func _bore_ray() -> Array:
	if not weapon_model:
		return []
	var local_bore: Vector3 = _get_current_bore_dir()
	if local_bore == Vector3.ZERO:
		local_bore = Vector3(0, 0, -1)
	local_bore = local_bore.normalized()
	var fdir: Vector3 = (weapon_model.global_transform.basis * local_bore).normalized()
	var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
	if muzzle:
		return [muzzle.global_position, fdir]
	return [weapon_model.global_position + fdir * 0.5, fdir]


func _get_current_bore_dir() -> Vector3:
	if current_weapon == null:
		return Vector3.ZERO
	if preview_mode == 0:
		return current_weapon.bore_dir
	return current_weapon.ads_bore_dir


func _set_current_bore_dir(v: Vector3) -> void:
	if current_weapon == null:
		return
	if preview_mode == 0:
		current_weapon.bore_dir = v
	else:
		current_weapon.ads_bore_dir = v


func _update_laser() -> void:
	_bore_valid = false
	if not _laser_mesh:
		return
	_laser_mesh.clear_surfaces()
	if not laser_enabled or not weapon_model:
		return
	var ray: Array = _bore_ray()
	if ray.is_empty():
		return
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]

	# Intersect the board plane (z = -BOARD_DIST)
	var end: Vector3 = origin + dir * 60.0
	if dir.z < -0.001:
		var t: float = (-BOARD_DIST - origin.z) / dir.z
		if t > 0.0 and t < 60.0:
			end = origin + dir * t
			_bore_offset = Vector2(end.x - BOARD_CENTER.x, end.y - BOARD_CENTER.y)
			_bore_valid = true

	# The laser MATH above uses the true muzzle (where rounds spawn). The DRAWN
	# near end starts at the muzzle as it appears through the lens, or the beam
	# would hang visibly off the drawn barrel (ADR-034).
	var draw_origin: Vector3 = origin
	if ViewmodelLens.ENABLED and current_weapon:
		draw_origin = ViewmodelLens.apparent_point(camera, current_weapon.viewmodel_fov, origin)
	_laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var laser_col := Color(1.0, 0.15, 0.1)
	_laser_mesh.surface_set_color(laser_col)
	_laser_mesh.surface_add_vertex(draw_origin)
	_laser_mesh.surface_set_color(laser_col)
	_laser_mesh.surface_add_vertex(end)
	# Impact diamond, drawn just off the board so it never z-fights
	if _bore_valid:
		var hit := Vector3(end.x, end.y, -BOARD_DIST + 0.05)
		var s: float = 0.06
		var dot_col := Color(1.0, 0.9, 0.1)
		var pts: Array[Vector3] = [
			hit + Vector3(-s, 0, 0), hit + Vector3(0, s, 0),
			hit + Vector3(0, s, 0), hit + Vector3(s, 0, 0),
			hit + Vector3(s, 0, 0), hit + Vector3(0, -s, 0),
			hit + Vector3(0, -s, 0), hit + Vector3(-s, 0, 0),
		]
		for p in pts:
			_laser_mesh.surface_set_color(dot_col)
			_laser_mesh.surface_add_vertex(p)
	_laser_mesh.surface_end()


## Rotate the model (pitch/yaw only, roll untouched) so the current mode's
## bore passes through the board center = crosshair. Delta-form + iteration
## converges even when the MuzzlePoint carries its own orientation offset.
func _auto_align() -> void:
	if not weapon_model or not current_weapon:
		return
	for i in range(3):
		var ray: Array = _bore_ray()
		if ray.is_empty():
			return
		var origin: Vector3 = ray[0]
		var cur_dir: Vector3 = ray[1]
		var want_dir: Vector3 = (BOARD_CENTER - origin).normalized()
		var inv: Basis = weapon_holder.global_transform.basis.inverse()
		var cur_l: Vector3 = (inv * cur_dir).normalized()
		var want_l: Vector3 = (inv * want_dir).normalized()
		var d_yaw: float = rad_to_deg(atan2(-want_l.x, -want_l.z) - atan2(-cur_l.x, -cur_l.z))
		var d_pitch: float = rad_to_deg(asin(clampf(want_l.y, -1.0, 1.0)) - asin(clampf(cur_l.y, -1.0, 1.0)))
		_rotate_about_gun(Vector3(d_pitch, d_yaw, 0.0))
		_apply_edit()
	var mode_name: String = "HIP" if preview_mode == 0 else "ADS"
	_flash("AUTO-ALIGNED %s bore to crosshair (B)" % mode_name)


## V: rear sight at camera center with the front sight down the view axis.
## Independent of the hip zero, so switching to ADS no longer drags the hip
## crosshair offset with it.
func _auto_align_ads_sights() -> void:
	const EYE_RELIEF: float = 0.12
	_align_to_sight_markers(Vector3(0.0, 0.0, -EYE_RELIEF), 1)


## H: same markers, hip-carry zone - sight line parallel to the camera axis,
## rear sight lower-right of the eye. One keypress recovers a legacy off-screen
## hip pose; nudge from there and Ctrl+S.
func _auto_align_hip() -> void:
	const HIP_ANCHOR: Vector3 = Vector3(0.09, -0.14, -0.30)
	_align_to_sight_markers(HIP_ANCHOR, 0)


## Shared V/H align: carry the SightRear->SightFront line onto the view axis,
## level the roll, park the rear sight at target_rear, and calibrate the mode's
## bore dir to the sight line so the laser/crosshair tracks the sights instead
## of a stale hand-dialed vector.
func _align_to_sight_markers(target_rear: Vector3, mode: int) -> void:
	if not weapon_model or not current_weapon:
		return
	var rear: Node3D = _find_ads_marker("rear")
	var front: Node3D = _find_ads_marker("front")
	if rear == null or front == null:
		_flash("ALIGN: no SightRear/SightFront markers in this model")
		return

	# The markers are NOT children of weapon_model - they hang off the gun node,
	# which hangs off hand.R inside the arm chain. Their .position is local to that
	# parent, so it must be converted into weapon_model space before the basis math
	# below means anything. _bore_ray() reads global_position for the same reason.
	var to_model: Transform3D = weapon_model.global_transform.affine_inverse()
	var m_rear: Vector3 = to_model * rear.global_position
	var m_front: Vector3 = to_model * front.global_position
	var sight_vec: Vector3 = (m_front - m_rear).normalized()

	# Shortest rotation that carries the current sight line onto the camera axis.
	var cur_dir: Vector3 = (weapon_model.basis * sight_vec).normalized()
	var delta_rot: Quaternion = _quaternion_from_to(cur_dir, Vector3(0, 0, -1))
	var new_quat: Quaternion = delta_rot * Quaternion.from_euler(weapon_model.rotation)

	# Level the roll (the axis _quaternion_from_to leaves free): the muzzle sits
	# BELOW the sight line, so muzzle->sight-line perpendicular is the gun's true
	# up. Roll about the view axis until it points straight up on screen.
	var gun_up: Vector3 = Vector3.UP - sight_vec * Vector3.UP.dot(sight_vec)
	var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
	if muzzle:
		var lift: Vector3 = m_rear - (to_model * muzzle.global_position)
		lift -= sight_vec * lift.dot(sight_vec)
		if lift.length() > 0.005:
			gun_up = lift
	var up_now: Vector3 = Basis(new_quat) * gun_up.normalized()
	if Vector2(up_now.x, up_now.y).length() > 0.001:
		new_quat = Quaternion(Vector3(0, 0, 1), atan2(up_now.x, up_now.y)) * new_quat

	# Apply rotation first so the basis is correct for positioning.
	var new_rot_rad: Vector3 = new_quat.get_euler()
	weapon_model.rotation = new_rot_rad
	edit_rotation = Vector3(
		rad_to_deg(new_rot_rad.x),
		rad_to_deg(new_rot_rad.y),
		rad_to_deg(new_rot_rad.z))

	# Now translate so the rear sight sits at the requested anchor.
	weapon_model.position = target_rear - weapon_model.basis * m_rear
	edit_position = weapon_model.position

	if mode == 0:
		current_weapon.bore_dir = sight_vec
	else:
		current_weapon.ads_bore_dir = sight_vec

	preview_mode = mode
	_apply_edit()
	_update_mode_button()
	_update_camera_fov()
	if mode == 0:
		_flash("HIP ALIGNED to sight markers + bore (H)")
	else:
		_flash("ADS ALIGNED to sight markers + bore (V)")


## Center the current model in the viewport without changing rotation. Useful if
## a weapon appears to have "disappeared" (off-screen due to an old child offset
## or bad edit position). Press F to bring it back into view, then tune normally.
func _frame_model() -> void:
	if not weapon_model:
		return
	var aabb := _model_aabb(weapon_model)
	if aabb.size.length() <= 0.001:
		_flash("FRAME MODEL: no mesh found")
		return
	# Place the mesh's local bounding-box center at (0, 0, -0.5) in front of camera.
	edit_position = Vector3(-aabb.get_center().x, -aabb.get_center().y, -aabb.get_center().z - 0.5)
	_apply_edit()
	_flash("FRAMED model (F)")


## True when any of the model's mesh AABB corners sits at or behind the camera
## plane. The lens depth squash stops WORLD clipping, but a vertex behind the
## eye is cut by the projection itself - no shader can draw it.
func _geometry_behind_eye() -> bool:
	if weapon_model == null or camera == null:
		return false
	var to_cam: Transform3D = camera.global_transform.affine_inverse()
	for c in weapon_model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = mi.mesh.get_aabb()
		var xf: Transform3D = to_cam * mi.global_transform
		for i in 8:
			if (xf * box.get_endpoint(i)).z > -0.01:
				return true
	return false


func _model_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for c in node.find_children("*", "MeshInstance3D", true):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local_aabb: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			aabb = local_aabb
			first = false
		else:
			aabb = aabb.merge(local_aabb)
	return aabb


func _find_ads_marker(kind: String) -> Node3D:
	if not weapon_model:
		return null
	# A ternary between array literals evaluates as untyped Array and throws on a
	# typed target at runtime - assign each literal directly so context typing holds.
	var want: Array[String] = ["SightFront", "sight_front"]
	if kind == "rear":
		want = ["SightRear", "sight_rear"]
	for child in weapon_model.find_children("*", "Node3D", true):
		var n: Node3D = child as Node3D
		if n == null:
			continue
		var lower: String = str(n.name).to_lower()
		for prefix in want:
			if lower.begins_with(prefix) or lower.contains("_" + prefix) or lower == prefix.to_lower():
				return n
	return null


func _quaternion_from_to(from: Vector3, to: Vector3) -> Quaternion:
	var a: Vector3 = from.normalized()
	var b: Vector3 = to.normalized()
	var dot: float = a.dot(b)
	if dot > 0.999999:
		return Quaternion.IDENTITY
	if dot < -0.999999:
		var axis: Vector3 = Vector3.RIGHT
		if absf(a.x) < 0.9:
			axis = Vector3.UP
		return Quaternion(axis, PI)
	var axis: Vector3 = a.cross(b).normalized()
	var angle: float = acos(clampf(dot, -1.0, 1.0))
	return Quaternion(axis, angle)


func _is_modified() -> bool:
	if not current_weapon:
		return false
	var snap: Dictionary = _snapshots.get(current_weapon.resource_path, {})
	if snap.is_empty():
		return false
	return current_weapon.hip_position != snap["hp"] \
		or current_weapon.hip_rotation != snap["hr"] \
		or current_weapon.ads_position != snap["ap"] \
		or current_weapon.ads_rotation != snap["ar"] \
		or current_weapon.bore_dir != snap["hb"] \
		or current_weapon.ads_bore_dir != snap["ab"]


## Largest per-axis gap between hip and ADS rotation. >90 deg risks the
## viewmodel spinning the long way round during the ADS lerp (CLAUDE.md rule).
func _rot_divergence() -> float:
	if not current_weapon:
		return 0.0
	var d: Vector3 = (current_weapon.hip_rotation - current_weapon.ads_rotation).abs()
	return maxf(d.x, maxf(d.y, d.z))


func _update_position_display() -> void:
	if not position_label:
		return
	if not current_weapon:
		position_label.text = "no weapon"
		return

	var mode_name: String = "HIP" if preview_mode == 0 else "ADS"
	var lines: Array[String] = []
	lines.append("%s%s  [%s]" % [current_weapon.display_name,
		"  *UNSAVED" if _is_modified() else "", mode_name])
	lines.append("cam fov %.0f   lens fov %.0f (eff %.0f)" % [camera.fov,
		current_weapon.viewmodel_fov,
		ViewmodelLens.effective_fov(current_weapon.viewmodel_fov, camera.fov)])
	if _geometry_behind_eye():
		lines.append("! GEOMETRY AT/BEHIND THE EYE - it will clip (pull the pose forward)")
	lines.append("")
	lines.append("pos Vector3(%.3f, %.3f, %.3f)" % [edit_position.x, edit_position.y, edit_position.z])
	lines.append("rot Vector3(%.1f, %.1f, %.1f)" % [edit_rotation.x, edit_rotation.y, edit_rotation.z])

	var active_bore: Vector3 = _get_current_bore_dir()
	var active_bore_name: String = "HIP bore" if preview_mode == 0 else "ADS bore"
	if active_bore != Vector3.ZERO:
		lines.append("%s CALIBRATED (%.2f, %.2f, %.2f)   Shift+B reset" % [
			active_bore_name, active_bore.x, active_bore.y, active_bore.z])
	else:
		lines.append("%s = contract -Z   I/K/U/O: calibrate" % active_bore_name)

	if current_weapon.bore_dir != Vector3.ZERO and current_weapon.ads_bore_dir != Vector3.ZERO:
		var d: float = acos(clampf(current_weapon.bore_dir.normalized().dot(current_weapon.ads_bore_dir.normalized()), -1.0, 1.0))
		lines.append("hip/ADS bore divergence: %.1f mrad" % (d * 1000.0))
	lines.append("")
	if _bore_valid:
		var mrad: float = _bore_offset.length() / BOARD_DIST * 1000.0
		lines.append("BORE @%dm:  x %+.1fcm  y %+.1fcm" % [int(BOARD_DIST), _bore_offset.x * 100.0, _bore_offset.y * 100.0])
		if _bore_offset.length() <= ALIGN_TOLERANCE_M:
			lines.append(">>> ALIGNED (%.1f mrad) <<<" % mrad)
		else:
			lines.append("off by %.1f mrad  (B = auto-align)" % mrad)
	elif weapon_model:
		lines.append("BORE: not on board (aim/rotation off)")
	if _rot_divergence() > 90.0:
		lines.append("! HIP vs ADS rot differs >90deg - ADS spin risk")
	position_label.text = "\n".join(lines)


func _on_weapon_selected(index: int) -> void:
	_load_weapon(index)


func _on_mode_toggle() -> void:
	preview_mode = 1 - preview_mode
	_load_edit_from_resource()
	_update_mode_button()
	_update_camera_fov()


## SYNC CONTRACT: hip = the game's BASE_FOV 75, ADS = the weapon's own ads_fov -
## exactly like weapon_holder.gd _update_ads. This camera stays the PLAYER's
## camera; the viewmodel lens is applied to the MODEL on load, never here.
func _update_camera_fov() -> void:
	if not camera:
		return
	if preview_mode == 1 and current_weapon and current_weapon.ads_fov > 1.0:
		camera.fov = current_weapon.ads_fov
	else:
		camera.fov = BASE_FOV
	if ViewmodelLens.ENABLED and current_weapon and not _vm_meshes.is_empty():
		ViewmodelLens.set_fov(_vm_meshes,
			ViewmodelLens.effective_fov(current_weapon.viewmodel_fov, camera.fov))


func _on_reload_weapon() -> void:
	print("[ViewmodelEditor] Reloading weapon...")
	_load_weapon(current_weapon_index)


func _update_mode_button() -> void:
	if mode_toggle:
		mode_toggle.text = "Mode: ADS" if preview_mode == 1 else "Mode: Hip"


func _on_copy_values() -> void:
	var pos_name: String = "ads_position" if preview_mode == 1 else "hip_position"
	var rot_name: String = "ads_rotation" if preview_mode == 1 else "hip_rotation"
	var text := "%s = Vector3(%.3f, %.3f, %.3f)\n%s = Vector3(%.1f, %.1f, %.1f)" % [
		pos_name, edit_position.x, edit_position.y, edit_position.z,
		rot_name, edit_rotation.x, edit_rotation.y, edit_rotation.z
	]
	DisplayServer.clipboard_set(text)
	_flash("COPIED!\n\n" + text)


func _flash(text: String) -> void:
	copy_feedback_timer = 2.5
	if copy_feedback:
		copy_feedback.text = text
		copy_feedback.visible = true


func _update_copy_feedback(delta: float) -> void:
	if copy_feedback_timer > 0.0:
		copy_feedback_timer -= delta
		if copy_feedback_timer <= 0.0 and copy_feedback:
			copy_feedback.visible = false


func _get_instructions() -> String:
	return """VIEWMODEL ALIGNMENT BENCH

POSITION   W/S fwd/back  A/D  Q/E up/dn
ROTATION   Arrows pitch/yaw  PgUp/Dn roll
           (pivots on the gun, not the node origin)
           Shift = fine (x0.1)   Alt stacks (x0.01)

ALIGN      B - auto-align current-mode bore to crosshair
           V - align ADS to SightRear/SightFront markers
           H - align HIP to the same markers (carry zone)
           I/K/U/O - calibrate bore for current mode
           Shift+B - reset current-mode bore   L - laser
           G - toggle alignment grid
           F - frame model (bring it back if it vanishes)

SAVE       Ctrl+S - write into the .tres
           R - revert to saved
           C - copy values to clipboard

WEAPONS    Z/X - prev/next   1-9 - direct
           Space - Hip/ADS (real ADS FOV)
           F5 - reload model scene

CLIPS      N - play next clip (Shift+N back)
           finished clips fall back to rifle_idle

Hip and ADS have independent bore zeros. Tuning one
never moves the other. V/H use the model sight markers."""


## ---------- RANGE VISUALS ----------

func _build_range() -> void:
	var board := MeshInstance3D.new()
	board.name = "TargetBoard"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	board.mesh = plane
	board.position = BOARD_CENTER
	board.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.18)
	mat.roughness = 0.9
	board.material_override = mat
	add_child(board)

	var pole := MeshInstance3D.new()
	pole.name = "TargetPole"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 3.5
	pole.mesh = cyl
	pole.position = Vector3(BOARD_CENTER.x, 1.75, BOARD_CENTER.z + 0.04)
	pole.material_override = mat
	add_child(pole)


func _build_laser() -> void:
	_laser_mesh = ImmediateMesh.new()
	_laser_node = MeshInstance3D.new()
	_laser_node.name = "BoreLaser"
	_laser_node.mesh = _laser_mesh
	var laser_mat := StandardMaterial3D.new()
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.vertex_color_use_as_albedo = true
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_node.material_override = laser_mat
	add_child(_laser_node)


func _build_grid() -> void:
	_grid_node = MeshInstance3D.new()
	_grid_node.name = "AlignmentGrid"
	var im := ImmediateMesh.new()
	_grid_node.mesh = im
	_grid_node.visible = false
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.vertex_color_use_as_albedo = true
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_node.material_override = grid_mat

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var col := Color(0.0, 1.0, 0.0, 0.3)
	for i in range(-6, 7):
		var o: float = i * 0.5
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(o, 0.0, -BOARD_DIST + 0.02))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(o, 4.0, -BOARD_DIST + 0.02))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(-3.0, o + 1.7, -BOARD_DIST + 0.02))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(3.0, o + 1.7, -BOARD_DIST + 0.02))
	im.surface_end()
	add_child(_grid_node)


func _build_no_model_label() -> void:
	_no_model_label = Label.new()
	_no_model_label.text = "NO VIEWMODEL\n(model_path is empty in the .tres)"
	_no_model_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_model_label.add_theme_font_size_override("font_size", 28)
	_no_model_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_no_model_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_no_model_label.add_theme_constant_override("outline_size", 4)
	_no_model_label.set_anchors_preset(Control.PRESET_CENTER)
	_no_model_label.visible = false
	$CanvasLayer.add_child(_no_model_label)


func _build_save_button() -> void:
	_save_button = Button.new()
	_save_button.text = "Save (Ctrl+S)"
	_save_button.position = Vector2(10.0, 130.0)
	_save_button.pressed.connect(_save_weapon)
	$CanvasLayer.add_child(_save_button)
