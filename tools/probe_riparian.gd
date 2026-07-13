## probe_riparian.gd - GALLERY FOREST, measured.
##
## The terrain already generates a real drainage network: Priority-Flood pit filling,
## D8 flow, flow accumulation -> creeks (<6m) and rivers (6-50m) that run downhill in
## natural formations. That network is the E&E network, because water breaks the
## enemy's breadcrumb trail (EnemySquad, shipped 2026-07-12).
##
## But GameplayGrid._determine_terrain_type() reads ELEVATION AND SLOPE ONLY. A creek
## valley is low and flat -> its banks classified as RICE_PADDY (density 0.2) or
## GRASSLAND (0.3) -> a sight cap around 130m. EVERY STREAM RAN THROUGH OPEN GROUND.
##
## So water was a DEATH TRAP, not an escape route: it erased your trail while you
## waded it slow, loud, and visible from 130m.
##
## In life a watercourse is the DENSEST vegetation in the jungle - water plus edge
## light is a riot of growth, and a Vietnamese stream is a tunnel of green. This probe
## holds that line: THE BANKS MUST BE THICK.
##
##   godot --headless --path . res://tools/probe_riparian.tscn
extends Node

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== GALLERY FOREST ===\n")

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = 20260712
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

	var grid: GameplayGrid = world.gameplay_grid
	if grid == null:
		print("  [FAIL] no gameplay grid")
		get_tree().quit(1)
		return

	# Walk the grid: classify every cell as water / bank (within RIPARIAN_M) / inland.
	var n: int = grid.grid_size
	var cell: float = grid.cell_size_meters
	var water: int = 0
	var wadeable: int = 0
	var bank_density: float = 0.0
	var bank_cells: int = 0
	var inland_density: float = 0.0
	var inland_cells: int = 0
	var reach_cells: int = int(ceil(GameplayGrid.RIPARIAN_M / cell))

	# First pass: where is the water.
	var is_wet: PackedByteArray = PackedByteArray()
	is_wet.resize(n * n)
	for gz in range(n):
		for gx in range(n):
			var i: int = gz * n + gx
			var wet: bool = grid.terrain_type[i] == GameplayGrid.TerrainType.WATER
			is_wet[i] = 1 if wet else 0
			if wet:
				water += 1
				if grid.is_passable[i] == 1:
					wadeable += 1

	if water == 0:
		print("  [FAIL] the terrain generated NO WATER at all on this seed")
		_fails += 1
		get_tree().quit(1)
		return

	# Second pass: bank vs inland.
	for gz in range(n):
		for gx in range(n):
			var i: int = gz * n + gx
			if is_wet[i] == 1:
				continue
			var near: bool = false
			for oz in range(-reach_cells, reach_cells + 1):
				for ox in range(-reach_cells, reach_cells + 1):
					var jx: int = gx + ox
					var jz: int = gz + oz
					if jx < 0 or jz < 0 or jx >= n or jz >= n:
						continue
					if is_wet[jz * n + jx] == 1:
						near = true
						break
				if near:
					break
			if near:
				bank_density += grid.vegetation_density[i]
				bank_cells += 1
			else:
				inland_density += grid.vegetation_density[i]
				inland_cells += 1

	var b: float = bank_density / maxf(1.0, float(bank_cells))
	var l: float = inland_density / maxf(1.0, float(inland_cells))

	print("  water cells ........ %d  (%d of them WADEABLE, depth <= %.1fm)" % [
		water, wadeable, GameplayGrid.WADE_DEPTH_M])
	print("  bank cells ......... %d   mean vegetation density %.2f" % [bank_cells, b])
	print("  inland cells ....... %d   mean vegetation density %.2f" % [inland_cells, l])
	print("")
	print("  sight cap on the BANK ....... %.0fm" % _cap(b))
	print("  sight cap INLAND ............ %.0fm" % _cap(l))
	print("")

	# THE ROOF. A narrow creek in the forest must be COVERED - you wade a green tunnel.
	# A wide river is open sky. Water cells used to be flat 0.0 density = a 140m firing
	# lane cut through the best cover on the map, which is also the ONE escape route.
	# SEGMENT THE WATER. Averaging across ALL of it is meaningless - this map is
	# mostly lakes and wide rivers, and those SHOULD be open sky. The question is
	# whether the CREEKS - the shallow, wadeable channels that are the escape route -
	# run under a canopy.
	var creek_veg: float = 0.0
	var creek_cells: int = 0
	var deep_veg: float = 0.0
	var deep_cells: int = 0
	var roofed: int = 0
	for gz2 in range(n):
		for gx2 in range(n):
			var k: int = gz2 * n + gx2
			if is_wet[k] == 0:
				continue
			if grid.is_passable[k] == 1:          # wadeable => a creek
				creek_veg += grid.vegetation_density[k]
				creek_cells += 1
				if grid.vegetation_density[k] >= 0.6:
					roofed += 1
			else:                                  # deep => river / lake / pond
				deep_veg += grid.vegetation_density[k]
				deep_cells += 1
	var cv: float = creek_veg / maxf(1.0, float(creek_cells))
	var dv: float = deep_veg / maxf(1.0, float(deep_cells))
	print("  WADEABLE CREEKS .... %d cells   density %.2f  ->  sight cap %.0fm   (%d roofed)" % [
		creek_cells, cv, _cap(cv), roofed])
	print("  DEEP WATER ......... %d cells   density %.2f  ->  sight cap %.0fm   (open sky, as it should be)" % [
		deep_cells, dv, _cap(dv)])
	print("")

	_check("the terrain generates real watercourses", water > 200, "%d water cells" % water)
	_check("CREEKS ARE ROOFED (you wade a green tunnel, not a firing lane)",
		roofed > creek_cells / 3, "%d of %d creek cells under canopy" % [roofed, creek_cells])
	_check("a creek hides you (not a 140m firing lane through your best cover)",
		_cap(cv) < 95.0, "%.0fm in the creek" % _cap(cv))
	_check("DEEP water stays OPEN SKY (a river is exposure - that is the trade)",
		_cap(dv) > _cap(cv), "river %.0fm vs creek %.0fm" % [_cap(dv), _cap(cv)])
	_check("SHALLOW water is WADEABLE (a creek is not a wall)", wadeable > 0,
		"%d/%d passable" % [wadeable, water])
	_check("THE BANKS ARE THICK (gallery forest)", b >= 0.7,
		"bank density %.2f -> they can only see you at %.0fm" % [b, _cap(b)])
	_check("the bank is denser than open inland ground", b > l,
		"bank %.2f vs inland %.2f" % [b, l])
	_check("a creek is a CONCEALED corridor, not a firing lane", _cap(b) < 70.0,
		"%.0fm on the bank" % _cap(b))

	print("")
	if _fails == 0:
		print("*** THE CREEKS ARE GREEN TUNNELS. Water erases your trail AND hides you. ***")
	else:
		print("*** %d FAILURE(S) - water is still a death trap ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## The same lerp enemy_base._sight_cap() uses: 140m open -> 45m deep jungle.
func _cap(veg: float) -> float:
	return lerpf(140.0, 45.0, clampf(veg, 0.0, 1.0))


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])
