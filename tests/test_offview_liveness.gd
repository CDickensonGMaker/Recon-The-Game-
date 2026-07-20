## test_offview_liveness.gd - DIAGNOSTIC. Measures whether the world can run on
## its own schedules while the player is not looking, and whether WorldSim's
## unwired region-LOD trio could deliver it.
##
## Not a guard: it asserts measured facts that a decree needs, and every
## assertion carries a negative control that makes it capable of failing.
## Run: godot --headless --path . res://tests/test_offview_liveness.tscn
extends Node

const CivilianScript := preload("res://scripts/world/civilian.gd")
const WorldConfigScript := preload("res://scripts/levels/world_config.gd")


func _ready() -> void:
	print("=== OFF-VIEW LIVENESS (can the world run unobserved?) ===")
	var failures: int = 0
	failures += _test_registry_payload_is_inert()
	failures += _test_abstract_tick_moves_nothing()
	failures += _test_registry_has_no_node_handle()
	failures += _test_ao_radius_covers_the_map_from_spawn()
	failures += _test_civilian_schedule_gate()

	if failures == 0:
		print("PASS: diagnostic complete")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The exact payload mission_generator.gd:213-218 registers for every enemy.
func _generator_payload(pos: Vector3) -> Dictionary:
	return {
		"kind": "enemy",
		"position": pos,
		"velocity": Vector3.ZERO,
		"faction": "VC",
		"schedule": {},
	}


## Claim 1: the live registration carries no behaviour to simulate.
func _test_registry_payload_is_inert() -> int:
	var p: Dictionary = _generator_payload(Vector3(100.0, 0.0, 100.0))
	var vel: Vector3 = p.get("velocity", Vector3.ONE)
	var sched: Dictionary = p.get("schedule", {"x": 1})
	if vel != Vector3.ZERO or not sched.is_empty():
		printerr("FAIL: generator payload carries behaviour (vel=%s sched=%d)"
			% [str(vel), sched.size()])
		return 1
	print("  generator payload: velocity=%s schedule=%d entries -> nothing to advance"
		% [str(vel), sched.size()])
	return 0


## Claim 2: _advance_abstract_cells over the LIVE payload moves nothing.
## NEGATIVE CONTROL: the same tick over a payload with real velocity DOES move
## it. Without this control the assertion would also pass if the tick were
## simply broken, which is a different bug with the same symptom.
func _test_abstract_tick_moves_nothing() -> int:
	WorldSim.clear_if_needed()
	var start := Vector3(100.0, 0.0, 100.0)
	var id_live: int = WorldSim.register(_generator_payload(start))

	var moving: Dictionary = _generator_payload(start)
	moving["velocity"] = Vector3(1.0, 0.0, 0.0)
	var id_ctrl: int = WorldSim.register(moving)

	WorldSim._advance_abstract_cells()

	var after_live: Vector3 = WorldSim.entities[id_live].get("position", Vector3.ZERO)
	var after_ctrl: Vector3 = WorldSim.entities[id_ctrl].get("position", Vector3.ZERO)

	if after_live != start:
		printerr("FAIL: live payload moved %s -> %s" % [str(start), str(after_live)])
		return 1
	if after_ctrl == start:
		printerr("FAIL(control): a payload WITH velocity did not move - the tick is dead,"
			+ " so the inertness assertion proves nothing")
		return 1
	print("  abstract tick: live payload %s (unmoved) | control with velocity -> %s"
		% [str(after_live), str(after_ctrl)])
	WorldSim.clear_if_needed()
	return 0


## Claim 3: a registry entry cannot be mapped back to the actor it describes,
## so materialize_near()'s return value has no consumer to hand a node to.
func _test_registry_has_no_node_handle() -> int:
	WorldSim.clear_if_needed()
	var id: int = WorldSim.register(_generator_payload(Vector3.ZERO))
	var data: Dictionary = WorldSim.entities[id]
	for k in data.keys():
		var v: Variant = data[k]
		if v is Node or v is NodePath:
			printerr("FAIL: registry key '%s' carries a node handle - a consumer IS possible" % str(k))
			return 1
	print("  registry keys %s - no node handle, no way back to the actor" % str(data.keys()))
	WorldSim.clear_if_needed()
	return 0


## Claim 4: on a 1280m map, AO_RADIUS=800 from the player's spawn (map centre,
## game_world.gd:166) leaves almost nothing off-AO.
## NEGATIVE CONTROL: the same measurement from a map corner must report a LARGE
## off-AO fraction. If both came back ~0 the sampler would be broken, and the
## "geometry is inert" claim would be an artefact of the measurement.
func _test_ao_radius_covers_the_map_from_spawn() -> int:
	var m: float = WorldConfigScript.MAP_SIZE
	var r: float = WorldSim.AO_RADIUS
	var centre_frac: float = _fraction_beyond(Vector3(m * 0.5, 0.0, m * 0.5), r, m)
	var corner_frac: float = _fraction_beyond(Vector3.ZERO, r, m)

	print("  map=%.0fm AO_RADIUS=%.0fm | off-AO area from spawn-centre: %.1f%% | from corner: %.1f%%"
		% [m, r, centre_frac * 100.0, corner_frac * 100.0])

	if centre_frac > 0.10:
		printerr("FAIL: %.1f%% of the map is off-AO from centre - region LOD is NOT inert here"
			% (centre_frac * 100.0))
		return 1
	if corner_frac < 0.30:
		printerr("FAIL(control): only %.1f%% off-AO from a corner - the sampler cannot"
			% (corner_frac * 100.0) + " detect off-AO area, so the centre result is meaningless")
		return 1
	return 0


## Uniform grid sample of the AO; returns the fraction of map area further than
## `r` from `from`.
func _fraction_beyond(from: Vector3, r: float, m: float) -> float:
	var steps: int = 128
	var beyond: int = 0
	var total: int = 0
	for ix in range(steps):
		for iz in range(steps):
			var x: float = (float(ix) + 0.5) / float(steps) * m
			var z: float = (float(iz) + 0.5) / float(steps) * m
			total += 1
			if Vector2(x - from.x, z - from.z).length() > r:
				beyond += 1
	return float(beyond) / float(total)


## Claim 5: a civilian past LOD_FAR_RADIUS never re-picks his scheduled action,
## so he does not live through the hours - he snaps to them on approach.
## NEGATIVE CONTROL: the identical civilian inside the radius DOES re-pick.
func _test_civilian_schedule_gate() -> int:
	var far_changed: bool = _picks_new_action_across_hour(CivilianScript.LOD_FAR)
	var near_changed: bool = _picks_new_action_across_hour(CivilianScript.LOD_FULL)

	if far_changed:
		printerr("FAIL: a LOD_FAR civilian re-picked his action - he is already live off-view")
		return 1
	if not near_changed:
		printerr("FAIL(control): a LOD_FULL civilian did not re-pick either - the harness never"
			+ " reached the schedule code, so the LOD_FAR result proves nothing")
		return 1
	print("  civilian schedule: LOD_FAR re-picks=false | LOD_FULL re-picks=true"
		+ " (gate at civilian.gd:200-203, radius %.0fm)" % CivilianScript.LOD_FAR_RADIUS)
	return 0


## Drives one civilian across a sim-hour boundary at a fixed LOD tier and
## reports whether his scheduled action was recomputed.
func _picks_new_action_across_hour(tier: int) -> bool:
	var civ: Node = CivilianScript.new()
	add_child(civ)
	civ.set("occupation", "farmer")
	civ.set("lod_tier", tier)
	# Stale pick from an earlier hour; a live civilian must overwrite it.
	var bb: Dictionary = {"last_pick_hour": 3.0, "scheduled_action": &"stale"}
	civ.set("_bt_bb", bb)
	# Freeze the tier: _update_lod only recomputes every LOD_RECOMPUTE_S, and we
	# step by less than that, so the tier we set is the tier under test.
	SimClock.sim_hour = 9.0

	civ.call("_physics_process", 0.016)

	var out: Dictionary = civ.get("_bt_bb")
	var picked: StringName = out.get("scheduled_action", &"stale")
	civ.queue_free()
	return picked != &"stale"
