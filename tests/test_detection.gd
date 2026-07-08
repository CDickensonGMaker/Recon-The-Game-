## test_detection.gd - R12/R13/R14: alert tiers, hearing, no psychic acquisition.
## Run: godot --headless --path . res://tests/test_detection.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	# Start FAR away (out of any sight cap).
	player.global_position = Vector3(250, 1.0, 0)

	var enemy := EnemyBase.spawn_enemy(self, Vector3(0, 1.0, 0), ENEMY_DATA)
	await get_tree().create_timer(0.6).timeout

	# 1. Distant player: enemy stays RELAXED, no target.
	await get_tree().create_timer(1.5).timeout
	if enemy.alert_tier != EnemyBase.AlertTier.RELAXED or enemy.target != null:
		print("FAIL: enemy not relaxed with distant player (tier=%d)" % enemy.alert_tier)
		failures += 1

	# 2. Gunshot noise BEHIND max sight -> suspicious, investigates the NOISE point.
	var noise_pos := Vector3(30, 1, 30)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, noise_pos, 0)
	await get_tree().create_timer(0.5).timeout
	if enemy.alert_tier == EnemyBase.AlertTier.RELAXED:
		print("FAIL: gunshot did not raise tier")
		failures += 1
	if enemy.last_known_target_pos.distance_to(noise_pos) > 1.0:
		print("FAIL: investigation point is not the noise point")
		failures += 1
	if enemy.target != null:
		print("FAIL: noise alone gave a hard target (psychic)")
		failures += 1

	# 3. Player walks up in the open, in front: awareness ramps to COMBAT.
	enemy.facing_dir = Vector3(1, 0, 0)  # face the player approach vector
	player.global_position = Vector3(20, 1.0, 0)
	var t: float = 0.0
	while enemy.alert_tier != EnemyBase.AlertTier.COMBAT and t < 8.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("time to COMBAT at 20m open ground: %.2fs (awareness ramp)" % t)
	if enemy.alert_tier != EnemyBase.AlertTier.COMBAT:
		print("FAIL: never reached COMBAT with visible player")
		failures += 1
	await get_tree().create_timer(0.5).timeout
	if enemy.target == null:
		print("FAIL: COMBAT but no target acquired")
		failures += 1

	# 4. Ramp was not instant (fairness: reaction gate).
	if t < 0.2:
		print("FAIL: detection was instant (unfair)")
		failures += 1

	if failures == 0:
		print("PASS: alert tiers + hearing + fair acquisition OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d detection failures" % failures)
		get_tree().quit(1)
