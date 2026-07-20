extends Node
## test_scored_flags.gd - every result key the debrief SCORES must be produced by
## something that runs in the game.
##
## THE DEFECT CLASS: a permanently-false branch. Dictionary.get(key, default)
## never throws, so a scoring rule keyed on a value nothing ever writes reads as
## live, working, tested code. It parses clean, it boots clean, the debrief prints
## a score, and the rule silently never fires. The fossil probe cannot see it -
## the symbol is a STRING, not a declaration.
##
## Found by this probe's construction, 2026-07-20:
##   emergency_exfil - declared, serialized, scored -50, set true NOWHERE. The
##     exfil bird it belonged to was deleted by ADR-029. Removed under fossil law.
##   pow_lost - scored -100 at debrief.gd, set true NOWHERE. NOT removed: ADR-006
##     names it, so its absence is a Summoner call, not a cleanup. Ratcheted below.
##
## Run: godot --headless --path . res://tests/test_scored_flags.tscn

const DEBRIEF: String = "res://scripts/ui/screens/debrief.gd"
const PRODUCER_DIRS: Array[String] = ["res://scripts"]

## Scored keys that KNOWINGLY have no producer, each with the reason it stays.
## This is a RATCHET, not an excuse list: if a key here GAINS a producer, this
## probe FAILS until the entry is deleted. That is what forces the list to shrink.
const AWAITING_PRODUCER: Dictionary = {
	"pow_lost":
		"Scored -100 and named in ADR-006, but the POW-rescue mission that set it "
		+ "was removed by ADR-029. Wire it or amend ADR-006 - Summoner's call, not cleanup.",
}

var _fails: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: SCORED RESULT FLAGS HAVE PRODUCERS ===")

	var scored: Array[String] = _scored_keys()
	if scored.size() < 4:
		print("FAIL: parsed only %d scored keys from %s - the parser is broken, not the game" % [scored.size(), DEBRIEF])
		get_tree().quit(1)
		return
	print("Scored keys (%d): %s" % [scored.size(), ", ".join(scored)])

	var sources: Array[String] = []
	for dir: String in PRODUCER_DIRS:
		_collect_gd(dir, sources)
	sources.erase(DEBRIEF)
	var corpus: String = ""
	for src: String in sources:
		var f := FileAccess.open(src, FileAccess.READ)
		if f != null:
			corpus += f.get_as_text() + "\n"
	if corpus.length() < 10000:
		print("FAIL: producer corpus is %d chars - the walker is broken" % corpus.length())
		get_tree().quit(1)
		return

	# Negative control: a key nothing could possibly produce MUST read as unproduced,
	# and a key that plainly is produced must NOT. A probe that has never failed
	# proves nothing.
	if _has_producer("__no_such_scored_key_ctl__", corpus):
		print("FAIL: self-test - matcher found a producer for a key that cannot exist")
		get_tree().quit(1)
		return
	if not _has_producer("damage_taken", corpus):
		print("FAIL: self-test - matcher found no producer for damage_taken, which mission_state writes")
		get_tree().quit(1)
		return
	print("Self-test OK: matcher separates a real producer from a fictional one.")

	for key: String in scored:
		var produced: bool = _has_producer(key, corpus)
		var waived: bool = AWAITING_PRODUCER.has(key)
		if produced and waived:
			print("RATCHET: '%s' now HAS a producer - delete its AWAITING_PRODUCER entry." % key)
			_fails += 1
		elif produced:
			pass
		elif waived:
			print("KNOWN-UNPRODUCED: '%s' - %s" % [key, AWAITING_PRODUCER[key]])
		else:
			print("DEAD SCORING RULE: '%s' is scored by the debrief and written by nothing." % key)
			_fails += 1

	# The waiver list must not rot either: an entry for a key nobody scores anymore
	# is itself a fossil.
	for key: String in AWAITING_PRODUCER:
		if not scored.has(key):
			print("STALE WAIVER: '%s' is no longer scored - remove it from AWAITING_PRODUCER." % key)
			_fails += 1

	print("--- %d problems ---" % _fails)
	if _fails > 0:
		print("FAIL")
		get_tree().quit(1)
		return
	print("PASS")
	get_tree().quit(0)


## Keys the debrief reads out of the result dictionary via .get("key".
func _scored_keys() -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(DEBRIEF, FileAccess.READ)
	if f == null:
		return out
	var text: String = f.get_as_text()
	var re := RegEx.new()
	re.compile("\\.get\\(\"([a-z_]+)\"")
	for m: RegExMatch in re.search_all(text):
		var k: String = m.get_string(1)
		if not out.has(k):
			out.append(k)
	out.sort()
	return out


## A producer is any write of the key OUTSIDE the debrief: a dictionary literal
## entry, a subscript assignment, or a bare declaration of the same name.
func _has_producer(key: String, corpus: String) -> bool:
	if corpus.find("\"%s\":" % key) != -1:
		return true
	if corpus.find("[\"%s\"]" % key) != -1:
		return true
	var re := RegEx.new()
	re.compile("(?m)^\\s*var\\s+%s\\s*[:=]" % key)
	return re.search(corpus) != null


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
