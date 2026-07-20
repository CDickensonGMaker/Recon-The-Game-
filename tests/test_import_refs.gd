extends Node
## test_import_refs.gd - every .import file's source_file must exist on disk.
##
## A .import whose source_file points at a moved or deleted path fails silently:
## Godot records valid=false in the .import and carries on booting. The asset is
## simply never available, and nothing in the suite notices. This is invisible to
## the fossil probe (a broken res:// path is not a symbol) and invisible to a
## headless boot (the asset is only loaded on demand).
##
## Found by hand: assets/building models/vehicles/USM4A3Sherman.obj.import named
## res://assets/models/us/vehicles/USM4A3Sherman.obj, a directory that does not
## exist, while the .obj sat beside the .import all along.
##
## Run: godot --headless --path . res://tests/test_import_refs.tscn

const SCAN_DIRS: Array[String] = ["res://assets", "res://scenes", "res://terrain"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: IMPORT SOURCE REFERENCES ===")

	var imports: Array[String] = []
	for dir: String in SCAN_DIRS:
		_collect(dir, imports)
	if imports.size() < 100:
		print("FAIL: found only %d .import files - the walker is broken, not the assets" % imports.size())
		get_tree().quit(1)
		return
	print("Scanned %d .import files across %s" % [imports.size(), ", ".join(SCAN_DIRS)])

	# Negative control: a source_file that cannot exist MUST be flagged, and a
	# path that does exist must NOT be. A probe that has never failed proves nothing.
	var bogus: String = "res://assets/__no_such_dir__/__no_such_file__.glb"
	if _source_ok(bogus):
		print("FAIL: self-test - matcher accepted a path that does not exist: %s" % bogus)
		get_tree().quit(1)
		return
	if not _source_ok(imports[0].trim_suffix(".import")):
		print("FAIL: self-test - matcher rejected a real path: %s" % imports[0])
		get_tree().quit(1)
		return

	var broken: Array[String] = []
	var stale_valid: Array[String] = []
	for imp: String in imports:
		var src: String = _read_source(imp)
		if src.is_empty():
			continue
		if not _source_ok(src):
			broken.append("%s -> %s" % [imp, src])
		elif _reads_invalid(imp):
			# The referent exists but the .import still records the old failure.
			stale_valid.append(imp)

	for b: String in broken:
		print("BROKEN: %s" % b)
	for s: String in stale_valid:
		print("STALE valid=false (source exists, needs reimport): %s" % s)

	var fails: int = broken.size()
	print("--- %d broken source_file refs, %d stale valid=false ---" % [fails, stale_valid.size()])
	if fails > 0:
		print("FAIL")
		get_tree().quit(1)
		return
	print("PASS")
	get_tree().quit(0)


## The source_file= line of an .import, or "" if it has none.
func _read_source(import_path: String) -> String:
	var f := FileAccess.open(import_path, FileAccess.READ)
	if f == null:
		return ""
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("source_file="):
			return line.substr(12).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


func _reads_invalid(import_path: String) -> bool:
	var f := FileAccess.open(import_path, FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		if f.get_line().strip_edges() == "valid=false":
			return true
	return false


## FileAccess.file_exists is the only honest check here: ResourceLoader.exists()
## answers from the import cache, which is exactly the thing under test.
func _source_ok(res_path: String) -> bool:
	if not res_path.begins_with("res://"):
		return false
	return FileAccess.file_exists(res_path)


func _collect(dir: String, out: Array[String]) -> void:
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
			_collect(full, out)
		elif entry.ends_with(".import"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
