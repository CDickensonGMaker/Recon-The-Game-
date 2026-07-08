## game_manager.gd - Central game state management for Hell of Duty
extends Node

signal game_paused
signal game_resumed
signal player_died
signal level_complete

## Game state
var is_paused: bool = false
var is_in_menu: bool = false

## Player reference
var player: Node = null

## Current level stats
var enemies_killed: int = 0
var total_enemies: int = 0

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
	game_paused.emit()


## Resume the game
func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_resumed.emit()


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


## Register player reference
func register_player(player_node: Node) -> void:
	player = player_node


## Track enemy kills
func on_enemy_killed() -> void:
	enemies_killed += 1
	if enemies_killed >= total_enemies and total_enemies > 0:
		level_complete.emit()


## Set total enemies for level
func set_total_enemies(count: int) -> void:
	total_enemies = count
	enemies_killed = 0


## Reset for new level
func reset_level() -> void:
	enemies_killed = 0
	total_enemies = 0
	is_paused = false
	is_in_menu = false
