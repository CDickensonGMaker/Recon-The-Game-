## vc_nva_dresser.gd - turns the exported NVA/VC men into a force that does not repeat.
##
## Deliberately the same shape as GruntDresser and ZombieDresser so the three read as
## one system: the head and hands sit inside ONE cell of the face sheet, so sliding
## that material's `uv1_offset` by one cell deals a different man.
##
##     faces x bodies x headgear x packs x chest rigs x belts x gear toggles
##
## THE ONE TRAP, inherited: `uv1_offset` is a MATERIAL property. Duplicate it per
## instance or every soldier on screen rerolls to the same face at once.
##
## FACE POOL. GruntDresser hardcodes US_FACES and that list has already had to be
## hand-corrected once; ZombieDresser's header calls deriving it from the builder the
## fix. This follows the zombie: the pool comes from vc_nva_manifest.json, emitted by
## tools/make_vc_nva_manifest.py. The NVA pool is male; the VC pool is a deliberate mix
## of women and men (Summoner ruling 2026-08-07).
##
## SKIN RIDES THE ATLAS, as on the grunt: face and hands are the same pixels, so a face
## can never land on a mismatched body. That invariant is matched on TEXTURE IDENTITY,
## not material name - the name is what drifted on the US side and stranded a black face
## on a white body.
class_name VcNvaDresser
extends RefCounted

## Grid of the VC/NVA face sheet. These are DEFAULTS: the manifest's atlas_cols /
## atlas_rows win, because the sheet is art and changes without touching this file.
## fixed_better_viet_faces.jpg is 10x3 - a 7-row assumption samples a third of a
## cell and every man wears a sliver of two faces.
const FACE_COLS: int = 10
const FACE_ROWS: int = 3

const MANIFEST: String = "res://assets/nva_vc/characters/vc_nva_manifest.json"

## Used only when the manifest is missing: the male cells of the 10x3 sheet, so a
## manifest-less run still deals a force of men rather than one repeated face.
const FALLBACK_FACES: Array[int] = [
	0, 1, 2, 4, 6, 7, 8,
	11, 12, 13, 15, 16, 18, 19,
	20, 21, 23, 24, 26, 27, 28,
]

const FACE_MATERIALS: Array[String] = ["face_atlas", "Skin_VC", "vc_face_skin"]

## The detachable gear library: headgear, packs, chest rigs and belts, one entry per
## variant. Read at RUNTIME so a new variant reaches the game with no code change here.
## Keys carrying a faction token (`_nva` / `_vc`) are gated to that faction - see _pick.
const GEAR_MANIFEST: String = "res://assets/nva_vc/props/nva_vc_gear.json"

## Headgear ships welded into each GLB - NVA wear the pith helmet, VC the rice hat.
## These are the names of THOSE meshes: the welded one comes off once the library
## variant is hung in its place.
const HEADGEAR: Array[String] = ["pith_helmet", "rice_hat"]

## Authored level. A section wearing one identical angle reads as a modelling error
## rather than as men. Pitch is biased backward, as on the steel pot.
const HEADGEAR_PITCH_DEG: Vector2 = Vector2(-8.0, 5.0)
const HEADGEAR_YAW_DEG: float = 6.0
const HEADGEAR_ROLL_DEG: float = 4.0

## One key -> every mesh it owns, so `pack: true` cannot hand a man a frame with no
## bedroll on it. These names are the CONTRACT the character builder must emit; a key
## whose meshes are absent from a body resolves to false in the returned loadout
## rather than lying about what he is carrying.
const GEAR_TOGGLES: Dictionary = {
	"pack":    ["pack_worn", "pack_roll"],
	"foliage": ["foliage_back", "foliage_headgear"],
}

## Vegetation camo is the faction's silhouette-breaker and should be common, not rare.
const FOLIAGE_CHANCE: float = 0.65
const PACK_CHANCE: float = 0.45

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false
static var _gear: Dictionary = {}
static var _gear_loaded: bool = false
static var _reported: Dictionary = {}


## The manifest, loaded once. Empty dictionary if it is missing - callers fall back
## to FALLBACK_FACES rather than refusing to spawn.
static func manifest() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	if not ResourceLoader.exists(MANIFEST) and not FileAccess.file_exists(MANIFEST):
		_report_once(MANIFEST, "[VCNVA] no %s - the force draws FALLBACK_FACES only" % MANIFEST)
		return _manifest
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		_report_once(MANIFEST, "[VCNVA] cannot read %s" % MANIFEST)
		return _manifest
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
	else:
		_report_once(MANIFEST, "[VCNVA] %s is not a JSON object" % MANIFEST)
	return _manifest


## The face sheet's grid, manifest first. Zero or negative is a broken manifest,
## not a request for an empty atlas - the default stands.
static func atlas_cols() -> int:
	return maxi(1, int(manifest().get("atlas_cols", FACE_COLS)))


static func atlas_rows() -> int:
	return maxi(1, int(manifest().get("atlas_rows", FACE_ROWS)))


## The VC/NVA bodies this dresser understands. Prefix-gated, not list-gated:
## a new export reaches the game with no code change here (GruntRandomizer.
## is_dressable does the same for the US side).
static func is_dressable(unit: String) -> bool:
	return unit.begins_with("nva_") or unit.begins_with("vc_")


## Faces this faction may draw. `unit` lets the manifest carry a per-role pool
## (an officer pool that skips the youngest faces, say) without a code change.
static func faces_for(unit: String) -> Array[int]:
	var man: Dictionary = manifest()
	var pools: Dictionary = man.get("face_pools", {}) as Dictionary
	var raw: Variant = pools.get(unit, pools.get("default", null))
	if raw is Array and (raw as Array).size() > 0:
		var out: Array[int] = []
		for v: Variant in raw as Array:
			out.append(int(v))
		return out
	return FALLBACK_FACES


## The gear library, loaded once. Empty dictionary if it is missing - every category
## then deals nothing and the man keeps whatever his body was exported wearing.
static func gear_manifest() -> Dictionary:
	if _gear_loaded:
		return _gear
	_gear_loaded = true
	if not ResourceLoader.exists(GEAR_MANIFEST) and not FileAccess.file_exists(GEAR_MANIFEST):
		_report_once(GEAR_MANIFEST, "[VCNVA] no %s - the men wear only welded gear"
			% GEAR_MANIFEST)
		return _gear
	var f: FileAccess = FileAccess.open(GEAR_MANIFEST, FileAccess.READ)
	if f == null:
		_report_once(GEAR_MANIFEST, "[VCNVA] cannot read %s" % GEAR_MANIFEST)
		return _gear
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_gear = parsed as Dictionary
	else:
		_report_once(GEAR_MANIFEST, "[VCNVA] %s is not a JSON object" % GEAR_MANIFEST)
	return _gear


## Every variant name in one gear category. Sorted, so the same seed deals the same
## man whatever order the builder happened to write the JSON in.
static func variants(category: String) -> Array[String]:
	var cat: Dictionary = gear_manifest().get(category, {}) as Dictionary
	var out: Array[String] = []
	for k: Variant in cat.keys():
		out.append(String(k))
	out.sort()
	return out


## Dress a soldier. `rng` in, so a mission can reproduce the same force from a seed.
static func dress(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary = {}) -> Dictionary:
	# NOT re-entrant - a second pass stacks a second hat on the same socket.
	if actor.get_meta("dressed", false):
		return {}
	actor.set_meta("dressed", true)
	var root: Node3D = actor.instance_root()
	if root == null:
		return {}

	var out: Dictionary = {}

	var pool: Array[int] = faces_for(actor.unit)
	if pool.is_empty():
		pool = FALLBACK_FACES
	var face: int = int(opts.get("face", pool[rng.randi() % pool.size()]))
	out["face"] = face
	_set_face(root, face, actor.unit)

	var wants_headgear: bool = bool(opts.get("headgear", true))
	out["headgear"] = _rehang_headgear(actor, root, rng, opts) if wants_headgear else ""
	if not wants_headgear:
		for name: String in HEADGEAR:
			_set_visible_by_name(root, name, false)

	var pack: String = _rehang_pack(actor, root, rng, opts)
	out["pack_variant"] = pack
	out["chest"] = _rehang_chest(actor, rng, opts)
	out["belt"] = _rehang_belt(actor, rng, opts)

	for key: String in GEAR_TOGGLES:
		# A hung library pack owns his back; the welded-mesh toggle must not put a
		# second ruck back on top of it.
		if key == "pack" and not pack.is_empty():
			out[key] = pack != "pack_none"
			continue
		var on: bool = bool(opts[key]) if opts.has(key) else _roll_gear(key, rng)
		var hit: int = 0
		for mesh_name: String in GEAR_TOGGLES[key]:
			hit += _set_visible_by_name(root, mesh_name, on)
		if on and hit == 0:
			_report_once(actor.unit + "/" + key,
				"[VCNVA] %s has no %s meshes - loadout reports false" % [actor.unit, key])
			out[key] = false
			continue
		out[key] = on

	return out


static func _roll_gear(key: String, rng: RandomNumberGenerator) -> bool:
	match key:
		"foliage":
			return rng.randf() < FOLIAGE_CHANCE
		"pack":
			return rng.randf() < PACK_CHANCE
	return false


## Slide the face material to a different cell of the atlas. Head, neck, hands and
## forearms all live in that cell, so they follow as one.
static func _set_face(root: Node3D, index: int, unit: String) -> void:
	var cols: int = atlas_cols()
	var rows: int = atlas_rows()
	var col: int = index % cols
	var row: int = int(index / float(cols)) % rows
	var off := Vector3(col / float(cols), row / float(rows), 0.0)

	var slid: int = 0
	var stranded: Array[String] = []
	for mi: MeshInstance3D in _all_meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s: int in mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				m = mesh.surface_get_material(s)
			var sm := m as BaseMaterial3D
			if sm == null:
				continue
			if not _rides_face_atlas(sm):
				if _is_face_material(sm):
					stranded.append(sm.resource_name)
				continue
			var mine := sm.duplicate() as BaseMaterial3D
			mine.uv1_offset = off
			mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.set_surface_override_material(s, mine)
			slid += 1
	# One line per BODY, not per man: a 45-man assault is 45 copies of one defect.
	if not stranded.is_empty():
		_report_once("stranded/" + unit,
			("[VCNVA] %s: %d skin material(s) do NOT sample the face atlas and cannot "
			+ "follow the face: %s. That body needs the face/skin merge pass, or his skin "
			+ "tone will not match the head he was dealt.")
			% [unit, stranded.size(), ", ".join(stranded)])
	elif slid == 0:
		_report_once("noatlas/" + unit,
			"[VCNVA] %s has no atlas surface to slide - these men keep the face " % unit
			+ "they were exported with")


## Texture identity, not resource name: the name is what drifted on the US side, and
## the pixels are what actually decide his skin.
static func _rides_face_atlas(m: BaseMaterial3D) -> bool:
	var tex: Texture2D = m.albedo_texture
	if tex != null and tex.resource_path.contains("face_atlas"):
		return true
	return tex == null and _is_face_material(m)


static func _is_face_material(m: Material) -> bool:
	for prefix: String in FACE_MATERIALS:
		if m.resource_name.begins_with(prefix):
			return true
	return false


## Deal a headgear variant from the library and hang it, then take the welded pith
## helmet / rice hat off. Returns the variant name, or "" if nothing was hung.
static func _rehang_headgear(actor: ModelActor, root: Node3D,
		rng: RandomNumberGenerator, opts: Dictionary) -> String:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return ""
	var pick: String = _pick("headgear", rng, opts, "headgear_id", actor.unit)
	if pick.is_empty():
		return ""

	var tilt: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rng.randf_range(HEADGEAR_PITCH_DEG.x, HEADGEAR_PITCH_DEG.y)),
		deg_to_rad(rng.randf_range(-HEADGEAR_YAW_DEG, HEADGEAR_YAW_DEG)),
		deg_to_rad(rng.randf_range(-HEADGEAR_ROLL_DEG, HEADGEAR_ROLL_DEG))))
	var worn: String = _hang(actor, skel, "headgear", "socket_headgear",
		"mixamorig:Head", "HeadgearSocket", pick, tilt)

	# The welded hat comes off only once the variant is decided - a bail above must
	# never leave a bare head.
	if worn.is_empty():
		return ""
	for name: String in HEADGEAR:
		_set_visible_by_name(root, name, false)
	return worn


## Deal a pack and hang it on the spine socket, then hide the one welded into the
## body. Returns the variant name, or "" if nothing was hung.
static func _rehang_pack(actor: ModelActor, root: Node3D,
		rng: RandomNumberGenerator, opts: Dictionary) -> String:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return ""
	var pick: String = _pick("packs", rng, opts, "pack_id", actor.unit)
	if pick.is_empty():
		return ""
	var worn: String = _hang(actor, skel, "packs", "socket_pack",
		"mixamorig:Spine1", "PackSocket", pick)
	if worn.is_empty():
		return ""
	for mesh_name: String in GEAR_TOGGLES["pack"]:
		_set_visible_by_name(root, mesh_name, false)
	return worn


## Deal a chest rig or bandolier. Nothing is welded into the bodies here, so there is
## no stock mesh to take off. Returns the variant name, or "" if nothing was hung.
static func _rehang_chest(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary) -> String:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return ""
	var pick: String = _pick("chest", rng, opts, "chest_id", actor.unit)
	if pick.is_empty():
		return ""
	return _hang(actor, skel, "chest", "socket_chest",
		"mixamorig:Spine2", "ChestSocket", pick)


## Deal a belt and hang it on the hips socket. Like the chest rig, nothing is welded into
## the bodies, so there is no stock mesh to take off. Belts carry their faction's webbing
## baked in (`belt_web_nva` black, `belt_web_vc` olive), so the pick is faction-gated.
## Returns the variant name, or "" if nothing was hung - a library with no belt category
## simply leaves the men beltless rather than erroring.
static func _rehang_belt(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary) -> String:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return ""
	var pick: String = _pick("belt", rng, opts, "belt_id", actor.unit)
	if pick.is_empty():
		return ""
	return _hang(actor, skel, "belt", "socket_belt",
		"mixamorig:Hips", "BeltSocket", pick)


## The variant this man draws from one category, or "" when the library carries none.
##
## FACTION-GATED. Some library keys carry their faction's webbing baked into the mesh
## (`chest_rig_ak_nva_foliage` is black, `..._vc_foliage` olive - Summoner ruling
## 2026-08-08: NVA wear black webbing, VC canvas/army-green). An ungated pick hands a
## VC the black NVA rig, which is the exact thing that ruling was about. Keys with no
## faction token stay available to both, so a library that never adopts the convention
## behaves as it always did.
static func _pick(category: String, rng: RandomNumberGenerator, opts: Dictionary,
		opt_key: String, unit: String = "") -> String:
	if opts.has(opt_key):
		return String(opts[opt_key])
	var names: Array[String] = variants(category)
	var allowed: Array[String] = []
	for n: String in names:
		if _wearable_by(category, n, unit):
			allowed.append(n)
	if allowed.is_empty():
		# Every variant in this category is another faction's. Better a man in neutral
		# gear than a VC in NVA black, so fall back to the unfiltered pool only when the
		# category has NOTHING neutral either.
		if not names.is_empty():
			_report_once("faction/" + category + "/" + unit,
				("[VCNVA] every '%s' variant is faction-locked away from %s - dealing "
				+ "nothing rather than another faction's gear") % [category, unit])
		return ""
	return allowed[rng.randi() % allowed.size()]


## The faction a library variant is locked to: "nva", "vc", or "" for neutral.
##
## The manifest's own `faction` field wins, so gear whose faction is a LOOK rather than a
## naming convention can be locked from data with no code change here - the pith helmet is
## the NVA's single most recognisable silhouette and its key carries no token. Falling back
## to a delimited token in the key keeps `chest_rig_ak_nva_foliage` gated without needing
## the field, and leaves `pack_ruck_light` neutral.
static func _faction_of(category: String, key: String) -> String:
	var cat: Dictionary = gear_manifest().get(category, {}) as Dictionary
	var entry: Dictionary = cat.get(key, {}) as Dictionary
	var declared: String = String(entry.get("faction", ""))
	if not declared.is_empty():
		return declared
	if key.contains("_nva_") or key.ends_with("_nva"):
		return "nva"
	if key.contains("_vc_") or key.ends_with("_vc"):
		return "vc"
	return ""


## May this unit wear this variant? Neutral gear is wearable by anyone; an unknown unit
## (bench and probe callers pass "") may draw anything.
static func _wearable_by(category: String, key: String, unit: String) -> bool:
	var locked: String = _faction_of(category, key)
	if locked.is_empty() or unit.is_empty():
		return true
	return unit.begins_with(locked + "_")


## Hang one library prop on a bone socket. Every GLB in this library is authored with
## its vertices already in bone-local space - the manifest's socket_* matrices are
## IDENTITY by construction - so the attachment carries no transform of its own and no
## Blender->Godot axis conversion can be got wrong. `tilt` turns the prop about its own
## centre, never about the bone.
##
## Returns the variant name, including for the explicit "wear nothing" entries whose
## `glb` is null: choosing to go without is a dressed man, not a failure to dress him.
static func _hang(actor: ModelActor, skel: Skeleton3D, category: String,
		socket_key: String, fallback_bone: String, socket_name: String,
		pick: String, tilt: Basis = Basis.IDENTITY) -> String:
	var cat: Dictionary = gear_manifest().get(category, {}) as Dictionary
	var entry: Dictionary = cat.get(pick, {}) as Dictionary
	if entry.is_empty():
		_report_once(category + "/" + pick,
			"[VCNVA] no '%s' in the %s library" % [pick, category])
		return ""

	var raw: Variant = entry.get("glb", null)
	if raw == null or String(raw).is_empty():
		return pick

	var path: String = String(raw)
	if not ResourceLoader.exists(path):
		_report_once(path, "[VCNVA] missing %s - '%s' not hung" % [path, pick])
		return ""
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_report_once(path, "[VCNVA] %s is not a scene - '%s' not hung" % [path, pick])
		return ""

	var bone: int = _socket_bone(skel, socket_key, fallback_bone)
	if bone < 0:
		_report_once(socket_key, "[VCNVA] no %s bone on %s" % [fallback_bone, actor.unit])
		return ""

	var att := BoneAttachment3D.new()
	att.name = socket_name
	att.bone_idx = bone
	skel.add_child(att)

	var prop: Node3D = packed.instantiate() as Node3D
	if prop == null:
		att.queue_free()
		_report_once(path, "[VCNVA] %s has no Node3D root - '%s' not hung" % [path, pick])
		return ""
	att.add_child(prop)

	if not tilt.is_equal_approx(Basis.IDENTITY):
		var centre: Vector3 = _local_centre(prop)
		prop.transform = Transform3D(tilt, centre - tilt * centre)
	return pick


## The bone a category's socket rides. The manifest names it in Blender form
## (`mixamorig:Spine1`); Godot's glTF importer sanitises the colon to an underscore,
## so both spellings are tried.
static func _socket_bone(skel: Skeleton3D, socket_key: String, fallback: String) -> int:
	var socket: Dictionary = gear_manifest().get(socket_key, {}) as Dictionary
	var named: String = String(socket.get("bone", fallback))
	var bone: int = skel.find_bone(named.replace(":", "_"))
	if bone < 0:
		bone = skel.find_bone(named)
	return bone


## The prop's own centre in its own space, so a tilt rotates a hat on the head rather
## than swinging it off the neck bone the socket sits on.
static func _local_centre(prop: Node3D) -> Vector3:
	var inv: Transform3D = prop.global_transform.affine_inverse()
	var box: AABB = AABB()
	var got: bool = false
	for mi: MeshInstance3D in _all_meshes(prop):
		if mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = b if not got else box.merge(b)
		got = true
	return box.get_center() if got else Vector3.ZERO


## One line per problem for the whole session - a 45-man assault would print 45 copies
## of the same missing file otherwise.
static func _report_once(key: String, msg: String) -> void:
	if _reported.has(key):
		return
	_reported[key] = true
	push_warning(msg)


## Returns how many meshes it touched, so a caller can tell "switched off" from
## "this body never had one".
static func _set_visible_by_name(root: Node3D, needle: String, on: bool) -> int:
	var hit: int = 0
	for mi: MeshInstance3D in _all_meshes(root):
		if mi.name.contains(needle):
			mi.visible = on
			hit += 1
	return hit


static func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
	return out
