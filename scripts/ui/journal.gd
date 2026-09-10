## journal.gd - The grunt's notebook. Opens upper-left on [J] with five index tabs down
## the right edge: GEAR, ORDERS, MISSION, LOG, MAP.
##
## IT DOES NOT PAUSE. Same law as the topo sheet (topo_map.gd:106-109, Summoner
## 2026-07-28): this is a HELD OBJECT, not a screen. The world runs, the squad moves and
## the hunters converge while the player reads it. The mouse is freed so the tabs can be
## thumbed, which is exactly the cost - a man reading his notebook is not aiming a rifle.
##
## Every page is drawn ON the ruled lines of Caleb's sheet. The art is the whole look:
## no icons, no glow, no modern type (period HUD decree). Slices are cut from
## assets/ui/journal/source_art/journal_sheet_caleb.png by tools/gen_journal_slices.py -
## regenerate from the sheet, never hand-edit the PNGs.
class_name Journal
extends CanvasLayer

## Above the HUD roots (0) and the suppression vignette (5), below the pause menu (90).
const LAYER: int = 40

const ART := "res://assets/ui/journal/"

## Measured off assets/ui/journal/spread.png (572x440) by tools/gen_journal_slices.py.
const SPREAD_PX := Vector2(572.0, 440.0)
const PAGE_L := Rect2(26.0, 40.0, 238.0, 356.0)
const PAGE_R := Rect2(300.0, 40.0, 246.0, 356.0)
const RULE_FIRST: float = 59.0
const RULE_PITCH: float = 23.0
const RULE_COUNT: int = 15
const MARGIN_PX := Vector2(28.0, 28.0)

## Fountain-pen blue-black, graphite, and the same saturated grease pencil the topo sheet
## reserves for the player's own layer (topo_map.gd:31) - so a note reads as HIS on both.
const INK := Color(0.17, 0.19, 0.30)
const GRAPHITE := Color(0.26, 0.24, 0.21)
const FADED := Color(0.40, 0.37, 0.33)
const PENCIL := Color(0.55, 0.16, 0.13)

enum Tab { GEAR, ORDERS, MISSION, LOG, MAP }

const TAB_NAMES: Array[String] = ["GEAR", "ORDERS", "MISSION", "LOG", "MAP"]

var world: GameWorld
var director: FieldDirector
var hud: MissionHUD

var _tab: int = Tab.GEAR
var _log_scroll: int = 0
var _scale: float = 1.0
var _font: SystemFont
var _page: Control
var _tab_buttons: Array[TextureButton] = []
var _art: Dictionary = {}
var _prior_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func setup(game_world: GameWorld, mission_director: FieldDirector, mission_hud: MissionHUD) -> void:
	world = game_world
	director = mission_director
	hud = mission_hud
	layer = LAYER
	_font = SystemFont.new()
	# Courier first: a DA Form 20 and a company journal were typed, not set.
	_font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])
	for n: String in ["spread", "tab_1", "tab_2", "tab_3", "tab_4", "tab_5", "pencil",
			"paperclip", "rubber_band", "da_form_20", "k_ration", "letter", "map_topo"]:
		var t: Texture2D = load(ART + n + ".png") as Texture2D
		if t != null:
			_art[n] = t
	_build()
	visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_rescale()
	_page = Control.new()
	_page.position = MARGIN_PX
	_page.size = SPREAD_PX * _scale
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.draw.connect(_draw_page)
	_page.gui_input.connect(_on_page_input)
	root.add_child(_page)
	for i: int in TAB_NAMES.size():
		var b := TextureButton.new()
		b.texture_normal = _art.get("tab_%d" % (i + 1)) as Texture2D
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.pressed.connect(_on_tab_pressed.bind(i))
		var l := Label.new()
		l.text = TAB_NAMES[i]
		l.add_theme_font_override("font", _font)
		l.add_theme_color_override("font_color", Color(0.20, 0.18, 0.15))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		root.add_child(b)
		_tab_buttons.append(b)
	_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_rescale()
	_layout()


func _rescale() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_scale = clampf(vp.x * 0.38 / SPREAD_PX.x, 0.85, 1.60)


## Tabs stack down the right edge, each half-tucked behind the page so only the raised
## half of Caleb's index tab reads. His tab art is drawn tucked-half-right, so the slicer
## mirrors it; the raised half is the right half of the flipped texture.
func _layout() -> void:
	if _page == null:
		return
	_page.position = MARGIN_PX
	_page.size = SPREAD_PX * _scale
	# The tucked half starts at the OUTER EDGE of the right page's text column, never
	# inside it: a tab lying across the writing is the one way this reads as a widget
	# instead of a notebook.
	var tw: float = _page.size.x * 0.31
	var th: float = tw * 88.0 / 280.0
	var pitch: float = _page.size.y * 0.82 / 5.0
	var top: float = _page.position.y + _page.size.y * 0.09
	var tuck: float = (SPREAD_PX.x - PAGE_R.end.x) * _scale
	for i: int in _tab_buttons.size():
		var b: TextureButton = _tab_buttons[i]
		b.size = Vector2(tw, th)
		b.position = Vector2(_page.position.x + PAGE_R.end.x * _scale, top + pitch * float(i))
		var l: Label = b.get_child(0) as Label
		l.add_theme_font_size_override("font_size", maxi(9, int(th * 0.30)))
		l.position = Vector2(tuck + th * 0.12, 0.0)
		l.size = Vector2(tw - tuck - th * 0.24, th * 0.80)
		l.modulate.a = 1.0 if i == _tab else 0.58


func _on_tab_pressed(idx: int) -> void:
	_tab = idx
	_log_scroll = 0
	_layout()
	_page.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		_set_open(not visible)
		return
	# The sheet and the notebook are two hands. Opening one puts the other away.
	if visible and event.is_action_pressed("map"):
		_set_open(false)


## The notebook needs a cursor, but the world is LIVE behind it - so the mouse mode is
## restored to whatever it was, never assumed to be CAPTURED (topo_map.gd:463).
func _set_open(open: bool) -> void:
	if open and hud != null and hud.topo_map != null:
		hud.topo_map.close()
	visible = open
	GameManager.is_in_menu = open
	if open:
		_prior_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_log_scroll = 0
		if _tab == Tab.LOG:
			_log_scroll = 0
		_page.queue_redraw()
	else:
		Input.mouse_mode = _prior_mouse_mode


## Never strand the menu flag if the notebook is torn down while open.
func _exit_tree() -> void:
	if visible:
		GameManager.is_in_menu = false


func _on_page_input(event: InputEvent) -> void:
	if _tab != Tab.LOG or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_log_scroll = mini(_log_scroll + 3, maxi(0, FieldLog.size() - RULE_COUNT))
		_page.queue_redraw()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_log_scroll = maxi(0, _log_scroll - 3)
		_page.queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		_page.queue_redraw()


# --- drawing ------------------------------------------------------------------------

func _fs() -> int:
	return maxi(9, int(RULE_PITCH * _scale * 0.48))


func _cols(page: Rect2) -> int:
	var w: float = _font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs()).x
	return maxi(8, int(page.size.x * _scale / maxf(1.0, w)))


func _rule_y(i: int) -> float:
	return (RULE_FIRST + RULE_PITCH * float(i)) * _scale


func _draw_page() -> void:
	var sheet: Texture2D = _art.get("spread") as Texture2D
	if sheet != null:
		_page.draw_texture_rect(sheet, Rect2(Vector2.ZERO, _page.size), false)
	match _tab:
		Tab.GEAR:
			_draw_text_page(PAGE_L, _gear_left())
			_draw_text_page(PAGE_R, _gear_right())
			_draw_tucked("k_ration", Vector2(0.575, 0.545), 0.215, 0.05)
			_draw_tucked("letter", Vector2(0.620, 0.720), 0.200, -0.04)
		Tab.ORDERS:
			_draw_text_page(PAGE_L, _orders_left())
			_draw_text_page(PAGE_R, _orders_right())
		Tab.MISSION:
			_draw_form_20()
			_draw_text_page(PAGE_R, _mission_right())
		Tab.LOG:
			var lines: Array[Dictionary] = _log_lines()
			_draw_text_page(PAGE_L, lines.slice(0, RULE_COUNT))
			_draw_text_page(PAGE_R, lines.slice(RULE_COUNT, RULE_COUNT * 2))
		Tab.MAP:
			_draw_map()
	# Loose kit, drawn last so it lies on top of the page like it does on the desk.
	_draw_tucked("pencil", Vector2(0.464, 0.060), 0.066, 0.0)
	# Only on GEAR: it is the one page whose bottom-left is reliably blank, and a rubber
	# band lying across a log entry hides the line the player opened the book to read.
	if _tab == Tab.GEAR:
		_draw_tucked("rubber_band", Vector2(0.055, 0.795), 0.200, 0.0)


## Draws one column of lines with every baseline sitting ON a printed rule.
func _draw_text_page(page: Rect2, lines: Array[Dictionary]) -> void:
	var x0: float = page.position.x * _scale
	var fs: int = _fs()
	for i: int in mini(lines.size(), RULE_COUNT):
		var d: Dictionary = lines[i]
		var t: String = String(d.get("t", ""))
		if t.is_empty():
			continue
		var col: Color = d.get("c", INK)
		var indent: float = float(d.get("x", 0.0)) * _scale
		_page.draw_string(_font, Vector2(x0 + indent, _rule_y(i) - 3.0 * _scale), t,
			HORIZONTAL_ALIGNMENT_LEFT, page.size.x * _scale - indent, fs, col)


## Loose kit lying on the page. Position and WIDTH are fractions of the spread; the height
## comes off the texture, so a re-slice can never squash the pencil or the rubber band.
func _draw_tucked(art_name: String, at: Vector2, w_frac: float, rot: float) -> void:
	var t: Texture2D = _art.get(art_name) as Texture2D
	if t == null:
		return
	var w: float = w_frac * _page.size.x
	var r := Rect2(at * _page.size, Vector2(w, w * float(t.get_height()) / float(t.get_width())))
	if is_zero_approx(rot):
		_page.draw_texture_rect(t, r, false, Color(1, 1, 1, 0.96))
		return
	_page.draw_set_transform(r.position + r.size * 0.5, rot, Vector2.ONE)
	_page.draw_texture_rect(t, Rect2(-r.size * 0.5, r.size), false, Color(1, 1, 1, 0.96))
	_page.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- tab content --------------------------------------------------------------------

func _row(label: String, value: String, col: Color = INK, indent: float = 0.0) -> Dictionary:
	var pad: int = maxi(1, 13 - label.length())
	return {"t": label + " ".repeat(pad) + value, "c": col, "x": indent}


func _head(text: String) -> Dictionary:
	return {"t": text, "c": GRAPHITE, "x": 0.0}


func _player() -> Node:
	return world.player if world != null else null


func _gear_left() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_head("WEAPONS")]
	var p: Node = _player()
	if p == null:
		out.append({"t": "(no man in the field)", "c": FADED, "x": 0.0})
		return out
	var wh: Node = p.get_node_or_null("Head/Camera3D/WeaponHolder")
	if wh == null:
		return out
	var prim: WeaponData = wh.get("primary_weapon") as WeaponData
	var sec: WeaponData = wh.get("secondary_weapon") as WeaponData
	if prim != null:
		out.append(_row("RIFLE", prim.display_name.to_upper()))
		out.append(_row("  IN MAG", "%d" % int(wh.call("current_rounds")), GRAPHITE, 8.0))
		out.append(_row("  SPARE", "%d MAG" % int(wh.call("spare_mag_count")), GRAPHITE, 8.0))
	var cond: float = float(wh.get("weapon_condition"))
	var cond_word: String = "SERVICEABLE"
	if bool(wh.get("is_jammed")):
		cond_word = "JAMMED"
	elif cond < 0.5:
		cond_word = "FOULED - CLEAN IT"
	elif cond < 0.8:
		cond_word = "DIRTY"
	out.append(_row("  CONDITION", cond_word,
		PENCIL if cond_word != "SERVICEABLE" else GRAPHITE, 8.0))
	out.append({"t": "", "c": INK, "x": 0.0})
	if sec != null:
		out.append(_row("SIDEARM", sec.display_name.to_upper()))
	else:
		out.append(_row("SIDEARM", "NONE", FADED))
	return out


func _gear_right() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_head("ON MY PERSON")]
	var p: Node = _player()
	if p == null:
		return out
	var hs: Node = p.get_node_or_null("HealthSystem")
	var eq: Node = p.get_node_or_null("EquipmentManager")
	out.append(_row("FRAG", "%d" % (int(eq.get("grenade_count")) if eq != null else 0)))
	out.append(_row("SMOKE", "%d" % int(p.get("smoke_count"))))
	out.append(_row("CLAYMORE", "%d" % int(p.get("claymore_count"))))
	out.append(_row("SATCHEL", "%d" % int(p.get("satchel_count"))))
	out.append(_row("FLARE", "%d" % int(p.get("flare_count"))))
	out.append({"t": "", "c": INK, "x": 0.0})
	out.append(_row("BANDAGE", "%d" % (int(hs.get("health_packs")) if hs != null else 0)))
	out.append(_row("RATION", "%d" % int(p.get("ration_count"))))
	out.append(_row("REPAIR KIT", "%d" % int(p.get("repair_kit_count"))))
	return out


func _orders_left() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_head("WHAT THEY TOLD ME")]
	if director == null:
		return out
	var kind: String = String(director.get("patrol_location_kind"))
	var pos: Vector3 = director.get("patrol_location") as Vector3
	if kind.is_empty():
		out.append({"t": "NOTHING STANDING.", "c": FADED, "x": 0.0})
	else:
		out.append(_row("SWEEP", kind.to_upper().replace("_", " ")))
		out.append(_row("GRID", _grid(pos), GRAPHITE))
		out.append({"t": "", "c": INK, "x": 0.0})
		out.append({"t": "THE CO WANTS EYES ON IT.", "c": GRAPHITE, "x": 0.0})
		out.append({"t": "HE DID NOT SAY HOW.", "c": GRAPHITE, "x": 0.0})
	out.append({"t": "", "c": INK, "x": 0.0})
	out.append(_head("PLACES ON THE SHEET"))
	var sites: Array = director.get("surveyed_sites") as Array
	for s: Dictionary in sites:
		if out.size() >= RULE_COUNT:
			break
		out.append(_row("  " + String(s.get("name", "?")).to_upper(),
			_grid(s.get("pos", Vector3.ZERO) as Vector3), GRAPHITE, 8.0))
	return out


func _orders_right() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_head("WHAT I WROTE DOWN")]
	if director == null or director.state == null:
		return out
	var marks: Array = director.state.pencil_marks
	if marks.is_empty():
		out.append({"t": "NOTHING YET. RIGHT-CLICK", "c": FADED, "x": 0.0})
		out.append({"t": "THE MAP TO MARK IT.", "c": FADED, "x": 0.0})
		return out
	for i: int in range(marks.size() - 1, -1, -1):
		if out.size() >= RULE_COUNT - 1:
			break
		var m: Dictionary = marks[i]
		var here := Vector3(float(m.get("x", 0.0)), 0.0, float(m.get("z", 0.0)))
		out.append(_row(String(m.get("kind", "?")), _grid(here), PENCIL))
		var note: String = String(m.get("text", "")).strip_edges()
		if not note.is_empty():
			out.append({"t": "  \"" + note + "\"", "c": PENCIL, "x": 10.0})
	return out


func _mission_right() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hour: float = SimClock.sim_hour
	out.append(_head(String(SaveManager.hub_snapshot.get("operation_name", "THE FIREBASE"))))
	out.append(_row("DAY", "%d" % SimClock.sim_day, GRAPHITE))
	out.append(_row("TIME", "%02d%02d" % [int(hour), int((hour - floorf(hour)) * 60.0)],
		GRAPHITE))
	out.append(_row("THREAT", CampaignState.threat_label(), GRAPHITE))
	if director != null:
		out.append(_row("PATROLS", "%d" % int(director.get("patrol_count")), GRAPHITE))
	out.append({"t": "", "c": INK, "x": 0.0})
	out.append(_head("THE SQUAD"))
	if director == null or director.squad_system == null:
		return out
	for a: AllyBase in director.squad_system.members:
		if out.size() >= RULE_COUNT:
			break
		var m: Dictionary = a.member
		var state: String = "KIA"
		var col: Color = FADED
		if not a.is_dead():
			var frac: float = float(a.current_hp) / maxf(1.0, float(a.max_hp))
			state = "OK" if frac > 0.66 else ("HIT" if frac > 0.33 else "CRIT")
			col = GRAPHITE if state == "OK" else PENCIL
		out.append({"t": "%-4s %-10s %s" % [SquadRoster.rank_for(m),
			SquadRoster.last_name(m), state], "c": col, "x": 6.0})
	return out


func _log_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src: Array[Dictionary] = FieldLog.entries()
	if src.is_empty():
		return [_head("NOTHING WRITTEN YET.")]
	var span: int = RULE_COUNT * 2
	var last: int = maxi(0, src.size() - _log_scroll)
	var first: int = maxi(0, last - span)
	var cols: int = _cols(PAGE_L) - 9
	for i: int in range(first, last):
		var e: Dictionary = src[i]
		var body: String = String(e.get("text", ""))
		var n: int = int(e.get("count", 1))
		if n > 1:
			body += " x%d" % n
		var wrapped: PackedStringArray = _wrap(body, cols)
		for w: int in wrapped.size():
			if out.size() >= span:
				break
			if w == 0:
				out.append({"t": "%s  %s" % [e.get("stamp", "----"), wrapped[0]],
					"c": INK, "x": 0.0})
			else:
				out.append({"t": wrapped[w], "c": INK, "x": 44.0})
	return out


func _wrap(text: String, cols: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word: String in text.split(" ", false):
		if line.is_empty():
			line = word
		elif line.length() + 1 + word.length() <= cols:
			line += " " + word
		else:
			out.append(line)
			line = word
	if not line.is_empty():
		out.append(line)
	return out


## Six-figure grid off the AO corner - the only coordinate a 1968 rifleman speaks.
func _grid(pos: Vector3) -> String:
	if world == null or world.map_size <= 0.0:
		return "------"
	var e: float = clampf(pos.x / world.map_size, 0.0, 0.999) * 1000.0
	var n: float = clampf(1.0 - pos.z / world.map_size, 0.0, 0.999) * 1000.0
	return "%03d %03d" % [int(e), int(n)]


# --- the DA Form 20 and the map -----------------------------------------------------

## The personnel qualification record, paperclipped into the notebook. What it can state
## is exactly what CampaignState holds (ADR-018 killed player stats, ADR-032 forbids
## showing reputation as a number) - so the form carries rank, MOS, tours and awards, and
## the identity blocks stay blank because the game has never had a player name.
func _draw_form_20() -> void:
	var form: Texture2D = _art.get("da_form_20") as Texture2D
	if form == null:
		return
	var r := Rect2(Vector2(14.0, 24.0) * _scale, Vector2(258.0, 392.0) * _scale)
	_page.draw_texture_rect(form, r, false)
	_draw_tucked("paperclip", Vector2(0.055, 0.028), 0.046, 0.0)
	var fs: int = maxi(8, int(_fs() * 0.86))
	var pitch: float = r.size.y * 0.052
	var y: float = r.position.y + r.size.y * 0.30
	var x: float = r.position.x + r.size.x * 0.09
	# A wash of the form's own paper under the typed block. Without it the entries land on
	# top of the form's printed micro-text and neither is readable.
	_page.draw_rect(Rect2(Vector2(x - float(fs) * 0.5, y - float(fs) * 1.4),
		Vector2(r.size.x * 0.82, pitch * 7.0 + float(fs) * 0.8)),
		Color(0.86, 0.83, 0.74, 0.80))
	var kills: int = 0
	for m: Dictionary in CampaignState.mission_log:
		kills += int(m.get("kills", 0))
	var rows: Array = [
		["NAME", "________________"],
		["GRADE", CampaignState.title()],
		["MOS", String(CampaignState.player_data.get("mos", "RIFLEMAN"))],
		["ORGANIZATION", "CO B 2D BN 42D INF"],
		["TOURS", "%d" % CampaignState.missions_played],
		["CONFIRMED", "%d" % kills],
		["SQUAD KIA", "%d" % CampaignState.kia_total],
	]
	for i: int in rows.size():
		var row: Array = rows[i]
		_page.draw_string(_font, Vector2(x, y + pitch * float(i)),
			"%-13s %s" % [row[0], row[1]], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.86,
			fs, INK)


## The AO sheet across both pages. This draws the SAME raster TopoMap prints
## (TopoSheet.render, topo_sheet.gd:76) - there is one map in this game, not two. The
## journal page is READ ONLY: the grease pencil lives on the sheet under [M], because
## ADR-037 makes marking the map's verb and a second marking surface would fork it.
func _draw_map() -> void:
	var paper: Texture2D = _art.get("map_topo") as Texture2D
	var span: float = (PAGE_R.end.x - PAGE_L.position.x) * _scale
	var avail: float = PAGE_L.size.y * _scale
	var org := Vector2(PAGE_L.position.x * _scale, PAGE_L.position.y * _scale)
	var sheet := Rect2(org, Vector2(span, avail))
	if paper != null:
		var pw: float = span
		var ph: float = pw * float(paper.get_height()) / float(paper.get_width())
		if ph > avail:
			ph = avail
			pw = ph * float(paper.get_width()) / float(paper.get_height())
		sheet = Rect2(org + Vector2((span - pw) * 0.5, 0.0), Vector2(pw, ph))
		_page.draw_texture_rect(paper, sheet, false)
	var side: float = sheet.size.y * 0.84
	var r := Rect2(sheet.position + (sheet.size - Vector2(side, side)) * 0.5,
		Vector2(side, side))
	var tex: Texture2D = null
	if hud != null and hud.topo_map != null:
		tex = hud.topo_map.sheet_texture()
	if tex != null:
		# 0.93, not 1.0: his fold creases and the paper read through the printed AO, so
		# the square is a survey printed ON this map instead of a panel stuck over it.
		_page.draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.93))
	_page.draw_rect(r, Color(0.32, 0.26, 0.18, 0.75), false, 1.5 * _scale)
	var p: Node3D = _player() as Node3D
	if p != null and world != null and world.map_size > 0.0:
		var f := Vector2(p.global_position.x, p.global_position.z) / world.map_size
		var at: Vector2 = r.position + f * side
		var head: float = -p.global_rotation.y
		_page.draw_line(at, at + Vector2(sin(head), -cos(head)) * 9.0 * _scale,
			Color(0.16, 0.36, 0.16), 2.0 * _scale)
		_page.draw_circle(at, 3.0 * _scale, Color(0.16, 0.36, 0.16))
	_page.draw_string(_font, Vector2(sheet.position.x, sheet.end.y + 15.0 * _scale),
		"AO - GRID %s   MARK IT ON THE SHEET [M]" % _grid(
			p.global_position if p != null else Vector3.ZERO),
		HORIZONTAL_ALIGNMENT_LEFT, sheet.size.x, maxi(8, int(_fs() * 0.86)), GRAPHITE)
