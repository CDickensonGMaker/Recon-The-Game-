class_name TerrainZoning
extends RefCounted

## THE ONE terrain-type classifier. Both the AI sight-cap grid (GameplayGrid) and the
## visible-jungle instancer (VegetationManager) MUST route their land classification here,
## or the jungle lies: the AI conceals against ground the player does not see (bead 6od4).
##
## Return values are ordinals shared by GameplayGrid.TerrainType and
## VegetationManager.TerrainType: CLEAR=0 RICE_PADDY=1 GRASSLAND=2 LIGHT_JUNGLE=3
## MEDIUM_JUNGLE=4 HEAVY_JUNGLE=5. WATER/CLIFF (6/7) are pathing-only overrides the
## callers apply BEFORE calling classify(); this function only zones walkable land.
##
## Pure function of (world position, seed) per ADR-010 — no global RNG, no per-frame draw,
## no stream order. The per-map lowland ceiling is seed-derived (configure() reads the
## seed-generated heightmap once); same seed + same cell -> same zone, forever.

const RICE_PADDY := 1
const GRASSLAND := 2
const LIGHT_JUNGLE := 3
const MEDIUM_JUNGLE := 4
const HEAVY_JUNGLE := 5

## Lowland (paddy country) is the low fraction of THIS map's own relief, not an absolute
## height. On a 132-207m highland map nothing is ever below an absolute 50m, so the old
## fixed gate produced zero paddies. configure() sets the ceiling from the heightmap.
const LOWLAND_RELIEF_FRACTION := 0.18

## Patch-noise carves coherent jungle thickets and open clearings. MEDIUM is the default
## cover the player moves through; GRASSLAND clearings and their LIGHT treeline rings break
## it up; HEAVY is the minority (it carries the LOS-block roll and the collider cost).
const PATCH_FREQUENCY := 0.010
const OPEN_THRESHOLD := -0.37
const LIGHT_THRESHOLD := -0.16
const HEAVY_THRESHOLD := 0.19

## Within lowland, a coarse noise band carves CONTIGUOUS paddy fields (below the threshold)
## with grassy margins (above), instead of a per-cell salt-and-pepper checkerboard.
const PADDY_NOISE_FREQUENCY := 0.006
const PADDY_THRESHOLD := 0.02

static var _noise: FastNoiseLite = null
static var _paddy_noise: FastNoiseLite = null
static var _noise_seed: int = 0
## Meters. INF until configure() runs; a cell is lowland when its height is below this.
static var _lowland_ceiling: float = INF


## Compute the per-map lowland ceiling ONCE from the heightmap, before any classify() call.
## Deterministic: the heightmap is seed-derived, so the ceiling is a pure function of the
## seed. terrain_manager.generate_terrain() calls this before chunk load; reset() clears it.
static func configure(heightmap: Object) -> void:
	var scale: float = heightmap.height_scale
	var mn: float = INF
	var mx: float = -INF
	for h: float in heightmap.data:
		mn = minf(mn, h)
		mx = maxf(mx, h)
	if mn == INF:
		_lowland_ceiling = INF
		return
	_lowland_ceiling = (mn + LOWLAND_RELIEF_FRACTION * (mx - mn)) * scale


## ADR-010: the noise fields and the lowland ceiling are statics that outlive mission
## teardown. MissionScope.reset() calls this so the next mission rebuilds them from its own
## seed/heightmap, never inheriting the last mission's world.
static func reset() -> void:
	_noise = null
	_paddy_noise = null
	_noise_seed = 0
	_lowland_ceiling = INF


static func classify(height: float, world_x: float, world_z: float, world_seed: int) -> int:
	if height < _lowland_ceiling:
		var pn: float = _paddy_field_noise(world_seed).get_noise_2d(world_x, world_z)
		return RICE_PADDY if pn < PADDY_THRESHOLD else GRASSLAND
	var patch: float = _patch_noise(world_seed).get_noise_2d(world_x, world_z)
	if patch < OPEN_THRESHOLD:
		return GRASSLAND
	elif patch < LIGHT_THRESHOLD:
		return LIGHT_JUNGLE
	elif patch < HEAVY_THRESHOLD:
		return MEDIUM_JUNGLE
	return HEAVY_JUNGLE


static func _patch_noise(world_seed: int) -> FastNoiseLite:
	if _noise == null or _noise_seed != world_seed:
		_rebuild_noise(world_seed)
	return _noise


static func _paddy_field_noise(world_seed: int) -> FastNoiseLite:
	if _paddy_noise == null or _noise_seed != world_seed:
		_rebuild_noise(world_seed)
	return _paddy_noise


## Both fields share the seed-guard so one rebuild reseeds both coherently.
static func _rebuild_noise(world_seed: int) -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = PATCH_FREQUENCY
	_noise.seed = world_seed
	_paddy_noise = FastNoiseLite.new()
	_paddy_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_paddy_noise.frequency = PADDY_NOISE_FREQUENCY
	_paddy_noise.seed = world_seed + 917  # decorrelate the paddy field from the patch field
	_noise_seed = world_seed
