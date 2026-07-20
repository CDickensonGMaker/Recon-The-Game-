## A perf harness must measure the world the game ships. Its REFERENCE row must reproduce
## the shipped render config; only a declared study phase may deviate.
## Shrink the register:  godot --headless --path . res://tests/test_ship_parity.tscn -- --write-baseline
## Grow it (recorded forever): ... -- --grandfather --reason="<why>"
extends Node

## Where the shipped values are authored. Excluded from the harness rules: it IS the reference.
const SHIP_FILE: String = "res://scripts/levels/game_world.gd"
const BASELINE_PATH: String = "res://tests/parity_baseline.json"
const BASELINE_COMMENT: String = "SHIP-PARITY REGISTER. Declared deviations from shipped render config in perf harnesses, keyed file|property|rhs (NOT line - lines move). THIS LIST ONLY SHRINKS. 'count' and 'ceiling' are the ratchet's witnesses: the probe FAILS if either disagrees with 'deviations', so a hand-edit cannot pass quietly. --write-baseline can only ever remove entries. New entries enter ONLY via --grandfather --reason=<text>. A declaration NEVER satisfies RULE B: a harness that deviates must still restore ship somewhere, and no register entry can buy its way out of that."

## Any .gd under these roots that reads a frame/render figure is a perf harness, discovered
## rather than listed. The 2026-07-17 fix was instance-shaped: it repaired ai_stress_arena and
## left the identical defect in perf_probe. Discovery is what covers the harness not yet written.
const HARNESS_DIRS: Array[String] = ["res://tests", "res://tools", "res://scripts/levels"]
const MEASUREMENT_MARKERS: Array[String] = [
	"get_rendering_info",
	"viewport_get_measured_render_time",
	"get_frames_per_second",
]

## Render properties whose shipped value the reference row must reproduce.
const PARITY_PROPS: Array[String] = ["shadow_enabled", "directional_shadow_max_distance"]

var _failures: int = 0
var _found: Dictionary = {}   ## key -> "file:line  property = rhs"


func _ready() -> void:
	print("=== SHIP-PARITY PROBE ===")

	# The matcher is exercised in both directions before it is trusted. A probe that has
	# never failed proves nothing, and this is the half that cannot rot into always-pass.
	if not _self_test():
		print("")
		print("=== SHIP-PARITY PROBE FAIL (self-test: the matcher is broken) ===")
		get_tree().quit(1)
		return

	var ship: Dictionary = _read_ship_config()
	print("ship config (%s):" % SHIP_FILE)
	for p: String in ship:
		print("    %s = %s" % [p, str(ship[p])])
	if ship.is_empty():
		print("*** no parity property is assigned in the ship file - the probe has no reference. ***")
		get_tree().quit(1)
		return

	var harnesses: Array[String] = _discover_harnesses()
	print("harnesses discovered: %d" % harnesses.size())
	for h: String in harnesses:
		print("    %s" % h)

	# RULE A: every parity assignment in a harness is ship-derived, ship-literal, or declared.
	# RULE B: a harness that deviates must ALSO reference ship for that property somewhere -
	# the reference row has to exist. No register entry can satisfy this.
	var deviating: Dictionary = {}   ## file -> {property: true}
	var restores: Dictionary = {}    ## file -> {property: true}
	for f: String in harnesses:
		_scan_harness(f, ship, deviating, restores)

	var keys: Array = _found.keys()
	keys.sort()

	var doc: Dictionary = _read_baseline_doc()
	var declared: Array = doc.get("deviations", []) as Array

	if "--write-baseline" in OS.get_cmdline_user_args():
		_shrink_baseline(doc, keys)
		return
	if "--grandfather" in OS.get_cmdline_user_args():
		_grandfather(doc, keys)
		return

	if not _audit_register(doc, declared):
		print("")
		print("=== SHIP-PARITY PROBE FAIL (register tampered) ===")
		get_tree().quit(1)
		return

	var known: Dictionary = {}
	for d: Variant in declared:
		known[str(d)] = true

	print("")
	print("deviations found: %d   declared: %d" % [keys.size(), declared.size()])

	var undeclared: Array[String] = []
	for k: String in keys:
		if not known.has(k):
			undeclared.append("%s\n        key: %s" % [str(_found[k]), k])

	var stale: Array[String] = []
	for d: Variant in declared:
		if not _found.has(str(d)):
			stale.append(str(d))

	if stale.size() > 0:
		print("")
		print("*** %d DECLARED DEVIATION(S) GONE - good. Shrink the register: ***" % stale.size())
		for s: String in stale:
			print("    - %s" % s)
		print("    run:  godot --headless --path . res://tests/test_ship_parity.tscn -- --write-baseline")

	if undeclared.size() > 0:
		_failures += undeclared.size()
		print("")
		print("*** RULE A - %d UNDECLARED DEVIATION(S) FROM SHIPPED CONFIG ***" % undeclared.size())
		print("    A harness may STUDY a what-if, but it may not bake one into its reference row.")
		print("    Assign the captured ship value, or declare the study phase:")
		print("    ... res://tests/test_ship_parity.tscn -- --grandfather --reason=\"<why>\"")
		for u: String in undeclared:
			print("    - %s" % u)

	for f: String in deviating:
		var props: Dictionary = deviating[f] as Dictionary
		for p: String in props:
			var r: Dictionary = restores.get(f, {}) as Dictionary
			if not r.has(p):
				_failures += 1
				print("")
				print("*** RULE B - %s deviates on '%s' and NEVER reads the shipped value. ***" % [f, p])
				print("    Its baseline is whatever the deviation left behind. This is the")
				print("    2026-07-16 and 2026-07-20 defect exactly. Capture ship (e.g.")
				print("    `_shipped = sun.%s`) and restore it on every non-study phase." % p)

	print("")
	if _failures == 0:
		print("=== SHIP-PARITY PROBE PASS (%d harness(es), %d declared deviation(s)) ===" % [
			harnesses.size(), declared.size()])
		get_tree().quit(0)
	else:
		print("=== SHIP-PARITY PROBE FAIL (%d) ===" % _failures)
		get_tree().quit(1)


## ------------------------------------------------------------------ the matcher

## Returns "" for a line that assigns nothing, else "property rhs".
func _match_assignment(line: String) -> String:
	var code: String = line
	var hash_at: int = code.find("#")
	if hash_at >= 0 and code.count("\"") % 2 == 0:
		code = code.substr(0, hash_at)
	var eq: int = code.find("=")
	if eq < 0:
		return ""
	if eq + 1 < code.length() and code[eq + 1] == "=":
		return ""
	if eq > 0 and code[eq - 1] in ["=", "!", "<", ">", "+", "-", "*", "/"]:
		return ""
	var lhs: String = code.substr(0, eq).strip_edges()
	var rhs: String = code.substr(eq + 1).strip_edges()
	if rhs.is_empty():
		return ""
	var dot: int = lhs.rfind(".")
	if dot < 0:
		return ""
	var prop: String = lhs.substr(dot + 1).strip_edges()
	if not PARITY_PROPS.has(prop):
		return ""
	# `if sun.shadow_enabled == x:` and friends never reach here (the == guard above),
	# but a lone `var` declaration would - it has no receiver, so the rfind("." ) fails.
	return "%s %s" % [prop, rhs]


## Does this expression read the shipped value rather than assert one?
func _is_ship_derived(rhs: String, prop: String) -> bool:
	if rhs.contains("." + prop):
		return true   # `sun.shadow_enabled` - a capture of whatever ship set
	var low: String = rhs.to_lower()
	return low.contains("_ship") or low.begins_with("ship") or low.contains("shipped")


func _self_test() -> bool:
	var ok: int = 0
	var bad: Array[String] = []

	# MUST FLAG - the actual historical defect, verbatim from perf_probe.gd:123 (2026-07-20)
	# and its ai_stress_arena.gd:390 ancestor (2026-07-16).
	var must_flag: Array[String] = [
		"\t\t\tsun.shadow_enabled = phase_name != \"no_sun_shadow\"",
		"\tsun.shadow_enabled = true",
		"\t\tsun.directional_shadow_max_distance = 40.0",
		"  self.sun.shadow_enabled = not _off",
	]
	# MUST PASS - ship parity, and the legitimate what-if restore arm.
	var must_pass: Array[String] = [
		"\t\t\tsun.shadow_enabled = _shipped_shadow",
		"\tlight.shadow_enabled = false",
		"\t_shadows_on = sun.shadow_enabled",
		"\tif sun.shadow_enabled == true:",
		"\tvar shadow_enabled: bool = true",
		"\t\tsun.shadow_enabled = ship_shadow",
	]
	var ship: Dictionary = {"shadow_enabled": "false", "directional_shadow_max_distance": ""}

	for src: String in must_flag:
		var m: String = _match_assignment(src)
		var flagged: bool = false
		if m != "":
			var parts: PackedStringArray = m.split(" ", true, 1)
			var p: String = parts[0]
			var r: String = parts[1]
			flagged = not _is_ship_derived(r, p) and r != str(ship.get(p, ""))
		if flagged:
			ok += 1
		else:
			bad.append("did NOT flag: %s" % src.strip_edges())

	for src2: String in must_pass:
		var m2: String = _match_assignment(src2)
		var flagged2: bool = false
		if m2 != "":
			var parts2: PackedStringArray = m2.split(" ", true, 1)
			var p2: String = parts2[0]
			var r2: String = parts2[1]
			flagged2 = not _is_ship_derived(r2, p2) and r2 != str(ship.get(p2, ""))
		if not flagged2:
			ok += 1
		else:
			bad.append("FALSELY flagged: %s" % src2.strip_edges())

	# Discovery must tell a harness from an ordinary script.
	if _looks_like_harness("var x: float = float(Engine.get_frames_per_second())"):
		ok += 1
	else:
		bad.append("discovery missed a measuring script")
	if not _looks_like_harness("func _ready() -> void:\n\tprint(\"hello\")"):
		ok += 1
	else:
		bad.append("discovery claimed a non-measuring script")

	print("self-test: %d/%d checks" % [ok, ok + bad.size()])
	for b: String in bad:
		print("    SELF-TEST FAIL: %s" % b)
	return bad.is_empty()


## ------------------------------------------------------------------ scanning

func _looks_like_harness(src: String) -> bool:
	for m: String in MEASUREMENT_MARKERS:
		if src.contains(m):
			return true
	return false


func _read_ship_config() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(SHIP_FILE, FileAccess.READ)
	if f == null:
		return out
	var n: int = 0
	while not f.eof_reached():
		var line: String = f.get_line()
		n += 1
		var m: String = _match_assignment(line)
		if m == "":
			continue
		var parts: PackedStringArray = m.split(" ", true, 1)
		if not out.has(parts[0]):
			out[parts[0]] = parts[1]
	f.close()
	return out


func _discover_harnesses() -> Array[String]:
	var out: Array[String] = []
	for d: String in HARNESS_DIRS:
		_collect(d, out)
	var keep: Array[String] = []
	var self_path: String = (get_script() as Script).resource_path
	for f: String in out:
		# The reference file is not a harness, and this probe's own self-test fixtures are
		# deliberately-malformed source strings - scanning them would flag the negative control.
		if f == SHIP_FILE or f == self_path:
			continue
		var src: String = FileAccess.get_file_as_string(f)
		if _looks_like_harness(src):
			keep.append(f)
	keep.sort()
	return keep


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_collect(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _scan_harness(path: String, ship: Dictionary, deviating: Dictionary, restores: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var rel: String = path.replace("res://", "")
	var n: int = 0
	while not f.eof_reached():
		var line: String = f.get_line()
		n += 1
		# A read of the shipped value anywhere in the file satisfies RULE B - capturing it
		# into a mirror (`_shadows_on = sun.shadow_enabled`) is exactly the correct pattern.
		for p: String in PARITY_PROPS:
			if line.contains("." + p) and not line.strip_edges().begins_with("#"):
				var m0: String = _match_assignment(line)
				var is_write_of_p: bool = m0 != "" and m0.split(" ", true, 1)[0] == p
				if not is_write_of_p or _is_ship_derived(m0.split(" ", true, 1)[1], p):
					if not restores.has(rel):
						restores[rel] = {}
					(restores[rel] as Dictionary)[p] = true
		var m: String = _match_assignment(line)
		if m == "":
			continue
		var parts: PackedStringArray = m.split(" ", true, 1)
		var prop: String = parts[0]
		var rhs: String = parts[1]
		if _is_ship_derived(rhs, prop):
			continue
		if ship.has(prop) and rhs == str(ship[prop]):
			continue   # asserts the shipped literal - parity by value
		var key: String = "%s|%s|%s" % [rel, prop, rhs]
		_found[key] = "%s:%d  %s = %s" % [rel, n, prop, rhs]
		if not deviating.has(rel):
			deviating[rel] = {}
		(deviating[rel] as Dictionary)[prop] = true
	f.close()


## ------------------------------------------------------------------ the ratchet

func _read_baseline_doc() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		return {"_comment": BASELINE_COMMENT, "ceiling": 0, "count": 0,
			"deviations": [], "grandfather_log": []}
	var txt: String = FileAccess.get_file_as_string(BASELINE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {"_comment": BASELINE_COMMENT, "ceiling": 0, "count": 0,
		"deviations": [], "grandfather_log": []}


func _audit_register(doc: Dictionary, declared: Array) -> bool:
	var count: int = int(doc.get("count", -1))
	var ceiling: int = int(doc.get("ceiling", -1))
	if count != declared.size():
		print("    register 'count'=%d but holds %d entries." % [count, declared.size()])
		return false
	if ceiling < declared.size():
		print("    register 'ceiling'=%d is below its %d entries." % [ceiling, declared.size()])
		return false
	if ceiling > declared.size():
		print("    ceiling %d > count %d - shrink it, the register only ratchets down." % [
			ceiling, declared.size()])
		return false
	return true


func _write_doc(doc: Dictionary, entries: Array[String]) -> void:
	entries.sort()
	doc["_comment"] = BASELINE_COMMENT
	doc["deviations"] = entries
	doc["count"] = entries.size()
	doc["ceiling"] = entries.size()
	var f := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t") + "\n")
	f.close()


## Can only ever REMOVE: the intersection of register and reality.
func _shrink_baseline(doc: Dictionary, keys: Array) -> void:
	var old: Array = doc.get("deviations", []) as Array
	var kept: Array[String] = []
	for d: Variant in old:
		if _found.has(str(d)):
			kept.append(str(d))
	_write_doc(doc, kept)
	print("register shrunk: %d -> %d" % [old.size(), kept.size()])
	get_tree().quit(0)


func _grandfather(doc: Dictionary, keys: Array) -> void:
	var reason: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--reason="):
			reason = a.substr(9)
	if reason.strip_edges().is_empty():
		print("--grandfather requires --reason=\"<why this study deviates from ship>\"")
		get_tree().quit(1)
		return
	var old: Array = doc.get("deviations", []) as Array
	var have: Dictionary = {}
	var merged: Array[String] = []
	for d: Variant in old:
		have[str(d)] = true
		merged.append(str(d))
	var added: Array[String] = []
	for k: String in keys:
		if not have.has(k):
			merged.append(k)
			added.append(k)
	var log: Array = doc.get("grandfather_log", []) as Array
	log.append({
		"date": Time.get_date_string_from_system(),
		"reason": reason,
		"added": added,
	})
	doc["grandfather_log"] = log
	_write_doc(doc, merged)
	print("grandfathered %d entry(ies): %s" % [added.size(), reason])
	get_tree().quit(0)
