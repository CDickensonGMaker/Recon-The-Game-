## probe_spawn_zoning.gd - PRE-CHECK for the world-build unification (Phase 1).
## Boots game_world at mission_seed 47225, prints heightmap min/max in METERS and a
## TerrainZoning.classify histogram over the spawn chunk. Answers: is the default spawn
## genuinely open-lowland, or everything-jungle-but-invisible? Evidence-gathering only.
extends Node

const SEED_VAL: int = 47225


func _ready() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
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
	var mss: int = hm.size

	# Whole-map min/max in meters.
	var mn: float = 1.0
	var mx: float = 0.0
	for h: float in hm.data:
		mn = minf(mn, h)
		mx = maxf(mx, h)
	print("=== PRE-CHECK seed %d ===" % SEED_VAL)
	print("[MAP] size=%dx%d cells, height_scale=%.0fm" % [mss, mss, hscale])
	print("[MAP] whole-map height: min=%.1fm max=%.1fm relief=%.1fm" % [
		mn * hscale, mx * hscale, (mx - mn) * hscale])
	print("[MAP] lowland ceiling = %.1fm (below = paddy/grassland, above = jungle)" % TerrainZoning._lowland_ceiling)

	# Spawn chunk = the 256m chunk containing AO center (map*0.5).
	var cs: float = world.terrain_manager.chunk_size
	var center: float = world.map_size * 0.5
	var chunk: Vector2i = Vector2i(int(center / cs), int(center / cs))
	var ox: float = chunk.x * cs
	var oz: float = chunk.y * cs
	print("[SPAWN] AO center=(%.0f,%.0f)  chunk=%s  covers x/z [%.0f..%.0f]" % [
		center, center, chunk, ox, ox + cs])

	# Histogram of TerrainZoning.classify over the spawn chunk, sampled every 8m.
	const NAMES: Array[String] = ["CLEAR", "RICE_PADDY", "GRASSLAND", "LIGHT_JUNGLE", "MEDIUM_JUNGLE", "HEAVY_JUNGLE"]
	var hist: Array[int] = [0, 0, 0, 0, 0, 0]
	var step: float = 8.0
	var samples: int = 0
	var chunk_mn: float = 1.0
	var chunk_mx: float = 0.0
	var wz: float = oz
	while wz < oz + cs:
		var wx: float = ox
		while wx < ox + cs:
			var h_norm: float = hm.sample_bilinear(wx / hm.cell_size, wz / hm.cell_size)
			chunk_mn = minf(chunk_mn, h_norm)
			chunk_mx = maxf(chunk_mx, h_norm)
			var h_m: float = h_norm * hscale
			var z: int = TerrainZoning.classify(h_m, wx, wz, SEED_VAL)
			hist[z] += 1
			samples += 1
			wx += step
		wz += step

	print("[SPAWN] chunk height: min=%.1fm max=%.1fm" % [chunk_mn * hscale, chunk_mx * hscale])
	print("[SPAWN] TerrainZoning.classify histogram over %d samples (8m grid):" % samples)
	for i in range(NAMES.size()):
		var pct: float = 100.0 * float(hist[i]) / float(maxi(1, samples))
		print("        %-14s %5d  (%.1f%%)" % [NAMES[i], hist[i], pct])

	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
