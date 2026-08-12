## probe_interior_nav.gd - CAN A MAN WALK INSIDE?
##
## PHASE C made enterable buildings carve their real doorway geometry instead of a
## full-footprint box, and proved it by the bake's polygon count. A polygon count is a
## PROXY: it says the mesh changed, not that the inside of a hut is reachable. This asks
## the navigation server directly, which is the same question an ally's path asks.
##
## An enterable structure is one SitePlanner marked `nav_trimesh` (site_planner.gd:186),
## which it does from CollisionTable.STRUCTURES' authored `mesh: true`.
##
##   godot --headless --path . res://tools/probe_interior_nav.tscn
extends Node

## How far map_get_closest_point may land from the interior sample before we call it
## unreachable. Nav cell size is 0.25 and agent_radius erodes 0.5 from every wall, so a
## real interior polygon should resolve well inside this.
const REACH_TOL_M: float = 1.6
## Lifted off the floor so the query is not fighting the ground plane itself.
const SAMPLE_UP_M: float = 0.4


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== INTERIOR NAV ===\n")

	# The DEMO world is the one that stamps the firebase and its village kit, which is where
	# the enterable structures are. A bare patrol world at this seed stamps none.
	var scene: PackedScene = load("res://scenes/levels/demo_game.tscn") as PackedScene
	add_child(scene.instantiate())
	var spins: int = 0
	while spins < 400 and get_tree().get_nodes_in_group(&"nav_baker").is_empty():
		spins += 1
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(6.0).timeout
	# The bake is async; the region is assigned on a later frame than world_ready.
	await get_tree().create_timer(3.0).timeout

	var map: RID = get_viewport().world_3d.navigation_map
	if not map.is_valid():
		print("  [FAIL] no navigation map")
		get_tree().quit(1)
		return

	var bodies: Array[Node3D] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Node3D and (n as Node3D).has_meta("nav_trimesh"):
			bodies.append(n as Node3D)

	if bodies.is_empty():
		print("  [FAIL] no nav_trimesh structures in the world - either none were stamped")
		print("         at this seed, or PHASE C's meta is not being set")
		get_tree().quit(1)
		return

	print("enterable structures: %d\n" % bodies.size())
	print("  %-34s %-22s %-8s %s" % ["model", "interior", "d(nav)", "verdict"])

	var reachable: int = 0
	var sealed: int = 0
	for b in bodies:
		var name_s: String = String(b.get_meta("model_name", b.name))
		var inside: Vector3 = b.global_position + Vector3.UP * SAMPLE_UP_M
		var got: Vector3 = NavigationServer3D.map_get_closest_point(map, inside)
		var d: float = Vector2(got.x - inside.x, got.z - inside.z).length()
		var ok: bool = d <= REACH_TOL_M
		if ok:
			reachable += 1
		else:
			sealed += 1
		print("  %-34s (%6.1f,%6.1f)  %-8.2f %s" % [name_s.left(34), inside.x, inside.z, d,
			"reachable" if ok else "SEALED"])

	print("\n%d reachable, %d SEALED, of %d enterable structures" % [
		reachable, sealed, bodies.size()])
	if sealed > 0:
		print("A SEALED interior is one the player can walk into and no AI can follow him into.")
	get_tree().quit(1 if sealed > 0 else 0)
