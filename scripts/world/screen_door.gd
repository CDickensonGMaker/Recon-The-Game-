class_name ScreenDoor
extends Node3D

## A screen door on a spring.
##
## IT HAS NO COLLIDER AND IT NEVER BLOCKS. That is the whole design, and it is a Pillar 1
## requirement, not a convenience: an interior the enemy cannot follow you into is a player
## safe room. If the wire goes, they come in after you.
##
## The doorway therefore bakes OPEN and never rebakes - the same contract ZombieDoor states
## at scripts/zombies/zombie_door.gd:8-12. Nothing here is a nav_blocker, and the leaves must
## never be given a -colonly twin.
##
## No interact key either. _try_field_interact (scripts/player/player.gd:948) is a hardcoded
## branch chain with no registry, so every door added there would compete with the medkit
## crate for one button. A screen door needs no button: it opens because a body pushed it.
## Player, allies and enemies all trip it identically.

const OPEN_ANGLE: float = 1.43        ## radians, ~82 deg
const OPEN_SPEED: float = 7.0         ## a shoved screen door snaps open
const SHUT_SPEED: float = 3.2         ## the spring is slower than the shove
const HOLD_AFTER_EXIT: float = 0.30   ## s before the spring takes it back
const BOUNCE: float = 0.16            ## overshoot on the slam, so it does not just stop

@export var leaf_a_path: NodePath
@export var leaf_b_path: NodePath

var _leaf_a: Node3D = null
var _leaf_b: Node3D = null
var _rest_a: float = 0.0
var _rest_b: float = 0.0
var _open: float = 0.0
var _vel: float = 0.0
var _inside: int = 0
var _hold: float = 0.0


func _ready() -> void:
	_leaf_a = get_node_or_null(leaf_a_path) as Node3D
	_leaf_b = get_node_or_null(leaf_b_path) as Node3D
	if _leaf_a != null:
		_rest_a = _leaf_a.rotation.y
	if _leaf_b != null:
		_rest_b = _leaf_b.rotation.y
	var threshold: Area3D = get_node_or_null("Threshold") as Area3D
	if threshold == null:
		push_warning("[ScreenDoor] %s has no Threshold Area3D - the door will never open" % name)
		return
	threshold.body_entered.connect(_on_body_entered)
	threshold.body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node3D) -> void:
	_inside += 1
	_hold = HOLD_AFTER_EXIT


func _on_body_exited(_body: Node3D) -> void:
	_inside = maxi(0, _inside - 1)


func _physics_process(delta: float) -> void:
	var step: float = minf(delta, 0.066)
	if _inside > 0:
		_hold = HOLD_AFTER_EXIT
	elif _hold > 0.0:
		_hold -= step

	var want: float = 1.0 if (_inside > 0 or _hold > 0.0) else 0.0
	if want > _open:
		_open = minf(want, _open + OPEN_SPEED * step)
		_vel = OPEN_SPEED
	else:
		# Swing shut, then let the leaf overshoot past the jamb and settle - that overshoot
		# IS the slap. Without it the door glides to a stop and reads as a sliding panel.
		_vel -= SHUT_SPEED * step
		_open = maxf(-BOUNCE, _open + _vel * step)
		if _open <= 0.0 and _vel < 0.0:
			_vel = -_vel * 0.35
			if absf(_vel) < 0.25:
				_vel = 0.0
				_open = 0.0

	var swing: float = _open * OPEN_ANGLE
	if _leaf_a != null:
		_leaf_a.rotation.y = _rest_a + swing
	if _leaf_b != null:
		_leaf_b.rotation.y = _rest_b - swing


## True while either leaf is off its jamb - for an ambient creak/slap cue.
func is_swinging() -> bool:
	return _open > 0.02 or absf(_vel) > 0.01
