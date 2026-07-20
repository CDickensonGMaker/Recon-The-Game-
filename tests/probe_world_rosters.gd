extends Node
## probe_world_rosters.gd - AirTraffic and AmbientWar kept append-only rosters that
## nothing read and nothing pruned: every flight and every shell-burst stayed in the
## list for the life of the mission, holding a live node.
##
## Run: godot --headless --path . res://tests/probe_world_rosters.tscn

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: WORLD ROSTERS PRUNE ===")

	SimClock.paused = true

	var at := AirTraffic.new()
	add_child(at)
	at.get_in_flight().clear()
	_seed_flight(at, 999999)       # long expired
	_seed_flight(at, 999999)
	_seed_flight(at, 0)            # born now
	_expect(at.get_in_flight().size() == 3, "3 flights on the roster")
	at._process(0.0)
	_expect(at.get_in_flight().size() == 1,
		"expired flights retired, fresh one kept (got %d)" % at.get_in_flight().size())

	# NEGATIVE CONTROL: pruning must be age-based, not "empty the list".
	at._process(0.0)
	_expect(at.get_in_flight().size() == 1,
		"NEGATIVE CONTROL: a fresh flight survives repeated prunes")

	var aw := AmbientWar.new()
	add_child(aw)
	aw.get_active().clear()
	_seed_event(aw, 5.0, 999999)   # 5s life, born long ago
	_seed_event(aw, 30.0, 0)       # 30s life, born now
	_expect(aw.get_active().size() == 2, "2 war events on the roster")
	aw._process(0.0)
	_expect(aw.get_active().size() == 1,
		"expired event retired, live one kept (got %d)" % aw.get_active().size())
	aw._process(0.0)
	_expect(aw.get_active().size() == 1,
		"NEGATIVE CONTROL: a live event survives repeated prunes")

	at.queue_free()
	aw.queue_free()

	print("")
	if _failures == 0:
		print("=== PROBE PASS ===")
		get_tree().quit(0)
	else:
		push_error("WORLD ROSTERS: %d assertion(s) failed." % _failures)
		print("=== PROBE FAIL (%d) ===" % _failures)
		get_tree().quit(1)


func _seed_flight(at: AirTraffic, age_ms: int) -> void:
	at.get_in_flight().append({
		"id": 1, "kind": "c130", "node": null,
		"route": [Vector3.ZERO, Vector3(100, 0, 0)], "pos": Vector3.ZERO,
		"phase": "flying", "born_ms": Time.get_ticks_msec() - age_ms,
	})


func _seed_event(aw: AmbientWar, life_s: float, age_ms: int) -> void:
	aw.get_active().append({
		"kind": "artillery", "position": Vector3.ZERO, "lifetime_s": life_s,
		"born_ms": Time.get_ticks_msec() - age_ms, "node": null,
	})


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
