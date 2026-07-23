## test_low_posture.gd - proves the shared combat-posture contract (CombatPosture)
## used by BOTH factions: crouch to hold/react/at-cover, stand to advance/flank/
## rush, a heavy pin crouches anyone, and SEEKING_COVER crouches only once NEAR the
## cover point (never on the goal flip 10m out). Also B3: cover_to_stand fires when
## a living man leaves cover, never on a corpse.
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
	print("=== Combat-Posture Probe (shared CombatPosture) ===")
	await get_tree().process_frame
	await get_tree().process_frame

	_test_module()
	_test_funnel()
	await _test_clips_exist()
	await _test_caller_guardrail()
	await _test_cover_exit()

	print("\n%s: %d failure(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## --- PART 0: the shared decision in isolation (crouch to hold, stand to push).
func _test_module() -> void:
	print("\n[0] CombatPosture.decide contract")
	var STAND := CombatPosture.Posture.STAND
	var CROUCH := CombatPosture.Posture.CROUCH
	_expect_bool(CombatPosture.decide(Enums.AIState.ADVANCING, 0.0, false) == STAND, true, "advancing -> stand")
	_expect_bool(CombatPosture.decide(Enums.AIState.FLANKING, 0.0, false) == STAND, true, "flanking -> stand")
	_expect_bool(CombatPosture.decide(Enums.AIState.COMBAT, 0.0, false) == CROUCH, true, "combat hold -> crouch")
	_expect_bool(CombatPosture.decide(Enums.AIState.SUPPRESSED, 0.0, false) == CROUCH, true, "suppressed -> crouch")
	_expect_bool(CombatPosture.decide(Enums.AIState.SEEKING_COVER, 0.0, false) == STAND, true, "seeking cover, far -> stand")
	_expect_bool(CombatPosture.decide(Enums.AIState.SEEKING_COVER, 0.0, true) == CROUCH, true, "seeking cover, near -> crouch")
	_expect_bool(CombatPosture.decide(Enums.AIState.ADVANCING, 0.7, false) == CROUCH, true, "advancing + heavy pin -> crouch")
	_expect_bool(CombatPosture.decide(Enums.AIState.IDLE, 0.0, false) == STAND, true, "idle -> stand")


## --- PART A: the intent funnel. Crouch clips appear only with the flag AND at
## crouch speed; a fast rush stays upright (the speed backstop).
func _test_funnel() -> void:
	print("\n[A] intent funnel (flag + kinematic backstop)")
	var ADV := Enums.AIState.ADVANCING
	var SUP := Enums.AIState.SUPPRESSED
	var CBT := Enums.AIState.COMBAT
	# Flag OFF -> upright, at any speed.
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 4.2, 0.0, false, false), "run", "advance fast, no flag")
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 1.8, 0.0, false, false), "run", "advance slow, no flag")
	# Flag ON but FAST (rush) -> stays upright sprint (speed backstop).
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 5.0, 0.0, false, true), "sprint", "advance sprint, flag on (backstop)")
	# Flag ON at crouch speed -> crouch-walk family.
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 1.8, 0.0, false, true), "crouch_fwd", "advance slow, flag on")
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 1.8, 0.8, false, true), "crouch_l", "advance lateral, flag on")
	_expect(SpriteStateMap.intent_for(ADV, false, false, false, 0.2, 0.0, false, true), "crouch_idle", "advance still, flag on")
	# Suppressed still -> crouch idle; suppressed moving -> crouch forward (no glide).
	_expect(SpriteStateMap.intent_for(SUP, false, false, false, 0.0, 0.0, false, true), "crouch_idle", "suppressed still")
	_expect(SpriteStateMap.intent_for(SUP, false, false, false, 1.5, 0.0, false, true), "crouch_fwd", "suppressed displacing")
	# Crouch-to-hold: a firing man who is low now crouch-aims (muzzle flash sells the shot).
	_expect(SpriteStateMap.intent_for(CBT, false, false, true, 0.0, 0.0, false, true), "crouch_aim", "combat firing while low -> crouch-aim")
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


## --- PART C: the CALLER contract on live agents. Both factions share it: crouch
## to hold/react/at-cover, stand to advance/flank/rush, heavy pin crouches anyone,
## seeking-cover crouches only NEAR the cover.
func _test_caller_guardrail() -> void:
	print("\n[C] caller contract (_is_low_posture, both factions)")
	var e: EnemyBase = EnemyScript.new()
	add_child(e)
	await get_tree().process_frame
	await get_tree().process_frame

	e.suppression_level = 0.0
	e.has_cover = false
	e._moving_to_cover = false
	e.current_state = Enums.AIState.ADVANCING
	_expect_bool(e._is_low_posture(false), false, "enemy advancing -> stand")
	e.current_state = Enums.AIState.FLANKING
	_expect_bool(e._is_low_posture(false), false, "enemy flanking -> stand")
	e.current_state = Enums.AIState.ADVANCING
	e.suppression_level = 0.7
	_expect_bool(e._is_low_posture(false), true, "enemy advancing but heavy pin -> crouch")
	e.suppression_level = 0.0
	e.current_state = Enums.AIState.COMBAT
	_expect_bool(e._is_low_posture(false), true, "enemy combat hold -> crouch")
	e.current_state = Enums.AIState.SUPPRESSED
	_expect_bool(e._is_low_posture(false), true, "enemy suppressed -> crouch")
	e.current_state = Enums.AIState.SEEKING_COVER
	e.has_cover = false
	e._moving_to_cover = false
	_expect_bool(e._is_low_posture(false), false, "enemy seeking cover, far -> stand")
	e.has_cover = true
	_expect_bool(e._is_low_posture(false), true, "enemy at cover -> crouch")
	e.current_state = Enums.AIState.IDLE
	e.has_cover = false
	_expect_bool(e._is_low_posture(false), false, "enemy idle -> stand")
	e.queue_free()

	# Allies use the IDENTICAL contract (same CombatPosture, no divergence).
	var a: AllyBase = AllyScript.new()
	add_child(a)
	await get_tree().process_frame
	await get_tree().process_frame

	a.suppression_level = 0.0
	a.has_cover = false
	a._moving_to_cover = false
	a.current_state = Enums.AIState.ADVANCING
	_expect_bool(a._is_low_posture(false), false, "ally advancing -> stand")
	a.current_state = Enums.AIState.COMBAT
	_expect_bool(a._is_low_posture(false), true, "ally combat hold -> crouch")
	a.current_state = Enums.AIState.ADVANCING
	a.suppression_level = 0.7
	_expect_bool(a._is_low_posture(false), true, "ally advancing but heavy pin -> crouch")
	a.suppression_level = 0.0
	a.current_state = Enums.AIState.SEEKING_COVER
	a.has_cover = false
	_expect_bool(a._is_low_posture(false), false, "ally seeking cover, far -> stand")
	a.has_cover = true
	_expect_bool(a._is_low_posture(false), true, "ally at cover -> crouch")
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
