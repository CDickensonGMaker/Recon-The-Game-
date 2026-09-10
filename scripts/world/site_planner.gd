## site_planner.gd - Finds valid flat sites via GameplayGrid and stamps
## village / firebase / LZ layouts onto generated terrain (NS06).
class_name SitePlanner
extends RefCounted

const LitterTeamScript := preload("res://scripts/world/litter_team.gd")
## Preloaded, not by class_name: a global class is not registered until the editor rescans.
const SCREEN_DOOR := preload("res://scripts/world/screen_door.gd")

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
## `feather` extends the VEGETATION cut outward as a thinning band instead of ending it on a
## drawn circle. The ClearingSystem zone and the AI grid stay on `radius`, the hard line, so
## nothing the grid calls cleared has cover standing in it; in the feather band the grid still
## reads full jungle while the player sees thinning scrub, which errs toward the player having
## LESS cover than the AI credits him with - never more.
func clear_and_flatten(center: Vector3, radius: float, feather: float = 0.0) -> void:
	var disc_key := Vector3i(int(center.x * 10.0), int(center.z * 10.0), int(radius * 10.0))
	if _cleared_discs.has(disc_key):
		return
	_cleared_discs[disc_key] = true
	var zone_id: int = ClearingSystem.create_zone(center, radius)
	ClearingSystem.set_zone_stage(zone_id, ClearingSystem.ClearingStage.CLEARED)
	if _veg and _veg.has_method("clear_area"):
		_veg.clear_area(center, radius, _terrain.chunk_size, _terrain.heightmap, false, feather)
	if _grid:
		_grid.update_region(center, radius)


## Discs already levelled by flatten_pad(). Same guard as _cleared_discs and for the same
## reason: the pad is a LERP toward a mean, so a second call on the same disc moves the
## ground again and breaks ADR-010's re-stamp contract (same seed + same centre must yield
## identical heights). Once per disc, forever.
var _flattened_pads: Dictionary = {}


## PLANT A FLAT AREA FOR THE BUILDING TO STAND ON. His ask, 2026-09-09: *"if we can make it
## when we place a model that it plants a flat area for the building to exist that we
## shouldnt have any issue."*
##
## THIS IS NOT clear_and_flatten(), AND THAT IS THE WHOLE POINT. ADR-041 measured it and said
## so in as many words: `clear_and_flatten()` DOES NOT FLATTEN. It stages a ClearingSystem
## CLEARED zone, whose height_flattening is 0.7, and the heightmap's own falloff is
## `1.0 - smoothstep(0, radius, dist)` - which is 1.0 only at the exact centre cell and falls
## away immediately. So the strongest correction anywhere in that disc is a 0.7 lerp at one
## cell, and a metre out it is already a fraction of that. It cuts vegetation, paints the
## dirt and tells the AI grid the ground is open. It leaves the slope where it was, and a
## building seated on it hangs off the hill exactly as before.
##
## What this does instead:
##   - takes the MEAN height over the pad's own core, in the heightmap's own normalised units
##   - lerps every core cell to that mean at full `strength` - a FLAT plateau at strength 1.0
##   - ramps back out to the untouched ground across `shoulder` metres, so the pad meets the
##     hill instead of standing on a cliff the player cannot climb
##
## Returns the pad height in METRES, which is the seat every part on it stands at.
##
## Why the mean and not the centre sample: on a slope the centre is not the middle of the
## work. Levelling to the mean cuts as much as it fills, so the pad sits IN the hill; levelling
## to the centre sample leaves half the footprint buried and half in the air.
func flatten_pad(center: Vector3, radius: float, strength: float, shoulder: float) -> float:
	if _terrain == null or radius <= 0.0 or strength <= 0.0:
		return _terrain.get_height_at(center) if _terrain != null else center.y
	var key := Vector3i(int(center.x * 10.0), int(center.z * 10.0), int(radius * 10.0))
	if _flattened_pads.has(key):
		return float(_flattened_pads[key])

	var hm = _terrain.heightmap
	if hm == null:
		return _terrain.get_height_at(center)
	var cell: float = _terrain.cell_size
	var c: Vector2i = hm.world_to_cell(center.x, center.z)
	var r_cells: int = int(ceil(radius / cell))

	# The mean is taken in NORMALISED units because that is what modify_region hands the
	# modifier and what set_cell clamps. Converting to metres here and back inside the
	# lambda is two chances to divide by a height_scale that disagrees with the one
	# sample_world() decodes with - the exact drift meters_to_norm() exists to prevent.
	var total: float = 0.0
	var count: int = 0
	for z in range(maxi(0, c.y - r_cells), mini(hm.size, c.y + r_cells + 1)):
		for x in range(maxi(0, c.x - r_cells), mini(hm.size, c.x + r_cells + 1)):
			if Vector2(float(x - c.x), float(z - c.y)).length() > float(r_cells):
				continue
			total += hm.get_cell(x, z)
			count += 1
	if count == 0:
		return _terrain.get_height_at(center)
	var target: float = total / float(count)

	# The falloff modify_region supplies is a fixed smoothstep over the WHOLE edited radius,
	# so a modifier that used it would taper from the first cell out and never produce a
	# plateau. The cell's world XZ is passed for exactly this reason (heightmap_storage.gd
	# says so at modify_region): compute the pad's own profile - flat to `radius`, ramped
	# across `shoulder`.
	var cx: float = center.x
	var cz: float = center.z
	var s: float = clampf(strength, 0.0, 1.0)
	var sh: float = maxf(shoulder, 0.0)
	var level := func(h: float, _falloff: float, wx: float, wz: float) -> float:
		var d: float = Vector2(wx - cx, wz - cz).length()
		if d > radius + sh:
			return h
		var blend: float = s
		if d > radius and sh > 0.0:
			blend = s * (1.0 - smoothstep(0.0, 1.0, (d - radius) / sh))
		return lerpf(h, target, blend)
	_terrain.modify_terrain(center, radius + sh, level)

	# The grid caches slope and walkability off the heights we just moved. Without this the
	# AI still reads the hill that is no longer there.
	if _grid:
		_grid.update_region(center, radius + sh)
	var seat: float = hm.norm_to_meters(target)
	_flattened_pads[key] = seat
	return seat


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
			# Per-part override: the crashed-aircraft wrecks author their split in
			# the part names (wreck_hard_ engine/fuselage/mound stops rounds,
			# wreck_soft_ skin shoots through) - one per-file material cannot
			# express a wreck that is cover on one side and concealment on the
			# other (his ruling 2026-08-13).
			var nm := String(n.name)
			var part_soft: bool = soft
			if nm.begins_with("wreck_soft_"):
				part_soft = true
			elif nm.begins_with("wreck_hard_"):
				part_soft = false
			n.add_to_group("soft_cover" if part_soft else "hard_surface")


## Place one structure: StaticBody3D root (layer 1) + GLB visual + authored box.
## Placed props that are DESTRUCTIBLE rather than scenery, keyed by model name. The
## surface stash was a plain StaticBody3D with no HP entry, so his "destroy the stash"
## verb existed only underground (his question, 2026-08-28; ruled: wire it).
##
## THE VILLAGE HUTS WERE INDESTRUCTIBLE (playtest 2026-08-28, fixed 2026-09-06). The
## nha_* prefixes were declared in FSB_STRUCTURE_KINDS, but that table is walked ONLY by
## _wire_structure_destructibles, whose only caller is the firebase GLB path (:1927) - so
## a hut inside fsb_main_v3.glb could be blown down and the identical hut stamped into a
## village by this function could not. Two tables would drift again, so there is ONE:
## _destructible_kind_for() reads the exact map below first, then falls back to the SAME
## prefix table the firebase path uses.
const PLACED_DESTRUCTIBLE_KINDS := {
	"weapons_cache": "weapons_cache",
}


## The destructible kind for a placed model, or "" for scenery. Exact key wins; then the
## shared FSB_STRUCTURE_KINDS prefixes (nha_tranh_ / nha_san_ / nha_ruong_ and the fb_*
## families, which this path never places but costs nothing to honour).
static func _destructible_kind_for(model_name: String) -> String:
	var exact: String = str(PLACED_DESTRUCTIBLE_KINDS.get(model_name, ""))
	if exact != "":
		return exact
	for spec in FSB_STRUCTURE_KINDS:
		if model_name.begins_with(str(spec["prefix"])):
			return str(spec["kind"])
	return ""


func place_structure(model_path: String, world_pos: Vector3, rotation_deg: float) -> Node3D:
	var model_name := model_path.get_file().get_basename()
	var entry: Dictionary = CollisionTable.get_entry(model_name)
	var dkind: String = _destructible_kind_for(model_name)
	var body: StaticBody3D
	if dkind != "":
		var d := Destructible.new()
		d.kind = dkind
		d.hp = Destructible.hp_for(dkind)
		body = d
	else:
		body = StaticBody3D.new()
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
		MaterialBudget.structure(visual)
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
		if bool(entry.get("mesh", false)):
			# mesh: true -> the GLB carries -col trimesh nodes, which are the whole
			# collision: an authored box would double it AND seal the doorway the
			# generator verified you can walk through. The nav carve must follow the
			# same geometry, or the doorway is physically open and navigationally shut.
			body.set_meta("nav_trimesh", true)
		else:
			body.set_meta("nav_box", box_size)
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
	if dkind != "":
		# CollisionTable is the ONE ballistics authority (tag_ballistics above ran off it).
		# Destructible._ready() then adds its own default group on the way into the tree, so
		# the root would carry BOTH soft_cover and hard_surface and a round would read
		# whichever the bullet system happened to test first. Drop the loser.
		body.remove_from_group("hard_surface" if soft else "soft_cover")
		# The blast bus damages PROPS on a radius test (combat_manager.gd:176-185); an
		# unregistered Destructible is one nothing can ever hit.
		AgentRegistry.register(body, AgentRegistry.Kind.PROP)
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

	# Both ends of the routine are collected only now, so the animals spawned above
	# get their driver here rather than at place time.
	for h in homes:
		if h.node != null:
			AnimalRoutine.attach(h.node as Node3D, str(h.species), h.pos as Vector3,
				grazing, _terrain)
	for rec in props.animals:
		var an: Node3D = rec.node
		AnimalRoutine.attach(an, str(rec.species),
			_home_for(str(rec.species), homes, an.global_position), grazing, _terrain)

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
	var free_animals: Array = []
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
			free_animals.append({"species": str(animal_name), "node": animal})
	return {"nodes": prop_nodes, "stations": stations, "animals": free_animals}


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
	MaterialBudget.structure(visual)
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


## A free-roamer beds down at the nearest home of its own species, or where it
## spawned when the village has none.
func _home_for(species: String, homes: Array, fallback: Vector3) -> Vector3:
	var best: Vector3 = fallback
	var best_d: float = INF
	for h in homes:
		if str(h.species) != species:
			continue
		var d: float = fallback.distance_to(h.pos as Vector3)
		if d < best_d:
			best_d = d
			best = h.pos as Vector3
	return best


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


## THE BAKED CAST T-POSED IN THE MEDICAL TENT because every clip keys every rig.
## Caleb, 2026-08-27: "all units inside are T-posed, no animations". Measured
## 2026-09-06 out of the imported firebase scene: 13 clips, 386 tracks EACH, and
## each clip's tracks cover ALL TEN skinned rigs - but exactly ONE rig's values
## vary over the clip. Blender exported every scene rig into every action, so the
## nine passengers ride at their REST pose, which for a mixamorig_* skeleton is
## the T-pose. The old pass then played all twelve non-MC_ clips at once on twelve
## sibling players sharing one skeleton set: last writer wins, so one rig moved and
## nine were pinned in bind pose. It reported `played=12` and looked correct.
##
## THE FIX IS ONE PLAYER PER RIG, PLAYING ONLY THAT RIG'S TRACKS. The owner of a
## clip is measured, never guessed from its name (`med_or_support_high` drives
## medic0, `office_write` drives two officers): a rig owns a clip when its own
## tracks actually CHANGE across the clip. A rig that several clips move keeps the
## first in get_animation_list() order - deterministic, ADR-010, same GLB same cast.
##
## MC_* is a mechanism FIRE beat, not an idle: looping it would fire the baked tube
## forever, and no fire path reaches this player.
const CAST_QUAT_EPS: float = 0.02      ## radians of bone rotation that counts as motion
const CAST_POS_EPS: float = 0.002      ## metres of bone translation that counts as motion


## True when `rig`'s own tracks in `anim` change value across the clip. A track set
## that never moves is a passenger the exporter welded in, not a performance.
static func _cast_rig_moves(anim: Animation, rig: String) -> bool:
	var prefix: String = rig + "/"
	for t in range(anim.get_track_count()):
		if not str(anim.track_get_path(t)).begins_with(prefix):
			continue
		var kc: int = anim.track_get_key_count(t)
		if kc < 2:
			continue
		var v0: Variant = anim.track_get_key_value(t, 0)
		for k in range(1, kc):
			var vk: Variant = anim.track_get_key_value(t, k)
			if typeof(v0) == TYPE_QUATERNION:
				if (v0 as Quaternion).angle_to(vk as Quaternion) > CAST_QUAT_EPS:
					return true
			elif typeof(v0) == TYPE_VECTOR3:
				if ((v0 as Vector3) - (vk as Vector3)).length() > CAST_POS_EPS:
					return true
	return false


static func _animate_fsb_baked_cast(root: Node3D) -> void:
	var played: int = 0
	var staged: Dictionary = {}
	for n in root.find_children("*", "AnimationPlayer", true, false):
		var src := n as AnimationPlayer
		if src == null:
			continue
		# rig name -> the clip that actually moves it, first in list order.
		var owner_clip: Dictionary = {}
		var rig_order: Array[String] = []
		for anim_name in src.get_animation_list():
			var clip: String = String(anim_name)
			if clip.begins_with("MC_"):
				continue
			var anim: Animation = src.get_animation(clip)
			var seen: Dictionary = {}
			for t in range(anim.get_track_count()):
				var head: String = str(anim.track_get_path(t)).get_slice("/", 0)
				if head == "" or head.contains(":"):
					continue          # a track on the player root itself owns no rig
				seen[head] = true
			for rig in seen.keys():
				var r: String = str(rig)
				if owner_clip.has(r):
					continue
				if not _cast_rig_moves(anim, r):
					continue
				owner_clip[r] = clip
				rig_order.append(r)
		rig_order.sort()
		for rig in rig_order:
			var clip2: String = str(owner_clip[rig])
			# One filtered copy per rig. Stripping the passenger tracks is what stops
			# this player writing a T-pose over the nine rigs it does not own.
			var cut: Animation = (src.get_animation(clip2) as Animation).duplicate(true)
			for t in range(cut.get_track_count() - 1, -1, -1):
				if not str(cut.track_get_path(t)).begins_with(rig + "/"):
					cut.remove_track(t)
			if cut.get_track_count() == 0:
				continue
			cut.loop_mode = Animation.LOOP_LINEAR
			var lib := AnimationLibrary.new()
			lib.add_animation(&"idle", cut)
			var p := AnimationPlayer.new()
			p.name = "CastPlayer_" + rig
			p.add_animation_library(&"", lib)
			src.get_parent().add_child(p)
			p.root_node = p.get_path_to(src.get_node(src.root_node))
			# Free-running idles, not choreography: each man starts at his own phase so
			# three attendants are not one attendant three times. Deterministic in the
			# rig name, so the same GLB always stages the same cast (ADR-010).
			p.play(&"idle")
			p.seek(fposmod(float(hash(rig) % 1000) * 0.001 * cut.length, cut.length), true)
			played += 1
			staged[rig] = true
	# ADR-042 clause 1. A rig this pass does not stage keeps its BIND POSE, and a bind-pose
	# mixamorig_* skeleton IS the T-pose he keeps reporting. The skip is silent by
	# construction - `_cast_rig_moves` returning false just `continue`s - so the only way to
	# know which bodies are standing frozen is to name them.
	var frozen: PackedStringArray = PackedStringArray()
	for sk in root.find_children("*", "Skeleton3D", true, false):
		var owner_name: String = String((sk as Node).get_parent().name) if (sk as Node).get_parent() != null else ""
		if owner_name != "" and not staged.has(owner_name):
			frozen.append(owner_name)
	frozen.sort()
	print("[FSB] baked cast: %d rig(s) staged, %d left at BIND POSE (T-pose)%s" % [
		played, frozen.size(), "" if frozen.is_empty() else " - " + ", ".join(frozen)])
	if played == 0:
		push_warning("[FSB] no baked cast clips in the firebase GLB - export drift")


## THE T-POSE AUDIT. His report, three playtests running: "medical tent has everyone t posed
## still and all the soldiers just sit around." A mixamorig_* skeleton sitting at bind pose IS
## the T-pose, and every way of getting there is SILENT - a rig no clip moves, a hide that
## missed because the GLB is flat, an AnimationPlayer that was never given one. So measure the
## outcome instead of any of the causes: a skeleton that is VISIBLE and has every bone on its
## rest pose is a frozen body, whatever put it there.
##
## Deliberately excludes rigs that are hidden (the swapped howitzers) and machine rigs, which
## have no bind pose worth the name. Reported by NAME - "some bodies are T-posed" is not a lead.
const FROZEN_AUDIT_IGNORE: Array[String] = ["M101Rig"]

static func _audit_frozen_bodies(root: Node3D) -> void:
	var frozen: PackedStringArray = PackedStringArray()
	var checked: int = 0
	for n in root.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		if sk == null or not sk.is_visible_in_tree():
			continue
		var owner_node: Node = sk.get_parent()
		var nm: String = String(owner_node.name) if owner_node != null else String(sk.name)
		var skip: bool = false
		for ig in FROZEN_AUDIT_IGNORE:
			if nm.begins_with(ig):
				skip = true
				break
		if skip:
			continue
		checked += 1
		var moved: bool = false
		for b in range(sk.get_bone_count()):
			if not sk.get_bone_pose(b).is_equal_approx(sk.get_bone_rest(b)):
				moved = true
				break
		if not moved:
			frozen.append(nm)
	frozen.sort()
	if frozen.is_empty():
		print("[FSB] frozen-body audit: %d visible rig(s), none at bind pose" % checked)
	else:
		push_warning("[FSB] T-POSE: %d of %d visible rig(s) sit at BIND POSE - %s"
			% [frozen.size(), checked, ", ".join(frozen)])


## Swap each baked howitzer for the animated fb_emplacement_m101 chunk at its exact
## transform, so GunCrewPerformance._bind_piece finds an AnimationPlayer carrying
## "M101Rig" within PIECE_SEARCH_M of the pit. Kit and baked emplacement share local
## coordinates 1:1 (measured 2026-08-24: M101Rig at [0,-0.043,0], stations identical).
## The baked node is HIDDEN, never freed: its -colonly colliders are scene-root
## siblings that stay live, and the chunk carries visuals only. The chunk's baked
## crew rigs are hidden too - fsb_garrison_plan seats the real crew at the work_gun
## markers. MUST run after _animate_fsb_baked_cast: that pass loops every non-MC_
## clip it finds, and looping M101Rig would fire the recoil forever.
func _wire_m101_rigs(root: Node3D) -> void:
	var chunk: PackedScene = load(M101_CHUNK_PATH) as PackedScene
	if chunk == null:
		push_warning("[FSB] fb_emplacement_m101.glb missing - howitzers stay static")
		return
	var wired: int = 0
	for n in root.find_children("m101_emplacement*", "Node3D", true, false):
		var baked := n as Node3D
		if baked == null:
			continue
		baked.visible = false
		var inst := chunk.instantiate() as Node3D
		root.add_child(inst)
		inst.global_transform = baked.global_transform
		for crew in inst.find_children("PSXRig_*", "Node3D", true, false):
			(crew as Node3D).visible = false
		wired += 1
	if wired == 0:
		push_warning("[FSB] no m101_emplacement nodes in the firebase GLB - export drift")
	print("[FSB] m101: %d emplacement(s) swapped for the animated chunk" % wired)


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
## The animated M101 chunk: the same emplacement the fsb bakes, WITH the
## M101Rig/MC_* clips the baked copy lacks (fsb ships M101Rig skins, 0 clips).
const M101_CHUNK_PATH: String = "res://assets/world/building models/structures/firebase/kit/fb_emplacement_m101.glb"
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
##
## HIS RULING 2026-09-09: "add more grass around the fire base and some trees too, just have the
## cut away be 20 m around the firebase and stagger it at that too." 140 m was a hard-edged
## circle that left up to 88 m of bald ground outside the wire.
##
## The wire is not a circle. Read off fsb_main_v3_mound.json through the same math
## fsb_mound_height() uses (r0 66 m, ridge_stretch 1.28, three edge harmonics, berm_w 3.2), the
## berm crest stands at a world radius of 51.8 m on its narrowest bearing and 99.7 m on its
## widest, mean 78.5. A single disc cannot be 20 m outside all of that at once: 120 m is
## exactly +20 on the widest bearing and more on the rest. Following the wire properly needs a
## SHAPED clear, which also reshapes the patrol AO's firebase site pick (plan_firebase_main_center
## scores off these offsets) - named for him, not smuggled in tonight.
##
## FSB_CLEAR_FEATHER is the "stagger it": past 120 m the cut does not stop, it thins, over 26 m
## with a 6 m wobble on the band's own edge (vegetation_manager._hole_removes). No bearing shows
## a drawn radius any more.
const FSB_CLEAR_DISCS: Array = [
	[Vector3.ZERO, 120.0],
]
const FSB_CLEAR_FEATHER: float = 26.0


## Marker locals cached once; plan-time band math and build-time placement use
## the SAME numbers (one math path, never re-derived by hand).
## The Y the firebase model was ACTUALLY seated at - place_firebase_main's 7x7 footprint
## MEAN. It is not `center.y`: plan_firebase_main_center returns y = 0.0, and the demo
## seeds center.y from a single pre-sculpt height sample. Marker world positions built on
## center.y are off by the difference, which drops the garrison under its own floor and
## hands it to the watchdog's re-seat.
static var _fsb_seat_y: float = 0.0
static var _fsb_seated: bool = false


## World origin for the firebase's authored markers, on the height the model was seated at.
static func _fsb_marker_origin(center: Vector3) -> Vector3:
	var origin: Vector3 = center - FSB_AABB_CENTER
	if _fsb_seated:
		origin.y = _fsb_seat_y
	return origin


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
	# The MG bunker's own firing point. "sentry" gave it a man and no gun, so the one
	# emplacement the compound is built around could not be manned - by him or by the
	# garrison. gun_crew is what stands an MGEmplacement there (mission_generator:1045).
	["mg_fire_point_001", "gun_crew", 1],
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

## work_* markers baked into the firebase GLB, as [pos, work_type, diggable]. Cached
## alongside the named keys because the garrison reads them by PREFIX, not by exact name.
static var _fsb_work_markers: Array = []

## The dig clip may only play at a work_dig marker standing within DIG_NEAR_M of a
## defensive earthwork mesh (his ruling 2026-08-24: "make specific spots where the DIG
## animation can happen. like close to the berms or a bunker"). Measured 2026-08-24:
## 10 of the GLB's 12 work_dig markers classify.
const DIG_NEAR_M: float = 8.0
const EARTHWORK_FAMILIES: Array[String] = [
	"berm", "bunker", "sandbag", "foxhole", "trench", "revet", "parapet",
]
## fb_berm_ring's AABB spans ~198m - the whole compound - so proximity to it would
## classify every marker. Meshes wider than this are perimeter rings, not spots; the
## sandbag/revet meshes lining the berm carry the classification there instead.
const EARTHWORK_SPAN_MAX_M: float = 60.0

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
	# THE BUNKER FIRE POINTS. 37 markers - 28 at fighting bunkers, 8 at MG bunkers.
	# The fighting bunkers used to emit NO station at all, so no garrison man could
	# ever occupy one during a siege; the art side was fixed, but the type was never
	# registered here, so all 37 fell through to off_duty and the bunkers stayed empty
	# in a different way. A man in an embrasure is watching his arc.
	"bunker": "sentry",
	# THE AID STATION. Staff and wounded are different occupations - "patient" drives
	# the lying/immobile clip set, and mapping a casualty to "medic" stands him up and
	# walks him around his own ward.
	"med_surgeon": "medic", "med_scrubnurse": "medic", "med_anesthetist": "medic",
	"med_tend": "medic", "med_officer": "medic",
	"med_cot": "patient", "med_or_patient": "patient",
	# The rest of the chow line. cook_range is the servery's hot side; the tray pair
	# are the return end of his diner loop (2026-08-07), same as chow_tray_return.
	"cook_range": "mess_cook",
	"traycollector": "mess_hall", "trayhandoff": "mess_hall",
	# THE HOOCH (marker names work_<building>_<role>, same convention as the chow hall).
	# off_duty is the CORRECT answer here - a billet is where men are not working - but
	# it has to be stated, because an unlisted type reaches off_duty by accident and
	# reads identically to a type nobody remembered to wire.
	"hooch_sleep": "off_duty", "hooch_table": "off_duty", "hooch_radio": "off_duty",
	"hooch_locker": "off_duty", "hooch_door": "off_duty",
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
	"chow_trigger", "chow_exit", "chow_tray_return",
	# The aid station is NOT in this list. It is seeded whole in fsb_garrison_plan
	# ahead of the rotation, exactly like the artillery crews, and its markers are
	# skipped when the by-type pool is built. Listing them here as well would seat a
	# second man on top of every one of them.
	# Bunkers sit with the other sentry posts - below the working party, above the
	# off-duty billet, and 37 markers means the stride samples them rather than
	# flooding the budget.
	"bunker",
	"cook_range", "traycollector", "trayhandoff",
	# The billet is last on purpose: a man asleep in a hooch is the cheapest thing the
	# garrison can spend a post on, and there are 8 sleep markers per hooch x 11.
	"hooch_sleep", "hooch_table", "hooch_radio", "hooch_locker", "hooch_door",
]

## THE garrison ceiling: how many men stand inside the wire, curated and work-post
## alike. Guarded by tests/test_firebase_garrison.gd, which reads THIS constant.
## 24 -> 40 measured 2026-07-31 on the exported demo (150s A/B; the flag that run
## cited did not exist then - `--print-fps` became real 2026-08-04, W-4):
## mid-siege 48.0 FPS at both values - the men are not the frame cost. If the
## siege now feels too safe to hold, this is the dial back toward 28-32.
const FSB_GARRISON_MAX_MEN: int = 40

## Upper bound on work_* variety. fsb_main_v3.glb carries 487 work markers
## (measured 2026-08-24) and one man each would be a crowd the frame cannot pay for.
## Sampled by a deterministic stride, never randomly - ADR-010, same seed same base.
##
## This is a VARIETY cap, not the population cap: the real limit is whatever
## FSB_GARRISON_MAX_MEN leaves after the curated posts are seated. Holding both as
## independent constants is how the compound came to hold 17 curated + 12 work =
## 29 men against a documented ceiling of 24.
const FSB_WORK_POST_CAP: int = 24

## THE AID STATION SEED. The OR table's three standing positions - measured
## 2026-09-06 at 2.0-2.2m from the baked PSXRig_med_or_patient, and carrying no
## baked body of their own. Ordered: the surgeon is the man the station is about,
## so a two-man budget buys the surgeon and the scrub nurse.
const MED_SURGICAL_TYPES: Array[String] = ["med_surgeon", "med_scrubnurse", "med_anesthetist"]
## Two is the image - a man working and a man assisting. The anesthetist is the
## third body and the first one a tight budget drops.
const MED_SURGICAL_MEN: int = 2
## Ceiling on live men in cots however bad the tour went. The GLB carries 7 cots.
const MED_WARD_MEN_MAX: int = 3


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
		# The howitzers are bare `work_gun`; the mortar pits carry a pit ordinal AND a role,
		# `work_mortar_<pit>_<gunner|dropper|runner>`, which the single-ordinal strip in
		# _ensure_fsb_markers cannot reduce to "mortar". Matching the prefix is what lets a
		# mortar pit crew at all - without it both pits seated nobody and the mortar_gunner /
		# mortar_dropper / mortar_runner clips had no caller.
		var is_mortar: bool = wt == "mortar" or wt.begins_with("mortar_")
		if wt != "gun" and not is_mortar:
			continue
		var p: Vector3 = e[0]
		var joined: bool = false
		for pit_any in pits:
			var pit: Dictionary = pit_any
			for q_any in (pit.markers as Array):
				var q: Vector3 = q_any
				if Vector2(p.x - q.x, p.z - q.z).length() <= FSB_ARTY_LINK_M:
					(pit.markers as Array).append(p)
					pit["mortar"] = bool(pit.mortar) or is_mortar
					joined = true
					break
			if joined:
				break
		if not joined:
			pits.append({"markers": [p], "mortar": is_mortar})
	return pits


## Men already promised by the curated post table - counting only the posts whose MARKER
## EXISTS. A curated entry whose marker is absent from the GLB is skipped silently when the
## posts are built (the `continue` below), but this function used to sum the TABLE, so the
## budget still paid for men nobody ever spawned. ADR-042 clause 1: the misses are named.
static func _fsb_curated_men() -> int:
	var n: int = 0
	var missing: PackedStringArray = PackedStringArray()
	for entry in FSB_GARRISON_POSTS:
		if _fsb_markers.has(String(entry[0])):
			n += int(entry[2])
		else:
			missing.append("%s (%s x%d)" % [String(entry[0]), String(entry[1]), int(entry[2])])
	if not missing.is_empty():
		push_warning("[FSB] %d curated post(s) name a marker the GLB does not carry - %s"
			% [missing.size(), ", ".join(missing)])
	return n


## Offsets are accumulated up to the GLB root: every consumer adds them to the
## compound center, so a marker nested under a sub-node must not contribute its
## parent-local position.
## ADR-043 P0. The runtime no longer builds the firebase to read its markers.
##
## THE DEFECT THIS CLOSES, measured 2026-09-09: this function instantiated the whole
## 5,812-node scene and freed it purely to read ~500 marker origins - and it fired at
## PLAN time, because mission_generator.gd:519 and :722 both call fsb_gate_metrics for
## the gate and the LZ before the world exists. The world then built the same scene
## AGAIN for real. Two full scene builds per world build, one of them thrown away.
##
## Now: bake once to disk with tools/bake_fsb_markers.tscn, read the JSON at runtime.
## The walk survives as bake_fsb_markers_from_scene() because the baker and the probe
## both need it - ONE implementation, two callers, which is why a re-export cannot
## silently disagree with the bake.
const FSB_MARKER_BAKE_PATH: String = "res://data/world/fsb_markers.json"
## Bumped when the bake's SHAPE changes, never when the firebase does. A stale-shaped
## file is refused rather than half-read.
const FSB_MARKER_BAKE_VERSION: int = 1


static func _ensure_fsb_markers() -> void:
	if not _fsb_markers.is_empty():
		return
	if _load_fsb_marker_bake():
		return
	# The bake is the shipping path. Walking the scene here is a LAST RESORT that keeps
	# the game playable on a fresh checkout before the baker has ever run - it is loud
	# on purpose, and tests/test_fsb_marker_bake.tscn fails the build if the bake is
	# missing or has drifted from the model.
	push_warning("[FSB] marker bake missing or stale at %s - walking the scene instead. "
		% FSB_MARKER_BAKE_PATH
		+ "Run: godot --headless --path . res://tools/bake_fsb_markers.tscn")
	var baked: Dictionary = bake_fsb_markers_from_scene()
	_adopt_fsb_marker_bake(baked)


## Read the baked markers. Returns false (having changed nothing) whenever the file is
## absent, unparseable, of the wrong shape version, or empty - every one of which must
## fall through to the walk rather than leave the compound with no markers at all.
static func _load_fsb_marker_bake() -> bool:
	if not FileAccess.file_exists(FSB_MARKER_BAKE_PATH):
		return false
	var f := FileAccess.open(FSB_MARKER_BAKE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != FSB_MARKER_BAKE_VERSION:
		return false
	var raw_markers: Dictionary = d.get("markers", {}) as Dictionary
	var raw_work: Array = d.get("work", []) as Array
	if raw_markers.is_empty() and raw_work.is_empty():
		return false
	var markers: Dictionary = {}
	for key_any in raw_markers.keys():
		var v: Array = raw_markers[key_any] as Array
		if v == null or v.size() != 3:
			continue
		markers[String(key_any)] = Vector3(float(v[0]), float(v[1]), float(v[2]))
	var work: Array = []
	for entry_any in raw_work:
		var e: Array = entry_any as Array
		if e == null or e.size() != 5:
			continue
		work.append([Vector3(float(e[0]), float(e[1]), float(e[2])), String(e[3]), bool(e[4])])
	_adopt_fsb_marker_bake({"markers": markers, "work": work})
	return true


static func _adopt_fsb_marker_bake(baked: Dictionary) -> void:
	_fsb_markers = (baked.get("markers", {}) as Dictionary).duplicate()
	_fsb_work_markers.clear()
	for entry_any in (baked.get("work", []) as Array):
		_fsb_work_markers.append((entry_any as Array).duplicate())


## Walk the firebase scene and derive every marker the game reads from it. THE ONE
## implementation: tools/bake_fsb_markers.gd writes its output to disk and
## tests/test_fsb_marker_bake.gd compares the file against a fresh call, so a
## re-export that moves a marker turns the suite red instead of shipping stale data.
## Returns {markers: {String: Vector3}, work: [[Vector3, String, bool]]}.
static func bake_fsb_markers_from_scene() -> Dictionary:
	var markers: Dictionary = {}
	var work: Array = []
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
		markers[key] = t.origin
	var earthworks: Array[AABB] = []
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if not (nd is Node3D):
			continue
		if nd is MeshInstance3D and not String(nd.name).begins_with("work_"):
			var low: String = String(nd.name).to_lower()
			for fam in EARTHWORK_FAMILIES:
				if low.contains(fam):
					var t3 := Transform3D.IDENTITY
					var cur3: Node3D = nd as Node3D
					while cur3 != null and cur3 != inst:
						t3 = cur3.transform * t3
						cur3 = cur3.get_parent() as Node3D
					var box: AABB = t3 * (nd as MeshInstance3D).get_aabb()
					if box.size.x < EARTHWORK_SPAN_MAX_M and box.size.z < EARTHWORK_SPAN_MAX_M:
						earthworks.append(box)
					break
			continue
		if not String(nd.name).begins_with("work_"):
			continue
		var t2 := Transform3D.IDENTITY
		var cur2: Node3D = nd as Node3D
		while cur2 != null and cur2 != inst:
			t2 = cur2.transform * t2
			cur2 = cur2.get_parent() as Node3D
		# work_<type>, with Blender's .001 / glTF _001 duplicate suffix stripped.
		# REPEATED, not once: an authored name that already ends in an ordinal picks up a
		# second one from Blender, so work_hooch_sleep_0.001 arrives as hooch_sleep_0_001
		# and one strip leaves hooch_sleep_0 - a type FSB_WORK_OCCUPATION does not list, which
		# then reaches off_duty by accident and reads exactly like a type nobody wired.
		var wt: String = String(nd.name).trim_prefix("work_")
		while true:
			var cut: int = wt.rfind("_")
			if cut <= 0 or not wt.substr(cut + 1).is_valid_int():
				break
			wt = wt.substr(0, cut)
		work.append([t2.origin, wt, false])
	for entry_any in work:
		var e: Array = entry_any
		if str(e[1]) != "dig":
			continue
		var p: Vector3 = e[0]
		for box_any in earthworks:
			var box: AABB = box_any
			var dx: float = maxf(maxf(box.position.x - p.x, 0.0), p.x - box.end.x)
			var dz: float = maxf(maxf(box.position.z - p.z, 0.0), p.z - box.end.z)
			if Vector2(dx, dz).length() <= DIG_NEAR_M:
				e[2] = true
				break
	work.sort_custom(func(a: Array, b: Array) -> bool:
		var pa: Vector3 = a[0]
		var pb: Vector3 = b[0]
		if not is_equal_approx(pa.x, pb.x):
			return pa.x < pb.x
		return pa.z < pb.z)
	inst.free()
	return {"markers": markers, "work": work}


## Garrison post/quarters positions in WORLD space. Y is the AUTHORED marker height over
## the seat the MODEL was placed at (kept since 2026-08-04); seat with GameWorld.floor_y
## from it, never surface_y. Call only after place_firebase_main - before it, the seat is
## unknown and the marker Y falls back to center.y, which is not the model's ground.
static func fsb_garrison_plan(center: Vector3) -> Dictionary:
	_ensure_fsb_markers()
	var origin: Vector3 = _fsb_marker_origin(center)
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
			(by_type[wt] as Array).append(e)
		# FSB_WORK_PRIORITY first, then anything the GLB carries that it does not name,
		# in marker order. Sorting alphabetically instead would spend the whole budget
		# on ammo/burn/cook/dig and never reach the medic.
		var type_order: Array[String] = []
		for wt in FSB_WORK_PRIORITY:
			if by_type.has(wt):
				type_order.append(wt)
		for wt in seen_order:
			# THE AID STATION NEVER ENTERS THE ROTATION, for two reasons measured
			# 2026-09-06. One: the GLB's baked cast already STANDS at med_tend,
			# med_officer and med_or_patient - within 1.05m of each marker - so a rotated
			# man spawns inside a body that is already there. Two: med_root is a parent
			# node, not a post, and loafing off-duty is not a thing to do in a ward. The
			# station is seeded whole below, off the markers that are EMPTY - which is
			# why the pools above still COLLECT med_*, they just do not rotate it.
			if wt.begins_with("med"):
				continue
			if not type_order.has(wt):
				type_order.append(wt)
		var taken: int = 0
		# THE AID STATION IS SEEDED, not left to the rotation. A medic alone at a
		# station plays medic_treat_give over empty ground - he mimes surgery on the
		# dirt. So the station opens with a man on the table, which is also the
		# casualty-ledger floor: an aid station with nobody in it is the fresh-player
		# failure. Wounded ABOVE this floor are the ledger's job, not the layout's.
		#
		# THIS BLOCK WAS DEAD FOR AS LONG AS IT EXISTED. It keyed on work type "medic",
		# and fsb_main_v3.glb carries no such marker - measured 2026-09-06: 488 work
		# markers, zero "medic", and the aid station spelled out instead as
		# med_surgeon / med_scrubnurse / med_anesthetist / med_cot / med_tend /
		# med_officer / med_or_patient / med_root. So med_pool was always empty, the
		# seed never ran, and med_* sat 27th in FSB_WORK_PRIORITY behind a budget that
		# runs out at "rest": the plan came back with ZERO medic and ZERO patient posts
		# out of 34. Caleb, 2026-08-27: "no wounded/dead present".
		#
		# It now seeds off the markers that are actually EMPTY. The three attendants,
		# the three med officers and the man on the OR table are BAKED into the GLB and
		# animate from _animate_fsb_baked_cast; live men there would stand inside them.
		# The surgical positions around the table carry no baked body, and neither does
		# a single cot.
		var or_pool: Array = []
		for mt in MED_SURGICAL_TYPES:
			var tp: Array = by_type.get(mt, [])
			if tp.size() > 0:
				or_pool.append(tp[0])
		var cot_pool: Array = by_type.get("med_cot", [])
		var ward_pos: Vector3 = Vector3.ZERO
		if or_pool.size() >= 2 and work_budget >= 2:
			for i in range(mini(or_pool.size(), MED_SURGICAL_MEN)):
				var mp: Vector3 = origin + ((or_pool[i] as Array)[0] as Vector3)
				if i == 0:
					ward_pos = mp
				posts.append({"pos": mp, "occupation": "medic", "men": 1})
				taken += 1
		# THE WOUNDED ARE THE LEDGER MADE VISIBLE. How many cots are full is
		# CampaignState.ward_wounded, not a layout constant - a fresh tour opens at
		# WARD_SEED_ON_NEW_TOUR and a bad operation fills the ward. Capped so a
		# catastrophic tour does not spend the whole work budget on bed rest.
		var cots_full: int = clampi(CampaignState.ward_wounded, 0,
			mini(cot_pool.size(), MED_WARD_MEN_MAX))
		cots_full = mini(cots_full, maxi(0, work_budget - taken))
		for i in range(cots_full):
			var cp: Vector3 = origin + ((cot_pool[i] as Array)[0] as Vector3)
			# `cot` tells the spawner this man does not stand: he is pinned on the
			# mattress as a puppet. mission_generator._build_firebase_garrison owns it.
			posts.append({"pos": cp, "occupation": "patient", "men": 1, "cot": true})
			taken += 1
		if taken > 0:
			# THE LITTER TEAM IS THE BUTCHER'S BILL MADE VISIBLE. Seeded on the same
			# rule as the station itself, but CONDITIONALLY: a stretcher crossing the
			# compound has to MEAN someone got hurt, so it runs only when the ward is
			# above its floor. Otherwise these three posts return to the rotation and
			# the working party keeps its men. Cost when it runs: 3 work posts (two
			# bearers plus the man on the litter). It collects from a cot NOBODY is lying
			# on, so the bearers never load a man who is already in the bed.
			var ward_full: bool = CampaignState.ward_wounded > CampaignState.WARD_SEED_ON_NEW_TOUR
			var litter_ok: bool = cot_pool.size() > cots_full and work_budget >= taken + 3
			if litter_ok and ward_full and ward_pos != Vector3.ZERO and LitterTeamScript.available():
				var cot: Vector3 = origin + ((cot_pool[cots_full] as Array)[0] as Vector3)
				posts.append({"pos": cot, "occupation": "litter", "men": 3, "ward": ward_pos})
				taken += 3
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
				var pe: Array = pool[round_i]
				var wp: Vector3 = origin + (pe[0] as Vector3)
				var occ: String = str(FSB_WORK_OCCUPATION.get(wt, "off_duty"))
				# Alternate the two sentry shifts so the wire is not empty after dark.
				if occ == "sentry" and taken % 2 == 1:
					occ = "sentry_night"
				# "role" carries the raw work_type: occupation is lossy, and the animation
				# picker needs to tell a chow server from a man in the queue.
				posts.append({"pos": wp, "occupation": occ, "men": 1, "role": wt,
					"dig_ok": bool(pe[2])})
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


## HOW FAR THIS GROUND STANDS ABOVE THE GROUND AROUND IT. Positive on a hilltop, negative in
## a hollow. The ring is an ELLIPSE, not a circle, so a rectangular footprint is sampled the
## same distance beyond its wire on every bearing instead of 149 m out on one axis and 111 m
## on the other. Samples that fall off the map are skipped rather than clamped: a clamped
## sample reads the edge cell twice and quietly pulls every coastal site toward the shore.
##
## READS THE HEIGHTMAP, NEVER A RAYCAST. A raycast hits whatever has been placed and reports
## its roof, which is how "hanging bulbs at +7.8 m" was once measured as correct.
##
## ONE AUTHORITY, TWO CALLERS. plan_firebase_main_center() scores with it and
## tools/firebase_site_pick.gd delegates to it, so the ground the tool photographs and the
## ground the game builds on cannot drift apart. That drift is exactly what this function was
## written to close: the two pickers disagreed until 2026-09-10.
static func prominence(terrain: Node, centre: Vector3, ring_x: float, ring_z: float,
		samples: int = 12) -> float:
	if terrain == null or samples <= 0:
		return 0.0
	var map_size: float = float(terrain.map_size) if "map_size" in terrain else 0.0
	var here: float = terrain.get_height_at(centre)
	var total: float = 0.0
	var n: int = 0
	for k in range(samples):
		var a: float = TAU * float(k) / float(samples)
		var p := Vector3(centre.x + cos(a) * ring_x, 0.0, centre.z + sin(a) * ring_z)
		if map_size > 0.0 and (p.x < 0.0 or p.z < 0.0 or p.x > map_size or p.z > map_size):
			continue
		total += terrain.get_height_at(p)
		n += 1
	if n == 0:
		return 0.0
	return here - total / float(n)


## [min_y, max_y] of the terrain over a disc. The other half of the pick, and the same
## instrument rule as prominence(): heightmap, never a raycast.
static func relief(terrain: Node, centre: Vector3, radius: float, samples: int = 15) -> Array:
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	if terrain == null:
		return [0.0, 0.0]
	for iz in range(samples):
		for ix in range(samples):
			var fx: float = float(ix) / float(samples - 1) * 2.0 - 1.0
			var fz: float = float(iz) / float(samples - 1) * 2.0 - 1.0
			if Vector2(fx, fz).length() > 1.0:
				continue
			var h: float = terrain.get_height_at(
				Vector3(centre.x + fx * radius, 0.0, centre.z + fz * radius))
			lo = minf(lo, h)
			hi = maxf(hi, h)
	if lo > hi:
		return [0.0, 0.0]
	return [lo, hi]


## How far beyond the wire the outlook ring is measured. 40 m is a rifle-fight distance and
## the scale the defect was reported at - "four of six bunkers were looking straight into
## rising ground 12-18 m out" (tools/firebase_site_pick.gd). Ground that overlooks the wire
## from 40 m is ground a machine gun sits on.
const FSB_OUTLOOK_M: float = 40.0
## Weight on the prominence term. 2.0 matches the flatness penalty already in the score.
const FSB_PROMINENCE_W: float = 2.0
## AND IT IS CAPPED, which is the whole lesson of the first run of tools/probe_site_pick.gd.
##
## Uncapped, the term did its job too well: it moved the pick off a hollow 3.02 m BELOW the
## ground outside its own wire and onto a summit 13.22 m above it - and bought that height
## with 9.87 m of extra relief across a 298 x 222 m footprint. That is the ridge-shoulder
## failure tools/firebase_site_pick.gd already records in its own header ("leaving a 7 m cut
## face in front of the same bunkers"). A firebase that has to cut 20 m of hill flat is not
## on high ground, it is in a quarry.
##
## The defect being fixed is BEING OVERLOOKED, not failing to be the highest thing on the map.
## 4 m clear of the ground 40 m out is enough that nothing fires down into the compound; past
## that the term stops paying, and flatness - which is still weighted 2.0 and uncapped - picks
## the winner among the sites that qualify. A flat-topped hill, which is his own words.
const FSB_PROMINENCE_CAP: float = 4.0
## HOW MANY CENTRES THE PICKER LOOKS AT, and it was 120 until 2026-09-10.
##
## MEASURED, tools/probe_site_pick.gd's Pareto scan: on the 1280 m patrol map the ground that
## is BOTH as flat as the old pick and not overlooked is 1 candidate in 300. At 120 draws the
## score was right and the picker simply never saw such a site - it was choosing the best of a
## pool that did not contain one, which reads exactly like a bad weight and is not.
##
## The flattest legal centre on the map carries 10.50 m of relief and stands +1.72 m over its
## ring; the best PROMINENT one stands +18.11 m and carries 31.47 m. Relief and height are
## strongly coupled here, so the pick has to be able to FIND the rare corner rather than be
## bribed toward the summit. 480 draws costs ~61 height samples each, once, at world build.
const FSB_SITE_CANDIDATES: int = 480
## HOW MUCH AO THE BASE NEEDS AROUND IT, and this term exists because the prominence term
## above went and found high ground in a CORNER.
##
## MEASURED on seed 31337: prominence alone moved the gate from (811, 808) - mid-map - to
## (975, 1105) on a 1280 m map. FSB_EDGE_MARGIN only guarantees the FOOTPRINT fits; it says
## nothing about there being a war outside it. With the base in the corner, one of the four
## quadrants the pacing contract requires a village in (mission_generator.gd, and
## tests/test_patrol_world.gd asserts it at ~500 m) has no land in it at all.
##
## 470 m is the outer edge of the village band the planner itself uses, so this asks for
## exactly the room the AO is about to be filled with and no more. It is clamped to what the
## map can actually offer, so on the 512 m demo map - where no centre can be 470 m from every
## edge - every candidate is penalised equally and the term stops deciding anything instead of
## swamping the score.
const FSB_AO_ROOM_M: float = 470.0
## Per metre short of that room. 0.5 makes 100 m of missing AO cost 50 points, which outranks
## the whole prominence term (capped at 8) on purpose: a base on a hill with no war around it
## is worse than a base on flat ground with one.
const FSB_AO_ROOM_W: float = 0.5


## Metres from the site centre to the NEAREST map edge - how much AO there is to patrol.
static func ao_room(centre: Vector3, map_size: float) -> float:
	return minf(minf(centre.x, map_size - centre.x), minf(centre.z, map_size - centre.z))


## Pure site pick for the AABB center: fits in-map with margin, prefers dry flat
## ground across the WHOLE footprint (not just the clear-disc centers), stays
## off paddies/reserved points. Flatness dominates the score on purpose - the
## seat/sculpt pass downstream can blend a gentle site, it cannot fix a ridge.
##
## AND IT PREFERS HIGH GROUND, since 2026-09-10. Flatness alone put fsb_kit_alpha in a hollow
## with four of six bunkers firing into rising ground 12-18 m out; the tool grew a prominence
## term to fix it and the GAME never got one, so the tool and the game picked different hills
## off the same seed. A firebase goes on a flat-topped hill: the score is BOTH.
## `prominence_w` exists for ONE caller: tools/probe_site_pick.gd passes 0.0 to reproduce the
## pre-2026-09-10 score exactly, so the probe's before/after is the same function twice and
## not a hand-copied rival of it. The game never passes it.
func plan_firebase_main_center(rng: RandomNumberGenerator,
		prominence_w: float = FSB_PROMINENCE_W) -> Vector3:
	var map_size: float = _terrain.map_size
	var min_x: float = FSB_HALF.x + FSB_EDGE_MARGIN
	var min_z: float = FSB_HALF.y + FSB_EDGE_MARGIN
	var best := Vector3(map_size * 0.5, 0.0, map_size * 0.5)
	var best_score: float = -1.0e9
	# Clamped to what this map can give: dead centre is the most room any centre can have.
	var room_want: float = minf(FSB_AO_ROOM_M, map_size * 0.5)
	for _i in range(FSB_SITE_CANDIDATES):
		var c := Vector3(rng.randf_range(min_x, map_size - min_x), 0.0,
			rng.randf_range(min_z, map_size - min_z))
		var score: float = 0.0
		for disc in FSB_CLEAR_DISCS:
			var p: Vector3 = c + (disc[0] as Vector3)
			if _grid.is_water(p):
				score -= 10.0
			score -= _grid.get_slope(p)
		score -= _footprint_height_range(c) * 2.0
		score += minf(prominence(_terrain, c, FSB_HALF.x + FSB_OUTLOOK_M,
			FSB_HALF.y + FSB_OUTLOOK_M), FSB_PROMINENCE_CAP) * prominence_w
		score -= maxf(0.0, room_want - ao_room(c, map_size)) * FSB_AO_ROOM_W
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
		clear_and_flatten(center + (disc[0] as Vector3), float(disc[1]), FSB_CLEAR_FEATHER)
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
	# ADR-043 P1. THE COMPOUND WRAPPER - one seated parent that every part of the base
	# hangs under, the bake included.
	#
	# The break it closes: NavBaker._queue_firebase takes site.nodes[0] and pushes exactly
	# ONE collider root (nav_baker.gd:202-205). That is correct while the whole compound is
	# a single GLB and wrong the moment a part is stamped beside it - the stamped part would
	# be invisible to the navmesh, and the file's own header says what that looks like:
	# "worse than no navmesh, because it would look deliberate."
	#
	# Fixing it here rather than in NavBaker is deliberate. A wrapper makes the single-root
	# assumption TRUE again instead of teaching a second system to iterate; nav_baker keeps
	# one root forever, and a kit part is simply another child. It also gives the seat one
	# owner: parts added later inherit the compound's transform instead of each re-deriving
	# origin/seat_y and drifting from it.
	var compound := Node3D.new()
	compound.name = "FirebaseCompound"
	compound.set_meta("model_name", "fsb_main")
	_parent.add_child(compound)
	var origin: Vector3 = center - FSB_AABB_CENTER
	origin.y = seat_y
	_fsb_seat_y = seat_y
	_fsb_seated = true
	compound.global_position = origin

	var scene: PackedScene = load(FSB_MAIN_PATH)
	var root := scene.instantiate() as Node3D
	root.set_meta("model_name", "fsb_main")
	MaterialBudget.structure(root)
	# Added AFTER the compound is seated and at IDENTITY, so root's global transform is the
	# same one it had when it was seated directly. Every walk below still measures world
	# positions, so none of them can tell the difference - which is the point.
	compound.add_child(root)
	_repair_glb_colliders(root)
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
	_animate_fsb_baked_cast(root)
	_wire_m101_rigs(root)
	_audit_frozen_bodies(root)
	var gm: Dictionary = SitePlanner.fsb_gate_metrics(center)
	var gate_pos: Vector3 = gm.gate_pos
	var gate_out: Vector3 = gm.gate_out
	var spawn_pos: Vector3 = gm.spawn_pos
	spawn_pos.y = _terrain.get_height_at(spawn_pos)
	gate_pos.y = _terrain.get_height_at(gate_pos)
	_stamp_radio(spawn_pos)
	_stamp_hooch_radios(root)
	# AFTER the radios, never before: _stamp_hooch_radios reads the eleven fb_int_radio MESH
	# positions to place the voices, and this removes those meshes.
	_fold_interior_props(root)
	_fsb_rect = Rect2(center.x - FSB_HALF.x, center.z - FSB_HALF.y,
		FSB_HALF.x * 2.0, FSB_HALF.y * 2.0)
	# nodes[0] is the COMPOUND, not the GLB. NavBaker walks colliders from it, so a part
	# stamped under the compound is in the bake by construction (ADR-043 P1).
	var site := {"kind": "firebase_main", "center": center, "nodes": [compound],
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


## THE INTERIOR PROPS ARE TOO NUMEROUS, not too heavy - and 545 of them are copies of 69
## things. Counted out of fsb_main_v3.glb (tools/probe_interior_pop.gd, then
## tools/probe_interior_fold.gd): 545 `fb_int_` nodes, 1,010 surfaces, 43,941 triangles of
## baked copies, but only **69 distinct meshes** and **5,471 triangles** of unique geometry.
##
## They are now folded into one MultiMesh per distinct mesh and the baked nodes are removed
## (InteriorPropFold, scripts/world/interior_prop_fold.gd) - 1,010 surfaces to 132. That
## replaces the range cull that used to live here, which set a 40 m range with no fade mode
## and so landed all 545 in a SINGLE frame. FADE_SELF was never the answer: it alpha-dithers
## a prop see-through, the ADR-026 opacity bug the Summoner rejected.
##
## The range is measured per TYPE now instead of guessed at 40 m for everything, and the 6 m
## name-derived stagger this file used to carry moved with it: 69 measured thresholds spread
## the arrival over ~150 m rather than 6 m, each landing while the prop covers two rendered
## rows or less. See interior_prop_fold.gd for why banding was measured and rejected.
const INTERIOR_PROP_PREFIX: String = "fb_int_"


func _fold_interior_props(root: Node3D) -> void:
	var r: Dictionary = InteriorPropFold.apply(root)
	if int(r.get("props", 0)) == 0:
		push_warning("[FSB] no %s props in the firebase GLB - nothing folded" % INTERIOR_PROP_PREFIX)
		return
	print("[FSB] interior props folded: %d prop(s) -> %d MultiMesh(es), %d surface(s) -> %d, shown to %.0f-%.0fm"
		% [r["props"], r["meshes"], r["surfaces_before"], r["surfaces_after"],
			r["near_m"], r["far_m"]])


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
## Last firebase tagging pass, for the penetration probe's ratchet.
static var fsb_ballistic_report: Dictionary = {}

const FSB_SOFT_PREFIXES: Array[String] = ["fb_hootch", "fb_gp_tent", "fb_mess",
	# The hooch WALL. This list has always said "a hootch wall does not stop a 7.62" and
	# has never covered one: the walls export as fb_hwall_*, not fb_hootch_*, so 242 plywood
	# panels shipped bulletproof while their own roofs and screens were penetrable.
	"fb_hwall",
	"fb_latrine", "fb_supply_dump", "fb_water_point",
	"fb_burn_barrel", "bwire_card",
	# The chow hall and the aid station are merged in by a separate tool under names no
	# prefix here had ever heard of, so a canvas mess tent and a canvas surgical station
	# stopped rifle rounds. fb_aid_station, the prefix that was MEANT to cover the second
	# of them, matched nothing at all - the asset had been renamed to medical_complex.
	"tent_roof_chowhall", "tent_gable_chowhall", "tent_frame_chowhall",
	"WB_chowhall_backwall", "medical_complex",
	# The casualty display figures (wounded + medical staff, per-part colliders in
	# the GLB). A body is flesh: rounds pass through with soft falloff and blasts
	# reach past it - it must never read as a sandbag wall that gives no hit
	# reaction. They stay in the nav bake per the fb_int_ ruling (real in both).
	#
	# `grunt_` alone reached 144 of 367 parts. The gore caps, the surgical dress and the
	# three baked officers export under their own stems, so two-thirds of the figures in
	# this compound were hard cover - a man's apron stopping a rifle round.
	"grunt_", "cap_", "scrub_cap_", "apron_", "mask_", "PSXRig_",
	"OFF0_", "OFF1_", "OFF2_",
	# HOOCH CLUTTER. Reading the 229 hard-by-default families found these, and they only
	# started to matter when fb_hwall went soft: with the walls penetrable, the thing that now
	# stops a round fired into a hooch is a hanging light bulb, a beer can or a girly mag.
	# None of these is cover by any reading of the contract's own sentence. Furniture -
	# lockers, cots, chairs, tables - is deliberately NOT here; that is his call, not mine.
	"fb_int_beer", "fb_int_bulb", "fb_int_fan", "fb_int_girlymag", "fb_int_radio",
	"fb_int_fb_hanging_bulb", "fb_int_fb_food_tray", "fb_int_fb_c_ration_case",
	"fb_hanging_bulb", "fb_c_ration_case"]

## The subset of the above that is a BODY, so the count in the tag report means what it says.
const FSB_FIGURE_PREFIXES: Array[String] = ["grunt_", "cap_", "scrub_cap_", "apron_",
	"mask_", "PSXRig_", "OFF0_", "OFF1_", "OFF2_"]


func _tag_fsb_ballistics(root: Node3D) -> void:
	var soft_n: int = 0
	var hard_n: int = 0
	var figure_n: int = 0
	var hard_families: Dictionary = {}
	var hits: Dictionary = {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var body := n as CollisionObject3D
		if body == null:
			continue
		var nm := _ballistic_name(body)
		var soft: bool = false
		for p in FSB_SOFT_PREFIXES:
			if nm.begins_with(p):
				soft = true
				hits[p] = int(hits.get(p, 0)) + 1
				break
		body.add_to_group("soft_cover" if soft else "hard_surface")
		if soft:
			soft_n += 1
			for fp in FSB_FIGURE_PREFIXES:
				if nm.begins_with(fp):
					figure_n += 1
					break
		else:
			hard_n += 1
			var fam: String = _collider_family(nm)
			hard_families[fam] = int(hard_families.get(fam, 0)) + 1
	print("[FSB] ballistic tags: %d soft (tent/hootch/tin, %d casualty-figure parts), %d hard (earth/sandbag/timber)"
		% [soft_n, figure_n, hard_n])
	# Published, not just printed: the penetration probe ratchets on these numbers, and a
	# probe that re-derives them from the same prefix list would only prove the list agrees
	# with itself.
	fsb_ballistic_report = {"soft": soft_n, "hard": hard_n, "figures": figure_n,
		"families": hard_families.keys().size(), "family_names": hard_families.keys()}
	_report_ballistic_misses(hard_families, hits)


## ADR-042 clause 1. `hard` is the DEFAULT here, so a family the soft list has never heard
## of ships bulletproof with no error - the same shape as the helmet defect. Two lists, both
## required: what defaulted to hard (by FAMILY, because 1,847 names is not a report), and
## which soft prefixes matched nothing at all. A prefix that matches zero nodes is a dead
## contract that READS as covered, which is worse than an absent one.
func _report_ballistic_misses(families: Dictionary, hits: Dictionary) -> void:
	var dead: Array[String] = []
	for p in FSB_SOFT_PREFIXES:
		if int(hits.get(p, 0)) == 0:
			dead.append(p)
	if not dead.is_empty():
		push_warning("[FSB] DEAD SOFT PREFIX: %s matched no collider - the family it names is either "
			% ", ".join(dead) + "gone or renamed, and anything that took its place is bulletproof")
	var names: Array = families.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(families[a]) > int(families[b]))
	var top: PackedStringArray = PackedStringArray()
	for i in mini(names.size(), 18):
		top.append("%s x%d" % [names[i], int(families[names[i]])])
	print("[FSB] hard by DEFAULT (matched no soft prefix): %d famil(ies) - %s%s" % [
		names.size(), ", ".join(top), "" if names.size() <= 18 else ", ..."])


## THE NAME THAT MATTERS IS NOT ALWAYS ON THE NODE. Godot MINTS a StaticBody3D per -colonly
## node it converts, and that body is called "StaticBody3D" or "@StaticBody3D@20876" - a name
## carrying no information at all, which is why 132 of them sat in the hard-by-default pile.
## The identity is on the PARENT. Measured 2026-09-09 (tools/probe_unnamed_colliders.gd):
## 80 are parapet segments (hard is right by accident), but three are fb_gp_tent_i and one is
## fb_mess_i - a GP tent and the mess hall, both on the SOFT list, reading as bulletproof
## because their collider was born anonymous.
static func _ballistic_name(body: CollisionObject3D) -> String:
	var nm: String = String(body.name)
	if not (nm.begins_with("@") or nm.begins_with("StaticBody3D")):
		return nm
	var p: Node = body.get_parent()
	return String(p.name) if p != null else nm


## Collider name -> the family a contract would be written against: ordinals and the
## -colonly suffix stripped. `fb_hwall_042_003-colonly` and `fb_hwall_007` are one family.
static func _collider_family(nm: String) -> String:
	# An engine auto-name (@StaticBody3D@20876) carries an instance id, not an identity. Left
	# alone it would put a fresh "new family" in every run and the ratchet would cry wolf
	# forever - the failure mode that gets a gate switched off.
	if nm.begins_with("@"):
		return "@auto@"
	var s: String = nm
	var dash: int = s.rfind("-colonly")
	if dash > 0:
		s = s.substr(0, dash)
	while true:
		var cut: int = s.rfind("_")
		if cut <= 0 or not s.substr(cut + 1).is_valid_int():
			break
		s = s.substr(0, cut)
	return s


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


## Name anything left standing on air. A collider whose LOWEST point floats well above what is
## under it is the shape of every "I got stuck on top of the base" report, and hunting one by
## jumping around the compound is not a debugging method.
##
## **READ THE COUNT CORRECTLY. THE DATUM IS THE TERRAIN HEIGHTMAP, NOT THE FLOOR THE SHAPE IS
## STANDING ON** (measured and labelled honestly 2026-08-30). Inside the firebase THE MODEL IS
## THE GROUND - this audit's own siblings print `kept 1 mound collider(s) - the MODEL is the
## ground` and `terrain sits under the model everywhere` - and fsb_main_v3 is authored with y=0
## at the mound TOE, rising to 14.5m. So the ~1441 this reports is **dominated by props
## correctly standing on the compound floor**, plus ceiling fittings that belong in the air.
## Measured composition: fb=636, fb_int=277, m101=141, MC=139, StaticBody3D=96, grunt=32,
## OFF0/1/2=30 each, PSXRig=12; worst offenders are hanging bulbs (+7.8m) and the medical-tent
## casualty figures' gib parts (+6.8m). **It is not a bug count and it was wrongly carried into
## PLAYTEST_FINDINGS_2026-08-28 item 8 as a lead.**
##
## A true datum needs a downward cast from each shape's bottom, and that CANNOT be fired here:
## a body added this frame is not in the physics space until the next physics step (the same
## trap game_flow.gd:647 documents), so the cast hits nothing and returns the terrain delta
## anyway - measured, 1417 of 1441 unchanged. Fixing it means moving this audit to a callsite
## that runs after a physics flush. That is the first task of the collision pass, not a
## one-liner here.
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
		var air: float = bottom - _terrain.get_height_at(cs.global_position)
		if air >= FLOAT_REPORT_M:
			worst.append([air, String(cs.get_parent().name)])
	if worst.is_empty():
		return
	worst.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var lines: Array[String] = []
	for i in range(mini(6, worst.size())):
		lines.append("%s +%.1fm" % [worst[i][1], worst[i][0]])
	print("[FSB] %d collider(s) >%.0fm above the TERRAIN HEIGHTMAP (not above their own floor - see _audit_floating_colliders); worst: %s" % [
		worst.size(), FLOAT_REPORT_M, ", ".join(lines)])
	# THE COUNT ON ITS OWN IS NOT A FINDING - it says nothing about WHAT is in the air, and a
	# ceiling bulb is supposed to be. Bucketed by name family so the number can be read.
	var fam: Dictionary = {}
	for w in worst:
		var nm: String = String(w[1])
		var key: String = nm.split("_")[0]
		if nm.begins_with("fb_int"):
			key = "fb_int"
		fam[key] = int(fam.get(key, 0)) + 1
	var fam_keys: Array = fam.keys()
	fam_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(fam[a]) > int(fam[b]))
	var fl: Array[String] = []
	for i in range(mini(10, fam_keys.size())):
		fl.append("%s=%d" % [fam_keys[i], int(fam[fam_keys[i]])])
	print("[FSB] floating by family: %s" % ", ".join(fl))



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
## Every parapet segment the exporter emits carries this, manifest entry or not - which is
## what lets the reconciliation below see a segment the manifest never claimed.
const FSB_PARAPET_MESH_PREFIX: String = "fb_sbg_seg_"
## The wired segments are the only runtime description of where the wire IS. SiegeDirector
## measures the perimeter off this group and reads a destroyed member as a breach.
const FSB_PARAPET_GROUP: StringName = &"fsb_parapet"
## EVERY Destructible that took a collider off the firebase model, parapet and structures
## alike. NavBaker seeds its collider walk from this, because a reparented shape is no longer
## reachable from the model root it was handed.
##
## Deliberately NOT FSB_PARAPET_GROUP: that one is the SIEGE's map of the perimeter -
## SiegeDirector measures the wire's radius from it and reads a destroyed member as its breach
## axis - so a bunker joining it would move the wire.
const FSB_NAV_GEOM_GROUP: StringName = &"fsb_nav_geom"


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
	var claimed: Dictionary = {}
	for s in segments:
		claimed[str((s as Dictionary).get("name", ""))] = true
	for s in segments:
		var seg: Dictionary = s
		var mi := root.find_child(str(seg.get("name", "")), true, false) as MeshInstance3D
		if mi == null:
			missing += 1
			continue
		_wire_parapet_segment(mi, str(seg.get("kind", "sandbag_wall")), int(seg.get("hp", 140)))
		wired += 1
	# THE OTHER DIRECTION, and the one that fails silently. `missing` catches a manifest entry
	# with no mesh - loud, because the wall visibly is not there. A mesh with no MANIFEST entry
	# looks exactly like its 80 destructible twins and is INVULNERABLE - sappers spend real
	# charges on a wall that cannot die. So a stray is HANDLED, not just named: co-located
	# with its manifest twin = an export duplicate, hidden with its colliders disabled;
	# standing apart = a real wall piece, adopted with its twin's kind and hp.
	var unclaimed: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		var nm := String(nd.name)
		if nd is MeshInstance3D and nm.begins_with(FSB_PARAPET_MESH_PREFIX) and not claimed.has(nm):
			unclaimed.append(nm)
	var seg_by_name: Dictionary = {}
	for s in segments:
		seg_by_name[str((s as Dictionary).get("name", ""))] = s
	var strays_adopted: int = 0
	var strays_hidden: int = 0
	for nm in unclaimed:
		var stray := root.find_child(nm, true, false) as MeshInstance3D
		if stray == null:
			push_warning("[FSB] stray parapet %s vanished between census and handling" % nm)
			continue
		var base: String = nm
		var ord_re := RegEx.new()
		ord_re.compile("^(.*)_[0-9]+$")
		var om: RegExMatch = ord_re.search(nm)
		if om != null:
			base = om.get_string(1)
		# The manifest loop has already REPARENTED every claimed twin off `root`
		# onto a Destructible under _parent - a root-only search reports every
		# twin "absent" and a real co-located duplicate would be adopted as a
		# SECOND stacked wall whose breach never reads open. Search both homes.
		var twin := root.find_child(base, true, false) as MeshInstance3D
		if twin == null and _parent != null:
			twin = _parent.find_child(base, true, false) as MeshInstance3D
		if twin != null and _mesh_center(twin).distance_to(_mesh_center(stray)) < 0.05:
			stray.visible = false
			_disable_parapet_colliders(stray)
			strays_hidden += 1
			print("[FSB] stray parapet %s co-locates with %s - duplicate hidden, colliders off"
				% [nm, base])
			continue
		var twin_seg: Dictionary = seg_by_name.get(base, {})
		_wire_parapet_segment(stray, str(twin_seg.get("kind", "sandbag_wall")),
			int(twin_seg.get("hp", 140)))
		strays_adopted += 1
		wired += 1
		print("[FSB] stray parapet %s adopted as destructible (manifest twin %s %s)"
			% [nm, base, "found" if twin != null else "absent"])
	print("[FSB] parapet: %d destructible segment(s) on the blast bus%s%s" % [wired,
		"" if missing == 0 else ", %d named in the manifest but absent from the GLB" % missing,
		"" if unclaimed.is_empty() else ", %d stray(s): %d adopted, %d duplicate(s) hidden"
			% [unclaimed.size(), strays_adopted, strays_hidden]])
	_audit_parapet_spread(root)
	_wire_structure_destructibles(root)
	# Screen doors LAST: they hang off the leaves the model carries, and a leaf reparented
	# onto a Destructible by the pass above must still be findable.
	var doors: int = SCREEN_DOOR.wire_all(root)
	print("[FSB] screen doors: %d hung" % doors)


## A wall that reads as ONE POINT is the failure this pass exists to prevent: every consumer
## of a segment position (sapper target, perimeter measure, overrun call, breach scan, blast
## radius) then aims at the compound centre, and one mortar round deletes the whole parapet.
## The manifest's own span is 49.3-96.1m, so a range under a metre means the origins are dead.
func _audit_parapet_spread(root: Node3D) -> void:
	var center: Vector3 = root.global_position
	var lo: float = INF
	var hi: float = -INF
	var n: int = 0
	for node in _parent.get_tree().get_nodes_in_group(FSB_PARAPET_GROUP):
		var d := node as Node3D
		if d == null:
			continue
		n += 1
		var r: float = Vector2(d.global_position.x - center.x, d.global_position.z - center.z).length()
		lo = minf(lo, r)
		hi = maxf(hi, r)
	if n == 0:
		return
	print("[FSB] parapet radii: %d segment(s) spanning %.1f-%.1fm from centre" % [n, lo, hi])
	if hi - lo < 1.0:
		push_warning("[FSB] PARAPET COLLAPSED TO A POINT (%.1fm): every segment shares one position - "
			% lo + "sapper targets, the perimeter and the blast bus are all reading the compound centre")


## World centre of a mesh's BAKED geometry. In a flat GLB a node origin carries no
## information - every parapet node in fsb_main_v3 is identity - so the AABB is the only
## honest position. Same form _adopt_structure uses.
static func _mesh_center(mi: MeshInstance3D) -> Vector3:
	var aabb: AABB = mi.get_aabb()
	return mi.global_transform * (aabb.position + aabb.size * 0.5)


## Stand ONE parapet mesh up as a Destructible on the blast bus - the single
## definition serving both the manifest loop and the stray-adoption pass.
func _wire_parapet_segment(mi: MeshInstance3D, kind: String, hp: int) -> void:
	var d := Destructible.new()
	d.kind = kind
	d.hp = hp
	d.collision_layer = 1
	d.collision_mask = 0
	_parent.add_child(d)
	# THE MESH NODE'S ORIGIN IS NOT THE WALL. fsb_main_v3 is a flat scene and 80 of the 81
	# parapet nodes carry NO node transform - the geometry is baked into vertices - so
	# mi.global_position is the model root for all of them, i.e. the compound centre.
	# Read the baked AABB instead, the same form _adopt_structure uses. Everything that
	# reads a segment position (sapper targets, the perimeter measure, the overrun call,
	# the breach scan, the blast radius test) reads THIS node's origin and nothing else.
	d.global_position = _mesh_center(mi)
	# Take the segment's collider off its auto-generated body and onto the Destructible, so
	# _do_destroy can disable it. A shape left nested under a child body survives the blast
	# and the "destroyed" wall keeps stopping rounds.
	# Same flat-GLB contract as _adopt_structure: the collider may be a SIBLING named
	# <mesh name>_<ord>-colonly, not a child.
	var seg_bodies: Array[Node] = []
	for c in mi.get_children():
		if c is StaticBody3D:
			seg_bodies.append(c)
	var seg_parent: Node = mi.get_parent()
	if seg_parent != null:
		for c in seg_parent.get_children():
			if c is StaticBody3D and String(c.name).begins_with(String(mi.name)):
				seg_bodies.append(c)
	var moved: int = 0
	for c in seg_bodies:
		var body := c as StaticBody3D
		if body == null:
			continue
		for cc in body.get_children():
			var shape := cc as CollisionShape3D
			if shape == null:
				continue
			moved += 1
			# All 80 parapet nodes happen to be identity today, which is the only
			# reason this worked without it. A sibling collider need not be.
			var keep: Transform3D = shape.global_transform
			body.remove_child(shape)
			d.add_child(shape)
			shape.global_transform = keep
		body.queue_free()
	if moved == 0:
		print("[TEMPSEG] %s: children=%d siblings=%d MOVED 0" % [mi.name,
			mi.get_children().size(),
			(seg_parent.get_children().size() if seg_parent != null else -1)])
	mi.reparent(d, true)      # keep_global_transform: the wall must not move
	AgentRegistry.register(d, AgentRegistry.Kind.PROP)
	# The perimeter is also the SIEGE's map of itself: SiegeDirector measures the wire's
	# radius from this group and reads a destroyed segment as its breach axis.
	d.add_to_group(FSB_PARAPET_GROUP)
	d.add_to_group(FSB_NAV_GEOM_GROUP)


## Disable a duplicate stray's colliders in place - hidden art must not keep
## stopping rounds or feeding the nav bake (the bake already skips disabled
## shapes).
func _disable_parapet_colliders(mi: MeshInstance3D) -> void:
	var bodies: Array[Node] = []
	for c in mi.get_children():
		if c is StaticBody3D:
			bodies.append(c)
	var mp: Node = mi.get_parent()
	if mp != null:
		for c in mp.get_children():
			if c is StaticBody3D and String(c.name).begins_with(String(mi.name)):
				bodies.append(c)
	for b in bodies:
		for cc in b.get_children():
			var shape := cc as CollisionShape3D
			if shape != null:
				shape.disabled = true


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
	# ADR-042 clause 1. This function is LOUDEST when it works and was SILENT when it did
	# nothing: an empty by_kind means not one mesh in the compound matched a destructible
	# prefix, i.e. every structure ships invulnerable - and the old early return printed
	# nothing at all, so the absence of the line was the only tell and nobody reads an
	# absence. It also names the prefixes that matched NOTHING, which is how a re-export
	# renaming a family shows up here instead of in a playtest.
	var dead: PackedStringArray = PackedStringArray()
	for spec in FSB_STRUCTURE_KINDS:
		if not by_kind.has(spec["kind"]):
			dead.append("%s -> %s" % [str(spec["prefix"]), str(spec["kind"])])
	if by_kind.is_empty():
		push_error("[FSB] NOTHING is on the structure blast bus - %d mesh(es) matched none of the %d destructible prefixes, so every bunker, tower and stack in this compound is INVULNERABLE"
			% [found.size(), FSB_STRUCTURE_KINDS.size()])
		return
	var parts: Array[String] = []
	for k in by_kind:
		parts.append("%d %s" % [int(by_kind[k]), k])
	# The nha_* rows are the village huts and CANNOT match here: this walk only ever runs on
	# the firebase root (place_structure never calls it - the skill's M-2 gap). They are named
	# anyway, because a prefix that matches nothing is either a fossil or a missing caller and
	# the log should not let anyone assume which.
	print("[FSB] structures on the blast bus: %s%s" % [", ".join(parts),
		"" if dead.is_empty() else " | %d prefix(es) matched nothing here: %s" % [
			dead.size(), ", ".join(dead)]])


## Adopt one authored structure mesh onto a Destructible, taking its collider with it.
##
## The Destructible is seated at the mesh's world AABB CENTRE, not its origin:
## combat_manager.gd:176-185 damages a prop on a pure radius test against global_position with
## no LOS and no bounds check, so a 9.6 m tower keyed off its foot survives a blast that
## visibly engulfs it.
## collider_root: KIT PARTS ONLY. When given, every StaticBody3D under it is taken as this
## structure's collision, instead of matching siblings by name. The monolith must match by
## name because it is one flat bake; a part must NOT, because its mesh and its collider carry
## different names - fb_bunker_fighting.glb draws WB_bunker_rifle and collides as
## fb_bunker_fighting_000, so a name match finds nothing and the bunker stands through a
## satchel charge.
## Returns the Destructible it built, so a caller that knows WHICH part this mesh came from
## can say so on the node. Nothing else could: adoption reparents both the mesh and every
## shape out of the part and onto a sibling of the compound, so after a stamp the part node
## is empty and no probe can ask "is this part on the blast bus" by walking its children.
func _adopt_structure(mi: MeshInstance3D, kind: String, hp: int,
		collider_root: Node = null) -> Destructible:
	var d := Destructible.new()
	d.kind = kind
	d.hp = hp
	d.collision_layer = 1
	d.collision_mask = 0
	# NavBaker reads the SHAPE'S PARENT name (nav_baker.gd:482) to match
	# NAV_IGNORE_PREFIXES and NAV_ROOF_CULL_PREFIXES. The shapes below are reparented
	# onto this node, so an unnamed Destructible makes every adopted structure invisible
	# to both contracts and its roof bakes walkable. A uniquifying suffix is harmless -
	# both contracts test begins_with.
	d.name = mi.name
	_parent.add_child(d)
	var aabb: AABB = mi.get_aabb()
	d.global_position = mi.global_transform * (aabb.position + aabb.size * 0.5)
	# A shape left nested under the mesh's auto-generated body survives the blast, and the
	# "destroyed" bunker keeps stopping rounds.
	#
	# The GLB is FLAT: the collider is not a child of the mesh, it is a SIBLING named
	# <mesh name>_<ord>-colonly. Walking mi.get_children() found nothing, so no bunker,
	# tower or sandbag stack was ever adopted - a destroyed one stayed solid forever.
	var bodies: Array[Node] = []
	if collider_root != null:
		bodies = _static_bodies_under(collider_root)
	else:
		for c in mi.get_children():
			if c is StaticBody3D:
				bodies.append(c)
		var sib_parent: Node = mi.get_parent()
		if sib_parent != null:
			for c in sib_parent.get_children():
				if c is StaticBody3D and String(c.name).begins_with(String(mi.name)):
					bodies.append(c)
	for c in bodies:
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
	d.add_to_group(FSB_NAV_GEOM_GROUP)
	AgentRegistry.register(d, AgentRegistry.Kind.PROP)
	return d


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
## The firebase's own radio furniture. `fb_int_radio` and its .001-.011 duplicates are the
## eleven hooch sets; the -colonly twins are skipped because only MeshInstance3D is considered.
const HOOCH_RADIO_MESH_PREFIX: String = "fb_int_radio"
## Wider than a hooch (10.97m long) so one billet gets one voice, narrower than the gap to the
## next so no hooch is left silent.
const RADIO_MIN_SEP_M: float = 12.0

## Drop a diegetic field radio near the TOC spawn so the player boots to the broadcast.
##
## Seated on the FLOOR, not on the terrain. get_height_at returns the raw heightmap, and the
## compound floor is the firebase MODEL sitting on a raised mound - so this buried the only
## audible radio in the game inside the hill, which is exactly how it played: music from under
## the firebase, and every radio the player could SEE silent (his playtest, 2026-08-12).
func _stamp_radio(near: Vector3) -> void:
	var ps: PackedScene = load(RADIO_SCENE) as PackedScene
	if ps == null:
		return
	var radio := ps.instantiate() as Node3D
	_parent.add_child(radio)
	var spot: Vector3 = near + Vector3(1.5, 0.0, 0.0)
	var world := _parent as GameWorld
	spot.y = world.floor_y(Vector3(spot.x, near.y + 1.0, spot.z)) if world != null \
		else _terrain.get_height_at(spot)
	radio.global_position = spot


## THE RADIOS THE PLAYER CAN SEE ARE THE ONES HE HEARS. The firebase ships eleven radio props
## as furniture (fb_int_radio*) and they were meshes only - nothing ever attached audio to one,
## so the hooch radios were silent while the single stamped radio played from under the mound.
##
## RadioProp was already built for a compound full of them: activation_distance 125m decides
## whether a stream exists at all, hear_distance 25m how far it carries, and the playlist is
## seeded from the radio's own POSITION so two in earshot never play in unison. The model is
## suppressed - the GLB already draws the set; this adds only the voice.
func _stamp_hooch_radios(root: Node3D) -> int:
	var ps: PackedScene = load(RADIO_SCENE) as PackedScene
	if ps == null:
		return 0
	var spots: Array[Vector3] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		var mi := nd as MeshInstance3D
		if mi == null:
			continue
		var nm := String(mi.name)
		if not nm.begins_with(HOOCH_RADIO_MESH_PREFIX) or nm.contains("-col"):
			continue
		spots.append(mi.global_position)
	# The set dresses the room three times over - 33 radio meshes across eleven hooches - and
	# every one of them voiced would put three different shuffled tracks inside one billet.
	# One voice per hooch: a radio is skipped if another already speaks within RADIO_MIN_SEP_M,
	# which is wider than a hooch (10.97m) and narrower than the gap between them.
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.x < b.x if not is_equal_approx(a.x, b.x) else a.z < b.z)
	var made: int = 0
	var taken: Array[Vector3] = []
	for p: Vector3 in spots:
		var near: bool = false
		for q: Vector3 in taken:
			if Vector2(p.x - q.x, p.z - q.z).length() < RADIO_MIN_SEP_M:
				near = true
				break
		if near:
			continue
		taken.append(p)
		var radio := ps.instantiate() as Node3D
		radio.set("model_path", "")     # set before _ready: the set is already drawn
		_parent.add_child(radio)
		radio.global_position = p
		made += 1
	print("[FSB] radios: %d hooch set(s) given a voice" % made)
	return made


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


## ---------- THE KIT CONSUMER (ADR-043 §2) ----------
## Stamp a SitePlan: instantiate its parts under ONE seated compound, wire them onto the
## contracts every other structure in this game already obeys, and hand back a site dict in
## the same shape place_firebase_main returns.
##
## This function is the CONSUMER the fossil law demanded before the kit could exist.
## gen_firebase.py:1-13 refused to ship 24 kit GLBs in July because they would be "24 files
## with one consumer, which ADR-023 would correctly come for" - the parts were never the
## problem, the missing placer was. So this ships before any part master is authored.
##
## ONE PATH (ADR-028). Parts are instanced here, seated here, and wired here, and nothing
## else in the codebase gains an entry point. The compound wrapper is the same shape
## place_firebase_main builds, so NavBaker's single collider root keeps working (ADR-043 P1).
## A crew role, in the vocabulary the parts use, mapped to the occupation the garrison
## already speaks. Same rule as FSB_WORK_OCCUPATION one system over: the PART names the role
## as a bare string and nothing gates on it, and code that needs to know what a role MEANS
## maps it here. A role nobody has mapped still turns up - as off_duty, loudly - because a
## man standing in the wrong job is a tuning defect and a man who never spawned is invisible.
const KIT_CREW_OCCUPATION: Dictionary = {
	"rifleman": "sentry", "guard": "sentry", "sentry": "sentry",
	"sentry_night": "sentry_night",
	"mg_gunner": "gun_crew", "gun_crew": "gun_crew", "gun_crew_arty": "gun_crew_arty",
	"radioman": "radioman", "medic": "medic", "cook": "mess_cook",
	"quartermaster": "quartermaster", "detail": "detail",
}


## THE PART BRINGS ITS OWN PEOPLE (ADR-043 §4, his ask: *"certian npcs thatll spawn with
## certian building combos"*).
##
## Returns posts in the SAME shape fsb_garrison_plan() emits - {pos, occupation, men} - so
## the consumer at mission_generator.gd:1050 takes either without knowing which. That is the
## whole reason for the shape: ADR-028 says Civilian.spawn is the one door, and a second
## spawn authority is exactly what this function must not become. It emits REQUESTS. It never
## instantiates anybody.
##
## THE COMBO RULE, and it is the half that makes this more than a crew list: a part's crew
## turns up only when every string in its `demands` is in the union of every OTHER part's
## `supplies` ACROSS THE SAME PLAN. A gate house demands `perimeter`; drop it on open ground
## with no wall either side and there is nothing to guard, so no guard is posted. Put a
## bunker line beside it and the guard appears - not because a function tested for a gate,
## but because the parts said what they needed and what they gave.
##
## An unmet demand is PRINTED. The whole bug class this kit exists to close is defaults that
## fail silently, and "the base spawned empty" is that class wearing a garrison's clothes.
func _plan_garrison(plan: SitePlan, reg: KitRegistry, compound: Node3D,
		stations: Array) -> Array[Dictionary]:
	var supplied: Dictionary = {}
	for entry_any in plan.parts:
		for s in reg.supplies_for(str((entry_any as Dictionary).get("id", ""))):
			supplied[s] = true

	# Where a part's men stand: its own first station if it declares one, else the part
	# itself. A station is a measured post on walkable ground (tests/test_marker_navmesh.gd
	# ratchets every one of them); the part origin is the ground contact point and is the
	# honest fallback when the art carries no marker yet.
	var station_for: Dictionary = {}
	for st_any in stations:
		var st: Dictionary = st_any
		var pid: String = str(st.get("part", ""))
		if pid != "" and not station_for.has(pid):
			station_for[pid] = st.get("pos", Vector3.ZERO)

	var posts: Array[Dictionary] = []
	var unmet: PackedStringArray = PackedStringArray()
	var unmapped: PackedStringArray = PackedStringArray()
	for entry_any in plan.parts:
		var entry: Dictionary = entry_any
		var id: String = str(entry.get("id", ""))
		var crew: Array[String] = reg.crew_for(id)
		if crew.is_empty():
			continue
		var blocked: bool = false
		for d in reg.demands_for(id):
			if not supplied.has(d):
				var line: String = "%s demands '%s', nothing in the plan supplies it" % [id, d]
				if not unmet.has(line):
					unmet.append(line)
				blocked = true
		if blocked:
			continue
		var pos: Vector3 = station_for.get(id,
			compound.global_position + (entry.get("pos", Vector3.ZERO) as Vector3))
		# Identical roles at one part are ONE post with a count, which is how
		# FSB_GARRISON_POSTS spells a two-man gun crew. Two posts on the same metre would
		# put two men inside each other.
		var by_role: Dictionary = {}
		var role_order: Array[String] = []
		for role in crew:
			if not by_role.has(role):
				by_role[role] = 0
				role_order.append(role)
			by_role[role] = int(by_role[role]) + 1
		for role in role_order:
			var occ: String = str(KIT_CREW_OCCUPATION.get(role, "off_duty"))
			if not KIT_CREW_OCCUPATION.has(role) and not unmapped.has(role):
				unmapped.append(role)
			posts.append({"pos": pos, "occupation": occ, "men": int(by_role[role]),
				"part": id, "role": role})
	if not unmet.is_empty():
		push_warning("[PLAN] %d unmet demand(s): %s" % [unmet.size(), ", ".join(unmet)])
	if not unmapped.is_empty():
		push_warning("[PLAN] crew role(s) with no occupation, posted as off_duty: %s"
			% ", ".join(unmapped))
	var men: int = 0
	for p in posts:
		men += int(p.get("men", 0))
	print("[PLAN] garrison: %d post(s), %d man/men, %d unmet demand(s)"
		% [posts.size(), men, unmet.size()])
	return posts


func stamp_site_plan(plan: SitePlan, center: Vector3, registry: KitRegistry = null) -> Dictionary:
	var reg: KitRegistry = registry if registry != null else KitRegistry.load_kit()
	var why: String = plan.validate(reg)
	if why != "":
		push_error("[PLAN] refusing to stamp: %s" % why)
		return {}

	# THE CONTRACT GATE, before a single node is instanced. ADR-042's bug class fails by
	# DEFAULT, never by error: an unrecognised mesh is bulletproof and indestructible and
	# nothing says so. The first stamped compound shipped exactly that way - 5 meshes, 0 on
	# the blast bus - and it was found by a suite run hours later. Refuse instead.
	var gaps: PackedStringArray = PackedStringArray()
	for entry in plan.parts:
		var gap: String = reg.contract_gap(str(entry.get("id", "")))
		if gap != "" and not gaps.has(gap):
			gaps.append(gap)
	if not gaps.is_empty():
		push_error("[PLAN] refusing to stamp '%s': %s" % [plan.plan_name, ", ".join(gaps)])
		return {}

	# ADR-041 §6: the flatten is per-plan and declared, never mandatory and never 1.0 by
	# default. A plan that asks for no seat gets none, and follows the ground it is on.
	#
	# TWO CALLS, AND THE ORDER IS LOAD-BEARING. clear_and_flatten() cuts the vegetation,
	# paints the dirt disc and opens the AI grid - it is the CLEARING half, and despite its
	# name it barely moves the ground (ADR-041 measured it: a 0.7 lerp at one cell, tapering
	# from the first cell out). flatten_pad() is the half his ask names - it plants the level
	# ground the building stands on. Clearing first, levelling last, so the final height is
	# the pad's and not the clearing zone's partial lerp over it.
	var seat_y: float = _terrain.get_height_at(center) if _terrain != null else center.y
	if plan.flatten_radius > 0.0 and plan.flatten_strength > 0.0:
		clear_and_flatten(center, plan.flatten_radius, plan.flatten_shoulder)
		seat_y = flatten_pad(center, plan.flatten_radius, plan.flatten_strength,
			plan.flatten_shoulder)
	var compound := Node3D.new()
	compound.name = "SitePlan_%s" % plan.plan_name
	compound.set_meta("model_name", plan.plan_name)
	_parent.add_child(compound)
	compound.global_position = Vector3(center.x, seat_y, center.z)

	var stations: Array = []
	var placed: int = 0
	for entry in plan.parts:
		var id: String = str(entry.get("id", ""))
		var scene: PackedScene = load(reg.model_path(id)) as PackedScene
		if scene == null:
			push_warning("[PLAN] part '%s' failed to load - skipped" % id)
			continue
		var part := scene.instantiate() as Node3D
		if part == null:
			continue
		# set_meta BEFORE the tree, and the id NOT the node name: Godot auto-renames a
		# duplicate child, so two hooches become hooch and hooch2 and every CollisionTable
		# lookup keyed on the name breaks silently (ADR-041 §3 contract 3).
		part.set_meta("model_name", id)
		part.set_meta("part_id", id)
		MaterialBudget.structure(part)
		compound.add_child(part)
		var local: Vector3 = entry.get("pos", Vector3.ZERO)
		part.position = local
		part.rotation.y = deg_to_rad(float(entry.get("yaw_deg", 0.0)))
		_apply_visibility_range(part)
		placed += 1

		# Stations come from the PART MANIFEST, in the part's own local space, and their
		# work_type is a bare string this function never inspects. A kit for another war
		# adds a work type by adding a marker, never by editing this file (ADR-043 §4).
		for st_any in reg.stations_for(id):
			var st: Dictionary = st_any
			var sl: Vector3 = st.get("local", Vector3.ZERO)
			stations.append({
				"pos": compound.global_position + local + Vector3(sl.x, sl.y, sl.z).rotated(
					Vector3.UP, deg_to_rad(float(entry.get("yaw_deg", 0.0)))),
				"type": str(st.get("work_type", "")),
				"part": id,
			})

	if placed == 0:
		push_error("[PLAN] '%s' stamped ZERO parts - the compound is empty" % plan.plan_name)
		compound.queue_free()
		return {}

	# A KIT PART RESOLVES ITS IDENTITY FROM DATA, NOT FROM A MESH NAME.
	#
	# _wire_structure_destructibles is the MONOLITH's mechanism and it cannot serve here. It
	# matches mesh names against FSB_STRUCTURE_KINDS, which works in the bake only because
	# gen_firebase.py stamped instances called fb_bunker_fighting_i*. The standalone kit GLBs
	# are July review exports whose visible meshes carry Blender workbench names -
	# fb_bunker_fighting.glb's mesh is WB_bunker_rifle while its collider is
	# fb_bunker_fighting_000-colonly. Ballistics reads the collider, destruction reads the
	# mesh, and that divergence is why the first stamped compound had nothing on the blast bus.
	#
	# A stamped part KNOWS what it is - we placed it by id - so it does not have to spell its
	# identity in every mesh name. That is strictly better than the bake's mechanism and it is
	# what keeps the vocabulary in data (ADR-043 §4) instead of in a const array.
	var wired: int = 0
	var no_collider: PackedStringArray = PackedStringArray()
	for part_any in compound.get_children():
		var part := part_any as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var pid: String = str(part.get_meta("part_id"))
		tag_ballistics(part, reg.is_soft(pid))
		var kind: String = reg.destructible_kind(pid)
		if kind == "":
			continue
		if _static_bodies_under(part).is_empty():
			if not no_collider.has(pid):
				no_collider.append(pid)
			continue
		var want: Array[String] = reg.structure_meshes(pid)
		var stack: Array[Node] = [part]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			var mi := n as MeshInstance3D
			if mi == null or not want.has(String(mi.name)):
				continue
			# part_id on the Destructible, because adoption empties the part node: the mesh
			# and every shape move onto this sibling, so without the meta nothing can ask
			# "is THIS part on the blast bus" afterwards without guessing by distance.
			var d: Destructible = _adopt_structure(mi, kind, Destructible.hp_for(kind), part)
			if d != null:
				d.set_meta("part_id", pid)
			wired += 1
			break
	if not no_collider.is_empty():
		# WARNING, not error, and the distinction is deliberate. run_all_tests.ps1 fails a
		# test on any line beginning "ERROR:", so push_error here would paint the suite red
		# over a KNOWN art gap nobody can close without Blender - and a permanently red gate
		# is one people learn to ignore. The count is asserted against a ratchet in
		# tests/test_site_plan_roundtrip.gd instead, so it cannot grow unnoticed.
		push_warning("[PLAN] %s ship NO COLLIDER - nothing can hit them, and a structure "
			% ", ".join(no_collider)
			+ "that cannot be hit cannot be breached")
	print("[PLAN] %d part(s) with no collider" % no_collider.size())
	print("[PLAN] %d structure(s) on the blast bus" % wired)

	var garrison: Array[Dictionary] = _plan_garrison(plan, reg, compound, stations)

	var site := {"kind": "site_plan", "plan": plan.plan_name, "center": center,
		"nodes": [compound], "stations": stations, "wired": wired,
		"no_collider": no_collider, "garrison": garrison,
		"radius": maxf(plan.flatten_radius, 16.0)}
	placed_sites.append(site)
	print("[PLAN] stamped '%s': %d part(s), %d station(s)"
		% [plan.plan_name, placed, stations.size()])
	return site


## Every StaticBody3D under `root`, at any depth. A kit part's colliders belong to the part
## whatever the exporter called them, which is the whole reason this exists.
static func _static_bodies_under(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is StaticBody3D:
			out.append(n)
	return out
