## rotor_spin.gd - Spin the propellers and rotors on a flying machine.
##
## Two populations, one call:
##
##   BAKED   a1_skyraider carries `A1_PropellerAction`, ac47_spooky carries
##           `prop_spin` (plus three stall variants) - real curves on
##           rotation_quaternion that nothing was ever playing. Where a clip
##           exists it is played, because the artist's arc beats a guess.
##   RUNTIME huey_v3 has MainRotorMast / New_Blade_* / New_TailBlade_* /
##           TailRotorMast and NO actions at all. Those get spun per-frame.
##
## Spin axis is chosen by NAME, not assumed: a main rotor turns about the mast
## (local Y), a tail rotor about its own hub (local X), and an aircraft propeller
## about the thrust line, which after the 2026-08-12 facing bake is local Z.
class_name RotorSpin
extends Node

## Clip names worth playing if the model ships one, best first.
const SPIN_CLIPS: Array[String] = ["prop_spin", "A1_PropellerAction.001",
	"A1_PropellerAction", "rotor_spin"]

const MAIN_HINTS: Array[String] = ["mainrotor", "rotor_hub", "new_blade",
	"rotor_flybar", "new_rotor"]
const TAIL_HINTS: Array[String] = ["tailrotor", "tailblade", "new_tailblade"]
const PROP_HINTS: Array[String] = ["prop", "spinner", "blade"]

## Radians/sec. A Huey main rotor turns ~324 rpm (33.9 rad/s) and its tail rotor
## ~1660 rpm; both are far past what reads on screen, so these are the SPEEDS
## THAT LOOK RIGHT at 60fps without strobing into a standstill.
const MAIN_RPS: float = 12.0
const TAIL_RPS: float = 26.0
const PROP_RPS: float = 18.0

var _spun: Array[Dictionary] = []
var _player: AnimationPlayer = null


## Attach to `model` (an instanced GLB root) and start turning.
static func attach(model: Node3D) -> RotorSpin:
	var rs := RotorSpin.new()
	rs.name = "RotorSpin"
	model.add_child(rs)
	rs._bind(model)
	return rs


func _bind(model: Node3D) -> void:
	_player = _find_player(model)
	if _player != null:
		for clip in SPIN_CLIPS:
			if _player.has_animation(clip):
				var anim: Animation = _player.get_animation(clip)
				anim.loop_mode = Animation.LOOP_LINEAR
				_player.play(clip)
				return   # baked curves win; do not also hand-spin the same parts

	# No clip: hand-spin whatever is named like a rotor.
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var low: String = n.name.to_lower()
		var axis := Vector3.ZERO
		var rps: float = 0.0
		if _has(low, TAIL_HINTS):
			axis = Vector3.RIGHT
			rps = TAIL_RPS
		elif _has(low, MAIN_HINTS):
			axis = Vector3.UP
			rps = MAIN_RPS
		elif _has(low, PROP_HINTS):
			axis = Vector3.BACK
			rps = PROP_RPS
		if rps > 0.0:
			_spun.append({"node": n as Node3D, "axis": axis, "rps": rps})


func _has(low: String, hints: Array[String]) -> bool:
	for h in hints:
		if low.contains(h):
			return true
	return false


func _find_player(root: Node) -> AnimationPlayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			return n as AnimationPlayer
		for c in n.get_children():
			stack.append(c)
	return null


func _process(delta: float) -> void:
	if _spun.is_empty():
		return
	for rec in _spun:
		var n: Node3D = rec["node"]
		if not is_instance_valid(n):
			continue
		n.rotate_object_local(rec["axis"] as Vector3, float(rec["rps"]) * delta)
