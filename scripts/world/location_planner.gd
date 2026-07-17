extends RefCounted
## Location planner. Picks village, firebase, and camp positions BEFORE the
## world is built, so the terrain + water system can shape itself around
## them (lift nearby ground, drain water, anchor paddy fields).
##
## Deterministic by construction — same (mission_seed, map_size) always
## produces the same set of locations.
##
## The terrain engine runs first (so the heightmap exists). The location
## pass then runs and lifts the heightmap in a disk around each location
## to push the cell above sea level. The water system runs last and
## finds nothing to fill where the lift is.
##
## Layout strategy (centered):
##   - 1 firebase at AO center (must be the "safe" place)
##   - 8-10 villages in a ring 350-500m from center, evenly distributed
##   - 2-3 enemy camps in a ring 600-800m from center (between villages)
##
## The user said "8-10 villages in a map" and "larger variants from small
## village to larger small town" — this planner rolls a SIZE per village
## (HAMLET, VILLAGE, TOWN) so the AO has visual variety.

class_name LocationPlanner

## Village size variants. SMALL is 3-5 huts; TOWN has 8-12 huts + a fence.
enum VillageSize { SMALL, MEDIUM, LARGE }


## A planned location, before any nodes are placed.
## kind: "village" | "firebase" | "camp"
## size (village only): VillageSize
## center: Vector3 world position (XZ on flat land; Y will be filled by terrain sample)
class PlannedLocation:
	var kind: String = ""
	var size: int = 0  ## VillageSize; 0 for non-villages
	var center: Vector3 = Vector3.ZERO
	var label: String = ""  ## human-readable name for debug


## Roll the full set of locations for a mission seed.
## `terrain` is the WorldConfig MAP_SIZE (default 1280.0). Returns an
## Array[PlannedLocation] ordered: firebase first, then villages, then camps.
static func plan_locations(mission_seed: int, map_size: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed + 31337  # separate stream from paddy/mission

	var locations: Array = []

	# 1) Firebase at AO center. The whole point of location-first is to
	# guarantee the firebase sits on dry, safe ground.
	var fb := PlannedLocation.new()
	fb.kind = "firebase"
	fb.center = Vector3(map_size * 0.5, 0.0, map_size * 0.5)
	fb.label = "FIREBASE"
	locations.append(fb)

	# 2) Villages in a ring 350-500m from center, evenly distributed.
	# Count: 8 to 10 (user said 8-10 villages per AO).
	var village_count: int = rng.randi_range(8, 10)
	var inner_r: float = 350.0
	var outer_r: float = 500.0
	# Evenly distribute angles, then jitter each one for organic feel.
	for i in range(village_count):
		var base_angle: float = (float(i) / float(village_count)) * TAU
		var angle: float = base_angle + rng.randf_range(-0.15, 0.15)
		var radius: float = rng.randf_range(inner_r, outer_r)
		# Slight offset from center; pull position back so the village
		# center isn't on the firebase doorstep.
		var pos: Vector3 = Vector3(
			map_size * 0.5 + cos(angle) * radius,
			0.0,
			map_size * 0.5 + sin(angle) * radius
		)
		var v := PlannedLocation.new()
		v.kind = "village"
		# Size distribution: 50% SMALL, 35% MEDIUM, 15% LARGE.
		var size_roll: float = rng.randf()
		if size_roll < 0.50:
			v.size = VillageSize.SMALL
		elif size_roll < 0.85:
			v.size = VillageSize.MEDIUM
		else:
			v.size = VillageSize.LARGE
		v.center = pos
		v.label = "VILLAGE_%d" % i
		locations.append(v)

	# 3) Enemy camps in a ring 600-800m from center. Sits in the gaps
	# between villages so the firebase has multiple threats from
	# different directions.
	var camp_count: int = rng.randi_range(2, 3)
	for i in range(camp_count):
		var angle: float = (float(i) / float(camp_count)) * TAU + PI / float(camp_count)
		var radius: float = rng.randf_range(600.0, 800.0)
		var pos: Vector3 = Vector3(
			map_size * 0.5 + cos(angle) * radius,
			0.0,
			map_size * 0.5 + sin(angle) * radius
		)
		var c := PlannedLocation.new()
		c.kind = "camp"
		c.center = pos
		c.label = "CAMP_%d" % i
		locations.append(c)

	return locations


## Lift the heightmap around each location so it's above sea level.
## Locations live on FLAT, DRY land — that's the whole point of location-first.
## The lift is a smooth radial bump; cells inside the lift_radius get
## raised so their filled depth is below 0 (negative = "drainable").
## `lift_height_m` is the meters of bump at center, falling to 0 at the
## edge via cosine falloff.
static func apply_lifts(heightmap: RefCounted, locations: Array) -> void:
	const LIFT_RADIUS_M: float = 200.0
	const LIFT_HEIGHT_M: float = 18.0
	# Cap on the lifted cell value (normalized 0-1). 0.55 = 55% of height_scale.
	# With height_scale=460 (STEEP_MOUNTAINS), that's 253m. With
	# height_scale=60 (COASTAL_HILLS), that's 33m — enough to clear the
	# sea level and any standing-water threshold.
	const LIFT_FLOOR: float = 0.55

	var size: int = heightmap.size
	var cs: float = heightmap.cell_size
	var hs: float = heightmap.height_scale

	for loc in locations:
		var lp: PlannedLocation = loc as PlannedLocation
		if lp == null or lp.kind == "":
			continue
		var cgx: int = int(lp.center.x / cs)
		var cgz: int = int(lp.center.z / cs)
		var r_cells: int = int(ceil(LIFT_RADIUS_M / cs))
		for dz in range(-r_cells, r_cells + 1):
			for dx in range(-r_cells, r_cells + 1):
				var nx: int = cgx + dx
				var nz: int = cgz + dz
				if nx < 0 or nx >= size or nz < 0 or nz >= size:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz)) * cs
				if dist > LIFT_RADIUS_M:
					continue
				# Cosine falloff: 1.0 at center, 0.0 at edge.
				var falloff: float = 0.5 * (1.0 + cos(dist / LIFT_RADIUS_M * PI))
				var current: float = heightmap.get_cell(nx, nz)
				var bump_m: float = LIFT_HEIGHT_M * falloff
				var bump_normalized: float = bump_m / hs
				var lifted: float = maxf(current, minf(LIFT_FLOOR, current + bump_normalized))
				heightmap.set_cell(nx, nz, lifted)
