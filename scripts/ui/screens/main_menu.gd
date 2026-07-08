## main_menu.gd - Title screen (NS18).
class_name MainMenuScreen
extends Control

signal start_pressed


func _ready() -> void:
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
	var quit := ReconUI.make_button("[ QUIT ]")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
