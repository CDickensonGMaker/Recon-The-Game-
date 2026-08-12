## probe_water_seat.gd - WHERE DOES THE WATER SHEET ACTUALLY SIT?
##
## Recomputes _append_river_strip's seating decision on real channels and compares it
## against the carved bed, the sampled "banks", and the true grade outside the carve.
##
##   godot --headless --path . res://tools/probe_water_seat.tscn
extends Node


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== WATER SEATING ===\n")

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = 47225
	world.spawn_player_on_ready = false
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 400:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  [FAIL] world never became ready")
		get_tree().quit(1)
		return

	var ws: WaterSystem = world.water_system
	var hm: RefCounted = ws._heightmap
	var hydro: RefCounted = ws._hydrology
	if hm == null or hydro == null:
		print("  [FAIL] no heightmap/hydrology")
		get_tree().quit(1)
		return

	var rivers: Array = hydro.rivers
	print("channels: %d" % rivers.size())

	var carve: float = TerrainManager.CHANNEL_CARVE_DEPTH
	var water_d: float = WaterSystem.CHANNEL_WATER_DEPTH
	var recess: float = WaterSystem.RIVER_RECESS

	var n_clamped: int = 0
	var n_total: int = 0
	var sum_above_bed: float = 0.0
	var sum_below_grade: float = 0.0
	var min_above_bed: float = INF
	var max_above_bed: float = -INF

	# Sort by point count so the biggest channel is reported in detail.
	var sorted: Array = rivers.duplicate()
	sorted.sort_custom(func(a, b): return (a["points"] as PackedVector2Array).size() > (b["points"] as PackedVector2Array).size())

	for ri in range(sorted.size()):
		var r: Dictionary = sorted[ri]
		var points: PackedVector2Array = r["points"]
		var widths: PackedFloat32Array = r["widths"]
		var detail: bool = ri == 0

		if detail:
			print("\n-- biggest channel: %d points --" % points.size())
			print("  %-6s %-7s %-8s %-8s %-8s %-8s %-8s" % ["i", "width", "bed", "bank_l", "bank_r", "grade", "y"])

		for i in range(points.size()):
			var p: Vector2 = points[i]
			var half: float = (widths[i] if i < widths.size() else 4.0) * 0.5
			var perp: Vector2 = ws._path_perpendicular(points, i)
			var left: Vector2 = p - perp * half
			var right: Vector2 = p + perp * half

			var bed: float = hm.sample_world(p.x, p.y)
			var bank_l: float = hm.sample_world(left.x, left.y)
			var bank_r: float = hm.sample_world(right.x, right.y)

			# True grade: sample OUTSIDE the carve (half_w + shoulder = reach).
			var shoulder: float = maxf(half * 0.6, hm.cell_size)
			var reach: float = half + shoulder
			var out_l: Vector2 = p - perp * (reach + hm.cell_size)
			var out_r: Vector2 = p + perp * (reach + hm.cell_size)
			var grade: float = minf(hm.sample_world(out_l.x, out_l.y), hm.sample_world(out_r.x, out_r.y))

			# Exactly what _append_river_strip does.
			var y: float = minf(bed + water_d, minf(bank_l, bank_r) - recess)
			var floored: bool = y < bed + 0.05
			y = maxf(y, bed + 0.05)

			if floored:
				n_clamped += 1
			n_total += 1
			var above: float = y - bed
			sum_above_bed += above
			sum_below_grade += (grade - y)
			min_above_bed = minf(min_above_bed, above)
			max_above_bed = maxf(max_above_bed, above)

			if detail and i % maxi(1, points.size() / 12) == 0:
				print("  %-6d %-7.2f %-8.2f %-8.2f %-8.2f %-8.2f %-8.2f" % [i, half * 2.0, bed, bank_l, bank_r, grade, y])

	print("\n-- all %d channels, %d vertices --" % [rivers.size(), n_total])
	print("  CONTRACT     carve %.2f - water %.2f = drop %.2f" % [carve, water_d, carve - water_d])
	print("  intended     water sits %.2fm above bed, %.2fm below grade" % [water_d, carve - water_d])
	print("  ACTUAL       water sits %.3fm above bed (min %.3f, max %.3f)" % [sum_above_bed / maxf(1.0, n_total), min_above_bed, max_above_bed])
	print("  ACTUAL       water sits %.3fm below grade" % (sum_below_grade / maxf(1.0, n_total)))
	print("  CLAMPED      %d / %d verts (%.1f%%) hit the bed+0.05 floor" % [n_clamped, n_total, 100.0 * n_clamped / maxf(1.0, n_total)])

	get_tree().quit(0)
