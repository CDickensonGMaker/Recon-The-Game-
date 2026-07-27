## test_group_contract.gd - group-string coupling probe.
## Godot groups are stringly-typed: neither the type system nor a grep can prove
## a writer and a reader agree. A group written and never read is an inert link
## that reads as live wiring; a group read and never written is a silently dead
## feature (the temple_shrines class, player.gd:454,602, found 2026-07-25).
## Both registers only ratchet DOWN - see ADR-023.
## Run: godot --headless --path . res://tests/test_group_contract.tscn
extends Node

const SCAN_DIRS: Array[String] = ["res://scripts", "res://terrain", "res://tests", "res://tools"]

## Production dirs. A group READ only from tests/ or tools/ is not live wiring.
const PRODUCTION_DIRS: Array[String] = ["res://scripts", "res://terrain"]

## Dev benches are out of scope (Summoner, 2026-07-27). The stress arena wires
## its own sterile world and its groups answer to nothing shipping.
const EXCLUDED_BENCHES: Array[String] = [
	"res://scripts/levels/ai_stress_arena.gd",
]

## Group names reach the tree two ways: a literal add_to_group, or a string
## inside an array handed to a builder. Miss the second and civilian_hurtbox
## reads as never-written when civilian.gd:154 plainly writes it.
const GROUP_BUILDER_CALLS: Array[String] = [
	"HitzoneBuilder.build(", "HitzoneBuilder._build_static(",
]

## Accepted inert writers. Entries leave this list; they never join it without a
## ruling recorded alongside.
const ALLOWED_WRITE_ONLY: Array[String] = [
	"nav_source",      # gun_range.gd:45 - gun_range bakes no navmesh
	"armorers_bench",  # armorers_bench.gd:63 - bench resolved by preload, not by group
]

## Accepted readerless-in-production groups.
const ALLOWED_READ_ONLY: Array[String] = []


func _ready() -> void:
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_walk(d, files)

	var writes: Dictionary = {}
	var reads: Dictionary = {}
	for path in files:
		if path == get_script().resource_path or path in EXCLUDED_BENCHES:
			continue
		var src: String = FileAccess.get_file_as_string(path)
		if src.is_empty():
			continue
		var n: int = 0
		for line in src.split("\n"):
			n += 1
			var code: String = line.get_slice("#", 0)
			if code.strip_edges().is_empty():
				continue
			# A list of call names is not a call. This probe failed its own first
			# run by counting its GROUP_BUILDER_CALLS declaration as six writers.
			var declares: bool = code.strip_edges().begins_with("const")
			for g in _match_all(code, "add_to_group\\(\\s*\"([^\"]+)\""):
				_record(writes, g, path, n)
			if not declares:
				for call in GROUP_BUILDER_CALLS:
					if code.contains(call):
						for g2 in _match_all(code, "\"([^\"]+)\""):
							_record(writes, g2, path, n)
			for g3 in _match_all(code,
					"(?:is_in_group|get_nodes_in_group|get_first_node_in_group)\\(\\s*\"([^\"]+)\""):
				_record(reads, g3, path, n)

	var failures: int = 0
	failures += _report(writes, reads, ALLOWED_WRITE_ONLY, true,
		"written but NEVER READ - inert link that reads as live wiring")
	failures += _report(reads, writes, ALLOWED_READ_ONLY, true,
		"read from production but NEVER WRITTEN - the feature can never fire")

	print("groups: %d written, %d read" % [writes.size(), reads.size()])
	if failures == 0:
		print("PASS: every group has a writer and a reader")
		get_tree().quit(0)
	else:
		print("FAIL: %d group contract violation(s)" % failures)
		get_tree().quit(1)


## `production_only` judges the side being checked: a group touched only from
## tests/ or tools/ is scaffolding, and a group read solely by a probe is not
## proof of a live consumer.
func _report(subject: Dictionary, counterpart: Dictionary, allowed: Array[String],
		production_only: bool, label: String) -> int:
	var failures: int = 0
	for g in subject:
		if counterpart.has(g) or g in allowed:
			continue
		var sites: Array = subject[g]
		if production_only and not _any_production(sites):
			continue
		print("FAIL: group \"%s\" %s\n        at %s" % [g, label, ", ".join(sites)])
		failures += 1
	return failures


func _any_production(sites: Array) -> bool:
	for s in sites:
		for d in PRODUCTION_DIRS:
			if (s as String).begins_with(d.trim_prefix("res://")):
				return true
	return false


func _record(bag: Dictionary, group: String, path: String, line: int) -> void:
	if not bag.has(group):
		bag[group] = []
	(bag[group] as Array).append("%s:%d" % [path.trim_prefix("res://"), line])


func _match_all(text: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var rx := RegEx.create_from_string(pattern)
	for m in rx.search_all(text):
		out.append(m.get_string(1))
	return out


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
