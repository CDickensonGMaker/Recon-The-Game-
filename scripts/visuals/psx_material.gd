## psx_material.gd - PS1_SETUP.md layer 2: vertex snap + affine warp + Gouraud,
## applied by converting imported BaseMaterial3D surfaces to the ps1_material
## shader at runtime. Same idiom as ViewmodelLens (scripts/weapons/viewmodel_lens.gd):
## the albedo is READ off the imported material, so no per-asset authoring exists.
## Driven only by PsxLook; nothing else may call apply().
class_name PsxMaterial
extends RefCounted

const SHADER_OPAQUE := "res://assets/shaders/ps1_material.gdshader"
const SHADER_CUTOUT := "res://assets/shaders/ps1_material_cutout.gdshader"

## Meshes in this group are never converted. Escape hatch for anything whose
## look is load-bearing under the toggle (bench props, debug gizmos).
const EXEMPT_GROUP := "psx_exempt"

## Original surface overrides, stashed per MeshInstance3D so restore() is exact
## rather than "set null and hope the mesh's own material was right".
const ORIG_META := "psx_orig_mats"

## NDC grid the vertices snap to. PsxLook writes the live 3D internal resolution
## here, so the wobble grid and the postprocess dither share one pixel grid.
static var snap_resolution: Vector2 = Vector2(480.0, 270.0)
static var wobble_amount: float = 1.0
static var affine_amount: float = 0.85

static var _opaque: Shader = null
static var _cutout: Shader = null
static var _cache: Dictionary = {}
## Holds a reference to every source material we have keyed on. Godot RECYCLES
## instance ids after a free, so an unpinned id key would hand a later material
## its predecessor's converted twin on the next level load.
static var _pinned: Dictionary = {}


## Convert every eligible surface under `root`. Returns the surface count converted.
static func apply(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var n: int = 0
	for child in root.find_children("*", "MeshInstance3D", true, false):
		n += apply_one(child as MeshInstance3D)
	for child in root.find_children("*", "MultiMeshInstance3D", true, false):
		n += apply_multi(child as MultiMeshInstance3D)
	return n


## MultiMeshInstance3D has no per-surface override - material_override is the
## only hook, so only single-surface multimeshes (clutter and foliage cards,
## which is all of them here) can be converted.
static func apply_multi(mmi: MultiMeshInstance3D) -> int:
	if mmi == null or not is_instance_valid(mmi):
		return 0
	if mmi.has_meta(ORIG_META) or mmi.is_in_group(EXEMPT_GROUP):
		return 0
	var mm: MultiMesh = mmi.multimesh
	if mm == null or mm.mesh == null or mm.mesh.get_surface_count() != 1:
		return 0
	_load_shaders()

	var own: Material = mmi.material_override
	var src: Material = own if own != null else mm.mesh.surface_get_material(0)
	var std := src as BaseMaterial3D
	if std == null or _skip(std):
		return 0

	var originals: Array[Material] = [own]
	mmi.set_meta(ORIG_META, originals)
	mmi.material_override = _convert(std)
	return 1


static func apply_one(mi: MeshInstance3D) -> int:
	if mi == null or not is_instance_valid(mi) or mi.mesh == null:
		return 0
	if mi.has_meta(ORIG_META) or mi.is_in_group(EXEMPT_GROUP):
		return 0
	_load_shaders()

	var count: int = mi.mesh.get_surface_count()
	var originals: Array[Material] = []
	originals.resize(count)
	var converted: int = 0

	for s in range(count):
		var own: Material = mi.get_surface_override_material(s)
		originals[s] = own
		var src: Material = own if own != null else mi.mesh.surface_get_material(s)
		var std := src as BaseMaterial3D
		if std == null or _skip(std):
			continue
		mi.set_surface_override_material(s, _convert(std))
		converted += 1

	if converted == 0:
		return 0
	mi.set_meta(ORIG_META, originals)
	return converted


static func restore(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	for child in root.find_children("*", "MeshInstance3D", true, false):
		restore_one(child as MeshInstance3D)
	for child in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := child as MultiMeshInstance3D
		if mmi == null or not mmi.has_meta(ORIG_META):
			continue
		if _ours(mmi.material_override):
			var orig: Array = mmi.get_meta(ORIG_META)
			var back: Material = orig[0] as Material if not orig.is_empty() else null
			mmi.material_override = back
		mmi.remove_meta(ORIG_META)


static func restore_one(mi: MeshInstance3D) -> void:
	if mi == null or not is_instance_valid(mi) or not mi.has_meta(ORIG_META):
		return
	var originals: Array = mi.get_meta(ORIG_META)
	for s in range(mini(originals.size(), mi.get_surface_override_material_count())):
		if not _ours(mi.get_surface_override_material(s)):
			continue
		mi.set_surface_override_material(s, originals[s] as Material)
	mi.remove_meta(ORIG_META)


## Restore only what we still own. Another system may have re-materialled the
## surface since (ViewmodelLens does, on any weapon it touches after us);
## putting the stashed import back would clobber its contract.
static func _ours(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	if sm == null:
		return false
	return sm.shader == _opaque or sm.shader == _cutout


## Push tuning to every live converted material. Cheap: the cache holds one
## material per SOURCE material, not per surface.
static func refresh_uniforms() -> void:
	for key in _cache:
		var mat: ShaderMaterial = _cache[key]
		mat.set_shader_parameter("snap_resolution", snap_resolution)
		mat.set_shader_parameter("wobble_amount", wobble_amount)
		mat.set_shader_parameter("affine_amount", affine_amount)


## A ShaderMaterial source is already someone else's contract (the viewmodel
## lens, antenna sway) and is left alone - it never reaches here, since only
## BaseMaterial3D is passed in. These are the BaseMaterial3D cases that must
## survive untouched: unshaded and billboarded surfaces are tracers, muzzle
## flash, rain and impact cards whose whole look is the flat blend, and true
## alpha blending has no PS1 equivalent to convert to.
static func _skip(std: BaseMaterial3D) -> bool:
	if std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return true
	if std.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return true
	return std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA


static func _is_cutout(std: BaseMaterial3D) -> bool:
	return std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
		or std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS \
		or std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH


static func _convert(std: BaseMaterial3D) -> ShaderMaterial:
	var cutout: bool = _is_cutout(std)
	## An imported GLB material carries a stable sub-resource path, so keying on
	## it also dedupes across level loads. Runtime-built materials have none and
	## fall back to the pinned instance id.
	var ident: String = std.resource_path
	if ident.is_empty():
		ident = str(std.get_instance_id())
		_pinned[ident] = std
	var key: String = "%s:%d" % [ident, 1 if cutout else 0]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = _cutout if cutout else _opaque
	mat.set_shader_parameter("albedo_color", std.albedo_color)
	if std.albedo_texture != null:
		mat.set_shader_parameter("albedo_tex", std.albedo_texture)
	mat.set_shader_parameter("use_vertex_color", std.vertex_color_use_as_albedo)
	mat.set_shader_parameter("snap_resolution", snap_resolution)
	mat.set_shader_parameter("wobble_amount", wobble_amount)
	mat.set_shader_parameter("affine_amount", affine_amount)
	if cutout:
		mat.set_shader_parameter("alpha_scissor", std.alpha_scissor_threshold)
	mat.resource_name = std.resource_name
	_cache[key] = mat
	return mat


static func _load_shaders() -> void:
	if _opaque == null:
		_opaque = load(SHADER_OPAQUE)
	if _cutout == null:
		_cutout = load(SHADER_CUTOUT)
