## field_log.gd - The ring buffer behind the journal's LOG tab. Every player-facing
## line the field HUD shows is written here before it is shown, so a message the player
## missed in a firefight can still be read afterwards.
##
## The capture point is MissionHUD.show_toast(), NOT FieldDirector.toast: player.gd,
## weapon_holder.gd, hud.gd and tree_cover_layer.gd all reach the renderer by group
## lookup and never touch the signal. The renderer is the only total-capture point.
##
## Static, not an autoload: the buffer must outlive the MissionHUD that fills it and
## must be readable before any journal exists.
class_name FieldLog
extends RefCounted

const CAPACITY: int = 240
## Identical lines inside this window collapse into one entry with a repeat count,
## so a jam or a check-fire warning cannot flush the whole log.
const COLLAPSE_WINDOW_S: float = 20.0

static var _lines: Array[Dictionary] = []


static func push(text: String) -> void:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if not _lines.is_empty():
		var last: Dictionary = _lines[_lines.size() - 1]
		if String(last.get("text", "")) == clean \
				and now - float(last.get("at_s", 0.0)) <= COLLAPSE_WINDOW_S:
			last["count"] = int(last.get("count", 1)) + 1
			last["at_s"] = now
			return
	_lines.append({
		"text": clean,
		"stamp": stamp_now(),
		"at_s": now,
		"count": 1,
	})
	if _lines.size() > CAPACITY:
		_lines.remove_at(0)


## "D1 0632" - sim day and 24h clock, the only time a man in the field has.
static func stamp_now() -> String:
	var hour: float = SimClock.sim_hour
	return "D%d %02d%02d" % [SimClock.sim_day, int(hour), int((hour - floorf(hour)) * 60.0)]


static func entries() -> Array[Dictionary]:
	return _lines


static func size() -> int:
	return _lines.size()


## Called when a world is entered. The log is a mission artefact, not a career one.
static func clear() -> void:
	_lines.clear()
