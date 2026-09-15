## probe_nav_ring.gd - can a man outside the wire path INTO the firebase, on every bearing?
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --nav-ring-probe --test-save --demo-map=N
##
## Attached to the live world by game_flow.gd under `--nav-ring-probe`. Waits for the firebase
## bake, then walks 36 bearings from RING_OUT_M in to RING_IN_M and asks the NavigationServer,
## from each sample point on the ground, for a path to the gate and to the siege aim. One line
## per bearing: the ground profile, water, the outermost radius a path to the gate exists from,
## and the innermost radius that is still off the mesh. Quits when done.
extends Node

const RING_OUT_M: float = 180.0
const RING_IN_M: float = 40.0
const STEP_M: float = 4.0
const BEARINGS: int = 36
const ON_MESH_M: float = 0.5
const ARRIVED_M: float = 2.0
const SETTLE_S: float = 3.0

var _world: Node3D = null
var _settle: float = -1.0
var _done: bool = false


func _ready() -> void:
	_world = get_parent() as Node3D


func _process(delta: float) -> void:
	if _done:
		return
	var flow: GameFlow = get_tree().get_first_node_in_group("game_flow") as GameFlow
	var director: FieldDirector = flow.director if flow != null else null
	if director == null or director.fsb_center == Vector3.ZERO:
		return
	if NavBaker.box_index_at(director.fsb_center) < 0:
		return
	if _settle < 0.0:
		_settle = SETTLE_S
	_settle -= delta
	if _settle > 0.0:
		return
	_done = true
	_run(director)
	get_tree().quit(0)


func _run(director: FieldDirector) -> void:
	var map: RID = get_tree().root.get_world_3d().navigation_map
	var c: Vector3 = director.fsb_center
	var gate: Vector3 = director.patrol_gate_pos
	var aim: Vector3 = director.siege_aim if director.siege_aim != Vector3.ZERO else c
	var grid: Object = _world.get("gameplay_grid")
	print("[NAV-RING] map %.0f centre %s gate %s aim %s | gate on mesh %.2fm aim on mesh %.2fm" % [
		float(_world.get("map_size")), c, gate, aim,
		NavigationServer3D.map_get_closest_point(map, gate).distance_to(gate),
		NavigationServer3D.map_get_closest_point(map, aim).distance_to(aim)])
	var n_steps: int = int((RING_OUT_M - RING_IN_M) / STEP_M) + 1
	for b in range(BEARINGS):
		var ang: float = TAU * float(b) / float(BEARINGS)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var gate_from: float = -1.0
		var aim_from: float = -1.0
		var off_in: float = -1.0
		var water_max: float = 0.0
		var y_out: float = 0.0
		var y_in: float = 0.0
		var y_min: float = INF
		var y_max: float = -INF
		var steep: int = 0
		var prev_y: float = NAN
		for i in range(n_steps):
			var r: float = RING_OUT_M - float(i) * STEP_M
			var p: Vector3 = c + dir * r
			p.y = float(_world.call("floor_y", p))
			if i == 0:
				y_out = p.y
			y_in = p.y
			y_min = minf(y_min, p.y)
			y_max = maxf(y_max, p.y)
			if not is_nan(prev_y) and absf(p.y - prev_y) > STEP_M:
				steep += 1
			prev_y = p.y
			if grid != null and grid.has_method("get_water_depth"):
				water_max = maxf(water_max, float(grid.call("get_water_depth", p)))
			var snap: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
			var flat := Vector2(snap.x - p.x, snap.z - p.z)
			if flat.length() > ON_MESH_M:
				off_in = r
				continue
			if gate_from < 0.0 and _reaches(map, snap, gate):
				gate_from = r
			if aim_from < 0.0 and _reaches(map, snap, aim):
				aim_from = r
		print("[NAV-RING] %3.0f deg | ground %.1f..%.1f (out %.1f in %.1f) steep %d water %.2f | off-mesh in to %.0fm | path to gate from %.0fm, to aim from %.0fm" % [
			rad_to_deg(ang), y_min, y_max, y_out, y_in, steep, water_max, off_in, gate_from, aim_from])
	_rim(map, c, gate)


## The rim: along the gate bearing, metre by metre, the physics floor, the heightmap and the
## navmesh surface - a step between the compound's ground sheet and the terrain shows here.
func _rim(map: RID, c: Vector3, gate: Vector3) -> void:
	var tm: Object = _world.get("terrain_manager")
	var dir := Vector3(gate.x - c.x, 0.0, gate.z - c.z).normalized()
	for r in range(int(RING_IN_M), int(RING_OUT_M) + 1):
		var p: Vector3 = c + dir * float(r)
		var fy: float = float(_world.call("floor_y", p))
		var hy: float = float(tm.call("get_height_at", p)) if tm != null else NAN
		var snap: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(p.x, fy, p.z))
		var flat: float = Vector2(snap.x - p.x, snap.z - p.z).length()
		var reach: bool = flat <= ON_MESH_M and _reaches(map, snap, gate)
		print("[NAV-RIM] r=%3d floor %.2f heightmap %.2f mesh_y %.2f mesh_xz_off %.2f gate_path %s" % [
			r, fy, hy, snap.y, flat, "yes" if reach else "NO"])

static func _reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	return NavRouter.server_reaches(map, from, to)
