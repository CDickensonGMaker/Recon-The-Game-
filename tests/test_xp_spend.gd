## test_xp_spend.gd - W25-W29: XP economy + skill/attribute purchases + effects.
## Run: godot --headless --path . res://tests/test_xp_spend.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	CampaignState.reset_campaign()

	# 1. XP from a debrief score.
	var result := {"success": true, "objectives_done": 2, "objectives_total": 2, "kills": 8,
		"damage_taken": 20, "time_sec": 500.0, "emergency_exfil": false,
		"mission_type": "PATROL", "seed": 1}
	var score: int = DebriefScreen.compute_score(result)
	print("score=%d" % score)
	if score != 2 * 100 + 8 * 10 - 20 + 50:
		print("FAIL: score math wrong")
		failures += 1
	CampaignState.team_xp += maxi(0, score)

	# 2. Skill purchase for the player.
	var before_xp: int = CampaignState.team_xp
	if not SkillCatalog.buy_skill(CampaignState.player_data, "small_arms"):
		print("FAIL: could not buy small_arms")
		failures += 1
	if CampaignState.team_xp != before_xp - 150:
		print("FAIL: xp not deducted")
		failures += 1
	if CampaignState.player_skill("small_arms") != 1:
		print("FAIL: skill level not recorded")
		failures += 1

	# 3. Attribute purchase for a squad member.
	SquadRoster.ensure_roster(5)
	var member: Dictionary = CampaignState.roster[0]
	var st_before: int = int(member.st)
	if not SkillCatalog.buy_attribute(member, "st"):
		print("FAIL: attribute purchase failed")
		failures += 1
	if int(CampaignState.roster[0].st) != st_before + 5:
		print("FAIL: attribute not applied to roster")
		failures += 1

	# 4. Broke = no purchase.
	CampaignState.team_xp = 10
	if SkillCatalog.buy_skill(CampaignState.player_data, "medic"):
		print("FAIL: bought skill without XP")
		failures += 1

	# 5. Persistence.
	CampaignState.save_campaign()
	CampaignState.player_data = {}
	CampaignState.load_campaign()
	if CampaignState.player_skill("small_arms") != 1:
		print("FAIL: player skills not persisted")
		failures += 1

	CampaignState.reset_campaign()
	if failures == 0:
		print("PASS: XP economy + purchases + persistence OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d xp failures" % failures)
		get_tree().quit(1)
