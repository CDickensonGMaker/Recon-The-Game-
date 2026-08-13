## main_menu.gd - title screen:
## full-bleed key art, left menu column w/ olive highlight, intel briefing panel.
class_name MainMenuScreen
extends Control

signal continue_pressed
signal new_pressed
signal barracks_pressed
signal record_pressed
signal settings_pressed

## The title card IS the menu background (his ruling 2026-08-12), so the splash and the
## menu are one continuous image - the card does not cut to a different picture.
const BG := preload("res://assets/ui/title_logo.jpg")

var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_soundscape()

	# Key art, letterboxed so the full composition shows uncropped and unmagnified.
	var letterbox := ColorRect.new()
	letterbox.color = Color(0.0, 0.0, 0.0)
	letterbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(letterbox)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(bg)

	# Left column scrim so the menu reads over the art.
	var scrim := ColorRect.new()
	scrim.color = Color(0.04, 0.045, 0.035, 0.72)
	scrim.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	scrim.custom_minimum_size = Vector2(430, 0)
	add_child(scrim)

	# Left column content. The key art now carries the title ("TOUR OF HELL:
	# VIETNAM") baked in top-left, so the column starts below it instead of
	# drawing a second, competing title over the art.
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_LEFT)
	col.position = Vector2(56, 220)
	col.add_theme_constant_override("separation", 4)
	add_child(col)

	col.add_child(ReconUI.make_label("OPEN PATROL SIMULATOR", 15, ReconUI.OLIVE))
	col.add_child(ReconUI.make_label("VIETNAM FPS/RPG", 15, ReconUI.DIM))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 36)
	col.add_child(spacer)

	# ADR-029 menu (design call, load-bearing for the Summoner's re-rule):
	# DEPLOY = the one standing world, continue-or-start. NEW TOUR = explicit
	# fresh slate. No mission board, no "operation" language anywhere.
	_add_menu_button(col, "DEPLOY", func() -> void: continue_pressed.emit())
	_add_menu_button(col, "NEW TOUR", func() -> void:
		CampaignState.reset_campaign()
		new_pressed.emit())
	_add_menu_button(col, "SOLDIER", func() -> void: barracks_pressed.emit())
	_add_menu_button(col, "SERVICE RECORD", func() -> void: record_pressed.emit())
	_add_menu_button(col, "OPTIONS", func() -> void: settings_pressed.emit())
	_add_menu_button(col, "EXIT", func() -> void: get_tree().quit())

	# Version tag, bottom-left (mockup). RECON is the internal project name;
	# TOUR OF HELL: VIETNAM is the external brand carried in the key art.
	var version := ReconUI.make_label("v0.3 DEV\nRECON 1969 SYSTEMS", 11, ReconUI.DIM)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(56, -70)
	add_child(version)

	_build_intel_panel()


## Menu row with the mockup's olive highlight bar on hover/focus.

	# the title screen. One call: a screen should not have to know which control is which.
	CursorSet.hook_buttons(self, CursorSet.Ctx.DEFAULT)

func _add_menu_button(parent: Control, text: String, action: Callable) -> void:
	var b := ReconUI.make_menu_button(text, action)
	parent.add_child(b)
	_buttons.append(b)


## Bottom-right INTEL BRIEFING panel (mockup): teases the next operation.
func _build_intel_panel() -> void:
	var panel := ReconUI.make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-420, -220)
	panel.custom_minimum_size = Vector2(370, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(ReconUI.make_label("S2 INTEL", 16, ReconUI.OLIVE))
	box.add_child(ReconUI.make_label(MissionGenerator.codename_for(GameFlow.DEFAULT_OPERATION_SEED), 13, Color(0.85, 0.82, 0.72)))
	box.add_child(ReconUI.make_label("THREAT: %s  //  PATROLS LOGGED: %d" % [
		CampaignState.threat_label(), CampaignState.missions_played], 12, ReconUI.DIM))
	box.add_child(ReconUI.make_label("ENEMY ACTIVITY INCREASED ALONG ROUTE 9.\nLOCAL MILITIA REPORT NVA PRESENCE\nNEAR THE AO. WALK OUT AND FIND THEM.", 12, Color(0.7, 0.68, 0.6)))


func _soundscape() -> void:
	for cfg in [["res://assets/audio/sfx/rotor_loop.wav", -18.0, 0.8], ["res://assets/audio/sfx/radio_crackle.wav", -16.0, 1.0]]:
		var stream := load(str(cfg[0])) as AudioStreamWAV
		if stream:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / 2
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.volume_db = float(cfg[1])
			p.pitch_scale = float(cfg[2])
			add_child(p)
			p.play()
