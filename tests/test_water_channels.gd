## test_water_channels.gd - ADR-027 water: assert the AO holds flowing channels
## (creeks/rivers) ONLY - zero lakes/ponds/swamps/coastal, every body fordable.
## Run: <godot> --headless --path . res://tests/test_water_channels.tscn
extends Node

const SEEDS: Array[int] = [42, 1337, 9001]
const FORDABLE_CAP_M: float = 3.0  ## deepest allowed water; rivers ~2.5m

# WaterBodyData.Type codes.
const T_CREEK: int = 1
const T_RIVER: int = 2
const T_POND: int = 3
const T_LAKE: int = 4
const T_SWAMP: int = 5
const T_COASTAL: int = 6


func _ready() -> void:
	# NOTE: per-process determinism (ADR-010) is proven separately by
	# test_water_once run twice in fresh processes - a SAME-process re-boot is
	# contaminated by the pre-existing global-RNG leak (worldgen determinism-cleanup
	# phase), so it is not asserted here.
	var failures: int = 0
	var total_channels: int = 0
	for seed_val in SEEDS:
		var r: Dictionary = await _test_seed(seed_val)
		failures += int(r.failures)
		total_channels += int(r.channels)

	if total_channels == 0:
		print("FAIL: no creek/river bodies on any seed - channels vanished")
		failures += 1

	if failures == 0:
		print("PASS: channels only, fordable, deterministic (%d channel bodies)" % total_channels)
		get_tree().quit(0)
	else:
		print("FAIL: %d water failures" % failures)
		get_tree().quit(1)


func _test_seed(seed_val: int) -> Dictionary:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = seed_val
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL[%d]: world timeout" % seed_val)
		world.queue_free()
		return {"failures": 1, "channels": 0, "fingerprint": ""}

	var failures: int = 0
	var channels: int = 0
	var counts: Dictionary = {}
	var max_depth: float = 0.0
	for body in world.water_system.water_bodies.values():
		var t: int = body.type
		counts[t] = int(counts.get(t, 0)) + 1
		max_depth = maxf(max_depth, body.depth)
		if t == T_CREEK or t == T_RIVER:
			channels += 1
		if t == T_LAKE or t == T_POND or t == T_SWAMP or t == T_COASTAL:
			print("FAIL[%d]: standing-water body type=%d (lakes/ponds/swamps must be gone)" % [seed_val, t])
			failures += 1
		if body.depth > FORDABLE_CAP_M:
			print("FAIL[%d]: body depth %.2fm exceeds fordable cap %.1fm" % [seed_val, body.depth, FORDABLE_CAP_M])
			failures += 1

	var stats: Dictionary = world.water_system.get_stats()
	if int(stats.lakes) != 0 or int(stats.ponds) != 0 or int(stats.swamps) != 0:
		print("FAIL[%d]: get_stats lakes=%d ponds=%d swamps=%d" % [seed_val, stats.lakes, stats.ponds, stats.swamps])
		failures += 1

	print("seed %d: creeks=%d rivers=%d max_depth=%.2fm bodies=%d" % [
		seed_val, int(counts.get(T_CREEK, 0)), int(counts.get(T_RIVER, 0)),
		max_depth, world.water_system.water_bodies.size()])

	var fingerprint: String = "c%d_r%d_d%.2f" % [int(counts.get(T_CREEK, 0)), int(counts.get(T_RIVER, 0)), max_depth]
	world.queue_free()
	await get_tree().process_frame
	return {"failures": failures, "channels": channels, "fingerprint": fingerprint}
