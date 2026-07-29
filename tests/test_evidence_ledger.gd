## test_evidence_ledger.gd - the hunters' honesty probe.
##
## The one property that must never regress: hunters converge on what the player LEFT,
## never on where he IS. This asserts the ledger only ever holds player-team evidence,
## that fixes decay, and that a clean patrol produces no lead at all - which is the
## mechanical form of ADR-006's "avoidance pays".
##
## Run: godot --headless --path . res://tests/test_evidence_ledger.tscn
extends Node

const LedgerClass := preload("res://scripts/enemies/evidence_ledger.gd")

var _failures: int = 0


func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ok(msg: String) -> void:
	print("  ok: %s" % msg)


func _ready() -> void:
	print("=== Evidence Ledger Probe ===")
	_test_quiet_patrol_has_no_lead()
	_test_enemy_noise_is_not_evidence()
	_test_noise_decays()
	_test_bodies_outlast_noise()
	_test_nearby_fixes_merge()
	_test_scatter_keeps_fix_off_the_exact_spot()
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## The whole stealth economy rests on this: walk quietly, nobody is sent.
func _test_quiet_patrol_has_no_lead() -> void:
	var led: EvidenceLedger = LedgerClass.new(1)
	if not led.best_fix(0.0).is_empty():
		_bad("a ledger with no evidence produced a lead")
	elif led.total_strength(0.0) != 0.0:
		_bad("empty ledger reported non-zero strength")
	else:
		_ok("quiet patrol yields no lead")


## Team 1 is the enemy. Their own gunfire must never become a lead on the player,
## or a firefight would feed the hunters that came to it.
func _test_enemy_noise_is_not_evidence() -> void:
	var led: EvidenceLedger = LedgerClass.new(2)
	led.on_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(100, 0, 100), 1, 0.0)
	if not led.fixes.is_empty():
		_bad("enemy-team gunfire was recorded as evidence against the player")
	else:
		_ok("enemy noise is not evidence")


func _test_noise_decays() -> void:
	var led: EvidenceLedger = LedgerClass.new(3)
	led.on_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(200, 0, 200), 0, 0.0)
	var fresh: float = led.total_strength(0.0)
	var stale: float = led.total_strength(LedgerClass.DECAY_NOISE_S * 0.5)
	led.prune(LedgerClass.DECAY_NOISE_S + 1.0)
	if fresh <= 0.0:
		_bad("a fresh gunshot carried no weight")
	elif stale >= fresh:
		_bad("a half-life-old fix was not weaker than a fresh one (%.2f vs %.2f)" % [stale, fresh])
	elif not led.fixes.is_empty():
		_bad("an expired fix survived prune()")
	else:
		_ok("noise decays and expires")


## A sound is gone when it stops; a body is still there tomorrow.
func _test_bodies_outlast_noise() -> void:
	var led: EvidenceLedger = LedgerClass.new(4)
	led.on_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(100, 0, 100), 0, 0.0)
	led.on_body_left(Vector3(600, 0, 600), 0.0)
	led.prune(LedgerClass.DECAY_NOISE_S + 1.0)
	if led.fixes.size() != 1:
		_bad("expected only the body to survive, got %d fixes" % led.fixes.size())
	elif (led.fixes[0].pos as Vector3).distance_to(Vector3(600, 0, 600)) > LedgerClass.SCATTER_PHYSICAL_M:
		_bad("the surviving fix was not the body")
	else:
		_ok("bodies outlast noise")


## One long firefight must read as one strong lead, not two hundred weak ones.
func _test_nearby_fixes_merge() -> void:
	var led: EvidenceLedger = LedgerClass.new(5)
	for i in range(20):
		led.record(Vector3(400, 0, 400), LedgerClass.WEIGHT_GUNSHOT,
			LedgerClass.DECAY_NOISE_S, 0.0, 0.0)
	if led.fixes.size() != 1:
		_bad("20 shots in one place produced %d fixes, expected 1" % led.fixes.size())
	else:
		_ok("co-located fixes merge")


## The fix is where something HAPPENED, blurred - never a pin on the player.
func _test_scatter_keeps_fix_off_the_exact_spot() -> void:
	var exact := Vector3(500, 0, 500)
	var offsets: int = 0
	for s in range(12):
		var led: EvidenceLedger = LedgerClass.new(s)
		led.on_noise(NoiseBus.NoiseType.GUNSHOT, exact, 0, 0.0)
		if (led.fixes[0].pos as Vector3).distance_to(exact) > 1.0:
			offsets += 1
	if offsets < 10:
		_bad("gunshot fixes landed on the exact spot %d/12 times - hunters would be pin-accurate" % (12 - offsets))
	else:
		_ok("noise fixes carry real positional error")
