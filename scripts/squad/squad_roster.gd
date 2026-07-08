## squad_roster.gd - SquadMember generation + roster persistence helpers (W14/W24).
class_name SquadRoster
extends RefCounted

const FIRST_NAMES: Array[String] = ["JOHNNY", "EDDIE", "RAY", "TOMMY", "HANK", "LEROY", "SAL", "DUANE", "CARL", "WILLIE", "FRANK", "JESSE", "EARL", "MARV", "GUS"]
const LAST_NAMES: Array[String] = ["MILLER", "JACKSON", "KOWALSKI", "REYES", "DUBOIS", "OBRIEN", "HAYES", "NAKAMURA", "STONE", "CARTER", "WOJCIK", "BAKER", "LONG", "PRICE", "GRIMES"]
const MOS_ORDER: Array[String] = ["POINT", "RTO", "MEDIC", "PIGMAN", "GRENADIER"]
const NICKNAMES := {"MEDIC": "DOC", "PIGMAN": "PIG", "RTO": "RADIO", "POINT": "EYES", "GRENADIER": "THUMPER"}


static func generate_member(rng: RandomNumberGenerator, mos: String) -> Dictionary:
	# RECON 2d100 attributes, 4-F reroll rule.
	var st: int = 0
	var ag: int = 0
	var al: int = 0
	for _attempt in range(20):
		st = rng.randi_range(1, 100) + rng.randi_range(1, 100)
		ag = rng.randi_range(1, 100) + rng.randi_range(1, 100)
		al = rng.randi_range(1, 100) + rng.randi_range(1, 100)
		if st + ag + al > 100 and mini(st, mini(ag, al)) >= 30:
			break
	return {
		"name": "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], LAST_NAMES[rng.randi() % LAST_NAMES.size()]],
		"mos": mos,
		"nick": str(NICKNAMES.get(mos, "GRUNT")),
		"st": st, "ag": ag, "al": al,
		"skills": {},   # skill_name -> level
		"kills": 0,
		"missions": 0,
		"alive": true,
	}


## Ensure CampaignState.roster has 5 living members; replaces KIA with rookies.
static func ensure_roster(rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var roster: Array = CampaignState.roster
	# Drop the dead (they stay in memory only via the log).
	var living: Array = []
	for m in roster:
		if bool(m.get("alive", true)):
			living.append(m)
	# Fill missing MOS slots with rookies.
	var have_mos: Array = []
	for m in living:
		have_mos.append(str(m.mos))
	for mos in MOS_ORDER:
		if living.size() >= 5:
			break
		if not have_mos.has(mos):
			living.append(generate_member(rng, mos))
			have_mos.append(mos)
	while living.size() < 5:
		living.append(generate_member(rng, MOS_ORDER[living.size() % MOS_ORDER.size()]))
	CampaignState.roster = living
	CampaignState.save_campaign()
	return living


static func skill_level(member: Dictionary, skill: String) -> int:
	return int((member.get("skills", {}) as Dictionary).get(skill, 0))
