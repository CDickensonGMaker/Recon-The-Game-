## The click menu shown when you interact with your RTO: the one affordance that
## carries both the per-man orders (FOLLOW ME / HOLD HERE) and the handset grab, so
## the radio is reachable wherever he is standing (player freedom). Built in code -
## it has no .tscn - cloning the BenchMenu shape (CanvasLayer, layer 12, always-on).
class_name RadioMenu
extends CanvasLayer

signal follow_requested
signal hold_requested
signal grab_requested
signal close_requested


func _init() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS


func build(rto_name: String, can_grab: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	panel.add_child(list)

	var title := Label.new()
	title.text = "%s — %s" % [rto_name.to_upper(), SquadRoster.mos_display("RTO")]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	list.add_child(title)

	list.add_child(HSeparator.new())

	var follow := Button.new()
	follow.text = "FOLLOW ME"
	follow.pressed.connect(func() -> void: follow_requested.emit())
	list.add_child(follow)

	var hold := Button.new()
	hold.text = "HOLD HERE"
	hold.pressed.connect(func() -> void: hold_requested.emit())
	list.add_child(hold)

	var grab := Button.new()
	grab.text = "GRAB HANDSET" if can_grab else "HANDSET IS OUT"
	grab.disabled = not can_grab
	grab.pressed.connect(func() -> void: grab_requested.emit())
	list.add_child(grab)

	list.add_child(HSeparator.new())

	var close_button := Button.new()
	close_button.text = "CLOSE  [F]"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	list.add_child(close_button)
