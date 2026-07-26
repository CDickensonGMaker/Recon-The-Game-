## test_viewmodel_contract.gd - the IMPORTED viewmodel GLBs honor the manifest
## (tools/viewmodel_manifest.json): every clip present after Godot's import, the
## MuzzlePoint marker findable by name. This is the Godot-side layer of the FP
## pipeline validator (research doc production/research/blender_godot_fp_pipeline_2026-07-25.md
## section 5D); the Blender-side layer runs in tools/export_all_viewmodels.py.
## Run: godot --headless --path . res://tests/test_viewmodel_contract.tscn
extends Node

var _failures := 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var f := FileAccess.open("res://tools/viewmodel_manifest.json", FileAccess.READ)
	if f == null:
		_fail("viewmodel_manifest.json missing")
		return _finish()
	var man: Dictionary = JSON.parse_string(f.get_as_text())
	if man.is_empty():
		_fail("viewmodel_manifest.json did not parse")
		return _finish()
	var guns: Dictionary = man.get("guns", {})
	for gun in guns.keys():
		_check_gun(str(gun), guns[gun] as Dictionary, str(man.get("output_dir", "")))
	_finish()


func _check_gun(gun: String, spec: Dictionary, out_dir: String) -> void:
	var path := "res://%s/%s_fp.glb" % [out_dir, gun]
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("%s: %s failed to load (not imported? run --headless --import)" % [gun, path])
		return
	var inst := packed.instantiate()
	add_child(inst)
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		_fail("%s: no AnimationPlayer in the imported scene" % gun)
	else:
		var have := ap.get_animation_list()
		for clip in spec.get("clips", []):
			if not str(clip) in have:
				_fail("%s: clip '%s' missing after import (have %s)" % [gun, clip, have])
	if inst.find_child("MuzzlePoint", true, false) == null:
		_fail("%s: MuzzlePoint marker missing - hip fire has no spawn point" % gun)
	inst.queue_free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: viewmodel contract - manifest clips + MuzzlePoint survive Godot import")
	else:
		print("FAIL: %d viewmodel contract failures" % _failures)
	get_tree().quit(_failures)
