## sight_cap.gd - Local sight ceiling from weather x darkness x vegetation x flare.
## One implementation for BOTH sides: a man's eyes obey the world, whichever
## army he is in.
class_name SightCap
extends RefCounted

## Darkness multiplier indexed by SimClock.Period (DAWN, DAY, DUSK, NIGHT).
## DAWN and DAY are both 1.0 so an unpinned clock never darkens sight: SimClock
## free-runs from a 06:00 (DAWN) default toward DAY, so a probe or the arena that
## never sets the hour stays at 1.0. Darkness only bites once the world sets the
## hour into DUSK/NIGHT (MissionWeather.setup does this per the mission's time).
const DARKNESS_BY_PERIOD: Array[float] = [1.0, 1.0, 0.75, 0.4]

## Metres. Sourced from EnemyBase so the two sides can never diverge by a retune.
static func open_range() -> float:
	return EnemyBase.SIGHT_CAP_OPEN


static func jungle_range() -> float:
	return EnemyBase.SIGHT_CAP_JUNGLE


## Sight multiplier from time-of-day alone. 1.0 = full daylight range.
static func darkness_mult() -> float:
	var period: int = SimClock.period_at(SimClock.sim_hour)
	if period < 0 or period >= DARKNESS_BY_PERIOD.size():
		return 1.0
	return DARKNESS_BY_PERIOD[period]


## How far a man at `from_pos` can see toward `look_pos`. `grid` may be null.
static func at(grid: GameplayGrid, from_pos: Vector3, look_pos: Vector3) -> float:
	var mult: float = MissionWeather.sight_mult * darkness_mult()
	if mult < 0.9 and IllumFlare.is_lit(look_pos):
		mult = maxf(mult, 0.9)
	if grid == null:
		return open_range() * mult
	var veg: float = maxf(grid.get_vegetation(from_pos), grid.get_vegetation(look_pos))
	return lerpf(open_range(), jungle_range(), clampf(veg, 0.0, 1.0)) * mult
