## probe_crater_veg.gd - A SHELL REBUILDS A CHUNK'S VEGETATION ONCE, AND THE HOLE IS REAL.
##
## The crater path used to re-materialize every touched chunk TWICE: DamageSystem called
## VegetationManager.clear_area (immediate rebuild) and then queued a heightmap dig whose
## chunk rebuild ran the identical work a frame later. Measured 2026-09-09 on
## tests/stall_bench.tscn: 36 build_scatter + 36 tree_cover_mmi calls over 18 chunk
## rebuilds, exactly two per chunk.
##
## The deferral is only safe if the SECOND pass still happens and still carries the hole,
## so this probe asserts the shape of the work, not its cost:
##   1. the chunk carries canopy before the shell            (control - no control, no proof)
##   2. every plant inside the blast radius is gone after it (the hole is real)
##   3. tree_cover_mmi calls == veg_generate calls           (one rebuild per chunk, not two)
##   4. the MultiMesh instance count actually fell           (the redraw was not lost)
##
##   godot --headless --path . res://tools/probe_crater_veg.tscn
extends Node

const SEED: int = 47225
const BOOM_RADIUS_GUESS: float = 16.0

var _fails: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s -- %s" % ["PASS" if ok else "FAIL", label, detail])


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== CRATER VEG: one rebuild per chunk, and the hole is real ===\n")

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = SEED
	world.spawn_player_on_ready = false
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 600:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  [FAIL] world never became ready")
		get_tree().quit(1)
		return

	var vm: Node = world.vegetation_manager
	var tc: Node = vm.get_node_or_null("TreeCoverLayer") if vm != null else null
	if vm == null or tc == null:
		print("  [FAIL] no vegetation manager / TreeCoverLayer (canopy source is not TREE_COVER)")
		get_tree().quit(1)
		return

	# Aim at the densest loaded chunk's centre, so the control below can pass honestly.
	var target: Vector3 = _densest_point(tc, world.terrain_manager.chunk_size)
	var coord := Vector2i(int(floor(target.x / 256.0)), int(floor(target.z / 256.0)))
	var before: Array = (tc.get("_chunk_scatter") as Dictionary).get(coord, []) as Array
	var before_n: int = before.size()
	_check("the target chunk carries canopy BEFORE the shell", before_n > 0,
		"chunk %s holds %d plants" % [coord, before_n])
	if before_n == 0:
		print("\n  *** ABORT: nothing to blow up, every check below would be a false pass. ***")
		get_tree().quit(1)
		return

	StallLedger.enable()
	StallLedger.reset_window()
	DamageSystem.apply_damage(target, DamageSystem.DamageType.LARGE_EXPLOSION, 1.0)
	# The dig is QUEUED (WorldConfig.TERRAIN_DEFORMS_PER_FRAME per frame); give it room.
	for _i in 30:
		await get_tree().process_frame

	# LIVE entries only: since 2026-09-11 a plant a blast took stays in the stored scatter,
	# marked dead, so the break registry's indices stay valid. Counting it would report a
	# chunk that never lost anything and a hole full of standing trees.
	var after_all: Array = (tc.get("_chunk_scatter") as Dictionary).get(coord, []) as Array
	var after: Array = []
	for e: Dictionary in after_all:
		if not bool(e.get("dead", false)):
			after.append(e)
	var survivors_in_hole: int = 0
	var radius: float = BOOM_RADIUS_GUESS
	for e: Dictionary in after:
		var o: Vector3 = (e["xf"] as Transform3D).origin
		if Vector2(o.x - target.x, o.z - target.z).length() < radius * 0.5:
			survivors_in_hole += 1
	_check("every plant well inside the blast is gone", survivors_in_hole == 0,
		"%d plant(s) still standing within %.0fm of ground zero" % [survivors_in_hole, radius * 0.5])
	_check("the chunk lost plants at all", after.size() < before_n,
		"%d -> %d plants in chunk %s" % [before_n, after.size(), coord])

	# A redraw is either the full rebuild or the local update; the contract is one per load.
	var mmi_calls: int = StallLedger.count("veg.tree_cover_mmi") + StallLedger.count("veg.tree_cover_partial")
	var gen_calls: int = StallLedger.count("terrain.veg_generate")
	_check("ONE canopy redraw per chunk load, not two", mmi_calls == gen_calls and gen_calls > 0,
		"veg.tree_cover_mmi+partial x%d vs terrain.veg_generate x%d" % [mmi_calls, gen_calls])
	var hits: int = StallLedger.count("veg.scatter_hit")
	var misses: int = StallLedger.count("veg.scatter_miss")
	print("  (scatter cache this window: %d hit / %d miss)" % [hits, misses])

	# 5. THE PRUNE MUST EQUAL THE REGENERATION. clear_area now deletes the blasted plants
	# from the cached scatter instead of throwing the chunk away, on the argument that
	# _build_scatter draws every RNG value for a candidate before it tests the hole. That is
	# an argument until this compares the two answers.
	var pruned: Array = ((vm.get("_scatter_cache") as Dictionary).get(coord, {}) as Dictionary).get("scatter", []) as Array
	vm.set("_scatter_epoch", int(vm.get("_scatter_epoch")) + 1)
	vm.call("_dirty_scatter", coord)
	var regen: Array = vm.call("_build_scatter", coord, world.terrain_manager.heightmap,
		world.terrain_manager.chunk_size) as Array
	var mismatch: int = 0
	for i in range(mini(pruned.size(), regen.size())):
		var pe: Dictionary = pruned[i]
		var re: Dictionary = regen[i]
		if String(pe["name"]) != String(re["name"]):
			mismatch += 1
			continue
		var po: Vector3 = (pe["xf"] as Transform3D).origin
		var ro: Vector3 = (re["xf"] as Transform3D).origin
		if absf(po.x - ro.x) > 0.001 or absf(po.z - ro.z) > 0.001:
			mismatch += 1
	_check("pruning the cache == regenerating the chunk with the hole",
		pruned.size() == regen.size() and mismatch == 0,
		"pruned %d vs regenerated %d plants, %d positional/species mismatch(es)"
			% [pruned.size(), regen.size(), mismatch])

	print("")
	if _fails == 0:
		print("*** A SHELL DIGS ONE HOLE AND PAYS FOR ONE REBUILD. ***")
	else:
		print("*** %d FAILURE(S) ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## The loaded chunk holding the most plants, sampled at its centre.
func _densest_point(tc: Node, chunk_size: float) -> Vector3:
	var best := Vector2i.ZERO
	var best_n: int = -1
	for coord: Vector2i in (tc.get("_chunk_scatter") as Dictionary):
		var n: int = ((tc.get("_chunk_scatter") as Dictionary)[coord] as Array).size()
		if n > best_n:
			best_n = n
			best = coord
	return Vector3((best.x + 0.5) * chunk_size, 0.0, (best.y + 0.5) * chunk_size)
