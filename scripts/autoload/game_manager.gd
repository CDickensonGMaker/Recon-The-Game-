## game_manager.gd - Central game state management for Hell of Duty
extends Node

signal player_died

## Game state
var is_paused: bool = false
var is_in_menu: bool = false

## Player reference
var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


## Pause the game
func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	CursorSet.set_context(CursorSet.Ctx.DEFAULT)


## Resume the game
func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Hand the pointer back on the way into the world: a captured mouse draws no cursor,
	# and leaving a custom one set means the next screen inherits whatever was last hovered.
	CursorSet.reset()


## Toggle pause
func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


## Check if player can act
func can_player_act() -> bool:
	return not is_paused and not is_in_menu


## Handle player death
func on_player_death() -> void:
	player_died.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	CursorSet.set_context(CursorSet.Ctx.CASUALTY)


## Register player reference
func register_player(player_node: Node) -> void:
	player = player_node
