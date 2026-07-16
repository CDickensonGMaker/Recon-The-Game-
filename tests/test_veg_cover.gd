## test_veg_cover.gd - headless proof that arena vegetation gives cover + concealment.
## With the GameplayGrid wired into the arena (Track D1), asserts:
##   (a) the grid is live and in group "game_world";
##   (b) OPEN ground reads ~0 density -> sight cap ~140m; JUNGLE reads >0.6 -> cap ~45-55m
##       (this doubles as the world_to_grid origin-offset guard: negative arena coords must
##        NOT collapse onto cell 0);
##   (c) an enemy standing in jungle CANNOT witness a target at 80m (distance > sight cap),
##       but CAN in the open (concealment via the wired sight cap);
##   (d) a tree TRUNK collider blocks both a bullet-mask ray and an LOS-mask ray, while an
##       open lane is clear (Track D2);
##   (e) reports a blocked-vs-clear ratio over a random ray sweep (cover-density proof).
## Run: godot --headless --path . res://tests/test_veg_cover.tscn
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")

## World points chosen from the arena layout: centre is the open contact zone; the
## jungle sample sits inside a north-flank tree-line clump band (z ~ +84).
const OPEN_PT: Vector3 = Vector3(0.0, 0.5, 0.0)
const JUNGLE_PT: Vector3 = Vector3(-88.0, 0.5, 84.0)

var _arena: Node3D
var _elapsed: float = 0.0
var _done: bool = false
var _failures: int = 0


func _ready() -> void:
	print("=== Vegetation Cover + Concealment Probe ===")
	_arena = ArenaScript.new()
	_arena.set("us_squads_active", 1)
	_arena.set("vc_squads_active", 1)
	_arena.set("men_per_squad", 3)
	_arena.set("us_reserve_squads", 0)
	_arena.set("vc_reserve_squads", 0)
	_arena.set("round_max_seconds", 60.0)
	_arena.set("spawn_player", false)
	_arena.set("spawn_hud", false)
	_arena.set("bench_dressing", false)
	_arena.set("hot_start", false)
	_arena.set("patrol_mode", false)
	add_child(_arena)


func _process(delta: float) -> void:
	_elapsed += delta
	# Let the arena finish its nav bake (two physics frames) + spawn before sampling.
	if _done or _elapsed < 1.5:
		return
	_done = true
	_run_checks()


func _run_checks() -> void:
	var grid: GameplayGrid = _arena.get("gameplay_grid")

	# (a) grid live + group membership
	if grid == null:
		_fail("(a) gameplay_grid is null - the grid never built")
		return _finish()
	if not _arena.is_in_group("game_world"):
		_fail("(a) arena not in group 'game_world' - enemy_base can't find the grid")

	# (b) density + sight-cap, and the origin-offset guard
	var veg_open: float = grid.get_vegetation(OPEN_PT)
	var veg_jungle: float = grid.get_vegetation(JUNGLE_PT)
	print("density: open=%.2f  jungle=%.2f" % [veg_open, veg_jungle])
	if veg_open > 0.1:
		_fail("(b) open ground reads %.2f density (expected ~0) - offset trap? veg leaking?" % veg_open)
	if veg_jungle < 0.6:
		_fail("(b) jungle reads %.2f density (expected >0.6) - stamp missing or offset trap" % veg_jungle)

	var e: EnemyBase = _first_living_enemy()
	if e == null:
		_fail("(b) no living enemy to measure sight cap")
		return _finish()

	e.global_position = OPEN_PT
	var cap_open: float = e._sight_cap(OPEN_PT)
	e.global_position = JUNGLE_PT
	var cap_jungle: float = e._sight_cap(JUNGLE_PT)
	print("sight cap: open=%.1fm  jungle=%.1fm" % [cap_open, cap_jungle])
	if cap_open < 130.0:
		_fail("(b) open sight cap %.1fm (expected ~140)" % cap_open)
	if cap_jungle > 60.0:
		_fail("(b) jungle sight cap %.1fm (expected ~45-55)" % cap_jungle)

	# (c) concealment: an 80m contact is beyond the jungle cap but inside the open cap
	if cap_jungle >= 80.0:
		_fail("(c) jungle cap %.1fm does not conceal an 80m target" % cap_jungle)
	if cap_open <= 80.0:
		_fail("(c) open cap %.1fm should still see an 80m target" % cap_open)

	# (d) trunk blocks bullet + sight; open lane clear
	_check_trunk()

	# (e) blocked-vs-clear ratio sweep (cover-density proof)
	var ratio: Vector2i = _ray_sweep(200, 30.0)
	var blocked: int = ratio.x
	var total: int = ratio.x + ratio.y
	print("ray sweep: %d/%d rays blocked (%.0f%% cover)" % [
		blocked, total, 100.0 * float(blocked) / float(maxi(1, total))])
	if blocked == 0:
		_fail("(e) not one ray in %d hit cover - the arena has no solid geometry?" % total)

	_finish()


## Bullet mask (world+hurtboxes) and LOS mask (world) must both stop on a trunk.
func _check_trunk() -> void:
	var trunk: StaticBody3D = _find_trunk(_arena)
	if trunk == null:
		_fail("(d) no trunk collider found (r=0.3 cylinder) - trunk wiring missing")
		return
	var p: Vector3 = trunk.global_position
	var mid: Vector3 = Vector3(p.x, p.y + 1.2, p.z)
	var from: Vector3 = mid + Vector3(-1.2, 0.0, 0.0)
	var to: Vector3 = mid + Vector3(1.2, 0.0, 0.0)

	var bullet_hit: bool = not _ray(from, to, 1 | 32 | 64).is_empty()
	var los_hit: bool = not _ray(from, to, 1).is_empty()
	# Control: an empty pocket above the open centre.
	var clear_ray: bool = _ray(Vector3(0, 2.5, 10), Vector3(0, 2.5, 12), 1 | 32 | 64).is_empty()
	print("trunk @ (%.1f,%.1f): bullet blocked=%s  sight blocked=%s  open-lane clear=%s" % [
		p.x, p.z, bullet_hit, los_hit, clear_ray])
	if not bullet_hit:
		_fail("(d) trunk did NOT stop a bullet-mask ray")
	if not los_hit:
		_fail("(d) trunk did NOT stop an LOS-mask ray")
	if not clear_ray:
		_fail("(d) the open control lane was not clear (bad control)")


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask)
	return space.intersect_ray(q)


## Cast horizontal rays at eye height from random points and count how many hit cover.
func _ray_sweep(n: int, length: float) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var blocked: int = 0
	var half: float = float(_arena.ARENA) * 0.5 - 2.0
	for _i in range(n):
		var from := Vector3(rng.randf_range(-half, half), 1.5, rng.randf_range(-half, half))
		var ang: float = rng.randf_range(0.0, TAU)
		var to := from + Vector3(cos(ang), 0.0, sin(ang)) * length
		if not _ray(from, to, 1 | 32 | 64).is_empty():
			blocked += 1
	return Vector2i(blocked, n - blocked)


func _find_trunk(root: Node) -> StaticBody3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var body := node as StaticBody3D
		if body != null and _is_trunk(body):
			return body
		for c in node.get_children():
			stack.append(c)
	return null


## Trunk signature: a StaticBody3D carrying a CylinderShape3D of radius 0.3, height 3.0
## (fallen logs use r=0.45; boxes are berms/rocks).
func _is_trunk(body: StaticBody3D) -> bool:
	for c in body.get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		var cyl := cs.shape as CylinderShape3D
		if cyl != null and is_equal_approx(cyl.radius, 0.3) and is_equal_approx(cyl.height, 3.0):
			return true
	return false


func _first_living_enemy() -> EnemyBase:
	for squad in _arena.get("_vc_squads"):
		for e in squad:
			if is_instance_valid(e) and not e.is_dead():
				return e as EnemyBase
	return null


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL %s" % msg)


func _finish() -> void:
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
