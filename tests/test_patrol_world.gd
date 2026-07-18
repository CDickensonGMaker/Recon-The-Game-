## test_patrol_world.gd - ADR-029 W1: the open patrol world end-to-end.
## GameFlow entry -> fsb_main placed via Caleb's markers, squad up, density
## bands honest, population deterministic per operation seed.
## Run: godot --headless --path . res://tests/test_patrol_world.tscn -- --test-save
extends Node

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	CampaignState.reset_campaign()
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(31337, "OPERATION TEST CASE")
	var waited := 0.0
	while waited < 150.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null \
				and flow.squad != null and flow.squad.members.size() > 0:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null or flow.world.player == null:
		_fail("patrol world/player never came up")
		_finish()
		return
	await get_tree().create_timer(1.0).timeout

	if SaveManager.context != "hub":
		_fail("context is '%s', wanted 'hub'" % SaveManager.context)
	if not SaveManager.has_save(SaveManager.AUTOSAVE_SLOT):
		_fail("patrol world entry did not autosave")

	var fsb: Node3D = null
	var stack: Array[Node] = [flow.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("model_name") and str(n.get_meta("model_name")) == "fsb_main":
			fsb = n as Node3D
			break
		for c in n.get_children():
			stack.append(c)
	if fsb == null:
		_fail("fsb_main not placed - Caleb's firebase IS the firebase (task 6b)")
	if flow.squad == null or flow.squad.members.size() != SquadSystem.SQUAD_SIZE:
		_fail("squad size wrong")

	# Bands + quadrants + determinism at plan level, on the same world.
	var p1: Dictionary = MissionGenerator.plan_patrol_world(flow.world, 31337)
	var p2: Dictionary = MissionGenerator.plan_patrol_world(flow.world, 31337)
	if _fingerprint(p1) != _fingerprint(p2):
		_fail("patrol plan not deterministic")
		print("A=" + _fingerprint(p1))
		print("B=" + _fingerprint(p2))
	var gate: Vector3 = p1.gate_pos
	var villages: Array = p1.village_centers
	var camps: Array = p1.camp_centers
	if villages.size() < 4:
		_fail("fewer than 4 villages planned")
	var close_village := false
	for v in villages:
		if (v as Vector3).distance_to(gate) <= 460.0:
			close_village = true
	if not close_village:
		_fail("no village within 460m of the gate (bored-player law)")
	var close_camp := false
	for cpos in camps:
		if (cpos as Vector3).distance_to(gate) <= 500.0:
			close_camp = true
	if not close_camp:
		_fail("no camp within 500m of the gate")
	for q in range(4):
		var qa: float = TAU * float(q) / 4.0 + TAU / 8.0
		var ok := false
		for loc in villages + camps:
			var l: Vector3 = loc
			if l.distance_to(gate) <= 520.0 \
					and absf(angle_difference(atan2(l.z - gate.z, l.x - gate.x), qa)) <= TAU / 8.0 + 0.45:
				ok = true
		if not ok:
			_fail("quadrant %d has no location within ~500m of the gate" % q)
	for q2 in range(4):
		var qa2: float = TAU * float(q2) / 4.0 + TAU / 8.0
		var best: float = 1.0e9
		for s in (p1.first_signs as Array):
			var sv: Vector3 = s
			if absf(angle_difference(atan2(sv.z - gate.z, sv.x - gate.x), qa2)) <= TAU / 8.0 + 0.45:
				best = minf(best, sv.distance_to(gate))
		if best > 320.0:
			_fail("quadrant %d first sign at %.0fm (want <=320)" % [q2, best])
	print("patrol world: %d villages, %d camps, gate %.0f,%.0f out %s" % [
		villages.size(), camps.size(), gate.x, gate.z, str(p1.gate_out)])
	_finish()


func _fingerprint(p: Dictionary) -> String:
	var parts: Array[String] = []
	for s in (p.sites as Array):
		var sd: Dictionary = s
		var c: Vector3 = sd.center
		parts.append("%s@%.1f,%.1f" % [str(sd.kind), c.x, c.z])
	parts.sort()
	return " | ".join(parts)


func _finish() -> void:
	DirAccess.remove_absolute("user://saves/save_%d.sav" % SaveManager.AUTOSAVE_SLOT)
	CampaignState.reset_campaign()
	if _failures == 0:
		print("PASS: open patrol world - fsb_main, squad, bands, determinism")
	else:
		print("FAIL: %d patrol world failures" % _failures)
	get_tree().quit(_failures)
