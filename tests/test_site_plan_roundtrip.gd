## test_site_plan_roundtrip.gd - THE KIT'S ONE PATH, END TO END (ADR-043 §2).
##
## Writes a plan, reads it back off disk, stamps it into a real world, and asserts the parts
## are where the plan said and that the compound is the shape NavBaker needs. It is the probe
## that has to exist before any part master is authored, because the fossil law's objection to
## the kit in July was never about the parts - gen_firebase.py:1-13 refused to ship them as
## "24 files with one consumer". This proves the consumer works.
##
## What it deliberately does NOT assert: that any particular part exists. Only seven of the
## manifest's twenty-three families have a .glb today, and a probe that named one would go red
## on the art rather than on the code.
##
## Run: godot --headless --path . res://tests/test_site_plan_roundtrip.tscn
extends Node

const SEED_VAL: int = 4242
const PLAN_NAME: String = "_probe_roundtrip"
## Local placement is exact - a part that lands further than this from its planned offset means
## the transform chain is wrong, not that the ground moved.
const TOL_M: float = 0.01

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var reg: KitRegistry = KitRegistry.load_kit()
	var ids: Array[String] = reg.placeable_ids()
	print("[PLAN] kit knows %d part(s), %d placeable: %s"
		% [reg.parts.size(), ids.size(), ", ".join(ids)])
	if ids.is_empty():
		_fail("no placeable parts in the kit - the registry found no .glb beside the manifest")
		_finish(null)
		return

	# Stations are the half of the data model that a second war depends on, so assert the
	# manifest actually carries some. A registry that silently produced zero would let the
	# rest of this probe pass while the part contract was dead.
	var with_stations: int = 0
	for id in reg.parts.keys():
		if not (reg.stations_for(String(id)) as Array).is_empty():
			with_stations += 1
	print("[PLAN] %d part(s) carry work stations" % with_stations)
	if with_stations == 0:
		_fail("no part in the manifest carries a work station - the part contract is empty")

	var plan := SitePlan.new()
	plan.plan_name = PLAN_NAME
	plan.flatten_radius = 24.0
	plan.flatten_strength = 0.7
	plan.flatten_shoulder = 8.0
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0), Vector3(9.0, 0.0, -4.0), Vector3(-7.5, 0.0, 6.0)]
	for i in range(offsets.size()):
		plan.add_part(ids[i % ids.size()], offsets[i], float(i) * 45.0)
	if not plan.save():
		_fail("could not save the plan")
		_finish(null)
		return

	var reloaded: SitePlan = SitePlan.load_from(PLAN_NAME)
	if reloaded == null:
		_fail("could not read the plan back")
		_finish(null)
		return
	if reloaded.parts.size() != plan.parts.size():
		_fail("round-trip lost parts: wrote %d, read %d"
			% [plan.parts.size(), reloaded.parts.size()])
	if not is_equal_approx(reloaded.flatten_radius, plan.flatten_radius):
		_fail("round-trip lost the flatten profile")
	for i in range(mini(plan.parts.size(), reloaded.parts.size())):
		var a: Dictionary = plan.parts[i]
		var b: Dictionary = reloaded.parts[i]
		if str(a["id"]) != str(b["id"]):
			_fail("part %d id changed across the round-trip" % i)
		if (a["pos"] as Vector3).distance_to(b["pos"] as Vector3) > TOL_M:
			_fail("part %d moved across the round-trip" % i)

	# A plan naming a part the kit has no model for must be REFUSED, not half-stamped.
	var bad := SitePlan.new()
	bad.plan_name = "_probe_bad"
	bad.add_part("fb_part_that_does_not_exist", Vector3.ZERO)
	if bad.validate(reg) == "":
		_fail("validate() accepted a plan naming a part with no model")

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
	var centre: Vector3 = planner.find_site(rng, 40.0)
	if centre == Vector3.ZERO:
		_fail("no site found for the plan")
		_finish(world)
		return

	var site: Dictionary = planner.stamp_site_plan(reloaded, centre, reg)
	await get_tree().physics_frame
	if site.is_empty():
		_fail("stamp_site_plan returned nothing")
		_finish(world)
		return

	var nodes: Array = site.get("nodes", []) as Array
	if nodes.size() != 1:
		_fail("site.nodes has %d entries - NavBaker takes nodes[0] and needs exactly one root"
			% nodes.size())
		_finish(world)
		return
	var compound: Node3D = nodes[0] as Node3D
	if compound == null:
		_fail("site.nodes[0] is not a Node3D")
		_finish(world)
		return

	var seen: int = 0
	for child in compound.get_children():
		var part := child as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var want: Vector3 = (reloaded.parts[seen] as Dictionary)["pos"]
		if part.position.distance_to(want) > TOL_M:
			_fail("part %d ('%s') sits at %s, plan said %s"
				% [seen, str(part.get_meta("part_id")), part.position, want])
		seen += 1
	if seen != reloaded.parts.size():
		_fail("stamped %d part node(s), the plan has %d" % [seen, reloaded.parts.size()])

	# The compound must be SEATED, or every part is at world origin and the plan's local
	# offsets are the only thing keeping them near each other.
	if compound.global_position.distance_to(Vector3(centre.x, compound.global_position.y, centre.z)) > 1.0:
		_fail("the compound is not seated at the site centre")

	var stations: Array = site.get("stations", []) as Array
	print("[PLAN] site carries %d station(s) from part manifests" % stations.size())
	for st_any in stations:
		var st: Dictionary = st_any
		if str(st.get("type", "")) == "":
			_fail("a station arrived with no work_type")
			break

	_finish(world)


func _finish(world: Node) -> void:
	# The probe's own plan file is not content. Leaving it behind would put a fixture in
	# data/site_plans where the tool writes real ones.
	var p: String = SitePlan.path_for(PLAN_NAME)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if _failures == 0:
		print("test_site_plan_roundtrip: PASS")
	else:
		print("test_site_plan_roundtrip: %d FAILURE(S)" % _failures)
	if world != null and is_instance_valid(world):
		world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
