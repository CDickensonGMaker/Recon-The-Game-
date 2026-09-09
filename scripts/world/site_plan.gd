## A site plan: the data a place is, before anything is built (ADR-043 §1).
##
## THE SCENE IS A PLAN, NOT A PREFAB (ADR-041). A plan names PART IDS and LOCAL transforms and
## nothing else - it never carries world coordinates, never carries terrain outside its own
## footprint, and never carries a node. That is what keeps ADR-041's anti-creep rule true: a
## plan cannot know where it is, so it cannot become an outdoor AO wearing a costume.
##
## Local space is X/Z metres from the site centre, Y metres from the seat. `yaw_deg` is the
## only rotation a part may carry: a part tilted off vertical no longer meets the ground it is
## seated on, and every collision and station offset in the kit assumes an upright part.
class_name SitePlan
extends RefCounted

const DIR: String = "res://data/site_plans"
## Bumped when the FILE SHAPE changes, never when a plan's contents change.
const VERSION: int = 1

var plan_name: String = "untitled"
## [{id: String, pos: Vector3 (local), yaw_deg: float}]
var parts: Array[Dictionary] = []
## Radius and strength of the ground seat this place asks for. ADR-041 §6 makes declaring it
## BINDING: a site that silently demands flattening = 1.0 is requesting a pancake.
var flatten_radius: float = 0.0
var flatten_strength: float = 0.0
var flatten_shoulder: float = 0.0


static func path_for(n: String) -> String:
	return "%s/%s.json" % [DIR, n]


func add_part(id: String, local_pos: Vector3, yaw_deg: float = 0.0) -> void:
	parts.append({"id": id, "pos": local_pos, "yaw_deg": yaw_deg})


## Returns "" when the plan is fit to stamp, else the first reason it is not. Callers must
## treat a non-empty return as fatal: a half-valid plan stamps a half-built place, and a
## half-built place is indistinguishable from a bug in the builder.
func validate(registry: KitRegistry) -> String:
	if parts.is_empty():
		return "plan '%s' has no parts" % plan_name
	if flatten_strength < 0.0 or flatten_strength > 1.0:
		return "flatten_strength %.2f is outside 0..1" % flatten_strength
	for i in range(parts.size()):
		var p: Dictionary = parts[i]
		var id: String = str(p.get("id", ""))
		if id == "":
			return "part %d has no id" % i
		if registry != null and not registry.has_model(id):
			return "part %d ('%s') has no model in the kit" % [i, id]
	return ""


func to_dict() -> Dictionary:
	var out: Array = []
	for p in parts:
		var v: Vector3 = p.get("pos", Vector3.ZERO)
		out.append({"id": str(p.get("id", "")), "pos": [v.x, v.y, v.z],
			"yaw_deg": float(p.get("yaw_deg", 0.0))})
	return {
		"version": VERSION,
		"name": plan_name,
		"flatten": {"radius": flatten_radius, "strength": flatten_strength,
			"shoulder": flatten_shoulder},
		"parts": out,
	}


func save() -> bool:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path_for(plan_name), FileAccess.WRITE)
	if f == null:
		push_error("[PLAN] cannot write %s" % path_for(plan_name))
		return false
	f.store_string(JSON.stringify(to_dict(), "\t", true))
	f.close()
	return true


static func load_from(n: String) -> SitePlan:
	var p: String = path_for(n)
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("[PLAN] %s is not a JSON object" % p)
		return null
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != VERSION:
		push_error("[PLAN] %s is version %s, this build reads %d"
			% [p, str(d.get("version", "?")), VERSION])
		return null
	var plan := SitePlan.new()
	plan.plan_name = str(d.get("name", n))
	var fl: Dictionary = d.get("flatten", {}) as Dictionary
	plan.flatten_radius = float(fl.get("radius", 0.0))
	plan.flatten_strength = float(fl.get("strength", 0.0))
	plan.flatten_shoulder = float(fl.get("shoulder", 0.0))
	for entry_any in (d.get("parts", []) as Array):
		var e: Dictionary = entry_any as Dictionary
		if e == null:
			continue
		var v: Array = e.get("pos", []) as Array
		if v == null or v.size() != 3:
			continue
		plan.add_part(str(e.get("id", "")),
			Vector3(float(v[0]), float(v[1]), float(v[2])),
			float(e.get("yaw_deg", 0.0)))
	return plan
