## test_ai_fairness.gd - locks in the HLL doctrine pass (2026-07-10).
## Guards: the exposure-ramp fairness law (DESIGN 4.2, formerly dead code),
## honest attention (no intrinsic player bias), cover-first engagement, and
## the anti-spam grenade broker.
## Run: godot --headless --path . res://tests/test_ai_fairness.tscn -- --test-save
extends Node3D

var _fail: int = 0


## The exposure fraction enemy_base feeds AIMarksmanship: seconds of exposure over
## this shooter's ramp, clamped. Mirrors _fire_at_target()'s own expression.
func _exposure_t(e: Node, visible_seconds: float) -> float:
	return clampf(visible_seconds / maxf(e.d_exposure_ramp, 0.1), 0.0, 1.0)


func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_fail += 1


func _ready() -> void:
	await get_tree().process_frame
	var nva := EnemyBase.spawn_enemy(self, Vector3(0, 1, 0), "res://data/enemies/nva_regular.tres")
	var farmer := EnemyBase.spawn_enemy(self, Vector3(5, 1, 0), "res://data/enemies/vc_farmer.tres")
	await get_tree().process_frame
	if nva == null or farmer == null:
		_bad("spawn failed")
		get_tree().quit(1)
		return

	# --- exposure ramp (DESIGN 4.2: accuracy ramps with exposure) -----------
	# PLUMBING IS THE CONTRACT, NOT THE TUNING. This asserted 2.2 and 3.5 - values these two
	# archetypes were retuned off (nva_regular is 1.6, vc_farmer 2.6) - so a probe named
	# "data not plumbed" failed while the data was plumbed perfectly, and would fail again on
	# every balance pass. Read the expected value off the RESOURCE: that catches the thing the
	# check exists for (a value that never reached the man, which reads as the 2.5 default)
	# without freezing a number the designer must be free to move.
	var nva_data: EnemyData = load("res://data/enemies/nva_regular.tres")
	var farmer_data: EnemyData = load("res://data/enemies/vc_farmer.tres")
	if absf(nva.d_exposure_ramp - nva_data.exposure_ramp_time) > 0.01:
		_bad("nva exposure_ramp %.2f != its data's %.2f (not plumbed)" % [
			nva.d_exposure_ramp, nva_data.exposure_ramp_time])
	if absf(farmer.d_exposure_ramp - farmer_data.exposure_ramp_time) > 0.01:
		_bad("farmer exposure_ramp %.2f != its data's %.2f (not plumbed)" % [
			farmer.d_exposure_ramp, farmer_data.exposure_ramp_time])
	# The ordering is the DESIGN claim and survives any retune: a trained soldier converges
	# faster than a farmer with a rifle.
	if nva.d_exposure_ramp >= farmer.d_exposure_ramp:
		_bad("NVA must lock on faster than a farmer (%.2f vs %.2f)" % [
			nva.d_exposure_ramp, farmer.d_exposure_ramp])
	var m0: float = AIMarksmanship.exposure_spread_mult(_exposure_t(nva, 0.0))
	var m_half: float = AIMarksmanship.exposure_spread_mult(_exposure_t(nva, nva.d_exposure_ramp * 0.5))
	var m1: float = AIMarksmanship.exposure_spread_mult(_exposure_t(nva, nva.d_exposure_ramp))
	if absf(m0 - (1.0 + AIMarksmanship.EXPOSURE_PEAK)) > 0.01:
		_bad("fresh exposure mult %.2f != %.2f" % [m0, 1.0 + AIMarksmanship.EXPOSURE_PEAK])
	if absf(m1 - 1.0) > 0.01:
		_bad("full-ramp mult %.2f != 1.0" % m1)
	if not (m0 > m_half and m_half > m1):
		_bad("exposure mult not monotone (%.2f, %.2f, %.2f)" % [m0, m_half, m1])
	print("  exposure ramp: x%.1f fresh -> x%.2f half -> x%.1f converged" % [m0, m_half, m1])

	# --- honest attention: no player bias -----------------------------------
	var mock_player := Node3D.new()
	mock_player.add_to_group("player")
	add_child(mock_player)
	mock_player.global_position = Vector3(10, 1, 0)
	var mock_ally := Node3D.new()
	mock_ally.add_to_group("allies")
	add_child(mock_ally)
	mock_ally.global_position = Vector3(-10, 1, 0)
	var now_ms: float = float(Time.get_ticks_msec())
	var sp: float = nva._target_score(mock_player, 10.0, now_ms)
	var sa: float = nva._target_score(mock_ally, 10.0, now_ms)
	if absf(sp - sa) > 0.001:
		_bad("player bias detected: player %.3f vs ally %.3f at equal distance" % [sp, sa])
	nva._last_attacker = mock_ally
	nva._last_attacker_ms = now_ms
	var sa2: float = nva._target_score(mock_ally, 10.0, now_ms)
	if sa2 < sp * 2.0:
		_bad("last-attacker weighting too weak: %.3f vs %.3f" % [sa2, sp])
	print("  attention: equal-dist scores %.3f == %.3f; attacker x%.1f" % [sp, sa, sa2 / maxf(sp, 0.001)])
	nva._last_attacker = null

	# --- cover-first engagement ---------------------------------------------
	farmer.target = mock_player
	mock_player.global_position = farmer.global_position + Vector3(farmer.preferred_range, 0, 0)
	farmer.has_line_of_sight = true
	farmer.contact_conf = 1.0  # goals read the debounced confidence (decree)
	farmer.threat_level = 0.1
	farmer.suppression_level = 0.0
	farmer.char_aggression = 0.4
	farmer.char_self_preservation = 0.5
	farmer.has_cover = false
	farmer._contact_time = 0.0
	farmer._cover_fail_count = 0
	farmer.goal_timer = 1.0
	farmer.current_goal = Enums.AIGoal.NONE
	farmer._evaluate_goals()
	if farmer.current_goal != Enums.AIGoal.SEEK_COVER:
		_bad("fresh contact in the open should SEEK_COVER, got %d" % farmer.current_goal)
	farmer.has_cover = true
	farmer.current_cover = farmer.global_position
	farmer.goal_timer = 1.0
	farmer.current_goal = Enums.AIGoal.NONE
	farmer._evaluate_goals()
	if farmer.current_goal != Enums.AIGoal.ENGAGE_TARGET:
		_bad("covered + LOS should ENGAGE, got %d" % farmer.current_goal)
	farmer.has_cover = false
	farmer.char_aggression = 0.85
	farmer.goal_timer = 1.0
	farmer.current_goal = Enums.AIGoal.NONE
	farmer._evaluate_goals()
	if farmer.current_goal == Enums.AIGoal.SEEK_COVER:
		_bad("aggression 0.85 must be doctrine-exempt (sappers push)")
	print("  cover-first: open->cover, covered->engage, fearless->push OK")

	# --- grenade broker -------------------------------------------------------
	EnemySquad.clear()
	var t0: float = 100000.0
	if not EnemySquad.grenade_ready(1, t0):
		_bad("broker should be ready initially")
	EnemySquad.claim_grenade(1, t0)
	if EnemySquad.grenade_ready(1, t0 + 1000.0):
		_bad("squad cooldown not enforced")
	if EnemySquad.grenade_ready(2, t0 + 1000.0):
		_bad("GLOBAL spacing not enforced across squads")
	if not EnemySquad.grenade_ready(2, t0 + 6000.0):
		_bad("other squad should be ready after global spacing")
	if EnemySquad.grenade_ready(1, t0 + 6000.0):
		_bad("same squad must wait the full 12s")
	if not EnemySquad.grenade_ready(1, t0 + 13000.0):
		_bad("squad should be ready after 12s")
	print("  grenade broker: global 5s + squad 12s enforced")
	EnemySquad.clear()

	if _fail == 0:
		print("PASS: AI fairness doctrine (exposure ramp, honest attention, cover-first, grenade broker) OK")
	else:
		print("FAIL: AI fairness suite had %d failure(s)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
