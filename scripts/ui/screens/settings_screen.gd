## settings_screen.gd - sensitivity, volumes, difficulty, HARDCORE, PSX LOOK,
## render scale.
class_name SettingsScreen
extends Control

signal back_pressed


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.add_theme_constant_override("separation", 14)
	root.add_child(outer)
	outer.add_child(ReconUI.make_header("SETTINGS", 28))

	var panel := ReconUI.make_panel()
	outer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)

	box.add_child(ReconUI.make_label("MOUSE SENSITIVITY", 13, ReconUI.DIM))
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = GameSettings.mouse_sensitivity
	sens.custom_minimum_size = Vector2(320, 20)
	sens.value_changed.connect(func(v: float) -> void:
		GameSettings.mouse_sensitivity = v
		GameSettings.save_settings())
	box.add_child(sens)

	_add_volume_row(box, "MASTER VOLUME", &"master_volume_db")
	_add_volume_row(box, "SFX VOLUME", &"sfx_volume_db")
	_add_volume_row(box, "AMBIENCE VOLUME", &"ambience_volume_db")
	_add_volume_row(box, "MUSIC VOLUME", &"music_volume_db")

	var diff := ReconUI.make_link_button("DIFFICULTY: %s" % GameSettings.DIFFICULTY_NAMES[GameSettings.difficulty], 16)
	diff.pressed.connect(func() -> void:
		GameSettings.difficulty = (GameSettings.difficulty + 1) % 3
		diff.text = "DIFFICULTY: %s" % GameSettings.DIFFICULTY_NAMES[GameSettings.difficulty]
		GameSettings.save_settings())
	box.add_child(diff)

	var hardcore := CheckBox.new()
	hardcore.text = "HARDCORE (no compass, no objective markers)"
	hardcore.button_pressed = GameSettings.hardcore
	hardcore.add_theme_font_override("font", ReconUI.mono_font())
	hardcore.add_theme_color_override("font_color", ReconUI.DIM)
	hardcore.toggled.connect(func(on: bool) -> void:
		GameSettings.hardcore = on
		GameSettings.save_settings())
	box.add_child(hardcore)

	## PSX look owns scaling_3d_scale while ON (PsxLook.apply()), so the manual
	## rung is disabled with it.
	var scale_btn := ReconUI.make_link_button(_render_scale_text(), 16)
	scale_btn.disabled = GameSettings.psx_look
	scale_btn.pressed.connect(func() -> void:
		var idx: int = (GameSettings.render_scale_index() + 1) % GameSettings.RENDER_SCALE_STEPS.size()
		GameSettings.render_scale = GameSettings.RENDER_SCALE_STEPS[idx]
		scale_btn.text = _render_scale_text()
		GameSettings.save_settings()
		PsxLook.apply())

	var psx := CheckBox.new()
	psx.text = "PSX LOOK (low-res render, PS1 dither)"
	psx.button_pressed = GameSettings.psx_look
	psx.add_theme_font_override("font", ReconUI.mono_font())
	psx.add_theme_color_override("font_color", ReconUI.DIM)
	psx.toggled.connect(func(on: bool) -> void:
		PsxLook.set_enabled(on)
		scale_btn.disabled = on)
	box.add_child(psx)
	box.add_child(scale_btn)

	var back := ReconUI.make_link_button("< BACK", 16)
	back.pressed.connect(func() -> void: back_pressed.emit())
	outer.add_child(back)


func _render_scale_text() -> String:
	return "RENDER SCALE: %s" % GameSettings.RENDER_SCALE_NAMES[GameSettings.render_scale_index()]


func _add_volume_row(box: VBoxContainer, label: String, prop: StringName) -> void:
	box.add_child(ReconUI.make_label(label, 13, ReconUI.DIM))
	var vol := HSlider.new()
	vol.min_value = -30.0
	vol.max_value = 6.0
	vol.step = 1.0
	vol.value = float(GameSettings.get(prop))
	vol.custom_minimum_size = Vector2(320, 20)
	vol.value_changed.connect(func(v: float) -> void:
		GameSettings.set(prop, v)
		GameSettings.apply_audio()
		GameSettings.save_settings())
	box.add_child(vol)
