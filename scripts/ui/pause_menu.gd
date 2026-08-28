## pause_menu.gd - the demo's pause screen. GameManager owns the pause STATE and the
## "pause" action (game_manager.gd:17-25); this layer is only its face, so there is
## one pause and one place that sets get_tree().paused.
class_name PauseMenu
extends CanvasLayer


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


var _root: Control


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var panel := ReconUI.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -150)
	panel.custom_minimum_size = Vector2(380, 0)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(ReconUI.make_header("STAND EASY"))
	col.add_child(ReconUI.make_divider(340.0))
	col.add_child(ReconUI.make_menu_button("RESUME", _resume))
	col.add_child(ReconUI.make_menu_button("QUIT TO DESKTOP", _quit))
	var hint: Label = ReconUI.make_label("[ESC] RESUMES - THE WAR IS STILL OUT THERE", 13,
		ReconUI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _process(_delta: float) -> void:
	if visible != GameManager.is_paused:
		visible = GameManager.is_paused


func _resume() -> void:
	GameManager.resume_game()


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
