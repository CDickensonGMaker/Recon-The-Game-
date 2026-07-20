## sight_cap.gd - Local sight ceiling from weather x vegetation x flare.
## One implementation for BOTH sides: a man's eyes obey the world, whichever
## army he is in.
class_name SightCap
extends RefCounted

## Metres. Sourced from EnemyBase so the two sides can never diverge by a retune.
static func open_range() -> float:
	return EnemyBase.SIGHT_CAP_OPEN


static func jungle_range() -> float:
	return EnemyBase.SIGHT_CAP_JUNGLE


## How far a man at `from_pos` can see toward `look_pos`. `grid` may be null.
static func at(grid: GameplayGrid, from_pos: Vector3, look_pos: Vector3) -> float:
	var mult: float = MissionWeather.sight_mult
	if mult < 0.9 and IllumFlare.is_lit(look_pos):
		mult = maxf(mult, 0.9)
	if grid == null:
		return open_range() * mult
	var veg: float = maxf(grid.get_vegetation(from_pos), grid.get_vegetation(look_pos))
	return lerpf(open_range(), jungle_range(), clampf(veg, 0.0, 1.0)) * mult
