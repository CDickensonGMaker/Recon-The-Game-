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
## Bind-to-rest size ratio: gib donor meshes store BIND-space verts while the
## man renders at REST scale - GibSystem scales spawned pieces by this so a
## popped forearm matches the arm it came off. 1.0 on healthy exports.
var gib_scale: float = 1.0
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

	_anim = _inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skel = _inst.find_child("Skeleton3D", true, false) as Skeleton3D
	_normalize_height()
	_merge_shared_library()
	_apply_loop_modes()
	_apply_gib_rig_contract()
	_apply_psx_filtering()
	return true


## Height normalization (ADR-002): the RENDERED man must stand exactly
## TARGET_HEIGHT_M with his soles on this node's origin. Skinned verts render
## pulled to the REST skeleton, so the skeleton is the only honest ruler - the
## mesh AABB measures the BIND pose, which the current exports bake ~2x larger
## and offset from rest (every man rendered 0.84m tall floating 0.82m up).
## AABB remains the fallback for rigless props.
func _normalize_height() -> void:
	if _inst == null:
		return
	if _skel != null:
		var top: int = _skel.find_bone("mixamorig_HeadTop_End")
		var toe: int = _skel.find_bone("mixamorig_LeftToeBase")
		if toe < 0:
			toe = _skel.find_bone("mixamorig_LeftFoot")
		if top >= 0 and toe >= 0:
			# Skeleton -> _inst space via LOCAL transforms (global transforms
			# race on the session's first build).
			var to_inst := Transform3D.IDENTITY
			var n: Node3D = _skel
			while n != null and n != _inst:
				to_inst = n.transform * to_inst
				n = n.get_parent() as Node3D
			var top_y: float = (to_inst * _skel.get_bone_global_rest(top).origin).y
			var toe_y: float = (to_inst * _skel.get_bone_global_rest(toe).origin).y
			if top_y - toe_y > 0.01:
				var k: float = TARGET_HEIGHT_M / (top_y - toe_y)
				norm_k = k
				var bind_aabb := _aabb_of(_inst)
				if bind_aabb.size.y > 0.01:
					gib_scale = clampf((top_y - toe_y) / bind_aabb.size.y, 0.05, 1.0)
				_inst.scale = Vector3(k, k, k)
				_inst.position.y = -toe_y * k
				print("[MODEL] %s rest-span %.2f k=%.3f gib_scale=%.2f (skeleton-ruled height; bind AABB lies on off-spec exports)" % [unit, top_y - toe_y, k, gib_scale])
				return
	var aabb := _aabb_of(_inst)
	if aabb.size.y > 0.01:
		var k2: float = TARGET_HEIGHT_M / aabb.size.y
		norm_k = k2
		_inst.scale = Vector3(k2, k2, k2)
		_inst.position.y = -aabb.position.y * k2
		print("[MODEL] %s instance_h=%.2f k=%.3f (AABB fallback - no usable rig)" % [unit, aabb.size.y, k2])


## ---- shared animation library (bead 00qp) -----------------------------------
## anim_library.glb carries every clip ONCE (91); character exports go mesh-only
## (EXPORT_ANIMATIONS=False in the exporters) and borrow them here, so a
## character re-export takes seconds instead of 11 minutes and anim fixes
## propagate to the whole roster from one file.
##
## THE NAME IS A CONTRACT: both exporters keep the armature node named "PSXRig",
## so every library track resolves as PSXRig/Skeleton3D:mixamorig_* on every
## character. Rename the rig in either export script and the entire library
## goes silent (T-pose).
const ANIM_LIBRARY_PATH := MODEL_DIR + "anim_library.glb"
static var _shared_lib: AnimationLibrary = null
static var _shared_lib_tried: bool = false


static func _load_shared_library() -> AnimationLibrary:
	if _shared_lib != null or _shared_lib_tried:
		return _shared_lib
	_shared_lib_tried = true
	if not ResourceLoader.exists(ANIM_LIBRARY_PATH):
		push_warning("[MODEL] anim_library.glb missing - mesh-only characters will T-pose")
		return null
	var packed: PackedScene = load(ANIM_LIBRARY_PATH)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation_library(""):
		# AnimationLibrary is a refcounted Resource - it outlives the instance
		_shared_lib = ap.get_animation_library("")
	inst.free()
	return _shared_lib


## Merge, don't replace: clips baked into the character GLB win; the library
## fills every gap. Transition-era exports (73 baked clips) and mesh-only
## exports (no AnimationPlayer at all) both come out with the full clip set.
## MUST run before _apply_loop_modes() so borrowed idles loop too - otherwise
## they freeze on their last frame and read as T-pose.
func _merge_shared_library() -> void:
	var lib: AnimationLibrary = ModelActor._load_shared_library()
	if lib == null or _inst == null:
		return
	# PSXRig contract guard: v1-era rigs (Mixamo node names) would accept the
	# merged clips but their track paths resolve to NOTHING - playing a merged
	# clip on them freezes the pose. Only merge where the paths can land.
	if _inst.get_node_or_null("PSXRig/Skeleton3D") == null:
		return
	if _anim == null:
		if _skel == null:
			return  # not a character rig - nothing to animate
		# Mesh-only export: create the player in the exporters' layout
		# (beside PSXRig, root_node "..") so library track paths resolve.
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		_inst.add_child(_anim)
		_anim.root_node = NodePath("..")
	var own: AnimationLibrary
	if _anim.has_animation_library(""):
		own = _anim.get_animation_library("")
	else:
		own = AnimationLibrary.new()
		_anim.add_animation_library("", own)
	var added: int = 0
	for key in lib.get_animation_list():
		if not own.has_animation(key):
			own.add_animation(key, lib.get_animation(key))
			added += 1
	if added > 0:
		print("[MODEL] %s: +%d clips from shared anim library" % [unit, added])


## PSX crunch: Godot re-imports GLB textures bilinear regardless of Blender's
## nearest setting - faces render smeared without this. Same convention as
## ground_clutter.gd / sprite_actor.gd.
func _apply_psx_filtering() -> void:
	if _inst == null:
		return
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat != null:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


## glTF carries NO loop flag, so every imported clip is play-once: an idle
## plays ~2s then FREEZES on its last frame - which reads as a T-pose/statue.
## Mark the cyclic clips looping at load. One-shots (deaths, jumps, turns,
## transitions) stay play-once.
const _LOOP_PREFIXES: Array[String] = ["idle", "run", "walk", "sprint", "strafe", "swim", "firing"]
## T1.1: cyclic clips whose names the prefix heuristic misses. These are wired
## to PERSISTENT intents (retreat/crippled/cover/surrender) - play-once meant
## a retreating man froze mid-stride and slid: THE gliding statue.
## laying_breathless stays one-shot deliberately.
## sitting/cockpit_idle: seated Huey occupants (SeatSystem §7) - play-once froze
## them into statues after ~2s; looping gives the idle sway for free.
const _LOOP_NAMES: Array[String] = ["injured_walk_backwards", "kneeling_pointing",
	"sitting", "cockpit_idle"]

func _apply_loop_modes() -> void:
	if _anim == null:
		return
	for clip_name in _anim.get_animation_list():
		var nm := String(clip_name)
		if nm in _LOOP_NAMES:
			var a_named: Animation = _anim.get_animation(clip_name)
			if a_named != null:
				a_named.loop_mode = Animation.LOOP_LINEAR
			continue
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
	# Trigger: donors present AND a live body to render instead. The body is
	# either a *_joined mesh (us_grunt_v2) or vc_*-style part meshes (any
	# non-donor, non-cap mesh) - the VC exports ship parts, not a joined body
	# (bead i3b0: requiring _joined left VC donors doubled inside the body).
	var has_body: bool = false
	var has_donors: bool = false
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var mesh_name := String(mi.name)
		if mesh_name.ends_with("_joined"):
			has_body = true
		elif mesh_name.begins_with("grunt_") or mesh_name.begins_with("head_frag_"):
			has_donors = true
		elif not mesh_name.begins_with("cap_"):
			has_body = true
	if not (has_body and has_donors):
		return
	var hidden: int = 0
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nm := String(mi.name)
		# Caps hide too: they are wound cross-sections (dark meat discs) that
		# GibSystem.dismember reveals on the pop. Left visible, any cap the
		# export skinned off-joint renders as floating gore beside the living
		# man (the VC "floating gib pieces" bug).
		if (nm.begins_with("grunt_") or nm.begins_with("head_frag_") or nm.begins_with("cap_")) \
				and not nm.ends_with("_joined"):
			mi.visible = false
			hidden += 1
	if hidden > 0:
		print("[MODEL] %s: hid %d gib-donor/cap meshes (gib-rig contract; live body renders)" % [unit, hidden])


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


## Play the first clip this rig actually has (rigs differ: v1 grunt carries
## stand_to_cover, v2 the crouch set). Returns the clip played, or "".
func play_first(clips: Array[String], restart: bool = false) -> String:
	for c in clips:
		if play(c, restart):
			return c
	return ""


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


## World-space forward. ONE yaw owner (war room AI decree): this sets GLOBAL
## yaw, so it is correct regardless of what the parent body's look_at did -
## the old LOCAL yaw compounded with the body rotation and read ~180 degrees
## wrong on enemies (they fight toward +Z; allies toward -Z masked it).
func set_facing(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() <= 0.0001:
		return
	_facing = flat.normalized()
	var target_yaw: float = atan2(_facing.x, _facing.z)
	if not _facing_init:
		_facing_init = true
		global_rotation.y = target_yaw
		return
	# T1.2 (smoothness plan): frame-rate-independent damped turn. The facing
	# SOURCE switches discontinuously (aim lerp <-> raw nav step <-> stale
	# aim) - smoothing at the single yaw owner kills every 180-degree
	# single-frame body whip at once. k=12: fast but visible.
	var dt: float = get_physics_process_delta_time()
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, 1.0 - exp(-12.0 * dt))

var _facing_init: bool = false


## Play a clip by the intent-resolved name. No-ops if already playing it.
## Missing clips resolve through SpriteStateMap.MODEL_ALIASES (v1/v2 rigs
## carry different clip generations - callers ask in either, every rig answers).
func play(clip: String, restart: bool = false) -> bool:
	if _anim == null:
		return false
	if clip == _current_clip and not restart:
		return true
	if not _anim.has_animation(clip):
		# Weapon-family hold ("firing_rifle__smg"): strip the suffix and fall
		# back to the base clip until Batch 7 authors the family variant.
		if clip.contains("__"):
			clip = clip.split("__")[0]
			if clip == _current_clip and not restart:
				return true
	if not _anim.has_animation(clip):
		for alias in SpriteStateMap.MODEL_ALIASES.get(clip, []):
			if _anim.has_animation(str(alias)):
				clip = str(alias)
				break
		if not _anim.has_animation(clip):
			return false
		if clip == _current_clip and not restart:
			return true
	_current_clip = clip
	# T1.7: preserve cycle phase across loop->loop switches (walk->run->strafe)
	# so feet stay on the same beat instead of teleporting to frame 0 under
	# the blend. One-shots and loop->one-shot start at 0 as authored.
	var from_loop: bool = _anim.current_animation != "" and _clip_loops(_anim.current_animation)
	var old_pos: float = _anim.current_animation_position if from_loop else 0.0
	var old_len: float = _anim.current_animation_length if from_loop else 0.0
	# 0.18s crossfade: hard cuts between clips read as pops/odd transitions
	# (Caleb). Deaths/one-shots blend in too - it only smooths the seam.
	_anim.play(clip, 0.18)
	if from_loop and old_len > 0.01 and _clip_loops(clip):
		var new_len: float = _anim.get_animation(clip).length
		if new_len > 0.01:
			_anim.seek(fposmod(old_pos / old_len, 1.0) * new_len, false)
	return true


func _clip_loops(clip: String) -> bool:
	var a: Animation = _anim.get_animation(clip)
	return a != null and a.loop_mode == Animation.LOOP_LINEAR


## Length in seconds of a clip (alias-resolved); 0.0 if the rig lacks it.
## Used to size override windows (ally cover leap) from the actual clip.
func clip_length(clip: String) -> float:
	if _anim == null:
		return 0.0
	if not _anim.has_animation(clip):
		for alias in SpriteStateMap.MODEL_ALIASES.get(clip, []):
			if _anim.has_animation(str(alias)):
				clip = str(alias)
				break
	if not _anim.has_animation(clip):
		return 0.0
	return _anim.get_animation(clip).length


## Authored ground speeds (m/s) per locomotion loop - starting nominals from
## the smoothness plan, retune from the bench eyeball pass.
const _CLIP_SPEED: Dictionary = {
	"run_forward": 4.2, "run_forward_left": 4.0, "run_forward_right": 4.0,
	"run_left": 2.8, "run_right": 2.8,
	"run_backward": 2.4, "run_backward_left": 2.4, "run_backward_right": 2.4,
	"sprint_forward": 5.5, "strafe": 2.5, "strafe_1": 2.5, "strafe_2": 2.5,
	"walk_forward": 1.6, "walk_left": 1.4, "walk_right": 1.4,
	"walk_backward": 1.3, "start_walking": 1.6,
	"injured_walk_backwards": 1.2,
}


## T1.6 (highest-leverage smoothness fix): match playback rate to actual
## ground speed so feet plant instead of skating - combat/patrol movement
## runs at 0.5-0.6x move_speed and previously played every cycle at 1.0x.
## Non-locomotion clips reset to authored rate.
func set_locomotion_speed(mps: float) -> void:
	if _anim == null:
		return
	var ref: float = float(_CLIP_SPEED.get(_current_clip, 0.0))
	if ref > 0.0:
		_anim.speed_scale = clampf(mps / ref, 0.6, 1.4)
	else:
		_anim.speed_scale = 1.0


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
