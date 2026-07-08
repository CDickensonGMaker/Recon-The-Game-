## skill_catalog.gd - RECON skill definitions + XP costs + spend logic (W27/W28).
class_name SkillCatalog
extends RefCounted

## skill_id -> {name, cost, desc, max}
const SKILLS := {
	"small_arms": {"name": "SMALL ARMS", "cost": 150, "desc": "Tighter spread with all small arms", "max": 8},
	"medic": {"name": "MEDIC", "cost": 100, "desc": "Faster revives, more HP restored", "max": 8},
	"detect_ambush": {"name": "DETECT AMBUSH", "cost": 100, "desc": "Point man warning radius", "max": 8},
	"demolitions": {"name": "DEMOLITIONS", "cost": 100, "desc": "Faster, surer charge planting", "max": 8},
	"fo_fac": {"name": "FO/FAC", "cost": 100, "desc": "Faster air support turnaround", "max": 8},
	"silent_movement": {"name": "SILENT MOVEMENT", "cost": 100, "desc": "Quieter footsteps", "max": 8},
	"sniping": {"name": "SNIPING", "cost": 100, "desc": "Long-range accuracy bonus", "max": 8},
}

const ATTRIBUTE_COST: int = 100
const ATTRIBUTE_MAX: int = 200  # 2d100 ceiling (RECON)

## MOS -> the skill their role consumes.
## The three skills whose EFFECT lives on the player's own body: his rifle
## (small_arms, sniping) and his own footsteps (silent_movement). Everything else
## belongs to a squadmate's role - see MOS_SKILL - and is bought on his row.
const PLAYER_SKILLS: Array[String] = ["small_arms", "sniping", "silent_movement"]

const MOS_SKILL := {
	"POINT": "detect_ambush",
	"RTO": "fo_fac",
	"MEDIC": "medic",
	"PIGMAN": "small_arms",
	"GRENADIER": "demolitions",
	"RIFLEMAN": "small_arms",
}


static func buy_skill(target: Dictionary, skill_id: String) -> bool:
	if not SKILLS.has(skill_id):
		return false
	var def: Dictionary = SKILLS[skill_id]
	var skills: Dictionary = target.get("skills", {})
	var level: int = int(skills.get(skill_id, 0))
	if level >= int(def.max) or CampaignState.team_xp < int(def.cost):
		return false
	CampaignState.team_xp -= int(def.cost)
	skills[skill_id] = level + 1
	target["skills"] = skills
	CampaignState.save_campaign()
	return true


static func buy_attribute(target: Dictionary, attr: String) -> bool:
	if not ["st", "ag", "al"].has(attr):
		return false
	var value: int = int(target.get(attr, 100))
	if value >= ATTRIBUTE_MAX or CampaignState.team_xp < ATTRIBUTE_COST:
		return false
	CampaignState.team_xp -= ATTRIBUTE_COST
	target[attr] = value + 5
	CampaignState.save_campaign()
	return true
