## probe_ai_lod.gd - does the behavioural LOD do what the Summoner ruled, and does it
## hold at the seams? (ruling 2026-09-09, design in scripts/ai/ai_lod.gd)
##
## This is the CORRECTNESS half of the before/after. The PERFORMANCE half is
## `perf_stress.bat` vs `perf_stress_lod_off.bat` - same build, one flag apart, with the
## promoted count printed on an [AILOD] row beside every [FPS] row.
##
## Twelve assertions, in the order the design can fail:
##   1  a man inside 80 m is NEAR
##   2  a man born beyond 105 m demotes, but only after the dwell
##   3  DWELL: he is still NEAR before DEMOTE_DWELL_S has passed
##   4  HYSTERESIS: a demoted man at 92 m stays FAR - he does not flicker back
##   5  ...and promotes the moment he crosses 80 m
##   6  a SAPPER at 400 m is never demoted
##   7  STICKY: a far man shot by the player promotes without closing a metre
##   8  ...bounded - the same hit at 200 m promotes nobody (STICKY_MAX_M)
##   9  CHEAP IS NOT ABSENT: a far man actually advances on his objective
##  10  ...and the wave spreads: six men on one objective do not aim at one point
##  11  the census counts exactly the men who are NEAR
##  12  --ai-lod-off puts every man back on the full brain (the BEFORE side)
##
##   godot --headless --path . res://tools/probe_ai_lod.tscn
extends Node3D

const RIFLEMAN: String = "res://data/enemies/vc_rifleman.tres"
const SAPPER: String = "res://data/enemies/vc_sapper.tres"
## One eval interval plus the per-man phase jitter, with room to spare.
const SETTLE_S: float = 0.6

var _pass: int = 0
var _fail: int = 0
var _player: Node3D = null


func _ready() -> void:
	AILod.force(true)
	AILod.reset()
	_floor()
	_player = Node3D.new()
	_player.name = "StandInPlayer"
	_player.add_to_group("player")
	add_child(_player)
	_player.global_position = Vector3.ZERO
	GameManager.player = _player

	print("[LODPROBE] promote %.0fm | demote %.0fm | dwell %.1fs | sticky ceiling %.0fm"
		% [AILod.PROMOTE_M, AILod.DEMOTE_M, AILod.DEMOTE_DWELL_S, AILod.STICKY_MAX_M])

	await _t(0.5)   # let the men finish _ready / _setup_visual before anything is judged

	await _distance_band()
	await _hysteresis()
	await _sapper_exempt()
	await _sticky()
	await _far_is_not_absent()
	await _census()
	await _off_switch()

	print("[LODPROBE] %d passed, %d FAILED" % [_pass, _fail])
	if _fail > 0:
		push_error("[LODPROBE] %d assertion(s) failed - the LOD does not hold" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## ---------- 1, 2, 3: the band and the dwell ----------

func _distance_band() -> void:
	var near_man: EnemyBase = _man(RIFLEMAN, Vector3(40.0, 0.5, 0.0))
	var far_man: EnemyBase = _man(RIFLEMAN, Vector3(300.0, 0.5, 0.0))
	await _t(SETTLE_S)
	_ok(near_man.ai_tier == AILod.Tier.NEAR, "1  a man at 40 m runs the full brain")
	# 3 BEFORE 2: the dwell is the thing that stops the handoff being visible, and it is
	# only provable while it is still running.
	_ok(far_man.ai_tier == AILod.Tier.NEAR,
		"3  DWELL - a man at 300 m is still NEAR %.1fs in (dwell is %.1fs)"
		% [SETTLE_S, AILod.DEMOTE_DWELL_S])
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S)
	_ok(far_man.ai_tier == AILod.Tier.FAR, "2  a man at 300 m demotes once the dwell expires")
	near_man.queue_free()
	far_man.queue_free()
	await _t(0.2)


## ---------- 4, 5: the hysteresis band, walked in both directions ----------

func _hysteresis() -> void:
	var m: EnemyBase = _man(RIFLEMAN, Vector3(130.0, 0.5, 0.0))
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S)
	if m.ai_tier != AILod.Tier.FAR:
		_ok(false, "4  setup - the man at 130 m never demoted, so hysteresis is untested")
		m.queue_free()
		return
	# 92 m: past PROMOTE_M, inside DEMOTE_M. If the band were one number he would flicker
	# here forever, and the handoff would be the most visible thing in the fight.
	m.global_position = Vector3(92.0, 0.5, 0.0)
	await _t(SETTLE_S * 3.0)
	_ok(m.ai_tier == AILod.Tier.FAR,
		"4  HYSTERESIS - a demoted man walking back to 92 m stays FAR (no flicker in the band)")
	m.global_position = Vector3(75.0, 0.5, 0.0)
	await _t(SETTLE_S)
	_ok(m.ai_tier == AILod.Tier.NEAR, "5  ...and promotes the instant he crosses 80 m")
	m.queue_free()
	await _t(0.2)


## ---------- 6: the demolition party is exempt ----------

func _sapper_exempt() -> void:
	var s: EnemyBase = _man(SAPPER, Vector3(400.0, 0.5, 0.0))
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S * 2.0)
	_ok(s.silent_infiltrator, "6a a vc_sapper is silent_infiltrator (the exemption marker)")
	_ok(s.ai_tier == AILod.Tier.NEAR,
		"6  a SAPPER at 400 m keeps his breach brain - never demoted by distance")
	s.queue_free()
	await _t(0.2)


## ---------- 7, 8: promotion is not only distance, and it is bounded ----------

func _sticky() -> void:
	var a: EnemyBase = _man(RIFLEMAN, Vector3(130.0, 0.5, 0.0))
	var b: EnemyBase = _man(RIFLEMAN, Vector3(200.0, 0.5, 0.0))
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S)
	var a_was: int = a.ai_tier
	var b_was: int = b.ai_tier
	a.take_damage(1, Enums.DamageType.PHYSICAL, _player, "BODY")
	b.take_damage(1, Enums.DamageType.PHYSICAL, _player, "BODY")
	await _t(SETTLE_S)
	_ok(a_was == AILod.Tier.FAR and a.ai_tier == AILod.Tier.NEAR,
		"7  STICKY - a far man at 130 m the PLAYER shoots promotes without closing a metre")
	_ok(b_was == AILod.Tier.FAR and b.ai_tier == AILod.Tier.FAR,
		"8  ...and it is bounded - the same hit at 200 m promotes nobody (ceiling %.0fm)"
		% AILod.STICKY_MAX_M)
	a.queue_free()
	b.queue_free()
	await _t(0.2)


## ---------- 9, 10: the far tier is CHEAP, not ABSENT ----------

func _far_is_not_absent() -> void:
	var objective := Vector3(0.0, 0.5, 0.0)   # the "firebase", where the player stands
	var wave: Array[EnemyBase] = []
	for i in range(6):
		var m: EnemyBase = _man(RIFLEMAN, Vector3(250.0, 0.5, float(i) * 3.0))
		m.assault_objective = objective
		wave.append(m)
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S)
	var all_far: bool = true
	for m in wave:
		if m.ai_tier != AILod.Tier.FAR:
			all_far = false
	if not all_far:
		_ok(false, "9  setup - the wave never demoted, so far-tier movement is untested")
		for m in wave:
			m.queue_free()
		return
	var a0: float = wave[0].global_position.distance_to(objective)
	await _t(3.0)
	var a1: float = wave[0].global_position.distance_to(objective)
	_ok(a1 < a0 - 2.0,
		"9  CHEAP IS NOT ABSENT - a far man advanced %.1f m on the objective in 3 s"
		% (a0 - a1))
	# THE LANE. Six men handed ONE objective must not aim at one point, or 45 of them
	# read as a queue at the gate instead of a wave hitting a front. Measured on the
	# TARGET POINTS, not on their current positions: a start-position spread would let
	# this assertion pass with the lane doing nothing at all.
	var lo: float = 1e9
	var hi: float = -1e9
	for m in wave:
		var t: float = m._far_target_point().z
		lo = minf(lo, t)
		hi = maxf(hi, t)
	_ok(hi - lo > 4.0,
		"10 ...and the wave holds a FRONT - six men on one objective aim across %.1f m (lane is +/-%.0f m)"
		% [hi - lo, EnemyBase.FAR_LANE_M])
	for m in wave:
		m.queue_free()
	await _t(0.2)


## ---------- 11: the number he asked for ----------

func _census() -> void:
	var men: Array[EnemyBase] = []
	for i in range(6):
		men.append(_man(RIFLEMAN, Vector3(30.0 + float(i) * 60.0, 0.5, 0.0)))
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S * 2.0)
	var counted: int = 0
	for m in men:
		if m.ai_tier == AILod.Tier.NEAR:
			counted += 1
	var census: int = AILod.promoted_count()
	_ok(census == counted,
		"11 the census counts exactly the men who are NEAR (%d roster / %d walked)"
		% [census, counted])
	print("[LODPROBE]    ranges 30/90/150/210/270/330 m -> %d promoted" % counted)
	for m in men:
		m.queue_free()
	await _t(0.2)


## ---------- 12: the A/B switch, so before and after are one build ----------

func _off_switch() -> void:
	AILod.force(false)
	var m: EnemyBase = _man(RIFLEMAN, Vector3(500.0, 0.5, 0.0))
	await _t(AILod.DEMOTE_DWELL_S + SETTLE_S * 2.0)
	_ok(m.ai_tier == AILod.Tier.NEAR,
		"12 --ai-lod-off puts a man at 500 m back on the full brain (the BEFORE side)")
	m.queue_free()
	AILod.force(true)
	await _t(0.2)


## ---------- plumbing ----------

func _man(data: String, at: Vector3) -> EnemyBase:
	var e: EnemyBase = EnemyBase.spawn_enemy(self, at, data)
	return e


func _t(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("[LODPROBE] PASS  %s" % what)
	else:
		_fail += 1
		print("[LODPROBE] FAIL  %s" % what)


func _floor() -> void:
	var f := StaticBody3D.new()
	f.collision_layer = 1
	f.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1400.0, 0.4, 400.0)
	cs.shape = box
	cs.position = Vector3(300.0, -0.2, 0.0)
	f.add_child(cs)
	add_child(f)
