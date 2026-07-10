## mission_offers.gd - The single source for rolling mission offers. Used by the
## HQ-tent board (hub) and the legacy MissionSelect screen (now the seed-replay
## dev tool) so the two can never drift apart.
class_name MissionOffers
extends RefCounted

const TERRAIN_HINTS: Array[String] = ["TRIPLE-CANOPY JUNGLE", "PADDY LOWLANDS", "HIGHLAND SCRUB", "RIVERINE VALLEY"]
const STRENGTHS: Array[String] = ["LIGHT", "MODERATE", "HEAVY"]


## Three offers, deterministic from `rng` (manual Fisher-Yates - Array.shuffle()
## draws from the GLOBAL rng, proven non-reproducible in probe_smoke_all C).
static func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var types := [MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID,
		MissionGenerator.MissionType.FIREBASE_DEFENSE, MissionGenerator.MissionType.ANTI_AA,
		MissionGenerator.MissionType.RESCUE]
	for i in range(types.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = types[i]
		types[i] = types[j]
		types[j] = tmp
	for i in range(3):
		var mission_seed: int = rng.randi() % 100000
		var conditions: Dictionary = MissionGenerator.conditions_for(mission_seed)
		offers.append({
			"type": types[i],
			"type_name": str(MissionGenerator.TYPE_NAMES[types[i]]),
			"world_seed": mission_seed,  # R88: ONE seed identifies ONE operation
			"mission_seed": mission_seed,
			"codename": MissionGenerator.codename_for(mission_seed),
			"terrain_hint": TERRAIN_HINTS[rng.randi() % TERRAIN_HINTS.size()],
			"strength": STRENGTHS[rng.randi() % STRENGTHS.size()],
			"weather": str(conditions.weather),
			"time": str(conditions.time),
			"complications": MissionGenerator.complications_for(mission_seed),
		})
	return offers
