extends Node
## test_autoload_api.gd - a call to an autoload method that does not exist.
##
## GDScript resolves `SaveManager.foo()` at RUNTIME. A misnamed autoload method
## therefore parses clean, boots clean, passes every headless smoke test, and
## only throws when a player presses the button that reaches it. It is invisible
## to the fossil probe (the symbol has no definition to be dead) and invisible to
## --check-only.
##
## Found by hand 2026-07-20: scripts/main/game_flow.gd called
## SaveManager.save_to_slot(), which has never existed - save_manager.gd:97
## defines save_game(). The pause menu's SAVE button could not save.
##
## Run: godot --headless --path . res://tests/test_autoload_api.tscn

const SCAN_DIRS: Array[String] = ["res://scripts", "res://tests"]
## This probe quotes the patterns it hunts, so it must not scan itself.
const EXEMPT: Array[String] = ["res://tests/test_autoload_api.gd"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: AUTOLOAD METHOD EXISTENCE ===")

	var api: Dictionary = _read_autoload_api()
	if api.is_empty():
		print("FAIL: parsed zero autoload scripts from project.godot - the probe cannot work")
		get_tree().quit(1)
		return
	var names: Array[String] = []
	for k: String in api:
		names.append(k)
	names.sort()
	print("Autoloads resolved (%d): %s" % [names.size(), ", ".join(names)])

	# Negative control: a synthetic call to a method no autoload defines MUST be
	# flagged. A probe that has never failed proves nothing.
	var victim: String = names[0]
	var control: String = "%s.this_method_does_not_exist_ctl()" % victim
	if _scan_line(control, 0, "control", api).is_empty():
		print("FAIL: self-test - matcher did not flag a known-bad call: %s" % control)
		get_tree().quit(1)
		return
	# And the inverse: a REAL method must not be flagged, or the probe is noise.
	var real: Array[String] = api[victim]
	if not real.is_empty():
		var good: String = "%s.%s()" % [victim, real[0]]
		if not _scan_line(good, 0, "control", api).is_empty():
			print("FAIL: self-test - matcher flagged a REAL method: %s" % good)
			get_tree().quit(1)
			return
	print("Matcher self-test: PASS (flags a missing method, passes a real one)")

	var files: Array[String] = []
	for d in SCAN_DIRS:
		_collect_gd(d, files)
	print("Scanned %d GDScript files." % files.size())

	var findings: Array[String] = []
	for f in files:
		if EXEMPT.has(f):
			continue
		findings.append_array(_scan_file(f, api))

	if findings.is_empty():
		print("Calls to non-existent autoload methods: NONE")
		print("=== PROBE PASS ===")
		get_tree().quit(0)
		return

	print("")
	print("CALLS TO NON-EXISTENT AUTOLOAD METHODS (%d):" % findings.size())
	for f in findings:
		print("    " + f)
	print("")
	print("    Each of these throws the moment it is reached at runtime.")
	push_error("AUTOLOAD API: %d call(s) name a method the autoload does not define." % findings.size())
	print("=== PROBE FAIL ===")
	get_tree().quit(1)


## Map autoload name -> every method callable on it (own script, base scripts,
## and the native base class).
func _read_autoload_api() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	if f == null:
		return out
	var in_block: bool = false
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("["):
			in_block = line == "[autoload]"
			continue
		if not in_block or line.is_empty() or line.begins_with(";"):
			continue
		var eq: int = line.find("=")
		if eq <= 0:
			continue
		var name: String = line.substr(0, eq).strip_edges()
		var path: String = line.substr(eq + 1).strip_edges()
		path = path.trim_prefix("\"").trim_suffix("\"").trim_prefix("*")
		if not path.ends_with(".gd"):
			continue
		var scr := load(path) as GDScript
		if scr == null:
			continue
		out[name] = _methods_of(scr)
	f.close()
	return out


## Every method name reachable on an instance of `scr`.
func _methods_of(scr: GDScript) -> Array[String]:
	var out: Array[String] = []
	var walk: GDScript = scr
	while walk != null:
		for m: Dictionary in walk.get_script_method_list():
			var n: String = str(m.get("name", ""))
			if n != "" and not out.has(n):
				out.append(n)
		walk = walk.get_base_script()
	var native: String = scr.get_instance_base_type()
	while native != "" and ClassDB.class_exists(native):
		for m: Dictionary in ClassDB.class_get_method_list(native, true):
			var n: String = str(m.get("name", ""))
			if n != "" and not out.has(n):
				out.append(n)
		native = ClassDB.get_parent_class(native)
	return out


func _scan_file(path: String, api: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var n: int = 0
	while not f.eof_reached():
		n += 1
		out.append_array(_scan_line(f.get_line(), n, path, api))
	f.close()
	return out


## Flag `Autoload.method(` where `method` is defined nowhere on that autoload.
func _scan_line(line: String, n: int, path: String, api: Dictionary) -> Array[String]:
	var out: Array[String] = []
	# A comment is not code, and neither is a string literal - both quote method
	# names in prose. The fossil probe learned the first half the hard way.
	var code: String = line
	var hash_at: int = code.find("#")
	if hash_at >= 0:
		code = code.substr(0, hash_at)
	if code.count("\"") >= 2:
		var parts: PackedStringArray = code.split("\"")
		code = ""
		for i in range(0, parts.size(), 2):
			code += parts[i] + " "
	for name: String in api:
		var at: int = code.find(name + ".")
		while at >= 0:
			# Must be a standalone identifier, not a suffix of a longer name.
			var ok: bool = at == 0
			if not ok:
				var prev: String = code[at - 1]
				ok = not (prev == "_" or prev.is_valid_identifier() \
					or (prev >= "0" and prev <= "9"))
			if ok:
				var start: int = at + name.length() + 1
				var end: int = start
				while end < code.length() and (code[end] == "_" \
						or code[end].is_valid_identifier() \
						or (code[end] >= "0" and code[end] <= "9")):
					end += 1
				# Only a CALL is checked - a bare property read is a different
				# defect class and this probe does not claim it.
				if end < code.length() and code[end] == "(" and end > start:
					var ident: String = code.substr(start, end - start)
					var known: Array = api[name]
					if not known.has(ident):
						out.append("%s:%d  %s.%s()  -- no such method" \
							% [path, n, name, ident])
			at = code.find(name + ".", at + 1)
	return out


## Recursively collect .gd files under `dir` into `out`.
func _collect_gd(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full: String = dir.path_join(entry)
		if d.current_is_dir():
			_collect_gd(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
