## test_dispatch_contract.gd - the dynamic-dispatch coupling probe.
##
## has_method("x") / call("x") / call_deferred("x") / connect("x") name their
## target in a STRING. The compiler cannot check it, a rename does not touch it,
## and a typo fails silently at runtime - has_method simply returns false and the
## branch is skipped forever. That is the temple_shrines failure (a live reader,
## no writer, feature can never fire) pointed at methods instead of groups.
##
## A target is satisfied by a `func` anywhere in the project OR by any engine
## class method. Anything else names a method that exists nowhere.
## Run: godot --headless --path . res://tests/test_dispatch_contract.tscn
extends Node

const SCAN_DIRS: Array[String] = ["res://scripts", "res://terrain", "res://tests", "res://tools"]
const PRODUCTION_DIRS: Array[String] = ["res://scripts", "res://terrain"]

## Dispatch forms whose first string argument is a method name.
const DISPATCH_FORMS: Array[String] = [
	"has_method\\(\\s*\"([^\"]+)\"",
	"(?<![\\w.])call\\(\\s*\"([^\"]+)\"",
	"call_deferred\\(\\s*\"([^\"]+)\"",
	"callv\\(\\s*\"([^\"]+)\"",
]

## Targets resolved on objects this project does not own, or built by the engine
## at runtime. Entries leave this list; they do not join it to silence red.
const ALLOWED_UNRESOLVED: Array[String] = []


func _ready() -> void:
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_walk(d, files)

	var defined: Dictionary = _project_methods(files)
	var engine: Dictionary = _engine_methods()

	var unresolved: Dictionary = {}
	var total: int = 0
	for path in files:
		if path == get_script().resource_path:
			continue
		var src: String = FileAccess.get_file_as_string(path)
		if src.is_empty():
			continue
		var n: int = 0
		for line in src.split("\n"):
			n += 1
			var code: String = line.get_slice("#", 0)
			if code.strip_edges().begins_with("const"):
				continue
			for pattern in DISPATCH_FORMS:
				var rx := RegEx.create_from_string(pattern)
				for m in rx.search_all(code):
					var target: String = m.get_string(1)
					total += 1
					if defined.has(target) or engine.has(target) or target in ALLOWED_UNRESOLVED:
						continue
					if not unresolved.has(target):
						unresolved[target] = []
					(unresolved[target] as Array).append("%s:%d" % [path.trim_prefix("res://"), n])

	var failures: int = 0
	for target in unresolved:
		var sites: Array = unresolved[target]
		if not _any_production(sites):
			continue
		print("FAIL: dispatch target \"%s\" is defined NOWHERE - the branch can never fire\n        at %s"
			% [target, ", ".join(sites)])
		failures += 1

	# Self-test: a PASS is only meaningful if the detector can still fail. The
	# synthetic name must be extracted by the regexes AND resolve nowhere.
	var probe_line: String = "\thas_method(\"zzz_synthetic_dispatch_target\")"
	var caught := false
	for pattern in DISPATCH_FORMS:
		var m := RegEx.create_from_string(pattern).search(probe_line)
		if m != null and m.get_string(1) == "zzz_synthetic_dispatch_target":
			caught = true
	if not caught or defined.has("zzz_synthetic_dispatch_target"):
		print("FAIL(self-test): the detector no longer flags an unresolvable target")
		failures += 1

	print("dispatch: %d string-named targets, %d project funcs, %d engine methods" % [
		total, defined.size(), engine.size()])
	if failures == 0:
		print("PASS: every string-named dispatch target resolves")
		get_tree().quit(0)
	else:
		print("FAIL: %d unresolved dispatch target(s)" % failures)
		get_tree().quit(1)


func _project_methods(files: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var rx := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+(\\w+)\\s*\\(")
	for path in files:
		var src: String = FileAccess.get_file_as_string(path)
		if src.is_empty():
			continue
		for line in src.split("\n"):
			var m := rx.search(line)
			if m != null:
				out[m.get_string(1)] = true
	return out


## Every method the engine ships, flattened. A target found here is dispatched on
## an engine object, not on project code, and is not ours to verify.
func _engine_methods() -> Dictionary:
	var out: Dictionary = {}
	for cls in ClassDB.get_class_list():
		for md in ClassDB.class_get_method_list(cls, true):
			out[str(md["name"])] = true
	return out


func _any_production(sites: Array) -> bool:
	for s in sites:
		for d in PRODUCTION_DIRS:
			if (s as String).begins_with(d.trim_prefix("res://")):
				return true
	return false


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_walk(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
