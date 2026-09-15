## test_hearts_felt.gd - Hearts & Minds is FELT, never READ (ADR-019 §4, ADR-038 §2a).
## Pure: no world, no clock. Three guards:
##   1. HmLedger exposes no number about the player: idempotent notes, bands by kind, and no
##      method with a numeric return except place_key (which names a place).
##   2. No script outside hm_ledger.gd counts the deeds (`deeds.size()` / `deeds.keys()`).
##   3. Every felt line (FieldDirector.HM_LINES) names a subject and never a quantity, a rate
##      or a direction of change: no numerals, no comparatives of degree, no more/less/than
##      before, no better/worse/turning.
extends Node

const HmS := preload("res://scripts/world/hm_ledger.gd")
const FdS := preload("res://scripts/missions/field_director.gd")

var _fail: int = 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("\n=== HEARTS FELT ===")
	_ledger()
	_no_counting()
	_lines()
	if _fail == 0:
		print("=== HEARTS FELT PASS ===")
	else:
		print("=== HEARTS FELT FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _ledger() -> void:
	var led: RefCounted = HmS.new()
	var key: int = HmS.place_key(Vector3(120.4, 3.0, 310.9))
	_check(key == HmS.place_key(Vector3(120.9, 99.0, 310.1)),
		"a village key is the whole-metre centre, not the height or the fraction")
	_check(led.band(key) == HmS.BAND_QUIET, "a ville with no deeds reads quiet")
	_check(led.note("fire/%d/p1" % key, HmS.KIND_FIRE, key, 9.5), "first note is new")
	_check(not led.note("fire/%d/p1" % key, HmS.KIND_FIRE, key, 9.6), "second note of the same id changes nothing")
	_check(led.band(key) == HmS.BAND_WARY, "fire near the ville reads wary")
	led.note("informer/%d/talked" % key, HmS.KIND_INFORMER, key, 10.0)
	_check(led.band(key) == HmS.BAND_WARY, "the informer's own act is not held against the player by the ville")
	led.note("civ/%d/farmer_3/killed" % key, HmS.KIND_KILLED, key, 11.0)
	_check(led.band(key) == HmS.BAND_HOSTILE, "a villager killed by his hand reads hostile")
	var other: int = HmS.place_key(Vector3(400.0, 0.0, 80.0))
	_check(led.band(other) == HmS.BAND_QUIET, "the next ville over knows nothing of it")
	var back: RefCounted = HmS.new()
	back.from_save(led.to_save())
	_check(back.band(key) == HmS.BAND_HOSTILE and back.has("informer/%d/talked" % key),
		"the ledger survives a save round-trip")
	# No numeric return about the player. Reflection over the script's own methods.
	for m in (led.get_script() as Script).get_script_method_list():
		var rt: int = int(m.return.type)
		if m.name == "place_key":
			continue
		_check(rt != TYPE_INT and rt != TYPE_FLOAT,
			"HmS.%s returns no number" % m.name)


func _no_counting() -> void:
	var offenders: Array[String] = []
	for path in ["res://scripts/missions/field_director.gd", "res://scripts/world/civilian.gd",
			"res://scripts/ai/civilian_schedules.gd", "res://scripts/levels/demo_game.gd",
			"res://scripts/autoload/campaign_state.gd", "res://scripts/missions/siege_director.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text: String = f.get_as_text()
		if text.contains("deeds.size()") or text.contains("deeds.keys().size()") \
				or text.contains("hearts.deeds"):
			offenders.append(path)
	_check(offenders.is_empty(), "no consumer counts the deeds (%s)" % ", ".join(offenders))


func _lines() -> void:
	var digits := RegEx.new()
	digits.compile("[0-9]")
	var banned := RegEx.new()
	# comparatives of degree, rates and directions - the words that rebuild the meter
	banned.compile("(?i)\\b(more|less|than before|better|worse|turning|turned|again|every time|half|most|least|percent|all the way)\\b")
	for k in FdS.HM_LINES.keys():
		var line: String = String(FdS.HM_LINES[k])
		_check(digits.search(line) == null, "%s carries no numeral" % k)
		_check(banned.search(line) == null, "%s names no quantity, rate or direction" % k)
		_check(line.split(" ").size() <= 20, "%s is under twenty words" % k)
