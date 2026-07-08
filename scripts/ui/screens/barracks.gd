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
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	box.add_child(ReconUI.make_header("BARRACKS - RECON TEAM", 28))
	_xp_label = ReconUI.make_label("", 16, ReconUI.OLIVE)
	box.add_child(_xp_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)

	var iron := CheckBox.new()
	iron.text = "IRON MAN (death archives the campaign)"
	iron.button_pressed = CampaignState.iron_man
	iron.add_theme_font_override("font", ReconUI.mono_font())
	iron.add_theme_color_override("font_color", ReconUI.DIM)
	iron.toggled.connect(func(on: bool) -> void:
		CampaignState.iron_man = on
		CampaignState.save_campaign())
	box.add_child(iron)

	var back := ReconUI.make_link_button("< BACK", 16)
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
	var panel := ReconUI.make_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var mos: String = str(target.get("mos", "RIFLEMAN"))
	# The player buys the three body-owned skills; each squadmate buys the one his
	# MOS actually uses (AUDIT-01: this row used to offer the player exactly one
	# skill, small_arms, because MOS was pinned to RIFLEMAN and four of the six
	# read sites queried player_data - which could never hold anything else).
	var buyable: Array[String] = SkillCatalog.PLAYER_SKILLS if is_player else [str(SkillCatalog.MOS_SKILL.get(mos, "small_arms"))]
	var info := "%-8s %-9s ST:%3d AG:%3d AL:%3d" % [
		label_name, mos, int(target.get("st", 100)), int(target.get("ag", 100)), int(target.get("al", 100))]
	if not is_player:
		info += "  K:%d M:%d" % [int(target.get("kills", 0)), int(target.get("missions", 0))]
	var info_label := ReconUI.make_label(info, 13, ReconUI.TEXT)
	info_label.custom_minimum_size = Vector2(300, 0)
	row.add_child(info_label)

	for skill_id in buyable:
		var lvl: int = int((target.get("skills", {}) as Dictionary).get(skill_id, 0))
		var btn := ReconUI.make_link_button("[%s L%d +%d]" % [
			str(SkillCatalog.SKILLS[skill_id].name), lvl, int(SkillCatalog.SKILLS[skill_id].cost)], 12)
		var sid: String = skill_id
		btn.pressed.connect(func() -> void:
			if SkillCatalog.buy_skill(target, sid):
				_refresh())
		row.add_child(btn)
	for attr in ["st", "ag", "al"]:
		var b := ReconUI.make_link_button("[+%s]" % attr.to_upper(), 12)
		b.pressed.connect(func() -> void:
			if SkillCatalog.buy_attribute(target, attr):
				_refresh())
		row.add_child(b)
	_rows.add_child(panel)
