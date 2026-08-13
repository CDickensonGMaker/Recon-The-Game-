## title_splash.gd - the card the game opens on. Logo, then a click.
##
## It sits in front of BOTH entry points (the campaign's GameFlow and the demo scene), so
## the first thing anyone sees is the title rather than a terrain popping in.
##
## ANY input dismisses it - key, button, mouse, pad. A splash that only accepts one
## specific click is a splash people think has hung.
class_name TitleSplash
extends Control

signal dismissed

const LOGO := preload("res://assets/ui/title_logo.jpg")

## The art is dark at the edges and lights toward the centre, so it carries its own
## vignette - the fade is on the WHOLE card, not a scrim over it.
const FADE_IN_S: float = 0.9
## Input is ignored until the logo is actually up, or a held key at launch eats the card
## before it is seen.
const ARM_AFTER_S: float = 0.45
const PROMPT_PERIOD_S: float = 1.6

var _armed: bool = false
var _t: float = 0.0
var _prompt: Label = null
var _done: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# KEEP_ASPECT_CENTERED, never IGNORE_SIZE: the logo is a fixed composition and
	# stretching it to an arbitrary window shears the lettering.
	var art := TextureRect.new()
	art.texture = LOGO
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	_prompt = Label.new()
	_prompt.text = "CLICK TO CONTINUE"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.position.y -= 96.0
	_prompt.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)

	# The card is the first pointer anyone sees, so it sets the default rather than
	# inheriting whatever the OS was showing.
	CursorSet.set_context(CursorSet.Ctx.DEFAULT)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN_S)


func _process(delta: float) -> void:
	_t += delta
	if not _armed and _t >= ARM_AFTER_S:
		_armed = true
	if _prompt != null:
		# Slow breath rather than a blink: it reads as waiting, not as an error.
		_prompt.modulate.a = 0.45 + 0.45 * sin(_t * TAU / PROMPT_PERIOD_S)


func _unhandled_input(event: InputEvent) -> void:
	if _done or not _armed:
		return
	var go: bool = event is InputEventKey and (event as InputEventKey).pressed \
		and not (event as InputEventKey).echo
	go = go or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	go = go or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if not go:
		return
	get_viewport().set_input_as_handled()
	_dismiss()


func _dismiss() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		dismissed.emit()
		queue_free())
