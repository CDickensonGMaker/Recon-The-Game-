## probe_far_ring_meshes.gd - FAR-RING CONVERSION AUDIT (Summoner 2026-09-08: all 3D models).
## Triangle count cannot tell a model from a card; NORMAL DISTRIBUTION can. This is the same
## audit that caught fallen_log_a/b posing as 3D (184 tris, 12 normals, 90.9% one sheet).
## For every species TreeCoverLayer actually plants, report:
##   distinct facings, % triangle AREA on the single dominant plane, AABB thinnest-axis ratio,
##   and the import-generated LOD ladder (tris per level) that the far ring will draw.
##   godot --headless --path . -s res://tools/probe_far_ring_meshes.gd
extends SceneTree

const SOLID_DIR := "res://assets/world/vegetation/"
const CARD_DIR := "res://assets/world/vegetation/cards/"

## Verbatim union of vegetation_manager.gd TYPE_SPECIES (what the world plants).
const LIVE := [
	"rice_a", "rice_b",
	"tall_grass_a", "tall_grass_b", "elephant_grass_a", "elephant_grass_b",
	"bush_a", "bush_b", "bush_c",
	"fern_a", "fern_b", "fern_c",
	"banana_a", "banana_b", "palm_sapling_a",
	"jungle_palm_a1", "jungle_palm_a2", "jungle_palm_b1", "jungle_palm_b2",
	"broadleaf_a", "broadleaf_b", "broadleaf_c",
	"bamboo_a", "bamboo_b", "bamboo_c",
	"liana_a", "vine_a",
]
## Cover-givers with a collider the player is invited to hide behind: flat = a lie.
const EXTRA := ["fallen_log_a", "fallen_log_b", "tree_stump", "felled_trunk", "felled_tree"]


func _initialize() -> void:
	print("\n=== FAR-RING MESH AUDIT (a plane must not come back as an optimisation) ===")
	print("%-20s %6s %6s %5s %7s %7s  %s" % ["species", "verts", "tris", "facg", "domPlan", "thin", "LOD ladder (tris)"])
	var verdicts: Dictionary = {}
	for nm: String in LIVE + EXTRA:
		var m: Mesh = _mesh(SOLID_DIR + nm + ".glb")
		if m == null:
			print("  %-20s  MISSING SOLID GLB" % nm)
			verdicts[nm] = "MISSING"
			continue
		verdicts[nm] = _report(nm, m)
	print("\n--- the cards being retired, for contrast ---")
	for nm: String in ["broadleaf_a", "bamboo_a", "bush_b", "fern_c"]:
		var c: Mesh = _mesh(CARD_DIR + nm + "_card.glb")
		if c != null:
			_report(nm + "_card", c)
	print("\n=== VERDICT ===")
	var flat: Array[String] = []
	for k: String in verdicts:
		if verdicts[k] == "FLAT":
			flat.append(k)
	print("  FLAT (no honest 3D mesh): %s" % (", ".join(flat) if not flat.is_empty() else "none"))
	quit(0)


## "FLAT" = the geometry is a picture, not a body. Two independent tests must both fail:
## dominant-plane area share (a card puts ~100% of its area on one plane) and the AABB's
## thinnest axis (a card has no depth). Either alone is fooled - a fan of quads spreads
## normals while staying thin; a crumpled sheet has depth but one facing.
func _report(label: String, mesh: Mesh) -> String:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tri_count: int = (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
	var facings: Array[Vector3] = []
	var area_by_facing: Array[float] = []
	var total_area: float = 0.0
	for t: int in tri_count:
		var a: Vector3 = verts[idx[t * 3]] if idx.size() > 0 else verts[t * 3]
		var b: Vector3 = verts[idx[t * 3 + 1]] if idx.size() > 0 else verts[t * 3 + 1]
		var c: Vector3 = verts[idx[t * 3 + 2]] if idx.size() > 0 else verts[t * 3 + 2]
		var cross: Vector3 = (b - a).cross(c - a)
		var area: float = cross.length() * 0.5
		if area <= 0.0000001:
			continue
		total_area += area
		var n: Vector3 = cross.normalized()
		var hit: int = -1
		for i: int in facings.size():
			# abs(): a plane and its back face are ONE plane, not two facings.
			if absf(facings[i].dot(n)) > 0.985:
				hit = i
				break
		if hit < 0:
			facings.append(n)
			area_by_facing.append(area)
		else:
			area_by_facing[hit] += area
	var dominant: float = 0.0
	for a: float in area_by_facing:
		dominant = maxf(dominant, a)
	var dom_pct: float = (dominant / total_area * 100.0) if total_area > 0.0 else 100.0
	var aabb: AABB = mesh.get_aabb()
	var s: Vector3 = aabb.size
	var thinnest: float = minf(s.x, minf(s.y, s.z))
	var largest: float = maxf(s.x, maxf(s.y, s.z))
	var thin: float = (thinnest / largest) if largest > 0.0 else 0.0
	var ladder: String = _lod_ladder(mesh)
	print("  %-20s %6d %6d %5d %6.1f%% %6.3f  %s"
		% [label, verts.size(), tri_count, facings.size(), dom_pct, thin, ladder])
	if dom_pct > 60.0 and thin < 0.10:
		return "FLAT"
	return "SOLID"


## The import-generated LOD levels on surface 0. This is what the far ring will actually
## draw: generate_lods=true is set on every vegetation GLB import, so promoting the SOLID
## to 350 m does NOT draw full detail at 350 m - it draws these.
func _lod_ladder(mesh: Mesh) -> String:
	var am := mesh as ArrayMesh
	if am == null:
		return "n/a (not ArrayMesh)"
	# ArrayMesh exposes no LOD accessor in 4.7 (surface_get_lods is ImporterMesh-only).
	# RenderingServer.mesh_get_surface() returns the surface as the RENDERER holds it,
	# "lods" included - that is the only truth about what will actually be drawn far away.
	var surf: Dictionary = RenderingServer.mesh_get_surface(am.get_rid(), 0)
	var lods: Array = surf.get("lods", [])
	if lods.is_empty():
		return "NO LODS - far ring draws full detail"
	var parts: Array[String] = []
	for i: int in lods.size():
		var e = lods[i]
		var n: int = 0
		if e is Dictionary:
			var ib = (e as Dictionary).get("index_data", PackedByteArray())
			# index_data is raw bytes: 2 per index if <=65535 verts, else 4.
			var stride: int = 4 if int(surf.get("vertex_count", 0)) > 65535 else 2
			n = (ib.size() / stride) / 3
			parts.append("d%.2f:%dt" % [float((e as Dictionary).get("edge_length", 0.0)), n])
		else:
			parts.append(str(e))
	return " ".join(parts)


func _mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var m: Mesh = _first(root)
	root.free()
	return m


func _first(node: Node) -> Mesh:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		return mi.mesh
	for c: Node in node.get_children():
		var r: Mesh = _first(c)
		if r != null:
			return r
	return null
