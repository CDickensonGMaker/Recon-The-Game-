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

var world: GameWorld
var director: MissionDirector
var sensors: Array = []
var exfil_zone: Node3D

var _map_texture: ImageTexture
var _rect: TextureRect
var _overlay: Control


func setup(game_world: GameWorld, mission_director: MissionDirector, sensor_list: Array, exfil: Node3D) -> void:
	world = game_world
	director = mission_director
	sensors = sensor_list
	exfil_zone = exfil
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


func _world_to_map(pos: Vector3) -> Vector2:
	var s: Vector2 = _rect.size
	return Vector2(pos.x / world.map_size * s.x, pos.z / world.map_size * s.y)


func _draw_overlay() -> void:
	if world == null or world.player == null:
		return
	# Objectives: red triangles (open) / dim (done).
	for sensor in sensors:
		if sensor is ObjectiveSensor and is_instance_valid(sensor):
			var s := sensor as ObjectiveSensor
			var p := _world_to_map(s.global_position)
			var col := Color(0.75, 0.2, 0.15) if not s.is_complete() else Color(0.4, 0.38, 0.3)
			_overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 5), p + Vector2(-6, 5)]), col)
	# Exfil: circled X.
	if exfil_zone != null and is_instance_valid(exfil_zone):
		var e := _world_to_map(exfil_zone.global_position)
		_overlay.draw_arc(e, 8.0, 0, TAU, 16, Color(0.2, 0.35, 0.6), 2.0)
		_overlay.draw_line(e + Vector2(-5, -5), e + Vector2(5, 5), Color(0.2, 0.35, 0.6), 2.0)
		_overlay.draw_line(e + Vector2(-5, 5), e + Vector2(5, -5), Color(0.2, 0.35, 0.6), 2.0)
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


func _process(_delta: float) -> void:
	if visible and _overlay:
		_overlay.queue_redraw()
