## test_placement_paths.gd - dlox structural probe (ADR-028/ADR-029).
## Static scan: (1) world-placement entry points may only be called from the
## manifest files - a second placement path fails the build; (2) placement
## files may not draw from the GLOBAL rng (bare randf/randi = unseeded world).
## The arena's hand-wired build is the ONE recorded exception until qjf0 lands.
## Run: godot --headless --path . res://tests/test_placement_paths.tscn
extends Node

const PLACEMENT_CALLS: Array[String] = [
	"place_structure(", "stamp_village(", "stamp_vc_camp(", "stamp_lz(",
	"place_firebase_main(", "place_prop(",
]
## Files allowed to CALL placement entries (self-calls inside site_planner are fine).
const CALLER_MANIFEST: Array[String] = [
	"res://scripts/world/site_planner.gd",
	"res://scripts/missions/mission_generator.gd",
]
## The recorded exception: hand-wired bench world, dies with qjf0 (arena wrapper).
const KNOWN_EXCEPTIONS: Array[String] = [
	"res://scripts/levels/ai_stress_arena.gd",
]
## Placement-owning files that must never touch the global rng.
const SEEDED_FILES: Array[String] = [
	"res://scripts/world/site_planner.gd",
	"res://scripts/missions/mission_generator.gd",
	"res://scripts/world/paddy_stamper.gd",
	"res://scripts/enemies/patrol_generator.gd",
	"res://scripts/missions/lazy_group.gd",
	"res://scripts/missions/convoy_spawner.gd",
]
const SCAN_DIRS: Array[String] = ["res://scripts", "res://terrain"]


func _ready() -> void:
	var failures: int = 0
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_walk(d, files)

	for path in files:
		var src: String = FileAccess.get_file_as_string(path)
		if src.is_empty():
			continue
		var in_manifest: bool = path in CALLER_MANIFEST
		var known: bool = path in KNOWN_EXCEPTIONS
		for call in PLACEMENT_CALLS:
			if not src.contains(call):
				continue
			# Strip comment lines before judging.
			var live := false
			for line in src.split("\n"):
				var code: String = line.get_slice("#", 0)
				if code.contains(call) and not code.strip_edges().begins_with("func "):
					live = true
					break
			if not live:
				continue
			if known:
				print("KNOWN EXCEPTION (qjf0): %s calls %s" % [path, call])
			elif not in_manifest:
				print("FAIL: %s calls %s - a SECOND placement path (ADR-028)" % [path, call])
				failures += 1

	for path2 in SEEDED_FILES:
		var src2: String = FileAccess.get_file_as_string(path2)
		if src2.is_empty():
			continue
		var n: int = 0
		for line2 in src2.split("\n"):
			n += 1
			var code2: String = line2.get_slice("#", 0)
			# Bare global-rng draws; member/param rng ("rng.randf") is the law.
			var rx := RegEx.create_from_string("(?<![\\w.])rand(f|i|f_range|i_range)\\s*\\(")
			if rx.search(code2) != null:
				print("FAIL: %s:%d draws the GLOBAL rng in a placement file: %s" % [
					path2, n, code2.strip_edges()])
				failures += 1

	if failures == 0:
		print("PASS: one placement path, seeded placement rng (dlox)")
		get_tree().quit(0)
	else:
		print("FAIL: %d structural violation(s)" % failures)
		get_tree().quit(1)


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		var full: String = dir_path + "/" + f
		if dir.current_is_dir():
			if not f.begins_with("."):
				_walk(full, out)
		elif f.ends_with(".gd"):
			out.append(full)
		f = dir.get_next()
	dir.list_dir_end()
