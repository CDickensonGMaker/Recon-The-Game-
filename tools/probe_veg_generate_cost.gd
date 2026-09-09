## probe_veg_generate_cost.gd - WHERE DO THE MILLISECONDS IN A CANOPY REBUILD ACTUALLY GO?
##
## `terrain.veg_generate` was measured at 62.8 ms for a SINGLE chunk on a distant napalm strike
## (2026-09-09, night). That span wraps the whole rebuild and says nothing about WHICH part is
## expensive, so any fix aimed at it would be a guess. This splits it.
##
## CPU spans are honest headless - they are script time, not a GPU bucket. What is NOT honest
## headless is anything the renderer stores (MultiMesh transform read-back), so this probe times
## work and never inspects rendered state.
##
##   godot --headless --path . res://tools/probe_veg_generate_cost.tscn -- --test-save
extends Node

const REBUILDS: int = 12


func _ready() -> void:
	await get_tree().process_frame
	var seed_v: int = 29072026
	var map_v: float = 512.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--probe-seed="):
			seed_v = int(a.get_slice("=", 1))
		if a.begins_with("--probe-map="):
			map_v = float(a.get_slice("=", 1))
	print("\n=== CANOPY REBUILD COST (seed %d, map %.0f m) ===\n" % [seed_v, map_v])

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = seed_v
	world.spawn_player_on_ready = false
	world.map_size = map_v
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 900:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  FAIL: world never became ready")
		get_tree().quit(1)
		return

	var vm: VegetationManager = world.vegetation_manager
	var tc: Node = vm.get_node_or_null("TreeCoverLayer")
	if tc == null:
		print("  FAIL: no TreeCoverLayer")
		get_tree().quit(1)
		return

	# The heaviest resident chunk, so the number is a worst case and not an average.
	var target := Vector2i.ZERO
	var most: int = -1
	for coord: Vector2i in (tc.get("_chunk_scatter") as Dictionary):
		var n: int = ((tc.get("_chunk_scatter") as Dictionary)[coord] as Array).size()
		if n > most:
			most = n
			target = coord
	print("  rebuilding chunk %s (%d plants) x%d" % [target, most, REBUILDS])

	StallLedger.enable()
	for _i in REBUILDS:
		vm.rebuild_chunk(target)
		await get_tree().process_frame

	var total: Dictionary = StallLedger._total
	var count: Dictionary = StallLedger._count
	var worst: Dictionary = StallLedger._worst_call
	var keys: Array = total.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(total[a]) > int(total[b]))
	print("\n  %-22s %10s %10s %8s" % ["span", "mean ms", "worst ms", "calls"])
	for k: String in keys:
		var c: int = maxi(1, int(count.get(k, 1)))
		print("  %-22s %10.2f %10.2f %8d"
			% [k, float(total[k]) / 1000.0 / float(c), float(worst.get(k, 0)) / 1000.0, c])
	print("\n  veg.build_scatter is the DATA (what is planted); the mmi.* spans are the DRAW")
	print("  (grouping, MultiMesh construction, node add). A fix that keeps the outcome identical")
	print("  and degrades presentation can only touch the mmi.* half.")
	get_tree().quit(0)
