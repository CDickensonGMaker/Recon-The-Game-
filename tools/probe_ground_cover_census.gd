## probe_ground_cover_census.gd - HOW MUCH OF THE CANOPY IS ANKLE-HIGH?
##
## The far ring draws real meshes now (his ruling: no cards), and the lever he ruled in is
## shortening the draw radius for the SMALL species only. Before any frame is measured, this
## says how much of the drawn world that lever can possibly reach: instances, triangles and
## MultiMesh nodes, split into GROUND COVER (rice, grass, ferns - the classes
## TreeCoverLayer.SMALL_PREFIXES cuts at SMALL_RING_M) and CANOPY (everything else).
##
## It is a census, not a frame: counts do not move with what else is running on the box, which
## is why it is worth taking even when a frame bench cannot be trusted.
##
##   godot --headless --path . res://tools/probe_ground_cover_census.tscn
extends Node

const SEED: int = 47225


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== GROUND COVER CENSUS (seed %d) ===\n" % SEED)

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = SEED
	world.spawn_player_on_ready = false
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 600:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  FAIL: world never became ready")
		get_tree().quit(1)
		return

	var tc: Node = world.vegetation_manager.get_node_or_null("TreeCoverLayer")
	if tc == null:
		print("  FAIL: no TreeCoverLayer")
		get_tree().quit(1)
		return
	var prefixes: Array = tc.get("SMALL_PREFIXES")
	var ring: float = float(tc.get("small_ring"))
	var view: float = float(tc.get("view_distance"))

	var per_species: Dictionary = {}
	var scatters: Dictionary = tc.get("_chunk_scatter")
	for coord: Vector2i in scatters:
		for e: Dictionary in (scatters[coord] as Array):
			var nm: String = String(e.get("name", ""))
			per_species[nm] = int(per_species.get(nm, 0)) + 1

	var small_n: int = 0
	var big_n: int = 0
	var small_tris: int = 0
	var big_tris: int = 0
	var names: Array = per_species.keys()
	names.sort()
	print("  %-22s %8s %8s  %s" % ["species", "planted", "tris ea", "class"])
	for nm: String in names:
		var n: int = per_species[nm]
		var mesh: Mesh = tc.call("solid_mesh_for", nm)
		# INDEX buffer, not vertex count / 3. The vertex form under-counts every indexed mesh
		# (rice_a reads 37 that way and 84 off the indices, which is what
		# tools/probe_far_ring_meshes.gd has always reported). Every triangle figure this probe
		# printed before 2026-09-09 is understated for that reason.
		var tris: int = 0
		if mesh != null:
			for si in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				@warning_ignore("integer_division")
				var t: int = (idx.size() / 3) if idx.size() > 0 					else ((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
				tris += t
		var is_small: bool = false
		for p: String in prefixes:
			if nm.begins_with(String(p)):
				is_small = true
				break
		if is_small:
			small_n += n
			small_tris += n * tris
		else:
			big_n += n
			big_tris += n * tris
		print("  %-22s %8d %8d  %s" % [nm, n, tris, "GROUND COVER" if is_small else "canopy"])

	var tot_n: int = small_n + big_n
	var tot_t: int = small_tris + big_tris
	print("")
	print("  ground cover : %7d instances (%.1f%%), %10d tris (%.1f%%)"
		% [small_n, 100.0 * float(small_n) / maxf(1.0, float(tot_n)),
			small_tris, 100.0 * float(small_tris) / maxf(1.0, float(tot_t))])
	print("  canopy       : %7d instances (%.1f%%), %10d tris (%.1f%%)"
		% [big_n, 100.0 * float(big_n) / maxf(1.0, float(tot_n)),
			big_tris, 100.0 * float(big_tris) / maxf(1.0, float(tot_t))])
	print("  the lever    : ground cover stops at %.0f m, canopy still draws to %.0f m."
		% [ring, view])
	print("  (Triangles are FULL detail. What the far ring actually submits is lower where the")
	print("   importer generated an LOD ladder - see tools/probe_far_ring_meshes.gd.)")
	get_tree().quit(0)
