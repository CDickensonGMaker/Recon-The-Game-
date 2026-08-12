## probe_ribbon_fold.gd - DOES THE RIVER RIBBON FOLD OVER ITSELF?
##
## The Summoner: "theres parts where the water seems to scrunch up or the jump from
## one area to the other doesnt make sense". Two symptoms, two candidate causes:
##
##   SCRUNCH  - path points are ~4m apart but half_w reaches 20m. Any bend tighter
##              than the half-width makes consecutive cross-sections cross, so the
##              ribbon folds back through itself (a bowtie).
##   JUMP     - the seating clamp (water_system.gd:340-341) picks bed+0.55 on one
##              vertex and bed+0.05 on the next, and _surface_h uses non-monotone
##              _elev, so the surface can also run uphill.
##
##   godot --headless --path . res://tools/probe_ribbon_fold.tscn
extends Node


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== RIBBON FOLD / SURFACE CONTINUITY ===\n")

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
	var rivers: Array = hydro.rivers

	var water_d: float = WaterSystem.CHANNEL_WATER_DEPTH
	var recess: float = WaterSystem.RIVER_RECESS

	var seg_n: int = 0
	var fold_l: int = 0
	var fold_r: int = 0
	var sum_seg: float = 0.0
	var sum_half: float = 0.0
	var worst_ratio: float = 0.0

	var jump_n: int = 0
	var sum_jump: float = 0.0
	var max_jump: float = 0.0
	var uphill: int = 0
	var sum_uphill: float = 0.0
	var max_uphill: float = 0.0
	var big_jump: int = 0

	for r in rivers:
		var points: PackedVector2Array = r["points"]
		var widths: PackedFloat32Array = r["widths"]
		if points.size() < 2:
			continue

		var ys := PackedFloat32Array()
		var ls := PackedVector2Array()
		var rs := PackedVector2Array()
		ys.resize(points.size())
		ls.resize(points.size())
		rs.resize(points.size())

		for i in range(points.size()):
			var p: Vector2 = points[i]
			var half: float = (widths[i] if i < widths.size() else 4.0) * 0.5
			var perp: Vector2 = ws._path_perpendicular(points, i)
			ls[i] = p - perp * half
			rs[i] = p + perp * half

			var bed: float = hm.sample_world(p.x, p.y)
			var bank_l: float = hm.sample_world(ls[i].x, ls[i].y)
			var bank_r: float = hm.sample_world(rs[i].x, rs[i].y)
			var y: float = minf(bed + water_d, minf(bank_l, bank_r) - recess)
			ys[i] = maxf(y, bed + 0.05)

		for i in range(points.size() - 1):
			var d: Vector2 = points[i + 1] - points[i]
			var seg: float = d.length()
			if seg < 0.0001:
				continue
			var half_i: float = (widths[i] if i < widths.size() else 4.0) * 0.5
			seg_n += 1
			sum_seg += seg
			sum_half += half_i
			worst_ratio = maxf(worst_ratio, half_i / seg)

			# Fold: does the edge vertex travel BACKWARDS along the centreline?
			if (ls[i + 1] - ls[i]).dot(d) < 0.0:
				fold_l += 1
			if (rs[i + 1] - rs[i]).dot(d) < 0.0:
				fold_r += 1

			# Surface continuity along the channel.
			var dy: float = ys[i + 1] - ys[i]
			jump_n += 1
			sum_jump += absf(dy)
			max_jump = maxf(max_jump, absf(dy))
			if absf(dy) > 0.30:
				big_jump += 1
			if dy > 0.01:
				uphill += 1
				sum_uphill += dy
				max_uphill = maxf(max_uphill, dy)

	print("-- ribbon geometry, %d segments --" % seg_n)
	print("  mean point spacing   %.2f m" % (sum_seg / maxf(1.0, seg_n)))
	print("  mean half-width      %.2f m" % (sum_half / maxf(1.0, seg_n)))
	print("  worst half/spacing   %.1fx   (>1.0 can fold on any bend)" % worst_ratio)
	print("  FOLDED left edge     %d / %d  (%.1f%%)" % [fold_l, seg_n, 100.0 * fold_l / maxf(1.0, seg_n)])
	print("  FOLDED right edge    %d / %d  (%.1f%%)" % [fold_r, seg_n, 100.0 * fold_r / maxf(1.0, seg_n)])

	print("\n-- surface continuity, %d steps --" % jump_n)
	print("  mean |dy| per step   %.3f m" % (sum_jump / maxf(1.0, jump_n)))
	print("  max  |dy| per step   %.3f m" % max_jump)
	print("  steps over 0.30m     %d  (%.1f%%)" % [big_jump, 100.0 * big_jump / maxf(1.0, jump_n)])
	print("  UPHILL steps         %d  (%.1f%%),  mean +%.3f m, max +%.3f m" % [uphill, 100.0 * uphill / maxf(1.0, jump_n), sum_uphill / maxf(1.0, uphill), max_uphill])

	get_tree().quit(0)
