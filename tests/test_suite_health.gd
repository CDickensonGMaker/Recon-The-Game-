## test_suite_health.gd - the suite is only evidence if every test in it RUNS.
##
## Run: godot --headless --path . res://tests/test_suite_health.tscn
## Shrink the register: ... res://tests/test_suite_health.tscn -- --write-baseline
## Add an entry (deliberate): ... -- --grandfather --reason="<why>"
##
## Named test_* on purpose. run_all_tests.ps1 globs `tests/test_*.tscn` ONLY, so a
## file named probe_* is never invoked by the suite - which is the exact defect this
## probe measures. A health probe that does not run cannot report its own absence.
##
## FIVE ASSERTIONS. Four are hard; only INVOCATION carries a ratcheted register,
## because 17 probes were already stranded when this landed and wiring them is a
## separate job per probe.
##   PARSE       a script that does not compile never reaches _ready(), so it can
##               never call quit() and burns the runner's full timeout box instead.
##               --check-only CANNOT be used for this: it resolves no autoloads and
##               reports "Identifier not found: GameManager" for most of the codebase.
##               A real load inside a booted engine is the only honest parse check.
##   TERMINATE   a test with no quit() path holds the box open.
##   NAMING      no _TMP scratch test may live in the suite.
##   SCENE       every tests/*.tscn points at a script that exists.
##   INVOCATION  every test/probe script is reachable by the runner. RATCHETED.
extends Node

const BASELINE_PATH: String = "res://tests/test_health_baseline.json"
const BASELINE_COMMENT: String = "Test scripts that NOTHING invokes. run_all_tests.ps1 globs tests/test_*.tscn only, so a probe_* scene is dead weight until it is wired or renamed. THIS LIST ONLY SHRINKS. 'count' and 'ceiling' are the ratchet's witnesses: the probe FAILS if either disagrees with 'uninvoked', so a hand-edit cannot pass quietly. --write-baseline can only ever remove entries. New entries enter ONLY via --grandfather --reason=<text>."

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scripts: PackedStringArray = _list("res://tests", ".gd")

	var stranded: PackedStringArray = _stranded(scripts)

	_assert_parse(scripts)
	_assert_terminates(scripts, stranded)
	_assert_naming(scripts)
	_assert_scene_scripts()

	if "--write-baseline" in args:
		_write_baseline(stranded)
		get_tree().quit(0)
		return
	if "--grandfather" in args:
		_grandfather(stranded, args)
		get_tree().quit(0)
		return
	_assert_invocation(stranded)

	if failures > 0:
		print("FAIL: test_suite_health - %d failure(s) across %d checks" % [failures, checks])
	else:
		print("PASS: test_suite_health - %d checks" % checks)
	get_tree().quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	print("  FAIL: " + msg)


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		_fail(msg)


# ---- assertions -------------------------------------------------------------

## A script that fails to compile returns null from load(). _ready() never fires,
## quit() is never reached, and the runner's 420s box absorbs the whole thing -
## which reads on the board as a hang, not as the parse error it is.
func _assert_parse(scripts: PackedStringArray) -> void:
	for path: String in scripts:
		checks += 1
		# Compile THIS script's own source and nothing else. ResourceLoader.load()
		# hands back a cached or half-resolved script for a file that in fact fails to
		# compile (the first cut of this probe passed a control that hung for the full
		# box), and CACHE_MODE_IGNORE fixes that only by recompiling the entire
		# dependency graph once per file - minutes of engine time for a text check.
		var gd := GDScript.new()
		gd.source_code = FileAccess.get_file_as_string(path)
		if gd.reload() != OK:
			_fail("%s does not compile. It can never reach quit(); the runner will box it for the full timeout and report a hang." % path)


## Only binds what the runner actually BOXES: a test_*.gd with a test_*.tscn beside it.
## A stranded script is already reported by INVOCATION, and a preloaded helper (a bare
## test_*.gd with no scene) is never boxed at all, so neither owes a quit().
func _assert_terminates(scripts: PackedStringArray, stranded: PackedStringArray) -> void:
	for path: String in scripts:
		var base: String = _basename(path)
		if not base.begins_with("test_") or base in stranded:
			continue
		if not ResourceLoader.exists("res://tests/%s.tscn" % base):
			continue
		var src: String = FileAccess.get_file_as_string(path)
		_check(src.contains("quit("),
			"%s never calls quit(). The runner has no way to know it finished." % path)


func _assert_naming(scripts: PackedStringArray) -> void:
	for path: String in scripts:
		_check(not _basename(path).ends_with("_TMP"),
			"%s is a _TMP scratch test living in the suite. Scratch tests rot: the last one called a function that never existed and burned 420s of every run." % path)


func _assert_scene_scripts() -> void:
	for scene: String in _list("res://tests", ".tscn"):
		var txt: String = FileAccess.get_file_as_string(scene)
		for frag: String in txt.split("path=\""):
			if not frag.begins_with("res://"):
				continue
			var ref: String = frag.substr(0, frag.find("\""))
			if not ref.ends_with(".gd"):
				continue
			_check(ResourceLoader.exists(ref),
				"%s references script %s, which does not exist." % [scene, ref])


func _assert_invocation(stranded: PackedStringArray) -> void:
	var doc: Dictionary = _load_baseline()
	var known: PackedStringArray = PackedStringArray(doc.get("uninvoked", []))
	if not _witnesses_agree(doc, known):
		return

	for name: String in stranded:
		checks += 1
		if name in known:
			continue
		_fail("%s is invoked by NOTHING. run_all_tests.ps1 globs tests/test_*.tscn; give it a test_*.tscn or wire it explicitly. A probe that never runs proves nothing." % name)

	var revived: PackedStringArray = PackedStringArray()
	for name: String in known:
		if not (name in stranded):
			revived.append(name)
	if revived.size() > 0:
		print("  %d register entr(ies) now invoked - run --write-baseline to bank it: %s"
			% [revived.size(), ", ".join(revived)])


# ---- the stranded set -------------------------------------------------------

## Reachable = the runner's glob finds it, OR another test pulls it in. A tests/foo.gd
## is invoked when tests/foo.tscn exists AND foo is named test_*; a HELPER reached by
## preload from a live test is equally invoked, and test_world_minimap.gd is exactly
## that shape (test_world_alive.gd preloads it) despite its test_ prefix.
func _stranded(scripts: PackedStringArray) -> PackedStringArray:
	var pulled: Dictionary = {}
	for path: String in scripts:
		var src: String = FileAccess.get_file_as_string(path)
		for frag: String in src.split("preload(\""):
			if frag.begins_with("res://tests/"):
				pulled[frag.substr(0, frag.find("\"")).get_file().trim_suffix(".gd")] = path

	var out: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		var base: String = _basename(path)
		if not (base.begins_with("test_") or base.begins_with("probe_")):
			continue
		var scene: String = "res://tests/%s.tscn" % base
		if base.begins_with("test_") and ResourceLoader.exists(scene):
			continue
		if pulled.has(base):
			continue
		out.append(base)
	out.sort()
	return out


# ---- baseline ---------------------------------------------------------------

func _load_baseline() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		push_warning("no test-health baseline - run with --grandfather --reason=<text> to create it")
		return {}
	var txt: String = FileAccess.get_file_as_string(BASELINE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


## `count` and `ceiling` are redundant on purpose: they are the witnesses that make a
## hand-edit of the register loud. Forging an entry means forging both as well.
func _witnesses_agree(doc: Dictionary, known: PackedStringArray) -> bool:
	if doc.is_empty():
		return true
	var size: int = known.size()
	if not doc.has("count") or int(doc["count"]) != size:
		checks += 1
		_fail("REGISTER TAMPERED: count=%s but uninvoked=%d. Regenerate with --write-baseline."
			% [str(doc.get("count", "<missing>")), size])
		return false
	if not doc.has("ceiling"):
		checks += 1
		_fail("baseline has no 'ceiling' - the ratchet cannot hold.")
		return false
	if size > int(doc["ceiling"]):
		checks += 1
		_fail("REGISTER GREW: %d stranded vs ceiling %d. This register only shrinks." % [size, int(doc["ceiling"])])
		return false
	return true


## Can only ever REMOVE entries. Growth is impossible through this door.
func _write_baseline(stranded: PackedStringArray) -> void:
	var doc: Dictionary = _load_baseline()
	var known: PackedStringArray = PackedStringArray(doc.get("uninvoked", []))
	var kept: PackedStringArray = PackedStringArray()
	for name: String in known:
		if name in stranded:
			kept.append(name)
	var old_ceiling: int = int(doc.get("ceiling", kept.size()))
	doc["_comment"] = BASELINE_COMMENT
	doc["uninvoked"] = kept
	doc["count"] = kept.size()
	doc["ceiling"] = mini(old_ceiling, kept.size())
	if not doc.has("grandfather_log"):
		doc["grandfather_log"] = []
	_save(doc)
	print("baseline written: %d stranded, ceiling %d" % [kept.size(), int(doc["ceiling"])])


## The ONLY door new entries may enter, and it demands a written reason on the record.
func _grandfather(stranded: PackedStringArray, args: PackedStringArray) -> void:
	var reason: String = ""
	for a: String in args:
		if a.begins_with("--reason="):
			reason = a.substr(len("--reason="))
	if reason.strip_edges().is_empty():
		push_error("--grandfather requires --reason=\"<why these are stranded>\"")
		return
	var doc: Dictionary = _load_baseline()
	var log: Array = doc.get("grandfather_log", [])
	var known: PackedStringArray = PackedStringArray(doc.get("uninvoked", []))
	var added: PackedStringArray = PackedStringArray()
	for name: String in stranded:
		if not (name in known):
			known.append(name)
			added.append(name)
	known.sort()
	log.append({
		"date": Time.get_date_string_from_system(),
		"reason": reason,
		"added": added,
	})
	doc["_comment"] = BASELINE_COMMENT
	doc["uninvoked"] = known
	doc["count"] = known.size()
	doc["ceiling"] = known.size()
	doc["grandfather_log"] = log
	_save(doc)
	print("grandfathered %d entr(ies), ceiling %d, reason: %s" % [added.size(), known.size(), reason])


func _save(doc: Dictionary) -> void:
	var f := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", false) + "\n")
	f.close()


# ---- helpers ----------------------------------------------------------------

func _list(dir_path: String, suffix: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(suffix):
			out.append(dir_path + "/" + name)
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func _basename(path: String) -> String:
	return path.get_file().trim_suffix(".gd").trim_suffix(".tscn")
