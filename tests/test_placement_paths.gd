## test_placement_paths.gd - dlox structural probe (ADR-028/ADR-029).
## Static scan: (1) world-placement entry points may only be called from the
## manifest files - a second placement path fails the build; (2) placement
## files may not draw from the GLOBAL rng (bare randf/randi = unseeded world).
## Dev benches (EXCLUDED_BENCHES) are out of scope entirely: the stress arena is
## a sterile debugging environment by the Summoner's ruling of 2026-07-26, so
## ADR-028 Phase 3 (arena-as-slice) is CUT, not deferred.
## Anything tuned in the arena must be re-confirmed in the real world build.
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
## Dev benches are NOT world-build code and this probe does not police them
## (Summoner, 2026-07-27: "remove the ai stress test from the probes"). Excluded
## outright rather than carried as an exception - an exception still asserts the
## file is in scope and merely forgiven, which is the drift this probe exists to
## stop. Files here are skipped before any rule runs.
const EXCLUDED_BENCHES: Array[String] = [
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
		if path in EXCLUDED_BENCHES:
			continue
		var src: String = FileAccess.get_file_as_string(path)
		if src.is_empty():
			continue
		var in_manifest: bool = path in CALLER_MANIFEST
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
			if not in_manifest:
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

	# ADR-028 Amendment A: exactly ONE world-build orchestrator, defined only in
	# mission_generator; a second build_patrol_world() would be a parallel world path.
	var bpw_defs: Array[String] = []
	for path3 in files:
		var src3: String = FileAccess.get_file_as_string(path3)
		if src3.is_empty():
			continue
		for line3 in src3.split("\n"):
			if line3.get_slice("#", 0).contains("func build_patrol_world("):
				bpw_defs.append(path3)
				break
	if bpw_defs.size() != 1 or bpw_defs[0] != "res://scripts/missions/mission_generator.gd":
		print("FAIL: build_patrol_world() defined in %s - expected exactly one, in mission_generator (ADR-028)" % str(bpw_defs))
		failures += 1
	# Self-test: the detector must match its own synthetic second definition.
	if not "func build_patrol_world(s: int) -> void:".contains("func build_patrol_world("):
		print("FAIL(self-test): build_patrol_world detector does not match its own pattern")
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
