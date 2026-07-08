## test_sprite_actor.gd - anchoring, direction select, frame advance.
##
## The direction assertions are the important ones. Getting the row mirrored
## looks ALMOST right in game (enemies appear to walk backwards), so it must be
## pinned by a test that reasons from geometry rather than by eye.
##
## Run: godot --headless --path . res://tests/test_sprite_actor.tscn -- --test-save
extends Node3D

const FACTION := "US Army and Co"
const UNIT := "us_grunt"
const WEAPON := "m16a1"

const ROWS: Array[String] = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]

var _fail: int = 0
var _actor: SpriteActor = null


func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_fail += 1


func _ready() -> void:
	# Camera sits on +Z looking at the origin, exactly like a player standing south.
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 1.7, 10)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true

	_actor = SpriteActor.new()
	add_child(_actor)
	_actor.global_position = Vector3.ZERO
	_actor.setup(FACTION, UNIT, WEAPON)
	if not _actor.play("rifle_aiming_idle"):
		_bad("play(rifle_aiming_idle) returned false")
		_finish()
		return

	await get_tree().process_frame
	_test_anchor()
	await _test_directions()
	await _test_frame_advance()
	await _test_hold_last_frame()
	_test_muzzle_split()
	_finish()


# --------------------------------------------------------------- anchoring
func _test_anchor() -> void:
	var s := _actor.sprite
	var m := SpriteLibrary.manifest(FACTION, UNIT, WEAPON, "rifle_aiming_idle")
	if not is_equal_approx(s.pixel_size, m.m_per_px):
		_bad("pixel_size %.6f != m_per_px %.6f" % [s.pixel_size, m.m_per_px])
	if s.hframes != 8 or s.vframes != 8:
		_bad("hframes/vframes = %d/%d, expected 8/8" % [s.hframes, s.vframes])

	# Where does the ground row actually land in world space?
	var quad_centre_y: float = s.offset.y * s.pixel_size
	var half_cell_m: float = float(m.cell.y) * 0.5 * m.m_per_px
	var cell_bottom_y: float = quad_centre_y - half_cell_m
	var ground_from_bottom_m: float = (float(m.cell.y) - m.ground_row) * m.m_per_px
	var feet_y: float = cell_bottom_y + ground_from_bottom_m
	var head_y: float = quad_centre_y + half_cell_m

	print("  anchor: quad centre y=%.3f  feet y=%.4f  cell top y=%.3f  (char height %.3fm)" % [
		quad_centre_y, feet_y, head_y, m.character_height_m])
	if absf(feet_y) > 0.01:
		_bad("feet land at y=%.4f, must be 0 (anchor by ground_row, not centre)" % feet_y)
	if head_y < m.character_height_m:
		_bad("cell top y=%.3f is below character height %.3f" % [head_y, m.character_height_m])


# -------------------------------------------------------------- directions
func _expect_dir(facing: Vector3, want: int, why: String) -> void:
	_actor.set_facing(facing)
	await get_tree().process_frame
	var got: int = _actor.current_dir
	if got != want:
		_bad("facing %s -> row %d (%s), expected %d (%s) [%s]" % [
			facing, got, ROWS[got], want, ROWS[want], why])
	else:
		print("  facing %-14s -> row %d %-12s  %s" % [str(facing), got, ROWS[got], why])


func _test_directions() -> void:
	# Camera is at +Z. Rows must be read from the CHARACTER's own left/right.
	await _expect_dir(Vector3(0, 0, 1), 0, "faces the camera")
	await _expect_dir(Vector3(0, 0, -1), 4, "faces away")
	# cross(RIGHT, UP) = +Z, so a character facing +X has his right toward +Z.
	await _expect_dir(Vector3(1, 0, 0), 2, "faces +X, right side toward camera")
	await _expect_dir(Vector3(-1, 0, 0), 6, "faces -X, left side toward camera")
	await _expect_dir(Vector3(1, 0, 1).normalized(), 1, "faces +X+Z -> front_right")
	await _expect_dir(Vector3(-1, 0, 1).normalized(), 7, "faces -X+Z -> front_left")
	await _expect_dir(Vector3(1, 0, -1).normalized(), 3, "faces +X-Z -> back_right")
	await _expect_dir(Vector3(-1, 0, -1).normalized(), 5, "faces -X-Z -> back_left")

	# facing_dir, not the node basis: rotating the node must change nothing.
	_actor.set_facing(Vector3(0, 0, 1))
	_actor.rotation.y = PI
	await get_tree().process_frame
	if _actor.current_dir != 0:
		_bad("node rotation changed the direction row - actor must read facing_dir only")
	_actor.rotation.y = 0.0


# ----------------------------------------------------------- frame advance
func _test_frame_advance() -> void:
	_actor.set_facing(Vector3(0, 0, 1))
	_actor.play("run_forward", true)
	var m := SpriteLibrary.manifest(FACTION, UNIT, WEAPON, "run_forward")
	if _actor.current_col != 0:
		_bad("clip does not start on column 0")
	if _actor.sprite.frame != 0:
		_bad("dir 0 col 0 must be frame 0, got %d" % _actor.sprite.frame)

	# Drive _process directly - headless still ticks, but pin the delta.
	for i in range(30):
		_actor._process(1.0 / 60.0)
	var expect: int = int(0.5 * m.fps) % m.columns
	print("  run_forward after 0.5s @ %.3f fps: col=%d (expect %d), frame=%d" % [
		m.fps, _actor.current_col, expect, _actor.sprite.frame])
	if _actor.current_col != expect:
		_bad("frame advance wrong: col %d, expected %d" % [_actor.current_col, expect])
	if _actor.finished:
		_bad("a looping clip must never report finished")

	# Loop wraps rather than clamping.
	for i in range(300):
		_actor._process(1.0 / 60.0)
	if _actor.current_col >= m.columns:
		_bad("looping clip ran past its last column")
	await get_tree().process_frame


func _test_hold_last_frame() -> void:
	_actor.play("death_forward", true)
	var m := SpriteLibrary.manifest(FACTION, UNIT, WEAPON, "death_forward")
	# death_forward: fps 2.494, 8 cols -> 3.2s. Run 5s.
	for i in range(300):
		_actor._process(1.0 / 60.0)
	if not _actor.finished:
		_bad("death_forward should be finished after 5s")
	if _actor.current_col != m.columns - 1:
		_bad("hold_last_frame must clamp to col %d, got %d" % [m.columns - 1, _actor.current_col])
	print("  death_forward held on col %d after 5s (finished=%s)" % [_actor.current_col, _actor.finished])

	# A dead enemy has set_physics_process(false) -- frame advance must be in
	# _process, so it still ran. Prove _physics_process is not what drives it.
	if _actor.has_method("_physics_process"):
		_bad("SpriteActor must not define _physics_process (corpses would freeze)")
	await get_tree().process_frame


# ---------------------------------------------------------------- muzzle
func _test_muzzle_split() -> void:
	_actor.play("firing_rifle", true)
	_actor.set_facing(Vector3(0, 0, 1))
	_actor._process(0.0)

	var aim := Vector3(0, 0, 1)
	var ballistic_a: Vector3 = _actor.muzzle_ballistic(aim)
	var visual_a: Vector3 = _actor.muzzle_visual()

	# Move the camera. The BULLET origin must not move. The tracer origin may.
	var cam := SpriteActor.camera(get_tree())
	cam.global_position = Vector3(10, 1.7, 0)
	cam.look_at(Vector3(0, 1, 0))
	SpriteActor._cam_frame = -1  # force the per-frame cache to re-read
	_actor._process(0.0)

	var ballistic_b: Vector3 = _actor.muzzle_ballistic(aim)
	var visual_b: Vector3 = _actor.muzzle_visual()

	print("  ballistic origin: %s -> %s" % [ballistic_a, ballistic_b])
	print("  visual   origin: %s -> %s" % [visual_a, visual_b])
	if ballistic_a.distance_to(ballistic_b) > 0.001:
		_bad("ballistic muzzle moved %.3fm when the CAMERA moved - hitscan origin depends on where the player looks" % ballistic_a.distance_to(ballistic_b))
	if visual_a.distance_to(visual_b) < 0.001:
		_bad("visual muzzle did not follow the camera - it should, the quad is Y-billboarded")


func _finish() -> void:
	if _fail == 0:
		print("PASS: sprite actor")
		get_tree().quit(0)
	else:
		print("FAIL: %d sprite actor assertion(s)" % _fail)
		get_tree().quit(1)
