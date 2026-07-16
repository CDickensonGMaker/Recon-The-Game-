## test_low_posture.gd - proves Track B2/B3 tactical crouch locomotion.
##
## B2: a low_posture flag swaps standing locomotion -> the walk_crouching_* set
## ONLY when a unit is cautious/pinned AND slow. A fast or firing push stays
## upright (the aggression the Summoner liked is the default). B3: cover_to_stand
## fires when a living man leaves cover, never on a corpse.
## Run: godot --headless --path . res://tests/test_low_posture.tscn
extends Node3D

const EnemyScript := preload("res://scripts/enemies/enemy_base.gd")
const AllyScript := preload("res://scripts/allies/ally_base.gd")
const ModelActorScript := preload("res://scripts/visuals/model_actor.gd")

var _fails: int = 0


func _expect(got: String, want: String, label: String) -> void:
	if got != want:
		_fails += 1
		print("  FAIL %s: got '%s' expected '%s'" % [label, got, want])
	else:
		print("  ok   %s -> %s" % [label, got])


func _expect_bool(got: bool, want: bool, label: String) -> void:
	if got != want:
		_fails += 1
		print("  FAIL %s: got %s expected %s" % [label, str(got), str(want)])
	else:
		print("  ok   %s -> %s" % [label, str(got)])


func _ready() -> void:
	print("=== Low-Posture Locomotion Probe (Track B2/B3) ===")
	await get_tree().process_frame
	await get_tree().process_frame

	_test_funnel()
	await _test_clips_exist()
	await _test_caller_guardrail()
	await _test_cover_exit()

	print("\n%s: %d failure(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## --- PART A: the funnel. Crouch appears ONLY with the flag AND at crouch speed.
func _test_funnel() -> void:
	print("\n[A] intent funnel (flag + kinematic backstop)")
	var ADV := Enums.AIState.ADVANCING
	var SUP := Enums.AIState.SUPPRESSED
	var CBT := Enums.AIState.COMBAT
	# Aggression preserved: advancing at speed, flag OFF -> upright run.
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 4.2, 0.0, false, false), "run", "advance fast, no flag")
	# Aggression preserved: flag ON but FAST (rush) -> stays upright sprint (backstop).
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 5.0, 0.0, false, true), "sprint", "advance sprint, flag on (backstop)")
	# Aggression preserved: flag OFF at crouch speed -> still upright run, NOT crouch.
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 1.8, 0.0, false, false), "run", "advance slow, no flag")
	# Low posture: cautious slow forward -> crouch-walk forward.
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 1.8, 0.0, false, true), "crouch_fwd", "advance slow, flag on")
	# Low posture: lateral -> crouch strafe.
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 1.8, 0.8, false, true), "crouch_l", "advance lateral, flag on")
	# Low posture: near-still -> crouch idle (hunker).
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 0.2, 0.0, false, true), "crouch_idle", "advance still, flag on")
	# Suppressed still -> crouch idle; suppressed moving -> crouch forward (no glide).
	_expect(SpriteStateMap.intent_for(SUP, false, false, false, 0.0, 0.0, false, true), "crouch_idle", "suppressed still")
	_expect(SpriteStateMap.intent_for(SUP, false, false, false, 1.5, 0.0, false, true), "crouch_fwd", "suppressed displacing")
	# A firing man commits: the fire pose survives even if the flag is on.
	_expect(SpriteStateMap.intent_for(CBT, false, false, true, 0.0, 0.0, false, true), "fire", "combat firing, flag on")
	# Clip resolution to the real merged clips.
	_expect(SpriteStateMap.clip_for(true, "us", "grunt", "m16", "crouch_fwd"), "walk_crouching_forward", "clip_for crouch_fwd (model)")
	_expect(SpriteStateMap.model_clip_for("crouch_idle"), "idle_crouching", "model_clip crouch_idle")
	_expect(SpriteStateMap.model_clip_for("crouch_back"), "walk_crouching_backward", "model_clip crouch_back")


## --- PART B: the crouch clips actually exist on a real merged rig and play.
func _test_clips_exist() -> void:
	print("\n[B] clips exist + play on us_grunt_v3 (merged library)")
	var ma: ModelActor = ModelActorScript.new()
	add_child(ma)
	if not ma.setup("us_grunt_v3"):
		_fails += 1
		print("  FAIL: could not set up us_grunt_v3 model (cannot verify clips)")
		ma.queue_free()
		return
	await get_tree().process_frame
	var want := [
		"walk_crouching_forward", "walk_crouching_backward",
		"walk_crouching_left", "walk_crouching_right",
		"idle_crouching", "idle_crouching_aiming", "cover_to_stand",
	]
	for c in want:
		var played: bool = ma.play(str(c), true)
		_expect_bool(played, true, "play %s" % c)
	ma.queue_free()


## --- PART C: the CALLER guardrail. low_posture keys on caution/pin only, and a
## confirmed or firing push is never low - aggression stays default.
func _test_caller_guardrail() -> void:
	print("\n[C] caller guardrail (_is_low_posture)")
	var e: EnemyBase = EnemyScript.new()
	add_child(e)
	await get_tree().process_frame
	await get_tree().process_frame

	e.current_state = Enums.AIState.ADVANCING
	e.alert_tier = EnemyBase.AlertTier.SUSPICIOUS
	_expect_bool(e._is_low_posture(false), true, "enemy cautious advance (SUSPICIOUS)")
	e.alert_tier = EnemyBase.AlertTier.COMBAT
	_expect_bool(e._is_low_posture(false), false, "enemy CONFIRMED advance (aggression kept)")
	e.alert_tier = EnemyBase.AlertTier.SUSPICIOUS
	_expect_bool(e._is_low_posture(true), false, "enemy advancing but FIRING (aggression kept)")
	e.current_state = Enums.AIState.SUPPRESSED
	_expect_bool(e._is_low_posture(false), true, "enemy suppressed")
	e.current_state = Enums.AIState.IDLE
	_expect_bool(e._is_low_posture(false), false, "enemy idle (upright)")
	e.queue_free()

	var a: AllyBase = AllyScript.new()
	add_child(a)
	await get_tree().process_frame
	await get_tree().process_frame

	a.current_state = Enums.AIState.COMBAT
	a.suppression_level = 0.7
	a.has_line_of_sight = true
	_expect_bool(a._is_low_posture(false), true, "ally heavy pin (0.7)")
	a.suppression_level = 0.3
	_expect_bool(a._is_low_posture(false), false, "ally light fire (0.3, aggression kept)")
	a.suppression_level = 0.7
	_expect_bool(a._is_low_posture(true), false, "ally pinned but FIRING (aggression kept)")
	a.suppression_level = 0.0
	a.current_state = Enums.AIState.SEEKING_COVER
	a.has_line_of_sight = false
	_expect_bool(a._is_low_posture(false), true, "ally eyes-off move to cover")
	a.has_line_of_sight = true
	_expect_bool(a._is_low_posture(false), false, "ally cover-seek WITH eyes-on (upright)")
	a.queue_free()


## --- PART D: cover_to_stand fires on a living cover-exit, never on a corpse.
func _test_cover_exit() -> void:
	print("\n[D] cover-exit stand-up (B3)")
	var e: EnemyBase = EnemyScript.new()
	add_child(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var ma: ModelActor = ModelActorScript.new()
	e.add_child(ma)
	if not ma.setup("us_grunt_v3"):
		_fails += 1
		print("  FAIL: could not set up model for cover-exit test")
		e.queue_free()
		return
	e.sprite_actor = ma

	# A living man who held cover: cover_to_stand window opens.
	e.current_state = Enums.AIState.COMBAT
	e.has_cover = true
	e._last_cover_exit_ms = -1.0e9
	e._cover_exit_until_ms = 0.0
	e._release_cover()
	var fired: bool = e._cover_exit_until_ms > float(Time.get_ticks_msec())
	_expect_bool(fired, true, "living cover-exit opens cover_to_stand window")

	# A corpse must NOT stand up.
	e.current_state = Enums.AIState.DEAD
	e.has_cover = true
	e._last_cover_exit_ms = -1.0e9
	e._cover_exit_until_ms = 0.0
	e._release_cover()
	var corpse_fired: bool = e._cover_exit_until_ms > float(Time.get_ticks_msec())
	_expect_bool(corpse_fired, false, "corpse cover-exit does NOT stand up")

	e.queue_free()
