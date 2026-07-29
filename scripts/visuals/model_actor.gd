## model_actor.gd - rigged 3D character, the default renderer.
##
## The one character visual (ADR-001): setup/play/set_facing/flash/muzzle_*.
## EnemyBase and AllyBase swap one for the other with no other change - keep the
## two interfaces in step.
class_name ModelActor
extends Node3D

## One characters folder per faction. A unit_id is unique across all of them, so
## resolution is a search - and model_path() is the ONLY sanctioned unit_id ->
## .glb path. Hardcode a character path elsewhere and the next faction re-org
## silently breaks it.
const MODEL_DIRS: Array[String] = [
	"res://assets/us/characters/",
	"res://assets/nva_vc/characters/",
	"res://assets/civilians/characters/",
]
const TARGET_HEIGHT_M: float = 1.7132   ## metres; ADR-002 scale contract (== manifests' character_height_m)


## The .glb for a unit_id, or "" if no faction folder holds one.
static func model_path(unit_id: String) -> String:
	if unit_id.is_empty():
		return ""
	for d in MODEL_DIRS:
		var p: String = d + unit_id + ".glb"
		if ResourceLoader.exists(p):
			return p
	return ""


## Every character unit_id on disk, across all factions. anim_library is not a
## character - it is the shared clip bank - so it never appears here.
static func all_units() -> Array[String]:
	var out: Array[String] = []
	for d in MODEL_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".glb") and not f.begins_with("anim_library"):
				out.append(f.trim_suffix(".glb"))
	return out

## Per-unit authored height, in METRES. A combatant is 1.7132 to the helmet top
## (ADR-002 / production/GAME_SCALE_STANDARD.md) and needs no entry here.
##
## A non-combatant MUST have an entry: _normalize_height() rescales EVERY skeleton
## to its target, so without one a child is not a child - he is a 1.71m adult
## wearing a child's mesh, and a stooped elder stands up straight.
const UNIT_HEIGHT_M: Dictionary = {
	"civ_farmer_m": 1.62, "civ_farmer_m_b": 1.60, "civ_farmer_m_c": 1.65,
	"civ_farmer_f": 1.52, "civ_farmer_f_b": 1.50, "civ_farmer_f_c": 1.55,
	"civ_elder":    1.55, "civ_elder_b":    1.53,
	"civ_kid":      1.26, "civ_kid_b":      1.30,
	# Aircrew keep the combatant standard - the flight helmet is the top of the
	# silhouette, exactly like a steel pot.
	"us_pilot_white": 1.7132, "us_pilot_black": 1.7132,
}


## Flinches are theater, not simulation: past this many at once the cheapest thing
## to drop is the one nobody is looking at. The gate is perceivability, never the
## body gate - a man who was just shot is in COMBAT, which holds that gate open.
const MAX_CONCURRENT_FLINCH: int = 8
static var _live_flinches: int = 0

var _flinch: FlinchModifier = null


## Shove the spine away from a round that did not kill him. No-op off-camera.
func flinch(world_dir: Vector3, strength: float) -> void:
	if _skel == null:
		return
	if _flinch == null:
		if _live_flinches >= MAX_CONCURRENT_FLINCH:
			return
		if not CombatManager.perceivable(self):
			return
		_flinch = FlinchModifier.new()
		_skel.add_child(_flinch)
		_live_flinches += 1
	var local: Vector3 = global_transform.basis.inverse() * world_dir
	_flinch.punch(local.normalized(), strength)


func _exit_tree() -> void:
	if _flinch != null:
		_live_flinches -= 1
		_flinch = null


## The height THIS unit was authored to. Unknown unit -> the roster standard, so
## adding a model never silently changes its scale.
static func target_height(unit_id: String) -> float:
	return float(UNIT_HEIGHT_M.get(unit_id, TARGET_HEIGHT_M))


var unit: String = ""
## Bind-to-rest size ratio: gib donor meshes store BIND-space verts while the man
## renders at REST scale, so GibSystem scales spawned pieces by this to make a
## popped forearm match the arm it came off. 1.0 on healthy exports.
var gib_scale: float = 1.0
var _inst: Node3D = null
var _anim: AnimationPlayer = null
var _skel: Skeleton3D = null
var _current_clip: String = ""
var _facing: Vector3 = Vector3.FORWARD


static func model_exists(unit_id: String) -> bool:
	return not ModelActor.model_path(unit_id).is_empty()


## Returns false if the unit has no .glb - caller falls back to the capsule.
func setup(unit_id: String) -> bool:
	unit = unit_id
	if not ModelActor.model_exists(unit_id):
		return false
	var packed: PackedScene = load(ModelActor.model_path(unit_id))
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
	_apply_optional_gear()
	_hide_export_duplicates()
	_apply_untextured_gear_tints()
	_apply_psx_filtering()
	return true


## Canvas gear that ships with NO albedo texture renders at its raw albedo, and
## these materials were authored white - a white bandolier on an olive-drab man.
## Every other canvas strap on the rig samples a *_canvas_od texture and is right.
##
## Materials are SHARED across every instance of a unit, so tinting in place
## would repaint every grunt on the map; the corrected material is cached per
## material name and applied as a surface override.
##
## This is a code patch over an art defect authored in gear_armory.blend. When the
## .blend is corrected the materials arrive textured, `_needs_tint` stops matching,
## and this whole path becomes dead code to delete.
const _GEAR_TINTS: Dictionary = {
	"bandolier_tex": Color(0.196, 0.212, 0.145),
}

static var _tint_cache: Dictionary = {}


func _apply_untextured_gear_tints() -> void:
	if _inst == null:
		return
	for mi in _all_mesh_instances(_inst):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var bm := mesh.surface_get_material(s) as BaseMaterial3D
			if bm == null or not _GEAR_TINTS.has(bm.resource_name):
				continue
			if bm.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) != null:
				continue
			var key: String = bm.resource_name
			if not _tint_cache.has(key):
				var fixed := bm.duplicate() as BaseMaterial3D
				fixed.albedo_color = _GEAR_TINTS[key]
				_tint_cache[key] = fixed
			mi.set_surface_override_material(s, _tint_cache[key])


## Height normalization (ADR-002): the RENDERED man must stand exactly
## TARGET_HEIGHT_M with his soles on this node's origin. Skinned verts render
## pulled to the REST skeleton, so the skeleton is the only honest ruler - the
## mesh AABB measures the BIND pose. AABB stays the fallback for rigless props.
func _normalize_height() -> void:
	if _inst == null:
		return
	var target: float = target_height(unit)     # 1.7132 for every combatant
	if _skel != null:
		var top: int = _skel.find_bone("mixamorig_HeadTop_End")
		var toe: int = _skel.find_bone("mixamorig_LeftToeBase")
		if toe < 0:
			toe = _skel.find_bone("mixamorig_LeftFoot")
		if top >= 0 and toe >= 0:
			# Skeleton -> _inst space via LOCAL transforms: the global
			# transform is stale on the session's first build.
			var to_inst := Transform3D.IDENTITY
			var n: Node3D = _skel
			while n != null and n != _inst:
				to_inst = n.transform * to_inst
				n = n.get_parent() as Node3D
			var top_y: float = (to_inst * _skel.get_bone_global_rest(top).origin).y
			var toe_y: float = (to_inst * _skel.get_bone_global_rest(toe).origin).y
			if top_y - toe_y > 0.01:
				var k: float = target / (top_y - toe_y)
				var bind_aabb := _aabb_of(_inst)
				if bind_aabb.size.y > 0.01:
					gib_scale = clampf((top_y - toe_y) / bind_aabb.size.y, 0.05, 1.0)
				_inst.scale = Vector3(k, k, k)
				_inst.position.y = -toe_y * k
				print("[MODEL] %s rest-span %.2f k=%.3f gib_scale=%.2f -> %.2fm (skeleton-ruled height; bind AABB lies on off-spec exports)" % [unit, top_y - toe_y, k, gib_scale, target])
				return
	var aabb := _aabb_of(_inst)
	if aabb.size.y > 0.01:
		var k2: float = target / aabb.size.y
		_inst.scale = Vector3(k2, k2, k2)
		_inst.position.y = -aabb.position.y * k2
		print("[MODEL] %s instance_h=%.2f k=%.3f (AABB fallback - no usable rig)" % [unit, aabb.size.y, k2])


## ---- shared animation library -----------------------------------------------
## anim_library.glb carries every clip ONCE; character exports are mesh-only
## (EXPORT_ANIMATIONS=False in the exporters) and borrow them here.
##
## THE RIG NAME IS A CONTRACT: both exporters keep the armature node named
## "PSXRig", so every library track resolves as PSXRig/Skeleton3D:mixamorig_* on
## every character. Rename the rig in either export script and the entire library
## goes silent (T-pose).
const ANIM_LIBRARY_PATH := "res://assets/shared/anim_library.glb"
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


## Merge, don't replace: clips baked into the character GLB win, the library fills
## every gap. MUST run BEFORE _apply_loop_modes(), so borrowed idles get looped
## too - otherwise they freeze on their last frame and read as a T-pose.
func _merge_shared_library() -> void:
	var lib: AnimationLibrary = ModelActor._load_shared_library()
	if lib == null or _inst == null:
		return
	# PSXRig contract guard: a rig with other node names accepts the merged clips
	# but their track paths resolve to NOTHING, freezing the pose. Only merge
	# where the paths can land.
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


## PSX crunch: Godot re-imports GLB textures BILINEAR regardless of Blender's
## nearest setting - faces render smeared without this.
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


## glTF carries NO loop flag, so every imported clip arrives play-once and a
## cyclic clip FREEZES on its last frame (reads as a T-pose/statue). Mark the
## cyclic ones looping at load; one-shots (deaths, jumps, turns, transitions)
## stay play-once.
const _LOOP_PREFIXES: Array[String] = ["idle", "run", "walk", "sprint", "strafe", "swim", "firing"]
## Cyclic clips the prefix heuristic misses. All are wired to PERSISTENT intents
## (retreat/crippled/cover/surrender/seated), so play-once would freeze them
## mid-stride. laying_breathless stays one-shot deliberately.
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


## Gib-rig contract: the *_joined mesh (or, on part-based exports, the part
## meshes) is the LIVE body; the pre-cut region meshes (grunt_*) are GIB DONORS,
## viewport-hidden in Blender. Blender viewport-hide does NOT survive glTF export,
## so both arrive visible - the double-render / "multi arms" bug. Godot re-applies
## the intent: donors hidden, body renders. Dismemberment collapses the bone chain
## and spawns the hidden donor as the flying gib. Non-contract rigs: no-op.
## The PRC-25 ships inside the rifleman and pointman GLBs so GruntDresser can promote
## either to radioman at spawn - but it must NOT render unless he is one. Fire support
## is RTO-gated (ADR-011): if every man visibly wears a radio, the player cannot pick
## out the RTO to kill him and the gate is unenforceable.
const OPTIONAL_GEAR_PREFIXES: Array[String] = ["prc25_"]

## Carries it with no dresser call.
const CARRIES_RADIO: Array[String] = ["us_grunt_rto"]

## No PRC-25 in their mesh at all (tools/export_us_squad.py NO_RADIO), so promoting
## one of these to radioman would silently do nothing. GruntDresser refuses instead.
const RADIO_FORBIDDEN: Array[String] = [
	"us_grunt_marksman", "us_grunt_mg", "us_grunt_grenadier",
]


## Hide opt-in gear on anyone not issued it. GruntDresser can switch it back on.
func _apply_optional_gear() -> void:
	if _inst == null or unit in CARRIES_RADIO:
		return
	var hidden: int = 0
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		for p: String in OPTIONAL_GEAR_PREFIXES:
			if String(mi.name).begins_with(p):
				mi.visible = false
				hidden += 1
				break
	if hidden > 0:
		print("[MODEL] %s: hid %d opt-in gear meshes (not the radioman)" % [unit, hidden])


## Some exports ship with both a worn live mesh and its donor/constituent parts
## visible at once, or with numbered duplicates (canteen_l.002 .. .006). Hide the
## leftovers so finished Blender work renders correctly while the exporter is
## tightened. This only touches meshes whose names match the known bad patterns.
const _GEAR_DONOR_PARTS: Dictionary = {
	"bandolier_worn": ["bandolier", "bando_mag0", "bando_mag1", "bando_mag2"],
	"ruck_pack_worn": ["ruck_bag", "ruck_crossbar", "ruck_rail_l", "ruck_rail_r"],
}


func _hide_export_duplicates() -> void:
	if _inst == null:
		return
	var all := _all_mesh_instances(_inst)
	var by_name: Dictionary = {}
	for mi in all:
		by_name[mi.name] = mi

	var hidden: int = 0

	# 1. If a *_worn mesh exists, hide its plain/donor counterparts.
	for worn_name: String in _GEAR_DONOR_PARTS.keys():
		if not by_name.has(worn_name):
			continue
		for donor_name: String in _GEAR_DONOR_PARTS[worn_name]:
			if by_name.has(donor_name):
				(by_name[donor_name] as MeshInstance3D).visible = false
				hidden += 1

	# 2. Collapse numbered duplicates (canteen_l.002, canteen_l.003, ...): keep the
	# lowest suffix, hide the rest. This is a common exporter-side duplicate name.
	var numbered: Dictionary = {}
	var re_num := RegEx.new()
	re_num.compile(r"^(.+)\.(\d+)$")
	for n: String in by_name.keys():
		var m := re_num.search(n)
		if m == null:
			continue
		var base: String = m.get_string(1)
		var suffix: int = int(m.get_string(2))
		if not numbered.has(base):
			numbered[base] = {}
		numbered[base][suffix] = by_name[n]
	for base: String in numbered.keys():
		var by_suffix: Dictionary = numbered[base]
		var suffixes: Array = by_suffix.keys()
		suffixes.sort()
		for i in range(1, suffixes.size()):
			(by_suffix[suffixes[i]] as MeshInstance3D).visible = false
			hidden += 1

	if hidden > 0:
		print("[MODEL] %s: hid %d duplicate gear meshes (export cleanup)" % [unit, hidden])


func _all_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in _walk(root):
		var mi := n as MeshInstance3D
		if mi != null:
			out.append(mi)
	return out


func _apply_gib_rig_contract() -> void:
	if _inst == null:
		return
	# Trigger: donors present AND a live body to render instead. The body is
	# either a *_joined mesh or part meshes (any non-donor, non-cap mesh) - not
	# every export ships a joined body.
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
	# Every mesh GibSystem throws as gear is ALSO a donor and must not render on the
	# living man. helmet_camo_shell / helmet_bugjuice do not begin with grunt_ or
	# cap_, so they slipped this net and every grunt shipped wearing TWO helmets -
	# the real one and the donor stacked inside it. Read the names off the gib
	# contract rather than re-listing them here, so the two can never drift apart.
	var gib_gear: Dictionary = {}
	for region: String in GibSystem.REGIONS:
		for g: String in GibSystem.REGIONS[region].get("gear", []):
			gib_gear[String(g)] = true

	var hidden: int = 0
	for n in _walk(_inst):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nm := String(mi.name)
		# Caps hide too: they are wound cross-sections that GibSystem.dismember
		# reveals on the pop. Left visible, a cap the export skinned off-joint
		# renders as floating gore beside the living man.
		var is_donor: bool = (nm.begins_with("grunt_") or nm.begins_with("head_frag_")
				or nm.begins_with("cap_")) and not nm.ends_with("_joined")
		if is_donor or gib_gear.has(nm):
			mi.visible = false
			hidden += 1
	if hidden > 0:
		print("[MODEL] %s: hid %d gib-donor/cap/gear meshes (gib-rig contract; live body renders)" % [unit, hidden])


func has_visual() -> bool:
	return _inst != null


## Rig access for the gore system.
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


# ---- ragdoll ----------------------------------------------------------------
## One authored PhysicalBoneSimulator3D scene fits every Mixamo rig: stop the
## clip, start the sim on the current pose, shove the spine. Capped globally so a
## grenade killing a squad cannot spike the solver; corpses stop simulating after
## a settle window and sleep as static bodies.
const RAGDOLL_SCENE_PATH := "res://scenes/characters/ragdoll_mixamo.tscn"
## Summoner's ruling 2026-07-28: NO CAP. At 8 a 36-man firefight starved most
## clean kills of a ragdoll and left the corpses standing. The guard survives only
## to stop an unbounded solver count; put a real number back here if the frametime
## bill shows up in a fight.
const MAX_ACTIVE_RAGDOLLS: int = 256
const RAGDOLL_SETTLE_S: float = 4.0
## A man is 1.71m; anything still spanning this much vertical is on his feet.
const PRONE_SPAN_MAX: float = 1.2
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
	var sim := (load(RAGDOLL_SCENE_PATH) as PackedScene).instantiate() as PhysicalBoneSimulator3D
	_skel.add_child(sim)
	var bones: Array = []
	for c in sim.get_children():
		if c is PhysicalBone3D:
			bones.append(c)
	# PROVE the sim will drive THIS rig before committing. Its physical bones must
	# resolve to real skeleton bones; on a rig-generation bone-name mismatch none
	# bind, the sim never topples the body, and pausing the clip first would latch
	# the corpse UPRIGHT (the "staggering back" bug). If nothing binds, abort with
	# the clip STILL RUNNING so _die() falls back to a death clip / flat pose.
	var bound: int = 0
	for b in bones:
		var pb: PhysicalBone3D = b as PhysicalBone3D
		var bid: int = pb.get_bone_id()
		if bid == -1:
			bid = _skel.find_bone(pb.bone_name)
		if bid != -1:
			bound += 1
	if bones.size() > 0 and bound == 0:
		sim.queue_free()
		return false
	_ragdoll_sim = sim
	stop_anim()  # binding proven - stop the clip before the sim drives the pose
	# A corpse must not collide with ITSELF: joints only exclude ADJACENT pairs,
	# so overlapping non-adjacent capsules (stacked spine, arm-vs-torso)
	# de-penetrate violently every frame and the body flails. Full mutual
	# exception = calm body; limbs may clip the torso, which is fine at PSX.
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
	_ragdoll_slot_held = true
	tree_exited.connect(_release_ragdoll_slot)
	var settle: SceneTreeTimer = get_tree().create_timer(RAGDOLL_SETTLE_S)
	settle.timeout.connect(func() -> void:
		if is_instance_valid(sim) and sim.is_simulating_physics():
			sim.physical_bones_stop_simulation()
		# The cap gates CONCURRENT solvers, not parked corpses: a settled body
		# costs nothing, so its slot frees HERE, not when the corpse despawns.
		_release_ragdoll_slot())
	return true


var _ragdoll_slot_held: bool = false


func _release_ragdoll_slot() -> void:
	if _ragdoll_slot_held:
		_ragdoll_slot_held = false
		_active_ragdolls = maxi(0, _active_ragdolls - 1)


## Pin the CURRENT pose to the ground: shift the visual down so the lowest bone
## touches the body's floor plane. For clips authored off the floor (some death
## clips lie the man a metre in the air). Elevation-safe: measures against this
## node's own origin (the feet plane), NOT world zero.
func ground_current_pose() -> void:
	if _skel == null or _inst == null:
		return
	var base: float = global_position.y
	var lo: float = INF
	for bi in range(_skel.get_bone_count()):
		lo = minf(lo, (_skel.global_transform * _skel.get_bone_global_pose(bi).origin).y - base)
	if lo < INF and absf(lo) > 0.05:
		_inst.position.y -= lo - 0.02


## Guaranteed prone corpse for the NON-ragdoll death path: snap to the flat end
## frame of a death clip so a janky or latched clip can never leave a man standing
## or mid-stagger. Falls back to grounding whatever pose is showing. No-op while
## the body is ragdolling. (stuck-stagger fix)
func settle_flat_corpse() -> void:
	if _ragdoll_sim != null:
		return
	var posed: bool = false
	for c in clip_names():
		if String(c).begins_with("death") and pose_end_of(String(c)):
			posed = true
			break
	if not posed:
		stop_anim()
	ground_current_pose()
	# PROVE the man is down. A death clip whose last frame is not prone - a bad
	# retarget, a clip authored standing - left the corpse upright, and grounding
	# only moves a body DOWN, it never lays one over. So measure the pose: a
	# standing rig spans most of its own height, a prone one does not.
	if _pose_span_y() > PRONE_SPAN_MAX:
		_lay_flat()
		ground_current_pose()


## Vertical extent of the posed skeleton, in metres.
func _pose_span_y() -> float:
	if _skel == null:
		return 0.0
	var lo: float = INF
	var hi: float = -INF
	for bi in range(_skel.get_bone_count()):
		var y: float = (_skel.global_transform * _skel.get_bone_global_pose(bi).origin).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo if lo < INF else 0.0


## Topple the visual. Yaw is randomised so a line of men cut down together does
## not read as a row of identical dominoes.
func _lay_flat() -> void:
	if _inst == null:
		return
	_inst.rotation = Vector3(-PI * 0.5, randf_range(0.0, TAU), 0.0)


## Any death clip this rig can actually play (shared library included) - the
## last-resort death performance when the unit's mapped clip name is missing.
func play_any_death() -> bool:
	var deaths: Array[String] = []
	for c in clip_names():
		if String(c).begins_with("death"):
			deaths.append(String(c))
	if deaths.is_empty():
		return false
	return play(deaths[randi_range(0, deaths.size() - 1)], true)


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


## World-space forward. This is the ONE yaw owner, and it sets GLOBAL yaw - never
## local, which would compound with the parent body's own rotation.
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
	# Frame-rate-independent damped turn. The facing SOURCE switches
	# discontinuously (aim lerp <-> raw nav step <-> stale aim), so smoothing at
	# the single yaw owner kills every single-frame body whip at once.
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
		# Weapon-family clip ("firing_rifle__smg"): strip the suffix and fall
		# back to the base clip when the family variant is not authored.
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
	# Preserve cycle phase across loop->loop switches (walk->run->strafe) so feet
	# stay on the same beat instead of teleporting to frame 0 under the blend.
	# One-shots and loop->one-shot start at 0 as authored.
	var from_loop: bool = _anim.current_animation != "" and _clip_loops(_anim.current_animation)
	var old_pos: float = _anim.current_animation_position if from_loop else 0.0
	var old_len: float = _anim.current_animation_length if from_loop else 0.0
	# 0.18s crossfade - hard cuts between clips read as pops.
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


## Authored ground speed of each locomotion loop, in METRES PER SECOND.
const _CLIP_SPEED: Dictionary = {
	"run_forward": 4.2, "run_forward_left": 4.0, "run_forward_right": 4.0,
	"run_left": 2.8, "run_right": 2.8,
	"run_backward": 2.4, "run_backward_left": 2.4, "run_backward_right": 2.4,
	"sprint_forward": 5.5,
	"walk_forward": 1.6, "walk_left": 1.4, "walk_right": 1.4,
	"walk_backward": 1.3, "start_walking": 1.6,
	"injured_walk_backwards": 1.2,
	"walk_crouching_forward": 1.3, "walk_crouching_backward": 1.1,
	"walk_crouching_left": 1.1, "walk_crouching_right": 1.1,
}


## Match playback rate to the actual ground speed (mps, METRES PER SECOND) so
## feet plant instead of skating. Non-locomotion clips reset to authored rate.
func set_locomotion_speed(mps: float) -> void:
	if _anim == null:
		return
	var ref: float = float(_CLIP_SPEED.get(_current_clip, 0.0))
	if ref > 0.0:
		_anim.speed_scale = clampf(mps / ref, 0.6, 1.4)
	else:
		_anim.speed_scale = 1.0


## For code + tests that read the playing clip.
var current_action: String:
	get: return _current_clip


func has_clip(clip: String) -> bool:
	return _anim != null and _anim.has_animation(clip)


func set_base_modulate(_c: Color) -> void:
	pass  # models carry their own textures; surrender/state tints are optional later


# ---- muzzle -----------------------------------------------------------------
## A camera-independent ballistic origin, so gunplay is identical across
## renderers. Override with the bone transform once the rig has a weapon socket.
func muzzle_ballistic(flat_aim: Vector3, forward_bias: float = 0.55) -> Vector3:
	return global_position + Vector3.UP * 1.35 + flat_aim * forward_bias


func muzzle_visual() -> Vector3:
	return global_position + Vector3.UP * 1.35 + _facing * 0.4


## Instance-space AABB of the model, ALL transforms accumulated from `root` down
## (armature/export-compensation scale included; root's own transform excluded,
## since that is what setup() rescales). Raw mesh-space AABBs are NOT usable here:
## an FBX-compensated rig reports a 60m mesh box on a ~1.9m model. ADR-002,
## guarded by test_model_scale.
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
