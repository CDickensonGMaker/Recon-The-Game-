## kit_editor.gd - THE MODULAR WORLD BUILDING TOOL (ADR-043 §5), as an in-game dev mode.
##
## Launch: godot --path . res://tools/kit_editor.tscn
##   KIT_PLAN=<name>  opens that plan out of data/site_plans/ (default: fsb_kit_alpha).
##   L reloads it, O moves the site centre under the crosshair, G stamps, P spawns the
##   player outside the gate so the place can be walked at eye height.
##
## IT IS NOT AN EDITOR PLUGIN, and the reason is a fact rather than a preference:
## scenes/levels/game_world.tscn is six lines and one empty Node3D. Every world node - terrain,
## navmesh, vegetation - is built in code at runtime, TerrainEngine is not @tool, and the
## project has no addons/ directory. Inside the Godot editor there is no heightmap to brush and
## no navmesh to place against. @tool-ing the foundation to fake one would be a second execution
## context for the world build, which ADR-028 forbids by name.
##
## So the tool runs the real game world, and a part placed here is placed against the real
## ground, the real navmesh and the real colliders - which is the whole point, because ADR-041's
## founding measurement was that every expensive defect it closed was a PLACEMENT defect,
## invisible in Blender and obvious in Godot.
##
## It writes a JSON plan. It never writes a .tscn: a composed scene through place_structure()
## breaks ten contracts, enumerated in ADR-041 §3.
extends Node

const SEED_VAL: int = 4242
const FLY_SPEED: float = 24.0
const FLY_FAST: float = 90.0
const MOUSE_SENS: float = 0.0022
const PLACE_RANGE_M: float = 400.0

var _world: GameWorld = null
var _cam: Camera3D = null
var _state := KitEditorState.new()
var _hud: Label = null
var _status: String = ""
var _preview: Node3D = null
var _stamped: Node3D = null
var _yaw: float = 0.0
var _pitch: float = -0.35
var _captured: bool = false
## Set once the player is spawned. The fly camera and every editing key stand down: two
## things reading WASD in the same frame is how a tool gets called broken.
var _walking: bool = false


func _ready() -> void:
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_color_override("font_color", Color(0.86, 0.88, 0.80))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 4)
	var layer := CanvasLayer.new()
	layer.add_child(_hud)
	add_child(layer)

	_state.setup(KitRegistry.load_kit())
	_set_status("kit: %d placeable part(s)" % _state.palette.size())

	# OPEN A SAVED PLAN. A tool that can only ever start from an empty plan cannot be used
	# to review one, and reviewing a place in the engine that renders it is the whole
	# argument for the tool (ADR-041). KIT_PLAN names it; L reloads it from disk.
	if _state.load_plan(_plan_name()):
		_set_status("loaded plan '%s': %d part(s)" % [_plan_name(), _state.plan.parts.size()])

	var scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	_world = scene.instantiate() as GameWorld
	_world.mission_seed = SEED_VAL
	_world.spawn_player_on_ready = false
	add_child(_world)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.far = 2000.0
	add_child(_cam)

	await _await_world()
	_cam.global_position = Vector3(256.0, _ground_y(Vector3(256.0, 0.0, 256.0)) + 40.0, 256.0)
	_capture(true)


func _await_world() -> void:
	var waited: float = 0.0
	while _world != null and not _world.is_world_ready and waited < 300.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_set_status("world ready" if _world != null and _world.is_world_ready else "WORLD TIMED OUT")


func _process(delta: float) -> void:
	_fly(delta)
	_update_preview()
	_draw_hud()


func _fly(delta: float) -> void:
	if _cam == null or _walking:
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
	if dir.length_squared() > 0.0:
		var speed: float = FLY_FAST if Input.is_key_pressed(KEY_SHIFT) else FLY_SPEED
		_cam.global_position += dir.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if _walking:
		return      # the player owns the mouse and the keyboard now
	var mm := event as InputEventMouseMotion
	if mm != null and _captured:
		_yaw -= mm.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - mm.relative.y * MOUSE_SENS, -1.5, 1.5)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
		return

	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_place_here()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_select_here()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_state.cycle_palette(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_state.cycle_palette(-1)
		return

	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE:
			_capture(not _captured)
		KEY_BRACKETLEFT:
			_state.cycle_palette(-1)
		KEY_BRACKETRIGHT:
			_state.cycle_palette(1)
		KEY_LEFT:
			_state.nudge(Vector3(-KitEditorState.NUDGE_M, 0, 0))
		KEY_RIGHT:
			_state.nudge(Vector3(KitEditorState.NUDGE_M, 0, 0))
		KEY_UP:
			_state.nudge(Vector3(0, 0, -KitEditorState.NUDGE_M))
		KEY_DOWN:
			_state.nudge(Vector3(0, 0, KitEditorState.NUDGE_M))
		KEY_PAGEUP:
			_state.nudge(Vector3(0, KitEditorState.NUDGE_M, 0))
		KEY_PAGEDOWN:
			_state.nudge(Vector3(0, -KitEditorState.NUDGE_M, 0))
		KEY_COMMA:
			_state.rotate_selected(-1)
		KEY_PERIOD:
			_state.rotate_selected(1)
		KEY_DELETE:
			_state.delete_selected()
		KEY_Z:
			if k.ctrl_pressed:
				_set_status("undo" if _state.undo() else "nothing to undo")
		KEY_S:
			if k.ctrl_pressed:
				var why: String = _state.save()
				_set_status("saved %s" % SitePlan.path_for(_state.plan.plan_name)
					if why == "" else "REFUSED: %s" % why)
		KEY_G:
			_stamp_preview()
		KEY_L:
			_set_status("loaded plan '%s'" % _plan_name() if _state.load_plan(_plan_name())
				else "no plan '%s' in %s" % [_plan_name(), SitePlan.DIR])
		KEY_O:
			var hit: Vector3 = _aim_ground()
			if hit == Vector3.INF:
				_set_status("no ground under the crosshair")
			else:
				_origin = hit
				_set_status("site centre moved to %s - press G to stamp there"
					% str(hit.round()))
		KEY_P:
			_walk()


## Place at the ground point under the crosshair. The cast is against the REAL world, so a
## part cannot be placed on nothing - which is the failure the whole tool exists to prevent.
func _place_here() -> void:
	var hit: Vector3 = _aim_ground()
	if hit == Vector3.INF:
		_set_status("no ground under the crosshair")
		return
	if _state.place(_to_local(hit)) < 0:
		_set_status("palette is empty - no kit .glb on disk")
		return
	_set_status("placed %s (%d part(s))" % [_state.current_palette_id(), _state.plan.parts.size()])


func _select_here() -> void:
	var hit: Vector3 = _aim_ground()
	if hit == Vector3.INF:
		return
	var i: int = _state.select_nearest(_to_local(hit))
	_set_status("selected %d" % i if i >= 0 else "nothing near the crosshair")


## Stamp the plan through SitePlanner - the SAME entry point the game uses, never a private
## preview path. If it looks right here it is right in the build, and if it is wrong here the
## tool has found the defect instead of a playtest.
func _stamp_preview() -> void:
	if _world == null or not _world.is_world_ready:
		return
	if _stamped != null and is_instance_valid(_stamped):
		_stamped.queue_free()
		_stamped = null
	var planner := SitePlanner.new(_world.gameplay_grid, _world.terrain_manager,
		_world.vegetation_manager, _world)
	var site: Dictionary = planner.stamp_site_plan(_state.plan, _site_centre(), _state.registry)
	if site.is_empty():
		_set_status("stamp refused - see the log")
		return
	_stamped = (site.get("nodes", []) as Array)[0] as Node3D
	_set_status("stamped %d part(s), %d station(s)"
		% [_state.plan.parts.size(), (site.get("stations", []) as Array).size()])


## WALK WHAT YOU JUST STAMPED. The tool builds the place against the real world; this is the
## half that lets him check it at eye height, which is the only height that matters. Spawns
## him OUTSIDE the gate if the plan has one, looking in - the approach is the view a place
## has to earn.
func _walk() -> void:
	if _world == null or not _world.is_world_ready or _walking:
		return
	if _stamped == null or not is_instance_valid(_stamped):
		_set_status("stamp it first (G) - there is nothing to walk yet")
		return
	var at: Vector3 = _site_centre()
	var gate: Node3D = null
	for c in _stamped.get_children():
		var n := c as Node3D
		if n != null and str(n.get_meta("part_id", "")).begins_with("fb_gate"):
			gate = n
			break
	if gate != null:
		var road: Vector3 = gate.global_transform.basis.z
		road.y = 0.0
		road = road.normalized()
		if (gate.global_position + road).distance_to(at) < gate.global_position.distance_to(at):
			road = -road
		at = gate.global_position + road * 28.0
	_world.spawn_player_at(at)
	_walking = true
	if _cam != null:
		_cam.current = false
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
	_set_status("WALKING - spawned %s. Restart the tool to edit again."
		% ("outside the gate" if gate != null else "at the site centre"))


func _plan_name() -> String:
	var n: String = OS.get_environment("KIT_PLAN")
	return n if n != "" else "fsb_kit_alpha"


func _update_preview() -> void:
	if _walking:
		return
	var id: String = _state.current_palette_id()
	if id == "" or _state.registry == null:
		return
	if _preview != null and str(_preview.get_meta("part_id", "")) != id:
		_preview.queue_free()
		_preview = null
	if _preview == null:
		var ps: PackedScene = load(_state.registry.model_path(id)) as PackedScene
		if ps == null:
			return
		_preview = ps.instantiate() as Node3D
		if _preview == null:
			return
		_preview.set_meta("part_id", id)
		add_child(_preview)
	var hit: Vector3 = _aim_ground()
	_preview.visible = hit != Vector3.INF
	if hit != Vector3.INF:
		_preview.global_position = hit


func _aim_ground() -> Vector3:
	if _cam == null:
		return Vector3.INF
	var from: Vector3 = _cam.global_position
	var to: Vector3 = from - _cam.global_transform.basis.z * PLACE_RANGE_M
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit: Dictionary = get_viewport().get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	return hit.position


func _ground_y(at: Vector3) -> float:
	if _world == null:
		return 0.0
	return _world.floor_y(at)


## The plan's origin. Fixed at the first part's ground point so local offsets stay stable while
## he works - a moving origin would silently rewrite every offset already placed.
func _site_centre() -> Vector3:
	return _origin


var _origin: Vector3 = Vector3(256.0, 0.0, 256.0)


func _to_local(world_pos: Vector3) -> Vector3:
	if _state.plan.parts.is_empty():
		_origin = world_pos
	return world_pos - _origin


func _capture(on: bool) -> void:
	_captured = on
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func _set_status(s: String) -> void:
	_status = s
	print("[KIT] ", s)


func _draw_hud() -> void:
	if _hud == null:
		return
	var sel: String = "-"
	if _state.selection >= 0 and _state.selection < _state.plan.parts.size():
		var p: Dictionary = _state.plan.parts[_state.selection]
		sel = "%s  yaw %.0f  at %s" % [str(p["id"]), float(p["yaw_deg"]),
			str((p["pos"] as Vector3).round())]
	_hud.text = "\n".join([
		"KIT EDITOR   plan '%s'   %d part(s)" % [_state.plan.plan_name, _state.plan.parts.size()],
		"palette: %s   (%d/%d)" % [_state.current_palette_id(),
			_state.palette_index + 1, maxi(_state.palette.size(), 1)],
		"selected: %s" % sel,
		"",
		"WASD/QE fly  SHIFT fast  ESC free mouse",
		"LMB place   RMB select   wheel or [ ] palette",
		"arrows nudge  PgUp/PgDn height  , . rotate  DEL remove",
		"CTRL+Z undo   CTRL+S save   L load '%s'   O set site centre" % _plan_name(),
		"G stamp through SitePlanner   P spawn and WALK it",
		"",
		_status,
	])
