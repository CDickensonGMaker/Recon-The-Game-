## test_destructible.gd - the general Destructible (ADR-031/ADR-023). A lethal blast QUEUES a
## throttled state-swap; draining runs it: off the blast bus, intact mesh hidden, collider
## disabled, shared rubble scattered (deterministic). Exercised end-to-end.
## Run: godot --headless --path . res://tests/test_destructible.tscn -- --test-save
extends Node

var _failures := 0


class TerrainStub extends Node:
	var cell_size: float = 4.0
	var chunk_size: float = 256.0
	var heightmap = null
	func get_height_at(_p: Vector3) -> float:
		return 0.0
	func modify_terrain(_p: Vector3, _r: float, _f: Callable) -> void:
		pass


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	# Give DamageSystem a stub so the death-crater call does not warn about a missing terrain.
	var saved_tm: Node = DamageSystem.terrain_manager
	var saved_veg: Node = DamageSystem.vegetation_manager
	DamageSystem.vegetation_manager = null
	var stub := TerrainStub.new()
	add_child(stub)
	DamageSystem.terrain_manager = stub
	Destructible.reset_all()

	var d := Destructible.new()
	d.hp = 50
	d.kind = "sandbag"
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	d.add_child(mi)
	add_child(d)
	d.global_position = Vector3(10.0, 0.0, 10.0)
	AgentRegistry.register(d, AgentRegistry.Kind.PROP)

	# THE RUIN MUST RESOLVE, or destruction silently goes back to a pop-out. Every kind in the
	# map names a real GLB and yields a real mesh - a renamed ruin asset fails here, not in play.
	for k in Destructible.RUIN_FOR.keys():
		if Destructible.ruin_mesh_for(String(k)) == null:
			_fail("kind '%s' maps to %s but no mesh came out of it" % [k, Destructible.RUIN_FOR[k]])

	# GUNFIRE NEVER DEMOLISHES (Summoner, 2026-08-07). A round PENETRATES a wall; only an
	# explosion brings it down. Enough PHYSICAL damage to kill it twice over must not scratch it.
	d.take_damage(9999, Enums.DamageType.PHYSICAL)
	if d._dying or d._dead or d.hp != 50:
		_fail("rifle fire demolished a structure (hp %d) - penetration is not demolition" % d.hp)

	# Sub-lethal: chips HP only, still intact + on the bus.
	d.take_damage(20, Enums.DamageType.EXPLOSIVE)
	if d._dying or d._dead:
		_fail("a sub-lethal hit destroyed it")
	if not AgentRegistry.props.has(d):
		_fail("intact destructible left the blast bus early")

	# Lethal: queues the swap (throttled), does NOT destroy inline, off the bus.
	d.take_damage(50, Enums.DamageType.EXPLOSIVE)
	if not d._dying:
		_fail("lethal hit did not mark it dying")
	if d._dead:
		_fail("destruction ran INLINE — it must be throttled/queued")
	if AgentRegistry.props.has(d):
		_fail("doomed destructible still on the blast bus")
	if d not in Destructible._destroy_queue:
		_fail("lethal destructible not queued for the throttled swap")

	# Drain runs the swap.
	Destructible.drain(4)
	if not d._dead:
		_fail("drain did not run the destruction")
	if mi.visible:
		_fail("intact mesh still visible after destruction")
	if Destructible._rubble_xforms.is_empty():
		_fail("no rubble scattered")

	Destructible.reset_all()
	AgentRegistry.unregister(d)
	DamageSystem.terrain_manager = saved_tm
	DamageSystem.vegetation_manager = saved_veg
	DamageSystem.clear_all_damage()
	d.queue_free()
	stub.queue_free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: destructible - lethal queues, drain swaps off-bus + rubble")
	else:
		print("FAIL: %d destructible failures" % _failures)
	get_tree().quit(_failures)
