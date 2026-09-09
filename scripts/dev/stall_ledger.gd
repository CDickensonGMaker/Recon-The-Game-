## stall_ledger.gd - FRAME STALL ATTRIBUTION. Answers "what was actually IN that 412ms
## physics step", by name, with microseconds, instead of by guess.
##
## WHY THIS EXISTS (2026-09-08). The shipped `--print-fps` row quotes
## `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS`. Both are read straight out of
## Godot's `main.cpp` and BOTH ARE MAXIMA OVER A ONE-SECOND BUCKET, not per-frame values:
##
##     process_max = MAX(process_ticks, process_max);              // main.cpp, every frame
##     ...
##     if (frame > 1000000) {                                      // once per SECOND
##         performance->set_process_time(USEC_TO_SEC(process_max));
##         performance->set_physics_process_time(USEC_TO_SEC(physics_process_max));
##         process_max = 0; physics_process_max = 0;
##     }
##
## So "process 43ms" means "the worst single idle step in the last completed second",
## which is exactly why a 43ms `process` sits happily beside a 44 fps average. It is NOT
## a per-frame cost and it must never be multiplied by the frame count.
##
## WORSE, and the reason this file measures its own spans: the timed region for
## `process_ticks` in `main.cpp` runs from before `MainLoop::process` to after
## `RenderingServer::draw()`, and therefore CONTAINS:
##     MainLoop::process (the _process callbacks)  +  message_queue->flush()
##   + NavigationServer2D::process + NavigationServer3D::process
##   + RenderingServer::sync()      <-- BLOCKS on the render thread
##   + RenderingServer::draw()      <-- the whole visual command flush
## `TIME_PROCESS` is therefore NOT "game thread" and NOT "script time". When the renderer
## is the bottleneck the main thread's wait for it lands inside this number. Any claim of
## the form "the game thread is the wall, look at process ms" is unproven by that column.
##
## `TIME_PHYSICS_PROCESS` has the same bucket-max semantics; its span is one physics
## SUB-STEP and contains the _physics_process callbacks, two message-queue flushes,
## `PhysicsServer3D::step()` (Jolt) and `iteration_end()`.
##
## WHAT THIS FILE MEASURES INSTEAD - all per-frame, all honest:
##   script_span  : first-priority sentinel to last-priority sentinel = the time the
##                  SceneTree spent running _process / _physics_process callbacks.
##                  Print the Godot bucket-maxima BESIDE it to see roughly how much of a
##                  step was engine rather than script - but never subtract one from the
##                  other and quote the result: they are different time bases.
##   causes       : named spans a caller opened with begin()/end(), with the worst single
##                  call and the total, plus a full breakdown OF THE WORST STEP ITSELF.
##
## COST WHEN OFF: one static bool test per call. It is off unless --print-fps is passed.
class_name StallLedger
extends RefCounted

## A step at or above this is a STALL and gets its cause breakdown snapshotted.
const STALL_US: int = 20000  ## 20ms - two thirds of a 30Hz physics budget

static var _on: bool = false

## cause -> accumulated usec over the window (nested causes double-count into parents)
static var _total: Dictionary = {}
static var _count: Dictionary = {}
static var _worst_call: Dictionary = {}
static var _stack: Array = []

## Per-step accumulation, snapshotted when a step turns out to be the window's worst.
static var _step: Dictionary = {}
static var _phys_t0: int = 0
static var _idle_t0: int = 0

static var _worst_phys_us: int = 0
static var _worst_phys_causes: Dictionary = {}
static var _worst_idle_us: int = 0
static var _worst_idle_causes: Dictionary = {}
static var _phys_steps: int = 0
static var _phys_total_us: int = 0
static var _stalls: int = 0


static func enable() -> void:
	_on = true


## Open a named span. MUST be paired with end() on every path, including early returns
## and error branches - an unclosed begin() charges its whole cause to the next end().
static func begin(cause: String) -> void:
	if not _on:
		return
	_stack.push_back(cause)
	_stack.push_back(Time.get_ticks_usec())


static func end() -> void:
	if not _on or _stack.size() < 2:
		return
	var t0: int = int(_stack.pop_back())
	var cause: String = String(_stack.pop_back())
	var dt: int = Time.get_ticks_usec() - t0
	_total[cause] = int(_total.get(cause, 0)) + dt
	_count[cause] = int(_count.get(cause, 0)) + 1
	_worst_call[cause] = maxi(int(_worst_call.get(cause, 0)), dt)
	_step[cause] = int(_step.get(cause, 0)) + dt


static func physics_frame_begin() -> void:
	if not _on:
		return
	_step.clear()
	_phys_t0 = Time.get_ticks_usec()


static func physics_frame_end() -> void:
	if not _on:
		return
	var dt: int = Time.get_ticks_usec() - _phys_t0
	_phys_steps += 1
	_phys_total_us += dt
	if dt >= STALL_US:
		_stalls += 1
	if dt > _worst_phys_us:
		_worst_phys_us = dt
		_worst_phys_causes = _step.duplicate()


static func idle_frame_begin() -> void:
	if not _on:
		return
	_step.clear()
	_idle_t0 = Time.get_ticks_usec()


static func idle_frame_end() -> void:
	if not _on:
		return
	var dt: int = Time.get_ticks_usec() - _idle_t0
	if dt > _worst_idle_us:
		_worst_idle_us = dt
		_worst_idle_causes = _step.duplicate()


## Causes sorted by total, "name total/worst xN", top `limit`.
static func _rank(d: Dictionary, limit: int) -> String:
	var keys: Array = d.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(d[a]) > int(d[b]))
	var out: PackedStringArray = []
	for i in range(mini(limit, keys.size())):
		var k: String = keys[i]
		out.append("%s %.1f/%.1fms x%d" % [k, float(d[k]) / 1000.0,
			float(_worst_call.get(k, 0)) / 1000.0, int(_count.get(k, 0))])
	return ", ".join(out) if out.size() > 0 else "nothing instrumented fired"


static func _rank_step(d: Dictionary, limit: int) -> String:
	var keys: Array = d.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(d[a]) > int(d[b]))
	var out: PackedStringArray = []
	for i in range(mini(limit, keys.size())):
		out.append("%s %.1fms" % [keys[i], float(d[keys[i]]) / 1000.0])
	return ", ".join(out) if out.size() > 0 else "UNATTRIBUTED - no instrumented cause ran in it"


## The window report. Every number here is measured by this file, per frame, in the
## caller's own time base - none of it is a Performance monitor bucket-max.
static func report() -> String:
	if not _on:
		return ""
	var mean_phys: float = (float(_phys_total_us) / float(maxi(1, _phys_steps))) / 1000.0
	var lines: PackedStringArray = []
	## An instrument that measured nothing must SAY SO, never print a confident 0.00ms.
	if _phys_steps == 0:
		lines.append("[STALL] INSTRUMENT FAILED: the frame sentinels never ticked, so no"
			+ " script span was measured. The named-cause totals below are still valid;"
			+ " the span lines are not. Do not quote them.")
	lines.append(("[STALL] physics script span: mean %.2fms, WORST %.2fms over %d steps"
		+ " | %d steps >= %.0fms")
		% [mean_phys, float(_worst_phys_us) / 1000.0, _phys_steps, _stalls,
			float(STALL_US) / 1000.0])
	lines.append("[STALL]   worst physics step was: %s" % _rank_step(_worst_phys_causes, 6))
	lines.append("[STALL] idle script span: WORST %.2fms | worst idle step was: %s"
		% [float(_worst_idle_us) / 1000.0, _rank_step(_worst_idle_causes, 6)])
	lines.append("[STALL] window totals: %s" % _rank(_total, 8))
	return "\n".join(lines)


static func reset_window() -> void:
	_total.clear()
	_count.clear()
	_worst_call.clear()
	_worst_phys_us = 0
	_worst_phys_causes.clear()
	_worst_idle_us = 0
	_worst_idle_causes.clear()
	_phys_steps = 0
	_phys_total_us = 0
	_stalls = 0
	_stack.clear()
