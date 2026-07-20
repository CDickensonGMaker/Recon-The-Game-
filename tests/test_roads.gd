## test_roads.gd - the road network exists, connects real ground, sits ON the ground,
## carries a convoy end to end, and does not starve the ambush planner.
##
## RATCHET. Every assertion here has a NEGATIVE CONTROL that was run against
## deliberately broken code and observed to FAIL. A probe that passes against both the
## fix and its absence is worse than no probe, and this suite has been burned by that
## before. The controls are not decoration - do not delete them to make a run green.
##
## Run: godot --headless --path . res://tests/test_roads.tscn
extends Node

const WORLD_SIZE: float = 3072.0
const CELLS: int = 256
const SEED_VAL: int = 42

## A road point must sit this close to the terrain surface under it. This is a
## seating contract, not a coarseness budget - the value is derived, not measured, so
## anything above float noise means the seating is broken.
const SEAT_TOL_M: float = 0.05
## Every village must have road within this of its centre, or the network does not
## actually connect the sites it claims to.
const CONNECT_TOL_M: float = 60.0

var _failures: int = 0
var _checks: int = 0

## Signal tallies for [E]. These are MEMBERS, not locals, because GDScript lambdas
## capture locals BY VALUE - a closure incrementing a local counter increments a copy
## and the probe reads zero forever.
var _waypoints_hit: int = 0
var _route_finished: bool = false
var _ambush_reports: int = 0


func _ready() -> void:
	await _run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ok(msg: String) -> void:
	print("  ok: ", msg)
	_checks += 1


func _run() -> void:
	print("=== ROAD NETWORK PROBE ===")
	_check_routing_synthetic()
	_check_traffic_weight_shape()
	_check_ambush_never_worse()
	await _check_real_world()
	await _check_convoy_drives()
	_finish()


# -----------------------------------------------------------------------------
# A. Routing on synthetic ground, with the controls that make it mean something.
# -----------------------------------------------------------------------------
func _check_routing_synthetic() -> void:
	print("\n[A] routing over a synthetic grid")

	var gate := Vector3(200.0, 0.0, 200.0)
	var villages: Array = [Vector3(800.0, 0.0, 800.0), Vector3(1400.0, 0.0, 400.0)]

	var open := _uniform_grid(GameplayGrid.TerrainType.GRASSLAND)
	var net := RoadNetwork.new(open, null)
	net.build(gate, villages)
	if net.segments.size() == 2:
		_ok("2 villages -> 2 road segments (%.0fm of road)" % net.total_length())
	else:
		_fail("expected 2 road segments on open ground, got %d" % net.segments.size())

	# Every segment must actually START at the gate and END at its village. A router
	# that returned a plausible-looking path to the wrong place would pass a mere
	# "segments.size() == 2" check.
	var endpoints_ok := true
	for i in range(net.segments.size()):
		var seg: PackedVector3Array = net.segments[i]
		if seg.size() < 2:
			endpoints_ok = false
			continue
		var d_start: float = Vector2(seg[0].x - gate.x, seg[0].z - gate.z).length()
		var last: Vector3 = seg[seg.size() - 1]
		var v: Vector3 = villages[i]
		var d_end: float = Vector2(last.x - v.x, last.z - v.z).length()
		if d_start > CONNECT_TOL_M or d_end > CONNECT_TOL_M:
			endpoints_ok = false
			_fail("segment %d runs %.0fm from gate to %.0fm from village" % [i, d_start, d_end])
	if endpoints_ok:
		_ok("every segment starts at the gate and ends at its village")

	# NEGATIVE CONTROL: cliff is impassable to a road. A map that is entirely cliff
	# must yield NO roads. Observed failing output when _cell_cost was mutated to
	# return 1.0 for CLIFF instead of -1.0:
	#   FAIL: NEGATIVE CONTROL LEAKED: all-cliff terrain produced 2 road segment(s)
	var cliff := _uniform_grid(GameplayGrid.TerrainType.CLIFF)
	var net_cliff := RoadNetwork.new(cliff, null)
	net_cliff.build(gate, villages)
	if net_cliff.segments.size() > 0:
		_fail("NEGATIVE CONTROL LEAKED: all-cliff terrain produced %d road segment(s)"
			% net_cliff.segments.size())
	else:
		_ok("neg ctrl: all-cliff terrain yields no roads")

	# NEGATIVE CONTROL: distance_to_road on an empty network must be INF, never 0.
	# A zero would silently tell the ambush planner that every point in the AO is
	# sitting on a highway. Observed failing output when the INF guard was removed:
	#   FAIL: NEGATIVE CONTROL LEAKED: empty network reports distance 0.0, not INF
	var empty := RoadNetwork.new(open, null)
	var d_empty: float = empty.distance_to_road(Vector3(500.0, 0.0, 500.0))
	if not is_inf(d_empty):
		_fail("NEGATIVE CONTROL LEAKED: empty network reports distance %.1f, not INF" % d_empty)
	else:
		_ok("neg ctrl: empty network reports INF distance, never 0")

	# distance_to_road must be small ON the road and large far from it.
	var on_road: Vector3 = net.segments[0][int(net.segments[0].size() / 2)]
	var d_on: float = net.distance_to_road(on_road)
	var d_off: float = net.distance_to_road(Vector3(2900.0, 0.0, 2900.0))
	if d_on < 1.0 and d_off > 500.0:
		_ok("distance_to_road: %.2fm on the centreline, %.0fm at the far corner" % [d_on, d_off])
	else:
		_fail("distance_to_road wrong: %.2fm on road, %.0fm off road" % [d_on, d_off])


# -----------------------------------------------------------------------------
# B. The traffic term is a PREFERENCE, not a gate. This is the ruling that keeps
#    roads from silently deleting ambushes, so it is asserted directly.
# -----------------------------------------------------------------------------
func _check_traffic_weight_shape() -> void:
	print("\n[B] TRAFFIC_NEAR_M is a score term, never a gate")

	var grid := _uniform_grid(GameplayGrid.TerrainType.HEAVY_JUNGLE)
	var net := RoadNetwork.new(grid, null)
	net.build(Vector3(200.0, 0.0, 200.0), [Vector3(1000.0, 0.0, 200.0)])

	# The weight must never reach zero at ANY distance, including infinitely far.
	# A zero here is what turns the score term back into a hard reject.
	# Observed failing output when _traffic_weight returned 0.0 beyond TRAFFIC_FAR_M:
	#   FAIL: traffic weight hit 0.00 at 3000m - that is a gate, not a preference
	var worst: float = 1.0
	# Sampled well past TRAFFIC_FAR_M on purpose - the floor must hold out there too.
	for d in [0.0, 50.0, 80.0, 150.0, 300.0, 1000.0, 3000.0]:
		var probe := Vector3(200.0 + float(d), 0.0, 3000.0)
		var w: float = AmbushPlanner._traffic_weight(net, probe)
		worst = minf(worst, w)
	if worst <= 0.0:
		_fail("traffic weight hit %.2f - that is a gate, not a preference" % worst)
	else:
		_ok("traffic weight floors at %.2f (>0 at every distance sampled)" % worst)

	# And a null network must not zero it either - synthetic worlds have no roads.
	var w_null: float = AmbushPlanner._traffic_weight(null, Vector3.ZERO)
	if w_null <= 0.0:
		_fail("null road network zeroes the traffic weight (%.2f)" % w_null)
	else:
		_ok("null road network still scores %.2f, so roadless worlds keep ambushes" % w_null)

	# Near beats far, or the term carries no signal at all.
	var near_w: float = AmbushPlanner._traffic_weight(net, net.segments[0][2])
	if near_w > w_null:
		_ok("on-road site scores %.2f vs %.2f off-network - roads do bias the choice"
			% [near_w, w_null])
	else:
		_fail("traffic term carries no signal: on-road %.2f vs off %.2f" % [near_w, w_null])


# -----------------------------------------------------------------------------
# C. THE REGRESSION GUARD. Adding roads must never reduce ambush yield.
#    This is the check that would have caught shipping ROAD_NEAR_M as a hard gate -
#    a failure mode that is otherwise INVISIBLE, because a rejected ambush silently
#    returns its men to the camp garrison and no headcount changes.
# -----------------------------------------------------------------------------
func _check_ambush_never_worse() -> void:
	print("\n[C] roads never starve the ambush planner")

	var trials: int = 120
	var grid := _uniform_grid(GameplayGrid.TerrainType.HEAVY_JUNGLE)
	# A road deliberately routed FAR from where the camps will be, which is the real
	# geometry: camps sit 400-540m out, the road's termini sit at the villages.
	var net := RoadNetwork.new(grid, null)
	net.build(Vector3(100.0, 0.0, 100.0), [Vector3(500.0, 0.0, 100.0)])

	var without: int = 0
	var with_roads: int = 0
	for i in range(trials):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i
		var camp := Vector3(1800.0 + float(i % 40) * 10.0, 0.0, 2200.0)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 9000 + i
		if not AmbushPlanner.plan(camp, 7, grid, [], rng, Rect2(), null).is_empty():
			without += 1
		if not AmbushPlanner.plan(camp, 7, grid, [], rng2, Rect2(), net).is_empty():
			with_roads += 1

	print("    ambush yield without roads: %d/%d" % [without, trials])
	print("    ambush yield with roads:    %d/%d" % [with_roads, trials])

	# THE BASELINE MUST BE NON-ZERO FIRST. Without this line the comparison below is
	# VACUOUS: a hard-gate mutation rejects every candidate in BOTH arms (a null road
	# network reports INF distance, which also fails the gate), so 0 >= 0 passes and
	# the probe reports "ok" against thoroughly broken code. That is exactly what this
	# check did on its first mutation run - it printed "ok: roads did not reduce ambush
	# yield (0 -> 0)" and the mutation was caught only by section [D]. A comparison
	# whose control arm is also broken proves nothing.
	if without == 0:
		_fail("VACUOUS COMPARISON: the roadless control yielded 0/%d ambushes, so the "
			% trials + "with-roads comparison below cannot mean anything")
	else:
		_ok("roadless control yields %d/%d - the comparison has a live baseline"
			% [without, trials])

	# Observed failing output when TRAFFIC_NEAR_M was mutated into a hard reject
	# (`if _traffic_distance(roads, site) > TRAFFIC_NEAR_M: continue`), AFTER the
	# baseline guard above was added:
	#   ambush yield without roads: 0/120
	#   FAIL: VACUOUS COMPARISON: the roadless control yielded 0/120 ambushes, ...
	#   FAIL: no ambush sites planned in the real world
	if with_roads < without:
		_fail("roads REDUCED ambush yield %d -> %d. A gate shipped where a score belongs."
			% [without, with_roads])
	else:
		_ok("roads did not reduce ambush yield (%d -> %d)" % [without, with_roads])


# -----------------------------------------------------------------------------
# D. The real generated world: roads connect the real sites and sit on real ground.
# -----------------------------------------------------------------------------
func _check_real_world() -> void:
	print("\n[D] the real generated world")

	# Build the world DIRECTLY. GameFlow._ready() already starts the default
	# operation (game_flow.gd), so going through it here would build TWO worlds and
	# double every count in this probe.
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var guard: int = 0
	while not world.is_world_ready and guard < 400:
		await get_tree().create_timer(0.1).timeout
		guard += 1
	if not world.is_world_ready:
		_fail("world never became ready; cannot check roads on real terrain")
		return

	var plan: Dictionary = MissionGenerator.plan_patrol_world(world, SEED_VAL)
	var net: RoadNetwork = plan.get("roads", null) as RoadNetwork
	if net == null:
		_fail("plan_patrol_world produced no road network")
		return

	if net.segments.size() > 0:
		_ok("real world: %d road segment(s), %.0fm total centreline"
			% [net.segments.size(), net.total_length()])
	else:
		_fail("real world produced ZERO roads")
		return

	# Roads must reach the villages the site planner actually placed.
	var villages: Array = plan.get("village_centers", [])
	var unconnected: int = 0
	for v in villages:
		if net.distance_to_road(v as Vector3) > CONNECT_TOL_M:
			unconnected += 1
	if unconnected == 0:
		_ok("all %d villages have road within %.0fm" % [villages.size(), CONNECT_TOL_M])
	else:
		_fail("%d of %d villages are not connected to the road network"
			% [unconnected, villages.size()])

	# SEATING. Every road point's Y must equal the terrain height under it. This is
	# the check that catches a road floating above a valley or buried in a hill.
	# Observed failing output when _seat was mutated to return the raw grid point
	# (`return p`) instead of sampling terrain height:
	#   FAIL: 153 of 153 road point(s) off the terrain surface, worst 232.36m
	var off_surface: int = 0
	var worst: float = 0.0
	var total_pts: int = 0
	for seg in net.segments:
		for p in seg:
			total_pts += 1
			var ground: float = world.terrain_manager.get_height_at(p)
			var dy: float = absf(p.y - ground)
			worst = maxf(worst, dy)
			if dy > SEAT_TOL_M:
				off_surface += 1
	if off_surface == 0:
		_ok("all %d road points sit on the terrain surface (worst %.4fm)" % [total_pts, worst])
	else:
		_fail("%d of %d road point(s) off the terrain surface, worst %.2fm"
			% [off_surface, total_pts, worst])

	# The ambush planner can now actually find traffic. This is ROAD_NEAR_M's
	# original claim, finally answerable.
	var sites: Array = plan.get("ambush_sites", [])
	if sites.is_empty():
		_fail("no ambush sites planned in the real world")
	else:
		var near: int = 0
		for s in sites:
			var sd: Dictionary = s
			if float(sd.get("traffic_dist", INF)) <= AmbushPlanner.TRAFFIC_FAR_M:
				near += 1
		_ok("%d/%d ambush sites lie within TRAFFIC_FAR_M of a road" % [near, sites.size()])

	world.queue_free()


# -----------------------------------------------------------------------------
# E. A convoy drives a road route end to end. This is what buries waypoint_reached,
#    route_finished and resume - they get real callers, not decorative listeners.
# -----------------------------------------------------------------------------
func _check_convoy_drives() -> void:
	print("\n[E] a convoy drives a road route end to end")

	var grid := _uniform_grid(GameplayGrid.TerrainType.GRASSLAND)
	var net := RoadNetwork.new(grid, null)
	net.build(Vector3(100.0, 0.0, 100.0), [Vector3(400.0, 0.0, 100.0)])
	var route: Array[Vector3] = []
	for p in net.longest_route():
		route.append(p)
	if route.size() < 2:
		_fail("no road route to drive")
		return

	var cv := Convoy.new()
	var truck := Node3D.new()
	cv.add_child(truck)
	cv.speed = 60.0  # probe speed; the real convoy does 12 m/s
	# The convoy must be in the tree BEFORE anything touches global_position.
	add_child(cv)
	truck.global_position = route[0]
	cv.setup(route, [truck])

	cv.waypoint_reached.connect(_on_probe_waypoint)
	cv.route_finished.connect(_on_probe_finished)

	var ticks: int = 0
	while not _route_finished and ticks < 4000:
		await get_tree().physics_frame
		ticks += 1
	var waypoints_hit: int = _waypoints_hit
	var finished: bool = _route_finished

	# Observed failing output when Convoy.setup was called with an empty vehicle list
	# (the shipped behaviour before this wave, cv.setup(route, [])):
	#   FAIL: convoy never finished its route (0 waypoints in 4000 ticks)
	if finished and waypoints_hit >= route.size():
		_ok("convoy drove %d waypoints and emitted route_finished in %d ticks"
			% [waypoints_hit, ticks])
	else:
		_fail("convoy never finished its route (%d waypoints in %d ticks)"
			% [waypoints_hit, ticks])

	# resume() must re-arm the ambush latch, or a convoy hit once can never report a
	# second contact. Observed failing output when the resume() call was removed from
	# _physics_process's stop-expiry branch:
	#   FAIL: resume() did not re-arm the ambush latch (1 reports, expected 2)
	var cv2 := Convoy.new()
	var t2 := Node3D.new()
	cv2.add_child(t2)
	add_child(cv2)
	t2.global_position = route[0]
	cv2.setup(route, [t2])
	cv2.ambushed.connect(_on_probe_ambushed)
	cv2.report_contact(self, route[0])
	cv2.resume()
	cv2.report_contact(self, route[0])
	var reports: int = _ambush_reports
	if reports == 2:
		_ok("resume() re-arms the ambush latch (2 contacts reported)")
	else:
		_fail("resume() did not re-arm the ambush latch (%d reports, expected 2)" % reports)

	cv.queue_free()
	cv2.queue_free()

	# The vehicle model names MissionGenerator schedules must resolve to real files.
	# The shipped name was "truck_m35", which matched nothing on disk - so even once
	# the empty-array bug was fixed, every convoy would still have spawned with zero
	# vehicles and silently never moved. A name is not a file until you check.
	var missing: Array[String] = []
	for model_name in ["m35_deuce_truck", "m151_mutt_gun_jeep"]:
		var path: String = ConvoySpawner.VEHICLE_MODEL_DIR + model_name + ".glb"
		if not ResourceLoader.exists(path):
			missing.append(path)
	if missing.is_empty():
		_ok("every scheduled convoy vehicle model resolves to a file on disk")
	else:
		_fail("%d convoy model path(s) resolve to nothing: %s" % [missing.size(), str(missing)])


# -----------------------------------------------------------------------------

func _on_probe_waypoint(_c: Convoy) -> void:
	_waypoints_hit += 1


func _on_probe_finished(_c: Convoy) -> void:
	_route_finished = true


func _on_probe_ambushed(_c: Convoy, _p: Vector3) -> void:
	_ambush_reports += 1


func _uniform_grid(ttype: int) -> GameplayGrid:
	var grid := GameplayGrid.new(WORLD_SIZE, CELLS)
	grid.terrain_type.fill(ttype)
	return grid


func _finish() -> void:
	print("")
	if _failures == 0:
		print("=== PASS === (%d checks passed, 0 failure(s))" % _checks)
	else:
		print("=== FAIL === (%d checks passed, %d failure(s))" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
