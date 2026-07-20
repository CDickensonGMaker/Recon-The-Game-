## test_world_minimap.gd - HUD minimap Control used by test_world_alive.
## Visual-test only; not part of the main game.
##
## A 220x220 top-right overlay that draws a top-down view of the AO with
## markers for the firebase, villages, camps, LZs, and the current drone
## position. Pulls live data from the test instance via two setters
## (set_plan, set_drone_state) so it can be re-aimed without coupling.
extends Control

var _plan: Dictionary = {}
var _drone_pos: Vector3 = Vector3.ZERO
var _drone_yaw: float = 0.0


func set_plan(plan: Dictionary) -> void:
	_plan = plan
	queue_redraw()


func set_drone_state(pos: Vector3, yaw: float) -> void:
	_drone_pos = pos
	_drone_yaw = yaw
	queue_redraw()


func _process(_delta: float) -> void:
	# No per-frame work — the test calls set_drone_state each tick which
	# already triggers a redraw. This is here so the node is in the tree
	# as a Control (not a "dead" overlay) and so future hooks land cleanly.
	pass


func _draw() -> void:
	var sz: Vector2 = size
	# Solid backing with a thin border so the HUD is readable on any AO.
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55), true)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.7, 0.8, 0.7, 0.8), false, 1.5)

	# World bounds come from TerrainManager. Fall back to 1.6km.
	var world_size: float = 1280.0
	var gw := get_tree().get_root().get_node_or_null("GameWorld")
	if gw != null and gw.has_node("TerrainManager"):
		var tm: Node = gw.get_node("TerrainManager")
		if "map_size" in tm:
			world_size = float(tm.map_size)
	var half: float = world_size * 0.5

	draw_string(ThemeDB.fallback_font, Vector2(6, 14),
			"AO MAP (%dm)" % int(world_size),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Grid: quarters, in 7 lines (-3..+3).
	for g in range(-3, 4):
		var gx: float = (float(g) / 3.0) * 0.5 + 0.5
		var gy: float = (float(g) / 3.0) * 0.5 + 0.5
		draw_line(Vector2(gx * sz.x, 0), Vector2(gx * sz.x, sz.y),
				Color(0.4, 0.45, 0.4, 0.4), 1.0)
		draw_line(Vector2(0, gy * sz.y), Vector2(sz.x, gy * sz.y),
				Color(0.4, 0.45, 0.4, 0.4), 1.0)

	if _plan.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(6, sz.y - 6),
				"no plan", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.GRAY)
		return

	# Centered crosshair so a marker at the AO origin is visible.
	var center: Vector2 = Vector2(sz.x * 0.5, sz.y * 0.5)
	draw_line(center + Vector2(-6, 0), center + Vector2(6, 0),
			Color(0.5, 0.55, 0.5, 0.6), 1.0)
	draw_line(center + Vector2(0, -6), center + Vector2(0, 6),
			Color(0.5, 0.55, 0.5, 0.6), 1.0)

	# World->map: +Z is "down" on the map (north-up).
	var world_to_map: Callable = func(w: Vector3) -> Vector2:
		var nx: float = (w.x + half) / world_size
		var nz: float = (w.z + half) / world_size
		return Vector2(nx * sz.x, nz * sz.y)

	# Labeled sites. Origin (0,0,0) is treated as "missing" so we don't
	# mark the AO center when a kind isn't on the plan. Villages and camps
	# come through the sites[] loop below.
	_draw_marker(_plan.get("fsb_center", Vector3.ZERO), world_to_map,
			Color(0.2, 0.6, 1.0), "FB", 7.0, true)
	_draw_marker(_plan.get("insertion_lz", Vector3.ZERO), world_to_map,
			Color(0.55, 0.9, 0.55), "LZ", 5.0, true)
	_draw_marker(_plan.get("exfil_lz", Vector3.ZERO), world_to_map,
			Color(0.55, 0.95, 0.85), "EX", 5.0, true)

	# Enemy groups (squads / camps / patrols). Always drawn (no origin guard)
	# since these are live spawns that may legitimately be at the origin.
	for g in _plan.get("enemy_groups", []):
		var gp: Vector3 = Vector3.ZERO
		if g is Dictionary:
			gp = g.get("position", g.get("center", Vector3.ZERO))
		elif g is Node3D and is_instance_valid(g):
			gp = (g as Node3D).global_position
		_draw_marker(gp, world_to_map, Color(0.9, 0.35, 0.3), "", 3.5, false)

	# Generic sites[] list (plan.sites: villages, paddies, firebase, camps, ...).
	for s in _plan.get("sites", []):
		if s is Dictionary:
			var kind: String = String(s.get("kind", ""))
			var c: Vector3 = s.get("center", Vector3.ZERO)
			var col: Color = Color.WHITE
			var radius: float = 4.0
			var label: String = ""
			match kind:
				"village": col = Color(0.95, 0.85, 0.3); radius = 6.0; label = "V"
				"firebase_main": col = Color(0.2, 0.6, 1.0); radius = 8.0; label = "FB"
				"vc_camp": col = Color(0.95, 0.3, 0.25); radius = 7.0; label = "C"
				"lz": col = Color(0.55, 0.9, 0.55)
				"paddy": col = Color(0.7, 0.55, 0.25); radius = 3.0
				"paddy_anchor": col = Color(0.95, 0.7, 0.2); radius = 5.0
			_draw_marker(c, world_to_map, col, label, radius, true)

	# Water bodies (rivers + lakes + ponds). Drawn last so the AO reads as
	# a terrain-with-water overview rather than a feature-light map.
	for wb in _plan.get("water_bodies", []):
		if wb is Resource and wb.has_method("get"):
			var ctr: Variant = wb.get("bounds")
			if ctr is Rect2:
				# Draw a small disc at the center of each water body's bounds.
				# Rect2.position/.size are Vector2; lift to Vector3 with y=0.
				var rect: Rect2 = ctr
				var center2: Vector2 = rect.position + rect.size * 0.5
				var center_v3: Vector3 = Vector3(center2.x, 0.0, center2.y)
				_draw_marker(center_v3, world_to_map, Color(0.3, 0.5, 0.85, 0.7), "", 3.5, false)

	# Drone marker — triangle pointing along the heading. White with a black
	# outline so it reads on any background.
	var me: Vector2 = world_to_map.call(_drone_pos)
	var hx: float = sin(_drone_yaw)
	var hz: float = cos(_drone_yaw)
	var tip: Vector2 = me + Vector2(hx, hz) * 8.0
	var left: Vector2 = me + Vector2(-hz, hx) * 4.0
	var right: Vector2 = me + Vector2(hz, -hx) * 4.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]),
			Color(0.95, 0.95, 0.95, 0.95))
	draw_polyline(PackedVector2Array([tip, left, right, tip]),
			Color(0, 0, 0, 0.8), 1.2)


func _draw_marker(world_pos: Vector3, world_to_map: Callable, color: Color,
		label: String, radius: float, origin_means_missing: bool) -> void:
	if origin_means_missing and world_pos == Vector3.ZERO:
		return
	var pt: Vector2 = world_to_map.call(world_pos)
	if pt.x < 0.0 or pt.x > size.x or pt.y < 0.0 or pt.y > size.y:
		return
	draw_circle(pt, radius, color)
	if not label.is_empty():
		draw_string(ThemeDB.fallback_font, pt + Vector2(radius + 2, -radius),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
