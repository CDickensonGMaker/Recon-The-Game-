## test_dynamic_events.gd - the four dynamic world events reach the player.
## DynamicMissionFactory was a complete consumer with exactly one producer
## (convoy_ambushed) on an inert convoy system, so no dynamic event could fire.
## This probe covers the producers AND the r4bk delivery path: a crisis that the
## player is never told about is dead code with extra steps.
##
## Every assertion carries a negative control - the condition inverted - because
## a test that passes against both the fix and its absence proves nothing.
## Run: godot --headless --path . res://tests/test_dynamic_events.tscn
extends Node

const FactoryScript := preload("res://scripts/missions/dynamic_mission_factory.gd")

const FSB := Vector3(600, 0, -400)   ## a plausible compound centre, never the origin

var _failures := 0
var _toasts: Array[String] = []


func _ready() -> void:
	_check_state_mapping()
	_check_dedupe()
	_check_crisis_outranks_ring()
	_check_radio_gate()
	_check_village_distress_gate()
	_check_firebase_threat_gate()
	if _failures == 0:
		print("test_dynamic_events: PASS")
	else:
		print("test_dynamic_events: %d FAILURES" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _on_toast(text: String) -> void:
	_toasts.append(text)


## A FieldDirector with just enough world to answer the radio and the gate.
## Built by hand rather than through GameFlow: GameFlow._ready() already starts
## the default operation (game_flow.gd:27), so a probe that also begins one
## builds TWO worlds and doubles every population count.
func _rig(rto_dist: float) -> FieldDirector:
	# Retire the previous rig's director, or emit_location fans out to every
	# director this probe has ever built and the counts cross-contaminate.
	for prior in get_tree().get_nodes_in_group("mission_director"):
		prior.remove_from_group("mission_director")
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")   # FieldDirector.setup() does this in game
	var w := GameWorld.new()
	add_child(w)
	var pl := CharacterBody3D.new()
	w.add_child(pl)
	pl.global_position = Vector3(500, 0, 0)
	w.player = pl
	d.world = w
	var ss := SquadSystem.new()
	add_child(ss)
	var rto := AllyBase.new()
	ss.add_child(rto)
	rto.member = {"mos": "RTO", "nick": "SPARKS"}
	rto.global_position = pl.global_position + Vector3(rto_dist, 0, 0)
	ss.members.append(rto)
	d.squad_system = ss
	d.patrol_gate_pos = Vector3.ZERO
	d.patrol_gate_out = Vector3.FORWARD
	d.patrol_out = true
	_toasts.clear()
	d.toast.connect(_on_toast)
	return d


func _check_state_mapping() -> void:
	var want := {
		&"friendly_patrol_pinned": "pinned_patrol",
		&"village_requesting_aid": "village",
		&"enemy_camp_discovered": "vc_camp",
		&"friendly_firebase_under_attack": "firebase_attack",
	}
	for st in want:
		var loc: Dictionary = FactoryScript.location_for(st, {"position": Vector3(10, 0, 10)})
		if loc.get("kind", "") != want[st]:
			_fail("state %s mapped to '%s', wanted '%s'" % [st, loc.get("kind", ""), want[st]])
		if loc.get("trigger_state", "") != String(st):
			_fail("state %s lost its trigger_state tag" % st)
	# NEGATIVE CONTROL: an unrecognised state must produce nothing at all. If this
	# returned a location, every stray signal in the game would become a waypoint.
	if not FactoryScript.location_for(&"not_a_real_state", {"position": Vector3.ONE}).is_empty():
		_fail("an unknown state produced a location")


## The same entity must never be offered twice (dynamic_mission_factory.gd:39).
func _check_dedupe() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	f.emit_location(&"village_requesting_aid", 4242, {"position": Vector3(80, 0, 0)})
	if d.patrol_locations.size() != 1:
		_fail("first emit produced %d locations, wanted 1" % d.patrol_locations.size())
	f.emit_location(&"village_requesting_aid", 4242, {"position": Vector3(80, 0, 0)})
	if d.patrol_locations.size() != 1:
		_fail("_seen dedupe failed: same entity queued %d times" % d.patrol_locations.size())
	# NEGATIVE CONTROL: a DIFFERENT entity must still get through, or the dedupe
	# is really just a one-shot latch that kills the second crisis of the patrol.
	f.emit_location(&"village_requesting_aid", 9999, {"position": Vector3(90, 0, 0)})
	if d.patrol_locations.size() != 2:
		_fail("a different entity was swallowed by the dedupe")
	# NEGATIVE CONTROL: a zero position is not a place. It must never be queued.
	f.emit_location(&"village_requesting_aid", 7777, {"position": Vector3.ZERO})
	if d.patrol_locations.size() != 2:
		_fail("a ZERO-position crisis was queued as a real location")


## push_front means nothing on its own - _pick_patrol_location scans the WHOLE
## array for the nearest site in the push direction, so array order is otherwise
## ignored. This is the assertion that proves the crisis actually outranks.
func _check_crisis_outranks_ring() -> void:
	var d := _rig(1.0)
	d.patrol_out = false
	# A standing village sits close and dead ahead - it wins every bearing scan.
	d.patrol_locations.append({"pos": Vector3(0, 0, -100), "kind": "village"})
	# The crisis is far away and BEHIND him: it loses the bearing scan outright.
	d.patrol_locations.push_front({"pos": Vector3(0, 0, 600), "kind": "firebase_attack",
		"trigger_state": "friendly_firebase_under_attack"})
	d.world.player.global_position = Vector3(0, 0, -20)   # pushing north
	var picked: Dictionary = d._pick_patrol_location()
	if picked.get("kind", "") != "firebase_attack":
		_fail("the ring beat a live crisis - picked '%s'" % picked.get("kind", ""))
	# NEGATIVE CONTROL: strip the trigger_state tag and the SAME geometry must
	# now pick the near village. Proves the crisis branch is what changed the
	# outcome, not the array order or the distances.
	var d2 := _rig(1.0)
	d2.patrol_out = false
	d2.patrol_locations.append({"pos": Vector3(0, 0, -100), "kind": "village"})
	d2.patrol_locations.push_front({"pos": Vector3(0, 0, 600), "kind": "firebase_attack"})
	d2.world.player.global_position = Vector3(0, 0, -20)
	if d2._pick_patrol_location().get("kind", "") != "village":
		_fail("an untagged entry was treated as a crisis")


## THE r4bk ASSERTION. A crisis raised while the player is ALREADY outside the
## wire must retarget the sweep and say so - otherwise it is invisible until he
## walks home and back out. And per the Fairness Law the channel is the RTO's
## net: off the net, nothing moves and nothing is announced.
func _check_radio_gate() -> void:
	var on := _rig(2.0)    # inside RTO_RADIO_RANGE
	on.raise_crisis({"pos": Vector3(300, 0, 0), "kind": "firebase_attack",
		"trigger_state": "friendly_firebase_under_attack"})
	if on.patrol_location != Vector3(300, 0, 0):
		_fail("on the net, the crisis did not retarget the sweep")
	if on.patrol_location_kind != "firebase_attack":
		_fail("on the net, the crisis did not set the location kind")
	if _toasts.is_empty():
		_fail("on the net, the crisis was never announced to the player")
	# The topo map draws its grease-pencil circle on director.patrol_location
	# (topo_map.gd:112), so a retarget IS the second visible affordance.

	# NEGATIVE CONTROL: same crisis, player off the net. Silence, no retarget -
	# but the location must still be QUEUED for the next walk-out, or being off
	# the net would delete the crisis instead of merely delaying the word.
	var off := _rig(FieldDirector.RTO_RADIO_RANGE + 50.0)
	off.raise_crisis({"pos": Vector3(300, 0, 0), "kind": "firebase_attack",
		"trigger_state": "friendly_firebase_under_attack"})
	if off.patrol_location != Vector3.ZERO:
		_fail("off the net, a marker appeared from nothing")
	if not _toasts.is_empty():
		_fail("off the net, the player was told anyway: %s" % str(_toasts))
	if off.patrol_locations.size() != 1:
		_fail("off the net, the crisis was dropped instead of queued")

	# NEGATIVE CONTROL: inside the wire (patrol_out false) nothing retargets -
	# he is standing at the firebase and has not begun an excursion.
	var home := _rig(2.0)
	home.patrol_out = false
	home.raise_crisis({"pos": Vector3(300, 0, 0), "kind": "village",
		"trigger_state": "village_requesting_aid"})
	if home.patrol_location != Vector3.ZERO:
		_fail("a crisis retargeted a patrol that had not left the wire")


## A villager panicking at the player's OWN firefight is not a distress call -
## he is already standing there.
func _check_village_distress_gate() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	var village := Vector3(400, 0, 0)
	# Player far away: something is happening that is not him. This is the event.
	f.report_village_distress(village, 111, Vector3.ZERO)
	if d.patrol_locations.size() != 1:
		_fail("a distant village in distress raised no event")
	# NEGATIVE CONTROL: player standing in the village. Must NOT fire.
	f.report_village_distress(Vector3(410, 0, 0), 222, Vector3(412, 0, 0))
	if d.patrol_locations.size() != 1:
		_fail("the player's own firefight was reported to him as a distress call")


## Enemies on the wire while the patrol is out. The garrison are noncombatant
## Civilians (mission_generator.gd:702) and cannot call it in themselves.
func _check_firebase_threat_gate() -> void:
	var c := FSB   # a real compound is never at the world origin
	# NEGATIVE CONTROL: one man on the wire is a probe, not an attack.
	if _threat_fires([c + Vector3(10, 0, 10)]):
		_fail("a single enemy near the wire called in a firebase attack")
	# NEGATIVE CONTROL: a whole squad, but out in the AO where it belongs.
	if _threat_fires([c + Vector3(400, 0, 400), c + Vector3(450, 0, 450),
			c + Vector3(420, 0, 430)]):
		_fail("enemies far out in the AO counted as being on the wire")
	# THE CONDITION: two men inside the threat radius.
	if not _threat_fires([c + Vector3(10, 0, 10), c + Vector3(-20, 0, 5)]):
		_fail("two enemies on the wire did not raise a firebase attack")
	# NEGATIVE CONTROL: the same two men, but the patrol never left the wire.
	# The player is standing in the compound - he does not need to be told.
	if _threat_fires([c + Vector3(10, 0, 10), c + Vector3(-20, 0, 5)], false):
		_fail("the firebase called for help while the player was standing in it")


## Drives the REAL _poll_firebase_threat against real EnemyBase bodies and reports
## whether a location actually reached the director. Nothing here re-implements
## the counting rule - a probe that restates the code it checks proves nothing.
func _threat_fires(positions: Array, out: bool = true) -> bool:
	var d := _rig(1.0)
	d.fsb_center = FSB
	d.patrol_out = out
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	for p in positions:
		var e := EnemyBase.new()
		add_child(e)
		e.global_position = p
		d._live_enemies.append(e)
	d._poll_firebase_threat()
	var fired: bool = false
	for loc in d.patrol_locations:
		if str(loc.get("kind", "")) == "firebase_attack":
			fired = true
	MissionGenerator.dynamic_factory_ref = null
	return fired
