## test_seat_system.gd - HUEY SEATSYSTEM v1 probe (research batch §7).
## Instantiates the real huey.tscn (no world needed) and proves the full-cabin
## contract end to end (seat count derived from SEAT_NAMES, never hardcoded):
##   1. All seat_* sockets exist (auto-generated today; the probe stays
##      green when Caleb's real GLB sockets land - it prints which mode).
##   2. 10 mock bodies seat: processing frozen, collision off, glued to socket.
##   3. is_full(), double-seat and overflow refused.
##   4. Seated ModelActors play cockpit_idle (pilot seats) / sitting (rest),
##      and both clips loop (statue guard).
##   5. board_squad: dead ally excluded, living staggered in one per 0.6s.
##   6. unseat: processing + collision restored, body at the exit point.
## Run: godot --headless --path . res://tests/test_seat_system.tscn
extends Node3D


## Minimal stand-ins - SeatSystem must not require AllyBase/player.
## MockGrunt has a real _physics_process like AllyBase does, so the
## freeze-on-seat / restore-on-unseat cycle is observable.
class MockGrunt:
	extends CharacterBody3D
	func _physics_process(_delta: float) -> void:
		pass


class MockDead:
	extends CharacterBody3D
	func is_dead() -> bool:
		return true


class MockPlayer:
	extends CharacterBody3D
	var is_seated: bool = false
	var seat_node: Node3D = null
	var exit_at: Vector3 = Vector3.ZERO
	func enter_seat(seat: Node3D) -> void:
		is_seated = true
		seat_node = seat
	func exit_seat(pos: Vector3) -> void:
		is_seated = false
		seat_node = null
		exit_at = pos
		global_position = pos


var failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	failures += 1


func _mock_body(with_model: bool) -> CharacterBody3D:
	var body: CharacterBody3D = MockGrunt.new()
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	body.add_child(col)
	add_child(body)
	if with_model:
		var ma := ModelActor.new()
		body.add_child(ma)
		if not ma.setup("us_grunt_rifleman"):
			_fail("us_grunt_rifleman ModelActor setup failed")
	return body


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var heli: Helicopter = (load("res://scenes/vehicles/huey.tscn") as PackedScene).instantiate() as Helicopter
	add_child(heli)
	heli.global_position = Vector3(0, 10, 0)
	await get_tree().process_frame

	var seats: SeatSystem = heli.seats()
	if seats == null:
		_fail("huey.tscn has no Seats/SeatSystem child")
		get_tree().quit(1)
		return

	# --- 1. socket contract
	var total: int = SeatSystem.SEAT_NAMES.size()
	var avail: Array[StringName] = seats.available_seats()
	print("  sockets: %d available, auto_generated=%s" % [avail.size(), seats.auto_generated])
	if avail.size() != total:
		_fail("expected %d available seats, got %d" % [total, avail.size()])
	for seat_name in SeatSystem.SEAT_NAMES:
		# GLB sockets are plain Node3D (empties), fallback sockets are Marker3D.
		var sock: Node3D = seats.socket(seat_name)
		if sock == null:
			_fail("socket %s missing" % seat_name)
		elif not heli.is_ancestor_of(sock):
			_fail("socket %s is not under the vehicle" % seat_name)
	if seats.is_full():
		_fail("empty bird reports is_full")

	# --- 2. seat a full cabin of mocks (models on a pilot, a gunner, two pax; rest bare)
	var modeled: Array[StringName] = [&"seat_pilot_l", &"seat_gunner_l", &"seat_pax_1", &"seat_pax_6"]
	var bodies: Dictionary = {}
	for seat_name in SeatSystem.SEAT_NAMES:
		var body: CharacterBody3D = _mock_body(seat_name in modeled)
		bodies[seat_name] = body
		if not seats.seat(body, seat_name):
			_fail("could not seat body in %s" % seat_name)
			continue
		if body.is_physics_processing():
			_fail("%s occupant still physics-processing" % seat_name)
		var sock2: Node3D = seats.socket(seat_name)
		if body.global_position.distance_to(sock2.global_position) > 0.05:
			_fail("%s occupant not glued to socket (%.2fm off)" % [seat_name, body.global_position.distance_to(sock2.global_position)])
		if seats.occupant(seat_name) != body:
			_fail("occupant(%s) mismatch" % seat_name)

	# --- 3. full-bird rules
	if not seats.is_full():
		_fail("%d seated but not is_full" % total)
	if not seats.available_seats().is_empty():
		_fail("full bird still lists available seats")
	var extra: CharacterBody3D = _mock_body(false)
	if seats.seat(extra, &"seat_pax_1"):
		_fail("double-seat into occupied seat_pax_1 accepted")
	var pilot_body: CharacterBody3D = bodies[&"seat_pilot_l"]
	if seats.seat(pilot_body, &"seat_pax_2"):
		_fail("already-seated body accepted into a second seat")

	# --- 4. clips: pilots in cockpit_idle, everyone else sitting; both loop
	# THE PILOT CLIP IS CHOSEN BY FLIGHT STATE (seat_system.gd:122-130), and State.IDLE is not
	# the ground - air_traffic.gd:332,344 holds an ORBITING ship in IDLE between waypoints. A
	# freshly instantiated huey.tscn is therefore airborne as far as the clip is concerned, so
	# asserting the grounded clip without setting a state tested nothing the game does.
	heli.state = Helicopter.State.LANDED
	await get_tree().process_frame  # let glue/anim tick once
	# Touchdown runs the panel ONCE (PILOT_PANEL_S) and then falls through to the hold, so the
	# grounded clip is a SEQUENCE, not a state. Asserting the hold the instant she lands caught
	# the one-shot and read as a failure.
	for seat_name in modeled:
		if not String(seat_name).begins_with("seat_pilot"):
			continue
		var panel_model: ModelActor = null
		for c in bodies[seat_name].get_children():
			if c is ModelActor:
				panel_model = c as ModelActor
		if panel_model != null and panel_model.current_action != SeatSystem.PILOT_CLIP_PANEL:
			_fail("%s on touchdown playing '%s', wanted the panel run '%s'" % [
				seat_name, panel_model.current_action, SeatSystem.PILOT_CLIP_PANEL])
	await get_tree().create_timer(SeatSystem.PILOT_PANEL_S + 0.5).timeout

	for seat_name in modeled:
		var body2: CharacterBody3D = bodies[seat_name]
		var model: ModelActor = null
		for c in body2.get_children():
			if c is ModelActor:
				model = c as ModelActor
		var want: String = "cockpit_idle" if String(seat_name).begins_with("seat_pilot") else "sitting"
		if model == null:
			_fail("no ModelActor on %s mock" % seat_name)
			continue
		if not model.has_clip(want):
			_fail("shared anim library lacks '%s' (contract broken)" % want)
		if model.current_action != want:
			_fail("%s occupant playing '%s', wanted '%s'" % [seat_name, model.current_action, want])
		else:
			print("  %s: playing '%s' OK" % [seat_name, want])

	# The other half of the same contract: put her in the air and the pilots take the controls.
	heli.state = Helicopter.State.FLYING
	await get_tree().create_timer(0.3).timeout
	for seat_name in modeled:
		if not String(seat_name).begins_with("seat_pilot"):
			continue
		var pm: ModelActor = null
		for c in bodies[seat_name].get_children():
			if c is ModelActor:
				pm = c as ModelActor
		if pm != null and pm.current_action != SeatSystem.PILOT_CLIP_FLYING:
			_fail("%s airborne playing '%s', wanted '%s'" % [
				seat_name, pm.current_action, SeatSystem.PILOT_CLIP_FLYING])

	# --- 5. unseat all: processing + collision restored at the exit point
	var i: int = 0
	for seat_name in SeatSystem.SEAT_NAMES:
		var body3: CharacterBody3D = bodies[seat_name]
		var exit_pos := Vector3(20.0 + float(i) * 2.0, 1.0, 20.0)
		seats.unseat(body3, exit_pos)
		if body3.global_position.distance_to(exit_pos) > 0.01:
			_fail("%s occupant not restored at exit point" % seat_name)
		if not body3.is_physics_processing():
			_fail("%s occupant physics still frozen after unseat" % seat_name)
		i += 1
	await get_tree().process_frame  # collision re-enable is deferred
	for seat_name in SeatSystem.SEAT_NAMES:
		var body4: CharacterBody3D = bodies[seat_name]
		var col := body4.get_child(0) as CollisionShape3D
		if col != null and col.disabled:
			_fail("%s occupant collision still disabled after unseat" % seat_name)
	if not seats.is_full() and seats.available_seats().size() != total:
		_fail("after per-seat unseat, %d seats available (want %d)" % [seats.available_seats().size(), total])
	print("  unseat: all %d restored" % total)

	# --- 6. board_squad: dead man excluded, living file in on the stagger
	var squad: Array = []
	for j in range(3):
		squad.append(_mock_body(false))
	var dead := MockDead.new()
	add_child(dead)
	squad.append(dead)
	var queued: int = seats.board_squad(squad)
	if queued != 3:
		_fail("board_squad queued %d, want 3 (dead excluded)" % queued)
	await get_tree().create_timer(0.7).timeout  # after first stagger beat
	var aboard_early: int = total - seats.available_seats().size()
	await get_tree().create_timer(1.5).timeout  # all beats done
	var aboard: int = total - seats.available_seats().size()
	print("  board_squad: %d aboard after first beat, %d aboard at end" % [aboard_early, aboard])
	if aboard_early >= 3:
		_fail("file-in was not staggered (all aboard at 0.7s)")
	if aboard != 3:
		_fail("board_squad seated %d, want 3" % aboard)
	for j in range(3):
		var sm := squad[j] as Node3D
		if seats.seat_of(sm) == &"" or not String(seats.seat_of(sm)).begins_with("seat_pax"):
			_fail("squad member %d not in a pax seat (%s)" % [j, seats.seat_of(sm)])
	if seats.seat_of(dead) != &"":
		_fail("dead ally got seated")

	# --- 7. player path: enter_seat/exit_seat used, never glued/reparented
	var mp := MockPlayer.new()
	add_child(mp)
	if not seats.seat(mp, &"seat_pax_4"):
		_fail("player-style body refused a seat")
	if not mp.is_seated or mp.seat_node != seats.socket(&"seat_pax_4"):
		_fail("player path did not use enter_seat glue")
	if mp.get_parent() != self:
		_fail("player body was reparented (forbidden)")
	seats.unseat(mp, Vector3(30, 1, 30))
	if mp.is_seated or mp.exit_at != Vector3(30, 1, 30):
		_fail("player path did not use exit_seat")

	if failures == 0:
		print("PASS: seat system (full-cabin socket contract, clips, stagger, restore) OK")
		get_tree().quit(0)
	else:
		print("FAIL: seat system probe had %d failure(s)" % failures)
		get_tree().quit(1)
