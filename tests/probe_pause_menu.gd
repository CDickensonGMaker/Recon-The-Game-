## probe_pause_menu.gd - MEASURES the pause menu's panel geometry.
## Item 34 (his playtest 2026-08-28): "when i pause in the demo, i dont see any
## menu i just get a paused screen with a image of a soldier in the river."
## Background + scrim render, the panel does not. This probe builds the real
## PauseMenu exactly the way GameFlow._open_pause does - PAUSED tree included -
## and prints every control's visibility and global rect.
## Run: godot --headless --path . res://tests/probe_pause_menu.tscn
extends Node


func _ready() -> void:
	print("=== PAUSE MENU PANEL PROBE (item 34) ===")
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	print("[PROBE] viewport = %s" % str(vp))
	# Exactly GameFlow._open_pause: pause FIRST, then new -> add_child -> build.
	get_tree().paused = true
	var pm := PauseMenu.new()
	add_child(pm)
	pm.build(false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_dump(pm, 0, vp)
	get_tree().paused = false
	await get_tree().process_frame
	get_tree().quit()


func _dump(n: Node, depth: int, vp: Vector2) -> void:
	var pad: String = "  ".repeat(depth)
	var c := n as Control
	if c != null:
		var r: Rect2 = c.get_global_rect()
		var onscreen: bool = r.intersects(Rect2(Vector2.ZERO, vp)) and r.size.x > 0.5 and r.size.y > 0.5
		print("%s%s [%s] vis=%s rect=%s min=%s %s" % [
			pad, n.name, n.get_class(), str(c.is_visible_in_tree()),
			str(r), str(c.get_combined_minimum_size()),
			"" if onscreen else "<<< OFFSCREEN OR ZERO"])
	else:
		print("%s%s [%s]" % [pad, n.name, n.get_class()])
	for ch in n.get_children():
		_dump(ch, depth + 1, vp)
