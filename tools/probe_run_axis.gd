## probe_run_axis.gd - the overfly guard + the dispatch mark (decree 2026-08-04:
## no aircraft ever approaches over the player's head, and every dispatched call
## shows its footprint on the target until impact).
## Resolves _run_axis across several geometries and prints the ground-track miss;
## then flies a real 900m CAS strike and a real 200m F-4 flyby, sampling the
## airframe every physics tick for its closest horizontal approach to the player,
## and asserts the dispatch mark stands when the call goes out.
## Run: godot --headless --path . res://tools/probe_run_axis.tscn
extends Node3D

var _director: FieldDirector = null
var _player: CharacterBody3D = null
var _fail: int = 0
var _tracking: bool = false
var _track_min: float = INF
var _spawn_seen: bool = false


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 0.2, 600)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)
	_player = CharacterBody3D.new()
	add_child(_player)
	_player.global_position = Vector3(0, 1, 0)
	var rto: AllyBase = AllyBase.spawn_ally(self, Vector3(2, 0, 1))
	if rto == null:
		print("FAIL: no RTO")
		get_tree().quit(1)
		return
	rto.add_to_group("radioman")
	rto.member = {"nick": "SPARKS", "mos": "RTO"}
	_director = FireSupportBench.wire(self, _player, 600.0)

	var p: Vector3 = _player.global_position
	var cases: Array = [
		["look axis, straight over his head", p + Vector3(0, 0, -60), Vector3(0, 0, -1)],
		["zero run (old default flew overhead)", p + Vector3(0, 0, -80), Vector3.ZERO],
		["target 20m out - no compliant line exists", p + Vector3(20, 1, 0), Vector3(1, 0, 0)],
		["already broadside - must pass unchanged", p + Vector3(0, 0, -60), Vector3(1, 0, 0)],
	]
	for c in cases:
		var target: Vector3 = c[1]
		var req: Vector3 = c[2]
		var axis: Vector3 = _director._run_axis(target, req)
		var miss: float = _director._track_miss(target, axis)
		var target_d: float = Vector2(target.x - p.x, target.z - p.z).length()
		var want: float = minf(FieldDirector.OVERFLY_MISS_M, target_d)
		var ok: bool = miss >= want - 0.5
		print("[AXIS] %-40s req %v -> %v | track miss %.1fm (want >= %.1f) %s"
			% [c[0], req, axis, miss, want, "OK" if ok else "FAIL"])
		if not ok:
			_fail += 1
	if cases[3][2] != _director._run_axis(cases[3][1] as Vector3, cases[3][2] as Vector3):
		_fail += 1
		print("FAIL: a compliant requested axis was rewritten")

	await _fly("bombs", p + Vector3(0, 0, -80), 14.0)
	await _fly("napalm", p + Vector3(0, 0, -80), 8.0)

	if _fail == 0:
		print("PASS: no aircraft track crosses within 40m of the player; dispatch marks stand")
	else:
		print("FAIL: %d overfly/mark failures" % _fail)
	get_tree().quit(mini(_fail, 1))


func _fly(kind: String, target: Vector3, wait_s: float) -> void:
	_director._cas_cooldown = 0.0
	_track_min = INF
	_spawn_seen = false
	_tracking = true
	_director.request_fire_support(kind, target, Vector3.ZERO)
	await get_tree().process_frame
	var mark_up: bool = _find_named(get_tree().root, "DispatchMark") != null
	print("[MARK] %s dispatch footprint standing at the target: %s" % [kind, str(mark_up)])
	if not mark_up:
		_fail += 1
	await get_tree().create_timer(wait_s).timeout
	_tracking = false
	var ok: bool = _track_min >= FieldDirector.OVERFLY_MISS_M - 0.5
	print("[TRACK] %s airframe closest horizontal approach to player %.1fm %s"
		% [kind, _track_min, "OK" if ok else "FAIL"])
	if not ok:
		_fail += 1


func _physics_process(_delta: float) -> void:
	if not _tracking or _player == null:
		return
	var plane: CASAirplane = _find_plane(get_tree().root)
	if plane == null:
		return
	if not _spawn_seen:
		_spawn_seen = true
		print("[SPAWN] airframe entered at %v" % plane.global_position)
	var p: Vector3 = _player.global_position
	var d: float = Vector2(plane.global_position.x - p.x, plane.global_position.z - p.z).length()
	_track_min = minf(_track_min, d)


func _find_plane(root: Node) -> CASAirplane:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CASAirplane:
			return n as CASAirplane
		for c in n.get_children():
			stack.push_back(c)
	return null


func _find_named(root: Node, nm: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if String(n.name) == nm:
			return n
		for c in n.get_children():
			stack.push_back(c)
	return null
