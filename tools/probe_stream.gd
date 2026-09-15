## probe_stream.gd - THE STREAM, THE WAY-STATION and THE CROSSING beat, headless (ADR-041
## thawed for the demo AO, Caleb 2026-09-15).
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --stream-probe --demo-map=1024 --test-save
##
## Attached to the live demo world by game_flow.gd under `--stream-probe`. Holds the stand-to
## off. Then:
##   1. the grid reads impassable at 20 points along the stream and passable at the three fords;
##   2. the way-station stamps three ways under three ledger bands (a deed noted, a re-stamp);
##   3. the crossing beat fires once on demand, its four lines go out once, the runner saw the
##      squad, and a second fire is refused.
## Exit 1 on any failure. At 512 the plan carries no stream and the probe says so and fails.
extends Node

const HmLedgerS := preload("res://scripts/world/hm_ledger.gd")
const SETTLE_S: float = 20.0
const LINE_WAIT_S: float = 16.0
const SAMPLES: int = 20

var _fail: int = 0
var _director: FieldDirector = null
var _toasts: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("\n=== STREAM PROBE ===")
	var waited: float = 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if _director == null:
			_director = get_tree().get_first_node_in_group("mission_director") as FieldDirector
			if _director != null:
				_director.stand_to_held = true
				_director.toast.connect(func(t: String) -> void: _toasts.append(t))
	if _director == null:
		print("  FAIL: no FieldDirector")
		_finish()
		return
	var book: BeatBook = get_tree().get_first_node_in_group("beat_book") as BeatBook
	_check(book != null, "the BeatBook rides the demo world")
	_check(book != null and book.plan.has("stream"),
		"the plan carries a stream at map %.0f (the 512 slice has no bank for one)" % GameFlow.demo_map_size())
	if book == null or not book.plan.has("stream"):
		_finish()
		return
	var world: GameWorld = get_tree().get_first_node_in_group("game_world") as GameWorld
	if world == null:
		world = get_parent() as GameWorld
	_check(world != null and world.gameplay_grid != null, "a world with a grid")
	if world == null or world.gameplay_grid == null:
		_finish()
		return
	_grid(world, book.plan.stream, book.plan.get("gate_pos", Vector3.ZERO) as Vector3)
	# The beat before the way-station: its hostile picket stands 28 m off F1 and a squad man
	# who sights it aborts the sequence (Pillar 3 - the cast stays mortal and reactive).
	await _beat(book)
	_way_station()
	_finish()


func _grid(world: GameWorld, stream: Dictionary, gate: Vector3) -> void:
	var grid: GameplayGrid = world.gameplay_grid
	var points: PackedVector2Array = stream.points
	var depths: PackedFloat32Array = stream.depths
	var deep: Array[int] = []
	for i in points.size():
		if depths[i] > MissionGenerator.FORD_DEPTH_M + 0.01:
			deep.append(i)
	var step: int = maxi(1, deep.size() / SAMPLES)
	var blocked: int = 0
	var sampled: int = 0
	var min_d: float = INF
	for k in range(0, deep.size(), step):
		if sampled >= SAMPLES:
			break
		var i: int = deep[k]
		var at := Vector3(points[i].x, 0.0, points[i].y)
		var d: float = grid.get_water_depth(at)
		min_d = minf(min_d, d)
		if not grid.is_position_passable(at) and d > GameplayGrid.WADE_DEPTH_M:
			blocked += 1
		sampled += 1
	_check(blocked == sampled, "the grid reads impassable across the stream at %d/%d points (shallowest %.2f m)"
		% [blocked, sampled, min_d])
	var fords: Dictionary = stream.fords
	for fname: String in ["F1", "F2", "F3"]:
		if not fords.has(fname):
			_check(false, "%s exists" % fname)
			continue
		var f: Vector3 = fords[fname]
		var d: float = grid.get_water_depth(f)
		_check(grid.is_position_passable(f) and d > 0.0 and d <= GameplayGrid.WADE_DEPTH_M,
			"%s is a wade at %.0f,%.0f (%.2f m, passable %s)" % [fname, f.x, f.z, d, grid.is_position_passable(f)])
	for fname: String in fords.keys():
		var f: Vector3 = fords[fname]
		var v := Vector2(f.x - _director.fsb_center.x, f.z - _director.fsb_center.z)
		print("  [STREAM] %s at %.0f,%.0f  %.0f m from the centre, bearing %.0f deg%s" % [
			fname, f.x, f.z, v.length(), fposmod(rad_to_deg(atan2(v.x, v.y)), 360.0),
			"" if gate == Vector3.ZERO else ", %.0f m from the gate" % Vector2(f.x - gate.x, f.z - gate.z).length()])


func _way_station() -> void:
	var ws: WayStation = get_tree().get_first_node_in_group("way_station") as WayStation
	_check(ws != null, "the way-station stands past the ville")
	if ws == null:
		return
	var key: int = HmLedgerS.place_key(ws.village)
	_check(ws.band == HmLedgerS.BAND_QUIET and ws._men == null and ws._cache == null,
		"quiet: a lean-to and rice sacks, nobody (band %s)" % ws.band)
	CampaignState.hearts.note("fire/%d/probe" % key, HmLedgerS.KIND_FIRE, key, SimClock.sim_hour, "stream probe")
	ws.restamp()
	_check(ws.band == HmLedgerS.BAND_WARY and ws._men != null and ws._men.enemy_count == WayStation.WARY_MEN
		and ws._cache != null, "wary after a fire deed: two men and a cache (band %s)" % ws.band)
	CampaignState.hearts.note("civ/%d/probe/killed" % key, HmLedgerS.KIND_KILLED, key, SimClock.sim_hour, "stream probe")
	ws.restamp()
	var near_ford: bool = ws._men != null and ws._men.global_position.distance_to(ws.covers) < 40.0
	_check(ws.band == HmLedgerS.BAND_HOSTILE and ws._men != null and ws._men.enemy_count == WayStation.HOSTILE_MEN
		and near_ford and ws._cache == null, "hostile after a killing: a picket of four covering F1 (band %s)" % ws.band)


func _beat(book: BeatBook) -> void:
	_check(book.beats.has("crossing"), "the crossing beat loaded (%s)" % ", ".join(book.beats.keys()))
	var player: Node3D = GameManager.player as Node3D
	var f1: Vector3 = (book.plan.stream as Dictionary).fords.get("F1", Vector3.ZERO)
	if player != null and f1 != Vector3.ZERO:
		player.global_position = f1 + Vector3.UP * 1.0
	await get_tree().create_timer(2.0).timeout
	for m: AllyBase in book._squad_men():
		var tgt: Node3D = m.target
		print("  [SQUAD] %s at %.0f,%.0f target %s" % [m.name, m.global_position.x, m.global_position.z,
			"-" if tgt == null else "%s at %.0f,%.0f" % [tgt.name, tgt.global_position.x, tgt.global_position.z]])
	var lines: Dictionary = (book.beats.get("crossing", {}) as Dictionary).get("lines", {})
	var before: Array[String] = _toasts.duplicate()
	_check(book.fire("crossing"), "crossing fires on demand")
	await get_tree().create_timer(LINE_WAIT_S).timeout
	for k in lines.keys():
		var line: String = str(lines[k])
		var n: int = _toasts.count(line) - before.count(line)
		_check(n == 1, "crossing.%s went out once (%d)" % [str(k), n])
	var runner: Civilian = get_tree().get_first_node_in_group("far_bank_runner") as Civilian
	_check(runner != null, "the far-bank runner stands in the world")
	if runner != null:
		_check(runner._inform_clock >= 0.0 or runner.state == Civilian.CivState.GONE,
			"the runner saw the squad and is running (clock %.1f, state %d)" % [runner._inform_clock, runner.state])
	_check(not book.fire("crossing"), "crossing refuses a second fire")


func _finish() -> void:
	if _fail == 0:
		print("=== STREAM PROBE PASS ===")
	else:
		print("=== STREAM PROBE FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
