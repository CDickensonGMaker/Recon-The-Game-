## test_arena_sandbox.gd - probe for the AI-stress arena fortification + destruction +
## fire-support + tunnel testbed. Proves: sandbags + wire spawn; a sapper detonation
## tears out the fortification segments in blast radius (gap) while a segment outside
## the radius survives; the player can call each of the six fire-support tiers and each
## dispatches; a tunnel mouth exists and the satchel-collapse verb removes it.
## Every assertion has a negative control (see the session mutation log).
## Run: godot --headless --path . res://tests/test_arena_sandbox.tscn
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")

var _fail: int = 0


func _ready() -> void:
	_run()


func _f(msg: String) -> void:
	_fail += 1
	print("FAIL: %s" % msg)


func _run() -> void:
	print("=== Arena Sandbox Probe ===")
	var arena: Node3D = ArenaScript.new()
	arena.set("us_squads_active", 1)
	arena.set("vc_squads_active", 1)
	arena.set("men_per_squad", 2)
	arena.set("us_reserve_squads", 0)
	arena.set("vc_reserve_squads", 0)
	arena.set("spawn_player", true)
	arena.set("spawn_hud", false)
	arena.set("bench_dressing", false)
	arena.set("hot_start", false)
	arena.set("patrol_mode", false)
	add_child(arena)
	# _ready awaits two physics frames internally; give it room to finish the build.
	for _i in range(10):
		await get_tree().physics_frame

	_t_forts_spawn(arena)
	_t_fire_support(arena)
	await _t_sapper_breach(arena)
	_t_tunnel(arena)

	print("\n%s: %d failure(s)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## T1: sandbags and barbwire both actually spawn in the arena.
func _t_forts_spawn(arena: Node3D) -> void:
	var sand: int = 0
	var wire: int = 0
	for f in arena.get("_forts"):
		if not is_instance_valid(f):
			continue
		match str(f.get("kind")):
			"sandbag": sand += 1
			"wire": wire += 1
	print("forts: %d sandbag, %d wire" % [sand, wire])
	if sand < 3:
		_f("too few sandbag segments (%d)" % sand)
	if wire < 3:
		_f("too few barbwire segments (%d)" % wire)


## T5 (fire support): every one of the six tiers dispatches through the RTO net. A
## successful call decrements its inventory; a call blocked by any gate does not.
func _t_fire_support(arena: Node3D) -> void:
	var d: FieldDirector = arena.get("_field_director")
	if d == null:
		_f("no FieldDirector wired - fire support is uncallable in the arena")
		return
	var pl: Node3D = arena.get("player")
	var cam: Camera3D = pl.get_node("Head/Camera3D") as Camera3D
	cam.rotation_degrees.x = -40.0  # look down so _cas_ground_target marches onto the floor
	if d._radio_check() != "":
		_f("radio net rejects the call: '%s'" % d._radio_check())
		return
	for kind in ["bombs", "napalm", "arty", "mortar", "spectre", "cbu"]:
		d.fire_support[kind] = 5
		d._cas_cooldown = 0.0
		d._pending_danger_close = ""
		var before: int = int(d.fire_support[kind])
		d.request_fire_support(kind)
		if int(d.fire_support[kind]) == before:
			# Danger close (the player is within 45m of his own aim point): confirm.
			d.request_fire_support(kind)
		var after: int = int(d.fire_support[kind])
		print("  fire '%s': %d -> %d" % [kind, before, after])
		if after != before - 1:
			_f("fire tier '%s' did not dispatch (%d -> %d)" % [kind, before, after])


## T2 + T3: _launch_arena_sappers spawns armed sappers; a detonation removes the
## fortification segments in blast radius (a real gap) while a segment outside the
## radius survives (no overreach).
func _t_sapper_breach(arena: Node3D) -> void:
	arena._launch_arena_sappers()
	await get_tree().physics_frame
	var sappers: Array = get_tree().get_nodes_in_group("arena_sapper")
	if sappers.is_empty():
		_f("no sappers spawned by _launch_arena_sappers")
		return
	var s: Node3D = sappers[0]
	var target: Vector3 = Vector3.ZERO
	for c in s.get_children():
		if c is SapperCharge:
			target = (c as SapperCharge).target_pos
	if target == Vector3.ZERO:
		_f("sapper carries no armed charge")
		return
	var gz: Node3D = _nearest_fort(arena, target)
	if gz == null:
		_f("no fort near the sapper objective")
		return
	var gz_pos: Vector3 = gz.global_position
	var control: Node3D = _farthest_fort(arena, gz_pos)  # a segment well outside the 14m radius
	var control_dist: float = control.global_position.distance_to(gz_pos) if control != null else 0.0
	var near_before: int = _forts_within(arena, gz_pos, 6.0)
	# Force the crossing: put the sapper on its objective so the live charge detonates.
	s.global_position = target
	var blew: bool = false
	for _i in range(40):
		await get_tree().physics_frame
		if not is_instance_valid(s) or s.is_dead():
			blew = true
			break
	if not blew:
		_f("sapper never detonated after reaching its objective")
		return
	var near_after: int = _forts_within(arena, gz_pos, 6.0)
	print("sapper breach: forts within 6m of ground zero %d -> %d | control at %.1fm valid: %s" % [
		near_before, near_after, control_dist, is_instance_valid(control)])
	if near_after >= near_before:
		_f("sapper detonation left the wire intact (%d -> %d) - no gap" % [near_before, near_after])
	if control != null and control_dist > 15.0 and not is_instance_valid(control):
		_f("blast destroyed a segment %.1fm out, outside its 14m radius - overreach" % control_dist)


## T4: a tunnel mouth exists and the satchel-collapse verb removes it from the world.
func _t_tunnel(arena: Node3D) -> void:
	var mouth: Node3D = null
	for m in arena.get_tree().get_nodes_in_group("tunnel_entrances"):
		if is_instance_valid(m) and str((m as Node).name) == "ArenaTunnelMouth":
			mouth = m as Node3D
	if mouth == null:
		_f("no tunnel entrance placed in the arena")
		return
	var pl: Node = arena.get("player")
	var before_satchels: int = int(pl.get("satchel_count"))
	if before_satchels <= 0:
		_f("player has no satchel - cannot collapse the mouth")
		return
	# The hold-timer is input-only; drive the real consequence directly.
	pl.call("_satchel_the_mouth", mouth)
	var still_grouped: bool = mouth.is_in_group("tunnel_entrances")
	print("tunnel: satchels %d -> %d, still a mouth: %s" % [
		before_satchels, int(pl.get("satchel_count")), still_grouped])
	if int(pl.get("satchel_count")) != before_satchels - 1:
		_f("satchel not consumed collapsing the mouth")
	if still_grouped:
		_f("mouth still in tunnel_entrances after collapse - not removed from the world")


func _nearest_fort(arena: Node3D, p: Vector3) -> Node3D:
	var best: Node3D = null
	var bd: float = 1.0e9
	for f in arena.get("_forts"):
		if not is_instance_valid(f):
			continue
		var dd: float = (f as Node3D).global_position.distance_to(p)
		if dd < bd:
			bd = dd
			best = f as Node3D
	return best


func _farthest_fort(arena: Node3D, p: Vector3) -> Node3D:
	var best: Node3D = null
	var bd: float = -1.0
	for f in arena.get("_forts"):
		if not is_instance_valid(f):
			continue
		var dd: float = (f as Node3D).global_position.distance_to(p)
		if dd > bd:
			bd = dd
			best = f as Node3D
	return best


func _forts_within(arena: Node3D, p: Vector3, r: float) -> int:
	var n: int = 0
	for f in arena.get("_forts"):
		if not is_instance_valid(f):
			continue
		if (f as Node3D).global_position.distance_to(p) <= r:
			n += 1
	return n
