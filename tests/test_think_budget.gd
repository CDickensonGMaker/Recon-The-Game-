## test_think_budget.gd - hot-set liveness + census freshness (W0 preservation probe).
## 14 riflemen, one squad, forced COMBAT on a visible contact - a real firefight.
##   (a) census fresh: EnemySquad.count_engaging equals the measured truth (living
##       hot fighters with the target and LOS), all reports inside ENGAGE_TTL_MS;
##   (b) hot-slot refill: kill a HOT fighter, a cold one is promoted within 500ms wall;
##   (c) census staleness: kill two engagers, wait past ENGAGE_TTL_MS - the dead
##       men's reports expire and the census matches the living truth again.
## Run: godot --headless --path . res://tests/test_think_budget.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"
const SQUAD: int = 5
const FORCE: int = 14

var _failures: int = 0
var _enemies: Array[EnemyBase] = []
var _death_ms: Array[float] = []
var _proxy: Node3D = null


func _ready() -> void:
	print("=== THINK BUDGET probe (hot refill + census) ===")
	await _run()


func _run() -> void:
	EnemySquad.clear()
	EnemyBase.unreported_corpses.clear()
	_make_floor()
	_proxy = Node3D.new()
	add_child(_proxy)
	_proxy.global_position = Vector3(0, 1, 25)
	GameManager.player = _proxy

	for i in FORCE:
		var e: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(-26.0 + 4.0 * float(i), 1, 0), ENEMY_DATA)
		e.squad_id = SQUAD
		e.died.connect(func(_who: EnemyBase) -> void: _death_ms.append(float(Time.get_ticks_msec())))
		_enemies.append(e)
	await get_tree().process_frame
	for e in _enemies:
		e._set_tier(EnemyBase.AlertTier.COMBAT, false)
	await get_tree().create_timer(2.0).timeout

	# (a) census fresh in a stable firefight moment.
	_check_census("(a)", 10)
	if _cold_living().is_empty():
		_fail("(a) no cold fighters with %d men vs HOT_CAP %d - probe vacuous" % [FORCE, EnemySquad.HOT_CAP])

	# (b) hot-slot refill: kill a hot man, clock a cold man's promotion.
	var pre_b: int = _failures
	var cold_before: Array[EnemyBase] = _cold_living()
	var hot_victim: EnemyBase = null
	for e in _living():
		if EnemySquad.is_hot(e):
			hot_victim = e
			break
	if hot_victim == null:
		_fail("(b) no hot fighter alive to kill - probe cannot run")
		get_tree().quit(1)
		return
	hot_victim.take_damage(10, Enums.DamageType.PHYSICAL, null, "HEAD")
	var t0: float = float(Time.get_ticks_msec())
	var promoted_ms: float = -1.0
	while promoted_ms < 0.0 and float(Time.get_ticks_msec()) - t0 < 900.0:
		for c in cold_before:
			if is_instance_valid(c) and not c.is_dead() and EnemySquad.is_hot(c):
				promoted_ms = float(Time.get_ticks_msec()) - t0
				break
		if promoted_ms < 0.0:
			await get_tree().process_frame
	print("  hot-slot refill after kill: %.0fms" % promoted_ms)
	if promoted_ms < 0.0:
		_fail("(b) no cold fighter promoted after a hot death (fight goes quiet)")
	elif promoted_ms > 500.0:
		_fail("(b) refill took %.0fms (>500ms budget)" % promoted_ms)
	if _failures == pre_b:
		print("  [OK] (b) promote-on-death refilled the hot set in time")

	# (c) staleness: kill two engagers, wait out ENGAGE_TTL_MS, census must shed them.
	var killed: int = 0
	for e in _living():
		if EnemySquad.is_hot(e) and killed < 2:
			e.take_damage(10, Enums.DamageType.PHYSICAL, null, "HEAD")
			killed += 1
	await get_tree().create_timer((EnemySquad.ENGAGE_TTL_MS + 600.0) / 1000.0).timeout
	_check_census("(c)", 8)

	GameManager.player = null
	EnemySquad.clear()
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## Truth = living HOT fighters holding the proxy with LOS (only full thinks report).
## Reports from men dead less than ENGAGE_TTL_MS are legally still fresh, so the
## census may exceed truth by at most that count - never more, never less than truth.
func _check_census(tag: String, min_truth: int) -> void:
	var now: float = float(Time.get_ticks_msec())
	var truth: int = 0
	for e in _living():
		if EnemySquad.is_hot(e) and e.target == _proxy and e.has_line_of_sight:
			truth += 1
	var recent_dead: int = 0
	for ms in _death_ms:
		if now - ms < EnemySquad.ENGAGE_TTL_MS + 200.0:
			recent_dead += 1
	var census: int = EnemySquad.count_engaging(SQUAD, _proxy, null, now)
	print("  %s census=%d truth=%d recent_dead=%d living=%d hot=%d" % [
		tag, census, truth, recent_dead, _living().size(), EnemySquad.hot_count()])
	if truth < min_truth:
		_fail("%s only %d honest engagers (want >=%d) - firefight never stabilized" % [tag, truth, min_truth])
	if census < truth:
		_fail("%s census %d UNDERCOUNTS truth %d - spread discipline dissolves" % [tag, census, truth])
	elif census > truth + recent_dead:
		_fail("%s census %d exceeds truth %d + fresh dead %d - stale reports leak" % [tag, census, truth, recent_dead])
	else:
		print("  [OK] %s census bounded: truth <= %d <= truth+fresh_dead" % [tag, census])


func _living() -> Array[EnemyBase]:
	var out: Array[EnemyBase] = []
	for e in _enemies:
		if is_instance_valid(e) and not e.is_dead():
			out.append(e)
	return out


func _cold_living() -> Array[EnemyBase]:
	var out: Array[EnemyBase] = []
	for e in _living():
		if not EnemySquad.is_hot(e):
			out.append(e)
	return out


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL %s" % msg)
