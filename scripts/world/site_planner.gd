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

const FSB_MAIN_PATH: String = "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
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

## work_type -> Civilian occupation. Only the seven the schedule machinery already knows;
## a work_type with no entry here becomes off_duty rather than inventing a schedule.
## gun/mortar deliberately do NOT map to gun_crew: mission_generator._place_firebase_mg
## spawns a mannable M60 per gun_crew post, and 20 of them is not a firebase, it is a joke.
const FSB_WORK_OCCUPATION: Dictionary = {
	"watch": "sentry", "guard": "sentry", "mg": "sentry",
	"ammo": "quartermaster", "supply": "quartermaster",
	"radio": "radioman", "plot": "radioman",
	"cook": "mess_cook", "mess": "mess_cook",
}

## THE garrison ceiling: how many men stand inside the wire, curated and work-post
## alike. Guarded by tests/test_firebase_garrison.gd, which reads THIS constant.
const FSB_GARRISON_MAX_MEN: int = 24

## Upper bound on work_* variety. fsb_main_v3.glb carries 191 work markers
## (measured) and one man each would be a crowd the frame cannot pay for.
## Sampled by a deterministic stride, never randomly - ADR-010, same seed same base.
##
## This is a VARIETY cap, not the population cap: the real limit is whatever
## FSB_GARRISON_MAX_MEN leaves after the curated posts are seated. Holding both as
## independent constants is how the compound came to hold 17 curated + 12 work =
## 29 men against a documented ceiling of 24.
const FSB_WORK_POST_CAP: int = 12


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


## Garrison post/quarters positions in WORLD XZ, y left at 0 for the caller to
## seat on terrain (same contract as fsb_gate_metrics).
static func fsb_garrison_plan(center: Vector3) -> Dictionary:
	_ensure_fsb_markers()
	var origin: Vector3 = center - FSB_AABB_CENTER
	var posts: Array[Dictionary] = []
	for entry in FSB_GARRISON_POSTS:
		var key: String = entry[0]
		if not _fsb_markers.has(key):
			continue
		var p: Vector3 = origin + (_fsb_markers[key] as Vector3)
		p.y = 0.0
		posts.append({"pos": p, "occupation": str(entry[1]), "men": int(entry[2])})
	# The work_* markers authored across the compound, so the garrison stands at the mess
	# line, the wash drums and the ammo niches instead of only the thirteen curated posts.
	var wcount: int = _fsb_work_markers.size()
	var work_budget: int = clampi(FSB_GARRISON_MAX_MEN - _fsb_curated_men(), 0, FSB_WORK_POST_CAP)
	if wcount > 0 and work_budget > 0:
		var stride: int = maxi(1, int(floor(float(wcount) / float(work_budget))))
		var taken: int = 0
		var i: int = 0
		while i < wcount and taken < work_budget:
			var entry: Array = _fsb_work_markers[i]
			var wp: Vector3 = origin + (entry[0] as Vector3)
			wp.y = 0.0
			var occ: String = str(FSB_WORK_OCCUPATION.get(str(entry[1]), "off_duty"))
			# Alternate the two sentry shifts so the wire is not empty after dark.
			if occ == "sentry" and taken % 2 == 1:
				occ = "sentry_night"
			posts.append({"pos": wp, "occupation": occ, "men": 1})
			taken += 1
			i += stride

	var quarters: Array[Vector3] = []
	for key in FSB_GARRISON_QUARTERS:
		if not _fsb_markers.has(key):
			continue
		var q: Vector3 = origin + (_fsb_markers[key] as Vector3)
		q.y = 0.0
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
	_terrain.modify_terrain(center, FSB_FLATTEN_RADIUS,
		func(h: float, f: float) -> float:
			return lerpf(h, seat_norm, clampf(f / FSB_PLATEAU_FALLOFF, 0.0, 1.0)))
	for disc in FSB_CLEAR_DISCS:
		clear_and_flatten(center + (disc[0] as Vector3), float(disc[1]))
	var scene: PackedScene = load(FSB_MAIN_PATH)
	var root := scene.instantiate() as Node3D
	root.set_meta("model_name", "fsb_main")
	_parent.add_child(root)
	var origin: Vector3 = center - FSB_AABB_CENTER
	origin.y = seat_y
	root.global_position = origin
	# Tower ladders. Built AFTER the root is seated - Ladder caches world positions off the
	# markers, so building before the move would bake them at the wrong height.
	var ladders: int = Ladder.build_from_markers(root)
	if ladders == 0:
		push_warning("[FSB] no ladder_bottom/ladder_top pairs in the firebase GLB")
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
		"radius": FSB_HALF.length()}
	placed_sites.append(site)
	return site


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
	var site := {"kind": "vc_camp", "center": center, "nodes": nodes, "radius": 16.0}
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
