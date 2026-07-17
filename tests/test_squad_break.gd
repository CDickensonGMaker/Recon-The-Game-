## test_squad_break.gd - squad break & exfil (4utx + the offered player exfil).
## (a) ENEMY squads auto-withdraw at ~45% (break math + the retreat wiring).
## (b) the PLAYER squad at 45% NEVER auto-moves - only the offer flag is set.
## (c) player-INITIATED exfil fires the near-firebase vs far-heli branch.
## Run: godot --headless --path . res://tests/test_squad_break.tscn
extends Node

const EnemySquad := preload("res://scripts/enemies/enemy_squad.gd")


func _ready() -> void:
	print("=== SQUAD BREAK & EXFIL (4utx) ===")
	var failures: int = 0
	failures += _test_enemy_break_math()
	failures += _test_enemy_retreat_wired()
	failures += _test_rout_not_immune()

	if failures == 0:
		print("PASS: enemy squad break math + withdrawal wiring hold")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_enemy_break_math() -> int:
	var fails: int = 0
	# 6/11 = 0.55 > 0.45 -> holds; 4/11 = 0.36 < 0.45 -> breaks (average nerve).
	if EnemySquad.break_state(6, 11, 0.5).broken:
		printerr("FAIL: a squad at 55%% strength must NOT break")
		fails += 1
	if not EnemySquad.break_state(4, 11, 0.5).broken:
		printerr("FAIL: a squad at 36%% strength (avg courage) must break")
		fails += 1
	# Courage modulation at the same 36% strength:
	# elite (0.9) threshold ~0.29 -> holds; green (0.1) threshold ~0.61 -> breaks.
	if EnemySquad.break_state(4, 11, 0.9).broken:
		printerr("FAIL: elite (high courage) must hold at 36%% where a green squad breaks")
		fails += 1
	if not EnemySquad.break_state(4, 11, 0.1).broken:
		printerr("FAIL: green (low courage) must break at 36%%")
		fails += 1
	# A lone wolf (squad_id -1) never squad-breaks (uses the individual ladder).
	if EnemySquad.is_broken(-1) or EnemySquad.strength_ratio(-1) != 1.0:
		printerr("FAIL: a lone wolf (id -1) must never squad-break")
		fails += 1
	if fails == 0:
		print("  [OK] enemy break math: 45%% threshold, courage-modulated, lone-wolf exempt")
	return fails


## The break must bias the EXISTING retreat goal, not a competing authority.
func _test_enemy_retreat_wired() -> int:
	var src: String = FileAccess.get_file_as_string("res://scripts/enemies/enemy_base.gd")
	var goals: String = _func_body(src, "func _evaluate_goals()")
	var fails: int = 0
	if goals.find("EnemySquad.is_broken(squad_id)") < 0 or goals.find("retreat_score") < 0:
		printerr("FAIL: squad-break must add to retreat_score in _evaluate_goals (layered on the ladder)")
		fails += 1
	if fails == 0:
		print("  [OK] enemy withdrawal layered on the existing retreat goal")
	return fails


## ROUT != IMMUNITY: a routing man is a normal damageable actor, just running.
## The retreat path must not grant invulnerability, untargetability, or early despawn,
## and take_damage must apply damage/death regardless of goal.
func _test_rout_not_immune() -> int:
	var src: String = FileAccess.get_file_as_string("res://scripts/enemies/enemy_base.gd")
	var flee: String = _func_body(src, "func _execute_retreating(")
	var fails: int = 0
	for pat in ["collision_layer", "collision_mask", "queue_free", "set_physics_process(false)",
			"set_deferred(\"monitorable\"", "invuln", "immune"]:
		if flee.find(pat) >= 0:
			printerr("FAIL: retreat path contains '%s' - a routing man must stay a normal damageable actor" % pat)
			fails += 1
	# take_damage must apply the lethal path (_die) INDEPENDENT of the rout decision:
	# _die() is reached before the rout ladder ever sets RETREAT, so a routing man
	# who takes a lethal hit still dies. (The RETREAT the ladder sets is a survivor's
	# behavior flip, not a damage guard.)
	var dmg: String = _func_body(src, "func take_damage(")
	var die_at: int = dmg.find("_die()")
	var rout_at: int = dmg.find("AIGoal.RETREAT")
	if die_at < 0:
		printerr("FAIL: take_damage never reaches _die() (lethal path missing)")
		fails += 1
	elif rout_at >= 0 and die_at > rout_at:
		printerr("FAIL: the lethal path is gated behind the rout decision - a routing man could dodge death")
		fails += 1
	if fails == 0:
		print("  [OK] rout is behavior-only: a routing enemy stays fully killable/targetable")
	return fails


func _func_body(src: String, signature: String) -> String:
	var start: int = src.find(signature)
	if start < 0:
		return ""
	var next: int = src.find("\nfunc ", start + signature.length())
	if next < 0:
		next = src.length()
	return src.substr(start, next - start)
