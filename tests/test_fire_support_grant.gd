## test_fire_support_grant.gd - does the AO's threat tier actually release air?
##
## _grant_fire_support() handed out napalm/spooky/cbu = 0 unconditionally, so three
## fully-built, key-bound fire-support verbs were unreachable in every playthrough.
## They are now bought with the player's own noise: CampaignState.threat_label(),
## the same LOW/MODERATE/HIGH/CRITICAL string shown at barracks.gd:45.
##
## THE NEGATIVE CONTROL IS THE POINT. The bug was "always zero", so proving the
## verbs can appear is worth nothing unless we also prove they stay at zero on a
## cold AO - otherwise the fix is just "always one".
extends Node

var _failures: int = 0

## Tier -> expected grant. bombs/arty/mortar are the routine allotment and must not
## move with threat; only the air does.
const CASES: Array[Dictionary] = [
	{"threat": 0.10, "tier": "LOW", "napalm": 0, "cbu": 0, "spooky": 0},
	{"threat": 0.35, "tier": "MODERATE", "napalm": 0, "cbu": 0, "spooky": 0},
	{"threat": 0.60, "tier": "HIGH", "napalm": 1, "cbu": 1, "spooky": 0},
	{"threat": 0.90, "tier": "CRITICAL", "napalm": 1, "cbu": 1, "spooky": 1},
]


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	print("=== PROBE: FIRE SUPPORT GRANT vs AO THREAT ===")
	CampaignState.reset_campaign()

	# BASE_THREAT is what a fresh campaign starts on. If that tier releases air, the
	# escalation ladder is decorative - everyone gets napalm on patrol one.
	if CampaignState.threat_label() != "MODERATE":
		_fail("a fresh campaign reads '%s', expected MODERATE - the case table is stale" % \
			CampaignState.threat_label())

	print("")
	print("| threat | tier      | bombs | arty | mortar | napalm | spooky | cbu |")
	print("|--------|-----------|-------|------|--------|--------|--------|-----|")
	for c in CASES:
		_check(c)

	# ADR-011 danger close is a PRECONDITION, not a budget. Granting more ordnance
	# must never widen or skip the confirm - these are the numbers that gate it.
	if FieldDirector.DANGER_CLOSE_M != 45.0:
		_fail("DANGER_CLOSE_M is %.1f, not 45.0 - the danger-close radius moved" % \
			FieldDirector.DANGER_CLOSE_M)
	if FieldDirector.DANGER_CLOSE_CONFIRM_S != 5.0:
		_fail("DANGER_CLOSE_CONFIRM_S is %.1f, not 5.0 - the confirm window moved" % \
			FieldDirector.DANGER_CLOSE_CONFIRM_S)

	print("")
	CampaignState.reset_campaign()
	if _failures == 0:
		print("PASS: air is released by threat tier, and stays dark on a cold AO")
	else:
		print("FAIL: %d fire-support grant failures" % _failures)
	get_tree().quit(_failures)


func _check(c: Dictionary) -> void:
	CampaignState.threat_modifiers.clear()
	CampaignState.threat_level = float(c.threat)
	var tier: String = CampaignState.threat_label()
	if tier != str(c.tier):
		_fail("threat %.2f reads '%s', case table says '%s'" % [float(c.threat), tier, str(c.tier)])

	var director := FieldDirector.new()
	director._grant_fire_support()
	var fs: Dictionary = director.fire_support.duplicate()
	director.free()

	print("| %6.2f | %-9s | %5d | %4d | %6d | %6d | %6d | %3d |" % [
		float(c.threat), tier, int(fs.bombs), int(fs.arty), int(fs.mortar),
		int(fs.napalm), int(fs.spooky), int(fs.cbu)])

	for verb in ["napalm", "spooky", "cbu"]:
		var want: int = int(c[verb])
		var got: int = int(fs[verb])
		if got == want:
			continue
		if want == 0:
			_fail("NEGATIVE CONTROL LEAKED: %s granted %d on a %s AO - air must stay dark" % [
				verb, got, tier])
		else:
			_fail("%s granted %d on a %s AO, expected %d - the verb is still unreachable" % [
				verb, got, tier, want])

	# The routine allotment is a battalion decision, not a threat readout.
	if int(fs.bombs) != 1 or int(fs.arty) != 1:
		_fail("routine allotment moved with threat: bombs %d, arty %d (want 1/1) on %s" % [
			int(fs.bombs), int(fs.arty), tier])
	if int(fs.mortar) != 3:
		_fail("mortar is %d on %s, want 3 with no RTO (fo_fac 0)" % [int(fs.mortar), tier])
