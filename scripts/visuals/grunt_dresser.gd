## grunt_dresser.gd - turns 6 exported grunts into thousands of distinct men.
##
## THE WHOLE IDEA
## Every soldier already ships with a head and a pair of hands whose UVs sit inside
## ONE cell of the 10x7 face atlas. Head and skin share a single material
## (`grunt_face_skin`), so sliding that material's `uv1_offset` by one cell moves his
## FACE and his SKIN TONE together, to a different man. They can never mismatch,
## because they are the same pixels.
##
##     10 cols x 7 rows = 70 faces  x  15 helmets  x  gear toggles
##
## from the six GLBs already on disk. No new exports, no per-variant characters.
##
## THE ONE TRAP: `uv1_offset` is a MATERIAL property. Forget to duplicate the
## material and every grunt on screen rerolls to the same face at once - a fireteam
## of octuplets. dress() duplicates per instance. Do not "optimise" that away.
class_name GruntDresser
extends RefCounted

const FACE_COLS: int = 10
const FACE_ROWS: int = 7

## The cells a 1968 US GRUNT may draw. The shared atlas also carries female faces
## (cells 13,14,16,22,23,32,33,41,52), a turban (49) and the whole legacy bottom
## row 60-69 with Asian villager faces - none may land on a soldier (Summoner
## ruling 2026-08-04: a female grunt is "immposible... make sure we fix that").
## An explicit opts["face"] bypasses this on purpose (bench/probe use).
const US_FACES: Array[int] = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
	10, 11, 12, 15, 17, 18, 19,
	20, 21, 24, 25, 26, 27, 28, 29,
	30, 31, 34, 35, 36, 37, 38, 39,
	40, 42, 43, 44, 45, 46, 47, 48,
	50, 51, 53, 54, 55, 56, 57, 58, 59,
]
## The merged head+skin material. The exports never renamed it, so match either
## name (same rule as tools/merge_face_skin_material.py).
const FACE_MATERIALS: Array[String] = ["grunt_face_skin", "face_atlas"]

const HELMET_DIR: String = "res://assets/us/props/helmets/"
const HELMET_COVER_DIR: String = "res://assets/us/textures/helmets/"
const HELMETS: Array[String] = [
	"m1_plain", "m1_cig", "m1_bugjuice", "m1_cig_bug", "m1_ace",
	"m1_ace_cig", "m1_war_is_hell", "m1_born_to_kill", "m1_rounds",
	"m1_foliage", "m1_foliage_graf", "m1_barepot", "m1_barepot_fta",
	"m1_erdl_short", "m1_veteran",
]

## The helmet that ships welded into every grunt GLB. We hide it and hang a
## variant in its place - and we use ITS rendered position to place the variant,
## which dodges every Blender->Godot axis conversion. Where it renders is right
## by definition; it is the one the artist fitted.
const STOCK_HELMET: String = "helmet_shell_worn"

## Helmets are authored LEVEL in helmet_variants.blend. Hanging every man's at the
## stock's basis gives a squad wearing one identical angle, which reads as a modelling
## error rather than as men. Each gets his own tilt off the mission rng, so the same
## seed rebuilds the same squad (ADR-010). Pitch is biased backward - a steel pot rides
## back off the brow far more often than it tips forward over the eyes.
const HELMET_PITCH_DEG: Vector2 = Vector2(-9.0, 4.0)
const HELMET_YAW_DEG: float = 5.0
const HELMET_ROLL_DEG: float = 4.0

const ANTENNA_SHADER: String = "res://assets/shaders/antenna_sway.gdshader"
const AntennaSwayScript := preload("res://scripts/visuals/antenna_sway.gd")

## One key -> every mesh it owns, so `radio: true` cannot hand a man a backpack
## with no whip antenna on it.
const GEAR_TOGGLES: Dictionary = {
	"ruck":  ["ruck_pack_worn"],
	"radio": ["prc25_pack", "prc25_antenna", "prc25_handset"],
}


## Dress a soldier. `rng` in, so a mission can reproduce the same squad from a seed.
static func dress(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary = {}) -> Dictionary:
	var root: Node3D = actor.instance_root()
	if root == null:
		return {}

	var out: Dictionary = {}

	# --- 1. FACE + SKIN (one material, one offset, they move together) ---
	var face: int = int(opts.get("face", US_FACES[rng.randi() % US_FACES.size()]))
	out["face"] = face
	_set_face(root, face)

	# --- 2. HELMET ---
	var wants_helmet: bool = bool(opts.get("helmet", true))
	if wants_helmet:
		var pick: String = String(opts.get("helmet_id",
			HELMETS[rng.randi() % HELMETS.size()]))
		# The loadout must never claim a helmet the swap could not hang.
		out["helmet"] = pick if _swap_helmet(actor, root, pick, rng) else ""
	else:
		out["helmet"] = ""
		_set_visible_by_name(root, STOCK_HELMET, false)

	# --- 3. GEAR ---
	for key in GEAR_TOGGLES:
		if not opts.has(key):
			continue
		var on: bool = bool(opts[key])
		# The marksman, MG gunner and grenadier ship with no PRC-25 in the mesh at
		# all (export_us_squad.NO_RADIO), so this would silently do nothing.
		if on and key == "radio" and actor.unit in ModelActor.RADIO_FORBIDDEN:
			push_warning("[DRESSER] %s cannot carry a radio - no PRC-25 in his GLB"
				% actor.unit)
			out[key] = false
			continue
		for mesh_name: String in GEAR_TOGGLES[key]:
			_set_visible_by_name(root, mesh_name, on)
		if key == "radio" and on:
			_rig_antenna(root)
		out[key] = on

	return out


## Give the PRC-25 whip its sway shader and driver.
##
## assets/shaders/antenna_sway.gdshader and scripts/visuals/antenna_sway.gd have
## both existed and done nothing: the shader was never assigned to a mesh, and
## the script was never attached to anything, so the whip has always been a rigid
## rod. This is the seam that connects them, run whenever a man is dressed with a
## radio.
static func _rig_antenna(root: Node3D) -> void:
	for mi in _all_meshes(root):
		if not mi.name.contains("prc25_antenna"):
			continue
		if mi.get_script() != null:
			continue                        # already rigged; dressing is re-runnable
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue

		# Carry the GLB's own texture across - material_override replaces the
		# surface material outright, so without this the whip renders untextured.
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = load(ANTENNA_SHADER) as Shader
		var src: Material = mi.get_active_material(0)
		if src is StandardMaterial3D:
			var std := src as StandardMaterial3D
			shader_mat.set_shader_parameter("albedo_tex", std.albedo_texture)
			shader_mat.set_shader_parameter("tint", std.albedo_color)

		# Measure the whip rather than trusting the shader's 1.07m default: an
		# antenna re-exported at a different length would otherwise bend on the
		# wrong curve, and the error is invisible until it looks subtly wrong.
		var aabb: AABB = mesh.get_aabb()
		shader_mat.set_shader_parameter("base_y", aabb.position.y)
		shader_mat.set_shader_parameter("whip_len", maxf(aabb.size.y, 0.01))

		mi.material_override = shader_mat
		mi.set_script(AntennaSwayScript)
		(mi as AntennaSway).activate()


## Slide the face material to a different cell of the atlas. Head, neck, hands and
## forearms all live in that cell, so they follow as one.
static func _set_face(root: Node3D, index: int) -> void:
	var col: int = index % FACE_COLS
	var row: int = int(index / float(FACE_COLS)) % FACE_ROWS
	var off := Vector3(col / float(FACE_COLS), row / float(FACE_ROWS), 0.0)

	# EVERY SURFACE THAT RIDES THE ATLAS MOVES, AND IT MOVES BY THE SAME OFFSET.
	#
	# The header's promise - "they can never mismatch, because they are the same pixels" -
	# only holds while head and skin really are one material. On any body where the
	# merge_face_skin_material pass did not take, they are two, this matched the face one by
	# NAME and slid it alone: the face went to a black man and the body stayed white
	# (Summoner, 2026-07-29: "if you have a black face you get a black body and vice versa").
	#
	# Matching on the TEXTURE instead of the name makes the invariant structural. Whatever a
	# material is called, if it samples the face atlas it is skin, and it moves with the face.
	var slid: int = 0
	var stranded: Array[String] = []
	for mi in _all_meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				m = mesh.surface_get_material(s)
			var sm := m as BaseMaterial3D
			if sm == null:
				continue
			if not _rides_face_atlas(sm):
				if _is_face_material(sm):
					stranded.append(sm.resource_name)   # named skin, NOT on the atlas
				continue
			# DUPLICATE, or every grunt sharing this material rerolls with him.
			var mine := sm.duplicate() as BaseMaterial3D
			mine.uv1_offset = off
			mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PSX
			mi.set_surface_override_material(s, mine)
			slid += 1
	if not stranded.is_empty():
		push_warning(("[DRESSER] %d skin material(s) do NOT sample the face atlas and cannot "
			+ "follow the face: %s. That body needs the merge_face_skin_material pass, or his "
			+ "skin tone will not match the head he was dealt.")
			% [stranded.size(), ", ".join(stranded)])
	elif slid == 0:
		push_warning("[DRESSER] no atlas surface found to slide - this man keeps the face "
			+ "he was exported with")


## Does this material sample the face atlas? Texture identity, not resource name: the name is
## what drifted, and the pixels are what actually decide his skin.
static func _rides_face_atlas(m: BaseMaterial3D) -> bool:
	var tex: Texture2D = m.albedo_texture
	if tex != null and tex.resource_path.contains("face_atlas"):
		return true
	# Un-textured or procedurally-assigned material: fall back to the authored name.
	return tex == null and _is_face_material(m)


static func _is_face_material(m: Material) -> bool:
	for prefix in FACE_MATERIALS:
		if m.resource_name.begins_with(prefix):
			return true
	return false


## Hide the stock helmet, hang a variant exactly where it was rendering.
## Returns false when nothing was hung, so dress() can report an honest loadout.
static func _swap_helmet(actor: ModelActor, root: Node3D, helmet_id: String,
		rng: RandomNumberGenerator) -> bool:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return false

	var stock: MeshInstance3D = _find_mesh(root, STOCK_HELMET)
	if stock == null:
		push_warning("[DRESSER] no %s in %s - cannot place a helmet" % [STOCK_HELMET, actor.unit])
		return false

	# where the stock helmet ACTUALLY RENDERS. The exported variants have their
	# origin at the helmet's centre, so this is the transform to match. Doing it
	# this way means no bone-space maths and no Y-up conversion to get wrong.
	var aabb: AABB = stock.get_aabb()
	var centre: Vector3 = stock.global_transform * aabb.get_center()
	var basis: Basis = stock.global_transform.basis

	var path: String = HELMET_DIR + helmet_id + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("[DRESSER] missing helmet %s" % path)
		return false
	var packed: PackedScene = load(path)
	if packed == null:
		return false

	var bone: int = skel.find_bone("mixamorig_Head")
	if bone < 0:
		bone = skel.find_bone("mixamorig:Head")
	if bone < 0:
		push_warning("[DRESSER] no Head bone on %s" % actor.unit)
		return false

	var att := BoneAttachment3D.new()
	att.name = "HelmetSocket"
	att.bone_idx = bone
	skel.add_child(att)

	# Hide the stock only once the variant is certain - a bail above must never
	# leave a bare head.
	stock.visible = false
	var hel: Node3D = packed.instantiate()
	att.add_child(hel)
	var tilt: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rng.randf_range(HELMET_PITCH_DEG.x, HELMET_PITCH_DEG.y)),
		deg_to_rad(rng.randf_range(-HELMET_YAW_DEG, HELMET_YAW_DEG)),
		deg_to_rad(rng.randf_range(-HELMET_ROLL_DEG, HELMET_ROLL_DEG))))
	hel.global_transform = Transform3D(basis * tilt, centre)
	_texture_helmet(hel, helmet_id)
	return true


## The helmet was baked to ONE albedo atlas (helm_<id>.png) but the glTF export left
## it unbound, so every UV-bearing surface renders flat/white. Bind it here: surfaces
## that carry UVs sample the atlas; UV-less detail props (brass, foliage) keep their
## authored factor colour; props with their own embedded texture (card, cig, bug-juice)
## keep it. NEAREST filter throughout for the PSX read.
static func _texture_helmet(hel: Node3D, helmet_id: String) -> void:
	var cover_path: String = HELMET_COVER_DIR + "helm_" + helmet_id + ".png"
	var cover: Texture2D = load(cover_path) if ResourceLoader.exists(cover_path) else null
	for mi in _all_meshes(hel):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var bm := mi.get_active_material(s) as BaseMaterial3D
			if bm == null:
				continue
			var mine := bm.duplicate() as BaseMaterial3D
			mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var has_uv: bool = (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV) != 0
			if cover != null and bm.albedo_texture == null and has_uv:
				mine.albedo_texture = cover
				mine.albedo_color = Color.WHITE
			mi.set_surface_override_material(s, mine)


static func _set_visible_by_name(root: Node3D, needle: String, on: bool) -> void:
	for mi in _all_meshes(root):
		if mi.name.contains(needle):
			mi.visible = on


static func _find_mesh(root: Node3D, needle: String) -> MeshInstance3D:
	for mi in _all_meshes(root):
		if mi.name.contains(needle):
			return mi
	return null


static func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
	return out
