## test_save_roundtrip.gd - SaveManager slots: save -> mutate -> load -> assert
## every section survives byte-exact. Run: godot --headless --path . res://tests/test_save_roundtrip.tscn -- --test-save
extends Node

const TEST_SLOT := 7  # a manual slot the game never auto-writes


func _ready() -> void:
	_run()


func _run() -> void:
	var failures := 0
	CampaignState.reset_campaign()

	# --- author a distinctive state ---
	CampaignState.team_xp = 777
	CampaignState.missions_played = 5
	CampaignState.intel_points = 3
	CampaignState.roster = [{"name": "TEST MAN", "mos": "RTO", "nick": "RADIO",
		"st": 120, "ag": 110, "al": 130, "skills": {"fo_fac": 3},
		"skill_uses": {"fo_fac": 50}, "xp": 50, "kills": 9, "missions": 4, "alive": true}]
	SaveManager.context = "hub"
	SaveManager.hub_snapshot = {
		"operation_seed": 4242, "operation_name": "OP TEST",
		"offers": [{"type": 0, "mission_seed": 111}], "accepted_offer": {},
		"checkpoint_offer": {},
	}

	if not SaveManager.save_game(TEST_SLOT, "ROUNDTRIP"):
		print("FAIL: save_game returned false")
		failures += 1

	# --- wreck the live state ---
	CampaignState.reset_campaign()
	SaveManager.hub_snapshot = {}
	if CampaignState.team_xp == 777:
		print("FAIL: reset did not clear xp (test invalid)")
		failures += 1

	# --- load + apply ---
	var s: SaveData = SaveManager.load_game(TEST_SLOT)
	if s == null:
		print("FAIL: load_game returned null")
		failures += 1
	else:
		SaveManager.apply(s)
		if CampaignState.team_xp != 777:
			print("FAIL: team_xp %d != 777" % CampaignState.team_xp)
			failures += 1
		if CampaignState.missions_played != 5:
			print("FAIL: missions_played")
			failures += 1
		if CampaignState.roster.size() != 1 or str(CampaignState.roster[0].get("nick")) != "RADIO":
			print("FAIL: roster lost")
			failures += 1
		if int(CampaignState.roster[0].get("skill_uses", {}).get("fo_fac", 0)) != 50:
			print("FAIL: learn-by-doing counters lost")
			failures += 1
		if int(SaveManager.hub_snapshot.get("operation_seed", 0)) != 4242:
			print("FAIL: hub snapshot lost")
			failures += 1
		if SaveManager.pending_player == null:
			print("FAIL: pending player section not stashed")
			failures += 1

	# --- metadata-only read ---
	var info := SaveManager.get_save_info(TEST_SLOT)
	if str(info.get("save_name", "")) != "ROUNDTRIP":
		print("FAIL: get_save_info name")
		failures += 1
	if int(info.get("missions_played", -1)) != 5:
		print("FAIL: get_save_info missions")
		failures += 1

	# --- corrupt-file safety ---
	var f := FileAccess.open("user://saves/save_%d.sav" % TEST_SLOT, FileAccess.WRITE)
	f.store_string("{ not json !!!")
	f.close()
	if SaveManager.load_game(TEST_SLOT) != null:
		print("FAIL: corrupt save did not return null")
		failures += 1

	# --- tier gating ---
	CampaignState.iron_man = true
	SaveManager.context = "mission"
	if SaveManager.can_manual_save():
		print("FAIL: ironman allowed a field save")
		failures += 1
	SaveManager.context = "hub"
	if not SaveManager.can_manual_save():
		print("FAIL: ironman refused a hub save")
		failures += 1
	CampaignState.iron_man = false

	# cleanup
	DirAccess.remove_absolute("user://saves/save_%d.sav" % TEST_SLOT)
	CampaignState.reset_campaign()

	if failures == 0:
		print("PASS: save roundtrip (sections, meta, corrupt-safety, tier gating)")
	else:
		print("FAIL: %d save roundtrip failures" % failures)
	get_tree().quit(failures)
