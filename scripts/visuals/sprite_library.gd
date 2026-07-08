## sprite_library.gd - process-wide cache for sprite clips.
##
## Not an autoload: Godot 4 static vars give us the same lifetime without adding
## a boot-time singleton (this project already loads a ~1400-line GameEnums
## autoload that nothing references - see AUDIT-06).
##
## Godot's ResourceLoader already dedups Texture2D by path, so 30 enemies sharing
## one sheet is free. What it does NOT do is unload. A 1024x1280 RGBA8 sheet is
## 5.24 MB of VRAM (135 KB on disk - do not confuse the two); 7 units x 20 clips
## is ~730 MB resident. So we cache manifests eagerly (they are tiny) and let
## textures be released by clear() at mission teardown.
class_name SpriteLibrary
extends RefCounted

static var _manifests: Dictionary = {}   ## key -> SpriteManifest (or null if absent)
static var _textures: Dictionary = {}    ## sheet_path -> Texture2D
static var _misses: Dictionary = {}      ## key -> true, so we warn once per clip


static func _key(faction: String, unit: String, weapon: String, action: String) -> String:
	return "%s/%s/%s/%s" % [faction, unit, weapon, action]


## Returns null when the clip has not been rendered/assembled yet.
static func manifest(faction: String, unit: String, weapon: String, action: String) -> SpriteManifest:
	var k := _key(faction, unit, weapon, action)
	if _manifests.has(k):
		return _manifests[k]
	var m := SpriteManifest.load_clip(faction, unit, weapon, action)
	_manifests[k] = m
	if m == null and not _misses.has(k):
		_misses[k] = true
		push_warning("[SpriteLibrary] no clip '%s' for %s/%s (%s)" % [action, unit, weapon, faction])
	return m


static func texture(m: SpriteManifest) -> Texture2D:
	if m == null:
		return null
	if _textures.has(m.sheet_path):
		return _textures[m.sheet_path]
	if not ResourceLoader.exists(m.sheet_path):
		push_error("[SpriteLibrary] sheet missing: %s" % m.sheet_path)
		return null
	var t: Texture2D = load(m.sheet_path)
	_textures[m.sheet_path] = t
	return t


## Does this unit have this clip at all? Used by the state map to fall back.
static func has_clip(faction: String, unit: String, weapon: String, action: String) -> bool:
	return manifest(faction, unit, weapon, action) != null


## Call at mission teardown (MissionScope). Drops texture refs so VRAM can go back.
static func clear() -> void:
	_textures.clear()
	_manifests.clear()
	_misses.clear()


static func stats() -> String:
	return "[SpriteLibrary] %d manifests, %d textures (~%.0f MB VRAM)" % [
		_manifests.size(), _textures.size(), float(_textures.size()) * 5.24]
