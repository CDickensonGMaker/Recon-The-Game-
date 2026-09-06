## probe_siege_fields_men.gd - Does a 30-man siege actually put 30 men on the field?
##
## The suite's `_check_assault_is_coordinated` counts on the SAME frame it calls
## materialize(). MarchingCell drips spawns through a GLOBAL budget of
## SPAWN_PER_FRAME=2 per RENDER frame (marching_cell.gd:147), so a same-frame count
## can never exceed 2 however many men were rolled. This probe measures the same
## siege with frames allowed to pass, and prints the per-frame arrival curve so the
## drip is visible rather than inferred.
extends Node3D

var _failures: int = 0


class StubPlayer extends CharacterBody3D:
	var holding_handset: bool = false
	var director: FieldDirector = null
	func set_on_net(want: bool) -> void:
		holding_handset = want


func _ready() -> void:
	MissionWeather.sight_mult = 1.0
	SimClock.paused = true
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1


func _bare_director(center: Vector3) -> FieldDirector:
	for prior in get_tree().get_nodes_in_group("mission_director"):
		prior.remove_from_group("mission_director")
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	var w := GameWorld.new()
	w.build_terrain_on_ready = false
	add_child(w)
	var pl := StubPlayer.new()
	pl.director = d
	w.add_child(pl)
	pl.global_position = center
	w.player = pl
	d.world = w
	d.fsb_center = center
	d.siege_aim = center + Vector3(0, 0, 8)
	d.patrol_gate_pos = center + Vector3(0, 0, 60)
	d.patrol_gate_out = Vector3.BACK
	return d


func _count() -> Dictionary:
	var sap: int = get_tree().get_nodes_in_group("siege_sappers").size()
	var ch: int = get_tree().get_nodes_in_group("siege_assault").size()
	for i in range(SiegeDirector.ASSAULT_SQUADS):
		ch += get_tree().get_nodes_in_group("siege_assault_%d" % i).size()
	return {"sap": sap, "chg": ch, "tot": sap + ch}


func _run() -> void:
	print("=== PROBE: DOES THE SIEGE FIELD ITS MEN ===")
	var d := _bare_director(Vector3(4200, 0, 0))
	d._attach_siege()
	d.siege.open_siege(30)

	var paper: int = 0
	for c in d.siege.cells:
		paper += c.strength
	print("  rolled: %d cell(s), %d men on paper" % [d.siege.cells.size(), paper])
	_expect(paper == 30, "the roll produced 30 men on paper (got %d)" % paper)

	for c in d.siege.cells:
		c.materialize()
	var same_frame: Dictionary = _count()
	print("  SAME FRAME as materialize(): sappers=%d chargers=%d total=%d"
		% [same_frame.sap, same_frame.chg, same_frame.tot])

	# Let frames pass. The budget is keyed on the RENDER frame, and headless renders far
	# slower than it steps physics, so the drip needs many PHYSICS frames per token.
	var curve: Array[int] = []
	for f in range(240):
		await get_tree().physics_frame
		curve.append(int(_count().tot))
	print("  arrival curve (per frame): %s" % str(curve))
	var fin: Dictionary = _count()
	print("  AFTER 240 frames: sappers=%d chargers=%d total=%d" % [fin.sap, fin.chg, fin.tot])
	_expect(fin.chg > 0, "the assault element reached the field (got %d)" % fin.chg)
	_expect(fin.tot == 30, "all 30 rolled men reached the field (got %d)" % fin.tot)

	# NEGATIVE CONTROL: the same count taken with zero frames must be capped at the
	# global per-frame budget - proving the drip, not the siege, is what a same-frame
	# count measures.
	_expect(same_frame.tot <= MarchingCell.SPAWN_PER_FRAME,
		"CONTROL: a same-frame count is capped at SPAWN_PER_FRAME=%d (got %d)"
		% [MarchingCell.SPAWN_PER_FRAME, same_frame.tot])

	print("")
	if _failures == 0:
		print("probe_siege_fields_men: PASS")
		get_tree().quit(0)
	else:
		push_error("SIEGE FIELDING: %d assertion(s) failed." % _failures)
		print("probe_siege_fields_men: %d FAILURES" % _failures)
		get_tree().quit(1)
