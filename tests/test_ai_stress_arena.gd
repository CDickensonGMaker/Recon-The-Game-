## test_ai_stress_arena.gd - headless probe for the AI Combat Stress Test Arena.
## Runs a small arena configuration for 15 seconds and asserts that both sides
## enter combat and suppression activates.
## Run: godot --headless --path . res://tests/test_ai_stress_arena.tscn
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")
const RUN_SECONDS: float = 15.0

## Captures push_warning output so the probe can assert the [NAV] warning
## count is 0 after the closest-point clamp fix. Restored on _exit_tree.
class WarningCapture extends Logger:
	var captured: Array[String] = []
	var prefix: String = ""

	func _log_message(message: String, _verbose: bool) -> void:
		if prefix.is_empty() or message.contains(prefix):
			captured.append(message)

	func _log_error(message: String, _func: String, _line: int, _file: String, _editor: String, _verbose: bool, _stack_idx: int, _backtrace: Array) -> void:
		pass

	func get_count() -> int:
		return captured.size()


var _arena: Node3D
var _elapsed: float = 0.0
var _failures: int = 0
var _saw_vc_combat: bool = false
var _saw_us_combat: bool = false
var _max_suppression: float = 0.0
var _nav_capture: WarningCapture = null


func _ready() -> void:
	print("=== AI Stress Arena Headless Probe ===")
	_nav_capture = WarningCapture.new()
	_nav_capture.prefix = "[NAV]"
	OS.add_logger(_nav_capture)
	_arena = ArenaScript.new()
	_arena.set("us_squads_active", 2)
	_arena.set("vc_squads_active", 2)
	_arena.set("us_reserve_squads", 0)
	_arena.set("vc_reserve_squads", 0)
	_arena.set("round_max_seconds", 30.0)
	_arena.set("spawn_player", false)
	_arena.set("spawn_hud", false)
	_arena.set("hot_start", true)
	add_child(_arena)
	await get_tree().process_frame


func _process(delta: float) -> void:
	_elapsed += delta
	_collect_metrics()
	if _elapsed >= RUN_SECONDS:
		_finish()


func _exit_tree() -> void:
	if _nav_capture != null:
		OS.remove_logger(_nav_capture)
		_nav_capture = null


func _collect_metrics() -> void:
	for squad in _arena.get("_vc_squads"):
		for e in squad:
			if not is_instance_valid(e):
				continue
			if not e.is_dead() and e.current_state == Enums.AIState.COMBAT:
				_saw_vc_combat = true
			_max_suppression = maxf(_max_suppression, e.suppression_level)
	for squad in _arena.get("_us_squads"):
		for a in squad:
			if not is_instance_valid(a):
				continue
			if not a.is_dead() and a.current_state == Enums.AIState.COMBAT:
				_saw_us_combat = true


func _finish() -> void:
	var nav_count: int = _nav_capture.get_count() if _nav_capture != null else 0
	print("VC combat seen: %s" % _saw_vc_combat)
	print("US combat seen: %s" % _saw_us_combat)
	print("Max suppression: %.2f" % _max_suppression)
	print("[NAV] warnings counted: %d" % nav_count)
	if not _saw_vc_combat:
		_failures += 1
		print("FAIL: no VC entered COMBAT")
	if not _saw_us_combat:
		_failures += 1
		print("FAIL: no US entered COMBAT")
	if _max_suppression < 0.1:
		_failures += 1
		print("FAIL: suppression did not activate")
	if nav_count > 0:
		_failures += 1
		print("FAIL: %d [NAV] warnings fired during the probe (expected 0 after fix)" % nav_count)
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
