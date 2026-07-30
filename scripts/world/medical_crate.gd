class_name MedicalCrate
extends Node3D

## The medic's field resupply. He sets one down every RESUPPLY_INTERVAL_S or after a real
## firefight, whichever lands first (SquadSystem drives that), calls it, and the squad takes
## bandages off it with [F].
##
## Deliberately NOT a viewmodel: this is world geometry you walk to, so it carries no clips
## and never goes through export_viewmodel_clips.py. `tools/make_medical_crate.py` builds
## the GLB; run that to regenerate it.

const MODEL_PATH: String = "res://assets/world/props/medical_crate.glb"
const GROUP: StringName = &"medical_crate"

## What one crate holds, and the most a man will carry off it. The carry cap is what stops
## a crate becoming an infinite pocket - without it a resupply is just a bigger number.
const BANDAGES_PER_CRATE: int = 6
const CARRY_LIMIT: int = 6
const REACH_M: float = 2.6

var remaining: int = BANDAGES_PER_CRATE


static func drop(parent: Node, pos: Vector3) -> MedicalCrate:
	if parent == null:
		return null
	var crate := MedicalCrate.new()
	crate.name = "MedicalCrate"
	parent.add_child(crate)
	crate.global_position = pos
	crate.add_to_group(GROUP)
	# Real model if it has been built, a plain box otherwise - a missing art file must not
	# cost the player his resupply.
	var packed: PackedScene = load(MODEL_PATH) as PackedScene if ResourceLoader.exists(MODEL_PATH) else null
	if packed != null:
		crate.add_child(packed.instantiate())
	else:
		var vis := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.3, 0.39)
		vis.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.17, 0.19, 0.13)
		vis.material_override = mat
		vis.position = Vector3(0, 0.15, 0)
		crate.add_child(vis)
	return crate


## The crate within reach of `who` that still has something in it, or null.
static func nearest(who: Node3D, max_d: float = REACH_M) -> MedicalCrate:
	if who == null or who.get_tree() == null:
		return null
	var best: MedicalCrate = null
	var best_d: float = max_d
	for n in who.get_tree().get_nodes_in_group(GROUP):
		var c := n as MedicalCrate
		if c == null or not is_instance_valid(c) or c.remaining <= 0:
			continue
		var d: float = c.global_position.distance_to(who.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


## Take what he can carry. Returns how many actually moved, so the caller can stay quiet
## when the answer is none.
func take(health_system: HealthSystem) -> int:
	if health_system == null or remaining <= 0:
		return 0
	var room: int = maxi(0, CARRY_LIMIT - health_system.health_packs)
	var moved: int = mini(room, remaining)
	if moved <= 0:
		return 0
	remaining -= moved
	health_system.health_packs += moved
	health_system.health_pack_changed.emit(health_system.health_packs)
	return moved
