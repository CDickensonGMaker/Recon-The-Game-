## ww2_map_generator_dock.gd - Editor dock panel for WW2 map generator
@tool
extends EditorPlugin

var dock: Control
var generator: Node


func _enter_tree() -> void:
	dock = _create_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()


func _create_dock() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "WW2MapGen"
	panel.custom_minimum_size = Vector2(200, 300)

	# Title
	var title := Label.new()
	title.text = "WW2 Map Generator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	# Separator
	panel.add_child(HSeparator.new())

	# Seed input
	var seed_hbox := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "Seed:"
	seed_hbox.add_child(seed_label)

	var seed_input := SpinBox.new()
	seed_input.name = "SeedInput"
	seed_input.min_value = 0
	seed_input.max_value = 999999999
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_hbox.add_child(seed_input)
	panel.add_child(seed_hbox)

	# Randomize seed button
	var random_btn := Button.new()
	random_btn.text = "Randomize Seed"
	random_btn.pressed.connect(_on_randomize_pressed.bind(seed_input))
	panel.add_child(random_btn)

	# Separator
	panel.add_child(HSeparator.new())

	# Generate button
	var generate_btn := Button.new()
	generate_btn.text = "Generate Map"
	generate_btn.pressed.connect(_on_generate_pressed.bind(seed_input))
	panel.add_child(generate_btn)

	# Progress bar
	var progress := ProgressBar.new()
	progress.name = "Progress"
	progress.show_percentage = true
	progress.value = 0
	panel.add_child(progress)

	# Separator
	panel.add_child(HSeparator.new())

	# Save/Load buttons
	var save_btn := Button.new()
	save_btn.text = "Save Map JSON"
	save_btn.pressed.connect(_on_save_pressed)
	panel.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Map JSON"
	load_btn.pressed.connect(_on_load_pressed)
	panel.add_child(load_btn)

	# Separator
	panel.add_child(HSeparator.new())

	# Stats button
	var stats_btn := Button.new()
	stats_btn.text = "Print Stats"
	stats_btn.pressed.connect(_on_stats_pressed)
	panel.add_child(stats_btn)

	# Status label
	var status := Label.new()
	status.name = "Status"
	status.text = "Ready"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)

	return panel


func _find_generator() -> Node:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root:
		for child in scene_root.get_children():
			if child.has_method("generate") and child.has_method("get_stats"):
				return child
	return null


func _on_randomize_pressed(seed_input: SpinBox) -> void:
	seed_input.value = randi()
	_set_status("Seed randomized!")


func _on_generate_pressed(seed_input: SpinBox) -> void:
	generator = _find_generator()
	if not generator:
		_set_status("Error: No WW2MapGenerator found in scene!")
		return

	generator.map_seed = int(seed_input.value)

	if generator.has_signal("generation_progress"):
		generator.generation_progress.connect(_on_progress)

	_set_status("Generating...")
	generator.generate()

	if generator.has_signal("generation_progress"):
		generator.generation_progress.disconnect(_on_progress)

	_set_status("Map generated!")


func _on_progress(percent: float) -> void:
	var progress: ProgressBar = dock.get_node("Progress")
	if progress:
		progress.value = percent


func _on_save_pressed() -> void:
	generator = _find_generator()
	if not generator:
		_set_status("Error: No WW2MapGenerator found!")
		return

	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.filters = ["*.json ; JSON files"]
	dialog.current_dir = "res://generated_maps/"
	dialog.file_selected.connect(func(path: String):
		generator.save_to_json(path)
		_set_status("Saved to: " + path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_load_pressed() -> void:
	generator = _find_generator()
	if not generator:
		_set_status("Error: No WW2MapGenerator found!")
		return

	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.filters = ["*.json ; JSON files"]
	dialog.current_dir = "res://generated_maps/"
	dialog.file_selected.connect(func(path: String):
		generator.load_from_json(path)
		_set_status("Loaded from: " + path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_stats_pressed() -> void:
	generator = _find_generator()
	if not generator:
		_set_status("Error: No WW2MapGenerator found!")
		return

	generator.print_stats()
	_set_status("Stats printed to console")


func _set_status(text: String) -> void:
	var status: Label = dock.get_node("Status")
	if status:
		status.text = text
