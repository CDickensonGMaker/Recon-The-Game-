## probe_water_once.gd - boots ONE world (seed 42) and prints a water fingerprint.
## Run twice in SEPARATE processes to prove per-process determinism (ADR-010).
extends Node


func _ready() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 42
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FINGERPRINT timeout")
		get_tree().quit(1)
		return
	var stats: Dictionary = world.water_system.get_stats()
	var max_depth: float = 0.0
	for body in world.water_system.water_bodies.values():
		max_depth = maxf(max_depth, body.depth)
	print("FINGERPRINT creeks=%d rivers=%d lakes=%d ponds=%d swamps=%d max_depth=%.3f" % [
		int(stats.creeks), int(stats.rivers), int(stats.lakes),
		int(stats.ponds), int(stats.swamps), max_depth])
	get_tree().quit(0)
