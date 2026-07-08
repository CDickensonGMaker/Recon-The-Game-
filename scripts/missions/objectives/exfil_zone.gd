## exfil_zone.gd - The exfil gate (RTCW rule): refuses until required objectives
## are met. With use_bird, arrival calls the Huey; boarding it ends the mission
## (NS15). ABORT (emergency exfil) force-unlocks with the penalty flag set.
class_name ExfilZone
extends Node3D

signal player_at_exfil(unlocked: bool)
signal bird_called
signal bird_landed

const HUEY_SCENE := preload("res://scenes/vehicles/huey.tscn")
const BOARD_RADIUS: float = 6.0

@export var radius: float = 10.0
@export var complete_on_enter: bool = true
@export var use_bird: bool = false

var director: MissionDirector
var world: GameWorld
var force_unlock: bool = false
var fallback_pos: Vector3 = Vector3.ZERO  ## secondary LZ; the FINAL one
var shoot_down_chance: float = 0.35

var _poll_timer: float = 0.0
var _refuse_cooldown: float = 0.0
var _done: bool = false
var _bird: Helicopter = null
var _bird_state: int = 0  # 0 none, 1 inbound, 2 landed, 3 leaving
var _lz: LandingZone = null
var _is_final: bool = false  ## true after wave-off/shoot-down: bird commits
var _compromise_rolled: bool = false


func register(mission_director: MissionDirector) -> void:
	director = mission_director


func _unlocked() -> bool:
	return force_unlock or (director != null and director.state.is_exfil_unlocked())


func _physics_process(delta: float) -> void:
	if _done or director == null:
		return
	_refuse_cooldown = maxf(0.0, _refuse_cooldown - delta)
	_poll_timer += delta
	if _poll_timer < 0.25:
		return
	_poll_timer = 0.0

	var player := GameManager.player as Node3D
	if player == null:
		return

	# Boarding check while the bird sits on the LZ.
	if _bird_state == 2 and _bird != null:
		if player.global_position.distance_to(_bird.global_position) <= BOARD_RADIUS:
			_board()
		return

	if _bird_state == 1:
		# LZ compromise: enemies can ruin the primary LZ while the bird is inbound.
		if not _is_final and not _compromise_rolled and _bird != null and _lz != null:
			var bird_dist: float = _bird.global_position.distance_to(global_position)
			if bird_dist < 160.0 and _lz.is_hot():
				_compromise_rolled = true
				if randf() < shoot_down_chance:
					_shoot_down()
				else:
					_wave_off()
		return

	var flat_dist: float = Vector2(player.global_position.x - global_position.x,
		player.global_position.z - global_position.z).length()
	if flat_dist > radius:
		return
	if _unlocked():
		player_at_exfil.emit(true)
		if use_bird:
			_call_bird()
		elif complete_on_enter:
			_done = true
			director.finish_mission()
	elif _refuse_cooldown <= 0.0:
		_refuse_cooldown = 5.0
		director.toast.emit("OBJECTIVES REMAIN - EXFIL DENIED")
		player_at_exfil.emit(false)


func _call_bird() -> void:
	if _bird_state != 0:
		return
	_bird_state = 1
	director.toast.emit("PAPA BEAR INBOUND - POP SMOKE AND HOLD THE LZ")
	bird_called.emit()
	_lz = LandingZone.new()
	world.add_child(_lz)
	_lz.global_position = global_position
	_bird = HUEY_SCENE.instantiate()
	world.add_child(_bird)
	_bird.setup(world.terrain_manager)
	var edge := _edge_spawn()
	_bird.global_position = Vector3(edge.x, world.terrain_manager.get_height_at(edge) + 35.0, edge.z)
	_bird.landed.connect(_on_bird_landed)
	_bird.took_off.connect(_on_bird_took_off)
	_bird.fly_to(global_position, _lz)


func _edge_spawn() -> Vector3:
	var map_size: float = world.map_size
	var center := Vector3(map_size * 0.5, 0, map_size * 0.5)
	var dir := (global_position - center)
	dir.y = 0.0
	if dir.length() < 1.0:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	var edge := global_position + dir * (map_size * 0.45)
	edge.x = clampf(edge.x, 60.0, map_size - 60.0)
	edge.z = clampf(edge.z, 60.0, map_size - 60.0)
	return edge


func _on_bird_landed(_h: Helicopter, _lz_node: LandingZone) -> void:
	_bird_state = 2
	director.toast.emit("BIRD ON THE GROUND - GET ABOARD")
	bird_landed.emit()


func _board() -> void:
	_bird_state = 3
	director.toast.emit("EXTRACTION - DUSTOFF")
	# Ride out in the door seat (W12) - the climb-out is the closing shot.
	var player := GameManager.player as Node3D
	if player and player.has_method("enter_seat"):
		var seat := Marker3D.new()
		seat.name = "SeatDoorLeft"
		_bird.add_child(seat)
		seat.position = Vector3(-0.85, 1.35, 0.6)
		player.enter_seat(seat)
	elif player:
		player.visible = false
	# Squad climbs aboard too.
	for a in player.get_tree().get_nodes_in_group("allies"):
		(a as Node3D).visible = false
		(a as Node).set_physics_process(false)
	_bird.take_off()


func _on_bird_took_off(_h: Helicopter) -> void:
	if _done:
		return
	_done = true
	if _unlocked() and director.state.is_exfil_unlocked():
		director.finish_mission()
	else:
		# Emergency exfil: banked partial credit, flagged result.
		director.fail_mission("ABORTED - EMERGENCY EXFIL")


## LZ hot: bird breaks off; fallback LZ becomes the FINAL extraction point.
func _wave_off() -> void:
	director.toast.emit("LZ TOO HOT - BIRD BREAKING OFF")
	if _bird:
		_bird.landed.disconnect(_on_bird_landed)
		_bird.took_off.disconnect(_on_bird_took_off)
		_bird.fly_to(_edge_spawn())
		_bird.get_tree().create_timer(30.0).timeout.connect(_bird.queue_free)
	_relocate_to_fallback()


## Bird takes fire on approach: crash + fallback LZ.
func _shoot_down() -> void:
	director.toast.emit("PAPA BEAR IS HIT - BIRD GOING DOWN!")
	if _bird:
		_bird.landed.disconnect(_on_bird_landed)
		_bird.took_off.disconnect(_on_bird_took_off)
		_bird.crashed.connect(func(_h: Helicopter) -> void:
			director.toast.emit("BIRD DOWN. FALLBACK LZ IS YOUR ONLY WAY OUT."))
		_bird.shoot_down()
	_relocate_to_fallback()


func _relocate_to_fallback() -> void:
	_is_final = true
	_bird = null
	_lz = null
	_bird_state = 0
	_compromise_rolled = false
	if fallback_pos != Vector3.ZERO and world != null:
		global_position = Vector3(fallback_pos.x,
			world.terrain_manager.get_height_at(fallback_pos), fallback_pos.z)
		director.toast.emit("FALLBACK LZ MARKED - %.0fm OUT" % _player_distance())


func _player_distance() -> float:
	var player := GameManager.player as Node3D
	if player == null:
		return 0.0
	return player.global_position.distance_to(global_position)


func is_final_lz() -> bool:
	return _is_final
