## test_field_marks.gd - The report verb / INTEL layer (ADR-022 Amendment A).
## Behavioral: mark purity + serialization, noun-inference priority, the seed/bank
## path, the CampaignState round-trip. Structural: the four §4 clauses and the
## death of the binocular Label3D fossil (ADR-023).
## Run: godot --headless --path . res://tests/test_field_marks.tscn
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
	_test_mark_purity_and_serialization()
	_test_inference_priority()
	_test_area_radius_is_large_and_clamped()
	_test_seed_and_bank()
	_test_campaign_round_trip()
	_probe_selector_and_tasking_never_read_marks()
	_probe_scorer_never_tallies_marks()
	_probe_no_counter_no_floating_marker()
	_finish()


## §4 CLAUSE: a mark is pure {kind, area, placed_at} - no completion, no objective.
func _test_mark_purity_and_serialization() -> void:
	var ms := MissionState.new()
	ms.add_field_mark("TUNNEL", Vector3(120.0, 3.0, 340.0), 55.0, 4)
	if ms.field_marks.size() != 1:
		_fail("add_field_mark did not append")
		return
	var m: Dictionary = ms.field_marks[0]
	var keys: Array = m.keys()
	keys.sort()
	if keys != ["area", "kind", "placed_at"]:
		_fail("mark is not pure {kind, area, placed_at}: %s" % str(keys))
	var area: Dictionary = m.get("area", {})
	var akeys: Array = area.keys()
	akeys.sort()
	if akeys != ["r", "x", "z"]:
		_fail("mark area is not {x, z, r}: %s" % str(akeys))
	if str_to_var(var_to_str(ms.field_marks)) != ms.field_marks:
		_fail("field_marks do not survive a var_to_str round trip")
	var r: Dictionary = ms.build_result(true, "PATROL")
	for k in r.keys():
		if str(k).findn("mark") != -1:
			_fail("build_result carries a mark key '%s' - the AAR must never tally marks (§4)" % str(k))


## One verb, world-inferred noun: a man beats a hole, a hole beats a hut, a hut
## beats a trail. FOUR nouns only.
func _test_inference_priority() -> void:
	var tunnel := StaticBody3D.new()
	tunnel.add_to_group("tunnel_entrances")
	add_child(tunnel)
	tunnel.global_position = Vector3(10, 0, 10)
	var hut := StaticBody3D.new()
	hut.add_to_group("flammable_structures")
	add_child(hut)
	var ground := StaticBody3D.new()
	add_child(ground)
	var trail_seg := PackedVector3Array([Vector3(0, 0, 0), Vector3(20, 0, 0)])
	var tunnels: Array = [tunnel]
	var camps: Array = [Vector3(200, 0, 200)]
	var segs: Array = [trail_seg]

	if FieldMarkVerb.infer(tunnel, Vector3(10, 0, 10), tunnels, camps, segs) != "TUNNEL":
		_fail("a tunnel mouth under the reticle must read TUNNEL")
	if FieldMarkVerb.infer(ground, Vector3(12, 0, 12), tunnels, camps, segs) != "TUNNEL":
		_fail("ground beside a tunnel mouth (within %sm) must read TUNNEL" % FieldMarkVerb.TUNNEL_NEAR_M)
	if FieldMarkVerb.infer(hut, Vector3(500, 0, 500), [], camps, segs) != "CAMP":
		_fail("a structure under the reticle must read CAMP")
	if FieldMarkVerb.infer(ground, Vector3(210, 0, 205), [], camps, segs) != "CAMP":
		_fail("ground inside a site footprint must read CAMP")
	if FieldMarkVerb.infer(ground, Vector3(10, 0, 2), [], [], segs) != "TRAIL":
		_fail("ground beside the trail must read TRAIL")
	if FieldMarkVerb.infer(ground, Vector3(900, 0, 900), tunnels, camps, segs) != "":
		_fail("bare jungle must infer NOTHING - a failed press is silent")
	tunnel.queue_free()
	hut.queue_free()
	ground.queue_free()


## The circle IS the uncertainty: large from the first metre, wider with range,
## clamped so a long glass never becomes a map-wide smear.
func _test_area_radius_is_large_and_clamped() -> void:
	if FieldMarkVerb.area_radius(0.0) < 40.0:
		_fail("a point-blank mark must still be a LARGE area circle")
	if FieldMarkVerb.area_radius(100.0) <= FieldMarkVerb.area_radius(10.0):
		_fail("area radius must grow with range")
	if FieldMarkVerb.area_radius(5000.0) > FieldMarkVerb.AREA_R_MAX:
		_fail("area radius must clamp at AREA_R_MAX")


## Marks persist across excursions: CampaignState seeds the fresh MissionState and
## the bank point writes back.
func _test_seed_and_bank() -> void:
	var kept: Array = CampaignState.field_marks
	CampaignState.field_marks = [{"kind": "CAMP", "area": {"x": 1.0, "z": 2.0, "r": 60.0}, "placed_at": 2}]
	var d := FieldDirector.new()
	d.restore_field_marks()
	if d.state.field_marks.size() != 1 or str(d.state.field_marks[0].get("kind", "")) != "CAMP":
		_fail("restore_field_marks did not seed the mission state from the campaign")
	d.state.add_field_mark("TRAIL", Vector3(50, 0, 50), 45.0, 3)
	d.bank_field_marks()
	if CampaignState.field_marks.size() != 2:
		_fail("bank_field_marks did not write the patrol's marks back to the campaign")
	d.free()
	CampaignState.field_marks = kept


func _test_campaign_round_trip() -> void:
	var kept_path: String = CampaignState.save_path
	var kept_marks: Array = CampaignState.field_marks
	CampaignState.save_path = "user://test_field_marks.cfg"
	CampaignState.field_marks = [{"kind": "TUNNEL", "area": {"x": 9.0, "z": 8.0, "r": 70.0}, "placed_at": 1}]
	CampaignState.save_campaign()
	CampaignState.field_marks = []
	CampaignState.load_campaign()
	if CampaignState.field_marks.size() != 1 or str(CampaignState.field_marks[0].get("kind", "")) != "TUNNEL":
		_fail("field_marks did not survive a save/load round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_field_marks.cfg"))
	CampaignState.save_path = kept_path
	CampaignState.field_marks = kept_marks


## §4 CLAUSE: the tasking/selector never reads marks. In field_director.gd the ONLY
## code lines naming field_marks are the seed and the bank.
func _probe_selector_and_tasking_never_read_marks() -> void:
	var src: String = _read("res://scripts/missions/field_director.gd")
	for raw_line in src.split("\n"):
		var line: String = str(raw_line)
		if line.findn("field_marks") == -1:
			continue
		var code: String = line.strip_edges()
		if code.begins_with("#") or code.begins_with("##"):
			continue
		var legal := code == "state.field_marks = CampaignState.field_marks.duplicate(true)" \
			or code == "CampaignState.field_marks = state.field_marks.duplicate(true)" \
			or code.begins_with("func restore_field_marks") \
			or code.begins_with("func bank_field_marks") \
			or code == "restore_field_marks()" \
			or code == "bank_field_marks()"
		if not legal:
			_fail("field_director.gd reads field_marks outside seed/bank: '%s' (§4)" % code)


## §4 CLAUSE: the scorer/AAR never tallies marks by kind.
func _probe_scorer_never_tallies_marks() -> void:
	if _read("res://scripts/ui/screens/debrief.gd").findn("field_marks") != -1:
		_fail("the scorer/debrief reads field_marks - marks must never price into score (§4)")


## §4 CLAUSE: no on-screen mark counter and no floating world marker. The map draws
## the marks (that is their home); the in-field HUD and the world never do. The old
## binocular Label3D auto-mark is DEAD (ADR-023) and must stay dead.
func _probe_no_counter_no_floating_marker() -> void:
	for path in ["res://scripts/ui/hud.gd", "res://scripts/ui/mission_hud.gd"]:
		if _read(path).findn("field_marks") != -1:
			_fail("%s reads field_marks - no on-screen mark counter (§4)" % path)
	var player_src: String = _read("res://scripts/player/player.gd")
	for tok in ["Label3D", "_mark_timer", "\"marked\""]:
		if player_src.find(tok) != -1:
			_fail("player.gd still carries '%s' - the binocular floating-marker fossil must stay dead (ADR-023)" % tok)


func _finish() -> void:
	if _failures == 0:
		print("PASS: field marks - report verb, INTEL layer, four nouns, §4 clauses, fossil dead")
	else:
		print("FAIL: %d field-mark failures" % _failures)
	get_tree().quit(_failures)
