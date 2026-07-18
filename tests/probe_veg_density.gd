## probe_veg_density.gd - headless verification for asr5 (near-spawn jungle) and
## y5ad (hamlet brush). Boots the real world, drives the TREE_COVER _build_scatter over
## the spawn ring and a stand-in hamlet, and prints instance-density + bush histograms
## BEFORE and AFTER set_density_centers(). No GPU, no window - pure placement counts.
extends Node

const SEED_VAL: int = 47225
const VegManagerScript := preload("res://terrain/vegetation/vegetation_manager.gd")


func _ready() -> void:
	var world: GameWorld = load("res://scenes/levels/game_world.tscn").instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world timeout"); get_tree().quit(1); return

	var hm: Object = world.terrain_manager.heightmap
	var cs: float = world.terrain_manager.chunk_size

	var vm: VegetationManager = VegManagerScript.new()
	vm.canopy_source = VegManagerScript.CanopySource.TREE_COVER
	vm.mission_seed = SEED_VAL
	vm.cell_size = WorldConfig.CELL_SIZE
	vm._terrain_manager = world.terrain_manager
	add_child(vm)
	await get_tree().process_frame

	# A jungle-classified spawn point near AO center, and a stand-in hamlet 200m off.
	var spawn := Vector3(world.map_size * 0.5, 0.0, world.map_size * 0.5)
	spawn.y = world.terrain_manager.get_height_at(spawn)
	var village := Vector3(spawn.x + 200.0, 0.0, spawn.z + 60.0)
	village.y = world.terrain_manager.get_height_at(village)

	# Build the terrain grid for every chunk the two rings touch (so _build_scatter has it).
	var touched: Dictionary = {}
	for center: Vector3 in [spawn, village]:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var coord := Vector2i(int(center.x / cs) + dx, int(center.z / cs) + dz)
				touched[coord] = true
	for coord: Vector2i in touched:
		vm.generate_for_chunk(coord, hm, cs)

	# --- BASELINE (no density centers) ---
	var base_spawn := _ring_stats(vm, hm, cs, spawn, 38.0, touched)
	var base_vill := _ring_stats(vm, hm, cs, village, 44.0, touched)

	# Terrain class at the exact spawn bundle (bare-clearing check).
	const NAMES: Array[String] = ["CLEAR", "RICE_PADDY", "GRASSLAND", "LIGHT_JUNGLE", "MEDIUM_JUNGLE", "HEAVY_JUNGLE"]
	var spawn_class: int = vm.get_terrain_type_at(spawn, cs)

	# --- BOOSTED (real hook) ---
	vm.set_density_centers([
		{"pos": spawn, "radius": 38.0, "chance_floor": 0.9, "count_boost": 2},
		{"pos": village, "radius": 44.0, "chance_floor": 0.9, "count_boost": 3, "bush_bias": true},
	])
	var boost_spawn := _ring_stats(vm, hm, cs, spawn, 38.0, touched)
	var boost_vill := _ring_stats(vm, hm, cs, village, 44.0, touched)

	print("=== VEG DENSITY (seed %d) ===" % SEED_VAL)
	print("[SPAWN] bundle class = %s" % NAMES[spawn_class])
	print("[SPAWN ring 38m]  baseline: %d instances (%d bush)  ->  boosted: %d instances (%d bush)" % [
		base_spawn.total, base_spawn.bush, boost_spawn.total, boost_spawn.bush])
	print("[VILLAGE ring 44m] baseline: %d instances (%d bush)  ->  boosted: %d instances (%d bush)" % [
		base_vill.total, base_vill.bush, boost_vill.total, boost_vill.bush])

	# Determinism: same centers -> identical scatter.
	var d1 := _ring_stats(vm, hm, cs, spawn, 38.0, touched)
	var det_ok: bool = d1.total == boost_spawn.total and d1.bush == boost_spawn.bush

	var fails: int = 0
	if spawn_class == 0 or spawn_class == 1:
		print("FLAG: spawn bundle is %s (open) - LZ placement, not veg, owns this" % NAMES[spawn_class])
	if boost_spawn.total <= base_spawn.total:
		print("FAIL: spawn ring not denser after boost"); fails += 1
	if boost_vill.total <= base_vill.total:
		print("FAIL: village ring not denser after boost"); fails += 1
	if boost_vill.bush <= base_vill.bush:
		print("FAIL: village bush count did not rise under bush_bias"); fails += 1
	if base_spawn.total <= 0:
		print("FAIL: spawn ring empty even at baseline"); fails += 1
	if not det_ok:
		print("FAIL: boosted scatter non-deterministic across two builds"); fails += 1

	print("")
	if fails == 0:
		print("=== VEG DENSITY PASS (near-spawn + hamlet thickening live) ===")
		get_tree().quit(0)
	else:
		print("=== VEG DENSITY FAIL (%d) ===" % fails)
		get_tree().quit(1)


## Tally scatter instances whose origin falls within `radius` of `center`, across the
## chunks the ring spans. Returns {total, bush}.
func _ring_stats(vm: VegetationManager, hm: Object, cs: float, center: Vector3, radius: float, touched: Dictionary) -> Dictionary:
	var total: int = 0
	var bush: int = 0
	for coord: Vector2i in touched:
		var scatter: Array = vm._build_scatter(coord, hm, cs)
		for e: Dictionary in scatter:
			var xf: Transform3D = e.xf
			var d: float = Vector2(xf.origin.x - center.x, xf.origin.z - center.z).length()
			if d <= radius:
				total += 1
				if String(e.name).begins_with("bush_"):
					bush += 1
	return {"total": total, "bush": bush}
