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

	# P0 2026-07-18 "a gate and a table": his eyes caught what node-exists checks
	# cannot. The base must STAND ON the ground - nearly every mesh above terrain,
	# >=30 poking near spawn, gate walkable from spawn, seat level.
	#
	# Measured as a RATIO of the model's own meshes, never a hardcoded count: the
	# old ">=500" was tuned to the v2 GLB's 678 meshes, and the v3 re-export ships
	# 430 in total. Every one of them was above ground and the probe still called
	# the base buried. A re-export must not be able to fake this either way.
	if fsb != null:
		var tm: TerrainManager = flow.world.terrain_manager
		var spawn_p: Vector3 = flow.world.player.global_position
		var total_meshes: int = 0
		var total_above: int = 0
		var near_above: int = 0
		var mstack: Array[Node] = [fsb]
		while not mstack.is_empty():
			var mn: Node = mstack.pop_back()
			for mc in mn.get_children():
				mstack.append(mc)
			var mi := mn as MeshInstance3D
			if mi != null and mi.visible:
				total_meshes += 1
				var b: AABB = mi.global_transform * mi.get_aabb()
				if b.end.y > tm.get_height_at(mi.global_position) + 0.3:
					total_above += 1
					if Vector2(mi.global_position.x - spawn_p.x, mi.global_position.z - spawn_p.z).length() < 200.0:
						near_above += 1
		# A firebase that shrank to a handful of meshes is its own failure, so the
		# ratio is floored by an absolute sanity minimum.
		if total_meshes < 200:
			_fail("firebase carries only %d visible meshes - the model did not load" % total_meshes)
		elif float(total_above) / float(total_meshes) < 0.95:
			_fail("only %d of %d fsb meshes above terrain (want >=95%%) - the base is buried"
				% [total_above, total_meshes])
		if near_above < 30:
			_fail("only %d fsb meshes above terrain near spawn (want >=30)" % near_above)
		var gd: float = spawn_p.distance_to(flow.director.patrol_gate_pos)
		if gd > 150.0:
			_fail("gate %.0fm from spawn (want <=150) - player not inside the wire" % gd)
		var seat_delta: float = absf(tm.get_height_at(spawn_p) - fsb.global_position.y)
		if seat_delta > 2.5:
			_fail("spawn terrain %.1fm off the base seat - ground not flattened" % seat_delta)
		print("fsb stand-up: %d above terrain, %d near spawn, gate %.0fm" % [total_above, near_above, gd])

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
	# First signs fan across the gate's OUTWARD half-plane (ADR-029 amendment
	# 2026-07-18) - the inward compass is the player's own base.
	var out_v: Vector3 = p1.gate_out
	var out_ang: float = atan2(out_v.z, out_v.x)
	var sectors_covered: int = 0
	for q2 in range(4):
		var qa2: float = out_ang + deg_to_rad(-67.5 + 45.0 * float(q2))
		var best: float = 1.0e9
		for s in (p1.first_signs as Array):
			var sv: Vector3 = s
			if absf(angle_difference(atan2(sv.z - gate.z, sv.x - gate.x), qa2)) <= deg_to_rad(22.5) + 0.45:
				best = minf(best, sv.distance_to(gate))
		if best <= 380.0:
			sectors_covered += 1
	if sectors_covered < 3:
		_fail("only %d/4 outward sectors have a first sign (want >=3; a water sector may go without)" % sectors_covered)

	# THE WIRE IS LAW (council 2026-07-18): no build-time placement inside the
	# firebase. Craters must clear it by their own blast radius.
	var fc: Vector3 = p1.fsb_center
	var fsb_rect := Rect2(fc.x - SitePlanner.FSB_HALF.x, fc.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0)
	var crater_rect: Rect2 = fsb_rect.grow(MissionGenerator._crater_keepout_grow())
	for s2 in (p1.first_signs as Array):
		var sp: Vector3 = s2
		if crater_rect.has_point(Vector2(sp.x, sp.z)):
			_fail("first sign at %.0f,%.0f inside the crater keep-out - digs the base" % [sp.x, sp.z])
	var site_rect: Rect2 = fsb_rect.grow(SitePlanner.FSB_SITE_CLEARANCE)
	for loc2 in villages + camps:
		var lp: Vector3 = loc2
		if site_rect.has_point(Vector2(lp.x, lp.z)):
			_fail("site at %.0f,%.0f inside the wire keep-out" % [lp.x, lp.z])
	# The keep-out binds ROUTES too: the player's seat is 22m outside the wire
	# (site_planner.gd:504), and a waypoint there walks a patrol onto him before he
	# is on his feet (Fairness Law).
	var anchor_rng := RandomNumberGenerator.new()
	anchor_rng.seed = 31337 + 777
	var anchors: Array[Vector3] = MissionGenerator._patrol_anchors(flow.world, p1, anchor_rng)
	for a in anchors:
		if site_rect.has_point(Vector2(a.x, a.z)):
			_fail("patrol anchor at %.0f,%.0f inside the wire keep-out - routes onto the spawn seat" % [a.x, a.z])
	if anchors.size() < 3:
		_fail("only %d patrol anchors survived the keep-out (want >=3, else the circuit degrades to a dot)" % anchors.size())
	print("patrol anchors: %d" % anchors.size())

	# THE PLANNER'S OUTPUT IS PLACEMENT, not a discarded score. Every sited ambush
	# must appear as a real spawnable group at the planned position, drawn from its
	# camp's garrison, and must clear the same keep-out every other placer clears.
	var sited: Array = p1.ambush_sites
	var ambush_groups: Array = []
	for g in (p1.enemy_groups as Array):
		if str((g as Dictionary).get("tag", "")).begins_with("camp_ambush_"):
			ambush_groups.append(g)
	if sited.size() != ambush_groups.size():
		_fail("%d ambush sites planned but %d spawn groups placed - the planner's output is being dropped" % [
			sited.size(), ambush_groups.size()])
	for i in range(mini(sited.size(), ambush_groups.size())):
		var plan_s: Dictionary = sited[i]
		var grp: Dictionary = ambush_groups[i]
		var tp: Vector3 = plan_s.trigger_pos
		if (grp.pos as Vector3).distance_to(tp) > 0.01:
			_fail("ambush group %d spawns at %s, planner chose %s" % [i, str(grp.pos), str(tp)])
		if int(grp.count) != int(plan_s.soldiers):
			_fail("ambush group %d has %d men, planner sited %d" % [i, int(grp.count), int(plan_s.soldiers)])
		if int(grp.count) < AmbushPlanner.AMBUSH_SOLDIERS_MIN:
			_fail("ambush group %d is %d men - below the documented minimum of %d" % [
				i, int(grp.count), AmbushPlanner.AMBUSH_SOLDIERS_MIN])
		if site_rect.has_point(Vector2(tp.x, tp.z)):
			_fail("ambush site at %.0f,%.0f inside the wire keep-out - stages on the spawn seat" % [tp.x, tp.z])
	# The party comes OUT of the garrison: a camp may never be emptied to fill one.
	for g2 in (p1.enemy_groups as Array):
		var gd2: Dictionary = g2
		if str(gd2.get("tag", "")).begins_with("camp_garrison_") \
				and int(gd2.count) < MissionGenerator.AMBUSH_CAMP_FLOOR:
			_fail("camp garrison left with %d men - the ambush emptied the camp" % int(gd2.count))
	print("ambush siting: %d camps sited, %d groups placed" % [sited.size(), ambush_groups.size()])

	if (p1.first_signs as Array).size() < 3:
		_fail("only %d first signs planned (want >=3 across the outward fan)" % (p1.first_signs as Array).size())
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
	DirAccess.remove_absolute(SaveManager.save_dir + "/save_%d.sav" % SaveManager.AUTOSAVE_SLOT)
	CampaignState.reset_campaign()
	if _failures == 0:
		print("PASS: open patrol world - fsb_main, squad, bands, determinism")
	else:
		print("FAIL: %d patrol world failures" % _failures)
	get_tree().quit(_failures)
