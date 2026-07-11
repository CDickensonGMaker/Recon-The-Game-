## test_scripted_events.gd - Scripted-events infra probe (batch_research §6).
## Builds a tiny scene at runtime and asserts the five contracts:
##  (a) ENTER trigger fires on body entry with honest context (and filters)
##  (b) NOISE trigger hears a NoiseBus event inside its radius, stays deaf outside
##  (c) a wait/move/signal/hand_off sequence runs to completion on a mock agent
##  (d) damaging a cast agent mid-sequence aborts to hand_off + interrupted
##      (the anti-corridor law - agents in sequences stay mortal)
##  (e) spawn_prop refuses a scene whose root is a combatant
##      (honest-quiet law - events never conjure fighters)
## Run: godot --headless --path . res://tests/test_scripted_events.tscn
extends Node3D

var _failures: int = 0


## Minimal mortal agent: takes damage, accepts sequence hooks, records calls.
class MockAgent:
	extends Node3D
	signal damaged(amount: int)
	signal died(agent: Node)
	var moved_to: Vector3 = Vector3.ZERO
	var clips: Array[String] = []
	var hand_off_count: int = 0

	func sequence_move_to(pos: Vector3) -> void:
		moved_to = pos
		global_position = pos  # teleport mover: arrival is instant

	func sequence_play_clip(clip: String) -> void:
		clips.append(clip)

	func sequence_hand_off() -> void:
		hand_off_count += 1

	func take_damage(amount: int, _damage_type: int = 0, _attacker: Node = null, _zone: String = "BODY") -> int:
		damaged.emit(amount)
		return amount


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	await _test_enter_trigger()
	await _test_noise_trigger()
	await _test_sequence_completes()
	await _test_damage_aborts()
	await _test_spawn_prop_guard()
	if _failures == 0:
		print("PASS: scripted events probe (5/5 contracts)")
	else:
		print("FAIL: scripted events probe had %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   %s" % label)
	else:
		print("  FAIL %s" % label)
		_failures += 1


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _await_until(pred: Callable, timeout: float) -> void:
	var left: float = timeout
	while left > 0.0 and not bool(pred.call()):
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _make_body(layer: int, group: String, pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.add_to_group(group)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.5
	cs.shape = sph
	body.add_child(cs)
	body.position = pos  # BEFORE add_child - never let it exist at origin for a tick
	add_child(body)
	return body


# ---------------------------------------------------------------------------
# (a) ENTER
# ---------------------------------------------------------------------------
func _test_enter_trigger() -> void:
	print("[a] ENTER trigger")
	var trig := MissionTrigger.new()
	trig.mode = MissionTrigger.Mode.ENTER
	trig.activator_filter = MissionTrigger.ActivatorFilter.PLAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	cs.shape = box
	trig.add_child(cs)
	add_child(trig)
	trig.global_position = Vector3.ZERO
	var hits: Array[Dictionary] = []
	trig.triggered.connect(func(ctx: Dictionary) -> void: hits.append(ctx))

	var body := _make_body(2, "player", Vector3(50, 0, 0))
	var wrong := _make_body(4, "enemies", Vector3(60, 0, 0))
	await _physics_frames(4)
	_check(hits.is_empty(), "no fire before entry")

	wrong.global_position = Vector3.ZERO  # enemy enters a PLAYER-filtered trigger
	await _physics_frames(4)
	_check(hits.is_empty(), "filter rejects non-player body")
	wrong.global_position = Vector3(60, 0, 0)
	await _physics_frames(4)

	body.global_position = Vector3.ZERO
	await _physics_frames(4)
	_check(hits.size() == 1, "fired once on player entry")
	if hits.size() >= 1:
		var ctx: Dictionary = hits[0]
		_check(ctx.get("activator") == body, "context.activator is the entering body")
		_check(str(ctx.get("mode")) == "ENTER", "context.mode == ENTER")
		_check(int(ctx.get("fire_count", 0)) == 1, "context.fire_count == 1")

	body.global_position = Vector3(50, 0, 0)
	await _physics_frames(3)
	body.global_position = Vector3.ZERO
	await _physics_frames(4)
	_check(hits.size() == 1, "one_shot did not refire on re-entry")

	trig.queue_free()
	body.queue_free()
	wrong.queue_free()
	await _physics_frames(2)


# ---------------------------------------------------------------------------
# (b) NOISE
# ---------------------------------------------------------------------------
func _test_noise_trigger() -> void:
	print("[b] NOISE trigger")
	var trig := MissionTrigger.new()
	trig.mode = MissionTrigger.Mode.NOISE
	trig.activator_filter = MissionTrigger.ActivatorFilter.ANY
	trig.noise_radius = 25.0
	add_child(trig)
	trig.global_position = Vector3(200, 0, 0)
	var hits: Array[Dictionary] = []
	trig.triggered.connect(func(ctx: Dictionary) -> void: hits.append(ctx))
	await _physics_frames(1)

	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(260, 0, 0), 0)  # 60m out
	await _physics_frames(2)
	_check(hits.is_empty(), "deaf to noise outside radius")

	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(210, 0, 0), 0)  # 10m out
	await _physics_frames(2)
	_check(hits.size() == 1, "hears noise inside radius")
	if hits.size() >= 1:
		var ctx: Dictionary = hits[0]
		_check(int(ctx.get("noise_type", -1)) == NoiseBus.NoiseType.GUNSHOT, "context.noise_type == GUNSHOT")
		_check(ctx.get("noise_position") == Vector3(210, 0, 0), "context.noise_position honest")

	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(210, 0, 0), 0)
	await _physics_frames(2)
	_check(hits.size() == 1, "one_shot noise trigger spent after firing")

	trig.queue_free()
	await _physics_frames(2)


# ---------------------------------------------------------------------------
# (c) 4-step sequence completes
# ---------------------------------------------------------------------------
func _test_sequence_completes() -> void:
	print("[c] sequence wait/move/signal/hand_off completes")
	var mock := MockAgent.new()
	mock.name = "MockActorC"
	add_child(mock)
	var seq := ScriptedSequence.new()
	add_child(seq)
	var st: Array[Dictionary] = [
		{"type": "wait", "seconds": 0.15},
		{"type": "move", "agent": mock.get_path(), "to": Vector3(3, 0, 3)},
		{"type": "signal", "name": "beat_done", "data": {"beat": 1}},
		{"type": "hand_off"},
	]
	seq.steps = st

	var sigs: Array = []
	seq.sequence_signal.connect(func(sig_name: StringName, data: Dictionary) -> void:
		sigs.append([sig_name, data]))
	var done: Array = []
	seq.completed.connect(func() -> void: done.append(true))
	var inter: Array = []
	seq.interrupted.connect(func(reason: String) -> void: inter.append(reason))
	var released: Array = []
	seq.handed_off.connect(func(agents: Array[Node]) -> void: released.append(agents))

	seq.start()
	await _await_until(func() -> bool: return not done.is_empty(), 3.0)
	_check(not done.is_empty(), "completed emitted")
	_check(inter.is_empty(), "no interruption on a clean run")
	_check(mock.moved_to == Vector3(3, 0, 3), "move step drove the agent hook")
	_check(sigs.size() == 1 and sigs[0][0] == StringName("beat_done"), "custom signal emitted")
	if sigs.size() == 1:
		var data: Dictionary = sigs[0][1]
		_check(int(data.get("beat", 0)) == 1, "signal payload intact")
	_check(mock.hand_off_count == 1, "hand_off released the agent")
	_check(released.size() == 1, "handed_off emitted with the cast")

	seq.queue_free()
	mock.queue_free()
	await _physics_frames(2)


# ---------------------------------------------------------------------------
# (d) damage mid-sequence aborts to hand_off
# ---------------------------------------------------------------------------
func _test_damage_aborts() -> void:
	print("[d] damage mid-sequence aborts to hand_off")
	var mock := MockAgent.new()
	mock.name = "MockActorD"
	add_child(mock)
	var seq := ScriptedSequence.new()
	add_child(seq)
	var st: Array[Dictionary] = [
		{"type": "wait", "seconds": 10.0},
		{"type": "signal", "name": "never_reached"},
	]
	seq.steps = st
	var cast: Array[NodePath] = [mock.get_path()]
	seq.cast_paths = cast

	var sigs: Array = []
	seq.sequence_signal.connect(func(_sig_name: StringName, _data: Dictionary) -> void:
		sigs.append(true))
	var done: Array = []
	seq.completed.connect(func() -> void: done.append(true))
	var inter: Array = []
	seq.interrupted.connect(func(reason: String) -> void: inter.append(reason))

	seq.start()
	await _physics_frames(3)
	_check(seq.is_running(), "sequence running before the hit")
	mock.take_damage(12)  # agent stayed mortal; the hit collapses the script
	await _physics_frames(3)
	_check(inter.size() == 1, "interrupted emitted on cast damage")
	_check(mock.hand_off_count == 1, "automatic hand_off on damage")
	_check(not seq.is_running(), "sequence stopped")
	await _physics_frames(20)  # give the dead wait loop time to prove it stays dead
	_check(done.is_empty(), "completed never emitted after abort")
	_check(sigs.is_empty(), "steps after the abort never ran")

	seq.queue_free()
	mock.queue_free()
	await _physics_frames(2)


# ---------------------------------------------------------------------------
# (e) spawn_prop combatant guard
# ---------------------------------------------------------------------------
func _test_spawn_prop_guard() -> void:
	print("[e] spawn_prop refuses combatants")
	var bad_root := Node3D.new()
	bad_root.name = "FakeVC"
	bad_root.add_to_group("enemies", true)  # persistent - survives pack()
	var bad_scene := PackedScene.new()
	bad_scene.pack(bad_root)
	bad_root.free()

	var good_root := Node3D.new()
	good_root.name = "CrateProp"
	var good_scene := PackedScene.new()
	good_scene.pack(good_root)
	good_root.free()

	var holder := Node3D.new()
	add_child(holder)
	var seq := ScriptedSequence.new()
	add_child(seq)
	seq.prop_parent_path = holder.get_path()
	var st: Array[Dictionary] = [
		{"type": "spawn_prop", "scene": bad_scene, "position": Vector3(1, 0, 1)},
		{"type": "spawn_prop", "scene": good_scene, "position": Vector3(2, 0, 2)},
		{"type": "hand_off"},
	]
	seq.steps = st
	var done: Array = []
	seq.completed.connect(func() -> void: done.append(true))

	seq.start()
	await _await_until(func() -> bool: return not done.is_empty(), 3.0)
	_check(not done.is_empty(), "sequence completed past the refused step")
	_check(holder.get_child_count() == 1, "combatant scene refused, prop scene spawned")
	if holder.get_child_count() == 1:
		var prop := holder.get_child(0) as Node3D
		_check(prop != null and prop.name == "CrateProp", "survivor is the innocent prop")
		_check(prop != null and prop.global_position == Vector3(2, 0, 2), "prop placed at step position")

	seq.queue_free()
	holder.queue_free()
	await _physics_frames(2)
