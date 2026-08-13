## nav_baker.gd - navmesh for the places enemies actually fight.
##
## Chunks are the wrong unit. A 256m chunk at the nav map's 0.25 cell size is a
## 1024x1024 Recast heightfield, x25, over jungle nobody paths through. Chunks
## also don't know where the structures are (SitePlanner parents them to
## GameWorld), they rebuild on every grenade crater, and they tile - so they need
## edge stitching that agent_radius erosion actively prevents.
##
## So: one NavigationRegion3D per stamped site cluster, parented to GameWorld at
## IDENTITY transform, source geometry synthesised from the heightmap, structures
## carved with add_projected_obstruction(). Everything falls out:
##   identity transform -> no double-offset (the old bake_navigation() baked
##                         world-space geometry into a region that then applied
##                         its own transform again)
##   islands by design  -> no border_size, no stitching
##   sites != chunks    -> a crater never triggers a re-bake
##
## NAMED TRADEOFF: no long-range pathfinding. An enemy 300m out in open jungle
## bee-lines. That is correct here - _move_toward() is only ever called with
## last_known_target_pos, current_cover and patrol waypoints, all short-range,
## and GameplayGrid already owns long-range placement queries.
class_name NavBaker
extends Node


const HALF_MIN: float = 35.0
const HALF_MAX: float = 70.0
const HALF_PAD: float = 25.0

## The main firebase is its own case, and it needs both of these.
##
## SIZE: the compound is ~300m across, so the 70m HALF_MAX would cover under a quarter of it
## and leave the gate, the spawn point and the whole outer wire off-mesh - and off-mesh means
## NavRouter.step returns direct steering, which is the defect this bake exists to fix.
##
## GEOMETRY: _add_structures only reads nodes in the "nav_blockers" group, and the firebase GLB
## is one plain Node3D root that is not in it. Baked that way the
## mesh would run flat through every bunker and berm, and the men would path INTO walls with
## full confidence - worse than no navmesh, because it would look deliberate. So this one site
## parses the real `-colonly` trimeshes instead: the exact colliders move_and_slide() hits, so
## navmesh and physics cannot disagree.
const FSB_KIND: String = "firebase_main"
const FSB_HALF: float = 185.0
const GRID_STEP: float = 4.0        ## == WorldConfig.CELL_SIZE; finer is pure interpolation
const AGENT_RADIUS: float = 0.5     ## enemy capsule is 0.4 + clearance
const AGENT_HEIGHT: float = 1.8
## The step a man takes without it being a climb. Quantised to cell_height at bake.
const AGENT_MAX_CLIMB: float = 0.4

## Boxes with a live navmesh. Static so EnemyBase can ask cheaply, at 6.7 Hz.
static var _live_boxes: Array[AABB] = []

var regions_live: int = 0
var _terrain: TerrainManager = null
var _queue: Array[Dictionary] = []
var _active_mesh: NavigationMesh = null
var _bake_start_ms: int = 0
var _total_ms: int = 0

## ---------- BREACHING ----------
## "sites != chunks -> a crater never triggers a re-bake" is right about CRATERS and wrong
## about STRUCTURES. A satchel that drops a parapet segment or a bunker has changed what a
## man can walk through, and until this existed the hole was cosmetic: _add_colliders
## already skips `disabled` shapes and Destructible._do_destroy already disables them, so
## the mesh was correct the moment it was rebuilt - nothing ever rebuilt it.
##
## Debounced, because a satchel kills several segments in one blast and each would
## otherwise queue its own bake of the same box.
const REBAKE_DEBOUNCE_S: float = 1.5
## Completed jobs, kept so a breach can re-run the one that owns its ground.
var _baked: Array[Dictionary] = []
var _dirty: Array[int] = []
var _dirty_timer: float = 0.0


static func clear() -> void:
	# GameFlow builds mission after mission in one process, and test_site_stamp
	# instantiates three GameWorlds. A stale AABB would put mission 5's enemies
	# inside mission 1's village.
	_live_boxes.clear()


static func box_index_at(p: Vector3) -> int:
	for i in range(_live_boxes.size()):
		if _xz_contains(_live_boxes[i], p):
			return i
	return -1


static func box_contains(i: int, p: Vector3) -> bool:
	if i < 0 or i >= _live_boxes.size():
		return false
	return _xz_contains(_live_boxes[i], p)


static func _xz_contains(b: AABB, p: Vector3) -> bool:
	return p.x >= b.position.x and p.x <= b.position.x + b.size.x \
		and p.z >= b.position.z and p.z <= b.position.z + b.size.z


func setup(terrain: TerrainManager) -> void:
	add_to_group(&"nav_baker")
	_terrain = terrain


func _exit_tree() -> void:
	NavBaker.clear()


## Bake only where there is something to path around AND someone to do it.
static func should_bake(site: Dictionary, anchors: Array[Vector3]) -> bool:
	if not WorldConfig.NAV_SITE_KINDS.has(str(site.get("kind", ""))):
		return false
	var center: Vector3 = site.get("center", Vector3.ZERO)
	var radius: float = float(site.get("radius", 20.0))
	for a in anchors:
		if Vector2(a.x - center.x, a.z - center.z).length() <= radius + 60.0:
			return true
	return false


func queue_sites(sites: Array, anchors: Array[Vector3]) -> void:
	var boxes: Array[AABB] = []
	for s in sites:
		var site: Dictionary = s
		# The firebase is baked whether or not an enemy anchor is near it: the squad and the
		# garrison live inside that wire and must path there on a quiet afternoon too. It is
		# also kept OUT of the merge below - a merged box would lose its collider root.
		if str(site.get("kind", "")) == FSB_KIND:
			_queue_firebase(site)
			continue
		if not NavBaker.should_bake(site, anchors):
			continue
		boxes.append(_box_for(site.get("center", Vector3.ZERO), float(site.get("radius", 20.0))))
	boxes = _merge(boxes)
	# _merge exists because overlapping, non-coincident regions produce NO edge connections
	# - but the firebase is deliberately kept OUT of it (a merged box would lose its
	# collider root), so it is the one box that can still overlap a site. Measured on the
	# demo: the firebase overlapped BOTH other regions, and an ally standing on one could
	# not path to a point on the other. Pull the sites clear of it.
	for b in _clear_of_firebase(boxes):
		_queue.append({"box": b})


## Shrink each site box out of the firebase's, or drop it if the firebase already covers
## it - that ground is baked from real colliders and does not want a second, coarser mesh
## sitting in the same place.
func _clear_of_firebase(boxes: Array[AABB]) -> Array[AABB]:
	var fsb: AABB = AABB()
	var have: bool = false
	for j in _queue:
		var job: Dictionary = j
		if job.has("colliders"):
			fsb = job["box"]
			have = true
			break
	if not have:
		return boxes
	var out: Array[AABB] = []
	for b in boxes:
		if not _xz_overlap(b, fsb):
			out.append(b)
			continue
		# Penetration on each side; retreat along the cheapest one so the two boxes end
		# ADJACENT. Aligned edges can connect through the map's edge_connection_margin;
		# overlapping ones can never connect at all.
		var pen_xl: float = (fsb.position.x + fsb.size.x) - b.position.x
		var pen_xh: float = (b.position.x + b.size.x) - fsb.position.x
		var pen_zl: float = (fsb.position.z + fsb.size.z) - b.position.z
		var pen_zh: float = (b.position.z + b.size.z) - fsb.position.z
		var best: float = minf(minf(pen_xl, pen_xh), minf(pen_zl, pen_zh))
		var trimmed: AABB = b
		if is_equal_approx(best, pen_xl):
			trimmed.position.x += pen_xl
			trimmed.size.x -= pen_xl
		elif is_equal_approx(best, pen_xh):
			trimmed.size.x -= pen_xh
		elif is_equal_approx(best, pen_zl):
			trimmed.position.z += pen_zl
			trimmed.size.z -= pen_zl
		else:
			trimmed.size.z -= pen_zh
		# What is left has to be worth baking. Anything smaller is inside the firebase's
		# own mesh in every way that matters.
		if trimmed.size.x >= HALF_MIN and trimmed.size.z >= HALF_MIN:
			out.append(trimmed)
	return out


func queue_site(center: Vector3, radius: float) -> void:
	_queue.append({"box": _box_for(center, radius)})


## Bake a box from LIVE COLLIDERS under `root` instead of the structure table. This is the
## firebase's own path (_queue_firebase uses it) made callable, so a bench can prove a breach
## through exactly the geometry the compound uses - and so the re-bake has a collider root to
## re-read when a wall dies.
func queue_site_with_colliders(center: Vector3, radius: float, root: Node3D) -> void:
	_queue.append({"box": _box_for(center, radius, radius), "colliders": root})


func _queue_firebase(site: Dictionary) -> void:
	var nodes: Array = site.get("nodes", [])
	var root: Node3D = (nodes[0] as Node3D) if nodes.size() > 0 else null
	if root == null:
		push_error("[NAV] firebase site has no root node - falling back to a terrain-only "
			+ "bake, which paths men straight through the bunkers")
	_queue.append({
		"box": _box_for(site.get("center", Vector3.ZERO), FSB_HALF, FSB_HALF),
		"colliders": root,
	})


func _box_for(center: Vector3, radius: float, cap: float = HALF_MAX) -> AABB:
	var half: float = clampf(radius + HALF_PAD, HALF_MIN, cap)
	return AABB(Vector3(center.x - half, -1000.0, center.z - half), Vector3(half * 2.0, 2000.0, half * 2.0))


## stamp_aa_site() does no separation check against placed_sites, so two boxes can
## overlap. Overlapping, non-coincident regions produce no edge connections and
## map_get_closest_point() picks arbitrarily - paths teleport between layers.
func _merge(boxes: Array[AABB]) -> Array[AABB]:
	var changed := true
	while changed:
		changed = false
		for i in range(boxes.size()):
			for j in range(i + 1, boxes.size()):
				if _xz_overlap(boxes[i], boxes[j]):
					boxes[i] = boxes[i].merge(boxes[j])
					boxes.remove_at(j)
					changed = true
					break
			if changed:
				break
	return boxes


static func _xz_overlap(a: AABB, b: AABB) -> bool:
	return a.position.x < b.position.x + b.size.x and b.position.x < a.position.x + a.size.x \
		and a.position.z < b.position.z + b.size.z and b.position.z < a.position.z + a.size.z


## Something solid died at `at`: rebuild the navmesh that owns that ground so the hole is
## walkable. Safe to call from anything, any number of times - it debounces.
func breach_at(at: Vector3) -> void:
	for i in range(_baked.size()):
		if NavBaker._xz_contains(_baked[i]["box"] as AABB, at):
			if i not in _dirty:
				_dirty.append(i)
			_dirty_timer = REBAKE_DEBOUNCE_S
			return


## The one baker in the tree, or null. Destructible has no reference to the world and must
## not grow one; the group is how it finds this.
static func instance(from: Node) -> NavBaker:
	if from == null or from.get_tree() == null:
		return null
	return from.get_tree().get_first_node_in_group(&"nav_baker") as NavBaker


func _remember(box: AABB, region: NavigationRegion3D, croot: Node3D) -> void:
	for j in _baked:
		if (j["box"] as AABB).is_equal_approx(box):
			var old := j.get("region", null) as NavigationRegion3D
			if old != null and is_instance_valid(old) and old != region:
				old.queue_free()      # the replacement is live; drop the stale overlap
			j["region"] = region
			if croot != null:
				j["colliders"] = croot
			return
	_baked.append({"box": box, "region": region, "colliders": croot})


func _tick_rebakes(delta: float) -> void:
	if _dirty.is_empty():
		return
	_dirty_timer -= delta
	if _dirty_timer > 0.0:
		return
	for i in _dirty:
		if i < 0 or i >= _baked.size():
			continue
		var j: Dictionary = _baked[i]
		var job: Dictionary = {"box": j["box"]}
		if j.get("colliders", null) != null:
			job["colliders"] = j["colliders"]
		_queue.append(job)
	print("[NavBaker] breach: re-baking %d region(s)" % _dirty.size())
	_dirty.clear()


func _process(delta: float) -> void:
	_tick_rebakes(delta)
	if _active_mesh != null:
		if NavigationServer3D.is_baking_navigation_mesh(_active_mesh):
			return
		_active_mesh = null
	if _queue.is_empty():
		return
	_start_bake(_queue.pop_front())


func _start_bake(job: Dictionary) -> void:
	if _terrain == null:
		return
	var box: AABB = job.box
	var map: RID = get_tree().root.get_world_3d().navigation_map

	var nav := NavigationMesh.new()
	# Read cell size from the SERVER, never hardcode it. project.godot has no
	# [navigation] section, so the map runs at the 0.25 default while the old
	# bake_navigation() set 0.5 -- Godot refuses to merge a region whose cell size
	# differs from the map's, and skips it silently. That defect would have
	# survived fixing every other one.
	nav.cell_size = NavigationServer3D.map_get_cell_size(map)
	nav.cell_height = NavigationServer3D.map_get_cell_height(map)
	# Agent metrics pre-snapped to voxel units - the baker quantizes them anyway
	# (radius/height ceiled, climb floored) and warns per bake if they don't land exact.
	nav.agent_radius = ceilf(AGENT_RADIUS / nav.cell_size) * nav.cell_size
	nav.agent_height = ceilf(AGENT_HEIGHT / nav.cell_height) * nav.cell_height
	# ROUND, not floor. The climb must be a whole number of cell heights, but 0.4/0.2 in
	# float32 lands a hair UNDER 2.0, so flooring it silently returned 1 cell - a 0.20m step,
	# half what is asked for, with nothing in the log to say so. Every crater rim was a cliff.
	nav.agent_max_climb = maxf(nav.cell_height,
		roundf(AGENT_MAX_CLIMB / nav.cell_height) * nav.cell_height)
	nav.agent_max_slope = 50.0
	nav.border_size = 0.0
	# The mound leaves a second walkable layer buried under the compound; anywhere it has
	# less than agent_height of clearance is not floor, and map_get_closest_point should
	# not be able to choose it.
	nav.filter_walkable_low_height_spans = true
	nav.filter_baking_aabb = box

	if not is_equal_approx(nav.cell_size, NavigationServer3D.map_get_cell_size(map)):
		push_error("[NAV] region cell_size %f != map cell_size %f - region will not merge" % [
			nav.cell_size, NavigationServer3D.map_get_cell_size(map)])
		return

	var source := NavigationMeshSourceGeometryData3D.new()
	_add_terrain(source, box)
	var carved: int = 0
	var croot: Node3D = job.get("colliders", null) as Node3D
	if croot != null and is_instance_valid(croot):
		carved = -_add_colliders(source, croot, box) - 1   # negative = collider count, see below
		# AND the stamped structures inside it. The firebase box is 370m and now swallows
		# whole village and ruin sites, whose own regions are pulled clear of it to stop
		# the overlap that severed every path between them. Its collider walk only knows
		# firebase geometry, so without this a hut inside the wire's box would be baked
		# straight through - navmesh disagreeing with physics, which is the one thing this
		# baker exists to prevent.
		_add_structures(source, box)
	else:
		carved = _add_structures(source, box)

	var region := NavigationRegion3D.new()
	region.name = "NavRegion_%d" % regions_live
	get_parent().add_child(region)
	region.global_transform = Transform3D.IDENTITY   # source geometry is world-space

	_active_mesh = nav
	_bake_start_ms = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav, source, _on_bake_done.bind(region, nav, box, carved, croot))


## Runs on the main thread. The ONLY place navigation_mesh is assigned.
func _on_bake_done(region: NavigationRegion3D, nav: NavigationMesh, box: AABB, carved: int,
		croot: Node3D = null) -> void:
	if not is_instance_valid(region):
		return
	var polys: int = nav.get_polygon_count()
	_total_ms += Time.get_ticks_msec() - _bake_start_ms
	var geom: String = ("%d colliders" % (-carved - 1)) if carved < 0 else "%d carved" % carved
	# climb is printed because it is QUANTISED to cell_height (floor(0.4/h)*h). With no
	# [navigation] section in project.godot it silently floors to 0.25 and every crater rim
	# becomes a cliff, with nothing in the log to say so.
	print("[NavBaker] bake done: box=%s verts=%d polys=%d geom=%s cell=%.3f h=%.3f climb=%.2f" % [
		box.size, nav.get_vertices().size(), polys, geom, nav.cell_size,
		nav.cell_height, nav.agent_max_climb])
	if polys == 0:
		push_error("[NAV] baked region has 0 polygons (box %s, geom %s)" % [box.size, geom])
		region.queue_free()
	else:
		region.navigation_mesh = nav
		NavBaker._live_boxes.append(box)
		regions_live += 1
		_remember(box, region, croot)
	if _queue.is_empty() and _active_mesh == null:
		print("[NavBaker] %d region(s), %d polys, %d ms total" % [regions_live, polys, _total_ms])


## The chunk mesh steps at chunk_size/grid_resolution = 256/64 = 4.0m, exactly the
## heightmap resolution, and get_height_at() is bilinear over the same grid. So
## sampling the heightmap at 4m is indistinguishable from parsing the chunk mesh,
## while being decoupled from chunk lifetime, transforms and crater rebuilds.
func _add_terrain(source: NavigationMeshSourceGeometryData3D, box: AABB) -> void:
	var x0: float = box.position.x
	var z0: float = box.position.z
	var nx: int = int(box.size.x / GRID_STEP)
	var nz: int = int(box.size.z / GRID_STEP)
	var faces := PackedVector3Array()
	for iz in range(nz):
		for ix in range(nx):
			var ax: float = x0 + float(ix) * GRID_STEP
			var az: float = z0 + float(iz) * GRID_STEP
			var bx: float = ax + GRID_STEP
			var bz: float = az + GRID_STEP
			var p00 := Vector3(ax, _terrain.get_height_at(Vector3(ax, 0, az)), az)
			var p10 := Vector3(bx, _terrain.get_height_at(Vector3(bx, 0, az)), az)
			var p01 := Vector3(ax, _terrain.get_height_at(Vector3(ax, 0, bz)), bz)
			var p11 := Vector3(bx, _terrain.get_height_at(Vector3(bx, 0, bz)), bz)
			faces.append(p00); faces.append(p10); faces.append(p11)
			faces.append(p00); faces.append(p11); faces.append(p01)
	source.add_faces(faces, Transform3D.IDENTITY)


## Feed the firebase's OWN colliders into the bake, walked by hand.
##
## NavigationServer3D.parse_source_geometry_data() was tried first and is not usable here: it
## returned a 4-polygon mesh for the whole compound, having discarded the terrain faces already
## in the source. Rather than build on an API whose emptying behaviour I would be guessing at,
## this reads the shapes directly - which is also the only version where it is obvious WHAT
## went into the navmesh, and where a bad collider can be excluded by name later.
##
## Shapes are converted in their own global transform, so a shape's node hierarchy, scale and
## the compound's seating are all already accounted for.
## Colliders a man walks AROUND but the navmesh must not be shredded by.
##
## fb_veg_ is 90 merged tree stumps and 46 logs scattered across the cleared band, each ~0.4-0.8m
## - right at agent_max_climb, so every one punches a hole and erodes agent_radius of ground
## around it. Feeding them in fragmented the compound into islands and allies 5m from their post
## could not path to it. They are still SOLID; a man just steps around them without the navmesh
## having to model it.
##
## fb_int_ is interior dressing - hanging bulbs, crates, bunks. Same story, indoors.
## Authority for the vegetation prefix is SitePlanner.VEG_COLLIDER_PREFIX. It is repeated as a
## literal here on purpose: naming SitePlanner inside a CONST INITIALISER makes this script's
## class resolution depend on that whole graph, and doing so broke an unrelated parse
## (enemy_base._dress_visual "not found in base self") in the same run. A const initialiser is
## not the place to reach across files.
## `door_` is here EXPLICITLY rather than by accident: a ScreenDoor leaf is visual only and
## must never carry a collider, but naming it in the contract means a leaf that is ever
## exported with one still cannot seal the doorway it hangs in.
## fb_hootch_roof_ joined this list 2026-08-12. The eleven hooches ship 176 roof panels and
## fb_hootch is in COL_TRIMESH, so every one bakes as a real surface. A panel rises 0.61m over
## 1.22m - about 27 degrees - which is comfortably under agent_max_slope, so the navmesh
## treated every roof in the compound as walkable floor and men pathed onto them. The collider
## stays: rounds still behave and nobody falls through. It is only no longer somewhere to walk.
const NAV_IGNORE_PREFIXES: Array[String] = ["fb_veg_", "fb_int_", "door_", "fb_hootch_roof_"]


func _add_colliders(source: NavigationMeshSourceGeometryData3D, root: Node3D, box: AABB) -> int:
	var roots: Array[Node] = [root]
	# SitePlanner reparents the ~80 perimeter segments and the adopted structures onto
	# Destructibles under GameWorld BEFORE this bake runs, and this walk only descends
	# the root it was handed - so the entire perimeter wall was absent from the mesh and
	# pathing routed men into solid berm. They live in their own group; seed from it.
	#
	# NOTE for NAV_IGNORE_PREFIXES below: it tests the collider's PARENT name, which for
	# these is now the Destructible, not the original fb_* node. That is safe only while
	# nothing prefixed fb_veg_/fb_int_ is ever reparented this way.
	for d in get_tree().get_nodes_in_group(SitePlanner.FSB_NAV_GEOM_GROUP):
		var dn := d as Node3D
		if dn != null and is_instance_valid(dn):
			roots.append(dn)
	return _walk_shapes(source, roots, box)


func _walk_shapes(source: NavigationMeshSourceGeometryData3D, roots: Array[Node], box: AABB) -> int:
	var added: int = 0
	var stack: Array[Node] = roots.duplicate()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var cs := n as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		if not NavBaker._xz_contains(box, cs.global_position):
			continue
		var owner_name: String = String(cs.get_parent().name)
		var skip: bool = false
		for p in NAV_IGNORE_PREFIXES:
			if owner_name.begins_with(p):
				skip = true
				break
		if skip:
			continue
		var faces: PackedVector3Array = _shape_faces(cs.shape)
		if faces.is_empty():
			continue
		faces = _cull_roof_faces(owner_name, faces, cs.global_transform)
		source.add_faces(faces, cs.global_transform)
		added += 1
	return added


## Structures whose ROOF bakes as walkable floor. Each is ONE mesh - roof and interior floor
## in the same shape - so a NAV_IGNORE_PREFIXES entry would delete the inside too, and the
## fighting bunkers now carry 37 work_bunker posts men have to reach. Measured 2026-08-12 in
## firebase_v3.2.blend, upward faces under agent_max_slope and >=1.9m above their own base:
## bunker_fighting 341.7 m2, bunker_mg 256.8, sleeping_bunker 192.1, gp_tent 154.0, mess 44.7.
##
## fb_tower is deliberately ABSENT: a tower is meant to be climbed, and its ladder_bottom /
## ladder_top markers exist precisely so men can stand the platform.
const NAV_ROOF_CULL_PREFIXES: Array[String] = [
	"fb_gp_tent", "fb_mess", "fb_bunker_mg", "fb_bunker_fighting", "fb_sleeping_bunker",
]
## How far above a structure's own base a surface stops being its floor and starts being its
## roof. Bunker interiors sit ~0.97m BELOW grade and their roofs ~3.2m above it, so 1.9m
## separates the two with room on both sides.
const NAV_ROOF_HEIGHT_M: float = 1.9


## Drop the roof triangles of a monolithic structure while keeping its floor. Returns the
## faces unchanged for everything else, which is nearly every shape in the compound.
func _cull_roof_faces(owner_name: String, faces: PackedVector3Array,
		xform: Transform3D) -> PackedVector3Array:
	var match_found: bool = false
	for p in NAV_ROOF_CULL_PREFIXES:
		if owner_name.begins_with(p):
			match_found = true
			break
	if not match_found:
		return faces
	var base_y: float = INF
	for v in faces:
		var wy: float = (xform * v).y
		if wy < base_y:
			base_y = wy
	var cut: float = base_y + NAV_ROOF_HEIGHT_M
	var kept: PackedVector3Array = PackedVector3Array()
	for i in range(0, faces.size() - 2, 3):
		var a: Vector3 = xform * faces[i]
		var b: Vector3 = xform * faces[i + 1]
		var c: Vector3 = xform * faces[i + 2]
		# a triangle is roof only if ALL of it is up there - a wall crossing the line stays,
		# or the structure loses the sides that hold its floor in.
		if a.y >= cut and b.y >= cut and c.y >= cut:
			continue
		kept.append(faces[i])
		kept.append(faces[i + 1])
		kept.append(faces[i + 2])
	return kept


## Triangles for the shape kinds the firebase GLB actually imports: `-colonly` trimeshes come
## in as ConcavePolygonShape3D, and the generator's box hulls as BoxShape3D. Anything else is
## approximated from its own AABB rather than skipped - an unrecognised shape that silently
## contributed nothing would be a hole in the navmesh where a real wall stands.
func _shape_faces(shape: Shape3D) -> PackedVector3Array:
	var concave := shape as ConcavePolygonShape3D
	if concave != null:
		return concave.get_faces()
	var half: Vector3 = Vector3(0.5, 0.5, 0.5)
	var boxs := shape as BoxShape3D
	if boxs != null:
		half = boxs.size * 0.5
	else:
		var dbg: ArrayMesh = shape.get_debug_mesh()
		if dbg == null:
			return PackedVector3Array()
		half = dbg.get_aabb().size * 0.5
	var out := PackedVector3Array()
	# 6 quads -> 12 triangles, wound outward.
	for axis in range(3):
		for sign_i in [-1.0, 1.0]:
			var u: int = (axis + 1) % 3
			var v: int = (axis + 2) % 3
			var quad: Array[Vector3] = []
			for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[axis] = half[axis] * sign_i
				p[u] = half[u] * o.x
				p[v] = half[v] * o.y
				quad.append(p)
			out.append(quad[0]); out.append(quad[1]); out.append(quad[2])
			out.append(quad[0]); out.append(quad[2]); out.append(quad[3])
	return out


## add_projected_obstruction() takes a footprint polygon and carves it. It is an
## exact match for CollisionTable's BoxShape3D + y_offset, needs no GLB mesh
## parsing and no scene walk - and, crucially, it matches the collider that
## move_and_slide() actually hits, so navmesh and physics never disagree.
func _add_structures(source: NavigationMeshSourceGeometryData3D, box: AABB) -> int:
	var carved: int = 0
	for n in get_tree().get_nodes_in_group("nav_blockers"):
		var body := n as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var p: Vector3 = body.global_position
		if not NavBaker._xz_contains(box, p):
			continue
		# An enterable model's own -col trimeshes ARE its collision (SitePlanner adds no
		# box hull for it). Projecting its footprint instead would carve the interior and
		# the doorway out of the mesh that the physics leaves open.
		if bool(body.get_meta("nav_trimesh", false)):
			var one: Array[Node] = [body]
			if _walk_shapes(source, one, box) > 0:
				carved += 1
			continue
		var size: Vector3 = body.get_meta("nav_box", Vector3.ZERO)
		if size.length() < 0.01:
			continue
		# Inflate the footprint by the agent radius (+ a hair). Godot erodes the
		# outer walkable border by agent_radius but does NOT erode around a carved
		# projected obstruction, so without this the path hugs the hut's exact edge
		# and the enemy's 0.4m body jams the collider. Standing the boundary off by
		# the radius is what makes the corridor actually walkable.
		var inflate: float = AGENT_RADIUS + 0.15
		var hx: float = size.x * 0.5 + inflate
		var hz: float = size.z * 0.5 + inflate
		var yaw: float = body.global_rotation.y
		var c: float = cos(yaw)
		var s: float = sin(yaw)
		var corners := PackedVector3Array()
		for o in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
			corners.append(Vector3(p.x + o.x * c - o.y * s, p.y, p.z + o.x * s + o.y * c))
		source.add_projected_obstruction(corners, p.y, maxf(size.y, 1.0), true)
		carved += 1
	return carved
