## cursor_set.gd - the pointer changes with what you are doing.
##
## Godot takes ONE Texture2D per cursor shape, so the sheet is sliced ahead of time by
## tools/gen_cursors.py. Regenerate from the sheet, never hand-edit the PNGs.
##
## SIZE IS A HARDWARE CONTRACT, not a taste call. set_custom_mouse_cursor rejects anything
## over 256x256, and above 128x128 Windows drops the hardware cursor for a software one
## that lags a frame behind the mouse - which reads as broken input. 32 ships; 64 is the
## high-DPI rung and is still hardware.
class_name CursorSet
extends RefCounted

const DIR: String = "res://assets/ui/cursors/"
## Authored at 64 and downsampled, so both exist. 32 is the default because it is
## hardware-safe on every target; the 64 rung is opt-in for a high-DPI desktop.
const SIZE_SMALL: int = 32
const SIZE_LARGE: int = 64

## What the pointer MEANS, not which picture it is - so the art can be re-cast without
## touching a single callsite.
enum Ctx {
	DEFAULT,     ## nothing special under the pointer
	CONFIRM,     ## a button, a choice, anything clickable
	MELEE,       ## a knife kill is in reach
	ORDER,       ## giving the squad something to do
	MAP,         ## the topo sheet / navigation
	RESUPPLY,    ## ammo, the belt
	ORDNANCE,    ## grenade or thrown weapon selected
	AIR,         ## calling or watching air support
	CASUALTY,    ## a man down - his tags
	SPENT,       ## empty, expended, unavailable
}

const ART: Dictionary = {
	Ctx.DEFAULT: "bullet",
	Ctx.CONFIRM: "crossed",
	Ctx.MELEE: "knife",
	Ctx.ORDER: "chevron",
	Ctx.MAP: "compass",
	Ctx.RESUPPLY: "belt",
	Ctx.ORDNANCE: "grenade",
	Ctx.AIR: "huey",
	Ctx.CASUALTY: "dogtags",
	Ctx.SPENT: "casing",
}

static var _size: int = SIZE_SMALL
static var _hotspots: Dictionary = {}
static var _cache: Dictionary = {}
static var _current: int = -1


## Call once at boot if the desktop wants the big rung. Re-applies the live cursor so the
## change is immediate rather than waiting for the next context switch.
static func use_large(large: bool) -> void:
	var want: int = SIZE_LARGE if large else SIZE_SMALL
	if want == _size:
		return
	_size = want
	_cache.clear()
	var was: int = _current
	_current = -1
	if was >= 0:
		set_context(was)


## Set the pointer. Idempotent: re-setting the same context does nothing, so this is safe
## to call every frame from a hover check.
static func set_context(ctx: int) -> void:
	if ctx == _current:
		return
	var name: String = String(ART.get(ctx, ""))
	if name.is_empty():
		return
	var tex: Texture2D = _texture(name)
	if tex == null:
		return
	_current = ctx
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, _hotspot(name))


## Hand the pointer back to the OS. Anything that hid or grabbed the mouse should call
## this on the way out rather than leaving a stale custom cursor behind.
static func reset() -> void:
	_current = -1
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


## Hook every Button under `root` so hovering it swaps the pointer and leaving restores it.
## One call per screen: a screen should not have to know which control is which, and a
## per-button connect at every callsite is how half of them end up missed.
##
## A DISABLED button reports SPENT - a spent casing over a fire mission you have no rounds
## for says "not available" faster than any tooltip, and nothing else in the UI says it.
static func hook_buttons(root: Node, base: int = Ctx.DEFAULT,
		hover: int = Ctx.CONFIRM) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var b := n as BaseButton
		if b == null or b.has_meta(&"cursor_hooked"):
			continue
		b.set_meta(&"cursor_hooked", true)
		b.mouse_entered.connect(func() -> void:
			set_context(Ctx.SPENT if b.disabled else hover))
		b.mouse_exited.connect(set_context.bind(base))


static func _texture(name: String) -> Texture2D:
	var key: String = "%s_%d" % [name, _size]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var path: String = "%s%s.png" % [DIR, key]
	if not ResourceLoader.exists(path):
		push_warning("[CURSOR] %s missing - run tools/gen_cursors.py" % path)
		return null
	var tex: Texture2D = load(path) as Texture2D
	_cache[key] = tex
	return tex


## Hotspots are stored NORMALISED by the slicer, so one number serves every size - and a
## blade points from its tip rather than from the middle of its own picture.
static func _hotspot(name: String) -> Vector2:
	if _hotspots.is_empty():
		var f: FileAccess = FileAccess.open(DIR + "cursors.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_hotspots = parsed
	var entry: Dictionary = _hotspots.get(name, {}) as Dictionary
	var h: Array = entry.get("hotspot", [0.5, 0.5]) as Array
	return Vector2(float(h[0]) * float(_size), float(h[1]) * float(_size))
