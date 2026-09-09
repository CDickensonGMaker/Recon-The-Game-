## material_budget.gd - ADR-026 Part A material normalisation, applied in code at load.
## GLB-embedded materials are shared resources: mutating one here fixes every instance of
## that species/kit for the whole run, with no art re-export and no per-frame cost.
##
## TWO RULES, both measured 2026-09-08 (tools/probe_material_budget.gd):
##   FOLIAGE  - 40 impostor cards + 33 near-ring plant materials import as
##              TRANSPARENCY_ALPHA_DEPTH_PRE_PASS, which draws every leaf TWICE (depth
##              prepass, then a sorted blended pass) on a fill-bound frame. They are
##              cutouts, not glass: ALPHA_SCISSOR draws them once, opaque, unsorted.
##   SANDBAGS - 48 `Sandbags*` materials on solid close-range geometry (helipad, firebase,
##              MG nest, revetments) also import DEPTH_PRE_PASS. Sandbags have no glass in
##              them; they are opaque.
##
## CULL IS DELIBERATELY NOT TOUCHED. Measured: every foliage card is a crossed pair of
## single-sided quads (0 of 40 are back-to-back) and 116 of 117 near-ring solids are open
## shells. Back-face culling this jungle would hole it, not cheapen it - which is exactly
## the carve-out ADR-026 Part A.2 already grants.
##
## Reversal is one move: launch with `--perf-before` and nothing here is applied (that same
## flag also restores the pre-fix full-resolution render scale - see GameSettings).
class_name MaterialBudget
extends RefCounted

const SCISSOR_THRESHOLD: float = 0.4
const DISABLE_FLAG := "--perf-before"

static var _enabled: int = -1  ## -1 unknown, 0 off, 1 on


static func enabled() -> bool:
	if _enabled < 0:
		_enabled = 0 if GameSettings.has_flag(DISABLE_FLAG) else 1
	return _enabled == 1


## Cutout-ise every surface of a foliage mesh. Returns the same mesh for call-site chaining.
static func foliage(mesh: Mesh) -> Mesh:
	if mesh == null or not enabled():
		return mesh
	for s in mesh.get_surface_count():
		_cutout(mesh.surface_get_material(s) as BaseMaterial3D)
	return mesh


## Opaque-ise every surface of a solid prop mesh (rocks). A rock has no cutout in it, so
## the foliage scissor path would be a lie about the material. Same chaining contract.
static func solid(mesh: Mesh) -> Mesh:
	if mesh == null or not enabled():
		return mesh
	for s in mesh.get_surface_count():
		_solid(mesh.surface_get_material(s) as BaseMaterial3D)
	return mesh


## Walk an instantiated structure kit and open up its opaque-but-blended surfaces.
static func structure(root: Node) -> void:
	if root == null or not enabled():
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				_solid(mi.mesh.surface_get_material(s) as BaseMaterial3D)
		for c: Node in n.get_children():
			stack.push_back(c)


static func _cutout(m: BaseMaterial3D) -> void:
	if m == null:
		return
	if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS \
			or m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = SCISSOR_THRESHOLD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED


## Named by the artist's material, not by the mesh name: the same `Sandbags` material is
## shared across the helipad revetments, the firebase parapets and the MG nest, and the
## meshes carrying it are named after their site, not their surface.
static func _solid(m: BaseMaterial3D) -> void:
	if m == null or not m.resource_name.begins_with("Sandbags"):
		return
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
