## debrief.gd - Mission result + scoring (NS21).
class_name DebriefScreen
extends Control

signal continue_pressed

var result: Dictionary = {}


func set_result(r: Dictionary) -> void:
	result = r


## R83: weapons-tight/ROE bonus - a quiet, disciplined run (few shots per
## objective) pays like a clean sweep, not just a fast one.
static func _ghost_bonus(r: Dictionary) -> bool:
	var shots: int = int(r.get("shots", 0))
	return bool(r.get("success", false)) and shots > 0 and shots <= 15 * maxi(1, int(r.objectives_done))


static func compute_score(r: Dictionary) -> int:
	var score: int = int(r.objectives_done) * 100
	score += int(r.kills) * 10
	score -= int(r.damage_taken)
	if float(r.time_sec) < 900.0 and bool(r.success):
		score += 50
	if bool(r.emergency_exfil):
		score -= 50
	if _ghost_bonus(r):
		score += 75
	return score


func _rank_word() -> String:
	if not bool(result.success):
		if str(result.reason) == "KIA":
			return "MISSION FAILED - BODY RECOVERED"
		return "MISSION INCOMPLETE - EXTRACTED UNDER FIRE"
	if int(result.objectives_done) >= int(result.objectives_total) and int(result.damage_taken) < 30:
		return "CLEAN SWEEP"
	return "MISSION COMPLETE"


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.add_theme_constant_override("separation", 14)
	root.add_child(outer)
	var head_color := ReconUI.AMBER if bool(result.success) else ReconUI.ALERT
	outer.add_child(ReconUI.make_header("AFTER ACTION REPORT", 28))
	outer.add_child(ReconUI.make_label(_rank_word(), 20, head_color))

	var panel := ReconUI.make_panel()
	outer.add_child(panel)
	var lines := [
		"MISSION:      %s (SEED %d)" % [result.mission_type, int(result.seed)],
		"OBJECTIVES:   %d / %d  (x100)" % [int(result.objectives_done), int(result.objectives_total)],
		"ENEMY KIA:    %d  (x10)" % int(result.kills),
		"WOUNDS TAKEN: -%d" % int(result.damage_taken),
		"TIME:         %d:%02d" % [int(result.time_sec) / 60, int(result.time_sec) % 60],
	]
	if int(result.get("shots", 0)) > 0:
		lines.append("MARKSMANSHIP: %d/%d ROUNDS ON TARGET (%.0f%%)" % [
			int(result.hits), int(result.shots), 100.0 * float(result.hits) / float(result.shots)])
	if bool(result.get("pow_lost", false)):
		lines.append("THE PILOT DIDN'T MAKE IT: -100")
	if bool(result.emergency_exfil):
		lines.append("EMERGENCY EXFIL: -50")
	if _ghost_bonus(result):
		lines.append("ROE - WEAPONS DISCIPLINE: +75")
	panel.add_child(ReconUI.make_label("\n".join(lines), 16, ReconUI.OLIVE))

	outer.add_child(ReconUI.make_label("SCORE: %d" % compute_score(result), 24, head_color))
	var cont := ReconUI.make_card_button("[ CONTINUE ]", 18)
	cont.pressed.connect(func() -> void: continue_pressed.emit())
	outer.add_child(cont)
