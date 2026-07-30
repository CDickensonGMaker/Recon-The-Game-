## recon_ui.gd - Shared sleek-tactical UI styling helpers (UI/UX modernization pass).
## Delta Force / Rainbow Six / Ghost Recon-leaning: dark khaki panels, olive accents,
## hairline borders, key-art backgrounds. Every screen builds from these primitives
## so the whole game reads as one interface.
class_name ReconUI
extends RefCounted

const OLIVE := Color(0.62, 0.64, 0.42)
const AMBER := Color(0.85, 0.72, 0.35)
const DIM := Color(0.45, 0.47, 0.34)
const BG := Color(0.06, 0.065, 0.05)
const PANEL_BG := Color(0.05, 0.055, 0.045, 0.88)
const BORDER := Color(0.4, 0.42, 0.3, 0.9)
const HILITE := Color(0.55, 0.58, 0.36)
const TEXT := Color(0.82, 0.8, 0.72)
const ALERT := Color(0.82, 0.36, 0.26)

static var _screen_bg: Texture2D = null


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


## Full-bleed key-art background + dark scrim so any screen reads as part of
## the same world as the main menu, instead of a flat void. Pass bg_override
## for a screen that needs its own art instead of the shared screen_bg.
static func make_screen_root(bg_override: Texture2D = null) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _screen_bg == null:
		_screen_bg = load("res://assets/ui/screen_bg.png")
	var bg := TextureRect.new()
	bg.texture = bg_override if bg_override != null else _screen_bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.04, 0.045, 0.035, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	return root


## Olive hairline-bordered panel, used for briefing sheets, roster cards, HUD panels.
static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Section header: amber label + thin olive underline, replaces ASCII dash rows.
static func make_header(text: String, size: int = 26) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(make_label(text, size, AMBER))
	box.add_child(make_divider())
	return box


static func make_divider(width: float = 0.0) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.4, 0.42, 0.3, 0.5)
	line.custom_minimum_size = Vector2(width, 1)
	if width <= 0.0:
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


## Left-column menu row with the mockup's olive highlight bar on hover/focus.
static func make_menu_button(text: String, action: Callable, min_width: float = 330.0, size: int = 21) -> Button:
	var b := Button.new()
	b.text = "  %s" % text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_width, 40)
	b.add_theme_font_override("font", mono_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.8, 0.79, 0.72))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.08))
	b.add_theme_color_override("font_focus_color", Color(0.1, 0.1, 0.08))
	var hover := StyleBoxFlat.new()
	hover.bg_color = HILITE
	hover.set_content_margin_all(4)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	var flat := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("pressed", hover)
	if action.is_valid():
		b.pressed.connect(action)
	return b


## Bordered clickable "card" (roster rows): hairline box that
## brightens on hover.
static func make_card_button(text: String, size: int = 15, min_height: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = false
	b.custom_minimum_size = Vector2(0, min_height)
	b.add_theme_font_override("font", mono_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.95, 0.92, 0.8))
	b.add_theme_color_override("font_focus_color", Color(0.95, 0.92, 0.8))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.085, 0.07, 0.75)
	normal.border_color = BORDER
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	normal.set_content_margin_all(12)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.17, 0.11, 0.9)
	hover.border_color = HILITE
	hover.set_border_width_all(1)
	hover.border_width_left = 4
	hover.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


## Small [ BACK ]-style secondary action, kept subdued vs. the card buttons.
static func make_link_button(text: String, size: int = 14) -> Button:
	var b := make_button(text, size)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", OLIVE)
	b.add_theme_color_override("font_focus_color", OLIVE)
	return b
