## Enforces ADR-023: a symbol declared and never read is a fossil. New fossils fail
## the build; tests/fossil_baseline.json grandfathers the existing ones and only shrinks.
## Rebuild the baseline: godot --headless --path . res://tests/test_fossils.tscn -- --write-baseline
extends Node

const SCAN_DIRS: Array[String] = ["res://scripts", "res://terrain"]
## Wider than SCAN_DIRS: a script's only caller may be a scene, a resource or a tool.
const REF_DIRS: Array[String] = [
	"res://scripts", "res://terrain", "res://scenes",
	"res://data", "res://tests", "res://tools",
]
const REF_EXTS: Array[String] = ["gd", "tscn", "tres", "cfg", "json"]
const BASELINE_PATH: String = "res://tests/fossil_baseline.json"

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

	# 2. every DECLARATION in the code we hold to the law.
	var decl_files: Array[String] = []
	for d: String in SCAN_DIRS:
		_collect(d, decl_files)
	for f: String in decl_files:
		if not f.ends_with(".gd"):
			continue
		_check_file(f, freq, conn_sites)

	var keys: Array = _seen.keys()
	keys.sort()

	# 3. the ratchet.
	if write_baseline:
		_write_baseline(keys)
		return

	var baseline: Array = _read_baseline()
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
func _check_file(path: String, freq: Dictionary, conn_sites: Dictionary) -> void:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var lines: PackedStringArray = fa.get_as_text().split("\n")
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
			_judge(mc.get_string(1), "const", rel, i + 1, freq)
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
			_judge(fname, "func", rel, i + 1, freq)


## freq <= 1 means the symbol appears NOWHERE outside its own declaration.
func _judge(sym: String, kind: String, rel: String, line: int, freq: Dictionary) -> void:
	if int(freq.get(sym, 0)) <= 1:
		_record(rel, kind, sym, line, "")


## Key on file+kind+symbol. The line number is display only - keying on it would
## make every edit above a symbol read as a brand-new fossil.
func _record(rel: String, kind: String, sym: String, line: int, note: String) -> void:
	_seen["%s|%s|%s" % [rel, kind, sym]] = "%s:%d  %s %s%s" % [rel, line, kind, sym, note]


func _read_baseline() -> Array:
	if not FileAccess.file_exists(BASELINE_PATH):
		push_warning("no fossil baseline - run with --write-baseline to create it")
		return []
	var fa: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(fa.get_as_text())
	fa.close()
	if data is Dictionary and (data as Dictionary).has("fossils"):
		return (data as Dictionary)["fossils"] as Array
	return []


func _write_baseline(keys: Array) -> void:
	var out: Dictionary = {
		"_comment": "ADR-023 THE FOSSIL LAW. Grandfathered dead symbols, keyed file|kind|symbol (NOT line - lines move). THIS LIST ONLY SHRINKS. Adding to it to silence a failure is the one forbidden move.",
		"count": keys.size(),
		"fossils": keys,
	}
	var fa: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "\t"))
	fa.close()
	print("")
	print("wrote baseline: %d fossils -> %s" % [keys.size(), BASELINE_PATH])
	for k: String in keys:
		print("    %s" % _seen[k])
	get_tree().quit(0)
