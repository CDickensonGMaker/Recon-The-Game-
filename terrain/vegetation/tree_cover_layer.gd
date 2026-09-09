class_name TreeCoverLayer
extends Node3D

## Individual-species vegetation instancing + trunk collision for the live AO.
##
## THE CANOPY IS REAL 3D AT EVERY DISTANCE (Summoner, 2026-09-08: "no more 2d terrain
## cards, or 3d plane spliced cards or whatever. all 3d blender models only in game",
## sharpened to "i do not want the old 2d made 3d terrain art pieces"). Barbwire is the
## single exemption and it does not live here. ADR-001 Amendment A revoked the sprite
## carve-out; ADR-026 Amendment D killed the canopy card atlas.
##
## WHAT THIS USED TO DO, and why it is gone: 0-65 m drew the real species GLB, 65-350 m
## swapped it for a 4-triangle impostor CARD out of assets/world/vegetation/cards/. That
## boundary was a HARD SNAP (see _multimesh) and it changed DIMENSION - a solid plant
## became a flat picture in one frame. That is the popping Caleb reported. There is now
## ONE MultiMeshInstance3D per (species x 64 m bucket) drawing the real model from 0 to
## view_distance, so there is no 65 m boundary left to pop across, and HALF the canopy
## nodes and draw calls of the old two-ring build.
##
## THE FAR RING IS NOT FULL DETAIL. Every vegetation GLB imports with
## meshes/generate_lods=true, so each ArrayMesh carries an import-generated LOD ladder and
## the renderer picks a level by screen coverage (measured 2026-09-09 by
## tools/probe_far_ring_meshes.gd: broadleaf_a 752 tris -> 12, bamboo_a 830 -> 86). Two
## live species, rice_a and elephant_grass_b, generated NO ladder and draw full detail at
## every range - they are 84 and 160 tris, which is why that is tolerated and recorded
## rather than papered over.
##
## NO QUAD MAY COME BACK AS AN OPTIMISATION. If a distance cannot afford these meshes the
## answer is a lower-poly real MESH.
##
## project.godot:331 `mesh_lod/lod_change/threshold_pixels=2.0` is now LOAD-BEARING for the
## whole canopy, where before it only touched the 0-65 m band. Godot's default is 1.0; 2.0
## swaps a level at twice the screen error, which is the aggressive end and the first place
## to look if the far ring is seen changing shape. Lowering it trades frames for smoothness
## and is the Summoner's call, not a silent tweak.
##
## Trunk COLLISION comes from a player-keyed pooled body ring (RING_RADIUS) so the player
## can physically hide behind cover (Pillar 3) without the AO holding thousands of
## resident StaticBody3D.

const SOLID_DIR := "res://assets/world/vegetation/"

## Cover-givers ONLY: a solid a bullet stops and a body hides behind. Value = trunk
## collider radius (m). Everything NOT listed (grass, fern, vine, moss, rice, bush,
## sapling, liana) is CONCEALMENT - it cuts sight via the veg grid, never a collider.
const COVER_TRUNK := {
	"broadleaf_a": 0.30, "broadleaf_b": 0.30, "broadleaf_c": 0.30,
	"banana_a": 0.26, "banana_b": 0.26,
	"bamboo_a": 0.34, "bamboo_b": 0.34, "bamboo_c": 0.34,
	"jungle_palm_a1": 0.30, "jungle_palm_a2": 0.30, "jungle_palm_a3": 0.30,
	"jungle_palm_b1": 0.30, "jungle_palm_b2": 0.30, "jungle_palm_b3": 0.30,
	"fallen_log_a": 0.45, "fallen_log_b": 0.45, "tree_stump": 0.34,
}

## World-geometry layer: bullets and the player capsule test this, so a trunk stops both.
const COVER_COLLISION_LAYER: int = 1
const TRUNK_HEIGHT: float = 3.0

## Collision ring (Caleb's ruling 2026-07-25): "the physics should only apply to trees
## within a 70m radius of the player." Solid render ring is 65m, so collision always
## covers what looks solid.
const RING_RADIUS := 70.0
## Measured worst 70m-ring demand (seed 47225, whole AO, mission density boost applied):
## 919 candidates. 1280 = ~40% headroom.
const POOL_MAX: int = 1280
const RING_INTERVAL: float = 0.25
const RING_MOVE_EPS: float = 2.0
const PARK_POS := Vector3(0.0, -4000.0, 0.0)

## No longer a RENDER boundary - kept as the documented radius the trunk-collider ring
## must cover. RING_RADIUS (70 m) still exceeds it, so anything close enough to hide
## behind is bodied.
@export var near_distance: float = 65.0
@export var view_distance: float = 350.0  ## whole canopy ring (fog transmittance <=10%)

## visibility_range is per-NODE against the transformed AABB (godot#79471 - the
## docs say origin and are wrong). Chunk-sized nodes quantize both rings by
## +/-181m - that WAS the invisible-jungle bug. 64m buckets bound the error to
## +/-45m without exploding the node count.
const BUCKET: float = 64.0
const RANGE_MARGIN: float = 8.0   ## hysteresis on the hard PS2 snap

var _solid_mesh: Dictionary = {}   ## name -> Mesh (the real model; there is no second tier)
var _chunk_nodes: Dictionary = {}  ## coord -> Array[Node] (MMIs)
var _chunk_scatter: Dictionary = {}  ## coord -> Array (the scatter as built, for single-instance removal)
## coord -> PackedVector3Array of placed WORLD origins (probe truth; MultiMesh
## transform read-back is blind headless in this build)
var chunk_origins: Dictionary = {}

## coord -> {positions: PackedVector3Array, radii: PackedFloat32Array, bounds: Rect2 (XZ)}
## for COVER_TRUNK instances - pure candidate data, bodied only inside the ring.
var _chunk_trunks: Dictionary = {}
var _chunk_bodies: Dictionary = {}         ## coord -> Dictionary(candidate idx -> StaticBody3D)
var _pool: Array[StaticBody3D] = []
var _free_bodies: Array[StaticBody3D] = []
var _shape_by_radius: Dictionary = {}      ## radius -> shared CylinderShape3D
## Vector3.INF = unset -> ring keys off GameManager.player; no player = no bodies.
var ring_center_override := Vector3.INF
var _last_center := Vector3.INF
var _ring_elapsed: float = 0.0
var _pool_starved: bool = false


## THREAT ZONES (decree 2026-08-04: "anything with explosives / heavy ordnance is
## being called out to the tree"). Ordnance promotes trunk colliders wherever it
## flies, so a contact fuze has something to strike beyond the player ring. A zone
## is just another reason a candidate is wanted - same pool, same park path, so
## expiry parks bodies through the existing delta pass and nothing can leak.
const ZONE_MAX: int = 16
const ZONE_DEDUPE_M: float = 4.0
var _zones: Array[Dictionary] = []   ## {a: Vector3, b: Vector3, r: float, until_ms: int}


static func threat_zone(tree: SceneTree, center: Vector3, radius: float, duration_s: float) -> void:
	threat_corridor(tree, center, center, radius, duration_s)


static func threat_corridor(tree: SceneTree, from: Vector3, to: Vector3,
		half_width: float, duration_s: float) -> void:
	if tree == null:
		return
	for layer in tree.get_nodes_in_group("tree_cover"):
		(layer as TreeCoverLayer)._add_zone(from, to, half_width, duration_s)


func _add_zone(a: Vector3, b: Vector3, r: float, duration_s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(duration_s * 1000.0)
	for z: Dictionary in _zones:
		if (z["a"] as Vector3).distance_to(a) < ZONE_DEDUPE_M \
				and (z["b"] as Vector3).distance_to(b) < ZONE_DEDUPE_M:
			z["until_ms"] = maxi(int(z["until_ms"]), until)
			z["r"] = maxf(float(z["r"]), r)
			return
	if _zones.size() >= ZONE_MAX:
		# Evict the soonest-to-expire, never the oldest-added: shell-corridor churn
		# must not knock a live dispatch footprint out mid-barrage.
		var evict: int = 0
		for i in range(1, _zones.size()):
			if int(_zones[i]["until_ms"]) < int(_zones[evict]["until_ms"]):
				evict = i
		_zones.remove_at(evict)
	_zones.append({"a": a, "b": b, "r": r, "until_ms": until})
	_update_ring(_resolve_center())


func _prune_zones() -> void:
	var now: int = Time.get_ticks_msec()
	var i: int = _zones.size() - 1
	while i >= 0:
		if int(_zones[i]["until_ms"]) <= now:
			_zones.remove_at(i)
		i -= 1


## XZ distance from p to the zone's segment <= its radius.
func _zone_wants(p: Vector3) -> bool:
	var p2 := Vector2(p.x, p.z)
	for z: Dictionary in _zones:
		var a2 := Vector2((z["a"] as Vector3).x, (z["a"] as Vector3).z)
		var b2 := Vector2((z["b"] as Vector3).x, (z["b"] as Vector3).z)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p2, a2, b2)
		if p2.distance_to(closest) <= float(z["r"]):
			return true
	return false


func _zone_overlaps(bounds: Rect2) -> bool:
	for z: Dictionary in _zones:
		var a2 := Vector2((z["a"] as Vector3).x, (z["a"] as Vector3).z)
		var b2 := Vector2((z["b"] as Vector3).x, (z["b"] as Vector3).z)
		var grown: Rect2 = bounds.grow(float(z["r"]))
		if grown.has_point(a2) or grown.has_point(b2) \
				or grown.intersects(Rect2(a2, Vector2.ZERO).expand(b2)):
			return true
	return false


func _ready() -> void:
	add_to_group("tree_cover")
	for a: String in OS.get_cmdline_user_args():
		# --card-dist= is kept as the spelling the bench scripts already pass; what it
		# moves is the canopy draw radius, and there are no cards left behind it.
		if a.begins_with("--card-dist=") or a.begins_with("--canopy-dist="):
			view_distance = maxf(near_distance, float(a.split("=")[1]))
			print("[TreeCover] canopy draw radius lever: view_distance=%.0f" % view_distance)


## Load the real model for each species name (idempotent). A species with no GLB is not
## drawn at all - it is never substituted with a plane, and the gap is named out loud.
func load_species(names: Array) -> void:
	for n: String in names:
		if not _solid_mesh.has(n):
			var sm: Mesh = _extract_mesh(SOLID_DIR + n + ".glb")
			if sm != null:
				_solid_mesh[n] = sm
			else:
				push_warning("[TreeCover] no 3D model for species '%s' - NOT DRAWN" % n)
	_report_cover_split(names)


## ADR-042 clause 1. COVER_TRUNK is a hand-maintained allow-list keyed on species NAME, and
## a name it has never heard of gets no collider at all - the player walks through the tree.
## The default here is the SAFE one (concealment, not bulletproof), so this reports rather
## than warns; what it must never do is stay silent about which half a species landed in.
func _report_cover_split(names: Array) -> void:
	var cover: PackedStringArray = PackedStringArray()
	var conceal: PackedStringArray = PackedStringArray()
	for n: String in names:
		if float(COVER_TRUNK.get(n, 0.0)) > 0.0:
			cover.append(n)
		else:
			conceal.append(n)
	cover.sort()
	conceal.sort()
	print("[TreeCover] %d species give COVER (trunk collider): %s | %d give CONCEALMENT only: %s"
		% [cover.size(), ", ".join(cover), conceal.size(), ", ".join(conceal)])


## The near-solid mesh for a species, for a one-off visual (the felling swap).
func solid_mesh_for(species: String) -> Mesh:
	return _solid_mesh.get(species) as Mesh


## scatter: Array of {name: String, xf: Transform3D}. Builds, for this chunk:
##   - ONE MultiMesh per (species, 64 m bucket) drawing the real model 0..view_distance
##   - trunk collider CANDIDATES per COVER instance (bodied by the ring, not here)
func generate_for_chunk(coord: Vector2i, scatter: Array) -> void:
	clear_chunk(coord)
	_chunk_scatter[coord] = scatter
	TreeBreakSystem.register_chunk(self, coord, scatter)
	var groups: Dictionary = {}   ## [name, bucket_x, bucket_z] -> Array[Transform3D]
	var origins := PackedVector3Array()
	var trunk_pos := PackedVector3Array()
	var trunk_rad := PackedFloat32Array()
	var trunk_hgt := PackedFloat32Array()
	for e: Dictionary in scatter:
		var nm: String = String(e.get("name", ""))
		if not _solid_mesh.has(nm):
			continue
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		var key: Array = [nm, int(floor(xf.origin.x / BUCKET)), int(floor(xf.origin.z / BUCKET))]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		origins.append(xf.origin)
		# Collider per ENTRY, not per species: a blast-shortened snag and a lying log are
		# the same species as the tree they came from and must not inherit its full post.
		# trunk_r/trunk_h ride on the scatter entry; a plain plant falls back to the table.
		var r: float = float(e.get("trunk_r", COVER_TRUNK.get(nm, 0.0)))
		if r > 0.0:
			trunk_pos.append(xf.origin)
			trunk_rad.append(r)
			trunk_hgt.append(float(e.get("trunk_h", TRUNK_HEIGHT)))

	var nodes: Array[Node] = []
	for key: Array in groups:
		var nm: String = key[0]
		var xforms: Array = groups[key]
		# Bucket node origin = member centroid, so the node's transformed AABB
		# (what visibility_range actually measures) hugs the real instances.
		var centroid := Vector3.ZERO
		for xf: Transform3D in xforms:
			centroid += xf.origin
		centroid /= float(xforms.size())
		var local: Array = []
		for xf: Transform3D in xforms:
			local.append(Transform3D(xf.basis, xf.origin - centroid))
		# The real model, all the way out. One node, one mesh, no boundary to pop across.
		nodes.append(_multimesh(_solid_mesh[nm], local, 0.0, view_distance, centroid))
	for node: Node in nodes:
		add_child(node)
	_chunk_nodes[coord] = nodes
	chunk_origins[coord] = origins
	if trunk_pos.size() > 0:
		var bounds := Rect2(Vector2(trunk_pos[0].x, trunk_pos[0].z), Vector2.ZERO)
		for p: Vector3 in trunk_pos:
			bounds = bounds.expand(Vector2(p.x, p.z))
		_chunk_trunks[coord] = {"positions": trunk_pos, "radii": trunk_rad,
			"heights": trunk_hgt, "bounds": bounds}
	# Same-frame refresh so a blast rebuild never leaves in-ring trunks bodiless.
	_update_ring(_resolve_center())


func clear_chunk(coord: Vector2i) -> void:
	chunk_origins.erase(coord)
	_chunk_trunks.erase(coord)
	_chunk_scatter.erase(coord)
	TreeBreakSystem.unregister_chunk(self, coord)
	_release_chunk(coord)
	if not _chunk_nodes.has(coord):
		return
	for node: Node in _chunk_nodes[coord]:
		if is_instance_valid(node):
			node.queue_free()
	_chunk_nodes.erase(coord)


func clear_all() -> void:
	for coord: Vector2i in _chunk_nodes.keys():
		clear_chunk(coord)


func _exit_tree() -> void:
	TreeBreakSystem.unregister_layer(self)


## Drop specific instances (a promoted tree's standing original) and rebuild the chunk
## from its stored scatter. TreeBreakSystem is the only caller.
func remove_scatter_entries(coord: Vector2i, indices: Array) -> void:
	if not _chunk_scatter.has(coord):
		return
	var old: Array = _chunk_scatter[coord]
	var kept: Array = []
	for i in old.size():
		if not indices.has(i):
			kept.append(old[i])
	generate_for_chunk(coord, kept)


## Assigned pool bodies right now (cover exists inside the ring). For the probe.
func collider_count() -> int:
	return _pool.size() - _free_bodies.size()


func _physics_process(delta: float) -> void:
	_ring_elapsed += delta
	var center: Vector3 = _resolve_center()
	var moved: bool = center != _last_center and (
		center == Vector3.INF or _last_center == Vector3.INF
		or (Vector2(center.x, center.z) - Vector2(_last_center.x, _last_center.z)).length_squared()
			> RING_MOVE_EPS * RING_MOVE_EPS)
	if _ring_elapsed < RING_INTERVAL and not moved:
		return
	StallLedger.begin("veg.trunk_ring")
	_update_ring(center)
	StallLedger.end()


func _resolve_center() -> Vector3:
	if ring_center_override != Vector3.INF:
		return ring_center_override
	var p: Node = GameManager.player
	if is_instance_valid(p) and p is Node3D and (p as Node3D).is_inside_tree():
		return (p as Node3D).global_position
	return Vector3.INF


## Delta pass: release bodies whose candidate left the ring AND every threat zone,
## body candidates that entered either. Nearest-first only when demand exceeds the
## pool (logged once).
func _update_ring(center: Vector3) -> void:
	_last_center = center
	_ring_elapsed = 0.0
	_prune_zones()
	if center == Vector3.INF and _zones.is_empty():
		if collider_count() > 0:
			for coord: Vector2i in _chunk_bodies.keys():
				_release_chunk(coord)
		return
	var has_player: bool = center != Vector3.INF
	var c2 := Vector2(center.x, center.z) if has_player else Vector2.ZERO
	var r2: float = RING_RADIUS * RING_RADIUS
	var wanted: Array = []   ## [dist2, coord, idx] per wanted candidate without a body
	for coord: Vector2i in _chunk_trunks:
		var data: Dictionary = _chunk_trunks[coord]
		var assigned: Dictionary = _chunk_bodies.get(coord, {})
		var near_player: bool = has_player \
			and (data["bounds"] as Rect2).grow(RING_RADIUS).has_point(c2)
		var near_zone: bool = not _zones.is_empty() and _zone_overlaps(data["bounds"] as Rect2)
		if not near_player and not near_zone:
			if not assigned.is_empty():
				_release_chunk(coord)
			continue
		var positions: PackedVector3Array = data["positions"]
		for i: int in positions.size():
			var p: Vector3 = positions[i]
			var d2: float = (Vector2(p.x, p.z) - c2).length_squared() if near_player else 1e18
			var want: bool = d2 <= r2 or (near_zone and _zone_wants(p))
			if want:
				if not assigned.has(i):
					wanted.append([d2, coord, i])
			elif assigned.has(i):
				_park_body(assigned[i])
				assigned.erase(i)
	var capacity: int = _free_bodies.size() + (POOL_MAX - _pool.size())
	if wanted.size() > capacity:
		if not _pool_starved:
			_pool_starved = true
			push_warning("[TreeCover] ring demand %d exceeds POOL_MAX %d - bodying nearest only"
					% [wanted.size(), POOL_MAX])
		wanted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for w: Array in wanted:
		var body: StaticBody3D = _acquire_body()
		if body == null:
			break
		var coord: Vector2i = w[1]
		var idx: int = w[2]
		var data: Dictionary = _chunk_trunks[coord]
		_place_body(body, (data["positions"] as PackedVector3Array)[idx],
				(data["radii"] as PackedFloat32Array)[idx],
				(data["heights"] as PackedFloat32Array)[idx])
		if not _chunk_bodies.has(coord):
			_chunk_bodies[coord] = {}
		(_chunk_bodies[coord] as Dictionary)[idx] = body


func _release_chunk(coord: Vector2i) -> void:
	if not _chunk_bodies.has(coord):
		return
	for body: StaticBody3D in (_chunk_bodies[coord] as Dictionary).values():
		_park_body(body)
	_chunk_bodies.erase(coord)


func _acquire_body() -> StaticBody3D:
	if not _free_bodies.is_empty():
		var b: StaticBody3D = _free_bodies.pop_back()
		return b
	if _pool.size() >= POOL_MAX:
		return null
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0   ## static cover reacts to nothing; things test IT
	body.add_to_group("hard_surface")   ## solid timber: rounds stop, wood FX resolve
	body.add_child(CollisionShape3D.new())
	add_child(body)
	body.position = PARK_POS
	_pool.append(body)
	return body


func _place_body(body: StaticBody3D, pos: Vector3, radius: float, height: float = TRUNK_HEIGHT) -> void:
	var h: float = maxf(0.2, height)
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	shape.shape = _shape_for(radius, h)
	body.position = pos + Vector3(0.0, h * 0.5, 0.0)
	body.collision_layer = COVER_COLLISION_LAYER


func _park_body(body: StaticBody3D) -> void:
	body.collision_layer = 0
	body.position = PARK_POS
	_free_bodies.append(body)


## One shared CylinderShape3D per distinct radius+height pair. Snags and lying logs add
## a handful of heights, not one shape per instance.
func _shape_for(radius: float, height: float = TRUNK_HEIGHT) -> CylinderShape3D:
	var key: Vector2 = Vector2(snappedf(radius, 0.001), snappedf(height, 0.05))
	if not _shape_by_radius.has(key):
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		_shape_by_radius[key] = cyl
	return _shape_by_radius[key]


func _multimesh(mesh: Mesh, xforms: Array, vis_begin: float, vis_end: float,
		origin: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = origin
	# Shadow casting stays ON across the whole ring. The shipped world sun has shadows off
	# (game_world.gd:65), so this is inert today; if directional shadows are ever turned
	# back on, directional_shadow_max_distance is the engine's own bound on the cost - not
	# a per-node cutoff that would make distant trees stop casting mid-view.
	if vis_begin > 0.0:
		mmi.visibility_range_begin = vis_begin
		mmi.visibility_range_begin_margin = RANGE_MARGIN
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = RANGE_MARGIN
	# Hard cut at view_distance (ADR-026), NEVER a fade: VISIBILITY_RANGE_FADE_SELF
	# alpha-dithers the mesh across the fade margin, so foliage at the boundary renders
	# SEE-THROUGH. That was the old "opacity" bug. With the card ring retired there is only
	# ONE boundary left - the far edge of the canopy, out in the fog.
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return mmi


## First MeshInstance3D's mesh (with its own materials) from a GLB; null if absent.
func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var mesh: Mesh = MaterialBudget.foliage(_first_mesh(root))
	root.queue_free()
	return mesh


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for c: Node in node.get_children():
		var m: Mesh = _first_mesh(c)
		if m != null:
			return m
	return null
