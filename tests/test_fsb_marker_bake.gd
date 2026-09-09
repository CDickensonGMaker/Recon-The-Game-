## test_fsb_marker_bake.gd - THE BAKED MARKERS MUST STILL BE THE MODEL'S MARKERS (ADR-043 P0).
##
## The runtime no longer walks the firebase to find its markers; it reads
## data/world/fsb_markers.json. That is only safe while the file agrees with the model, and
## the way it stops agreeing is mundane: somebody re-exports fsb_main_v3.glb and forgets to
## re-run tools/bake_fsb_markers.tscn. Nothing would crash. The garrison would simply stand
## at last week's posts.
##
## This project has shipped that exact class of defect before - the GLB the game loaded was
## a 2026-07-26 export carrying zero chow hall and zero medical complex while both had been
## in the .blend for a week. A stale derived artifact is invisible until someone measures it.
##
## So: walk the scene fresh, compare to the file, and go red on any drift. It is deliberately
## an EQUIVALENCE probe between two things that must agree, which is the shape that has found
## three defects in this codebase this week.
##
## Run: godot --headless --path . res://tests/test_fsb_marker_bake.tscn
extends Node

## Marker origins are authored, not computed - they should match to the float, and a
## millimetre of tolerance is generous. Anything larger is real movement.
const TOL_M: float = 0.001

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	if not FileAccess.file_exists(SitePlanner.FSB_MARKER_BAKE_PATH):
		_fail("no bake at %s - run: godot --headless --path . res://tools/bake_fsb_markers.tscn"
			% SitePlanner.FSB_MARKER_BAKE_PATH)
		_finish()
		return

	var f := FileAccess.open(SitePlanner.FSB_MARKER_BAKE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		_fail("the bake is not a JSON object")
		_finish()
		return
	var baked: Dictionary = parsed
	if int(baked.get("version", 0)) != SitePlanner.FSB_MARKER_BAKE_VERSION:
		_fail("bake version %s, code expects %d - re-bake"
			% [str(baked.get("version", "?")), SitePlanner.FSB_MARKER_BAKE_VERSION])

	var fresh: Dictionary = SitePlanner.bake_fsb_markers_from_scene()
	var fresh_markers: Dictionary = fresh.get("markers", {}) as Dictionary
	var fresh_work: Array = fresh.get("work", []) as Array
	var file_markers: Dictionary = baked.get("markers", {}) as Dictionary
	var file_work: Array = baked.get("work", []) as Array

	# A bake of nothing would satisfy every comparison below against a model that had also
	# lost everything. Assert presence first, or this probe certifies an empty set.
	if fresh_markers.is_empty():
		_fail("the model carries NO named markers at all - export drift in fsb_main_v3.glb")
	if fresh_work.is_empty():
		_fail("the model carries NO work_* markers at all - export drift in fsb_main_v3.glb")

	if file_markers.size() != fresh_markers.size():
		_fail("bake has %d named marker(s), the model has %d"
			% [file_markers.size(), fresh_markers.size()])
	for key_any in fresh_markers.keys():
		var key: String = String(key_any)
		if not file_markers.has(key):
			_fail("marker %s is in the model and not in the bake" % key)
			continue
		var v: Array = file_markers[key] as Array
		var from_file := Vector3(float(v[0]), float(v[1]), float(v[2]))
		var from_model: Vector3 = fresh_markers[key]
		if from_file.distance_to(from_model) > TOL_M:
			_fail("marker %s moved %.4f m: bake %s vs model %s"
				% [key, from_file.distance_to(from_model), from_file, from_model])
	for key_any in file_markers.keys():
		if not fresh_markers.has(String(key_any)):
			_fail("marker %s is in the bake and no longer in the model" % String(key_any))

	if file_work.size() != fresh_work.size():
		_fail("bake has %d work point(s), the model has %d" % [file_work.size(), fresh_work.size()])
	else:
		# The walk sorts by (x, z), so index comparison is meaningful and order drift is
		# itself a finding - fsb_garrison_plan deals posts off this order.
		var moved: int = 0
		var retyped: int = 0
		var redug: int = 0
		for i in range(fresh_work.size()):
			var fe: Array = fresh_work[i]
			var be: Array = file_work[i] as Array
			var fp: Vector3 = fe[0]
			var bp := Vector3(float(be[0]), float(be[1]), float(be[2]))
			if fp.distance_to(bp) > TOL_M:
				moved += 1
			if String(be[3]) != String(fe[1]):
				retyped += 1
			if bool(be[4]) != bool(fe[2]):
				redug += 1
		if moved > 0:
			_fail("%d work point(s) moved between the bake and the model" % moved)
		if retyped > 0:
			_fail("%d work point(s) changed type between the bake and the model" % retyped)
		if redug > 0:
			_fail("%d work point(s) changed dig classification" % redug)

	var dig: int = 0
	for entry_any in fresh_work:
		if bool((entry_any as Array)[2]):
			dig += 1
	print("[FSB BAKE] %d named marker(s), %d work point(s), %d dig-classified"
		% [fresh_markers.size(), fresh_work.size(), dig])
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("test_fsb_marker_bake: PASS")
	else:
		print("test_fsb_marker_bake: %d FAILURE(S) - re-run tools/bake_fsb_markers.tscn" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
