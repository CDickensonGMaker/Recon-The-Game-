## observatory.gd - THE OBSERVATORY as a standalone tool scene (council 2026-09-14 ruling 7).
## Boots the demo world through the SAME path as scenes/levels/demo_game.tscn (one world
## build, ADR-028) with the overlay ON and the observer camera flying from the first frame.
##
##   godot --path . res://tools/observatory.tscn
##
## Keys once up: F9 overlay on/off · F7 observer camera · F6 MAN/LEDGER pane · Tab/Shift+Tab
## cycle · left-click select (hold right button to look) · Backspace clear · \ [ ] - = 0 time.
## Debug builds only: ObservationTools refuses to act in a shipped player build.
extends Node

const DEMO_SCENE: PackedScene = preload("res://scenes/levels/demo_game.tscn")
const ObsToolsS := preload("res://scripts/dev/observation_tools.gd")

var tools: Node = null
var flow: Node = null


func _ready() -> void:
	add_child(DEMO_SCENE.instantiate())
	await _world_up()
	if flow == null:
		return
	_dismiss_splash()
	tools = ObsToolsS.new()
	tools.set("live_world", true)
	(flow.get("world") as Node).add_child(tools)
	tools.call("set_observatory", true)
	if not DisplayServer.get_name() == "headless":
		tools.call("_activate_observer")
	_on_world_up()


## Hook for the probe subclass.
func _on_world_up() -> void:
	print("[OBSERVATORY] up - F9 overlay · F7 observer · F6 pane · Tab cycle")


func _world_up() -> void:
	var waited: float = 0.0
	while waited < 240.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
		if flow == null:
			flow = get_tree().get_first_node_in_group("game_flow")
		if flow != null and bool(flow.get("_in_world")) and flow.get("world") != null:
			return
	push_error("[OBSERVATORY] the demo world never came up")


## The demo's title card waits for a click; a tool does not.
func _dismiss_splash() -> void:
	for n in get_tree().root.find_children("*", "Control", true, false):
		var sc: Script = (n as Node).get_script() as Script
		if sc != null and sc.resource_path.ends_with("title_splash.gd"):
			(n as Node).queue_free()
