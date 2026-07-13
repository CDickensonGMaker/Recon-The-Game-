## probe_clear_area.gd - ONE GRENADE MUST NOT TURN THE JUNGLE INTO PALM TREES.
##
## Found by the TECHNICAL DIRECTOR in the war room, 2026-07-12. A live shipping bug:
##
##   vegetation_manager.clear_area() called clear_chunk_visuals() - which destroys the
##   authored patch MultiMeshes - and then ran _materialize_vegetation()
##   UNCONDITIONALLY. That is the LEGACY PROCEDURAL PALM PATH. It never re-ran
##   _patch_layer.generate_for_chunk().
##
##   So a single explosion converted a 256m chunk of the authored jungle - 23
##   hand-composed patches, Poisson-spaced, edge-overhung, palette-atlased, LOD-twinned
##   - into procedural palm trees. And it fires on every SitePlanner stamp, so every
##   LZ, firebase and outpost did it too.
##
## The tell is the NODE NAMES. The patch layer names its instances after the patch
## ("patch_tangle", "patch_canopy"...). The legacy path makes generic tree/grass
## MultiMeshes. So: blow a hole, then count what is standing.
##
##   godot --headless --path . res://tools/probe_clear_area.tscn
extends Node

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== CLEAR_AREA: does the jungle survive a grenade? ===\n")

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = 20260712
	world.spawn_player_on_ready = false
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 500:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  [FAIL] world never became ready")
		get_tree().quit(1)
		return

	var vm: Node = world.vegetation_manager
	if vm == null:
		print("  [FAIL] no vegetation manager")
		get_tree().quit(1)
		return

	var before_patch: int = _count_patch_mmis(vm)
	var before_legacy: int = _count_legacy_mmis(vm)
	print("  BEFORE:  %d authored-patch MultiMeshes   %d legacy tree/grass MultiMeshes" % [
		before_patch, before_legacy])
	_check("the world builds AUTHORED jungle to begin with", before_patch > 0,
		"%d patch instances" % before_patch)
	if before_patch == 0:
		# CONTROL GUARD. If there is no authored jungle to destroy, "it wasn't
		# destroyed" would pass for the wrong reason. (probe_penetration's lesson:
		# a green test that proves nothing is worse than a red one.)
		print("\n  *** ABORT: no authored patches exist, so this probe cannot prove anything.")
		print("      Every check below would be a FALSE PASS. ***")
		get_tree().quit(1)
		return

	# BOOM. A grenade-sized hole, right in the middle of the map.
	var mid := Vector3(640.0, 0.0, 640.0)
	var cleared: int = int(vm.clear_area(mid, 12.0, 256.0, world.terrain_manager.heightmap))
	await get_tree().process_frame
	await get_tree().process_frame

	var after_patch: int = _count_patch_mmis(vm)
	var after_legacy: int = _count_legacy_mmis(vm)
	print("  AFTER:   %d authored-patch MultiMeshes   %d legacy tree/grass MultiMeshes" % [
		after_patch, after_legacy])
	print("           (%d vegetation bundles cleared by the blast)" % cleared)
	print("")

	_check("the AUTHORED jungle is still standing after the blast", after_patch > 0,
		"%d -> %d patch instances" % [before_patch, after_patch])
	_check("*** IT DID NOT TURN INTO PROCEDURAL PALM TREES ***",
		after_legacy <= before_legacy,
		"legacy MMIs %d -> %d" % [before_legacy, after_legacy])
	_check("the chunk was genuinely rebuilt (not just left alone)", cleared > 0,
		"%d bundles cleared" % cleared)

	print("")
	if _fails == 0:
		print("*** THE JUNGLE SURVIVES. A grenade blows a hole in it, not a palm grove. ***")
	else:
		print("*** %d FAILURE(S) - one grenade still destroys the authored jungle ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## The patch layer names its MultiMeshInstances after the patch it stamped.
func _count_patch_mmis(vm: Node) -> int:
	var n: int = 0
	for c in _all_mmis(vm):
		if str(c.name).begins_with("patch_"):
			n += 1
	return n


## The legacy procedural path makes generic tree/grass MultiMeshes.
func _count_legacy_mmis(vm: Node) -> int:
	var n: int = 0
	for c in _all_mmis(vm):
		var nm := str(c.name).to_lower()
		if not nm.begins_with("patch_") and ("tree" in nm or "veg" in nm or "grass" in nm):
			n += 1
	return n


func _all_mmis(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in root.get_children():
		if c is MultiMeshInstance3D:
			out.append(c)
		out.append_array(_all_mmis(c))
	return out


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])
