## test_dormancy_clocks.gd - death clocks run UNOBSERVED (W0 preservation probe).
## No player exists in this scene: today that is maximum unobservedness, and when
## WB dormancy lands this same probe is the catch-up contract (a dormant dying man
## still dies).
##   (a) gut-bleed: an unwatched gutshot man keeps bleeding - 15s+ later his HP has
##       dropped by the bleed rate (or he is dead);
##   (b) downed bleed-out: an unwatched downed man dies ON SCHEDULE - alive with a
##       ticking clock at +3s, dead by +8s on a 6s clock.
## Run: godot --headless --path . res://tests/test_dormancy_clocks.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"

var _failures: int = 0


func _ready() -> void:
	print("=== DORMANCY CLOCKS probe ===")
	await _run()


func _run() -> void:
	_make_floor()
	var gut: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(0, 1, 0), ENEMY_DATA)
	var downed: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(100, 1, 0), ENEMY_DATA)
	await get_tree().create_timer(0.5).timeout

	gut.take_damage(8, Enums.DamageType.PHYSICAL, null, "GUT")
	var hp_after_hit: int = gut.current_hp
	if gut._gut_bleed_dps <= 0.0:
		_fail("(a) GUT hit did not start the bleed clock")
	downed._become_downed()
	downed._downed_bleed_s = 6.0

	await get_tree().create_timer(3.0).timeout
	if downed.current_state == Enums.AIState.DEAD:
		_fail("(b) downed man died EARLY (clock had 6s, dead at +3s)")
	elif not downed.is_downed:
		_fail("(b) downed man stood back up")
	elif downed._downed_bleed_s > 4.0:
		_fail("(b) downed clock frozen at %.1fs after 3s unobserved" % downed._downed_bleed_s)
	else:
		print("  [OK] (b1) +3s: downed man alive, clock ticking (%.1fs left)" % downed._downed_bleed_s)
	if not gut.is_dead() and gut.current_hp >= hp_after_hit - 8:
		_fail("(a) gut-bleed frozen: hp %d after 3s unobserved (started %d)" % [gut.current_hp, hp_after_hit])

	await get_tree().create_timer(5.0).timeout
	if downed.current_state != Enums.AIState.DEAD:
		_fail("(b) downed man immortal: 6s clock, still alive at +8s (%.1fs left)" % downed._downed_bleed_s)
	else:
		print("  [OK] (b2) +8s: downed man bled out on schedule")

	await get_tree().create_timer(9.0).timeout
	var dropped: int = hp_after_hit - gut.current_hp
	if gut.is_dead():
		print("  [OK] (a) +17s: unwatched gutshot man bled out and died")
	elif dropped >= 50:
		print("  [OK] (a) +17s: gut-bleed advanced unobserved (hp -%d)" % dropped)
	else:
		_fail("(a) gut-bleed clock froze: only -%d hp in 17s unobserved" % dropped)

	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL %s" % msg)
