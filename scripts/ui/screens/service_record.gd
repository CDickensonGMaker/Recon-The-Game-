## service_record.gd - W81: career totals + medals wall + mission log.
class_name ServiceRecordScreen
extends Control

signal back_pressed


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	box.add_child(ReconUI.make_header("SERVICE RECORD", 28))

	var total_kills: int = 0
	var successes: int = 0
	var clean_sweeps: int = 0
	for m in CampaignState.mission_log:
		total_kills += int(m.get("kills", 0))
		if bool(m.get("success", false)):
			successes += 1
			if int(m.get("kills", 0)) <= 3:
				clean_sweeps += 1
	var stats_panel := ReconUI.make_panel()
	box.add_child(stats_panel)
	stats_panel.add_child(ReconUI.make_label(
		"MISSIONS: %d   SUCCESSFUL: %d   ENEMY KIA: %d   TEAM XP EARNED: %d" % [
			CampaignState.missions_played, successes, total_kills, CampaignState.team_xp], 14, ReconUI.TEXT))

	# Medals wall (criteria-derived, no storage needed).
	box.add_child(ReconUI.make_label("COMMENDATIONS", 15, ReconUI.DIM))
	var medals: Array[String] = []
	if clean_sweeps >= 1:
		medals.append("SILVER STAR - mission complete, minimal contact (x%d)" % clean_sweeps)
	if total_kills >= 50:
		medals.append("BRONZE STAR w/ V - fifty confirmed")
	if CampaignState.missions_played >= 10:
		medals.append("VIETNAM SERVICE MEDAL - ten operations")
	if medals.is_empty():
		medals.append("(no commendations yet - go earn them)")
	var medals_panel := ReconUI.make_panel()
	box.add_child(medals_panel)
	var medals_box := VBoxContainer.new()
	medals_box.add_theme_constant_override("separation", 4)
	medals_panel.add_child(medals_box)
	for medal in medals:
		medals_box.add_child(ReconUI.make_label("* %s" % medal, 13, Color(0.85, 0.75, 0.4)))

	box.add_child(ReconUI.make_label("RECENT PATROLS", 15, ReconUI.DIM))
	var ops_panel := ReconUI.make_panel()
	box.add_child(ops_panel)
	var ops_box := VBoxContainer.new()
	ops_box.add_theme_constant_override("separation", 4)
	ops_panel.add_child(ops_box)
	var recent: Array = CampaignState.mission_log.slice(maxi(0, CampaignState.mission_log.size() - 8))
	for m in recent:
		var line_color := ReconUI.OLIVE if bool(m.get("success", false)) else ReconUI.ALERT
		ops_box.add_child(ReconUI.make_label("%s  //  %s  //  %d KIA" % [
			str(m.get("type", "?")), "SUCCESS" if bool(m.get("success", false)) else "FAILED",
			int(m.get("kills", 0))], 12, line_color))

	var back := ReconUI.make_link_button("< BACK", 16)
	back.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back)
