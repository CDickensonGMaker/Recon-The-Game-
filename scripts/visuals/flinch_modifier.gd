## flinch_modifier.gd - a directional spine punch laid over whatever clip is
## playing, so a man who is hit MOVES without surrendering his animation.
##
## Additive and short-lived: it rotates the spine away from the round and decays.
## It never replaces a clip, so a running man keeps running while he takes it.
class_name FlinchModifier
extends SkeletonModifier3D

## How far the spine yields on a full-strength hit.
const MAX_PITCH_DEG: float = 22.0
## Seconds from full punch back to nothing.
const DECAY_S: float = 0.28

var _bone: int = -1
## Punch in the skeleton's own basis: x = shoved backward, z = shoved sideways.
var _punch: Vector2 = Vector2.ZERO
var _amount: float = 0.0


func _ready() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null:
		return
	for candidate in ["mixamorig_Spine1", "mixamorig_Spine", "mixamorig_Spine2"]:
		_bone = skel.find_bone(candidate)
		if _bone != -1:
			break


## `local_dir` is the round's travel direction expressed in the actor's space.
func punch(local_dir: Vector3, strength: float) -> void:
	_punch = Vector2(local_dir.z, -local_dir.x)
	if _punch.length() > 0.001:
		_punch = _punch.normalized()
	_amount = clampf(strength, 0.0, 1.0)


func is_spent() -> bool:
	return _amount <= 0.001


func _process_modification() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null or _bone == -1 or _amount <= 0.001:
		return
	var rad: float = deg_to_rad(MAX_PITCH_DEG) * _amount
	var pose: Transform3D = skel.get_bone_pose(_bone)
	pose.basis = pose.basis \
		* Basis(Vector3.RIGHT, rad * _punch.x) \
		* Basis(Vector3.FORWARD, rad * _punch.y)
	skel.set_bone_pose_rotation(_bone, pose.basis.get_rotation_quaternion())
	_amount = maxf(0.0, _amount - get_physics_process_delta_time() / DECAY_S)
