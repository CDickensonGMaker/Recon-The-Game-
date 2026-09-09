## test_demo_arc.gd - THE SHIPPING ARC'S TIMINGS DO NOT MOVE.
##
## `--stress=<target>` exists so the heavy frames can be reached in ~2 minutes instead of
## ~24. The whole value of that flag rests on it being invisible when absent: if a dev route
## can shift the demo's own clock, the thing he playtests is not the thing that ships.
##
## `DemoGame.resolve_stress` is deliberately PURE and static so this can be gated without
## booting a 512 m world - a test that has to build the demo to check a number is a test
## nobody runs.
extends Node

var _fails: PackedStringArray = []
var _checks: int = 0


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)


func _ready() -> void:
	# 1. NO FLAG = THE SHIPPING ARC. This is the check the flag exists to not break.
	var none: Dictionary = DemoGame.resolve_stress(false, "")
	_ok(int(none["target"]) == DemoGame.Stress.NONE, "absent --stress did not resolve to NONE")
	_ok(float(none["probe_at"]) == DemoGame.PROBE_AT_S,
		"absent --stress moved probe_at to %s" % str(none["probe_at"]))
	_ok(float(none["siege_at"]) == DemoGame.SIEGE_AT_S,
		"absent --stress moved siege_at to %s" % str(none["siege_at"]))

	# 2. The arc constants themselves. A dev flag is not the only way to move a demo; an
	# edit is. These are the numbers the playtest gate is written against
	# (CLAUDE.md, THE SESSION ENTRY GATE) and they are law until he re-decrees them.
	_ok(DemoGame.PROBE_AT_S == 1395.0, "PROBE_AT_S moved from 1395")
	_ok(DemoGame.SIEGE_AT_S == 1440.0, "SIEGE_AT_S moved from 1440")
	_ok(DemoGame.SIEGE_STRENGTH == 45, "SIEGE_STRENGTH moved from 45 - the assault is not the assault")
	_ok(DemoGame.PROBE_STRENGTH == 11, "PROBE_STRENGTH moved from 11")
	_ok(DemoGame.START_HOUR == 6.5, "START_HOUR moved from 06:30")
	_ok(DemoGame.DAY_RATIO == 38.0, "DAY_RATIO moved from 38x")
	_ok(DemoGame.NIGHT_RATIO == 20.0, "NIGHT_RATIO moved from 20x")
	_ok(DemoGame.DEMO_SEED == 29072026, "DEMO_SEED moved - two stress runs are no longer comparable")

	# 3. Bare `--stress` still means assault, so no existing bench invocation changed meaning.
	for v: String in ["", "assault", "ASSAULT", " assault "]:
		var a: Dictionary = DemoGame.resolve_stress(true, v)
		_ok(int(a["target"]) == DemoGame.Stress.ASSAULT, "--stress=%s is not the assault target" % v)
		_ok(float(a["siege_at"]) == 45.0, "--stress=%s does not open the siege at 45s" % v)

	# 4. reinforce is DELIBERATELY the assault: the 11 -> 45 escalation is the demo's only
	# reinforcement arrival. Aliased out loud rather than invented as a fourth event.
	_ok(int(DemoGame.resolve_stress(true, "reinforce")["target"]) == DemoGame.Stress.ASSAULT,
		"--stress=reinforce should alias the assault, not invent a second reinforcement path")

	# 5. The single-event targets must never open the siege - the whole point is one event
	# in the frame with nothing else in it.
	for v: String in ["napalm", "trees"]:
		var e: Dictionary = DemoGame.resolve_stress(true, v)
		_ok(float(e["siege_at"]) == INF, "--stress=%s would still open the siege" % v)
		_ok(float(e["probe_at"]) == INF, "--stress=%s would still run the probe" % v)
	_ok(int(DemoGame.resolve_stress(true, "napalm")["target"]) == DemoGame.Stress.NAPALM, "napalm target")
	_ok(int(DemoGame.resolve_stress(true, "trees")["target"]) == DemoGame.Stress.TREES, "trees target")

	# 6. NOT TESTED HERE, deliberately. An unknown target falls back to assault and
	# push_errors so it cannot become a silent different measurement - but push_error writes
	# a line the suite scans for, so a test that exercised that path would FAIL ITSELF for
	# proving the guard works. Same trap the runner's own header records for "[NAV]".

	if _fails.is_empty():
		print("[TEST demo_arc] PASS - %d checks" % _checks)
	else:
		for f: String in _fails:
			printerr("[TEST demo_arc] FAIL: %s" % f)
		printerr("[TEST demo_arc] FAIL - %d of %d checks failed" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)
