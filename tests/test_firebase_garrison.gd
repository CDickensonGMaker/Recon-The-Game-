## test_firebase_garrison.gd - men live inside the wire.
## Asserts the firebase garrison spawns INSIDE the compound, wears US models,
## runs hour-driven military occupations, and is not the player's squad.
## Negative controls: village civilians must all be OUTSIDE the wire, and the
## garrison flag must actually change behavior (a villager panics at a gunshot,
## a garrison man does not).
## Run: godot --headless --path . res://tests/test_firebase_garrison.tscn
extends Node

const CivScript := preload("res://scripts/world/civilian.gd")
const SchedScript := preload("res://scripts/ai/civilian_schedules.gd")

const GARRISON_OCCUPATIONS: Array[String] = [
	"sentry", "sentry_night", "quartermaster", "gun_crew",
	"radioman", "mess_cook", "off_duty",
]
const MIN_MEN: int = 12
## Read from the planner, never restated here: a second copy of the ceiling is how
## the compound drifted to 29 men while this file still said 24.
const MAX_MEN: int = SitePlanner.FSB_GARRISON_MAX_MEN

var _failures := 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _run() -> void:
	_check_schedules()
	_check_flag_changes_behavior()
	await _check_world()
	if _failures == 0:
		print("test_firebase_garrison: PASS")
	else:
		print("test_firebase_garrison: %d FAILURES" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Every garrison occupation must actually move through the day. A template that
## returns one action for 24h is a statue with a job title.
func _check_schedules() -> void:
	for occ in GARRISON_OCCUPATIONS:
		var seen: Dictionary = {}
		var h: float = 0.0
		while h < 24.0:
			seen[SchedScript.action_for(occ, h)] = true
			h += 0.5
		if seen.size() < 3:
			_fail("occupation '%s' has only %d distinct actions across 24h" % [occ, seen.size()])
		if seen.has(SchedScript.ACTION_IDLE):
			_fail("occupation '%s' fell through to ACTION_IDLE - no template matched" % occ)
	# Negative control on the templates: an unknown occupation MUST fall through.
	if SchedScript.action_for("no_such_job", 12.0) != SchedScript.ACTION_IDLE:
		_fail("unknown occupation did not fall through to idle")
	# The two sentry shifts must genuinely differ, or the wire is empty at night.
	if SchedScript.action_for("sentry", 2.0) == SchedScript.action_for("sentry_night", 2.0):
		_fail("day and night sentries do the same thing at 02:00")
	if SchedScript.action_for("sentry_night", 2.0) != SchedScript.ACTION_WORK:
		_fail("nobody is standing the wire at 02:00")


## Negative control on the garrison flag: same class, same noise, opposite result.
func _check_flag_changes_behavior() -> void:
	var villager: Civilian = CivScript.new()
	var soldier: Civilian = CivScript.new()
	soldier.is_garrison = true
	add_child(villager)
	add_child(soldier)
	villager.global_position = Vector3.ZERO
	soldier.global_position = Vector3.ZERO
	villager._on_noise(NoiseBus.NoiseType.GUNSHOT, Vector3.ZERO, 50.0, 0)
	soldier._on_noise(NoiseBus.NoiseType.GUNSHOT, Vector3.ZERO, 50.0, 0)
	if villager.state == CivScript.CivState.WANDER:
		_fail("control villager ignored a gunshot at 0m - the control proves nothing")
	if soldier.state != CivScript.CivState.WANDER:
		_fail("garrison man panicked at a gunshot inside his own base")
	villager.queue_free()
	soldier.queue_free()


func _check_world() -> void:
	CampaignState.reset_campaign()
	var flow := GameFlow.new()
	add_child(flow)
	# GameFlow._ready() starts the default operation itself (game_flow.gd:27).
	# Beginning a second one here would build a second world and double every
	# population count this probe measures.
	var waited := 0.0
	while waited < 150.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null \
				and flow.squad != null and flow.squad.members.size() > 0:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null or flow.world.player == null:
		_fail("patrol world never came up")
		return
	await get_tree().create_timer(1.0).timeout

	var fsb: Node3D = _find_fsb(flow.world)
	if fsb == null:
		_fail("fsb_main not placed - cannot judge what is inside the wire")
		return
	var c: Vector3 = fsb.global_position
	var wire := Rect2(c.x - SitePlanner.FSB_HALF.x, c.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0)

	var men: Array[Node] = get_tree().get_nodes_in_group("firebase_garrison")

	if men.size() < MIN_MEN:
		_fail("only %d garrison men inside the wire (want >=%d)" % [men.size(), MIN_MEN])
	if men.size() > MAX_MEN:
		_fail("%d garrison men (want <=%d) - the firebase was populated twice" % [men.size(), MAX_MEN])

	# The squad array is typed; comparing a Civilian against it needs plain ids.
	var squad_ids: Dictionary = {}
	for sm in flow.squad.members:
		if sm != null:
			squad_ids[(sm as Object).get_instance_id()] = true

	var occupations_seen: Dictionary = {}
	for n in men:
		var m: Civilian = n as Civilian
		if m == null:
			_fail("a firebase_garrison member is not a Civilian")
			continue
		var xz := Vector2(m.global_position.x, m.global_position.z)
		if not wire.has_point(xz):
			_fail("garrison man at %s is OUTSIDE the compound %s" % [xz, wire])
		if not m.is_garrison:
			_fail("garrison man spawned without is_garrison")
		if m.actor == null or not CivScript.GARRISON_MEN.has(m.actor.unit):
			var got: String = m.actor.unit if m.actor != null else "<no actor>"
			_fail("garrison man wears '%s', not a US model" % got)
		if not GARRISON_OCCUPATIONS.has(m.occupation):
			_fail("garrison man has occupation '%s'" % m.occupation)
		if m._bt == null:
			_fail("garrison man never had build_bt() called - his schedule is inert")
		if m.working_point_pos == Vector3.ZERO:
			_fail("garrison man has no post to stand")
		occupations_seen[m.occupation] = true
		if squad_ids.has(m.get_instance_id()):
			_fail("a garrison man is IN THE SQUAD")
		if m.is_in_group("allies") or m.is_in_group("enemies"):
			_fail("a garrison man is a combatant")
	if occupations_seen.size() < 4:
		_fail("garrison covers only %d occupations - the base has no variety" % occupations_seen.size())

	# NEGATIVE CONTROL: the wire test must be able to FAIL. Village civilians run
	# the same class through the same spawn and must all be outside the compound.
	var villagers: int = 0
	var villagers_inside: int = 0
	for n in get_tree().get_nodes_in_group("civilians"):
		var v: Civilian = n as Civilian
		if v == null or v.is_in_group("firebase_garrison"):
			continue
		villagers += 1
		if wire.has_point(Vector2(v.global_position.x, v.global_position.z)):
			villagers_inside += 1
	if villagers == 0:
		_fail("no village civilians spawned - the outside-the-wire control proves nothing")
	elif villagers_inside > 0:
		_fail("%d of %d village civilians are inside the firebase" % [villagers_inside, villagers])


func _find_fsb(root: Node) -> Node3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("model_name") and str(n.get_meta("model_name")) == "fsb_main":
			return n as Node3D
		for ch in n.get_children():
			stack.append(ch)
	return null
