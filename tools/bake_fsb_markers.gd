## bake_fsb_markers.gd - ADR-043 P0. Write the firebase's authored markers to disk so the
## runtime never has to build the compound to read them.
##
## Before this, SitePlanner._ensure_fsb_markers instantiated the whole 5,812-node scene and
## freed it purely to read ~500 marker origins - and it fired at PLAN time, because
## mission_generator.gd:519 and :722 both ask for fsb_gate_metrics before the world exists.
## The world then built the same scene again for real. Two builds per world build, one
## thrown away.
##
## RUN THIS AFTER EVERY FIREBASE RE-EXPORT. tests/test_fsb_marker_bake.tscn fails the build
## when the file has drifted from the model, so a forgotten bake is loud rather than silent.
##
## Run: godot --headless --path . res://tools/bake_fsb_markers.tscn
extends Node


func _ready() -> void:
	var baked: Dictionary = SitePlanner.bake_fsb_markers_from_scene()
	var markers: Dictionary = baked.get("markers", {}) as Dictionary
	var work: Array = baked.get("work", []) as Array

	if markers.is_empty() and work.is_empty():
		# Writing an empty bake would be worse than not writing one: the loader would
		# reject it, fall back to the walk, and the defect would hide behind a warning.
		print("bake_fsb_markers: FAIL - the walk found no markers at all; wrote nothing")
		get_tree().quit(1)
		return

	# Sorted keys so the file is byte-stable across runs and a diff shows real movement
	# rather than dictionary ordering.
	var out_markers: Dictionary = {}
	var keys: Array = markers.keys()
	keys.sort()
	for k in keys:
		var v: Vector3 = markers[k]
		out_markers[String(k)] = [v.x, v.y, v.z]

	# work is already sorted by (x, z) inside the walk - determinism is its contract, not
	# this tool's, so it is written in the order the walk produced.
	var out_work: Array = []
	for entry_any in work:
		var e: Array = entry_any
		var p: Vector3 = e[0]
		out_work.append([p.x, p.y, p.z, String(e[1]), bool(e[2])])

	var payload: Dictionary = {
		"version": SitePlanner.FSB_MARKER_BAKE_VERSION,
		"source": SitePlanner.FSB_MAIN_PATH,
		"markers": out_markers,
		"work": out_work,
	}

	var dir: String = SitePlanner.FSB_MARKER_BAKE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SitePlanner.FSB_MARKER_BAKE_PATH, FileAccess.WRITE)
	if f == null:
		print("bake_fsb_markers: FAIL - could not open %s for writing"
			% SitePlanner.FSB_MARKER_BAKE_PATH)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(payload, "\t", true))
	f.close()

	var dig: int = 0
	for entry_any in work:
		if bool((entry_any as Array)[2]):
			dig += 1
	print("bake_fsb_markers: wrote %d marker(s) and %d work point(s) (%d dig-classified) to %s"
		% [out_markers.size(), out_work.size(), dig, SitePlanner.FSB_MARKER_BAKE_PATH])
	get_tree().quit(0)
