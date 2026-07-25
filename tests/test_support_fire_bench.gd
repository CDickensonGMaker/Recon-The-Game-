## test_support_fire_bench.gd - the support-fire bench (P1) + WP + felling (P3).
## Behavioral: FireSupportBench.wire stocks every tier incl. WP; a FellableTree registers
## on the blast bus and leaves it when felled. Structural (ratcheting): the fire-support rig
## was EXTRACTED from the arena, not cloned (ADR-023), and WP is a real deliverable kind.
## Run: godot --headless --path . res://tests/test_support_fire_bench.tscn -- --test-save
extends Node

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("could not read %s" % path)
		return ""
	return f.get_as_text()


func _run() -> void:
	_test_bench_wire_stocks_every_tier()
	_test_fellable_tree_rides_the_blast_bus()
	_probe_rig_extracted_not_cloned()
	_probe_wp_is_a_real_kind()
	_finish()


## FireSupportBench.wire builds a FieldDirector stocked on all six tiers + WP.
func _test_bench_wire_stocks_every_tier() -> void:
	var host := Node3D.new()
	add_child(host)
	var pl := Node3D.new()
	host.add_child(pl)
	var d: FieldDirector = FireSupportBench.wire(host, pl, 200.0)
	if d == null:
		_fail("FireSupportBench.wire returned null")
	else:
		for tier in ["bombs", "napalm", "arty", "mortar", "spectre", "cbu", "wp"]:
			if int(d.fire_support.get(tier, 0)) <= 0:
				_fail("bench tier '%s' not stocked" % tier)
	host.queue_free()


## A FellableTree registers on AgentRegistry.props and leaves the bus the moment it is felled.
func _test_fellable_tree_rides_the_blast_bus() -> void:
	var host := Node3D.new()
	add_child(host)
	var tree := FellableTree.create(host, Vector3(10.0, 0.0, 10.0), 60)
	if tree == null:
		_fail("FellableTree.create returned null")
		host.queue_free()
		return
	if not AgentRegistry.props.has(tree):
		_fail("felled tree never registered on the blast bus (AgentRegistry.props)")
	tree.take_damage(999)   # lethal - begins the fall + leaves the bus this frame
	if AgentRegistry.props.has(tree):
		_fail("a felled tree is still on the blast bus (should unregister on death)")
	host.queue_free()


## The rig moved to FireSupportBench and was DELETED from the arena (ADR-023: extract, not clone).
func _probe_rig_extracted_not_cloned() -> void:
	var arena: String = _read("res://scripts/levels/ai_stress_arena.gd")
	for cloned in ["class ArenaFireWorld", "class ArenaFlatTerrain", "class DestructibleFortification"]:
		if arena.find(cloned) != -1:
			_fail("ai_stress_arena.gd still defines '%s' — the rig must live only in FireSupportBench" % cloned)
	if arena.find("FireSupportBench.wire") == -1:
		_fail("the arena no longer delegates to FireSupportBench.wire")
	var bench: String = _read("res://scripts/levels/fire_support_bench.gd")
	for owned in ["class BenchWorld", "class BenchTerrain", "class DestructibleFortification", "static func wire"]:
		if bench.find(owned) == -1:
			_fail("fire_support_bench.gd is missing '%s'" % owned)


## Willy Pete is a real deliverable kind, not just a dict entry.
func _probe_wp_is_a_real_kind() -> void:
	var fd: String = _read("res://scripts/missions/field_director.gd")
	if fd.find("\"wp\":") == -1:
		_fail("field_director.gd has no 'wp' fire-mission case")
	if fd.find("func _run_wp_mission") == -1:
		_fail("field_director.gd has no _run_wp_mission delivery")


func _finish() -> void:
	if _failures == 0:
		print("PASS: support-fire bench - wire stocks WP, felling rides the bus, rig extracted")
	else:
		print("FAIL: %d support-fire bench failures" % _failures)
	get_tree().quit(_failures)
