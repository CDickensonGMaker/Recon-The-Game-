## test_exfil_sim.gd - NS15: mission completes ONLY after bird lands + boarding;
## ABORT path flags emergency exfil. Run: godot --headless --path . res://tests/test_exfil_sim.tscn
extends Node

var mission_done: bool = false
var mission_failed: bool = false
var result: Dictionary = {}
var bird_was_called: bool = false
var bird_did_land: bool = false


func _on_done(r: Dictionary) -> void:
	mission_done = true
	result = r


func _on_failed(r: Dictionary) -> void:
	mission_failed = true
	result = r


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 606
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world timeout")
		get_tree().quit(1)
		return

	var director := MissionDirector.new()
	world.add_child(director)
	director.setup(world)
	director.mission_completed.connect(_on_done)
	director.mission_failed.connect(_on_failed)

	var plan: Dictionary = MissionGenerator.plan(world, 12, MissionGenerator.MissionType.PATROL)
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	var player: CharacterBody3D = world.player
	var exfil: ExfilZone = built.exfil_zone
	exfil.bird_called.connect(func() -> void: bird_was_called = true)
	exfil.bird_landed.connect(func() -> void: bird_did_land = true)

	var failures: int = 0

	# ABORT path: force emergency exfil without doing objectives.
	director.state.emergency_exfil = true
	exfil.force_unlock = true
	# Force a HOT primary LZ so the compromise path fires (wave-off or shootdown),
	# then the fallback LZ must be final and extraction succeeds there.
	exfil.shoot_down_chance = 1.0  # deterministic: always shot down
	var exfil_pos: Vector3 = exfil.global_position
	player.global_position = Vector3(exfil_pos.x, world.terrain_manager.get_height_at(exfil_pos) + 1.0, exfil_pos.z)

	var heated := false
	var wait: float = 0.0
	while not (mission_done or mission_failed) and wait < 150.0:
		await get_tree().create_timer(0.5).timeout
		wait += 0.5
		# Keep the primary LZ cooking while the bird is inbound (threat decays).
		if not exfil.is_final_lz() and exfil._lz != null:
			exfil._lz.add_threat(1.0)
			heated = true
		# Follow the (possibly relocated) exfil zone.
		exfil_pos = exfil.global_position
		player.global_position = Vector3(exfil_pos.x, world.terrain_manager.get_height_at(exfil_pos) + 1.0, exfil_pos.z)

	if not heated:
		print("FAIL: LZ never heated (bird flow broken)")
		failures += 1
	if not exfil.is_final_lz():
		print("FAIL: shootdown did not trigger fallback LZ")
		failures += 1
	else:
		print("shootdown -> fallback LZ used (final), extraction at fallback")

	if not bird_was_called:
		print("FAIL: bird never called")
		failures += 1
	if not bird_did_land:
		print("FAIL: bird never landed")
		failures += 1
	if not mission_failed:
		print("FAIL: emergency exfil should end as failed-forward (got done=%s failed=%s)" % [mission_done, mission_failed])
		failures += 1
	elif not bool(result.emergency_exfil):
		print("FAIL: result missing emergency flag: %s" % result)
		failures += 1
	else:
		print("emergency exfil result: reason=%s objectives=%d/%d" % [result.reason, result.objectives_done, result.objectives_total])

	if failures == 0:
		print("PASS: exfil bird + abort flow OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
