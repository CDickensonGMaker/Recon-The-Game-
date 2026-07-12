## viewmodel_editor.gd - Standalone viewmodel ALIGNMENT WORKBENCH.
##
## Launch outside the game (viewmodel_editor.bat at the project root). The
## camera rig mirrors the player exactly - head at Y=1.7, hip FOV 75,
## WeaponHolder identity transform (the sync contract in CLAUDE.md) - so what
## you align here is what the game renders.
##
## Workflow per gun: nudge with WASD/QE + arrows until the red bore laser dot
## sits on the target-board center (= the crosshair), or press B to auto-align
## the rotation, then Ctrl+S to write straight back into the .tres. Z/X cycle
## the whole armory. The weapon list is auto-discovered from data/weapons/.
##
## In-game bullets are REAL projectiles now (7ks, BulletSystem): they spawn at
## the gun's MuzzlePoint and converge onto the crosshair's aim point
## (weapon_holder.gd _fire_shot). Alignment here matters MORE than under
## hitscan - a misaligned gun visibly lofts its round sideways into the
## convergence line. Goal unchanged: the bore laser dot ON the crosshair.
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

## Range visuals
var _laser_node: MeshInstance3D = null
var _laser_mesh: ImmediateMesh = null
var _grid_node: MeshInstance3D = null
var _no_model_label: Label = null
var _save_button: Button = null
var _bore_offset: Vector2 = Vector2.ZERO  ## meters on the board plane
var _bore_valid: bool = false

## Movement speeds
const MOVE_SPEED: float = 0.5
const ROTATE_SPEED: float = 45.0

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
	# Weapon switching works even with no model loaded
	if _pressed_once(KEY_Z):
		_step_weapon(-1)
	if _pressed_once(KEY_X):
		_step_weapon(1)
	for i in range(mini(weapons.size(), 9)):
		if _pressed_once(KEY_1 + i):
			weapon_selector.select(i)
			_load_weapon(i)
			break
	if _pressed_once(KEY_F5):
		_on_reload_weapon()
	if Input.is_key_pressed(KEY_CTRL) and _pressed_once(KEY_S):
		_save_weapon()
	if _pressed_once(KEY_L):
		laser_enabled = not laser_enabled

	if Input.is_action_just_pressed("ui_accept"):
		_on_mode_toggle()

	if not weapon_model:
		return

	# Position adjustments (WASD + Q/E). Ctrl reserved for Ctrl+S.
	var move_input := Vector3.ZERO
	if not Input.is_key_pressed(KEY_CTRL):
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

	# Rotation adjustments (Arrow keys + Page Up/Down)
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

	var speed_mult: float = 0.1 if Input.is_key_pressed(KEY_SHIFT) else 1.0

	if move_input != Vector3.ZERO or rot_input != Vector3.ZERO:
		edit_position += move_input * MOVE_SPEED * speed_mult * delta
		edit_rotation += rot_input * ROTATE_SPEED * speed_mult * delta
		_apply_edit()

	# BORE CALIBRATION (I/K/U/O): lay the laser along the barrel BY EYE, once
	# per gun - Ctrl+S persists it (WeaponData.bore_dir, viewmodel-local).
	# The baked posed holds give no data axis to trust; your eye is the truth
	# source here, and B then auto-aligns against the calibrated bore.
	var bore_input := Vector2.ZERO   # x = yaw (U/O), y = pitch (I/K)
	if not Input.is_key_pressed(KEY_CTRL):
		if Input.is_key_pressed(KEY_I):
			bore_input.y += 1.0
		if Input.is_key_pressed(KEY_K):
			bore_input.y -= 1.0
		if Input.is_key_pressed(KEY_U):
			bore_input.x += 1.0
		if Input.is_key_pressed(KEY_O):
			bore_input.x -= 1.0
	if bore_input != Vector2.ZERO and current_weapon != null:
		var b: Vector3 = current_weapon.bore_dir
		if b == Vector3.ZERO:
			b = Vector3(0, 0, -1)
		var bstep: float = deg_to_rad(20.0) * speed_mult * delta
		b = b.rotated(Vector3.RIGHT, bore_input.y * bstep)
		b = b.rotated(Vector3.UP, bore_input.x * bstep)
		current_weapon.bore_dir = b.normalized()

	if _pressed_once(KEY_R) and not Input.is_key_pressed(KEY_CTRL):
		_revert_to_snapshot()
	if _pressed_once(KEY_B):
		if Input.is_key_pressed(KEY_SHIFT):
			if current_weapon != null:
				current_weapon.bore_dir = Vector3.ZERO
				_flash("BORE reset to contract axis (-Z)")
		else:
			_auto_align()
	if _pressed_once(KEY_C) and not Input.is_key_pressed(KEY_CTRL):
		_on_copy_values()
	if _pressed_once(KEY_G) and _grid_node != null:
		_grid_node.visible = not _grid_node.visible


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
		}

	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null

	if not current_weapon.model_path.is_empty():
		# Bypass cache so .tscn edits show after F5 without restarting
		var scene: PackedScene = ResourceLoader.load(current_weapon.model_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if scene:
			weapon_model = scene.instantiate()
			weapon_holder.add_child(weapon_model)
			# Mirror the game (weapon_holder.gd): without the idle clip a
			# rigged arms viewmodel renders in bind pose
			var vm_anim: AnimationPlayer = weapon_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if vm_anim and vm_anim.has_animation("rifle_idle"):
				vm_anim.play("rifle_idle")

	# Unconditionally, even for [NO MODEL] weapons: otherwise the previous
	# weapon's edit values would be saved into this weapon's .tres on Ctrl+S
	_load_edit_from_resource()

	if _no_model_label:
		_no_model_label.visible = weapon_model == null
	_update_mode_button()
	_update_camera_fov()


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
		}
		_flash("SAVED -> %s" % current_weapon.resource_path)
		print("[ViewmodelEditor] saved %s" % current_weapon.resource_path)
	else:
		_flash("SAVE FAILED (err %d)" % err)
		push_error("[ViewmodelEditor] ResourceSaver.save failed: %d" % err)


## ---------------------------------------------------------------- bore laser

## [origin, direction] of the bore in GLOBAL space. Origin = the MuzzlePoint
## marker (the same node the game spawns bullets at). Direction = the
## CALIBRATED bore (WeaponData.bore_dir, authored here with I/K/U/O), falling
## back to the contract axis (root -Z). NOT the marker's own basis (the
## Blender muzzle empties are position markers, never aimed - the laser fired
## out of gun tops) and NOT blindly the contract axis either (arms viewmodels
## are baked POSED holds - the barrel sits wherever the hand holds it).
## normalized(): the global basis carries the baked root scale (~0.03), which
## otherwise breaks the board-plane t bound.
func _bore_ray() -> Array:
	if not weapon_model:
		return []
	var local_bore: Vector3 = Vector3(0, 0, -1)
	if current_weapon != null and current_weapon.bore_dir != Vector3.ZERO:
		local_bore = current_weapon.bore_dir.normalized()
	var fdir: Vector3 = (weapon_model.global_transform.basis * local_bore).normalized()
	var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
	if muzzle:
		return [muzzle.global_position, fdir]
	return [weapon_model.global_position + fdir * 0.5, fdir]


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

	_laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var laser_col := Color(1.0, 0.15, 0.1)
	_laser_mesh.surface_set_color(laser_col)
	_laser_mesh.surface_add_vertex(origin)
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


## Rotate the model (pitch/yaw only, roll untouched) so the bore passes through
## the board center = crosshair. Delta-form + iteration converges even when the
## MuzzlePoint carries its own orientation offset.
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
		edit_rotation.x += d_pitch
		edit_rotation.y += d_yaw
		_apply_edit()
	_flash("AUTO-ALIGNED bore to crosshair (B)")


## CALIBRATION GRID (Caleb 2026-07-11): a shooting-tunnel lattice so "even"
## is judged against straight lines, not open air. Depth rails run from the
## firing line to the board - the laser must run PARALLEL to them; any cant
## reads instantly against the converging perspective. The eye-height center
## rail (the true aim line, x=0 y=1.7) is highlighted. Cross-frames every 5m
## give depth reference; graph lines on the board give the dot a ruler.
## G toggles.
func _build_grid() -> void:
	var im := ImmediateMesh.new()
	_grid_node = MeshInstance3D.new()
	_grid_node.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_grid_node.material_override = mat
	add_child(_grid_node)
	var dim := Color(0.28, 0.36, 0.30)
	var bright := Color(0.55, 0.80, 0.55)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Depth rails (0.5m lattice, firing line -> board).
	for xi in range(-4, 5):
		for yi in range(0, 8):
			var x: float = float(xi) * 0.5
			var y: float = float(yi) * 0.5
			im.surface_set_color(dim)
			im.surface_add_vertex(Vector3(x, y, 0.0))
			im.surface_set_color(dim)
			im.surface_add_vertex(Vector3(x, y, -BOARD_DIST))
	# The true aim rail: eye height, dead center - where a perfect bore lives.
	im.surface_set_color(bright)
	im.surface_add_vertex(Vector3(0.0, 1.7, 0.0))
	im.surface_set_color(bright)
	im.surface_add_vertex(Vector3(0.0, 1.7, -BOARD_DIST))
	# Cross-frames every 5m for depth reference.
	for zi in range(1, 5):
		var z: float = -5.0 * float(zi)
		var corners: Array[Vector3] = [
			Vector3(-2.0, 0.0, z), Vector3(2.0, 0.0, z),
			Vector3(2.0, 0.0, z), Vector3(2.0, 3.5, z),
			Vector3(2.0, 3.5, z), Vector3(-2.0, 3.5, z),
			Vector3(-2.0, 3.5, z), Vector3(-2.0, 0.0, z),
		]
		for p in corners:
			im.surface_set_color(dim)
			im.surface_add_vertex(p)
	# Board graph paper (0.25m ruling, just off the board plane).
	var bz: float = -BOARD_DIST + 0.03
	for gx in range(-12, 13):
		var x2: float = float(gx) * 0.25
		im.surface_set_color(bright if gx == 0 else dim)
		im.surface_add_vertex(Vector3(x2, 0.0, bz))
		im.surface_set_color(bright if gx == 0 else dim)
		im.surface_add_vertex(Vector3(x2, 3.5, bz))
	for gy in range(0, 15):
		var y2: float = float(gy) * 0.25
		var row_col: Color = bright if absf(y2 - 1.75) < 0.13 else dim
		im.surface_set_color(row_col)
		im.surface_add_vertex(Vector3(-3.0, y2, bz))
		im.surface_set_color(row_col)
		im.surface_add_vertex(Vector3(3.0, y2, bz))
	im.surface_end()


## ---------------------------------------------------------------- the range

func _build_range() -> void:
	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _flat_mat(Color(0.18, 0.22, 0.14))
	add_child(floor_mesh)

	# Back wall behind the board
	var wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(16.0, 6.0, 0.3)
	wall.mesh = wall_box
	wall.position = Vector3(0.0, 3.0, -BOARD_DIST - 0.5)
	wall.material_override = _flat_mat(Color(0.35, 0.32, 0.28))
	add_child(wall)

	# Target board: center EXACTLY on the camera axis at eye height
	var board := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	board.mesh = quad
	board.position = Vector3(BOARD_CENTER.x, BOARD_CENTER.y, -BOARD_DIST - 0.02)
	board.material_override = _flat_mat(Color(0.92, 0.9, 0.85))
	add_child(board)

	# Rings + center cross (static line art)
	var rings := MeshInstance3D.new()
	var rings_mesh := ImmediateMesh.new()
	rings.mesh = rings_mesh
	rings.material_override = _line_mat()
	add_child(rings)
	rings_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var radii: Array[float] = [0.05, 0.125, 0.25, 0.5, 1.0, 1.45]
	for r_i in range(radii.size()):
		var radius: float = radii[r_i]
		var col: Color = Color(0.8, 0.1, 0.1) if r_i % 2 == 0 else Color(0.1, 0.1, 0.1)
		var segments: int = 64
		for s_i in range(segments):
			var a0: float = TAU * float(s_i) / float(segments)
			var a1: float = TAU * float(s_i + 1) / float(segments)
			rings_mesh.surface_set_color(col)
			rings_mesh.surface_add_vertex(BOARD_CENTER + Vector3(cos(a0) * radius, sin(a0) * radius, 0.01))
			rings_mesh.surface_set_color(col)
			rings_mesh.surface_add_vertex(BOARD_CENTER + Vector3(cos(a1) * radius, sin(a1) * radius, 0.01))
	var cross_col := Color(0.1, 0.1, 0.1)
	rings_mesh.surface_set_color(cross_col)
	rings_mesh.surface_add_vertex(BOARD_CENTER + Vector3(-1.45, 0, 0.01))
	rings_mesh.surface_set_color(cross_col)
	rings_mesh.surface_add_vertex(BOARD_CENTER + Vector3(1.45, 0, 0.01))
	rings_mesh.surface_set_color(cross_col)
	rings_mesh.surface_add_vertex(BOARD_CENTER + Vector3(0, -1.45, 0.01))
	rings_mesh.surface_set_color(cross_col)
	rings_mesh.surface_add_vertex(BOARD_CENTER + Vector3(0, 1.45, 0.01))
	rings_mesh.surface_end()

	# Distance posts every 5m for depth reference
	for d in [5.0, 10.0, 15.0, 20.0]:
		for side in [-2.0, 2.0]:
			var post := MeshInstance3D.new()
			var post_box := BoxMesh.new()
			post_box.size = Vector3(0.08, 1.0, 0.08)
			post.mesh = post_box
			post.position = Vector3(side, 0.5, -d)
			post.material_override = _flat_mat(Color(0.6, 0.55, 0.4))
			add_child(post)


func _build_laser() -> void:
	_laser_mesh = ImmediateMesh.new()
	_laser_node = MeshInstance3D.new()
	_laser_node.mesh = _laser_mesh
	_laser_node.material_override = _line_mat()
	add_child(_laser_node)


func _flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _line_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	return m


func _build_save_button() -> void:
	var panel: VBoxContainer = $CanvasLayer/ControlPanel
	if not panel:
		return
	_save_button = Button.new()
	_save_button.text = "SAVE to .tres (Ctrl+S)"
	_save_button.pressed.connect(_save_weapon)
	panel.add_child(_save_button)


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


## ---------------------------------------------------------------- HUD

func _is_modified() -> bool:
	if not current_weapon:
		return false
	var snap: Dictionary = _snapshots.get(current_weapon.resource_path, {})
	if snap.is_empty():
		return false
	return current_weapon.hip_position != snap["hp"] \
		or current_weapon.hip_rotation != snap["hr"] \
		or current_weapon.ads_position != snap["ap"] \
		or current_weapon.ads_rotation != snap["ar"]


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
	lines.append("fov %.0f   scale %.2f" % [camera.fov, current_weapon.viewmodel_scale])
	lines.append("")
	lines.append("pos Vector3(%.3f, %.3f, %.3f)" % [edit_position.x, edit_position.y, edit_position.z])
	lines.append("rot Vector3(%.1f, %.1f, %.1f)" % [edit_rotation.x, edit_rotation.y, edit_rotation.z])
	if current_weapon.bore_dir != Vector3.ZERO:
		lines.append("bore CALIBRATED (%.2f, %.2f, %.2f)   Shift+B reset" % [
			current_weapon.bore_dir.x, current_weapon.bore_dir.y, current_weapon.bore_dir.z])
	else:
		lines.append("bore = contract -Z   I/K/U/O: calibrate to barrel")
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


## Hip = game BASE_FOV. ADS = the weapon's real ads_fov, exactly like
## weapon_holder.gd _update_ads - tuning ADS at 75 was silently wrong.
func _update_camera_fov() -> void:
	if not camera:
		return
	if preview_mode == 1 and current_weapon and current_weapon.ads_fov > 1.0:
		camera.fov = current_weapon.ads_fov
	else:
		camera.fov = BASE_FOV


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
           Shift = fine (x0.1)

ALIGN      B - auto-align bore to crosshair
           I/K/U/O - calibrate bore to barrel
           Shift+B - reset bore   L - laser
           G - toggle alignment grid

SAVE       Ctrl+S - write into the .tres
           R - revert to saved
           C - copy values to clipboard

WEAPONS    Z/X - prev/next   1-9 - direct
           Space - Hip/ADS (real ADS FOV)
           F5 - reload model scene

Laser dot on the board center = gun
agrees with the crosshair. Save and go."""
