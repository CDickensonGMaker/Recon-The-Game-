## test_world_boot.gd - NS02 verification: terrain generates, player stands on it.
## Run: godot --headless --path . res://tests/test_world_boot.tscn
## (Scene-based so autoloads are live — `-s` SceneTree scripts skip them.)
extends Node

const TIMEOUT_SECONDS: float = 180.0


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 42
	add_child(world)

	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < TIMEOUT_SECONDS:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5

	if not world.is_world_ready:
		print("FAIL: terrain generation timed out after %.0fs" % TIMEOUT_SECONDS)
		get_tree().quit(1)
		return

	# Sanity: the player script must actually be attached and running.
	if world.player.get_script() == null:
		print("FAIL: player script not attached")
		get_tree().quit(1)
		return

	print("terrain ready in %.1fs, letting physics settle..." % elapsed)
	await get_tree().create_timer(2.0).timeout

	var player_y: float = world.player.global_position.y
	var ground_y: float = world.terrain_manager.get_height_at(world.player.global_position)
	var delta_y: float = absf(player_y - ground_y)
	print("player_y=%.2f ground_y=%.2f delta=%.2f" % [player_y, ground_y, delta_y])

	if delta_y < 3.0:
		print("PASS: player standing on generated terrain")
		get_tree().quit(0)
	else:
		print("FAIL: player not on terrain (delta %.2f >= 3.0)" % delta_y)
		get_tree().quit(1)
