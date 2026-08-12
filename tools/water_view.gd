extends Node3D

## Seeded water viewer. Generates a real AO, parks a free-fly camera on the
## biggest creek in it and lets you look. Run WINDOWED - headless renders nothing.
##   godot --path . tools/water_view.tscn -- --seed=47225
##
## WASD/QE fly · mouse look · Shift boost · 1-4 time of day · N next creek
## F freeze/unfreeze water flow · ESC release mouse, again to quit

const MOVE_SPEED: float = 8.0
const BOOST_MULT: float = 5.0
const LOOK_SENS: float = 0.0025
const EYE_H: float = 1.7

## label, sun pitch, sun energy
const LIGHTING := [
	["DAY", -50.0, 1.0],
	["DAWN", -10.0, 0.65],
	["DUSK", -8.0, 0.55],
	["NIGHT", -35.0, 0.08],
]

var _world: GameWorld
var _cam: Camera3D
var _sun: DirectionalLight3D
var _label: Label
var _spots: Array[Dictionary] = []
var _spot_idx: int = 0
var _seed: int = 47225
var _lit: int = 0
var _placed: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _captured: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			_seed = int(a.substr(7))

	_world = load("res://scripts/levels/game_world.gd").new() as GameWorld
	_world.mission_seed = _seed
	_world.spawn_player_on_ready = false
	add_child(_world)

	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.current = true
	_cam.far = 600.0
	add_child(_cam)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)

	_capture(true)


func _capture(on: bool) -> void:
	_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _captured:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * LOOK_SENS
		_pitch = clampf(_pitch - mm.relative.y * LOOK_SENS, -1.5, 1.5)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
		return

	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_ESCAPE:
			if _captured:
				_capture(false)
			else:
				get_tree().quit()
		KEY_1, KEY_2, KEY_3, KEY_4:
			_lit = k.keycode - KEY_1
			_apply_lighting()
		KEY_N:
			if not _spots.is_empty():
				_spot_idx = (_spot_idx + 1) % _spots.size()
				_frame_spot(_spots[_spot_idx])
		KEY_F:
			Engine.time_scale = 1.0 if is_zero_approx(Engine.time_scale) else 0.0


func _apply_lighting() -> void:
	if _sun == null:
		return
	_sun.rotation_degrees = Vector3(float(LIGHTING[_lit][1]), 30.0, 0.0)
	_sun.light_energy = float(LIGHTING[_lit][2])


func _process(delta: float) -> void:
	if not _placed:
		if not _world.is_world_ready:
			_label.text = "generating AO, seed %d ..." % _seed
			return
		_placed = true
		_sun = _world.get_node_or_null("SunLight") as DirectionalLight3D
		_spots = _find_water_spots()
		if _spots.is_empty():
			_label.text = "seed %d generated NO water" % _seed
			push_warning("[WATERVIEW] no water in seed %d" % _seed)
			return
		_frame_spot(_spots[0])
		_apply_lighting()

	_fly(delta)
	_update_label()


func _fly(delta: float) -> void:
	if not _captured:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	if dir == Vector3.ZERO:
		return
	var spd: float = MOVE_SPEED * (BOOST_MULT if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	# Unscaled: F freezes water by zeroing time_scale, movement must survive it.
	_cam.global_position += dir.normalized() * spd * delta / maxf(Engine.time_scale, 0.0001)


func _update_label() -> void:
	if _spots.is_empty():
		return
	var p: Vector3 = _cam.global_position
	var ws: WaterSystem = _world.water_system
	var wet: bool = ws.is_water(p.x, p.z)
	var d: float = ws.get_water_depth(p.x, p.z)
	var lvl: float = ws.get_water_level_at(p.x, p.z)
	_label.text = "\n".join([
		"seed %d   %s   creek %d/%d   %s" % [
			_seed, LIGHTING[_lit][0], _spot_idx + 1, _spots.size(),
			"FROZEN" if is_zero_approx(Engine.time_scale) else ""],
		"cam  %.0f, %.1f, %.0f" % [p.x, p.y, p.z],
		"here  water=%s  depth=%.2fm  surface_y=%s" % [
			"YES" if wet else "no", d, ("%.2f" % lvl) if lvl != -INF else "-"],
		"",
		"WASD/QE fly · Shift boost · 1-4 time · N next creek · F freeze · ESC",
	])


func _frame_spot(spot: Dictionary) -> void:
	var target: Vector3 = spot["pos"]
	var along: Vector3 = spot["along"]
	var across := Vector3(-along.z, 0.0, along.x)
	# Stand off the bank and look back down the channel so the ribbon runs away
	# from the lens instead of crossing it.
	_cam.global_position = target + across * 7.0 + Vector3.UP * EYE_H - along * 5.0
	_cam.look_at(target, Vector3.UP)
	_yaw = _cam.rotation.y
	_pitch = _cam.rotation.x


## Every water cell scored by how much water surrounds it, thinned so the list is
## distinct channel runs rather than 300 neighbours of one creek.
func _find_water_spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ws: WaterSystem = _world.water_system
	if ws == null or ws.water_map_size == 0:
		return out
	var n: int = ws.water_map_size
	var cs: float = ws.water_map_cell_size

	var scored: Array[Dictionary] = []
	for cz in range(4, n - 4):
		for cx in range(4, n - 4):
			if ws.water_map[cz * n + cx] == 0:
				continue
			var score: int = 0
			for dz in range(-3, 4):
				for dx in range(-3, 4):
					if ws.water_map[(cz + dz) * n + cx + dx] > 0:
						score += 1
			scored.append({"cell": Vector2i(cx, cz), "score": score})

	scored.sort_custom(func(a, b): return a["score"] > b["score"])

	var min_sep: float = 45.0 / cs
	for s in scored:
		var c: Vector2i = s["cell"]
		var far_enough: bool = true
		for o in out:
			if Vector2(o["cell"]).distance_to(Vector2(c)) < min_sep:
				far_enough = false
				break
		if not far_enough:
			continue

		var wx: float = (c.x + 0.5) * cs
		var wz: float = (c.y + 0.5) * cs
		var level: float = ws.get_water_level_at(wx, wz)
		if level == -INF:
			level = _world.terrain_manager.get_height_at(Vector3(wx, 0.0, wz))

		var acc := Vector2.ZERO
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				if dx == 0 and dz == 0:
					continue
				if ws.water_map[(c.y + dz) * n + c.x + dx] > 0:
					var v := Vector2(float(dx), float(dz))
					if acc.dot(v) < 0.0:
						v = -v
					acc += v
		if acc.length() < 0.001:
			acc = Vector2(1.0, 0.0)

		out.append({
			"cell": c,
			"pos": Vector3(wx, level, wz),
			"along": Vector3(acc.normalized().x, 0.0, acc.normalized().y),
		})
		if out.size() >= 8:
			break

	return out
