## mission_select.gd - Three generated mission offers (NS19).
class_name MissionSelectScreen
extends Control

signal offer_chosen(offer: Dictionary)
signal back_pressed

var offers: Array[Dictionary] = []

const TERRAIN_HINTS: Array[String] = ["TRIPLE-CANOPY JUNGLE", "PADDY LOWLANDS", "HIGHLAND SCRUB", "RIVERINE VALLEY"]
const STRENGTHS: Array[String] = ["LIGHT", "MODERATE", "HEAVY"]


func roll_offers(rng: RandomNumberGenerator) -> void:
	# Single source of truth: the same roll the HQ-tent board uses.
	offers = MissionOffers.roll(rng)
	return

	var types := [MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID,
		MissionGenerator.MissionType.FIREBASE_DEFENSE, MissionGenerator.MissionType.ANTI_AA,
		MissionGenerator.MissionType.RESCUE]
	# Array.shuffle() draws from the GLOBAL rng, so roll_offers() was not
	# reproducible even when handed a seeded generator. PROVEN: the same rng seed
	# produced types [3,1,0] then [0,1,4] (probe_smoke_all section C).
	for i in range(types.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = types[i]
		types[i] = types[j]
		types[j] = tmp
	for i in range(3):
		var mission_seed: int = rng.randi() % 100000
		var conditions: Dictionary = MissionGenerator.conditions_for(mission_seed)
		offers.append({
			"type": types[i],
			"type_name": str(MissionGenerator.TYPE_NAMES[types[i]]),
			# ONE seed identifies ONE operation: world_seed and mission_seed MUST
			# stay the same number, or a shared seed reproduces different terrain.
			"world_seed": mission_seed,
			"mission_seed": mission_seed,
			"codename": MissionGenerator.codename_for(mission_seed),
			"terrain_hint": TERRAIN_HINTS[rng.randi() % TERRAIN_HINTS.size()],
			"strength": STRENGTHS[rng.randi() % STRENGTHS.size()],
			"weather": str(conditions.weather),
			"time": str(conditions.time),
			"complications": MissionGenerator.complications_for(mission_seed),
		})


## R88: rebuild a specific offer from a bare seed number (share-a-seed play).
static func offer_for_seed(seed_value: int, type: MissionGenerator.MissionType) -> Dictionary:
	var conditions: Dictionary = MissionGenerator.conditions_for(seed_value)
	return {
		"type": type,
		"type_name": str(MissionGenerator.TYPE_NAMES[type]),
		"world_seed": seed_value,
		"mission_seed": seed_value,
		"codename": MissionGenerator.codename_for(seed_value),
		"terrain_hint": TERRAIN_HINTS[seed_value % TERRAIN_HINTS.size()],
		"strength": STRENGTHS[seed_value % STRENGTHS.size()],
		"weather": str(conditions.weather),
		"time": str(conditions.time),
		"complications": MissionGenerator.complications_for(seed_value),
	}


var _replay_types: Array = [MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID,
	MissionGenerator.MissionType.FIREBASE_DEFENSE, MissionGenerator.MissionType.ANTI_AA, MissionGenerator.MissionType.RESCUE]
var _replay_type_index: int = 0
var _replay_seed_edit: LineEdit
var _replay_type_btn: Button


func _build_replay_row(box: VBoxContainer) -> void:
	box.add_child(ReconUI.make_label("REPLAY A SEED", 13, ReconUI.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_replay_seed_edit = LineEdit.new()
	_replay_seed_edit.placeholder_text = "SEED NUMBER"
	_replay_seed_edit.custom_minimum_size = Vector2(160, 0)
	_replay_seed_edit.add_theme_font_override("font", ReconUI.mono_font())
	row.add_child(_replay_seed_edit)
	_replay_type_btn = ReconUI.make_link_button(str(MissionGenerator.TYPE_NAMES[_replay_types[0]]), 13)
	_replay_type_btn.pressed.connect(func() -> void:
		_replay_type_index = (_replay_type_index + 1) % _replay_types.size()
		_replay_type_btn.text = str(MissionGenerator.TYPE_NAMES[_replay_types[_replay_type_index]]))
	row.add_child(_replay_type_btn)
	var go := ReconUI.make_link_button("DEPLOY BY SEED >", 13)
	go.pressed.connect(func() -> void:
		if not _replay_seed_edit.text.is_valid_int():
			return
		var sv: int = absi(int(_replay_seed_edit.text))
		offer_chosen.emit(offer_for_seed(sv, _replay_types[_replay_type_index]))
	)
	row.add_child(go)


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 16)
	root.add_child(box)
	box.add_child(ReconUI.make_header("AVAILABLE OPERATIONS", 30))
	var threat_color := ReconUI.OLIVE if CampaignState.effective_threat() < 0.5 else ReconUI.ALERT
	box.add_child(ReconUI.make_label("AO ANTI-AIR THREAT: %s   //   MISSIONS FLOWN: %d   //   TEAM XP: %d" % [
		CampaignState.threat_label(), CampaignState.missions_played, CampaignState.team_xp], 13, threat_color))
	for offer in offers:
		# W76/R79: condition + complication chips right on the card.
		var comps: Array = offer.get("complications", [])
		var comp_line := "  //  %s" % " / ".join(comps) if not comps.is_empty() else ""
		var card := ReconUI.make_card_button("%s\n%s  //  ENEMY: %s  //  %s\n%s %s%s" % [
			offer.codename, offer.type_name, offer.strength, offer.terrain_hint,
			offer.get("time", "DAY"), offer.get("weather", "CLEAR"), comp_line], 15, 64.0)
		card.pressed.connect(_on_card.bind(offer))
		box.add_child(card)
	_build_replay_row(box)
	var back := ReconUI.make_link_button("< BACK", 14)
	back.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back)


func _on_card(offer: Dictionary) -> void:
	offer_chosen.emit(offer)
