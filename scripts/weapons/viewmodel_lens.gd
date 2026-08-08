## viewmodel_lens.gd - the ONE viewmodel lens (ADR-034). Real-scale gun meshes
## render through their own FOV via assets/shaders/viewmodel_lens.gdshader;
## weapon_holder.gd and viewmodel_editor.gd both go through this class, so the
## bench cannot disagree with the game.
class_name ViewmodelLens
extends RefCounted

## 2026-07-26: false = the legacy mesh-scale path (_lens_ratio). Escape hatch
## while Caleb re-poses the armory on the bench; when he blesses the re-pose,
## delete the legacy path everywhere this const is read (ADR-034 kill list).
const ENABLED: bool = true

const BASE_FOV: float = 75.0

static var _shader: Shader = null
static var _mat_cache: Dictionary = {}


## Convert every surface of a freshly-instantiated viewmodel to the lens shader,
## preserving the imported albedo/roughness/metallic and the material NAME (the
## warhead art contract matches on it). cast_shadow dies here: a depth-squashed
## mesh must never write a shadow map. Returns the meshes for set_fov().
static func apply(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _shader == null:
		_shader = load("res://assets/shaders/viewmodel_lens.gdshader")
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## The lens owns these surfaces; the PSX material pass must not convert
		## them, and vertex-snapping the player's own gun would be unreadable.
		mi.add_to_group(PsxMaterial.EXEMPT_GROUP)
		PsxMaterial.restore_one(mi)
		for s in range(mi.mesh.get_surface_count()):
			var src: Material = mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			mi.set_surface_override_material(s, _convert(src))
		out.append(mi)
	return out


## One converted material per source material, cached: shared imported materials
## stay shared, so per-surface memory does not balloon across weapon switches.
static func _convert(src: Material) -> ShaderMaterial:
	var key: int = src.get_instance_id() if src != null else 0
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var std := src as BaseMaterial3D
	if std != null:
		mat.set_shader_parameter("albedo_col", std.albedo_color)
		if std.albedo_texture != null:
			mat.set_shader_parameter("albedo_tex", std.albedo_texture)
		mat.set_shader_parameter("roughness_val", std.roughness)
		mat.set_shader_parameter("metallic_val", std.metallic)
	if src != null:
		mat.resource_name = src.resource_name
	_mat_cache[key] = mat
	return mat


## Push the effective lens FOV to a model's meshes (per-instance uniform, so the
## shared materials still serve every weapon at once).
static func set_fov(meshes: Array[MeshInstance3D], fov_deg: float) -> void:
	for mi in meshes:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(&"viewmodel_fov", fov_deg)


## The lens FOV that keeps gun-vs-world magnification constant while the camera
## zooms (ADR-004 ADS): tan(eff/2) = tan(cam/2) * tan(vm/2) / tan(75/2).
## At cam = 75 this is exactly the weapon's authored viewmodel_fov.
static func effective_fov(vm_fov: float, cam_fov: float) -> float:
	var r: float = tan(deg_to_rad(clampf(vm_fov, 20.0, 120.0)) * 0.5) \
		/ tan(deg_to_rad(BASE_FOV) * 0.5)
	return rad_to_deg(atan(tan(deg_to_rad(clampf(cam_fov, 1.0, 179.0)) * 0.5) * r)) * 2.0


## On-screen magnification of the gun vs the world under the lens. Also the
## factor a world-space point must be pushed off-axis to LOOK attached to the
## drawn gun (apparent muzzle), and the divisor that keeps sway/punch feel
## constants reading the same as they did pre-lens.
static func magnification(vm_fov: float) -> float:
	return tan(deg_to_rad(BASE_FOV) * 0.5) \
		/ maxf(0.01, tan(deg_to_rad(clampf(vm_fov, 20.0, 120.0)) * 0.5))


## Where a world-space point on the true gun APPEARS to be when the gun is drawn
## through the lens: view-space x/y scaled by the magnification. Flash and laser
## visuals use this; rounds, noise and suppression keep the true position.
static func apparent_point(cam: Camera3D, vm_fov: float, world_pos: Vector3) -> Vector3:
	if cam == null:
		return world_pos
	var v: Vector3 = cam.global_transform.affine_inverse() * world_pos
	var r: float = magnification(vm_fov)
	v.x *= r
	v.y *= r
	return cam.global_transform * v
