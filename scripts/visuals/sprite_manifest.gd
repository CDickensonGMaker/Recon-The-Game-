## sprite_manifest.gd - typed view over one clip's .json, written by
## tools/assemble_sheets.py.
##
## Layout: assets/NPCs/<faction>/<unit>/<weapon>/<action>/
##           <action>_ALL.png    1024x1280 -> 8 columns x 8 direction rows
##           <action>.json       this file
##
## Row order (top to bottom) is front, front_right, right, back_right, back,
## back_left, left, front_left. Column order is left to right, frame 0 first.
## So a Sprite3D with hframes=8, vframes=8 selects with frame = dir * 8 + col.
## No shader required.
class_name SpriteManifest
extends RefCounted

const ROOT := "res://assets/NPCs/"
const DIR_COUNT: int = 8

var action: String = ""
var unit: String = ""
var weapon: String = ""
var faction: String = ""

var cell: Vector2i = Vector2i(128, 160)
var columns: int = 8
var fps: float = 12.0
var loop: bool = true
var hold_last_frame: bool = false

## Pixel row (0 = top of cell) where the z=0 ground plane sits. The quad is
## taller than the character, so anchoring by centre sinks him.
var ground_row: float = 143.53
var m_per_px: float = 0.014375
var character_height_m: float = 1.7132

## muzzle_px[dir][col] = Vector2(x, y), y measured DOWN from the top of the cell.
var muzzle_px: Array = []

var sheet_path: String = ""
var _valid: bool = false


static func dir_of(faction_: String, unit_: String, weapon_: String, action_: String) -> String:
	return "%s%s/%s/%s/%s/" % [ROOT, faction_, unit_, weapon_, action_]


## Returns null if the clip does not exist on disk (e.g. a unit still rendering).
static func load_clip(faction_: String, unit_: String, weapon_: String, action_: String) -> SpriteManifest:
	var base := dir_of(faction_, unit_, weapon_, action_)
	var json_path := base + action_ + ".json"
	if not ResourceLoader.exists(json_path) and not FileAccess.file_exists(json_path):
		return null
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_error("[SpriteManifest] cannot open %s" % json_path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SpriteManifest] %s is not a JSON object" % json_path)
		return null

	var d: Dictionary = parsed
	var m := SpriteManifest.new()
	m.action = str(d.get("action", action_))
	m.unit = str(d.get("unit", unit_))
	m.weapon = str(d.get("weapon", weapon_))
	m.faction = str(d.get("faction", faction_))
	var c: Array = d.get("cell", [128, 160])
	m.cell = Vector2i(int(c[0]), int(c[1]))
	m.columns = int(d.get("columns", 8))
	m.fps = float(d.get("fps", 12.0))
	m.loop = bool(d.get("loop", true))
	m.hold_last_frame = bool(d.get("hold_last_frame", false))
	m.ground_row = float(d.get("ground_row", 143.53))
	m.m_per_px = float(d.get("m_per_px", 0.014375))
	m.character_height_m = float(d.get("character_height_m", 1.7132))
	m.muzzle_px = d.get("muzzle_px", [])
	m.sheet_path = base + action_ + "_ALL.png"
	m._valid = true
	return m


func is_valid() -> bool:
	return _valid


func has_muzzle() -> bool:
	return muzzle_px.size() == DIR_COUNT


## Sprite3D frame index for a direction row and animation column.
func frame_index(dir_idx: int, col: int) -> int:
	return wrapi(dir_idx, 0, DIR_COUNT) * columns + clampi(col, 0, columns - 1)


## Metres the quad must be pushed UP so that ground_row lands on y = 0.
## Sprite3D.offset is in pixels, applied before pixel_size scaling.
func offset_px_y() -> float:
	return ground_row - float(cell.y) * 0.5


## Barrel tip as an offset from the character's FEET, in metres.
##   x = lateral, positive toward the sprite's screen-right
##   y = height above the feet
## Returns Vector2.ZERO when the clip carries no muzzle data.
func muzzle_offset_m(dir_idx: int, col: int) -> Vector2:
	if not has_muzzle():
		return Vector2.ZERO
	var row: Array = muzzle_px[wrapi(dir_idx, 0, DIR_COUNT)]
	if row.is_empty():
		return Vector2.ZERO
	var px: Array = row[clampi(col, 0, row.size() - 1)]
	var lateral: float = (float(px[0]) - float(cell.x) * 0.5) * m_per_px
	var height: float = (ground_row - float(px[1])) * m_per_px
	return Vector2(lateral, height)


## Camera-INDEPENDENT muzzle height, for the ballistic ray origin.
##
## muzzle_offset_m() is indexed by dir_idx, which is derived from where the
## player's camera is. Feeding that into the hitscan would make an enemy's
## bullet origin - and therefore whether it clears a rock - depend on where the
## player happens to be looking. See enemy_base.gd:1152, where `origin` is the
## raycast start, not just the tracer spawn. So ballistics use row 0 (front).
func canonical_muzzle_height_m(col: int) -> float:
	if not has_muzzle():
		return 1.35  # the old hardcoded shoulder height
	return muzzle_offset_m(0, col).y


func frame_count() -> int:
	return columns


func duration_s() -> float:
	return float(columns) / maxf(fps, 0.001)
