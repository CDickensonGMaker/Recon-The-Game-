## probe_destructible_placement.gd - CAN THE THINGS HE PLACES BE DESTROYED?
##
## Two findings, one mechanism (playtest 2026-08-28):
##   NEW - "village huts are indestructible". They were: SitePlanner.PLACED_DESTRUCTIBLE_KINDS
##         listed only weapons_cache, and the nha_* prefixes lived in FSB_STRUCTURE_KINDS,
##         which is walked ONLY by _wire_structure_destructibles on the firebase GLB.
##   Q2b - the surface weapons_cache. Its old proof (tests/probe_surface_cache.gd, deleted
##         with this file under the Fossil Law) asserted three dictionary lookups and never
##         placed a cache, never damaged one and never closed a sweep. A table test is not a
##         presence test.
##
## This probe places the real models through the real placement path, damages them with the
## real grammar, and drives the real sweep. Nothing here reads a dictionary.
##
##   godot --headless --path . res://tests/probe_destructible_placement.tscn
extends Node

const SEED_VAL: int = 4242
const VILLAGE_DIR: String = "res://assets/world/building models/structures/village/"
const CACHE_PATH: String = "res://assets/world/building models/structures/vc_nva/weapons_cache.glb"
## model file -> the kind it must come up as.
const EXPECTED: Dictionary = {
	"nha_tranh_01": "hut_thatch",
	"nha_san_01": "hut_timber",
	"nha_ruong_01": "hut_timber",
}
## Far enough apart that one blast's rubble and fire never reach the next.
const SPACING_M: float = 26.0

var _failures: int = 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _run() -> void:
	print("=== DESTRUCTIBLE PLACEMENT PROBE (village huts + Q2b) ===")
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
		_finish()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
		world.vegetation_manager, world)
	var centre: Vector3 = planner.find_site(rng, 60.0)
	if centre == Vector3.ZERO:
		_fail("no flat site found - the probe cannot place anything")
		_finish()
		return
	planner.clear_and_flatten(centre, 70.0)

	# ---- LEG 1: PLACEMENT. Does place_structure build a Destructible at all? ----
	var placed: Array[Dictionary] = []
	var slot: int = 0
	for model_name in EXPECTED:
		var pos: Vector3 = centre + Vector3(float(slot) * SPACING_M, 0.0, 0.0)
		slot += 1
		var node: Node3D = planner.place_structure(
			VILLAGE_DIR + str(model_name) + ".glb", pos, 0.0)
		if node == null:
			_fail("%s did not place at all" % model_name)
			continue
		var d := node as Destructible
		if d == null:
			_fail("%s placed as %s, NOT a Destructible - it cannot be blown up" % [
				model_name, node.get_class()])
			continue
		var want: String = str(EXPECTED[model_name])
		if d.kind != want:
			_fail("%s came up kind '%s', expected '%s'" % [model_name, d.kind, want])
			continue
		if d.hp != Destructible.hp_for(want):
			_fail("%s hp %d, expected %d from the one HP table" % [
				model_name, d.hp, Destructible.hp_for(want)])
			continue
		# An unregistered Destructible is one the blast bus can never reach
		# (combat_manager.gd:176-185 walks AgentRegistry props).
		if not _on_blast_bus(d):
			_fail("%s is a Destructible but is NOT on the blast bus" % model_name)
			continue
		print("  %s -> Destructible kind=%s hp=%d, on the blast bus" % [model_name, d.kind, d.hp])
		placed.append({"name": model_name, "node": d})

	var cache_pos: Vector3 = centre + Vector3(float(slot) * SPACING_M, 0.0, 0.0)
	var cache_node: Node3D = planner.place_structure(CACHE_PATH, cache_pos, 0.0)
	var cache := cache_node as Destructible
	if cache == null:
		_fail("weapons_cache did not place as a Destructible")
	else:
		cache_pos = cache.global_position
		print("  weapons_cache -> Destructible kind=%s hp=%d" % [cache.kind, cache.hp])
	await get_tree().physics_frame

	# ---- LEG 2: THE DAMAGE GRAMMAR. Rifle fire must NOT demolish a building. ----
	# ADR-016 + destructible.gd:147 - only EXPLOSIVE brings a building down. If this leg
	# ever passes damage through, the huts became shootable-down and that is a worse bug
	# than indestructible ones.
	for p in placed:
		var d: Destructible = p["node"]
		var before: int = d.hp
		d.take_damage(999, Enums.DamageType.PHYSICAL, null, "BODY")
		if d.hp != before:
			_fail("%s lost hp to PHYSICAL damage (%d -> %d) - gunfire is demolishing buildings"
				% [str(p["name"]), before, d.hp])

	# ---- LEG 3: DESTRUCTION. A satchel-sized explosive must actually take it down. ----
	for p in placed:
		var d: Destructible = p["node"]
		d.take_damage(d.hp, Enums.DamageType.EXPLOSIVE, null, "BODY")
	Destructible.drain(16)
	await get_tree().physics_frame
	for p in placed:
		var d: Destructible = p["node"]
		if not is_instance_valid(d):
			continue
		if not d.is_destroyed():
			_fail("%s survived a lethal EXPLOSIVE hit" % str(p["name"]))
		else:
			print("  %s destroyed by explosive, ruin swapped" % str(p["name"]))

	# ---- LEG 4 (Q2b): BLOWING THE SURFACE STASH CLOSES A SWEEP. ----
	if cache != null and is_instance_valid(cache):
		await _sweep_leg(world, cache, cache_pos)

	_finish()


## Is this node on the blast bus the props loop walks?
func _on_blast_bus(d: Node) -> bool:
	for n in AgentRegistry.props:
		if n == d:
			return true
	return false


## Q2b end to end: the player walks to the cache, blows it, and the sweep closes.
## Uses the real FieldDirector - report_stash_cleared is reached only through the
## "mission_director" group lookup inside Destructible._do_destroy().
func _sweep_leg(world: GameWorld, cache: Destructible, cache_pos: Vector3) -> void:
	var fd := FieldDirector.new()
	add_child(fd)
	# setup(), not _ready(): the group join lives in FieldDirector.setup (field_director.gd:18).
	fd.setup(world)
	if not fd.is_in_group("mission_director"):
		_fail("FieldDirector did not join the 'mission_director' group - the destroy hook "
			+ "in destructible.gd looks it up by that group and would find nothing")
		return
	world.spawn_player_at(cache_pos, false)
	await get_tree().physics_frame
	if world.player == null:
		_fail("no player - the sweep poll needs one to measure arrival")
		return
	world.player.global_position = cache_pos
	fd.patrol_out = true
	fd._set_patrol_location({"pos": cache_pos, "kind": "village"})
	# First poll is the ARRIVAL baseline; nothing may finish before he is there.
	fd._poll_sweep()
	if fd._sweep_done:
		_fail("the sweep closed on arrival, before anything was cleared - the probe is blind")
		return
	cache.take_damage(cache.hp, Enums.DamageType.EXPLOSIVE, null, "BODY")
	Destructible.drain(4)
	await get_tree().physics_frame
	if not fd._sweep_stash_cleared:
		_fail("the cache blew up and the director never heard about it "
			+ "(report_stash_cleared was not reached)")
		return
	fd._poll_sweep()
	if not fd._sweep_done:
		_fail("the stash was reported cleared and the sweep still did not close")
	else:
		print("  weapons_cache blown -> report_stash_cleared -> sweep CLOSED")


func _finish() -> void:
	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
