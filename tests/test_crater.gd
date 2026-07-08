## test_crater.gd - NS13: grenade detonation craters terrain + collision follows.
## Run: godot --headless --path . res://tests/test_crater.tscn
extends Node

func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 33
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world timeout")
		get_tree().quit(1)
		return

	var pos := world.player.global_position + Vector3(15, 0, 0)
	pos.y = world.terrain_manager.get_height_at(pos)
	var before: float = pos.y

	# Detonate a real grenade at the spot.
	var grenade := Grenade.new()
	world.add_child(grenade)
	grenade.global_position = pos + Vector3(0, 0.3, 0)
	grenade.remaining_fuse = 0.2
	await get_tree().create_timer(1.0).timeout

	var after: float = world.terrain_manager.get_height_at(pos)
	print("grenade crater: before=%.2f after=%.2f delta=%.2f" % [before, after, before - after])
	var failures: int = 0
	if after >= before:
		print("FAIL: no crater")
		failures += 1

	# Collision regenerated: raycast down finds the NEW surface near 'after'.
	var space := world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 50, 0), pos + Vector3(0, -50, 0), 1)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		print("FAIL: no terrain collision hit after crater")
		failures += 1
	else:
		var hit_y: float = (hit.position as Vector3).y
		print("raycast surface y=%.2f (heightmap %.2f)" % [hit_y, after])
		if absf(hit_y - after) > 1.5:
			print("FAIL: collision out of sync with heightmap")
			failures += 1

	if failures == 0:
		print("PASS: grenade craters terrain, collision follows")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
