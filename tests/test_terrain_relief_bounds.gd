## test_terrain_relief_bounds.gd - relief-budget probe for the terrain engine.
## Generates deterministic seeds per preset and asserts the AO stays playable.
##
## MEASURES WHAT SHIPS. The cell count comes from HeightmapStorage at the real
## WorldConfig.MAP_SIZE, and metres decode through TerrainConfig.WORLD_HEIGHT_MAX -
## the same two contracts terrain_manager.gd:57,96 use. Deriving either one
## independently is what let a 2.7x relief overshoot sit under a green suite.
## Run: godot --headless --path . res://tests/test_terrain_relief_bounds.tscn
extends Node3D

const TerrainEngineClass := preload("res://terrain/core/terrain_engine.gd")
const HeightmapStorageClass := preload("res://terrain/core/heightmap_storage.gd")

const SEEDS_PER_PRESET: int = 5
const CELL_SIZE_M: float = 2.0

# Per-preset budgets. These are intentionally tight: the lowland presets must be
# flat enough for paddies/villages; the highland presets keep drama but must not
# become unplayable canyons.
const BUDGETS: Dictionary = {
	TerrainEngineClass.TerrainPreset.COASTAL_HILLS: {
		"relief_m": 30.0, "steep_pct": 5.0, "roughness_m": 2.0, "max_slope_deg": 8.0
	},
	TerrainEngineClass.TerrainPreset.RIVER_VALLEY: {
		"relief_m": 50.0, "steep_pct": 10.0, "roughness_m": 3.0, "max_slope_deg": 12.0
	},
	TerrainEngineClass.TerrainPreset.ROLLING_HILLS: {
		"relief_m": 110.0, "steep_pct": 20.0, "roughness_m": 6.0, "max_slope_deg": 22.0
	},
	TerrainEngineClass.TerrainPreset.STEEP_MOUNTAINS: {
		"relief_m": 350.0, "steep_pct": 45.0, "roughness_m": 25.0, "max_slope_deg": 50.0
	},
	TerrainEngineClass.TerrainPreset.PLATEAU: {
		"relief_m": 200.0, "steep_pct": 35.0, "roughness_m": 12.0, "max_slope_deg": 40.0
	},
}

var _failures: int = 0

func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	print("=== Terrain Relief Bounds Probe ===")

	var presets: Array = [
		TerrainEngineClass.TerrainPreset.COASTAL_HILLS,
		TerrainEngineClass.TerrainPreset.RIVER_VALLEY,
		TerrainEngineClass.TerrainPreset.ROLLING_HILLS,
		TerrainEngineClass.TerrainPreset.STEEP_MOUNTAINS,
		TerrainEngineClass.TerrainPreset.PLATEAU,
	]

	for preset in presets:
		var preset_name: String = _preset_name(preset)
		var budget: Dictionary = BUDGETS[preset]
		print("\n-- preset: %s --" % preset_name)

		for i in range(SEEDS_PER_PRESET):
			var seed_value: int = 1000 + preset * 100 + i
			var stats: Dictionary = _measure_preset(preset, seed_value)

			print("  seed=%d relief=%.1fm slope=%.1f%% steep=%.1f%% rough=%.2fm" % [
				seed_value, stats.relief_m, stats.avg_slope_deg,
				stats.steep_pct, stats.window_roughness_m
			])

			if stats.relief_m > budget.relief_m:
				_bad("%s seed %d: relief %.1fm > %.1fm" % [preset_name, seed_value, stats.relief_m, budget.relief_m])
			if stats.steep_pct > budget.steep_pct:
				_bad("%s seed %d: steep %.1f%% > %.1f%%" % [preset_name, seed_value, stats.steep_pct, budget.steep_pct])
			if stats.window_roughness_m > budget.roughness_m:
				_bad("%s seed %d: roughness %.2fm > %.2fm" % [preset_name, seed_value, stats.window_roughness_m, budget.roughness_m])
			if stats.avg_slope_deg > budget.max_slope_deg:
				_bad("%s seed %d: avg slope %.1fdeg > %.1fdeg" % [preset_name, seed_value, stats.avg_slope_deg, budget.max_slope_deg])

	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _measure_preset(preset: int, seed_value: int) -> Dictionary:
	var storage: RefCounted = HeightmapStorageClass.new(WorldConfig.MAP_SIZE, CELL_SIZE_M,
		TerrainConfig.WORLD_HEIGHT_MAX)
	var engine := TerrainEngineClass.new()
	engine.terrain_size = storage.size
	engine.cell_size = CELL_SIZE_M
	# Add to tree first so _ready() initializes the noise objects.
	add_child(engine)
	engine.set_preset(preset)
	var intended_scale: float = TerrainConfig.preset_relief(preset)
	# Use the intended per-preset scale so the probe measures real meters.
	# With bounded amplitude scaling, the engine centers the distribution and
	# targets `intended_scale / WORLD_HEIGHT_MAX` in normalized space.
	engine.target_relief = intended_scale / TerrainConfig.WORLD_HEIGHT_MAX
	engine.generate(seed_value)

	var data: PackedFloat32Array = engine.heightmap_data.duplicate()
	var size: int = engine.terrain_size

	# Determinism guard: generate a second time and compare hashes.
	engine.generate(seed_value)
	var second: PackedFloat32Array = engine.heightmap_data.duplicate()
	var hash1: int = _hash_data(data)
	var hash2: int = _hash_data(second)
	if hash1 != hash2:
		_bad("preset %s seed %d NOT deterministic (%d vs %d)" % [_preset_name(preset), seed_value, hash1, hash2])

	engine.queue_free()

	return _analyze(data, size, TerrainConfig.WORLD_HEIGHT_MAX)


func _analyze(data: PackedFloat32Array, size: int, height_scale: float) -> Dictionary:
	var min_h: float = INF
	var max_h: float = -INF
	for h in data:
		min_h = minf(min_h, h)
		max_h = maxf(max_h, h)

	var relief_m: float = (max_h - min_h) * height_scale

	var slope_sum: float = 0.0
	var steep_count: int = 0
	var total_cells: int = 0
	var window_sum: float = 0.0
	var window_count: int = 0

	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var idx: int = y * size + x
			# gx/gy are NORMALIZED height deltas per cell. Rise is metres
			# (delta * height_scale); run is metres (CELL_SIZE_M). Using the raw
			# normalized delta as rise/run understated every slope by
			# height_scale/cell_size - 175x - which is why the steepness budgets
			# below had never once been capable of failing.
			var gx: float = (data[idx + 1] - data[idx - 1]) * 0.5
			var gy: float = (data[(y + 1) * size + x] - data[(y - 1) * size + x]) * 0.5
			var rise_m: float = sqrt(gx * gx + gy * gy) * height_scale
			var slope_deg: float = rad_to_deg(atan(rise_m / CELL_SIZE_M))
			slope_sum += slope_deg
			total_cells += 1
			if slope_deg > 30.0:
				steep_count += 1

			# 16x16 cell window ~= 32 m x 32 m
			if x >= 8 and x < size - 8 and y >= 8 and y < size - 8:
				var win_mean: float = 0.0
				for wy in range(-8, 9):
					for wx in range(-8, 9):
						win_mean += data[(y + wy) * size + (x + wx)]
				win_mean /= 289.0
				var win_var: float = 0.0
				for wy in range(-8, 9):
					for wx in range(-8, 9):
						var d: float = data[(y + wy) * size + (x + wx)] - win_mean
						win_var += d * d
				win_var /= 289.0
				window_sum += sqrt(win_var) * height_scale
				window_count += 1

	var avg_slope_deg: float = slope_sum / maxi(total_cells, 1)
	var steep_pct: float = float(steep_count) / maxi(total_cells, 1) * 100.0
	var window_roughness_m: float = window_sum / maxi(window_count, 1)

	return {
		"relief_m": relief_m,
		"avg_slope_deg": avg_slope_deg,
		"steep_pct": steep_pct,
		"window_roughness_m": window_roughness_m,
	}


func _hash_data(data: PackedFloat32Array) -> int:
	var h: int = 0
	for v in data:
		# Simple hash mixing; good enough for deterministic comparison.
		var bits: int = _hash_bits(v)
		h = (h * 31 + bits) & 0x7FFFFFFF
	return h


func _hash_bits(v: float) -> int:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, v)
	var out: int = 0
	for b in bytes:
		out = (out << 8) | (int(b) & 0xFF)
	return out


func _preset_name(preset: int) -> String:
	match preset:
		TerrainEngineClass.TerrainPreset.COASTAL_HILLS: return "COASTAL_HILLS"
		TerrainEngineClass.TerrainPreset.RIVER_VALLEY: return "RIVER_VALLEY"
		TerrainEngineClass.TerrainPreset.ROLLING_HILLS: return "ROLLING_HILLS"
		TerrainEngineClass.TerrainPreset.STEEP_MOUNTAINS: return "STEEP_MOUNTAINS"
		TerrainEngineClass.TerrainPreset.PLATEAU: return "PLATEAU"
		_: return "UNKNOWN"
