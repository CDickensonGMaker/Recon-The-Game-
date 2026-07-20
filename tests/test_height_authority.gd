## test_height_authority.gd - the world has exactly ONE vertical scale.
##
## Terrain height was defined in eight places that disagreed 280 vs 350. The mesh was
## built at one scale, the shader banded at another, and riverbeds were carved through
## a third - so the creekbed and the water that filled it were computed against
## different worlds.
##
## This probe is a RATCHET. It asserts:
##   A. exactly one source-level definition of the height constant (no fifth copy)
##   B. the shader's uniform default equals that constant (GDScript cannot share a
##      const into a .gdshader, so the literal is an irreducible second copy - it is
##      bound here by text, or it is unbound)
##   C. every runtime height consumer agrees with the authority, in meters
##   D. the carved creekbed and the water surface that fills it agree
##
## Run: godot --headless --path . res://tests/test_height_authority.tscn
extends Node

const SEED_VAL: int = 42

## Float rounding allowance on a meters comparison. Not a coarseness budget.
const HEIGHT_TOL_M: float = 0.05
## A carved channel must hold water within this of its own bed. Wider than
## HEIGHT_TOL_M because the water ribbon deliberately rides RIVER_RECESS below the
## bank average. That recess is the ONLY reason for the extra slack: terrain and
## hydrology share one 320^2 / 4m grid, since water_system.gd:131 _auto_downsample()
## returns maxi(1, round(320/450)) = 1 and hydrology_map.gd:535-538 takes the
## identity path. Do not read this tolerance as a resolution-mismatch budget.
const CHANNEL_TOL_M: float = 2.5

const SHADER_PATH: String = "res://terrain/shaders/terrain.gdshader"

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ok(msg: String) -> void:
	print("  ok: ", msg)
	_checks += 1


func _run() -> void:
	print("=== HEIGHT AUTHORITY PROBE ===")
	_check_single_definition()
	_check_shader_binding()
	await _check_runtime_agreement()
	_finish()


# -----------------------------------------------------------------------------
# A. Exactly one source-level definition.
# -----------------------------------------------------------------------------
func _check_single_definition() -> void:
	print("\n[A] single source-level definition")

	# Any file that assigns a bare float to a height-scale identifier is declaring a
	# second authority. The authority itself is the ONE allowed match.
	var offenders: Array[String] = []
	var authority_hits: int = 0

	for path in _gd_files("res://terrain") + _gd_files("res://scripts"):
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		var line_no: int = 0
		for line in text.split("\n"):
			line_no += 1
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			# Declarations/assignments of a height scale to a numeric literal.
			var re := RegEx.new()
			re.compile("(WORLD_HEIGHT_MAX|height_scale|_height_scale)\\s*(:\\s*float\\s*)?=\\s*([0-9]+\\.[0-9]+)")
			var m: RegExMatch = re.search(stripped)
			if m == null:
				continue
			if path == "res://terrain/core/terrain_config.gd":
				authority_hits += 1
				continue
			offenders.append("%s:%d  %s" % [path, line_no, stripped])

	if authority_hits != 1:
		_fail("terrain_config.gd must declare the height constant exactly once (found %d)" % authority_hits)
	else:
		_ok("terrain_config.gd declares WORLD_HEIGHT_MAX exactly once")

	if offenders.size() > 0:
		_fail("%d competing height-scale literal(s) outside the authority:" % offenders.size())
		for o in offenders:
			print("        ", o)
	else:
		_ok("no competing height-scale literals in terrain/ or scripts/")


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [root]
	while dirs.size() > 0:
		var d: String = dirs.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			continue
		da.list_dir_begin()
		var name: String = da.get_next()
		while name != "":
			var full: String = d.path_join(name)
			if da.current_is_dir():
				if not name.begins_with("."):
					dirs.append(full)
			elif name.ends_with(".gd"):
				out.append(full)
			name = da.get_next()
		da.list_dir_end()
	return out


# -----------------------------------------------------------------------------
# B. The shader default is bound to the constant.
# -----------------------------------------------------------------------------
func _check_shader_binding() -> void:
	print("\n[B] shader uniform default bound to the authority")
	var text: String = FileAccess.get_file_as_string(SHADER_PATH)
	if text.is_empty():
		_fail("could not read %s" % SHADER_PATH)
		return
	var re := RegEx.new()
	re.compile("uniform\\s+float\\s+height_scale\\s*=\\s*([0-9]+\\.?[0-9]*)")
	var m: RegExMatch = re.search(text)
	if m == null:
		_fail("terrain.gdshader declares no height_scale uniform default")
		return
	var shader_default: float = float(m.get_string(1))
	if absf(shader_default - TerrainConfig.WORLD_HEIGHT_MAX) > 0.001:
		_fail("shader default %.1f != TerrainConfig.WORLD_HEIGHT_MAX %.1f" % [
			shader_default, TerrainConfig.WORLD_HEIGHT_MAX])
	else:
		_ok("shader default %.1f == authority" % shader_default)


# -----------------------------------------------------------------------------
# C + D. Runtime agreement, on a real generated world.
# -----------------------------------------------------------------------------
func _check_runtime_agreement() -> void:
	print("\n[C] runtime consumers agree with the authority")
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
		return

	var tm: TerrainManager = world.terrain_manager
	var water: WaterSystem = world.water_system
	if tm == null or water == null:
		_fail("world came up without terrain/water")
		return

	var authority: float = TerrainConfig.WORLD_HEIGHT_MAX

	# C1 - the storage that decodes the data uses the authority.
	if absf(tm.heightmap.height_scale - authority) > 0.001:
		_fail("heightmap.height_scale %.1f != authority %.1f" % [tm.heightmap.height_scale, authority])
	else:
		_ok("heightmap decode scale == authority (%.1f)" % authority)

	# C2 - the live shader material bands against the authority.
	var mat: Material = TerrainChunk.shared_material
	if mat is ShaderMaterial:
		var live: Variant = (mat as ShaderMaterial).get_shader_parameter("height_scale")
		if live == null:
			_fail("terrain material has no height_scale override (falls back to shader default)")
		elif absf(float(live) - authority) > 0.001:
			_fail("live shader height_scale %.1f != authority %.1f -- terrain above %.0fm bands as one flat texture" % [
				float(live), authority, float(live)])
		else:
			_ok("live shader height_scale == authority (%.1f)" % authority)
	else:
		print("  skip: terrain is using the fallback material, no shader to check")

	# C3 - the mesh vertex scale. TerrainChunk is handed the scale at build time;
	# if it kept its own it would silently disagree with the collision/query path.
	var any_chunk: Node3D = null
	for c in tm.chunks.values():
		any_chunk = c
		break
	if any_chunk != null:
		if absf(any_chunk.height_scale - authority) > 0.001:
			_fail("chunk mesh height_scale %.1f != authority %.1f" % [any_chunk.height_scale, authority])
		else:
			_ok("chunk mesh scale == authority (%.1f)" % authority)

	# C4 - the gameplay query path returns the same meters as the backing store.
	var worst: float = 0.0
	var samples: int = 0
	var map_m: float = tm.map_size
	for i in range(400):
		var wx: float = fposmod(float(i) * 137.51, map_m - 20.0) + 10.0
		var wz: float = fposmod(float(i) * 311.73, map_m - 20.0) + 10.0
		var via_manager: float = tm.get_height_at(Vector3(wx, 0.0, wz))
		var via_storage: float = tm.heightmap.sample_world(wx, wz)
		worst = maxf(worst, absf(via_manager - via_storage))
		samples += 1
	if worst > HEIGHT_TOL_M:
		_fail("get_height_at vs sample_world disagree by up to %.3f m over %d samples" % [worst, samples])
	else:
		_ok("get_height_at == sample_world (worst %.4f m over %d samples)" % [worst, samples])

	# C5 - the meters<->normalized conversion round-trips against the same scale.
	var probe_m: float = 1.8
	var round_trip: float = tm.heightmap.norm_to_meters(tm.heightmap.meters_to_norm(probe_m))
	if absf(round_trip - probe_m) > 0.001:
		_fail("meters_to_norm/norm_to_meters do not round-trip (%.4f -> %.4f)" % [probe_m, round_trip])
	else:
		_ok("meters<->normalized round-trips exactly")

	# ---------------------------------------------------------------------
	# D. The creekbed and the water that fills it describe the same ground.
	# ---------------------------------------------------------------------
	print("\n[D] carved channel vs water surface")
	_check_channels(tm, water)


func _check_channels(tm: TerrainManager, water: WaterSystem) -> void:
	# The carved grooves come from RiverGenerator (terrain_manager.river_paths).
	# The water that renders comes from HydrologyMap (water_system). If those are
	# two authorities for where water goes, this is where it shows.
	var paths: Array = tm.river_paths
	if paths.is_empty():
		print("  note: seed %d generated no carved rivers - channel check inconclusive" % SEED_VAL)
		return

	var pts: int = 0
	var wet: int = 0
	var dry_examples: Array[String] = []
	var worst_gap: float = 0.0

	for path in paths:
		for p in path.points:
			pts += 1
			var wx: float = p.x
			var wz: float = p.y
			if water.is_water(wx, wz):
				wet += 1
				var bed: float = tm.get_height_at(Vector3(wx, 0.0, wz))
				var surf: float = water.get_water_level_at(wx, wz)
				if surf > -INF and surf > 0.0:
					worst_gap = maxf(worst_gap, absf(surf - bed))
			elif dry_examples.size() < 5:
				dry_examples.append("(%.0f, %.0f)" % [wx, wz])

	var pct: float = 100.0 * float(wet) / float(maxi(pts, 1))
	print("  carved channel points: %d" % pts)
	print("  of those, WaterSystem reports water: %d (%.1f%%)" % [wet, pct])
	if dry_examples.size() > 0:
		print("  dry carved-groove examples: %s" % ", ".join(dry_examples))
	print("  worst bed-vs-surface gap where both exist: %.2f m" % worst_gap)

	# This is the owner's visible bug: a carved creekbed with no water in it, or
	# water sitting off its own bed.
	if pct < 50.0:
		_fail("only %.1f%% of carved channel is wet - the groove and the water disagree" % pct)
	else:
		_ok("%.1f%% of carved channel holds water" % pct)

	if worst_gap > CHANNEL_TOL_M:
		_fail("water surface sits %.2f m off the carved bed (tol %.2f)" % [worst_gap, CHANNEL_TOL_M])
	else:
		_ok("water surface within %.2f m of the carved bed" % worst_gap)


func _finish() -> void:
	print("\n=== %s === (%d checks passed, %d failure(s))" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
