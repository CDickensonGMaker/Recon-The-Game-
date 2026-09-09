## probe_interior_fold.gd - the FOLD PLAN for the 545 firebase interior props, measured
## before anything is built.
##
## probe_interior_pop.gd counted the problem (545 nodes, 1010 surfaces, 43,941 tris, all
## arriving in one frame at 40 m). This answers the two questions the fix turns on:
##   1. How many DISTINCT meshes are behind those 545 nodes? That is the MultiMesh count,
##      and it decides whether "1010 surfaces -> ~11" is real or optimistic.
##   2. How far out is each prop TYPE genuinely sub-pixel? The 40 m range was a guess; the
##      range should come off the prop's own size and the shipped projection, not a number
##      somebody liked.
##   godot --headless --path . -s res://tools/probe_interior_fold.gd
extends SceneTree

const FSB := "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
const PREFIX := "fb_int_"

## The shipped projection. Vertical FOV 75 deg is the player's hip lens (ADR-004); 720p at the
## ratified 0.75 render scale is 540 rendered rows (PERF_LEDGER 2026-09-08, and the viewport
## reads 0.750 in every bench run). A thing of height h metres at distance d covers
## h * ROWS / (2 * tan(fov/2) * d) rows. Solve for the distance at which it covers PX rows.
const ROWS: float = 540.0
const FOV_DEG: float = 75.0
## Two rendered pixels. Chosen to match `mesh_lod/lod_change/threshold_pixels=2.0`, the error
## this project already accepts for swapping a whole LOD level - NOT a new standard, and this
## probe does not touch that setting (it is an open ruling).
const PX: float = 2.0


func _initialize() -> void:
	if not ResourceLoader.exists(FSB):
		print("[INTFOLD] firebase GLB not found at %s" % FSB)
		quit(1)
		return
	var root: Node = (load(FSB) as PackedScene).instantiate()
	## mesh RID -> {name, count, surfaces, size, tris}
	var by_mesh: Dictionary = {}
	var nodes: int = 0
	var surfaces_now: int = 0
	var tris_once: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).begins_with(PREFIX):
			continue
		nodes += 1
		surfaces_now += mi.mesh.get_surface_count()
		var key: String = str(mi.mesh.get_rid())
		if not by_mesh.has(key):
			var aabb: AABB = mi.mesh.get_aabb()
			var t: int = 0
			for si in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				t += (idx.size() / 3) if idx.size() > 0 else (v.size() / 3)
			tris_once += t
			by_mesh[key] = {
				"name": String(mi.name),
				"count": 0,
				"surfaces": mi.mesh.get_surface_count(),
				"size": maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)),
				"tris": t,
			}
		(by_mesh[key] as Dictionary)["count"] += 1

	var k: float = ROWS / (2.0 * tan(deg_to_rad(FOV_DEG) * 0.5) * PX)
	print("[INTFOLD] %d '%s' node(s) share %d DISTINCT mesh(es)" % [nodes, PREFIX, by_mesh.size()])
	print("[INTFOLD] surfaces drawn today: %d | one MultiMesh per mesh would be: %d"
		% [surfaces_now, _sum(by_mesh, "surfaces")])
	print("[INTFOLD] unique geometry %d tris (against %d tris of baked copies)"
		% [tris_once, _instanced_tris(by_mesh)])
	print("[INTFOLD] %.1f-pixel distance = size_m x %.1f  (vfov %.0f, %d rendered rows)"
		% [PX, k, FOV_DEG, int(ROWS)])
	print("[INTFOLD] %-38s %5s %4s %8s %9s %9s" % ["representative node", "inst", "surf", "tris", "size m", "%.0fpx m" % PX])
	var rows: Array = by_mesh.values()
	rows.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	for r: Dictionary in rows:
		print("[INTFOLD] %-38s %5d %4d %8d %9.2f %9.1f"
			% [r["name"], r["count"], r["surfaces"], r["tris"], r["size"], float(r["size"]) * k])
	for bands in [1, 4, 6, 8, 10]:
		print("[INTFOLD] with %2d stagger band(s): up to %4d MultiMesh(es), %4d draw call(s) - %.0f%% of today"
			% [bands, by_mesh.size() * bands, _sum(by_mesh, "surfaces") * bands,
				float(_sum(by_mesh, "surfaces") * bands) / float(surfaces_now) * 100.0])
	root.free()
	quit(0)


func _sum(d: Dictionary, field: String) -> int:
	var n: int = 0
	for r: Dictionary in d.values():
		n += int(r[field])
	return n


func _instanced_tris(d: Dictionary) -> int:
	var n: int = 0
	for r: Dictionary in d.values():
		n += int(r["tris"]) * int(r["count"])
	return n
