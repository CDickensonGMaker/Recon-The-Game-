## settings_screen.gd - W82/W83: sensitivity, volume, difficulty, HARDCORE.
class_name SettingsScreen
extends Control

signal back_pressed


func _ready() -> void:
	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	box.add_child(ReconUI.make_label("SETTINGS", 28, ReconUI.AMBER))

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

	box.add_child(ReconUI.make_label("MASTER VOLUME", 13, ReconUI.DIM))
	var vol := HSlider.new()
	vol.min_value = -30.0
	vol.max_value = 6.0
	vol.step = 1.0
	vol.value = GameSettings.master_volume_db
	vol.custom_minimum_size = Vector2(320, 20)
	vol.value_changed.connect(func(v: float) -> void:
		GameSettings.master_volume_db = v
		GameSettings.apply_audio()
		GameSettings.save_settings())
	box.add_child(vol)

	var diff := ReconUI.make_button("DIFFICULTY: %s" % GameSettings.DIFFICULTY_NAMES[GameSettings.difficulty], 16)
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

	var back := ReconUI.make_button("[ BACK ]", 16)
	back.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back)
