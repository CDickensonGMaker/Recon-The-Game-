extends RefCounted
class_name VillageSpawner
## Rolls villages + linked hideouts for a mission. Deterministic by
## construction — the same (mission_seed, map_size) always produces the
## same set of villages with the same villagers and hideout positions.
## (RECONgame-bx2m)

const HideoutRulesScript := preload("res://terrain/world/hideout_rules.gd")
const VillageSiteScript := preload("res://terrain/world/village_site.gd")
const HideoutRefScript := preload("res://terrain/world/hideout_ref.gd")
const HideoutType := HideoutRulesScript.HideoutType

const MAX_SAMPLE_ATTEMPTS_PER_HIDEOUT: int = 64
const VILLAGE_COUNT_MIN: int = 8
const VILLAGE_COUNT_MAX: int = 10
const FAMILIES_PER_VILLAGE_MIN: int = 2
const FAMILIES_PER_VILLAGE_MAX: int = 5

static func hideout_count_for(family_count: int) -> int:
	if family_count <= 2:
		return 1
	if family_count <= 4:
		return 2
	return 3


static func type_for_index(idx: int) -> int:
	if idx == 0:
		return HideoutType.CAMP
	return HideoutType.TUNNEL


## Sample villages + hideouts across the playable AO. Returns the full
## list; downstream code (GameplayGrid, AI director) registers them.
static func sample_world(mission_seed: int, map_size: float, firebases: Array[Vector2]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed

	var villages: Array = []
	var all_hideouts: Array[Vector2] = []
	var village_count: int = rng.randi_range(VILLAGE_COUNT_MIN, VILLAGE_COUNT_MAX)

	for vi in village_count:
		var village_pos := _sample_village_position(rng, map_size, firebases, villages)
		if village_pos == Vector2.INF:
			continue
		if not HideoutRulesScript.village_location_legal(village_pos, firebases):
			continue

		var family_count: int = rng.randi_range(FAMILIES_PER_VILLAGE_MIN, FAMILIES_PER_VILLAGE_MAX)
		var village_id_str := "village_%d" % vi
		var village: Resource = VillageSiteScript.roll_village(
			rng, village_id_str, village_pos, family_count
		)
		villages.append(village)

		var h_count: int = hideout_count_for(family_count)
		for hi in h_count:
			var h_type: int = type_for_index(hi)
			var hideout: Resource = _sample_hideout(
				rng, village_pos, h_type, all_hideouts, firebases, vi, hi
			)
			if hideout != null:
				village.linked_hideouts.append(hideout)
				all_hideouts.append(hideout.world_position)

	return villages


## Try to find a position for a hideout that satisfies all spatial rules.
## Returns null if the rules reject every candidate in the budget.
static func _sample_hideout(
	rng: RandomNumberGenerator,
	village_pos: Vector2,
	hideout_type: int,
	other_hideouts: Array[Vector2],
	firebases: Array[Vector2],
	village_idx: int,
	hideout_idx: int,
) -> Resource:
	for attempt in MAX_SAMPLE_ATTEMPTS_PER_HIDEOUT:
		var r: float = rng.randf_range(
			HideoutRulesScript.VILLAGE_RADIUS_MIN,
			HideoutRulesScript.VILLAGE_RADIUS_MAX
		)
		var a: float = rng.randf() * TAU
		var proposed: Vector2 = village_pos + Vector2(cos(a), sin(a)) * r

		if not HideoutRulesScript.is_legal(
			proposed, hideout_type, village_pos, other_hideouts, firebases
		):
			continue

		var h := HideoutRefScript.new()
		h.hideout_id = "hideout_%d_%d" % [village_idx, hideout_idx]
		h.world_position = proposed
		h.type = hideout_type
		h.defender_count = 2 if hideout_type == HideoutType.CAMP else 3
		h.angle_from_village = rad_to_deg(a) as float
		h.distance_from_village = r
		return h
	return null


## Find a village seed point on flat ground, away from firebases, away from
## other villages. Rejection sampling with a budget. Returns Vector2.INF
## if no legal point found in the budget.
static func _sample_village_position(
	rng: RandomNumberGenerator,
	map_size: float,
	firebases: Array[Vector2],
	existing_villages: Array,
) -> Vector2:
	const ATTEMPTS: int = 256
	## Village-to-village separation: 1.5x the firebase band so two villages
	## never compete for the same firebase's doorstep.
	const VILLAGE_SEPARATION: float = HideoutRulesScript.VILLAGE_FIREBASE_MAX * 1.5
	for attempt in ATTEMPTS:
		var p: Vector2 = Vector2(
			rng.randf_range(80.0, map_size - 80.0),
			rng.randf_range(80.0, map_size - 80.0),
		)
		# Reject if too close to an existing village
		var too_close: bool = false
		for v in existing_villages:
			if p.distance_to(v.world_position) < VILLAGE_SEPARATION:
				too_close = true
				break
		if too_close:
			continue
		# Reject if in the firebase danger zone (the village must be 250-400m
		# from any firebase, NOT on top of one)
		var in_legal_band: bool = true
		for fb in firebases:
			var d: float = p.distance_to(fb)
			if d < HideoutRulesScript.VILLAGE_FIREBASE_MIN:
				in_legal_band = false
				break
		if not in_legal_band:
			continue
		return p
	return Vector2.INF
