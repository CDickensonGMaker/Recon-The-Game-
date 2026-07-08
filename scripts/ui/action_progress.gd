## action_progress.gd - Circular progress indicator for actions (reload, heal, switch)
class_name ActionProgress
extends Control

## Action types with their icons
enum ActionType { NONE, RELOAD, HEAL, SWITCH }

## Visual settings
const CIRCLE_RADIUS: float = 40.0
const CIRCLE_WIDTH: float = 6.0
const BG_COLOR: Color = Color(0.2, 0.2, 0.2, 0.8)
const PROGRESS_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

## State
var current_action: ActionType = ActionType.NONE
var progress: float = 0.0  ## 0.0 to 1.0
var is_active: bool = false

## Icon labels
const ICON_RELOAD: String = "[]="  ## Bullet/magazine
const ICON_HEAL: String = "+"      ## Medical cross
const ICON_SWITCH: String = "<>"   ## Cycle arrows

@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(CIRCLE_RADIUS * 2 + 20, CIRCLE_RADIUS * 2 + 20)


func _draw() -> void:
	if not is_active:
		return

	var center := size / 2.0

	# Draw background circle
	draw_arc(center, CIRCLE_RADIUS, 0, TAU, 64, BG_COLOR, CIRCLE_WIDTH, true)

	# Draw progress arc (starts from top, goes clockwise)
	if progress > 0.0:
		var start_angle: float = -PI / 2.0  # Start from top
		var end_angle: float = start_angle + (progress * TAU)
		var color: Color = _get_action_color()
		draw_arc(center, CIRCLE_RADIUS, start_angle, end_angle, 64, color, CIRCLE_WIDTH, true)


func _get_action_color() -> Color:
	match current_action:
		ActionType.RELOAD:
			return Color(1.0, 0.8, 0.2)  # Yellow/gold
		ActionType.HEAL:
			return Color(0.2, 1.0, 0.2)  # Green
		ActionType.SWITCH:
			return Color(0.5, 0.8, 1.0)  # Light blue
		_:
			return PROGRESS_COLOR


func _get_icon_text() -> String:
	match current_action:
		ActionType.RELOAD:
			return ICON_RELOAD
		ActionType.HEAL:
			return ICON_HEAL
		ActionType.SWITCH:
			return ICON_SWITCH
		_:
			return ""


## Start showing progress for an action
func start_action(action_type: ActionType) -> void:
	current_action = action_type
	progress = 0.0
	is_active = true
	visible = true

	if icon_label:
		icon_label.text = _get_icon_text()
		icon_label.modulate = _get_action_color()

	queue_redraw()


## Update progress (0.0 to 1.0)
func update_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


## Complete and hide
func finish_action() -> void:
	is_active = false
	visible = false
	current_action = ActionType.NONE
	progress = 0.0
	queue_redraw()


## Cancel and hide
func cancel_action() -> void:
	finish_action()
