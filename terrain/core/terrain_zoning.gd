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
## no stream order. Same seed + same cell -> same zone, forever.

const RICE_PADDY := 1
const GRASSLAND := 2
const LIGHT_JUNGLE := 3
const MEDIUM_JUNGLE := 4
const HEAVY_JUNGLE := 5

## ADR-027-B: lowland is the open, inhabited rice plain; jungle begins in the hills.
const LOWLAND_MAX_H := 50.0
## ADR-027-D: rice-paddy fraction of the lowland (the +50% pass, 0.30 -> 0.45).
const PADDY_FRACTION := 0.45

## Patch-noise: low-frequency field carves coherent thickets and clearings.
const PATCH_FREQUENCY := 0.012
const OPEN_THRESHOLD := -0.18
const LIGHT_THRESHOLD := 0.05
const HEAVY_THRESHOLD := 0.28

static var _noise: FastNoiseLite = null
static var _noise_seed: int = 0


static func classify(height: float, world_x: float, world_z: float, world_seed: int) -> int:
	if height < LOWLAND_MAX_H:
		return RICE_PADDY if _paddy_roll(world_x, world_z, world_seed) < PADDY_FRACTION else GRASSLAND
	var patch: float = _patch_noise(world_seed).get_noise_2d(world_x, world_z)
	if patch < OPEN_THRESHOLD:
		return GRASSLAND
	elif patch < LIGHT_THRESHOLD:
		return LIGHT_JUNGLE
	elif patch < HEAVY_THRESHOLD:
		return MEDIUM_JUNGLE
	return HEAVY_JUNGLE


## Per-cell paddy draw. Fresh RNG seeded by (cell, seed) so the result is a pure function
## of position, not of iteration order.
static func _paddy_roll(world_x: float, world_z: float, world_seed: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([Vector2(world_x, world_z), world_seed])
	return r.randf()


static func _patch_noise(world_seed: int) -> FastNoiseLite:
	if _noise == null or _noise_seed != world_seed:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = PATCH_FREQUENCY
		_noise.seed = world_seed
		_noise_seed = world_seed
	return _noise
