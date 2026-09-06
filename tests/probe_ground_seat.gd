## probe_ground_seat.gd - items 4 and 6. Nothing in this repo has ever MEASURED
## where a seated body lands. This does: it stands a stilt house on flat ground -
## a building with a floor ABOVE the terrain and a roof above that - and drives
## the real call sites at its centre.
##
##   terrain_y  < floor_y  < surface_y
##   (bare)       (inside)   (roof)
##
## A man seated on terrain_y is UNDER the house. A man seated on surface_y is ON
## THE ROOF. Both were shipping.
## Run: godot --headless --path . res://tests/probe_ground_seat.tscn -- --test-save
extends Node

const SEED_VAL: int = 4242
const HUT_PATH := "res://assets/world/building models/structures/village/nha_san_01.glb"
const TOL_M: float = 0.35

var _failures: int = 0
## Legs that ran but could not tell a fixed seat from a broken one. Reported, never
## swallowed: a leg that cannot fail is not a pass.
var _blind: Array[String] = []
var _terrain_y: float = 0.0
var _floor_y: float = 0.0
var _roof_y: float = 0.0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _run() -> void:
	print("=== GROUND SEAT PROBE (items 4 + 6) ===")
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		_fail("world timeout")
		_finish(world)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
		world.vegetation_manager, world)
	var centre: Vector3 = planner.find_site(rng, 20.0)
	if centre == Vector3.ZERO:
		_fail("no flat site found")
		_finish(world)
		return
	planner.clear_and_flatten(centre, 30.0)
	planner.place_structure(HUT_PATH, centre, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_terrain_y = world.terrain_manager.get_height_at(centre)
	centre = Vector3(centre.x, _terrain_y, centre.z)
	_floor_y = world.floor_y(centre)
	_roof_y = world.surface_y(centre)
	print("[PROBE] at %s  terrain=%.2f  floor_y=%.2f  surface_y=%.2f" % [
		str(Vector2(centre.x, centre.z)), _terrain_y, _floor_y, _roof_y])

	# THE INSTRUMENT CHECK. Without a real gap between the three, this probe
	# cannot tell a fixed seat from a broken one and must not report PASS.
	if _roof_y - _floor_y < 1.0:
		_fail("no roof over the test point (surface_y - floor_y = %.2fm) - the probe is blind"
			% (_roof_y - _floor_y))
		_finish(world)
		return

	await _case_litter_team(world, centre)
	await _case_marching_cell(world, centre)
	_case_air_traffic(world, centre)
	await _case_village_civilians(world, planner, centre, rng)
	_finish(world)


## litter_team.gd:172 - the bearers walk covered ground carrying a casualty.
func _case_litter_team(world: GameWorld, centre: Vector3) -> void:
	if not LitterTeam.available():
		print("[SKIP] litter prop not exported - LitterTeam case not run")
		return
	var men: Array[Civilian] = []
	for i in range(3):
		men.append(Civilian.spawn(world, centre + Vector3(float(i) * 2.0, 0, 0), null, false))
	await get_tree().process_frame
	var team := LitterTeam.new()
	if not team.setup(world, men, centre, centre + Vector3(0, 0, 10.0)):
		print("[SKIP] LitterTeam.setup refused")
		return
	await get_tree().process_frame
	team._pos = centre
	team._dir = Vector3.FORWARD
	team._write_bodies()
	var y: float = men[0].global_position.y
	print("[PROBE] litter front bearer y=%.2f (floor %.2f, roof %.2f)" % [y, _floor_y, _roof_y])
	if absf(y - _floor_y) > TOL_M:
		_fail("litter bearer seated %.2f, not on the floor %.2f (roof is %.2f)"
			% [y, _floor_y, _roof_y])
	team.queue_free()
	for m in men:
		m.queue_free()
	await get_tree().process_frame


## marching_cell.gd:242 - the cell that marches onto the firebase.
func _case_marching_cell(world: GameWorld, centre: Vector3) -> void:
	var fd := FieldDirector.new()
	fd.world = world
	add_child(fd)
	var cell := MarchingCell.new()
	add_child(cell)
	cell.director = fd
	cell.global_position = centre
	cell._seat_on_terrain()
	var y: float = cell.global_position.y
	print("[PROBE] marching cell y=%.2f (floor %.2f, roof %.2f)" % [y, _floor_y, _roof_y])
	if absf(y - _floor_y) > TOL_M:
		_fail("marching cell seated %.2f, not on the floor %.2f (roof is %.2f)"
			% [y, _floor_y, _roof_y])
	cell.queue_free()
	fd.queue_free()
	await get_tree().process_frame


## air_traffic.gd:520 - the OPPOSITE sign. Every caller adds a cruise altitude to
## this, so it must clear the roof, not the bare terrain under it.
func _case_air_traffic(world: GameWorld, centre: Vector3) -> void:
	var at := AirTraffic.new()
	world.add_child(at)
	var y: float = at._ground_at(centre)
	print("[PROBE] air _ground_at=%.2f (terrain %.2f, roof %.2f)" % [y, _terrain_y, _roof_y])
	if absf(y - _roof_y) > TOL_M:
		_fail("air clearance datum %.2f is not the roof %.2f - ships fly through the compound"
			% [y, _roof_y])
	at.queue_free()


## mission_generator.gd:1148 - the real village build, not a re-typed expression.
##
## RE-SITED 2026-09-06. This leg used to report BLIND: on the village site it happened to
## pick, floor_y and get_height_at agreed at every villager (spread 0.00m), so the seat
## change was a no-op there and the leg could not fail. A leg that cannot fail proves
## nothing, and item 6 was being carried as "parity done, unproven".
##
## The bunker work (tools/probe_bunker_entry) named the world condition that bites: a
## COLLIDER DECK standing above bare terrain. So this lays one where the villagers
## actually land, rather than hoping the layout walks a man under a stilt house, and the
## deck's height is the probe's OWN - external ground truth, not another height helper.
##
## Two things are asserted, and they are the two that are unambiguous:
##   BURIED - a villager below the bare terrain is wrong on any reading.
##   ON THE ROOF - the defect item 6 actually reports.
## The deck divergence is MEASURED AND REPORTED, not failed on: whether a man planned at
## terrain height belongs on a deck 1.2m over him or underneath it is a design question
## nobody has ruled, and this probe will not rule it by assertion.
const DECK_H: float = 1.2
const DECK_R: float = 34.0
const DECK_T: float = 0.2
## mission_generator.gd:1150 lifts every villager this far off the floor it picks.
const SEAT_LIFT: float = 0.5


func _case_village_civilians(world: GameWorld, planner: SitePlanner,
		centre: Vector3, rng: RandomNumberGenerator) -> void:
	var terrain_here: float = world.terrain_manager.get_height_at(centre)
	var deck_top: float = terrain_here + DECK_H
	var deck := StaticBody3D.new()
	deck.collision_layer = 1
	deck.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DECK_R * 2.0, DECK_T, DECK_R * 2.0)
	cs.shape = box
	deck.add_child(cs)
	world.add_child(deck)
	deck.global_position = Vector3(centre.x, deck_top - DECK_T * 0.5, centre.z)
	await get_tree().physics_frame

	var site: Dictionary = {"center": centre, "kind": "village"}
	var built: Dictionary = MissionGenerator._build_village_site(
		world, null, planner, site, rng, "day")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var civs: Array[Node] = world.get_tree().get_nodes_in_group("civilians")
	if civs.is_empty():
		_fail("village build seated no civilians - nothing to measure (built=%s)" % str(built.keys()))
		deck.queue_free()
		return
	var over_deck: int = 0
	var on_deck: int = 0
	var buried: int = 0
	var on_roof: int = 0
	var deepest: float = 0.0
	for n in civs:
		var c := n as Node3D
		if c == null:
			continue
		var p: Vector3 = c.global_position
		var ground: float = world.terrain_manager.get_height_at(p)
		if p.y < ground - TOL_M:
			buried += 1
			deepest = maxf(deepest, ground - p.y)
		# The reported defect: standing on the lid of something the WORLD built.
		# The probe's own deck is excluded - a probe that fails on its own scaffolding
		# is measuring itself. First run of this leg flagged a man standing on the deck
		# as a roof, which he was not: the deck is a floor.
		var roof: float = _world_surface_excluding(world, p, deck)
		if roof - ground > 1.0 and p.y >= roof - TOL_M:
			on_roof += 1
		if absf(p.x - centre.x) <= DECK_R - 1.0 and absf(p.z - centre.z) <= DECK_R - 1.0:
			over_deck += 1
			if p.y >= deck_top - TOL_M:
				on_deck += 1
	print("[PROBE] %d village civilians: %d under a deck %.2fm over bare terrain, %d of those seated ON it"
		% [civs.size(), over_deck, DECK_H, on_deck])
	print("[PROBE] %d buried under the terrain (deepest %.2fm), %d standing on a roof"
		% [buried, deepest, on_roof])
	if buried > 0:
		_fail("%d villagers seated %.2fm under bare terrain" % [buried, deepest])
	if on_roof > 0:
		_fail("%d villagers seated on the roof of something (item 6's own defect)" % on_roof)
	# NOT a failure, and NOT blind: a measured statement about what the wave-1 parity
	# change can and cannot do. floor_y probes DOWN from cpos + 0.4m
	# (game_world.gd floor_y), and mission_generator.gd:1145 builds cpos at the site's
	# own height - so it is structurally incapable of lifting a villager onto a deck
	# above him. It differs from get_height_at only for a collider within 0.4m of
	# terrain. That is the whole reach of the fix, and it is now on the record.
	if over_deck > 0 and on_deck < over_deck:
		print("[FINDING] item 6: %d of %d villagers over a %.2fm deck were NOT seated on it."
			% [over_deck - on_deck, over_deck, DECK_H]
			+ " floor_y cannot reach a floor above cpos + 0.4m, so the parity change"
			+ " corrects at most 0.4m. Unruled: whether a man planned at terrain height"
			+ " belongs on the deck or under it.")
	deck.queue_free()


## surface_y with one body taken out of the world: the highest thing under this
## point that the probe did not build itself.
func _world_surface_excluding(world: GameWorld, at: Vector3, skip: StaticBody3D) -> float:
	var ground: float = world.terrain_manager.get_height_at(at)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	if space == null:
		return ground
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, ground + 18.0, at.z), Vector3(at.x, ground - 2.0, at.z), 1)
	if skip != null and is_instance_valid(skip):
		q.exclude = [skip.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return ground
	return maxf(ground, (hit.position as Vector3).y)


func _finish(world: Node = null) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	for b in _blind:
		print("[BLIND] %s" % b)
	var verdict: String = "FAIL (%d)" % _failures if _failures > 0 else 		("PASS (%d blind leg(s))" % _blind.size() if not _blind.is_empty() else "PASS")
	print("=== %s ===" % verdict)
	get_tree().quit(0 if _failures == 0 else 1)
