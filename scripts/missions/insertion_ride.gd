## insertion_ride.gd - Huey insertion ride v1 (W06/W07/W09/W10/W11).
## Walk up -> board (E/F) -> door seat, head-look -> flight with AA threat rolls
## -> touchdown -> dismount. Shoot-down = hard crash, mission continues (E&E).
class_name InsertionRide
extends Node

signal ride_finished(at_position: Vector3, crashed: bool)
signal prompt_changed(text: String)

const HUEY_SCENE := preload("res://scenes/vehicles/huey.tscn")
const ROTOR_LOOP := preload("res://assets/audio/sfx/rotor_loop.wav")

enum RideState { WAITING_BOARD, FLYING, LANDED_LZ, DISMOUNTED, CRASHED }

var world: GameWorld
var director: MissionDirector
var destination: Vector3
var state: RideState = RideState.WAITING_BOARD

var heli: Helicopter
var door_seat: Marker3D
var _rotor: AudioStreamPlayer3D
var _prompt_active: bool = false
var _aa_timer: float = 0.0
var _crashed: bool = false
var aa_roll_interval: float = 6.0
var aa_hit_chance_scale: float = 0.35  ## vs effective threat; tests may force


func setup(game_world: GameWorld, mission_director: MissionDirector, start_pad: Vector3, lz: Vector3) -> void:
	world = game_world
	director = mission_director
	destination = lz
	heli = HUEY_SCENE.instantiate()
	world.add_child(heli)
	heli.setup(world.terrain_manager)
	var pad_y: float = world.terrain_manager.get_height_at(start_pad)
	heli.global_position = Vector3(start_pad.x, pad_y + 0.5, start_pad.z)
	heli.reset_physics_interpolation()
	heli.state = Helicopter.State.LANDED
	_build_seats_and_crew()
	_start_rotor(0.85)


## Door seat + capsule crew. Blender handoff: the interior scene should expose
## sockets named SeatPilot / SeatCopilot / SeatDoorLeft / SeatDoorRight /
## DoorGunMount - this code looks for them by name before using fallbacks.
func _build_seats_and_crew() -> void:
	# PT7: seats tucked INSIDE the cabin (body is ~3.3m wide, floor ~1m up).
	door_seat = _socket("SeatDoorLeft", Vector3(-0.85, 1.35, 0.6))
	var crew_seats := [
		_socket("SeatPilot", Vector3(0.5, 1.5, -3.6)),
		_socket("SeatCopilot", Vector3(-0.5, 1.5, -3.6)),
		_socket("SeatDoorRight", Vector3(0.85, 1.35, 0.6)),
	]
	for seat in crew_seats:
		var crew := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.1
		crew.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.36, 0.24)
		crew.material_override = mat
		seat.add_child(crew)


func _socket(socket_name: String, fallback: Vector3) -> Marker3D:
	var existing := heli.find_child(socket_name, true, false) as Marker3D
	if existing:
		return existing
	var m := Marker3D.new()
	m.name = socket_name
	heli.add_child(m)
	m.position = fallback
	return m


func _start_rotor(pitch: float) -> void:
	_rotor = AudioStreamPlayer3D.new()
	var stream := ROTOR_LOOP as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2  # 16-bit mono frames
	_rotor.stream = stream
	_rotor.volume_db = 4.0
	_rotor.max_distance = 300.0
	_rotor.unit_size = 20.0
	_rotor.pitch_scale = pitch
	heli.add_child(_rotor)
	_rotor.play()


func _physics_process(delta: float) -> void:
	match state:
		RideState.WAITING_BOARD:
			_poll_board()
		RideState.FLYING:
			_aa_threat_tick(delta)
		RideState.LANDED_LZ:
			_poll_dismount()
		_:
			pass


## Context interact (W08): the bound interact action OR a raw E press while a
## prompt is up (lean_right shares E; harmless overlap during prompts).
static func context_interact_pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_physical_key_pressed(KEY_E)


func _poll_board() -> void:
	var player := world.player
	if player == null:
		return
	var dist: float = player.global_position.distance_to(heli.global_position)
	var near: bool = dist < 5.0
	if near != _prompt_active:
		_prompt_active = near
		prompt_changed.emit("BOARD THE BIRD [E]" if near else "")
	if near and context_interact_pressed():
		board()


func board() -> void:
	if state != RideState.WAITING_BOARD:
		return
	state = RideState.FLYING
	_prompt_active = false
	prompt_changed.emit("")
	world.player.enter_seat(door_seat)
	_stow_allies(true)
	_rotor.pitch_scale = 1.15
	heli.state = Helicopter.State.TAKING_OFF
	heli.took_off.connect(_on_lifted, CONNECT_ONE_SHOT)
	director.toast.emit("WHEELS UP - INBOUND TO THE AO")


func _on_lifted(_h: Helicopter) -> void:
	if _crashed:
		return
	heli.landed.connect(_on_touchdown, CONNECT_ONE_SHOT)
	heli.crashed.connect(_on_crashed, CONNECT_ONE_SHOT)
	heli.fly_to(destination)


func _stow_allies(aboard: bool) -> void:
	for a in get_tree().get_nodes_in_group("allies"):
		var ally := a as CharacterBody3D
		if ally == null:
			continue
		ally.visible = not aboard
		ally.set_physics_process(not aboard)
		if not aboard:
			var off := Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
			var pos: Vector3 = heli.global_position + off
			pos.y = world.terrain_manager.get_height_at(pos) + 0.5
			ally.global_position = pos
		ally.reset_physics_interpolation()


## W09: AA rolls while inbound, scaled by campaign threat.
func _aa_threat_tick(delta: float) -> void:
	_aa_timer += delta
	if _aa_timer < aa_roll_interval:
		return
	_aa_timer = 0.0
	var threat: float = CampaignState.effective_threat()
	if randf() > threat:
		return
	# AA event: ground tracer stream at the bird.
	var a := randf_range(0.0, TAU)
	var ground := heli.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(120.0, 280.0)
	ground.y = world.terrain_manager.get_height_at(ground)
	director.toast.emit("TAKING FIRE - AA ON THE %s" % _bearing_text(a))
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, ground, 1)
	for i in range(6):
		get_tree().create_timer(float(i) * 0.22).timeout.connect(func() -> void:
			if is_instance_valid(heli):
				var jitter := Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
				BulletTracer.spawn_tracer(world, ground + Vector3(0, 1, 0), heli.global_position + jitter, Color(0.4, 1.0, 0.5)))
	if randf() < threat * aa_hit_chance_scale:
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			if is_instance_valid(heli) and not _crashed:
				director.toast.emit("WE'RE HIT! BRACE - GOING DOWN")
				heli.shoot_down())


func _bearing_text(angle: float) -> String:
	var dirs := ["EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST", "WEST", "NORTHWEST", "NORTH", "NORTHEAST"]
	return dirs[int(roundf(angle / (TAU / 8.0))) % 8]


func _on_touchdown(_h: Helicopter, _lz: LandingZone) -> void:
	state = RideState.LANDED_LZ
	_rotor.pitch_scale = 0.9
	prompt_changed.emit("DISMOUNT [E]")
	_prompt_active = true


func _poll_dismount() -> void:
	if context_interact_pressed():
		dismount(false)


func dismount(from_crash: bool) -> void:
	if state == RideState.DISMOUNTED:
		return
	# PT3: after a crash, come out well clear of the crater rim.
	var side_dist: float = 8.0 if from_crash else 2.5
	var out := heli.global_position + heli.global_transform.basis.x * -side_dist
	out.y = world.terrain_manager.get_height_at(out) + 1.0
	world.player.exit_seat(out)
	_stow_allies(false)
	prompt_changed.emit("")
	state = RideState.DISMOUNTED
	if not from_crash:
		director.toast.emit("LZ IS %s - MOVE OUT" % ("COLD" if CampaignState.effective_threat() < 0.5 else "QUESTIONABLE"))
		# Bird departs.
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(heli):
				heli.take_off()
				get_tree().create_timer(25.0).timeout.connect(func() -> void:
					if is_instance_valid(heli):
						heli.queue_free()))
	ride_finished.emit(out, from_crash)


func _on_crashed(_h: Helicopter) -> void:
	_crashed = true
	state = RideState.CRASHED
	if _rotor:
		_rotor.stop()
	director.toast.emit("BIRD DOWN - SURVIVORS, MOVE OUT. MISSION CONTINUES.")
	dismount(true)
