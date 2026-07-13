## probe_vegetation.gd - assert the jungle vegetation GLBs are game-ready.
## Pattern: tools/dump_viewmodels.gd. Checks per GLB: loads, has meshes,
## vertex colors present (the sway mask), mask spans base->tip (min R low,
## max R high), grounded near y=0, sane height (palms 4-10m, grass ~1m).
## Run: godot --headless --path . --script res://tools/probe_vegetation.gd
## Exits 1 on any failure.
extends SceneTree

const PALMS: Array[String] = [
	"jungle_palm_a1", "jungle_palm_a2", "jungle_palm_a3",
	"jungle_palm_b1", "jungle_palm_b2", "jungle_palm_b3",
]

var _failures: int = 0


func _init() -> void:
	for nm in PALMS:
		_probe("res://assets/world/vegetation/" + nm + ".glb", 4.0, 10.0)
	_probe("res://assets/world/vegetation/grass_fan.glb", 0.5, 1.5)
	if _failures > 0:
		print("[VEG PROBE] FAILED - %d problem(s)" % _failures)
		quit(1)
	else:
		print("[VEG PROBE] all vegetation GLBs PASS")
		quit(0)


func _fail(msg: String) -> void:
	_failures += 1
	print("  FAIL: ", msg)


func _probe(path: String, min_h: float, max_h: float) -> void:
	print("=== ", path)
	if not ResourceLoader.exists(path):
		_fail("missing")
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("load failed")
		return
	var inst: Node = packed.instantiate()
	var aabb := AABB()
	var first: bool = true
	var meshes: int = 0
	var tris: int = 0
	var surfaces: int = 0
	var colored_surfaces: int = 0
	var col_min: float = 99.0
	var col_max: float = -99.0
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		meshes += 1
		var a: AABB = mi.get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
		for s in range(mi.mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if cols.size() > 0:
				colored_surfaces += 1
				for c in cols:
					col_min = minf(col_min, c.r)
					col_max = maxf(col_max, c.r)
	inst.free()

	if meshes == 0:
		_fail("no MeshInstance3D with a mesh")
		return
	print("  meshes=%d surfaces=%d tris=%d aabb pos=%s size=%s colR=[%.2f..%.2f]" % [
		meshes, surfaces, tris, aabb.position, aabb.size, col_min, col_max])
	if colored_surfaces < surfaces:
		_fail("vertex colors missing on %d/%d surfaces (sway mask)" % [
			surfaces - colored_surfaces, surfaces])
	elif col_min > 0.15 or col_max < 0.7:
		_fail("sway mask range weak (want base<0.15, tips>0.7)")
	var height: float = aabb.size.y
	if height < min_h or height > max_h:
		_fail("height %.2fm outside [%.1f, %.1f]" % [height, min_h, max_h])
	if aabb.position.y < -0.5 or aabb.position.y > 0.5:
		_fail("not grounded: base y=%.2f (want ~0)" % aabb.position.y)
