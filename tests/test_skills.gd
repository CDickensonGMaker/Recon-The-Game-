## ADR-018 guard, both halves.
##
## SQUAD skills live: they improve by use and must change an OBSERVABLE value.
## PLAYER progression is DEAD: nothing he can earn may touch accuracy, recoil, sway,
## handling, health or stamina. A player-accuracy stat is hit-point math, and Pillar 1
## forbids it. This test goes red if anyone re-grows one.
extends Node

var _fail := 0


func _bad(m: String) -> void:
	print("FAIL: %s" % m)
	_fail += 1


func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.team_xp = 99999
	SquadRoster.ensure_roster(4242)

	_squad_skills_live()
	_player_progression_is_dead()

	print("PASS: skills" if _fail == 0 else "FAIL: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## ADR-018 s2: squad XP is kept, but SILENT and BEHAVIOURAL. Each MOS skill must
## reach a real system, or the veteran is indistinguishable from the rookie and
## Pillar 4 has no teeth.
func _squad_skills_live() -> void:
	for m in CampaignState.roster:
		var sk: String = str(SkillCatalog.MOS_SKILL.get(str(m.mos), ""))
		if not sk.is_empty():
			SkillCatalog.buy_skill(m, sk)

	var demo: int = CampaignState.roster_skill("GRENADIER", "demolitions")
	var fo: int = CampaignState.roster_skill("RTO", "fo_fac")
	var det: int = CampaignState.roster_skill("POINTMAN", "detect_ambush")
	var med: int = CampaignState.roster_skill("MEDIC", "medic")
	print("  squad: demolitions=%d fo_fac=%d detect_ambush=%d medic=%d" % [demo, fo, det, med])

	if demo < 1:
		_bad("GRENADIER demolitions 0 - charge plant speed can never improve")
	if fo < 1:
		_bad("RTO fo_fac 0 - fire support turnaround can never improve")
	if det < 1:
		_bad("POINTMAN detect_ambush 0 - he can never learn to spot the trip wire")
	if med < 1:
		_bad("MEDIC medic 0 - Doc can never get faster")


## ADR-018 s1: PLAYER STATS ARE KILLED. Your aim is your aim, mission 1 to 100.
func _player_progression_is_dead() -> void:
	var pd: Dictionary = CampaignState.player_data

	for stat: String in ["st", "ag", "al", "skills"]:
		if pd.has(stat):
			_bad("player_data still carries '%s' - ADR-018 killed the stat pool" % stat)

	if "PLAYER_SKILLS" in SkillCatalog:
		_bad("SkillCatalog.PLAYER_SKILLS is back - the player may not buy skills")
	if "ATTRIBUTE_COST" in SkillCatalog or "ATTRIBUTE_MAX" in SkillCatalog:
		_bad("SkillCatalog attribute purchase is back - ADR-018 killed St/Ag/Al")

	# The bullet must not care who is holding the rifle.
	var wd: WeaponData = load("res://data/weapons/m16a1.tres")
	if wd == null:
		_bad("m16a1.tres missing")
		return
	var hip: float = wd.get_spread(0.0)
	var ads: float = wd.get_spread(1.0)
	print("  m16a1 spread hip=%.4f ads=%.4f (weapon's own, unmodified)" % [hip, ads])
	if hip <= 0.0:
		_bad("m16a1 has no spread at the hip - a weapon stat went missing")

	# Jamming survives, but as the RIFLE's condition, never the player's skill.
	if not ("weapon_condition" in WeaponHolder.new()):
		_bad("weapon_condition gone - jamming must stay, tied to the weapon")
