## test_field_item_hud.gd - the r4bk law for carried field items.
##
## The player spawns with 3 flares, 2 claymores and 2 satchels (player.gd:87-94),
## all fully implemented - claymore.gd is a working directional mine with a 2s
## arm, a 9m/35-degree cone and real explosion damage. But mission_hud's slot
## slider rendered a hardcoded range(4): rifle, pistol, frag, medkit. Flares,
## claymores and satchels are direct-key actions rather than selectable slots,
## so they appeared nowhere and the player had no way to learn he carried them.
##
## This probe asserts the HUD names every carried item. It reads the shipping
## source rather than a copy of the list, so it fails if a future edit drops one.
## Run: godot --headless --path . res://tests/test_field_item_hud.tscn
extends Node

const HUD_PATH: String = "res://scripts/ui/mission_hud.gd"
## Counts are split across two owners: frags live on the equipment manager, the
## rest on the player. The probe checks both so it cannot be fooled by either.
const OWNER_PATHS: Array[String] = [
	"res://scripts/player/player.gd",
	"res://scripts/player/equipment_manager.gd",
]

## Every count the player carries, and the label that must surface it.
const CARRIED: Array = [
	["grenade_count", "FRAG"],
	["flare_count", "FLARE"],
	["claymore_count", "CLAYMORE"],
	["satchel_count", "SATCHEL"],
]


func _ready() -> void:
	print("=== FIELD ITEM HUD (r4bk) ===")
	var failures: int = 0
	failures += _test_player_actually_carries_them()
	failures += _test_hud_names_every_item()
	failures += _test_slider_not_hardcoded_to_four()

	if failures == 0:
		print("PASS: every carried item has an affordance")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Guard: if the player stopped carrying these, the HUD assertions below would
## be demanding labels for items that no longer exist.
func _test_player_actually_carries_them() -> int:
	var src: String = ""
	for p in OWNER_PATHS:
		src += FileAccess.get_file_as_string(p)
	var fails: int = 0
	for entry in CARRIED:
		var field: String = entry[0]
		if not src.contains("var %s" % field):
			printerr("FAIL: nothing declares %s any more - probe is stale" % field)
			fails += 1
	if fails == 0:
		print("  player carries: %s" % ", ".join(CARRIED.map(func(e): return e[0])))
	return fails


func _test_hud_names_every_item() -> int:
	var src: String = FileAccess.get_file_as_string(HUD_PATH)
	var fails: int = 0
	for entry in CARRIED:
		var field: String = entry[0]
		var label: String = entry[1]
		if not src.contains(label):
			printerr("FAIL: HUD never shows '%s' - the player cannot know he carries it" % label)
			fails += 1
			continue
		if not src.contains(field):
			printerr("FAIL: HUD shows '%s' but never reads %s - the count is decorative"
				% [label, field])
			fails += 1
	if fails == 0:
		print("  HUD names and reads all %d carried items" % CARRIED.size())
	return fails


## The specific defect: a hardcoded range(4) that silently truncated the list.
## Appending a fifth entry to `names` did nothing at all until this changed.
func _test_slider_not_hardcoded_to_four() -> int:
	var src: String = FileAccess.get_file_as_string(HUD_PATH)
	if src.contains("for i in range(4):"):
		printerr("FAIL: slot slider is hardcoded to 4 rows - items past MEDKIT are dropped")
		return 1
	print("  slider iterates the list, not a fixed count")
	return 0
