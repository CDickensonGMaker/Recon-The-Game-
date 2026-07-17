## seat_system.gd - The 10-seat UH-1 slick contract: 2 pilots + 2 door gunners
## + 6 pax. Sockets are found ANYWHERE under the vehicle by exact name -
## seat_pilot_l / seat_pilot_r / seat_gunner_l / seat_gunner_r / seat_pax_1..6.
## GLB-exported empties import as plain Node3D, NOT Marker3D: the scan must
## accept any Node3D. Missing sockets are generated from FALLBACK_LAYOUT.
##
## SOCKET ORIENTATION CONTRACT: the occupant faces the socket's LOCAL +Z
## (characters are authored facing +Z; ModelActor yaw 0 == facing +Z).
## Pilots face the nose, gunners/pax face outward.
##
## The player is glued position-only (player.enter_seat) - NEVER reparent a
## physics body. AI bodies get physics/process/collision off + a RemoteTransform3D.
class_name SeatSystem
extends Node

signal seated(body: Node3D, seat_name: StringName)
signal unseated(body: Node3D)
signal prompt_changed(text: String)

## Canonical seat order. Crew first, then the cabin.
const SEAT_NAMES: Array[StringName] = [
	&"seat_pilot_l", &"seat_pilot_r",
	&"seat_gunner_l", &"seat_gunner_r",
	&"seat_pax_1", &"seat_pax_2", &"seat_pax_3",
	&"seat_pax_4", &"seat_pax_5", &"seat_pax_6",
]
## Fill order for squad/player boarding: bench first, door guns as overflow.
## Pilot seats are CREW seats - passengers never take the controls.
const PASSENGER_SEATS: Array[StringName] = [
	&"seat_pax_1", &"seat_pax_2", &"seat_pax_3",
	&"seat_pax_4", &"seat_pax_5", &"seat_pax_6",
	&"seat_gunner_l", &"seat_gunner_r",
]

## UH-1 fallback layout in vehicle-root space: seat -> [position, facing yaw degrees].
## Doors sit at z -3.4..-1.9 with walls at x +-1.56; nose = -Z, Door_Left side = +X.
const FALLBACK_LAYOUT: Dictionary = {
	&"seat_pilot_l": [Vector3(0.55, 1.35, -5.35), 180.0],
	&"seat_pilot_r": [Vector3(-0.55, 1.35, -5.35), 180.0],
	&"seat_gunner_l": [Vector3(1.15, 1.30, -2.70), 90.0],
	&"seat_gunner_r": [Vector3(-1.15, 1.30, -2.70), -90.0],
	&"seat_pax_1": [Vector3(0.40, 1.30, -3.40), 90.0],
	&"seat_pax_2": [Vector3(0.40, 1.30, -2.70), 90.0],
	&"seat_pax_3": [Vector3(0.40, 1.30, -2.00), 90.0],
	&"seat_pax_4": [Vector3(-0.40, 1.30, -3.40), -90.0],
	&"seat_pax_5": [Vector3(-0.40, 1.30, -2.70), -90.0],
	&"seat_pax_6": [Vector3(-0.40, 1.30, -2.00), -90.0],
}

const PILOT_CLIP := "cockpit_idle"
const SITTING_CLIP := "sitting"
const BOARD_STAGGER_S: float = 0.6   ## seconds between ally boardings
const FADE_S: float = 0.25           ## seconds of the board/dismount fade
const BOARD_RANGE: float = 4.5       ## player-to-door interact radius, metres
const EXIT_PUSH_M: float = 2.5       ## how far outside the door you land

## OPT-IN. In missions the bird is owned by InsertionRide / ExfilZone, whose own
## board/dismount flows poll the same interact key - enabling both double-triggers.
@export var player_boarding: bool = false:
	set(v):
		player_boarding = v
		set_physics_process(v)

var auto_generated: bool = false

var _vehicle: Node3D = null
var _sockets: Dictionary = {}        ## StringName -> Node3D
var _occupants: Dictionary = {}      ## StringName -> {body, glue, shapes, was_physics, was_process}
var _prompt: Label = null
var _prompt_text: String = ""
var _fading: bool = false
var _interact_cd: float = 0.0


var _scanned: bool = false


func _ready() -> void:
	_vehicle = get_parent() as Node3D
	if _vehicle == null:
		push_warning("[SeatSystem] parent is not a Node3D - no seats")
		set_physics_process(false)
		return
	# Deferred: generating fallback markers ADDS children to the vehicle, which
	# is forbidden while the scene is still setting up ("parent busy" error).
	_scan_sockets.call_deferred()
	set_physics_process(player_boarding)


## Find real sockets by name anywhere under the vehicle (the GLB export lands them
## inside the Model subtree); generate any missing one from FALLBACK_LAYOUT.
## Idempotent - the public API calls it lazily in case someone seats pre-frame-1.
func _scan_sockets() -> void:
	if _scanned or _vehicle == null:
		return
	_scanned = true
	var generated: int = 0
	for seat_name in SEAT_NAMES:
		# GLB empties arrive as plain Node3D - never type-check for Marker3D here.
		var existing := _vehicle.find_child(String(seat_name), true, false) as Node3D
		if existing != null:
			_sockets[seat_name] = existing
			continue
		var entry: Array = FALLBACK_LAYOUT[seat_name]
		var m := Marker3D.new()
		m.name = String(seat_name)
		_vehicle.add_child(m)
		m.position = entry[0] as Vector3
		m.rotation_degrees = Vector3(0.0, float(entry[1]), 0.0)
		_sockets[seat_name] = m
		generated += 1
	auto_generated = generated > 0
	if generated > 0:
		print("[SeatSystem] %s: auto-generated %d/10 UH-1 fallback sockets (real seat_* markers will override when exported)" % [_vehicle.name, generated])
	else:
		print("[SeatSystem] %s: all 10 seat_* sockets found in the model - fallback table retired" % _vehicle.name)


func available_seats() -> Array[StringName]:
	_scan_sockets()
	var out: Array[StringName] = []
	for seat_name in SEAT_NAMES:
		if _sockets.has(seat_name) and occupant(seat_name) == null:
			out.append(seat_name)
	return out


func occupant(seat_name: StringName) -> Node3D:
	if not _occupants.has(seat_name):
		return null
	var rec: Dictionary = _occupants[seat_name]
	var body := rec.get("body") as Node3D
	if body == null or not is_instance_valid(body):
		_occupants.erase(seat_name)  # occupant died/freed while seated
		return null
	return body


func is_full() -> bool:
	if _sockets.is_empty():
		return false
	for seat_name in SEAT_NAMES:
		if _sockets.has(seat_name) and occupant(seat_name) == null:
			return false
	return true


## The seat this body occupies, or &"" if not aboard.
func seat_of(body: Node3D) -> StringName:
	for seat_name in SEAT_NAMES:
		if _occupants.has(seat_name) and occupant(seat_name) == body:
			return seat_name
	return &""


func socket(seat_name: StringName) -> Node3D:
	_scan_sockets()
	return _sockets.get(seat_name) as Node3D


## Seat a body in a named socket. Returns false if the seat is unknown,
## occupied, or the body is already aboard.
func seat(body: Node3D, seat_name: StringName) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	_scan_sockets()
	if not _sockets.has(seat_name) or occupant(seat_name) != null:
		return false
	if seat_of(body) != &"":
		return false
	var sock: Node3D = _sockets[seat_name]
	var rec: Dictionary = {"body": body}

	if body.has_method("enter_seat"):
		# Player: position-only glue, never reparented.
		body.call("enter_seat", sock)
	else:
		# AI / mock body: freeze it and glue it to the socket.
		rec["was_physics"] = body.is_physics_processing()
		rec["was_process"] = body.is_processing()
		body.set_physics_process(false)
		body.set_process(false)
		var cb := body as CharacterBody3D
		if cb != null:
			cb.velocity = Vector3.ZERO
		var shapes: Array = []
		for c in body.get_children():
			var cs := c as CollisionShape3D
			if cs != null and not cs.disabled:
				cs.set_deferred("disabled", true)
				shapes.append(cs)
		rec["shapes"] = shapes
		body.global_transform = sock.global_transform
		body.reset_physics_interpolation()
		var glue := RemoteTransform3D.new()
		glue.update_scale = false
		sock.add_child(glue)
		glue.remote_path = glue.get_path_to(body)
		rec["glue"] = glue

	var model: ModelActor = _model_of(body)
	if model != null:
		# Zero the actor's local yaw so the authored +Z facing lines up with
		# the socket's +Z (set_facing writes GLOBAL yaw, so mid-walk actors
		# carry an arbitrary local offset in).
		model.rotation = Vector3.ZERO
		model.play(PILOT_CLIP if String(seat_name).begins_with("seat_pilot") else SITTING_CLIP)

	_occupants[seat_name] = rec
	seated.emit(body, seat_name)
	return true


## Restore a seated body to the world at exit_pos. Physics interpolation is ON
## project-wide, so every teleport out of the socket resets interpolation.
func unseat(body: Node3D, exit_pos: Vector3) -> void:
	var seat_name: StringName = seat_of(body)
	if seat_name == &"":
		return
	var rec: Dictionary = _occupants[seat_name]
	_occupants.erase(seat_name)
	var glue := rec.get("glue") as RemoteTransform3D
	if glue != null and is_instance_valid(glue):
		glue.queue_free()
	if body == null or not is_instance_valid(body):
		return

	if body.has_method("exit_seat"):
		body.call("exit_seat", exit_pos)  # player path (resets its own collision)
	else:
		var shapes: Array = rec.get("shapes", [])
		for s in shapes:
			var cs := s as CollisionShape3D
			if cs != null and is_instance_valid(cs):
				cs.set_deferred("disabled", false)
		body.set_physics_process(bool(rec.get("was_physics", true)))
		body.set_process(bool(rec.get("was_process", true)))
		body.global_position = exit_pos
		# Level the body: the socket basis carried the airframe's bank/pitch.
		var e: Vector3 = body.global_rotation
		body.global_rotation = Vector3(0.0, e.y, 0.0)
		var cb := body as CharacterBody3D
		if cb != null:
			cb.velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	unseated.emit(body)


func unseat_all(exit_center: Vector3) -> void:
	var i: int = 0
	for seat_name in SEAT_NAMES:
		var body: Node3D = occupant(seat_name)
		if body == null:
			continue
		var ring: float = TAU * float(i) / 10.0
		unseat(body, exit_center + Vector3(cos(ring), 0.0, sin(ring)) * 1.5)
		i += 1


## Order living allies to a staging point by the left door, then seat them one
## per BOARD_STAGGER_S. Dead/downed excluded. Returns how many were queued.
func board_squad(allies: Array) -> int:
	var staging: Vector3 = door_staging_pos()
	var queued: int = 0
	for a in allies:
		var body := a as Node3D
		if body == null or not is_instance_valid(body):
			continue
		if body.has_method("is_dead") and bool(body.call("is_dead")):
			continue
		if "is_downed" in body and bool(body.get("is_downed")):
			continue
		var ally := body as AllyBase
		if ally != null:
			ally.set_order(AllyBase.OrderMode.MOVE_TO, staging)
		queued += 1
		get_tree().create_timer(BOARD_STAGGER_S * float(queued)).timeout.connect(
			_board_one.bind(body))
	return queued


func _board_one(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		return
	if seat_of(body) != &"":
		return
	var seat_name: StringName = _next_free_passenger_seat()
	if seat_name == &"":
		return
	seat(body, seat_name)


func _next_free_passenger_seat() -> StringName:
	for seat_name in PASSENGER_SEATS:
		if _sockets.has(seat_name) and occupant(seat_name) == null:
			return seat_name
	return &""


## World-space point EXIT_PUSH_M outside the left door - allies stage here,
## the player dismounts here.
func door_staging_pos() -> Vector3:
	var sock: Node3D = _sockets.get(&"seat_gunner_l") as Node3D
	if sock != null:
		# Gunner sockets face outward: local +Z is straight out the door.
		return sock.global_position + sock.global_transform.basis.z * EXIT_PUSH_M
	if _vehicle != null:
		return _vehicle.global_position + Vector3(EXIT_PUSH_M, 0.0, 0.0)
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	_interact_cd = maxf(0.0, _interact_cd - delta)
	if not player_boarding or _fading or _vehicle == null:
		return
	var player := GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		_set_prompt("")
		return

	if seat_of(player) != &"":
		_set_prompt("DISMOUNT [E]")
		if _interact_ok():
			_interact_cd = 0.6
			_fade_then(func() -> void:
				unseat(player, _exit_ground(door_staging_pos())))
		return

	var near: bool = player.global_position.distance_to(door_staging_pos()) <= BOARD_RANGE \
		or player.global_position.distance_to(_vehicle.global_position) <= BOARD_RANGE
	_set_prompt("BOARD THE BIRD [E]" if near else "")
	if near and _interact_ok():
		_interact_cd = 0.6
		_fade_then(func() -> void:
			var seat_name: StringName = _next_free_passenger_seat()
			if seat_name != &"":
				seat(player, seat_name))


func _interact_ok() -> bool:
	return _interact_cd <= 0.0 and InsertionRide.context_interact_pressed()


func _fade_then(action: Callable) -> void:
	var overlay: ColorRect = _ensure_overlay()
	if overlay == null:
		action.call()
		return
	_fading = true
	var tw: Tween = create_tween()
	tw.tween_property(overlay, "color:a", 1.0, FADE_S)
	tw.tween_callback(action)
	tw.tween_property(overlay, "color:a", 0.0, FADE_S)
	tw.tween_callback(func() -> void: _fading = false)


var _overlay: ColorRect = null

func _ensure_overlay() -> ColorRect:
	if _overlay != null and is_instance_valid(_overlay):
		return _overlay
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	return _overlay


func _set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	prompt_changed.emit(text)
	if _prompt == null:
		if text == "":
			return
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		_prompt = ReconUI.make_label("", 18, ReconUI.AMBER)
		_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.position = Vector2(-200, -120)
		_prompt.custom_minimum_size = Vector2(400, 0)
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(_prompt)
	_prompt.text = text


## Ground under a door-exit point (raycast down; fallback: vehicle deck height).
func _exit_ground(pos: Vector3) -> Vector3:
	var out: Vector3 = pos
	out.y = _vehicle.global_position.y + 0.5
	var w3d: World3D = _vehicle.get_world_3d()
	if w3d != null:
		var query := PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 8.0, 1)  # layer 1 = world
		var hit: Dictionary = w3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var p: Vector3 = hit.position
			out.y = p.y + 1.0
	return out


func _model_of(body: Node3D) -> ModelActor:
	if body is ModelActor:
		return body as ModelActor
	if "sprite_actor" in body:  # AllyBase / EnemyBase renderer slot
		var sa := body.get("sprite_actor") as Node
		if sa is ModelActor:
			return sa as ModelActor
	for c in body.get_children():
		if c is ModelActor:
			return c as ModelActor
	return null
