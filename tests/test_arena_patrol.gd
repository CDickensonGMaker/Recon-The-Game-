## test_arena_patrol.gd - headless probe for the PATROL -> ENGAGEMENT arena scenario.
## Asserts (a) both sides start in PATROL/IDLE, not COMBAT; (b) both reach COMBAT
## emergently through the perception path; (c) start force ~16-18/side; (d) a wave
## adds 16-26/side; (e) nav bakes and no unit lands off-map or in a wall.
## Run: godot --headless --path . res://tests/test_arena_patrol.tscn
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")
const MAX_SECONDS: float = 90.0


## Captures [NAV] warnings. A count of 0 is the "everyone landed on the mesh" proof -
## but ONLY once the count can actually rise.
##
## IT COULD NOT. push_warning() routes to Logger._log_error, NOT _log_message, and
## _log_error was stubbed `pass` - so this counter was structurally pinned at 0 while
## nav_router.gd:120 fired 18 warnings in the same run. The probe then printed
## "[NAV] warnings: 0" and PASSED. A dead capture and a clean run are indistinguishable
## from the outside, and this file called the dead one proof.
class WarningCapture extends Logger:
	var count: int = 0
	func _log_message(message: String, _verbose: bool) -> void:
		if message.contains("[NAV]"):
			count += 1
	## Godot hands push_warning's text through the `code`/`rationale` pair; check both
	## rather than betting on which one carries it.
	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_backtraces: Array) -> void:
		if code.contains("[NAV]") or rationale.contains("[NAV]"):
			count += 1


var _arena: Node3D
var _elapsed: float = 0.0
var _failures: int = 0
var _nav_capture: WarningCapture = null

var _start_checked: bool = false
var _start_us: int = 0
var _start_vc: int = 0
var _start_combat: int = -1

var _us_combat_t: float = -1.0
var _vc_combat_t: float = -1.0
var _saw_vc_ramp: bool = false
var _max_vc_awareness: float = 0.0

var _wave_us: int = 0
var _wave_vc: int = 0
var _wave_done: bool = false


func _ready() -> void:
	print("=== Arena Patrol -> Engagement Probe ===")
	_nav_capture = WarningCapture.new()
	OS.add_logger(_nav_capture)
	_arena = ArenaScript.new()
	_arena.set("patrol_mode", true)
	_arena.set("hot_start", false)
	_arena.set("us_squads_active", 3)
	_arena.set("vc_squads_active", 3)
	_arena.set("men_per_squad", 6)
	_arena.set("us_reserve_squads", 0)
	_arena.set("vc_reserve_squads", 0)
	_arena.set("round_max_seconds", MAX_SECONDS + 30.0)
	_arena.set("spawn_player", false)
	_arena.set("spawn_hud", false)
	_arena.set("bench_dressing", false)
	# Build it the way it SHIPS: scenes/levels/ai_stress_arena.tscn sets both of these
	# true. ArenaScript.new() otherwise takes the `false` defaults (ai_stress_arena.gd
	# :170-171), which is a configuration that never ships - see the comment on check
	# (e) below for why that matters to the nav-warning signal.
	_arena.set("spawn_cover", true)
	_arena.set("spawn_vegetation", true)
	add_child(_arena)


func _exit_tree() -> void:
	if _nav_capture != null:
		OS.remove_logger(_nav_capture)
		_nav_capture = null


func _process(delta: float) -> void:
	_elapsed += delta

	# Give the arena its nav bake + 2 physics frames + spawn before sampling.
	if not _start_checked and _elapsed >= 1.5:
		_start_checked = true
		_start_us = _living(true)
		_start_vc = _living(false)
		_start_combat = _in_combat(true) + _in_combat(false)

	if not _start_checked:
		return

	# Track the patrol -> combat transition and the VC awareness ramp.
	for squad in _arena.get("_vc_squads"):
		for e in squad:
			if not is_instance_valid(e) or e.is_dead():
				continue
			if e.alert_tier != EnemyBase.AlertTier.COMBAT:
				_max_vc_awareness = maxf(_max_vc_awareness, e.awareness)
				if e.alert_tier == EnemyBase.AlertTier.SUSPICIOUS or e.awareness > 0.1:
					_saw_vc_ramp = true
			elif _vc_combat_t < 0.0:
				_vc_combat_t = _elapsed
	if _us_combat_t < 0.0 and _in_combat(true) > 0:
		_us_combat_t = _elapsed

	# Once both sides have reached COMBAT, verify a reinforcement wave and finish.
	if _us_combat_t >= 0.0 and _vc_combat_t >= 0.0 and not _wave_done:
		_wave_done = true
		_wave_us = _arena.call("debug_spawn_wave", true)
		_wave_vc = _arena.call("debug_spawn_wave", false)
		_finish()
		return

	if _elapsed >= MAX_SECONDS:
		_finish()


func _living(us: bool) -> int:
	var n: int = 0
	for squad in _arena.get("_us_squads" if us else "_vc_squads"):
		for a in squad:
			if is_instance_valid(a) and not a.is_dead():
				n += 1
	return n


func _in_combat(us: bool) -> int:
	var n: int = 0
	for squad in _arena.get("_us_squads" if us else "_vc_squads"):
		for a in squad:
			if is_instance_valid(a) and not a.is_dead() and a.current_state == Enums.AIState.COMBAT:
				n += 1
	return n


func _off_map_or_bad() -> int:
	var half: float = float(_arena.ARENA) * 0.5 - 1.0
	var bad: int = 0
	for us in [true, false]:
		for squad in _arena.get("_us_squads" if us else "_vc_squads"):
			for a in squad:
				if not is_instance_valid(a) or a.is_dead():
					continue
				var p: Vector3 = a.global_position
				if absf(p.x) > half or absf(p.z) > half or p.y < -2.0 or p.y > 8.0:
					bad += 1
	return bad


func _finish() -> void:
	var nav_region: NavigationRegion3D = _arena.get("_nav_region")
	var nav_polys: int = nav_region.navigation_mesh.get_polygon_count() if nav_region != null else 0
	var off_map: int = _off_map_or_bad()
	var nav_warnings: int = _nav_capture.count if _nav_capture != null else 0

	print("--- results ---")
	print("start force: US %d / VC %d (combat at start: %d)" % [_start_us, _start_vc, _start_combat])
	print("US reached COMBAT at: %.1fs" % _us_combat_t)
	print("VC reached COMBAT at: %.1fs" % _vc_combat_t)
	print("VC awareness ramp seen: %s (peak pre-combat awareness %.2f)" % [_saw_vc_ramp, _max_vc_awareness])
	print("reinforcement wave: US %d men / VC %d men" % [_wave_us, _wave_vc])
	print("nav polys: %d | off-map/bad-Y units: %d | [NAV] warnings: %d" % [nav_polys, off_map, nav_warnings])

	# (a) both sides start out of combat
	if _start_combat != 0:
		_failures += 1
		print("FAIL (a): %d units already in COMBAT at start" % _start_combat)
	# (c) start force 16-18 per side
	if _start_us < 16 or _start_us > 18:
		_failures += 1
		print("FAIL (c): US start force %d not in 16-18" % _start_us)
	if _start_vc < 16 or _start_vc > 18:
		_failures += 1
		print("FAIL (c): VC start force %d not in 16-18" % _start_vc)
	# (b) both sides reach COMBAT via the perception path
	if _us_combat_t < 0.0:
		_failures += 1
		print("FAIL (b): US never reached COMBAT")
	if _vc_combat_t < 0.0:
		_failures += 1
		print("FAIL (b): VC never reached COMBAT")
	if not _saw_vc_ramp:
		_failures += 1
		print("FAIL (b): VC never showed an awareness ramp before COMBAT (looks pre-forced)")
	# (d) wave adds 16-26 per side
	if _wave_us < 16 or _wave_us > 26:
		_failures += 1
		print("FAIL (d): US wave %d not in 16-26" % _wave_us)
	if _wave_vc < 16 or _wave_vc > 26:
		_failures += 1
		print("FAIL (d): VC wave %d not in 16-26" % _wave_vc)
	# (e) nav baked and nobody off-map / in a wall
	# POLY COUNT IS NOT THE SIGNAL, and a floor here would fail forever on a correct bake:
	# even with spawn_cover/spawn_vegetation forced true above (matching the shipped
	# .tscn), a sparse arena can still triangulate to very few polygons. The honest
	# signal is the warning count below - a path that failed - not how many triangles
	# the mesh has.
	if nav_polys <= 0:
		_failures += 1
		print("FAIL (e): navmesh did not bake (0 polys)")
	if off_map > 0:
		_failures += 1
		print("FAIL (e): %d units off-map or at a bad height" % off_map)
	if nav_warnings > 0:
		_failures += 1
		print("FAIL (e): %d [NAV] warnings (a spawn missed the navmesh)" % nav_warnings)

	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
