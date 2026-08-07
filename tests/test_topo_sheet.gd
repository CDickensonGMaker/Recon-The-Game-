## probe_topo_sheet.gd - Renders the topo base sheet to PNG for visual review.
## The sheet is judged by EYES, not by reasoning about the algorithm, so this dumps
## one image per preset/seed to screenshots/topo/ for a before/after comparison.
##
## Water is ABSENT here - the probe has no GameplayGrid. Water is judged in-game only.
##
## Run: Godot_v4.7-stable_win64.exe --headless --path . res://tests/probe_topo_sheet.tscn
extends Node3D

const TerrainEngineClass := preload("res://terrain/core/terrain_engine.gd")
const HeightmapStorageClass := preload("res://terrain/core/heightmap_storage.gd")

const CELL_SIZE_M: float = 2.0
const SEEDS_PER_PRESET: int = 1
const OUT_DIR: String = "res://screenshots/topo"

## Tag written into each filename so a run can be diffed against a previous one.
const TAG: String = "fixed"

## Hypothesis under test: noise is sampled in CELL indices, not metres
## (terrain_engine.gd:263-264 - cell_size is never applied), so the preset frequencies,
## authored against the default terrain_size of 1537, are stretched across the 641 cells
## the 1280m AO actually uses. Scaling frequency by 1537/641 should restore the intended
## feature density if that is the cause.
const FREQ_SCALES: Array[float] = [1.0]

## Isotropy test: SIMPLEX_SMOOTH FBM streaks along one diagonal at every frequency.
## Does another noise type produce drainage-organised terrain instead of corduroy?
const NOISE_TYPES: Dictionary = {
	"simplexsmooth": FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
}
const FREQ_KEYS: Array[String] = ["base_frequency", "warp_frequency", "ridge_frequency",
	"detail_frequency"]


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	print("=== Topo Sheet Probe (tag=%s) ===" % TAG)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var presets: Array = [
		TerrainEngineClass.TerrainPreset.COASTAL_HILLS,
		TerrainEngineClass.TerrainPreset.RIVER_VALLEY,
		TerrainEngineClass.TerrainPreset.ROLLING_HILLS,
		TerrainEngineClass.TerrainPreset.STEEP_MOUNTAINS,
		TerrainEngineClass.TerrainPreset.PLATEAU,
	]

	for preset in presets:
		for i in range(SEEDS_PER_PRESET):
			var seed_value: int = 1000 + preset * 100 + i
			for nt in NOISE_TYPES:
				_render_one(preset, seed_value, FREQ_SCALES[0], String(nt))

	# Compile-check the consumers here rather than under --check-only: that mode has no
	# autoloads, so the dependency chain to GameManager fails and buries any real error.
	var failed: int = 0
	for path in ["res://scripts/ui/topo_map.gd", "res://scripts/missions/field_director.gd",
			"res://scripts/world/hamlet_names.gd", "res://scripts/ui/topo_sheet.gd",
			"res://scripts/enemies/evidence_ledger.gd", "res://scripts/enemies/enemy_base.gd",
			"res://scripts/autoload/campaign_state.gd", "res://scripts/missions/mission_state.gd",
			"res://scripts/player/player.gd", "res://scripts/ai/air_traffic.gd",
			"res://scripts/missions/mission_generator.gd", "res://scripts/ui/war_facts.gd",
			"res://scripts/main/game_flow.gd"]:
		var scr: Resource = load(path)
		if scr == null:
			print("  COMPILE FAIL: %s" % path)
			failed += 1
		else:
			print("  compiles: %s" % path)

	print("=== done (%d compile failures) ===" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _render_one(preset: int, seed_value: int, freq_scale: float, noise_key: String) -> void:
	var map_size: float = WorldConfig.MAP_SIZE

	# terrain_size MUST come from the storage, exactly as terrain_manager.gd:96 does it.
	# Deriving it independently put 641 cells into a 640-wide store and sheared every
	# row by one cell - which reads as diagonal corduroy and a seam, and is not terrain.
	var heightmap: RefCounted = HeightmapStorageClass.new(map_size, CELL_SIZE_M,
		TerrainConfig.WORLD_HEIGHT_MAX)

	var engine := TerrainEngineClass.new()
	engine.terrain_size = heightmap.size
	engine.cell_size = CELL_SIZE_M
	add_child(engine)
	engine.set_preset(preset)
	if not is_equal_approx(freq_scale, 1.0):
		for k in FREQ_KEYS:
			engine.params[k] = float(engine.params.get(k, 0.002)) * freq_scale
		engine._apply_params()
	var nt: int = int(NOISE_TYPES[noise_key])
	engine.base_noise.noise_type = nt
	engine.ridge_noise.noise_type = nt
	engine.detail_noise.noise_type = nt
	engine.warp_noise_x.noise_type = nt
	engine.warp_noise_y.noise_type = nt
	engine.target_relief = TerrainConfig.preset_relief(preset) / TerrainConfig.WORLD_HEIGHT_MAX
	engine.generate(seed_value)

	heightmap.data = engine.heightmap_data.duplicate()

	var h_min: float = 99999.0
	var h_max: float = -99999.0
	for n in heightmap.data:
		var m: float = float(n) * TerrainConfig.WORLD_HEIGHT_MAX
		h_min = minf(h_min, m)
		h_max = maxf(h_max, m)

	var sampler := func(p: Vector3) -> float:
		return heightmap.sample_world(p.x, p.z)

	# The zoning statics outlive a mission by design (ADR-010), so reset before
	# configuring or every preset after the first inherits the first one's ceiling.
	TerrainZoning.reset()
	TerrainZoning.configure(heightmap)
	var zone := func(h: float, wx: float, wz: float) -> int:
		return TerrainZoning.classify(h, wx, wz, seed_value)

	var sheet: Dictionary = TopoSheet.render(map_size, sampler, Callable(), zone)
	var name: String = "%s_%s_seed%d.png" % [TAG, _preset_name(preset), seed_value]
	(sheet.get("image") as Image).save_png("%s/%s" % [OUT_DIR, name])

	print("  %-30s relief %6.1fm  target %5.1fm  contour %4.1fm" % [name, h_max - h_min,
		TerrainConfig.preset_relief(preset), float(sheet.get("interval", 0.0))])
	engine.queue_free()


func _preset_name(preset: int) -> String:
	match preset:
		TerrainEngineClass.TerrainPreset.COASTAL_HILLS: return "coastal_hills"
		TerrainEngineClass.TerrainPreset.RIVER_VALLEY: return "river_valley"
		TerrainEngineClass.TerrainPreset.ROLLING_HILLS: return "rolling_hills"
		TerrainEngineClass.TerrainPreset.STEEP_MOUNTAINS: return "steep_mountains"
		TerrainEngineClass.TerrainPreset.PLATEAU: return "plateau"
	return "unknown"
