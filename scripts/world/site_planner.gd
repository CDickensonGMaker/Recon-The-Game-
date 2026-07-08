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


func _init(grid: GameplayGrid, terrain: TerrainManager, veg: VegetationManager, parent: Node3D) -> void:
	_grid = grid
	_terrain = terrain
	_veg = veg
	_parent = parent


## Find a site center: footprint circle must be non-water, non-cliff, low slope,
## and >= min_separation from every already-placed site. Returns Vector3.ZERO on failure.
func find_site(rng: RandomNumberGenerator, radius: float, min_separation: float = 200.0) -> Vector3:
	var map_size: float = _terrain.map_size
	var best := Vector3.ZERO
	var best_score: float = -1.0
	for _i in range(SITE_ATTEMPTS):
		var p := Vector3(
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


## Place one structure: StaticBody3D root (layer 1) + GLB visual + authored box.
func place_structure(model_path: String, world_pos: Vector3, rotation_deg: float) -> Node3D:
	var model_name := model_path.get_file().get_basename()
	var entry: Dictionary = CollisionTable.get_entry(model_name)
	var body := StaticBody3D.new()
	body.name = model_name
	body.collision_layer = 1
	body.collision_mask = 0
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


## VILLAGE: ring of huts + center feature + weapons cache (+ hidden tunnel).
func stamp_village(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Array[Node3D] = []
	var hut_count: int = rng.randi_range(5, 8)
	for i in range(hut_count):
		var a := TAU * float(i) / float(hut_count) + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(SiteLayouts.VILLAGE_RING_RADIUS_MIN, SiteLayouts.VILLAGE_RING_RADIUS_MAX)
		var pos := center + Vector3(cos(a), 0, sin(a)) * r
		var model: String = SiteLayouts.VILLAGE_HUT_MODELS[rng.randi() % SiteLayouts.VILLAGE_HUT_MODELS.size()]
		var hut := place_structure(model, pos, rad_to_deg(a) + 90.0 + rng.randf_range(-15, 15))
		hut.add_to_group("flammable_structures")  # R71: thatch catches fire
		nodes.append(hut)
	var center_model: String = SiteLayouts.VILLAGE_CENTER_MODELS[rng.randi() % SiteLayouts.VILLAGE_CENTER_MODELS.size()]
	nodes.append(place_structure(center_model, center, rng.randf_range(0, 360)))
	# Cache tucked behind a random hut.
	var cache_a := rng.randf_range(0, TAU)
	var cache_pos := center + Vector3(cos(cache_a), 0, sin(cache_a)) * (SiteLayouts.VILLAGE_RING_RADIUS_MAX + 4.0)
	var cache := place_structure(SiteLayouts.CACHE_MODEL, cache_pos, rng.randf_range(0, 360))
	nodes.append(cache)
	var tunnel_pos := center + Vector3(cos(cache_a + PI), 0, sin(cache_a + PI)) * (SiteLayouts.VILLAGE_RING_RADIUS_MAX + 6.0)
	nodes.append(place_structure(SiteLayouts.TUNNEL_MODEL, tunnel_pos, 0.0))
	var site := {"kind": "village", "center": center, "nodes": nodes, "cache": cache, "cache_pos": cache_pos, "radius": SiteLayouts.VILLAGE_RING_RADIUS_MAX + 8.0}
	placed_sites.append(site)
	return site


## FIREBASE: flattened pad, interior buildings, sandbag+wire rings, MG nests,
## helipad pad, parked vehicles.
func stamp_firebase(center: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	clear_and_flatten(center, SiteLayouts.FIREBASE_WIRE_RADIUS + 6.0)
	var nodes: Array[Node3D] = []
	for item in SiteLayouts.FIREBASE_INTERIOR:
		var off: Vector2 = item[1]
		nodes.append(place_structure(item[0], center + Vector3(off.x, 0, off.y), float(item[2])))
	# MG nests north/south on the perimeter, facing out.
	var mg_positions: Array[Vector3] = []
	for a in [0.0, PI]:
		var pos: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * SiteLayouts.FIREBASE_PERIMETER_RADIUS
		nodes.append(place_structure(SiteLayouts.FIREBASE_MG_NEST, pos, rad_to_deg(a)))
		mg_positions.append(pos)
	# Sandbag ring (skip MG slots), wire ring outside.
	var ring_count: int = 14
	for i in range(ring_count):
		var a := TAU * float(i) / float(ring_count)
		if absf(a) < 0.3 or absf(a - PI) < 0.3:
			continue
		var pos := center + Vector3(cos(a), 0, sin(a)) * SiteLayouts.FIREBASE_PERIMETER_RADIUS
		if _grid.is_water(pos):
			continue  # gap in the line beats sandbags in a pond
		nodes.append(place_structure(SiteLayouts.FIREBASE_SANDBAG, pos, rad_to_deg(a) + 90.0))
	var wire_count: int = 20
	for i in range(wire_count):
		var a := TAU * float(i) / float(wire_count)
		var pos := center + Vector3(cos(a), 0, sin(a)) * SiteLayouts.FIREBASE_WIRE_RADIUS
		if _grid.is_water(pos):
			continue
		nodes.append(place_structure(SiteLayouts.FIREBASE_WIRE, pos, rad_to_deg(a) + 90.0))
	# Helipad pad (extra flatten) + parked vehicles + a static Chinook for flavor.
	var helipad := center + Vector3(SiteLayouts.FIREBASE_HELIPAD_OFFSET.x, 0, SiteLayouts.FIREBASE_HELIPAD_OFFSET.y)
	clear_and_flatten(helipad, 9.0)
	for i in range(SiteLayouts.FIREBASE_VEHICLES.size()):
		var pos := center + Vector3(-6.0 + float(i) * 5.0, 0, -14.0)
		nodes.append(DestructibleVehicle.create(_parent, SiteLayouts.FIREBASE_VEHICLES[i], pos, 90.0, _terrain))
	nodes.append(place_structure("res://assets/building models/vehicles/ch47_chinook.glb", helipad + Vector3(0, 0, -2), 45.0))
	var site := {"kind": "firebase", "center": center, "nodes": nodes, "helipad": helipad, "mg_positions": mg_positions, "radius": SiteLayouts.FIREBASE_WIRE_RADIUS + 6.0}
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
