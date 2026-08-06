## zombie_map_lot.gd - THE LOT. The VC Zombies map.
##
## You start OUTSIDE, in a fenced parking lot, and buy your way into the buildings
## around it. Four zones:
##
##     LOT (start, open air) -> WAREHOUSE -> YARD
##                           -> HANGAR    -> YARD
##
## Two routes out of the lot means the ring closes from either side, so the map
## becomes trainable whichever gate you could afford first.
##
## THE BUG THIS LAYOUT EXISTS TO FIX. The first version's ground plane was exactly
## the compound footprint, and spawn points are pushed OUTSIDE the perimeter - so
## all fourteen sat off the floor, off the navmesh, in the void. Nothing ever
## spawned and the lot was silent. The apron below is not decoration: GROUND MUST
## EXTEND WELL PAST ANYTHING THE HORDE SPAWNS BEHIND.
##
## NAVIGATION IS BAKED ONCE OVER THE WHOLE GROUND, INSIDE AND OUT, AND NEVER
## REBAKES. Nothing in this project rebakes nav on structure death
## (nav_baker.gd:16-18). Fence breaches and doorways are GAPS in the wall runs, so
## the mesh already flows through them; what closes one is a physical blocker
## deliberately kept OUT of the `nav_source` group.
class_name ZombieMapLot
extends Node3D

const KIT: String = "res://assets/world/props/psx_kit/"

## Ground, generously larger than the compound. The apron is where the dead come
## from - see the header.
const GROUND := Vector2(150.0, 120.0)
const APRON: float = 18.0          ## spawn stand-off outside the fence

const FENCE_H: float = 2.6
const WALL_H: float = 4.2
const WALL_T: float = 0.4
const GAP_W: float = 3.0           ## doorway / breach width

## Compound footprint inside the ground plane.
const X0: float = 25.0
const X1: float = 125.0
const Z0: float = 20.0
const Z1: float = 96.0
## The lot/buildings divide.
const MID_X: float = 76.0
const MID_Z: float = 58.0

## zone -> Rect2(x, z, w, d)
const ZONES: Dictionary = {
	"lot":       Rect2(25, 58, 51, 38),
	"hangar":    Rect2(76, 58, 49, 38),
	"warehouse": Rect2(25, 20, 51, 38),
	"yard":      Rect2(76, 20, 49, 38),
}

## Gates between zones. `along_x` = the gap runs along the X axis.
const GATES: Array[Dictionary] = [
	{"id": "g_lot_warehouse", "at": Vector3(46, 0, 58), "along_x": true,
	 "zone": "warehouse", "cost": 750},
	{"id": "g_lot_hangar", "at": Vector3(76, 0, 78), "along_x": false,
	 "zone": "hangar", "cost": 1250},
	{"id": "g_warehouse_yard", "at": Vector3(76, 0, 34), "along_x": false,
	 "zone": "yard", "cost": 1750},
	{"id": "g_hangar_yard", "at": Vector3(100, 0, 58), "along_x": true,
	 "zone": "yard", "cost": 1000},
]

## Breaches in the PERIMETER - the holes the dead come through. Each gets boards
## the player rebuilds and a spawn point on the apron outside it.
## `out` is the outward normal, so the spawn lands on open ground every time
## rather than being inferred from a centre that is wrong on a non-convex plan.
const BREACHES: Array[Dictionary] = [
	# the lot's own fence - live from round 1
	{"zone": "", "at": Vector3(34, 0, 96), "out": Vector3(0, 0, 1), "fence": true},
	{"zone": "", "at": Vector3(56, 0, 96), "out": Vector3(0, 0, 1), "fence": true},
	{"zone": "", "at": Vector3(25, 0, 70), "out": Vector3(-1, 0, 0), "fence": true},
	{"zone": "", "at": Vector3(25, 0, 86), "out": Vector3(-1, 0, 0), "fence": true},
	# warehouse
	{"zone": "warehouse", "at": Vector3(25, 0, 30), "out": Vector3(-1, 0, 0), "fence": false},
	{"zone": "warehouse", "at": Vector3(25, 0, 46), "out": Vector3(-1, 0, 0), "fence": false},
	{"zone": "warehouse", "at": Vector3(44, 0, 20), "out": Vector3(0, 0, -1), "fence": false},
	{"zone": "warehouse", "at": Vector3(62, 0, 20), "out": Vector3(0, 0, -1), "fence": false},
	# hangar
	{"zone": "hangar", "at": Vector3(125, 0, 70), "out": Vector3(1, 0, 0), "fence": false},
	{"zone": "hangar", "at": Vector3(125, 0, 86), "out": Vector3(1, 0, 0), "fence": false},
	{"zone": "hangar", "at": Vector3(96, 0, 96), "out": Vector3(0, 0, 1), "fence": false},
	# yard
	{"zone": "yard", "at": Vector3(125, 0, 30), "out": Vector3(1, 0, 0), "fence": true},
	{"zone": "yard", "at": Vector3(125, 0, 46), "out": Vector3(1, 0, 0), "fence": true},
	{"zone": "yard", "at": Vector3(100, 0, 20), "out": Vector3(0, 0, -1), "fence": true},
]

const WALL_BUYS: Array[Dictionary] = [
	{"id": "m16", "at": Vector3(30.0, 1.5, 62.0), "yaw": 0.0},
	{"id": "ak", "at": Vector3(40.0, 1.5, 26.0), "yaw": 0.0},
	{"id": "shotgun", "at": Vector3(80.0, 1.5, 92.0), "yaw": 0.0},
	{"id": "m60", "at": Vector3(120.0, 1.5, 76.0), "yaw": 90.0},
	{"id": "rpg", "at": Vector3(112.0, 1.5, 26.0), "yaw": 0.0},
]

const BOX_SPOTS: Array[Vector3] = [
	Vector3(52, 0.6, 76), Vector3(100, 0.6, 76), Vector3(50, 0.6, 38),
	Vector3(100, 0.6, 34),
]

const POWER_UPS: Array[Dictionary] = [
	{"id": "toughness", "at": Vector3(96, 0.0, 66)},
	{"id": "stamina", "at": Vector3(34, 0.0, 40)},
	{"id": "speedload", "at": Vector3(116, 0.0, 40)},
]

## Out in the open, mid-lot, so round 1 is a fight in daylight rather than a
## corridor - his note was that it should start outside.
const PLAYER_START := Vector3(50, 0.2, 78)

var _rng := RandomNumberGenerator.new()
var _nav_region: NavigationRegion3D = null
var terrain: ZombieTerrainOhio = null


func build(seed_value: int = 20260805) -> void:
	_rng.seed = seed_value
	_build_ground()
	_build_perimeter()
	_build_interior_walls()
	_build_gates()
	_build_breaches()
	_build_interactables()
	_dress()
	bake_nav()


# ---------------------------------------------------------------- ground

## Ohio ground: flat asphalt under the compound, low rolling field on the apron.
## ZombieTerrainOhio owns the reasoning for why the pad stays flat.
func _build_ground() -> void:
	terrain = ZombieTerrainOhio.new()
	terrain.name = "OhioTerrain"
	add_child(terrain)
	terrain.build(GROUND, Rect2(X0, Z0, X1 - X0, Z1 - Z0), int(_rng.seed))


# ---------------------------------------------------------------- shell

## The perimeter. Chain-link where the lot faces open ground so the player can SEE
## the horde gathering, solid wall behind the buildings.
func _build_perimeter() -> void:
	var runs: Array[Dictionary] = [
		{"a": Vector2(X0, Z1), "b": Vector2(X1, Z1), "fence": true},
		{"a": Vector2(X0, Z0), "b": Vector2(X1, Z0), "fence": false},
		{"a": Vector2(X0, Z0), "b": Vector2(X0, Z1), "fence": true},
		{"a": Vector2(X1, Z0), "b": Vector2(X1, Z1), "fence": false},
	]
	for r in runs:
		_run_with_gaps(r["a"], r["b"], bool(r["fence"]))


func _build_interior_walls() -> void:
	for r in [
		{"a": Vector2(X0, MID_Z), "b": Vector2(X1, MID_Z)},
		{"a": Vector2(MID_X, Z0), "b": Vector2(MID_X, Z1)},
	]:
		_run_with_gaps(r["a"], r["b"], false)


## A wall run, broken by every gate and breach that sits on it. The GAP is what
## keeps the navmesh flowing through an opening forever.
func _run_with_gaps(a: Vector2, b: Vector2, fence: bool) -> void:
	var cuts: Array[float] = []
	var total: float = a.distance_to(b)
	for src in [GATES, BREACHES]:
		for d in src:
			var at: Vector3 = d["at"]
			var p := Vector2(at.x, at.z)
			if _on_segment(p, a, b):
				cuts.append(a.distance_to(p))
	var dir: Vector2 = (b - a).normalized()
	var marks: Array[float] = [0.0]
	for t in cuts:
		marks.append(t - GAP_W * 0.5)
		marks.append(t + GAP_W * 0.5)
	marks.append(total)
	marks.sort()
	for i in range(0, marks.size() - 1, 2):
		var t0: float = maxf(0.0, marks[i])
		var t1: float = minf(total, marks[i + 1])
		if t1 - t0 < 0.2:
			continue
		_segment(a + dir * t0, a + dir * t1, fence)


func _segment(p0: Vector2, p1: Vector2, fence: bool) -> void:
	var mid: Vector2 = (p0 + p1) * 0.5
	var len_m: float = p0.distance_to(p1)
	var horiz: bool = absf(p1.x - p0.x) > absf(p1.y - p0.y)
	var h: float = FENCE_H if fence else WALL_H
	var t: float = 0.12 if fence else WALL_T
	var size := Vector3(len_m if horiz else t, h, t if horiz else len_m)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	if fence:
		# Chain-link: see-through, so the lot reads as open air and the horde
		# gathering outside is visible before it is a problem.
		mat.albedo_color = Color(0.44, 0.46, 0.44, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		mat.albedo_color = Color(0.30, 0.29, 0.26)
	mat.roughness = 1.0
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.position = Vector3(mid.x, h * 0.5, mid.y)


static func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return absf(a.distance_to(p) + p.distance_to(b) - a.distance_to(b)) < 0.05


## Ground height at a world XZ. Zero inside the compound (the pad is flat by
## design); real relief out on the apron. Everything placed outside the wire MUST
## go through this or it floats over a rise and sinks into a dip.
func _ground_y(x: float, z: float) -> float:
	return 0.0 if terrain == null else terrain.height_at(Vector3(x, 0.0, z))


# ---------------------------------------------------------------- buyables

func _build_gates() -> void:
	for spec in GATES:
		var gate := ZombieDoor.new()
		gate.name = String(spec["id"])
		gate.door_id = String(spec["id"])
		gate.price = int(spec["cost"])
		gate.unlocks_zone = String(spec["zone"])
		add_child(gate)
		gate.position = spec["at"]

		var along_x: bool = bool(spec["along_x"])
		var size := Vector3(GAP_W if along_x else 0.3, WALL_H, 0.3 if along_x else GAP_W)

		var blocker := StaticBody3D.new()
		blocker.name = "Blocker"
		blocker.collision_layer = 1
		blocker.collision_mask = 0
		# NOT nav_source: the opening stays on the navmesh forever.
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.position.y = WALL_H * 0.5
		blocker.add_child(cs)
		gate.add_child(blocker)

		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf"
		var bm := BoxMesh.new()
		bm.size = size
		leaf.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.40, 0.33, 0.18)
		mat.roughness = 1.0
		leaf.material_override = mat
		leaf.position.y = WALL_H * 0.5
		gate.add_child(leaf)


## A breach, its boards, and the spawn on the apron behind it. Paired here on
## purpose: a breach with no spawn is scenery, and a spawn with no breach is a
## zombie walking through a wall.
func _build_breaches() -> void:
	for spec in BREACHES:
		var at: Vector3 = spec["at"]
		var out: Vector3 = (spec["out"] as Vector3).normalized()

		var bar := ZombieBarricade.new()
		bar.barricade_id = "breach_%d_%d" % [int(at.x), int(at.z)]
		bar.opening_size = Vector2(GAP_W, 2.0)
		bar.board_count = 6
		add_child(bar)
		bar.position = at + Vector3(0, 1.0, 0)
		# Face the boards across the opening: the gap runs perpendicular to `out`.
		bar.rotation.y = atan2(out.x, out.z)

		var sp := ZombieSpawnPoint.new()
		sp.zone = String(spec["zone"])
		sp.min_player_distance = 8.0
		add_child(sp)
		# ON THE APRON, on real ground with real navmesh under it. This is the
		# line the first layout got wrong. Height comes from the terrain, or a
		# spawn on a rise drops its zombie out of the sky.
		var sp_at: Vector3 = at + out * APRON
		sp.position = Vector3(sp_at.x, _ground_y(sp_at.x, sp_at.z) + 0.1, sp_at.z)


func _build_interactables() -> void:
	for spec in WALL_BUYS:
		var wb := ZombieWallBuy.new()
		wb.buy_id = String(spec["id"])
		wb.name = "wallbuy_" + wb.buy_id
		add_child(wb)
		wb.position = spec["at"]
		wb.rotation.y = deg_to_rad(float(spec["yaw"]))

	for i in BOX_SPOTS.size():
		var spot := Node3D.new()
		spot.name = "box_spot_%d" % i
		spot.add_to_group("zombie_box_spots")
		add_child(spot)
		spot.position = BOX_SPOTS[i]

	var box := ZombieMysteryBox.new()
	box.name = "MysteryBox"
	add_child(box)
	box.position = BOX_SPOTS[0]

	for spec in POWER_UPS:
		var pu := ZombiePowerUp.new()
		pu.power_id = String(spec["id"])
		pu.name = "powerup_" + pu.power_id
		add_child(pu)
		pu.position = spec["at"]


# ---------------------------------------------------------------- dressing

## Heavy prop use, per his note. Placement is seeded so the lot is the same lot
## every run - learning the map is most of what the player does between rounds.
func _dress() -> void:
	var plan: Array[Dictionary] = [
		# THE LOT: parked-up, barricaded, the fight starts here
		{"dir": "barriers", "names": [], "at": Vector3(50, 0, 74), "n": 14, "spread": 18.0},
		{"dir": "industrial", "names": ["cargocontainer"], "at": Vector3(38, 0, 88),
		 "n": 4, "spread": 8.0},
		{"dir": "debris", "names": [], "at": Vector3(56, 0, 82), "n": 18, "spread": 14.0},
		{"dir": "ammo", "names": [], "at": Vector3(31, 0, 63), "n": 5, "spread": 2.5},
		# HANGAR
		{"dir": "hangar", "names": ["hangar"], "at": Vector3(100, 0, 78), "n": 1,
		 "spread": 0.0, "yaw": 0.0},
		{"dir": "industrial", "names": ["barreloil", "jerrycan", "generatorunit",
		 "generatorportable", "locker", "locker2"], "at": Vector3(112, 0, 88),
		 "n": 12, "spread": 9.0},
		# WAREHOUSE
		{"dir": "industrial", "names": ["crate", "cratewood", "cratewood2",
		 "cratemetal", "cratemetal2", "cargocontainer"], "at": Vector3(50, 0, 38),
		 "n": 18, "spread": 14.0},
		{"dir": "debris", "names": [], "at": Vector3(38, 0, 30), "n": 12, "spread": 8.0},
		# YARD
		{"dir": "industrial", "names": ["concretepipe", "concretepipepile",
		 "dumpster", "barrelwater", "brick", "brickcement"], "at": Vector3(100, 0, 38),
		 "n": 14, "spread": 12.0},
		{"dir": "barriers", "names": [], "at": Vector3(112, 0, 30), "n": 6, "spread": 6.0},
		# outside the wire, so the apron is not a bare grey field
		{"dir": "debris", "names": [], "at": Vector3(50, 0, 108), "n": 10, "spread": 16.0},
		{"dir": "barriers", "names": [], "at": Vector3(14, 0, 76), "n": 5, "spread": 7.0},
	]
	var placed: int = 0
	for p in plan:
		placed += _scatter(String(p["dir"]), p["names"], p["at"], int(p["n"]),
			float(p["spread"]), float(p.get("yaw", -1.0)))
	print("[LOT] dressed with %d props" % placed)


func _scatter(subdir: String, names: Array, centre: Vector3, count: int,
		spread: float, yaw: float) -> int:
	var pool: Array = names
	if pool.is_empty():
		pool = _list_kit(subdir)
	if pool.is_empty():
		push_warning("[LOT] psx_kit/%s is empty - nothing to place" % subdir)
		return 0
	var made: int = 0
	for i in count:
		var path: String = KIT + subdir + "/" + String(pool[_rng.randi() % pool.size()]) + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			continue
		var inst := packed.instantiate() as Node3D
		if inst == null:
			continue
		add_child(inst)
		var px: float = centre.x + _rng.randf_range(-spread, spread)
		var pz: float = centre.z + _rng.randf_range(-spread, spread)
		inst.global_position = Vector3(px, centre.y + _ground_y(px, pz), pz)
		inst.rotation.y = deg_to_rad(yaw) if yaw >= 0.0 else _rng.randf_range(0.0, TAU)
		# Props are cover, so they collide - but they are NOT nav_source. Baking
		# them in carves the ground into slivers and the horde jams on the debris.
		_add_box_collider(inst)
		made += 1
	return made


func _add_box_collider(inst: Node3D) -> void:
	var mi: MeshInstance3D = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			mi = n as MeshInstance3D
			break
	if mi == null or mi.mesh == null:
		return
	var aabb: AABB = mi.mesh.get_aabb()
	if aabb.size.length() < 0.05:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	cs.shape = box
	cs.position = aabb.get_center()
	body.add_child(cs)
	inst.add_child(body)


func _list_kit(subdir: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(KIT + subdir)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".glb"):
			out.append(f.trim_suffix(".glb"))
	out.sort()
	return out


# ---------------------------------------------------------------- navigation

## Baked ONCE over the whole ground - INCLUDING the apron outside the wire, or the
## spawns have no mesh under them and the round stands still. Every gate and
## breach is a gap in a wall run, so the mesh already flows through them.
func bake_nav() -> void:
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "LotNav"
	add_child(_nav_region)
	var nm := NavigationMesh.new()
	# Whole multiples of the voxel size (cell_size 0.25 / cell_height 0.25), or
	# the baker rounds each one and warns about the lost precision.
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	# MUST match the navigation map's cell_size (0.25) or Godot rasterises the
	# edges on a coarser grid and agents clip every opening's corners.
	nm.cell_size = 0.25

	# PARSE THE `nav_source` GROUP, NOT THE REGION'S CHILDREN.
	# NavigationRegion3D defaults to SOURCE_GEOMETRY_ROOT_NODE_CHILDREN, and this
	# region has NO children - the ground and walls are its SIBLINGS. That default
	# baked a completely EMPTY navmesh, and nothing looked broken: ZombieBase falls
	# back to straight-line movement when a path will not resolve, so the horde
	# still walked at the player and would simply have jammed on the first wall.
	# The group is the project's existing convention for exactly this.
	# STATIC_COLLIDERS, and it is the only option that works here. Godot cannot
	# parse MeshInstance3D source geometry at RUNTIME - it says so itself when you
	# try ("For runtime (re)baking navigation meshes use and parse collision shapes
	# as source geometry") - so MESH_INSTANCES and BOTH both bake empty outside the
	# editor. Every nav_source node must therefore carry a real collision shape.
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	_nav_region.navigation_mesh = nm
	print("[LOT] baking nav from %d 'nav_source' node(s)"
		% get_tree().get_nodes_in_group("nav_source").size())
	_nav_region.bake_navigation_mesh(false)

	# Say how big the mesh came out. An empty bake is silent and its symptom
	# (agents walking into walls) looks like an AI bug, not a navigation one.
	var polys: int = nm.get_polygon_count()
	if polys == 0:
		push_warning("[LOT] navmesh baked EMPTY - every zombie will straight-line "
			+ "into the nearest wall. Check the 'nav_source' group.")
	else:
		print("[LOT] navmesh baked: %d polygons, %d vertices"
			% [polys, nm.get_vertices().size()])


func player_start() -> Vector3:
	return PLAYER_START
