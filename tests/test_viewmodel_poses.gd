## test_viewmodel_poses.gd - no NEW stub ADS poses ship. A stub is the copy-paste
## placeholder ads_position (0, 0.05, 0.08) or an ads_rotation identical to
## hip_rotation on a gun that has a real model: it means "nobody ever aimed this
## gun on the bench" and the sights land nowhere at ADS.
## Existing stubs are grandfathered fossil-law style: the list ONLY shrinks -
## when a gun gets a real ADS pose, delete it here in the same change.
## Run: godot --headless --path . res://tests/test_viewmodel_poses.tscn
extends Node

const PLACEHOLDER_ADS := Vector3(0.0, 0.05, 0.08)
## 2026-07-26 audit: five guns carried the placeholder (ak47/m1911/rpd/rpg2) or a
## hip-copied ads_rotation with the placeholder position (mosin).
const GRANDFATHERED: Array[String] = ["ak47", "m1911", "mosin", "rpd", "rpg2"]

var _failures := 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _is_stub(w: WeaponData) -> bool:
	if w.model_path.is_empty():
		return false  # nothing to pose yet - covered by the manifest gap, not here
	if w.ads_position.distance_to(PLACEHOLDER_ADS) < 0.0001:
		return true
	# hip==ads pose entirely = never aimed (identical rotation alone is legal on
	# items with no sights, so require the position to match too)
	return w.ads_rotation == w.hip_rotation and w.ads_position == w.hip_position


func _ready() -> void:
	var dir := DirAccess.open("res://data/weapons")
	if dir == null:
		_fail("data/weapons missing")
		return _finish()
	var cleaned: Array[String] = []
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var w := load("res://data/weapons/" + f) as WeaponData
		if w == null:
			_fail("%s failed to load as WeaponData" % f)
			continue
		var stub := _is_stub(w)
		if stub and not w.id in GRANDFATHERED:
			_fail("%s: NEW stub ADS pose (placeholder position or hip==ads) - aim it on the bench" % w.id)
		elif not stub and w.id in GRANDFATHERED:
			cleaned.append(w.id)
	if not cleaned.is_empty():
		print("NOTE: %s now have real ADS poses - shrink GRANDFATHERED in this test" % str(cleaned))
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: viewmodel poses - no new stub ADS poses")
	else:
		print("FAIL: %d stub pose failures" % _failures)
	get_tree().quit(_failures)
