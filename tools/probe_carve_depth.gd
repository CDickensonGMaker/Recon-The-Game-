## probe_carve_depth.gd - HOW DEEP IS THE CARVE ACTUALLY CUT?
##
## Compares the post-carve bed against the pre-carve grade the hydrology solved on
## (recovered from water_surface_full + CHANNEL_SURFACE_DROP) and reports how the
## bank samples _append_river_strip takes relate to that bed.
##
##   godot --headless --path . res://tools/probe_carve_depth.tscn
extends Node


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== CARVE DEPTH ===\n")

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = 47225
	world.spawn_player_on_ready = false
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 600:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  [FAIL] world never became ready")
		get_tree().quit(1)
		return

	var ws: WaterSystem = world.water_system
	var hm: RefCounted = ws._heightmap
	var hydro: RefCounted = ws._hydrology
	var surf: PackedFloat32Array = hydro.water_surface_full
	var hsize: int = hm.size
	var cs: float = hm.cell_size

	print("heightmap %dx%d  cell %.1fm  hydro downsample %d" % [hsize, hsize, cs, hydro.downsample])

	var n: int = 0
	var sum_carve: float = 0.0
	var max_carve: float = -INF
	var min_carve: float = INF
	var over3: int = 0
	var bank_eq_bed: int = 0
	var sum_bank_minus_bed: float = 0.0
	var sum_reach_minus_bed: float = 0.0
	var w_hist: Dictionary = {}

	for r in hydro.rivers:
		var points: PackedVector2Array = r["points"]
		var widths: PackedFloat32Array = r["widths"]
		for i in range(points.size()):
			var p: Vector2 = points[i]
			var half: float = widths[i] * 0.5
			var perp: Vector2 = ws._path_perpendicular(points, i)
			var cx: int = clampi(int(p.x / cs), 0, hsize - 1)
			var cz: int = clampi(int(p.y / cs), 0, hsize - 1)
			var s: float = surf[cz * hsize + cx]
			if s <= 0.0:
				continue
			var grade_pre: float = s + 0.65
			var bed: float = hm.sample_world(p.x, p.y)
			var carve: float = grade_pre - bed

			var bl: float = hm.sample_world(p.x - perp.x * half, p.y - perp.y * half)
			var br: float = hm.sample_world(p.x + perp.x * half, p.y + perp.y * half)
			var bank: float = minf(bl, br)
			var shoulder: float = maxf(half * 0.6, cs)
			var reach: float = half + shoulder
			var rl: float = hm.sample_world(p.x - perp.x * reach, p.y - perp.y * reach)
			var rr: float = hm.sample_world(p.x + perp.x * reach, p.y + perp.y * reach)

			n += 1
			sum_carve += carve
			max_carve = maxf(max_carve, carve)
			min_carve = minf(min_carve, carve)
			if carve > 3.0:
				over3 += 1
			if absf(bank - bed) < 0.05:
				bank_eq_bed += 1
			sum_bank_minus_bed += bank - bed
			sum_reach_minus_bed += minf(rl, rr) - bed
			var wb: int = int(widths[i])
			w_hist[wb] = int(w_hist.get(wb, 0)) + 1

	print("\n-- %d channel points measured --" % n)
	print("  intended carve            1.20 m")
	print("  ACTUAL carve  mean %.2f m   min %.2f   max %.2f" % [sum_carve / maxf(1.0, n), min_carve, max_carve])
	print("  points carved deeper than 3.0 m: %d (%.1f%%)" % [over3, 100.0 * over3 / maxf(1.0, n)])
	print("  bank(+-half_w) - bed  mean %+.3f m" % (sum_bank_minus_bed / maxf(1.0, n)))
	print("  bank(+-reach)  - bed  mean %+.3f m" % (sum_reach_minus_bed / maxf(1.0, n)))
	print("  points where bank == bed (within 5cm): %d (%.1f%%)" % [bank_eq_bed, 100.0 * bank_eq_bed / maxf(1.0, n)])

	var keys: Array = w_hist.keys()
	keys.sort()
	var line: String = "  width histogram: "
	for k in keys:
		line += "%dm:%d  " % [k, w_hist[k]]
	print(line)

	# Mesh surface vs the height every gameplay query reports.
	var dis_sum: float = 0.0
	var dis_max: float = -INF
	var dn: int = 0
	for r in hydro.rivers:
		var points: PackedVector2Array = r["points"]
		var widths: PackedFloat32Array = r["widths"]
		for i in range(points.size()):
			var p: Vector2 = points[i]
			var half: float = widths[i] * 0.5
			var perp: Vector2 = ws._path_perpendicular(points, i)
			var bed: float = hm.sample_world(p.x, p.y)
			var bl: float = hm.sample_world(p.x - perp.x * half, p.y - perp.y * half)
			var br: float = hm.sample_world(p.x + perp.x * half, p.y + perp.y * half)
			var y: float = maxf(minf(bed + WaterSystem.CHANNEL_WATER_DEPTH, minf(bl, br) - WaterSystem.RIVER_RECESS), bed + 0.05)
			var q: float = ws.get_water_level_at(p.x, p.y)
			if q == -INF:
				continue
			dn += 1
			dis_sum += q - y
			dis_max = maxf(dis_max, q - y)
	print("\n  get_water_level_at() - mesh y:  mean %+.2f m   max %+.2f m  (%d pts)" % [dis_sum / maxf(1.0, dn), dis_max, dn])

	get_tree().quit(0)
