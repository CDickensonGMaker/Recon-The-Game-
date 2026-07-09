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
	var member := {
		"name": "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], LAST_NAMES[rng.randi() % LAST_NAMES.size()]],
		"mos": mos,
		"nick": str(NICKNAMES.get(mos, "GRUNT")),
		"st": st, "ag": ag, "al": al,
		"skills": {},        # skill_name -> level (rolled below - no blank recruits)
		"skill_uses": {},    # skill_name -> cumulative use-points (learn-by-doing)
		"xp": 0,             # personal XP, separate from the player's team_xp
		"kills": 0,
		"missions": 0,
		"alive": true,
	}
	_roll_starting_skills(member, rng)
	return member


## No blank recruits (War Room decree): MOS skill guaranteed L1-3 by aptitude, plus
## 0-2 al-weighted extra skills at L1. Every recruit reads as a distinct person at spawn.
static func _roll_starting_skills(member: Dictionary, rng: RandomNumberGenerator) -> void:
	var skills: Dictionary = {}
	var al: int = int(member.get("al", 100))
	var mos_skill: String = str(SkillCatalog.MOS_SKILL.get(str(member.get("mos", "")), ""))
	if mos_skill != "" and SkillCatalog.SKILLS.has(mos_skill):
		var lvl: int = 1 + (1 if al > 110 else 0) + (1 if al > 150 else 0)  # L1-3 by aptitude
		skills[mos_skill] = mini(lvl, int(SkillCatalog.SKILLS[mos_skill].max))
	# 0-2 extra skills, likelier for sharp (high-al) men.
	var extras: int = 0
	if rng.randf() < clampf(float(al) / 220.0, 0.15, 0.85):
		extras += 1
	if rng.randf() < clampf(float(al) / 320.0, 0.05, 0.55):
		extras += 1
	var pool: Array = SkillCatalog.SKILLS.keys()
	for _i in range(extras):
		var pick: String = str(pool[rng.randi() % pool.size()])
		if not skills.has(pick):
			skills[pick] = 1
	member["skills"] = skills


## Learn-by-doing: add `n` use-points toward a member's skill, leveling it up when the
## cumulative curve is crossed. Mutates `member` in place (it IS the roster dict, so
## growth persists at the next campaign save - no disk write here, the mission-end save
## carries it). Returns the new level if a PROMOTION happened this call (so the caller
## can bark it), else 0. Only touches skills, never attributes (decree: no hoarding).
static func credit_use(member: Dictionary, skill: String, n: int = 1) -> int:
	if member.is_empty() or not SkillCatalog.SKILLS.has(skill) or n <= 0:
		return 0
	var uses: Dictionary = member.get("skill_uses", {})
	var total: int = int(uses.get(skill, 0)) + n
	uses[skill] = total
	member["skill_uses"] = uses
	member["xp"] = int(member.get("xp", 0)) + n
	var skills: Dictionary = member.get("skills", {})
	var level: int = int(skills.get(skill, 0))
	var cap: int = int(SkillCatalog.SKILLS[skill].max)
	var promoted: int = 0
	while level < cap and total >= SkillCatalog.uses_for_level(level + 1):
		level += 1
		promoted = level
	if promoted > 0:
		skills[skill] = level
		member["skills"] = skills
	return promoted


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
	# Back-fill fields added after an older save was written (learn-by-doing).
	for m in living:
		if not m.has("skill_uses"):
			m["skill_uses"] = {}
		if not m.has("xp"):
			m["xp"] = 0
		if not m.has("skills"):
			m["skills"] = {}
	CampaignState.roster = living
	CampaignState.save_campaign()
	return living


static func skill_level(member: Dictionary, skill: String) -> int:
	return int((member.get("skills", {}) as Dictionary).get(skill, 0))
