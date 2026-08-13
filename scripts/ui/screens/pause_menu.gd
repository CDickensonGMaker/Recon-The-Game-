## pause_menu.gd - the in-game pause screen. Runs while the tree is PAUSED
## (PROCESS_MODE_ALWAYS), knows whether it was opened from a mission or the hub,
## and offers:
##   RESUME · BARRACKS · SAVE (hub only) · ABANDON MISSION · QUIT TO MENU
##
## ABANDON exists because a mission you cannot leave is a mission you cannot
## fail - and failing forward is Pillar 5. It routes through the director's own
## abort path so the debrief and the roster consequences are the real ones.
class_name PauseMenu
extends CanvasLayer

signal resume_pressed
signal barracks_pressed
signal save_pressed
signal abandon_pressed
signal quit_to_menu_pressed

var _root: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90


## in_mission=false means we are standing in the hub (no ABANDON, but SAVE).

	# the pause menu. One call: a screen should not have to know which control is which.
	CursorSet.hook_buttons(self, CursorSet.Ctx.DEFAULT)

func build(in_mission: bool) -> void:
	if _root != null:
		_root.queue_free()
	_root = ReconUI.make_screen_root(load("res://assets/ui/pause_bg.png"))
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var panel := ReconUI.make_panel()
	_root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -180)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(ReconUI.make_header("PAUSED" if in_mission else "FIREBASE"))
	box.add_child(ReconUI.make_divider(330.0))

	box.add_child(ReconUI.make_menu_button("RESUME", func() -> void:
		resume_pressed.emit()))
	box.add_child(ReconUI.make_menu_button("BARRACKS", func() -> void:
		barracks_pressed.emit()))
	if not in_mission:
		box.add_child(ReconUI.make_menu_button("SAVE", func() -> void:
			save_pressed.emit()))
	if in_mission:
		box.add_child(ReconUI.make_menu_button("ABANDON MISSION", func() -> void:
			abandon_pressed.emit()))
	box.add_child(ReconUI.make_divider(330.0))
	box.add_child(ReconUI.make_menu_button("QUIT TO MENU", func() -> void:
		quit_to_menu_pressed.emit()))

	var note := ReconUI.make_label(
		"the war keeps its own time - saves are honest" if not in_mission
		else "abandoning is a debrief, not a delete", 13, ReconUI.DIM)
	box.add_child(note)


func teardown() -> void:
	if _root != null:
		_root.queue_free()
		_root = null
