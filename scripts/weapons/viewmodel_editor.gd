## viewmodel_editor.gd - Interactive viewmodel positioning tool
extends Node3D

## Weapon data resources for preview
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

## Copy feedback state
var copy_feedback_timer: float = 0.0
var _copy_key_held: bool = false

## State
var current_weapon_index: int = 0
var current_weapon: WeaponData = null
var weapon_model: Node3D = null
var preview_mode: int = 0  ## 0 = hip, 1 = ADS

## Position editing
var edit_position: Vector3 = Vector3.ZERO
var edit_rotation: Vector3 = Vector3.ZERO

## Movement speeds
const MOVE_SPEED: float = 0.5
const ROTATE_SPEED: float = 45.0

func _ready() -> void:
	# Auto-load weapons if not set
	if weapons.is_empty():
		_load_default_weapons()

	# Populate weapon selector
	if weapon_selector:
		for weapon in weapons:
			weapon_selector.add_item(weapon.display_name)
		weapon_selector.item_selected.connect(_on_weapon_selected)

	# Connect signals with null checks
	if mode_toggle:
		mode_toggle.pressed.connect(_on_mode_toggle)

	if copy_button:
		copy_button.pressed.connect(_on_copy_values)
		print("[ViewmodelEditor] Copy button connected")
	else:
		push_error("[ViewmodelEditor] Copy button not found!")

	if reload_button:
		reload_button.pressed.connect(_on_reload_weapon)

	# Load first weapon
	if not weapons.is_empty():
		_load_weapon(0)

	# Set instructions
	if instructions_label:
		instructions_label.text = _get_instructions()


func _load_default_weapons() -> void:
	# Full roster so every gun can have its hip/ADS/sight alignment tuned here.
	var weapon_paths: Array[String] = [
		"res://data/weapons/thompson.tres",
		"res://data/weapons/m1911.tres",
		"res://data/weapons/m16a1.tres",
		"res://data/weapons/car15.tres",
		"res://data/weapons/m60.tres",
		"res://data/weapons/sks.tres",
		"res://data/weapons/ak47.tres",
		"res://data/weapons/rpd.tres",
		"res://data/weapons/ppsh41.tres",
		"res://data/weapons/mosin.tres",
		"res://data/weapons/m79.tres",
		"res://data/weapons/m72_law.tres",
		"res://data/weapons/rpg2.tres",
		"res://data/weapons/rpg7.tres",
	]

	for path in weapon_paths:
		if ResourceLoader.exists(path):
			var weapon: WeaponData = load(path)
			if weapon:
				weapons.append(weapon)


func _process(delta: float) -> void:
	_handle_input(delta)
	_update_position_display()
	_update_copy_feedback(delta)


func _handle_input(delta: float) -> void:
	if not weapon_model:
		return

	# Toggle mode with Space
	if Input.is_action_just_pressed("ui_accept"):
		_on_mode_toggle()

	# Position adjustments (WASD + Q/E for up/down)
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

	# Fine adjustment with Shift
	var speed_mult: float = 0.1 if Input.is_key_pressed(KEY_SHIFT) else 1.0

	# Apply movement
	edit_position += move_input * MOVE_SPEED * speed_mult * delta
	edit_rotation += rot_input * ROTATE_SPEED * speed_mult * delta

	# Update weapon transform
	weapon_model.position = edit_position
	weapon_model.rotation_degrees = edit_rotation

	# Reset position with R
	if Input.is_action_just_pressed("ui_text_completion_replace"):  # R key in some contexts
		_reset_position()
	if Input.is_key_pressed(KEY_R) and not Input.is_key_pressed(KEY_CTRL):
		_reset_position()

	# Copy with C key (simple press)
	if Input.is_key_pressed(KEY_C) and not Input.is_key_pressed(KEY_CTRL):
		if not _copy_key_held:
			_copy_key_held = true
			_on_copy_values()
	else:
		_copy_key_held = false

	# Reload with F5
	if Input.is_key_pressed(KEY_F5):
		_on_reload_weapon()

	# Switch weapons with number keys
	for i in range(mini(weapons.size(), 9)):
		if Input.is_key_pressed(KEY_1 + i):
			weapon_selector.select(i)
			_load_weapon(i)
			break


func _load_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return

	current_weapon_index = index
	current_weapon = weapons[index]

	# Remove old model
	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null

	# Load new model
	if current_weapon and not current_weapon.model_path.is_empty():
		# Force reload to pick up any scene changes (bypass cache)
		var scene: PackedScene = ResourceLoader.load(current_weapon.model_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if scene:
			weapon_model = scene.instantiate()
			weapon_holder.add_child(weapon_model)

			# Don't override scale - use whatever is baked into the scene
			# This lets you adjust scale in the .tscn file directly

			# Load initial position based on mode
			_reset_position()

	# Update mode toggle text and FOV
	_update_mode_button()
	_update_camera_fov()


func _reset_position() -> void:
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


func _update_position_display() -> void:
	if not position_label:
		return

	var mode_name: String = "HIP" if preview_mode == 0 else "ADS"
	var pos_str: String = "Vector3(%.3f, %.3f, %.3f)" % [edit_position.x, edit_position.y, edit_position.z]
	var rot_str: String = "Vector3(%.1f, %.1f, %.1f)" % [edit_rotation.x, edit_rotation.y, edit_rotation.z]

	position_label.text = "%s MODE\n\nPosition:\n%s\n\nRotation:\n%s" % [mode_name, pos_str, rot_str]


func _on_weapon_selected(index: int) -> void:
	_load_weapon(index)


func _on_mode_toggle() -> void:
	preview_mode = 1 - preview_mode
	_reset_position()
	_update_mode_button()
	_update_camera_fov()


func _update_camera_fov() -> void:
	# FOV stays constant at 75 to match in-game
	if camera:
		camera.fov = 75.0


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
	print("[ViewmodelEditor] Copied to clipboard:\n%s" % text)

	# Show feedback
	copy_feedback_timer = 2.0
	if copy_feedback:
		copy_feedback.text = "COPIED!\n\n" + text
		copy_feedback.visible = true


func _update_copy_feedback(delta: float) -> void:
	if copy_feedback_timer > 0.0:
		copy_feedback_timer -= delta
		if copy_feedback_timer <= 0.0 and copy_feedback:
			copy_feedback.visible = false


func _get_instructions() -> String:
	return """VIEWMODEL EDITOR CONTROLS

POSITION:
  W/S - Forward/Back
  A/D - Left/Right
  Q/E - Down/Up

ROTATION:
  Arrow Keys - Pitch/Yaw
  PgUp/PgDn - Roll

OTHER:
  Space - Toggle Hip/ADS
  Shift - Fine adjustment
  R - Reset to saved
  C - Copy values
  F5 - Reload scene
  1-4 - Switch weapons

After editing a .tscn, save it
and restart this editor."""
