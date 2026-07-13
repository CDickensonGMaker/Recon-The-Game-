## probe_hunt.gd - THE HUNT, measured (bead 0623 / gpvb).
##
## Summoner's make-or-break directive: "they need patrol routes, A TOUGH SEARCHING
## MECHANISM WHEN YOU ARE EVADING THEM, teamwork and firing cohesion. the NVA were
## not militarily strong but made up in DETERMINATION and tactics."
##
## And after watching the patrol lab (2026-07-12):
##   "even the most searching unit stops after their circles hit. i think the nva
##    should get more additional breadcrumbs to follow."
##   "because if they started to chase me it would fulfil that true MACV-SOG story
##    ive been hearing... being chased by 1000 men with 6 people in their squad.
##    AND MAKING IT OUT ALIVE."
##
## THE FANTASY IS THE CHASE. A net that inflates around your LAST KNOWN POSITION can
## never chase anyone - you just walk out of it. The anchor has to SLIDE down your
## escape route. Scenarios 5-7 exist to make sure it never stops doing that.
##
##   godot --headless --path . res://tools/probe_hunt.tscn
extends Node

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== THE HUNT ===\n")
	_t_they_fan_out()
	_t_the_net_expands()
	_t_determination_decides_who_goes_home()
	_t_fresh_sign_moves_the_net()
	_t_the_net_chases()
	_t_the_trail_points_the_right_way()
	_t_nva_read_more_trail()
	_t_water_breaks_trail()
	print("")
	if _fails == 0:
		print("*** THE HUNT HOLDS. They chase. Getting out alive is the game. ***")
	else:
		print("*** %d FAILURE(S) ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])


## Stand-ins for squad members: hunt_point only needs a stable instance id.
func _members(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		var m := Node.new()
		m.name = "M%d" % i
		add_child(m)
		out.append(m)
	return out


## FIVE MEN, FIVE SECTORS. The old code sent all five to one crumb.
func _t_they_fan_out() -> void:
	print("-- 1. FIVE SEARCHERS, FIVE WEDGES (they used to clump on one crumb) --")
	EnemySquad.clear()
	var t0: float = 1000.0
	EnemySquad.begin_hunt(7, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var men := _members(5)
	var pts: Array[Vector3] = []
	for m in men:
		pts.append(EnemySquad.hunt_point(7, m, t0 + 8000.0, 0.6))

	var min_sep: float = 1e9
	for i in range(pts.size()):
		for j in range(i + 1, pts.size()):
			min_sep = minf(min_sep, pts[i].distance_to(pts[j]))
	_check("no two men search the same spot", min_sep > 4.0, "closest pair %.1fm apart" % min_sep)

	var width: float = pts[0].distance_to(pts[4])
	_check("the net is WIDE, not a conga line", width > 18.0, "flank-to-flank %.1fm" % width)

	var mean := Vector3.ZERO
	for p in pts:
		mean += p
	mean /= float(pts.size())
	_check("the sweep pushes the way he RAN (+Z), not backwards",
		mean.z > 0.0, "mean bearing z=%.1f" % mean.z)


## STANDING STILL DOES NOT SAVE YOU. It buries you.
func _t_the_net_expands() -> void:
	print("\n-- 2. THE NET GROWS WITH TIME --")
	EnemySquad.clear()
	var t0: float = 1000.0
	EnemySquad.begin_hunt(1, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var r5: float = EnemySquad.hunt_radius(1, t0 + 5000.0, 0.6)
	var r20: float = EnemySquad.hunt_radius(1, t0 + 20000.0, 0.6)
	_check("the ring pushes outward", r20 > r5 + 10.0, "5s=%.0fm -> 20s=%.0fm" % [r5, r20])

	# The cap SCALES WITH DETERMINATION now (a determined man casts a wider net as
	# well as a longer one), so it is no longer a flat HUNT_R_MAX.
	var r_far: float = EnemySquad.hunt_radius(1, t0 + 300000.0, 0.6)
	var cap_06: float = EnemySquad.HUNT_R_MAX * (0.65 + 0.6 * 0.6)
	_check("...and it is capped (they don't search the whole map)",
		r_far <= cap_06 + 0.1, "settles at %.0fm" % r_far)

	var cap_farmer: float = EnemySquad.hunt_radius(1, t0 + 300000.0, 0.25)
	var cap_nva: float = EnemySquad.hunt_radius(1, t0 + 300000.0, 0.90)
	_check("the NVA casts a WIDER net than the farmer", cap_nva > cap_farmer * 1.3,
		"farmer %.0fm, NVA %.0fm" % [cap_farmer, cap_nva])


## "The NVA were not militarily strong but made up in determination."
func _t_determination_decides_who_goes_home() -> void:
	print("\n-- 3. DETERMINATION: WHO KEEPS LOOKING --")
	EnemySquad.clear()
	var t0: float = 1000.0
	EnemySquad.begin_hunt(2, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var farmer: float = 0.25
	var vc: float = 0.45
	var nva: float = 0.9

	var still: Callable = func(det: float, secs: float) -> bool:
		return EnemySquad.hunt_active(2, t0 + secs * 1000.0, det)

	_check("everyone is still hunting at 20s", still.call(farmer, 20.0) and still.call(nva, 20.0))
	_check("the FARMER has gone home by 45s", not still.call(farmer, 45.0))
	_check("the VC is still out there at 45s", still.call(vc, 45.0))
	_check("the VC quits by 60s", not still.call(vc, 60.0))
	_check("THE NVA IS STILL HUNTING AT 80s", still.call(nva, 80.0))

	var t_f: float = EnemySquad.HUNT_BASE_S + EnemySquad.HUNT_DET_S * farmer
	var t_n: float = EnemySquad.HUNT_BASE_S + EnemySquad.HUNT_DET_S * nva
	print("      farmer %.0fs   VC %.0fs   NVA %.0fs" % [
		t_f, EnemySquad.HUNT_BASE_S + EnemySquad.HUNT_DET_S * vc, t_n])
	_check("an NVA regular hunts ~2x as long as a farmer", t_n > t_f * 1.9,
		"%.0fs vs %.0fs" % [t_n, t_f])


## The body you didn't hide. The witness rule and the hunt are ONE system.
func _t_fresh_sign_moves_the_net() -> void:
	print("\n-- 4. A BODY YOU LEFT BEHIND MOVES THE WHOLE NET --")
	EnemySquad.clear()
	var t0: float = 1000.0
	EnemySquad.begin_hunt(3, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var men := _members(3)
	var before: Vector3 = EnemySquad.hunt_point(3, men[0], t0 + 30000.0, 0.6)
	var r_before: float = EnemySquad.hunt_radius(3, t0 + 30000.0, 0.6)

	var body := Vector3(50, 0, 0)
	EnemySquad.reanchor_hunt(3, body, t0 + 30000.0)
	var after: Vector3 = EnemySquad.hunt_point(3, men[0], t0 + 31000.0, 0.6)
	var r_after: float = EnemySquad.hunt_radius(3, t0 + 31000.0, 0.6)

	_check("the net jumps onto the body", after.distance_to(body) < before.distance_to(body),
		"%.0fm -> %.0fm from the corpse" % [before.distance_to(body), after.distance_to(body)])
	_check("the clock RESTARTS (the net tightens, then grows again)", r_after < r_before,
		"radius %.0fm -> %.0fm" % [r_before, r_after])
	_check("he KEEPS his sector (the squad pivots as a squad)",
		EnemySquad.hunt_point(3, men[0], t0 + 31000.0, 0.6)
			!= EnemySquad.hunt_point(3, men[1], t0 + 31000.0, 0.6))


## ================== THE CHASE ==================
## The Summoner watched the lab and said the net "stops after their circles hit."
## He was right, and it is the difference between a search and the SOG nightmare:
## six men, a thousand chasing, and getting out alive. A donut around your last
## known position is not a chase. The anchor must SLIDE.
func _t_the_net_chases() -> void:
	print("\n-- 5. THE NET CHASES (it does not squat on a memory) --")
	EnemySquad.clear()
	var t0: float = 1000.0
	EnemySquad.begin_hunt(11, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var a10: Vector3 = EnemySquad.hunt_anchor_now(11, t0 + 10000.0, 0.9)
	var a60: Vector3 = EnemySquad.hunt_anchor_now(11, t0 + 60000.0, 0.9)
	_check("the net's CENTRE moves downrange after him",
		a60.z > a10.z + 30.0, "anchor z: %.0fm at 10s -> %.0fm at 60s" % [a10.z, a60.z])
	_check("...in the direction he RAN (+Z)", a60.z > 0.0)

	var farmer: Vector3 = EnemySquad.hunt_anchor_now(11, t0 + 60000.0, 0.25)
	var nva: Vector3 = EnemySquad.hunt_anchor_now(11, t0 + 60000.0, 0.90)
	_check("THE NVA PUSHES THE NET FURTHER THAN THE FARMER", nva.z > farmer.z * 1.5,
		"at 60s: farmer %.0fm, NVA %.0fm downrange" % [farmer.z, nva.z])

	var reach: float = nva.z + EnemySquad.hunt_radius(11, t0 + 60000.0, 0.9)
	var f_reach: float = farmer.z + EnemySquad.hunt_radius(11, t0 + 60000.0, 0.25)
	print("      one minute after you break contact, the sweep can touch you at:")
	print("         farmer %.0fm      NVA %.0fm      <- run, and do not stop" % [f_reach, reach])
	_check("an NVA sweep reaches past 150m within a minute", reach > 150.0, "%.0fm" % reach)


## THE BUG THE LAB FOUND. enemy_base built its heading from search_point(), which
## walks the trail NEWEST->OLDEST - so it pointed where he had COME FROM, and the net
## swept AWAY from him. probe_hunt never caught it because the probe passed a heading
## in BY HAND and only ever tested EnemySquad in isolation.
##   TEST THE WIRING, NOT JUST THE PART. The wiring is where nothing was looking.
func _t_the_trail_points_the_right_way() -> void:
	print("\n-- 6. THE TRAIL POINTS THE WAY HE WENT (it pointed BACKWARDS) --")
	EnemySquad.clear()
	var ghost := Node3D.new()
	add_child(ghost)
	var t: float = 1000.0
	for i in range(12):   # he runs north; report_contact lays the trail
		EnemySquad.report_contact(21, ghost, Vector3(0, 0, float(i) * 6.0), t)
		t += EnemySquad.CRUMB_INTERVAL * 1000.0
	var h := EnemySquad.trail_heading(21)
	_check("heading points NORTH (+Z), the way he ran", h.z > 0.9,
		"heading = (%.2f, %.2f)" % [h.x, h.z])
	_check("...and NOT back down his own bootprints", h.z > 0.0)


## "the nva should get more additional breadcrumbs to follow" - Summoner, verbatim.
func _t_nva_read_more_trail() -> void:
	print("\n-- 7. WHO CAN READ THE TRAIL --")
	var farmer: int = EnemySquad.readable_crumbs(0.25)
	var vc: int = EnemySquad.readable_crumbs(0.45)
	var nva: int = EnemySquad.readable_crumbs(0.90)
	print("      crumbs readable:  farmer %d   VC %d   NVA %d   (of %d, %.1fs apart)" % [
		farmer, vc, nva, EnemySquad.CRUMB_MAX, EnemySquad.CRUMB_INTERVAL])
	_check("the trail is a real trail now (it was 5 crumbs = 5 seconds)",
		EnemySquad.CRUMB_MAX >= 15,
		"%d crumbs x %.1fs = %.0fs of his actual path" % [
			EnemySquad.CRUMB_MAX, EnemySquad.CRUMB_INTERVAL,
			float(EnemySquad.CRUMB_MAX) * EnemySquad.CRUMB_INTERVAL])
	_check("THE NVA READS FAR MORE OF IT THAN THE FARMER", nva > farmer * 2,
		"%d vs %d crumbs" % [nva, farmer])


## ================== WATER BREAKS TRAIL ==================
## The counterplay that makes a 169m/minute chase survivable, and the thing the real
## SOG teams actually did. Wade the creek and you lay no sign: the freshest crumb
## stays at the bank where you went IN, so the net anchors on the water and loses
## the thread. Honest price: water is OPEN, SLOW, LOUD, and full of leeches.
func _t_water_breaks_trail() -> void:
	print("
-- 8. WATER BREAKS TRAIL (the only way out of a real chase) --")
	EnemySquad.clear()
	var ghost := Node3D.new()
	add_child(ghost)
	var t: float = 1000.0

	# He runs north up the bank, laying sign, and enters the creek at z = 30.
	for i in range(6):
		EnemySquad.report_contact(31, ghost, Vector3(0, 0, float(i) * 6.0), t, true)
		t += EnemySquad.CRUMB_INTERVAL * 1000.0
	var on_land: int = (EnemySquad._squads[31].crumbs as Array).size()

	# Now he is IN the water, and he wades 60m east. They can still SEE him -
	# but he is leaving nothing to follow.
	for i in range(10):
		EnemySquad.report_contact(31, ghost, Vector3(float(i) * 6.0, 0, 30.0), t, false)
		t += EnemySquad.CRUMB_INTERVAL * 1000.0
	var after_wade: int = (EnemySquad._squads[31].crumbs as Array).size()

	_check("wading lays NO new sign", after_wade == on_land,
		"%d crumbs before the creek, %d after wading 60m" % [on_land, after_wade])

	var crumbs: Array = EnemySquad._squads[31].crumbs
	var freshest: Vector3 = crumbs[crumbs.size() - 1]
	_check("the trail ENDS AT THE BANK where he went in", freshest.z <= 30.1 and freshest.x < 1.0,
		"freshest sign at (%.0f, %.0f)" % [freshest.x, freshest.z])

	# So when they lose him, the hunt anchors on the bank - not on where he actually is.
	var h := EnemySquad.trail_heading(31)
	EnemySquad.begin_hunt(31, freshest, h, t)
	var net: Vector3 = EnemySquad.hunt_anchor_now(31, t + 40000.0, 0.9)
	var truth := Vector3(54, 0, 30)          # where he actually came out
	_check("the NET GOES THE WRONG WAY (he is 54m east; they sweep north)",
		net.distance_to(truth) > 40.0,
		"net at (%.0f, %.0f), he is at (%.0f, %.0f)" % [net.x, net.z, truth.x, truth.z])
	print("      even an NVA sweep is hunting empty jungle. THAT is how you get out alive.")
