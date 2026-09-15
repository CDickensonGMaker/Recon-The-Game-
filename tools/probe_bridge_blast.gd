## probe_bridge_blast.gd - THE MONKEY BRIDGE BLOWS AND CUTS, headless.
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --bridge-probe --demo-map=1024 --test-save
##
## Attached to the live demo world by game_flow.gd under `--bridge-probe`. Holds the stand-to
## off, waits for every queued bake, then:
##   1. the F3 bridge is a Destructible of kind bridge_timber at Destructible.hp_for, on the
##      blast bus (AgentRegistry.props); the fallen log at F1 is scenery, not a Destructible;
##   2. HE: one M79 round (150, radius 6) at mid-span drops it - the deck meshes hide, a ray
##      down at mid-span hits the bed and no monkey_bridge hull, the bank->bank path through
##      F3 still lands (the ford is a wade; the deck was a second surface over it, now gone);
##   3. CUT: a spare bridge placed on dry ground takes M60 rounds through the real bullet
##      path until it dies; the count must be the arithmetic in Destructible.HP_FOR, and a
##      rifle round must not bite at all.
## Exit 1 on any failure.
extends Node

const SETTLE_S: float = 20.0
const BAKE_WAIT_S: float = 150.0
const M79_HE: int = 150
const M79_MIN: int = 22
const M79_RADIUS_M: float = 6.0
const M60: String = "res://data/weapons/m60.tres"
const M16: String = "res://data/weapons/m16a1.tres"
const BRIDGE: String = "res://assets/world/props/monkey_bridge.glb"
const MAX_ROUNDS: int = 40

var _fail: int = 0
var _director: FieldDirector = null


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("\n=== BRIDGE PROBE ===")
	var waited: float = 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if _director == null:
			_director = get_tree().get_first_node_in_group("mission_director") as FieldDirector
			if _director != null:
				_director.stand_to_held = true
	var book: BeatBook = get_tree().get_first_node_in_group("beat_book") as BeatBook
	_check(book != null and book.plan.has("stream"),
		"the plan carries a stream at map %.0f (the 512 slice has no bank for one)" % GameFlow.demo_map_size())
	if book == null or not book.plan.has("stream"):
		_finish()
		return
	var world: GameWorld = get_tree().get_first_node_in_group("game_world") as GameWorld
	var baker: NavBaker = NavBaker.instance(self)
	_check(world != null and world.gameplay_grid != null and baker != null, "a world, a grid and a baker")
	if world == null or world.gameplay_grid == null or baker == null:
		_finish()
		return
	waited = 0.0
	while waited < BAKE_WAIT_S and not (baker._queue.is_empty() and baker._job.is_empty()
			and baker._active_mesh == null and baker.regions_live > 0):
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	await get_tree().create_timer(2.0).timeout
	var stream: Dictionary = book.plan.stream
	var bridge: Destructible = _bridge_at(world, stream.fords["F3"])
	_check(bridge != null, "the F3 bridge placed as a Destructible")
	_log_is_scenery(world, stream.fords["F1"])
	if bridge == null:
		_finish()
		return
	_check(bridge.kind == "bridge_timber" and bridge.hp == Destructible.hp_for("bridge_timber"),
		"kind %s hp %d (table %d)" % [bridge.kind, bridge.hp, Destructible.hp_for("bridge_timber")])
	_check(bridge in AgentRegistry.props, "on the blast bus (AgentRegistry.props)")
	await _he_leg(world, baker, bridge, stream)
	await _cut_leg(world)
	_finish()


func _bridge_at(world: GameWorld, f: Vector3) -> Destructible:
	for n in world.find_children("*monkey_bridge*", "Node3D", true, false):
		var d := n as Destructible
		if d != null and Vector2(d.global_position.x - f.x, d.global_position.z - f.z).length() <= 12.0:
			return d
	return null


## The log is stamped by SitePlanner.place_prop - a bare Node3D with no body and no HP. A log
## lying in a ford opens nothing when it goes, so it is scenery on purpose.
func _log_is_scenery(world: GameWorld, f1: Vector3) -> void:
	var found: int = 0
	var destructible: int = 0
	for n in world.find_children("*fallen_log_a*", "Node3D", true, false):
		var p := n as Node3D
		if Vector2(p.global_position.x - f1.x, p.global_position.z - f1.z).length() > 6.0:
			continue
		found += 1
		if p is Destructible or p is StaticBody3D:
			destructible += 1
	_check(found >= 1 and destructible == 0,
		"fallen_log_a at F1 is scenery (%d node(s), %d body/Destructible)" % [found, destructible])


func _hull_under(world: GameWorld, at: Vector3) -> String:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 8.0, at + Vector3.DOWN * 4.0, 1))
	return "none" if hit.is_empty() else "%s at %.2f" % [str((hit.collider as Node).name), float(hit.position.y)]


func _meshes_visible(root: Node) -> int:
	var n: int = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			n += 1
	return n


## {"text": ..., "ok": lands within 2 m of the far bank and passes within 14 m of F3}.
func _cross_f3(world: GameWorld, stream: Dictionary) -> Dictionary:
	var map: RID = get_tree().root.get_world_3d().navigation_map
	var f3: Vector3 = stream.fords["F3"]
	var axis: Vector3 = stream.axis
	var a := Vector3(f3.x - axis.x * 25.0, 0.0, f3.z - axis.z * 25.0)
	var b := Vector3(f3.x + axis.x * 25.0, 0.0, f3.z + axis.z * 25.0)
	a.y = world.terrain_manager.get_height_at(a)
	b.y = world.terrain_manager.get_height_at(b)
	var path: PackedVector3Array = NavRouter.server_path(map, a, b)
	if path.size() < 2:
		return {"text": "no path", "ok": false}
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, b)
	var tail: float = Vector2(path[path.size() - 1].x - goal.x, path[path.size() - 1].z - goal.z).length()
	var nearest: float = INF
	for pt in path:
		nearest = minf(nearest, Vector2(pt.x - f3.x, pt.z - f3.z).length())
	return {"text": "%d point(s), lands %.1f m off the far bank, passes %.1f m from F3" % [path.size(), tail, nearest],
		"ok": tail <= 2.0 and nearest <= 14.0}


func _he_leg(world: GameWorld, baker: NavBaker, bridge: Destructible, stream: Dictionary) -> void:
	var mid: Vector3 = bridge.global_position + Vector3.UP * 1.2
	var before: String = _hull_under(world, bridge.global_position)
	_check(before.contains("monkey_bridge"), "before: the deck hull carries a man at mid-span (%s)" % before)
	print("  [BRIDGE] before: bank->bank through F3: %s" % str(_cross_f3(world, stream).text))
	var vis_before: int = _meshes_visible(bridge)
	CombatManager.apply_explosion_damage(mid, M79_HE, M79_MIN, M79_RADIUS_M, null)
	_check(bridge.hp <= 0, "one M79 HE (%d, r %.0f) at mid-span leaves hp %d" % [M79_HE, M79_RADIUS_M, bridge.hp])
	Destructible.drain(4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(bridge.is_destroyed(), "the bridge is destroyed")
	_check(bridge not in AgentRegistry.props, "off the blast bus")
	var vis_after: int = _meshes_visible(bridge)
	_check(vis_before >= 3 and vis_after == 0, "the deck, legs and rail vanish (%d visible -> %d)" % [vis_before, vis_after])
	var after: String = _hull_under(world, bridge.global_position)
	_check(not after.contains("monkey_bridge"), "after: a ray down at mid-span hits the bed, not a hull (%s)" % after)
	var waited: float = 0.0
	while waited < 60.0 and not (baker._dirty.is_empty() and baker._queue.is_empty()
			and baker._job.is_empty() and baker._active_mesh == null):
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	await get_tree().create_timer(2.0).timeout
	var cross: Dictionary = _cross_f3(world, stream)
	_check(bool(cross.ok), "after (%.0f s, breach re-bake %s): the wade still carries the crossing through F3 - the fords are the nav, the deck was a surface over one (%s)" % [
		waited, "landed" if baker._dirty.is_empty() else "PENDING", str(cross.text)])


## A spare bridge on dry ground, so the cut is measured against a whole one.
func _cut_leg(world: GameWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var site: Vector3 = planner.find_site(rng, 30.0)
	if site == Vector3.ZERO:
		_check(false, "a flat site for the spare bridge")
		return
	var spare := MissionGenerator.place_event_prop(world, BRIDGE, site, 0.0) as Destructible
	_check(spare != null, "a spare bridge placed at %.0f,%.0f" % [site.x, site.z])
	if spare == null:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var m60: WeaponData = load(M60) as WeaponData
	var m16: WeaponData = load(M16) as WeaponData
	var top: Vector3 = spare.global_position + Vector3.UP * 1.2
	var from: Vector3 = top + Vector3.UP * 5.0 + spare.global_transform.basis.x * 0.5
	var hp0: int = spare.hp
	# A rifle round must not bite: base 27 is under Destructible.GUNFIRE_CUT_FLOOR.
	for i in 3:
		CombatManager.bullets.fire(m16, self, from, (top - from).normalized(), 1, [], false, false)
		await get_tree().physics_frame
	await get_tree().physics_frame
	_check(spare.hp == hp0, "3 M16 rounds (base %d) bite nothing (hp %d -> %d)" % [m16.get_damage(), hp0, spare.hp])
	var rounds: int = 0
	while rounds < MAX_ROUNDS and spare.hp > 0:
		CombatManager.bullets.fire(m60, self, from, (top - from).normalized(), 1, [], false, false)
		rounds += 1
		await get_tree().physics_frame
		await get_tree().physics_frame
	var bite: int = maxi(1, int(float(m60.get_damage()) * Destructible.gunfire_bite("bridge_timber", m60.get_damage())))
	var want: int = int(ceil(float(hp0) / float(bite)))
	_check(spare.hp <= 0 and rounds == want,
		"M60 rounds to cut: %d (base %d x bite %.1f = %d each vs hp %d -> %d)" % [
			rounds, m60.get_damage(), Destructible.gunfire_bite("bridge_timber", m60.get_damage()), bite, hp0, want])
	Destructible.drain(4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(spare.is_destroyed() and _meshes_visible(spare) == 0, "the cut bridge is destroyed and gone")
	var under: String = _hull_under(world, spare.global_position)
	_check(not under.contains("monkey_bridge"), "no hull left under the cut bridge (%s)" % under)


func _finish() -> void:
	if _fail == 0:
		print("=== BRIDGE PROBE PASS ===")
	else:
		print("=== BRIDGE PROBE FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
