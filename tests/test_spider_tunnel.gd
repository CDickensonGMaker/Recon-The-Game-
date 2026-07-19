## test_spider_tunnel.gd - buried spider-hole ambusher (W0 preservation probe).
##   (a) at 2x trigger range the hole stays buried: invisible, no collision, no pop;
##   (b) a player walking in pops the ambush BY trigger range (+0.5m margin, not
##       early) and not late (>= 5.5m at pop with a 0.5m/0.25s approach);
##   (c) the pop is a real ambush: visible, collision live, COMBAT tier, player targeted.
## Run: godot --headless --path . res://tests/test_spider_tunnel.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"

var _failures: int = 0


func _ready() -> void:
	print("=== SPIDER HOLE probe ===")
	await _run()


func _run() -> void:
	_make_floor()
	var spider: EnemyBase = _spawn_spider(Vector3(0, 1, 0))
	var proxy := Node3D.new()
	add_child(proxy)
	proxy.global_position = Vector3(EnemyBase.SPIDER_TRIGGER_RANGE * 2.0, 1, 0)
	GameManager.player = proxy
	await get_tree().create_timer(2.0).timeout

	# (a) 2x range: still buried.
	if spider._spider_triggered:
		_fail("(a) popped at %.1fm (2x trigger range)" % _dist(spider, proxy))
	if spider.visible:
		_fail("(a) buried hole is visible")
	if spider.collision_layer != 0:
		_fail("(a) buried hole has live collision (layer=%d)" % spider.collision_layer)
	if _failures == 0:
		print("  [OK] (a) no pop at %.1fm, invisible, collision off" % _dist(spider, proxy))

	# (b) walk in at 2 m/s; record the distance at the moment of the pop.
	var pop_dist: float = -1.0
	while _dist(spider, proxy) > 4.0:
		proxy.global_position.x -= 0.5
		await get_tree().create_timer(0.25).timeout
		if spider._spider_triggered:
			pop_dist = _dist(spider, proxy)
			break
	print("  pop at %.2fm (trigger range %.1fm)" % [pop_dist, EnemyBase.SPIDER_TRIGGER_RANGE])
	if pop_dist < 0.0:
		_fail("(b) never popped - player walked to 4m over a live spider hole")
	elif pop_dist > EnemyBase.SPIDER_TRIGGER_RANGE + 0.5:
		_fail("(b) popped EARLY at %.2fm (range inflated)" % pop_dist)
	elif pop_dist < 5.5:
		_fail("(b) popped LATE at %.2fm (trigger sluggish)" % pop_dist)
	else:
		print("  [OK] (b) pop inside the trigger band")

	# (c) the pop is a real ambush.
	if pop_dist > 0.0:
		var pre_c: int = _failures
		if not spider.visible:
			_fail("(c) popped but still invisible")
		if spider.collision_layer != 4:
			_fail("(c) popped but collision dead (layer=%d)" % spider.collision_layer)
		if spider.alert_tier != EnemyBase.AlertTier.COMBAT:
			_fail("(c) popped but not COMBAT (tier=%d)" % spider.alert_tier)
		if spider.target != proxy:
			_fail("(c) popped without targeting the player")
		if _failures == pre_c:
			print("  [OK] (c) ambush live: visible, collision, COMBAT, player targeted")

	GameManager.player = null
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _spawn_spider(pos: Vector3) -> EnemyBase:
	var enemy := EnemyBase.new()
	enemy.enemy_data_path = ENEMY_DATA
	enemy.is_spider_hole = true
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	enemy.add_child(col)
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	add_child(enemy)
	enemy.global_position = pos
	enemy.reset_physics_interpolation()
	return enemy


func _dist(a: Node3D, b: Node3D) -> float:
	return a.global_position.distance_to(b.global_position)


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL %s" % msg)
