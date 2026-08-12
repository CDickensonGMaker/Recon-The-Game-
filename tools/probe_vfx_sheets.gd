## probe_vfx_sheets.gd - A FLIPBOOK SHEET THAT LOADS IS NOT A SHEET THAT WORKS.
##
## Loads every fire-pack sheet through the SAME res:// path GunFX uses and checks
## the three things that silently ruin a flipbook in-engine:
##
##   1. LOADS       - a missing/renamed sheet returns null and the effect renders
##                    as an untextured quad, which reads as a flat coloured block.
##   2. GRID FITS   - width must divide by particles_anim_h_frames and height by
##                    v_frames, or every cell samples across two frames and the
##                    animation smears.
##   3. BORDER CLEAR- opaque pixels on a tile edge render as an effect with its
##                    top sliced flat. No engine setting can undo it; the pixels
##                    are cut in the texture.
##
## Check 3 doubles as a STALE-IMPORT detector: the shipped sheets were re-rendered
## with headroom, so if this reports border contact the .ctex in .godot/imported
## is the old clipped art and the editor has not reimported.
##
##   godot --headless --path . res://tools/probe_vfx_sheets.tscn
extends Node

const SHEET_DIR: String = "res://assets/textures/fx/sheets/%s.png"
const PART_DIR: String = "res://assets/textures/fx/particles/%s.png"

## name -> [h_frames, v_frames]. These MUST match the _sheet_mat() calls in
## gun_fx.gd and fire_hazard.gd; a mismatch there is invisible until it animates.
const SHEETS: Dictionary = {
	"napalm_explosion_sheet": [6, 6],
	"fire_loop_sheet": [4, 4],
	"fire_core_sheet": [4, 4],
	"smoke_loop_sheet": [4, 4],
	"mortar_burst_sheet": [4, 4],
	"muzzle_flash_sheet": [8, 1],
}
const STATICS: Array[String] = ["fire_glow", "ember", "haze_noise"]
const ALPHA_EPS: float = 0.03
## Sub-sampling stride along each edge. 1 = every pixel.
const STRIDE: int = 2

var _fails: int = 0


func _ready() -> void:
	print("[VFX SHEETS] probing %d sheets + %d statics" % [SHEETS.size(), STATICS.size()])
	for name: String in SHEETS:
		var grid: Array = SHEETS[name]
		_check_sheet(name, int(grid[0]), int(grid[1]))
	for name in STATICS:
		_check_static(name)
	if _fails == 0:
		print("[VFX SHEETS] PASS - every sheet loads, fits its grid, and clears its borders")
	else:
		printerr("[VFX SHEETS] FAIL - %d problem(s). If borders are hit, the editor has "
			% _fails + "not reimported the re-rendered PNGs.")
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	printerr("  FAIL %s" % msg)


func _load_image(path: String) -> Image:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		_fail("%s did not load" % path)
		return null
	var img: Image = tex.get_image()
	if img == null:
		_fail("%s loaded but has no image data" % path)
		return null
	if img.is_compressed():
		img.decompress()
	return img


func _check_sheet(name: String, h: int, v: int) -> void:
	var path: String = SHEET_DIR % name
	var img: Image = _load_image(path)
	if img == null:
		return
	var w: int = img.get_width()
	var ht: int = img.get_height()
	if w % h != 0 or ht % v != 0:
		_fail("%s is %dx%d, which does not divide into a %dx%d grid" % [name, w, ht, h, v])
		return
	var cw: int = w / h
	var ch: int = ht / v
	var clipped: int = 0
	var worst: int = 0
	for row in v:
		for col in h:
			var ox: int = col * cw
			var oy: int = row * ch
			var hits: int = 0
			for x in range(0, cw, STRIDE):
				if img.get_pixel(ox + x, oy).a > ALPHA_EPS:
					hits += 1
				if img.get_pixel(ox + x, oy + ch - 1).a > ALPHA_EPS:
					hits += 1
			for y in range(0, ch, STRIDE):
				if img.get_pixel(ox, oy + y).a > ALPHA_EPS:
					hits += 1
				if img.get_pixel(ox + cw - 1, oy + y).a > ALPHA_EPS:
					hits += 1
			if hits > 0:
				clipped += 1
				worst = maxi(worst, hits)
	if clipped > 0:
		_fail("%s: %d/%d frames touch the tile border (worst %d px) - tops will read cut off"
			% [name, clipped, h * v, worst])
	else:
		print("  ok   %-26s %dx%d  %dx%d grid  cell %dx%d  borders clear"
			% [name, w, ht, h, v, cw, ch])


func _check_static(name: String) -> void:
	var path: String = PART_DIR % name
	var img: Image = _load_image(path)
	if img == null:
		return
	print("  ok   %-26s %dx%d" % [name, img.get_width(), img.get_height()])
