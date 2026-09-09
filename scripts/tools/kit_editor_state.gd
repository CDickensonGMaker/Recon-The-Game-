## The kit editor's model: everything the tool does to a SitePlan, with no scene and no input.
##
## Split from the dev mode on purpose. The editor itself needs a window, a camera and a mouse,
## which means it can only ever be tested by a person looking at it - and this project's law is
## that nothing closes without a probe. Every operation that can be wrong lives here instead,
## where tests/test_kit_editor_state.tscn drives it headless.
##
## Undo is a plan snapshot, not a command log. A plan is a list of small dictionaries; copying
## it is cheaper than being clever, and a command log is where an editor's real bugs live.
class_name KitEditorState
extends RefCounted

const UNDO_DEPTH: int = 64
const NUDGE_M: float = 0.5
const YAW_STEP_DEG: float = 15.0

var plan: SitePlan = SitePlan.new()
var registry: KitRegistry = null
## Index into plan.parts, or -1. Everything that edits acts on this and nothing else.
var selection: int = -1
var palette: Array[String] = []
var palette_index: int = 0

var _undo: Array[Array] = []


func setup(reg: KitRegistry) -> void:
	registry = reg
	palette = reg.placeable_ids()
	palette_index = 0


func current_palette_id() -> String:
	if palette.is_empty():
		return ""
	return palette[palette_index % palette.size()]


func cycle_palette(step: int) -> void:
	if palette.is_empty():
		return
	palette_index = wrapi(palette_index + step, 0, palette.size())


## Add the palette's current part at a local offset. Returns its index, or -1 when the palette
## is empty - which is a real state on a checkout with no kit GLBs, not an error.
func place(local: Vector3) -> int:
	var id: String = current_palette_id()
	if id == "":
		return -1
	_push_undo()
	plan.add_part(id, local, 0.0)
	selection = plan.parts.size() - 1
	return selection


func select_nearest(local: Vector3, max_m: float = 6.0) -> int:
	var best: int = -1
	var best_d: float = max_m
	for i in range(plan.parts.size()):
		var d: float = (plan.parts[i]["pos"] as Vector3).distance_to(local)
		if d < best_d:
			best_d = d
			best = i
	selection = best
	return best


func nudge(delta: Vector3) -> bool:
	if not _has_selection():
		return false
	_push_undo()
	plan.parts[selection]["pos"] = (plan.parts[selection]["pos"] as Vector3) + delta
	return true


func rotate_selected(steps: int) -> bool:
	if not _has_selection():
		return false
	_push_undo()
	var y: float = float(plan.parts[selection]["yaw_deg"]) + float(steps) * YAW_STEP_DEG
	plan.parts[selection]["yaw_deg"] = wrapf(y, 0.0, 360.0)
	return true


func delete_selected() -> bool:
	if not _has_selection():
		return false
	_push_undo()
	plan.parts.remove_at(selection)
	selection = mini(selection, plan.parts.size() - 1)
	return true


func undo() -> bool:
	if _undo.is_empty():
		return false
	plan.parts = _undo.pop_back()
	selection = mini(selection, plan.parts.size() - 1)
	return true


## Refuses to write a plan the stamper would refuse to read. An editor that can save a broken
## plan has moved the failure from the person who can fix it to the loader that cannot.
func save(as_name: String = "") -> String:
	if as_name != "":
		plan.plan_name = as_name
	var why: String = plan.validate(registry)
	if why != "":
		return why
	return "" if plan.save() else "could not write %s" % SitePlan.path_for(plan.plan_name)


func load_plan(n: String) -> bool:
	var p: SitePlan = SitePlan.load_from(n)
	if p == null:
		return false
	_push_undo()
	plan = p
	selection = -1
	return true


func _has_selection() -> bool:
	return selection >= 0 and selection < plan.parts.size()


func _push_undo() -> void:
	var snap: Array[Dictionary] = []
	for p in plan.parts:
		snap.append(p.duplicate())
	_undo.append(snap)
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
