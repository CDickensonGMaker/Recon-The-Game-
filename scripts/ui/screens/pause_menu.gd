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
signal quit_to_desktop_pressed

var _root: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90


## in_mission=false means we are standing in the hub (no ABANDON, but SAVE).
##
## THE PANEL WAS OFF THE TOP-LEFT CORNER IN EVERY BUILD THAT EVER SHIPPED. His playtest
## 2026-08-28: "when i pause in the demo, i dont see any menu i just get a paused screen
## with a image of a soldier in the river. but no options". MEASURED by
## tests/probe_pause_menu.tscn on a 1280x720 viewport: the PanelContainer's global rect
## came back at (-190, -180) size 362x362 - the literal `position` value, with the
## PRESET_CENTER anchors contributing nothing.
##
## WHY: `Control.position` is PARENT-RELATIVE, not anchor-relative. Setting it rewrites the
## offsets to whatever lands the rect at that parent-space point, so it CANCELS the preset.
## The same pattern reads as centred all over the HUD only because those controls are
## positioned while their parent is still zero-sized (offset = position, and the anchor then
## does the centring on the first resize). `_root` here is added to a CanvasLayer FIRST and
## resolves to the full viewport immediately, so the offsets baked absolute and the menu sat
## in the corner. Do not "fix" this by tuning the numbers - a CenterContainer cannot drift.
##
## The stray `CursorSet.hook_buttons` that used to sit here was swallowed by `_ready()`
## (comments and blank lines do not close an indented block), so it ran at add_child() time,
## before a single button existed. It belongs at the END of build().
func build(in_mission: bool) -> void:
	if _root != null:
		_root.queue_free()
	_root = ReconUI.make_screen_root(load("res://assets/ui/pause_bg.png"))
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var panel := ReconUI.make_panel()
	centre.add_child(panel)

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
	# The demo has no menu front door - its quit is a fresh demo day, and the
	# button must say what it does.
	box.add_child(ReconUI.make_menu_button(
		"RESTART DAY" if GameFlow.demo_mode else "QUIT TO MENU", func() -> void:
		quit_to_menu_pressed.emit()))
	# The demo has no front door to fall back to, so ESC had no way OUT of the game
	# at all (his playtest, 2026-08-27). One menu, both exits.
	box.add_child(ReconUI.make_menu_button("QUIT TO DESKTOP", func() -> void:
		quit_to_desktop_pressed.emit()))

	var note := ReconUI.make_label(
		"the war keeps its own time - saves are honest" if not in_mission
		else "abandoning is a debrief, not a delete", 13, ReconUI.DIM)
	box.add_child(note)

	# the pause menu. One call: a screen should not have to know which control is which.
	# LAST, not in _ready(): it hooks BUTTONS, and until this line there were none.
	CursorSet.hook_buttons(self, CursorSet.Ctx.DEFAULT)


func teardown() -> void:
	if _root != null:
		_root.queue_free()
		_root = null
