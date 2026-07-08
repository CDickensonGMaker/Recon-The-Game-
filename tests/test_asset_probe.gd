## test_asset_probe.gd - NS05: instantiate every imported GLB, probe merged AABB,
## flag scale anomalies. Run: godot --headless --path . res://tests/test_asset_probe.tscn
extends Node

## model path -> [min_dimension_m, max_dimension_m] expected band (largest axis)
const EXPECTED := {
	"res://assets/models/structures/village/thatched_hut.glb": [2.0, 12.0],
	"res://assets/models/structures/village/stilt_house.glb": [2.0, 14.0],
	"res://assets/models/structures/village/well.glb": [0.5, 6.0],
	"res://assets/models/structures/firebase/hootch.glb": [2.0, 14.0],
	"res://assets/models/structures/firebase/observation_tower.glb": [3.0, 14.0],
	"res://assets/models/structures/firebase/mg_nest.glb": [1.0, 8.0],
	"res://assets/models/structures/firebase/sandbag_bunker.glb": [1.0, 10.0],
	"res://assets/models/structures/vc_nva/weapons_cache.glb": [0.5, 8.0],
	"res://assets/models/vehicles/huey.glb": [6.0, 32.0],  # raw GLB oversized; CollisionTable scale 0.55 compensates at runtime
	"res://assets/models/vehicles/us_m24_tank.glb": [3.0, 10.0],
	"res://assets/models/vehicles/m113_apc.glb": [2.0, 9.0],
	"res://assets/models/aircraft/a1_skyraider.glb": [6.0, 18.0],
	"res://assets/models/ordnance/Bomb_500lb_Mk82.glb": [0.5, 4.0],
}


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	var checked: int = 0
	var dirs := [
		"res://assets/models/structures/village",
		"res://assets/models/structures/firebase",
		"res://assets/models/structures/vc_nva",
		"res://assets/models/vehicles",
		"res://assets/models/aircraft",
		"res://assets/models/ordnance",
	]
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			print("FAIL: missing dir %s" % dir_path)
			failures += 1
			continue
		for f in dir.get_files():
			if not f.ends_with(".glb"):
				continue
			var path := "%s/%s" % [dir_path, f]
			var scene: PackedScene = load(path)
			if scene == null:
				print("FAIL: cannot load %s" % path)
				failures += 1
				continue
			var inst := scene.instantiate()
			add_child(inst)
			var aabb := _merged_aabb(inst)
			var largest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
			checked += 1
			var band: Array = EXPECTED.get(path, [])
			var verdict := "ok"
			if band.size() == 2:
				if largest < float(band[0]) or largest > float(band[1]):
					verdict = "OUT-OF-BAND [%s..%s]" % [band[0], band[1]]
					failures += 1
			elif largest > 60.0 or largest < 0.05:
				verdict = "SUSPICIOUS"
				failures += 1
			print("%s largest=%.2fm %s" % [f, largest, verdict])
			inst.queue_free()

	print("checked=%d failures=%d" % [checked, failures])
	if failures == 0 and checked > 30:
		print("PASS: all GLBs within expected scale bands")
		get_tree().quit(0)
	else:
		print("FAIL: %d scale/load failures" % failures)
		get_tree().quit(1)


func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var xf: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
			var box: AABB = xf * mi.get_aabb()
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c in n.get_children():
			stack.push_back(c)
	return result
