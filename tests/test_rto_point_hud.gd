## test_rto_point_hud.gd - r4bk probe: the RTO's 10m radio tether and the point
## man's scan must both have a visible HUD affordance.
##
## THIS PROBE CANNOT VERIFY THAT THE STRIP LOOKS RIGHT. It certifies the state
## machine behind it: net/off-net flips at the director's own constant, a dead RTO
## reads as no radio, and the point man's scan radius the HUD prints is the same
## number _point_scan uses.
## Run: godot --headless --path . res://tests/test_rto_point_hud.tscn
extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	var r: float = FieldDirector.RTO_RADIO_RANGE

	# --- 1. in range: the player can see he is on the net -------------------
	var near: Array = MissionHUD.radio_state(true, r - 0.1)
	if not str(near[0]).contains("ON THE NET"):
		print("FAIL: inside %.1fm the strip reads '%s'" % [r, str(near[0])])
		failures += 1

	# --- 2. out of range: visible BEFORE he presses T, with the distance -----
	var far: Array = MissionHUD.radio_state(true, r + 0.1)
	if not str(far[0]).contains("OFF THE NET"):
		print("FAIL: outside %.1fm the strip reads '%s' - the tether is invisible" \
			% [r, str(far[0])])
		failures += 1
	if not str(far[0]).contains(str(int(r + 0.1))):
		print("FAIL: off-net row '%s' does not print the range to the radio" % str(far[0]))
		failures += 1
	if str(near[0]) == str(far[0]) or near[1] == far[1]:
		print("FAIL: in-range and out-of-range rows are indistinguishable")
		failures += 1

	# --- 3. negative control: kill the RTO, the state MUST change -----------
	var down: Array = MissionHUD.radio_state(false, 0.0)
	if str(down[0]) == str(near[0]):
		print("FAIL: a dead RTO standing on the player still reads as on the net")
		failures += 1
	if not str(down[0]).contains("NO RADIO"):
		print("FAIL: dead-RTO row reads '%s' - the radio being a man is invisible" \
			% str(down[0]))
		failures += 1

	# --- 4. the boundary is the director's constant, not a copy -------------
	# Negative control: a hardcoded 10.0 in the HUD would not follow this shift.
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/mission_hud.gd")
	if not src.contains("FieldDirector.RTO_RADIO_RANGE"):
		print("FAIL: mission_hud does not read the tether from FieldDirector - it can drift")
		failures += 1

	# --- 5. the point man: the HUD prints the scan's own radius -------------
	var squad := SquadSystem.new()
	add_child(squad)
	if squad.point_scan_radius() != 0.0:
		print("FAIL: point_scan_radius %.1f with no point man" % squad.point_scan_radius())
		failures += 1
	var point := AllyBase.new()
	point.member = {"nick": "TEX", "mos": "POINTMAN", "al": 100, "skills": {}}
	squad.members.append(point)
	add_child(point)
	var base_r: float = squad.point_scan_radius()
	if base_r <= 0.0:
		print("FAIL: point man present but scan radius is %.1f" % base_r)
		failures += 1
	point.member["skills"] = {"detect_ambush": 6}
	if squad.point_scan_radius() <= base_r:
		print("FAIL: detect_ambush does not extend the printed radius (%.1f vs %.1f)" \
			% [squad.point_scan_radius(), base_r])
		failures += 1
	var scan_src: String = FileAccess.get_file_as_string("res://scripts/squad/squad_system.gd")
	if scan_src.contains("var radius: float = 30.0 +"):
		print("FAIL: _point_scan still computes its own radius - HUD and scan can diverge")
		failures += 1
	if not src.contains("point_scan_radius"):
		print("FAIL: the HUD never prints the point man's scan")
		failures += 1

	point.queue_free()
	squad.queue_free()
	if failures == 0:
		print("PASS: RTO radio + point man have HUD state (LOOK is the Summoner's ruling)")
	else:
		print("FAIL: RTO/point HUD probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
