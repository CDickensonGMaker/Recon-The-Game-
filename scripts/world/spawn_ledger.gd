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


static func note(tag: String) -> void:
	var f: int = Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_counts.clear()
	_counts[tag] = int(_counts.get(tag, 0)) + 1


## The current frame's spawns, for a hitch line. Reads clean in _process because
## physics (where spawns happen) runs earlier in the same frame.
static func frame_report() -> String:
	if _counts.is_empty() or _frame != Engine.get_physics_frames():
		return "no spawns this frame"
	var parts: PackedStringArray = []
	for k in _counts:
		parts.append("%s x%d" % [k, _counts[k]])
	return ", ".join(parts)
