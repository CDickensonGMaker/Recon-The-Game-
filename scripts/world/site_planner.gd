## site_planner.gd - Finds valid flat sites via GameplayGrid and stamps
## village / firebase / LZ layouts onto generated terrain (NS06).
class_name SitePlanner
extends RefCounted

const MARGIN: float = 100.0  ## keep sites away from AO edges
const MAX_SLOPE: float = 0.25
const SITE_ATTEMPTS: int = 300

var _grid: GameplayGrid
var _terrain: TerrainManager
var _veg: VegetationManager
var _parent: Node3D
var placed_sites: Array[Dictionary] = []
var _reserved: Array[Vector3] = []  ## centers returned by find_site, pre-stamp
## World-space rect of the placed main firebase; band-mode find_site rejects
## points inside it (grown by FSB_SITE_CLEARANCE).
var _fsb_rect := Rect2()


func _init(grid: GameplayGrid, terrain: TerrainManager, veg: VegetationManager, parent: Node3D) -> void:
	_grid = grid
	_terrain = terrain
	_veg = veg
	_parent = parent


## Find a site center: footprint circle must be non-water, non-cliff, low slope,
## and >= min_separation from every already-placed site, _reserved point, and any
## point in extra_reject. extra_reject is used by callers that need to keep sites
## away from a class of terrain (e.g. paddy centroids for firebase placement).
## Band mode (band_max > 0): sample the annulus [band_min, band_max] around
## band_anchor instead of the whole map, and never inside the firebase rect —
## the open-patrol density bands (villages 280-450m etc, measured from the gate).
## Returns Vector3.ZERO on failure.
func find_site(rng: RandomNumberGenerator, radius: float, min_separation: float = 200.0,
		extra_reject: Array[Vector3] = [], band_anchor := Vector3.ZERO,
		band_min: float = 0.0, band_max: float = 0.0) -> Vector3:
	var map_size: float = _terrain.map_size
	var best := Vector3.ZERO
	var best_score: float = -1.0
	for _i in range(SITE_ATTEMPTS):
		var p: Vector3
		if band_max > 0.0:
			var a: float = rng.randf() * TAU
			var r: float = rng.randf_range(band_min, band_max)
			p = band_anchor + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if p.x < MARGIN or p.x > map_size - MARGIN or p.z < MARGIN or p.z > map_size - MARGIN:
				continue
			if _fsb_rect.size != Vector2.ZERO \
					and _fsb_rect.grow(FSB_SITE_CLEARANCE).has_point(Vector2(p.x, p.z)):
				continue
		else:
			p = Vector3(
				rng.randf_range(MARGIN, map_size - MARGIN),
				0.0,
				rng.randf_range(MARGIN, map_size - MARGIN)
			)
		if not _footprint_valid(p, radius):
			continue
		var sep_ok := true
		for site in placed_sites:
			if p.distance_to(site.center) < min_separation:
				sep_ok = false
				break
		if sep_ok:
			for r in _reserved:
				if p.distance_to(r) < min_separation:
					sep_ok = false
					break
		if sep_ok:
			for er in extra_reject:
				if p.distance_to(er) < min_separation:
					sep_ok = false
					break
		if not sep_ok:
			continue
		var score: float = 1.0 - _grid.get_slope(p)
		if score > best_score:
			best_score = score
			best = p
			if best_score > 0.95:
				break
	if best != Vector3.ZERO:
		_reserved.append(best)
	return best


func _footprint_valid(center: Vector3, radius: float) -> bool:
	# Sample center + 8 ring points + 4 half-ring points.
	var samples: Array[Vector3] = [center]
	for i in range(16):
		var a := TAU * float(i) / 16.0
		samples.append(center + Vector3(cos(a), 0, sin(a)) * radius)
	for i in range(8):
		var a := TAU * float(i) / 8.0 + 0.35
		samples.append(center + Vector3(cos(a), 0, sin(a)) * radius * 0.55)
	for s in samples:
		if _grid.is_water(s):
			return false
		var t: int = _grid.get_terrain_type(s)
		if t == GameplayGrid.TerrainType.WATER or t == GameplayGrid.TerrainType.CLIFF:
			return false
		if _grid.get_slope(s) > MAX_SLOPE:
			return false
	return true


## Flatten + clear vegetation for a pad (LZ / firebase ground).
func clear_and_flatten(center: Vector3, radius: float) -> void:
	var zone_id: int = ClearingSystem.create_zone(center, radius)
	ClearingSystem.set_zone_stage(zone_id, ClearingSystem.ClearingStage.CLEARED)
	if _veg and _veg.has_method("clear_area"):
		_veg.clear_area(center, radius, _terrain.chunk_size, _terrain.heightmap)
	if _grid:
		_grid.update_region(center, radius)


## SOFT COVER: what lead goes THROUGH. In this war most "walls" are thatch,
## bamboo and palm leaf - concealment, not cover - and a hooch wall stopping a
## 7.62 was a lie the physics told. Bunkers, rock and vehicles are NOT on this
## list: those actually stop a round. (00 buck - nine 0.33in balls - punches
## brush better than anything else a man can carry, which is the historical
## reason a point man in the bush carried a 12-gauge.)
const _SOFT_NAME_HINTS: Array[String] = ["hooch", "hut", "thatch", "bamboo",
	"fence", "shack", "lean_to", "leanto", "basket", "drying", "rack", "hedge",
	"brush", "crate", "cart"]


static func _is_soft_cover(model_name: String) -> bool:
	var n: String = model_name.to_lower()
	for h in _SOFT_NAME_HINTS:
		if n.contains(h):
			return true
	return false


## Place one structure: StaticBody3D root (layer 1) + GLB visual + authored box.
func place_structure(model_path: String, world_pos: Vector3, rotation_deg: float) -> Node3D:
	var model_name := model_path.get_file().get_basename()
	var entry: Dictionary = CollisionTable.get_entry(model_name)
	var body := StaticBody3D.new()
	body.name = model_name
	# The tree auto-renames duplicate names; anything reading identity back off a
	# node must use this meta, never .name (CollisionTable lookups break silently).
	body.set_meta("model_name", model_name)
	body.collision_layer = 1
	body.collision_mask = 0
	# MATERIAL IS AUTHORED DATA, NOT A GUESS ABOUT THE FILENAME (war room 2026-07-12).
	# CollisionTable.is_soft() is the one authority, and it push_warning()s loudly for
	# any model it has no material for - so a gap is NOISY instead of silently making
	# a bunker shootable through because its name contains "rack".
	if CollisionTable.is_soft(model_name):
		body.add_to_group("soft_cover")   # rounds punch through it (x0.8, soft_left=2)
	else:
		body.add_to_group("hard_surface")  # stops the round - and finally SPARKS
	var scene: PackedScene = load(model_path)
	if scene:
		var visual := scene.instantiate()
		var s: float = float(entry.scale)
		if s != 1.0:
			visual.scale = Vector3(s, s, s)
		body.add_child(visual)
		_apply_visibility_range(visual)  # R92: cull distant structure geometry
	var box_size: Vector3 = entry.box
	if box_size.length() > 0.01:
		# NavBaker carves these out of the site navmesh. punji_trap has a zero box
		# and is correctly skipped by this same guard.
		body.add_to_group("nav_blockers")
		body.set_meta("nav_box", box_size)
		# mesh: true -> the GLB carries -col trimesh nodes (pow_cage, ruins). The
		# authored box would double the collision AND block doorways/breaches, so
		# skip it; the box entry above still drives the nav carve. [bead sjup]
		if not bool(entry.get("mesh", false)):
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = box_size
			shape.shape = box
			shape.position = Vector3(0, float(entry.y_offset), 0)
			body.add_child(shape)
	_parent.add_child(body)
	var ground_y: float = _terrain.get_height_at(world_pos)
	body.global_position = Vector3(world_pos.x, ground_y, world_pos.z)
	body.rotation_degrees = Vector3(0, rotation_deg, 0)
	if model_name.contains("tunnel"):
		body.add_to_group("tunnel_entrances")  # W51
	return body


## R92: fade structure geometry out beyond ~230m - a 1.28km AO has dozens of
## these live at once, and most are never close enough to matter.
const STRUCTURE_VISIBILITY_END: float = 230.0
const STRUCTURE_VISIBILITY_MARGIN: float = 25.0


func _apply_visibility_range(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.visibility_range_end = STRUCTURE_VISIBILITY_END
		gi.visibility_range_end_margin = STRUCTURE_VISIBILITY_MARGIN
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		_apply_visibility_range(child)


## VILLAGE: huts scattered across a flattened footprint, >= 14m between any two
## structures (ADR-027-D), on level dry ground; center feature + cache + tunnel.
func stamp_village(center: Vector3, rng: RandomNumberGenerator, working_points: Array[NodePath] = []) -> Dictionary:
	var hut_count: int = rng.randi_range(7, 10)
	var footprint_r: float = SiteLayouts.VILLAGE_FOOTPRINT_RADIUS
	# One shared foundation: level the ground + clear vegetation under the footprint.
	clear_and_flatten(center, footprint_r + 6.0)

	var nodes: Array[Node3D] = []
	var placed: Array[Vector3] = [center]  # center feature reserves the middle
	var sep: float = SiteLayouts.VILLAGE_MIN_STRUCTURE_SEP

	for pos in _scatter_huts(center, footprint_r, hut_count, sep, rng, placed):
		placed.append(pos)
		var a: float = atan2(pos.z - center.z, pos.x - center.x)
		var model: String = SiteLayouts.VILLAGE_HUT_MODELS[rng.randi() % SiteLayouts.VILLAGE_HUT_MODELS.size()]
		var hut := place_structure(model, pos, rad_to_deg(a) + 90.0 + rng.randf_range(-15, 15))
		hut.add_to_group("flammable_structures")  # R71: thatch catches fire
		nodes.append(hut)

	var center_model: String = SiteLayouts.VILLAGE_CENTER_MODELS[rng.randi() % SiteLayouts.VILLAGE_CENTER_MODELS.size()]
	nodes.append(place_structure(center_model, center, rng.randf_range(0, 360)))

	# Auxiliary VC props are deliberately concealed among/around the huts (a cache
	# tucked behind a hut, spider holes between them, punji on the approaches), so
	# they are off water but NOT held to the >=14m building separation.
	var cache_pos: Vector3 = _dry_point(center, footprint_r * 0.5, footprint_r, rng)
	var cache := place_structure(SiteLayouts.CACHE_MODEL, cache_pos, rng.randf_range(0, 360))
	nodes.append(cache)

	var tunnel_pos: Vector3 = _dry_point(center, footprint_r * 0.5, footprint_r, rng)
	nodes.append(place_structure(SiteLayouts.TUNNEL_MODEL, tunnel_pos, 0.0))

	for _s in range(rng.randi_range(0, 2)):
		var sp: Vector3 = _dry_point(center, sep, footprint_r, rng)
		var sm: String = SiteLayouts.VILLAGE_SCATTER_MODELS[rng.randi() % SiteLayouts.VILLAGE_SCATTER_MODELS.size()]
		nodes.append(place_structure(sm, sp, rng.randf_range(0, 360)))

	for _t in range(rng.randi_range(1, 2)):
		var tp: Vector3 = _dry_point(center, footprint_r + 3.0, footprint_r + 12.0, rng)
		var ta: float = atan2(tp.z - center.z, tp.x - center.x)
		nodes.append(PunjiTrap.place(_parent, _terrain, tp, ta))

	var props: Dictionary = _stamp_village_props(center, footprint_r, rng, nodes)

	# working_points is a write-only contract the activity system reads.
	var site := {
		"kind": "village",
		"center": center,
		"nodes": nodes,
		"cache": cache,
		"cache_pos": cache_pos,
		"radius": footprint_r + 8.0,
		"working_points": working_points,
		"work_stations": props.stations,
		"prop_nodes": props.nodes,
	}
	placed_sites.append(site)
	return site


## ---------- VILLAGE LIFE PROPS (Caleb-authored, uiho) ----------
## DRESSING v1 by Summoner decree: no colliders, no nav carve, never cover.
## Zone-banded annuli, always OUTSIDE building footprints, off water.

const PROP_BUILDING_MARGIN: float = 1.2
const PROP_MIN_SEP: float = 2.0


func _stamp_village_props(center: Vector3, footprint_r: float, rng: RandomNumberGenerator,
		buildings: Array[Node3D]) -> Dictionary:
	var prop_nodes: Array[Node3D] = []
	var stations: Array = []
	var placed_props: Array[Vector3] = []
	var prop_names: Array = SiteLayouts.VILLAGE_PROPS.keys()
	prop_names.sort()  # dictionary order is not a contract; the seed is
	for prop_name in prop_names:
		var spec: Dictionary = SiteLayouts.VILLAGE_PROPS[prop_name]
		var band: Vector2 = SiteLayouts.VILLAGE_PROP_ZONES.get(str(spec.zone), Vector2(0.35, 0.8)) as Vector2
		var cnt: Array = spec.count
		for _i in range(rng.randi_range(int(cnt[0]), int(cnt[1]))):
			var pos: Vector3 = _prop_point(center, footprint_r * band.x, footprint_r * band.y,
				rng, buildings, placed_props)
			if pos == Vector3.ZERO:
				continue
			placed_props.append(pos)
			var node := place_prop(SiteLayouts.VILLAGE_PROP_DIR + str(prop_name) + ".glb",
				pos, rng.randf_range(0.0, 360.0))
			if node == null:
				continue
			prop_nodes.append(node)
			_collect_stations(node, stations)
	var animal_names: Array = SiteLayouts.VILLAGE_ANIMALS.keys()
	animal_names.sort()
	for animal_name in animal_names:
		var arange: Array = SiteLayouts.VILLAGE_ANIMALS[animal_name]
		for _j in range(rng.randi_range(int(arange[0]), int(arange[1]))):
			var apos: Vector3 = _prop_point(center, footprint_r * 0.45, footprint_r * 1.05,
				rng, buildings, placed_props)
			if apos == Vector3.ZERO:
				continue
			placed_props.append(apos)
			var animal := place_prop(SiteLayouts.VILLAGE_ANIMAL_DIR + str(animal_name) + ".glb",
				apos, rng.randf_range(0.0, 360.0))
			if animal == null:
				continue
			animal.add_to_group("village_animals")
			_play_idle(animal)
			prop_nodes.append(animal)
	return {"nodes": prop_nodes, "stations": stations}


## Dressing prop: GLB visual only - no physics body. Distinct from place_structure
## on purpose; a market table must never read as something that stops lead.
func place_prop(model_path: String, world_pos: Vector3, rotation_deg: float) -> Node3D:
	var scene: PackedScene = load(model_path)
	if scene == null:
		push_warning("[SitePlanner] missing prop: " + model_path)
		return null
	var root := Node3D.new()
	root.name = model_path.get_file().get_basename()
	root.set_meta("prop_model", model_path.get_file().get_basename())
	var visual: Node = scene.instantiate()
	root.add_child(visual)
	_apply_visibility_range(visual)
	_parent.add_child(root)
	var gy: float = _terrain.get_height_at(world_pos)
	root.global_position = Vector3(world_pos.x, gy, world_pos.z)
	root.rotation_degrees = Vector3(0.0, rotation_deg, 0.0)
	return root


func _prop_point(center: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator,
		buildings: Array[Node3D], placed_props: Array[Vector3]) -> Vector3:
	for _try in range(24):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(r_min, maxf(r_min + 0.5, r_max))
		var p: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * r
		if _grid.is_water(p):
			continue
		if _near_building(p, buildings):
			continue
		if not _separated(p, PROP_MIN_SEP, placed_props, []):
			continue
		return p
	return Vector3.ZERO


## HARD REQUIREMENT (Summoner): props spawn OUTSIDE buildings, never inside.
func _near_building(p: Vector3, buildings: Array[Node3D]) -> bool:
	for b in buildings:
		if b == null or not is_instance_valid(b):
			continue
		var entry: Dictionary = CollisionTable.get_entry(str(b.get_meta("model_name", b.name)))
		var fp: Vector2 = entry.get("footprint", Vector2(4, 4)) as Vector2
		var clearance: float = maxf(fp.x, fp.y) * 0.5 + PROP_BUILDING_MARGIN
		var d: float = Vector2(p.x - b.global_position.x, p.z - b.global_position.z).length()
		if d < clearance:
			return true
	return false


## GLB station empties (work_*) -> activity anchors for CampDirector/civilians.
## Contract: node name prefix "work_"; glTF extras work_type when present.
func _collect_stations(prop_root: Node3D, stations: Array) -> void:
	var stack: Array[Node] = [prop_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Node3D and String(n.name).begins_with("work_"):
			var wtype: String = str((n as Node3D).get_meta("work_type",
				String(n.name).trim_prefix("work_")))
			if wtype.contains("cook"):
				wtype = "cook"
			stations.append({"pos": (n as Node3D).global_position, "type": wtype})


func _play_idle(prop_root: Node3D) -> void:
	var ap := prop_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for anim_name in ap.get_animation_list():
		if String(anim_name).to_lower().contains("idle"):
			ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			ap.play(anim_name)
			return


## Scatter up to `count` hut positions in the footprint disk, each >= min_sep from
## every already-placed structure and off water. Never collides and never relaxes
## the separation: on a cramped/wet site it returns FEWER huts rather than stack
## them. Grows the disk within the flattened band to hit the target when it can.
func _scatter_huts(center: Vector3, footprint_r: float, count: int, min_sep: float,
		rng: RandomNumberGenerator, placed: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var r: float = footprint_r
	var r_max: float = footprint_r + 4.0  # stays inside the flattened (+6) band
	for _grow in range(6):
		var attempts: int = count * 25
		while result.size() < count and attempts > 0:
			attempts -= 1
			var p: Vector3 = _disk_point(center, r, rng)
			if _grid.is_water(p) or not _separated(p, min_sep, placed, result):
				continue
			result.append(p)
		if result.size() >= count:
			break
		r = minf(r_max, r + 2.0)
	return result


## One off-water point in the annulus [r_min, r_max]. Never returns origin: on a wet
## site it falls back to an offset from the (dry-validated) centre.
func _dry_point(center: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator) -> Vector3:
	for _i in range(40):
		var a: float = rng.randf() * TAU
		var rad: float = rng.randf_range(r_min, r_max)
		var p: Vector3 = center + Vector3(cos(a), 0, sin(a)) * rad
		if not _grid.is_water(p):
			return p
	var fa: float = rng.randf() * TAU
	return center + Vector3(cos(fa), 0, sin(fa)) * r_min


func _disk_point(center: Vector3, r: float, rng: RandomNumberGenerator) -> Vector3:
	var a: float = rng.randf() * TAU
	var rad: float = sqrt(rng.randf()) * r  # uniform over the disk area
	return center + Vector3(cos(a), 0, sin(a)) * rad


func _separated(p: Vector3, min_sep: float, a: Array[Vector3], b: Array[Vector3]) -> bool:
	for q in a:
		if p.distance_to(q) < min_sep:
			return false
	for q in b:
		if p.distance_to(q) < min_sep:
			return false
	return true


## ---------- THE MAIN FIREBASE (Caleb-authored fsb_main.glb, task 6b) ----------
## Measured contract (2026-07-18, glTF JSON + imported scene agree): model AABB
## x -145.1..224.2, z -101.5..242.9 (369x344m), origin y=0 = parade ground; 1,116
## -col trimesh bodies; 20 root-level markers. SOCKET_A/B_001 = the wire-gate
## sides, FACE_OUT_001 disambiguates the outward normal, GUN_POINT_001 = MG post,
## FOOTPRINT_* = ground-contact ring, APPROACH_* = approach lanes. Placed
## UNROTATED v1 (map-tile scale; rotation risks edge overhang). The wire-gate
## trigger and all patrol density bands measure from GATE_POS, not the AABB
## center - walking distance is the pacing contract.

const FSB_MAIN_PATH: String = "res://assets/building models/structures/firebase/fsb_main.glb"
const FSB_AABB_CENTER := Vector3(39.5, 0.0, 70.7)   # model space, measured
const FSB_HALF := Vector2(184.6, 172.2)             # model space, measured
const FSB_SITE_CLEARANCE: float = 40.0
const FSB_EDGE_MARGIN: float = 60.0
## Vegetation-clear discs covering the footprint (model-space offsets from AABB
## center + radius). The base is authored cleared ground; trees through bunkers lie.
const FSB_CLEAR_DISCS: Array = [
	[Vector3.ZERO, 120.0],
	[Vector3(92.0, 0.0, 86.0), 110.0], [Vector3(-92.0, 0.0, 86.0), 110.0],
	[Vector3(92.0, 0.0, -86.0), 110.0], [Vector3(-92.0, 0.0, -86.0), 110.0],
]


## Marker locals cached once; plan-time band math and build-time placement use
## the SAME numbers (one math path, never re-derived by hand).
static var _fsb_markers: Dictionary = {}


static func fsb_gate_metrics(center: Vector3) -> Dictionary:
	if _fsb_markers.is_empty():
		var scene: PackedScene = load(FSB_MAIN_PATH)
		var inst := scene.instantiate() as Node3D
		for key in ["SOCKET_A_001", "SOCKET_B_001", "FACE_OUT_001"]:
			var n := inst.get_node_or_null(key) as Node3D
			_fsb_markers[key] = n.position if n != null else Vector3.ZERO
		inst.free()
	var origin: Vector3 = center - FSB_AABB_CENTER
	var a: Vector3 = origin + (_fsb_markers["SOCKET_A_001"] as Vector3)
	var b: Vector3 = origin + (_fsb_markers["SOCKET_B_001"] as Vector3)
	var fo: Vector3 = origin + (_fsb_markers["FACE_OUT_001"] as Vector3)
	var gate_pos: Vector3 = (a + b) * 0.5
	var ab: Vector3 = (b - a).normalized()
	var out := Vector3(-ab.z, 0.0, ab.x)
	if out.dot(fo - gate_pos) < 0.0:
		out = -out
	out.y = 0.0
	out = out.normalized()
	gate_pos.y = 0.0
	return {"gate_pos": gate_pos, "gate_out": out, "spawn_pos": gate_pos - out * 22.0}


## Pure site pick for the AABB center: fits in-map with margin, prefers dry flat
## ground at the clear-disc centers, stays off paddies/reserved points.
func plan_firebase_main_center(rng: RandomNumberGenerator) -> Vector3:
	var map_size: float = _terrain.map_size
	var min_x: float = FSB_HALF.x + FSB_EDGE_MARGIN
	var min_z: float = FSB_HALF.y + FSB_EDGE_MARGIN
	var best := Vector3(map_size * 0.5, 0.0, map_size * 0.5)
	var best_score: float = -1.0e9
	for _i in range(120):
		var c := Vector3(rng.randf_range(min_x, map_size - min_x), 0.0,
			rng.randf_range(min_z, map_size - min_z))
		var score: float = 0.0
		for disc in FSB_CLEAR_DISCS:
			var p: Vector3 = c + (disc[0] as Vector3)
			if _grid.is_water(p):
				score -= 10.0
			score -= _grid.get_slope(p)
		for r in _reserved:
			if c.distance_to(r) < 240.0:
				score -= 25.0
		if score > best_score:
			best_score = score
			best = c
	_reserved.append(best)
	return best


## Stamp Caleb's base with its AABB center at `center`. Returns the site dict
## with gate/spawn metrics derived from HIS markers - never guessed.
func place_firebase_main(center: Vector3) -> Dictionary:
	for disc in FSB_CLEAR_DISCS:
		clear_and_flatten(center + (disc[0] as Vector3), float(disc[1]))
	var scene: PackedScene = load(FSB_MAIN_PATH)
	var root := scene.instantiate() as Node3D
	root.set_meta("model_name", "fsb_main")
	_parent.add_child(root)
	var origin: Vector3 = center - FSB_AABB_CENTER
	origin.y = _terrain.get_height_at(center)
	root.global_position = origin
	var gm: Dictionary = SitePlanner.fsb_gate_metrics(center)
	var gate_pos: Vector3 = gm.gate_pos
	var gate_out: Vector3 = gm.gate_out
	var spawn_pos: Vector3 = gm.spawn_pos
	spawn_pos.y = _terrain.get_height_at(spawn_pos)
	gate_pos.y = _terrain.get_height_at(gate_pos)
	_fsb_rect = Rect2(center.x - FSB_HALF.x, center.z - FSB_HALF.y,
		FSB_HALF.x * 2.0, FSB_HALF.y * 2.0)
	var site := {"kind": "firebase_main", "center": center, "nodes": [root],
		"gate_pos": gate_pos, "gate_out": gate_out, "spawn_pos": spawn_pos,
		"radius": FSB_HALF.length()}
	placed_sites.append(site)
	return site


## VC jungle camp: tunnel + cache + spider holes tucked under canopy. Deliberately
## NOT cleared - the jungle IS the camp's roof.
func stamp_vc_camp(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Array[Node3D] = []
	nodes.append(place_structure(SiteLayouts.TUNNEL_MODEL, center, rng.randf_range(0, 360)))
	nodes.append(place_structure(SiteLayouts.CACHE_MODEL,
		_dry_point(center, 4.0, 10.0, rng), rng.randf_range(0, 360)))
	for _i in range(rng.randi_range(1, 2)):
		var sp: Vector3 = _dry_point(center, 6.0, 14.0, rng)
		nodes.append(place_structure(
			"res://assets/building models/structures/vc_nva/spider_hole.glb",
			sp, rng.randf_range(0, 360)))
	var site := {"kind": "vc_camp", "center": center, "nodes": nodes, "radius": 16.0}
	placed_sites.append(site)
	return site


## AA SITE (W03/W04): emplacement on a flattened pad + sandbag ring.
## The gun is a DestructibleVehicle (satchel it) - mg_nest GLB as placeholder
## until Caleb models a ZPU/DShK.
func stamp_aa_site(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	clear_and_flatten(center, 10.0)
	var nodes: Array[Node3D] = []
	var gun := DestructibleVehicle.create(_parent,
		"res://assets/building models/structures/firebase/mg_nest.glb",
		center, rng.randf_range(0, 360), _terrain)
	nodes.append(gun)
	for i in range(4):
		var a := TAU * float(i) / 4.0 + 0.4
		var pos := center + Vector3(cos(a), 0, sin(a)) * 5.0
		nodes.append(place_structure(SiteLayouts.FIREBASE_SANDBAG, pos, rad_to_deg(a) + 90.0))
	var site := {"kind": "aa_site", "center": center, "nodes": nodes, "gun": gun, "radius": 10.0}
	placed_sites.append(site)
	return site


## PT6: small friendly OUTPOST for the insertion staging pad - helipad,
## hootches, tower, sandbag line. Home base feel without a full firebase.
func stamp_outpost(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	clear_and_flatten(center, 22.0)
	var nodes: Array[Node3D] = []
	nodes.append(place_structure("res://assets/building models/structures/firebase/observation_tower.glb", center + Vector3(-10, 0, -8), 0.0))
	nodes.append(place_structure("res://assets/building models/structures/firebase/hootch.glb", center + Vector3(-12, 0, 4), 15.0))
	nodes.append(place_structure("res://assets/building models/structures/firebase/hootch.glb", center + Vector3(-8, 0, 12), -20.0))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var pos := center + Vector3(cos(a), 0, sin(a)) * 18.0
		if not _grid.is_water(pos):
			nodes.append(place_structure(SiteLayouts.FIREBASE_SANDBAG, pos, rad_to_deg(a) + 90.0))
	nodes.append(place_structure("res://assets/building models/vehicles/m151_mutt_gun_jeep.glb", center + Vector3(8, 0, -8), rng.randf_range(0, 360)))
	var site := {"kind": "outpost", "center": center, "nodes": nodes, "radius": 22.0}
	placed_sites.append(site)
	return site


## Ancient Buddhist temple ruin POI (Caleb's cultist temple set) - overgrown,
## lootable shrine, natural landmark and ambush magnet.
func stamp_temple_ruin(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	clear_and_flatten(center, 14.0)
	var nodes: Array[Node3D] = []
	var temple := place_structure("res://assets/building models/structures/temple/cultist_temple2.glb", center, rng.randf_range(0, 360))
	temple.add_to_group("temple_shrines")
	nodes.append(temple)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + rng.randf_range(-0.4, 0.4)
		var pos := center + Vector3(cos(a), 0, sin(a)) * rng.randf_range(8.0, 12.0)
		nodes.append(place_structure("res://assets/building models/structures/temple/ruins_corner.glb", pos, rad_to_deg(a) + rng.randf_range(-30, 30)))
	var site := {"kind": "temple", "center": center, "nodes": nodes, "radius": 14.0}
	placed_sites.append(site)
	return site


## LZ: cleared flattened circle, no structures.
func stamp_lz(center: Vector3) -> Dictionary:
	clear_and_flatten(center, 16.0)
	var site := {"kind": "lz", "center": center, "nodes": [], "radius": 16.0}
	placed_sites.append(site)
	return site
