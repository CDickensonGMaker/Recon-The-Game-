## test_terrain_throttle.gd - terrain destruction throttle (ADR-031). A crater's expensive
## heightmap dig is QUEUED and drained a bounded N-per-frame (WorldConfig.TERRAIN_DEFORMS_PER_FRAME),
## not run inline, so a napalm run never eats a whole frame. Exercised end-to-end against a
## counting terrain stub. Run: godot --headless --path . res://tests/test_terrain_throttle.tscn -- --test-save
extends Node

var _failures := 0


class TerrainStub extends Node:
	var cell_size: float = 4.0
	var chunk_size: float = 256.0
	var heightmap = null
	var modify_calls: int = 0

	func get_height_at(_p: Vector3) -> float:
		return 0.0

	func modify_terrain(_p: Vector3, _r: float, _f: Callable) -> void:
		modify_calls += 1


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	var saved_tm: Node = DamageSystem.terrain_manager
	var saved_veg: Node = DamageSystem.vegetation_manager
	DamageSystem.clear_all_damage()
	DamageSystem.vegetation_manager = null   # skip the veg-clear branch for a clean count
	var stub := TerrainStub.new()
	add_child(stub)
	DamageSystem.terrain_manager = stub

	# Fire five craters. The cheap scar applies inline; the expensive dig must be DEFERRED.
	for i in range(5):
		DamageSystem.apply_damage(Vector3(float(i) * 10.0, 0.0, 0.0), DamageSystem.DamageType.MEDIUM_EXPLOSION)
	if stub.modify_calls != 0:
		_fail("dig ran inline (%d) — it must be queued, never inside apply_damage" % stub.modify_calls)
	if DamageSystem._deform_queue.size() != 5:
		_fail("expected 5 queued digs, got %d" % DamageSystem._deform_queue.size())

	# One frame drains exactly the throttle amount.
	var per_frame: int = maxi(1, WorldConfig.TERRAIN_DEFORMS_PER_FRAME)
	DamageSystem._process(0.1)
	if stub.modify_calls != per_frame:
		_fail("one frame drained %d digs, expected the throttle %d" % [stub.modify_calls, per_frame])
	if DamageSystem._deform_queue.size() != 5 - per_frame:
		_fail("queue not drained by exactly the throttle amount")

	# Drain the rest — every crater eventually digs, none is lost.
	for _f in range(10):
		DamageSystem._process(0.1)
	if not DamageSystem._deform_queue.is_empty():
		_fail("queue never fully drained")
	if stub.modify_calls != 5:
		_fail("only %d of 5 craters ever dug" % stub.modify_calls)

	DamageSystem.terrain_manager = saved_tm
	DamageSystem.vegetation_manager = saved_veg
	DamageSystem.clear_all_damage()
	stub.queue_free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: terrain throttle - digs queue + drain per-frame")
	else:
		print("FAIL: %d terrain throttle failures" % _failures)
	get_tree().quit(_failures)
