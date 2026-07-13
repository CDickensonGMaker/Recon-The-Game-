## probe_patrol.gd - PATROL CIRCUITS, measured (ADR-021, bead 0623 gap #1).
##
## Summoner: "we generate 5 to 10 patrol points that are in various distances that
## ZIG ZAG ACROSS THE MAP and the unit loops those patrol points."
##
## The old make_patrol_route() walked a 16m circle around the spawn point - a man
## pacing his own doorstep. A patrol has to cross real ground between real things,
## or the player can never learn it, predict it, or ambush it. That intel loop is
## the entire economy of ADR-021, so this probe guards its foundation.
##
##   godot --headless --path . res://tools/probe_patrol.tscn
extends Node

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== PATROL CIRCUITS ===\n")
	_t_it_crosses_the_map()
	_t_it_zigzags()
	_t_every_node_is_visited()
	_t_deterministic()
	print("")
	if _fails == 0:
		print("*** THE PATROLS WALK THE MAP. They can be learned, and they can be ambushed. ***")
	else:
		print("*** %d FAILURE(S) ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])


## A pool of "features" scattered over a 1km AO, the way the generator builds it.
func _pool(rng: RandomNumberGenerator, n: int = 10) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var guard: int = 0
	while out.size() < n and guard < 500:
		guard += 1
		var c := Vector3(rng.randf_range(-500, 500), 0, rng.randf_range(-500, 500))
		var ok := true
		for e in out:
			if e.distance_to(c) < 60.0:
				ok = false
				break
		if ok:
			out.append(c)
	return out


func _legs(route: Array[Vector3]) -> Array[float]:
	var out: Array[float] = []
	for i in range(route.size()):
		out.append(route[i].distance_to(route[(i + 1) % route.size()]))
	return out


## A patrol crosses GROUND. The old 16m doorstep loop could never.
func _t_it_crosses_the_map() -> void:
	print("-- 1. IT CROSSES THE MAP (the old route was a 16m circle) --")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var route := EnemyBase.make_patrol_circuit(_pool(rng), rng, 7)
	_check("5-10 nodes", route.size() >= 5 and route.size() <= 10, "%d nodes" % route.size())

	var legs := _legs(route)
	var total: float = 0.0
	var longest: float = 0.0
	var shortest: float = 1e9
	for l in legs:
		total += l
		longest = maxf(longest, l)
		shortest = minf(shortest, l)
	_check("the circuit is long (a real beat, not a doorstep)", total > 1500.0,
		"%.0fm around" % total)
	_check("legs are at VARIOUS distances", longest > shortest * 1.8,
		"shortest %.0fm, longest %.0fm" % [shortest, longest])

	# Compare against the old local loop, for the record.
	var old := EnemyBase.make_patrol_route(Vector3.ZERO, rng)
	var old_total: float = 0.0
	for l in _legs(old):
		old_total += l
	print("      old make_patrol_route(): %.0fm around.  circuit: %.0fm." % [old_total, total])


## ZIG-ZAG, not a tidy convex ring. Measured as: consecutive legs turn hard, and the
## path crosses near the centroid instead of orbiting it at constant radius.
func _t_it_zigzags() -> void:
	print("\n-- 2. IT ZIG-ZAGS (a convex ring is not a patrol) --")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var route := EnemyBase.make_patrol_circuit(_pool(rng), rng, 7)

	# A convex ring turns the SAME way at every node. A star zig-zag reverses.
	var turns_left: int = 0
	var turns_right: int = 0
	for i in range(route.size()):
		var a: Vector3 = route[i]
		var b: Vector3 = route[(i + 1) % route.size()]
		var c: Vector3 = route[(i + 2) % route.size()]
		var cross: float = (b - a).cross(c - b).y
		if cross > 0.0:
			turns_left += 1
		else:
			turns_right += 1
	_check("the route turns BOTH ways (it is not a convex loop)",
		turns_left > 0 and turns_right > 0, "%d left / %d right turns" % [turns_left, turns_right])

	# Legs should be long relative to the node ring's radius: a star cuts across.
	var c0 := Vector3.ZERO
	for v in route:
		c0 += v
	c0 /= float(route.size())
	var mean_r: float = 0.0
	for v in route:
		mean_r += v.distance_to(c0)
	mean_r /= float(route.size())
	var mean_leg: float = 0.0
	for l in _legs(route):
		mean_leg += l
	mean_leg /= float(route.size())
	_check("legs CUT ACROSS the middle (leg > node radius)", mean_leg > mean_r * 1.15,
		"mean leg %.0fm vs mean radius %.0fm" % [mean_leg, mean_r])


## The star step must be coprime with n or the walk closes early on a sub-loop and
## silently abandons half the nodes.
func _t_every_node_is_visited() -> void:
	print("\n-- 3. EVERY NODE IS VISITED (the coprime rule) --")
	var bad: int = 0
	for n in range(5, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + n
		var route := EnemyBase.make_patrol_circuit(_pool(rng, 10), rng, n)
		var uniq: Dictionary = {}
		for v in route:
			uniq[v] = true
		if uniq.size() != route.size():
			bad += 1
			print("      n=%d: only %d unique of %d!" % [n, uniq.size(), route.size()])
	_check("no node is walked twice, for every circuit size 5..10", bad == 0)


## ADR-010: same seed, same world. A patrol route the player learned must be THERE.
func _t_deterministic() -> void:
	print("\n-- 4. DETERMINISTIC (ADR-010 - the route he learned is still there) --")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 999
	var a := EnemyBase.make_patrol_circuit(_pool(r1), r1, 7)
	var r2 := RandomNumberGenerator.new()
	r2.seed = 999
	var b := EnemyBase.make_patrol_circuit(_pool(r2), r2, 7)
	var same: bool = a.size() == b.size()
	if same:
		for i in range(a.size()):
			if a[i].distance_to(b[i]) > 0.01:
				same = false
				break
	_check("same seed -> the same circuit, node for node", same)
