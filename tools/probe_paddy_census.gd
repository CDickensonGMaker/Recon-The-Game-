## probe_paddy_census.gd - THE RICE, THE FIREBASE COLLAR, AND WHAT A BUSH CUT WOULD TAKE.
##
## Three questions, one world build, all answered in COUNTS rather than frames (this box
## cannot give an honest frame and the ledger already says so):
##   1. RICE. The rice-paddy zone planted nothing for the life of the project. How much of the
##      map is paddy, how wet and how flat it is, and what the row lattice now puts in it.
##   2. THE FIREBASE COLLAR. His ruling shrank the vegetation cut from a hard 140 m circle to
##      120 m plus a staggered feather, and thickened the apron. What grows there now.
##   3. THE BUSH RING. He ruled bushes stay at 350 m. The band table is kept anyway, so the
##      price of every F12 step is on the record instead of being re-argued from memory.
##
## TRIANGLES ARE COUNTED OFF THE INDEX BUFFER. tools/probe_ground_cover_census.gd divides the
## VERTEX array by three, which under-counts every indexed mesh - it reads rice_a as 37 tris
## where tools/probe_far_ring_meshes.gd, which reads indices, reads 84.
##
##   godot --headless --path . res://tools/probe_paddy_census.tscn -- --test-save
##   optional: --probe-seed=N --probe-map=512
extends Node

const SEED_DEMO: int = 29072026


func _ready() -> void:
	await get_tree().process_frame
	var seed_v: int = SEED_DEMO
	var map_v: float = 512.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--probe-seed="):
			seed_v = int(a.get_slice("=", 1))
		if a.begins_with("--probe-map="):
			map_v = float(a.get_slice("=", 1))
	print("\n=== PADDY / COLLAR / BUSH CENSUS (seed %d, map %.0f m) ===\n" % [seed_v, map_v])

	var world: GameWorld = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = seed_v
	world.spawn_player_on_ready = false
	world.map_size = map_v
	add_child(world)
	var spins: int = 0
	while not world.is_world_ready and spins < 900:
		spins += 1
		await get_tree().create_timer(0.1).timeout
	if not world.is_world_ready:
		print("  FAIL: world never became ready")
		get_tree().quit(1)
		return

	var vm: VegetationManager = world.vegetation_manager
	var tc: Node = vm.get_node_or_null("TreeCoverLayer")
	if tc == null:
		print("  FAIL: no TreeCoverLayer")
		get_tree().quit(1)
		return
	var cs: float = world.terrain_manager.chunk_size
	print("  map=%.0f chunk=%.0f bundle=%.1fm" % [world.map_size, cs, vm.bundle_meters])

	# ---------- zone census ----------
	var names := ["CLEAR", "RICE_PADDY", "GRASSLAND", "LIGHT_J", "MEDIUM_J", "HEAVY_J"]
	var counts := PackedInt32Array()
	counts.resize(8)
	var paddy_cells: Array[Vector3] = []
	var bpc: int = vm._bundles_per_chunk
	for coord: Vector2i in vm._chunk_terrain:
		var t: PackedByteArray = vm._chunk_terrain[coord]
		for i in t.size():
			counts[t[i]] = counts[t[i]] + 1
			if t[i] == 1:
				@warning_ignore("integer_division")
				var bz: int = i / bpc
				paddy_cells.append(Vector3(coord.x * cs + ((i % bpc) + 0.5) * vm.bundle_meters,
					0.0, coord.y * cs + (bz + 0.5) * vm.bundle_meters))
	var total: int = 0
	for c in counts:
		total += c
	var bm2: float = vm.bundle_meters * vm.bundle_meters
	print("\n  %-12s %8s %7s %12s" % ["zone", "bundles", "share", "area m2"])
	for i in names.size():
		print("  %-12s %8d %6.1f%% %12.0f" % [names[i], counts[i],
			100.0 * float(counts[i]) / maxf(1.0, float(total)), float(counts[i]) * bm2])

	# ---------- how wet, how flat ----------
	var wet: int = 0
	var depth_sum: float = 0.0
	var hm: Object = world.terrain_manager.heightmap
	var relief_sum: float = 0.0
	for p: Vector3 in paddy_cells:
		if world.water_system.is_water(p.x, p.z):
			wet += 1
			depth_sum += world.water_system.get_water_depth(p.x, p.z)
		var h0: float = hm.sample_world(p.x, p.z)
		var lo: float = h0
		var hi: float = h0
		for o: Vector2 in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
			var h: float = hm.sample_world(p.x + o.x, p.z + o.y)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		relief_sum += hi - lo
	print("  paddy bundles %d | standing water in %d (%.1f%%), mean depth %.2f m | mean relief over 8 m: %.2f m"
		% [paddy_cells.size(), wet, 100.0 * float(wet) / maxf(1.0, float(paddy_cells.size())),
			depth_sum / maxf(1.0, float(wet)), relief_sum / maxf(1.0, float(paddy_cells.size()))])

	# ---------- the firebase collar: clear + feather + apron, exactly as shipped ----------
	var fsb := Vector3(world.map_size * 0.5, 0.0, world.map_size * 0.5)
	fsb.y = world.terrain_manager.get_height_at(fsb)
	var before: Dictionary = _species_census(tc)
	var legacy: bool = OS.get_cmdline_user_args().has("--legacy-collar")
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, vm, world)
	var cut_r: float = 140.0 if legacy else float(SitePlanner.FSB_CLEAR_DISCS[0][1])
	var feath: float = 0.0 if legacy else SitePlanner.FSB_CLEAR_FEATHER
	print("\n  COLLAR MODE: %s (cut %.0f m, feather %.0f m, apron %s)"
		% ["LEGACY - the 140 m circle, no apron" if legacy else "SHIPPED", cut_r, feath,
			"off" if legacy else "on"])
	planner.clear_and_flatten(fsb, cut_r, feath)
	if legacy:
		vm.set_density_centers([])
	else:
		vm.set_density_centers([{"pos": fsb, "radius": MissionGenerator.FSB_APRON_RADIUS,
			"chance_floor": MissionGenerator.FSB_APRON_CHANCE,
			"count_boost": MissionGenerator.FSB_APRON_BOOST}])
	await get_tree().process_frame

	# ---------- what is planted now ----------
	var tris_of: Dictionary = {}
	var per_species: Dictionary = _species_census(tc)
	var nm_list: Array = per_species.keys()
	nm_list.sort()
	var rice_n: int = 0
	var rice_tris: int = 0
	for nm: String in nm_list:
		tris_of[nm] = _tris(tc.call("solid_mesh_for", nm) as Mesh)
		if nm.begins_with("rice_"):
			rice_n += int(per_species[nm])
			rice_tris += int(per_species[nm]) * int(tris_of[nm])
	print("\n  RICE PLANTED: %d clumps, %d tris at full detail (rice_a %d tris, rice_b %d tris - neither has an LOD ladder)"
		% [rice_n, rice_tris, int(tris_of.get("rice_a", 0)), int(tris_of.get("rice_b", 0))])
	print("  world plants before the collar pass: %d | after: %d"
		% [_sum(before), _sum(per_species)])
	# SEATING TRUTH: a clump must sit on the mud, or stand IN the water where the paddy is
	# flooded - never float over either. Measured against the same heightmap the scatter used.
	var seated: int = 0
	var in_water: int = 0
	var worst_air: float = 0.0
	var worst_sunk: float = 0.0
	for coord3: Vector2i in (tc.get("_chunk_scatter") as Dictionary):
		for e3: Dictionary in ((tc.get("_chunk_scatter") as Dictionary)[coord3] as Array):
			if not String(e3.get("name", "")).begins_with("rice_"):
				continue
			var o3: Vector3 = (e3["xf"] as Transform3D).origin
			var g: float = hm.sample_world(o3.x, o3.z)
			seated += 1
			if world.water_system.is_water(o3.x, o3.z):
				in_water += 1
			worst_air = maxf(worst_air, o3.y - g)
			worst_sunk = maxf(worst_sunk, g - o3.y)
	print("  seating: %d clumps checked, %d standing in water; worst above ground %.2f m, worst below %.2f m"
		% [seated, in_water, worst_air, worst_sunk])
	var mmi_rice: int = 0
	var mmi_all: int = 0
	for coord: Vector2i in (tc.get("_chunk_nodes") as Dictionary):
		for n in ((tc.get("_chunk_nodes") as Dictionary)[coord] as Array):
			mmi_all += 1
			if String((n as MultiMeshInstance3D).get_meta("species", "")).begins_with("rice_"):
				mmi_rice += 1
	print("  MultiMesh nodes (= draw calls, 1 surface each): %d total, %d of them rice"
		% [mmi_all, mmi_rice])

	# ---------- the collar, band by band ----------
	print("\n  FIREBASE COLLAR at %.0f,%.0f  (hard cut %.0f m, feather to %.0f m + %.0f m wobble)"
		% [fsb.x, fsb.z, cut_r, cut_r + feath, VegetationManager.FEATHER_WOBBLE_M])
	print("  %-13s %8s %10s %7s   %s" % ["band (m)", "plants", "tris", "nodes", "zone mix"])
	var edges: Array[float] = [0.0, 100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 175.0, 200.0]
	for bi in range(edges.size() - 1):
		var lo2: float = edges[bi]
		var hi2: float = edges[bi + 1]
		var n2: int = 0
		var tr: int = 0
		var nodes2: int = 0
		var zmix := PackedInt32Array()
		zmix.resize(8)
		for coord: Vector2i in (tc.get("_chunk_scatter") as Dictionary):
			for e: Dictionary in ((tc.get("_chunk_scatter") as Dictionary)[coord] as Array):
				var o: Vector3 = (e["xf"] as Transform3D).origin
				var d: float = Vector2(o.x - fsb.x, o.z - fsb.z).length()
				if d < lo2 or d >= hi2:
					continue
				n2 += 1
				tr += int(tris_of.get(String(e.get("name", "")), 0))
				var zt: int = vm.get_terrain_type_at(o, cs)
				zmix[zt] = zmix[zt] + 1
		for coord2: Vector2i in (tc.get("_chunk_nodes") as Dictionary):
			for n3 in ((tc.get("_chunk_nodes") as Dictionary)[coord2] as Array):
				var d3: float = Vector2((n3 as Node3D).position.x - fsb.x,
					(n3 as Node3D).position.z - fsb.z).length()
				if d3 >= lo2 and d3 < hi2:
					nodes2 += 1
		var mix: String = ""
		for zi in names.size():
			if zmix[zi] > 0:
				mix += "%s %d  " % [names[zi], zmix[zi]]
		print("  %5.0f-%-7.0f %8d %10d %7d   %s" % [lo2, hi2, n2, tr, nodes2, mix])

	# ---------- the bush ring: what each F12 step would take ----------
	print("\n  BUSHES (his ruling: they stay at 350 m). What a cut WOULD take, from %.0f,%.0f:"
		% [fsb.x, fsb.z])
	print("  %-10s %10s %12s %10s" % ["cut at", "instances", "tris(full)", "nodes"])
	for r: float in [350.0, 250.0, 200.0, 150.0]:
		var bn: int = 0
		var bt: int = 0
		for coord4: Vector2i in (tc.get("_chunk_scatter") as Dictionary):
			for e4: Dictionary in ((tc.get("_chunk_scatter") as Dictionary)[coord4] as Array):
				var nm4: String = String(e4.get("name", ""))
				if not nm4.begins_with("bush_"):
					continue
				var o4: Vector3 = (e4["xf"] as Transform3D).origin
				if Vector2(o4.x - fsb.x, o4.z - fsb.z).length() >= r:
					bn += 1
					bt += int(tris_of.get(nm4, 0))
		var bnodes: int = 0
		for coord5: Vector2i in (tc.get("_chunk_nodes") as Dictionary):
			for n5 in ((tc.get("_chunk_nodes") as Dictionary)[coord5] as Array):
				var mmi5: MultiMeshInstance3D = n5 as MultiMeshInstance3D
				if not String(mmi5.get_meta("species", "")).begins_with("bush_"):
					continue
				# A node is hidden only when its WHOLE transformed AABB clears the ring, so
				# the bucket half-diagonal is the honest allowance and this count is a FLOOR.
				if Vector2(mmi5.position.x - fsb.x, mmi5.position.z - fsb.z).length() - 45.0 >= r:
					bnodes += 1
		print("  %-10s %10d %12d %10d" % ["%.0f m" % r, bn, bt, bnodes])
	print("  (the 350 m row is the shipped default and removes nothing.)")
	get_tree().quit(0)


func _species_census(tc: Node) -> Dictionary:
	var d: Dictionary = {}
	for coord: Vector2i in (tc.get("_chunk_scatter") as Dictionary):
		for e: Dictionary in ((tc.get("_chunk_scatter") as Dictionary)[coord] as Array):
			var nm: String = String(e.get("name", ""))
			d[nm] = int(d.get(nm, 0)) + 1
	return d


## Index buffer, not vertex count / 3.
func _tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var n: int = 0
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.size() > 0:
			@warning_ignore("integer_division")
			var t: int = idx.size() / 3
			n += t
		else:
			@warning_ignore("integer_division")
			var t2: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			n += t2
	return n


func _sum(d: Dictionary) -> int:
	var n: int = 0
	for k in d:
		n += int(d[k])
	return n
