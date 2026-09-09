## probe_heightfield_shape.gd - CAN A HEIGHTFIELD STAND IN FOR THE TERRAIN TRIMESH?
##
## The question is not "is it faster" (it is, trivially - one array copy against building a
## 32,768-triangle BVH). The question is whether a bullet and a boot land in the SAME PLACE,
## because terrain collision is what ballistics hits. Two things could break that and neither
## can be settled by reading the docs:
##   1. HeightMapShape3D has NO cell size - it is one unit per sample - so a 2m grid needs a
##      non-uniformly SCALED collision shape, and Jolt does not accept every scale.
##   2. The engine picks its own diagonal when it splits a cell into two triangles. If it
##      disagrees with terrain_chunk.build_mesh (which splits (x+1,z)-(x,z+1)), the surface
##      differs by up to half the cell's height range along that seam.
##
## Synthetic ground on purpose: an analytic surface makes the expected answer computable, so a
## disagreement is attributable to the SHAPE rather than to the terrain generator.
##
##   godot --headless --path . res://tools/probe_heightfield_shape.tscn
extends Node

const SAMPLES: int = 129          ## terrain_manager.chunk_cells
const CELL: float = 2.0           ## terrain_manager.cell_size
const SPAN: float = float(SAMPLES - 1) * CELL   ## 256m
const RAYS: int = 4000

var _fails: int = 0
var _heights: PackedFloat32Array = PackedFloat32Array()


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s -- %s" % ["PASS" if ok else "FAIL", label, detail])


## Deliberately steep and lumpy: a flat plane would hide a diagonal mismatch completely.
func _h(x: float, z: float) -> float:
	return 18.0 * sin(x * 0.031) + 12.0 * cos(z * 0.047) + 0.06 * x + 0.04 * z


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== HEIGHTFIELD vs TRIMESH: does the ground stay where it was? ===\n")

	_heights.resize(SAMPLES * SAMPLES)
	for z in SAMPLES:
		for x in SAMPLES:
			_heights[z * SAMPLES + x] = _h(float(x) * CELL, float(z) * CELL)

	var tri: StaticBody3D = _make_trimesh_body()
	tri.collision_layer = 1
	add_child(tri)
	var t0: int = Time.get_ticks_usec()
	var hf: StaticBody3D = _make_heightfield_body()
	var hf_us: int = Time.get_ticks_usec() - t0
	hf.collision_layer = 2
	add_child(hf)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 47225
	var worst: float = 0.0
	var sum: float = 0.0
	var n: int = 0
	var tri_miss: int = 0
	var hf_miss: int = 0
	var worst_at := Vector2.ZERO
	for _i in RAYS:
		# Stay a cell in from the rim: the trimesh ends there, the heightfield's edge
		# behaviour is its own question and would swamp the surface comparison.
		var wx: float = rng.randf_range(CELL, SPAN - CELL)
		var wz: float = rng.randf_range(CELL, SPAN - CELL)
		var a: Variant = _drop(space, wx, wz, 1)
		var b: Variant = _drop(space, wx, wz, 2)
		if a == null:
			tri_miss += 1
			continue
		if b == null:
			hf_miss += 1
			continue
		var d: float = absf(float(a) - float(b))
		sum += d
		n += 1
		if d > worst:
			worst = d
			worst_at = Vector2(wx, wz)

	print("  heightfield shape built in %.2f ms (%d samples)" % [float(hf_us) / 1000.0, SAMPLES * SAMPLES])
	_check("the trimesh answers every ray", tri_miss == 0, "%d/%d missed" % [tri_miss, RAYS])
	_check("the HEIGHTFIELD answers every ray (a rejected scale answers none)",
		hf_miss == 0, "%d/%d missed" % [hf_miss, RAYS])
	if n > 0:
		print("  ground height delta over %d rays: mean %.4f m, WORST %.4f m at (%.1f, %.1f)"
			% [n, sum / float(n), worst, worst_at.x, worst_at.y])
	_check("the two surfaces agree to within 1 cm", n > 0 and worst < 0.01,
		"worst %.4f m" % worst)

	print("")
	print("*** %s ***" % ("HEIGHTFIELD IS A DROP-IN" if _fails == 0
		else "%d FAILURE(S) - it is NOT a drop-in as configured" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _drop(space: PhysicsDirectSpaceState3D, wx: float, wz: float, mask: int) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(wx, 500.0, wz), Vector3(wx, -500.0, wz))
	q.collision_mask = mask
	var r: Dictionary = space.intersect_ray(q)
	if r.is_empty():
		return null
	return (r["position"] as Vector3).y


## The same winding and the same diagonal as terrain_chunk.build_mesh.
func _make_trimesh_body() -> StaticBody3D:
	var verts := PackedVector3Array()
	var res: int = SAMPLES - 1
	verts.resize(res * res * 6)
	var w: int = 0
	for z in res:
		for x in res:
			var v0 := Vector3(x * CELL, _heights[z * SAMPLES + x], z * CELL)
			var v1 := Vector3((x + 1) * CELL, _heights[z * SAMPLES + x + 1], z * CELL)
			var v2 := Vector3(x * CELL, _heights[(z + 1) * SAMPLES + x], (z + 1) * CELL)
			var v3 := Vector3((x + 1) * CELL, _heights[(z + 1) * SAMPLES + x + 1], (z + 1) * CELL)
			verts[w] = v0; w += 1
			verts[w] = v1; w += 1
			verts[w] = v2; w += 1
			verts[w] = v1; w += 1
			verts[w] = v3; w += 1
			verts[w] = v2; w += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = am.create_trimesh_shape()
	body.add_child(cs)
	return body


## HeightMapShape3D is CENTRED on its own origin and spans one unit per sample, so a 2m grid
## needs a (CELL, 1, CELL) scale and a half-span offset to sit where the mesh sits.
func _make_heightfield_body() -> StaticBody3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = SAMPLES
	shape.map_depth = SAMPLES
	shape.map_data = _heights
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(
		Basis.IDENTITY.scaled(Vector3(CELL, 1.0, CELL)),
		Vector3(SPAN * 0.5, 0.0, SPAN * 0.5))
	body.add_child(cs)
	return body
