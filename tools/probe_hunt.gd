## probe_hunt.gd - THE HUNT, measured (bead 0623 / gpvb).
##
## Summoner's make-or-break directive: "they need patrol routes, A TOUGH SEARCHING
## MECHANISM WHEN YOU ARE EVADING THEM, teamwork and firing cohesion. the NVA were
## not militarily strong but made up in DETERMINATION and tactics."
##
## What search was before this: every man in the squad walked to the SAME breadcrumb,
## stood on it, and the goal-scorer dropped INVESTIGATE after 5 seconds. Five men
## piled onto one point and then forgot about you. This probe exists so that can
## never quietly come back.
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
	print("")
	if _fails == 0:
		print("*** THE HUNT HOLDS. Breaking contact is no longer walking behind a tree. ***")
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
	# You broke contact at the origin, running north (+Z).
	EnemySquad.begin_hunt(7, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var men := _members(5)
	var pts: Array[Vector3] = []
	for m in men:
		pts.append(EnemySquad.hunt_point(7, m, t0 + 8000.0, 0.6))

	# Every wedge distinct?
	var min_sep: float = 1e9
	for i in range(pts.size()):
		for j in range(i + 1, pts.size()):
			min_sep = minf(min_sep, pts[i].distance_to(pts[j]))
	_check("no two men search the same spot", min_sep > 4.0, "closest pair %.1fm apart" % min_sep)

	# Line abreast: the outer two should be a long way apart.
	var width: float = pts[0].distance_to(pts[4])
	_check("the net is WIDE, not a conga line", width > 20.0, "flank-to-flank %.1fm" % width)

	# Biased along the heading: the mean bearing should point roughly north (+Z).
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
	var r90: float = EnemySquad.hunt_radius(1, t0 + 90000.0, 0.6)
	_check("the ring pushes outward", r20 > r5 + 10.0, "5s=%.0fm -> 20s=%.0fm" % [r5, r20])
	_check("...and it is capped (they don't search the whole map)",
		r90 <= EnemySquad.HUNT_R_MAX + 0.1, "90s=%.0fm (cap %.0fm)" % [r90, EnemySquad.HUNT_R_MAX])


## "The NVA were not militarily strong but made up in determination."
func _t_determination_decides_who_goes_home() -> void:
	print("\n-- 3. DETERMINATION: WHO KEEPS LOOKING --")
	EnemySquad.clear()
	var t0: float = 1000.0
	EnemySquad.begin_hunt(2, Vector3.ZERO, Vector3(0, 0, 1), t0)
	var farmer: float = 0.25   # vc_farmer
	var vc: float = 0.45       # vc_rifleman
	var nva: float = 0.9       # nva_regular

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

	# 30s in, someone walks up on a corpse 50m east. Re-anchor.
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
