## probe_aim_ground_point.gd - squad_system.gd:322, the one wave-1 height call site that
## was changed and never measured because "it needs a live player camera". This is that
## camera.
##
## _aim_ground_point() is where a MOVE order lands: the player looks somewhere and the
## squad is sent there. It does NOT raycast. It marches the look direction outward in 5m
## steps and, at each step, samples world.surface_y() at that XZ, stopping at the first
## step where the ray has dropped to or below the sampled height.
##
## GROUND TRUTH here is not a table and not another height helper - it is a real physics
## ray from the real camera along the real view direction, which is by definition the
## point the player is looking at. The probe reports how far the shipped answer sits from
## that, in metres, for shots at open ground, at a building, and over one.
##
##   godot --headless --path . res://tests/probe_aim_ground_point.tscn
extends Node

const SEED_VAL: int = 4242
const HUT_PATH := "res://assets/world/building models/structures/village/nha_san_01.glb"
## How far the shipped answer may sit from the point the camera is actually looking at.
## The march steps 5m, so anything under a couple of metres is the method's own grain.
const TOL_M: float = 3.0

var _failures: int = 0
var _blind: Array[String] = []


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== AIM GROUND POINT PROBE (squad_system.gd:322) ===")
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 240.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		_fail("world timeout")
		_finish()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
		world.vegetation_manager, world)
	var centre: Vector3 = planner.find_site(rng, 40.0)
	if centre == Vector3.ZERO:
		_fail("no flat site found")
		_finish()
		return
	planner.clear_and_flatten(centre, 60.0)
	# A stilt house: a roof well above bare terrain, which is the only shape that can
	# tell surface_y's answer from the ground's.
	var hut_at: Vector3 = centre
	planner.place_structure(HUT_PATH, hut_at, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var terrain_y: float = world.terrain_manager.get_height_at(centre)
	var roof_y: float = world.surface_y(Vector3(centre.x, terrain_y, centre.z))
	print("  site %s  terrain %.2f  hut roof %.2f  (%.2fm apart)" % [
		str(Vector2(centre.x, centre.z)), terrain_y, roof_y, roof_y - terrain_y])
	if roof_y - terrain_y < 1.0:
		_blind.append("the hut placed no roof above terrain here (%.2fm) - the "
			% (roof_y - terrain_y) + "building cases cannot fail")

	# Stand the player 25m off the hut, looking at it.
	var stand := Vector3(centre.x + 25.0, 0.0, centre.z)
	world.spawn_player_at(Vector3(stand.x, world.terrain_manager.get_height_at(stand), stand.z))
	await get_tree().physics_frame
	if world.player == null:
		_fail("no player spawned")
		_finish()
		return
	var cam: Camera3D = world.player.get_node("Head/Camera3D") as Camera3D
	if cam == null:
		_fail("no player camera")
		_finish()
		return

	var squad := SquadSystem.new()
	squad.world = world
	add_child(squad)
	await get_tree().physics_frame

	# 1. OPEN GROUND, 40m out, away from the hut. The easy case; if this misses, the
	#    method is broken outright rather than merely coarse.
	await _case(cam, squad, world, Vector3(stand.x + 40.0, terrain_y, stand.z),
		"open ground 40m out")
	# 2. THE BUILDING. Looking at the hut from 25m: what does the order verb return?
	await _case(cam, squad, world, Vector3(centre.x, roof_y, centre.z),
		"the hut, 25m out")
	# 3. OVER IT. Ground on the far side, past the building - the case a 5m march can
	#    step clean over.
	await _case(cam, squad, world, Vector3(centre.x - 20.0, terrain_y, centre.z),
		"ground 45m out, with the hut in the way")

	_finish()


## Aim the real camera at `look_at`, then compare the order verb's answer against a real
## physics ray down the same view direction.
func _case(cam: Camera3D, squad: SquadSystem, world: GameWorld, look_at: Vector3,
		name: String) -> void:
	cam.look_at(look_at, Vector3.UP)
	await get_tree().physics_frame

	var got: Vector3 = squad._aim_ground_point()
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 250.0, 1)
	q.exclude = [world.player.get_rid()]
	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_blind.append("%s: the camera ray hit nothing, so there is no ground truth" % name)
		print("  %-34s NO GROUND TRUTH (the ray left the world)" % name)
		return
	var truth: Vector3 = hit.position as Vector3
	if got == Vector3.ZERO:
		_fail("%s: the order verb returned ZERO - the squad would be sent to the origin"
			% name)
		return
	var flat: float = Vector2(got.x - truth.x, got.z - truth.z).length()
	var dy: float = got.y - truth.y
	print("  %-34s verb %s | camera ray %s | %.2fm across, %+.2fm high" % [
		name, str(Vector2(got.x, got.z).round()), str(Vector2(truth.x, truth.z).round()),
		flat, dy])
	if flat > TOL_M or absf(dy) > TOL_M:
		_fail("%s: the order lands %.2fm across and %+.2fm high off the point he is "
			% [name, flat, dy] + "actually looking at")


func _finish() -> void:
	for b in _blind:
		print("BLIND: %s" % b)
	if _failures == 0 and _blind.is_empty():
		print("=== PASS ===")
	elif _failures == 0:
		print("=== PASS, WITH %d BLIND LEG(S) ===" % _blind.size())
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
