## helicopter.gd - Kinematic transport helicopter (NS14). Terrain-following
## cruise, straight-line flight, land/unload/takeoff state machine.
## Concepts from the RTS insertion system, original implementation.
class_name Helicopter
extends Node3D

signal arrived_at_destination
signal landed(heli: Helicopter, lz: LandingZone)
signal took_off(heli: Helicopter)
signal crashed(heli: Helicopter)

enum State { IDLE, FLYING, LANDING, LANDED, TAKING_OFF, CRASHING, DESTROYED }

@export var cruise_altitude: float = 30.0
@export var max_speed: float = 50.0
@export var landing_speed: float = 6.0
@export var climb_speed: float = 10.0

var state: State = State.IDLE
var terrain: TerrainManager
var _target: Vector3 = Vector3.ZERO
var _lz: LandingZone
var _land_y: float = 0.0


## PT7: the source GLB ships a duplicate blank fuselage + spare skid parts at
## x=-7.7 and the real bird at x=+8.3. Strip the junk and recenter the model.
func _ready() -> void:
	var model := get_node_or_null("Model")
	if model == null:
		return
	var junk_prefixes := ["Huey_Copy", "New_Skid", "Cross_", "Strut_"]
	var root := model.get_child(0) if model.get_child_count() > 0 else model
	for child in root.get_children():
		for prefix in junk_prefixes:
			if str(child.name).begins_with(prefix):
				child.queue_free()
				break
	# Recenter: the real Body sits ~+8.26 on X in the source.
	var body := root.find_child("Body", true, false) as Node3D
	if body != null:
		root.position.x -= body.position.x
		root.position.z -= body.position.z


func setup(terrain_manager: TerrainManager) -> void:
	terrain = terrain_manager


func fly_to(target: Vector3, lz: LandingZone = null) -> void:
	_target = target
	_lz = lz
	state = State.FLYING


func take_off() -> void:
	if state != State.LANDED:
		return
	if _lz:
		_lz.helicopters_present = maxi(0, _lz.helicopters_present - 1)
		_lz = null
	state = State.TAKING_OFF


func _ground_y(pos: Vector3) -> float:
	if terrain:
		return terrain.get_height_at(pos)
	return 0.0


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_process_flying(delta)
		State.LANDING:
			_process_landing(delta)
		State.TAKING_OFF:
			_process_takeoff(delta)
		State.CRASHING:
			_process_crashing(delta)


## Shot down: uncontrolled descent with forward drift, then wreck.
func shoot_down() -> void:
	if state == State.CRASHING or state == State.DESTROYED:
		return
	state = State.CRASHING


func _process_crashing(delta: float) -> void:
	var forward := -global_transform.basis.z
	global_position += forward * 18.0 * delta
	global_position.y -= 16.0 * delta
	rotation.z = lerpf(rotation.z, 0.6, 1.5 * delta)
	var ground: float = _ground_y(global_position)
	if global_position.y <= ground + 0.5:
		global_position.y = ground + 0.5
		state = State.DESTROYED
		# PT3: shallow scar, not a pit trap - survivors must be able to walk out.
		DamageSystem.apply_damage(global_position, DamageSystem.DamageType.SMALL_EXPLOSION, 0.7)
		CombatManager.apply_explosion_damage(global_position, 150, 40, 10.0, null)
		crashed.emit(self)


func _process_flying(delta: float) -> void:
	var flat_target := Vector3(_target.x, 0, _target.z)
	var flat_pos := Vector3(global_position.x, 0, global_position.z)
	var to_target := flat_target - flat_pos
	var dist: float = to_target.length()
	var desired_y: float = _ground_y(global_position) + cruise_altitude

	if dist < 4.0:
		arrived_at_destination.emit()
		if _lz != null or _target != Vector3.ZERO:
			_land_y = _ground_y(_target) + 0.5
			state = State.LANDING
		else:
			state = State.IDLE
		return

	var speed: float = max_speed if dist > 25.0 else maxf(8.0, max_speed * dist / 60.0)
	var dir := to_target.normalized()
	global_position += dir * speed * delta
	global_position.y = lerpf(global_position.y, desired_y, 1.5 * delta)
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 2.5 * delta)


func _process_landing(delta: float) -> void:
	global_position.y -= landing_speed * delta
	if global_position.y <= _land_y:
		global_position.y = _land_y
		state = State.LANDED
		if _lz:
			_lz.helicopters_present += 1
		landed.emit(self, _lz)


func _process_takeoff(delta: float) -> void:
	var desired_y: float = _ground_y(global_position) + cruise_altitude
	global_position.y += climb_speed * delta
	if global_position.y >= desired_y:
		state = State.IDLE
		took_off.emit(self)
