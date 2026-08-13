## probe_compound_nav.gd - IS THE COMPOUND AN ISLAND?
##
## PHASE B put the perimeter wall into the navmesh (geom 106 -> 186). Before that the wall
## did not exist to the mesh and men walked through it - including, unknowingly, through the
## gate. Four ALLY no-path warnings survive, all ~70m, both endpoints ON the mesh, and the
## server confirms no route: that is the signature of two disconnected islands.
##
## The hypothesis this tests: the wall is now solid to the mesh and the GATE is not walkable,
## so everything inside the wire is cut off from everything outside it.
##
##   godot --headless --path . res://tools/probe_compound_nav.tscn
extends Node

## A route between two points this far apart that returns under 2 points is no route.
const MIN_PATH_PTS: int = 2
## How far out from the wall to stand the "outside" samples.
const OUTSIDE_PAD_M: float = 40.0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== COMPOUND CONNECTIVITY ===\n")

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

	# REGION OVERLAP. _merge() folds overlapping boxes together for exactly one reason,
	# stated at nav_baker.gd:167-169: two overlapping, non-coincident regions produce NO
	# edge connections and a path between them cannot exist. The firebase is deliberately
	# kept OUT of that merge, so it is the one box that can still overlap another.
	print("baked regions: %d" % NavBaker._live_boxes.size())
	for i in range(NavBaker._live_boxes.size()):
		var b: AABB = NavBaker._live_boxes[i]
		print("  %d: x %.0f..%.0f  z %.0f..%.0f" % [i, b.position.x, b.position.x + b.size.x,
			b.position.z, b.position.z + b.size.z])
	var overlaps: int = 0
	for i in range(NavBaker._live_boxes.size()):
		for j in range(i + 1, NavBaker._live_boxes.size()):
			var a: AABB = NavBaker._live_boxes[i]
			var c: AABB = NavBaker._live_boxes[j]
			if a.position.x < c.position.x + c.size.x \
					and c.position.x < a.position.x + a.size.x \
					and a.position.z < c.position.z + c.size.z \
					and c.position.z < a.position.z + a.size.z:
				overlaps += 1
				print("  OVERLAP %d x %d - no edge connections between them" % [i, j])
	print("region overlaps: %d" % overlaps)

	# The parapet IS the perimeter, and it is already a group.
	var wall: Array[Vector3] = []
	for d in get_tree().get_nodes_in_group(&"fsb_parapet"):
		if d is Node3D and is_instance_valid(d):
			wall.append((d as Node3D).global_position)
	if wall.is_empty():
		print("  [FAIL] no fsb_parapet members - the perimeter never wired")
		get_tree().quit(1)
		return

	var centre := Vector3.ZERO
	for p in wall:
		centre += p
	centre /= float(wall.size())
	var radius: float = 0.0
	for p in wall:
		radius = maxf(radius, Vector2(p.x - centre.x, p.z - centre.z).length())
	print("perimeter: %d segments, centre (%.0f, %.0f), radius %.0fm\n" % [
		wall.size(), centre.x, centre.z, radius])

	var inside: Vector3 = NavigationServer3D.map_get_closest_point(map, centre)
	print("  %-12s %-22s %-9s %s" % ["bearing", "outside sample", "path pts", "verdict"])
	var linked: int = 0
	var cut: int = 0
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var raw: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * (radius + OUTSIDE_PAD_M)
		var outside: Vector3 = NavigationServer3D.map_get_closest_point(map, raw)
		var pts: PackedVector3Array = NavigationServer3D.map_get_path(map, inside, outside, true)
		var ok: bool = pts.size() >= MIN_PATH_PTS
		if ok:
			linked += 1
		else:
			cut += 1
		print("  %-12.0f (%7.0f,%7.0f)  %-9d %s" % [rad_to_deg(a), outside.x, outside.z,
			pts.size(), "linked" if ok else "CUT"])

	print("\n%d of 8 bearings reach the compound interior; %d CUT" % [linked, cut])
	if cut == 0:
		print("The compound is NOT an island. The 4 surviving warnings are something else.")
	elif linked == 0:
		print("The compound is SEALED - no bearing reaches it. The gate is not walkable.")
	else:
		print("PARTIALLY cut: the mesh reaches some bearings and not others, which is a hole in")
		print("the perimeter rather than a gate defect.")
	get_tree().quit(0)
