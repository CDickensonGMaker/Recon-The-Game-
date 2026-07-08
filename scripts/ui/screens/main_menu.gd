## main_menu.gd - Title screen (NS18).
class_name MainMenuScreen
extends Control

signal start_pressed


func _ready() -> void:
	# W68: menu soundscape - idle rotor far off + radio net crackle.
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

	var root := ReconUI.make_screen_root()
	add_child(root)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	root.add_child(box)
	var title := ReconUI.make_label("R E C O N", 72, ReconUI.OLIVE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := ReconUI.make_label("MILITARY ASSISTANCE COMMAND, VIETNAM - STUDIES AND OBSERVATIONS", 12, ReconUI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	var start := ReconUI.make_button("[ START OPERATION ]")
	start.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(start)
	var barracks := ReconUI.make_button("[ BARRACKS ]")
	barracks.pressed.connect(func() -> void: barracks_pressed.emit())
	box.add_child(barracks)
	var record := ReconUI.make_button("[ SERVICE RECORD ]")
	record.pressed.connect(func() -> void: record_pressed.emit())
	box.add_child(record)
	var settings := ReconUI.make_button("[ SETTINGS ]")
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	box.add_child(settings)
	var quit := ReconUI.make_button("[ QUIT ]")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)


signal barracks_pressed
signal record_pressed
signal settings_pressed
