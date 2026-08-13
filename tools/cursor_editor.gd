## cursor_editor.gd - place each cursor's CLICK POINT by eye, and prove it.
##
## A hotspot is the one pixel the OS reports when you click. Get it wrong and the art
## points at one thing while the game receives another - and that is invisible in a static
## preview, which is why this tool applies the LIVE cursor and gives you something to hit.
##
##   godot --path . res://tools/cursor_editor.tscn
##
## Click the zoomed art to place the point. Arrows nudge by one source pixel, shift-arrows
## by five. SAVE writes assets/ui/cursors/cursors.json, which CursorSet reads.
extends Control

const DIR: String = "res://assets/ui/cursors/"
const JSON_PATH: String = DIR + "cursors.json"
const SRC: int = 64          ## the rung we author against; 32 is a downsample of it
const ZOOM: int = 8
const NAMES: Array[String] = [
	"bullet", "crossed", "knife", "bayonet",
	"grenade", "dogtags", "belt", "huey",
	"compass", "casing", "chevron", "kbar",
]

var _meta: Dictionary = {}
var _name: String = "bullet"
var _canvas: Control = null
var _readout: Label = null
var _status: Label = null
var _target: Control = null
var _hits: int = 0
var _err_sum: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_meta()

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	root.add_child(_build_picker())
	root.add_child(_build_canvas())
	root.add_child(_build_side())

	_select(_name)


## ---------- the list ----------
func _build_picker() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(150, 0)
	var t := Label.new()
	t.text = "CURSORS"
	col.add_child(t)
	for n in NAMES:
		var b := Button.new()
		b.text = n
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select.bind(n))
		col.add_child(b)
	var hint := Label.new()
	hint.text = "\nclick art = place\narrows = nudge 1px\nshift = 5px\nC = centre\nT = auto tip"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(hint)
	return col


## ---------- the zoomed art ----------
func _build_canvas() -> Control:
	var box := VBoxContainer.new()
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(SRC * ZOOM, SRC * ZOOM)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	box.add_child(_canvas)
	_readout = Label.new()
	_readout.text = "-"
	box.add_child(_readout)
	return box


func _draw_canvas() -> void:
	var tex: Texture2D = _tex(_name)
	if tex == null:
		return
	var r := Rect2(Vector2.ZERO, Vector2(SRC * ZOOM, SRC * ZOOM))
	# A checker under the art, or a dark blade on a dark panel is invisible.
	for y in range(0, SRC * ZOOM, 32):
		for x in range(0, SRC * ZOOM, 32):
			var odd: bool = ((x / 32) + (y / 32)) % 2 == 1
			_canvas.draw_rect(Rect2(x, y, 32, 32),
				Color(0.20, 0.20, 0.20) if odd else Color(0.26, 0.26, 0.26))
	_canvas.draw_texture_rect(tex, r, false)
	_canvas.draw_rect(r, Color(0.4, 0.4, 0.4), false, 1.0)

	var h: Vector2 = _hot_px() * float(ZOOM)
	# Crosshair to the edges, so the point can be lined up against the art's own features.
	_canvas.draw_line(Vector2(h.x, 0), Vector2(h.x, SRC * ZOOM), Color(1, 0.25, 0.2, 0.55), 1.0)
	_canvas.draw_line(Vector2(0, h.y), Vector2(SRC * ZOOM, h.y), Color(1, 0.25, 0.2, 0.55), 1.0)
	_canvas.draw_circle(h, 9.0, Color(0, 0, 0, 0.55))
	_canvas.draw_circle(h, 5.0, Color(1.0, 0.30, 0.22))
	_canvas.draw_circle(h, 2.0, Color(1, 1, 1))


func _canvas_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	var p: Vector2 = (event as InputEventMouseButton).position / float(ZOOM)
	_set_hot(Vector2(floorf(p.x), floorf(p.y)))


## ---------- live proof ----------
func _build_side() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	var t := Label.new()
	t.text = "PROVE IT"
	col.add_child(t)
	var note := Label.new()
	note.text = "The live cursor is applied. Click the dot - the error is measured from where the OS says you clicked."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(note)

	_target = Control.new()
	_target.custom_minimum_size = Vector2(300, 300)
	_target.mouse_filter = Control.MOUSE_FILTER_STOP
	_target.draw.connect(_draw_target)
	_target.gui_input.connect(_target_input)
	col.add_child(_target)

	_status = Label.new()
	_status.text = "no clicks yet"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_status)

	var save := Button.new()
	save.text = "SAVE cursors.json"
	save.pressed.connect(_save)
	col.add_child(save)
	return col


func _draw_target() -> void:
	var c := _target.size * 0.5
	_target.draw_rect(Rect2(Vector2.ZERO, _target.size), Color(0.14, 0.15, 0.14))
	for r in [90.0, 60.0, 30.0]:
		_target.draw_arc(c, r, 0.0, TAU, 48, Color(0.35, 0.38, 0.32), 1.0)
	_target.draw_line(Vector2(c.x, c.y - 100), Vector2(c.x, c.y + 100), Color(0.35, 0.38, 0.32))
	_target.draw_line(Vector2(c.x - 100, c.y), Vector2(c.x + 100, c.y), Color(0.35, 0.38, 0.32))
	_target.draw_circle(c, 5.0, Color(0.95, 0.35, 0.25))


func _target_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	var d: float = ((event as InputEventMouseButton).position - _target.size * 0.5).length()
	_hits += 1
	_err_sum += d
	_status.text = "%s: last %.0f px off centre, mean %.1f over %d click(s).\nUnder ~4 px is a hotspot that lands where the art points." % [
		_name, d, _err_sum / float(_hits), _hits]


## ---------- state ----------
func _select(n: String) -> void:
	_name = n
	_hits = 0
	_err_sum = 0.0
	if _status != null:
		_status.text = "no clicks yet"
	_apply_live()
	_refresh()


func _hot_px() -> Vector2:
	var e: Dictionary = _meta.get(_name, {}) as Dictionary
	var h: Array = e.get("hotspot", [0.5, 0.5]) as Array
	return Vector2(float(h[0]) * SRC, float(h[1]) * SRC)


func _set_hot(px: Vector2) -> void:
	px = px.clamp(Vector2.ZERO, Vector2(SRC - 1, SRC - 1))
	var e: Dictionary = _meta.get(_name, {}) as Dictionary
	e["hotspot"] = [px.x / float(SRC), px.y / float(SRC)]
	_meta[_name] = e
	_hits = 0
	_err_sum = 0.0
	_apply_live()
	_refresh()


func _refresh() -> void:
	var px: Vector2 = _hot_px()
	_readout.text = "%s   hotspot %d,%d px of %d   (%.3f, %.3f)" % [
		_name, int(px.x), int(px.y), SRC, px.x / SRC, px.y / SRC]
	_canvas.queue_redraw()


## THE POINT OF THE TOOL. A hotspot is only real once the OS is using it.
func _apply_live() -> void:
	var tex: Texture2D = _tex(_name)
	if tex == null:
		return
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, _hot_px())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var k := event as InputEventKey
	var step: float = 5.0 if k.shift_pressed else 1.0
	var px: Vector2 = _hot_px()
	match k.physical_keycode:
		KEY_LEFT: _set_hot(px + Vector2(-step, 0))
		KEY_RIGHT: _set_hot(px + Vector2(step, 0))
		KEY_UP: _set_hot(px + Vector2(0, -step))
		KEY_DOWN: _set_hot(px + Vector2(0, step))
		KEY_C: _set_hot(Vector2(SRC, SRC) * 0.5)
		KEY_T: _set_hot(_auto_tip())
		KEY_S: _save()
		_: return
	get_viewport().set_input_as_handled()


## The slicer's own rule, re-run on demand: the tip is the topmost opaque pixel.
func _auto_tip() -> Vector2:
	var tex: Texture2D = _tex(_name)
	if tex == null:
		return Vector2(SRC, SRC) * 0.5
	var img: Image = tex.get_image()
	for y in range(img.get_height()):
		var run: Array[int] = []
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.03:
				run.append(x)
		if not run.is_empty():
			var mid: int = run[run.size() / 2]
			return Vector2(float(mid), float(y))
	return Vector2(SRC, SRC) * 0.5


func _tex(n: String) -> Texture2D:
	var p: String = "%s%s_%d.png" % [DIR, n, SRC]
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _load_meta() -> void:
	var f: FileAccess = FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_meta = parsed


func _save() -> void:
	var f: FileAccess = FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if f == null:
		_status.text = "COULD NOT WRITE %s" % JSON_PATH
		return
	f.store_string(JSON.stringify(_meta, " ", true))
	f.close()
	_status.text = "saved %s (%d cursors)" % [JSON_PATH, _meta.size()]
	print("[CURSOR-EDITOR] saved ", JSON_PATH)
