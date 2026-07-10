## hub_briefing.gd - The mission board INSIDE the HQ tent: an in-world panel over
## the live 3D view (no screen swap, no world teardown). Uses the dormant
## GameManager.is_in_menu flag to freeze the player while the world keeps
## rendering behind the panel. Built entirely with ReconUI.
class_name HubBriefing
extends CanvasLayer

signal accepted(offer: Dictionary)
signal closed


func open(operation_name: String, offers: Array) -> void:
	GameManager.is_in_menu = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	layer = 20

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := ReconUI.make_panel()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)

	col.add_child(ReconUI.make_header("%s - TOC MISSION BOARD" % operation_name, 22))
	col.add_child(ReconUI.make_label("S-3 HAS THREE TASKINGS. PICK YOUR OP, THEN GET TO THE BIRD.", 12, ReconUI.DIM))
	col.add_child(ReconUI.make_divider())

	for offer_v in offers:
		var offer: Dictionary = offer_v
		var text := "%s - %s\n%s | %s, %s | ENEMY: %s" % [
			str(offer.get("codename", "?")), str(offer.get("type_name", "?")),
			str(offer.get("terrain_hint", "")), str(offer.get("weather", "")),
			str(offer.get("time", "")), str(offer.get("strength", "")),
		]
		var comps: Array = offer.get("complications", [])
		if comps.size() > 0:
			text += "\n! " + " / ".join(PackedStringArray(comps))
		var card := ReconUI.make_card_button(text, 14, 74.0)
		card.pressed.connect(func() -> void: _accept(offer))
		col.add_child(card)

	col.add_child(ReconUI.make_divider())
	var leave := ReconUI.make_button("LEAVE THE TENT", 16)
	leave.pressed.connect(_close)
	col.add_child(leave)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close()


func _accept(offer: Dictionary) -> void:
	_release()
	accepted.emit(offer)
	queue_free()


func _close() -> void:
	_release()
	closed.emit()
	queue_free()


func _release() -> void:
	GameManager.is_in_menu = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
