## test_downed_enemy.gd - DOWN-NOT-DEAD v1 probe (bead 5iha).
##   1. A downed man is out of the fight: is_dead() true, died emitted ONCE,
##      hp pinned at 1, no AI motion.
##   2. FINISH: further damage kills for real, without double-emitting died.
##   3. SECURE: stabilizes the bleed clock + joins the capture economy.
##   4. Bleed-out: the clock alone kills him.
## Run: godot --headless --path . res://tests/test_downed_enemy.tscn
extends Node3D

var _died_count: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _spawn() -> EnemyBase:
	var dir := DirAccess.open("res://data/enemies")
	var data_path: String = ""
	for f in dir.get_files():
		if f.ends_with(".tres"):
			data_path = "res://data/enemies/" + f
			break
	var e: EnemyBase = EnemyBase.spawn_enemy(self, Vector3.ZERO, data_path)
	return e


func _run() -> void:
	var failures: int = 0

	# --- 1. downed = out of the fight
	var e1: EnemyBase = _spawn()
	await get_tree().process_frame
	_died_count = 0
	e1.died.connect(func(_who: Node) -> void: _died_count += 1)
	e1._become_downed()
	if not e1.is_downed:
		print("FAIL: _become_downed did not set is_downed")
		failures += 1
	if not e1.is_dead():
		print("FAIL: downed man must read is_dead() (targeting/waves drop him)")
		failures += 1
	if _died_count != 1:
		print("FAIL: died emitted %d times on down (want 1)" % _died_count)
		failures += 1
	if e1.current_hp != 1:
		print("FAIL: downed hp %d (want 1)" % e1.current_hp)
		failures += 1

	# --- 2. FINISH: further damage = real death, no double emit
	e1.take_damage(10)
	if e1.current_state != Enums.AIState.DEAD:
		print("FAIL: FINISH did not kill (state %d)" % e1.current_state)
		failures += 1
	if _died_count != 1:
		print("FAIL: died emitted %d times after FINISH (want still 1)" % _died_count)
		failures += 1
	print("  down -> FINISH OK (died emitted once)")

	# --- 3. SECURE
	var e2: EnemyBase = _spawn()
	await get_tree().process_frame
	e2._become_downed()
	if not e2.secure():
		print("FAIL: secure() refused a downed man")
		failures += 1
	if not e2.is_in_group("captured"):
		print("FAIL: secured man not in captured group")
		failures += 1
	if e2._downed_bleed_s < 1000.0:
		print("FAIL: secure did not stop the bleed clock")
		failures += 1
	print("  down -> SECURE OK (captured, stabilized)")

	# --- 4. bleed-out
	var e3: EnemyBase = _spawn()
	await get_tree().process_frame
	e3._become_downed()
	e3._downed_bleed_s = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if e3.current_state != Enums.AIState.DEAD:
		print("FAIL: bleed-out did not kill (bleed %.2f state %d)" % [e3._downed_bleed_s, e3.current_state])
		failures += 1
	else:
		print("  bleed-out OK")

	if failures == 0:
		print("PASS: downed enemy v1 (down/finish/secure/bleed-out) OK")
	else:
		print("FAIL: downed probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
