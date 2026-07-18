## helicopter.gd - Kinematic transport helicopter: terrain-following cruise,
## straight-line flight, land/unload/takeoff state machine.
class_name Helicopter
extends Node3D

signal arrived_at_destination
signal landed(heli: Helicopter, lz: LandingZone)
signal took_off(heli: Helicopter)

enum State { IDLE, FLYING, LANDING, LANDED, TAKING_OFF, CRASHING, DESTROYED }

@export var cruise_altitude: float = 30.0
@export var max_speed: float = 50.0
@export var landing_speed: float = 6.0
@export var climb_speed: float = 10.0

## Rotor spin (rad/s at full RPM). Real UH-1 main rotor is ~324 RPM = 34 rad/s,
## but a two-blade rotor strobes horribly at 60Hz, so we run it slower on purpose.
const MAIN_ROTOR_SPEED: float = 22.0
const TAIL_ROTOR_SPEED: float = 48.0
const SPOOL_RATE: float = 0.35  ## how fast RPM chases its target (0-1 per second-ish)

var state: State = State.IDLE
var terrain: TerrainManager
var _target: Vector3 = Vector3.ZERO
var _lz: LandingZone
var _land_y: float = 0.0

var _main_rotor: Node3D = null   ## New_Blade_1 - parent of New_Blade_2 + New_Rotor_Hub
var _tail_rotor: Node3D = null   ## New_TailBlade_2.002 - parent of the tail hub + blade
var _rotor_rpm: float = 0.0      ## 0..1, spools up/down with state


## The rotors are driven in code, not by the GLB's baked clips: those are six
## separate rotation/scale tracks that would need an AnimationTree to play
## together, and code lets the RPM spool with the flight state.
func _ready() -> void:
	# The GLB's scene root IS the "Model" node; the fuselage is its child Huey_Copy.
	var root := get_node_or_null("Model") as Node3D
	if root == null:
		return

	# The imported AnimationPlayer would fight our code-driven rotation.
	var anim := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null:
		anim.stop()
		anim.active = false

	# Godot's GLB importer rewrites '.' to '_' in node names: the authored
	# "New_TailBlade_2.002" arrives as "New_TailBlade_2_002". A miss returns null
	# silently and the rotor simply never turns, so warn loudly.
	_main_rotor = root.find_child("New_Blade_1", true, false) as Node3D
	_tail_rotor = root.find_child("New_TailBlade_2_002", true, false) as Node3D
	if _main_rotor == null:
		push_warning("[Huey] main rotor 'New_Blade_1' not found - blades will not spin")
	if _tail_rotor == null:
		push_warning("[Huey] tail rotor 'New_TailBlade_2_002' not found - tail will not spin")

	# Recenter on the fuselage's AABB centre, NOT its node origin: the mesh origin
	# sits ~2m forward of the hull's true centre and would offset the CollisionTable
	# box. MUST be basis-aware - huey.tscn rotates Model 180 degrees about Y, so the
	# centre has to be mapped through the basis first; a raw "-= centre" DOUBLES the
	# offset instead of cancelling it. The GLB's seat_* sockets ride inside Model and
	# land in this recentered frame at the FALLBACK_LAYOUT coordinates.
	var fuselage := root.find_child("Huey_Copy", true, false) as MeshInstance3D
	if fuselage != null:
		var centre: Vector3 = root.transform.basis * (fuselage.position + fuselage.get_aabb().get_center())
		root.position.x -= centre.x
		root.position.z -= centre.z


## Idle on the pad still turns slowly: a Huey with stopped rotors reads as wreckage.
func _target_rpm() -> float:
	match state:
		State.DESTROYED:
			return 0.0
		State.CRASHING:
			return 0.35
		State.IDLE, State.LANDED:
			return 0.30
		_:
			return 1.0


func _spin_rotors(delta: float) -> void:
	_rotor_rpm = lerpf(_rotor_rpm, _target_rpm(), clampf(SPOOL_RATE * delta * 4.0, 0.0, 1.0))
	if _rotor_rpm < 0.001:
		return
	if _main_rotor != null:
		_main_rotor.rotate_y(MAIN_ROTOR_SPEED * _rotor_rpm * delta)
	if _tail_rotor != null:
		# Tail boom runs along -Z, so the tail rotor turns about X.
		_tail_rotor.rotate_x(TAIL_ROTOR_SPEED * _rotor_rpm * delta)


## The 10-seat SeatSystem child (huey.tscn "Seats") - null on seatless vehicles.
func seats() -> SeatSystem:
	return get_node_or_null("Seats") as SeatSystem


## Air-traffic flight id; -1 = uncontrolled. Set by AirTraffic at dispatch.
var traffic_flight_id: int = -1


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
	_spin_rotors(delta)
	match state:
		State.FLYING:
			_process_flying(delta)
		State.LANDING:
			_process_landing(delta)
		State.TAKING_OFF:
			_process_takeoff(delta)
		State.CRASHING:
			_process_crashing(delta)




func _process_crashing(delta: float) -> void:
	var forward := -global_transform.basis.z
	global_position += forward * 18.0 * delta
	global_position.y -= 16.0 * delta
	rotation.z = lerpf(rotation.z, 0.6, 1.5 * delta)
	var ground: float = _ground_y(global_position)
	if global_position.y <= ground + 0.5:
		global_position.y = ground + 0.5
		state = State.DESTROYED
		# A shallow scar, not a pit trap: survivors must be able to walk out.
		DamageSystem.apply_damage(global_position, DamageSystem.DamageType.SMALL_EXPLOSION, 0.7)
		CombatManager.apply_explosion_damage(global_position, 150, 40, 10.0, null)


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
