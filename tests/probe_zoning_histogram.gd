## probe_zoning_histogram.gd - Phase 2 zoning tuning: whole-map TerrainZoning.classify
## histogram on a booted world, so the dense-jungle-with-clearings distribution + the
## relative paddy gate can be read and tuned. Evidence-gathering.
extends Node

const SEED_VAL: int = 47225


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
		print("FAIL: world timeout")
		get_tree().quit(1)
		return

	var hm: Object = world.terrain_manager.heightmap
	var hscale: float = hm.height_scale
	var bounds: float = world.map_size

	print("=== ZONING HISTOGRAM seed %d ===" % SEED_VAL)
	print("[MAP] lowland ceiling = %.1fm (LOWLAND_RELIEF_FRACTION=%.2f)" % [
		TerrainZoning._lowland_ceiling, TerrainZoning.LOWLAND_RELIEF_FRACTION])

	const NAMES: Array[String] = ["CLEAR", "RICE_PADDY", "GRASSLAND", "LIGHT_JUNGLE", "MEDIUM_JUNGLE", "HEAVY_JUNGLE"]
	var hist: Array[int] = [0, 0, 0, 0, 0, 0]
	var step: float = 8.0
	var samples: int = 0
	var wz: float = 0.0
	while wz < bounds:
		var wx: float = 0.0
		while wx < bounds:
			var h_m: float = hm.sample_bilinear(wx / hm.cell_size, wz / hm.cell_size) * hscale
			var z: int = TerrainZoning.classify(h_m, wx, wz, SEED_VAL)
			hist[z] += 1
			samples += 1
			wx += step
		wz += step

	print("[MAP] whole-map classify histogram over %d samples (8m grid):" % samples)
	for i in range(NAMES.size()):
		var pct: float = 100.0 * float(hist[i]) / float(maxi(1, samples))
		print("        %-14s %6d  (%.1f%%)" % [NAMES[i], hist[i], pct])
	var jungle: float = 100.0 * float(hist[3] + hist[4] + hist[5]) / float(maxi(1, samples))
	var open_pct: float = 100.0 * float(hist[0] + hist[1] + hist[2]) / float(maxi(1, samples))
	print("[MAP] jungle(L+M+H)=%.1f%%  open(clear+paddy+grass)=%.1f%%  paddy=%.1f%%" % [
		jungle, open_pct, 100.0 * float(hist[1]) / float(maxi(1, samples))])

	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
