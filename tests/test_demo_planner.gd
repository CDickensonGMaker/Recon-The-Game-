## test_demo_planner.gd - MissionGenerator.plan_demo_world (mission_generator.gd:666-800),
## the planner behind the EA product (demo_game.gd, plan_demo_world -> build_patrol_world
## on a 512m map). No automated coverage existed for it before this file.
##
## Builds a bare GameWorld the way game_flow.gd:582-589 does for demo_mode (map_size 512,
## spawn_player_on_ready false) - the planner only reads terrain_manager/vegetation_manager/
## gameplay_grid, so player/squad/director are unneeded weight.
## Run: godot --headless --path . res://tests/test_demo_planner.tscn -- --test-save
extends Node

const DEMO_SEED: int = 29072026   ## DemoGame.DEMO_SEED - the shipped seed
const MAP_SIZE: float = 512.0     ## GameFlow.DEMO_MAP_SIZE

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	var world: GameWorld = await _build_world()
	if world == null:
		_fail("demo world terrain never came up")
		_finish()
		return

	# 1. DETERMINISM - the strongest guard, checked first.
	var p1: Dictionary = MissionGenerator.plan_demo_world(world, DEMO_SEED)
	var p2: Dictionary = MissionGenerator.plan_demo_world(world, DEMO_SEED)
	var fc1: Vector3 = p1.fsb_center
	var fc2: Vector3 = p2.fsb_center
	var gp1: Vector3 = p1.gate_pos
	var gp2: Vector3 = p2.gate_pos
	if fc1 != fc2:
		_fail("fsb_center not deterministic: %s vs %s" % [str(fc1), str(fc2)])
	if gp1 != gp2:
		_fail("gate_pos not deterministic: %s vs %s" % [str(gp1), str(gp2)])
	var sites1: Array = p1.sites
	var sites2: Array = p2.sites
	if sites1.size() != sites2.size():
		_fail("site count not deterministic: %d vs %d" % [sites1.size(), sites2.size()])

	var p: Dictionary = p1

	# 2. village_centers non-empty AND a "village" site exists - the code has an explicit
	# fallback (mission_generator.gd:713-716) so this can never legitimately be empty.
	var villages: Array = p.village_centers
	if villages.is_empty():
		_fail("village_centers is empty - the fallback should have prevented this")
	var has_village_site := false
	for s in (p.sites as Array):
		if str((s as Dictionary).get("kind", "")) == "village":
			has_village_site = true
	if not has_village_site:
		_fail("no site of kind 'village' in p.sites")

	# 3. first_signs non-empty (2-3 craters expected) - the 200m landmark stretch
	# (mission_generator.gd:763-769) where the five-minute rule is won or lost.
	var signs: Array = p.first_signs
	if signs.is_empty():
		_fail("first_signs is empty - the outbound landmark stretch has nothing in it")

	# 4. weather/time must agree with DemoGame.START_HOUR's period. mission_weather.gd:51
	# seeds the sim clock straight from these two strings; START_HOUR=6.5 falls in DAWN
	# (sim_clock.period_at), so a mismatch here desyncs the boot lighting from the arc.
	if str(p.get("weather", "")) != "CLEAR":
		_fail("weather is '%s', want 'CLEAR'" % str(p.get("weather", "")))
	if str(p.get("time", "")) != "DAWN":
		_fail("time is '%s', want 'DAWN'" % str(p.get("time", "")))

	# 5. Required world anchors present and non-zero.
	var anchor_keys: Array[String] = ["gate_pos", "gate_out", "insertion_lz", "fsb_center"]
	for key in anchor_keys:
		if not p.has(key):
			_fail("plan is missing '%s'" % key)
			continue
		var v: Vector3 = p[key]
		if v == Vector3.ZERO:
			_fail("'%s' is Vector3.ZERO" % key)

	# 6. No site center lies inside the firebase rect - sites must not spawn on top
	# of the base (the wire is law, per test_patrol_world.gd's own keep-out check).
	var fc: Vector3 = p.fsb_center
	var fsb_rect := Rect2(fc.x - SitePlanner.FSB_HALF.x, fc.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0)
	for s2 in (p.sites as Array):
		var sd: Dictionary = s2
		var sc: Vector3 = sd.center
		if fsb_rect.has_point(Vector2(sc.x, sc.z)):
			_fail("site '%s' at %.0f,%.0f lands inside the firebase rect" % [str(sd.kind), sc.x, sc.z])

	# 7. Temple count is INFORMATION, not a gate - on the shipped DEMO_SEED it is
	# seed-dependent (authored temple + jungle ruins that may or may not find passable ground).
	var temple_count := 0
	for s3 in (p.sites as Array):
		if str((s3 as Dictionary).get("kind", "")) == "temple":
			temple_count += 1
	print("[INFO] temple sites on seed %d: %d" % [DEMO_SEED, temple_count])

	print("demo plan: %d sites, %d villages, %d first signs, gate %.0f,%.0f" % [
		(p.sites as Array).size(), villages.size(), signs.size(), gp1.x, gp1.z])
	_finish()


func _build_world() -> GameWorld:
	var packed: PackedScene = load("res://scenes/levels/game_world.tscn") as PackedScene
	var world: GameWorld = packed.instantiate() as GameWorld
	world.mission_seed = DEMO_SEED
	world.map_size = MAP_SIZE
	world.spawn_player_on_ready = false
	add_child(world)
	var waited := 0.0
	while not world.is_world_ready and waited < 60.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if not world.is_world_ready:
		return null
	return world


func _finish() -> void:
	if _failures == 0:
		print("PASS: demo planner - determinism, village fallback, first signs, weather, keepout")
	else:
		print("FAIL: %d demo planner failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
