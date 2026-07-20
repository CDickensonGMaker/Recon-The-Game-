## Enforces ADR-023: a symbol declared and never read is a fossil. New fossils fail
## the build; tests/fossil_baseline.json grandfathers the existing ones and ONLY SHRINKS.
## Shrink it:    godot --headless --path . res://tests/test_fossils.tscn -- --write-baseline
## Grow it (forbidden except when SCAN_DIRS widens, and it is recorded forever):
##               ... -- --grandfather --reason="<why>"
extends Node

const SCAN_DIRS: Array[String] = ["res://scripts", "res://terrain"]
## Wider than SCAN_DIRS: a script's only caller may be a scene, a resource or a tool.
const REF_DIRS: Array[String] = [
	"res://scripts", "res://terrain", "res://scenes",
	"res://data", "res://tests", "res://tools",
]
const REF_EXTS: Array[String] = ["gd", "tscn", "tres", "cfg", "json"]
const BASELINE_PATH: String = "res://tests/fossil_baseline.json"
const BASELINE_COMMENT: String = "ADR-023 THE FOSSIL LAW. Grandfathered dead symbols, keyed file|kind|symbol (NOT line - lines move). THIS LIST ONLY SHRINKS. 'count' and 'ceiling' are the ratchet's witnesses: the probe FAILS if either disagrees with 'fossils', so a hand-edit cannot pass quietly. --write-baseline can only ever remove entries. New entries enter ONLY via --grandfather --reason=<text>, which records provenance in grandfather_log."

## Godot calls these. They have no caller in OUR code and never will.
const LIFECYCLE: Array[String] = [
	"_ready", "_process", "_physics_process", "_input", "_unhandled_input",
	"_unhandled_key_input", "_shortcut_input", "_enter_tree", "_exit_tree",
	"_init", "_draw", "_notification", "_to_string", "_gui_input",
	"_integrate_forces", "_get_configuration_warnings", "_process_modification",
	"_validate_property", "_get_property_list", "_set", "_get", "_can_drop_data",
	"_drop_data", "_get_drag_data", "_has_point", "_structured_text_parser",
]

## key -> "file:line  kind symbol". A fossil's IDENTITY is file+kind+symbol; the line
## number is display only. Keying on the line makes every edit above a symbol look like
## a new fossil, which trains you to regenerate the baseline - the one forbidden move.
var _seen: Dictionary = {}
var _failures: int = 0


func _ready() -> void:
	var write_baseline: bool = "--write-baseline" in OS.get_cmdline_user_args()

	print("=== FOSSIL PROBE (ADR-023) ===")

	# 1. every identifier in every referenceable file, with a frequency count.
	var freq: Dictionary = {}
	var conn_sites: Dictionary = {}   # signal_name -> true if something connects to it
	var files: Array[String] = []
	for d: String in REF_DIRS:
		_collect(d, files)
	for f: String in files:
		_tally(f, freq, conn_sites)
	print("scanned %d files, %d distinct identifiers" % [files.size(), freq.size()])

	# A DECLARATION IS NOT A REFERENCE. `freq` counts the bare name everywhere, so the
	# line `func get_height_at(...)` counts itself, and two files declaring the same name
	# count as each other's caller. Competing implementations mutually alibi, and the more
	# duplicated a dead system is, the more alive it looks. Subtract every declaration.
	var decls: Dictionary = {}
	for f: String in files:
		if f.ends_with(".gd"):
			_tally_decls(f, decls)
	var dupes: Array[String] = []
	for sym: String in decls:
		if int(decls[sym]) > 1:
			dupes.append("%s x%d" % [sym, int(decls[sym])])
	dupes.sort()
	print("declarations tallied: %d distinct, %d declared in 2+ places" % [decls.size(), dupes.size()])

	# 2. every DECLARATION in the code we hold to the law.
	var decl_files: Array[String] = []
	for d: String in SCAN_DIRS:
		_collect(d, decl_files)
	for f: String in decl_files:
		if not f.ends_with(".gd"):
			continue
		_check_file(f, freq, decls, conn_sites)

	var keys: Array = _seen.keys()
	keys.sort()

	# 3. the ratchet.
	var doc: Dictionary = _read_baseline_doc()
	var baseline: Array = doc.get("fossils", []) as Array

	if write_baseline:
		_shrink_baseline(doc, keys)
		return
	if "--grandfather" in OS.get_cmdline_user_args():
		_grandfather(doc, keys)
		return

	# The register is tamper-evident BEFORE it is consulted. A hand-edit that adds
	# entries must also forge `count` and raise `ceiling`, and both are checked here.
	if not _audit_register(doc, baseline):
		print("")
		print("=== FOSSIL PROBE FAIL (register tampered) ===")
		get_tree().quit(1)
		return

	var known: Dictionary = {}
	for b: Variant in baseline:
		known[str(b)] = true

	var new_fossils: Array[String] = []
	for k: String in keys:
		if not known.has(k):
			new_fossils.append(str(_seen[k]))

	# A baseline entry that is GONE = someone did the work. Tell them to shrink
	# the register; the baseline only goes down.
	var cleaned: Array[String] = []
	for b: Variant in baseline:
		if not _seen.has(str(b)):
			cleaned.append(str(b))

	print("")
	print("fossils now: %d   baseline: %d" % [keys.size(), baseline.size()])

	if cleaned.size() > 0:
		print("")
		print("*** %d FOSSIL(S) BURIED - good. Shrink the register: ***" % cleaned.size())
		for c: String in cleaned:
			print("    - %s" % c)
		print("    run:  godot --headless --path . res://tests/test_fossils.tscn -- --write-baseline")

	if new_fossils.size() > 0:
		print("")
		print("*** %d NEW FOSSIL(S) - THE FOSSIL LAW (ADR-023) FORBIDS THIS ***" % new_fossils.size())
		for n: String in new_fossils:
			print("    + %s" % n)
		print("")
		print("    You changed a system and left the old one standing.")
		print("    DELETE the superseded symbol. Do not add it to the baseline.")
		_failures += 1
		push_error("FOSSIL LAW: %d new dead symbol(s) - delete the old system, don't bury it." % new_fossils.size())

	print("")
	if _failures == 0:
		print("=== FOSSIL PROBE PASS (no new fossils) ===")
		get_tree().quit(0)
	else:
		print("=== FOSSIL PROBE FAIL ===")
		get_tree().quit(1)


## Recursively collect referenceable files under `dir`.
func _collect(dir: String, out: Array[String]) -> void:
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if name.begins_with("."):
			name = da.get_next()
			continue
		var path: String = dir.path_join(name)
		if da.current_is_dir():
			_collect(path, out)
		elif name.get_extension() in REF_EXTS:
			out.append(path)
		name = da.get_next()
	da.list_dir_end()


## Count every identifier in a file, and note any signal CONNECTION sites.
func _tally(path: String, freq: Dictionary, conn_sites: Dictionary) -> void:
	# The baseline names every fossil, so tallying it would count the death register
	# as a reference and resurrect all of them.
	if path == BASELINE_PATH:
		return

	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var text: String = fa.get_as_text()
	fa.close()

	# A comment is not a caller: an obituary like `# was a hardcoded ALERT_RANGE*2`
	# would otherwise keep the dead const it describes off this list.
	if path.ends_with(".gd"):
		text = _strip_comments(text)

	var ident: RegEx = RegEx.new()
	ident.compile("[A-Za-z_][A-Za-z0-9_]*")
	for m: RegExMatch in ident.search_all(text):
		var s: String = m.get_string()
		freq[s] = int(freq.get(s, 0)) + 1

	# A signal is live only if something CONNECTS to it. Emitting into the void
	# is exactly the r4bk Law's "simulation without presentation".
	#   foo.connect(...)          |  connect("foo", ...)  |  .tscn: signal="foo"
	var conn: RegEx = RegEx.new()
	conn.compile("([A-Za-z_][A-Za-z0-9_]*)\\s*\\.\\s*connect\\s*\\(")
	for m: RegExMatch in conn.search_all(text):
		conn_sites[m.get_string(1)] = true
	var conn_str: RegEx = RegEx.new()
	conn_str.compile("connect\\s*\\(\\s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']")
	for m: RegExMatch in conn_str.search_all(text):
		conn_sites[m.get_string(1)] = true
	var conn_scene: RegEx = RegEx.new()
	conn_scene.compile("signal\\s*=\\s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']")
	for m: RegExMatch in conn_scene.search_all(text):
		conn_sites[m.get_string(1)] = true


## Cut every `#` comment, but never a `#` that lives inside a string literal.
## Line-by-line, tracking quote state - GDScript has no multi-line block comment.
func _strip_comments(text: String) -> String:
	var out: PackedStringArray = []
	for line: String in text.split("\n"):
		var in_s: bool = false
		var quote: String = ""
		var cut: int = -1
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if c == "\\" and in_s:
				i += 2          # escaped char inside a string - skip both
				continue
			if in_s:
				if c == quote:
					in_s = false
			elif c == "\"" or c == "'":
				in_s = true
				quote = c
			elif c == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut) if cut >= 0 else line)
	return "\n".join(out)


## Find declarations in one .gd and judge each against the frequency table.
func _check_file(path: String, freq: Dictionary, decls: Dictionary, conn_sites: Dictionary) -> void:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	# A commented-out `#func foo()` is not a declaration.
	var lines: PackedStringArray = _strip_comments(fa.get_as_text()).split("\n")
	fa.close()

	var re_const: RegEx = RegEx.new()
	re_const.compile("^\\s*const\\s+([A-Z_][A-Z0-9_]*)\\s*[:=]")
	var re_signal: RegEx = RegEx.new()
	re_signal.compile("^\\s*signal\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var re_func: RegEx = RegEx.new()
	re_func.compile("^\\s*func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(")

	for i: int in range(lines.size()):
		var line: String = lines[i]
		var rel: String = path.replace("res://", "")

		var mc: RegExMatch = re_const.search(line)
		if mc != null:
			_judge(mc.get_string(1), "const", rel, i + 1, freq, decls)
			continue

		var ms: RegExMatch = re_signal.search(line)
		if ms != null:
			var sname: String = ms.get_string(1)
			# Declared and emitted, but nothing CONNECTS: it does nothing. r4bk Law.
			if not conn_sites.has(sname):
				_record(rel, "signal", sname, i + 1, " (emitted into the void - nothing connects)")
			continue

		var mf: RegExMatch = re_func.search(line)
		if mf != null:
			var fname: String = mf.get_string(1)
			if fname in LIFECYCLE:
				continue
			_judge(fname, "func", rel, i + 1, freq, decls)


## Occurrences minus declarations. Zero left means nothing anywhere reads this symbol.
## When N files declare one name, all N declarations are subtracted, so a family of
## competing dead implementations can no longer vouch for each other.
func _judge(sym: String, kind: String, rel: String, line: int, freq: Dictionary, decls: Dictionary) -> void:
	var refs: int = int(freq.get(sym, 0)) - int(decls.get(sym, 0))
	if refs > 0:
		return
	var n: int = int(decls.get(sym, 0))
	# With 2+ declarations and 0 references we know the NAME is dead, which means every
	# declaration of it is dead. With 1 declaration it is simply dead.
	_record(rel, kind, sym, line, (" (%d competing declarations, none referenced)" % n) if n > 1 else "")


## Count how many times each symbol is DECLARED, across the whole reference corpus.
func _tally_decls(path: String, decls: Dictionary) -> void:
	if path == BASELINE_PATH:
		return
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var text: String = _strip_comments(fa.get_as_text())
	fa.close()

	var res: Array[RegEx] = []
	for pattern: String in [
		"^\\s*const\\s+([A-Z_][A-Z0-9_]*)\\s*[:=]",
		"^\\s*signal\\s+([A-Za-z_][A-Za-z0-9_]*)",
		"^\\s*func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(",
		"^\\s*static\\s+func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(",
	]:
		var r: RegEx = RegEx.new()
		r.compile(pattern)
		res.append(r)

	for line: String in text.split("\n"):
		for r: RegEx in res:
			var m: RegExMatch = r.search(line)
			if m != null:
				var s: String = m.get_string(1)
				decls[s] = int(decls.get(s, 0)) + 1
				break


## Key on file+kind+symbol. The line number is display only - keying on it would
## make every edit above a symbol read as a brand-new fossil.
func _record(rel: String, kind: String, sym: String, line: int, note: String) -> void:
	_seen["%s|%s|%s" % [rel, kind, sym]] = "%s:%d  %s %s%s" % [rel, line, kind, sym, note]


func _read_baseline_doc() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		push_warning("no fossil baseline - run with --grandfather --reason=<text> to create it")
		return {}
	var fa: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(fa.get_as_text())
	fa.close()
	return (data as Dictionary) if data is Dictionary else {}


## `count` and `ceiling` are redundant on purpose: they are the witnesses that make a
## hand-edit of `fossils` visible. Nothing checked them, which is how 77 became 146.
func _audit_register(doc: Dictionary, baseline: Array) -> bool:
	var ok: bool = true
	var size: int = baseline.size()

	if not doc.has("count") or int(doc["count"]) != size:
		print("")
		print("*** REGISTER TAMPERED: count=%s but fossils=%d ***" % [(str(int(doc["count"])) if doc.has("count") else "<missing>"), size])
		print("    Shrink the register with the tool, never the editor:")
		print("    godot --headless --path . res://tests/test_fossils.tscn -- --write-baseline")
		push_error("FOSSIL LAW: baseline count desync (%s vs %d) - hand-edited register." % [str(doc.get("count", "?")), size])
		ok = false

	if not doc.has("ceiling"):
		print("")
		print("*** REGISTER HAS NO CEILING - the ratchet is disarmed. ***")
		push_error("FOSSIL LAW: baseline has no 'ceiling' - the ratchet cannot hold.")
		ok = false
	elif size > int(doc["ceiling"]):
		print("")
		print("*** REGISTER GREW: %d fossils vs ceiling %d ***" % [size, int(doc["ceiling"])])
		print("    ADR-023: the register ONLY SHRINKS. Someone buried a failure instead of a corpse.")
		push_error("FOSSIL LAW: register grew past its ceiling (%d > %d)." % [size, int(doc["ceiling"])])
		ok = false

	return ok


## The ONLY unguarded write path, and it is structurally incapable of growth: it keeps
## the intersection of the register and reality. A fossil that is not already
## grandfathered can never enter the register through this door.
func _shrink_baseline(doc: Dictionary, keys: Array) -> void:
	var baseline: Array = doc.get("fossils", []) as Array
	var live: Dictionary = {}
	for k: String in keys:
		live[k] = true
	var known: Dictionary = {}
	for b: Variant in baseline:
		known[str(b)] = true

	var kept: Array[String] = []
	for b: Variant in baseline:
		if live.has(str(b)):
			kept.append(str(b))
	var refused: Array[String] = []
	for k: String in keys:
		if not known.has(k):
			refused.append(k)

	var old_ceiling: int = int(doc.get("ceiling", baseline.size()))
	doc["_comment"] = BASELINE_COMMENT
	doc["count"] = kept.size()
	doc["ceiling"] = mini(old_ceiling, kept.size())
	doc["fossils"] = kept
	if not doc.has("grandfather_log"):
		doc["grandfather_log"] = []
	_store(doc)

	print("")
	print("SHRANK register: %d -> %d (ceiling %d -> %d)" % [baseline.size(), kept.size(), old_ceiling, int(doc["ceiling"])])
	if refused.size() > 0:
		print("")
		print("REFUSED to grandfather %d live fossil(s) - this door only shrinks:" % refused.size())
		for r: String in refused:
			print("    ! %s" % str(_seen[r]))
		print("    Delete them, or justify them: -- --grandfather --reason=\"why\"")
	get_tree().quit(0)


## Widening SCAN_DIRS legitimately reveals pre-existing debt. That is the ONLY reason to
## grow the register, it demands a written reason, and it leaves a permanent record.
func _grandfather(doc: Dictionary, keys: Array) -> void:
	var reason: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--reason="):
			reason = a.substr("--reason=".length()).strip_edges()

	if reason.length() < 12:
		print("")
		print("*** --grandfather REQUIRES --reason=\"<at least 12 chars>\" ***")
		print("    ADR-023: growing the register is the one forbidden move. If you are doing it")
		print("    anyway, the reason goes in the file, in the open, forever.")
		push_error("FOSSIL LAW: --grandfather refused - no reason given.")
		get_tree().quit(1)
		return

	var baseline: Array = doc.get("fossils", []) as Array
	var known: Dictionary = {}
	for b: Variant in baseline:
		known[str(b)] = true

	var added: Array[String] = []
	var merged: Array[String] = []
	for b: Variant in baseline:
		merged.append(str(b))
	for k: String in keys:
		if not known.has(k):
			added.append(k)
			merged.append(k)
	merged.sort()

	var glog: Array = doc.get("grandfather_log", []) as Array
	glog.append({
		"date": Time.get_datetime_string_from_system(true),
		"reason": reason,
		"from": baseline.size(),
		"to": merged.size(),
		"added": added,
	})

	doc["_comment"] = BASELINE_COMMENT
	doc["count"] = merged.size()
	doc["ceiling"] = merged.size()
	doc["fossils"] = merged
	doc["grandfather_log"] = glog
	_store(doc)

	print("")
	print("GRANDFATHERED %d entr(ies): %d -> %d" % [added.size(), baseline.size(), merged.size()])
	print("reason recorded: %s" % reason)
	for a: String in added:
		print("    + %s" % a)
	get_tree().quit(0)


func _store(doc: Dictionary) -> void:
	var fa: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	fa.store_string(JSON.stringify(doc, "\t"))
	fa.close()
