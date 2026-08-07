## vc_nva_dresser.gd - turns the exported NVA/VC men into a force that does not repeat.
##
## Deliberately the same shape as GruntDresser and ZombieDresser so the three read as
## one system: the head and hands sit inside ONE cell of a 10x7 face atlas, so sliding
## that material's `uv1_offset` by one cell deals a different man.
##
##     faces x 7 bodies x headgear x gear toggles
##
## THE ONE TRAP, inherited: `uv1_offset` is a MATERIAL property. Duplicate it per
## instance or every soldier on screen rerolls to the same face at once.
##
## FACE POOL. GruntDresser hardcodes US_FACES and that list has already had to be
## hand-corrected once; ZombieDresser's header calls deriving it from the builder the
## fix. This follows the zombie: the pool comes from vc_nva_manifest.json, emitted by
## the builder that writes the characters. The fallback below is the atlas rows the US
## pool explicitly refuses (grunt_dresser.gd:23-24 bans 60-69 as "Asian villager faces")
## - which is precisely who these men are.
##
## SKIN RIDES THE ATLAS, as on the grunt: face and hands are the same pixels, so a face
## can never land on a mismatched body. That invariant is matched on TEXTURE IDENTITY,
## not material name - the name is what drifted on the US side and stranded a black face
## on a white body.
class_name VcNvaDresser
extends RefCounted

const FACE_COLS: int = 10
const FACE_ROWS: int = 7

const MANIFEST: String = "res://assets/nva_vc/characters/vc_nva_manifest.json"

## Used only when the manifest is missing. The rows the US pool refuses.
const FALLBACK_FACES: Array[int] = [
	60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
]

const FACE_MATERIALS: Array[String] = ["face_atlas", "Skin_VC", "vc_face_skin"]

## Headgear ships welded into each GLB - NVA wear the pith helmet, VC the rice hat.
## Both are re-hung rather than swapped: there is no library of variants to draw from,
## and inventing one would be a fossil. Re-hanging buys the per-man tilt.
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


## The manifest, loaded once. Empty dictionary if it is missing - callers fall back
## to FALLBACK_FACES rather than refusing to spawn.
static func manifest() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	if not ResourceLoader.exists(MANIFEST) and not FileAccess.file_exists(MANIFEST):
		return _manifest
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		return _manifest
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
	return _manifest


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


## Dress a soldier. `rng` in, so a mission can reproduce the same force from a seed.
static func dress(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary = {}) -> Dictionary:
	var root: Node3D = actor.instance_root()
	if root == null:
		return {}

	var out: Dictionary = {}

	var pool: Array[int] = faces_for(actor.unit)
	var face: int = int(opts.get("face", pool[rng.randi() % pool.size()]))
	out["face"] = face
	_set_face(root, face)

	var wants_headgear: bool = bool(opts.get("headgear", true))
	out["headgear"] = _rehang_headgear(actor, root, rng) if wants_headgear else ""
	if not wants_headgear:
		for name: String in HEADGEAR:
			_set_visible_by_name(root, name, false)

	for key: String in GEAR_TOGGLES:
		var on: bool = bool(opts[key]) if opts.has(key) else _roll_gear(key, rng)
		var hit: int = 0
		for mesh_name: String in GEAR_TOGGLES[key]:
			hit += _set_visible_by_name(root, mesh_name, on)
		if on and hit == 0:
			push_warning("[VCNVA] %s has no %s meshes - loadout reports false"
				% [actor.unit, key])
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
static func _set_face(root: Node3D, index: int) -> void:
	var col: int = index % FACE_COLS
	var row: int = int(index / float(FACE_COLS)) % FACE_ROWS
	var off := Vector3(col / float(FACE_COLS), row / float(FACE_ROWS), 0.0)

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
	if not stranded.is_empty():
		push_warning(("[VCNVA] %d skin material(s) do NOT sample the face atlas and cannot "
			+ "follow the face: %s. That body needs the face/skin merge pass, or his skin "
			+ "tone will not match the head he was dealt.")
			% [stranded.size(), ", ".join(stranded)])
	elif slid == 0:
		push_warning("[VCNVA] no atlas surface found to slide - this man keeps the face "
			+ "he was exported with")


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


## Hide the welded headgear and re-hang the same mesh on a bone socket with a tilt.
## Its rendered transform is the placement the artist fitted, so matching it dodges
## every Blender->Godot axis conversion. Returns the headgear name, or "" if none hung.
static func _rehang_headgear(actor: ModelActor, root: Node3D,
		rng: RandomNumberGenerator) -> String:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return ""

	var stock: MeshInstance3D = null
	var worn: String = ""
	for name: String in HEADGEAR:
		stock = _find_mesh(root, name)
		if stock != null:
			worn = name
			break
	if stock == null:
		return ""

	var bone: int = skel.find_bone("mixamorig_Head")
	if bone < 0:
		bone = skel.find_bone("mixamorig:Head")
	if bone < 0:
		push_warning("[VCNVA] no Head bone on %s" % actor.unit)
		return ""

	var aabb: AABB = stock.get_aabb()
	var centre: Vector3 = stock.global_transform * aabb.get_center()
	var basis: Basis = stock.global_transform.basis
	var mesh: Mesh = stock.mesh
	if mesh == null:
		return ""

	var att := BoneAttachment3D.new()
	att.name = "HeadgearSocket"
	att.bone_idx = bone
	skel.add_child(att)

	var hung := MeshInstance3D.new()
	hung.name = worn
	hung.mesh = mesh
	for s: int in mesh.get_surface_count():
		var src: Material = stock.get_active_material(s)
		if src != null:
			hung.set_surface_override_material(s, src)
	att.add_child(hung)

	# Hide the stock only once the replacement is parented - a bail above must never
	# leave a bare head.
	stock.visible = false
	var tilt: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rng.randf_range(HEADGEAR_PITCH_DEG.x, HEADGEAR_PITCH_DEG.y)),
		deg_to_rad(rng.randf_range(-HEADGEAR_YAW_DEG, HEADGEAR_YAW_DEG)),
		deg_to_rad(rng.randf_range(-HEADGEAR_ROLL_DEG, HEADGEAR_ROLL_DEG))))
	hung.global_transform = Transform3D(basis * tilt, centre)
	return worn


## Returns how many meshes it touched, so a caller can tell "switched off" from
## "this body never had one".
static func _set_visible_by_name(root: Node3D, needle: String, on: bool) -> int:
	var hit: int = 0
	for mi: MeshInstance3D in _all_meshes(root):
		if mi.name.contains(needle):
			mi.visible = on
			hit += 1
	return hit


static func _find_mesh(root: Node3D, needle: String) -> MeshInstance3D:
	for mi: MeshInstance3D in _all_meshes(root):
		if mi.name.contains(needle):
			return mi
	return null


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
