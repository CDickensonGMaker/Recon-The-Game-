## test_body_gate.gd - the brain never sleeps (W0 preservation probe, A2 contract).
## Headless = nothing is ever on screen, so these hold exactly what the coming body
## gate must preserve:
##   (a) an enemy 200m from the player still accumulates thinks (LOD-throttled, never 0);
##   (b) he still HEARS: a noise event 30m from him raises awareness + tier;
##   (c) a downed man's bleed clock keeps running;
##   (d) a man inside his cover_exit window keeps thinking (never gated mid-stand).
## Run: godot --headless --path . res://tests/test_body_gate.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"

var _failures: int = 0


func _ready() -> void:
	print("=== BODY GATE probe (unseen brains keep ticking) ===")
	await _run()


func _run() -> void:
	_make_floor()
	var proxy := Node3D.new()
	add_child(proxy)
	proxy.global_position = Vector3.ZERO
	GameManager.player = proxy

	var far: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(200, 1, 0), ENEMY_DATA)
	var down: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(30, 1, 40), ENEMY_DATA)
	var cover: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(60, 1, -10), ENEMY_DATA)
	await get_tree().create_timer(2.5).timeout

	# (c)+(d) clocks armed, (a) counter sampled - one shared 3s window.
	down._become_downed()
	var bleed0: float = down._downed_bleed_s
	cover._cover_exit_until_ms = float(Time.get_ticks_msec()) + 4000.0
	var far_c0: int = far.think_count
	var cover_c0: int = cover.think_count
	await get_tree().create_timer(3.0).timeout

	var far_thinks: int = far.think_count - far_c0
	print("  far (200m): %d thinks in 3s" % far_thinks)
	if far_thinks < 3:
		_fail("(a) distant enemy thought %d times in 3s - brain gated by distance" % far_thinks)
	else:
		print("  [OK] (a) 200m off-screen enemy keeps thinking")

	var a0: float = far.awareness
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, Vector3(170, 1, 0), 0)
	if far.awareness < a0 + 0.3:
		_fail("(b) 30m gunshot did not raise awareness (%.2f -> %.2f)" % [a0, far.awareness])
	elif far.alert_tier < EnemyBase.AlertTier.SUSPICIOUS:
		_fail("(b) 30m gunshot left him RELAXED (tier=%d)" % far.alert_tier)
	else:
		print("  [OK] (b) distant enemy still hears (awareness %.2f, tier %d)" % [far.awareness, far.alert_tier])

	var bled: float = bleed0 - down._downed_bleed_s
	if not down.is_downed and down.current_state != Enums.AIState.DEAD:
		_fail("(c) downed man is neither downed nor dead")
	elif bled < 2.0:
		_fail("(c) downed bleed clock advanced %.1fs in 3s - frozen" % bled)
	else:
		print("  [OK] (c) downed bleed clock ran %.1fs in 3s" % bled)

	var in_window: bool = float(Time.get_ticks_msec()) < cover._cover_exit_until_ms
	var cover_thinks: int = cover.think_count - cover_c0
	if not in_window:
		_fail("(d) cover_exit window expired before the sample - probe raced")
	elif cover_thinks < 2:
		_fail("(d) man mid cover-exit thought %d times in 3s - gated during the window" % cover_thinks)
	else:
		print("  [OK] (d) cover-exit-window man kept thinking (%d thinks)" % cover_thinks)

	GameManager.player = null
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL %s" % msg)
