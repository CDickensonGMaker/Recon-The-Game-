## sprite_actor.gd - the only thing in the project that touches Sprite3D.
##
## Owns one Sprite3D, picks the direction row from the camera, advances the
## column from the manifest's fps, and reports the barrel tip.
##
## Three constraints drove the design, all verified in the codebase:
##
## 1. The camera is first-person perspective with free-look and +/-89 deg pitch,
##    so the direction row must be recomputed per enemy per frame and the quad
##    must be BILLBOARD_FIXED_Y. Full billboard makes sprites lean when you look
##    up.
## 2. facing_dir (enemy_base.gd:76) is the source of truth. _move_toward() sets
##    it at :1033 but never rotates the node, so reading global_transform.basis.z
##    renders a patrolling enemy facing the wrong way. look_at() only runs while
##    aiming (:815).
## 3. _die() and try_surrender() both call set_physics_process(false)
##    (enemy_base.gd:1334, :1361). Frame advance therefore lives in _process, or
##    corpses freeze on frame 0 and the death clip never plays.
class_name SpriteActor
extends Node3D

## Set true if a strafe-circle test shows the sprite rotating the wrong way.
## Getting this mirrored looks ALMOST right - enemies appear to walk backwards.
@export var mirror_directions: bool = false
@export var unshaded: bool = true

var faction: String = ""
var unit: String = ""
var weapon: String = ""

var sprite: Sprite3D = null
var current_action: String = ""
var current_dir: int = 0
var current_col: int = 0
var finished: bool = false      ## true once a non-looping clip has held its last frame

var _m: SpriteManifest = null
var _clip_time: float = 0.0
var _facing: Vector3 = Vector3.FORWARD
var _flash_until: float = 0.0
var _base_modulate: Color = Color.WHITE

## Cached per frame at the tree level - 30 enemies must not each call
## get_viewport().get_camera_3d().
static var _cam: Camera3D = null
static var _cam_frame: int = -1


static func camera(tree: SceneTree) -> Camera3D:
	var f := Engine.get_process_frames()
	if _cam_frame != f or _cam == null or not is_instance_valid(_cam):
		_cam = tree.root.get_viewport().get_camera_3d()
		_cam_frame = f
	return _cam


func setup(faction_: String, unit_: String, weapon_: String) -> void:
	faction = faction_
	unit = unit_
	weapon = weapon_
	if sprite == null:
		sprite = Sprite3D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = not unshaded
	sprite.double_sided = true
	sprite.hframes = 8
	sprite.vframes = 8
	sprite.centered = true


func has_visual() -> bool:
	return _m != null and sprite != null and sprite.texture != null


## Switch clips. Silently no-ops if the clip is already playing (so you can call
## it every frame from a state map).
func play(action: String, restart: bool = false) -> bool:
	if action == current_action and not restart:
		return true
	var m := SpriteLibrary.manifest(faction, unit, weapon, action)
	if m == null:
		return false
	var tex := SpriteLibrary.texture(m)
	if tex == null:
		return false

	_m = m
	current_action = action
	_clip_time = 0.0
	current_col = 0
	finished = false

	sprite.texture = tex
	sprite.hframes = m.columns
	sprite.vframes = SpriteManifest.DIR_COUNT
	sprite.pixel_size = m.m_per_px
	# Push the quad up so ground_row lands on this node's origin (the feet).
	# Sprite3D.offset is in texture pixels, applied before pixel_size.
	sprite.offset = Vector2(0.0, m.offset_px_y())
	_apply_frame()
	return true


## World-space forward vector. Pass enemy.facing_dir, never basis.z.
func set_facing(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		_facing = flat.normalized()


func _dir_index() -> int:
	var cam := SpriteActor.camera(get_tree())
	if cam == null:
		return 0
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return 0
	# Derivation (checked by hand, then asserted in test_sprite_actor):
	#   a character facing +X has his right hand toward +Z, since
	#   cross(RIGHT, UP) = cross((1,0,0),(0,1,0)) = (0,0,1).
	#   So a camera sitting at +Z must select row 2, "right".
	#   atan2(facing) - atan2(to_cam) gives +PI/2 -> idx 2.  Correct.
	#   The other order gives -PI/2 -> idx 6, "left" -- mirrored, and it looks
	#   almost right: enemies appear to walk backwards.
	var angle: float = atan2(_facing.x, _facing.z) - atan2(to_cam.x, to_cam.z)
	if mirror_directions:
		angle = -angle
	var idx: int = roundi(angle / (TAU / float(SpriteManifest.DIR_COUNT)))
	return wrapi(idx, 0, SpriteManifest.DIR_COUNT)


func _apply_frame() -> void:
	if _m == null or sprite == null:
		return
	sprite.frame = _m.frame_index(current_dir, current_col)


func _process(delta: float) -> void:
	if _m == null or sprite == null:
		return

	var d := _dir_index()
	if d != current_dir:
		current_dir = d

	if not finished:
		_clip_time += delta
		var col: int = int(_clip_time * _m.fps)
		if col >= _m.columns:
			if _m.loop:
				col = col % _m.columns
				_clip_time = fmod(_clip_time, _m.duration_s())
			elif _m.hold_last_frame:
				col = _m.columns - 1
				finished = true
			else:
				col = _m.columns - 1
				finished = true
		current_col = col

	_apply_frame()

	if _flash_until > 0.0:
		_flash_until -= delta
		if _flash_until <= 0.0:
			sprite.modulate = _base_modulate


## Replaces the old mesh.material_override.albedo_color = RED hit flash.
func flash(color: Color, seconds: float = 0.1) -> void:
	if sprite == null:
		return
	sprite.modulate = color
	_flash_until = seconds


func set_base_modulate(c: Color) -> void:
	_base_modulate = c
	if sprite != null and _flash_until <= 0.0:
		sprite.modulate = c


# ---------------------------------------------------------------- muzzle
## Where the muzzle flash and tracer should APPEAR. Camera-relative, because the
## quad is Y-billboarded toward the camera and muzzle_px is measured in that
## plane.
func muzzle_visual() -> Vector3:
	if _m == null or not _m.has_muzzle():
		return global_position + Vector3.UP * 1.35
	var off := _m.muzzle_offset_m(current_dir, current_col)
	var cam := SpriteActor.camera(get_tree())
	var right := Vector3.RIGHT
	if cam != null:
		right = cam.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() > 0.0001:
			right = right.normalized()
	return global_position + Vector3.UP * off.y + right * off.x


## Where the BULLET starts. Deliberately camera-independent.
##
## enemy_base.gd:1152 feeds this same value into intersect_ray() as the ray
## origin, not just to the tracer. A camera-relative origin would mean the
## player's look direction decides whether an enemy's bullet clears a rock.
## So: manifest height (row 0), enemy-local forward bias, no lateral term.
func muzzle_ballistic(flat_aim: Vector3, forward_bias: float = 0.55) -> Vector3:
	var height: float = 1.35
	if _m != null:
		height = _m.canonical_muzzle_height_m(current_col)
	return global_position + Vector3.UP * height + flat_aim * forward_bias
