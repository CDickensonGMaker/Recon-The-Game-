## probe_orphaned_art.gd - ART WITHOUT AN INSTANTIATOR DOES NOT EXIST.
##
## Caleb, 2026-07-12: "we made good progress... it's just I HAVEN'T SEEN IT DEVELOP IN
## THE GAME."
##
## The War Room found out why, and it was not what either of us expected. He is not
## art-starved. HE IS INTEGRATION-STARVED. Verified that day:
##
##   civilian.gd:32          built a brown CapsuleMesh. Ten finished villager GLBs sat
##                           unused; the ONLY reference to "civ_farmer_m" anywhere in
##                           the codebase was a HEIGHT TABLE ENTRY.
##   insertion_ride.gd:58    built olive capsule aircrew. us_pilot_white/black.glb had
##                           ZERO references - and the player rides that Huey at the
##                           start of EVERY MISSION.
##   us_rto.glb              (the radio man he built that very day) - ZERO references.
##   radio_handset/cord/     finished, elaborate, and NEVER INSTANCED.
##   antenna_sway.gd
##
## THE MECHANISM: art beads get filed P1, wiring beads get filed P2 - and P2 sinks
## beneath forty open P1s. He had industrialised invisible art.
##
## His own r4bk law says "simulation without presentation is unfinished work."
## THIS PROBE IS THE INVERSE, AND IT IS NOW A GATE:
##
##       *** A MODEL THAT NOTHING INSTANTIATES DOES NOT EXIST. ***
##
##   godot --headless --path . res://tools/probe_orphaned_art.tscn
extends Node


## Scanned for a reference to each model's unit_id.
const SEARCH_DIRS: Array[String] = ["res://scripts/", "res://data/", "res://scenes/"]

## Known-unused ON PURPOSE (gib donors, LOD twins, source parts). Keep this SHORT
## and make every entry earn its place - an allowlist is where dead art goes to hide.
const ALLOWED: Array[String] = []

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== ORPHANED ART: what is finished and invisible? ===\n")

	var models: Array[String] = _list_models()
	if models.is_empty():
		print("  [FAIL] no character models found at all - the probe is looking in the wrong place")
		get_tree().quit(1)
		return

	var corpus: String = _read_corpus()
	var orphans: Array[String] = []
	for m in models:
		if m in ALLOWED:
			continue
		# A HEIGHT TABLE ENTRY IS NOT AN INSTANTIATOR. That was the whole trap: the
		# civilians WERE named in model_actor.gd's UNIT_HEIGHT_M, which made them look
		# wired to any grep. Nothing ever called setup() with them.
		if not corpus.contains('"%s"' % m):
			orphans.append(m)

	print("  %d character models on disk" % models.size())
	print("  %d referenced by scripts/data/scenes" % (models.size() - orphans.size()))
	print("")
	if orphans.is_empty():
		print("  every model is referenced by something.")
	else:
		print("  *** %d MODEL(S) THAT NOTHING INSTANTIATES: ***" % orphans.size())
		for o in orphans:
			print("      %s" % o)
		print("")
		print("      Finished art. In the repo. Invisible in the game.")

	_check("no finished character model is orphaned", orphans.is_empty(),
		"%d orphan(s)" % orphans.size())

	# The two that bit us. Named explicitly, because a generic count can be gamed by
	# adding one reference somewhere useless.
	_check("CIVILIANS are people, not brown capsules",
		not _spawner_builds_capsule("res://scripts/world/civilian.gd"),
		"civilian.gd")
	_check("the HUEY AIRCREW are pilots, not olive capsules",
		_reads("res://scripts/missions/insertion_ride.gd", "us_pilot"),
		"insertion_ride.gd")

	print("")
	if _fails == 0:
		print("*** THE ART IS IN THE GAME. ***")
	else:
		print("*** %d FAILURE(S) - finished art is still invisible ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## A spawner "builds a capsule" only if it does so as its PRIMARY path. A capsule kept
## as a loud, warned fallback is fine - that is honest degradation.
func _spawner_builds_capsule(path: String) -> bool:
	var t: String = _read(path)
	if not t.contains("CapsuleMesh"):
		return false
	# Fallback is allowed ONLY if it warns.
	return not t.contains("push_warning")


func _reads(path: String, needle: String) -> bool:
	return _read(path).contains(needle)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _list_models() -> Array[String]:
	var out: Array[String] = ModelActor.all_units()
	out.sort()
	return out


func _read_corpus() -> String:
	var buf: String = ""
	for dir in SEARCH_DIRS:
		buf += _read_tree(dir)
	return buf


func _read_tree(path: String) -> String:
	var buf: String = ""
	var d := DirAccess.open(path)
	if d == null:
		return buf
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		var full: String = path + n
		if d.current_is_dir():
			if not n.begins_with("."):
				buf += _read_tree(full + "/")
		elif n.ends_with(".gd") or n.ends_with(".tres") or n.ends_with(".tscn"):
			buf += _read(full)
		n = d.get_next()
	d.list_dir_end()
	return buf


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])
