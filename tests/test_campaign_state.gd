## test_campaign_state.gd - W01/W02/W03: persistence, modifier decay, AA payoff.
## Run: godot --headless --path . res://tests/test_campaign_state.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	CampaignState.reset_campaign()

	# Baseline.
	if absf(CampaignState.effective_threat() - CampaignState.BASE_THREAT) > 0.001:
		print("FAIL: baseline threat wrong")
		failures += 1

	# ANTI-AA success applies a -0.25 modifier for 3 missions.
	CampaignState.on_mission_end({"success": true, "is_anti_aa": true, "kills": 8, "mission_type": "ANTI-AA SWEEP", "seed": 1})
	var after_aa: float = CampaignState.effective_threat()
	print("threat after ANTI-AA: %.2f (%s)" % [after_aa, CampaignState.threat_label()])
	if after_aa >= CampaignState.BASE_THREAT - 0.1:
		print("FAIL: ANTI-AA did not lower threat")
		failures += 1

	# Modifier decays out after 3 more missions.
	for i in range(3):
		CampaignState.on_mission_end({"success": true, "kills": 5, "mission_type": "PATROL", "seed": 2 + i})
	if CampaignState.threat_modifiers.size() != 0:
		print("FAIL: modifier did not decay (%d left)" % CampaignState.threat_modifiers.size())
		failures += 1

	# Loud missions raise the baseline.
	var before_loud: float = CampaignState.threat_level
	CampaignState.on_mission_end({"success": true, "kills": 20, "mission_type": "VILLAGE RAID", "seed": 9})
	if CampaignState.threat_level <= before_loud:
		print("FAIL: loud mission did not raise threat")
		failures += 1

	# Opportunistic AA kills apply modifiers.
	CampaignState.on_mission_end({"success": true, "kills": 4, "aa_killed": 2, "mission_type": "PATROL", "seed": 10})
	if CampaignState.threat_modifiers.size() == 0:
		print("FAIL: aa_killed did not add modifier")
		failures += 1

	# Persistence round-trip.
	CampaignState.reputation = 555
	CampaignState.save_campaign()
	CampaignState.reputation = 0
	CampaignState.missions_played = 0
	CampaignState.load_campaign()
	if CampaignState.reputation != 555 or CampaignState.missions_played != 6:
		print("FAIL: persistence broken (rep=%d missions=%d)" % [CampaignState.reputation, CampaignState.missions_played])
		failures += 1

	CampaignState.reset_campaign()
	if failures == 0:
		print("PASS: campaign state + threat meta OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d campaign failures" % failures)
		get_tree().quit(1)
