## test_squad_break.gd - squad break at ~45% strength (4utx). Same rule both sides
## (Summoner, 2026-07-20).
## (a) ENEMY squads auto-withdraw (break math + the retreat wiring).
## (b) the PLAYER squad breaks on the SAME authority, and the flag reaches the men.
## (c) a broken man's goals change at the boundary (cover-first, no closing).
##
## THIS PROBE CANNOT VERIFY FEEL. It certifies that the threshold fires, that both
## sides compute it from one function, and that behavior differs across the
## boundary. Whether a mauled squad READS right is the Summoner's eyes.
## Run: godot --headless --path . res://tests/test_squad_break.tscn
extends Node

const EnemySquad := preload("res://scripts/enemies/enemy_squad.gd")


func _ready() -> void:
	print("=== SQUAD BREAK (4utx) ===")
	var failures: int = 0
	failures += _test_enemy_break_math()
	failures += _test_enemy_retreat_wired()
	failures += _test_rout_not_immune()
	failures += _test_one_break_authority()
	failures += _test_player_squad_breaks()
	failures += _test_broken_man_goals()

	if failures == 0:
		print("PASS: squad break holds on both sides")
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
	# `retreat_score` was a LOCAL in _evaluate_goals until the posture merge (8074af38) moved
	# goal scoring into the shared CombatGoals scorer. The contract did not change - the break
	# must still ride the existing ladder rather than steer the man directly - so assert the
	# contract, not the vanished local: _evaluate_goals stamps the break onto the goal context,
	# and the shared scorer is what reads it.
	if goals.find("EnemySquad.is_broken(squad_id)") < 0 or goals.find("squad_broken") < 0:
		printerr("FAIL: _evaluate_goals must stamp the squad break onto the goal context")
		fails += 1
	var scorer: String = FileAccess.get_file_as_string("res://scripts/ai/combat_goals.gd")
	if scorer.find("squad_broken") < 0:
		printerr("FAIL: CombatGoals must READ squad_broken - a break nothing scores is not layered")
		fails += 1
	if fails == 0:
		print("  [OK] enemy withdrawal layered on the shared goal ladder")
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


## ONE authority. The player side must not carry its own threshold or its own
## ratio math - that duplication is the defect, not the feature.
func _test_one_break_authority() -> int:
	var src: String = FileAccess.get_file_as_string("res://scripts/squad/squad_system.gd")
	var fails: int = 0
	if src.find("EnemySquad.break_state(") < 0:
		printerr("FAIL: SquadSystem must break via EnemySquad.break_state (one authority)")
		fails += 1
	# Scanning for the bare literal "0.45" matched squad_system.gd:137's MG accuracy tuple
	# `Vector2(0.45, 0.95)` - a weapon figure with nothing to do with morale - so this probe
	# reported a second morale authority that does not exist. Match the SYMBOL, not a number
	# that any unrelated tuning value can collide with.
	if src.find("BREAK_RATIO") >= 0:
		printerr("FAIL: SquadSystem carries its own break threshold - two morale authorities")
		fails += 1
	if fails == 0:
		print("  [OK] both sides break on EnemySquad.break_state - no second authority")
	return fails


## Behavioral, at the boundary, with the 55%% case as the negative control.
func _test_player_squad_breaks() -> int:
	var fails: int = 0
	var sys := SquadSystem.new()
	var men: Array[AllyBase] = []
	for i in range(11):
		var a := AllyBase.new()
		a.courage = 0.5
		men.append(a)
		sys.members.append(a)
	sys._break_ms = -1e9
	sys._update_break()          # peak = 11, all up

	# NEGATIVE CONTROL: 6/11 = 55%% - above threshold, nothing may flip.
	for i in range(5):
		men[i].current_state = Enums.AIState.DEAD
	sys._break_ms = -1e9
	sys._update_break()
	if sys.squad_broken:
		printerr("FAIL: player squad broke at 55%% strength")
		fails += 1
	if men[10].squad_broken:
		printerr("FAIL: the broken flag reached a man while the squad was intact")
		fails += 1

	# 4/11 = 36%% - below the 0.45 threshold at average nerve.
	men[5].current_state = Enums.AIState.DEAD
	men[6].current_state = Enums.AIState.DEAD
	sys._break_ms = -1e9
	sys._update_break()
	if not sys.squad_broken:
		printerr("FAIL: player squad did NOT break at 36%% strength")
		fails += 1
	if not men[10].squad_broken:
		printerr("FAIL: the break never reached the men (flag not propagated)")
		fails += 1
	if men[0].squad_broken:
		printerr("FAIL: a dead man was flagged - peak/live scan counts corpses")
		fails += 1

	for a in men:
		a.free()
	sys.free()
	if fails == 0:
		print("  [OK] player squad: holds at 55%%, breaks at 36%%, flag reaches the living")
	return fails


## The flag must CHANGE the goals the ally ladder already has (there is no ally
## RETREAT goal, and adding one would be a second system).
func _test_broken_man_goals() -> int:
	var fails: int = 0
	var a := AllyBase.new()
	a._contact_time = 99.0        # long fight, high nerve: the go-getter who pushes
	# NEGATIVE CONTROL - unbroken, this man skips cover and closes.
	if a.wants_cover_first(0.9):
		printerr("FAIL: an unbroken go-getter took the cover trip")
		fails += 1
	if not a.may_close_distance(0.9):
		printerr("FAIL: an unbroken go-getter refused to close")
		fails += 1
	a.squad_broken = true
	if not a.wants_cover_first(0.9):
		printerr("FAIL: a broken squad's go-getter still skipped cover")
		fails += 1
	if a.may_close_distance(0.9):
		printerr("FAIL: a broken squad's man still closes the range")
		fails += 1
	# The thrash guard survives the break: two failed cover hunts stop the trip.
	a._cover_fail_count = 2
	if a.wants_cover_first(0.9):
		printerr("FAIL: break bypassed the cover fail-count guard (thrash)")
		fails += 1
	a.free()
	if fails == 0:
		print("  [OK] broken man: covers first, stops closing, still guarded from thrash")
	return fails


func _func_body(src: String, signature: String) -> String:
	var start: int = src.find(signature)
	if start < 0:
		return ""
	var next: int = src.find("\nfunc ", start + signature.length())
	if next < 0:
		next = src.length()
	return src.substr(start, next - start)
