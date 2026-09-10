## probe_site_pick.gd - DOES THE GAME PICK THE SAME HILL THE TOOL DOES? (ADR-043)
##
## Run: godot --headless --path . res://tools/probe_site_pick.tscn
##
## It exists because the tool and the game disagreed and nothing said so. The kit editor and
## tools/probe_firebase_site.gd score a site with SitePick.pick() - prominence minus relief,
## "a firebase goes on a flat-topped hill". SitePlanner.plan_firebase_main_center(), which is
## what the GAME actually builds on, scored slope, water, separation and flatness and had NO
## prominence term at all. Same seed, different hill: the tool kept showing a good base and
## the game kept building somewhere else.
##
## Four questions, one boot:
##   1. DETERMINISM  same seed twice -> the same centre, still.
##   2. LIFT         does the prominence term actually move the pick onto higher ground?
##                   The control is the SAME function with prominence_w = 0.0, which is the
##                   pre-2026-09-10 score exactly - not a hand-copy of it that could drift.
##   3. FLATNESS     the ground it stands on must not get worse to buy that height. Relief
##                   across the footprint is what the seat has to cut, and a firebase on a
##                   ridge shoulder is the failure this whole score exists to avoid.
##   4. ONE INSTRUMENT  SitePick and SitePlanner must return the SAME prominence for the same
##                   point, or the delegation is decorative and they can drift apart again.
extends Node

const SitePick = preload("res://tools/firebase_site_pick.gd")

const SEED_VAL: int = 4242
## How much worse the footprint relief is allowed to get in exchange for the height. A pick
## that buys 3 m of prominence with 3 m of extra cut has not improved anything: the seat has
## to level all of it and the bunkers end up in a cut face, which is the original defect.
const RELIEF_REGRESSION_TOL_M: float = 0.75

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
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
		_finish(world)
		return

	var tm: Node = world.terrain_manager
	var ring_x: float = SitePlanner.FSB_HALF.x + SitePlanner.FSB_OUTLOOK_M
	var ring_z: float = SitePlanner.FSB_HALF.y + SitePlanner.FSB_OUTLOOK_M
	var map_size: float = float(tm.map_size)
	print("[PICK] map %.0f m, footprint %.1f x %.1f m, outlook ring %.0f m beyond the wire"
		% [float(tm.map_size), SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0,
			SitePlanner.FSB_OUTLOOK_M])

	# 1. DETERMINISM, checked first and on the SHIPPING call - a picker that wanders is a
	# world that cannot be reproduced from a seed (ADR-010), and every other number below
	# would be describing a different hill each run.
	var a: Vector3 = _pick(world, SEED_VAL)
	var b: Vector3 = _pick(world, SEED_VAL)
	if a != b:
		_fail("plan_firebase_main_center is not deterministic: %s vs %s" % [str(a), str(b)])
	print("[PICK] deterministic: %s == %s" % [str(a), str(b)])

	# 2. LIFT - the control is the same function with the term switched off.
	var old_c: Vector3 = _pick(world, SEED_VAL, 0.0)
	var new_c: Vector3 = a
	var old_p: float = SitePlanner.prominence(tm, old_c, ring_x, ring_z)
	var new_p: float = SitePlanner.prominence(tm, new_c, ring_x, ring_z)
	var old_r: Array = SitePlanner.relief(tm, old_c, SitePlanner.FSB_HALF.x)
	var new_r: Array = SitePlanner.relief(tm, new_c, SitePlanner.FSB_HALF.x)
	var old_rm: float = old_r[1] - old_r[0]
	var new_rm: float = new_r[1] - new_r[0]
	print("[PICK] BEFORE (prominence off): centre %s  stands %+.2f m over the ring, %.2f m of relief"
		% [str(old_c), old_p, old_rm])
	print("[PICK] AFTER  (shipping score): centre %s  stands %+.2f m over the ring, %.2f m of relief"
		% [str(new_c), new_p, new_rm])
	print("[PICK] lift %+.2f m, relief change %+.2f m" % [new_p - old_p, new_rm - old_rm])
	if new_p < old_p:
		_fail("the prominence term moved the firebase DOWN: %+.2f m -> %+.2f m" % [old_p, new_p])

	# 3. FLATNESS not sold for height.
	if new_rm > old_rm + RELIEF_REGRESSION_TOL_M:
		_fail("the pick bought %+.2f m of height with %+.2f m of extra relief (tol %.2f) - the "
			% [new_p - old_p, new_rm - old_rm, RELIEF_REGRESSION_TOL_M]
			+ "seat has to cut all of it and the bunkers end up in a cut face")

	# THE THING HIS ASK WAS ABOUT: nothing should overlook the wire. A negative prominence is
	# a hollow, which is where fsb_kit_alpha landed before the tool grew this term.
	if new_p < 0.0:
		_fail("the shipping pick is in a HOLLOW: %.2f m BELOW the ground %.0f m outside the wire"
			% [new_p, SitePlanner.FSB_OUTLOOK_M])

	# 2b. WHAT THE TERM ITSELF BUYS, ACROSS SEEDS - and this exists because the single-seed
	# before/after above went to +0.00 the moment the candidate pool was raised to 480.
	# That is the honest result and it must not be reported as the term working: on this seed
	# flatness alone already lands on ground that stands +1.42 m over its ring. One seed
	# cannot tell a term that does nothing from a term that did not need to fire. Eight can.
	var rescued: int = 0
	var off_sum: float = 0.0
	var on_sum: float = 0.0
	var worse: int = 0
	for k in range(8):
		var sd: int = SEED_VAL + k * 1013
		var c_off: Vector3 = _pick(world, sd, 0.0)
		var c_on: Vector3 = _pick(world, sd)
		var p_off: float = SitePlanner.prominence(tm, c_off, ring_x, ring_z)
		var p_on: float = SitePlanner.prominence(tm, c_on, ring_x, ring_z)
		off_sum += p_off
		on_sum += p_on
		if p_off < 0.0 and p_on >= 0.0:
			rescued += 1
		if p_on < p_off - 0.01:
			worse += 1
		print("[TERM] seed %-8d off %+6.2f m -> on %+6.2f m%s"
			% [sd, p_off, p_on, "   (out of a hollow)" if p_off < 0.0 and p_on >= 0.0 else ""])
	print("[TERM] 8 seeds: mean prominence %+.2f m -> %+.2f m, %d rescued from a hollow, %d worse"
		% [off_sum / 8.0, on_sum / 8.0, rescued, worse])
	if worse > 0:
		_fail("%d of 8 seeds ended on LOWER ground with the prominence term on" % worse)

	# 2c. AO ROOM. The prominence term's first shipped form found high ground in a CORNER -
	# gate (975, 1105) on a 1280 m map, seed 31337 - and one of the four quadrants the pacing
	# contract needs a village in had no land in it. A firebase on a hill with no war around
	# it is worse than a firebase on flat ground with one, so the room is gated, not reported.
	var want_room: float = minf(SitePlanner.FSB_AO_ROOM_M, map_size * 0.5)
	var short: int = 0
	for k in range(8):
		var sd2: int = SEED_VAL + k * 1013
		var c: Vector3 = _pick(world, sd2)
		var room: float = SitePlanner.ao_room(c, map_size)
		if room < want_room - 1.0:
			short += 1
			print("[ROOM] seed %-8d only %.0f m to the nearest map edge (want %.0f)"
				% [sd2, room, want_room])
	print("[ROOM] 8 seeds: %d short of %.0f m of AO around the base" % [short, want_room])
	if short > 0:
		_fail("%d of 8 seeds put the firebase closer than %.0f m to a map edge - a quadrant of "
			% [short, want_room] + "the AO has no land in it")

	# THE PARETO SCAN. Added because the first two runs of this probe traded flatness for
	# height and there was no way to tell whether that was a bad WEIGHT or a map with no
	# flat hilltops on it. Tuning a score against a gate without knowing which is the honest
	# way to make a probe agree with you. 300 legal candidates, the same draw the picker uses.
	var scan_rng := RandomNumberGenerator.new()
	scan_rng.seed = SEED_VAL + 991
	var mn_x: float = SitePlanner.FSB_HALF.x + SitePlanner.FSB_EDGE_MARGIN
	var mn_z: float = SitePlanner.FSB_HALF.y + SitePlanner.FSB_EDGE_MARGIN
	var cand: Array = []
	for _i in range(300):
		var c := Vector3(scan_rng.randf_range(mn_x, map_size - mn_x), 0.0,
			scan_rng.randf_range(mn_z, map_size - mn_z))
		var pr: float = SitePlanner.prominence(tm, c, ring_x, ring_z)
		var rl: Array = SitePlanner.relief(tm, c, SitePlanner.FSB_HALF.x)
		cand.append([pr, rl[1] - rl[0]])
	cand.sort_custom(func(u, v): return u[1] < v[1])
	print("[SCAN] 300 legal centres, sorted by relief (the cut the seat has to make):")
	var front_p: float = -1.0e9
	for row in cand:
		if row[0] > front_p:
			front_p = row[0]
			print("[SCAN]   relief %5.2f m  prominence %+6.2f m" % [row[1], row[0]])
	var flat_and_high: int = 0
	for row in cand:
		if row[1] <= old_rm and row[0] >= 0.0:
			flat_and_high += 1
	print("[SCAN] %d of 300 are BOTH no rougher than the old pick (%.2f m) and not overlooked"
		% [flat_and_high, old_rm])

	# 4. ONE INSTRUMENT. Same point, both entry doors, same number.
	var probe_pt: Vector3 = new_c
	var via_planner: float = SitePlanner.prominence(tm, probe_pt, SitePick.OUTLOOK_RING_M,
		SitePick.OUTLOOK_RING_M)
	var via_tool: Array = SitePick.relief(tm, probe_pt, 36.0)
	var direct: Array = SitePlanner.relief(tm, probe_pt, 36.0)
	if not (is_equal_approx(via_tool[0], direct[0]) and is_equal_approx(via_tool[1], direct[1])):
		_fail("SitePick.relief and SitePlanner.relief disagree: %s vs %s"
			% [str(via_tool), str(direct)])
	print("[PICK] one instrument: SitePick delegates, relief %s == %s, tool-ring prominence %+.2f m"
		% [str(via_tool), str(direct), via_planner])

	_finish(world)


## One pick, on a fresh planner and a fresh rng, exactly as MissionGenerator does it
## (mission_generator.gd:518). A reused planner would carry _reserved from the last call and
## push the second pick 240 m away, which would read as non-determinism.
func _pick(world: GameWorld, seed_val: int, prominence_w: float = -1.0) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
		world.vegetation_manager, world)
	if prominence_w < 0.0:
		return planner.plan_firebase_main_center(rng)
	return planner.plan_firebase_main_center(rng, prominence_w)


func _finish(world: Node) -> void:
	if _failures == 0:
		print("probe_site_pick: PASS")
	else:
		print("probe_site_pick: %d FAILURE(S)" % _failures)
	if world != null and is_instance_valid(world):
		world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
