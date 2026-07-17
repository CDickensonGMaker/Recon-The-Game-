## probe_tree_cover_wired.gd - Phase 2: proves TreeCoverLayer is wired LIVE-CAPABLE through
## VegetationManager's CanopySource.TREE_COVER path (not a built-ahead-of-wiring fossil).
## Drives the real VM._build_scatter -> TreeCoverLayer.generate_for_chunk and asserts the
## mechanism produces near+far render + cover colliders. Also MEASURES the resident collider
## count across the whole AO (evidence for the pooled-ring bead - the resident-all count is a
## landmine that the switchover must replace with a player-keyed ring).
extends Node

const SEED_VAL: int = 47225
const VegManagerScript := preload("res://terrain/vegetation/vegetation_manager.gd")


func _ready() -> void:
	# A booted world gives a real, configured heightmap (TerrainZoning ceiling set).
	var world: GameWorld = load("res://scenes/levels/game_world.tscn").instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world timeout")
		get_tree().quit(1)
		return

	var hm: Object = world.terrain_manager.heightmap
	var cs: float = world.terrain_manager.chunk_size
	var per_side: int = int(ceil(world.map_size / cs))

	# A SECOND vegetation manager flipped to TREE_COVER, driven over the whole AO.
	var vm: VegetationManager = VegManagerScript.new()
	vm.canopy_source = VegManagerScript.CanopySource.TREE_COVER
	vm.mission_seed = SEED_VAL
	vm.cell_size = WorldConfig.CELL_SIZE
	vm._terrain_manager = world.terrain_manager
	add_child(vm)
	await get_tree().process_frame  # let _ready run (creates TreeCoverLayer, loads species)

	var species_loaded: int = vm._tree_cover._solid_mesh.size() if vm._tree_cover != null else 0

	# Build the spawn chunk first so its _chunk_terrain grid exists, then check determinism:
	# same seed + chunk -> identical scatter.
	vm.generate_for_chunk(Vector2i(2, 2), hm, cs)
	var s1: Array = vm._build_scatter(Vector2i(2, 2), hm, cs)
	var s2: Array = vm._build_scatter(Vector2i(2, 2), hm, cs)
	var det_ok: bool = _scatter_hash(s1) == _scatter_hash(s2)

	# Build the WHOLE AO through the TREE_COVER path (measures resident collider load).
	var t0: int = Time.get_ticks_msec()
	for z in range(per_side):
		for x in range(per_side):
			vm.generate_for_chunk(Vector2i(x, z), hm, cs)
	var build_ms: int = Time.get_ticks_msec() - t0

	var colliders: int = vm._tree_cover.collider_count()
	var tc_nodes: int = vm._tree_cover.get_child_count()

	print("=== TREE_COVER WIRED (seed %d) ===" % SEED_VAL)
	print("species solids loaded: %d" % species_loaded)
	print("spawn-chunk scatter size: %d (determinism %s)" % [s1.size(), "OK" if det_ok else "FAIL"])
	print("whole-AO TreeCoverLayer: %d child nodes, %d resident cover colliders, build %dms" % [
		tc_nodes, colliders, build_ms])

	var fails: int = 0
	if species_loaded <= 0:
		print("FAIL: no species solids loaded"); fails += 1
	if s1.is_empty():
		print("FAIL: TREE_COVER scatter empty on a jungle spawn chunk"); fails += 1
	if not det_ok:
		print("FAIL: TREE_COVER scatter non-deterministic"); fails += 1
	if colliders <= 0:
		print("FAIL: no cover colliders - Pillar-3 cover mechanism not live"); fails += 1
	if tc_nodes <= 0:
		print("FAIL: TreeCoverLayer built no render nodes"); fails += 1

	print("")
	if fails == 0:
		print("=== TREE_COVER WIRED PASS (mechanism live-capable) ===")
		print("NOTE: %d resident colliders is the landmine the switchover must replace with a pooled ring." % colliders)
		get_tree().quit(0)
	else:
		print("=== TREE_COVER WIRED FAIL (%d) ===" % fails)
		get_tree().quit(1)


func _scatter_hash(scatter: Array) -> int:
	var acc: int = 0
	for e: Dictionary in scatter:
		var xf: Transform3D = e.xf
		acc = (acc + hash([String(e.name), xf.origin])) % 0x7FFFFFFF
	return acc
