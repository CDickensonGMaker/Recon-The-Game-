## test_test_only_liveness.gd - a test is not a caller.
##
## Run: godot --headless --path . res://tests/test_test_only_liveness.tscn
## Shrink:      ... -- --write-baseline
## Add (rare):  ... -- --grandfather --reason="<why>"
##
## THE DISEASE. tests/test_fossils.gd unions tests/ and tools/ into REF_DIRS alongside
## scripts/, so ONE test call is indistinguishable from one production call. A symbol
## whose only caller is its own test scores refs=1 and is judged live forever. That
## alibi hid five findings in the 2026-07-19 audit - the same inversion as the
## _judge() bug where a declaration counted as its own reference, and the same as the
## death register counting as a caller.
##
## TWO REGISTERS, NOT ONE, and the split is the whole point.
##   debt  - production code alive only by its test. Shrinks by wiring it or cutting it.
##   seams - read-only observers a test must call to see state it cannot otherwise
##           reach (count_live, hot_count, get_stats...). These are CORRECT and expected.
## Fold them together and nobody can shrink the register with confidence, because every
## attempted shrink stalls on "is this one a seam?" - and a register that cannot be
## shrunk is a snooze button, which is the one forbidden move (ADR-023).
##
## SCOPE. func and const only. class_name is excluded by construction: those scripts are
## reached by preload path or by group, so an untyped identifier proves nothing. Plain
## var is excluded too - locals and _ready/_physics_process member state defeat
## name-counting outright. The measured signal lives in func and const.
extends Node

const BASELINE_PATH: String = "res://tests/test_only_liveness_baseline.json"
const BASELINE_COMMENT: String = "Production symbols whose ONLY references are tests. 'debt' = alive only by its test, shrink by wiring or cutting. 'seams' = read-only observers a test legitimately needs. BOTH ONLY SHRINK. 'count'/'ceiling' witness a hand-edit. New entries enter ONLY via --grandfather --reason=<text>."

const PROD_DIRS: Array[String] = ["res://scripts", "res://terrain"]
const TEST_DIRS: Array[String] = ["res://tests", "res://tools"]

## Engine callbacks are invoked by Godot, never by name.
const LIFECYCLE: Array[String] = [
	"_ready", "_process", "_physics_process", "_input", "_unhandled_input",
	"_unhandled_key_input", "_enter_tree", "_exit_tree", "_notification", "_init",
	"_draw", "_gui_input", "_to_string", "_get", "_set", "_get_property_list",
	"_integrate_forces", "_shortcut_input", "_can_drop_data", "_drop_data",
	"_get_drag_data", "_validate_property", "_property_can_revert",
	"_property_get_revert", "_static_init", "_get_configuration_warnings",
]

## ModelActor resolves the entire cast from bare unit_id strings - 913 of 1291 assets
## have zero grep hits. Its consts name units, so name-counting cannot judge them.
const DYNAMIC_FILES: Array[String] = ["res://scripts/visuals/model_actor.gd"]

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()

	var prod: PackedStringArray = _gather(PROD_DIRS)
	var tests: PackedStringArray = _gather(TEST_DIRS)

	var decls: Dictionary = {}       ## sym -> Array[String] of declaring files
	for path: String in prod:
		_declare(path, decls)

	var prod_refs: Dictionary = _tally(prod, decls)
	var test_refs: Dictionary = _tally(tests, {})
	var str_syms: Dictionary = _string_symbols(prod)

	var found: PackedStringArray = PackedStringArray()
	for sym: String in decls:
		if sym in LIFECYCLE or str_syms.has(sym):
			continue
		# An override family's call site names the BASE, so the child looks unreferenced.
		if (decls[sym] as Array).size() > 1:
			continue
		var declared_in: String = (decls[sym] as Array)[0]
		if declared_in in DYNAMIC_FILES:
			continue
		if int(prod_refs.get(sym, 0)) > 0:
			continue
		if int(test_refs.get(sym, 0)) <= 0:
			continue
		found.append("%s|%s" % [declared_in.replace("res://", ""), sym])
	found.sort()

	if "--write-baseline" in args:
		_write_baseline(found)
		get_tree().quit(0)
		return
	if "--grandfather" in args:
		_grandfather(found, args)
		get_tree().quit(0)
		return

	_judge(found)
	if failures > 0:
		print("FAIL: test_test_only_liveness - %d failure(s) across %d checks" % [failures, checks])
	else:
		print("PASS: test_test_only_liveness - %d checks, %d test-only symbol(s) on the register" % [checks, found.size()])
	get_tree().quit(1 if failures > 0 else 0)


func _judge(found: PackedStringArray) -> void:
	var doc: Dictionary = _load_baseline()
	var debt: PackedStringArray = PackedStringArray(doc.get("debt", []))
	var seams: PackedStringArray = PackedStringArray(doc.get("seams", []))
	if not _witnesses_agree(doc, debt, seams):
		return

	for entry: String in found:
		checks += 1
		if entry in debt or entry in seams:
			continue
		var bits: PackedStringArray = entry.split("|")
		failures += 1
		print("  FAIL: %s declares %s, and NOTHING in scripts/ or terrain/ references it - only a test does. A test is not a caller. Wire it, cut it, or record it as a deliberate test seam." % [bits[0], bits[1]])

	var healed: PackedStringArray = PackedStringArray()
	for entry: String in debt:
		if not (entry in found):
			healed.append(entry)
	if healed.size() > 0:
		print("  %d debt entr(ies) now have production callers - run --write-baseline to bank it:" % healed.size())
		for h: String in healed:
			print("      %s" % h)


# ---- corpus -----------------------------------------------------------------

func _gather(dirs: Array[String]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: String in dirs:
		_walk(d, out)
	return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var full: String = dir_path + "/" + name
		if d.current_is_dir():
			_walk(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


## A COMMENT IS A TOMBSTONE, NOT A CALLER. `# was a hardcoded ALERT_RANGE*2` is the
## exact sentence that kept a dead const off the fossil list.
## QUOTE-AWARE by necessity: a bare line.find("#") truncates every line carrying a
## '#' inside a string literal, silently dropping real call sites from the corpus.
func _strip(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in src.split("\n"):
		var in_s: bool = false
		var quote: String = ""
		var cut: int = -1
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if c == "\\" and in_s:
				i += 2
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


func _declare(path: String, decls: Dictionary) -> void:
	var src: String = _strip(FileAccess.get_file_as_string(path))
	for line: String in src.split("\n"):
		var s: String = line.strip_edges()
		var sym: String = ""
		if s.begins_with("func "):
			sym = s.substr(5).split("(")[0].strip_edges()
		elif s.begins_with("static func "):
			sym = s.substr(12).split("(")[0].strip_edges()
		elif s.begins_with("const "):
			sym = s.substr(6).split("=")[0].split(":")[0].strip_edges()
		if sym.is_empty() or not _is_ident(sym):
			continue
		if not decls.has(sym):
			decls[sym] = []
		var owners: Array = decls[sym]
		if not (path in owners):
			owners.append(path)


## Occurrences of each declared symbol, minus the declarations themselves.
## A DECLARATION IS NOT A REFERENCE - counting it makes every symbol its own caller.
func _tally(files: PackedStringArray, decls: Dictionary) -> Dictionary:
	var freq: Dictionary = {}
	for path: String in files:
		if path == BASELINE_PATH:
			continue
		var src: String = _strip(FileAccess.get_file_as_string(path))
		for tok: String in _tokens(src):
			freq[tok] = int(freq.get(tok, 0)) + 1
	for sym: String in decls:
		var owners: Array = decls[sym]
		freq[sym] = int(freq.get(sym, 0)) - owners.size()
	return freq


## Every identifier appearing inside a production STRING LITERAL. call("foo"),
## has_method("foo"), connect("foo"), add_to_group("foo") and .tres property names
## are all invisible to name-counting, so anything named in a string is exempt BY
## CONSTRUCTION - never by padding the baseline.
func _string_symbols(files: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for path: String in files:
		var src: String = _strip(FileAccess.get_file_as_string(path))
		var parts: PackedStringArray = src.split("\"")
		var i: int = 1
		while i < parts.size():
			for tok: String in _tokens(parts[i]):
				out[tok] = true
			i += 2
	return out


func _tokens(src: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur: String = ""
	for ch: String in src:
		if _ident_char(ch):
			cur += ch
		else:
			if cur.length() > 1:
				out.append(cur)
			cur = ""
	if cur.length() > 1:
		out.append(cur)
	return out


func _ident_char(ch: String) -> bool:
	return ch == "_" or (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") \
		or (ch >= "0" and ch <= "9")


func _is_ident(s: String) -> bool:
	for ch: String in s:
		if not _ident_char(ch):
			return false
	return true


# ---- baseline ---------------------------------------------------------------

func _load_baseline() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		push_warning("no liveness baseline - run with --grandfather --reason=<text>")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	return parsed if parsed is Dictionary else {}


func _witnesses_agree(doc: Dictionary, debt: PackedStringArray, seams: PackedStringArray) -> bool:
	if doc.is_empty():
		return true
	if int(doc.get("count", -1)) != debt.size():
		checks += 1
		failures += 1
		print("  FAIL: REGISTER TAMPERED: count=%s but debt=%d." % [str(doc.get("count", "<missing>")), debt.size()])
		return false
	if int(doc.get("seam_count", -1)) != seams.size():
		checks += 1
		failures += 1
		print("  FAIL: REGISTER TAMPERED: seam_count=%s but seams=%d." % [str(doc.get("seam_count", "<missing>")), seams.size()])
		return false
	if debt.size() > int(doc.get("ceiling", 0)):
		checks += 1
		failures += 1
		print("  FAIL: REGISTER GREW: debt %d > ceiling %d. This register only shrinks." % [debt.size(), int(doc.get("ceiling", 0))])
		return false
	if seams.size() > int(doc.get("seam_ceiling", 0)):
		checks += 1
		failures += 1
		print("  FAIL: SEAM REGISTER GREW: %d > ceiling %d. The escape hatch ratchets too." % [seams.size(), int(doc.get("seam_ceiling", 0))])
		return false
	return true


## Can only ever REMOVE. Entries stay in whichever register already holds them.
func _write_baseline(found: PackedStringArray) -> void:
	var doc: Dictionary = _load_baseline()
	var debt: PackedStringArray = PackedStringArray()
	for e: String in PackedStringArray(doc.get("debt", [])):
		if e in found:
			debt.append(e)
	var seams: PackedStringArray = PackedStringArray()
	for e: String in PackedStringArray(doc.get("seams", [])):
		if e in found:
			seams.append(e)
	doc["_comment"] = BASELINE_COMMENT
	doc["debt"] = debt
	doc["count"] = debt.size()
	doc["ceiling"] = mini(int(doc.get("ceiling", debt.size())), debt.size())
	doc["seams"] = seams
	doc["seam_count"] = seams.size()
	doc["seam_ceiling"] = mini(int(doc.get("seam_ceiling", seams.size())), seams.size())
	doc.get_or_add("grandfather_log", [])
	_save(doc)
	print("baseline written: debt %d (ceiling %d), seams %d (ceiling %d)"
		% [debt.size(), int(doc["ceiling"]), seams.size(), int(doc["seam_ceiling"])])


func _grandfather(found: PackedStringArray, args: PackedStringArray) -> void:
	var reason: String = ""
	for a: String in args:
		if a.begins_with("--reason="):
			reason = a.substr(len("--reason="))
	if reason.strip_edges().length() < 12:
		push_error("--grandfather requires --reason=\"<why these stand>\"")
		return
	var doc: Dictionary = _load_baseline()
	var debt: PackedStringArray = PackedStringArray(doc.get("debt", []))
	var seams: PackedStringArray = PackedStringArray(doc.get("seams", []))
	var added: PackedStringArray = PackedStringArray()
	for e: String in found:
		if not (e in debt) and not (e in seams):
			debt.append(e)
			added.append(e)
	debt.sort()
	doc["_comment"] = BASELINE_COMMENT
	doc["debt"] = debt
	doc["count"] = debt.size()
	doc["ceiling"] = debt.size()
	doc["seams"] = seams
	doc["seam_count"] = seams.size()
	doc["seam_ceiling"] = seams.size()
	var log: Array = doc.get("grandfather_log", [])
	log.append({
		"date": Time.get_date_string_from_system(),
		"reason": reason,
		"added": added,
	})
	doc["grandfather_log"] = log
	_save(doc)
	print("grandfathered %d into debt, ceiling %d, reason: %s" % [added.size(), debt.size(), reason])


func _save(doc: Dictionary) -> void:
	var f := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", false) + "\n")
	f.close()
