## site_planner.gd - Finds valid flat sites via GameplayGrid and stamps
## village / firebase / LZ layouts onto generated terrain (NS06).
class_name SitePlanner
extends RefCounted

const LitterTeamScript := preload("res://scripts/world/litter_team.gd")

const MARGIN: float = 100.0  ## keep sites away from AO edges
const MAX_SLOPE: float = 0.25
const SITE_ATTEMPTS: int = 300

var _grid: GameplayGrid
var _terrain: TerrainManager
var _veg: VegetationManager
var _parent: Node3D
var placed_sites: Array[Dictionary] = []
var _reserved: Array[Vector3] = []  ## centers returned by find_site, pre-stamp
var _cleared_discs: Dictionary = {}  ## clear_and_flatten dedup keys (0.1m grain)
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
## Idempotent per disc: the CLEARED flatten is a partial lerp toward the disc
## mean, so a repeat call sinks the pad again and breaks the ADR-010 re-stamp
## contract (same seed + center must yield identical heights).
func clear_and_flatten(center: Vector3, radius: float) -> void:
	var disc_key := Vector3i(int(center.x * 10.0), int(center.z * 10.0), int(radius * 10.0))
	if _cleared_discs.has(disc_key):
		return
	_cleared_discs[disc_key] = true
	var zone_id: int = ClearingSystem.create_zone(center, radius)
	ClearingSystem.set_zone_stage(zone_id, ClearingSystem.ClearingStage.CLEARED)
	if _veg and _veg.has_method("clear_area"):
		_veg.clear_area(center, radius, _terrain.chunk_size, _terrain.heightmap)
	if _grid:
		_grid.update_region(center, radius)


## SOFT COVER: what lead goes THROUGH. In this war most "walls" are thatch, bamboo and
## palm leaf - concealment, not cover - and a hooch wall stopping a 7.62 was a lie the
## physics told. Bunkers, rock and vehicles are NOT soft: those actually stop a round.
## Which model is which is AUTHORED DATA - CollisionTable.is_soft() is the one authority.
##
## bullet_system reads the soft_cover/hard_surface GROUP off the exact collider a round
## hits - never a parent. This puts one material on every collision object under a
## structure, so nested GLB -col bodies answer the same as the root.
static func tag_ballistics(root: Node, soft: bool) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is CollisionObject3D:
			n.add_to_group("soft_cover" if soft else "hard_surface")


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
	var soft: bool = CollisionTable.is_soft(model_name)
	var scene: PackedScene = load(model_path)
	if scene:
		var visual := scene.instantiate()
		var s: float = float(entry.scale)
		if s != 1.0:
			visual.scale = Vector3(s, s, s)
		body.add_child(visual)
		_apply_visibility_range(visual)  # R92: cull distant structure geometry
	# Runs on the WHOLE subtree, not just this root: for mesh-collision GLBs the
	# collider a bullet actually hits is the -col StaticBody3D nested inside the
	# visual scene, and a group on the root alone never reaches it - every thatch
	# hut was silently bulletproof.
	tag_ballistics(body, soft)
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
		# A mouth the player satchelled on an earlier patrol stays gone (ADR-029
		# Amendment B: the world remembers). It is never re-placed and never
		# re-joins the group the enemy surfaces from.
		if CampaignState.tunnel_is_collapsed(body.global_position):
			body.queue_free()
			return null
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
## structures, on level dry ground; center feature + cache + tunnel.
func stamp_village(center: Vector3, rng: RandomNumberGenerator, working_points: Array[NodePath] = []) -> Dictionary:
	var hut_count: int = rng.randi_range(7, 10)
	var footprint_r: float = SiteLayouts.VILLAGE_FOOTPRINT_RADIUS
	# One shared foundation: level the ground + clear vegetation under the footprint.
	clear_and_flatten(center, footprint_r + 6.0)

	var nodes: Array[Node3D] = []
	var buildings_placed: Array[Node3D] = []
	var placed: Array[Vector3] = [center]  # center feature reserves the middle
	var sep: float = SiteLayouts.VILLAGE_MIN_STRUCTURE_SEP

	for pos in _scatter_huts(center, footprint_r, hut_count, sep, rng, placed):
		placed.append(pos)
		var a: float = atan2(pos.z - center.z, pos.x - center.x)
		var model: String = SiteLayouts.VILLAGE_HUT_MODELS[rng.randi() % SiteLayouts.VILLAGE_HUT_MODELS.size()]
		var hut := place_structure(model, pos, rad_to_deg(a) + 90.0 + rng.randf_range(-15, 15))
		hut.add_to_group("flammable_structures")  # R71: thatch catches fire
		nodes.append(hut)
		buildings_placed.append(hut)

	var center_model: String = SiteLayouts.VILLAGE_CENTER_MODELS[rng.randi() % SiteLayouts.VILLAGE_CENTER_MODELS.size()]
	var centre_node: Node3D = place_structure(center_model, center, rng.randf_range(0, 360))
	nodes.append(centre_node)
	buildings_placed.append(centre_node)

	# Auxiliary VC props are deliberately concealed among/around the huts (a cache
	# tucked behind a hut, spider holes between them, punji on the approaches), so
	# they are off water but NOT held to the >=14m building separation.
	var cache_pos: Vector3 = _dry_point(center, footprint_r * 0.5, footprint_r, rng)
	var cache := place_structure(SiteLayouts.CACHE_MODEL, cache_pos, rng.randf_range(0, 360))
	nodes.append(cache)

	var tunnel_pos: Vector3 = _dry_point(center, footprint_r * 0.5, footprint_r, rng)
	# null = a mouth the player already satchelled; it is simply not there.
	var tunnel_node: Node3D = place_structure(SiteLayouts.TUNNEL_MODEL, tunnel_pos, 0.0)
	if tunnel_node != null:
		nodes.append(tunnel_node)

	for _s in range(rng.randi_range(0, 2)):
		var sp: Vector3 = _dry_point(center, sep, footprint_r, rng)
		var sm: String = SiteLayouts.VILLAGE_SCATTER_MODELS[rng.randi() % SiteLayouts.VILLAGE_SCATTER_MODELS.size()]
		nodes.append(place_structure(sm, sp, rng.randf_range(0, 360)))

	for _t in range(rng.randi_range(1, 2)):
		var tp: Vector3 = _dry_point(center, footprint_r + 3.0, footprint_r + 12.0, rng)
		var ta: float = atan2(tp.z - center.z, tp.x - center.x)
		nodes.append(PunjiTrap.place(_parent, _terrain, tp, ta))

	var props: Dictionary = _stamp_village_props(center, footprint_r, rng, nodes)

	# Buildings furnish themselves off their own baked markers, and offer their work_*
	# stations the same way props always have. Before this, _collect_stations() only ever
	# ran on props, so a house was scenery the activity system could not see.
	# Edge pieces (hedge, gate, fence, paddy, tomb) and yard clutter (haystack, cart).
	# Both pools existed unused until now - a village with no boundary and no working
	# clutter reads as a set of houses dropped on grass.
	for _e in range(rng.randi_range(2, 4)):
		var ep: Vector3 = _dry_point(center, footprint_r * 0.85, footprint_r * 1.15, rng)
		var em: String = SiteLayouts.VILLAGE_EDGE_MODELS[rng.randi() % SiteLayouts.VILLAGE_EDGE_MODELS.size()]
		var en: Node3D = place_structure(em, ep, rad_to_deg(atan2(ep.z - center.z, ep.x - center.x)) + 90.0)
		nodes.append(en)
		buildings_placed.append(en)
	for _y in range(rng.randi_range(1, 3)):
		var yp: Vector3 = _dry_point(center, footprint_r * 0.3, footprint_r * 0.75, rng)
		var ym: String = SiteLayouts.VILLAGE_YARD_MODELS[rng.randi() % SiteLayouts.VILLAGE_YARD_MODELS.size()]
		var yn: Node3D = place_structure(ym, yp, rng.randf_range(0.0, 360.0))
		nodes.append(yn)
		buildings_placed.append(yn)

	# Buildings furnish themselves off their own baked markers, and offer their work_*
	# stations the same way props always have. Before this, _collect_stations() only ever
	# ran on props, so a house was scenery the activity system could not see.
	var homes: Array = []
	var grazing: Array = []
	for b in buildings_placed:
		if b == null:
			continue
		nodes.append_array(_furnish_interior(b, rng))
		_collect_stations(b, props.stations)
		nodes.append_array(_stable_animals(b, homes))
		_collect_grazing(b, grazing)

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
		# Where each animal sleeps and where it feeds. A day routine needs both ends.
		"animal_homes": homes,
		"grazing_points": grazing,
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


## Same as place_prop but keeps the Y you give it. place_prop snaps to terrain, which
## is right for ground cover and wrong for anything growing ON a building - a vine
## hung on a wall at 2.5m would drop to the dirt.
func place_prop_at(model_path: String, world_pos: Vector3, rotation_deg: float) -> Node3D:
	var node: Node3D = place_prop(model_path, world_pos, rotation_deg)
	if node != null:
		node.global_position = world_pos
	return node


## VEGETATION FOR A TEMPLE SITE. clear_and_flatten() strips the AO's own growth from
## the pad, so a shrine reads as a bald patch unless we put the jungle back deliberately.
## Ta Prohm is the reference: canopy closing overhead, undergrowth to the walls, vines
## down the stonework.
const TEMPLE_CANOPY: Array[String] = [
	"broadleaf_a", "broadleaf_b", "broadleaf_c",
	"jungle_palm_a1", "jungle_palm_a2", "jungle_palm_b1", "jungle_palm_b2"]
const TEMPLE_UNDER: Array[String] = [
	"fern_a", "fern_b", "fern_c", "bush_a", "bush_b", "bush_c",
	"elephant_grass_a", "elephant_grass_b", "tall_grass_a", "tall_grass_b"]
const TEMPLE_VINES: Array[String] = [
	"vine_a", "vine_b", "liana_a", "liana_b", "trunk_vine_a", "trunk_vine_b"]
const TEMPLE_LITTER: Array[String] = [
	"fallen_log_a", "fallen_log_b", "tree_stump", "moss_a", "moss_b"]
const VEG_DIR: String = "res://assets/world/vegetation/"


func _stamp_temple_vegetation(center: Vector3, radius: float, size: Array,
		rng: RandomNumberGenerator, nodes: Array[Node3D]) -> void:
	var half: float = maxf(float(size[0]), float(size[1])) * 0.5

	for i in range(rng.randi_range(6, 9)):          # canopy ringing the clearing
		var a: float = TAU * float(i) / 9.0 + rng.randf_range(-0.3, 0.3)
		var r: float = rng.randf_range(radius * 0.72, radius * 1.15)
		var p: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * r
		var n: Node3D = place_prop(VEG_DIR + TEMPLE_CANOPY[rng.randi() % TEMPLE_CANOPY.size()]
				+ ".glb", p, rng.randf_range(0.0, 360.0))
		if n != null:
			nodes.append(n)

	for i in range(rng.randi_range(12, 20)):        # undergrowth up to the walls
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(half + 0.8, radius * 0.95)
		var p2: Vector3 = center + Vector3(cos(a2), 0.0, sin(a2)) * r2
		var n2: Node3D = place_prop(VEG_DIR + TEMPLE_UNDER[rng.randi() % TEMPLE_UNDER.size()]
				+ ".glb", p2, rng.randf_range(0.0, 360.0))
		if n2 != null:
			nodes.append(n2)

	for i in range(rng.randi_range(4, 7)):          # vines hanging down the stonework
		var a3: float = rng.randf_range(0.0, TAU)
		var p3: Vector3 = center + Vector3(cos(a3), 0.0, sin(a3)) * (half + rng.randf_range(-0.2, 0.35))
		p3.y = _terrain.get_height_at(p3) + rng.randf_range(1.4, float(size[2]) * 0.75)
		var n3: Node3D = place_prop_at(VEG_DIR + TEMPLE_VINES[rng.randi() % TEMPLE_VINES.size()]
				+ ".glb", p3, rad_to_deg(a3) + rng.randf_range(-25.0, 25.0))
		if n3 != null:
			nodes.append(n3)

	for i in range(rng.randi_range(3, 5)):          # deadfall and moss at the base
		var a4: float = rng.randf_range(0.0, TAU)
		var r4: float = rng.randf_range(half + 0.4, radius * 0.85)
		var p4: Vector3 = center + Vector3(cos(a4), 0.0, sin(a4)) * r4
		var n4: Node3D = place_prop(VEG_DIR + TEMPLE_LITTER[rng.randi() % TEMPLE_LITTER.size()]
				+ ".glb", p4, rng.randf_range(0.0, 360.0))
		if n4 != null:
			nodes.append(n4)


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
## Bed an animal at each home_<species> marker and record the spot, so a day/night
## routine has somewhere to return TO. Village animals used to be scattered at random
## with an idle loop and no home at all - they had nowhere to go back to at dusk.
func _stable_animals(building: Node3D, homes: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m in _find_markers(building, SiteLayouts.ANIMAL_HOME_PREFIX):
		var species: String = str(m.get_meta("species", ""))
		if species == "":
			continue
		var node: Node3D = place_prop(SiteLayouts.VILLAGE_ANIMAL_DIR + species + ".glb",
			m.global_position, rad_to_deg(m.global_rotation.y))
		homes.append({"species": species, "pos": m.global_position, "node": node})
		if node != null:
			_play_idle(node)
			out.append(node)
	return out


## graze_* markers: the daytime end of the routine. graze_for names which species may
## feed there, so buffalo do not end up grazing a chicken run.
func _collect_grazing(building: Node3D, grazing: Array) -> void:
	for m in _find_markers(building, SiteLayouts.ANIMAL_GRAZE_PREFIX):
		var who: String = str(m.get_meta("graze_for", ""))
		grazing.append({"pos": m.global_position,
			"species": who.split(",", false) if who != "" else []})


## Fill a building from the prop_* empties gen_village.py baked into its GLB.
## The marker carries its own prop_class, so a hearth lands on the hearth spot and a
## sleeping mat lands against the wall - instead of both being thrown into an annulus
## somewhere in the yard, which is what made village dressing look like litter.
func _furnish_interior(building: Node3D, rng: RandomNumberGenerator) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m in _find_markers(building, "prop_"):
		var pclass: String = str(m.get_meta("prop_class", ""))
		if not SiteLayouts.INTERIOR_PROPS.has(pclass):
			continue
		var pool: Array = SiteLayouts.INTERIOR_PROPS[pclass]
		var pick: String = str(pool[rng.randi() % pool.size()])
		# place_prop_at, NOT place_prop: a mat on a stilt deck 1.8m up must keep its Y
		# instead of being snapped down to the terrain under the house.
		var node: Node3D = place_prop_at(SiteLayouts.VILLAGE_PROP_DIR + pick + ".glb",
			m.global_position, rad_to_deg(m.global_rotation.y))
		if node != null:
			out.append(node)
	return out


## Marker empties export from Blender as plain Node3D, never Marker3D - the same thing
## seat_system.gd:6-7 had to learn. Match on name prefix and accept any Node3D.
func _find_markers(root: Node3D, prefix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Node3D and String(n.name).begins_with(prefix):
			found.append(n as Node3D)
	return found


func _collect_stations(prop_root: Node3D, stations: Array) -> void:
	var stack: Array[Node] = [prop_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Node3D and String(n.name).begins_with("work_"):
			var wtype: String = str((n as Node3D).get_meta("work_type",
				String(n.name).trim_prefix("work_")))
			# Blender's .001 / glTF _001 duplicate suffix, same strip as the fsb
			# marker reader below - "cook_001" is not a work type.
			var cut: int = wtype.rfind("_")
			if cut > 0 and wtype.substr(cut + 1).is_valid_int():
				wtype = wtype.substr(0, cut)
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


## ---------- THE MAIN FIREBASE (fsb_main_v3.glb) ----------
## Measured contract (2026-07-26 export from tools/gen_firebase_v3.py, blend
## firebase/kit/firebase_v3.1.blend): model AABB x -122.6..149.3, z -111.2..96.6, y -1.2..14.5.
## NOT recentred - the base is authored about the origin already, and y=0 is the mound TOE, so
## the earth mound stands proud of the seated plateau instead of being buried. Craters reach
## y=-1.2. SOCKET_A/B = the wire-gate sides, FACE_OUT = outward normal, APPROACH = the road in.
## Placed UNROTATED (rotation risks edge overhang). The wire-gate trigger and all patrol density
## bands measure from GATE_POS, not the AABB center - walking distance is the pacing contract.
## tools/diag_fsb_seat asserts these consts against the loaded GLB - remeasure on every re-export.
##
## v1 fsb_main.glb is archived under firebase/_archive_v1/ behind a .gdignore. Do not point
## anything back at it: two firebase models live in the same world slot is the divergent-systems
## failure, not a fallback.

## THE FIREBASE IS A SCENE, NOT A RAW GLB (ruling 2026-07-29: "we make the main firebase a real
## scene in godot and give me spawn markers that i can place").
##
## scenes/world/firebase_main.tscn wraps the model and carries everything AUTHORED BY HAND
## beside it - spawn markers first. The crucial property is that those markers live in the
## SCENE, not in the GLB, so re-exporting fsb_main_v3.glb from Blender can never delete them.
## Anything hand-placed in the compound belongs in that scene for the same reason.
##
## The GLB is still the model and still the ground; this only gives it a place to keep
## authored siblings. One world-build path (ADR-028) is untouched: the build instances this
## scene exactly where it used to instance the GLB.
const FSB_MAIN_PATH: String = "res://scenes/world/firebase_main.tscn"
const FSB_MODEL_GLB: String = "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
const FSB_AABB_CENTER := Vector3(0.0, 0.0, 0.0)     # authored about the origin, measured
## Half-extents from the ORIGIN, not from the AABB centre: the authored treeline runs further
## out on +x than -x, and _fsb_rect is built centred on `center`, so it must cover the reach.
const FSB_HALF := Vector2(149.3, 111.2)             # model space, measured
const FSB_SITE_CLEARANCE: float = 40.0
const FSB_EDGE_MARGIN: float = 60.0
const FSB_FLATTEN_RADIUS: float = 215.0
## modify_region falloff = 1 - smoothstep(0, R, d); full seat where falloff >=
## FSB_PLATEAU_FALLOFF, i.e. d <= 0.796*R (~171m) - covers the crater-free
## guarantee rect.grow(40) whose corners reach 169m. Only the outer shoulder
## blends into relief.
const FSB_PLATEAU_FALLOFF: float = 0.107

## ---------- THE MOUND MANIFEST (2026-07-29 decree) ----------
## Written by tools/gen_firebase_v3.py::write_mound_manifest on every export. The terrain is
## sculpted to THIS surface, and the GLB's own ground plate collider is deleted, so the base
## stands on exactly ONE ground.
##
## What it replaces: a flat interior plateau at a hardcoded seat+2.87 (taken from the
## fb_gate_gap MARKER, not from the mound SURFACE). The model's plate rolls between ~1.5 and
## ~5.3 m, so it stood 0.5-2.4 m proud of that plateau over most of the compound - an
## invisible floor the player jumped onto and was then walled in by - and swallowed the feet
## of every structure where it dipped below. ADR-023: the old two-tier stamp is DELETED here,
## not left behind a flag.
const FSB_MOUND_MANIFEST: String = "res://assets/world/building models/structures/firebase/fsb_main_v3_mound.json"
static var _fsb_mound: Dictionary = {}


static func _mound_manifest() -> Dictionary:
	if not _fsb_mound.is_empty():
		return _fsb_mound
	var f: FileAccess = FileAccess.open(FSB_MOUND_MANIFEST, FileAccess.READ)
	if f == null:
		push_error(("[FSB] mound manifest missing (%s) - the terrain cannot be sculpted to "
			+ "the model and the base will stand on two grounds again. Re-export the firebase.")
			% FSB_MOUND_MANIFEST)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_fsb_mound = parsed
	return _fsb_mound


## Height in METRES of the authored mound above its own toe, at a point given in model-local
## Godot XZ (world minus compound centre). The one reader of the manifest; a line-for-line
## port of gen_firebase_v3.py::platform_z, with Blender's +Y mapped to Godot's -Z (the
## export runs export_yup, same convention as the vehicle facing rule).
static func fsb_mound_height(local_x: float, local_z: float) -> float:
	var m: Dictionary = _mound_manifest()
	if m.is_empty():
		return 0.0
	var x: float = local_x
	var y: float = -local_z          # Blender +Y is Godot -Z
	var a: float = atan2(y, x)
	var stretch: float = float(m.ridge_stretch)
	var r: float = Vector2(x / stretch, y).length()
	var harm: float = 0.0
	for h in (m.edge_harmonics as Array):
		var t: Array = h
		harm += float(t[0]) * sin(float(t[1]) * a + float(t[2]))
	var edge: float = float(m.r0) * (1.0 + harm) + float(m.berm_w)
	var xy: Array = m.top_xy
	var yv: Array = m.top_y
	var xy2: Array = m.top_xy2
	var top: float = float(m.mound_h) \
		+ float(xy[0]) * sin(x * float(xy[1]) + float(xy[2])) * cos(y * float(xy[3]) + float(xy[4])) \
		+ float(yv[0]) * sin(y * float(yv[1]) + float(yv[2])) \
		+ float(xy2[0]) * cos(x * float(xy2[1]) + y * float(xy2[2]) + float(xy2[3]))
	if r <= edge:
		return top + _fighting_step(m, r, edge)
	var t2: float = minf(1.0, (r - edge) / float(m.mound_fall))
	return top * pow(1.0 - t2, 2.0) * (1.0 - 0.35 * t2)


## THE FIGHTING STEP, BUILT OUT OF GROUND. Measured against the authored wall: the berm crest
## stands BERM_H (1.22m) over the compound floor and the parapet puts nine 0.13m courses on top
## of it, so its lip is 2.39m up. A man's eye is ~1.6m. From the yard he is 0.8m under his own
## wall, and `berm()` emits the crest as a knife edge with the revetment sitting on it - there
## is nowhere to stand even after you climb. That is the Summoner's report, four times over:
## "I still cannot climb up the angled dirt mounds and see to shoot over the sandbag walls...
## I should be able to walk up the dirt mound and see slightly over the sandbags to shoot,
## otherwise the immersion is broken." It is also how the VC come over the berm once the
## sandbags are blown.
##
## This does NOT need Blender. Since the one-ground decree the TERRAIN is the collider under
## the base - the model's mound plate is stripped at load - so a banquette raised in the
## heightmap is real ground a man can walk up. The model's mound mesh ends up buried inside it
## across this band, which is invisible: terrain renders over the top.
##
## Eye check: 0.9m step + 1.6m eye = 2.5m against a 2.39m lip. He clears it by ~0.11m standing -
## "slightly over", exactly the ask - and crouching drops him fully behind cover.
## The ramp is ~11m of run for 0.9m of rise, about 5 degrees, and the heightmap's 4m cells need
## a band this wide to represent the shelf at all.
static func _fighting_step(m: Dictionary, r: float, edge: float) -> float:
	var h: float = float(m.get("step_h", 0.9))
	if h <= 0.0:
		return 0.0
	var band_out: float = edge - float(m.get("step_gap_m", 3.0))
	var band_in: float = band_out - float(m.get("step_width_m", 11.0))
	if r >= band_out:
		return h                              # the flat shelf, hard against the revetment
	if r <= band_in:
		return 0.0                            # the compound floor is untouched
	return h * smoothstep(band_in, band_out, r)
## Vegetation-clear discs (model-space offsets from AABB center + radius). The base is authored
## cleared ground; trees through bunkers lie.
## 140 m, not the v1 ring of five 58 m discs: v3 authors its OWN cut-over treeline out to ~149 m
## (stumps, fallen logs, scrub, then palms). Clearing only to ~100 m would let procedural jungle
## grow straight through the authored trees and double the treeline. Clearing to 140 leaves a
## thin 140-149 m band where the two meet, which reads as the blend it is.
const FSB_CLEAR_DISCS: Array = [
	[Vector3.ZERO, 140.0],
]


## Marker locals cached once; plan-time band math and build-time placement use
## the SAME numbers (one math path, never re-derived by hand).
static var _fsb_markers: Dictionary = {}

const FSB_MARKER_KEYS: Array[String] = [
	"SOCKET_A_001", "SOCKET_B_001", "FACE_OUT_001",
	"mg_fire_point_001", "bunker_los_point_001", "tower_los_point_001",
	"GUN_POINT_001",
	"USSupplyDepot_001", "USSupplyDepot_007",
	"FOOTPRINT_001", "FOOTPRINT_002", "FOOTPRINT_003",
	"FOOTPRINT_004", "FOOTPRINT_007",
	"APPROACH_001", "APPROACH_002",
]

## Garrison posts as [marker key, occupation, men]. The marker set is the
## contract: a post whose marker is absent from the GLB is SKIPPED, never
## relocated to the compound center.
const FSB_GARRISON_POSTS: Array = [
	["SOCKET_A_001", "sentry", 1],
	["SOCKET_B_001", "sentry_night", 1],
	["mg_fire_point_001", "sentry", 1],
	["bunker_los_point_001", "sentry_night", 1],
	["tower_los_point_001", "sentry", 1],
	["GUN_POINT_001", "gun_crew", 2],
	["USSupplyDepot_001", "quartermaster", 1],
	["USSupplyDepot_007", "quartermaster", 1],
	["FOOTPRINT_003", "radioman", 1],
	["APPROACH_002", "mess_cook", 1],
	["FOOTPRINT_002", "off_duty", 2],
	["FOOTPRINT_004", "off_duty", 2],
	["FOOTPRINT_007", "off_duty", 2],
]

## Where off-shift men sleep and loaf. Round-robin `home` for every post man, so
## the compound carries traffic between quarters and post instead of statues.
const FSB_GARRISON_QUARTERS: Array[String] = [
	"FOOTPRINT_001", "FOOTPRINT_002", "FOOTPRINT_004", "FOOTPRINT_007",
]

## work_* markers baked into the firebase GLB, as [pos, work_type]. Cached alongside the
## named keys because the garrison reads them by PREFIX, not by exact name.
static var _fsb_work_markers: Array = []

## work_type -> Civilian occupation. A work_type with no entry here becomes off_duty
## rather than inventing a schedule.
##
## THE GUNS ARE ABSENT ON PURPOSE, twice over. gun/mortar must never map to the
## CURATED "gun_crew" occupation - mission_generator.gd:967 stands up a mannable M60
## per gun_crew post, and 20 work_gun markers is twenty M60s. And they are not in the
## round-robin either: a rotation seats one man per pass wherever the sorted pool
## lands him, scattering singles across six pits, and a served gun is a CREW. They
## are seeded whole as per-pit "gun_crew_arty" crews below (fsb_garrison_plan),
## capped by FSB_ARTY_CREWS_PER_TYPE, and phase-locked by gun_crew_performance.gd.
const FSB_WORK_OCCUPATION: Dictionary = {
	"watch": "sentry", "guard": "sentry", "mg": "sentry",
	"ammo": "quartermaster", "supply": "quartermaster",
	"radio": "radioman", "plot": "radioman",
	"cook": "mess_cook", "mess": "mess_cook",
	"medic": "medic",
	# THE CHOW HALL (marker names locked by Caleb 2026-08-03, convention
	# work_<building>_<role>). The servery side is a POST - a man stands it. The diner
	# side, the seats and the queue are where the garrison GOES, so they carry the
	# mess_hall schedule instead of a job.
	"chow_server": "mess_cook", "chow_server_line": "mess_cook",
	"chow_diner": "mess_hall", "chow_trigger": "mess_hall", "chow_exit": "mess_hall",
	"eat": "mess_hall", "queue": "mess_hall",
	# Stage 6 of his diner loop (2026-08-07): they return the tray before they leave.
	# chow_tray_dump was authored for it and had no marker to play at - mapped ahead of the
	# export so the chow hall works the first time it lands. See CHOW_HALL_EXPORT_CONTRACT.md.
	"chow_tray_return": "mess_hall",
	# The working party. Digging, filling, burning, hauling water, washing down,
	# policing the pad - the labour that fills a firebase day.
	"dig": "detail", "burn": "detail", "latrine": "detail",
	"water": "detail", "wash": "detail", "pad": "detail",
	# Named so the fall-through is a decision, not an accident.
	"rest": "off_duty", "smoke": "off_duty",
}

## Which JOBS the work-post budget buys, best first. The curated table above already
## seats sentries, gun crew, quartermasters, a radioman, a cook and six off-duty men,
## so the budget is spent on what it does NOT cover: the aid station and the working
## party. Types absent here still get seated, after these, in marker order.
const FSB_WORK_PRIORITY: Array[String] = [
	"medic",
	"dig", "wash", "water", "burn", "latrine", "pad",
	"chow_server", "chow_server_line", "eat", "chow_diner", "queue",
	"radio", "supply", "cook", "mess", "ammo",
	"watch", "guard", "mg", "plot", "smoke", "rest",
	"chow_trigger", "chow_exit",
]

## THE garrison ceiling: how many men stand inside the wire, curated and work-post
## alike. Guarded by tests/test_firebase_garrison.gd, which reads THIS constant.
## 24 -> 40 measured 2026-07-31 on the exported demo (150s A/B; the flag that run
## cited did not exist then - `--print-fps` became real 2026-08-04, W-4):
## mid-siege 48.0 FPS at both values - the men are not the frame cost. If the
## siege now feels too safe to hold, this is the dial back toward 28-32.
const FSB_GARRISON_MAX_MEN: int = 40

## Upper bound on work_* variety. fsb_main_v3.glb carries 191 work markers
## (measured) and one man each would be a crowd the frame cannot pay for.
## Sampled by a deterministic stride, never randomly - ADR-010, same seed same base.
##
## This is a VARIETY cap, not the population cap: the real limit is whatever
## FSB_GARRISON_MAX_MEN leaves after the curated posts are seated. Holding both as
## independent constants is how the compound came to hold 17 curated + 12 work =
## 29 men against a documented ceiling of 24.
const FSB_WORK_POST_CAP: int = 24


## THE ARTILLERY CREWS. fsb_main_v3.glb carries 6 gun pits x3 work_gun markers
## (each <=3.7m from its howitzer) and 2 mortar pits x3 markers - one work_gun
## marker sits INSIDE each mortar pit and is that crew's third station; clusters
## are >=14m apart (all measured 2026-08-07). Seat caps are the staged clip sets:
## four howitzer seats, three mortar seats. One crew of each ships - six of the
## ~23 work-budget men; crewing all eight pits would spend the whole compound.
const FSB_ARTY_LINK_M: float = 7.0        ## single-linkage cluster join distance
const FSB_GUN_CREW_MEN: int = 4
const FSB_MORTAR_CREW_MEN: int = 3
const FSB_ARTY_CREWS_PER_TYPE: int = 1


## Cluster gun/mortar work markers into pits: [{markers: Array[Vector3] (model
## space), mortar: bool}]. Deterministic - _fsb_work_markers is already sorted.
static func _arty_pits() -> Array:
	var pits: Array = []
	for entry_any in _fsb_work_markers:
		var e: Array = entry_any
		var wt: String = str(e[1])
		if wt != "gun" and wt != "mortar":
			continue
		var p: Vector3 = e[0]
		var joined: bool = false
		for pit_any in pits:
			var pit: Dictionary = pit_any
			for q_any in (pit.markers as Array):
				var q: Vector3 = q_any
				if Vector2(p.x - q.x, p.z - q.z).length() <= FSB_ARTY_LINK_M:
					(pit.markers as Array).append(p)
					pit["mortar"] = bool(pit.mortar) or wt == "mortar"
					joined = true
					break
			if joined:
				break
		if not joined:
			pits.append({"markers": [p], "mortar": wt == "mortar"})
	return pits


## Men already promised by the curated post table.
static func _fsb_curated_men() -> int:
	var n: int = 0
	for entry in FSB_GARRISON_POSTS:
		n += int(entry[2])
	return n


## Offsets are accumulated up to the GLB root: every consumer adds them to the
## compound center, so a marker nested under a sub-node must not contribute its
## parent-local position.
static func _ensure_fsb_markers() -> void:
	if not _fsb_markers.is_empty():
		return
	var scene: PackedScene = load(FSB_MAIN_PATH)
	var inst := scene.instantiate() as Node3D
	for key in FSB_MARKER_KEYS:
		var n := inst.find_child(key, true, false) as Node3D
		if n == null:
			continue
		var t := Transform3D.IDENTITY
		var cur: Node3D = n
		while cur != null and cur != inst:
			t = cur.transform * t
			cur = cur.get_parent() as Node3D
		_fsb_markers[key] = t.origin
	_fsb_work_markers.clear()
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if not (nd is Node3D) or not String(nd.name).begins_with("work_"):
			continue
		var t2 := Transform3D.IDENTITY
		var cur2: Node3D = nd as Node3D
		while cur2 != null and cur2 != inst:
			t2 = cur2.transform * t2
			cur2 = cur2.get_parent() as Node3D
		# work_<type>, with Blender's .001 / glTF _001 duplicate suffix stripped.
		var wt: String = String(nd.name).trim_prefix("work_")
		var cut: int = wt.rfind("_")
		if cut > 0 and wt.substr(cut + 1).is_valid_int():
			wt = wt.substr(0, cut)
		_fsb_work_markers.append([t2.origin, wt])
	_fsb_work_markers.sort_custom(func(a: Array, b: Array) -> bool:
		var pa: Vector3 = a[0]
		var pb: Vector3 = b[0]
		if not is_equal_approx(pa.x, pb.x):
			return pa.x < pb.x
		return pa.z < pb.z)
	inst.free()


## Garrison post/quarters positions in WORLD space. Y is the AUTHORED marker height
## (kept since 2026-08-04); seat with GameWorld.floor_y from it, never surface_y.
static func fsb_garrison_plan(center: Vector3) -> Dictionary:
	_ensure_fsb_markers()
	var origin: Vector3 = center - FSB_AABB_CENTER
	var posts: Array[Dictionary] = []
	for entry in FSB_GARRISON_POSTS:
		var key: String = entry[0]
		if not _fsb_markers.has(key):
			continue
		# AUTHORED HEIGHT KEPT (2026-08-04). Zeroing Y here forced every consumer onto a
		# top-down surface_y probe, which hits the ROOF over any covered post - the whole
		# garrison stood on the buildings. The marker's Y IS the floor it was placed on;
		# seat with GameWorld.floor_y from it.
		var p: Vector3 = origin + (_fsb_markers[key] as Vector3)
		posts.append({"pos": p, "occupation": str(entry[1]), "men": int(entry[2])})
	# The work_* markers authored across the compound, so the garrison stands at the mess
	# line, the wash drums and the ammo niches instead of only the thirteen curated posts.
	var wcount: int = _fsb_work_markers.size()
	var work_budget: int = clampi(FSB_GARRISON_MAX_MEN - _fsb_curated_men(), 0, FSB_WORK_POST_CAP)
	if wcount > 0 and work_budget > 0:
		# ROUND-ROBIN BY WORK TYPE, not a positional stride. The stride walked 198
		# markers sorted by X and took every 16th, so which JOBS the twelve work-post
		# men did was decided by where their markers happened to sit on the map: four
		# medic posts in one building could all be skipped, and thirty-six work_rest
		# markers could win most of the budget. The constant this budget comes from
		# calls itself a VARIETY cap - so spend it on variety.
		var by_type: Dictionary = {}
		var seen_order: Array[String] = []
		for entry_any in _fsb_work_markers:
			var e: Array = entry_any
			var wt: String = str(e[1])
			# gun/mortar are crew-seeded below, never rotated - a marker left in this
			# pool would fall through FSB_WORK_OCCUPATION to an off_duty man loafing
			# in the pit, the exact pre-M22 failure.
			if wt == "gun" or wt == "mortar":
				continue
			if not by_type.has(wt):
				by_type[wt] = []
				seen_order.append(wt)
			(by_type[wt] as Array).append(e[0])
		# FSB_WORK_PRIORITY first, then anything the GLB carries that it does not name,
		# in marker order. Sorting alphabetically instead would spend the whole budget
		# on ammo/burn/cook/dig and never reach the medic.
		var type_order: Array[String] = []
		for wt in FSB_WORK_PRIORITY:
			if by_type.has(wt):
				type_order.append(wt)
		for wt in seen_order:
			if not type_order.has(wt):
				type_order.append(wt)
		var taken: int = 0
		# THE AID STATION IS SEEDED, not left to the rotation. A medic alone at a
		# station plays medic_treat_give over empty ground - he mimes surgery on the
		# dirt. So the station opens with a man on the table, which is also the
		# casualty-ledger floor: an aid station with nobody in it is the fresh-player
		# failure. Wounded ABOVE this floor are the ledger's job, not the layout's.
		var med_pool: Array = by_type.get("medic", [])
		if med_pool.size() >= 2 and work_budget >= 2:
			var mp: Vector3 = origin + (med_pool[0] as Vector3)
			var pp: Vector3 = origin + (med_pool[1] as Vector3)
			posts.append({"pos": mp, "occupation": "medic", "men": 1})
			posts.append({"pos": pp, "occupation": "patient", "men": 1})
			taken = 2
			type_order.erase("medic")
			# THE LITTER TEAM IS THE BUTCHER'S BILL MADE VISIBLE. Seeded on the same
			# rule as the station itself, but CONDITIONALLY: a stretcher crossing the
			# compound has to MEAN someone got hurt, so it runs only when the ward is
			# above its floor. Otherwise these three posts return to the rotation and
			# the working party keeps its men. Cost when it runs: 3 of the 7 work posts
			# (two bearers plus the man on the litter).
			var ward_full: bool = CampaignState.ward_wounded > CampaignState.WARD_SEED_ON_NEW_TOUR
			if med_pool.size() >= 3 and work_budget >= 5 and ward_full and LitterTeamScript.available():
				var cot: Vector3 = origin + (med_pool[2] as Vector3)
				posts.append({"pos": cot, "occupation": "litter", "men": 3, "ward": mp})
				taken = 5
		# THE ARTILLERY CREWS ARE SEEDED WHOLE, one pit per weapon type, ahead of the
		# rotation - a served gun is the firebase's signature image and it only reads
		# as served when the whole crew stands ONE piece. One post per station so
		# every man spawns on his own marker; gun_crew_performance.gd reassembles
		# them by pit and phase-locks the clips.
		var crews_seeded: Dictionary = {"gun": 0, "mortar": 0}
		for pit_any in _arty_pits():
			var pit: Dictionary = pit_any
			var wt: String = "mortar" if bool(pit.mortar) else "gun"
			if int(crews_seeded[wt]) >= FSB_ARTY_CREWS_PER_TYPE:
				continue
			var mk: Array = pit.markers
			var crew_n: int = mini(mk.size(),
				FSB_MORTAR_CREW_MEN if wt == "mortar" else FSB_GUN_CREW_MEN)
			if crew_n < 3 or taken + crew_n > work_budget:
				continue
			crews_seeded[wt] = int(crews_seeded[wt]) + 1
			for i in range(crew_n):
				posts.append({"pos": origin + (mk[i] as Vector3),
					"occupation": "gun_crew_arty", "men": 1, "role": wt})
				taken += 1
		var round_i: int = 0
		while taken < work_budget:
			var placed_this_round: bool = false
			for wt in type_order:
				if taken >= work_budget:
					break
				var pool: Array = by_type[wt]
				if round_i >= pool.size():
					continue
				var wp: Vector3 = origin + (pool[round_i] as Vector3)
				var occ: String = str(FSB_WORK_OCCUPATION.get(wt, "off_duty"))
				# Alternate the two sentry shifts so the wire is not empty after dark.
				if occ == "sentry" and taken % 2 == 1:
					occ = "sentry_night"
				# "role" carries the raw work_type: occupation is lossy, and the animation
				# picker needs to tell a chow server from a man in the queue.
				posts.append({"pos": wp, "occupation": occ, "men": 1, "role": wt})
				taken += 1
				placed_this_round = true
			if not placed_this_round:
				break
			round_i += 1

	var quarters: Array[Vector3] = []
	for key in FSB_GARRISON_QUARTERS:
		if not _fsb_markers.has(key):
			continue
		var q: Vector3 = origin + (_fsb_markers[key] as Vector3)
		quarters.append(q)
	return {"posts": posts, "quarters": quarters}


static func fsb_gate_metrics(center: Vector3) -> Dictionary:
	_ensure_fsb_markers()
	var origin: Vector3 = center - FSB_AABB_CENTER
	var a: Vector3 = origin + (_fsb_markers.get("SOCKET_A_001", Vector3.ZERO) as Vector3)
	var b: Vector3 = origin + (_fsb_markers.get("SOCKET_B_001", Vector3.ZERO) as Vector3)
	var fo: Vector3 = origin + (_fsb_markers.get("FACE_OUT_001", Vector3.ZERO) as Vector3)
	var gate_pos: Vector3 = (a + b) * 0.5
	var ab: Vector3 = (b - a).normalized()
	var out := Vector3(-ab.z, 0.0, ab.x)
	if out.dot(fo - gate_pos) < 0.0:
		out = -out
	out.y = 0.0
	out = out.normalized()
	gate_pos.y = 0.0
	return {"gate_pos": gate_pos, "gate_out": out, "spawn_pos": gate_pos - out * 22.0}


## Same 7x7 grid place_firebase_main() uses to seat the model, run BEFORE
## picking a site instead of after. A seed that rolls the footprint through a
## ridge or a paddy edge is not "unlucky" - it should never have won the pick.
func _footprint_height_range(center: Vector3) -> float:
	var step: float = FSB_HALF.x / 3.0
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var h: float = _terrain.get_height_at(center + Vector3(float(dx) * step, 0.0, float(dz) * step))
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


## Pure site pick for the AABB center: fits in-map with margin, prefers dry flat
## ground across the WHOLE footprint (not just the clear-disc centers), stays
## off paddies/reserved points. Flatness dominates the score on purpose - the
## seat/sculpt pass downstream can blend a gentle site, it cannot fix a ridge.
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
		score -= _footprint_height_range(c) * 2.0
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
## P0 2026-07-18 ("a gate and a table"): a 369m model seated on ROLLING relief
## buries one wing and floats the other - 26 of 678 meshes poked above ground.
## The ground must come to the base: seat at the footprint MEAN height and
## FLATTEN the terrain to the seat before placing.
func place_firebase_main(center: Vector3) -> Dictionary:
	var seat_y: float = 0.0
	var n: int = 0
	var step: float = FSB_HALF.x / 3.0   # 7x7 samples across the actual footprint
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			seat_y += _terrain.get_height_at(center + Vector3(float(dx) * step, 0.0, float(dz) * step))
			n += 1
	seat_y /= float(n)
	var seat_norm: float = seat_y / _terrain.heightmap.height_scale
	# Full plateau across the model AND the spawn ring (corner reach ~252m), then a
	# 65m blend shoulder. The old f*8.0 curve left the gate wing at ~80% seat and
	# the spawn ring at ~57% - level at seed 47225 by luck, buried on rougher AOs.
	#
	# ONE GROUND (2026-07-29). On top of that seat plateau the terrain reproduces the
	# model's OWN mound surface, exactly, from the manifest the generator exports. The
	# GLB's ground plate is then stripped below, so there is a single collider under the
	# base instead of two disagreeing ones.
	#
	# It also keeps what the 07-28 two-tier stamp was reaching for: the authored skirt is
	# MOUND_H over MOUND_FALL - 3.4m across 34m, ~5.7 degrees - so the player walks up from
	# every bearing. The old pin at a 3m dirt wall was never the authored slope; it was the
	# step where a flat plateau met the plate's edge, and that step is now gone.
	#
	# ORDER IS LOAD-BEARING. The vegetation clear runs FIRST, because clear_and_flatten ->
	# ClearingSystem CLEARED stage does its own height flatten toward the mean of a 140m disc.
	# Run after the sculpt it averages the authored mound back down while the model still draws
	# it at full height, and the player ends up walking between the two - or inside the mound.
	# The sculpt must have the last word on this ground.
	for disc in FSB_CLEAR_DISCS:
		clear_and_flatten(center + (disc[0] as Vector3), float(disc[1]))
	# THE MODEL IS THE GROUND (ruling 2026-07-29). The terrain is levelled to the mound's TOE and
	# stops there - it does NOT reproduce the mound any more. The mesh does, because the mesh is
	# the one that can show the craters, the thrown-up lips and the mud: "i want that mesh mound
	# because it showed destroyed earth and mud, so just moving the world terrain up doesn't fix
	# a lot of problems." A 4m heightmap cannot draw any of that at any setting.
	#
	# So terrain's whole job here is to be a clean, level seat UNDER the model, and to blend out
	# to the surrounding relief. Everything the player stands on inside the base comes from
	# fsb_main_v3.glb's own trimesh - which is why its walkability is now an EXPORT contract
	# (production/blender/FIREBASE_BLENDER_HANDOFF.md §00).
	_terrain.modify_terrain(center, FSB_FLATTEN_RADIUS,
		func(h: float, f: float, _wx: float, _wz: float) -> float:
			return lerpf(h, seat_norm, clampf(f / FSB_PLATEAU_FALLOFF, 0.0, 1.0)))
	# The grid was rebuilt by the clear against pre-sculpt heights; the sculpt just moved them.
	if _grid:
		_grid.update_region(center, FSB_FLATTEN_RADIUS)
	_audit_one_ground(center, seat_y)
	var scene: PackedScene = load(FSB_MAIN_PATH)
	var root := scene.instantiate() as Node3D
	root.set_meta("model_name", "fsb_main")
	_parent.add_child(root)
	var origin: Vector3 = center - FSB_AABB_CENTER
	origin.y = seat_y
	root.global_position = origin
	_repair_glb_colliders(root)
	_cull_interior_props(root)
	_wire_parapet_destructibles(root)
	_wire_claymores(root, center)
	# Tower ladders. Built AFTER the root is seated - Ladder caches world positions off the
	# markers, so building before the move would bake them at the wrong height.
	var ladders: int = Ladder.build_from_markers(root)
	if ladders == 0:
		push_warning("[FSB] no ladder_bottom/ladder_top pairs in the firebase GLB")
	var siren: SirenTower = SirenTower.build_from_markers(root)
	if siren == null:
		push_warning("[FSB] no fb_tower_i meshes in the firebase GLB - no alarm")
	var gm: Dictionary = SitePlanner.fsb_gate_metrics(center)
	var gate_pos: Vector3 = gm.gate_pos
	var gate_out: Vector3 = gm.gate_out
	var spawn_pos: Vector3 = gm.spawn_pos
	spawn_pos.y = _terrain.get_height_at(spawn_pos)
	gate_pos.y = _terrain.get_height_at(gate_pos)
	_stamp_radio(spawn_pos)
	_fsb_rect = Rect2(center.x - FSB_HALF.x, center.z - FSB_HALF.y,
		FSB_HALF.x * 2.0, FSB_HALF.y * 2.0)
	var site := {"kind": "firebase_main", "center": center, "nodes": [root],
		"gate_pos": gate_pos, "gate_out": gate_out, "spawn_pos": spawn_pos,
		"radius": FSB_HALF.length(), "siren": siren}
	placed_sites.append(site)
	return site


## REPAIR THE GLB'S COLLIDERS AT LOAD. Two export-era defects, both fixed at source in
## gen_firebase_v3.py, both repaired here so the build does not wait on a Blender pass.
## When the re-exported GLB lands both counts come back 0 and this whole function is deleted
## (ADR-023) - which is why it reports counts instead of passing silently.
##
## 1. THE MOUND PLATE. fb_terrain_mound shipped a full-compound ground collider, and the
##    terrain now reproduces that same surface. Two grounds, the higher one invisible.
##
## 2. THE VEGETATION BOXES - the 2026-07-29 "I can still jump and get stuck above the
##    firebase". scatter_veg MERGES every instance of a card type into ONE object spanning
##    the whole ~300m treeline ring, and the solid ones (tree_stump x90, fallen_log_a/b,
##    felled_trunk, felled_tree x16) were not on COL_NONE. So each exported as ONE
##    axis-aligned box wrapping the entire ring, ground to canopy: four invisible slabs
##    stacked over the base with walkable tops and impassable rims. Measured at +12.48m by
##    game_flow's SPAWN-TRUTH probe, which named fb_veg_felled_tree as the topmost hit at
##    the bunk spawn.
##
##    The box is replaced with a trimesh off the object's own visual mesh, so the logs and
##    stumps stay the cover the design intends ("logs and stumps stay solid because the
##    player takes cover behind them") without the slab.
## 3. THE PARAPET BOX HULLS - "I still cannot climb up the angled dirt mounds and see to shoot
##    over the sandbags" (2026-07-29). The perimeter revetment is ~6m of sandbag wall following
##    a CURVED path, and the default export wraps it in an axis-aligned box around that curve's
##    whole bounding volume. On the diagonal runs that box is far fatter than the wall it
##    represents: it overhangs the berm crest and swallows the 37-degree inner face, so the
##    climb is into an invisible slab, not up a slope. It also seals every gap a round could go
##    through. gen_firebase_v3.py now lists fb_sbg_seg_ as trimesh, but that only lands on a
##    re-export - so the same re-mesh the vegetation gets is applied here today.
const MOUND_COLLIDER_PREFIX: String = "fb_terrain_mound"
## Box-hulled in the shipped GLB, re-meshed from their own geometry at load. Both are already
## corrected at source; when the re-export lands these counts go to 0 and this all deletes.
const VEG_COLLIDER_PREFIX: String = "fb_veg_"
const REMESH_COLLIDER_PREFIXES: Array[String] = [VEG_COLLIDER_PREFIX, "fb_sbg_seg_"]


## THE INTERIORS COST 45% OF THE COMPOUND'S DRAW CALLS FOR 4% OF ITS GEOMETRY. Measured
## 2026-07-30 out of fsb_main_v3.glb: 826 visible surfaces, of which 368 are the 178 `fb_int_`
## props, carrying 11,936 of 318,056 triangles. This project is CALL-BOUND (PERF_LEDGER) and tri
## budgets are style, not perf, so the props are not too heavy - they are too NUMEROUS, and every
## one of them was drawn from any distance because nothing ever set a range on them.
##
## A cot inside a hootch is not visible from outside it. Culling them at ~40m is free: they are
## occluded by their own building long before the range bites, so the fade is unobservable.
## This is the cheap half of the fix; folding each prop TYPE into one MultiMesh (368 -> ~11) is
## the rest, and it needs the bake removed in the same change or every prop doubles.
const INTERIOR_PROP_PREFIX: String = "fb_int_"
const INTERIOR_CULL_M: float = 40.0
const INTERIOR_CULL_MARGIN_M: float = 8.0


func _cull_interior_props(root: Node3D) -> void:
	var n_props: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or not String(mi.name).begins_with(INTERIOR_PROP_PREFIX):
			continue
		mi.visibility_range_end = INTERIOR_CULL_M
		mi.visibility_range_end_margin = INTERIOR_CULL_MARGIN_M
		n_props += 1
	print("[FSB] %d interior prop(s) culled past %.0fm" % [n_props, INTERIOR_CULL_M])


## EVERY structure in the shipped GLB winds inward - measured 2026-08-02, signed volume is
## negative for all 19 families tested and fb_terrain_mound / fb_berm_ring are 100% down-facing.
## ConcavePolygonShape3D only collides on its front face, so the ground and the walls were both
## one-sided. Root cause was gen_firebase.py::box() plus the two swept surfaces, all fixed at
## source; this holds the shipped GLB solid until that re-export lands, and returns 0 once it has.
func _force_backface_collision(body: StaticBody3D) -> int:
	var fixed: int = 0
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs == null:
			continue
		var concave := cs.shape as ConcavePolygonShape3D
		if concave == null or concave.backface_collision:
			continue
		concave.backface_collision = true
		fixed += 1
	return fixed


func _repair_glb_colliders(root: Node3D) -> void:
	var mound: int = 0
	var mound_backfaced: int = 0
	var veg_boxed: int = 0
	var veg_remeshed: int = 0
	# Collected in a FULL pass before anything is touched: re-meshing adds StaticBody3D children
	# whose names also start with fb_veg_, and a walk that mutates the tree it is reading would
	# delete the replacement it just built.
	var doomed: Array[StaticBody3D] = []
	var regrow: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var body := n as StaticBody3D
		if body == null:
			continue
		if String(body.name).begins_with(MOUND_COLLIDER_PREFIX):
			# KEPT, not stripped (ruling 2026-07-29). This trimesh IS the walkable ground now.
			# It was stripped while the terrain reproduced the mound, because two grounds at
			# different heights is what put the player on an invisible floor. The terrain no
			# longer climbs, so this is the only ground and it must stay.
			mound += 1
			continue
		for p in REMESH_COLLIDER_PREFIXES:
			if String(body.name).begins_with(p):
				doomed.append(body)
				regrow.append(String(body.name))
				veg_boxed += 1
				break
	for body in doomed:
		body.get_parent().remove_child(body)
		body.queue_free()
	for body_name in regrow:
		if _remesh_collider(root, body_name):
			veg_remeshed += 1
	if mound > 0:
		print("[FSB] kept %d mound collider(s) - the MODEL is the ground" % mound)
	else:
		push_warning("[FSB] the GLB carries NO mound collider - fb_terrain_mound must be on "
			+ "COL_TRIMESH in gen_firebase_v3.py, or the player walks on the flat seat and the "
			+ "cratered mound is scenery he passes through")
	if veg_boxed > 0:
		print("[FSB] replaced %d box hull(s) (vegetation + parapet), %d re-meshed as trimesh"
			% [veg_boxed, veg_remeshed])
	# Runs LAST: _remesh_collider builds new bodies above, and they inherit the same winding.
	var stack2: Array[Node] = [root]
	while not stack2.is_empty():
		var n2: Node = stack2.pop_back()
		for c in n2.get_children():
			stack2.append(c)
		var b2 := n2 as StaticBody3D
		if b2 != null:
			mound_backfaced += _force_backface_collision(b2)
	print("[FSB] %d concave shape(s) forced double-sided (inward winding in the shipped GLB)"
		% mound_backfaced)
	_tag_fsb_ballistics(root)
	_audit_floating_colliders(root)


## Ballistic material for the firebase GLB's own colliders, by mesh family (the family
## name IS the material: gen_firebase_v3.py builds each list from one master). Canvas,
## plywood and tin are CONCEALMENT - a GP tent, a hootch wall or a water trailer does
## not stop a 7.62. Everything else on this compound is filled sandbags, earth, timber
## or steel, so hard is the default. The TOC is deliberately hard: a firebase TOC is
## the most sandbagged structure inside the wire.
const FSB_SOFT_PREFIXES: Array[String] = ["fb_hootch", "fb_gp_tent", "fb_mess",
	"fb_aid_station", "fb_latrine", "fb_supply_dump", "fb_water_point",
	"fb_burn_barrel", "bwire_card"]


func _tag_fsb_ballistics(root: Node3D) -> void:
	var soft_n: int = 0
	var hard_n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var body := n as CollisionObject3D
		if body == null:
			continue
		var nm := String(body.name)
		var soft: bool = false
		for p in FSB_SOFT_PREFIXES:
			if nm.begins_with(p):
				soft = true
				break
		body.add_to_group("soft_cover" if soft else "hard_surface")
		if soft:
			soft_n += 1
		else:
			hard_n += 1
	print("[FSB] ballistic tags: %d soft (tent/hootch/tin), %d hard (earth/sandbag/timber)"
		% [soft_n, hard_n])


## Rebuild one merged-vegetation collider from its own visual mesh. Returns whether it found
## the mesh - a miss is reported by the caller's count, never assumed.
##
## The collider carries the export's ordinal (`fb_veg_tree_stump_041`, from make_collision's
## `{base}_{i:03d}-colonly`); the visual mesh does not. Strip it to get back to the object.
func _remesh_collider(root: Node3D, body_name: String) -> bool:
	var stem: String = body_name
	var cut: int = stem.rfind("_")
	if cut > 0 and stem.substr(cut + 1).is_valid_int():
		stem = stem.substr(0, cut)
	var mi := root.find_child(stem, true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return false
	mi.create_trimesh_collision()
	return true


## Does the terrain actually stand where the model's mound stands? "One ground" is a claim
## about two surfaces agreeing, and the only honest way to hold it is to measure the gap.
##
## This exists because the first attempt LOOKED right in the log and was wrong in the world:
## the vegetation clear ran after the sculpt and averaged the mound back down, so the player
## walked in the gap between the terrain he collided with and the mound he could see. A gap
## that big must never again be something only a playtest can find.
const GROUND_GAP_TOLERANCE_M: float = 0.6


func _audit_one_ground(center: Vector3, seat_y: float) -> void:
	var worst: float = 0.0
	var worst_at: Vector3 = Vector3.ZERO
	var over: int = 0
	var samples: int = 0
	for ring in range(0, 9):
		var r: float = float(ring) * 16.0
		var steps: int = 1 if ring == 0 else 16
		for s in range(steps):
			var a: float = TAU * float(s) / float(steps)
			var p: Vector3 = center + Vector3(cos(a) * r, 0.0, sin(a) * r)
			# The model's own surface at this point, from the manifest the generator exports.
			var model_y: float = seat_y + SitePlanner.fsb_mound_height(p.x - center.x, p.z - center.z)
			# ONE-WAY TEST NOW. The model is the ground; terrain only has to stay UNDER it.
			# Terrain lower than the mound is correct and invisible (buried seat). Terrain
			# ABOVE the mound is the bug: it pokes through the cratered earth, and the player
			# walks on a flat heightmap where he should be walking on shell holes.
			var poke: float = _terrain.get_height_at(p) - model_y
			samples += 1
			if poke > GROUND_GAP_TOLERANCE_M:
				over += 1
			if poke > worst:
				worst = poke
				worst_at = p
	if over == 0:
		print("[FSB] ground: %d samples, terrain sits under the model everywhere (worst +%.2fm)"
			% [samples, maxf(0.0, worst)])
		return
	push_warning(("[FSB] TERRAIN POKES THROUGH THE MODEL: %d of %d samples above it, worst "
		+ "+%.2fm at (%.0f, %.0f). The seat is too high - the mound's craters are buried there.")
		% [over, samples, worst, worst_at.x, worst_at.z])


## Name anything left standing on air. A collider whose LOWEST point floats well above the
## ground is the shape of every "I got stuck on top of the base" report, and hunting one by
## jumping around the compound is not a debugging method. Reports the worst offenders by name
## so the next one is found in a log line instead of a playtest.
const FLOAT_REPORT_M: float = 3.0


func _audit_floating_colliders(root: Node3D) -> void:
	if not OS.is_debug_build():
		return   # get_debug_mesh() allocates per shape; this is an instrument, not a ship cost
	var worst: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var cs := n as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var aabb: AABB = cs.shape.get_debug_mesh().get_aabb() if cs.shape.get_debug_mesh() != null else AABB()
		if aabb.size.length() < 0.01:
			continue
		var bottom: float = (cs.global_transform * aabb).position.y
		var ground: float = _terrain.get_height_at(cs.global_position)
		var air: float = bottom - ground
		if air >= FLOAT_REPORT_M:
			worst.append([air, String(cs.get_parent().name)])
	if worst.is_empty():
		return
	worst.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var lines: Array[String] = []
	for i in range(mini(6, worst.size())):
		lines.append("%s +%.1fm" % [worst[i][1], worst[i][0]])
	print("[FSB] %d collider(s) floating >%.0fm off the ground; worst: %s" % [
		worst.size(), FLOAT_REPORT_M, ", ".join(lines)])


## THE PARAPET CAN BE BLOWN APART. gen_firebase_v3 has emitted the perimeter as 80 destructible
## segments with HP since it was written, and `firebase_v3_destructibles.json` has been sitting
## next to the GLB READ BY NOTHING - the 2026-07-28 council logged it as UNFINISHED and ADR-036
## lists wiring it as step one. Nothing in the shipped world ever called Destructible.new(); the
## firebase was incapable of taking a mark. That is the Summoner's ship gate item: "the base
## attack has parts of the base blow up".
##
## The Destructible ADOPTS the segment the GLB already ships rather than adding geometry beside
## it. Destructible IS a StaticBody3D, so it takes the segment's collision shape directly and
## its mesh as a child - which is exactly what _do_destroy() expects to find when it hides the
## intact wall and disables its cover. No second wall, no second collider.
const FSB_DESTRUCTIBLES_JSON: String = "res://assets/world/building models/structures/firebase/kit/firebase_v3_destructibles.json"
## The wired segments are the only runtime description of where the wire IS. SiegeDirector
## measures the perimeter off this group and reads a destroyed member as a breach.
const FSB_PARAPET_GROUP: StringName = &"fsb_parapet"


func _wire_parapet_destructibles(root: Node3D) -> void:
	var f: FileAccess = FileAccess.open(FSB_DESTRUCTIBLES_JSON, FileAccess.READ)
	if f == null:
		push_warning("[FSB] no destructibles manifest - the parapet cannot be blown apart")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var segments: Array = (parsed as Dictionary).get("segments", [])
	var wired: int = 0
	var missing: int = 0
	for s in segments:
		var seg: Dictionary = s
		var mi := root.find_child(str(seg.get("name", "")), true, false) as MeshInstance3D
		if mi == null:
			missing += 1
			continue
		var d := Destructible.new()
		d.kind = str(seg.get("kind", "sandbag_wall"))
		d.hp = int(seg.get("hp", 140))
		d.collision_layer = 1
		d.collision_mask = 0
		_parent.add_child(d)
		d.global_position = mi.global_position
		# Take the segment's collider off its auto-generated body and onto the Destructible, so
		# _do_destroy can disable it. A shape left nested under a child body survives the blast
		# and the "destroyed" wall keeps stopping rounds.
		for c in mi.get_children():
			var body := c as StaticBody3D
			if body == null:
				continue
			for cc in body.get_children():
				var shape := cc as CollisionShape3D
				if shape == null:
					continue
				body.remove_child(shape)
				d.add_child(shape)
			body.queue_free()
		mi.reparent(d, true)      # keep_global_transform: the wall must not move
		AgentRegistry.register(d, AgentRegistry.Kind.PROP)
		# The perimeter is also the SIEGE's map of itself: SiegeDirector measures the wire's
		# radius from this group and reads a destroyed segment as its breach axis.
		d.add_to_group(FSB_PARAPET_GROUP)
		wired += 1
	print("[FSB] parapet: %d destructible segment(s) on the blast bus%s" % [wired,
		"" if missing == 0 else ", %d named in the manifest but absent from the GLB" % missing])
	_wire_structure_destructibles(root)


## THE REST OF THE COMPOUND CAN BE BLOWN APART TOO. The manifest describes ONLY the 80 parapet
## segments, so bunkers, towers and sandbag stacks stood indestructible in every shipped build -
## a satchel could open the wire and never touch what the wire protects.
##
## These are matched by MESH NAME PREFIX rather than added to the manifest, because the meshes
## are already in the GLB: this costs no Blender re-export. HP matches the bench
## (FireSupportBench.TARGET_KINDS) so the sapper room grades the same art the same way.
const FSB_STRUCTURE_KINDS: Array[Dictionary] = [
	{"prefix": "fb_bunker_fighting_i", "kind": "bunker"},
	{"prefix": "fb_bunker_mg_i", "kind": "bunker_mg"},
	{"prefix": "fb_sleeping_bunker_i", "kind": "bunker"},
	{"prefix": "fb_tower_i", "kind": "tower"},
	{"prefix": "fb_sandbag_stack_i", "kind": "sandbag_stack"},
	# VILLAGE BUILDINGS (Summoner, 2026-08-07: the explosives-only rule covers ALL buildings,
	# so they must first be damageable at all). Only fb_* was listed, so every hut in the AO
	# was indestructible while the firebase was not. HP is FIRST-PASS and his to tune: thatch
	# gives way to one satchel, the timber/stilt houses take more.
	{"prefix": "nha_tranh_", "kind": "hut_thatch"},
	{"prefix": "nha_san_", "kind": "hut_timber"},
	{"prefix": "nha_ruong_", "kind": "hut_timber"},
]


func _wire_structure_destructibles(root: Node3D) -> void:
	var by_kind: Dictionary = {}
	var stack: Array[Node] = [root]
	var found: Array[MeshInstance3D] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null and not String(mi.name).contains("-colonly"):
			found.append(mi)
	for mi in found:
		var nm := String(mi.name)
		for spec in FSB_STRUCTURE_KINDS:
			if not nm.begins_with(str(spec["prefix"])):
				continue
			_adopt_structure(mi, str(spec["kind"]), Destructible.hp_for(str(spec["kind"])))
			by_kind[spec["kind"]] = int(by_kind.get(spec["kind"], 0)) + 1
			break
	if by_kind.is_empty():
		return
	var parts: Array[String] = []
	for k in by_kind:
		parts.append("%d %s" % [int(by_kind[k]), k])
	print("[FSB] structures on the blast bus: %s" % ", ".join(parts))


## Adopt one authored structure mesh onto a Destructible, taking its collider with it.
##
## The Destructible is seated at the mesh's world AABB CENTRE, not its origin:
## combat_manager.gd:176-185 damages a prop on a pure radius test against global_position with
## no LOS and no bounds check, so a 9.6 m tower keyed off its foot survives a blast that
## visibly engulfs it.
func _adopt_structure(mi: MeshInstance3D, kind: String, hp: int) -> void:
	var d := Destructible.new()
	d.kind = kind
	d.hp = hp
	d.collision_layer = 1
	d.collision_mask = 0
	_parent.add_child(d)
	var aabb: AABB = mi.get_aabb()
	d.global_position = mi.global_transform * (aabb.position + aabb.size * 0.5)
	# A shape left nested under the mesh's auto-generated body survives the blast, and the
	# "destroyed" bunker keeps stopping rounds.
	for c in mi.get_children():
		var body := c as StaticBody3D
		if body == null:
			continue
		for cc in body.get_children():
			var shape := cc as CollisionShape3D
			if shape == null:
				continue
			var keep: Transform3D = shape.global_transform
			body.remove_child(shape)
			d.add_child(shape)
			shape.global_transform = keep
		body.queue_free()
	mi.reparent(d, true)      # keep_global_transform: the structure must not move
	AgentRegistry.register(d, AgentRegistry.Kind.PROP)


## THE CLAYMORES GO LIVE. gen_firebase_v3 rings the perimeter with 16 fb_claymore props
## (offset_closed(path, 13.0)) and they have been scenery: a working Claymore class existed the
## whole time, but the ONLY thing that ever built one was the player pressing 6. Same shape of
## gap as the 80 parapet segments - authored art with no code behind it, and the Summoner found
## it the same way: "there are claymores in the model... how do we make those explode? or are
## they going to be stuck as set pieces?"
##
## Safe to arm around your own men, checked before wiring: Claymore triggers ONLY on an
## EnemyBase inside a 9m / 35-degree forward cone, so the garrison cannot set one off, and the
## blast is centred 4m OUTWARD with an 8m radius while the mines sit 13m beyond the perimeter -
## the wire is between them and anyone friendly.
##
## The prop mesh is freed because Claymore.place() brings its own claymore.glb. Facing comes
## from the compound centre, not the node's rotation: outward is outward whatever the export's
## axis convention did to the prop.
const CLAYMORE_PROP_PREFIX: String = "fb_claymore"


func _wire_claymores(root: Node3D, center: Vector3) -> void:
	var props: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi != null and String(mi.name).begins_with(CLAYMORE_PROP_PREFIX):
			props.append(mi)
	var armed: int = 0
	for mi in props:
		var pos: Vector3 = mi.global_position
		var out: Vector3 = pos - center
		out.y = 0.0
		if out.length() < 1.0:
			continue
		var mine: Claymore = Claymore.place(_parent, pos, out.normalized())
		if mine == null:
			continue
		armed += 1
		# KEEP THE FIREBASE'S OWN CLAYMORE, drop the stand-in. Claymore.place() brings
		# claymore.glb - a different asset from the fb_claymore master in the firebase kit - so
		# arming the wire would silently restyle sixteen props. Reparenting his mesh under the
		# mine keeps the perimeter looking exactly as authored AND makes the model vanish with
		# the blast, because _detonate() queue_frees the mine and takes its children with it.
		for c in mine.get_children():
			c.queue_free()                     # the stand-in visual
		var keep_at: Transform3D = mi.global_transform
		mi.get_parent().remove_child(mi)
		mine.add_child(mi)
		mi.global_transform = keep_at          # authored placement, not the mine's facing
	if armed > 0:
		print("[FSB] %d claymore(s) armed on the wire, facing out (authored models kept)" % armed)


const RADIO_SCENE: String = "res://scenes/props/radio.tscn"

## Drop a diegetic field radio near the TOC spawn so the player boots to the broadcast.
func _stamp_radio(near: Vector3) -> void:
	var ps: PackedScene = load(RADIO_SCENE) as PackedScene
	if ps == null:
		return
	var radio := ps.instantiate() as Node3D
	_parent.add_child(radio)
	var spot: Vector3 = near + Vector3(1.5, 0.0, 0.0)
	spot.y = _terrain.get_height_at(spot)
	radio.global_position = spot


## VC jungle camp: tunnel + cache + spider holes tucked under canopy. Deliberately
## NOT cleared - the jungle IS the camp's roof.
func stamp_vc_camp(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Array[Node3D] = []
	# null = a mouth the player already satchelled; it is simply not there.
	var camp_tunnel: Node3D = place_structure(SiteLayouts.TUNNEL_MODEL, center, rng.randf_range(0, 360))
	if camp_tunnel != null:
		nodes.append(camp_tunnel)
	nodes.append(place_structure(SiteLayouts.CACHE_MODEL,
		_dry_point(center, 4.0, 10.0, rng), rng.randf_range(0, 360)))
	for _i in range(rng.randi_range(1, 2)):
		var sp: Vector3 = _dry_point(center, 6.0, 14.0, rng)
		nodes.append(place_structure(
			"res://assets/world/building models/structures/vc_nva/spider_hole.glb",
			sp, rng.randf_range(0, 360)))
	var stations: Array = []
	for n in nodes:
		if n != null:
			_collect_stations(n, stations)
	var site := {"kind": "vc_camp", "center": center, "nodes": nodes, "radius": 16.0,
		"work_stations": stations}
	placed_sites.append(site)
	return site


const TEMPLE_ACCENT_MODEL: String = "res://assets/world/building models/structures/temple/ruins_corner.glb"
const TEMPLE_DIR: String = "res://assets/world/building models/structures/temple/"
## Used only when the manifest cannot be read; the file ships with the set.
const TEMPLE_FALLBACK: String = "prasat_ruin_01"

## The prasat set written by tools/gen_temples.py. Read from its manifest rather than
## hardcoded here, so adding a temple to the generator is enough to put it in rotation.
static var _temple_set: Dictionary = {}


func _temple_manifest() -> Dictionary:
	if not _temple_set.is_empty():
		return _temple_set
	var f: FileAccess = FileAccess.open(TEMPLE_DIR + "temple_set.json", FileAccess.READ)
	if f == null:
		push_error("[SitePlanner] temple_set.json missing - shrines fall back to "
				+ TEMPLE_FALLBACK)
		return _temple_set
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_temple_set = parsed
	return _temple_set


func _temples_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for k in _temple_manifest().keys():
		var e: Dictionary = _temple_manifest()[k]
		if String(e.get("kind", "")) == kind:
			out.append(String(k))
	out.sort()
	return out


## Forgotten Cham shrine: a small overgrown ruin, no garrison. The temple body
## joins "temple_shrines" - player.gd's [F] SEARCH THE SHRINE reads that group
## by distance to the body's origin, so the group node must be the temple root.
func stamp_temple_shrine(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	clear_and_flatten(center, 14.0)
	var nodes: Array[Node3D] = []

	# Mostly ruins; an intact prasat is the rarer "found something" beat.
	var ruins: Array[String] = _temples_of_kind("ruined")
	var intact: Array[String] = _temples_of_kind("intact")
	var pool: Array[String] = ruins
	if not intact.is_empty() and rng.randf() < 0.28:
		pool = intact

	var rot: float = rng.randf_range(0.0, 360.0)
	var temple: Node3D = null
	var entry: Dictionary = {}
	if pool.is_empty():
		temple = place_structure(TEMPLE_DIR + TEMPLE_FALLBACK + ".glb", center, rot)
	else:
		var pick: String = pool[rng.randi() % pool.size()]
		entry = _temple_manifest()[pick]
		temple = place_structure(TEMPLE_DIR + pick + ".glb", center, rot)
	# player.gd's [F] SEARCH THE SHRINE reads this group by distance to the body
	# origin, so it must stay on the temple root - see the note above.
	temple.add_to_group("temple_shrines")
	nodes.append(temple)

	# Guardians flank the stair. door_dir is baked by tools/gen_temples.py:
	# 0=+Z 1=+X 2=-Z 3=-X in model space, so world facing = rot + dir*90.
	if not entry.is_empty():
		var size: Array = entry.get("size", [6.0, 6.0, 6.0])
		var reach: float = maxf(float(size[0]), float(size[1])) * 0.5 + 1.6
		var facing: float = deg_to_rad(rot + float(int(entry.get("door_dir", 0))) * 90.0)
		var fwd := Vector3(sin(facing), 0.0, cos(facing))
		var side := Vector3(fwd.z, 0.0, -fwd.x)
		var foot: Vector3 = center + fwd * reach
		for s in [-1.0, 1.0]:
			var g: Vector3 = foot + side * (s * 1.5)
			nodes.append(place_structure(TEMPLE_DIR + "temple_statue_guardian_0"
					+ ("1" if s < 0.0 else "2") + ".glb", g, rot + 180.0))
		nodes.append(place_structure(TEMPLE_DIR + "temple_statue_naga.glb",
				foot + fwd * 1.1, rot))
		var back: Vector3 = center - fwd * (reach + rng.randf_range(1.0, 2.5))
		nodes.append(place_structure(TEMPLE_DIR
				+ ("temple_statue_seated.glb" if rng.randf() < 0.5 else "temple_statue_lingam.glb"),
				back, rng.randf_range(0.0, 360.0)))

	for i in range(2):
		var a: float = TAU * float(i) / 2.0 + rng.randf_range(-0.5, 0.5)
		var pos: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(8.0, 12.0)
		nodes.append(place_structure(TEMPLE_ACCENT_MODEL, pos, rad_to_deg(a) + rng.randf_range(-30.0, 30.0)))
	var veg_size: Array = entry.get("size", [8.0, 8.0, 6.0]) if not entry.is_empty() else [8.0, 8.0, 6.0]
	_stamp_temple_vegetation(center, 14.0, veg_size, rng, nodes)
	var site := {"kind": "temple", "center": center, "nodes": nodes, "radius": 14.0}
	placed_sites.append(site)
	return site


## LZ: cleared flattened circle, no structures.
func stamp_lz(center: Vector3) -> Dictionary:
	clear_and_flatten(center, 16.0)
	var site := {"kind": "lz", "center": center, "nodes": [], "radius": 16.0}
	placed_sites.append(site)
	return site
