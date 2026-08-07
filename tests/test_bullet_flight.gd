## test_bullet_flight.gd - BulletSystem probe (bead 7ks: hitscan is dead).
##   1. TRAVEL IS REAL: a round fired at a wall 60m out arrives after multiple
##      physics ticks (distance/speed), never on the tick it left the muzzle.
##   2. DROP IS REAL: an unobstructed round falls ~4.9m over its first second
##      of flight (9.8 gravity), and it EXPIRES at MAX_TRAVEL - "a bullet is
##      a bullet", it does not stop at the weapon's stat-card max_range.
##   3. ARRIVAL DAMAGE: a bullet into a HEAD hitzone resolves through the zone
##      seams (mult 4.0 via get_damage_multiplier) with falloff by distance
##      travelled - the same grammar the retired hitscan used (ADR-016).
## Run: godot --headless --path . res://tests/test_bullet_flight.tscn
extends Node3D


class DamageRecorder:
	extends StaticBody3D
	var last_damage: int = -1
	var last_zone: String = ""
	var hits: int = 0
	func take_damage(amount: int, _type: int = 0, _attacker: Node = null, zone: String = "BODY") -> int:
		last_damage = amount
		last_zone = zone
		hits += 1
		return amount


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var failures: int = 0
	var bullets: BulletSystem = CombatManager.bullets
	if bullets == null:
		print("FAIL: CombatManager.bullets missing")
		get_tree().quit(1)
		return
	var m16: WeaponData = load("res://data/weapons/m16a1.tres")

	# --- 1. travel is real: wall at 60m, m16 projectile_speed governs arrival
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wcol := CollisionShape3D.new()
	var wshape := BoxShape3D.new()
	wshape.size = Vector3(20, 20, 1)
	wcol.shape = wshape
	wall.add_child(wcol)
	add_child(wall)
	wall.global_position = Vector3(0, 5, -60)

	bullets.fire(m16, null, Vector3(0, 5, 0), Vector3(0, 0, -1), 1, [], false)
	var ticks_to_hit: int = -1
	for t in range(120):
		await get_tree().physics_frame
		if bullets.live_count() == 0:
			ticks_to_hit = t + 1
			break
	# ASK THE ENGINE FOR THE TICK RATE. This project runs physics at 30 Hz
	# (project.godot:312), not the 60 this probe assumed - so every "per tick" figure here was
	# computed against a step half the real size.
	var phys_hz: float = float(Engine.physics_ticks_per_second)
	var expected_ticks: int = int(ceil((60.0 / m16.projectile_speed) / (1.0 / phys_hz)))
	print("  wall hit after %d ticks (expected ~%d at %.0f m/s)" % [ticks_to_hit, expected_ticks, m16.projectile_speed])
	if ticks_to_hit <= 1:
		print("FAIL: round arrived instantly - that is a hitscan, not a projectile")
		failures += 1
	if ticks_to_hit < 0 or absi(ticks_to_hit - expected_ticks) > 3:
		print("FAIL: arrival ticks off (%d vs %d)" % [ticks_to_hit, expected_ticks])
		failures += 1
	wall.queue_free()
	await get_tree().physics_frame

	# --- 2. drop is real + max-travel expiry (no obstacles in the lane)
	var slow: WeaponData = m16.duplicate()
	slow.projectile_speed = 100.0
	bullets.fire(slow, null, Vector3(0, 200, 0), Vector3(0, 0, -1), 1, [], false)
	# ONE SECOND IS `hz` FRAMES, NOT 60. At the project's 30 Hz this waited two seconds and
	# then measured the drop against a one-second expectation - 19.93m read as broken gravity
	# when it is exactly 1/2 * 9.8 * 2^2. GRAVITY is 9.8 and bullet_system.gd:118 integrates
	# it correctly; only the probe's clock was wrong.
	var ticks: int = 0
	var one_second: int = Engine.physics_ticks_per_second
	var pos_at_1s: Vector3 = Vector3.ZERO
	while bullets.live_count() > 0 and ticks < 800:
		await get_tree().physics_frame
		ticks += 1
		if ticks == one_second:
			pos_at_1s = bullets._bullets[0].pos
	if pos_at_1s == Vector3.ZERO:
		print("FAIL: bullet did not survive to 1s of flight")
		failures += 1
	else:
		var drop: float = 200.0 - pos_at_1s.y
		print("  drop after 1s: %.2fm (expect ~4.9)" % drop)
		if drop < 3.5 or drop > 6.5:
			print("FAIL: gravity drop wrong (%.2fm)" % drop)
			failures += 1
	if ticks >= 800:
		print("FAIL: round never expired (max travel/age dead)")
		failures += 1
	else:
		print("  round expired after %d ticks (max travel honored past stat-card range)" % ticks)

	# --- 3. arrival damage through the zone seams
	var body := DamageRecorder.new()
	add_child(body)
	body.global_position = Vector3(0, 0, -30)
	var hz := Hitzone.new()
	hz.zone_type = Hitzone.ZoneType.HEAD
	hz.set_owner_entity(body)
	hz.collision_layer = 64
	var hcol := CollisionShape3D.new()
	var hshape := SphereShape3D.new()
	hshape.radius = 1.0
	hcol.shape = hshape
	hz.add_child(hcol)
	add_child(hz)
	hz.global_position = Vector3(0, 5, -30)

	bullets.fire(m16, null, Vector3(0, 5, 0), Vector3(0, 0, -1), 64, [], false)
	for t in range(60):
		await get_tree().physics_frame
		if body.hits > 0:
			break
	if body.hits == 0:
		print("FAIL: bullet never resolved against the HEAD hitzone")
		failures += 1
	else:
		# 30m is inside m16 effective_range -> falloff 1.0; HEAD mult = 4.0.
		var expected: int = m16.get_damage() * 4
		print("  HEAD arrival: zone=%s dmg=%d (expect %d)" % [body.last_zone, body.last_damage, expected])
		if body.last_zone != "HEAD":
			print("FAIL: zone name did not travel (got %s)" % body.last_zone)
			failures += 1
		if body.last_damage != expected:
			print("FAIL: damage %d != base*HEADx4 %d" % [body.last_damage, expected])
			failures += 1

	if failures == 0:
		print("PASS: bullet flight (travel + drop + expiry + zone arrival damage) OK")
	else:
		print("FAIL: bullet flight probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
