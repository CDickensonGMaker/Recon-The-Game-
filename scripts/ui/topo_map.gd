## topo_map.gd - 1960s military topographic map: contour bands rendered
## from the real heightmap, grid squares, water in blue, green player arrow,
## objective marks. Toggle with M. The map IS the AO.
class_name TopoMap
extends Control

const MAP_PIXELS: int = 512
const CONTOUR_INTERVAL: float = 12.0  ## meters per band

## 1960s paper palette
const PAPER := Color(0.87, 0.83, 0.70)
const PAPER_HIGH := Color(0.80, 0.74, 0.58)
const CONTOUR := Color(0.45, 0.36, 0.22)
const WATER := Color(0.55, 0.66, 0.72)
const GRID := Color(0.5, 0.42, 0.3, 0.35)
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

var world: GameWorld
var director: FieldDirector

var _map_texture: ImageTexture
var _rect: TextureRect
var _overlay: Control


func setup(game_world: GameWorld, mission_director: FieldDirector) -> void:
	world = game_world
	director = mission_director
	_render_base_map()
	_build_ui()
	visible = false


func _render_base_map() -> void:
	var img := Image.create(MAP_PIXELS, MAP_PIXELS, false, Image.FORMAT_RGB8)
	var map_size: float = world.map_size
	var heights := PackedFloat32Array()
	heights.resize(MAP_PIXELS * MAP_PIXELS)
	for py in range(MAP_PIXELS):
		for px in range(MAP_PIXELS):
			var wx: float = float(px) / float(MAP_PIXELS) * map_size
			var wz: float = float(py) / float(MAP_PIXELS) * map_size
			heights[py * MAP_PIXELS + px] = world.terrain_manager.get_height_at(Vector3(wx, 0, wz))
	var h_min: float = 99999.0
	var h_max: float = -99999.0
	for h in heights:
		h_min = minf(h_min, h)
		h_max = maxf(h_max, h)
	for py in range(MAP_PIXELS):
		for px in range(MAP_PIXELS):
			var h: float = heights[py * MAP_PIXELS + px]
			var wx: float = float(px) / float(MAP_PIXELS) * map_size
			var wz: float = float(py) / float(MAP_PIXELS) * map_size
			var color: Color
			if world.gameplay_grid != null and world.gameplay_grid.is_water(Vector3(wx, 0, wz)):
				color = WATER
			else:
				var band: int = int(h / CONTOUR_INTERVAL)
				# Contour line where the band changes vs right/down neighbor.
				var line := false
				if px + 1 < MAP_PIXELS and int(heights[py * MAP_PIXELS + px + 1] / CONTOUR_INTERVAL) != band:
					line = true
				elif py + 1 < MAP_PIXELS and int(heights[(py + 1) * MAP_PIXELS + px] / CONTOUR_INTERVAL) != band:
					line = true
				if line:
					color = CONTOUR
				else:
					var t: float = clampf((h - h_min) / maxf(1.0, h_max - h_min), 0.0, 1.0)
					color = PAPER.lerp(PAPER_HIGH, t)
			# Grid squares every 100m.
			var gx: float = fmod(wx, 100.0)
			var gz: float = fmod(wz, 100.0)
			if gx < map_size / float(MAP_PIXELS) or gz < map_size / float(MAP_PIXELS):
				color = color.lerp(GRID, GRID.a)
			img.set_pixel(px, py, color)
	_map_texture = ImageTexture.create_from_image(img)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := VBoxContainer.new()
	center.add_child(frame)
	frame.add_child(ReconUI.make_label("AO TACTICAL MAP - 1:25,000  //  GRID 100M  //  CONTOUR %dM" % int(CONTOUR_INTERVAL), 13, ReconUI.AMBER))
	_rect = TextureRect.new()
	_rect.texture = _map_texture
	_rect.custom_minimum_size = Vector2(560, 560)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.add_child(_rect)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_rect.add_child(_overlay)
	frame.add_child(ReconUI.make_label("[M] CLOSE", 12, ReconUI.DIM))


## The road network as printed linework. Drawn first so every mark - the CO's sweep
## circle, the player arrow - sits ON TOP of the paper rather than competing with it.
func _draw_roads() -> void:
	if world.road_network == null:
		return
	for seg in world.road_network.segments:
		if seg.size() < 2:
			continue
		var pts := PackedVector2Array()
		for p in seg:
			pts.append(_world_to_map(p))
		_overlay.draw_polyline(pts, ROAD, ROAD_WIDTH_PX, true)


func _world_to_map(pos: Vector3) -> Vector2:
	var s: Vector2 = _rect.size
	return Vector2(pos.x / world.map_size * s.x, pos.z / world.map_size * s.y)


func _draw_overlay() -> void:
	if world == null or world.player == null:
		return
	_draw_roads()
	# THE CO'S ORDER (ADR-029/ADR-022): a grease-pencil circle. An order on paper -
	# it never checks off, never updates; the next patrol's circle replaces it.
	if director != null and director.patrol_location != Vector3.ZERO:
		var gp := _world_to_map(director.patrol_location)
		var pencil := Color(0.62, 0.15, 0.12, 0.85)
		_overlay.draw_arc(gp, 13.0, 0.3, TAU + 0.1, 20, pencil, 2.5)
		_overlay.draw_arc(gp + Vector2(1.5, 1.0), 12.0, 2.1, TAU + 1.7, 18, pencil, 1.5)
		var f := ThemeDB.fallback_font
		_overlay.draw_string(f, gp + Vector2(16.0, 4.0), "SWEEP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, pencil)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		visible = not visible
		get_viewport().set_input_as_handled()
		# Opening the map re-asks the point man (ADR-029: the bark is repeatable).
		if visible and director != null:
			director.rebark_patrol()


func _process(_delta: float) -> void:
	if visible and _overlay:
		_overlay.queue_redraw()
