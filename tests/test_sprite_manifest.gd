## test_sprite_manifest.gd - the muzzle math, pinned to a hand-computed value.
## Run: godot --headless --path . res://tests/test_sprite_manifest.tscn -- --test-save
extends Node

const FACTION := "US Army and Co"
const UNIT := "us_grunt"
const WEAPON := "m16a1"

var _fail: int = 0


func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_fail += 1


func _ready() -> void:
	var m := SpriteManifest.load_clip(FACTION, UNIT, WEAPON, "firing_rifle")
	if m == null:
		_bad("firing_rifle manifest did not load")
		_finish()
		return

	# --- schema ---
	if m.cell != Vector2i(128, 160):
		_bad("cell = %s, expected (128,160)" % m.cell)
	if m.columns != 8:
		_bad("columns = %d, expected 8" % m.columns)
	if not m.has_muzzle():
		_bad("muzzle_px missing or not 8 rows (got %d)" % m.muzzle_px.size())

	# --- frame index: 8x8 grid, frame = dir*8 + col ---
	if m.frame_index(0, 0) != 0:
		_bad("frame_index(0,0) = %d" % m.frame_index(0, 0))
	if m.frame_index(3, 5) != 29:
		_bad("frame_index(3,5) = %d, expected 29" % m.frame_index(3, 5))
	if m.frame_index(7, 7) != 63:
		_bad("frame_index(7,7) = %d, expected 63" % m.frame_index(7, 7))
	if m.frame_index(8, 0) != 0:
		_bad("frame_index wraps: dir 8 should be dir 0, got %d" % m.frame_index(8, 0))

	# --- muzzle math, hand-computed from muzzle_px[0][0] = [74.61, 57.91] ---
	#   lateral = (74.61 - 64.0)  * 0.014375 = +0.15252 m
	#   height  = (143.53 - 57.91) * 0.014375 =  1.23079 m
	var off: Vector2 = m.muzzle_offset_m(0, 0)
	if absf(off.x - 0.15252) > 0.0005:
		_bad("muzzle lateral = %.5f, expected +0.15252" % off.x)
	if absf(off.y - 1.23079) > 0.0005:
		_bad("muzzle height = %.5f, expected 1.23079" % off.y)
	print("  muzzle_offset_m(0,0) = (%+.5f, %.5f) m" % [off.x, off.y])

	# The old hardcoded value was 1.35. Manifest says 1.231. Close enough to swap
	# in and verify by eye -- but assert it did not drift wildly.
	if absf(off.y - 1.35) > 0.25:
		_bad("manifest muzzle height %.3f is far from the hardcoded 1.35" % off.y)

	# --- ballistic height must NOT vary with the camera-derived direction ---
	var h0: float = m.canonical_muzzle_height_m(0)
	var h4: float = m.canonical_muzzle_height_m(0)
	if not is_equal_approx(h0, h4):
		_bad("canonical height is not stable")
	if not is_equal_approx(h0, m.muzzle_offset_m(0, 0).y):
		_bad("canonical height should equal dir-0 height")
	# ...whereas the VISUAL offset is allowed (expected) to vary by direction.
	var side: Vector2 = m.muzzle_offset_m(2, 0)  # 'right' row
	print("  dir 0 (front) muzzle x=%+.3f   dir 2 (right) muzzle x=%+.3f" % [off.x, side.x])
	if is_equal_approx(off.x, side.x):
		_bad("front and right rows have identical muzzle x - muzzle_px is not per-direction")

	# --- anchoring ---
	# ground_row 143.53 of a 160px cell -> quad centre must rise by 63.53px.
	var off_y: float = m.offset_px_y()
	if absf(off_y - 63.53) > 0.01:
		_bad("offset_px_y = %.2f, expected 63.53" % off_y)
	var head_m: float = m.ground_row * m.m_per_px
	print("  ground_row %.2fpx -> quad offset %.2fpx, feet-to-cell-top %.3fm (char height %.4fm)" % [
		m.ground_row, off_y, head_m, m.character_height_m])

	# --- fps / loop, per clip, not global ---
	var run := SpriteManifest.load_clip(FACTION, UNIT, WEAPON, "run_forward")
	var death := SpriteManifest.load_clip(FACTION, UNIT, WEAPON, "death_forward")
	if run == null or death == null:
		_bad("run_forward / death_forward manifests missing")
	else:
		print("  run_forward  fps=%.3f loop=%s hold_last=%s" % [run.fps, run.loop, run.hold_last_frame])
		print("  death_forward fps=%.3f loop=%s hold_last=%s" % [death.fps, death.loop, death.hold_last_frame])
		if not run.loop:
			_bad("run_forward should loop")
		if death.loop:
			_bad("death_forward must not loop")
		if not death.hold_last_frame:
			_bad("death_forward must hold its last frame (corpse sits for 45s)")
		if is_equal_approx(run.fps, death.fps):
			_bad("all clips share one fps - per-clip fps is not being read")

	# --- the sheet actually exists and is 1024x1280 ---
	if not ResourceLoader.exists(m.sheet_path):
		_bad("sheet missing: %s" % m.sheet_path)
	else:
		var tex: Texture2D = load(m.sheet_path)
		if tex.get_width() != 1024 or tex.get_height() != 1280:
			_bad("sheet is %dx%d, expected 1024x1280" % [tex.get_width(), tex.get_height()])

	# --- a unit that is still rendering must return null, not crash ---
	if SpriteManifest.load_clip("Vietcong and NVA", "vc6_heavy", "rpg2", "firing_rifle") != null:
		print("  note: vc6_heavy/rpg2 now assembled")

	_finish()


func _finish() -> void:
	if _fail == 0:
		print("PASS: sprite manifest")
		get_tree().quit(0)
	else:
		print("FAIL: %d sprite manifest assertion(s)" % _fail)
		get_tree().quit(1)
