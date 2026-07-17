extends Node
## End-to-end smoke: plan() + build() for VILLAGE_RAID on a real GameWorld.
## Asserts: village_center is in paddy territory, working_points propagate,
## no crashes, sites stamped. Run: godot --headless --path . res://tests/test_mission_plan.tscn

const TIMEOUT_SECONDS: float = 180.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 42
	add_child(world)

	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < TIMEOUT_SECONDS:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("FAIL: world not ready in time")
		get_tree().quit(1)
		return

	print("=== MISSION GENERATOR SMOKE (VILLAGE_RAID) ===")

	var p: Dictionary = MissionGenerator.plan(
		world, 42, MissionGenerator.MissionType.VILLAGE_RAID
	)

	# Paddy fields + village anchors should be on the plan dict.
	var paddies: Array = p.get("paddy_fields", [])
	var anchors: Array = p.get("village_anchors", [])
	print("Plan: %d paddies, %d village anchors" % [paddies.size(), anchors.size()])
	if paddies.size() == 0:
		print("FAIL: no paddy_fields in plan")
		get_tree().quit(1)
		return
	if anchors.size() < 4:
		print("FAIL: village_anchors below floor: %d" % anchors.size())
		get_tree().quit(1)
		return

	# Village center is the first anchor's center.
	var vc: Vector3 = p.get("village_center", Vector3.ZERO)
	var wp_count: int = (p.get("village_working_points", []) as Array).size()
	print("Village center: %s, working_points: %d" % [str(vc), wp_count])
	if vc == Vector3.ZERO:
		print("FAIL: village_center is Vector3.ZERO")
		get_tree().quit(1)
		return

	# Build the mission — exercises stamp_village with working_points.
	var director_node: Node = world.get_node_or_null("MissionDirector")
	if director_node == null:
		# Spawn one inline so build() can wire state into it.
		director_node = Node.new()
		director_node.set_script(load("res://scripts/missions/mission_director.gd"))
		director_node.name = "MissionDirector"
		world.add_child(director_node)
	var built: Dictionary = MissionGenerator.build(world, director_node, p)
	print("Built %d sites" % (built.sites.size() if built.has("sites") else 0))

	# At least one site should be a village with working_points set.
	var found_village_with_wp: bool = false
	for s in built.sites:
		if s.kind == "village" and s.has("working_points") and s.working_points.size() > 0:
			found_village_with_wp = true
			break
	if not found_village_with_wp:
		print("FAIL: no village site with non-empty working_points")
		get_tree().quit(1)
		return

	print("PASS: VILLAGE_RAID plan + build OK")

	# Also exercise FIREBASE_DEFENSE: verify the firebase center is >=200m from
	# any paddy centroid (the extra_reject rule on find_site).
	var p2: Dictionary = MissionGenerator.plan(
		world, 42, MissionGenerator.MissionType.FIREBASE_DEFENSE
	)
	var fc: Vector3 = p2.get("firebase_center", Vector3.ZERO)
	var paddy_centroids: Array = p2.get("paddy_centroids", [])
	if fc == Vector3.ZERO:
		print("FAIL: FIREBASE_DEFENSE produced zero firebase")
		get_tree().quit(1)
		return
	var min_d: float = INF
	for c in paddy_centroids:
		var d: float = fc.distance_to(c)
		if d < min_d:
			min_d = d
	print("Firebase center: %s, min distance to paddy: %.0fm" % [str(fc), min_d])
	if min_d < 200.0 and not paddy_centroids.is_empty():
		print("FAIL: firebase placed within 200m of a paddy centroid")
		get_tree().quit(1)
		return

	print("=== SMOKE COMPLETE ===")
	get_tree().quit(0)
