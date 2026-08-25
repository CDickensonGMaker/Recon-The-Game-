## test_magazine_ammo.gd - magazine-model verification probe (decree 2026-08-24).
## Locks in the per-mag round-count grammar that replaced the pooled
## [rounds, spare_full_mags] pair:
##   (a) a shot leaves the SEATED mag (index 0) and nothing else
##   (b) reload pouches the partial at its TRUE count and seats the fullest
##       spare (ties -> lowest index); a 0-round mag is dropped, never pouched
##   (c) reload refuses when no spare beats the seated mag
##   (d) INTERNAL: from-empty loads a full stroke (stripper clip), partial tops
##       up one round at a time, and both decrement the loose pool
##   (e) PlayerSection round-trips a ragged mag array bit-exact, and a legacy
##       pair without the mag_model key rebuilds as [rounds] + N full mags
##   (f) fossil tripwire: the killed mirrors' symbols have ZERO hits in scripts/
##   (g) the gunner's belt stock decrements per take, refuses at zero, and one
##       draw appends ONE full 100-rd belt (ruling A2/A4, 2026-08-24)
## Run: godot --headless --path . res://tests/test_magazine_ammo.tscn
extends Node

## Feed assignments of record. MAGAZINE is the WeaponData default; only
## belt/internal/single guns carry a line in their .tres.
const EXPECTED_FEED := {
	"m16a1": Enums.FeedType.MAGAZINE, "car15": Enums.FeedType.MAGAZINE,
	"m14": Enums.FeedType.MAGAZINE, "m1911": Enums.FeedType.MAGAZINE,
	"ppsh41": Enums.FeedType.MAGAZINE, "ak47": Enums.FeedType.MAGAZINE,
	"m60": Enums.FeedType.BELT, "rpd": Enums.FeedType.BELT,
	"mosin": Enums.FeedType.INTERNAL, "m70": Enums.FeedType.INTERNAL,
	"shotgun": Enums.FeedType.INTERNAL,
	"m79": Enums.FeedType.SINGLE, "m72_law": Enums.FeedType.SINGLE,
	"rpg2": Enums.FeedType.SINGLE, "rpg7": Enums.FeedType.SINGLE,
	"m26_grenade": Enums.FeedType.SINGLE,
}
## The two dead mirror symbols. A hit anywhere in scripts/ is a resurrected
## fossil (ADR-023) - the pooled counter must not grow back beside the arrays.
const DEAD_SYMBOLS := ["spare_magazines", "current_ammo"]

var failures: int = 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	failures += 1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


func _run() -> void:
	# --- feed tags of record --------------------------------------------------
	for wid: String in EXPECTED_FEED.keys():
		var wd: WeaponData = load("res://data/weapons/%s.tres" % wid) as WeaponData
		if wd == null:
			_fail("%s did not load as WeaponData" % wid)
			continue
		if wd.feed != int(EXPECTED_FEED[wid]):
			_fail("%s feed %d != decreed %d" % [wid, wd.feed, int(EXPECTED_FEED[wid])])

	# --- (a) fire decrements mags[0] only ------------------------------------
	var m: Array[int] = [14, 20, 20, 7]
	_check(WeaponHolder.fire_round(m), "(a) fire on a loaded mag refused")
	_check(m == [13, 20, 20, 7], "(a) fire touched more than mags[0]: %s" % [m])
	var empty_seated: Array[int] = [0, 20]
	_check(not WeaponHolder.fire_round(empty_seated), "(a) fire drew from a spare mag")
	_check(empty_seated == [0, 20], "(a) dry fire mutated the pouch: %s" % [empty_seated])

	# --- (b) reload pouches exact count + seats fullest (ties -> lowest) -----
	m = [3, 12, 20, 20, 5]
	_check(WeaponHolder.swap_to_best(m), "(b) valid reload refused")
	_check(m == [20, 12, 20, 5, 3],
		"(b) expected [20,12,20,5,3] (fullest seated, tie to lowest index, 3 pouched last), got %s" % [m])
	m = [0, 7]
	_check(WeaponHolder.swap_to_best(m), "(b) from-empty reload refused")
	_check(m == [7], "(b) a 0-round mag was pouched: %s" % [m])

	# --- (c) reload refuses when no spare beats the seated mag ---------------
	var all_empty: Array[int] = [0]
	_check(not WeaponHolder.swap_to_best(all_empty), "(c) all-empty reload did not refuse")
	var no_better: Array[int] = [5, 5, 3]
	_check(not WeaponHolder.swap_to_best(no_better), "(c) reload accepted a spare that does not beat the seated mag")
	_check(no_better == [5, 5, 3], "(c) refused reload still mutated the pouch: %s" % [no_better])

	# --- (d) INTERNAL: stripper stroke + stepwise, pool decrements -----------
	var tube: Array[int] = [0, 12]
	_check(WeaponHolder.internal_stroke(tube, 5) == 5, "(d) from-empty stroke did not load 5")
	_check(tube == [5, 7], "(d) stroke result wrong: %s" % [tube])
	tube = [3, 7]
	_check(WeaponHolder.internal_step(tube, 5) == 1, "(d) partial step did not load 1")
	_check(tube == [4, 6], "(d) step result wrong: %s" % [tube])
	tube = [0, 3]
	WeaponHolder.internal_stroke(tube, 5)
	_check(tube == [3, 0], "(d) short pool stroke wrong: %s" % [tube])
	tube = [5, 4]
	_check(WeaponHolder.internal_step(tube, 5) == 0, "(d) step overfilled a full tube")

	# --- (e) save round-trip: ragged bit-exact + legacy migration ------------
	var sect := SaveData.PlayerSection.new()
	sect.primary_path = "res://data/weapons/m16a1.tres"
	sect.primary_ammo = [14, 20, 7, 0]
	sect.secondary_ammo = [2, 7, 7, 3]
	var back: SaveData.PlayerSection = SaveData.PlayerSection.from_dict(sect.to_dict())
	_check(back.primary_ammo == [14, 20, 7, 0],
		"(e) ragged primary did not round-trip bit-exact: %s" % [back.primary_ammo])
	_check(back.secondary_ammo == [2, 7, 7, 3],
		"(e) ragged secondary did not round-trip bit-exact: %s" % [back.secondary_ammo])
	# JSON turns ints to floats; the schema must int them back.
	var floated: SaveData.PlayerSection = SaveData.PlayerSection.from_dict({
		"mag_model": 1.0, "primary_ammo": [14.0, 20.0, 7.0, 0.0],
		"primary_path": "res://data/weapons/m16a1.tres",
	})
	_check(floated.primary_ammo == [14, 20, 7, 0],
		"(e) float-typed JSON counts did not come back int: %s" % [floated.primary_ammo])
	var legacy: SaveData.PlayerSection = SaveData.PlayerSection.from_dict({
		"primary_path": "res://data/weapons/m16a1.tres", "primary_ammo": [13, 4],
		"secondary_path": "res://data/weapons/m1911.tres", "secondary_ammo": [7, 3],
	})
	_check(legacy.primary_ammo == [13, 20, 20, 20, 20],
		"(e) legacy [13,4] m16 pair should rebuild [13]+4 full mags, got %s" % [legacy.primary_ammo])
	_check(legacy.secondary_ammo == [7, 7, 7, 7],
		"(e) legacy [7,3] m1911 pair should rebuild [7]+3 full mags, got %s" % [legacy.secondary_ammo])
	var legacy_mosin: SaveData.PlayerSection = SaveData.PlayerSection.from_dict({
		"primary_path": "res://data/weapons/mosin.tres", "primary_ammo": [3, 2],
	})
	_check(legacy_mosin.primary_ammo == [3, 10],
		"(e) legacy mosin [3,2] should rebuild [tube 3, pool 10], got %s" % [legacy_mosin.primary_ammo])
	var legacy_rpg: SaveData.PlayerSection = SaveData.PlayerSection.from_dict({
		"primary_path": "res://data/weapons/rpg7.tres", "primary_ammo": [1, 2],
	})
	_check(legacy_rpg.primary_ammo == [1, 2],
		"(e) legacy rpg7 [1,2] is already [chambered, loose], got %s" % [legacy_rpg.primary_ammo])

	# --- (f) fossil tripwire: the mirrors stay dead --------------------------
	var hits: Array[String] = []
	_scan_dir("res://scripts", hits)
	for h in hits:
		_fail("(f) dead symbol resurrected: %s" % h)

	# --- (g) gunner belt stock + belt append shape ----------------------------
	var sq := SquadSystem.new()
	sq.mg_belts = 2
	_check(sq.take_mg_belt(), "(g) belt take refused with stock on hand")
	_check(sq.mg_belts == 1, "(g) take did not decrement: %d" % sq.mg_belts)
	_check(sq.take_mg_belt(), "(g) second take refused")
	_check(not sq.take_mg_belt(), "(g) take did not refuse at 0")
	_check(sq.mg_belts == 0, "(g) refused take mutated the stock: %d" % sq.mg_belts)
	sq.free()
	var wh := WeaponHolder.new()
	wh.primary_weapon = load("res://data/weapons/m60.tres") as WeaponData
	var belt_pouch: Array[int] = [37]
	wh.primary_mags = belt_pouch
	wh.add_full_mags(0, 1)
	_check(wh.primary_mags == [37, 100],
		"(g) one draw should append one full 100-rd belt, got %s" % [wh.primary_mags])
	wh.free()

	if failures == 0:
		print("PASS: magazine-model grammar OK (%d feed tags checked)" % EXPECTED_FEED.size())
	else:
		print("FAIL: magazine ammo suite had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _scan_dir(path: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_fail("(f) cannot open %s for the fossil sweep" % path)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full, hits)
		elif entry.ends_with(".gd"):
			var text: String = FileAccess.get_file_as_string(full)
			for sym: String in DEAD_SYMBOLS:
				if text.contains(sym):
					hits.append("%s contains '%s'" % [full, sym])
		entry = dir.get_next()
	dir.list_dir_end()
