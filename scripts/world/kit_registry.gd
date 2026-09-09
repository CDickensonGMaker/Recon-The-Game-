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
## AUTHORED overlay, merged over the generated manifest. Every placeable part must appear in
## it or the stamp is refused - see contract_gap().
const CONTRACT: String = "res://data/world/kit_parts.json"

## part_id -> {tris, size: Vector3, solid, enterable, stations: [{local, work_type}],
##             props: [{local, prop_class}], crew/demands/supplies: Array[String],
##             model: String ("" when no .glb exists)}
var parts: Dictionary = {}

## part_id -> why it was retired, from the contract's "_retired" block. A retired part is
## refused by contract_gap() and never reaches placeable_ids(), so a .glb reappearing in the
## kit folder cannot quietly put it back on the palette. Retiring is a RULING and it lives in
## authored data; deleting the file would only mean the next export re-created it.
var retired: Dictionary = {}


static func load_kit() -> KitRegistry:
	var reg := KitRegistry.new()
	reg._read_manifest()
	reg._read_contract()
	reg._attach_models()
	return reg


## "" when this part may be stamped; otherwise the reason it may not.
##
## THE STAMP-TIME GATE. The naming contract has now failed SILENTLY four times in this project
## - a bulletproof tent, a bulletproof mess hall, an ammo crate that shipped as a white box for
## a month, and a stamped compound where nothing at all was on the blast bus. Every one was
## found by accident, hours or weeks later, because the failure mode is a DEFAULT rather than
## an error. This turns the fourth one into a refusal at the moment of placement.
func contract_gap(part_id: String) -> String:
	if retired.has(part_id):
		return "'%s' is RETIRED from the kit: %s" % [part_id, str(retired[part_id])]
	var e: Dictionary = parts.get(part_id, {}) as Dictionary
	if e == null or e.is_empty():
		return "'%s' is not in the kit at all" % part_id
	if not e.has("destructible"):
		return ("'%s' has no entry in %s - a part with no authored material ships BULLETPROOF "
			+ "and INDESTRUCTIBLE with no error, so it is refused instead") % [part_id, CONTRACT]
	var kind: String = str(e.get("destructible", ""))
	var meshes: Array = e.get("structure_meshes", []) as Array
	if kind != "" and meshes.is_empty():
		return "'%s' claims kind '%s' but names no structure mesh" % [part_id, kind]
	# A KNOWN LIMIT, stated loudly rather than handled wrongly. One Destructible takes ALL of
	# a part's colliders, so a second structure mesh in the same part would be adopted with
	# no shape left to give it. Splitting collision per structure needs authored collider
	# names, and the July review exports do not have them. Refuse until a part needs it.
	if meshes.size() > 1:
		return ("'%s' names %d structure meshes; only one per part is supported - split it "
			+ "into separate parts, or author per-mesh collider names first")% [part_id, meshes.size()]
	if kind != "" and not Destructible.HP_FOR.has(kind):
		return "'%s' claims kind '%s', which has no HP in Destructible.HP_FOR" % [part_id, kind]
	return ""


func destructible_kind(part_id: String) -> String:
	return str((parts.get(part_id, {}) as Dictionary).get("destructible", ""))


func structure_meshes(part_id: String) -> Array[String]:
	return _string_list((parts.get(part_id, {}) as Dictionary).get("structure_meshes", []))


func is_soft(part_id: String) -> bool:
	return bool((parts.get(part_id, {}) as Dictionary).get("soft", false))


func has_model(part_id: String) -> bool:
	var e: Dictionary = parts.get(part_id, {}) as Dictionary
	return e != null and str(e.get("model", "")) != ""


func model_path(part_id: String) -> String:
	return str((parts.get(part_id, {}) as Dictionary).get("model", ""))


## Stations a part carries, in the part's own local space. The stamper adds the part transform;
## nothing here knows where the part is, which is ADR-041's anti-creep rule one level down.
func stations_for(part_id: String) -> Array:
	return (parts.get(part_id, {}) as Dictionary).get("stations", []) as Array


## Roles a part BRINGS with it. Bare strings, checked against nothing here - the same rule
## the work vocabulary follows, and for the same reason: a kit for another war must be able
## to declare a role without editing this file. SitePlanner.site_plan_garrison() maps a role
## to an occupation; code that PLACES one may not gate on it.
func crew_for(part_id: String) -> Array[String]:
	return _string_list((parts.get(part_id, {}) as Dictionary).get("crew", []))


## What must be present in the same plan before this part's crew turns up.
func demands_for(part_id: String) -> Array[String]:
	return _string_list((parts.get(part_id, {}) as Dictionary).get("demands", []))


## What this part provides to other parts' demands.
func supplies_for(part_id: String) -> Array[String]:
	return _string_list((parts.get(part_id, {}) as Dictionary).get("supplies", []))


func placeable_ids() -> Array[String]:
	var out: Array[String] = []
	for k in parts.keys():
		if has_model(String(k)) and not retired.has(String(k)):
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
			# His kit ask included "certian npcs thatll spawn with certian building combos".
			# These three fields are the shape that keeps it expressible, and they are read
			# HERE and consumed NOWHERE - deliberately. Nothing spawns off them yet; the
			# combo resolver is post-demo work. What matters now is that a part CAN say it,
			# because a data model that cannot express it forecloses the capability and
			# costs a second migration to add later.
			#
			# All three are STRINGS, never enums: an enum would put the vocabulary back in
			# code, which is the exact defect FSB_STRUCTURE_KINDS still has.
			"crew": _string_list(src.get("crew", [])),
			"demands": _string_list(src.get("demands", [])),
			"supplies": _string_list(src.get("supplies", [])),
			"model": "",
		}


static func _string_list(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for e in (v as Array):
			var s: String = String(e)
			if s != "":
				out.append(s)
	return out


## Merge the authored overlay. Entries for parts the generated manifest never described are
## kept: a part can exist as a .glb with no manifest row, and its material still has to be
## authored somewhere.
func _read_contract() -> void:
	if not FileAccess.file_exists(CONTRACT):
		push_warning("[KIT] no authored contract at %s - every part will refuse to stamp" % CONTRACT)
		return
	var f := FileAccess.open(CONTRACT, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("[KIT] %s is not a JSON object" % CONTRACT)
		return
	var retired_block: Dictionary = (parsed as Dictionary).get("_retired", {}) as Dictionary
	if retired_block != null:
		for id_any in retired_block.keys():
			var rid: String = String(id_any)
			if not rid.begins_with("_"):
				retired[rid] = str(retired_block[id_any])
	for id_any in (parsed as Dictionary).keys():
		var id: String = String(id_any)
		if id.begins_with("_"):
			continue  # _doc / _fields / _retired / _why_this_file_exists
		var src: Dictionary = (parsed as Dictionary)[id_any] as Dictionary
		if src == null:
			continue
		if not parts.has(id):
			parts[id] = {"tris": 0, "size": Vector3.ZERO, "solid": true, "enterable": false,
				"stations": [], "props": [], "crew": [], "demands": [], "supplies": [],
				"model": ""}
		var e: Dictionary = parts[id]
		e["destructible"] = str(src.get("destructible", ""))
		e["structure_meshes"] = _string_list(src.get("structure_meshes", []))
		e["soft"] = bool(src.get("soft", false))
		# THE NPC HALF, AND WHY IT IS AUTHORED HERE RATHER THAN GENERATED.
		#
		# These three were read off the GENERATED manifest and nowhere else until
		# 2026-09-09, and the generated manifest carries none of them - twenty-two part
		# families, zero crew, zero demands, zero supplies. So the door his ask needed
		# ("certian npcs thatll spawn with certian building combos") was open onto an
		# empty room: every part answered [] and site_plan_garrison() would have had
		# nothing to resolve.
		#
		# Who mans a bunker is a RULING, exactly like whether a bunker is soft cover, and
		# it belongs beside that ruling in the authored file - not in a JSON a Blender
		# script rewrites. The overlay wins; a generated value survives only where the
		# author has said nothing.
		if src.has("crew"):
			e["crew"] = _string_list(src.get("crew", []))
		if src.has("demands"):
			e["demands"] = _string_list(src.get("demands", []))
		if src.has("supplies"):
			e["supplies"] = _string_list(src.get("supplies", []))


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
				# The same six fields _read_contract() seeds. This branch used to omit
				# crew/demands/supplies, so a .glb with neither a manifest row nor a
				# contract row produced an entry MISSING three of the contract's doors -
				# and the roundtrip probe's own field check would have gone red on it.
				parts[id] = {"tris": 0, "size": Vector3.ZERO, "solid": true,
					"enterable": false, "stations": [], "props": [],
					"crew": [], "demands": [], "supplies": [], "model": ""}
			(parts[id] as Dictionary)["model"] = "%s/%s" % [KIT_DIR, fn]
		fn = dir.get_next()
	dir.list_dir_end()
