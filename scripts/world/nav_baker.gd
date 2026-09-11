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
## man can walk through, and until this existed the hole was cosmetic: the collider walk
## already skips `disabled` shapes and Destructible._do_destroy already disables them, so
## the mesh was correct the moment it was rebuilt - nothing ever rebuilt it.
##
## Debounced, because a satchel kills several segments in one blast and each would
## otherwise queue its own bake of the same box. The quiet window is trailing - every
## breach re-arms it - so REBAKE_MAX_WAIT_S caps how long a stream of them (wire cards
## under mortar fire) can hold the hole shut; a bake in flight still finishes first.
const REBAKE_DEBOUNCE_S: float = 1.5
const REBAKE_MAX_WAIT_S: float = 6.0
## Completed jobs, kept so a breach can re-run the one that owns its ground.
var _baked: Array[Dictionary] = []
var _dirty: Array[int] = []
var _dirty_timer: float = 0.0
var _dirty_wait: float = 0.0


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


## A dirty box becomes AT MOST ONE job. Measured 2026-09-11 (B1_before.log, one 200 s
## stress night): 14 parapet breaches became 7 re-bake prints and 6 full 370 m bakes, twice
## as a PAIR queued two lines apart that both baked in full, because a box already
## collecting or baking still took a second queue entry. A box mid-collect now restarts
## its collect (the dead segment is skipped on the re-read); a box mid-bake stays dirty,
## re-arms the quiet window and is queued ONCE when that bake has landed - queuing it the
## frame the bake landed (A1_after.log) made every breach that fell in that gap a THIRD
## bake; a box already queued is left alone.
func _tick_rebakes(delta: float) -> void:
	if _dirty.is_empty():
		return
	_dirty_timer -= delta
	_dirty_wait += delta
	if _dirty_timer > 0.0 and _dirty_wait < REBAKE_MAX_WAIT_S:
		return
	var later: Array[int] = []
	var queued: int = 0
	for i in _dirty:
		if i < 0 or i >= _baked.size():
			continue
		var j: Dictionary = _baked[i]
		var box: AABB = j["box"]
		if _active_mesh != null and _active_box.is_equal_approx(box):
			later.append(i)
			continue
		if not _job.is_empty() and (_job.box as AABB).is_equal_approx(box):
			_queue.push_front(_job.job)
			_job = {}
			queued += 1
			continue
		if _is_queued(box):
			continue
		var job: Dictionary = {"box": box}
		if j.get("colliders", null) != null:
			job["colliders"] = j["colliders"]
		_queue.append(job)
		queued += 1
	if queued > 0:
		print("[NavBaker] breach: re-baking %d region(s)" % queued)
	if not later.is_empty():
		if not _fold_announced:
			print("[NavBaker] breach: folded into the bake in flight")
		_dirty_timer = REBAKE_DEBOUNCE_S
	else:
		_dirty_wait = 0.0
	_fold_announced = not later.is_empty()
	_dirty = later


func _is_queued(box: AABB) -> bool:
	for q in _queue:
		if ((q as Dictionary)["box"] as AABB).is_equal_approx(box):
			return true
	return false


## THE COLLECT IS SLICED, BOUNDED BY THE CLOCK, AND CACHED (2026-09-11). Every phase runs
## under COLLECT_BUDGET_MS of main-thread time per frame, measured in usec, and a shape too
## big for the budget is chewed a chunk of triangles at a time - a slice used to run to
## the end of whatever item it was on, and one item was 53 ms. Nothing leaves the main
## thread: the node walk, the face copies and the source resource are all touched from
## here and only here, so no thread-safety surface is added.
##
## The price is latency: at 6 ms a frame a first-bake collect is ~1.5 s at 30 fps before
## the Recast solve, which takes 2-5 s on its own thread, can start.
const COLLECT_BUDGET_MS: float = 6.0
var _job: Dictionary = {}
## The box the async Recast solve is working on, so a breach in it is folded, not queued.
var _active_box: AABB = AABB()
var _fold_announced: bool = false

## World-space faces per CollisionShape3D, keyed by instance id: {xf, shape, fwd, flip}.
## A breach re-bake re-reads ~2,400 colliders of which exactly one changed; measured
## 2026-09-11 (B1_before.log) that re-read cost ~300 ms of main-thread time per re-bake,
## six re-bakes a night. A cached shape costs two add_faces() calls. An entry is ignored
## when the shape's transform or resource differs, and dropped when the node is freed; a
## disabled shape is skipped before the cache is asked, so a dead segment never replays.
var _face_cache: Dictionary = {}
var _cache_reported: int = -1
## Usec per triangle of the cull loop, measured as it runs, so a chunk is sized to the
## budget left in the slice rather than to an item count.
var _tri_us: float = 1.0


func _process(delta: float) -> void:
	_tick_rebakes(delta)
	if not _job.is_empty():
		StallLedger.begin("nav.collect")
		_collect_slice()
		StallLedger.end()
		return
	if _active_mesh != null:
		if NavigationServer3D.is_baking_navigation_mesh(_active_mesh):
			return
		_active_mesh = null
	if _queue.is_empty():
		return
	StallLedger.begin("nav.collect")
	_start_bake(_queue.pop_front())
	StallLedger.end()


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
	# Matches physics: CharacterBody3D floor_max_angle defaults to 45 deg and no
	# body in this project overrides it. A steeper nav slope opens an inverse
	# fiction band - faces nav calls walkable that move_and_slide refuses.
	nav.agent_max_slope = 45.0
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
	var croot: Node3D = job.get("colliders", null) as Node3D
	# The job carries every input the old synchronous body held on its stack, plus a phase
	# cursor. _collect_slice() advances it; _finish_job() does what the tail of this
	# function used to do.
	_job = {"job": job, "nav": nav, "source": source, "box": box, "croot": croot,
		"phase": 0, "iz": 0, "faces": PackedVector3Array(), "stack": [],
		"shapes": [], "si": 0, "cur": {}, "added": 0, "carved": 0}
	_collect_slice()


## One frame's worth of collection. Phases: 0 terrain rows -> 1 seed the collider walk ->
## 2 walk it, a node at a time -> 3 read the shapes, a chunk of triangles at a time ->
## 4 carve the box-hull structures and start the bake. Each phase is a named span so the
## ledger says WHICH phase a fat slice was, instead of the whole collect wearing it.
func _collect_slice() -> void:
	var t0: int = Time.get_ticks_usec()
	var deadline: int = t0 + int(COLLECT_BUDGET_MS * 1000.0)
	var source: NavigationMeshSourceGeometryData3D = _job.source
	var box: AABB = _job.box
	while Time.get_ticks_usec() < deadline:
		match int(_job.phase):
			0:
				StallLedger.begin("nav.terrain")
				var more: bool = true
				while more and Time.get_ticks_usec() < deadline:
					more = _terrain_row(box)
				if not more:
					source.add_faces(_job.faces, Transform3D.IDENTITY)
					_job.faces = PackedVector3Array()
					_job.phase = 1
				StallLedger.end()
			1:
				StallLedger.begin("nav.walk")
				_seed_walk(box)
				_job.phase = 2
				StallLedger.end()
			2:
				StallLedger.begin("nav.walk")
				var more: bool = true
				while more and Time.get_ticks_usec() < deadline:
					more = _walk_step(box)
				if not more:
					_job.phase = 3
				StallLedger.end()
			3:
				if not _shape_step(source, deadline):
					_job.phase = 4
			4:
				StallLedger.begin("nav.structures")
				var carved: int = int(_job.carved) + _add_structures(source, box)
				var croot: Node3D = _job.croot
				# negative = collider count, see _on_bake_done
				_job.carved = (-int(_job.added) - 1) if (croot != null and is_instance_valid(croot)) else carved
				_job.phase = 5
				StallLedger.end()
			_:
				StallLedger.begin("nav.finish")
				_finish_job()
				StallLedger.end()
				return


## Emit ONE row of terrain quads into the job's face buffer. False when the box is done.
func _terrain_row(box: AABB) -> bool:
	var nz: int = int(box.size.z / GRID_STEP)
	var iz: int = int(_job.iz)
	if iz >= nz:
		return false
	var x0: float = box.position.x
	var z0: float = box.position.z
	var nx: int = int(box.size.x / GRID_STEP)
	var faces: PackedVector3Array = _job.faces
	var az: float = z0 + float(iz) * GRID_STEP
	var bz: float = az + GRID_STEP
	for ix in range(nx):
		var ax: float = x0 + float(ix) * GRID_STEP
		var bx: float = ax + GRID_STEP
		var p00 := Vector3(ax, _terrain.get_height_at(Vector3(ax, 0, az)), az)
		var p10 := Vector3(bx, _terrain.get_height_at(Vector3(bx, 0, az)), az)
		var p01 := Vector3(ax, _terrain.get_height_at(Vector3(ax, 0, bz)), bz)
		var p11 := Vector3(bx, _terrain.get_height_at(Vector3(bx, 0, bz)), bz)
		faces.append(p00); faces.append(p10); faces.append(p11)
		faces.append(p00); faces.append(p11); faces.append(p01)
	_job.faces = faces
	_job.iz = iz + 1
	return true


## Roots of the collider walk: the site's collider root, every Destructible that took a
## collider off it (FSB_NAV_GEOM_GROUP - SitePlanner reparents the perimeter and the
## adopted structures onto Destructibles under GameWorld BEFORE this bake runs, so a walk
## of the root alone left the entire perimeter wall out of the mesh), and the enterable
## models whose own -col trimeshes ARE their collision (nav_trimesh: SitePlanner adds no
## box hull for them, and projecting a footprint would carve their doorway out of the mesh
## the physics leaves open).
##
## Walked a node at a time rather than with find_children(): one engine-side walk of the
## ~8k-node compound was the single unsliceable item left in the collect, measured
## 2026-09-11 at 7-14 ms (A1_after.log) and 8-21 ms under load (A2_after.log).
func _seed_walk(box: AABB) -> void:
	var stack: Array = []
	var croot: Node3D = _job.croot
	if croot != null and is_instance_valid(croot):
		stack.append(croot)
		for d in get_tree().get_nodes_in_group(SitePlanner.FSB_NAV_GEOM_GROUP):
			if d != null and is_instance_valid(d):
				stack.append(d)
	for n in get_tree().get_nodes_in_group("nav_blockers"):
		var body := n as Node3D
		if body == null or not is_instance_valid(body):
			continue
		if bool(body.get_meta("nav_trimesh", false)) and NavBaker._xz_contains(box, body.global_position):
			stack.append(body)
			_job.carved = int(_job.carved) + 1
	_job.stack = stack


## Pop one node: push its children, keep it if it is an enabled, in-box, non-ignored
## shape. False when the stack is spent.
func _walk_step(box: AABB) -> bool:
	var stack: Array = _job.stack
	if stack.is_empty():
		return false
	var n := stack.pop_back() as Node
	if n == null or not is_instance_valid(n):
		return true
	for c in n.get_children():
		stack.append(c)
	var cs := n as CollisionShape3D
	if cs == null or cs.disabled or cs.shape == null:
		return true
	if not NavBaker._xz_contains(box, cs.global_position):
		return true
	if NavBaker._has_prefix(String(cs.get_parent().name), NAV_IGNORE_PREFIXES):
		return true
	_job.shapes.append(cs)
	return true


## Read one shape into the source - from the cache in two calls, or a chunk of its
## triangles at a time on a miss. False when the shape list is spent.
func _shape_step(source: NavigationMeshSourceGeometryData3D, deadline: int) -> bool:
	var shapes: Array = _job.shapes
	var si: int = int(_job.si)
	if si >= shapes.size():
		return false
	var cur: Dictionary = _job.cur
	if cur.is_empty():
		var cs := shapes[si] as CollisionShape3D
		# Re-checked here, not only in the filter: a segment that died between the two
		# phases must not bake solid.
		if cs == null or not is_instance_valid(cs) or cs.disabled or cs.shape == null:
			_job.si = si + 1
			return true
		var hit: Dictionary = _face_cache.get(cs.get_instance_id(), {})
		if not hit.is_empty() and hit.shape == cs.shape \
				and (hit.xf as Transform3D).is_equal_approx(cs.global_transform):
			_emit(source, hit.fwd, hit.flip)
			_job.added = int(_job.added) + 1
			_job.si = si + 1
			return true
		cur = _begin_shape(cs)
		if cur.is_empty():
			_job.si = si + 1
			return true
		_job.cur = cur
	if int(cur.i) < (cur.wv as PackedVector3Array).size() - 2:
		_cull_chunk(cur, deadline)
		return true
	_end_shape(source, cur)
	_job.cur = {}
	_job.added = int(_job.added) + 1
	_job.si = si + 1
	return true


## Maps a vertex to (y, y, y) / (z, z, z), so Array.min()/max() - which order Vector3
## lexicographically - order by that one component, in C++.
const Y_ONLY := Transform3D(Basis(Vector3.ZERO, Vector3.ONE, Vector3.ZERO), Vector3.ZERO)
const Z_ONLY := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ONE), Vector3.ZERO)


## [min, max] of one world axis over `wv` without a GDScript loop. `axis` is IDENTITY for
## x, Y_ONLY / Z_ONLY for the others.
static func _axis_span(wv: PackedVector3Array, axis: Transform3D) -> Vector2:
	var a: Array = Array(axis * wv)
	return Vector2(float((a.min() as Vector3).x), float((a.max() as Vector3).x))


static func _has_prefix(owner_name: String, prefixes: Array[String]) -> bool:
	for p in prefixes:
		if owner_name.begins_with(p):
			return true
	return false


## ONE get_faces() per shape, transformed to world space once, in C++. Decides whether the
## height rule has anything to do: it cuts triangles sitting entirely above the shape's
## own base + NAV_ROOF_HEIGHT_M, so a shape that never reaches its own roof line - a 1.2 m
## sandbag part, and most of the compound is parts - needs no triangle loop at all.
##
## Ground sheets are exempt from every cut: the mound spans the compound, so its crests sit
## far above its own lowest point and the height rule would amputate the berms.
func _begin_shape(cs: CollisionShape3D) -> Dictionary:
	var raw: PackedVector3Array = _shape_faces(cs.shape)
	if raw.is_empty():
		return {}
	var xf: Transform3D = cs.global_transform
	var owner_name: String = String(cs.get_parent().name)
	var wv: PackedVector3Array = xf * raw
	var ground: bool = NavBaker._has_prefix(owner_name, NAV_GROUND_PREFIXES)
	var listed: bool = NavBaker._has_prefix(owner_name, NAV_ROOF_CULL_PREFIXES)
	var concave := cs.shape as ConcavePolygonShape3D
	var ds: bool = concave != null and concave.backface_collision
	var span: Vector2 = NavBaker._axis_span(wv, Y_ONLY)
	var cut: float = span.x + NAV_ROOF_HEIGHT_M
	# The loop serves three readers: the listed roof cull, the flipped-face cull, and the
	# first-bake audit that counts what an unlisted structure WOULD have lost. count_only
	# is the audit alone - nothing downstream needs the kept faces.
	var loop: bool = span.y >= cut and not ground and (listed or ds or not _roof_audit_done)
	return {"cs": cs, "xf": xf, "name": owner_name, "wv": wv, "cut": cut, "base": span.x,
		"listed": listed, "ds": ds, "count_only": not (listed or ds), "loop": loop,
		"i": 0 if loop else wv.size(), "kept": PackedVector3Array(), "over": 0}


## The height rule, one budget-sized chunk of triangles. A triangle is roof only if ALL of
## it is above the cut - a wall crossing the line stays, or the structure loses the sides
## that hold its floor in.
func _cull_chunk(cur: Dictionary, deadline: int) -> void:
	var wv: PackedVector3Array = cur.wv
	var left: int = deadline - Time.get_ticks_usec()
	var n: int = clampi(int(float(left) / _tri_us), 32, 1 << 20)
	var start: int = int(cur.i)
	var i: int = start
	var end: int = mini(i + n * 3, wv.size() - 2)
	var cut: float = cur.cut
	var over: int = 0
	var t0: int = Time.get_ticks_usec()
	StallLedger.begin("nav.cull")
	if bool(cur.count_only):
		while i < end:
			if wv[i].y >= cut and wv[i + 1].y >= cut and wv[i + 2].y >= cut:
				over += 1
			i += 3
	else:
		var kept: PackedVector3Array = cur.kept
		cur.kept = PackedVector3Array()
		while i < end:
			if wv[i].y >= cut and wv[i + 1].y >= cut and wv[i + 2].y >= cut:
				over += 1
			else:
				kept.append(wv[i]); kept.append(wv[i + 1]); kept.append(wv[i + 2])
			i += 3
		cur.kept = kept
	StallLedger.end()
	var done: int = (i - start) / 3
	if done > 0:
		_tri_us = maxf(0.05, lerpf(_tri_us, float(Time.get_ticks_usec() - t0) / float(done), 0.5))
	cur.i = i
	cur.over = int(cur.over) + over


## THE GROUND WAS INVISIBLE TO THIS BAKE. The shipped GLB winds inward (physics is repaired
## via backface_collision - site_planner._force_backface_collision), but the bake reads
## WINDING, not that flag: a down-facing floor contributes no walkable surface, so the
## whole compound's mesh sat on the flat terrain seat ~1.7 m under the mound and routes
## tunnelled through berm volume. Where physics is double-sided, the nav source is too
## (Summoner decree 2026-08-13: "make the ai walk all the real geometry in the game").
## The flipped copy of a NON-ground shape still respects the roof line - a tower top was
## never walkable before the flip and must not become so because of it. reverse() on the
## whole array reverses every triangle's winding; the order of triangles is not read.
func _end_shape(source: NavigationMeshSourceGeometryData3D, cur: Dictionary) -> void:
	var cs: CollisionShape3D = cur.cs
	var wv: PackedVector3Array = cur.wv
	var listed: bool = cur.listed
	var culled: PackedVector3Array = cur.kept if (bool(cur.loop) and not bool(cur.count_only)) else wv
	var fwd: PackedVector3Array = culled if listed else wv
	var flip: PackedVector3Array = PackedVector3Array()
	if bool(cur.ds):
		StallLedger.begin("nav.flip")
		flip = culled.duplicate()
		flip.reverse()
		StallLedger.end()
	# ADR-042 clause 1: a prefix list must name what it MISSED. An unlisted structure whose
	# up-facing geometry reaches above its own roof line bakes that roof as walkable floor.
	# Counted on the first bake, reported once, never silently dropped - the flipped pass
	# culls universally, so this is the ONLY door a roof can still walk through. The roof
	# geometry does not change when a wall comes down, so the first answer stands.
	var over: int = int(cur.over)
	if over > 0 and not listed and not _roof_audit_done:
		_record_roof_miss(String(cur.name), over, float(cur.base), wv)
	_face_cache[cs.get_instance_id()] = {"xf": cur.xf, "shape": cs.shape, "fwd": fwd, "flip": flip}
	_emit(source, fwd, flip)


func _emit(source: NavigationMeshSourceGeometryData3D, fwd: PackedVector3Array,
		flip: PackedVector3Array) -> void:
	StallLedger.begin("nav.addfaces")
	source.add_faces(fwd, Transform3D.IDENTITY)
	if not flip.is_empty():
		source.add_faces(flip, Transform3D.IDENTITY)
	StallLedger.end()


func _finish_job() -> void:
	var nav: NavigationMesh = _job.nav
	var source: NavigationMeshSourceGeometryData3D = _job.source
	var box: AABB = _job.box
	var croot: Node3D = _job.croot
	var carved: int = int(_job.carved)
	_job = {}
	for id in _face_cache.keys():
		if not is_instance_id_valid(int(id)):
			_face_cache.erase(id)
	if _face_cache.size() != _cache_reported:
		_cache_reported = _face_cache.size()
		var verts: int = 0
		for e in _face_cache.values():
			verts += ((e as Dictionary).fwd as PackedVector3Array).size() \
				+ ((e as Dictionary).flip as PackedVector3Array).size()
		print("[NavBaker] face cache: %d shapes, %d world verts (%.1f MB)" % [
			_face_cache.size(), verts, float(verts) * 12.0 / 1048576.0])
	var region := NavigationRegion3D.new()
	region.name = "NavRegion_%d" % regions_live
	get_parent().add_child(region)
	region.global_transform = Transform3D.IDENTITY   # source geometry is world-space

	_active_mesh = nav
	_active_box = box
	_bake_start_ms = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav, source, _on_bake_done.bind(region, nav, box, carved, croot))


## Runs on the main thread. The ONLY place navigation_mesh is assigned.
func _on_bake_done(region: NavigationRegion3D, nav: NavigationMesh, box: AABB, carved: int,
		croot: Node3D = null) -> void:
	if not is_instance_valid(region):
		return
	var polys: int = nav.get_polygon_count()
	var bake_ms: int = Time.get_ticks_msec() - _bake_start_ms
	_total_ms += bake_ms
	var geom: String = ("%d colliders" % (-carved - 1)) if carved < 0 else "%d carved" % carved
	# climb is printed because it is QUANTISED to cell_height (floor(0.4/h)*h). With no
	# [navigation] section in project.godot it silently floors to 0.25 and every crater rim
	# becomes a cliff, with nothing in the log to say so.
	# ms is per bake and printed HERE because the queue-empty summary below can
	# race _process's _active_mesh poll and stay silent - this line is the one
	# reliable bake-cost instrument (breach re-bakes pay it mid-siege).
	print("[NavBaker] bake done: box=%s verts=%d polys=%d geom=%s cell=%.3f h=%.3f climb=%.2f ms=%d" % [
		box.size, nav.get_vertices().size(), polys, geom, nav.cell_size,
		nav.cell_height, nav.agent_max_climb, bake_ms])
	_report_roof_misses(nav)
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
## fb_int_ LEFT this list 2026-08-13, on his ruling. It was in NAV_IGNORE_PREFIXES but NOT in
## COL_NONE, so all 572 interior props were SOLID to physics and INVISIBLE to pathing: the
## navmesh said walkable, the collider said no. That contradiction is the stuck-NPC recipe -
## a man paths into a footlocker the mesh swore was floor and stands there. His ruling was
## that the furniture should be real in both, not absent from both.
const NAV_IGNORE_PREFIXES: Array[String] = ["fb_veg_", "door_", "fb_hootch_roof_"]


## The compound's ground-of-record sheets (the model IS the ground, ruling
## 2026-07-29). Same two families combat_manager treats as BLAST_PROOF - the
## coincidence is real but the meanings differ, so the list is declared here,
## not shared.
const NAV_GROUND_PREFIXES: Array[String] = ["fb_terrain_mound", "fb_berm_ring"]


## Structures whose ROOF bakes as walkable floor. Each is ONE mesh - roof and interior floor
## in the same shape - so a NAV_IGNORE_PREFIXES entry would delete the inside too, and the
## fighting bunkers now carry 37 work_bunker posts men have to reach. Measured 2026-08-12 in
## firebase_v3.2.blend, upward faces under agent_max_slope and >=1.9m above their own base:
## bunker_fighting 341.7 m2, bunker_mg 256.8, sleeping_bunker 192.1, gp_tent 154.0, mess 44.7.
##
## fb_tower is deliberately ABSENT: a tower is meant to be climbed, and its ladder_bottom /
## ladder_top markers exist precisely so men can stand the platform.
## medical_complex joined 2026-08-12 with the export that first shipped it: it is ONE mesh
## with ONE collider, so its roof bakes walkable exactly like the bunkers above.
##
## The chow hall (item 27, 2026-09-06) has no single leading token - it is FOUR separate
## collider owners (WB_chowhall_backwall, tent_frame_chowhall, tent_gable_chowhall,
## tent_roof_chowhall), so it takes four entries instead of one. Measured before this fix
## with tools/probe_chowhall_nav.gd: 16 of 48 work_chow*/work_eat/work_queue/work_cook
## markers were SEALED (no navmesh polygon within 1.6m), including ALL FIVE server-side
## posts and the whole stove (work_cook_004/_005/work_cook_range) - the uncut tent roof
## sat close enough over the counter and the range that Recast found no clearance to walk
## under it there. The open floor (queue, most seats) already had clearance and was fine.
const NAV_ROOF_CULL_PREFIXES: Array[String] = [
	"fb_gp_tent", "fb_mess", "fb_bunker_mg", "fb_bunker_fighting", "fb_sleeping_bunker",
	"medical_complex", "WB_chowhall_backwall", "tent_frame_chowhall", "tent_gable_chowhall",
	"tent_roof_chowhall",
	# Added 2026-09-09 after asking the BAKED MESH, not the triangle count: the TOC baked 17
	# walkable polygons above its own roof line and each of the five latrines two or three.
	# WB_bunker_* is the same naming miss as fb_hwall - a differently-named twin of a family
	# already on this list.
	"fb_latrine_i", "fb_toc_i", "WB_bunker_",
]

## DELIBERATELY NOT CULLED, so nobody "fixes" them later: fb_tower_i (the towers are fighting
## positions and Ladder.build_from_markers builds the way up - a man is MEANT to stand there)
## and fb_bunker_steps (steps are a floor). Both show up in the roof report and both are
## correct. fb_supply_dump_i and fb_water_point_i were on the suspect list and produce no
## uncut roof geometry at all.
## How far above a structure's own base a surface stops being its floor and starts being its
## roof. Bunker interiors sit ~0.97m BELOW grade and their roofs ~3.2m above it, so 1.9m
## separates the two with room on both sides.
const NAV_ROOF_HEIGHT_M: float = 1.9
## Widest footprint the roof check will judge. Above this the owner is a ring, a trigger
## volume or the ground itself, and its bounding box says nothing about a roof.
const ROOF_JUDGE_MAX_M: float = 40.0


## Ran once, on the first bake only - see the gate in _begin_shape / _end_shape.
var _roof_audit_done: bool = false

func _record_roof_miss(owner_name: String, over: int, base_y: float,
		wv: PackedVector3Array) -> void:
	var rec: Dictionary = _roof_misses.get(owner_name, {}) as Dictionary
	var xs: Vector2 = NavBaker._axis_span(wv, Transform3D.IDENTITY)
	var zs: Vector2 = NavBaker._axis_span(wv, Z_ONLY)
	var lo := Vector2(xs.x, zs.x)
	var hi := Vector2(xs.y, zs.y)
	rec["tris"] = int(rec.get("tris", 0)) + over
	rec["cut_y"] = minf(float(rec.get("cut_y", INF)), base_y + NAV_ROOF_HEIGHT_M)
	rec["lo"] = Vector2(minf(float((rec.get("lo", lo) as Vector2).x), lo.x),
		minf(float((rec.get("lo", lo) as Vector2).y), lo.y))
	rec["hi"] = Vector2(maxf(float((rec.get("hi", hi) as Vector2).x), hi.x),
		maxf(float((rec.get("hi", hi) as Vector2).y), hi.y))
	_roof_misses[owner_name] = rec


## Owner NAME -> {tris, cut_y, lo, hi} for the report below. Keyed by name, not prefix: the
## name is what a fix has to be written against.
var _roof_misses: Dictionary = {}


## Did any of those uncut roofs actually become FLOOR? Asked of the finished mesh, because
## an uncut triangle is only a candidate - Recast decides. A structure with polygons above
## its own roof line is a roof a man can be pathed onto deliberately, which is a different
## defect from the top-down re-seat that put him there by accident.
func _report_roof_misses(nav: NavigationMesh = null) -> void:
	if _roof_audit_done:
		return
	_roof_audit_done = true
	if _roof_misses.is_empty():
		print("[NavBaker] roof cull: every structure with geometry above its roof line is covered")
		return
	var names: Array = _roof_misses.keys()
	names.sort()
	var total: int = 0
	var walkable: PackedStringArray = PackedStringArray()
	var too_big: PackedStringArray = PackedStringArray()
	var verts: PackedVector3Array = nav.get_vertices() if nav != null else PackedVector3Array()
	for k in names:
		var rec: Dictionary = _roof_misses[k]
		total += int(rec.get("tris", 0))
		if nav == null or verts.is_empty():
			continue
		var lo: Vector2 = rec.get("lo", Vector2.ZERO)
		var hi: Vector2 = rec.get("hi", Vector2.ZERO)
		var cut: float = float(rec.get("cut_y", INF))
		# A BOUNDING BOX IS ONLY HONEST OVER A BUILDING. The wire ring and the compound-wide
		# trigger volumes have footprints tens of metres across, so every polygon in the
		# compound above their cut line falls inside the box and the count is meaningless -
		# measured 4,871 and 3,181 on the first pass. Judge buildings; name the rest as
		# unjudgeable rather than reporting a number that is not about a roof.
		if hi.x - lo.x > ROOF_JUDGE_MAX_M or hi.y - lo.y > ROOF_JUDGE_MAX_M:
			too_big.append("%s (%.0fx%.0fm)" % [String(k), hi.x - lo.x, hi.y - lo.y])
			continue
		var on_roof: int = 0
		for pi in range(nav.get_polygon_count()):
			var idx: PackedInt32Array = nav.get_polygon(pi)
			var above: bool = true
			for i in idx:
				var v: Vector3 = verts[i]
				if v.y < cut or v.x < lo.x or v.x > hi.x or v.z < lo.y or v.z > hi.y:
					above = false
					break
			if above:
				on_roof += 1
		if on_roof > 0:
			walkable.append("%s x%d" % [String(k), on_roof])
	print("[NavBaker] roof cull MISSES: %d structure(s), %d uncut roof triangle(s) - %s"
		% [names.size(), total, ", ".join(names)])
	if nav == null:
		pass
	elif walkable.is_empty():
		print("[NavBaker] ...and NONE of them baked a walkable polygon above its roof line")
	else:
		push_warning("[NAVROOF] %d structure(s) have WALKABLE navmesh on the roof: %s"
			% [walkable.size(), ", ".join(walkable)])
	if not too_big.is_empty():
		print("[NavBaker] roof check skipped (footprint too wide to judge by box): %s"
			% ", ".join(too_big))
	_roof_misses.clear()


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
## Enterable (nav_trimesh) models are not here: their own colliders were walked in phase 1.
func _add_structures(source: NavigationMeshSourceGeometryData3D, box: AABB) -> int:
	var carved: int = 0
	for n in get_tree().get_nodes_in_group("nav_blockers"):
		var body := n as Node3D
		if body == null or not is_instance_valid(body):
			continue
		if bool(body.get_meta("nav_trimesh", false)):
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
