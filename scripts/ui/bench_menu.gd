## Click menu shown while standing at the armorer's bench: the weapon rack and
## the strip-and-clean action. Built in code - it has no .tscn.
class_name BenchMenu
extends CanvasLayer

signal weapon_chosen(tres_path: String)
signal clean_requested
signal close_requested

var _rows: Array[Button] = []
var _clean_button: Button
var _list: VBoxContainer


func _init() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS


func build(rack: Array[String], current_id: String, condition: float) -> void:
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

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	panel.add_child(_list)

	var title := Label.new()
	title.text = "ARMORER'S BENCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	_list.add_child(title)

	_clean_button = Button.new()
	_clean_button.pressed.connect(func() -> void: clean_requested.emit())
	_list.add_child(_clean_button)
	set_condition(condition)

	_list.add_child(HSeparator.new())

	var rack_label := Label.new()
	rack_label.text = "RACK - SELECT A PRIMARY"
	rack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(rack_label)

	for path: String in rack:
		var data: WeaponData = load(path) as WeaponData
		if data == null:
			push_error("[BenchMenu] rack entry will not load: %s" % path)
			continue
		var row := Button.new()
		row.text = data.display_name
		if data.id == current_id:
			row.text = "%s   [CARRIED]" % data.display_name
			row.disabled = true
		row.pressed.connect(func() -> void: weapon_chosen.emit(path))
		_rows.append(row)
		_list.add_child(row)

	_list.add_child(HSeparator.new())

	var close_button := Button.new()
	close_button.text = "CLOSE  [F]"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	_list.add_child(close_button)


func set_condition(condition: float) -> void:
	if _clean_button == null:
		return
	if condition >= 99.99:
		_clean_button.text = "WEAPON IS CLEAN"
		_clean_button.disabled = true
	else:
		_clean_button.text = "STRIP AND CLEAN  (%d%%)" % int(condition)
		_clean_button.disabled = false


func set_clean_progress(percent: int) -> void:
	if _clean_button != null:
		_clean_button.text = "CLEANING... %d%%" % percent


## Rebuild the carried marker after a swap without tearing the menu down.
func mark_carried(current_id: String, rack: Array[String]) -> void:
	for i: int in range(_rows.size()):
		if i >= rack.size():
			break
		var data: WeaponData = load(rack[i]) as WeaponData
		if data == null:
			continue
		var carried: bool = data.id == current_id
		_rows[i].text = "%s   [CARRIED]" % data.display_name if carried else data.display_name
		_rows[i].disabled = carried
