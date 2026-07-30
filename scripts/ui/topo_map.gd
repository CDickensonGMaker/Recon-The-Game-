## topo_map.gd - 1960s military topographic map: contour bands rendered
## from the real heightmap, grid squares, water in blue, green player arrow,
## objective marks. Toggle with M. The map IS the AO.
class_name TopoMap
extends Control

## Roads are BASE SHEET, not intel. A 1968 survey map prints roads for the same reason
## it prints rivers and contours: they are surveyed cartography, permanent terrain, and
## this map already draws every river the player has never seen (see _render_base_map).
## So roads are printed from mission start, whole, and never decay - they are the paper,
## not a mark on it, and ADR-022's two-layer law governs MARKS.
##
## They are drawn in the contour ink at contour weight for exactly one reason: a road
## must read as furniture, never as a destination. Saturated colour is reserved for the
## player's grease pencil. Nothing is ever marked ON a road.
const ROAD := Color(0.38, 0.30, 0.18)
const ROAD_WIDTH_PX: float = 1.6
const FSB_MARK_PX: float = 9.0
const VILLAGE_BLOCKS: int = 5
## Metres of spoke, measured from the firebase gate, that read as improved road.
const IMPROVED_ROAD_M: float = 260.0
## Half the gap between the two lines of an improved road, in sheet pixels.
const ROAD_GAUGE_PX: float = 1.1
const SCALE_BAR_SEG_M: float = 100.0
const SCALE_BAR_SEGS: int = 5
const HELD_MARGIN_PX: float = 24.0

## Grease-pencil ink. Saturated on purpose: ADR-022 warns that if the player's layer is
## not instantly distinguishable from the printed sheet the whole two-layer law
## collapses into mush, so nothing printed is ever allowed this colour.
const PENCIL := Color(0.62, 0.15, 0.12, 0.9)
const ROUTE_INK := Color(0.20, 0.25, 0.55, 0.85)
## Third ink: someone else's claim. Distinct from both the printed sheet and the
## player's own pencil, or ADR-022's layer law collapses into mush.
const REPORTED_INK := Color(0.35, 0.28, 0.52, 0.85)

## ADR-022 §"Marker vocabulary will want to grow. It must stay small." Four words.
const PENCIL_KINDS: Array[String] = ["AMBUSH", "DANGER", "RALLY", "AVOID"]
const OBJECTIVE_HIT_PX: float = 16.0
const PENCIL_TEXT_MAX: int = 28

var world: GameWorld
var director: FieldDirector

var _map_texture: ImageTexture
var _contour_interval: float = 20.0
var _rect: TextureRect
var _overlay: Control
var _hint: Label
var _pencil_kind: int = 0
## Index into state.pencil_marks currently accepting typed text, or -1.
var _typing: int = -1
var _prior_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func setup(game_world: GameWorld, mission_director: FieldDirector) -> void:
	world = game_world
	director = mission_director
	_render_base_map()
	_build_ui()
	visible = false
	# DEFERRED, or the check races its own fix. _build_ui sets the size deferred (anchors would
	# otherwise overwrite a direct write), so reading `size` here reads the OLD zero rect and
	# cries wolf on a map that is fine. It fired three boots running for exactly that reason.
	call_deferred("_check_sheet_fits")


## The sheet is pinned to the BOTTOM-RIGHT of this control's rect, so a rect smaller than the
## sheet puts it off-screen while every other sign of health looks fine - texture rendered, key
## bound, node listening. That is the 2026-07-29 "M does nothing / it just centers my screen".
func _check_sheet_fits() -> void:
	if size.x >= TopoSheet.MAP_PIXELS and size.y >= TopoSheet.MAP_PIXELS:
		print("[TOPO] sheet fits: control %s, sheet %dpx" % [size, TopoSheet.MAP_PIXELS])
		return
	push_warning("[TOPO] map control is %s but the sheet needs %dpx - it will draw off-screen"
		% [size, TopoSheet.MAP_PIXELS])


func _render_base_map() -> void:
	var water := Callable()
	if world.gameplay_grid != null:
		water = Callable(world.gameplay_grid, "is_water")
	var seed_value: int = world.mission_seed
	var zone := func(h: float, wx: float, wz: float) -> int:
		return TerrainZoning.classify(h, wx, wz, seed_value)
	var sheet: Dictionary = TopoSheet.render(world.map_size,
		Callable(world.terrain_manager, "get_height_at"), water, zone)
	_contour_interval = float(sheet.get("interval", 20.0))
	_map_texture = ImageTexture.create_from_image(sheet.get("image") as Image)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# ...AND TAKE THE SIZE NOW. Anchors alone only resolve on a layout pass, and this control
	# is built hidden under a CanvasLayer, so it never got one: its rect stayed 0x0. The sheet
	# below is pinned to the BOTTOM-RIGHT of that rect, so every offset went negative and the
	# map drew off the top-left corner of the screen. Pressing M released the mouse and opened
	# nothing visible - "it just centers my screen", 2026-07-29.
	# set_deferred, not a direct assign: with opposite anchors set, Godot recomputes size after
	# _ready() and warns that a direct write will be overridden. Deferring lands it after that
	# pass instead of fighting it.
	set_deferred("size", get_viewport_rect().size)
	get_viewport().size_changed.connect(func() -> void:
		set_deferred("size", get_viewport_rect().size))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NO full-screen dim. The world does not pause while the sheet is up (Summoner,
	# 2026-07-28), so blanking the screen would stand the player blind in the jungle
	# with his squad moving and hunters converging. A man reading a map still sees the
	# treeline over the top of it - the sheet is a HELD OBJECT, not a screen.
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var frame := VBoxContainer.new()
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -(TopoSheet.MAP_PIXELS + HELD_MARGIN_PX)
	frame.offset_top = -(TopoSheet.MAP_PIXELS + HELD_MARGIN_PX + 34)
	frame.offset_right = -HELD_MARGIN_PX
	frame.offset_bottom = -HELD_MARGIN_PX
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	# No printed ratio. A scale RATIO is a statement about paper, and this sheet has no
	# paper - the old "1:25,000" was fiction, and it claimed a 1000m grid it did not
	# draw. A drawn bar is true at any window size. The 100m grid stays: that is the
	# precision of the six-figure grid reference an RTO actually called.
	frame.add_child(ReconUI.make_label("AO TACTICAL MAP  //  GRID 100M  //  CONTOUR INTERVAL %dM"
		% int(_contour_interval), 13, ReconUI.AMBER))
	_rect = TextureRect.new()
	_rect.texture = _map_texture
	# Displayed 1:1 with TopoSheet.MAP_PIXELS. Stretching 512 into 560 is a 1.09x
	# resample that lands 1-pixel contour lines unevenly - some doubled, some filtered
	# away - and contour weight is the whole legibility of the sheet.
	_rect.custom_minimum_size = Vector2(TopoSheet.MAP_PIXELS, TopoSheet.MAP_PIXELS)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_rect)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.gui_input.connect(_on_sheet_input)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_rect.add_child(_overlay)
	_hint = ReconUI.make_label("", 12, ReconUI.DIM)
	frame.add_child(_hint)
	_refresh_hint()


## The road network as printed linework. Drawn first so every mark - the CO's sweep
## circle, the player arrow - sits ON TOP of the paper rather than competing with it.
func _draw_roads() -> void:
	if world.road_network == null:
		return
	# Every segment radiates from the firebase gate, so the stretch nearest the hub is
	# the one every vehicle actually uses: that is the improved provincial road, drawn
	# double. Past IMPROVED_ROAD_M the spoke is a cart track to one hamlet, drawn as a
	# dashed trail. The hierarchy is derived from the network's real shape, not from a
	# tier field invented for the map.
	for seg in world.road_network.segments:
		if seg.size() < 2:
			continue
		var travelled: float = 0.0
		for i in range(seg.size() - 1):
			var a3: Vector3 = seg[i]
			var b3: Vector3 = seg[i + 1]
			var a := _world_to_map(a3)
			var b := _world_to_map(b3)
			travelled += Vector2(b3.x - a3.x, b3.z - a3.z).length()
			if travelled < IMPROVED_ROAD_M:
				var n := (b - a).normalized().orthogonal() * ROAD_GAUGE_PX
				_overlay.draw_line(a + n, b + n, ROAD, ROAD_WIDTH_PX, true)
				_overlay.draw_line(a - n, b - n, ROAD, ROAD_WIDTH_PX, true)
			elif i % 2 == 0:
				_overlay.draw_line(a, b, ROAD, ROAD_WIDTH_PX * 0.8, true)


## Surveyed cartography, printed with the roads: the firebase you live in and the
## villages a 1968 sheet would carry. Contour ink at contour weight - saturated colour
## stays reserved for the grease pencil, and nothing here is a destination.
func _draw_surveyed_sites() -> void:
	if director == null:
		return
	var f := ThemeDB.fallback_font
	for s in director.surveyed_sites:
		var sd: Dictionary = s
		var p := _world_to_map(sd.get("pos", Vector3.ZERO) as Vector3)
		if str(sd.get("kind", "")) == "firebase_main":
			var h: float = FSB_MARK_PX * 0.5
			_overlay.draw_rect(Rect2(p - Vector2(h, h), Vector2(h * 2.0, h * 2.0)),
				ROAD, false, ROAD_WIDTH_PX)
			_overlay.draw_string(f, p + Vector2(h + 3.0, 4.0), "FSB",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, ROAD)
		else:
			# Period convention: a settlement is a cluster of small solid building blocks.
			var r: float = maxf(2.0, float(sd.get("radius", 30.0)) / world.map_size * _rect.size.x)
			for i in range(VILLAGE_BLOCKS):
				var a: float = TAU * float(i) / float(VILLAGE_BLOCKS)
				var bp := p + Vector2(cos(a), sin(a)) * r * 0.55
				_overlay.draw_rect(Rect2(bp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), ROAD, true)
			var label: String = str(sd.get("name", ""))
			if not label.is_empty():
				_overlay.draw_string(f, p + Vector2(r * 0.6 + 3.0, 3.0), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, ROAD)


## Alternating black/white bar in the bottom margin, plus a north arrow. True at any
## window size, which a printed ratio is not.
func _draw_scale_bar() -> void:
	var f := ThemeDB.fallback_font
	var px_per_m: float = _rect.size.x / world.map_size
	var seg_px: float = SCALE_BAR_SEG_M * px_per_m
	var origin := Vector2(12.0, _rect.size.y - 16.0)
	for i in range(SCALE_BAR_SEGS):
		var r := Rect2(origin + Vector2(seg_px * float(i), 0.0), Vector2(seg_px, 4.0))
		_overlay.draw_rect(r, ROAD, i % 2 == 0)
		if i % 2 == 0:
			_overlay.draw_rect(r, ROAD, false, 1.0)
	_overlay.draw_string(f, origin + Vector2(0.0, -3.0), "0",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ROAD)
	_overlay.draw_string(f, origin + Vector2(seg_px * float(SCALE_BAR_SEGS) - 8.0, -3.0),
		"%dM" % int(SCALE_BAR_SEG_M * SCALE_BAR_SEGS), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ROAD)
	# North arrow. Grid north and true north are the same here - there is no projection
	# to declinate against, so drawing a declination diagram would be decoration.
	var n := Vector2(_rect.size.x - 20.0, _rect.size.y - 30.0)
	_overlay.draw_line(n, n + Vector2(0.0, 18.0), ROAD, 1.4)
	_overlay.draw_colored_polygon(PackedVector2Array([
		n + Vector2(0.0, -4.0), n + Vector2(-3.5, 4.0), n + Vector2(3.5, 4.0)]), ROAD)
	_overlay.draw_string(f, n + Vector2(-3.0, -6.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, ROAD)


## The circles the world offers, and the order the player put them in. An unordered
## circle is a bare ring; an ordered one carries its number and joins the pencil line.
## The line closes at the firebase because the patrol has to come home.
func _draw_route() -> void:
	if director == null:
		return
	var f := ThemeDB.fallback_font
	var order: Array = director.state.route_order
	for i in range(director.patrol_objectives.size()):
		var p := _world_to_map(director.patrol_objectives[i].pos as Vector3)
		var seq: int = order.find(i)
		_overlay.draw_arc(p, 11.0, 0.25, TAU + 0.1, 22, ROUTE_INK, 2.0)
		if seq >= 0:
			_overlay.draw_arc(p + Vector2(1.2, 0.8), 13.0, 1.9, TAU + 1.5, 20,
				ROUTE_INK * Color(1, 1, 1, 0.55), 1.4)
			_overlay.draw_string(f, p + Vector2(-3.0, 4.0), str(seq + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, ROUTE_INK)
	if order.is_empty():
		return
	var home := _world_to_map(director.fsb_center)
	var path := PackedVector2Array([home])
	for idx in order:
		var oi: int = int(idx)
		if oi >= 0 and oi < director.patrol_objectives.size():
			path.append(_world_to_map(director.patrol_objectives[oi].pos as Vector3))
	path.append(home)
	if path.size() >= 2:
		_overlay.draw_polyline(path, ROUTE_INK * Color(1, 1, 1, 0.7), 1.8, true)


## THE THIRD INK - REPORTED. Not the printed sheet (that is surveyed fact) and not the
## player's pencil (that is his own belief): this is somebody ELSE'S claim, off a
## captured document. It is drawn dashed and DATED, because a document is accurate as of
## when it was written and the camp may have moved since. The game never reconciles it -
## walk there, find nothing, and the mark stays until the player rubs it out.
func _draw_reported_marks() -> void:
	var f := ThemeDB.fallback_font
	var now_patrol: int = CampaignState.missions_played
	for m in CampaignState.reported_marks:
		var md: Dictionary = m
		var p := _world_to_map(Vector3(float(md.get("x", 0.0)), 0.0, float(md.get("z", 0.0))))
		# Dashed ring: eight strokes, so it never reads as the pencil's solid circle.
		for i in range(8):
			var a0: float = TAU * float(i) / 8.0
			_overlay.draw_arc(p, 9.0, a0, a0 + 0.28, 4, REPORTED_INK, 1.8)
		var age: int = now_patrol - int(md.get("patrol_no", 0))
		var label: String = str(md.get("kind", "CAMP"))
		if age > 0:
			label += " (%d PATROLS OLD)" % age
		_overlay.draw_string(f, p + Vector2(11.0, 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, REPORTED_INK)


## The ANNOTATED layer. What the player THINKS, placed from the sheet with no line of
## sight required - he may mark ground he has never walked, and he may be wrong.
## Nothing in this function checks anything against the world. That is the law.
func _draw_pencil_marks() -> void:
	if director == null:
		return
	var f := ThemeDB.fallback_font
	for i in range(director.state.pencil_marks.size()):
		var m: Dictionary = director.state.pencil_marks[i]
		var p := _world_to_map(Vector3(float(m.get("x", 0.0)), 0.0, float(m.get("z", 0.0))))
		_overlay.draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), PENCIL, 2.0)
		_overlay.draw_line(p + Vector2(5, -5), p + Vector2(-5, 5), PENCIL, 2.0)
		var label: String = str(m.get("kind", ""))
		var note: String = str(m.get("text", ""))
		if not note.is_empty():
			label += " " + note
		if i == _typing:
			label += "_"
		_overlay.draw_string(f, p + Vector2(7.0, 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, PENCIL)


func _world_to_map(pos: Vector3) -> Vector2:
	var s: Vector2 = _rect.size
	return Vector2(pos.x / world.map_size * s.x, pos.z / world.map_size * s.y)


func _draw_overlay() -> void:
	if world == null or world.player == null:
		return
	_draw_roads()
	_draw_surveyed_sites()
	_draw_scale_bar()
	_draw_route()
	_draw_reported_marks()
	_draw_pencil_marks()
	# THE CO'S ORDER (ADR-029/ADR-022): a grease-pencil circle. An order on paper -
	# it never checks off, never updates; the next patrol's circle replaces it.
	if director != null and director.patrol_location != Vector3.ZERO:
		var gp := _world_to_map(director.patrol_location)
		var pencil := Color(0.62, 0.15, 0.12, 0.85)
		_overlay.draw_arc(gp, 13.0, 0.3, TAU + 0.1, 20, pencil, 2.5)
		_overlay.draw_arc(gp + Vector2(1.5, 1.0), 12.0, 2.1, TAU + 1.7, 18, pencil, 1.5)
		var f := ThemeDB.fallback_font
		_overlay.draw_string(f, gp + Vector2(16.0, 4.0), "SWEEP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, pencil)
	# THE INTEL LAYER (ADR-022 Amendment A): the player's field marks. Each is a
	# LARGE general-area circle - the circle IS the uncertainty - and it never
	# updates once drawn (stale = intended fog). No counter, no tally by kind (§4).
	# Placeholder chrome: the period pixel glyphs ride with ADR-030 to final polish.
	if director != null:
		var ink := Color(0.16, 0.22, 0.50, 0.8)
		var mf := ThemeDB.fallback_font
		for m in director.state.field_marks:
			var md: Dictionary = m
			var area: Dictionary = md.get("area", {})
			var mp := _world_to_map(Vector3(float(area.get("x", 0.0)), 0.0, float(area.get("z", 0.0))))
			var pr: float = float(area.get("r", 60.0)) / world.map_size * _rect.size.x
			_overlay.draw_arc(mp, pr, 0.6, TAU + 0.4, 26, ink, 2.0)
			_overlay.draw_arc(mp + Vector2(1.0, 1.5), pr - 1.5, 1.8, TAU + 1.3, 22, ink * Color(1, 1, 1, 0.6), 1.2)
			_overlay.draw_string(mf, mp + Vector2(4.0, 4.0), str(md.get("kind", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, ink)
	# Player: green arrow with heading.
	var pp := _world_to_map(world.player.global_position)
	var cam := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	var heading: float = 0.0
	if cam:
		var fwd := -cam.global_transform.basis.z
		heading = atan2(fwd.x, fwd.z)
	var dir := Vector2(sin(heading), cos(heading))
	var right := Vector2(dir.y, -dir.x)
	_overlay.draw_colored_polygon(PackedVector2Array([
		pp + dir * 10.0, pp - dir * 5.0 + right * 6.0, pp - dir * 5.0 - right * 6.0]),
		Color(0.2, 0.8, 0.25))


func _map_to_world(p: Vector2) -> Vector3:
	var s: Vector2 = _rect.size
	return Vector3(p.x / s.x * world.map_size, 0.0, p.y / s.y * world.map_size)


## LEFT IS THE PENCIL. His report was that only right-click placed a mark, and the reason
## the two verbs felt tangled is that LEFT did nothing at all unless it landed on an
## objective circle - the map's main verb was on the button nobody reaches for first.
##
## Left on a circle still sequences the route: a circle is a small hotspot and the pencil
## is everywhere else, so they cannot compete for the same pixel. Right is now the ERASER,
## which the sheet has never had - marks went on and stayed forever.
## Nothing here validates anything - the grease-pencil law forbids it.
const ERASE_RADIUS_M: float = 45.0


func _on_sheet_input(event: InputEvent) -> void:
	if director == null:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var hit: int = _objective_at(mb.position)
		if hit >= 0:
			_toggle_route(hit)
		else:
			var w: Vector3 = _map_to_world(mb.position)
			_typing = director.state.add_pencil_mark(PENCIL_KINDS[_pencil_kind], w.x, w.z,
				CampaignState.missions_played)
		_refresh_hint()
		_rect.accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		var w: Vector3 = _map_to_world(mb.position)
		if director.state.erase_pencil_mark_near(w.x, w.z, ERASE_RADIUS_M) >= 0:
			_typing = -1
		_refresh_hint()
		_rect.accept_event()


func _objective_at(p: Vector2) -> int:
	for i in range(director.patrol_objectives.size()):
		var sp := _world_to_map(director.patrol_objectives[i].pos as Vector3)
		if sp.distance_to(p) <= OBJECTIVE_HIT_PX:
			return i
	return -1


## Already in the route -> remove it and everything after keeps its relative order.
## Not in it -> append. A circle is OFFERED, so un-picking must be as easy as picking.
func _toggle_route(idx: int) -> void:
	var order: Array = director.state.route_order
	var at: int = order.find(idx)
	if at >= 0:
		order.remove_at(at)
	else:
		order.append(idx)


func _refresh_hint() -> void:
	if _hint == null:
		return
	if _typing >= 0:
		_hint.text = "TYPING - [ENTER] DONE   //   %s" % PENCIL_KINDS[_pencil_kind]
	else:
		_hint.text = "[M] STOW   //   [LMB] ORDER A CIRCLE   //   [RMB] MARK: %s   //   [TAB] INK" \
			% PENCIL_KINDS[_pencil_kind]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	# Free text on the mark just placed (ADR-022: "a note, free text"). The game never
	# reads this string back for anything - it is the player talking to himself.
	if _typing >= 0:
		var marks: Array = director.state.pencil_marks
		if _typing < marks.size():
			var m: Dictionary = marks[_typing]
			if key.keycode == KEY_ENTER or key.keycode == KEY_ESCAPE:
				_typing = -1
			elif key.keycode == KEY_BACKSPACE:
				m["text"] = str(m.get("text", "")).left(-1)
			elif key.unicode >= 32 and str(m.get("text", "")).length() < PENCIL_TEXT_MAX:
				m["text"] = str(m.get("text", "")) + char(key.unicode).to_upper()
		else:
			_typing = -1
		_refresh_hint()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		_pencil_kind = (_pencil_kind + 1) % PENCIL_KINDS.size()
		_refresh_hint()
		get_viewport().set_input_as_handled()


## The sheet needs a cursor, but the world is LIVE behind it - so the mouse mode is
## restored to whatever it was, never assumed to be CAPTURED.
func _set_open(open: bool) -> void:
	visible = open
	if open:
		_prior_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Opening the map re-asks the point man (ADR-029: the bark is repeatable).
		if director != null:
			director.rebark_patrol()
	else:
		_typing = -1
		Input.mouse_mode = _prior_mouse_mode
	_refresh_hint()


func _process(_delta: float) -> void:
	if visible and _overlay:
		_overlay.queue_redraw()
