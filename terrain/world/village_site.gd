extends Resource
## A procedurally-spawned village. The world holds a list of these, one per
## settlement. Each has a stable id keyed to the mission seed so reloads
## produce the same village. The villager families and linked hideouts are
## rolled at generation and frozen — only state transitions (PEACEFUL →
## ARMED → CLEARED) change after that.

enum VillageState { PEACEFUL, DORMANT_VC, ARMING, ARMED, CLEARED }

@export var village_id: String
@export var world_position: Vector2
@export var families: Array = []
@export var linked_hideouts: Array = []
@export var state: int = VillageState.PEACEFUL
## 0..1; when the player has been within ARMING_RADIUS for ARMING_DELAY seconds,
## the village starts arming. Filled in by the spawner so the rules file
## (HideoutRules) stays the single source of truth on the radii.
@export var arming_delay_seconds: float = 4.0
@export var arming_radius_meters: float = 35.0


static func roll_village(
	rng: RandomNumberGenerator,
	village_id_str: String,
	pos: Vector2,
	family_count: int,
) -> Resource:
	var Self := load("res://terrain/world/village_site.gd")
	var v: Resource = Self.new()
	v.village_id = village_id_str
	v.world_position = pos
	var FamilyScript := load("res://terrain/world/villager_family.gd")
	for i in family_count:
		var fid := "%s_family_%d" % [village_id_str, i]
		v.families.append(FamilyScript.roll_family(rng, fid))
	return v


func total_villagers() -> int:
	var n: int = 0
	for f in families:
		n += f.total_villagers()
	return n


func total_vc() -> int:
	var n: int = 0
	for f in families:
		n += f.vc_count()
	return n


func all_hideouts_cleared() -> bool:
	if linked_hideouts.is_empty():
		return false
	for h in linked_hideouts:
		if not h.is_cleared:
			return false
	return true
