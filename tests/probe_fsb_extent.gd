## probe_fsb_extent.gd - AUDIT PROBE 2026-09-07 (read-only measurement, no fix).
## test_asset_probe reports fsb_main_v3.glb largest=996.96m against a [250..300] band.
## A merged AABB that large means SOMETHING in the firebase GLB sits hundreds of metres
## from the model origin. This probe names it: the 15 mesh nodes furthest from origin,
## and the merged AABB with and without them. Godot culls per-MeshInstance3D, so a wide
## merged AABB is not by itself a culling bug - this probe measures WHAT, not WHY.
## Run: godot --headless --path . res://tests/probe_fsb_extent.tscn
extends Node

const FSB := "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"


func _ready() -> void:
	get_tree().create_timer(900.0).timeout.connect(func() -> void: get_tree().quit(3))
	var scene: PackedScene = load(FSB) as PackedScene
	if scene == null:
		print("FAIL: cannot load %s" % FSB)
		get_tree().quit(1)
		return
	var inst: Node = scene.instantiate()
	add_child(inst)
	var rows: Array = []
	var merged := AABB()
	var first := true
	_walk(inst, inst, rows, merged, first)
	# recompute merged properly (AABB is a value type; _walk returns nothing)
	var all := AABB()
	var seeded := false
	for r: Dictionary in rows:
		var b: AABB = r["aabb"]
		if not seeded:
			all = b
			seeded = true
		else:
			all = all.merge(b)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) > float(b["dist"]))
	print("MESHES=%d" % rows.size())
	print("MERGED AABB pos=%s size=%s largest=%.2fm" % [all.position, all.size,
		maxf(all.size.x, maxf(all.size.y, all.size.z))])
	print("--- 15 furthest mesh nodes from model origin ---")
	for i in mini(15, rows.size()):
		var r: Dictionary = rows[i]
		print("  %7.2fm  %s  (aabb size %s)" % [float(r["dist"]), String(r["name"]),
			(r["aabb"] as AABB).size])
	# What the merged AABB would be with everything beyond 200m dropped.
	var near := AABB()
	var nseed := false
	var dropped: int = 0
	for r: Dictionary in rows:
		if float(r["dist"]) > 200.0:
			dropped += 1
			continue
		var b: AABB = r["aabb"]
		if not nseed:
			near = b
			nseed = true
		else:
			near = near.merge(b)
	print("--- dropping %d mesh node(s) past 200m ---" % dropped)
	print("NEAR AABB size=%s largest=%.2fm" % [near.size,
		maxf(near.size.x, maxf(near.size.y, near.size.z))])
	get_tree().quit(0)


func _walk(n: Node, root: Node, rows: Array, merged: AABB, first: bool) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var xf: Transform3D = (root as Node3D).global_transform.affine_inverse() \
				* mi.global_transform
			var b: AABB = xf * mi.mesh.get_aabb()
			rows.append({"name": mi.name, "aabb": b,
				"dist": b.get_center().length()})
	for c in n.get_children():
		_walk(c, root, rows, merged, first)
