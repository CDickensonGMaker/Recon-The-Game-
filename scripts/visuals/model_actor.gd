## model_actor.gd - rigged 3D character, the DEFAULT renderer.
##
## Decision (Caleb, locked): 3D models are the normal, sprites are the far-LOD /
## fallback. This mirrors SpriteActor's interface (setup/play/set_facing/flash/
## muzzle_*) so EnemyBase and AllyBase swap one for the other with no other
## change, and a future distance-LOD can hold BOTH and cross-fade.
##
## The logic is promoted verbatim from the combat lab, where it was proven: load
## assets/models/characters/<unit>.glb, normalise to character_height_m, seat the
## feet, and drive the rigged AnimationPlayer off SpriteStateMap intents so the
## model animates from the same AI the sprites did.
class_name ModelActor
extends Node3D

const MODEL_DIR := "res://assets/models/characters/"
const TARGET_HEIGHT_M: float = 1.7132   ## == manifests' character_height_m

var unit: String = ""
var norm_k: float = 1.0   ## normalization scale applied to the instance (ADR-002)
var _inst: Node3D = null
var _anim: AnimationPlayer = null
var _skel: Skeleton3D = null
var _current_clip: String = ""
var _flash_mats: Array[StandardMaterial3D] = []
var _flash_until: float = 0.0
var _facing: Vector3 = Vector3.FORWARD


static func model_exists(unit_id: String) -> bool:
	return not unit_id.is_empty() and ResourceLoader.exists(MODEL_DIR + unit_id + ".glb")


## Returns false if the unit has no .glb - caller falls back to SpriteActor.
func setup(unit_id: String) -> bool:
	unit = unit_id
	if not ModelActor.model_exists(unit_id):
		return false
	var packed: PackedScene = load(MODEL_DIR + unit_id + ".glb")
	if packed == null:
		return false
	_inst = packed.instantiate() as Node3D
	add_child(_inst)

	# Normalise height + seat feet on this node's origin (which sits at the
	# CharacterBody3D's feet), so hitzones and the 1.7m HEAD zone line up.
	var aabb := _aabb_of(_inst)
	if aabb.size.y > 0.01:
		var k: float = TARGET_HEIGHT_M / aabb.size.y
		norm_k = k
		_inst.scale = Vector3(k, k, k)
		_inst.position.y = -aabb.position.y * k
		print("[MODEL] %s instance_h=%.2f k=%.3f (k far from ~0.9 = off-spec export; see GAME_SCALE_STANDARD)" % [unit_id, aabb.size.y, k])

	_anim = _inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skel = _inst.find_child("Skeleton3D", true, false) as Skeleton3D
	_apply_loop_modes()
	_apply_gib_rig_contract()
	return true


## glTF carries NO loop flag, so every imported clip is play-once: an idle
## plays ~2s then FREEZES on its last frame - which reads as a T-pose/statue.
## Mark the cyclic clips looping at load. One-shots (deaths, jumps, turns,
## transitions) stay play-once.
const _LOOP_PREFIXES: Array[String] = ["idle", "run", "walk", "sprint", "strafe", "swim", "firing"]

func _apply_loop_modes() -> void:
	if _anim == null:
		return
	for clip_name in _anim.get_animation_list():
		var nm := String(clip_name)
		if nm.contains("turn") or nm.contains("_to_") or nm.contains("jump"):
			continue
		for p in _LOOP_PREFIXES:
			if nm.begins_with(p):
				var a: Animation = _anim.get_animation(clip_name)
				if a != null:
					a.loop_mode = Animation.LOOP_LINEAR
				break


## Gib-rig contract (bead 1xqs / us_grunt_v2, ARTIST INTENT verified in the
## .blend 2026-07-10): the *_joined mesh is the LIVE body (visible in Blender);
## the pre-cut region meshes (grunt_*) are GIB DONORS, viewport-hidden in
## Blender - but Blender viewport-hide does not survive glTF export, so both
## arrive visible = the double-render / "multi arms" bug. Godot re-applies the
## intent: donors hidden, joined body renders. Dismemberment collapses the
## bone chain (removes the limb from the joined body + gear on that chain)
## and spawns the hidden donor mesh as the flying gib. Non-contract rigs: no-op.
func _apply_gib_rig_contract() -> void:
	if _inst == null:
		return
	var has_joined_body: bool = false
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi != null and mi.name.ends_with("_joined"):
			has_joined_body = true
			break
	if not has_joined_body:
		return
	var hidden: int = 0
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nm := String(mi.name)
		if nm.begins_with("grunt_") and not nm.ends_with("_joined"):
			mi.visible = false
			hidden += 1
	if hidden > 0:
		print("[MODEL] %s: hid %d gib-donor region meshes (gib-rig contract; joined body renders)" % [unit, hidden])


func has_visual() -> bool:
	return _inst != null


## Rig access for the gore system (GORE_WORKFLOW Phase 3).
func skeleton() -> Skeleton3D:
	return _skel


func instance_root() -> Node3D:
	return _inst


func clip_names() -> PackedStringArray:
	if _anim == null:
		return PackedStringArray()
	return _anim.get_animation_list()


func stop_anim() -> void:
	if _anim != null:
		_anim.pause()


## Freeze the skeleton at the LAST frame of a clip - e.g. the end of a death
## anim = a flat, lying pose. Used to spawn casualties already down, and as
## the launch pose for a calm (non-exploding) ragdoll.
func pose_end_of(clip: String) -> bool:
	if _anim == null or not _anim.has_animation(clip):
		return false
	_anim.play(clip)
	_anim.seek(maxf(0.0, _anim.get_animation(clip).length - 0.01), true)
	_anim.pause()
	_current_clip = clip
	return true


## Park a live ragdoll (stop solving; pose stays). wake_ragdoll() resumes.
func sleep_ragdoll() -> void:
	if _ragdoll_sim != null and _ragdoll_sim.is_simulating_physics():
		_ragdoll_sim.physical_bones_stop_simulation()


# ---- ragdoll (research/ragdoll.md: shared 13-bone physical skeleton) --------
## One authored PhysicalBoneSimulator3D scene fits every Mixamo rig. Mode A:
## stop the clip, start the sim on the current pose, shove the spine. Capped
## globally so a grenade killing a squad can't spike the solver; corpses stop
## simulating after a settle window and sleep as static bodies.
const RAGDOLL_SCENE_PATH := "res://scenes/characters/ragdoll_mixamo.tscn"
const MAX_ACTIVE_RAGDOLLS: int = 8
const RAGDOLL_SETTLE_S: float = 4.0
static var _active_ragdolls: int = 0
var _ragdoll_sim: PhysicalBoneSimulator3D = null


func has_ragdoll() -> bool:
	return _ragdoll_sim != null


func start_ragdoll(impulse_dir: Vector3, force: float = 8.0) -> bool:
	if _skel == null or _ragdoll_sim != null:
		return false
	if _active_ragdolls >= MAX_ACTIVE_RAGDOLLS:
		return false
	if not ResourceLoader.exists(RAGDOLL_SCENE_PATH):
		return false
	stop_anim()  # research 3, Mode A: the clip must stop driving bone poses
	var sim := (load(RAGDOLL_SCENE_PATH) as PackedScene).instantiate() as PhysicalBoneSimulator3D
	_skel.add_child(sim)
	_ragdoll_sim = sim
	# A corpse must not collide with ITSELF: joints only exclude adjacent
	# pairs, so overlapping non-adjacent capsules (stacked spine, arm-vs-torso)
	# de-penetrate violently every frame = the flailing/flying bug. Full
	# mutual exception = calm body; limbs may clip the torso (fine at PSX).
	var bones: Array = []
	for c in sim.get_children():
		if c is PhysicalBone3D:
			bones.append(c)
	for i in range(bones.size()):
		for j in range(i + 1, bones.size()):
			(bones[i] as PhysicalBone3D).add_collision_exception_with(bones[j] as PhysicalBone3D)
	# severed-bone modifier must stay LAST so dismembered parts survive the sim
	var sever_mod: Node = _skel.find_child("SeveredBones", false, false)
	if sever_mod != null:
		_skel.move_child(sever_mod, _skel.get_child_count() - 1)
	sim.physical_bones_start_simulation()  # start FIRST, then impulse (same frame)
	var spine := sim.find_child("Spine2", true, false) as PhysicalBone3D
	if spine == null:
		spine = sim.find_child("Hips", true, false) as PhysicalBone3D
	if spine != null:
		spine.apply_central_impulse(impulse_dir.normalized() * force + Vector3.UP * 1.5)
	_active_ragdolls += 1
	tree_exited.connect(_release_ragdoll_slot)
	var settle: SceneTreeTimer = get_tree().create_timer(RAGDOLL_SETTLE_S)
	settle.timeout.connect(func() -> void:
		if is_instance_valid(sim) and sim.is_simulating_physics():
			sim.physical_bones_stop_simulation())
	return true


func _release_ragdoll_slot() -> void:
	if _ragdoll_sim != null:
		_active_ragdolls = maxi(0, _active_ragdolls - 1)
		_ragdoll_sim = null


## A named PhysicalBone3D from the live ragdoll ("Hips", "Spine2"...) - the
## drag mechanic grabs these.
func ragdoll_bone(bone: String) -> PhysicalBone3D:
	if _ragdoll_sim == null:
		return null
	return _ragdoll_sim.find_child(bone, true, false) as PhysicalBone3D


## Re-wake a settled ragdoll (the settle-stop parks corpses; grabbing one
## needs the solver running again).
func wake_ragdoll() -> void:
	if _ragdoll_sim != null and not _ragdoll_sim.is_simulating_physics():
		_ragdoll_sim.physical_bones_start_simulation()


## World-space forward. The body is rotated to face it (unlike the billboard
## sprite, a 3D model must actually turn).
func set_facing(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		_facing = flat.normalized()
		# Model authored facing -Z (Godot forward); rotate so -Z aligns to facing.
		rotation.y = atan2(_facing.x, _facing.z)


## Play a clip by the intent-resolved name. No-ops if already playing it.
func play(clip: String, restart: bool = false) -> bool:
	if _anim == null:
		return false
	if clip == _current_clip and not restart:
		return true
	if not _anim.has_animation(clip):
		return false
	_current_clip = clip
	_anim.play(clip)
	return true


## Parity with SpriteActor for code + tests that read the playing clip.
var current_action: String:
	get: return _current_clip


func has_clip(clip: String) -> bool:
	return _anim != null and _anim.has_animation(clip)


## Hit flash - tint every material briefly. (Sprite used modulate; a lit model
## uses an emission bump so it reads in shade.)
func flash(color: Color, seconds: float = 0.1) -> void:
	if _inst == null:
		return
	if _flash_mats.is_empty():
		for n in _walk(_inst):
			var mi := n as MeshInstance3D
			if mi == null:
				continue
			for si in range(mi.get_surface_override_material_count()):
				var m := mi.get_active_material(si)
				if m is StandardMaterial3D:
					_flash_mats.append(m as StandardMaterial3D)
	for m in _flash_mats:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g * 0.3, color.b * 0.3)
		m.emission_energy_multiplier = 1.5
	_flash_until = seconds


func set_base_modulate(_c: Color) -> void:
	pass  # models carry their own textures; surrender/state tints are optional later


func _process(delta: float) -> void:
	if _flash_until > 0.0:
		_flash_until -= delta
		if _flash_until <= 0.0:
			for m in _flash_mats:
				m.emission_enabled = false


# ---- muzzle: models have a real hand bone, so this can be exact later --------
## For now, mirror the sprite's camera-independent ballistic origin so gunplay
## is identical across renderers. When the weapon socket / MuzzlePoint is wired
## on the rig, override this with the bone transform.
func muzzle_ballistic(flat_aim: Vector3, forward_bias: float = 0.55) -> Vector3:
	return global_position + Vector3.UP * 1.35 + flat_aim * forward_bias


func muzzle_visual() -> Vector3:
	return global_position + Vector3.UP * 1.35 + _facing * 0.4


## Instance-space AABB of the model, ALL transforms accumulated from `root`
## down (armature/export-compensation scale included; root's own transform
## excluded, since that is what setup() rescales). Measuring raw mesh-space
## AABBs here was the speck-soldier bug (n2ij / ADR-002): a rig exported with
## FBX-style compensation reports a 60m mesh box on a ~1.9m model, so the
## normaliser shrank correct characters 30x. Guarded by test_model_scale.
func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var n: Node = entry[0]
		var xf: Transform3D = entry[1]
		var n3 := n as Node3D
		var here: Transform3D = xf
		if n3 != null and n != root:
			here = xf * n3.transform
		for c in n.get_children():
			stack.push_back([c, here])
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var a: AABB = here * mi.get_aabb()
			if first:
				out = a
				first = false
			else:
				out = out.merge(a)
	return out


func _walk(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
