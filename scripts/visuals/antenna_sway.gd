class_name AntennaSway
extends MeshInstance3D
## Makes the RTO's PRC-25 whip antenna bend and spring as he moves.
##
## The antenna is NOT animated and carries NO bones. It is a 108-tri whip with a vertex
## shader (assets/shaders/antenna_sway.gdshader) that bends it along its length. All this
## script does is decide, each physics frame, HOW FAR THE TIP SHOULD BE PUSHED - one
## Vector2, in metres, in the antenna's own local space.
##
## The physics is a damped spring driven by the carrier's ACCELERATION, not his velocity.
## That distinction is the whole effect:
##   * running at a constant speed, a real whip sits still (it has caught up)
##   * it lashes when you START, STOP, or CUT a corner
## Driving it off velocity would leave the antenna permanently bent backwards while
## running, which looks like it is caught in a gale.
##
## Attach this to the antenna MeshInstance3D. It finds the carrier (the CharacterBody3D
## it hangs under) by walking up the tree, so it works on the player, on an AI RTO, and
## on a corpse without any wiring.

## How hard the whip resists being bent. Higher = stiffer rod, faster snap-back.
@export var stiffness: float = 55.0
## How quickly the wobble dies out. Too low and it rings like a tuning fork forever.
@export var damping: float = 5.5
## Metres of tip travel per m/s^2 of carrier acceleration.
@export var accel_gain: float = 0.016
## The tip cannot travel further than this, however violently he moves.
@export var max_tip_travel: float = 0.22
## A slow idle breath so the whip is never perfectly dead when he is standing still.
@export var idle_amplitude: float = 0.006
@export var idle_speed: float = 1.7

var _material: ShaderMaterial = null
var _carrier: Node3D = null
var _prev_velocity: Vector3 = Vector3.ZERO
var _angle: Vector2 = Vector2.ZERO
var _angular_velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	var mat: Material = get_active_material(0)
	if mat is ShaderMaterial:
		_material = mat as ShaderMaterial
	else:
		push_warning("AntennaSway: %s has no ShaderMaterial - the whip will not move." % name)
		set_physics_process(false)
		return
	_carrier = _find_carrier()
	if _carrier == null:
		# Not an error: a dropped radio lying in the mud has no carrier. It just holds still.
		set_physics_process(false)


func _find_carrier() -> Node3D:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterBody3D:
			return n as Node3D
		n = n.get_parent()
	return null


func _physics_process(delta: float) -> void:
	if _material == null or _carrier == null or delta <= 0.0:
		return
	_time += delta

	var vel: Vector3 = Vector3.ZERO
	if _carrier is CharacterBody3D:
		vel = (_carrier as CharacterBody3D).velocity
	var accel: Vector3 = (vel - _prev_velocity) / delta
	_prev_velocity = vel

	# Into the antenna's own local space, so a whip mounted at an angle still lashes the
	# right way. The whip runs along local +Y, so its bending plane is local X/Z.
	var basis_inv: Basis = global_transform.basis.inverse()
	var local_accel: Vector3 = basis_inv * accel

	# The whip lags BEHIND the motion, so it is pushed opposite the acceleration.
	var drive: Vector2 = Vector2(-local_accel.x, -local_accel.z) * accel_gain

	# damped spring:  a = drive - k*x - c*v
	var accel_ang: Vector2 = drive - _angle * stiffness - _angular_velocity * damping
	_angular_velocity += accel_ang * delta
	_angle += _angular_velocity * delta

	if _angle.length() > max_tip_travel:
		_angle = _angle.normalized() * max_tip_travel
		# kill any outward velocity so it does not grind against the clamp
		var outward: Vector2 = _angle.normalized()
		var along: float = _angular_velocity.dot(outward)
		if along > 0.0:
			_angular_velocity -= outward * along

	var idle: Vector2 = Vector2(
		sin(_time * idle_speed), cos(_time * idle_speed * 0.73)) * idle_amplitude

	_material.set_shader_parameter("sway", _angle + idle)
