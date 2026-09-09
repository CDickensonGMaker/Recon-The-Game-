## test_marker_navmesh.gd - A WORK POINT A MAN CANNOT STAND ON IS NOT A WORK POINT.
## ADR-041 §5 makes this BINDING for authored-site work; ADR-043 P1 is where it lands.
##
## THE LESSON IT MAKES MECHANICAL. The chow-hall fix that actually shipped (commit 8e1129c7)
## was NOT code - it was 16 of 48 markers moved in the source asset after somebody measured
## each one against the bake. The cook could not stand at his own stove, and nothing in the
## build said so. Hand-placed does not mean correct, and the tool ADR-043 authorises will
## make it far easier to place a marker somewhere no man can reach.
##
## It is also the guard against the way that failure hides: NavRouter.nearest_mesh_point
## (nav_router.gd:63-77) returns the point UNCHANGED when no baked region covers it, so an
## unreachable marker reads as "already on the mesh" to every caller. The clamp cannot tell
## you it failed. This probe asks the map directly.
##
## RATCHET, not a bar. OFF_MESH_BASELINE is what the compound measures today; it may only be
## driven DOWN. Raising it to make a red run green is the forbidden move - it is the same
## debt-register shape as tests/fossil_baseline.json, for the same reason.
##
## Run: godot --headless --path . res://tests/test_marker_navmesh.tscn
extends Node

const SEED_VAL: int = 4242
## The player capsule is r=0.40 (player.tscn:9-11). A marker further than this from a baked
## polygon is one a body cannot occupy without clipping the world.
const CLEARANCE_M: float = 1.0
## Measured 2026-09-09 on this compound. DRIVE IT DOWN, never up.
const OFF_MESH_BASELINE: int = 5

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
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

	# ADR-043 P1: nodes[0] is the COMPOUND wrapper. Asserting it here means the wrapper
	# cannot be quietly removed without this probe noticing.
	var compound: Node3D = (site.nodes as Array)[0] as Node3D
	if compound == null or String(compound.name) != "FirebaseCompound":
		_fail("site.nodes[0] is not the FirebaseCompound wrapper - ADR-043 P1 regressed")

	var baker := NavBaker.new()
	world.add_child(baker)
	baker.setup(world.terrain_manager)
	baker.queue_sites([site], [])
	var waited: float = 0.0
	while baker.regions_live == 0 and waited < 120.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if baker.regions_live == 0:
		_fail("NavBaker produced no firebase region in 120s - probe blind")
		_finish(world)
		return
	var map: RID = world.get_world_3d().navigation_map
	for _i in range(30):
		NavigationServer3D.map_force_update(map)
		await get_tree().physics_frame

	var plan: Dictionary = SitePlanner.fsb_garrison_plan(centre)
	var checked: int = 0
	var off: int = 0
	var worst: float = 0.0
	var worst_what: String = ""
	var by_type: Dictionary = {}

	for post_any in (plan.get("posts", []) as Array):
		var post: Dictionary = post_any
		var p: Vector3 = post.get("pos", Vector3.ZERO)
		# `role` is the raw work_<type>; `occupation` is what FSB_WORK_OCCUPATION maps it to.
		# Report the role when there is one - it names the marker in the asset, which is what
		# whoever has to move it needs.
		var label: String = str(post.get("role", post.get("occupation", "post")))
		p.y = world.floor_y(p)
		checked += 1
		var d: float = _off_mesh_by(map, p)
		if d > CLEARANCE_M:
			off += 1
			by_type[label] = int(by_type.get(label, 0)) + 1
			if d > worst:
				worst = d
				worst_what = "%s at %s" % [label, str(Vector2(p.x, p.z).round())]

	if checked == 0:
		# A green run over an empty set certifies nothing. This is the failure mode the
		# project has named repeatedly: a ceiling test is not a presence test.
		_fail("fsb_garrison_plan produced NO posts - probe measured nothing")

	var types: Array = by_type.keys()
	types.sort()
	for t in types:
		print("[MARKER NAV]   %s: %d off-mesh" % [String(t), int(by_type[t])])
	print("[MARKER NAV] %d post(s) checked, %d further than %.2fm from a baked polygon; worst %.2fm (%s)"
		% [checked, off, CLEARANCE_M, worst, worst_what if worst_what != "" else "none"])

	if off > OFF_MESH_BASELINE:
		_fail("%d off-mesh post(s), baseline is %d - a marker moved off walkable ground"
			% [off, OFF_MESH_BASELINE])
	_finish(world)


## How far this point is from the nearest baked polygon. Asks the map directly rather than
## going through NavRouter.nearest_mesh_point, which returns the point unchanged when no
## region covers it - i.e. it reports an unreachable marker as fine.
func _off_mesh_by(map: RID, p: Vector3) -> float:
	if not map.is_valid():
		return INF
	var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
	return Vector2(snapped.x - p.x, snapped.z - p.z).length()


func _finish(world: Node) -> void:
	if _failures == 0:
		print("test_marker_navmesh: PASS")
	else:
		print("test_marker_navmesh: %d FAILURE(S)" % _failures)
	if world != null and is_instance_valid(world):
		world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
