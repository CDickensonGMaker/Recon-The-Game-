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
	var routes: Array[Dictionary] = []
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
		routes.append({"i": i, "path": path})

	print("\n%d reachable, %d OFF-MESH, %d SEALED, of %d bunker fire points" % [
		reached, off_mesh, no_route, posts.size()])
	print("An OFF-MESH post has no navmesh under it at all - the interior never baked.")
	print("A SEALED post baked, but no route reaches it - the padding closed the doorway.")

	# PHYSICS PASS - nav reachability is not enterability (his playtest: "the AI
	# can get in and I can't"). Walk each route with the PLAYER'S capsule
	# (player.tscn: r 0.4, h 1.8) and name the first world collider that blocks
	# it. The test band starts 0.5m up so risers and steps he can climb do not
	# read as walls; anything solid in the torso/head band on a route the navmesh
	# calls open is the solid-but-nav-invisible class (NAV_IGNORE_PREFIXES).
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.3
	var blocked: int = 0
	for r in routes:
		var path: PackedVector3Array = r["path"]
		var hit_name: String = ""
		var hit_at := Vector3.ZERO
		for seg in range(path.size() - 1):
			var a: Vector3 = path[seg]
			var b: Vector3 = path[seg + 1]
			var steps: int = maxi(1, int(a.distance_to(b) / 0.25))
			for s in range(steps + 1):
				var p: Vector3 = a.lerp(b, float(s) / float(steps))
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = capsule
				q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0.0, 1.15, 0.0))
				q.collision_mask = 1
				var hits: Array[Dictionary] = space.intersect_shape(q, 8)
				for h in hits:
					var col := h["collider"] as Node
					if col == null:
						continue
					var nm: String = String(col.name)
					var parent_nm: String = String(col.get_parent().name) if col.get_parent() != null else "-"
					# The ground under his feet is not a blocker.
					if nm == "RaycastCollision" or parent_nm.begins_with("Chunk_"):
						continue
					hit_name = "%s (parent %s)" % [nm, parent_nm]
					hit_at = p
					break
				if hit_name != "":
					break
			if hit_name != "":
				break
		if hit_name != "":
			blocked += 1
			# Diagnose the block: where is the REAL ground under this point, and how
			# high does the blocking solid reach? ground >> path-point = the straight
			# chord between nav corners is cutting through a rising slope (a climb
			# route, possibly honest); a solid face reaching chest height above the
			# local ground = a wall the capsule genuinely cannot pass.
			var down := PhysicsRayQueryParameters3D.create(
				hit_at + Vector3(0, 6.0, 0), hit_at + Vector3(0, -6.0, 0), 1)
			var dh: Dictionary = space.intersect_ray(down)
			var ground_y: float = (dh.position as Vector3).y if dh else -999.0
			var up := PhysicsRayQueryParameters3D.create(
				Vector3(hit_at.x, ground_y + 0.05, hit_at.z),
				Vector3(hit_at.x, ground_y + 2.4, hit_at.z), 1)
			var uh: Dictionary = space.intersect_ray(up)
			var head_y: float = (uh.position as Vector3).y if uh else 999.0
			print("  post %2d CAPSULE-BLOCKED at (%7.1f,%7.1f) by %s | path_y %.2f ground_y %.2f (chord %.2fm under ground) | overhead solid at +%.2fm" % [
				int(r["i"]), hit_at.x, hit_at.z, hit_name, hit_at.y, ground_y,
				ground_y - hit_at.y, head_y - ground_y])
	print("\nPHYSICS: %d of %d nav-reachable routes pass the player's capsule, %d blocked" % [
		routes.size() - blocked, routes.size(), blocked])
	print("chord-under-ground >0.5m = the probe's straight line is inside a climbable rise;")
	print("overhead solid under 2.0m over TRUE ground = a real lintel/slab in the walk path.")

	# PASS 3 - CAN HE STAND IN THERE? (item 3, 2026-09-06)
	#
	# Passes 1 and 2 answer "is there a route" and "does a 1.3m torso band clear it".
	# Neither is what he reported. The player is a CharacterBody3D with a 0.4r x 1.8h
	# capsule centred 0.9m over his feet (scenes/player/player.tscn:9-20) and he stands
	# UPRIGHT by default - if the bunker's headroom is under 1.8m the doorway can be wide
	# open, the navmesh can be perfect, the AI can walk in, and he still cannot follow,
	# because his own capsule never fits. That is the exact shape of "the AI can get in
	# and I can't", and nothing in this repo had ever measured it.
	#
	# Reported both ways: the standing capsule AND the crouched one (player.gd
	# CROUCH_HEIGHT 0.9), so a bunker that takes him only on his knees is named as such
	# instead of reading as sealed.
	var stand_ok: int = 0
	var crouch_only: int = 0
	var no_fit: int = 0
	for i in range(posts.size()):
		var pw: Vector3 = posts[i]
		# START LOW. A ray dropped from post+3.0 lands on the bunker ROOF (measured
		# 2026-09-06: floor "fb_bunker_fighting_i at +2.87 over the post") and every
		# reading after it describes a man standing on the lid. The work marker is
		# authored AT the interior floor, so the ray must start inside the room.
		var floor_ray := PhysicsRayQueryParameters3D.create(
			pw + Vector3(0, FLOOR_RAY_UP_M, 0), pw + Vector3(0, -2.0, 0), 1)
		var fh: Dictionary = space.intersect_ray(floor_ray)
		if fh.is_empty():
			print("  post %2d STAND: no floor under the post at all" % i)
			no_fit += 1
			continue
		var feet: Vector3 = fh.position as Vector3
		# THE MARKER IS NOT WHERE HE STANDS. nav_router pulls a post inside a structure's
		# footprint onto the nearest mesh (nav_router.gd:40,129), so the AI does not
		# occupy the raw marker either - measuring exactly on it measures a point nobody
		# uses. Sweep the room instead: the nearest spot within SEARCH_M of the post that
		# takes the player's own capsule, on that spot's own floor. A bunker with no such
		# spot anywhere is a bunker he cannot be inside, whatever the navmesh says.
		var best_stand: float = -1.0
		var best_crouch: float = -1.0
		var blocker: String = _capsule_blocker(space, feet, 0.4, STAND_H)
		var step_n: int = int(SEARCH_M / SEARCH_STEP_M)
		for gx in range(-step_n, step_n + 1):
			for gz in range(-step_n, step_n + 1):
				var off := Vector3(float(gx) * SEARCH_STEP_M, 0.0, float(gz) * SEARCH_STEP_M)
				var r_flat: float = Vector2(off.x, off.z).length()
				if r_flat > SEARCH_M:
					continue
				var probe_at: Vector3 = pw + off
				var fr := PhysicsRayQueryParameters3D.create(
					probe_at + Vector3(0, FLOOR_RAY_UP_M, 0), probe_at + Vector3(0, -2.0, 0), 1)
				var h2: Dictionary = space.intersect_ray(fr)
				if h2.is_empty():
					continue
				var f2: Vector3 = h2.position as Vector3
				if _capsule_blocker(space, f2, 0.4, STAND_H) == "":
					if best_stand < 0.0 or r_flat < best_stand:
						best_stand = r_flat
				if _capsule_blocker(space, f2, 0.4, CROUCH_H) == "":
					if best_crouch < 0.0 or r_flat < best_crouch:
						best_crouch = r_flat
		if best_stand >= 0.0:
			stand_ok += 1
			if best_stand > 0.01:
				print("  post %2d STAND: upright %.2fm off the marker (the marker itself is %s)" % [
					i, best_stand, "clear" if blocker == "" else "inside " + blocker])
		elif best_crouch >= 0.0:
			crouch_only += 1
			print("  post %2d STAND: CROUCH ONLY inside %.1fm - nearest crouch spot %.2fm off, upright blocked by %s" % [
				i, SEARCH_M, best_crouch, blocker])
		else:
			no_fit += 1
			print("  post %2d STAND: NO FIT anywhere inside %.1fm of the post - blocked by %s" % [
				i, SEARCH_M, blocker])
	print("\nSTAND: %d of %d fire points take the player UPRIGHT, %d crouch-only, %d no fit" % [
		stand_ok, posts.size(), crouch_only, no_fit])

	get_tree().quit(0 if off_mesh == 0 and no_route == 0 and blocked == 0 and no_fit == 0 else 1)


## How far over the marker the floor ray starts. Under a fighting bunker's 2.87m lid and
## over any doorsill, so it can only find the floor the marker stands on.
const FLOOR_RAY_UP_M: float = 0.6
## How far around the marker to look for a spot the player's body actually fits.
const SEARCH_M: float = 1.5
const SEARCH_STEP_M: float = 0.25
## The player's own capsule, verbatim from scenes/player/player.tscn:9-20.
const STAND_H: float = 1.8
## player.gd:27 CROUCH_HEIGHT - what he shrinks to on ctrl.
const CROUCH_H: float = 0.9


## The name of the collider owner, for a diagnosis that can be acted on.
static func _owner_name(col: Variant) -> String:
	var n := col as Node
	if n == null:
		return "-"
	var par: Node = n.get_parent()
	return "%s/%s" % [String(par.name) if par != null else "-", String(n.name)]


## "" when a capsule of this height stands at these feet touching nothing; otherwise the
## name of the first world solid it hits.
## Layer 1 only - layer 2 is the player and the agents, and they are not the walls.
static func _capsule_blocker(space: PhysicsDirectSpaceState3D, feet: Vector3,
		radius: float, height: float) -> String:
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	# 2cm of daylight top and bottom: a capsule resting exactly on the floor reports a
	# contact with the floor, which is not a blocked bunker.
	cap.height = maxf(height - 0.04, radius * 2.0 + 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, height * 0.5 + 0.02, 0.0))
	q.collision_mask = 1
	var hits: Array[Dictionary] = space.intersect_shape(q, 1)
	if hits.is_empty():
		return ""
	return _owner_name(hits[0].get("collider"))
