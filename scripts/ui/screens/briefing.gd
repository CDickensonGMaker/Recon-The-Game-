## briefing.gd - RECON 7-element mission briefing (NS19). Intel is fuzzed.
class_name BriefingScreen
extends Control

signal deploy_pressed
signal back_pressed

var offer: Dictionary = {}


func set_offer(o: Dictionary) -> void:
	offer = o


func _briefing_text() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(offer.mission_seed) + 13
	var support := "NONE"
	var objectives := ""
	var special := ""
	match int(offer.type):
		MissionGenerator.MissionType.PATROL:
			objectives = "SWEEP ASSIGNED ROUTE. CLEAR ALL CHECKPOINTS.\n   LOCATE SUSPECTED VC CACHE (SECONDARY)."
			special = "AVOID DECISIVE ENGAGEMENT. TRAIL WATCHERS REPORTED."
			support = "NONE - YOU ARE ALONE OUT THERE"
		MissionGenerator.MissionType.VILLAGE_RAID:
			objectives = "DESTROY ENEMY MATERIEL IN THE VILLE.\n   NEUTRALIZE THE GARRISON."
			special = "DEMO CHARGE REQUIRED ON PRIMARY TARGET. [F] TO PLANT."
			support = "1 CAS SORTIE ON STATION. [T] TO CALL."
		MissionGenerator.MissionType.FIREBASE_DEFENSE:
			objectives = "HOLD THE FIREBASE AGAINST ALL ASSAULT WAVES."
			special = "FRIENDLY SQUAD IN POSITION. DO NOT LET THE WIRE FALL."
			support = "3 CAS SORTIES ON STATION. [T] TO CALL."
	var est: int = rng.randi_range(4, 12)
	# W80: gathered intel sharpens the estimate.
	var fuzz_span: float = 0.4 / (1.0 + 0.5 * float(CampaignState.intel_points))
	var fuzz: float = 1.0 + rng.randf_range(-fuzz_span, fuzz_span)
	var lines := [
		"%s" % offer.codename,
		"CLASSIFICATION: SECRET // MACV-SOG",
		"",
		"1. INSERTION:  HELIBORNE, SINGLE LZ. WALK-ON THIS OPERATION.",
		"2. FIRE SUPPORT:  %s" % support,
		"3. ENEMY:  %s ACTIVITY. EST %d-%d FIGHTERS IN AO. INTEL CONFIDENCE: MARGINAL." % [offer.strength, int(float(est) * fuzz * 0.7), int(float(est) * fuzz * 1.5)],
		"4. TERRAIN/WX:  %s. VISIBILITY LIMITED UNDER CANOPY." % offer.terrain_hint,
		"5. OBJECTIVES:  %s" % objectives,
		"6. SPECIAL:  %s" % special,
		"7. EXTRACTION:  BIRD ON CALL AT MARKED LZ. FALLBACK LZ DESIGNATED.",
		"   HOLD [G] TO ABORT MISSION - EMERGENCY EXFIL.",
	]
	return "\n".join(lines)


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.add_theme_constant_override("separation", 14)
	root.add_child(outer)
	outer.add_child(ReconUI.make_header("OPERATION ORDER", 26))

	var panel := ReconUI.make_panel()
	outer.add_child(panel)
	var body := ReconUI.make_label(_briefing_text(), 15, ReconUI.OLIVE)
	panel.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	outer.add_child(row)
	var deploy := ReconUI.make_card_button("[ DEPLOY ]", 18)
	deploy.pressed.connect(func() -> void: deploy_pressed.emit())
	row.add_child(deploy)
	var back := ReconUI.make_link_button("< BACK", 16)
	back.pressed.connect(func() -> void: back_pressed.emit())
	row.add_child(back)
