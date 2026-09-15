## beat_book.gd - the authored beats of the demo day, read from data/beats/*.json and played on
## the existing runner: MissionTrigger observes, ScriptedSequence performs, the player keeps every
## control he had and the Pillar-3 abort stays intact (council 2026-09-14, ruling 6).
##
## A beat file: {id, trigger {kind: "enter"|"poll", radius, place, fallback_place, name,
## window {sim_from, sim_to}}, lines {key: line}, steps [ScriptedSequence step shapes, with
## "line_key" resolved to "line" and "agent": "nearest_garrison" resolved to a live man]}.
## Places: "fsb_work:<type>" (a work-marker family under the seated compound), "parapet" (the
## nearest FSB_PARAPET_GROUP member to the player), "ford:<F1|F2|F3>" and "way_station" (the
## demo plan's stream, plan_demo_world). Once per sim day per id; `"once": true` on the
## trigger is once per run. bark steps go out on director.toast. Every line is grepped by
## tests/test_hearts_felt.gd (lines_of_record). Actors: "nearest_garrison[:occupation]",
## "squad:point" (the point man), "squad:second" (the man behind him). A "signal" step named
## "runner_sees" hands the far-bank runner (mission_generator's FarBankRunner) the sight of
## the squad: the existing informer clock, so his escape lands on informer/<ville>/talked.
class_name BeatBook
extends Node

const BEATS_DIR: String = "res://data/beats"
const POLL_S: float = 1.0
const ENTER_COOLDOWN_S: float = 5.0
## "A probe man inside the wire" for the dusk beat: a live enemy this close to the compound
## centre, or the siege's own inside count.
const WIRE_GUARD_M: float = 70.0

var world: GameWorld = null
var director: FieldDirector = null
var plan: Dictionary = {}
var beats: Dictionary = {}       ## id -> the parsed file
var fired_day: Dictionary = {}   ## id -> sim_day it played
var fire_count: Dictionary = {}  ## id -> times it played (the probe's negative)
var _triggers: Dictionary = {}   ## id -> MissionTrigger
var _poll: float = 0.0


static func attach(game_world: GameWorld, field_director: FieldDirector,
		patrol_plan: Dictionary = {}) -> BeatBook:
	var book := BeatBook.new()
	book.name = "BeatBook"
	book.world = game_world
	book.director = field_director
	book.plan = patrol_plan
	game_world.add_child(book)
	book.add_to_group("beat_book")
	return book


## Every bark line in every beat file, keyed "<id>.<key>" - the §2a guard's table.
static func lines_of_record() -> Dictionary:
	var out: Dictionary = {}
	for beat: Dictionary in load_all().values():
		var lines: Dictionary = beat.get("lines", {})
		for k in lines.keys():
			out["%s.%s" % [str(beat.get("id", "?")), str(k)]] = str(lines[k])
	return out


static func load_all() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(BEATS_DIR)
	if dir == null:
		return out
	for fname in dir.get_files():
		if not fname.ends_with(".json"):
			continue
		var f := FileAccess.open("%s/%s" % [BEATS_DIR, fname], FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if not (parsed is Dictionary):
			push_warning("[BEAT] %s does not parse" % fname)
			continue
		var beat: Dictionary = parsed
		var id: String = str(beat.get("id", ""))
		if id.is_empty():
			continue
		out[id] = beat
	return out


func _ready() -> void:
	beats = load_all()
	for id: String in beats.keys():
		_arm(id)
	print("[BEAT] book open: %s" % ", ".join(beats.keys()))


func _arm(id: String) -> void:
	var beat: Dictionary = beats[id]
	var trig: Dictionary = beat.get("trigger", {})
	if str(trig.get("kind", "")) != "enter":
		return
	var place: Vector3 = _resolve_place(str(trig.get("place", "")))
	if place == Vector3.ZERO:
		place = _resolve_place(str(trig.get("fallback_place", "")))
	if place == Vector3.ZERO:
		print("[BEAT] %s degraded: no place for %s" % [id, str(trig.get("place", ""))])
		return
	var mt := MissionTrigger.new()
	mt.name = "BeatTrigger_%s" % id
	mt.mode = MissionTrigger.Mode.ENTER
	mt.activator_filter = MissionTrigger.ActivatorFilter.PLAYER
	mt.one_shot = false
	mt.cooldown = ENTER_COOLDOWN_S
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(trig.get("radius", 8.0))
	shape.shape = sphere
	mt.add_child(shape)
	add_child(mt)
	mt.global_position = place
	mt.triggered.connect(func(_ctx: Dictionary) -> void:
		if _in_window(beat):
			fire(id))
	_triggers[id] = mt
	print("[BEAT] %s armed at %s (r %.0f)" % [id, place, sphere.radius])


func _resolve_place(spec: String) -> Vector3:
	if director == null or director.fsb_center == Vector3.ZERO:
		return Vector3.ZERO
	if spec.begins_with("fsb_work:"):
		var at: Vector3 = SitePlanner.fsb_work_marker_world(director.fsb_center, spec.trim_prefix("fsb_work:"))
		if at != Vector3.ZERO and world != null:
			at.y = world.floor_y(at + Vector3.UP * 0.5)
		return at
	if spec.begins_with("ford:"):
		var fords: Dictionary = (plan.get("stream", {}) as Dictionary).get("fords", {})
		return fords.get(spec.trim_prefix("ford:"), Vector3.ZERO)
	if spec == "way_station":
		return (plan.get("way_station", {}) as Dictionary).get("center", Vector3.ZERO)
	return Vector3.ZERO


func _in_window(beat: Dictionary) -> bool:
	var win: Dictionary = (beat.get("trigger", {}) as Dictionary).get("window", {})
	if win.is_empty():
		return true
	var h: float = SimClock.sim_hour
	return h >= float(win.get("sim_from", 0.0)) and h < float(win.get("sim_to", 24.0))


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_S
	for id: String in beats.keys():
		var trig: Dictionary = (beats[id] as Dictionary).get("trigger", {})
		if str(trig.get("kind", "")) != "poll" or int(fired_day.get(id, -1)) == SimClock.sim_day:
			continue
		if not _in_window(beats[id]):
			continue
		if _poll_condition(str(trig.get("name", "")), trig):
			fire(id)


func _poll_condition(cond: String, trig: Dictionary) -> bool:
	match cond:
		"first_flare_after_seam":
			return _first_flare_after_seam(float(trig.get("radius", 40.0)))
		"squad_bunched":
			return _squad_bunched(trig)
	return false


## The point man within `radius` of the place and at least `bunch_count` living squad men
## (him included) inside `bunch_radius` of it - a file closed up at a crossing.
func _squad_bunched(trig: Dictionary) -> bool:
	var place: Vector3 = _resolve_place(str(trig.get("place", "")))
	if place == Vector3.ZERO:
		return false
	var point: AllyBase = _point_man()
	if point == null:
		return false
	var flat := Vector3(1.0, 0.0, 1.0)
	if ((point.global_position - place) * flat).length() > float(trig.get("radius", 6.0)):
		return false
	var bunch_r: float = float(trig.get("bunch_radius", 12.0))
	var n: int = 0
	for m in _squad_men():
		if ((m.global_position - place) * flat).length() <= bunch_r:
			n += 1
	return n >= int(trig.get("bunch_count", 4))


func _squad_men() -> Array[AllyBase]:
	var out: Array[AllyBase] = []
	if director == null or director.squad_system == null or not is_instance_valid(director.squad_system):
		return out
	for m: AllyBase in director.squad_system.members:
		if m == null or not is_instance_valid(m) or not m.is_inside_tree():
			continue
		if m.has_method("is_dead") and bool(m.call("is_dead")):
			continue
		out.append(m)
	return out


func _point_man() -> AllyBase:
	var men: Array[AllyBase] = _squad_men()
	for m in men:
		if m.point_slot:
			return m
	return men[0] if not men.is_empty() else null


## The man behind the point man: the living member nearest him who is not him.
func _second_man() -> AllyBase:
	var point: AllyBase = _point_man()
	if point == null:
		return null
	var best: AllyBase = null
	var best_d: float = INF
	for m in _squad_men():
		if m == point:
			continue
		var d: float = m.global_position.distance_to(point.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


## The far-bank runner SEES the bunched squad: the informer clock starts on him exactly as it
## would had he seen the player himself (civilian.gd's 25 s), so catching him inside it stops
## the word and letting him go notes informer/<ville>/talked. Nothing here is an atrocity;
## the hook is the one entry the clock has.
func _runner_sees() -> void:
	var player: Node3D = GameManager.player as Node3D
	if player == null:
		return
	for n in get_tree().get_nodes_in_group("far_bank_runner"):
		var civ := n as Civilian
		if civ == null or not is_instance_valid(civ):
			continue
		civ.on_atrocity_witnessed(player.global_position)
		print("[BEAT] the runner saw the squad at %s" % player.global_position)
		return


## The seam has passed, the wire is lit (a flare up or the garrison stood to), the player is
## at the parapet, and NO probe man is inside the wire - a vision confirmed is a monster.
func _first_flare_after_seam(radius: float) -> bool:
	if not MissionWeather.is_night or director == null or not is_instance_valid(director):
		return false
	var lit: bool = not IllumFlare.active_flares.is_empty() or director._garrison_stood_to
	if not lit:
		return false
	if probe_man_inside_wire():
		return false
	var player: Node3D = GameManager.player as Node3D
	if player == null:
		return false
	return _nearest_parapet_m(player.global_position) <= radius


func probe_man_inside_wire() -> bool:
	if director == null or not is_instance_valid(director):
		return false
	if director.siege != null and is_instance_valid(director.siege) and director.siege.inside_count() > 0:
		return true
	return director._hostile_within(director.fsb_center, WIRE_GUARD_M)


func _nearest_parapet_m(from: Vector3) -> float:
	var best: float = INF
	for n in get_tree().get_nodes_in_group(SitePlanner.FSB_PARAPET_GROUP):
		var seg := n as Node3D
		if seg == null or not is_instance_valid(seg) or not seg.is_inside_tree():
			continue
		best = minf(best, seg.global_position.distance_to(from))
	return best


## Play a beat now, bypassing its trigger (the probe's door). False when it already played
## today or the id is unknown.
func fire(id: String) -> bool:
	if not beats.has(id) or int(fired_day.get(id, -1)) == SimClock.sim_day:
		return false
	var trig: Dictionary = (beats[id] as Dictionary).get("trigger", {})
	if bool(trig.get("once", false)) and int(fire_count.get(id, 0)) > 0:
		return false
	fired_day[id] = SimClock.sim_day
	fire_count[id] = int(fire_count.get(id, 0)) + 1
	var beat: Dictionary = beats[id]
	var lines: Dictionary = beat.get("lines", {})
	var seq := ScriptedSequence.new()
	seq.name = "Beat_%s" % id
	add_child(seq)
	var steps: Array[Dictionary] = []
	for raw in (beat.get("steps", []) as Array):
		var step: Dictionary = (raw as Dictionary).duplicate()
		if step.has("line_key"):
			step["line"] = str(lines.get(str(step["line_key"]), ""))
			step.erase("line_key")
		if step.has("agent"):
			var actor: Node = _resolve_actor(str(step["agent"]))
			if actor == null:
				step.erase("agent")
			else:
				step["agent"] = actor.get_path()
		steps.append(step)
	seq.steps = steps
	seq.sequence_bark.connect(func(_agent: Node, line: String) -> void:
		if director != null and is_instance_valid(director):
			director.toast.emit(line))
	seq.sequence_signal.connect(func(signal_name: StringName, _data: Dictionary) -> void:
		if signal_name == &"runner_sees":
			_runner_sees())
	seq.completed.connect(seq.queue_free)
	seq.interrupted.connect(func(reason: String) -> void:
		print("[BEAT] %s interrupted: %s" % [id, reason])
		seq.queue_free())
	print("[BEAT] %s fires (sim %05.2f)" % [id, SimClock.sim_hour])
	seq.start()
	return true


## "nearest_garrison" or "nearest_garrison:<occupation>" - the living man closest to the
## player; anything else is a NodePath.
func _resolve_actor(spec: String) -> Node:
	if spec == "squad:point":
		return _point_man()
	if spec == "squad:second":
		return _second_man()
	if spec.begins_with("nearest_garrison"):
		var want: String = spec.trim_prefix("nearest_garrison").trim_prefix(":")
		var player: Node3D = GameManager.player as Node3D
		if player == null:
			return null
		var best: Node = null
		var best_d: float = INF
		for n in get_tree().get_nodes_in_group("firebase_garrison"):
			var man := n as Node3D
			if man == null or not is_instance_valid(man):
				continue
			if man.has_method("is_dead") and bool(man.call("is_dead")):
				continue
			if not want.is_empty() and str(man.get("occupation")) != want:
				continue
			var d: float = man.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = man
		return best
	return get_node_or_null(NodePath(spec))
