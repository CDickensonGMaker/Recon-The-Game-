extends Node
## Vegetation seat + canopy truth in the PATROL world (council 2026-07-18 evening).
## HONEST LIMIT: this proves DATA SEATING, never pixels - MultiMesh transform
## read-back is blind in this build (tools/diag_mm_readback.gd), so placement
## truth comes from system-owned placed-origin arrays, cross-checked by TWO
## independent channels: physics rays against chunk trimesh collision, and an
## instance_count census. The LOOK is blessed only by the Summoner's windowed run.

const EPS_INSTRUMENT: float = 0.6
const EPS_SEAT: float = 0.5
const NEAR_RADIUS: float = 300.0

func _ready() -> void:
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(47225, "DIAG-VEG")
	var waited := 0.0
	while waited < 180.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(1.0).timeout
	for i in range(5):
		await get_tree().physics_frame   # deferred clutter flush + collider settle
	var world: GameWorld = flow.world
	var tm: TerrainManager = world.terrain_manager
	var vm: VegetationManager = world.vegetation_manager
	var spawn: Vector3 = world.player.global_position
	var fail := false

	# ---- canopy-source + range contract
	var src_ok: bool = vm.canopy_source == VegetationManager.CanopySource.TREE_COVER \
		and vm._tree_cover != null
	print("[VEG] canopy TREE_COVER=%s  near=%.0f view=%.0f bucket=%.0f" % [
		str(src_ok), vm._tree_cover.near_distance if vm._tree_cover else -1.0,
		vm._tree_cover.view_distance if vm._tree_cover else -1.0, TreeCoverLayer.BUCKET])
	if not src_ok:
		fail = true

	# ---- instrument validity: heightmap vs physics ray at random points
	var space := world.get_world_3d().direct_space_state
	var vrng := RandomNumberGenerator.new()
	vrng.seed = 4711
	var inst_bad: int = 0
	for _i in range(40):
		var p := Vector3(vrng.randf_range(100.0, tm.map_size - 100.0), 0.0,
			vrng.randf_range(100.0, tm.map_size - 100.0))
		var hm_y: float = tm.get_height_at(p)
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(p.x, 400.0, p.z), Vector3(p.x, -100.0, p.z))
		q.exclude = [world.player.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.has("position"):
			inst_bad += 1
			continue
		var dy: float = absf((hit.position as Vector3).y - hm_y)
		# structures/water sit above terrain - only judge rays that hit a terrain chunk
		if (hit.collider as Node).name == "RaycastCollision" and dy > EPS_INSTRUMENT:
			inst_bad += 1
	print("[VEG] instrument: %d/40 terrain rays off by >%.1fm" % [inst_bad, EPS_INSTRUMENT])
	if inst_bad > 2:
		print("[VEG] FAIL instrument - heightmap and physics disagree; nothing below is trustworthy")
		fail = true

	# ---- placement honesty per system (placed origins vs terrain NOW + ray)
	fail = _check_system("TreeCover", vm._tree_cover.chunk_origins, world, spawn, 0.05) or fail
	var clutter: GroundClutter = null
	for c in world.get_children():
		if c is GroundClutter:
			clutter = c
			break
	if clutter == null:
		print("[VEG] FAIL GroundClutter node missing")
		fail = true
	else:
		# quad layers center at +size.y/2 (max 1.1m/2) - allow that art margin
		fail = _check_system("Clutter", clutter.placed_origins, world, spawn, 0.66) or fail
		var census_bad: int = 0
		for sc: Vector2i in clutter._buckets:
			var stored: int = (clutter.placed_origins.get(sc, PackedVector3Array()) as PackedVector3Array).size()
			var live: int = 0
			for mmi in clutter._buckets[sc]:
				if is_instance_valid(mmi) and (mmi as MultiMeshInstance3D).multimesh != null:
					live += (mmi as MultiMeshInstance3D).multimesh.instance_count
			if stored != live:
				census_bad += 1
		print("[VEG] clutter census: %d/%d subcells where stored != live instance count" % [
			census_bad, clutter._buckets.size()])
		if census_bad > 0:
			fail = true

	# ---- near-spawn generation floor (the jungle must EXIST around the wire)
	var near_inst: int = 0
	for coord: Vector2i in vm._tree_cover.chunk_origins:
		for o: Vector3 in vm._tree_cover.chunk_origins[coord]:
			if Vector2(o.x - spawn.x, o.z - spawn.z).length() <= NEAR_RADIUS:
				near_inst += 1
	print("[VEG] tree-cover instances within %.0fm of spawn: %d (floor 500)" % [NEAR_RADIUS, near_inst])
	if near_inst < 500:
		fail = true

	var kids: int = vm._tree_cover.get_child_count()
	print("[VEG] tree-cover child nodes: %d (cap 26000)" % kids)
	if kids > 26000:
		fail = true

	print("[VEG] VERDICT -> %s" % ("FAIL" if fail else "PASS"))
	get_tree().quit(1 if fail else 0)


## Returns true on failure. offset = expected base-above-origin art margin cap.
func _check_system(label: String, origins_by_key: Dictionary, world: GameWorld,
		spawn: Vector3, offset: float) -> bool:
	var tm: TerrainManager = world.terrain_manager
	var space := world.get_world_3d().direct_space_state
	var checked: int = 0
	var seat_bad: int = 0
	var ray_bad: int = 0
	var worst: float = 0.0
	var worst_at := Vector3.ZERO
	for key in origins_by_key:
		var arr: PackedVector3Array = origins_by_key[key]
		var step: int = maxi(1, arr.size() / 60)
		for i in range(0, arr.size(), step):
			var o: Vector3 = arr[i]
			if Vector2(o.x - spawn.x, o.z - spawn.z).length() > NEAR_RADIUS:
				continue
			checked += 1
			var gap: float = o.y - tm.get_height_at(o)
			if absf(gap) > EPS_SEAT + offset:
				seat_bad += 1
				if absf(gap) > absf(worst):
					worst = gap
					worst_at = o
			if checked % 7 == 0:   # ray subset - the independent channel, budgeted
				var q := PhysicsRayQueryParameters3D.create(
					Vector3(o.x, 400.0, o.z), Vector3(o.x, -100.0, o.z))
				var hit: Dictionary = space.intersect_ray(q)
				if hit.has("position") and (hit.collider as Node).name == "RaycastCollision":
					var ray_y: float = (hit.position as Vector3).y
					# only judge placement where collision agrees with the heightmap;
					# where THEY diverge (steep tris, crater rims) it is terrain-mesh
					# business, not veg placement - the instrument pass owns that
					if absf(ray_y - tm.get_height_at(o)) <= EPS_INSTRUMENT \
							and absf(o.y - ray_y) > EPS_SEAT + offset + EPS_INSTRUMENT:
						ray_bad += 1
	print("[VEG] %-10s checked=%d seat_bad=%d ray_bad=%d worst=%+.2fm at %.0f,%.0f" % [
		label, checked, seat_bad, ray_bad, worst, worst_at.x, worst_at.z])
	return seat_bad > 0 or ray_bad > 0 or checked == 0
