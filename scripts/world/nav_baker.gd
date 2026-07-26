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
const GRID_STEP: float = 4.0        ## == WorldConfig.CELL_SIZE; finer is pure interpolation
const AGENT_RADIUS: float = 0.5     ## enemy capsule is 0.4 + clearance
const AGENT_HEIGHT: float = 1.8

## Boxes with a live navmesh. Static so EnemyBase can ask cheaply, at 6.7 Hz.
static var _live_boxes: Array[AABB] = []

var regions_live: int = 0
var _terrain: TerrainManager = null
var _queue: Array[Dictionary] = []
var _active_mesh: NavigationMesh = null
var _bake_start_ms: int = 0
var _total_ms: int = 0


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
		if not NavBaker.should_bake(site, anchors):
			continue
		boxes.append(_box_for(site.get("center", Vector3.ZERO), float(site.get("radius", 20.0))))
	boxes = _merge(boxes)
	for b in boxes:
		_queue.append({"box": b})


func queue_site(center: Vector3, radius: float) -> void:
	_queue.append({"box": _box_for(center, radius)})


func _box_for(center: Vector3, radius: float) -> AABB:
	var half: float = clampf(radius + HALF_PAD, HALF_MIN, HALF_MAX)
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


func _process(_delta: float) -> void:
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
	nav.agent_max_climb = floorf(0.4 / nav.cell_height) * nav.cell_height
	nav.agent_max_slope = 50.0
	nav.border_size = 0.0
	nav.filter_baking_aabb = box

	if not is_equal_approx(nav.cell_size, NavigationServer3D.map_get_cell_size(map)):
		push_error("[NAV] region cell_size %f != map cell_size %f - region will not merge" % [
			nav.cell_size, NavigationServer3D.map_get_cell_size(map)])
		return

	var source := NavigationMeshSourceGeometryData3D.new()
	_add_terrain(source, box)
	var carved: int = _add_structures(source, box)

	var region := NavigationRegion3D.new()
	region.name = "NavRegion_%d" % regions_live
	get_parent().add_child(region)
	region.global_transform = Transform3D.IDENTITY   # source geometry is world-space

	_active_mesh = nav
	_bake_start_ms = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav, source, _on_bake_done.bind(region, nav, box, carved))


## Runs on the main thread. The ONLY place navigation_mesh is assigned.
func _on_bake_done(region: NavigationRegion3D, nav: NavigationMesh, box: AABB, carved: int) -> void:
	if not is_instance_valid(region):
		return
	var polys: int = nav.get_polygon_count()
	_total_ms += Time.get_ticks_msec() - _bake_start_ms
	print("[NavBaker] bake done: box=%s verts=%d polys=%d carved=%d cell=%.3f" % [
		box.size, nav.get_vertices().size(), polys, carved, nav.cell_size])
	if polys == 0:
		push_error("[NAV] baked region has 0 polygons (box %s, %d structures carved)" % [box.size, carved])
		region.queue_free()
	else:
		region.navigation_mesh = nav
		NavBaker._live_boxes.append(box)
		regions_live += 1
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
