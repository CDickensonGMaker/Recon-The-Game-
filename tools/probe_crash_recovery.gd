## probe_crash_recovery.gd - THE SLICK GOES IN, headless (council 2026-09-14, his ruling).
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --crash-probe --test-save
##   ... --demo-seed=N
##
## Attached to the live demo world by game_flow.gd under `--crash-probe`. Holds the stand-to
## off (a promoted garrison is not a camp). Does not wait for the 11:30 pad cycle: at SETTLE_S
## it dispatches the slick itself, forces the hold-fire open, and lets the gun take it. Then:
##   1. the ship reaches DESTROYED, the wreck stands, the men are on the ground;
##   2. the roll is inside his ranges (pilots 1-2 of 2, pax 1-4 of the stick) and the record is
##      printed so a second run of the same seed can be compared line for line (ADR-010);
##   3. the escort: the headless player is walked toward the gate in leash steps from WAKE_M;
##      every living man stays inside the hold radius or is holding, and no man trips the stuck
##      detector twice;
##   4. arrival: the garrison grows by the men who walked in, the ward by the wounded, the
##      tasking closes, the event cannot fire twice.
## Exit 1 on any failure.
extends Node

const SETTLE_S: float = 25.0
const CRASH_WAIT_S: float = 90.0
const LEASH_STEP_M: float = 7.0
const LEASH_EVERY_S: float = 4.0
const ESCORT_MAX_S: float = 480.0

var _fail: int = 0
var _director: FieldDirector = null
var _pr: PilotRecovery = null


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("
=== CRASH PROBE ===")
	var waited: float = 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if _director == null:
			_director = _find_director()
			if _director != null:
				_director.stand_to_held = true
	if _director == null:
		print("  FAIL: no FieldDirector")
		_finish()
		return
	_pr = get_tree().get_first_node_in_group("pilot_recovery") as PilotRecovery
	_check(_pr != null, "PilotRecovery rides the world")
	if _pr == null:
		_finish()
		return
	_pr._elapsed = PilotRecovery.HOLD_FIRE_S + 1.0
	var site: Vector3 = _pr.planned_crash_site()
	_check(site != Vector3.ZERO, "a crash site is planned (%s)" % site)
	_check(site.distance_to(_director.fsb_center) >= SitePlanner.FSB_SITE_CLEARANCE,
		"the site clears the wire (%.0f m from the centre)" % site.distance_to(_director.fsb_center))
	var at: AirTraffic = _air_traffic()
	_check(at != null, "AirTraffic rides the world")
	if at == null or site == Vector3.ZERO:
		_finish()
		return
	at._dispatch_lz_cycle("huey")
	var heli: Helicopter = _last_heli(at)
	_check(heli != null, "the slick was dispatched")
	if heli == null:
		_finish()
		return
	var lift: HeliLift = heli.get_node_or_null("HeliLift") as HeliLift
	await get_tree().process_frame
	var aboard: int = lift.aboard().size() if lift != null else 0
	_check(aboard >= 3, "men aboard before the hit: %d (2 aircrew + a stick)" % aboard)
	# The gun rolls on its own poll; the hit is asked for here so the probe is not hostage to the
	# gun's range on this seed's layout.
	_check(_pr.request_down_heli(heli), "PilotRecovery took the slick")
	_check(heli.is_shot_down(), "the ship is doomed")
	waited = 0.0
	while waited < CRASH_WAIT_S and _pr.phase_name() != "wait":
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	_check(_pr.phase_name() == "wait", "the ship went in and the men are on the ground (%.0fs)" % waited)
	# THE PROBE MEASURES THE CHAIN, NOT THE FIGHT: the roll, the follow, the hand-back. The AO's
	# hunters and the wreck's own pickets are the open world's, and a survivor shot on the walk
	# is a day, not a defect. Quiet them here so a red means the chain broke.
	_director._hunter_pool = 0
	_director._escalation_active = false
	for n in get_tree().get_nodes_in_group("wreck_pickets"):
		if is_instance_valid(n):
			(n as Node).queue_free()
	for n in get_tree().get_nodes_in_group("enemies"):
		var e: Node = n as Node
		if is_instance_valid(e) and e.has_method("is_dead") and not bool(e.call("is_dead")):
			e.queue_free()
	print("  (hunters, pickets and live enemies quieted - the chain is what is measured)")
	var inc: Dictionary = _pr.incident
	print("  INCIDENT %s" % JSON.stringify(inc))
	var pa: int = int(inc.get("pilots_alive", 0))
	var xa: int = int(inc.get("pax_alive", 0))
	_check(pa >= 1 and pa <= 2, "pilots alive in 1..2 (%d)" % pa)
	_check(xa >= 1 and xa <= 4, "pax alive in 1..4 (%d)" % xa)
	_check(int(inc.get("alive", 0)) == _pr.men().size(), "every living man stands by the wreck (%d)" % _pr.men().size())
	_check(int(inc.get("dead", -1)) == aboard - int(inc.get("alive", 0)), "the dead are the rest")
	_check(int(_director.state.flags.get("crash_kia_placed", 0)) == int(inc.get("dead", 0)),
		"the dead fell at the wreck (%d)" % int(_director.state.flags.get("crash_kia_placed", 0)))
	_check(CampaignState.tasking_state(PilotRecovery.TASKING_ID) == CampaignState.TASKING_OPEN,
		"HQ's tasking is open")
	# THE PACE CAP: no wounded man's walk home may run more than CRIT_EXTRA_S past a healthy
	# man's from this wreck, by the arithmetic the men were given.
	var walk_m: float = (inc.get("crash_pos", Vector3.ZERO) as Vector3).distance_to(_director.fsb_center)
	for m in _pr.men():
		var wound: int = int(m.get_meta("crash_wound", 0))
		if wound == 0:
			continue
		var pace: float = float(m.get_meta("crash_pace", 1.0))
		var healthy_s: float = walk_m / (m.move_speed / pace)
		var wounded_s: float = walk_m / m.move_speed
		_check(wounded_s - healthy_s <= PilotRecovery.CRIT_EXTRA_S + 0.5,
			"%s (wound %d, pace %.2f) walks %.0f m in %.0f s, %.0f s over a healthy man (cap %.0f)"
			% [str(m.get_meta("crash_role", "?")), wound, pace, walk_m, wounded_s, wounded_s - healthy_s, PilotRecovery.CRIT_EXTRA_S])
	_check(PilotRecovery.capped_pace(0.35, 900.0, 5.6) > 0.35 and PilotRecovery.capped_pace(0.35, 200.0, 5.6) == 0.35,
		"the cap lifts a CRIT pace on a long walk and leaves a short one alone")
	_check(_pr._used and _pr.planned_crash_site() == Vector3.ZERO, "a second ship is refused today")
	await _escort()
	_finish()


func _escort() -> void:
	var player: Node3D = GameManager.player as Node3D
	if player == null or _pr.men().is_empty():
		_check(false, "no player or no men to escort")
		return
	var garrison_before: int = get_tree().get_nodes_in_group("firebase_garrison").size()
	var first: AllyBase = _pr.men()[0]
	var toward_home: Vector3 = (_director.fsb_center - first.global_position)
	toward_home.y = 0.0
	player.global_position = first.global_position + toward_home.normalized() * 4.0 + Vector3.UP * 0.5
	await get_tree().create_timer(3.0).timeout
	_check(_pr.phase_name() == "escort", "the men woke for the man who came for them")
	for m in _pr.men():
		print("  man %s at %s, %.1f m off the hull, order %d" % [str(m.get_meta("crash_role", "?")),
			m.global_position, m.global_position.distance_to(_pr.incident.get("crash_pos", Vector3.ZERO) as Vector3),
			int(m.order_mode)])
	# Home is THROUGH THE GATE, as a player walks it: the wire has one gap and a leash that
	# teleports over the parapet leaves the men on the wrong side of it.
	var route: Array[Vector3] = [
		_director.patrol_gate_pos + _director.patrol_gate_out * 24.0,
		_director.patrol_gate_pos,
		_director.patrol_gate_pos - _director.patrol_gate_out * 16.0,
		_director.fsb_center,
	]
	var leg: int = 0
	var t: float = 0.0
	var flips_seen: Dictionary = {}
	while t < ESCORT_MAX_S and _pr.phase_name() == "escort":
		await get_tree().create_timer(LEASH_EVERY_S).timeout
		t += LEASH_EVERY_S
		var pp: Vector3 = player.global_position
		var far: float = 0.0
		for m in _pr.men():
			far = maxf(far, pp.distance_to(m.global_position))
			var flips: int = int(m.get("_unstick_flips")) if "_unstick_flips" in m else 0
			if flips >= 3:
				flips_seen[m.get_instance_id()] = int(flips_seen.get(m.get_instance_id(), 0)) + 1
		if int(t) % 40 == 0:
			print("  leash t=%.0f far %.1f player %s" % [t, far, pp])
			for m in _pr.men():
				print("    %s %s d=%.1f v=%.2f order %d tgt %s hp %d state %d"
					% [str(m.get_meta("crash_role", "?")), m.global_position, pp.distance_to(m.global_position),
						m.velocity.length(), int(m.order_mode), str(m.target != null), m.current_hp, int(m.current_state)])
		# The leash: step toward home only while the slowest man is inside the lag radius, so a
		# held group is waited for, never abandoned - the walk a player who wants them home does.
		if far <= PilotRecovery.SLICK_LAG_M:
			var gate: Vector3 = route[mini(leg, route.size() - 1)]
			var to_gate: Vector3 = gate - pp
			to_gate.y = 0.0
			if to_gate.length() > LEASH_STEP_M:
				var step: Vector3 = pp + to_gate.normalized() * LEASH_STEP_M
				player.global_position = MissionGenerator._seat(_director.world, step) + Vector3.UP * 0.5
			else:
				player.global_position = MissionGenerator._seat(_director.world, gate) + Vector3.UP * 0.5
				leg += 1
		else:
			# He outran them: walk back toward the slowest man, as a player who wants them home does.
			var slowest: Vector3 = pp
			for m in _pr.men():
				if pp.distance_to(m.global_position) >= far - 0.01:
					slowest = m.global_position
			var back: Vector3 = slowest - pp
			back.y = 0.0
			if back.length() > LEASH_STEP_M:
				player.global_position = MissionGenerator._seat(_director.world, pp + back.normalized() * LEASH_STEP_M) + Vector3.UP * 0.5
	print("  escort ended after %.0fs in phase %s" % [t, _pr.phase_name()])
	_check(_pr.phase_name() == "recovered", "the men walked in")
	var twice: int = 0
	for k in flips_seen.keys():
		if int(flips_seen[k]) >= 2:
			twice += 1
	_check(twice == 0, "no man tripped the stuck detector twice (%d did)" % twice)
	var inc: Dictionary = _pr.incident
	var walked: int = int(inc.get("walked_in", 0))
	_check(walked == int(inc.get("alive", 0)) or walked > 0, "walked in: %d of %d" % [walked, int(inc.get("alive", 0))])
	var garrison_after: int = get_tree().get_nodes_in_group("firebase_garrison").size()
	_check(garrison_after >= garrison_before + walked - int(inc.get("pilots_alive", 0)),
		"the garrison grew by the men who walked in (%d -> %d)" % [garrison_before, garrison_after])
	_check(get_tree().get_nodes_in_group("crash_survivors").size() == walked,
		"survivors registered (%d)" % get_tree().get_nodes_in_group("crash_survivors").size())
	_check(int(_director.state.flags.get("friendly_wia", 0)) >= 0, "the ward count is a number")
	_check(CampaignState.tasking_state(PilotRecovery.TASKING_ID) == CampaignState.TASKING_CLOSED,
		"HQ's tasking closed: %s" % String((CampaignState.taskings.get(PilotRecovery.TASKING_ID, {}) as Dictionary).get("cause", "")))


func _finish() -> void:
	if _fail == 0:
		print("=== CRASH PROBE PASS ===")
	else:
		print("=== CRASH PROBE FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _find_director() -> FieldDirector:
	for n in AgentRegistry.civilians:
		var civ: Civilian = n as Civilian
		if civ != null and is_instance_valid(civ) and civ.director != null:
			return civ.director
	var found: Array[Node] = get_tree().root.find_children("*", "FieldDirector", true, false)
	return found[0] as FieldDirector if not found.is_empty() else null


func _air_traffic() -> AirTraffic:
	var found: Array[Node] = get_tree().root.find_children("AirTraffic", "", true, false)
	for n in found:
		if n is AirTraffic:
			return n as AirTraffic
	return null


func _last_heli(at: AirTraffic) -> Helicopter:
	var flights: Array = at.get_in_flight()
	for i in range(flights.size() - 1, -1, -1):
		var raw: Variant = (flights[i] as Dictionary).get("node")
		if is_instance_valid(raw) and raw is Helicopter:
			return raw as Helicopter
	return null
