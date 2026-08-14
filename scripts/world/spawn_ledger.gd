## spawn_ledger.gd - who spawned WHAT this frame. The crucible's hitch tracer
## proved the recurring ~285ms worst-frame class is mass spawn bursts but could
## not NAME the caller (2026-08-14, PERF_LEDGER - bursts persisted from unnamed
## sites after MarchingCell's was budgeted). Every mass-instantiation wrapper
## notes itself here; the crucible prints the frame's ledger on any hitch, so
## the next burst arrives with its caller's name attached. Zero cost off the
## hitch path: one dictionary bump per spawn.
class_name SpawnLedger
extends RefCounted

static var _frame: int = -1
static var _counts: Dictionary = {}
static var _prev_counts: Dictionary = {}


## Keyed on the RENDER frame, not the physics frame: a 280ms hitch frame runs
## many catch-up physics ticks, and a physics-frame key made each tick wipe the
## previous tick's counts - the hitch line then read "no spawns" on exactly the
## frames it exists to explain.
static func note(tag: String) -> void:
	var f: int = Engine.get_process_frames()
	if f != _frame:
		_prev_counts = _counts.duplicate() if f == _frame + 1 else {}
		_counts.clear()
		_frame = f
	_counts[tag] = int(_counts.get(tag, 0)) + 1


## Merges the previous render frame's counts with the current one, because the
## hitch tracer reports in frame N+1 with a delta measured across frame N - a
## single-frame read misses every spawn the heavy frame itself made.
static func frame_report() -> String:
	var now: int = Engine.get_process_frames()
	var merged: Dictionary = {}
	if _frame == now:
		merged = _prev_counts.duplicate()
		for k in _counts:
			merged[k] = int(merged.get(k, 0)) + int(_counts[k])
	elif _frame == now - 1:
		merged = _counts.duplicate()
	if merged.is_empty():
		return "no spawns this frame"
	var parts: PackedStringArray = []
	for k in merged:
		parts.append("%s x%d" % [k, merged[k]])
	return ", ".join(parts)
