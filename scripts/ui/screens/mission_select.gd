## mission_select.gd - Three generated mission offers (NS19).
class_name MissionSelectScreen
extends Control

signal offer_chosen(offer: Dictionary)
signal back_pressed

var offers: Array[Dictionary] = []

const TERRAIN_HINTS: Array[String] = ["TRIPLE-CANOPY JUNGLE", "PADDY LOWLANDS", "HIGHLAND SCRUB", "RIVERINE VALLEY"]
const STRENGTHS: Array[String] = ["LIGHT", "MODERATE", "HEAVY"]


func roll_offers(rng: RandomNumberGenerator) -> void:
	offers.clear()
	var types := [MissionGenerator.MissionType.PATROL, MissionGenerator.MissionType.VILLAGE_RAID,
		MissionGenerator.MissionType.FIREBASE_DEFENSE, MissionGenerator.MissionType.ANTI_AA,
		MissionGenerator.MissionType.RESCUE]
	types.shuffle()
	for i in range(3):
		var mission_seed: int = rng.randi() % 100000
		var conditions: Dictionary = MissionGenerator.conditions_for(mission_seed)
		offers.append({
			"type": types[i],
			"type_name": str(MissionGenerator.TYPE_NAMES[types[i]]),
			"world_seed": rng.randi() % 100000,
			"mission_seed": mission_seed,
			"codename": MissionGenerator.codename_for(mission_seed),
			"terrain_hint": TERRAIN_HINTS[rng.randi() % TERRAIN_HINTS.size()],
			"strength": STRENGTHS[rng.randi() % STRENGTHS.size()],
			"weather": str(conditions.weather),
			"time": str(conditions.time),
		})


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
		# W76: condition chips right on the card.
		var card := ReconUI.make_card_button("%s\n%s  //  ENEMY: %s  //  %s\n%s %s" % [
			offer.codename, offer.type_name, offer.strength, offer.terrain_hint,
			offer.get("time", "DAY"), offer.get("weather", "CLEAR")], 15, 64.0)
		card.pressed.connect(_on_card.bind(offer))
		box.add_child(card)
	var back := ReconUI.make_link_button("< BACK", 14)
	back.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back)


func _on_card(offer: Dictionary) -> void:
	offer_chosen.emit(offer)
