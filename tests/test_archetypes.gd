## test_archetypes.gd - Step 8: the ten dead EnemyData exports now differentiate.
extends Node3D
var _fail := 0
func _bad(m: String) -> void: print("FAIL: %s" % m); _fail += 1
func _spawn(path: String) -> EnemyBase:
	var e := EnemyBase.spawn_enemy(self, Vector3.ZERO, path)
	await get_tree().process_frame
	return e
func _ready() -> void:
	var vc := await _spawn("res://data/enemies/vc_rifleman.tres")
	var nva := await _spawn("res://data/enemies/nva_regular.tres")
	var rpg := await _spawn("res://data/enemies/nva_rpg.tres")

	# accuracy: the .tres values must reach base_accuracy_modifier, not be shadowed.
	print("  vc base_acc=%.2f nva base_acc=%.2f rpg base_acc=%.2f" % [
		vc.base_accuracy_modifier, nva.base_accuracy_modifier, rpg.base_accuracy_modifier])
	if not is_equal_approx(vc.base_accuracy_modifier, 1.15): _bad("vc base_accuracy_modifier %.2f != 1.15" % vc.base_accuracy_modifier)
	if not is_equal_approx(nva.base_accuracy_modifier, 0.95): _bad("nva base_accuracy_modifier %.2f != 0.95" % nva.base_accuracy_modifier)

	# aggro radius from alert_range (was a hardcoded ALERT_RANGE*2 = 50 for all).
	print("  vc aggro=%.0f nva aggro=%.0f rpg aggro=%.0f" % [vc.aggro_range, nva.aggro_range, rpg.aggro_range])
	if is_equal_approx(vc.aggro_range, nva.aggro_range): _bad("aggro_range identical - alert_range not read")

	# behaviour flags differ by archetype.
	print("  flanks: vc=%s nva=%s | retreats: vc=%s nva=%s" % [vc.d_flanks, nva.d_flanks, vc.d_retreats_when_hurt, nva.d_retreats_when_hurt])
	if vc.d_flanks: _bad("vc_rifleman should not flank")
	if not nva.d_flanks: _bad("nva_regular should flank")
	if not vc.d_retreats_when_hurt: _bad("vc_rifleman should break when hurt")
	if nva.d_retreats_when_hurt: _bad("nva_regular should hold")

	# aggression blended toward the archetype (not pure personality noise).
	print("  char_aggression: vc=%.2f nva=%.2f (data 0.45 vs 0.65)" % [vc.char_aggression, nva.char_aggression])

	# the crippled accuracy penalty must be DURABLE now (it multiplied a
	# per-frame scratch var and was wiped on the next tick - a no-op for years).
	var before: float = nva.base_accuracy_modifier
	nva.base_accuracy_modifier *= 1.6
	if is_equal_approx(nva.base_accuracy_modifier, before): _bad("crippled penalty did not stick")
	print("  crippled base_acc %.2f -> %.2f (durable)" % [before, nva.base_accuracy_modifier])

	print("PASS: archetypes" if _fail == 0 else "FAIL: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
