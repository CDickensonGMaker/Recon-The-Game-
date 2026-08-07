class_name ScopeOverlay
extends Control
## Fullscreen sniper-scope view: the weapon's scope_overlay texture (transparent
## circle in a dark frame) centered and square, black bars filling the rest, and
## a reticle drawn in code so it stays tunable without touching the art.
## Shows only when the held weapon HAS a scope texture and ADS is near-complete;
## zoom itself is the weapon's ads_fov through the one ADR-004 camera path.

@export var reticle_color: Color = Color(0.05, 0.05, 0.05, 1.0)
@export var reticle_width: float = 2.0
## Reticle lines stop this far from center, leaving the aim point open (mil-dot
## style center gap, in fractions of the circle radius).
@export var center_gap: float = 0.04
## Crosshair arm length as a fraction of the circle radius.
@export var arm_length: float = 0.85
## The transparent hole spans this fraction of the texture's width (measured
## from the source art: radius ~520px of 2041px, recentred crop).
@export var hole_fraction: float = 0.51

var _weapon_holder: WeaponHolder = null
var _texture: Texture2D = null


func setup(wpn: WeaponHolder) -> void:
	_weapon_holder = wpn


func _process(_delta: float) -> void:
	var tex: Texture2D = null
	if _weapon_holder and _weapon_holder.current_weapon:
		tex = _weapon_holder.current_weapon.scope_overlay
	var active: bool = tex != null and _weapon_holder.is_aiming \
		and _weapon_holder.ads_transition >= 0.9
	if active != visible or tex != _texture:
		_texture = tex
		visible = active
		queue_redraw()


func _ready() -> void:
	visible = false


func _draw() -> void:
	if _texture == null:
		return
	# square covers the larger viewport axis entirely, so the hole stays a
	# circle and the frame's own dark border crops off-screen - no bars needed
	var vp: Vector2 = size
	var side: float = maxf(vp.x, vp.y)
	var origin: Vector2 = (vp - Vector2(side, side)) * 0.5
	draw_texture_rect(_texture, Rect2(origin, Vector2(side, side)), false)
	var center: Vector2 = vp * 0.5
	var radius: float = side * 0.5 * hole_fraction
	var gap: float = radius * center_gap
	var arm: float = radius * arm_length
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * gap, center + dir * arm, reticle_color, reticle_width)
