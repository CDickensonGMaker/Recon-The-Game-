extends RefCounted
class_name TerrainConfig
## THE vertical scale contract for the terrain engine.
##
## `WORLD_HEIGHT_MAX` is the world-space meaning of a normalized heightmap value of
## 1.0. Every conversion between normalized data and meters resolves to this number,
## and nothing else may declare it. `tests/test_height_authority.gd` enforces that by
## scanning source, and binds the terrain shader's uniform default to it by text
## (GDScript cannot share a const into a .gdshader).
##
## The per-preset relief table lives here with the cap because the two are one unit:
## `target_relief = preset_relief(preset) / WORLD_HEIGHT_MAX` must stay <= 1.0, so a
## preset can never be raised without checking it against the cap in the same file.
##
## To retune the vertical scale of a world, change it here. There is no second place.

const WORLD_HEIGHT_MAX: float = 350.0

enum Preset {
	COASTAL_HILLS,
	RIVER_VALLEY,
	ROLLING_HILLS,
	STEEP_MOUNTAINS,
	PLATEAU,
}


## Target peak-to-valley relief in meters for an AO archetype. Tied directly to the
## relief budgets in tests/test_terrain_relief_bounds.gd. Must never exceed
## WORLD_HEIGHT_MAX. (RECONgame-p7wx)
static func preset_relief(preset: int) -> float:
	match preset:
		Preset.COASTAL_HILLS:
			return 25.0
		Preset.RIVER_VALLEY:
			return 40.0
		Preset.ROLLING_HILLS:
			return 90.0
		Preset.STEEP_MOUNTAINS:
			return 200.0
		Preset.PLATEAU:
			return 160.0
		_:
			return 90.0
