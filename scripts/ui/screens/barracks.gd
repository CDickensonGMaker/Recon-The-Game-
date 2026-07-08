## barracks.gd - Roster + XP spend screen (W26/W27/W31/W32).
class_name BarracksScreen
extends Control

signal back_pressed

var _xp_label: Label
var _rows: VBoxContainer


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	box.add_child(ReconUI.make_label("BARRACKS - RECON TEAM", 28, ReconUI.AMBER))
	_xp_label = ReconUI.make_label("", 16, ReconUI.OLIVE)
	box.add_child(_xp_label)
	box.add_child(ReconUI.make_label("------------------------------------------------------------", 12, ReconUI.DIM))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)
	box.add_child(ReconUI.make_label(" ", 6))

	var iron := CheckBox.new()
	iron.text = "IRON MAN (death archives the campaign)"
	iron.button_pressed = CampaignState.iron_man
	iron.add_theme_font_override("font", ReconUI.mono_font())
	iron.add_theme_color_override("font_color", ReconUI.DIM)
	iron.toggled.connect(func(on: bool) -> void:
		CampaignState.iron_man = on
		CampaignState.save_campaign())
	box.add_child(iron)

	var back := ReconUI.make_button("[ BACK ]", 16)
	back.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back)
	_refresh()


func _refresh() -> void:
	_xp_label.text = "TEAM XP POOL: %d   //   MISSIONS: %d   //   THREAT: %s" % [
		CampaignState.team_xp, CampaignState.missions_played, CampaignState.threat_label()]
	for c in _rows.get_children():
		c.queue_free()
	SquadRoster.ensure_roster(CampaignState.missions_played + 1)
	_add_row(CampaignState.player_data, "YOU", true)
	for m in CampaignState.roster:
		_add_row(m, str(m.nick), false)


func _add_row(target: Dictionary, label_name: String, is_player: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mos: String = str(target.get("mos", "RIFLEMAN"))
	var skill_id: String = str(SkillCatalog.MOS_SKILL.get(mos, "small_arms"))
	var skill_level: int = int((target.get("skills", {}) as Dictionary).get(skill_id, 0))
	var info := "%-8s %-9s ST:%3d AG:%3d AL:%3d  %s L%d" % [
		label_name, mos, int(target.get("st", 100)), int(target.get("ag", 100)),
		int(target.get("al", 100)), str(SkillCatalog.SKILLS[skill_id].name), skill_level]
	if not is_player:
		info += "  K:%d M:%d" % [int(target.get("kills", 0)), int(target.get("missions", 0))]
	row.add_child(ReconUI.make_label(info, 13, ReconUI.OLIVE))

	var skill_btn := ReconUI.make_button("[+%s %d]" % [str(SkillCatalog.SKILLS[skill_id].name), int(SkillCatalog.SKILLS[skill_id].cost)], 12)
	skill_btn.pressed.connect(func() -> void:
		if SkillCatalog.buy_skill(target, skill_id):
			_refresh())
	row.add_child(skill_btn)
	for attr in ["st", "ag", "al"]:
		var b := ReconUI.make_button("[+%s]" % attr.to_upper(), 12)
		b.pressed.connect(func() -> void:
			if SkillCatalog.buy_attribute(target, attr):
				_refresh())
		row.add_child(b)
	_rows.add_child(row)
