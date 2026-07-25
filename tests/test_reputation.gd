## test_reputation.gd - ADR-032: hidden reputation, ranks, armory tiers.
##   1. Banked score -> level(): monotonic, capped at MAX_LEVEL, ranks fire in
##      order at levels 3/8/18/30, bank_reputation() is true ONLY on a rank rise.
##   2. Save/load round-trips reputation, including the pre-ADR-032 "team_xp" key.
##   3. The bench rack is title-gated: tier 0 hides the earned weapons, each tier
##      adds its own, and an incomplete .tres is never served at any tier.
##   4. NEVER A NUMBER: no screen renders the raw reputation or level as UI text.
## Run: godot --headless --path . res://tests/test_reputation.tscn -- --test-save
extends Node

var failures: int = 0


func _fail(msg: String) -> void:
	printerr("FAIL: " + msg)
	failures += 1


func _ready() -> void:
	print("=== REPUTATION / RANKS / ARMORY (ADR-032) ===")
	_test_ladder()
	_test_save_roundtrip()
	await _test_rack_tiers()
	await _test_never_a_number()
	CampaignState.reset_campaign()
	if failures == 0:
		print("PASS: reputation ladder / save migration / rack tiers / never-a-number")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_ladder() -> void:
	CampaignState.reset_campaign()
	if CampaignState.level() != 1 or CampaignState.title() != "PVT":
		_fail("fresh campaign is level %d '%s' (want 1 PVT)" % [
			CampaignState.level(), CampaignState.title()])

	# level() must never move backwards as reputation grows.
	var prev: int = 0
	for rep in range(0, 14000, 50):
		CampaignState.reputation = rep
		var lvl: int = CampaignState.level()
		if lvl < prev:
			_fail("level fell %d -> %d at rep %d" % [prev, lvl, rep])
		prev = lvl

	CampaignState.reputation = 10 * CampaignState.rep_for_level(CampaignState.MAX_LEVEL)
	if CampaignState.level() != CampaignState.MAX_LEVEL:
		_fail("level %d past the cap (want %d)" % [CampaignState.level(), CampaignState.MAX_LEVEL])

	# Rank milestones, crossed in order via the live bank point.
	CampaignState.reputation = 0
	var promotions: Array[String] = []
	for step in [
		CampaignState.rep_for_level(3), CampaignState.rep_for_level(8),
		CampaignState.rep_for_level(18), CampaignState.rep_for_level(30)]:
		var short_of: int = int(step) - 1 - CampaignState.reputation
		if CampaignState.bank_reputation(short_of):
			_fail("promotion fired 1 point BELOW the rep-%d gate" % int(step))
		if not CampaignState.bank_reputation(1):
			_fail("no promotion crossing rep %d" % int(step))
		promotions.append(CampaignState.title())
	if ",".join(promotions) != "PFC,SP4,SGT,SSG":
		_fail("promotion order was %s (want PFC,SP4,SGT,SSG)" % ",".join(promotions))
	if CampaignState.bank_reputation(999999):
		_fail("a promotion fired above the last rank")
	print("  ladder OK: PVT->PFC@L3->SP4@L8->SGT@L18->SSG@L30, cap %d" % CampaignState.MAX_LEVEL)


func _test_save_roundtrip() -> void:
	CampaignState.reset_campaign()
	CampaignState.reputation = 555
	CampaignState.save_campaign()
	CampaignState.reputation = 0
	CampaignState.load_campaign()
	if CampaignState.reputation != 555:
		_fail("reputation did not round-trip the cfg (got %d)" % CampaignState.reputation)

	# A pre-ADR-032 save banked the pool as "team_xp" - it must load as reputation.
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "version", CampaignState.SAVE_VERSION)
	cfg.set_value("campaign", "team_xp", 4321)
	cfg.save(CampaignState.save_path)
	CampaignState.reputation = 0
	CampaignState.load_campaign()
	if CampaignState.reputation != 4321:
		_fail("legacy team_xp key did not migrate (got %d, want 4321)" % CampaignState.reputation)

	CampaignState.from_dict({"team_xp": 222, "roster": []})
	if CampaignState.reputation != 222:
		_fail("SaveData dict with legacy team_xp did not migrate (got %d)" % CampaignState.reputation)
	print("  save round-trip + team_xp fallback OK")


func _test_rack_tiers() -> void:
	await get_tree().process_frame
	var t0: Array[String] = ArmorersBench.rack_for_tier(0)
	for locked in ["m14", "shotgun", "m60", "m70", "m79", "m72_law"]:
		if t0.has("res://data/weapons/%s.tres" % locked):
			_fail("tier 0 rack serves %s" % locked)
	for base in ["m16a1", "m1911", "ak47"]:
		if not t0.has("res://data/weapons/%s.tres" % base):
			_fail("tier 0 rack lost %s" % base)

	var t1: Array[String] = ArmorersBench.rack_for_tier(1)
	if not t1.has("res://data/weapons/m14.tres") or not t1.has("res://data/weapons/shotgun.tres"):
		_fail("tier 1 did not add the m14 + shotgun")
	if t1.has("res://data/weapons/m60.tres") or t1.has("res://data/weapons/m70.tres"):
		_fail("tier 1 leaked a higher gate")

	if not ArmorersBench.rack_for_tier(2).has("res://data/weapons/m60.tres"):
		_fail("tier 2 did not add the m60")
	if not ArmorersBench.rack_for_tier(3).has("res://data/weapons/m70.tres"):
		_fail("tier 3 did not add the m70")

	# Incomplete .tres never serves, at ANY tier - and if this ever fails because
	# the arms models landed, move the id up into the tier expectations above.
	var top: Array[String] = ArmorersBench.rack_for_tier(CampaignState.TITLES.size() - 1)
	for path: String in top:
		var data: WeaponData = load(path) as WeaponData
		if data == null or not ArmorersBench.tres_complete(data):
			_fail("top tier serves an incomplete weapon: %s" % path)
	for gap in ["m79", "m72_law"]:
		var gap_data: WeaponData = load("res://data/weapons/%s.tres" % gap) as WeaponData
		if ArmorersBench.tres_complete(gap_data):
			if not top.has("res://data/weapons/%s.tres" % gap):
				_fail("%s is complete now but the top tier does not serve it" % gap)
		elif top.has("res://data/weapons/%s.tres" % gap):
			_fail("%s has no arms viewmodel yet reached the rack" % gap)
	print("  rack tiers OK: 0=%d, top=%d entries, no incomplete weapon served" % [
		t0.size(), top.size()])


## The law of the decree: the pool and the level surface ONLY as a rank word and
## as rack contents. Plant unmistakable numbers, then scan every screen for them.
func _test_never_a_number() -> void:
	CampaignState.reset_campaign()
	CampaignState.reputation = 8887   # level 33, tier 4 - both digits distinctive
	var rep_s := str(CampaignState.reputation)
	var lvl_s := str(CampaignState.level())

	var barracks := BarracksScreen.new()
	add_child(barracks)
	var record := ServiceRecordScreen.new()
	add_child(record)
	var debrief := DebriefScreen.new()
	debrief.set_result({"success": true, "mission_type": "PATROL", "seed": 1})
	add_child(debrief)
	await get_tree().process_frame

	for screen: Node in [barracks, record, debrief]:
		if _any_label_contains(screen, rep_s):
			_fail("%s renders the raw reputation %s" % [screen.get_class(), rep_s])
		if _any_label_contains(screen, "XP"):
			_fail("%s still says XP on screen" % screen.get_class())
	# The level int is short, so only flag it where it stands alone as a word.
	for screen: Node in [barracks, record, debrief]:
		if _any_label_has_word(screen, lvl_s):
			_fail("%s renders the raw level %s" % [screen.get_class(), lvl_s])
	if not _any_label_contains(record, CampaignState.title()):
		_fail("service record does not carry the title word")
	if not _any_label_contains(debrief, CampaignState.title()):
		_fail("the AAR does not address you by title")

	barracks.queue_free()
	record.queue_free()
	debrief.queue_free()
	print("  never-a-number OK (screens carry '%s', never %s/level %s)" % [
		CampaignState.title(), rep_s, lvl_s])


func _any_label_contains(root: Node, needle: String) -> bool:
	if root is Label and str((root as Label).text).contains(needle):
		return true
	for c in root.get_children():
		if _any_label_contains(c, needle):
			return true
	return false


func _any_label_has_word(root: Node, word: String) -> bool:
	if root is Label:
		for token in str((root as Label).text).split(" ", false):
			if str(token).strip_edges() == word:
				return true
	for c in root.get_children():
		if _any_label_has_word(c, word):
			return true
	return false
