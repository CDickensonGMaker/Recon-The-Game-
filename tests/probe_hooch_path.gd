## probe_hooch_path.gd - item 22, "the squad cannot path into the hooches".
## Nothing has ever asked the nav map whether a hooch interior is reachable.
## This does: it stands the real firebase, bakes the real firebase region, then
## for every hooch doorway (the door_hooch_leaf_l/_r pairs) asks the nav map for
## a path from 6m outside the door to the nearest work_hooch_* post inside.
## Run: godot --headless --path . res://tests/probe_hooch_path.tscn -- --test-save
extends Node

const SEED_VAL: int = 4242
const OUTSIDE_M: float = 6.0
const ARRIVE_M: float = 1.5

var _failures: int = 0
var _leaf_gap: float = 0.0
var _leaf_min: float = INF
var _leaf_max: float = 0.0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _run() -> void:
	print("=== HOOCH PATH PROBE (item 22) ===")
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 240.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		_fail("world timeout")
		_finish(world)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
		world.vegetation_manager, world)
	var centre: Vector3 = planner.find_site(rng, 120.0)
	if centre == Vector3.ZERO:
		_fail("no site large enough for the firebase")
		_finish(world)
		return
	var site: Dictionary = planner.place_firebase_main(centre)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var root: Node3D = (site.nodes as Array)[0] as Node3D
	var doors: Array[Vector3] = []
	var posts: Array[Vector3] = []
	_collect(root, doors, posts)
	print("[PROBE] %d hooch door pairs, %d work_hooch posts" % [doors.size(), posts.size()])
	if doors.is_empty() or posts.is_empty():
		_fail("no hooch doorways or no interior posts found in the firebase GLB - probe blind")
		_finish(world)
		return

	var baker := NavBaker.new()
	world.add_child(baker)
	baker.setup(world.terrain_manager)
	baker.queue_sites([site], [])
	var waited: float = 0.0
	while baker.regions_live == 0 and waited < 120.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if baker.regions_live == 0:
		_fail("NavBaker produced no firebase region in 120s")
		_finish(world)
		return
	var map: RID = world.get_world_3d().navigation_map
	for i in range(30):
		NavigationServer3D.map_force_update(map)
		await get_tree().physics_frame
	print("[PROBE] regions on map: %d" % NavigationServer3D.map_get_regions(map).size())

	var reached: int = 0
	var tested: int = 0
	var skipped: int = 0
	for d in doors:
		var post: Vector3 = _nearest(posts, d)
		if post == Vector3.INF:
			continue
		var away: Vector3 = d - post
		away.y = 0.0
		if away.length() < 0.5:
			continue
		var outside: Vector3 = d + away.normalized() * OUTSIDE_M
		outside.y = world.floor_y(outside)
		var inside: Vector3 = post
		inside.y = world.floor_y(post)
		var o_pre: Vector3 = NavigationServer3D.map_get_closest_point(map, outside)
		if Vector2(o_pre.x - outside.x, o_pre.z - outside.z).length() > 1.0:
			# The probe's own 6m-out point landed off the mesh (inside a neighbouring
			# structure or on a parapet). Nothing to conclude about the doorway.
			skipped += 1
			print("[PROBE] door %s SKIPPED - the 6m-out start point is itself %.2fm off the navmesh" % [
				str(Vector2(d.x, d.z).round()),
				Vector2(o_pre.x - outside.x, o_pre.z - outside.z).length()])
			continue
		tested += 1
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, outside, inside, true)
		var miss: float = INF
		if path.size() >= 2:
			var last: Vector3 = path[path.size() - 1]
			miss = Vector2(last.x - inside.x, last.z - inside.z).length()
		if miss <= ARRIVE_M:
			reached += 1
		var o_snap: Vector3 = NavigationServer3D.map_get_closest_point(map, outside)
		var i_snap: Vector3 = NavigationServer3D.map_get_closest_point(map, inside)
		print("[PROBE] door %s -> post %s : %d pts, ends %.2fm short (start off-mesh %.2fm, end off-mesh %.2fm)" % [
			str(Vector2(d.x, d.z).round()), str(Vector2(inside.x, inside.z).round()),
			path.size(), miss,
			Vector2(o_snap.x - outside.x, o_snap.z - outside.z).length(),
			Vector2(i_snap.x - inside.x, i_snap.z - inside.z).length()])
	print("[PROBE] %d of %d hooch interiors reachable (%d skipped: no valid start point)"
		% [reached, tested, skipped])
	_diagnose(world, map, doors, posts)
	if tested == 0:
		_fail("no doorway/post pair testable - probe blind")
	elif reached == 0:
		_fail("NOT ONE hooch interior is reachable on the navmesh (item 22 confirmed)")
	elif reached < tested:
		_fail("%d of %d hooch interiors unreachable" % [tested - reached, tested])
	_finish(world)


## When a leg fails, say WHY: is the interior floor missing from the navmesh, or
## is only the doorway pinched shut by the 0.5m agent erosion?
func _diagnose(world: GameWorld, map: RID, doors: Array[Vector3], posts: Array[Vector3]) -> void:
	var d: Vector3 = doors[0]
	var post: Vector3 = _nearest(posts, d)
	var gap: float = _leaf_gap
	print("[DIAG] doorway clear width between leaf pairs: min %.2fm max %.2fm (agent needs 2*%.2f=%.2fm)"
		% [_leaf_min, _leaf_max, NavBaker.AGENT_RADIUS, NavBaker.AGENT_RADIUS * 2.0])
	print("[DIAG] (first pair %.2fm)" % gap)
	# How far is the navmesh from the interior post, and from the doorway itself?
	var at_post: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(post.x, world.floor_y(post), post.z))
	var at_door: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(d.x, world.floor_y(d), d.z))
	print("[DIAG] nearest navmesh point to interior post: %.2fm away" % Vector2(at_post.x - post.x, at_post.z - post.z).length())
	print("[DIAG] nearest navmesh point to the doorway   : %.2fm away" % Vector2(at_door.x - d.x, at_door.z - d.z).length())
	# Transect: walk the threshold line and report the floor height and the
	# distance to the navmesh at each step. A STEP shows as a jump in floor_y;
	# a blocked doorway shows as a run of large navmesh distances.
	var inward: Vector3 = post - d
	inward.y = 0.0
	inward = inward.normalized()
	print("[DIAG] threshold transect (t=metres inward from the door midpoint):")
	var t: float = -3.0
	while t <= 3.01:
		var p: Vector3 = d + inward * t
		var fy: float = world.floor_y(Vector3(p.x, world.terrain_manager.get_height_at(p) + 2.5, p.z), 6.0)
		var np: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(p.x, fy, p.z))
		print("[DIAG]   t=%+.2f floor=%.2f  nav %.2fm away (dy %.2f)" % [
			t, fy, Vector2(np.x - p.x, np.z - p.z).length(), np.y - fy])
		t += 0.5
	# WHAT is standing in the doorway? Name every collider whose shape overlaps a
	# man-sized box at the threshold.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.8, 1.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, Vector3(d.x, world.floor_y(
		Vector3(d.x, world.terrain_manager.get_height_at(d) + 2.5, d.z), 6.0) + 0.9, d.z))
	var hits: Array[Dictionary] = space.intersect_shape(q, 32)
	print("[DIAG] %d collider(s) inside the doorway volume:" % hits.size())
	for h in hits:
		var col: Object = h.get("collider")
		var cn := col as Node
		if cn == null:
			continue
		var par: Node = cn.get_parent()
		print("[DIAG]   %s   (parent %s)" % [cn.name, "-" if par == null else par.name])
	# HEADROOM. filter_walkable_low_height_spans deletes any span with less than
	# agent_height of clearance - a low lintel makes a hole exactly this shape.
	print("[DIAG] headroom transect (ceiling above floor; nav agent_height needs %.2fm):" % NavBaker.AGENT_HEIGHT)
	var t2: float = -3.0
	while t2 <= 3.01:
		var p2: Vector3 = d + inward * t2
		var fy2: float = world.floor_y(Vector3(p2.x, world.terrain_manager.get_height_at(p2) + 2.5, p2.z), 6.0)
		var up := PhysicsRayQueryParameters3D.create(
			Vector3(p2.x, fy2 + 0.1, p2.z), Vector3(p2.x, fy2 + 8.0, p2.z))
		up.collision_mask = 1
		var h2: Dictionary = space.intersect_ray(up)
		var head: float = 99.0
		var who: String = "open sky"
		if not h2.is_empty():
			head = (h2.position as Vector3).y - fy2
			var cc: Object = h2.get("collider")
			who = (cc as Node).name if cc is Node else "?"
		print("[DIAG]   t=%+.2f headroom %.2fm  (%s)" % [t2, head, who])
		t2 += 0.5


func _collect(root: Node, doors: Array[Vector3], posts: Array[Vector3]) -> void:
	var stack: Array[Node] = [root]
	var leaf_l: Array[Vector3] = []
	var leaf_r: Array[Vector3] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var n3 := n as Node3D
		if n3 == null:
			continue
		var nm: String = String(n.name)
		if nm.begins_with(ScreenDoor.LEAF_L):
			leaf_l.append(n3.global_position)
		elif nm.begins_with(ScreenDoor.LEAF_R):
			leaf_r.append(n3.global_position)
		elif nm.begins_with("work_hooch"):
			posts.append(n3.global_position)
	# One doorway per leaf pair: the midpoint of the two leaves.
	for l in leaf_l:
		var r: Vector3 = _nearest(leaf_r, l)
		if r != Vector3.INF and l.distance_to(r) < 4.0:
			var g: float = l.distance_to(r)
			if _leaf_gap == 0.0:
				_leaf_gap = g
			_leaf_min = minf(_leaf_min, g)
			_leaf_max = maxf(_leaf_max, g)
			doors.append((l + r) * 0.5)


func _nearest(pool: Array[Vector3], to: Vector3) -> Vector3:
	var best: Vector3 = Vector3.INF
	var bd: float = INF
	for p in pool:
		var d: float = p.distance_to(to)
		if d < bd:
			bd = d
			best = p
	return best


func _finish(world: Node = null) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	print("=== %s ===" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
