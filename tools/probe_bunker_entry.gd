## probe_bunker_entry.gd - CAN A MAN GET INSIDE A BUNKER?
##
## His playtest, 2026-08-12: "there's bunkers that I placed along the berms that I cannot get
## into the side of - we need to fix how that padding works with the stairs".
##
## fb_bunker_steps joined COL_TRIMESH on 2026-08-12 so the staircase stopped being a sealed box
## hull, and the roof-cull stopped the roofs baking as walkable floor. Neither change was ever
## measured against the thing that matters: whether the navigation server will route a man from
## outside the bunker to the fire point INSIDE it.
##
## The 37 work_bunker markers are that fire point - 28 at fighting bunkers, 8 at MG bunkers
## (site_planner.gd FSB_WORK_OCCUPATION, "bunker" -> sentry). A marker the server cannot reach
## is a post no garrison man can ever stand, and the bunker reads as sealed.
##
##   godot --headless --path . res://tools/probe_bunker_entry.tscn
extends Node

## A route to a marker this far apart that returns under 2 points is no route.
const MIN_PATH_PTS: int = 2
## Where "outside" is: far enough out to be on open compound floor, not on the bunker itself.
const APPROACH_M: float = 14.0
## map_get_closest_point may land this far from the marker before we call it off-mesh. Nav cell
## is 0.25 and agent_radius erodes 0.5 from every wall, so a real interior polygon resolves well
## inside this.
const REACH_TOL_M: float = 1.6
## Lifted off the floor so the query is not fighting the ground plane.
const SAMPLE_UP_M: float = 0.4


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== BUNKER ENTRY ===\n")

	var scene: PackedScene = load("res://scenes/levels/demo_game.tscn") as PackedScene
	add_child(scene.instantiate())
	var spins: int = 0
	while spins < 400 and get_tree().get_nodes_in_group(&"nav_baker").is_empty():
		spins += 1
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(8.0).timeout

	var map: RID = get_viewport().world_3d.navigation_map
	if not map.is_valid():
		print("  [FAIL] no navigation map")
		get_tree().quit(1)
		return
	NavigationServer3D.map_force_update(map)
	await get_tree().physics_frame

	# The bunker posts, in world space, straight off the planner's own marker table.
	var posts: Array[Vector3] = []
	for entry_any in SitePlanner._fsb_work_markers:
		var e: Array = entry_any
		if str(e[1]) == "bunker":
			posts.append(e[0] as Vector3)
	if posts.is_empty():
		print("  [FAIL] no work_bunker markers - nothing to test")
		get_tree().quit(1)
		return

	# _fsb_work_markers is MODEL space. Every consumer adds `center - FSB_AABB_CENTER`
	# (site_planner.gd:1072), and FSB_AABB_CENTER is the origin, so the compound centre IS
	# the offset. The parapet rings the wire, so its centroid is that centre.
	var ring: Array = get_tree().get_nodes_in_group(&"fsb_parapet")
	if ring.is_empty():
		print("  [FAIL] no fsb_parapet members - cannot locate the compound")
		get_tree().quit(1)
		return
	var centre := Vector3.ZERO
	for d in ring:
		if d is Node3D and is_instance_valid(d):
			centre += (d as Node3D).global_position
	centre /= float(ring.size())
	for i in range(posts.size()):
		posts[i] = centre + posts[i]

	var off_mesh: int = 0
	var no_route: int = 0
	var reached: int = 0
	for i in range(posts.size()):
		var world_p: Vector3 = posts[i] + Vector3(0.0, SAMPLE_UP_M, 0.0)
		var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, world_p)
		var drift: float = Vector2(snapped.x - world_p.x, snapped.z - world_p.z).length()
		if drift > REACH_TOL_M:
			off_mesh += 1
			print("  post %2d (%7.1f,%7.1f) OFF-MESH   nearest polygon %.2fm away" % [
				i, world_p.x, world_p.z, drift])
			continue
		# Stand outside, on the far side from the compound centre, and ask for a route in.
		var out_dir: Vector3 = (world_p - centre)
		out_dir.y = 0.0
		if out_dir.length() < 0.01:
			out_dir = Vector3.FORWARD
		var outside: Vector3 = NavigationServer3D.map_get_closest_point(
			map, world_p + out_dir.normalized() * APPROACH_M)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, outside, snapped, true)
		if path.size() < MIN_PATH_PTS:
			no_route += 1
			print("  post %2d (%7.1f,%7.1f) NO ROUTE   on the mesh, but sealed from outside" % [
				i, world_p.x, world_p.z])
			continue
		reached += 1

	print("\n%d reachable, %d OFF-MESH, %d SEALED, of %d bunker fire points" % [
		reached, off_mesh, no_route, posts.size()])
	print("An OFF-MESH post has no navmesh under it at all - the interior never baked.")
	print("A SEALED post baked, but no route reaches it - the padding closed the doorway.")
	get_tree().quit(0 if off_mesh == 0 and no_route == 0 else 1)
