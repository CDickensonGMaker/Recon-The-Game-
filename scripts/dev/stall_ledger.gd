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
##   causes       : named spans a caller opened with begin()/end(), reported BOTH inclusive
##                  and exclusive of nesting, with the worst single call and a full
##                  breakdown OF THE WORST STEP ITSELF. Only the exclusive column sums to
##                  the step; adding a parent to its own child counts the child twice.
##
## COST WHEN OFF: one static bool test per call. It is off unless --print-fps is passed.
class_name StallLedger
extends RefCounted

## A step at or above this is a STALL and gets its cause breakdown snapshotted.
const STALL_US: int = 20000  ## 20ms - two thirds of a 30Hz physics budget

static var _on: bool = false

## cause -> accumulated usec over the window. INCLUSIVE: a parent's total contains its
## children's. `terrain.crater` calls `terrain.chunk_rebuild`, so reading the two as
## independent costs double-counts the rebuild and inflates the frame it is blamed for.
static var _total: Dictionary = {}
## cause -> the same window, EXCLUSIVE of nested spans: the time spent in THIS cause and
## not in anything it called. Exclusive figures sum to the step; inclusive ones do not.
static var _excl: Dictionary = {}
static var _count: Dictionary = {}
static var _worst_call: Dictionary = {}
static var _stack: Array = []

## Per-step accumulation, snapshotted when a step turns out to be the window's worst.
static var _step: Dictionary = {}
static var _step_excl: Dictionary = {}
static var _phys_t0: int = 0
static var _idle_t0: int = 0

static var _worst_phys_us: int = 0
static var _worst_phys_causes: Dictionary = {}
static var _worst_phys_excl: Dictionary = {}
static var _worst_idle_us: int = 0
static var _worst_idle_causes: Dictionary = {}
static var _worst_idle_excl: Dictionary = {}
## THE MARKS (2026-09-11). Every window's worst idle step read 30-90 ms with NOTHING named,
## on both sides of the perf A/B: the span instruments only see code that calls begin/end,
## and the frame that hurt was spent somewhere that never does. FrameMark nodes sit as the
## first child of each subtree the sentinels bracket and stamp the clock as the SceneTree
## reaches them (tree order, priority 0), so the worst frame can be cut into "which subtree
## - and everything the engine ran inside it - took the time", named or not.
static var _marks: Array = []          # [[label, usec], ...] for the frame in flight
static var _worst_idle_marks: Array = []
static var _phys_steps: int = 0
static var _phys_total_us: int = 0
static var _stalls: int = 0
## Wall clock at the first begin and the last end of the window's physics steps. The sum of
## the spans and the elapsed wall between the first and last step answer different questions,
## and comparing them says WHICH clock is wrong when they disagree: spans > elapsed means a
## begin() was skipped and spans overlap; elapsed > window means the frame delta is clamped
## and the reported frame rate is optimistic.
static var _phys_first_us: int = 0
static var _phys_last_us: int = 0

## The MOST RECENT step, not the worst. A live overlay needs this frame's own script span
## in the SAME time base as the per-frame buckets printed beside it; the worst-step figures
## above are a window statistic and cannot be compared against a single frame's numbers.
static var _last_idle_us: int = 0
static var _last_phys_us: int = 0
## Instrument health. Not cleared by reset_window() - it answers "did the sentinels ever
## tick", which is a property of the run, not of the window.
static var _idle_steps_ever: int = 0


static func enable() -> void:
	_on = true


## True only once the sentinels have actually bracketed a frame. A reader that prints a
## span without checking this is printing 0.00ms from a dead instrument.
static func armed() -> bool:
	return _on and _idle_steps_ever > 0


## The last completed idle / physics step, in ms. Per-frame, measured by the sentinels in
## Time.get_ticks_usec - never a Performance monitor bucket-max.
static func last_idle_ms() -> float:
	return float(_last_idle_us) / 1000.0


static func last_phys_ms() -> float:
	return float(_last_phys_us) / 1000.0


## Open a named span. MUST be paired with end() on every path, including early returns
## and error branches - an unclosed begin() charges its whole cause to the next end().
static func begin(cause: String) -> void:
	if not _on:
		return
	_stack.push_back(cause)
	_stack.push_back(Time.get_ticks_usec())
	## Third slot: usec this span's CHILDREN consume. end() subtracts it to get exclusive
	## time and then charges this span's whole duration to its own parent's slot.
	_stack.push_back(0)


static func end() -> void:
	if not _on or _stack.size() < 3:
		return
	var child: int = int(_stack.pop_back())
	var t0: int = int(_stack.pop_back())
	var cause: String = String(_stack.pop_back())
	var dt: int = Time.get_ticks_usec() - t0
	var excl: int = maxi(0, dt - child)
	_total[cause] = int(_total.get(cause, 0)) + dt
	_excl[cause] = int(_excl.get(cause, 0)) + excl
	_count[cause] = int(_count.get(cause, 0)) + 1
	_worst_call[cause] = maxi(int(_worst_call.get(cause, 0)), dt)
	_step[cause] = int(_step.get(cause, 0)) + dt
	_step_excl[cause] = int(_step_excl.get(cause, 0)) + excl
	if _stack.size() >= 3:
		_stack[_stack.size() - 1] = int(_stack[_stack.size() - 1]) + dt


static func physics_frame_begin() -> void:
	if not _on:
		return
	_step.clear()
	_step_excl.clear()
	_phys_t0 = Time.get_ticks_usec()
	if _phys_steps == 0:
		_phys_first_us = _phys_t0


static func physics_frame_end() -> void:
	if not _on:
		return
	_phys_last_us = Time.get_ticks_usec()
	var dt: int = _phys_last_us - _phys_t0
	_last_phys_us = dt
	_phys_steps += 1
	_phys_total_us += dt
	if dt >= STALL_US:
		_stalls += 1
	if dt > _worst_phys_us:
		_worst_phys_us = dt
		_worst_phys_causes = _step.duplicate()
		_worst_phys_excl = _step_excl.duplicate()


static func idle_frame_begin() -> void:
	if not _on:
		return
	_step.clear()
	_step_excl.clear()
	_marks.clear()
	_idle_t0 = Time.get_ticks_usec()


static func mark(label: String) -> void:
	if _on:
		_marks.append([label, Time.get_ticks_usec()])


static func idle_frame_end() -> void:
	if not _on:
		return
	var dt: int = Time.get_ticks_usec() - _idle_t0
	_last_idle_us = dt
	_idle_steps_ever += 1
	if dt > _worst_idle_us:
		_worst_idle_us = dt
		_worst_idle_causes = _step.duplicate()
		_worst_idle_excl = _step_excl.duplicate()
		_worst_idle_marks = _marks.duplicate()
		_worst_idle_marks.append(["<back sentinel>", Time.get_ticks_usec()])


## The worst idle frame cut by the marks: each entry is the time from the previous mark to
## this one, i.e. the subtree that ran in between. Top `n` by cost.
static func _rank_marks(n: int) -> String:
	if _worst_idle_marks.is_empty():
		return "(no marks installed)"
	var segs: Array = []
	var prev: int = _idle_t0
	# _idle_t0 belongs to the frame in flight; recover the worst frame's own start instead.
	prev = int(_worst_idle_marks[0][1])
	var first_label: String = String(_worst_idle_marks[0][0])
	for i in range(1, _worst_idle_marks.size()):
		var m: Array = _worst_idle_marks[i]
		segs.append([float(int(m[1]) - prev) / 1000.0, "%s..%s" % [first_label if i == 1 else String(_worst_idle_marks[i - 1][0]), String(m[0])]])
		prev = int(m[1])
	segs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: PackedStringArray = []
	for i in range(mini(n, segs.size())):
		out.append("%s %.1fms" % [String(segs[i][1]), float(segs[i][0])])
	return ", ".join(out)


## Causes ranked by EXCLUSIVE time - the ordering that answers "where did the window go",
## because exclusive figures sum to the wall and inclusive ones double-count.
## Printed as "name excl(incl)/worst xN": excl is this cause's own work, incl contains
## everything it called. `terrain.crater 5.5(19.1)` means 5.5 ms of crater and 13.6 ms of
## the chunk rebuild it invoked - two numbers that must never be added together.
static func _rank(d: Dictionary, limit: int) -> String:
	var keys: Array = d.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(_excl.get(a, 0)) > int(_excl.get(b, 0)))
	var out: PackedStringArray = []
	for i in range(mini(limit, keys.size())):
		var k: String = keys[i]
		out.append("%s %.1f(%.1f)/%.1fms x%d" % [k, float(_excl.get(k, 0)) / 1000.0,
			float(d[k]) / 1000.0,
			float(_worst_call.get(k, 0)) / 1000.0, int(_count.get(k, 0))])
	return ", ".join(out) if out.size() > 0 else "nothing instrumented fired"


## The worst step's breakdown, in EXCLUSIVE ms, which is the only form that can be summed
## against the step's own duration. `e` takes the exclusive companion of `d`.
static func _rank_step(d: Dictionary, e: Dictionary, limit: int) -> String:
	var keys: Array = d.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(e.get(a, 0)) > int(e.get(b, 0)))
	var out: PackedStringArray = []
	for i in range(mini(limit, keys.size())):
		var k: String = keys[i]
		out.append("%s %.1f(%.1f)ms" % [k, float(e.get(k, 0)) / 1000.0, float(d[k]) / 1000.0])
	return ", ".join(out) if out.size() > 0 else "UNATTRIBUTED - no instrumented cause ran in it"


## The window report. Every number here is measured by this file, per frame, in the
## caller's own time base - none of it is a Performance monitor bucket-max.
static func report(window_ms: float = 0.0) -> String:
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
	lines.append("[STALL]   worst physics step was: %s   [excl(incl)ms - sum the EXCL column]"
		% _rank_step(_worst_phys_causes, _worst_phys_excl, 6))
	lines.append("[STALL] idle script span: WORST %.2fms | worst idle step was: %s"
		% [float(_worst_idle_us) / 1000.0,
			_rank_step(_worst_idle_causes, _worst_idle_excl, 6)])
	lines.append("[STALL]   worst idle frame by subtree (mark..mark): %s" % _rank_marks(6))
	lines.append("[STALL] window totals (excl(incl)/worst xN, ranked by EXCL): %s"
		% _rank(_total, 12))
	## SELF-CHECK. Physics steps are serial on the main thread, so their spans cannot sum to
	## more wall time than the window holds. When they do, one of the two clocks is wrong and
	## NEITHER may be quoted until it is known which. An instrument that cannot detect its own
	## impossibility is the defect class this file exists to prevent.
	if window_ms > 0.0:
		var span_ms: float = float(_phys_total_us) / 1000.0
		var elapsed_ms: float = float(_phys_last_us - _phys_first_us) / 1000.0
		lines.append("[STALL] clocks: spans %.0fms | first-to-last step %.0fms | printer window %.0fms"
			% [span_ms, elapsed_ms, window_ms])
		if span_ms > window_ms:
			lines.append("[STALL] INSTRUMENT DISAGREEMENT: physics spans total %.0fms inside a"
				% span_ms + " %.0fms window (%.0f%%). Serial steps cannot exceed the wall."
				% [window_ms, 100.0 * span_ms / window_ms]
				+ " Do not quote the step mean or the frame rate until this is resolved.")
	return "\n".join(lines)


## How many times a named span ran this window. For probes that assert on the SHAPE of the
## work ("this chunk was rebuilt once, not twice") rather than on its cost - a millisecond
## figure is a machine's mood, a call count is a contract.
static func count(cause: String) -> int:
	return int(_count.get(cause, 0))


## Window totals for a named cause, for probes that assert on the SHAPE of the nesting.
## incl contains everything the cause called; excl is its own work. Never add them.
static func incl_ms(cause: String) -> float:
	return float(_total.get(cause, 0)) / 1000.0


static func excl_ms(cause: String) -> float:
	return float(_excl.get(cause, 0)) / 1000.0


static func reset_window() -> void:
	_total.clear()
	_excl.clear()
	_count.clear()
	_worst_call.clear()
	_worst_phys_us = 0
	_worst_phys_causes.clear()
	_worst_phys_excl.clear()
	_worst_idle_us = 0
	_worst_idle_causes.clear()
	_worst_idle_excl.clear()
	_worst_idle_marks.clear()
	_phys_steps = 0
	_phys_total_us = 0
	_phys_first_us = 0
	_phys_last_us = 0
	_stalls = 0
	_stack.clear()
