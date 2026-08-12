## test_collision_table.gd - CollisionTable's two authored tables must agree.
##
## A model with a STRUCTURES entry and no MATERIALS entry does not error at runtime:
## is_soft() warns and then substring-matches _SOFT_NAME_HINTS, so a "dug-in earth
## bunker hooch" matches "hooch" and ships SHOOTABLE THROUGH. The warning is in the
## log; the bunker is in the game. This gate is the difference.
##
## Run: godot --headless --path . res://tests/test_collision_table.tscn
extends Node


func _ready() -> void:
	var failures: int = 0

	var no_material: Array[String] = []
	for model: String in CollisionTable.STRUCTURES:
		if not CollisionTable.MATERIALS.has(model):
			no_material.append(model)
	no_material.sort()

	if no_material.size() > 0:
		print("")
		print("*** %d MODEL(S) IN STRUCTURES WITH NO AUTHORED MATERIAL ***" % no_material.size())
		for m: String in no_material:
			print("    + %s  ->  is_soft() would guess %s from the FILENAME" % [
				m, "SOFT" if CollisionTable._filename_guess(m) else "HARD"])
		print("")
		print("    Ballistics are AUTHORED DATA, not a guess about what somebody typed.")
		print("    Add each to CollisionTable.MATERIALS - collision_table.gd:212.")
		push_error("CollisionTable: %d model(s) in STRUCTURES have no MATERIALS entry." % no_material.size())
		failures += 1

	# A material with no footprint is the FIX 4 hazard from the other side: placing it
	# yields a silent 3x2x3 nav carve. Reported, not fatal - several are weapon mounts
	# that never route through get_entry.
	var no_footprint: Array[String] = []
	for model: String in CollisionTable.MATERIALS:
		if not CollisionTable.STRUCTURES.has(model):
			no_footprint.append(model)
	no_footprint.sort()
	if no_footprint.size() > 0:
		print("NOTE: %d material(s) with no STRUCTURES entry (get_entry would stand in): %s" % [
			no_footprint.size(), ", ".join(no_footprint)])

	# get_entry's fallback must stay distinguishable from every authored entry, or the
	# stand-in stops being detectable at all.
	for model: String in CollisionTable.STRUCTURES:
		var entry: Dictionary = CollisionTable.STRUCTURES[model]
		if not entry.has("box") or not entry.has("y_offset") or not entry.has("footprint"):
			print("FAIL: STRUCTURES['%s'] is missing box/y_offset/footprint" % model)
			push_error("CollisionTable: STRUCTURES['%s'] is malformed." % model)
			failures += 1

	print("")
	print("collision table: %d structures, %d materials" % [
		CollisionTable.STRUCTURES.size(), CollisionTable.MATERIALS.size()])
	if failures == 0:
		print("PASS: every structure carries an authored material")
		get_tree().quit(0)
	else:
		print("FAIL: %d collision table failure(s)" % failures)
		get_tree().quit(1)
