## test_gib_contract_all.gd - every character on disk carries the gib donor set.
## test_gore_rig covers only us_grunt_rifleman; this walks the whole cast so a new
## export cannot ship without its gibs. Regions and names come from GibSystem.
## Run: godot --headless --path . res://tests/test_gib_contract_all.tscn
extends Node3D

const REGIONS: Array[String] = ["head", "forearm_l", "forearm_r", "leg_l", "leg_r"]
const MODEL_DIRS: Array[String] = [
	"res://assets/us/characters/",
	"res://assets/nva_vc/characters/",
	"res://assets/civilians/characters/",
]

var _fail: int = 0
var _checked: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var units: Array[String] = _all_units()
	if units.is_empty():
		print("FAIL: no character .glb found - the scan path is wrong")
		get_tree().quit(1)
		return

	for unit in units:
		_check_unit(unit)

	print("")
	print("characters checked: %d" % _checked)
	if _fail > 0:
		print("*** GIB CONTRACT: %d character(s) incomplete ***" % _fail)
		print("A character missing grunt_<region> cannot lose that limb; missing")
		print("cap_<region> leaves an open stump when it does.")
		get_tree().quit(1)
	else:
		print("PASS: every character carries the full gib donor set")
		get_tree().quit(0)


func _all_units() -> Array[String]:
	var out: Array[String] = []
	for d in MODEL_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".glb") and not f.begins_with("anim_library"):
				out.append(d + f)
	out.sort()
	return out


func _check_unit(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("FAIL: %s will not load" % path.get_file())
		_fail += 1
		return
	var root: Node = packed.instantiate()
	if root == null:
		print("FAIL: %s will not instantiate" % path.get_file())
		_fail += 1
		return
	add_child(root)

	# Skinned-only rigs (weapons, props) are not characters - skip, don't fail.
	if root.find_child("PSXRig", true, false) == null:
		root.queue_free()
		return
	_checked += 1

	var missing_mesh: Array[String] = []
	var missing_cap: Array[String] = []
	for r in REGIONS:
		if root.find_child("grunt_" + r, true, false) == null:
			missing_mesh.append("grunt_" + r)
		if root.find_child("cap_" + r, true, false) == null:
			missing_cap.append("cap_" + r)

	var frags: int = 0
	for n in root.find_children("head_frag_*", "", true, false):
		frags += 1

	var name_only: String = path.get_file().trim_suffix(".glb")
	if missing_mesh.is_empty() and missing_cap.is_empty():
		print("  ok   %-24s (head_frag x%d)" % [name_only, frags])
	else:
		_fail += 1
		print("  FAIL %-24s missing donors=%s caps=%s" % [
			name_only,
			str(missing_mesh) if not missing_mesh.is_empty() else "-",
			str(missing_cap) if not missing_cap.is_empty() else "-",
		])

	root.queue_free()
