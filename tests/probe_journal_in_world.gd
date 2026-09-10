## probe_journal_in_world.gd - The journal inside the SHIPPED demo arc, not in isolation.
## Proves it is actually built on the live MissionHUD, that the real world's toasts land in
## the ring, and that the MAP page has a real rendered sheet to print.
##
##   godot --headless --path . res://tests/probe_journal_in_world.tscn
extends Node

const DEMO := "res://scenes/levels/demo_game.tscn"
const SETTLE_FRAMES: int = 700

var _fail: int = 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _ready() -> void:
	print("[PROBE JOURNAL IN WORLD]")
	add_child((load(DEMO) as PackedScene).instantiate())
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var hud: Node = get_tree().get_first_node_in_group("mission_hud")
	_ok(hud != null, "the live MissionHUD exists")
	if hud != null:
		var j: Journal = hud.get("journal") as Journal
		_ok(j != null, "the journal is built on it")
		if j != null:
			_ok(not j.visible, "stowed until [J]")
			_ok(j.layer == Journal.LAYER,
				"canvas layer %d - over the HUD (0) and the vignette (5), under pause (90)"
					% j.layer)
			_ok(j.world != null and j.director != null, "wired to the world and the director")
			var tex: Texture2D = null
			if j.hud != null and j.hud.topo_map != null:
				tex = j.hud.topo_map.sheet_texture()
			_ok(tex != null, "the MAP page has the live AO raster to print (%s)"
				% ("null" if tex == null else str(tex.get_size())))
			var g: String = j._grid(Vector3(128.0, 0.0, 128.0))
			_ok(g != "------", "grid reference resolves against the real map size (%s)" % g)
			j._tab = Journal.Tab.MISSION
			_ok(j._mission_right().size() >= 3,
				"the MISSION page reads the live roster (%d lines)" % j._mission_right().size())
			j._tab = Journal.Tab.GEAR
			_ok(j._gear_right().size() >= 5,
				"the GEAR page reads the live player (%d lines)" % j._gear_right().size())
	_ok(FieldLog.size() > 0, "the real arc has already written %d lines into the log"
		% FieldLog.size())
	for e: Dictionary in FieldLog.entries():
		print("    %s  %s" % [e.get("stamp", "?"), e.get("text", "?")])
	print("[PROBE JOURNAL IN WORLD] %s (%d failures)"
		% ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)
