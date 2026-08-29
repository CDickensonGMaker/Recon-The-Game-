## sleep_screen.gd - THE CEREMONY. Black, the roll call of the dead, the clock, and what the
## night decided.
##
## HIS RULING, 2026-08-28: "during the sleep part is when we get read off the names of those
## who died. that way were keeping the player from potentially being attacked and its
## stopping them to read off names." Both halves are load-bearing. Nothing can shoot him
## while this runs (GameManager.is_in_menu gates the player's whole _physics_process and
## _input), and he cannot walk away from it - which is exactly why the naming moved here off
## the radio traffic at the wire.
##
## THIS IS NOT A CUTSCENE, and waking into a siege is not one either (his 2026-07-30
## constraint). No camera moves, no shot is composed, no control is taken beyond the black.
## The instant the black lifts he is standing at his own rack in the dark with the siren
## already going and the ranging rounds already walking in, holding his rifle, in charge.
extends CanvasLayer

## Deliberately below MissionHUD's default layer so nothing about this fights the HUD;
## the roll call is drawn by this screen itself, not by the toast queue.
const STATION := preload("res://scripts/world/sleep_station.gd")

const LAYER: int = 60

const FADE_S: float = 1.1
const HOLD_BEFORE_NAMES_S: float = 1.0
## Per name. Slow on purpose - the pause IS the mechanic he asked for.
const NAME_S: float = 1.4
const HOLD_AFTER_S: float = 1.6

var _black: ColorRect
var _lines: VBoxContainer


## Run the whole ceremony. Awaits until control is handed back.
static func run(player: Node3D) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or player == null or not is_instance_valid(player):
		return
	var director := tree.get_first_node_in_group("mission_director") as FieldDirector
	if director == null or not is_instance_valid(director):
		return
	var screen = (load("res://scripts/ui/screens/sleep_screen.gd") as GDScript).new()
	player.get_tree().root.add_child(screen)
	await screen._ceremony(director, player)


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	# A CenterContainer cannot drift: Control.position is PARENT-relative, and hand-placing
	# a panel after a preset is what put the pause menu off the top-left corner for weeks
	# (measured 2026-08-28, tests/probe_pause_menu.tscn).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_lines = VBoxContainer.new()
	_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_lines)


func _ceremony(director: FieldDirector, player: Node3D) -> void:
	var was_in_menu: bool = GameManager.is_in_menu
	GameManager.is_in_menu = true
	await _fade(1.0)
	await _wait(HOLD_BEFORE_NAMES_S)

	# 1. BANK, AND TAKE THE NAMES QUIETLY. turn_in_for_the_night drives _bank_patrol - the
	#    same one bank that has always existed - and suppresses its toasts so they are read
	#    here instead. One ceremony, never two.
	var turn_in: Dictionary = director.turn_in_for_the_night()
	if bool(turn_in.get("banked", false)):
		_say("YOU LOG THE PATROL AND SIT DOWN ON YOUR RACK.")
	else:
		_say("YOU SIT DOWN ON YOUR RACK.")
	await _wait(HOLD_BEFORE_NAMES_S)

	# 2. THE ROLL CALL.
	var names: Array = turn_in.get("names", []) as Array
	if not names.is_empty():
		_say("")
		_say("KILLED IN ACTION")
		await _wait(NAME_S)
		for n in names:
			_say("    %s" % str(n))
			await _wait(NAME_S)
		_say("")
		_say("%d KIA THIS TOUR.  %d IN THE WARD." % [
			int(turn_in.get("kia", 0)), int(turn_in.get("ward", 0))])
		await _wait(HOLD_AFTER_S)

	# 3. THE NIGHT DECIDES. Asked here, once, at the moment he goes under - the poll in
	#    SiegeDirector._maybe_open needs a player awake and present at night and never had
	#    one, which is exactly why the demo has to author its assault on a clock.
	var attacked: bool = director.roll_the_night()
	if attacked:
		SimClock.sleep_advance(STATION.WAKE_HOURS)
		_clear()
		_say("SOMEBODY IS SHAKING YOU.")
		await _wait(1.4)
		_clear()
		_say("\"UP. UP! THEY'RE IN THE WIRE!\"")
		await _wait(1.5)
	else:
		SimClock.sleep_advance(STATION.SLEEP_HOURS)
		_clear()
		_say("YOU SLEEP.")
		await _wait(1.6)
		_clear()
		_say("%02d%02d.  ANOTHER DAY." % [
			int(SimClock.sim_hour), int(fmod(SimClock.sim_hour, 1.0) * 60.0)])
		await _wait(1.6)

	# 4. HAND HIM BACK HIS RIFLE. Control returns with the black, not after a beat of it -
	#    a man who wakes into an assault and cannot move for two seconds is in a cutscene.
	GameManager.is_in_menu = was_in_menu
	_clear()
	await _fade(0.0)
	queue_free()


func _fade(to: float) -> void:
	if _black == null or not is_instance_valid(_black):
		return
	var tw: Tween = create_tween()
	tw.tween_property(_black, "color:a", to, FADE_S)
	await tw.finished


func _wait(s: float) -> void:
	# Sleep is not the pause menu: the world keeps running under the black (the garrison,
	# the clock, a siege standing itself up), so this waits on unscaled tree time.
	await get_tree().create_timer(s).timeout


func _say(text: String) -> void:
	if _lines == null or not is_instance_valid(_lines):
		return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	l.add_theme_font_size_override("font_size", 22)
	_lines.add_child(l)


func _clear() -> void:
	if _lines == null or not is_instance_valid(_lines):
		return
	for c in _lines.get_children():
		c.queue_free()
