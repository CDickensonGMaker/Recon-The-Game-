## test_ally_states.gd - proves the ally half of the 7/23 posture merge (Part B
## seam) on a REAL AllyBase, not just the tables: COMBAT -> ADVANCING
## stand-and-push, the heavy-pin SUPPRESSED freeze on the SHARED gate
## (CombatPosture.SUPPRESS_PIN - the same constant the enemy state machine
## reads), recovery back to COMBAT past the goal dwell, the _execute default arm
## (no unhandled-state statue), and the per-rush RUSH_CLIPS pick.
## Run: godot --headless --path . res://tests/test_ally_states.tscn
extends Node3D

const AllyScript := preload("res://scripts/allies/ally_base.gd")
const EnemyScript := preload("res://scripts/enemies/enemy_base.gd")

var _fails: int = 0


func _check(got: bool, label: String) -> void:
	if got:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("  FAIL %s" % label)


func _ready() -> void:
	print("=== Ally States Probe (ADVANCING / SUPPRESSED / default arm) ===")
	await get_tree().process_frame
	await get_tree().process_frame

	var a: AllyBase = AllyScript.new()
	add_child(a)
	var e: EnemyBase = EnemyScript.new()
	add_child(e)
	await get_tree().process_frame
	await get_tree().process_frame
	# The probe drives think/execute by hand - the engine loop must not race it.
	a.set_physics_process(false)
	e.set_physics_process(false)

	a.global_position = Vector3.ZERO
	a.courage = 0.9   # go-getter: skips the cover-first trip, advance_band 0.9
	a.squad_broken = false
	a.weapons_free = true
	a._aim_settle = 1.0e9  # the probe never actually fires
	a.can_fire = false
	a.fire_timer = 1.0e9

	_part_advancing(a, e)
	_part_suppressed(a, e)
	_part_recovery(a, e)
	_part_default_arm(a, e)
	_part_enemy_shared_gate()
	_part_rush_clips(a)

	a.queue_free()
	e.queue_free()
	print("\n%s: %d failure(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## Contact far outside preferred range -> ADVANCING: posture STAND, speed uncapped.
func _part_advancing(a: AllyBase, e: EnemyBase) -> void:
	print("\n[1] COMBAT -> ADVANCING (stand-and-push)")
	e.global_position = Vector3(30, 0, 0)
	a.target = e
	a.has_line_of_sight = true
	a.contact_conf = 1.0
	a.target_last_seen_time = 0.0
	a.suppression_level = 0.0
	a.goal_timer = 99.0
	# HE NEEDS SUPPORT TO CROSS OPEN GROUND. The posture merge put the ADVANCE score behind
	# OPEN-GROUND DISCIPLINE (combat_goals.gd:120-121): "crossing needs covering fire or real
	# aggression; a lone unsupported man holds and shoots", and its header records that an
	# unpressed advance tops out at 0.61 and therefore loses to an incumbent ENGAGE - "which is
	# why a night assault has always stalled". This probe staged a lone, unsupported, unpressed
	# man and demanded he push, which is exactly the behaviour that discipline removed.
	# Give him the covering fire the scorer names as the legitimate route, so the probe tests
	# the ladder the game actually has.
	a.has_covering_fire = true
	a._evaluate_goals()
	_check(a.current_state == Enums.AIState.ADVANCING, "goal ladder enters ADVANCING")
	_check(a.current_goal == Enums.AIGoal.ADVANCE, "goal is ADVANCE")
	_check(not a._is_low_posture(false), "advancing posture is STAND")
	for _i in range(60):
		a._execute(1.0 / 30.0)
	var spd: float = Vector2(a.velocity.x, a.velocity.z).length()
	_check(a.current_state == Enums.AIState.ADVANCING, "still advancing with the gap open")
	_check(not a._low_posture, "_low_posture stays false on the push")
	_check(spd > AllyBase.CROUCH_SPEED_CAP, "closes above the crouch cap (%.2f m/s)" % spd)
	# Arrival: target inside the exit band drops him back to COMBAT.
	e.global_position = a.global_position + Vector3(6, 0, 0)
	a._execute(1.0 / 30.0)
	_check(a.current_state == Enums.AIState.COMBAT, "arrival drops back to COMBAT")


## Suppression spike above the SHARED pin gate -> SUPPRESSED: crouch, hold fast.
func _part_suppressed(a: AllyBase, e: EnemyBase) -> void:
	print("\n[2] heavy pin -> SUPPRESSED (freeze)")
	e.global_position = a.global_position + Vector3(25, 0, 0)
	a.suppression_level = CombatPosture.SUPPRESS_PIN + 0.15
	a.goal_timer = 0.0  # the pin check must run OUTSIDE the goal dwell
	a._evaluate_goals()
	_check(a.current_state == Enums.AIState.SUPPRESSED, "pin enters SUPPRESSED past the dwell")
	_check(a.current_goal == Enums.AIGoal.ENGAGE_TARGET, "pinned goal stays ENGAGE_TARGET")
	_check(a._is_low_posture(false), "pinned posture is CROUCH")
	a.velocity = Vector3(3.0, 0.0, 3.0)
	for _i in range(40):
		a._execute(1.0 / 30.0)
	var spd: float = Vector2(a.velocity.x, a.velocity.z).length()
	_check(a.current_state == Enums.AIState.SUPPRESSED, "holds SUPPRESSED while pinned")
	_check(spd < 0.5, "holds position under the pin (%.2f m/s)" % spd)


## Decay below the gate -> immediate re-plan (dwell bypass), back to the fight.
func _part_recovery(a: AllyBase, e: EnemyBase) -> void:
	print("\n[3] pin decays -> back to COMBAT")
	e.global_position = a.global_position + Vector3(8, 0, 0)
	a.suppression_level = 0.2
	a.goal_timer = 0.0  # dwell would hold the old goal - the pin exit must bypass it
	a._evaluate_goals()
	_check(a.current_state == Enums.AIState.COMBAT, "recovery re-plans to COMBAT immediately")


## An unhandled state must never produce a statue.
func _part_default_arm(a: AllyBase, e: EnemyBase) -> void:
	print("\n[4] _execute default arm (no statue)")
	a.target = null
	a.current_state = Enums.AIState.FLANKING
	a._execute(1.0 / 30.0)
	_check(a.current_state == Enums.AIState.IDLE, "FLANKING w/o target routes to IDLE")
	e.current_state = Enums.AIState.DEAD  # a dead target must also unstick the arm
	a.target = e
	a.current_state = Enums.AIState.ALERT
	a._execute(1.0 / 30.0)
	_check(a.current_state == Enums.AIState.IDLE, "ALERT w/ dead target routes to IDLE")
	e.current_state = Enums.AIState.IDLE


## Both factions read ONE pin constant (fossil law: mirrored, never forked).
func _part_enemy_shared_gate() -> void:
	print("\n[5] enemy reads the same CombatPosture.SUPPRESS_PIN")
	var e2: EnemyBase = EnemyScript.new()
	add_child(e2)
	e2.set_physics_process(false)
	e2.current_goal = Enums.AIGoal.ENGAGE_TARGET
	e2.suppression_level = CombatPosture.SUPPRESS_PIN + 0.05
	e2._update_state_for_goal()
	_check(e2.current_state == Enums.AIState.SUPPRESSED, "enemy pins above the shared gate")
	e2.suppression_level = CombatPosture.SUPPRESS_PIN - 0.05
	e2._update_state_for_goal()
	_check(e2.current_state == Enums.AIState.COMBAT, "enemy releases below the shared gate")
	e2.queue_free()


## The rush pick draws from the WHOLE authored set, not just element [0].
func _part_rush_clips(a: AllyBase) -> void:
	print("\n[6] RUSH_CLIPS per-rush pick")
	var seen: Dictionary = {}
	var all_valid: bool = true
	for _i in range(24):
		var c: String = a._pick_rush_clip()
		if not AllyBase.RUSH_CLIPS.has(c):
			all_valid = false
		seen[c] = true
	_check(all_valid, "every pick is an authored RUSH_CLIP")
	_check(seen.size() >= 2, "24 rushes draw >= 2 distinct clips (got %d)" % seen.size())
