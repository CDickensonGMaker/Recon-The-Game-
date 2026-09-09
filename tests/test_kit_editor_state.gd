## test_kit_editor_state.gd - the kit editor's operations, driven without a window (ADR-043 §5).
##
## The tool itself needs a camera and a mouse, so it can only be judged by a person looking at
## it. That is exactly why every operation that can be WRONG was split into KitEditorState:
## this project's law is that nothing closes without a probe, and "I clicked around and it
## seemed fine" closes nothing.
##
## Run: godot --headless --path . res://tests/test_kit_editor_state.tscn
extends Node

const PLAN_NAME: String = "_probe_editor"

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var reg: KitRegistry = KitRegistry.load_kit()
	var st := KitEditorState.new()
	st.setup(reg)

	if st.palette.is_empty():
		_fail("palette is empty - no placeable part in the kit")
		_finish()
		return

	# Cycling must wrap in both directions. An editor that walks off the end of its own
	# palette is the first thing a user finds and the last thing anyone tests.
	var first: String = st.current_palette_id()
	st.cycle_palette(-1)
	var back: String = st.current_palette_id()
	st.cycle_palette(1)
	if st.current_palette_id() != first:
		_fail("cycling back and forth did not return to the same part")
	if st.palette.size() > 1 and back == first:
		_fail("cycling backwards did not move the palette")

	if st.place(Vector3(3.0, 0.0, -2.0)) != 0:
		_fail("first place() did not return index 0")
	st.place(Vector3(-4.0, 0.0, 5.0))
	if st.plan.parts.size() != 2:
		_fail("expected 2 parts, have %d" % st.plan.parts.size())

	# Selection is by proximity in the plan's own local space.
	if st.select_nearest(Vector3(-4.2, 0.0, 5.1)) != 1:
		_fail("select_nearest picked the wrong part")
	if st.select_nearest(Vector3(500.0, 0.0, 500.0)) != -1:
		_fail("select_nearest matched something 500m away")

	st.select_nearest(Vector3(3.0, 0.0, -2.0))
	var before: Vector3 = st.plan.parts[st.selection]["pos"]
	st.nudge(Vector3(KitEditorState.NUDGE_M, 0.0, 0.0))
	var after: Vector3 = st.plan.parts[st.selection]["pos"]
	if not is_equal_approx(after.x - before.x, KitEditorState.NUDGE_M):
		_fail("nudge moved %.3fm, expected %.3f" % [after.x - before.x, KitEditorState.NUDGE_M])

	st.rotate_selected(1)
	if not is_equal_approx(float(st.plan.parts[st.selection]["yaw_deg"]), KitEditorState.YAW_STEP_DEG):
		_fail("rotate did not step yaw by %.1f" % KitEditorState.YAW_STEP_DEG)
	# Yaw must wrap rather than grow without bound - an unwrapped angle serialises as 3600
	# and reads as corrupt data to anyone opening the file.
	for _i in range(30):
		st.rotate_selected(1)
	var y: float = float(st.plan.parts[st.selection]["yaw_deg"])
	if y < 0.0 or y >= 360.0:
		_fail("yaw did not wrap: %.1f" % y)

	if not st.undo():
		_fail("undo returned false with edits on the stack")
	if not is_equal_approx(float(st.plan.parts[st.selection]["yaw_deg"]), y - KitEditorState.YAW_STEP_DEG):
		_fail("undo did not restore the previous yaw")

	# Undo must restore a DELETED part, which is the operation people actually undo.
	var count_before: int = st.plan.parts.size()
	st.select_nearest(Vector3(-4.0, 0.0, 5.0))
	st.delete_selected()
	if st.plan.parts.size() != count_before - 1:
		_fail("delete did not remove a part")
	st.undo()
	if st.plan.parts.size() != count_before:
		_fail("undo did not restore the deleted part")

	# Deleting with nothing selected must be a no-op, not a crash and not a silent removal
	# of part 0 - which is what an unguarded index would do.
	st.selection = -1
	if st.delete_selected():
		_fail("delete_selected acted with no selection")
	if st.nudge(Vector3.RIGHT):
		_fail("nudge acted with no selection")

	var why: String = st.save(PLAN_NAME)
	if why != "":
		_fail("save refused a valid plan: %s" % why)
	if not st.load_plan(PLAN_NAME):
		_fail("could not load the plan back")
	if st.plan.parts.size() != count_before:
		_fail("loaded plan has %d part(s), saved %d" % [st.plan.parts.size(), count_before])

	# The editor must REFUSE to write a plan the stamper would refuse to read.
	var bad := KitEditorState.new()
	bad.setup(reg)
	bad.plan.plan_name = "_probe_editor_bad"
	bad.plan.add_part("fb_not_a_real_part", Vector3.ZERO)
	if bad.save() == "":
		_fail("save() wrote a plan naming a part with no model")

	print("[KIT STATE] %d palette entr(ies), %d part(s) round-tripped"
		% [st.palette.size(), st.plan.parts.size()])
	_finish()


func _finish() -> void:
	for n in [PLAN_NAME, "_probe_editor_bad"]:
		var p: String = SitePlan.path_for(String(n))
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if _failures == 0:
		print("test_kit_editor_state: PASS")
	else:
		print("test_kit_editor_state: %d FAILURE(S)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
