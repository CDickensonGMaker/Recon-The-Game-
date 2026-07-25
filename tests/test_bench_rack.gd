## test_bench_rack.gd - the armorer's rack contract.
##   1. Every data/weapons/*.tres with an arms viewmodel is a RACK candidate, and
##      rack_for_tier(top tier) serves EXACTLY the complete ones - a gun with no
##      first-person arms (or a missing projectile resource) never reaches the rack.
##   2. Every served entry's viewmodel scene exists on disk and loads.
##   3. Drawing a weapon replaces the primary and loads that weapon's viewmodel.
##   4. Rack fouling survives a rack-and-redraw round trip.
##   5. NEGATIVE CONTROL: a dirty weapon racked and redrawn is still dirty -
##      swapping is not a free clean.
## Title-tier gating of the rack is probed in tests/test_reputation.gd (ADR-032).
## Run: godot --headless --path . res://tests/test_bench_rack.tscn
extends Node

const WEAPON_DIR := "res://data/weapons"
const ARMS_SUFFIX := "_arms_viewmodel.tscn"

var _failures: int = 0


func _ready() -> void:
	_check_rack_membership()
	_check_viewmodels_load()
	_check_draw_swaps_primary()
	_check_condition_round_trip()
	_check_negative_controls()
	if _failures == 0:
		print("test_bench_rack: OK")
	else:
		print("test_bench_rack: FAIL (%d)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(msg: String) -> void:
	_failures += 1
	print("  FAIL: %s" % msg)


## The rack served at the top tier must match what the data says is complete, both ways.
func _check_rack_membership() -> void:
	var expected: Array[String] = []
	for f: String in DirAccess.get_files_at(WEAPON_DIR):
		var name: String = f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var path: String = "%s/%s" % [WEAPON_DIR, name]
		var data: WeaponData = load(path) as WeaponData
		if data == null:
			_fail("%s will not load as WeaponData" % path)
			continue
		if data.model_path.ends_with(ARMS_SUFFIX):
			expected.append(path)

	if expected.size() != 11:
		_fail("expected 11 weapons with arms viewmodels, data says %d" % expected.size())

	var served: Array[String] = ArmorersBench.rack_for_tier(CampaignState.TITLES.size() - 1)
	for path: String in expected:
		if not ArmorersBench.RACK.has(path):
			_fail("%s has an arms viewmodel but is not a rack candidate" % path)
		if not served.has(path):
			_fail("%s is complete but the top tier does not serve it" % path)
	for path: String in served:
		if not expected.has(path):
			_fail("%s is served but has no arms viewmodel" % path)


func _check_viewmodels_load() -> void:
	for path: String in ArmorersBench.rack_for_tier(CampaignState.TITLES.size() - 1):
		var data: WeaponData = load(path) as WeaponData
		if data == null:
			_fail("rack entry will not load: %s" % path)
			continue
		if not ResourceLoader.exists(data.model_path):
			_fail("%s names a viewmodel that is not on disk: %s" % [data.id, data.model_path])
		elif load(data.model_path) == null:
			_fail("%s viewmodel will not load: %s" % [data.id, data.model_path])


## The bench under test, plus a holder for it to act on. The probe drives the
## SHIPPING _draw_from_rack / _tick_clean - it must never reimplement them.
var _bench: ArmorersBench


func _make_holder() -> WeaponHolder:
	if _bench == null:
		_bench = ArmorersBench.new()
		add_child(_bench)
	var head := Node3D.new()
	var cam := Camera3D.new()
	var wh := WeaponHolder.new()
	head.add_child(cam)
	cam.add_child(wh)
	add_child(head)
	return wh


func _draw(wh: WeaponHolder, path: String) -> void:
	_bench._draw_from_rack(wh, path)


## One full 20-second strip, driven through the shipping clean tick.
func _clean(wh: WeaponHolder) -> void:
	_bench._progress = 0.0
	_bench._cleaning = true
	_bench._tick_clean(wh, ArmorersBench.BENCH_SECONDS + 1.0)


func _check_draw_swaps_primary() -> void:
	var wh := _make_holder()
	for path: String in ArmorersBench.rack_for_tier(CampaignState.TITLES.size() - 1):
		var data: WeaponData = load(path) as WeaponData
		_draw(wh, path)
		if wh.primary_weapon == null or wh.primary_weapon.id != data.id:
			_fail("drawing %s did not become the primary" % data.id)
		if wh.current_weapon == null or wh.current_weapon.id != data.id:
			_fail("drawing %s did not become the carried weapon" % data.id)
		if wh.weapon_model == null:
			_fail("drawing %s loaded no viewmodel" % data.id)
	wh.get_parent().queue_free()


func _check_condition_round_trip() -> void:
	CampaignState.rack_condition = {}
	var wh := _make_holder()
	_draw(wh, "res://data/weapons/ak47.tres")
	if not is_equal_approx(wh.weapon_condition, 100.0):
		_fail("a weapon never drawn should come off the rack at 100, got %.1f" % wh.weapon_condition)
	wh.weapon_condition = 43.0
	_draw(wh, "res://data/weapons/m16a1.tres")
	_draw(wh, "res://data/weapons/ak47.tres")
	if not is_equal_approx(wh.weapon_condition, 43.0):
		_fail("racked at 43%%, redrawn at %.1f%% - fouling did not survive the rack" % wh.weapon_condition)

	# The bench is still the only road back to 100.
	_clean(wh)
	if not is_equal_approx(wh.weapon_condition, 100.0):
		_fail("the %ds strip left the weapon at %.1f%%, not 100" % [
			int(ArmorersBench.BENCH_SECONDS), wh.weapon_condition])
	_draw(wh, "res://data/weapons/m16a1.tres")
	_draw(wh, "res://data/weapons/ak47.tres")
	if not is_equal_approx(wh.weapon_condition, 100.0):
		_fail("a repaired weapon did not go back on the rack clean")
	wh.get_parent().queue_free()


## Each of these asserts something the code must NOT do. If they all pass
## trivially, the probe above proves nothing.
func _check_negative_controls() -> void:
	CampaignState.rack_condition = {}
	var wh := _make_holder()

	_draw(wh, "res://data/weapons/m16a1.tres")
	wh.weapon_condition = 12.0
	_draw(wh, "res://data/weapons/m60.tres")
	if is_equal_approx(wh.weapon_condition, 12.0):
		_fail("drawing a fresh M60 inherited the M16's fouling")
	_draw(wh, "res://data/weapons/m16a1.tres")
	if wh.weapon_condition >= 99.99:
		_fail("cycling weapons laundered a dirty rifle back to clean")

	var top: Array[String] = ArmorersBench.rack_for_tier(CampaignState.TITLES.size() - 1)
	if top.has("res://data/weapons/m79.tres") \
			or top.has("res://data/weapons/m72_law.tres") \
			or top.has("res://data/weapons/rpg7.tres") \
			or top.has("res://data/weapons/m26_grenade.tres"):
		_fail("a weapon with no arms viewmodel reached the rack")

	# A partial strip must not bank anything: 100 is all-or-nothing.
	wh.weapon_condition = 20.0
	_bench._cleaning = true
	_bench._tick_clean(wh, ArmorersBench.BENCH_SECONDS * 0.5)
	if wh.weapon_condition > 20.0:
		_fail("half a strip already restored condition (%.1f) - the 20s hold means nothing" % wh.weapon_condition)
	_bench._cleaning = false
	_bench._progress = 0.0
	wh.get_parent().queue_free()
