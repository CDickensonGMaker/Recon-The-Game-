## test_patrol_contract.gd - Phase 1 spine of the patrol contract (ADR-029
## Amendment C, PROPOSED). Behavioral: the route is INPUT to the ONE selector, and
## ground-covered accumulates by distinct sector. Structural (ratcheting): the FOUR
## §4 clauses that keep the loop from becoming the mission tracking ADR-029 §4 bans.
## Run: godot --headless --path . res://tests/test_patrol_contract.tscn -- --test-save
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


func _scripts_gd() -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		d.list_dir_begin()
		var fname: String = d.get_next()
		while fname != "":
			var full: String = dir + "/" + fname
			if d.current_is_dir():
				if not fname.begins_with("."):
					stack.append(full)
			elif fname.ends_with(".gd"):
				out.append(full)
			fname = d.get_next()
		d.list_dir_end()
	return out


func _run() -> void:
	_test_route_is_selector_input()
	_test_bare_mark_points_at_itself()
	_test_ground_covered_accumulator()
	_probe_waypoints_never_check_off()
	_probe_ground_covered_silent()
	_probe_command_names_features_not_pins()
	_probe_route_feeds_only_the_one_selector()
	_finish()


## The route replaces push-direction as the selector's input: the sweep anchors to
## the LIVING feature nearest the next mark (no world/player needed — the route path
## returns before push-direction ever reads the player).
func _test_route_is_selector_input() -> void:
	var d := FieldDirector.new()
	d.patrol_locations = [
		{"pos": Vector3(500, 0, 0), "kind": "village"},
		{"pos": Vector3(0, 0, 500), "kind": "vc_camp"},
	]
	d.set_patrol_route(PackedVector3Array([Vector3(10, 0, 480)]))  # ~22m from the camp
	var picked: Dictionary = d._pick_patrol_location()
	if str(picked.get("kind", "")) != "vc_camp":
		_fail("route anchor did not select the nearest living feature (got %s)" % str(picked))
	d.free()


## A mark with no stamped feature within range points at ITSELF as an area (a pointer,
## never a spawn) — the world stays persistent, nothing is placed on the drawn line.
func _test_bare_mark_points_at_itself() -> void:
	var d := FieldDirector.new()
	d.patrol_locations = [{"pos": Vector3(1000, 0, 1000), "kind": "village"}]
	d.set_patrol_route(PackedVector3Array([Vector3(10, 0, 10)]))  # nothing within 260m
	var p: Dictionary = d._pick_patrol_location()
	if str(p.get("kind", "")) != "area":
		_fail("bare mark should point at itself as 'area', got %s" % str(p))
	elif (p.get("pos", Vector3.ZERO) as Vector3).distance_to(Vector3(10, 0, 10)) > 0.01:
		_fail("area target should be the mark itself")
	d.free()


func _test_ground_covered_accumulator() -> void:
	var ms := MissionState.new()
	ms.mark_covered(Vector3(0, 0, 0))
	ms.mark_covered(Vector3(5, 0, 5))    # same 25m cell as (0,0,0)
	ms.mark_covered(Vector3(30, 0, 0))   # next cell in x
	ms.mark_covered(Vector3(0, 0, 30))   # next cell in z
	if ms.ground_covered_sectors() != 3:
		_fail("ground-covered miscounted sectors: %d (want 3)" % ms.ground_covered_sectors())
	var r: Dictionary = ms.build_result(true, "PATROL")
	if int(r.get("ground_covered", -1)) != 3:
		_fail("ground_covered (%s) not banked into the AAR result" % str(r.get("ground_covered", "absent")))


## §4 CLAUSE 1 — waypoints never check off. A PackedVector3Array cannot carry a
## per-waypoint completion flag, and the selector's source carries no completion verb.
func _probe_waypoints_never_check_off() -> void:
	var d := FieldDirector.new()
	if typeof(d.patrol_route) != TYPE_PACKED_VECTOR3_ARRAY:
		_fail("patrol_route must be PackedVector3Array (a pure position array cannot check off)")
	d.free()
	var src: String = _read("res://scripts/missions/field_director.gd")
	for tok in ["waypoint_done", "waypoint_complete", "route_complete", "route_done", "checked_off", "objective_id"]:
		if src.findn(tok) != -1:
			_fail("field_director.gd carries completion vocabulary '%s' — waypoints must never check off" % tok)


## §4 CLAUSE 2 — ground-covered is debrief-only. It must never be read by an in-field
## HUD (the AAR/debrief screen is allowed; the combat HUD and map are not).
func _probe_ground_covered_silent() -> void:
	var in_field := ["res://scripts/ui/mission_hud.gd", "res://scripts/ui/hud.gd", "res://scripts/ui/topo_map.gd"]
	for path in in_field:
		var s: String = _read(path)
		for tok in ["ground_covered", "covered_cells", "mark_covered", "ground_covered_sectors"]:
			if s.findn(tok) != -1:
				_fail("%s reads '%s' — ground-covered must never reach the in-field HUD (ADR-029 §4)" % [path, tok])


## §4 CLAUSE 3 — command names FEATURES/ORDINALS, never objective pins. The tasking
## still routes through _bearing_name (a feature/bearing), and no pin vocabulary leaks.
func _probe_command_names_features_not_pins() -> void:
	var src: String = _read("res://scripts/missions/field_director.gd")
	if src.find("OBJECTIVE") != -1:
		_fail("field_director.gd tasking uses objective-pin vocabulary 'OBJECTIVE' (§4: name features/ordinals)")
	if src.find("_bearing_name") == -1:
		_fail("tasking no longer names a bearing/feature (_bearing_name missing)")


## §4 CLAUSE 4 — the route feeds ONLY the one selector. No other script reads the
## `patrol_route` member (populating it via set_patrol_route is fine), the scorer never
## sees it, there is exactly one location selector, and no parallel manager node exists.
func _probe_route_feeds_only_the_one_selector() -> void:
	for f in _scripts_gd():
		if f.ends_with("field_director.gd"):
			continue
		var s: String = _read(f).replace("set_patrol_route", "")
		if s.find("patrol_route") != -1:
			_fail("patrol_route is read outside the one selector, in %s (§4)" % f)
	if _read("res://scripts/ui/screens/debrief.gd").find("patrol_route") != -1:
		_fail("the scorer/debrief reads patrol_route — the route must never reach scoring (§4)")
	for banned in ["res://scripts/missions/route_manager.gd",
			"res://scripts/missions/tasking_system.gd",
			"res://scripts/missions/ground_covered_tracker.gd"]:
		if FileAccess.file_exists(banned):
			_fail("a parallel manager node exists (%s) — everything hangs on FieldDirector/MissionState (ADR-023)" % banned)
	var pickers := 0
	for f2 in _scripts_gd():
		if _read(f2).find("func _pick_patrol_location") != -1:
			pickers += 1
	if pickers != 1:
		_fail("%d location selectors found (want exactly 1) — no second picker (ADR-023)" % pickers)


func _finish() -> void:
	if _failures == 0:
		print("PASS: patrol-contract spine - route-as-input, ground-covered, four §4 clauses")
	else:
		print("FAIL: %d patrol-contract failures" % _failures)
	get_tree().quit(_failures)
