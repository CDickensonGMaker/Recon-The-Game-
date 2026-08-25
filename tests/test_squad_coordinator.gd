## test_squad_coordinator.gd - squad coordinator probe (War Room 2026-08-24
## Phases 2-3). Drives the coordinator with a synthetic clock and fake members:
##   (a) exposure tokens cap at the doctrine count; grants are staggered
##   (b) while a fight is live and bounding, only the ACTIVE element draws
##       fresh tokens, and the elements ALTERNATE on the bound period
##   (c) tokens expire on their TTL and release() frees a slot
##   (d) exactly ONE suppressor per squad; prefers a covered MG; never a token
##       holder; the slot answer is stable across re-queries inside one refresh
##   (e) the covering-fire census is per-squad and never covers the firer
##   (f) the press draws on the assault_press doctrine: grants beyond any line cap
##   (g) doctrine .tres files load with the decreed token counts
##   (h) fossil tripwire: the killed census symbols have ZERO hits in scripts/
## Run: godot --headless --path . res://tests/test_squad_coordinator.tscn
extends Node

const SC := preload("res://scripts/ai/squad_coordinator.gd")

## The retired census: the ally global static pair and EnemySquad's per-squad
## fire pair. A hit anywhere in scripts/ is a resurrected fossil (ADR-023).
const DEAD_SYMBOLS := ["_last_ally_fire_ms", "_last_ally_firer",
	"EnemySquad.report_firing", "EnemySquad.has_covering_fire"]

var failures: int = 0
var _men: Array[Node] = []


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	failures += 1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


func _man() -> Node:
	var n := Node.new()
	_men.append(n)
	return n


func _run() -> void:
	SC.clear()

	# --- (g) doctrine data of record ------------------------------------------
	var d_us: Resource = SC.doctrine("us")
	var d_nva: Resource = SC.doctrine("nva")
	var d_vc: Resource = SC.doctrine("vc")
	var d_press: Resource = SC.doctrine("assault_press")
	_check(d_us.exposure_tokens == 3, "(g) US tokens %d != 3" % d_us.exposure_tokens)
	_check(d_nva.exposure_tokens == 3, "(g) NVA tokens %d != 3" % d_nva.exposure_tokens)
	_check(d_vc.exposure_tokens == 2, "(g) VC tokens %d != 2" % d_vc.exposure_tokens)
	_check(d_press.exposure_tokens >= 999,
		"(g) assault_press tokens %d - the siege must never be strangled" % d_press.exposure_tokens)
	_check(d_press.bound_period_ms == 0,
		"(g) assault_press must not element-gate (the siege rotates its own press)")

	# --- squad of six VC: elements 0/1 alternate by registration order --------
	var t: float = 100000.0
	var men: Array[Node] = []
	for i in range(6):
		men.append(_man())
	for m in men:
		SC.register(SC.SIDE_ENEMY, 7, m, false, true, "vc", t)
	SC.report_fight(SC.SIDE_ENEMY, 7, Vector3(10, 0, 10), t)

	# --- (a)+(b) cap, stagger, element gate -----------------------------------
	# Active element starts 0 = men[0], men[2], men[4]. VC cap is 2.
	_check(not SC.request_exposure(SC.SIDE_ENEMY, 7, men[1], false, t),
		"(b) passive-element man drew a token while the fight was bounding")
	_check(SC.request_exposure(SC.SIDE_ENEMY, 7, men[0], false, t),
		"(a) first active-element grant refused")
	_check(not SC.request_exposure(SC.SIDE_ENEMY, 7, men[2], false, t),
		"(a) second grant ignored the stagger gap")
	t += 600.0
	_check(SC.request_exposure(SC.SIDE_ENEMY, 7, men[2], false, t),
		"(a) staggered second grant refused")
	t += 600.0
	_check(not SC.request_exposure(SC.SIDE_ENEMY, 7, men[4], false, t),
		"(a) grant #3 exceeded the VC cap of 2")
	_check(SC.request_exposure(SC.SIDE_ENEMY, 7, men[0], false, t),
		"(a) a held token failed to renew")

	# --- (d) one suppressor, prefers the covered MG, never a token holder -----
	SC.register(SC.SIDE_ENEMY, 7, men[5], true, true, "vc", t)  # the MG, passive elem
	var supp: int = 0
	for m in men:
		if SC.is_suppressor(SC.SIDE_ENEMY, 7, m, t):
			supp += 1
	_check(supp == 1, "(d) %d suppressors elected - the slot is ONE" % supp)
	_check(SC.is_suppressor(SC.SIDE_ENEMY, 7, men[5], t),
		"(d) the covered MG was not elected suppressor")
	_check(SC.is_suppressor(SC.SIDE_ENEMY, 7, men[5], t + 100.0),
		"(d) the slot answer flapped inside one refresh window")
	_check(SC.suppress_point(SC.SIDE_ENEMY, 7, t) == Vector3(10, 0, 10),
		"(d) suppress point lost the reported fight position")

	# --- (b) elements alternate on the bound period ---------------------------
	# Keep the fight fresh, walk past the bound period: the passive element opens.
	t += float(d_vc.bound_period_ms) + 100.0
	SC.report_fight(SC.SIDE_ENEMY, 7, Vector3(10, 0, 10), t)
	SC.release_exposure(SC.SIDE_ENEMY, 7, men[0])
	SC.release_exposure(SC.SIDE_ENEMY, 7, men[2])
	_check(SC.request_exposure(SC.SIDE_ENEMY, 7, men[1], false, t),
		"(b) element flip never opened the passive element")
	_check(not SC.request_exposure(SC.SIDE_ENEMY, 7, men[0], false, t),
		"(b) old active element kept drawing after the flip")

	# --- (c) TTL expiry frees slots -------------------------------------------
	t += float(d_vc.token_ttl_ms) + float(d_vc.bound_period_ms) + 200.0
	SC.report_fight(SC.SIDE_ENEMY, 7, Vector3(10, 0, 10), t)
	for m in men:
		SC.register(SC.SIDE_ENEMY, 7, m, false, true, "vc", t)
	var granted: int = 0
	for m in men:
		if SC.request_exposure(SC.SIDE_ENEMY, 7, m, false, t):
			granted += 1
		t += 600.0
		SC.report_fight(SC.SIDE_ENEMY, 7, Vector3(10, 0, 10), t)
	_check(granted == 2, "(c) after TTL expiry expected exactly 2 grants, got %d" % granted)

	# --- (e) census is per-squad and excludes the firer -----------------------
	var a: Node = _man()
	var b: Node = _man()
	SC.register(SC.SIDE_ALLY, 0, a, false, false, "us", t)
	SC.register(SC.SIDE_ALLY, 0, b, false, false, "us", t)
	SC.report_firing(SC.SIDE_ALLY, 0, a, t)
	_check(SC.has_covering_fire(SC.SIDE_ALLY, 0, b, t),
		"(e) a squadmate's fire did not read as covering")
	_check(not SC.has_covering_fire(SC.SIDE_ALLY, 0, a, t),
		"(e) a man's own fire counted as his covering fire")
	_check(not SC.has_covering_fire(SC.SIDE_ALLY, 1, b, t),
		"(e) fire in squad 0 leaked into squad 1's census")
	_check(not SC.has_covering_fire(SC.SIDE_ENEMY, 0, b, t),
		"(e) an ALLY volley covered an ENEMY squad")

	# --- (f) the press bypasses the line cap by DATA --------------------------
	var pressed: int = 0
	for i in range(8):
		var pm: Node = _man()
		SC.register(SC.SIDE_ENEMY, 9, pm, false, false, "nva", t)
		if SC.request_exposure(SC.SIDE_ENEMY, 9, pm, true, t):
			pressed += 1
	_check(pressed == 8, "(f) the press was strangled: %d of 8 granted" % pressed)

	# --- (h) fossil tripwire --------------------------------------------------
	var hits: Array[String] = []
	_scan_dir("res://scripts", hits)
	for h in hits:
		_fail("(h) %s" % h)

	for n in _men:
		n.free()
	if failures == 0:
		print("PASS: squad coordinator OK (tokens, elements, slot, census, doctrine)")
	else:
		print("FAIL: squad coordinator suite had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _scan_dir(path: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_fail("(h) cannot open %s for the fossil sweep" % path)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full, hits)
		elif entry.ends_with(".gd"):
			var text: String = FileAccess.get_file_as_string(full)
			for sym: String in DEAD_SYMBOLS:
				if text.contains(sym):
					hits.append("%s contains '%s'" % [full, sym])
		entry = dir.get_next()
	dir.list_dir_end()
