## topo_sheet.gd - Pure renderer for the 1960s topographic base sheet.
## Tree-free and world-free on purpose: the game passes its live samplers, a probe
## passes a bare heightmap, and both get the identical image.
class_name TopoSheet
extends RefCounted

const MAP_PIXELS: int = 512

## Period-plausible contour intervals in metres, ascending. A real sheet picks the one
## that suits its ground - 20m through the Annamites, 5m supplementary in the delta -
## and a constant cannot serve a 25m coastal AO and a 300m massif at the same time.
const INTERVAL_LADDER: Array[float] = [2.0, 5.0, 10.0, 20.0, 25.0, 40.0, 50.0]
## Contour bands to aim for across the AO's measured relief. Too few and the sheet is
## blank; too many and the lines merge into unreadable ink.
const TARGET_BANDS: float = 15.0

## Percentile band the paper tone ramps across.
const TONE_PERCENTILE_LO: float = 0.05
const TONE_PERCENTILE_HI: float = 0.95


## Base paper for a TerrainZoning ordinal, darkened by elevation tone `t` (0-1).
## `px`/`py` drive the paddy stipple. Returns the screen the contours print over.
static func zone_paper(zone: int, t: float, px: int, py: int) -> Color:
	var tint: Color
	match zone:
		TerrainZoning.HEAVY_JUNGLE: tint = CANOPY_HEAVY
		TerrainZoning.MEDIUM_JUNGLE: tint = CANOPY_MEDIUM
		TerrainZoning.LIGHT_JUNGLE: tint = CANOPY_LIGHT
		TerrainZoning.RICE_PADDY:
			tint = PADDY_STIPPLE if (px + py) % 5 == 0 else PADDY
		_: tint = PAPER
	if zone == TerrainZoning.GRASSLAND or zone < TerrainZoning.RICE_PADDY:
		return PAPER.lerp(PAPER_HIGH, t)
	return tint.lerp(PAPER_HIGH, t * TONE_ON_TINT)


## The interval a sheet of this ground would have been drawn at.
static func choose_interval(relief_m: float) -> float:
	var wanted: float = relief_m / TARGET_BANDS
	for step in INTERVAL_LADDER:
		if step >= wanted:
			return step
	return INTERVAL_LADDER[INTERVAL_LADDER.size() - 1]

## 1960s paper palette
const PAPER := Color(0.87, 0.83, 0.70)
const PAPER_HIGH := Color(0.80, 0.74, 0.58)
const CONTOUR := Color(0.45, 0.36, 0.22)
const WATER := Color(0.55, 0.66, 0.72)
const GRID := Color(0.5, 0.42, 0.3, 0.35)

## Woodland screen. A real sheet prints vegetation as a flat green tint UNDER the brown
## linework - it is a screen, not a fill, so contours stay the readable layer on top.
## Tints are keyed to TerrainZoning's ordinals, which is the same classifier the AI sight
## grid and the visible jungle use: if the sheet disagrees with those, the map lies.
const CANOPY_LIGHT := Color(0.82, 0.84, 0.66)
const CANOPY_MEDIUM := Color(0.75, 0.80, 0.60)
const CANOPY_HEAVY := Color(0.66, 0.74, 0.53)
## Worked ground: paler and cooler than dry paper, carrying a stipple.
const PADDY := Color(0.82, 0.83, 0.73)
const PADDY_STIPPLE := Color(0.62, 0.66, 0.58)
## How far the elevation tone is allowed to darken a tint. Full-strength tone over green
## turns the highland canopy to mud, which is the defect this whole pass exists to kill.
const TONE_ON_TINT: float = 0.35

const GRID_SPACING_M: float = 100.0


## `height_at` takes Vector3 -> float. `is_water` takes Vector3 -> bool, or is an
## invalid Callable on worlds with no water system.
## Returns {image: Image, interval: float, relief_m: float} - the caller needs the
## interval because the sheet's own margin has to state what it was drawn at.
## `zone_at` takes (height_m, world_x, world_z) -> TerrainZoning ordinal, or is an
## invalid Callable to print the sheet with no woodland screen at all.
static func render(map_size: float, height_at: Callable, is_water: Callable,
		zone_at: Callable = Callable(), px_count: int = MAP_PIXELS) -> Dictionary:
	var img := Image.create(px_count, px_count, false, Image.FORMAT_RGB8)
	var heights := PackedFloat32Array()
	heights.resize(px_count * px_count)
	for py in range(px_count):
		for px in range(px_count):
			var wx: float = float(px) / float(px_count) * map_size
			var wz: float = float(py) / float(px_count) * map_size
			heights[py * px_count + px] = float(height_at.call(Vector3(wx, 0, wz)))
	var h_min: float = 99999.0
	var h_max: float = -99999.0
	for h in heights:
		h_min = minf(h_min, h)
		h_max = maxf(h_max, h)

	# Paper tone ramps over the bulk of the ground, not the absolute extremes: one
	# peak setting h_max compresses every metre the player actually walks into a
	# sliver of the range, and the sheet reads flat where it matters most.
	var ordered: PackedFloat32Array = heights.duplicate()
	ordered.sort()
	var t_lo: float = ordered[int(float(ordered.size() - 1) * TONE_PERCENTILE_LO)]
	var t_hi: float = ordered[int(float(ordered.size() - 1) * TONE_PERCENTILE_HI)]
	var t_span: float = maxf(1.0, t_hi - t_lo)
	var interval: float = choose_interval(h_max - h_min)
	var has_water: bool = is_water.is_valid()
	var has_zones: bool = zone_at.is_valid()
	for py in range(px_count):
		for px in range(px_count):
			var h: float = heights[py * px_count + px]
			var wx: float = float(px) / float(px_count) * map_size
			var wz: float = float(py) / float(px_count) * map_size
			var color: Color
			if has_water and bool(is_water.call(Vector3(wx, 0, wz))):
				color = WATER
			else:
				# floori, not int: int() truncates toward zero, which makes the band
				# straddling sea level twice as tall as every other band. Terrain is
				# currently all-positive, so this is defensive - water carving is the
				# thing that would put heights below zero and expose it.
				var band: int = floori(h / interval)
				var line := false
				if px + 1 < px_count and floori(heights[py * px_count + px + 1] / interval) != band:
					line = true
				elif py + 1 < px_count and floori(heights[(py + 1) * px_count + px] / interval) != band:
					line = true
				if line:
					color = CONTOUR
				else:
					var t: float = clampf((h - t_lo) / t_span, 0.0, 1.0)
					if has_zones:
						color = zone_paper(int(zone_at.call(h, wx, wz)), t, px, py)
					else:
						color = PAPER.lerp(PAPER_HIGH, t)
			var gx: float = fmod(wx, GRID_SPACING_M)
			var gz: float = fmod(wz, GRID_SPACING_M)
			if gx < map_size / float(px_count) or gz < map_size / float(px_count):
				color = color.lerp(GRID, GRID.a)
			img.set_pixel(px, py, color)
	return {"image": img, "interval": interval, "relief_m": h_max - h_min}
