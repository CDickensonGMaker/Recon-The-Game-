## probe_fell_visual.gd - the live-jungle felling swap, measured (decree 2026-08-04:
## support fires must drop trees in the REAL world, not only on the bench).
## Stands a HEAVY_JUNGLE chunk through the real TreeCoverLayer, blasts clear_area at
## its centre, and asserts: instances inside the hole leave the batched scatter, a
## capped number of felling visuals spawn, and each has hinged over by settle time.
## Run: godot --headless --path . res://tools/probe_fell_visual.tscn
extends Node3D


class FlatMap:
	extends RefCounted

	func sample_world(_x: float, _z: float) -> float:
		return 12.0

	func get_normal_world(_x: float, _z: float) -> Vector3:
		return Vector3.UP


func _ready() -> void:
	var vm := VegetationManager.new()
	vm.canopy_source = VegetationManager.CanopySource.TREE_COVER
	vm.mission_seed = 1234
	add_child(vm)
	var hm := FlatMap.new()
	var chunk := Vector2i(0, 0)
	vm._bundles_per_chunk = int(256.0 / vm.bundle_meters)
	var bytes := PackedByteArray()
	bytes.resize(vm._bundles_per_chunk * vm._bundles_per_chunk)
	bytes.fill(VegetationManager.TerrainType.HEAVY_JUNGLE)
	vm._chunk_terrain[chunk] = bytes
	var before: int = vm._build_scatter(chunk, hm, 256.0).size()
	vm.clear_area(Vector3(128.0, 0.0, 128.0), 12.0, 256.0, hm)
	await get_tree().create_timer(2.5).timeout
	var after: int = vm._build_scatter(chunk, hm, 256.0).size()
	var fallen: int = vm._fallen_visuals.size()
	var tipped: int = 0
	for f in vm._fallen_visuals:
		if is_instance_valid(f) and (f as Node3D).basis.get_euler().length() > 1.0:
			tipped += 1
	print("[FELL] scatter %d -> %d (hole removed %d) | felling visuals %d (cap %d) | hinged over %d"
		% [before, after, before - after, fallen, VegetationManager.FELL_MAX_PER_BLAST, tipped])
	if after < before and fallen > 0 and fallen <= VegetationManager.FELL_MAX_PER_BLAST and tipped == fallen:
		print("PASS: the live canopy drops real falling trees where the blast cleared it")
		get_tree().quit(0)
	else:
		print("FAIL: felling swap did not behave")
		get_tree().quit(1)
