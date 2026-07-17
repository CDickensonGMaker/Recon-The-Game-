## severed_bones_modifier.gd - keeps dismembered limbs GONE under ragdoll.
##
## Dismemberment collapses a bone's pose scale - but PhysicalBoneSimulator3D
## is a SkeletonModifier that rewrites every bone pose each frame, which
## RESURRECTS blown-off limbs the moment ragdoll kicks in.
## SkeletonModifier3Ds run in child order: this one must sit AFTER the sim
## (ModelActor keeps it last), re-zeroing severed bone chains so the severed
## state survives physics, animation, and anything else driving the skeleton.
class_name SeveredBonesModifier
extends SkeletonModifier3D

var severed: PackedInt32Array = PackedInt32Array()


func sever(bone_idx: int) -> void:
	if bone_idx >= 0 and not severed.has(bone_idx):
		severed.append(bone_idx)


func _process_modification() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null:
		return
	for bi in severed:
		skel.set_bone_pose_scale(bi, Vector3.ONE * 0.0001)
