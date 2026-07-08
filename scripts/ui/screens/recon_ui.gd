## recon_ui.gd - Shared 1960s military UI styling helpers (NS18).
class_name ReconUI
extends RefCounted

const OLIVE := Color(0.62, 0.64, 0.42)
const AMBER := Color(0.85, 0.72, 0.35)
const DIM := Color(0.45, 0.47, 0.34)
const BG := Color(0.06, 0.065, 0.05)


static func mono_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return f


static func make_label(text: String, size: int = 18, color: Color = OLIVE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", mono_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_button(text: String, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", mono_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", AMBER)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.5))
	return b


static func make_screen_root() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	return root
