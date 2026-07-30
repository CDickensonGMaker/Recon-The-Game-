## debrief.gd - Mission result + scoring (NS21).
class_name DebriefScreen
extends Control

signal continue_pressed

var result: Dictionary = {}


func set_result(r: Dictionary) -> void:
	result = r


## R83: weapons-tight/ROE bonus - a quiet, disciplined run pays like a clean
## sweep, not just a fast one.
const GHOST_SHOT_CEILING: int = 15


static func _ghost_bonus(r: Dictionary) -> bool:
	var shots: int = int(r.get("shots", 0))
	return bool(r.get("success", false)) and shots > 0 and shots <= GHOST_SHOT_CEILING


## ADR-006 SCORING. Kills earn NOTHING. What earns is CONTACT DISCIPLINE: +25 for
## every enemy group slipped past unseen, -25 for every one that got eyes on you.
## A firefight you had to have is not punished (objectives still bank); one you
## CHOSE costs you.
const CONTACT_AVOIDED: int = 25
const CONTACT_DETECTED: int = -25


static func compute_score(r: Dictionary) -> int:
	var score: int = int(r.get("contacts_avoided", 0)) * CONTACT_AVOIDED
	score += int(r.get("contacts_detected", 0)) * CONTACT_DETECTED
	score -= int(r.get("damage_taken", 0))
	if float(r.get("time_sec", 0)) < 900.0 and bool(r.get("success", false)):
		score += 50
	if _ghost_bonus(r):
		score += 75
	if bool(r.get("pow_lost", false)):
		score -= 100
	return score


func _rank_word() -> String:
	if not bool(result.get("success", false)):
		if str(result.get("reason", "")) == "KIA":
			return "MISSION FAILED - BODY RECOVERED"
		return "MISSION INCOMPLETE - EXTRACTED UNDER FIRE"
	if int(result.get("damage_taken", 0)) < 30:
		return "CLEAN SWEEP"
	return "MISSION COMPLETE"


func _ready() -> void:
	var root := ReconUI.make_screen_root(load("res://assets/ui/debrief_bg.png"))
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.add_theme_constant_override("separation", 14)
	root.add_child(outer)
	var head_color := ReconUI.AMBER if bool(result.get("success", false)) else ReconUI.ALERT
	outer.add_child(ReconUI.make_header("AFTER ACTION REPORT", 28))
	outer.add_child(ReconUI.make_label(_rank_word(), 20, head_color))
	outer.add_child(ReconUI.make_label(CampaignState.title(), 16, ReconUI.DIM))

	var panel := ReconUI.make_panel()
	outer.add_child(panel)
	@warning_ignore("integer_division")
	var lines := [
		"MISSION:      %s (SEED %d)" % [result.get("mission_type", ""), int(result.get("seed", 0))],
		# ADR-006: the AAR now names what it PAYS for. Kills are reported because
		# a recon element still counts bodies - they just do not buy anything.
		"CONTACTS AVOIDED: %d  (+25 each)" % int(result.get("contacts_avoided", 0)),
		"CONTACTS DETECTED: %d  (-25 each)" % int(result.get("contacts_detected", 0)),
		"ENEMY KIA:    %d  (bodies buy nothing)" % int(result.get("kills", 0)),
		"WOUNDS TAKEN: -%d" % int(result.get("damage_taken", 0)),
		"TIME:         %d:%02d" % [int(result.get("time_sec", 0)) / 60, int(result.get("time_sec", 0)) % 60],
		"GROUND COVERED: %d SECTORS" % int(result.get("ground_covered", 0)),
	]
	if int(result.get("shots", 0)) > 0:
		lines.append("MARKSMANSHIP: %d/%d ROUNDS ON TARGET (%.0f%%)" % [
			int(result.get("hits", 0)), int(result.get("shots", 0)), 100.0 * float(result.get("hits", 0)) / float(result.get("shots", 0))])
	if bool(result.get("pow_lost", false)):
		lines.append("THE PILOT DIDN'T MAKE IT: -100")
	# ADR-019: named at the AAR, never priced into score - the district keeps its
	# own ledger.
	if int(result.get("civilian_deaths", 0)) > 0:
		lines.append("NONCOMBATANTS KILLED: %d" % int(result.get("civilian_deaths", 0)))
	if _ghost_bonus(result):
		lines.append("ROE - WEAPONS DISCIPLINE: +75")
	panel.add_child(ReconUI.make_label("\n".join(lines), 16, ReconUI.OLIVE))

	outer.add_child(ReconUI.make_label("SCORE: %d" % compute_score(result), 24, head_color))
	var cont := ReconUI.make_card_button("[ CONTINUE ]", 18)
	cont.pressed.connect(func() -> void: continue_pressed.emit())
	outer.add_child(cont)
