## test_support_fire_bench.gd - the support-fire bench (P1) + WP + felling (P3).
## Behavioral: FireSupportBench.wire stocks every tier incl. WP; a registered tree leaves
## the TreeBreakSystem registry when a blast consumes it. Structural (ratcheting): the
## fire-support rig was EXTRACTED from the arena, not cloned (ADR-023), and WP is a real
## deliverable kind.
## Run: godot --headless --path . res://tests/test_support_fire_bench.tscn -- --test-save
extends Node

var _failures := 0


func _ready() -> void:
	await _run()


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
	_test_bench_wire_stands_up()
	await _test_blast_consumes_a_registered_tree()
	_probe_rig_extracted_not_cloned()
	_probe_wp_is_a_real_kind()
	_finish()


## FireSupportBench.wire builds the full rig — inert world, flat terrain, RTO squad, a
## stocked FieldDirector. Exercised END-TO-END (a real CharacterBody3D player, and the
## wired graph asserted) so a "committed but never ran" break fails loudly right here.
func _test_bench_wire_stands_up() -> void:
	var host := Node3D.new()
	add_child(host)
	var pl := CharacterBody3D.new()
	host.add_child(pl)
	pl.global_position = Vector3(20.0, 1.0, 20.0)
	var d: FieldDirector = FireSupportBench.wire(host, pl, 200.0)
	if d == null:
		_fail("FireSupportBench.wire returned null")
		host.queue_free()
		return
	# The rig stood up and satisfies the interfaces FieldDirector reads off the world.
	if not (d.world is FireSupportBench.BenchWorld):
		_fail("director.world is not a BenchWorld (wire did not build the inert host)")
	elif d.world.player != pl:
		_fail("director.world.player is not the CharacterBody3D we passed")
	elif not (d.world.terrain_manager is FireSupportBench.BenchTerrain):
		_fail("director.world.terrain_manager is not a BenchTerrain")
	elif absf(d.world.terrain_manager.get_height_at(Vector3(5, 5, 5))) > 0.001:
		_fail("BenchTerrain.get_height_at should be a constant 0")
	elif absf(d.world.map_size - 200.0) > 0.001:
		_fail("director.world.map_size not set to the passed map_size")
	if d.squad_system == null:
		_fail("director.squad_system was not wired")
	for tier in ["bombs", "napalm", "arty", "mortar", "spectre", "cbu", "wp"]:
		if int(d.fire_support.get(tier, 0)) <= 0:
			_fail("bench tier '%s' not stocked" % tier)
	host.queue_free()


## S29 replaced FellableTree's per-tree node and blast bus with a data registry: the canopy
## carries ZERO standing colliders and a blast resolves against TreeBreakSystem's spatial
## index. Same contract, one level down - a live tree is registered, a blasted one is not.
##
## Species names are read off the segment art rather than hardcoded: the
## *_stump/_stem/_crown GLBs ARE the set of breakable species, so a test naming its own
## would drift off them.
func _test_blast_consumes_a_registered_tree() -> void:
	var tbs: Node = TreeBreakSystem   # autoload singleton, not a class
	if int(tbs.call("species_count")) <= 0:
		_fail("TreeBreakSystem loaded 0 break bands - the jungle is UNBREAKABLE and S29 "
			+ "can fell nothing. data/veg_break_bands.json does not exist in the repo; "
			+ "the band data was never authored, so this is missing DATA, not missing code.")
		return
	var species: String = _a_breakable_species(tbs)
	if species.is_empty():
		_fail("no *_stump.glb segment species passes TreeBreakSystem.is_breakable")
		return
	var host := Node3D.new()
	add_child(host)
	var layer := Node3D.new()
	host.add_child(layer)
	# Deltas, not absolutes: the singleton is shared and may already hold chunks.
	var before: int = int(tbs.call("registered_count"))
	var at := Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 10.0))
	tbs.call("register_chunk", layer, Vector2i.ZERO, [{"name": species, "xf": at}])
	if int(tbs.call("registered_count")) - before != 1:
		_fail("registered 1 %s instance, registry moved by %d"
			% [species, int(tbs.call("registered_count")) - before])
		tbs.call("unregister_layer", layer)
		host.queue_free()
		return
	if int(tbs.call("apply_blast", at.origin, 8.0)) != 1:
		_fail("a blast on top of the instance consumed nothing")
	if int(tbs.call("registered_count")) != before:
		_fail("a consumed tree is still in the registry (%d over baseline)"
			% [int(tbs.call("registered_count")) - before])
	# The blast QUEUES the promotion; the singleton spawns it on later frames. Tearing
	# the layer down first hands _spawn_broken a freed node.
	tbs.call("unregister_layer", layer)
	for _i in 3:
		await get_tree().process_frame
	host.queue_free()


## First segmented species on disk the loaded bands accept.
func _a_breakable_species(tbs: Node) -> String:
	var dir := DirAccess.open("res://assets/world/vegetation/")
	if dir == null:
		return ""
	for fn in dir.get_files():
		# res:// listings can carry the .import sidecar name instead of the source.
		var base: String = fn.trim_suffix(".import")
		if not base.ends_with("_stump.glb"):
			continue
		var nm: String = base.trim_suffix("_stump.glb")
		if bool(tbs.call("is_breakable", nm)):
			return nm
	return ""


## The rig moved to FireSupportBench and was DELETED from the arena (ADR-023: extract, not clone).
func _probe_rig_extracted_not_cloned() -> void:
	var arena: String = _read("res://scripts/levels/ai_stress_arena.gd")
	for cloned in ["class ArenaFireWorld", "class ArenaFlatTerrain", "class DestructibleFortification"]:
		if arena.find(cloned) != -1:
			_fail("ai_stress_arena.gd still defines '%s' — the rig must live only in FireSupportBench" % cloned)
	if arena.find("FireSupportBench.wire") == -1:
		_fail("the arena no longer delegates to FireSupportBench.wire")
	var bench: String = _read("res://scripts/levels/fire_support_bench.gd")
	for owned in ["class BenchWorld", "class BenchTerrain", "static func wire"]:
		if bench.find(owned) == -1:
			_fail("fire_support_bench.gd is missing '%s'" % owned)
	# DestructibleFortification folded into the general Destructible (ADR-023) — no second path.
	if bench.find("class DestructibleFortification") != -1:
		_fail("DestructibleFortification still defined in fire_support_bench — must fold into Destructible")
	if not FileAccess.file_exists("res://scripts/world/destructible.gd"):
		_fail("the general Destructible component is missing")


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
