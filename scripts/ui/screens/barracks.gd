## barracks.gd - roster screen.
class_name BarracksScreen
extends Control

signal back_pressed

var _status_label: Label
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
	_status_label = ReconUI.make_label("", 16, ReconUI.OLIVE)
	box.add_child(_status_label)
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

	# the roster - these are his men. One call: a screen should not have to know which control is which.
	CursorSet.hook_buttons(self, CursorSet.Ctx.CASUALTY)

func _refresh() -> void:
	_status_label.text = "%s   //   MISSIONS: %d   //   THREAT: %s   //   STRENGTH %d/%d   //   KIA %d   //   WARD %d" % [
		CampaignState.title(), CampaignState.missions_played, CampaignState.threat_label(),
		SquadRoster.SQUAD_SIZE - SquadRoster.vacancies(), SquadRoster.SQUAD_SIZE,
		CampaignState.kia_total, CampaignState.ward_wounded]
	for c in _rows.get_children():
		c.queue_free()
	# A REPAINT DOES NOT MANUFACTURE MEN. This called ensure_roster, which minted
	# replacements and wrote them to disk as a side effect of drawing a screen -
	# opening the roster board was a free refill. The board REPORTS; the bird fills.
	var short: int = SquadRoster.vacancies()
	if short > 0:
		_rows.add_child(ReconUI.make_label(
			"%d SLOT%s OPEN - REPLACEMENTS COME BY AIR" % [short, "" if short == 1 else "S"],
			15, ReconUI.ALERT))
	for m in CampaignState.roster:
		if bool(m.get("alive", true)):
			_add_row(m)


## ADR-018: there is no "YOU" row. The player buys nothing - no stats, no skills.
## A squadmate's experience is not a number either. He gets better by doing the job,
## and you are meant to FEEL it in the field, not read it here. This is the man, not
## his character sheet.
func _add_row(member: Dictionary) -> void:
	var panel := ReconUI.make_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var id_col := VBoxContainer.new()
	id_col.custom_minimum_size = Vector2(440, 0)
	row.add_child(id_col)
	id_col.add_child(ReconUI.make_label(str(member.get("name", "")), 17, ReconUI.TEXT))
	var sub := "%-4s %-14s  KILLS %-3d  MISSIONS %d" % [
		SquadRoster.rank_for(member), SquadRoster.mos_display(str(member.get("mos", ""))),
		int(member.get("kills", 0)), int(member.get("missions", 0))]
	var nick: String = SquadRoster.earned_nick(member)
	if nick != "":
		sub += "  \"%s\"" % nick
	id_col.add_child(ReconUI.make_label(sub, 12, ReconUI.DIM))
	row.add_child(ReconUI.make_label(_seasoning(member), 13, ReconUI.AMBER))
	_rows.add_child(panel)


## His experience, in words. Never a number.
func _seasoning(member: Dictionary) -> String:
	var skill: String = str(SkillCatalog.MOS_SKILL.get(str(member.get("mos", "")), ""))
	var lvl: int = SquadRoster.skill_level(member, skill)
	if lvl >= 7:
		return "SALTY"
	if lvl >= 5:
		return "SEASONED"
	if lvl >= 3:
		return "STEADY"
	if lvl >= 1:
		return "BREAKING IN"
	return "GREEN"
