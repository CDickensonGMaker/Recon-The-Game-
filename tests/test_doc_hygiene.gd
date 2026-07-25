## test_doc_hygiene.gd - runs the Python doc-drift probes under the suite so they gate the
## build like any .gd test. run_all_tests.ps1 only discovers tests/test_*.tscn, and these
## probes are Python, so this wrapper is how THE POINTER LAW (probe_doc_pointers.py) and
## the RETIRED-REF probe (probe_retired_refs.py) become build-breaking.
## Run: godot --headless --path . res://tests/test_doc_hygiene.tscn
extends Node

const PROBES: Array[String] = [
	"tools/probe_doc_pointers.py",
	"tools/probe_retired_refs.py",
]


func _ready() -> void:
	print("=== DOC HYGIENE (pointer law + retired-ref probes) ===")
	var py: String = _python()
	if py.is_empty():
		push_error("[doc_hygiene] no python interpreter on PATH - cannot run the doc probes")
		get_tree().quit(1)
		return

	var failures: int = 0
	for probe in PROBES:
		var out: Array = []
		var script_path: String = ProjectSettings.globalize_path("res://" + probe)
		var code: int = OS.execute(py, [script_path], out, true)
		if out.size() > 0:
			print(String(out[0]).strip_edges())
		if code != 0:
			push_error("[doc_hygiene] %s FAILED (exit %d)" % [probe, code])
			failures += 1

	if failures == 0:
		print("=== DOC HYGIENE PASS ===")
		get_tree().quit(0)
	else:
		print("=== DOC HYGIENE FAIL (%d probe(s)) ===" % failures)
		get_tree().quit(1)


## First interpreter on PATH that answers --version, or "" if none.
func _python() -> String:
	for exe in ["python", "python3", "py"]:
		if OS.execute(exe, ["--version"]) == 0:
			return exe
	return ""
