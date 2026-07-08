## debrief.gd - Mission result + scoring (NS21).
class_name DebriefScreen
extends Control

signal continue_pressed

var result: Dictionary = {}


func set_result(r: Dictionary) -> void:
	result = r


static func compute_score(r: Dictionary) -> int:
	var score: int = int(r.objectives_done) * 100
	score += int(r.kills) * 10
	score -= int(r.damage_taken)
	if float(r.time_sec) < 900.0 and bool(r.success):
		score += 50
	if bool(r.emergency_exfil):
		score -= 50
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
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var head_color := ReconUI.AMBER if bool(result.success) else Color(0.8, 0.35, 0.25)
	box.add_child(ReconUI.make_label("AFTER ACTION REPORT", 28, head_color))
	box.add_child(ReconUI.make_label(_rank_word(), 20, head_color))
	box.add_child(ReconUI.make_label("-------------------------------------", 14, ReconUI.DIM))
	var lines := [
		"MISSION:      %s (SEED %d)" % [result.mission_type, int(result.seed)],
		"OBJECTIVES:   %d / %d  (x100)" % [int(result.objectives_done), int(result.objectives_total)],
		"ENEMY KIA:    %d  (x10)" % int(result.kills),
		"WOUNDS TAKEN: -%d" % int(result.damage_taken),
		"TIME:         %d:%02d" % [int(result.time_sec) / 60, int(result.time_sec) % 60],
	]
	if bool(result.emergency_exfil):
		lines.append("EMERGENCY EXFIL: -50")
	box.add_child(ReconUI.make_label("\n".join(lines), 16, ReconUI.OLIVE))
	box.add_child(ReconUI.make_label("SCORE: %d" % compute_score(result), 24, head_color))
	box.add_child(ReconUI.make_label(" ", 8))
	var cont := ReconUI.make_button("[ CONTINUE ]")
	cont.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(cont)
