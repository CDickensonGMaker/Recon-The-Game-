## probe_journal.gd - The journal (J) and the field log behind its LOG page.
## Proves: every toast the HUD renders is captured, repeats collapse, the ring caps,
## the notebook builds with five tabs, every art slice loads, no page builder crashes
## with a null world, and the tab column does not sit on the text column.
##
##   godot --headless --path . res://tests/probe_journal.tscn
extends Node

var _fail: int = 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _ready() -> void:
	print("[PROBE JOURNAL]")
	_probe_log()
	await _probe_journal()
	print("[PROBE JOURNAL] %s (%d failures)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _probe_log() -> void:
	print(" field log")
	FieldLog.clear()
	_ok(FieldLog.size() == 0, "clear empties the ring")
	FieldLog.push("CONTACT FRONT")
	FieldLog.push("   ")
	_ok(FieldLog.size() == 1, "blank lines are not logged")
	FieldLog.push("CONTACT FRONT")
	_ok(FieldLog.size() == 1, "an immediate repeat collapses instead of flushing")
	_ok(int(FieldLog.entries()[0].get("count", 0)) == 2, "the repeat is counted")
	FieldLog.push("MAN DOWN - DOC IS MOVING TO YOU")
	_ok(FieldLog.size() == 2, "a different line is a new entry")
	_ok(String(FieldLog.entries()[1].get("stamp", "")).begins_with("D"),
		"entries carry a sim-clock stamp (%s)" % FieldLog.entries()[1].get("stamp", ""))
	for i: int in FieldLog.CAPACITY + 40:
		FieldLog.push("LINE %d" % i)
	_ok(FieldLog.size() == FieldLog.CAPACITY,
		"the ring caps at %d, oldest out" % FieldLog.CAPACITY)
	FieldLog.clear()


func _probe_journal() -> void:
	print(" journal")
	var j := Journal.new()
	add_child(j)
	j.setup(null, null, null)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not j.visible, "starts stowed")
	_ok(j._tab_buttons.size() == 5, "five index tabs")
	for n: String in ["spread", "tab_1", "tab_5", "pencil", "paperclip", "rubber_band",
			"da_form_20", "k_ration", "letter"]:
		_ok(j._art.has(n), "art slice loaded: %s" % n)
	_ok(j._page.size.x > 300.0 and j._page.size.y > 220.0,
		"page has a real rect: %s" % j._page.size)
	var vp: Vector2 = j.get_viewport().get_visible_rect().size
	var right_edge: float = j._page.position.x + j._page.size.x
	for i: int in j._tab_buttons.size():
		var b: TextureButton = j._tab_buttons[i]
		_ok(b.position.x + b.size.x <= vp.x,
			"tab %d stays on screen (ends %.0f of %.0f)" % [i, b.position.x + b.size.x, vp.x])
		_ok(b.position.x > right_edge - b.size.x * 0.6,
			"tab %d protrudes past the page edge" % i)
	_ok(j._page.position.x + j._page.size.x < vp.x * 0.75,
		"the notebook stays UPPER-LEFT, not centred (right edge %.0f of %.0f)"
			% [right_edge, vp.x])
	# Every page builder, with no world and no director: this is the boot-order case.
	FieldLog.push("SAPPERS ON THE WIRE")
	for tab: int in 5:
		j._tab = tab
		var l: Array[Dictionary] = []
		match tab:
			Journal.Tab.GEAR:
				l = j._gear_left()
				l.append_array(j._gear_right())
			Journal.Tab.ORDERS:
				l = j._orders_left()
				l.append_array(j._orders_right())
			Journal.Tab.MISSION:
				l = j._mission_right()
			Journal.Tab.LOG:
				l = j._log_lines()
			Journal.Tab.MAP:
				l = [{"t": j._grid(Vector3.ZERO), "c": Color.BLACK, "x": 0.0}]
		_ok(l.size() > 0, "tab %s builds %d lines with a null world"
			% [Journal.TAB_NAMES[tab], l.size()])
	j._tab = Journal.Tab.LOG
	var log_lines: Array[Dictionary] = j._log_lines()
	_ok(String(log_lines[log_lines.size() - 1].get("t", "")).contains("SAPPERS"),
		"the log page prints a line the HUD toasted")
	FieldLog.clear()
	j.queue_free()
