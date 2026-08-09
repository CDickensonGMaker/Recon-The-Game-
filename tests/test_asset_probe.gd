## test_asset_probe.gd - NS05: instantiate every imported GLB, probe merged AABB,
## flag scale anomalies. Run: godot --headless --path . res://tests/test_asset_probe.tscn
extends Node

## model path -> [min_dimension_m, max_dimension_m] expected band (largest axis)
const EXPECTED := {
	"res://assets/world/building models/structures/village/nha_tranh_01.glb": [2.0, 12.0],
	"res://assets/world/building models/structures/village/nha_san_01.glb": [2.0, 14.0],
	"res://assets/world/building models/structures/village/village_well_01.glb": [0.5, 6.0],
	"res://assets/world/building models/structures/firebase/fsb_main_v3.glb": [250.0, 300.0],
	"res://assets/world/building models/structures/vc_nva/weapons_cache.glb": [0.5, 8.0],
	# huey.glb is v1 (17.46m, ~30% overlong) and no longer wired to huey.tscn - kept only
	# because the four heli_*.glb staged clips still bake its geometry. huey_v3.glb is live.
	"res://assets/us/vehicles/huey.glb": [6.0, 32.0],
	"res://assets/us/vehicles/huey_v3.glb": [12.0, 16.0],  # 14.63 = main rotor span
	"res://assets/us/vehicles/m113_apc.glb": [2.0, 9.0],
	"res://assets/us/aircraft/a1_skyraider.glb": [6.0, 18.0],
	"res://assets/us/aircraft/ac47_spooky.glb": [26.0, 32.0],  # true DC-3 span 28.96m via import root_scale 0.1475; source blend keeps its working scale

	"res://assets/world/building models/ordnance/Bomb_500lb_Mk82.glb": [0.5, 4.0],
}


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	var checked: int = 0
	var dirs := [
		"res://assets/world/building models/structures/village",
		"res://assets/world/building models/structures/firebase",
		"res://assets/world/building models/structures/vc_nva",
		"res://assets/us/vehicles",
		"res://assets/us/aircraft",
		"res://assets/world/building models/ordnance",
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
