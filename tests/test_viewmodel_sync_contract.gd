## test_viewmodel_sync_contract.gd - the bench IS the game camera. The WYSIWYG
## contract (CLAUDE.md "Camera/Viewmodel Setup") lives in two scenes that must stay
## byte-equivalent on eye height / FOV / holder transform; until now nothing enforced
## it. Parses both .tscn as text so no gameplay autoloads are needed.
## Run: godot --headless --path . res://tests/test_viewmodel_sync_contract.tscn
extends Node

const EYE_Y := 1.7
const BASE_FOV := 75.0

var _failures := 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


## Returns {property: raw_value_string} for the named node block, or empty if absent.
func _node_props(tscn_text: String, node_name: String) -> Dictionary:
	var out := {}
	var start := tscn_text.find("[node name=\"%s\"" % node_name)
	if start < 0:
		return out
	var body_start := tscn_text.find("]", start) + 1
	var body_end := tscn_text.find("[", body_start)
	if body_end < 0:
		body_end = tscn_text.length()
	for line in tscn_text.substr(body_start, body_end - body_start).split("\n"):
		var eq := line.find(" = ")
		if eq > 0:
			out[line.substr(0, eq).strip_edges()] = line.substr(eq + 3).strip_edges()
	return out


func _transform_y(raw: String) -> float:
	# Transform3D(xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz) -> oy
	var nums := raw.trim_prefix("Transform3D(").trim_suffix(")").split(",")
	if nums.size() != 12:
		return NAN
	return nums[10].strip_edges().to_float()


func _is_identity_basis(raw: String) -> bool:
	var nums := raw.trim_prefix("Transform3D(").trim_suffix(")").split(",")
	if nums.size() != 12:
		return false
	var identity := [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
	for i in 9:
		if absf(nums[i].strip_edges().to_float() - float(identity[i])) > 0.0001:
			return false
	return true


func _check_scene(path: String, cam_node: String, cam_y_from: String, holder_node: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("%s missing" % path)
		return
	var text := f.get_as_text()

	var cam := _node_props(text, cam_node)
	var y_src := _node_props(text, cam_y_from)
	var y := _transform_y(str(y_src.get("transform", ""))) if y_src.has("transform") else NAN
	if is_nan(y) or absf(y - EYE_Y) > 0.0001:
		_fail("%s: %s eye height %s != %.1f" % [path, cam_y_from, str(y), EYE_Y])
	# fov absent = Godot's default 75.0, which satisfies the contract
	var fov := float(cam.get("fov", BASE_FOV))
	if absf(fov - BASE_FOV) > 0.0001:
		_fail("%s: %s fov %.1f != %.1f" % [path, cam_node, fov, BASE_FOV])

	var holder := _node_props(text, holder_node)
	if text.find("[node name=\"%s\"" % holder_node) < 0:
		_fail("%s: %s node missing" % [path, holder_node])
	elif holder.has("transform") and not (
			_is_identity_basis(str(holder["transform"]))
			and absf(_transform_y(str(holder["transform"]))) < 0.0001):
		_fail("%s: %s transform is not identity: %s" % [path, holder_node, holder["transform"]])


func _ready() -> void:
	_check_scene("res://scenes/player/player.tscn", "Camera3D", "Head", "WeaponHolder")
	_check_scene("res://scenes/weapons/viewmodel_editor.tscn", "Camera3D", "Camera3D", "WeaponHolder")
	if _failures == 0:
		print("PASS: viewmodel sync contract - bench camera matches player camera")
	else:
		print("FAIL: %d sync contract failures" % _failures)
	get_tree().quit(_failures)
