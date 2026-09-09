## The kit: what parts exist, what each one carries, and where its model is (ADR-043 §4).
##
## THE WORK VOCABULARY LIVES IN THE PART, NOT IN CODE. A station's `work_type` is read as a
## bare string out of the part manifest and never checked against any const in this codebase.
## That is deliberate and it is the constraint that makes a second kit possible: a WW1 trench
## part must be able to declare `work_firestep` without anyone editing site_planner.gd. Code
## that needs to know what a work type MEANS may map it; code that places one may not gate on it.
##
## The manifest is assets/.../firebase/kit/firebase_set.json, written by tools/gen_firebase.py
## in July and, until ADR-043, read by nothing. It carries per-part tris, size, solid, enterable
## and markers with work_type / prop_class / door_width. Its models are the .glb files beside
## it; a part with a manifest entry and no .glb is KNOWN but not PLACEABLE, and has_model()
## is the only question the stamper is allowed to ask.
class_name KitRegistry
extends RefCounted

const KIT_DIR: String = "res://assets/world/building models/structures/firebase/kit"
const MANIFEST: String = KIT_DIR + "/firebase_set.json"

## part_id -> {tris, size: Vector3, solid, enterable, stations: [{local, work_type}],
##             props: [{local, prop_class}], model: String ("" when no .glb exists)}
var parts: Dictionary = {}


static func load_kit() -> KitRegistry:
	var reg := KitRegistry.new()
	reg._read_manifest()
	reg._attach_models()
	return reg


func has_model(part_id: String) -> bool:
	var e: Dictionary = parts.get(part_id, {}) as Dictionary
	return e != null and str(e.get("model", "")) != ""


func model_path(part_id: String) -> String:
	return str((parts.get(part_id, {}) as Dictionary).get("model", ""))


## Stations a part carries, in the part's own local space. The stamper adds the part transform;
## nothing here knows where the part is, which is ADR-041's anti-creep rule one level down.
func stations_for(part_id: String) -> Array:
	return (parts.get(part_id, {}) as Dictionary).get("stations", []) as Array


func placeable_ids() -> Array[String]:
	var out: Array[String] = []
	for k in parts.keys():
		if has_model(String(k)):
			out.append(String(k))
	out.sort()
	return out


func _read_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST):
		push_warning("[KIT] no manifest at %s - the kit is empty" % MANIFEST)
		return
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("[KIT] %s is not a JSON object" % MANIFEST)
		return
	for id_any in (parsed as Dictionary).keys():
		var id: String = String(id_any)
		var src: Dictionary = (parsed as Dictionary)[id_any] as Dictionary
		var size_arr: Array = src.get("size", []) as Array
		var size := Vector3.ZERO
		if size_arr != null and size_arr.size() == 3:
			size = Vector3(float(size_arr[0]), float(size_arr[1]), float(size_arr[2]))
		var stations: Array = []
		var props: Array = []
		for m_any in (src.get("markers", []) as Array):
			var m: Dictionary = m_any as Dictionary
			if m == null:
				continue
			var pos_arr: Array = m.get("pos", []) as Array
			if pos_arr == null or pos_arr.size() != 3:
				continue
			# The manifest is authored in Blender space: pos is [x, y, z] with Y forward and
			# Z up. Godot is Y up, -Z forward, which is the same swap gen_firebase.py's own
			# exporter applies to the geometry - so a station read raw would sit at the part's
			# height offset in front of it instead of on the ground beside it.
			var local := Vector3(float(pos_arr[0]), float(pos_arr[2]), -float(pos_arr[1]))
			var wt: String = str(m.get("work_type", ""))
			var pc: String = str(m.get("prop_class", ""))
			if wt != "":
				stations.append({"local": local, "work_type": wt, "name": str(m.get("name", ""))})
			if pc != "":
				props.append({"local": local, "prop_class": pc, "name": str(m.get("name", ""))})
		parts[id] = {
			"tris": int(src.get("tris", 0)),
			"size": size,
			"solid": bool(src.get("solid", true)),
			"enterable": bool(src.get("enterable", false)),
			"stations": stations,
			"props": props,
			"model": "",
		}


## A manifest entry earns a model when kit/<id>.glb is on disk. Models with no manifest entry
## are registered too, with no stations - a part nobody described is still placeable, and
## saying so is better than pretending it does not exist.
func _attach_models() -> void:
	var dir := DirAccess.open(KIT_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".glb"):
			var id: String = fn.get_basename()
			if not parts.has(id):
				parts[id] = {"tris": 0, "size": Vector3.ZERO, "solid": true,
					"enterable": false, "stations": [], "props": [], "model": ""}
			(parts[id] as Dictionary)["model"] = "%s/%s" % [KIT_DIR, fn]
		fn = dir.get_next()
	dir.list_dir_end()
