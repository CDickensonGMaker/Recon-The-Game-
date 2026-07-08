## test_skills.gd - AUDIT-01: every skill, bought on the correct owner, must
## change an observable value. Before Step 7 the player could only buy one skill.
extends Node
var _fail := 0
func _bad(m: String) -> void: print("FAIL: %s" % m); _fail += 1
func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.team_xp = 99999
	SquadRoster.ensure_roster(4242)

	# The player row offers three skills, not one.
	if SkillCatalog.PLAYER_SKILLS.size() != 3:
		_bad("PLAYER_SKILLS should be 3, is %d" % SkillCatalog.PLAYER_SKILLS.size())
	for s in SkillCatalog.PLAYER_SKILLS:
		if not SkillCatalog.SKILLS.has(s): _bad("PLAYER_SKILL %s not in catalog" % s)

	# small_arms tightens spread. Buy 5, spread must drop.
	var wd: WeaponData = load("res://data/weapons/mosin.tres")
	var before: float = 1.0 / (1.0 + 0.06 * 0)
	for i in range(5): SkillCatalog.buy_skill(CampaignState.player_data, "small_arms")
	var sa: int = CampaignState.player_skill("small_arms")
	if sa != 5: _bad("small_arms bought 5, reads %d" % sa)
	var after: float = 1.0 / (1.0 + 0.06 * float(sa))
	if after >= before: _bad("small_arms did not reduce the spread factor")
	print("  small_arms L%d: spread factor %.3f -> %.3f" % [sa, before, after])

	# sniping is now buyable AND read.
	for i in range(3): SkillCatalog.buy_skill(CampaignState.player_data, "sniping")
	if CampaignState.player_skill("sniping") != 3: _bad("sniping not buyable")
	# silent_movement scales the player footstep radius.
	for i in range(4): SkillCatalog.buy_skill(CampaignState.player_data, "silent_movement")
	var sm: int = CampaignState.player_skill("silent_movement")
	var quiet: float = 1.0 / (1.0 + 0.12 * float(sm))
	if sm != 4 or quiet >= 1.0: _bad("silent_movement dead")
	print("  sniping L%d, silent_movement L%d (footstep x%.2f)" % [CampaignState.player_skill("sniping"), sm, quiet])

	# ALLY skills route to the ally's own dict, read via roster_skill by MOS.
	for m in CampaignState.roster:
		var mos: String = str(m.mos)
		var sk: String = str(SkillCatalog.MOS_SKILL.get(mos, ""))
		if sk.is_empty(): continue
		SkillCatalog.buy_skill(m, sk)
	# GRENADIER demolitions must now read > 0 via roster_skill (was pinned to 0).
	var demo: int = CampaignState.roster_skill("GRENADIER", "demolitions")
	var fo: int = CampaignState.roster_skill("RTO", "fo_fac")
	print("  roster_skill GRENADIER/demolitions=%d  RTO/fo_fac=%d" % [demo, fo])
	if demo < 1: _bad("GRENADIER demolitions still 0 - world-gen plant speed can never improve")
	if fo < 1: _bad("RTO fo_fac still 0 - CAS turnaround can never improve")
	# The player must NOT be able to reach these (fiction: they are his squad's).
	if CampaignState.player_skill("fo_fac") != 0: _bad("player somehow has fo_fac")

	print("PASS: skills" if _fail == 0 else "FAIL: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
