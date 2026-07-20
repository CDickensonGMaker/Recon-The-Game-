extends Node
## test_autoload_reach.gd - catches a defect class the fossil probe is blind to:
## an AUTOLOAD reached through a mechanism that can never see it.
##
## Autoloads are plain nodes under /root. They are NOT engine singletons, so
## Engine.has_singleton()/Engine.get_singleton() never see them. They only appear
## in ClassDB if the script also declares a class_name - and several here
## deliberately omit it so the class does not collide with the autoload name.
##
## A guard written on either mechanism is therefore permanently false, and the
## guarded code silently serves its fallback forever. That is how every civilian
## in the game got pinned to sim_hour 12.0 while SimClock ticked correctly.
##
## Run: godot --headless --path . res://tests/test_autoload_reach.tscn

const SCAN_DIRS: Array[String] = ["res://scripts", "res://tests"]
## Files allowed to name an autoload inside these calls - this probe itself,
## which must quote the patterns it hunts for.
const EXEMPT: Array[String] = ["res://tests/test_autoload_reach.gd"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: AUTOLOAD REACHABILITY ===")

	var autoloads: Array[String] = _read_autoload_names()
	if autoloads.is_empty():
		print("FAIL: parsed zero autoloads from project.godot - the probe cannot work")
		get_tree().quit(1)
		return
	print("Autoloads declared in project.godot (%d): %s" % [autoloads.size(), ", ".join(autoloads)])

	# Negative control on the PARSER: a name that is not an autoload must not be
	# reported no matter how it is used. If this trips, the matcher is too loose.
	var control: String = "ThisIsNotAnAutoload"
	if autoloads.has(control):
		print("FAIL: control name '%s' collided with a real autoload" % control)
		get_tree().quit(1)
		return

	var files: Array[String] = []
	for d in SCAN_DIRS:
		_collect_gd(d, files)
	print("Scanned %d GDScript files." % files.size())

	var findings: Array[String] = []
	for f in files:
		if EXEMPT.has(f):
			continue
		findings.append_array(_scan_file(f, autoloads))

	# Prove the matcher actually fires: run it over a synthetic line built from a
	# real autoload name. A probe that can only ever pass is not a probe.
	var probe_line: String = 'if Engine.has_singleton("%s"): pass' % autoloads[0]
	if _hits(probe_line, autoloads).is_empty():
		print("FAIL: self-test - matcher did not flag a known-bad line: %s" % probe_line)
		get_tree().quit(1)
		return
	print("Matcher self-test: PASS (flags a synthetic bad guard)")

	if findings.is_empty():
		print("Unreachable-autoload guards: NONE")
		print("=== PROBE PASS ===")
		get_tree().quit(0)
		return

	print("")
	print("UNREACHABLE AUTOLOAD GUARDS (%d):" % findings.size())
	for f in findings:
		print("    " + f)
	print("")
	print("    These guards are permanently FALSE. The code behind them never runs")
	print("    and its fallback is serving as the real implementation.")
	print("    Reach an autoload by node path: get_node_or_null(^\"/root/Name\").")
	push_error("AUTOLOAD REACH: %d guard(s) can never see the autoload they name." % findings.size())
	print("=== PROBE FAIL ===")
	get_tree().quit(1)


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


## Parse the [autoload] block of project.godot. Returns the autoload names.
func _read_autoload_names() -> Array[String]:
	var out: Array[String] = []
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
		out.append(line.substr(0, eq).strip_edges())
	f.close()
	return out


func _scan_file(path: String, autoloads: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var n: int = 0
	while not f.eof_reached():
		n += 1
		var line: String = f.get_line()
		# A comment is not code. The fossil probe learned this the hard way.
		var code: String = line
		var hash_at: int = code.find("#")
		if hash_at >= 0:
			code = code.substr(0, hash_at)
		for name in _hits(code, autoloads):
			out.append("%s:%d  %s" % [path, n, line.strip_edges()])
	f.close()
	return out


## Return autoload names used inside a singleton/ClassDB lookup on this line.
func _hits(code: String, autoloads: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var calls: Array[String] = [
		"Engine.has_singleton", "Engine.get_singleton", "ClassDB.class_exists",
	]
	for call in calls:
		var at: int = code.find(call)
		while at >= 0:
			var open: int = code.find("(", at)
			var close: int = code.find(")", open)
			if open < 0 or close < 0:
				break
			var arg: String = code.substr(open + 1, close - open - 1).strip_edges()
			arg = arg.trim_prefix("\"").trim_suffix("\"").trim_prefix("&")
			if autoloads.has(arg) and not out.has(arg):
				out.append(arg)
			at = code.find(call, close)
	return out
