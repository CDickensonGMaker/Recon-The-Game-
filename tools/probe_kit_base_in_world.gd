## probe_kit_base_in_world.gd - IS THE KIT BASE ACTUALLY IN THE GAME? (ADR-043)
##
## Run: godot --headless --path . res://tools/probe_kit_base_in_world.tscn
##
## Until 2026-09-10 `SitePlanner.stamp_site_plan()` had ZERO callers under scripts/. Every
## caller was a probe or tools/kit_editor.gd. The kit could be authored, measured, photographed
## and walked in the tool, and none of it reached a world the player builds - which is exactly
## the "parked-but-built" deliverable ADR-043's mechanical test refuses.
##
## So this probe does not measure the stamp (tools/probe_firebase_site.gd already does, on a
## hill it picks itself). It measures the WIRE: plan a real patrol AO the way MissionGenerator
## plans one, build it the way the game builds it, and then go looking for the kit base in the
## finished world.
##
##   1. PLANNED    the AO carries a `site_plan` site, and it is deterministic.
##   2. KEEP-OUT   it is outside the main firebase's wire, not an annex of it.
##   3. BUILT      the compound exists in the scene tree with every part the plan named.
##   4. STEEL      the parts are on the blast bus with real collision shapes.
##   5. MEN        the posts the part manifests asked for became people, through Civilian.spawn.
extends Node

const SEED_VAL: int = 4242

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

	var plan_name: String = MissionGenerator.KIT_SITE_PLAN
	var sp: SitePlan = SitePlan.load_from(plan_name)
	if sp == null:
		_fail("no site plan '%s' on disk - the AO has nothing to stamp" % plan_name)
		_finish(world)
		return
	print("[KIT] plan '%s': %d part(s), pad r=%.0f" % [plan_name, sp.parts.size(),
		sp.flatten_radius])

	# 1. PLANNED, and deterministic. A site that moves between two plans of the same seed is a
	# world that cannot be reproduced (ADR-010), and every number below would describe a
	# different base each run.
	var p1: Dictionary = MissionGenerator.plan_patrol_world(world, SEED_VAL)
	var p2: Dictionary = MissionGenerator.plan_patrol_world(world, SEED_VAL)
	var s1: Dictionary = _kit_site(p1)
	var s2: Dictionary = _kit_site(p2)
	if s1.is_empty():
		_fail("the planned AO has no 'site_plan' site - stamp_site_plan is still unreachable "
			+ "from the game")
		_finish(world)
		return
	var c1: Vector3 = s1.get("center", Vector3.ZERO)
	var c2: Vector3 = s2.get("center", Vector3.ZERO)
	if c1 != c2:
		_fail("the kit site is not deterministic: %s vs %s" % [str(c1), str(c2)])
	print("[KIT] planned at %s (deterministic), plan '%s'" % [str(c1), str(s1.get("plan", ""))])

	# 2. KEEP-OUT. It is somebody else's base out in the AO, not an annex bolted to the wire.
	var fsb: Vector3 = p1.fsb_center
	var gap: float = Vector2(c1.x - fsb.x, c1.z - fsb.z).length()
	var wire: Rect2 = Rect2(fsb.x - SitePlanner.FSB_HALF.x, fsb.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0)
	print("[KIT] %.0f m from the main firebase centre" % gap)
	if wire.grow(SitePlanner.FSB_SITE_CLEARANCE).has_point(Vector2(c1.x, c1.z)):
		_fail("the kit base is inside the main firebase's keep-out")

	# 3. BUILT - through the SHIPPING build call, not a hand-rolled stamp.
	MissionGenerator.build_patrol_world(world, _director(world), p1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var compound: Node3D = _find_compound(world, "SitePlan_%s" % plan_name)
	if compound == null:
		_fail("no 'SitePlan_%s' node in the built world - the site planned and never stamped"
			% plan_name)
		_finish(world)
		return
	var parts: int = 0
	for child in compound.get_children():
		if (child as Node3D) != null and child.has_meta("part_id"):
			parts += 1
	print("[KIT] built: %d part node(s) under %s at %s"
		% [parts, compound.name, str(compound.global_position)])
	if parts != sp.parts.size():
		_fail("the plan names %d part(s), the world has %d" % [sp.parts.size(), parts])

	# The compound must be SEATED on the site, not left at world origin with the plan's local
	# offsets as the only thing holding it together.
	if Vector2(compound.global_position.x - c1.x, compound.global_position.z - c1.z).length() > 1.0:
		_fail("the compound is at %s, the site is at %s" % [str(compound.global_position), str(c1)])

	# 4. STEEL. ADR-042's bug class fails by DEFAULT and in the dangerous direction: an
	# unrecognised mesh is bulletproof, an unwired collider is walk-through, and neither raises
	# an error. Count what should be there rather than asking whether anything is.
	var reg: KitRegistry = KitRegistry.load_kit()
	var want: int = 0
	for entry_any in sp.parts:
		if reg.destructible_kind(str((entry_any as Dictionary)["id"])) != "":
			want += 1
	# SEARCH THE WORLD, NOT THE COMPOUND, and this is a lesson the probe learned the hard way:
	# its first run reported 0 of 80 on the blast bus while the stamp's own line said 80.
	# `_adopt_structure` ADOPTS the part's mesh onto a Destructible parented to the PLANNER'S
	# parent - the world - and empties the part node (site_planner.gd:2792, and the comment at
	# :3321 says so). A Destructible is a StaticBody3D that takes the mesh's own collider with
	# it; it was never going to be a child of the compound. Match by distance to the site.
	var found: int = 0
	var no_shape: int = 0
	var reach: float = maxf(sp.flatten_radius, 24.0) + 12.0
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var d3 := n as Node3D
		if not (n is Destructible) or d3 == null:
			continue
		if Vector2(d3.global_position.x - c1.x, d3.global_position.z - c1.z).length() > reach:
			continue
		found += 1
		var shapes: int = 0
		for c in n.get_children():
			if c is CollisionShape3D:
				shapes += 1
		if shapes == 0:
			no_shape += 1
	print("[KIT] steel: %d Destructible(s) of %d part(s) that declare a kind, %d with no shape"
		% [found, want, no_shape])
	if found < want:
		_fail("%d part(s) declare a destructible kind, only %d are on the blast bus - the rest "
			% [want, found] + "are invulnerable and nothing raised an error")
	if no_shape > 0:
		_fail("%d Destructible(s) have no collision shape - nothing can hit them" % no_shape)

	# 5. MEN. The part manifests' crew is the half of the contract that was wired to nothing
	# until this change; a base with walls and no soldiers is scenery.
	var pad: float = maxf(sp.flatten_radius, 24.0) + 12.0
	var garrison: int = 0
	for m_any in get_tree().get_nodes_in_group("firebase_garrison"):
		var m := m_any as Node3D
		if m == null:
			continue
		if Vector2(m.global_position.x - c1.x, m.global_position.z - c1.z).length() <= pad:
			garrison += 1
	var any_crew: bool = false
	for entry_any in sp.parts:
		if not reg.crew_for(str((entry_any as Dictionary)["id"])).is_empty():
			any_crew = true
			break
	print("[KIT] men: %d garrison body/bodies within %.0f m of the kit base" % [garrison, pad])
	if any_crew and garrison == 0:
		_fail("parts in this plan declare crew and NOBODY stands at the kit base")

	_finish(world)


func _kit_site(p: Dictionary) -> Dictionary:
	for s_any in (p.get("sites", []) as Array):
		var s: Dictionary = s_any
		if str(s.get("kind", "")) == "site_plan":
			return s
	return {}


## build_patrol_world writes mission state onto a director. The probe supplies the one the
## world already carries where there is one, so nothing downstream reads a half-built stub.
func _director(world: GameWorld) -> FieldDirector:
	var d: Node = world.get_node_or_null("FieldDirector")
	if d is FieldDirector:
		return d as FieldDirector
	var made := FieldDirector.new()
	made.name = "FieldDirector"
	made.world = world
	world.add_child(made)
	return made


func _find_compound(root: Node, want: String) -> Node3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == want:
			return n as Node3D
		for c in n.get_children():
			stack.append(c)
	return null


func _finish(world: Node) -> void:
	if _failures == 0:
		print("probe_kit_base_in_world: PASS")
	else:
		print("probe_kit_base_in_world: %d FAILURE(S)" % _failures)
	if world != null and is_instance_valid(world):
		world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
