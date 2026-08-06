## zombie_map_depot.gd - THE DEPOT. The VC Zombies map.
##
## An enclosed supply depot, five zones on a RING:
##
##     DISPATCH -> WAREHOUSE -> YARD -> CORRIDOR -> back to DISPATCH
##
## The ring is the point. Round 1 you are locked in one office with two boarded
## windows; buy all four doors and the map becomes a loop you can train the horde
## around. That progression from cornered to mobile IS the mode's arc, and it is
## bought with points rather than handed over.
##
## NAVIGATION IS BAKED ONCE, WITH EVERY OPENING OPEN, AND NEVER REBAKES.
## Doorways are gaps in the wall runs, so the navmesh already flows through them.
## What closes a door or a window is a PHYSICAL blocker that is deliberately NOT
## in the `nav_source` group - see ZombieBarricade's header for the full reasoning.
## Nothing in this project rebakes nav on structure death (nav_baker.gd:16-18) and
## this map is built so that it never has to.
##
## Geometry is placed in code, the same way ai_stress_arena builds its firebase.
## Shipped GLBs for every prop; primitives only for floor and walls.
class_name ZombieMapDepot
extends Node3D

const KIT: String = "res://assets/world/props/psx_kit/"
const WALL_H: float = 4.0
const WALL_T: float = 0.4

## zone -> Rect2(x, z, w, d). Rooms share edges; a door lives in the shared wall.
const ZONES: Dictionary = {
	"dispatch":  Rect2(0, 0, 16, 14),
	"warehouse": Rect2(16, 0, 28, 14),
	"hangar":    Rect2(44, 0, 26, 30),
	"yard":      Rect2(16, 14, 28, 20),
	"corridor":  Rect2(0, 14, 16, 20),
}

## Each door: position, whether it faces along X, the zone it unlocks, its price.
## Prices climb because each zone also adds spawn points - you are buying ground
## and paying for it in directions to watch.
const DOORS: Array[Dictionary] = [
	{"id": "d_dispatch_warehouse", "at": Vector3(16, 0, 7), "along_x": false,
	 "zone": "warehouse", "cost": 750},
	{"id": "d_warehouse_hangar", "at": Vector3(44, 0, 7), "along_x": false,
	 "zone": "hangar", "cost": 1250},
	{"id": "d_warehouse_yard", "at": Vector3(30, 0, 14), "along_x": true,
	 "zone": "yard", "cost": 1750},
	{"id": "d_dispatch_corridor", "at": Vector3(8, 0, 14), "along_x": true,
	 "zone": "corridor", "cost": 1000},
]
const DOOR_W: float = 2.6

## Boarded openings. Zone decides when their spawn goes live.
const WINDOWS: Array[Dictionary] = [
	{"zone": "", "at": Vector3(0, 1.3, 4), "yaw": 90.0},
	{"zone": "", "at": Vector3(0, 1.3, 10), "yaw": 90.0},
	{"zone": "warehouse", "at": Vector3(24, 1.3, 0), "yaw": 0.0},
	{"zone": "warehouse", "at": Vector3(34, 1.3, 0), "yaw": 0.0},
	{"zone": "warehouse", "at": Vector3(40, 1.3, 0), "yaw": 0.0},
	{"zone": "hangar", "at": Vector3(70, 1.3, 8), "yaw": 90.0},
	{"zone": "hangar", "at": Vector3(70, 1.3, 20), "yaw": 90.0},
	{"zone": "hangar", "at": Vector3(56, 1.3, 30), "yaw": 0.0},
	{"zone": "yard", "at": Vector3(22, 1.3, 34), "yaw": 0.0},
	{"zone": "yard", "at": Vector3(30, 1.3, 34), "yaw": 0.0},
	{"zone": "yard", "at": Vector3(38, 1.3, 34), "yaw": 0.0},
	{"zone": "yard", "at": Vector3(44, 1.3, 24), "yaw": 90.0},
	{"zone": "corridor", "at": Vector3(0, 1.3, 20), "yaw": 90.0},
	{"zone": "corridor", "at": Vector3(0, 1.3, 28), "yaw": 90.0},
]

## Five guns, spread so no single zone arms you completely.
const WALL_BUYS: Array[Dictionary] = [
	{"id": "m16", "at": Vector3(2.2, 1.5, 2.0), "yaw": 90.0},
	{"id": "ak", "at": Vector3(30.0, 1.5, 1.0), "yaw": 0.0},
	{"id": "m60", "at": Vector3(68.0, 1.5, 26.0), "yaw": 90.0},
	{"id": "shotgun", "at": Vector3(18.5, 1.5, 32.5), "yaw": 0.0},
	{"id": "rpg", "at": Vector3(42.0, 1.5, 32.0), "yaw": 0.0},
]

const BOX_SPOTS: Array[Vector3] = [
	Vector3(30, 0.6, 7), Vector3(56, 0.6, 14), Vector3(30, 0.6, 24),
]

const POWER_UPS: Array[Dictionary] = [
	{"id": "toughness", "at": Vector3(62, 0.0, 4)},
	{"id": "stamina", "at": Vector3(20, 0.0, 18)},
	{"id": "speedload", "at": Vector3(8, 0.0, 30)},
]

const PLAYER_START := Vector3(8, 0.1, 4)
## Compound centre, used to decide which side of a wall is "outside".
const CENTRE := Vector3(35.0, 0.0, 17.0)

var _rng := RandomNumberGenerator.new()
var _nav_region: NavigationRegion3D = null


func build(seed_value: int = 20260805) -> void:
	_rng.seed = seed_value
	_build_floor()
	_build_walls()
	_build_doors()
	_build_windows()
	_build_interactables()
	_dress()
	bake_nav()


# ---------------------------------------------------------------- shell

func _build_floor() -> void:
	# One slab under the whole compound. Separate per-room floors would leave
	# seams the player catches a foot on at every threshold.
	var body := StaticBody3D.new()
	body.name = "DepotFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 34)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.15)
	mat.roughness = 1.0
	mi.mesh.surface_set_material(0, mat)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(70, 0.2, 34)
	cs.shape = box
	cs.position.y = -0.1
	body.add_child(cs)
	add_child(body)
	body.position = Vector3(35, 0, 17)


## Wall runs with gaps where the doors go. The GAP is what makes the navmesh
## flow through a doorway - the door leaf is a blocker laid into an opening that
## navigation always considered passable.
func _build_walls() -> void:
	var runs: Array[Dictionary] = [
		# perimeter
		{"a": Vector2(0, 0), "b": Vector2(70, 0)},
		{"a": Vector2(0, 34), "b": Vector2(44, 34)},
		{"a": Vector2(44, 30), "b": Vector2(70, 30)},
		{"a": Vector2(0, 0), "b": Vector2(0, 34)},
		{"a": Vector2(70, 0), "b": Vector2(70, 30)},
		{"a": Vector2(44, 30), "b": Vector2(44, 34)},
		# interior
		{"a": Vector2(16, 0), "b": Vector2(16, 14)},
		{"a": Vector2(44, 0), "b": Vector2(44, 30)},
		{"a": Vector2(16, 14), "b": Vector2(44, 14)},
		{"a": Vector2(0, 14), "b": Vector2(16, 14)},
	]
	for r in runs:
		_wall_run(r["a"], r["b"])


func _wall_run(a: Vector2, b: Vector2) -> void:
	var gaps: Array[Vector2] = []
	for d in DOORS:
		var at: Vector3 = d["at"]
		var p := Vector2(at.x, at.z)
		if _on_segment(p, a, b):
			gaps.append(p)
	var dir: Vector2 = (b - a).normalized()
	var total: float = a.distance_to(b)
	var marks: Array[float] = [0.0]
	for g in gaps:
		var t: float = a.distance_to(g)
		marks.append(t - DOOR_W * 0.5)
		marks.append(t + DOOR_W * 0.5)
	marks.append(total)
	marks.sort()
	for i in range(0, marks.size(), 2):
		if i + 1 >= marks.size():
			break
		var t0: float = maxf(0.0, marks[i])
		var t1: float = minf(total, marks[i + 1])
		if t1 - t0 < 0.15:
			continue
		var p0: Vector2 = a + dir * t0
		var p1: Vector2 = a + dir * t1
		_wall_box(p0, p1)


func _wall_box(p0: Vector2, p1: Vector2) -> void:
	var mid: Vector2 = (p0 + p1) * 0.5
	var len_m: float = p0.distance_to(p1)
	var horiz: bool = absf(p1.x - p0.x) > absf(p1.y - p0.y)
	var size := Vector3(len_m if horiz else WALL_T, WALL_H, WALL_T if horiz else len_m)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
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
	body.position = Vector3(mid.x, WALL_H * 0.5, mid.y)


static func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var d: float = a.distance_to(b)
	return absf(a.distance_to(p) + p.distance_to(b) - d) < 0.05


# ---------------------------------------------------------------- buyables

func _build_doors() -> void:
	for spec in DOORS:
		var door := ZombieDoor.new()
		door.name = String(spec["id"])
		door.door_id = String(spec["id"])
		door.price = int(spec["cost"])
		door.unlocks_zone = String(spec["zone"])
		add_child(door)
		door.position = spec["at"]

		var blocker := StaticBody3D.new()
		blocker.name = "Blocker"
		blocker.collision_layer = 1
		blocker.collision_mask = 0
		# NOT a nav_source: the doorway must stay open on the navmesh forever.
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var along_x: bool = bool(spec["along_x"])
		box.size = Vector3(DOOR_W if along_x else 0.3, WALL_H,
			0.3 if along_x else DOOR_W)
		cs.shape = box
		cs.position.y = WALL_H * 0.5
		blocker.add_child(cs)
		door.add_child(blocker)

		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf"
		var bm := BoxMesh.new()
		bm.size = box.size
		leaf.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.34, 0.22, 0.13)
		leaf.material_override = mat
		leaf.position.y = WALL_H * 0.5
		door.add_child(leaf)


## A boarded opening, plus the spawn point OUTSIDE it. Pairing them here is the
## point: a window with no spawn behind it is scenery, and a spawn with no window
## is a zombie walking through a wall.
func _build_windows() -> void:
	for spec in WINDOWS:
		var at: Vector3 = spec["at"]
		var yaw: float = deg_to_rad(float(spec["yaw"]))

		var bar := ZombieBarricade.new()
		bar.barricade_id = "win_%d_%d" % [int(at.x), int(at.z)]
		bar.opening_size = Vector2(1.8, 1.5)
		bar.board_count = 6
		add_child(bar)
		bar.position = at
		bar.rotation.y = yaw

		# Push the spawn OUTSIDE, away from the compound centre, and clear of the
		# wall - a spawn left on the inside face drops bodies in the room the
		# window was supposed to protect.
		var out_dir: Vector3 = (at - CENTRE)
		out_dir.y = 0.0
		out_dir = out_dir.normalized() if out_dir.length() > 0.01 else Vector3.FORWARD
		var outside: Vector3 = at + out_dir * 3.5
		var sp := ZombieSpawnPoint.new()
		sp.zone = String(spec["zone"])
		sp.min_player_distance = 6.0
		add_child(sp)
		sp.position = Vector3(outside.x, 0.1, outside.z)


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

## Props from the imported PSX kit. Placement is seeded, so the depot is the same
## room every run - a map that reshuffles cannot be learned, and learning the map
## is most of what a player is doing between rounds.
func _dress() -> void:
	var plan: Array[Dictionary] = [
		{"dir": "hangar", "names": ["hangar"], "at": Vector3(57, 0, 15), "n": 1,
		 "spread": 0.0, "yaw": 0.0},
		{"dir": "industrial", "names": ["cargocontainer", "cratewood", "cratemetal",
		 "crate", "cratewood2", "cratemetal2"], "at": Vector3(30, 0, 7), "n": 12,
		 "spread": 9.0, "yaw": -1.0},
		{"dir": "industrial", "names": ["barreloil", "barrelwater", "jerrycan",
		 "generatorportable", "locker", "dumpster"], "at": Vector3(58, 0, 20),
		 "n": 10, "spread": 8.0, "yaw": -1.0},
		{"dir": "barriers", "names": ["jersey_barrier", "jersey_barrier_dirty",
		 "jersey_barrier_broken_edge", "jersey_barrier_broken_center"],
		 "at": Vector3(30, 0, 24), "n": 9, "spread": 8.0, "yaw": -1.0},
		{"dir": "debris", "names": [], "at": Vector3(8, 0, 24), "n": 14,
		 "spread": 6.0, "yaw": -1.0},
		{"dir": "ammo", "names": ["7_62cal", "5_56cal", "12cal"],
		 "at": Vector3(4, 0, 6), "n": 4, "spread": 2.0, "yaw": -1.0},
	]
	var placed: int = 0
	for p in plan:
		placed += _scatter(String(p["dir"]), p["names"], p["at"], int(p["n"]),
			float(p["spread"]), float(p["yaw"]))
	print("[DEPOT] dressed with %d props" % placed)


func _scatter(subdir: String, names: Array, centre: Vector3, count: int,
		spread: float, yaw: float) -> int:
	var pool: Array = names
	if pool.is_empty():
		pool = _list_kit(subdir)
	if pool.is_empty():
		push_warning("[DEPOT] psx_kit/%s is empty - nothing to place" % subdir)
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
		inst.global_position = centre + Vector3(
			_rng.randf_range(-spread, spread), 0.0, _rng.randf_range(-spread, spread))
		inst.rotation.y = deg_to_rad(yaw) if yaw >= 0.0 else _rng.randf_range(0.0, TAU)
		# Props are cover, so they are solid - but they are NOT nav_source. Baking
		# them in would carve the floor into slivers and the horde would jam.
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

## Baked ONCE, from the floor and the walls only. Every doorway and window is a
## gap in those, so the mesh already flows through them and no later event needs
## to touch it.
func bake_nav() -> void:
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "DepotNav"
	add_child(_nav_region)
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	# MUST match the navigation map's own cell_size (0.25, the project default) or
	# Godot rasterises the mesh edges against a coarser grid and warns. A mismatch
	# here shows up as agents clipping doorway corners, which on this map is every
	# zombie coming through every window.
	nm.cell_size = 0.25
	_nav_region.navigation_mesh = nm
	# Fresh mesh, never a reused resource - a stale bake is the classic way a map
	# ships with the previous layout's holes in it.
	_nav_region.bake_navigation_mesh(false)


func player_start() -> Vector3:
	return PLAYER_START
