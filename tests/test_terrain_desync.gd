## test_terrain_desync.gd - the AI grid and the water map must describe the ground
## that is actually there, after terrain is edited at runtime.
## Asserts STATE, not calls: every sampled cell is compared against the live heightmap.
## Run: godot --headless --path . res://tests/test_terrain_desync.tscn
extends Node

const SEED_VAL: int = 42

## Both systems sample at cell centres via the same heightmap function the probe
## queries, so the 12m grid / 2m heightmap ratio contributes ZERO error here. This is
## a float rounding allowance, not a coarseness budget - do not loosen it.
const ELEV_TOL_M: float = 0.05
const SLOPE_TOL: float = 0.02

const MESA_R: float = 120.0
const MESA_LIFT: float = 20.0
const CRATER_R: float = 9.0
const CRATER_DEPTH: float = 4.0

## Mirrors WaterSystem.RETIRE_RISE_M. Duplicated deliberately: the probe must still
## compile and MEASURE against a build where that constant does not exist.
const RETIRE_RISE_M: float = 1.0

var _failures: int = 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
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
		_fail("world never came up")
		_finish()
		return

	var tm: TerrainManager = world.terrain_manager
	var grid: GameplayGrid = world.gameplay_grid
	var water: WaterSystem = world.water_system
	if tm == null or grid == null or water == null:
		_fail("world came up without terrain/grid/water")
		_finish()
		return

	# The channel itself must be wired, or every assertion below passes by accident
	# on a build where nothing subscribes.
	# Counted, not named: this must still compile against a build where the
	# subscriber does not exist, or the negative control dies here instead of
	# measuring the drift it exists to measure.
	var subs: int = tm.region_rebuilt.get_connections().size()
	print("[desync] region_rebuilt subscribers: %d" % subs)
	if subs < 2:
		_fail("only %d subscriber(s) on region_rebuilt - nothing re-seats the grid or the water map" % subs)

	_report_baseline_burial(water, tm)

	var center := Vector3(tm.map_size * 0.5, 0.0, tm.map_size * 0.5)

	await _edit_and_verify(world, tm, grid, water, center, MESA_R, MESA_LIFT, "mesa +20m")

	# The water half is only tested if the edit lands ON water - burying a creek is
	# the whole of t5ne. An edit over dry ground asserts nothing about WaterSystem.
	var wet: Vector3 = _find_water(water, tm)
	if wet == Vector3.ZERO:
		_fail("no water found on seed %d - the water assertions would be vacuous" % SEED_VAL)
	else:
		# Crater first: the mesa dries this creek, and a dried creek makes the
		# crater case vacuous.
		await _edit_and_verify(world, tm, grid, water, wet, CRATER_R, -CRATER_DEPTH, "crater in creek -4m", true)
		await _edit_and_verify(world, tm, grid, water, wet, MESA_R, MESA_LIFT, "creek buried +20m", true)

	world.queue_free()
	_finish()


## Find the wettest neighbourhood on the map, so the buried-creek assertions have
## something to bury. Returns ZERO if this seed has no water at all.
func _find_water(water: WaterSystem, tm: TerrainManager) -> Vector3:
	var step: float = 24.0
	var best := Vector3.ZERO
	var best_wet: int = 0
	var x: float = step
	while x < tm.map_size - step:
		var z: float = step
		while z < tm.map_size - step:
			if water.is_water(x, z):
				var wet: int = 0
				for ox in [-8.0, 0.0, 8.0]:
					for oz in [-8.0, 0.0, 8.0]:
						if water.is_water(x + ox, z + oz):
							wet += 1
				if wet > best_wet:
					best_wet = wet
					best = Vector3(x, 0.0, z)
			z += step
		x += step
	return best


## Raise/lower a disc of ground, then assert every consumer agrees with the new ground.
func _edit_and_verify(world: GameWorld, tm: TerrainManager, grid: GameplayGrid,
		water: WaterSystem, center: Vector3, radius: float, lift: float,
		label: String, expect_water: bool = false) -> void:
	var before: float = grid.get_elevation(center)

	var wet_before: int = _count_wet(water, center, radius)
	if expect_water and wet_before == 0:
		_fail("%s: no water in the rect before the edit - nothing to bury, assertion is vacuous" % label)
		return

	# HeightmapStorage.data is NORMALISED (sample_world multiplies by height_scale),
	# so a modifier that adds raw metres would author a mountain 100s of times too
	# tall and the reported drift would be fiction.
	var lift_norm: float = lift / tm.heightmap.height_scale
	var lift_func := func(h: float, falloff: float) -> float:
		return h + lift_norm * falloff
	tm.modify_terrain(center, radius, lift_func)

	# region_rebuilt emits synchronously but the re-seat is deferred (ClearingSystem
	# emits before it writes its mask). Two frames: one for the deferred call to run,
	# one for it to land.
	await get_tree().process_frame
	await get_tree().process_frame

	var truth_moved: float = absf(tm.get_height_at(center) - before)
	if truth_moved < absf(lift) * 0.5:
		_fail("%s: the heightmap itself barely moved (%.2fm) - probe edit did not take"
			% [label, truth_moved])
		return

	var worst_elev: float = 0.0
	var worst_slope: float = 0.0
	var worst_at := Vector3.ZERO
	var sampled: int = 0

	var g_center: Vector2i = grid.world_to_grid(center)
	var g_r: int = int(ceil(radius / grid.cell_size_meters))
	for gz in range(g_center.y - g_r, g_center.y + g_r + 1):
		for gx in range(g_center.x - g_r, g_center.x + g_r + 1):
			if gx < 0 or gz < 0 or gx >= grid.grid_size or gz >= grid.grid_size:
				continue
			var p: Vector3 = grid.grid_to_world(Vector2i(gx, gz))
			sampled += 1

			var d_elev: float = absf(grid.get_elevation_at(gx, gz) - tm.get_height_at(p))
			if d_elev > worst_elev:
				worst_elev = d_elev
				worst_at = p

			var d_slope: float = absf(grid.get_slope(p) - clampf(1.0 - tm.get_normal_at(p).y, 0.0, 1.0))
			worst_slope = maxf(worst_slope, d_slope)

	if sampled == 0:
		_fail("%s: sampled no cells" % label)
		return

	print("[desync] %s: %d cells, worst elevation drift %.3fm, worst slope drift %.4f"
		% [label, sampled, worst_elev, worst_slope])

	if worst_elev > ELEV_TOL_M:
		_fail("%s: grid elevation is %.2fm off the real ground at %s (tol %.2fm) - the AI reads terrain that is not there"
			% [label, worst_elev, str(worst_at), ELEV_TOL_M])
	if worst_slope > SLOPE_TOL:
		_fail("%s: grid slope is %.4f off the real ground (tol %.4f)"
			% [label, worst_slope, SLOPE_TOL])

	_verify_water(water, tm, center, radius, label, wet_before, lift)


## Water may never sit under the ground it stands on. WaterSystem runs its own 2m
## lattice, so this catches the crater the 12m grid cannot see.
## Asserts BEHAVIOUR, not water_surface_full: channel cells carry no surface
## (see _report_baseline_burial), so a depth comparison would prove nothing here.
## Raise the ground through a creek and it must stop being water; dig a crater in
## one and the water must SURVIVE - wiping it would be the same lie inverted.
func _verify_water(water: WaterSystem, tm: TerrainManager, center: Vector3,
		radius: float, label: String, wet_before: int, lift: float) -> void:
	var wet: int = _count_wet(water, center, radius)
	var center_wet: bool = water.is_water(center.x, center.z)

	print("[desync] %s: %d wet cells before -> %d after (centre still water: %s)"
		% [label, wet_before, wet, str(center_wet)])

	if wet_before == 0:
		return

	if lift > RETIRE_RISE_M:
		if center_wet:
			_fail("%s: ground rose %.1fm through the water and is_water STILL says water at the centre"
				% [label, lift])
		if wet >= wet_before:
			_fail("%s: %d wet cells before, %d after - burying the creek retired nothing"
				% [label, wet_before, wet])
	elif lift < 0.0:
		if wet < wet_before:
			_fail("%s: digging DOWN dried %d water cells - the re-seat is wiping water, not correcting it"
				% [label, wet_before - wet])


## Water sitting under the ground BEFORE anything is edited is not this bug - it is
## hydrology's own surface/terrain mismatch. Reported, not asserted, so the drift
## numbers above are never mistaken for it.
func _report_baseline_burial(water: WaterSystem, tm: TerrainManager) -> void:
	var step: float = 16.0
	var wet: int = 0
	var buried: int = 0
	var worst: float = 0.0
	var x: float = step
	while x < tm.map_size - step:
		var z: float = step
		while z < tm.map_size - step:
			if water.is_water(x, z):
				wet += 1
				var d: float = tm.get_height_at(Vector3(x, 0.0, z)) - water.get_water_level_at(x, z)
				if d > 0.0:
					buried += 1
					worst = maxf(worst, d)
			z += step
		x += step
	print("[desync] BASELINE (pre-edit, %.0fm sampling): %d wet, %d already buried, worst %.2fm"
		% [step, wet, buried, worst])


func _count_wet(water: WaterSystem, center: Vector3, radius: float) -> int:
	var step: float = water.water_map_cell_size
	var wet: int = 0
	var x: float = center.x - radius
	while x <= center.x + radius:
		var z: float = center.z - radius
		while z <= center.z + radius:
			if water.is_water(x, z):
				wet += 1
			z += step
		x += step
	return wet


func _finish() -> void:
	if _failures == 0:
		print("PASS: grid and water re-seat to match edited terrain")
		get_tree().quit(0)
	else:
		print("FAIL: %d terrain desync failures" % _failures)
		get_tree().quit(1)
